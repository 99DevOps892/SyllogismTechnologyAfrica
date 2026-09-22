import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { error, json } from "../_shared/response.ts";

// POST { amount, currency, phone, provider, purpose, appId }
// Initiates a Mobile Money payment via an aggregator (PesaPal / Daraja / Payfonte).
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { global: { headers: { Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}` } } },
);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    const token = authHeader?.replace("Bearer ", "");
    if (!token) return error(401, "missing_token", "No auth token");

    const {
      data: { user },
    } = await supabase.auth.getUser(token);
    if (!user) return error(401, "unauthorized", "Invalid token");

    const body = await req.json();
    const { amount, currency = "KES", phone, provider, purpose = "payment", appId } = body;

    if (!amount || !phone || !provider) {
      return error(400, "missing_fields", "amount, phone, provider are required");
    }

    const aggregatorUrl = Deno.env.get("MOBILE_MONEY_API_URL");
    const aggregatorKey = Deno.env.get("MOBILE_MONEY_API_KEY");
    if (!aggregatorUrl || !aggregatorKey) {
      return error(503, "aggregator_not_configured", "Mobile money aggregator not configured");
    }

    const aggregatorRes = await fetch(aggregatorUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${aggregatorKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount,
        currency,
        phone,
        provider, // mpesa | airtel | mtn
        callback_url: `${Deno.env.get("SUPABASE_URL")}/functions/v1/mobile-money-webhook`,
        metadata: { userId: user.id, purpose, appId },
      }),
    });

    if (!aggregatorRes.ok) {
      const text = await aggregatorRes.text();
      return error(502, "aggregator_error", text.slice(0, 500));
    }

    const data = await aggregatorRes.json();

    await supabase.from("payments").insert({
      user_id: user.id,
      app_id: appId || null,
      amount,
      currency,
      provider,
      provider_ref: data.transaction_id,
      status: "pending",
      purpose,
      metadata: data,
    });

    return json({
      success: true,
      checkout_url: data.checkout_url || null,
      ref: data.transaction_id,
    });
  } catch (e) {
    return error(500, "internal_error", (e as Error).message);
  }
});