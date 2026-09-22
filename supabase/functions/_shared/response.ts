import { corsHeaders } from "./cors.ts";

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export function error(code: number, errorCode: string, message: string): Response {
  return json({ error: errorCode, message }, code);
}