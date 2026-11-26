import { createClient } from "npm:@supabase/supabase-js@2";

import { authenticatedUser, isAdmin, serviceClient } from "../_shared/supabase.ts";
import { corsHeaders, errorMessage, jsonResponse } from "../_shared/http.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

if (!supabaseUrl || !anonKey) {
  throw new Error("Konfigurasi Supabase Edge Function belum lengkap.");
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Metode request tidak didukung." }, 405);
  }

  try {
    const user = await authenticatedUser(request);
    if (await isAdmin(user.id)) {
      return jsonResponse(
        { error: "Akun admin tidak dapat dihapus melalui fitur ini." },
        403,
      );
    }
    if (!user.email) {
      return jsonResponse({ error: "Akun tidak memiliki alamat email." }, 400);
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return jsonResponse({ error: "Permintaan tidak valid." }, 400);
    }
    if (
      typeof body !== "object" ||
      body === null ||
      !("password" in body) ||
      typeof body.password !== "string" ||
      body.password.length === 0
    ) {
      return jsonResponse({ error: "Kata sandi wajib diisi." }, 400);
    }

    const passwordClient = createClient(supabaseUrl, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: verified, error: passwordError } = await passwordClient.auth
      .signInWithPassword({ email: user.email, password: body.password });
    if (passwordError || verified.user?.id !== user.id) {
      return jsonResponse({ error: "Kata sandi akun tidak sesuai." }, 401);
    }

    const { data: orders, error: ordersError } = await serviceClient
      .from("orders")
      .select("status")
      .eq("user_id", user.id);
    if (ordersError) throw ordersError;

    const hasOpenOrders = (orders ?? []).some(
      (order) => !["completed", "cancelled"].includes(order.status),
    );
    if (hasOpenOrders) {
      return jsonResponse(
        {
          error:
            "Selesaikan atau batalkan semua pesanan yang masih berjalan sebelum menghapus akun.",
        },
        409,
      );
    }

    const { error: deleteError } = await serviceClient.auth.admin.deleteUser(
      user.id,
    );
    if (deleteError) {
      if (deleteError.message.includes("pesanan yang belum selesai")) {
        return jsonResponse(
          {
            error:
              "Selesaikan atau batalkan semua pesanan yang masih berjalan sebelum menghapus akun.",
          },
          409,
        );
      }
      throw deleteError;
    }

    return jsonResponse({ deleted: true });
  } catch (error) {
    console.error("delete-account failed", errorMessage(error));
    return jsonResponse(
      { error: "Akun belum dapat dihapus. Silakan coba lagi." },
      500,
    );
  }
});
