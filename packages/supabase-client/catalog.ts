import type { SupabaseClient } from "@supabase/supabase-js";

export interface CatalogApp {
  id: string;
  title: string;
  slug: string;
  short_description: string | null;
  category: string | null;
  size_mb: number | null;
  is_pwa: boolean;
  offline_capable: boolean;
  supports_mobile_money: boolean;
  status: string;
}

/** Public catalog — only approved apps (RLS enforces this server-side too). */
export async function listApprovedApps(supabase: SupabaseClient): Promise<CatalogApp[]> {
  const { data, error } = await supabase
    .from("apps")
    .select("id, title, slug, short_description, category, size_mb, is_pwa, offline_capable, supports_mobile_money, status")
    .eq("status", "approved")
    .order("created_at", { ascending: false });

  if (error) throw new Error(error.message);
  return (data ?? []) as CatalogApp[];
}