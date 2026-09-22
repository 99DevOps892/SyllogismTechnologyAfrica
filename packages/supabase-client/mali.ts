import type { SupabaseClient, RealtimeChannel } from "@supabase/supabase-js";

// =====================================================================
// MALI Access Union — typed client for the live MALI project
// (vfkqjapegrhdsrlmmiih). Mirrors the live store shape (migration 006
// + 008 realtime/creator policies). RLS-scoped: lookups are anonymous,
// the write path requires an authenticated user (group creator / member).
// SAFE: read + INSERT only. No UPDATE/DELETE anywhere in this module.
// =====================================================================

export interface MaliLookup {
  id: number;
  code: string;
  name: string;
  [k: string]: unknown;
}

export interface MaliGroup {
  id: string;
  name: string;
  currency: string;
  description: string | null;
  is_active: boolean;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface MaliMember {
  id: string;
  group_id: string;
  auth_uid: string | null;
  phone: string | null;
  full_name: string;
  national_id: string | null;
  join_date: string;
  role: string;
  is_active: boolean;
  created_at: string;
}

export interface MaliCycle {
  id: string;
  group_id: string;
  saving_type: number;
  state: number;
  name: string;
  contribution: number;
  currency: string;
  frequency: string;
  start_date: string | null;
  end_date: string | null;
  pot_target: number | null;
  is_rotating: boolean;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface MaliContribution {
  id: string;
  cycle_id: string;
  member_id: string;
  amount: number;
  currency: string;
  channel_id: number | null;
  paid_on: string;
  ref_no: string | null;
  verified_by: string | null;
  verified_at: string | null;
  created_at: string;
}

export interface MaliLookups {
  ethnicGroups: MaliLookup[];
  savingTypes: MaliLookup[];
  cycleStates: MaliLookup[];
  paymentChannels: MaliLookup[];
}

export interface MaliGroupInput {
  name: string;
  description?: string | null;
  currency?: string;
  is_active?: boolean;
  created_by: string;
}

export interface MaliMemberInput {
  group_id: string;
  full_name: string;
  phone?: string | null;
  national_id?: string | null;
  role?: string;
  auth_uid?: string | null;
}

export interface MaliCycleInput {
  group_id: string;
  name: string;
  saving_type: number;
  state?: number;
  contribution: number;
  currency?: string;
  frequency?: string;
  pot_target?: number | null;
  is_rotating?: boolean;
  created_by: string;
}

export interface MaliContributionInput {
  cycle_id: string;
  member_id: string;
  amount: number;
  currency?: string;
  channel_id?: number | null;
  paid_on?: string;
  ref_no?: string | null;
}

export async function fetchMaliLookups(supabase: SupabaseClient): Promise<MaliLookups> {
  const q = async (table: string) => {
    const { data, error } = await supabase.from(table).select("*").order("code");
    if (error) throw new Error(error.message);
    return (data ?? []) as MaliLookup[];
  };
  const [ethnicGroups, savingTypes, cycleStates, paymentChannels] = await Promise.all([
    q("mali_ethnic_group"),
    q("mali_saving_type"),
    q("mali_cycle_state"),
    q("mali_payment_channel"),
  ]);
  return { ethnicGroups, savingTypes, cycleStates, paymentChannels };
}

export async function listMaliGroups(supabase: SupabaseClient): Promise<MaliGroup[]> {
  const { data, error } = await supabase.from("mali_union_group").select("*").order("created_at", { ascending: false });
  if (error) throw new Error(error.message);
  return (data ?? []) as MaliGroup[];
}

export async function createMaliGroup(supabase: SupabaseClient, input: MaliGroupInput): Promise<MaliGroup> {
  const { data, error } = await supabase
    .from("mali_union_group")
    .insert({
      name: input.name,
      description: input.description ?? null,
      currency: input.currency ?? "XOF",
      is_active: input.is_active ?? true,
      created_by: input.created_by,
    })
    .select()
    .single();
  if (error) throw new Error(error.message);
  return data as MaliGroup;
}

export async function listMaliMembers(supabase: SupabaseClient, groupId?: string): Promise<MaliMember[]> {
  let q = supabase.from("mali_union_member").select("*").order("created_at", { ascending: false });
  if (groupId) q = q.eq("group_id", groupId);
  const { data, error } = await q;
  if (error) throw new Error(error.message);
  return (data ?? []) as MaliMember[];
}

export async function addMaliMember(supabase: SupabaseClient, input: MaliMemberInput): Promise<MaliMember> {
  const { data, error } = await supabase
    .from("mali_union_member")
    .insert({
      group_id: input.group_id,
      full_name: input.full_name,
      phone: input.phone ?? null,
      national_id: input.national_id ?? null,
      role: input.role ?? "member",
      auth_uid: input.auth_uid ?? null,
    })
    .select()
    .single();
  if (error) throw new Error(error.message);
  return data as MaliMember;
}

export async function listMaliCycles(supabase: SupabaseClient, groupId?: string): Promise<MaliCycle[]> {
  let q = supabase.from("mali_cycle").select("*").order("created_at", { ascending: false });
  if (groupId) q = q.eq("group_id", groupId);
  const { data, error } = await q;
  if (error) throw new Error(error.message);
  return (data ?? []) as MaliCycle[];
}

export async function openMaliCycle(supabase: SupabaseClient, input: MaliCycleInput): Promise<MaliCycle> {
  const { data, error } = await supabase
    .from("mali_cycle")
    .insert({
      group_id: input.group_id,
      name: input.name,
      saving_type: input.saving_type,
      state: input.state ?? 1,
      contribution: input.contribution,
      currency: input.currency ?? "XOF",
      frequency: input.frequency ?? "weekly",
      pot_target: input.pot_target ?? null,
      is_rotating: input.is_rotating ?? false,
      created_by: input.created_by,
    })
    .select()
    .single();
  if (error) throw new Error(error.message);
  return data as MaliCycle;
}

export async function listMaliContributions(supabase: SupabaseClient, cycleId?: string): Promise<MaliContribution[]> {
  let q = supabase.from("mali_contribution").select("*").order("paid_on", { ascending: false });
  if (cycleId) q = q.eq("cycle_id", cycleId);
  const { data, error } = await q;
  if (error) throw new Error(error.message);
  return (data ?? []) as MaliContribution[];
}

export async function recordMaliContribution(
  supabase: SupabaseClient,
  input: MaliContributionInput
): Promise<MaliContribution> {
  const { data, error } = await supabase
    .from("mali_contribution")
    .insert({
      cycle_id: input.cycle_id,
      member_id: input.member_id,
      amount: input.amount,
      currency: input.currency ?? "XOF",
      channel_id: input.channel_id ?? null,
      paid_on: input.paid_on ?? new Date().toISOString().slice(0, 10),
      ref_no: input.ref_no ?? null,
    })
    .select()
    .single();
  if (error) throw new Error(error.message);
  return data as MaliContribution;
}

export interface MaliRealtimeEvent {
  table: string;
  eventType: string;
  payload: Record<string, unknown> & { new?: Record<string, unknown> };
}

/** Real-time subscription over postgres_changes for the whole mali_* store. */
export function subscribeMaliStore(
  supabase: SupabaseClient,
  onEvent: (e: MaliRealtimeEvent) => void
): RealtimeChannel {
  const channel = supabase.channel("mali-store");
  for (const table of [
    "mali_union_group",
    "mali_union_member",
    "mali_cycle",
    "mali_contribution",
    "mali_payout",
    "mali_loan",
  ]) {
    channel.on(
      "postgres_changes",
      { event: "*", schema: "public", table },
      (payload) => onEvent({ table, eventType: payload.eventType, payload: payload as unknown as MaliRealtimeEvent["payload"] })
    );
  }
  return channel.subscribe() as RealtimeChannel;
}