import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { error, json } from "../_shared/response.ts";

// POST { appId, countryCode, network }
// Smart Download Manager: data-cost estimation + selective (required-only) sizing.
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_ANON_KEY")!,
);

// Cost per MB (USD) by country — replace with real operator rates when enabled.
const COST_PER_MB: Record<string, number> = { KE: 0.004, NG: 0.003, ZA: 0.005, GH: 0.004, EG: 0.004 };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { appId, countryCode = "KE", network = "4g" } = await req.json();

    const { data: assets, error: assetsError } = await supabase
      .from("app_assets")
      .select("size_bytes, is_required, asset_type")
      .eq("app_id", appId);

    if (assetsError) return error(500, "asset_fetch_failed", assetsError.message);

    const totalBytes = (assets ?? []).reduce((s: number, a) => s + (a.size_bytes || 0), 0);
    const requiredBytes = (assets ?? []).filter((a) => a.is_required).reduce((s: number, a) => s + (a.size_bytes || 0), 0);

    const costPerMB = COST_PER_MB[countryCode] ?? 0.005;
    const estimateUSD = (totalBytes / 1e6) * costPerMB;
    const requiredUSD = (requiredBytes / 1e6) * costPerMB;

    return json({
      app_id: appId,
      network,
      total_mb: +(totalBytes / 1e6).toFixed(2),
      required_only_mb: +(requiredBytes / 1e6).toFixed(2),
      estimate_usd: +estimateUSD.toFixed(3),
      required_only_usd: +requiredUSD.toFixed(3),
      message: `This app uses ~${(totalBytes / 1e6).toFixed(0)}MB ≈ $${estimateUSD.toFixed(2)} on your network.`,
    });
  } catch (e) {
    return error(500, "internal_error", (e as Error).message);
  }
});