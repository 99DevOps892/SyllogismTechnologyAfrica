import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { error, json } from "../_shared/response.ts";

// POST — aggregator webhook (no user JWT; verified by x-signature).
// Runs server-side only (never in browser).
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { global: { headers: { Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}` } } },
);

async function verifySignature(body: string, signature: string): Promise<boolean> {
  const secret = Deno.env.get("MOBILE_MONEY_WEBHOOK_SECRET");
  if (!secret) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const bytes = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body)));
  const hex = [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
  return hex === signature;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const signature = req.headers.get("x-signature") || "";
    const body = await req.text();

    const secretConfigured = Boolean(Deno.env.get("MOBILE_MONEY_WEBHOOK_SECRET"));
    if (secretConfigured && !(await verifySignature(body, signature))) {
      return error(401, "bad_signature", "Invalid signature");
    }

    const event = JSON.parse(body);
    const { transaction_id, status, metadata } = event;
    if (!transaction_id) return error(400, "missing_tx", "transaction_id required");

    const paymentStatus = status === "successful" || status === "success" ? "success" : "failed";

    await supabase.from("payments")
      .update({ status: paymentStatus })
      .eq("provider_ref", transaction_id);

    if (paymentStatus === "success" && metadata?.purpose === "subscription") {
      // Activate or extend the subscription
      await supabase.from("subscriptions")
        .update({ status: "active", enabled: true })
        .eq("external_ref", transaction_id);
    }

    return new Response("ok", { status: 200, headers: corsHeaders });
  } catch (e) {
    return error(500, "webhook_error", (e as Error).message);
  }
});