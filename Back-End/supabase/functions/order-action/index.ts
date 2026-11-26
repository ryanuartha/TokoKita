import { corsHeaders, errorMessage, jsonResponse } from "../_shared/http.ts";
import {
  authenticatedUser,
  isAdmin,
  serviceClient,
} from "../_shared/supabase.ts";

const allowedActions = new Set([
  "cancel",
  "dispatch",
  "mark_delivered",
  "confirm_received",
  "handover_pickup",
  "confirm_cash_payment",
]);
const production = Deno.env.get("MIDTRANS_IS_PRODUCTION") === "true";
const midtransServerKey = Deno.env.get("MIDTRANS_SERVER_KEY");

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Metode request tidak didukung." }, 405);
  }

  try {
    const user = await authenticatedUser(request);
    const body = await request.json();
    const orderId = body.order_id;
    const action = body.action;
    const trackingNumber = body.tracking_number ?? null;
    if (
      typeof orderId !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(orderId) ||
      !allowedActions.has(action)
    ) {
      return jsonResponse({ error: "Aksi pesanan tidak valid." }, 400);
    }
    if (
      action === "dispatch" &&
      trackingNumber !== null &&
      typeof trackingNumber !== "string"
    ) {
      return jsonResponse({ error: "Nomor resi tidak valid." }, 400);
    }

    const admin = await isAdmin(user.id);
    if (
      [
        "dispatch",
        "mark_delivered",
        "handover_pickup",
        "confirm_cash_payment",
      ].includes(action) && !admin
    ) {
      return jsonResponse({ error: "Akses admin diperlukan." }, 403);
    }

    if (action === "cancel") {
      const { data: order, error: orderError } = await serviceClient
        .from("orders")
        .select("user_id, status, display_id")
        .eq("id", orderId)
        .maybeSingle();
      if (orderError) throw orderError;
      if (!order) {
        return jsonResponse({ error: "Pesanan tidak ditemukan." }, 404);
      }
      if (order.user_id !== user.id && !admin) {
        return jsonResponse(
          { error: "Tidak berwenang membatalkan pesanan ini." },
          403,
        );
      }
      if (order.status === "cancelled") {
        return jsonResponse({ updated: true });
      }
      if (order.status === "pending_payment") {
        const cancellationError = await cancelPendingMidtransTransaction(
          order.display_id,
        );
        if (cancellationError) return cancellationError;
      }
    }

    const { error } = await serviceClient.rpc("transition_store_order", {
      p_order_id: orderId,
      p_action: action,
      p_tracking_number: trackingNumber,
      p_actor_id: user.id,
      p_is_admin: admin,
    });
    if (error) throw error;
    return jsonResponse({ updated: true });
  } catch (error) {
    console.error("order-action failed", errorMessage(error));
    return jsonResponse({ error: errorMessage(error) }, 400);
  }
});

async function cancelPendingMidtransTransaction(
  displayId: string,
): Promise<Response | null> {
  if (!midtransServerKey) {
    return jsonResponse(
      { error: "Pembatalan pembayaran belum dikonfigurasi. Hubungi admin toko." },
      503,
    );
  }

  const baseUrl = production
    ? "https://api.midtrans.com"
    : "https://api.sandbox.midtrans.com";
  const endpoint = `${baseUrl}/v2/${encodeURIComponent(displayId)}`;
  const headers = {
    Authorization: `Basic ${btoa(`${midtransServerKey}:`)}`,
    Accept: "application/json",
  };

  try {
    let cancelResponse: Response | null = null;
    try {
      cancelResponse = await fetch(`${endpoint}/cancel`, {
        method: "POST",
        headers,
      });
    } catch (error) {
      console.error("Midtrans cancel request failed", errorMessage(error));
    }
    if (cancelResponse?.ok) return null;

    const statusResponse = await fetch(`${endpoint}/status`, { headers });
    if (!statusResponse.ok) {
      console.error("Midtrans status request failed", statusResponse.status);
      return jsonResponse(
        {
          error:
            "Status pembayaran belum dapat dipastikan. Pesanan belum dibatalkan, silakan coba lagi.",
        },
        502,
      );
    }

    const statusBody = await statusResponse.json();
    const transactionStatus = statusBody.transaction_status;
    if (typeof transactionStatus !== "string") {
      return jsonResponse(
        {
          error:
            "Status pembayaran belum dapat dipastikan. Pesanan belum dibatalkan, silakan coba lagi.",
        },
        502,
      );
    }
    if (["cancel", "expire", "deny"].includes(transactionStatus)) return null;
    if (transactionStatus === "pending") {
      return jsonResponse(
        {
          error:
            "Pembayaran belum berhasil dibatalkan di Midtrans. Silakan coba lagi.",
        },
        502,
      );
    }
    return jsonResponse(
      {
        error:
          "Pembayaran sudah diproses atau tidak dapat dibatalkan. Segarkan status pesanan.",
      },
      409,
    );
  } catch (error) {
    console.error("Midtrans cancellation check failed", errorMessage(error));
    return jsonResponse(
      {
        error:
          "Status pembayaran belum dapat dipastikan. Pesanan belum dibatalkan, silakan coba lagi.",
      },
      502,
    );
  }
}
