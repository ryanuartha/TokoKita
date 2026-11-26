import { corsHeaders, errorMessage, jsonResponse } from "../_shared/http.ts";
import {
  authenticatedUser,
  serviceClient,
} from "../_shared/supabase.ts";

const paymentMethods = new Set([
  "qris",
  "gopay",
  "bank_transfer",
  "credit_card",
  "cod",
  "store_payment",
]);
const productSizes = new Set(["S", "M", "L", "XL"]);
const productColors = new Set(["Hitam", "Putih", "Navy", "Abu-abu"]);
const enabledPayments: Record<string, string[]> = {
  qris: ["qris"],
  gopay: ["gopay"],
  bank_transfer: ["bca_va"],
  credit_card: ["credit_card"],
};
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
    const items = body.items;
    const paymentMethod = body.payment_method;
    const fulfillmentMethod = body.fulfillment_method;
    const shippingAddress = body.shipping_address;
    const voucherCode = body.voucher_code ?? "";
    const shippingLatitude = body.shipping_latitude ?? null;
    const shippingLongitude = body.shipping_longitude ?? null;

    if (!Array.isArray(items) || items.length === 0 || items.length > 50) {
      return jsonResponse({ error: "Item pesanan tidak valid." }, 400);
    }
    if (!paymentMethods.has(paymentMethod)) {
      return jsonResponse({ error: "Metode pembayaran tidak didukung." }, 400);
    }
    if (!["courier", "store_pickup"].includes(fulfillmentMethod)) {
      return jsonResponse({ error: "Metode penerimaan tidak valid." }, 400);
    }
    if (
      (shippingLatitude === null) !== (shippingLongitude === null) ||
      (shippingLatitude !== null &&
        (typeof shippingLatitude !== "number" ||
          !Number.isFinite(shippingLatitude) ||
          shippingLatitude < -90 ||
          shippingLatitude > 90)) ||
      (shippingLongitude !== null &&
        (typeof shippingLongitude !== "number" ||
          !Number.isFinite(shippingLongitude) ||
          shippingLongitude < -180 ||
          shippingLongitude > 180))
    ) {
      return jsonResponse({ error: "Titik alamat tidak valid." }, 400);
    }
    if (fulfillmentMethod === "store_pickup" && shippingLatitude !== null) {
      return jsonResponse(
        { error: "Titik alamat tidak diperlukan untuk ambil di toko." },
        400,
      );
    }
    if (typeof voucherCode !== "string" || voucherCode.length > 40) {
      return jsonResponse({ error: "Kode voucher tidak valid." }, 400);
    }
    if (
      fulfillmentMethod === "courier" &&
      (typeof shippingAddress !== "string" || shippingAddress.trim().length < 8)
    ) {
      return jsonResponse({ error: "Alamat pengiriman belum lengkap." }, 400);
    }

    const normalizedItems: {
      product_id: string;
      quantity: number;
      variant_size: string | null;
      variant_color: string | null;
    }[] = [];
    const seenVariants = new Set<string>();
    for (const item of items) {
      const variantSize = item?.variant_size ?? null;
      const variantColor = item?.variant_color ?? null;
      if (
        typeof item?.product_id !== "string" ||
        !/^(EL|PK|AK)-\d{3}$/.test(item.product_id) ||
        !Number.isInteger(item.quantity) ||
        item.quantity < 1 ||
        item.quantity > 50 ||
        (variantSize !== null &&
          (typeof variantSize !== "string" || !productSizes.has(variantSize))) ||
        (variantColor !== null &&
          (typeof variantColor !== "string" || !productColors.has(variantColor)))
      ) {
        return jsonResponse({ error: "Item pesanan tidak valid." }, 400);
      }
      const variantKey = JSON.stringify([
        item.product_id,
        variantSize,
        variantColor,
      ]);
      if (seenVariants.has(variantKey)) {
        return jsonResponse({ error: "Varian produk duplikat dalam pesanan." }, 400);
      }
      seenVariants.add(variantKey);
      normalizedItems.push({
        product_id: item.product_id,
        quantity: item.quantity,
        variant_size: variantSize,
        variant_color: variantColor,
      });
    }

    const { data: createdRows, error: createError } = await serviceClient.rpc(
      "create_store_order",
      {
        p_user_id: user.id,
        p_items: normalizedItems,
        p_payment_method: paymentMethod,
        p_fulfillment_method: fulfillmentMethod,
        p_shipping_address: fulfillmentMethod === "courier"
          ? shippingAddress.trim()
          : "Ambil di toko",
        p_voucher_code: voucherCode,
      },
    );
    if (createError) throw createError;

    const created = Array.isArray(createdRows) ? createdRows[0] : createdRows;
    if (!created?.order_id || !created?.display_id) {
      throw new Error("Pesanan tidak berhasil dibuat.");
    }

    if (shippingLatitude !== null && shippingLongitude !== null) {
      const { error: locationError } = await serviceClient
        .from("orders")
        .update({
          shipping_latitude: shippingLatitude,
          shipping_longitude: shippingLongitude,
        })
        .eq("id", created.order_id)
        .eq("user_id", user.id)
        .select("id")
        .single();
      if (locationError) {
        await cancelCreatedOrder(created.order_id);
        throw locationError;
      }
    }

    if (paymentMethod === "cod" || paymentMethod === "store_payment") {
      return jsonResponse({
        order_id: created.order_id,
        display_id: created.display_id,
        total_amount: created.total_amount,
        expires_at: null,
        payment_url: null,
        status: "processing",
      });
    }

    if (!midtransServerKey) {
      await cancelCreatedOrder(created.order_id);
      return jsonResponse({
        error: "Pembayaran belum dikonfigurasi. Hubungi admin toko.",
      }, 503);
    }

    const { data: profile, error: profileError } = await serviceClient
      .from("profiles")
      .select("full_name")
      .eq("id", user.id)
      .single();
    if (profileError) throw profileError;

    const itemDetails = created.item_details.map((item: {
      id: string;
      price: number;
      quantity: number;
      name: string;
      variant_size: string | null;
      variant_color: string | null;
    }) => {
      const variantLabel = [
        item.variant_size ? `Ukuran ${item.variant_size}` : null,
        item.variant_color,
      ]
        .filter((variant): variant is string => variant !== null)
        .join(", ");
      const name = variantLabel
        ? `${item.name.substring(0, 47 - variantLabel.length)} - ${variantLabel}`
        : item.name.substring(0, 50);
      return {
        id: item.id,
        price: item.price,
        quantity: item.quantity,
        name,
      };
    });
    const itemTotal = itemDetails.reduce(
      (total: number, item: { price: number; quantity: number }) =>
        total + item.price * item.quantity,
      0,
    );
    const adjustment = created.total_amount - itemTotal;
    if (adjustment !== 0) {
      itemDetails.push({
        id: "order-adjustment",
        price: adjustment,
        quantity: 1,
        name: adjustment < 0 ? "Diskon voucher" : "Ongkos kirim",
      });
    }

    const expiryMinutes = paymentMethod === "bank_transfer" ? 1440 : 15;
    const snapResponse = await fetch(
      production
        ? "https://app.midtrans.com/snap/v1/transactions"
        : "https://app.sandbox.midtrans.com/snap/v1/transactions",
      {
        method: "POST",
        headers: {
          Authorization: `Basic ${btoa(`${midtransServerKey}:`)}`,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({
          transaction_details: {
            order_id: created.display_id,
            gross_amount: created.total_amount,
          },
          item_details: itemDetails,
          customer_details: {
            first_name: (profile.full_name || user.email || "Pembeli")
              .substring(0, 50),
            email: user.email,
          },
          enabled_payments: enabledPayments[paymentMethod],
          expiry: {
            start_time: new Date().toISOString()
              .replace("T", " ")
              .replace(/\.\d{3}Z$/, " +0000"),
            unit: "minute",
            duration: expiryMinutes,
          },
        }),
      },
    );

    const snapBody = await snapResponse.json();
    if (!snapResponse.ok || !snapBody.token || !snapBody.redirect_url) {
      await cancelCreatedOrder(created.order_id);
      console.error("Midtrans Snap rejected create transaction", {
        status: snapResponse.status,
        orderId: created.display_id,
      });
      return jsonResponse({
        error: "Midtrans gagal membuat tagihan. Silakan coba kembali.",
      }, 502);
    }

    const { error: saveError } = await serviceClient
      .from("orders")
      .update({
        snap_token: snapBody.token,
        snap_redirect_url: snapBody.redirect_url,
        updated_at: new Date().toISOString(),
      })
      .eq("id", created.order_id);
    if (saveError) {
      await cancelCreatedOrder(created.order_id);
      throw saveError;
    }

    return jsonResponse({
      order_id: created.order_id,
      display_id: created.display_id,
      total_amount: created.total_amount,
      expires_at: created.expires_at,
      payment_url: snapBody.redirect_url,
      status: "pending_payment",
    });
  } catch (error) {
    console.error("create-payment failed", errorMessage(error));
    return jsonResponse({ error: errorMessage(error) }, 400);
  }
});

async function cancelCreatedOrder(orderId: string): Promise<void> {
  const { error } = await serviceClient.rpc("transition_store_order", {
    p_order_id: orderId,
    p_action: "cancel",
    p_tracking_number: null,
    p_actor_id: null,
    p_is_admin: true,
  });
  if (error) console.error("Could not release order reservation", orderId);
}
