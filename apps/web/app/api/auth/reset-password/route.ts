import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { supabase } from "../../../../lib/supabase";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export async function POST(request: NextRequest) {
  let body: { email?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ detail: "invalid request body" }, { status: 400 });
  }

  const email = (body.email || "").trim().toLowerCase();
  if (!EMAIL_RE.test(email)) {
    return NextResponse.json({ detail: "enter a valid email address" }, { status: 422 });
  }

  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
    return NextResponse.json(
      { detail: "password reset requires Supabase auth to be configured" },
      { status: 501 },
    );
  }

  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: "/reset-password",
  });
  if (error) {
    console.warn("reset_password_failed", error.message);
    return NextResponse.json({ detail: "unable to start password reset" }, { status: 400 });
  }

  console.info("reset_password_requested", email);
  return NextResponse.json({ status: "ok" });
}