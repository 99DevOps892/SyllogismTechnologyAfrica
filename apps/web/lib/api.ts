import { supabase } from "./supabase";

export interface MobileMoneyPayload {
  amount: number;
  phone: string;
  provider: "mpesa" | "airtel" | "mtn";
  purpose: string;
  appId?: string;
  currency?: string;
}

export async function initiateMobileMoneyPayment(payload: MobileMoneyPayload) {
  const { data, error } = await supabase.functions.invoke("mobile-money-pay", {
    body: payload,
  });
  if (error) throw new Error(error.message);
  return data;
}

export async function estimateDataCost(appId: string, countryCode = "KE", network = "4g") {
  const { data, error } = await supabase.functions.invoke("estimate-data-cost", {
    body: { appId, countryCode, network },
  });
  if (error) throw new Error(error.message);
  return data;
}

export async function triageReview(appId: string) {
  const { data, error } = await supabase.functions.invoke("review-triage", {
    body: { appId },
  });
  if (error) throw new Error(error.message);
  return data;
}