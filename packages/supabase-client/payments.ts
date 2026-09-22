import type { SupabaseClient } from "@supabase/supabase-js";

export interface InitiatePaymentInput {
  amount: number;
  currency: string;
  phone: string;
  provider: "mpesa" | "airtel" | "mtn" | "coop" | "im";
  purpose: "subscription" | "iap" | "tip" | "download" | "rent" | "fee";
  appId?: string;
}

export async function initiatePayment(supabase: SupabaseClient, input: InitiatePaymentInput) {
  const { data, error } = await supabase.functions.invoke("mobile-money-pay", { body: input });
  if (error) throw new Error(error.message);
  return data as { success: true; checkout_url: string | null; ref: string };
}

/** 1-5 Ksh per processed tenant transaction (Setup task 2). Storage = payments.fee_amount. */
export function transactionFee(amount: number): number {
  const BASE_FEE = 1; // KES
  const MAX_FEE = 5; // KES
  return Math.min(MAX_FEE, Math.max(BASE_FEE, Math.round(amount * 0.01)));
}