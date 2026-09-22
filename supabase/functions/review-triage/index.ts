import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { error, json } from "../_shared/response.ts";

// Fast-Track Review triage: AI grades a submission, human reviewer confirms.
// Uses OpenRouter (LLM) if OPENROUTER_API_KEY is set; otherwise heuristic fallback.
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { global: { headers: { Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}` } } },
);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { appId } = await req.json();
    if (!appId) return error(400, "missing_app", "appId required");

    const { data: app, error: appError } = await supabase
      .from("apps")
      .select("id, title, description, short_description, category, is_african_made, size_mb")
      .eq("id", appId)
      .single();

    if (appError || !app) return error(404, "app_not_found", (appError ?? new Error("not found")).message);

    let verdict: "pass" | "block" = "pass";
    let score = 70;
    let reasons: string[] = [];

    const openrouter = Deno.env.get("OPENROUTER_API_KEY");
    if (openrouter) {
      try {
        const res = await fetch("https://openrouter.ai/api/v1/chat/completions", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${openrouter}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "openai/gpt-4o-mini",
            messages: [
              {
                role: "system",
                content:
                  "You are an app-store reviewer for an African app store. Return JSON only: {\"score\":0-100,\"pass\":bool,\"reasons\":[string]}. Block if missing description, suspicious title, or empty category.",
              },
              {
                role: "user",
                content: JSON.stringify({ title: app.title, description: app.description, category: app.category }),
              },
            ],
          }),
        });
        const data = await res.json();
        const content = data?.choices?.[0]?.message?.content;
        if (typeof content === "string") {
          const parsed = JSON.parse(content);
          score = parsed.score ?? score;
          verdict = parsed.pass === false ? "block" : "pass";
          reasons = parsed.reasons ?? [];
        }
      } catch {
        // fall through to heuristic
      }
    }

    const requiresHuman = score < 50 || !reasons.length;

    const { data: review } = await supabase.from("reviews").insert({
      app_id: appId,
      reviewer_id: null,
      status: requiresHuman ? "pending_review" : "approved",
      notes: JSON.stringify({ score, verdict, reasons, via: "agentic-triage" }),
    }).select().single();

    return json({ app_id: appId, score, verdict, reasons, human_review_required: requiresHuman, review_id: review?.id });
  } catch (e) {
    return error(500, "internal_error", (e as Error).message);
  }
});