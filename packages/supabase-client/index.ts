import { createClient } from "@supabase/supabase-js";

// Shared Supabase client factory — used by all eco apps (Mwarokin, Mali, SylloPay, SAICOS...).
export function createStaClient(url: string, anonKey: string) {
  return createClient(url, anonKey);
}

export * from "./payments";
export * from "./catalog";
export * from "./mali";