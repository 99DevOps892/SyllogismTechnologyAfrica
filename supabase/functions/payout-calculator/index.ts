import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { error, json } from "../_shared/response.ts";

// Payout calculator — 10% platform revenue share.
// Runs on a schedule (cron): sums successful payments per creator per period,
// leaves 10% platform cut, creates payout rows for creators.
const REVENUE_SHARE = 0.10;

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { global: { headers: { Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}` } } },
);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const periodStart = new Date();
    periodStart.setUTCDate(1);
    periodStart.setUTCHours(0, 0, 0, 0);
    const periodEnd = new Date(periodStart);
    periodEnd.setUTCMonth(periodEnd.getUTCMonth() + 1);

    // Sum successful IAP/tip/download payments per creator (negative amounts excluded).
    const { data: rows, error: paymentsError } = await supabase
      .from("payments")
      .select(`app_id, amount, status, apps!inner(creator_id)`)
      .eq("status", "success")
      .gte("created_at", periodStart.toISOString())
      .lt("created_at", periodEnd.toISOString());

    if (paymentsError) return error(500, "payments_query_failed", paymentsError.message);

    const byCreator = new Map<string, number>();
    for (const row of rows ?? []) {
      const creatorId = (row as unknown as { apps: { creator_id: string } }).apps?.creator_id;
      if (!creatorId) continue;
      const gross = Number(row.amount) || 0;
      byCreator.set(creatorId, (byCreator.get(creatorId) ?? 0) + gross);
    }

    let created = 0;
    for (const [creatorId, gross] of byCreator) {
      const net = gross - gross * REVENUE_SHARE;
      const { data } = await supabase.from("payouts").insert({
        creator_id: creatorId,
        amount: +net.toFixed(2),
        currency: "KES",
        status: "pending",
        period_start: periodStart.toISOString().slice(0, 10),
        period_end: periodEnd.toISOString().slice(0, 10),
      }).select("id").single();
      if (data) created++;
    }

    return json({ period_start: periodStart.toISOString(), creators: byCreator.size, payouts_created: created });
  } catch (e) {
    return error(500, "internal_error", (e as Error).message);
  }
});