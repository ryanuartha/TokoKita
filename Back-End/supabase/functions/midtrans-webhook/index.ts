import { corsHeaders, errorMessage, jsonResponse } from "../_shared/http.ts";
import { serviceClient } from "../_shared/supabase.ts";

const midtransServerKey = Deno.env.get("MIDTRANS_SERVER_KEY");

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Metode request tidak didukung." }, 405);
  }
  if (!midtransServerKey) {
    return jsonResponse({ error: "Webhook belum dikonfigurasi." }, 503);
  }

  try {
    const body = await request.json();
    const orderId = body.order_id;
    const statusCode = body.status_code;
    const grossAmount = body.gross_amount;
    const signatureKey = body.signature_key;
    if (
      typeof orderId !== "string" ||
      typeof statusCode !== "string" ||
      typeof grossAmount !== "string" ||
      typeof signatureKey !== "string"
    ) {
      return jsonResponse({ error: "Payload notifikasi tidak valid." }, 400);
    }

    const expectedSignature = await sha512(
      `${orderId}${statusCode}${grossAmount}${midtransServerKey}`,
    );
    if (!constantTimeEqual(expectedSignature, signatureKey)) {
      return jsonResponse({ error: "Signature notifikasi tidak valid." }, 401);
    }

    const { data: order, error: orderError } = await serviceClient
      .from("orders")
      .select("id, total_amount")
      .eq("display_id", orderId)
      .maybeSingle();
    if (orderError) throw orderError;
    if (!order) return jsonResponse({ error: "Pesanan tidak ditemukan." }, 404);
    if (Number(grossAmount) !== order.total_amount) {
      return jsonResponse({ error: "Nominal pembayaran tidak cocok." }, 400);
    }

    const { error: updateError } = await serviceClient.rpc(
      "apply_midtrans_status",
      {
        p_order_id: order.id,
        p_transaction_status: body.transaction_status,
        p_fraud_status: body.fraud_status ?? "",
        p_transaction_id: body.transaction_id ?? "",
      },
    );
    if (updateError) throw updateError;
    return jsonResponse({ received: true });
  } catch (error) {
    console.error("midtrans-webhook failed", errorMessage(error));
    return jsonResponse({ error: "Notifikasi pembayaran gagal diproses." }, 500);
  }
});

async function sha512(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-512", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let index = 0; index < a.length; index++) {
    mismatch |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }
  return mismatch === 0;
}
