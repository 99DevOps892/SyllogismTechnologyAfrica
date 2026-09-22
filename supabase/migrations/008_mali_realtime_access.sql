-- =====================================================================
-- 008_mali_realtime_access.sql — MALI ACCESS UNION · realtime + creator write path
-- Project MALI (vfkqjapegrhdsrlmmiih) — public schema.
-- SAFE: idempotent DO-guards, no DROP/DELETE/UPDATE, additive policies only.
-- Purpose:
--   1) publish the 10 mali_* tables on supabase_realtime (postgres_changes)
--   2) open the first authenticated write path:
--        create group -> add member -> open cycle -> record contribution
--      (group creator + members only; anon reads ONLY the 4 lookup tables)
-- Approved under MALI-005 (backup ts logged in docs/APPROVALS_LOG.md).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. LOOKUP READ POLICIES (reference data only: anonymous + authenticated)
-- ---------------------------------------------------------------------
do $do$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_ethnic_group' and policyname='mali_lookup_read_public') then
    execute $pol$ create policy "mali_lookup_read_public" on public.mali_ethnic_group for select to anon, authenticated using (true) $pol$;
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_saving_type' and policyname='mali_lookup_read_public') then
    execute $pol$ create policy "mali_lookup_read_public" on public.mali_saving_type for select to anon, authenticated using (true) $pol$;
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_cycle_state' and policyname='mali_lookup_read_public') then
    execute $pol$ create policy "mali_lookup_read_public" on public.mali_cycle_state for select to anon, authenticated using (true) $pol$;
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_payment_channel' and policyname='mali_lookup_read_public') then
    execute $pol$ create policy "mali_lookup_read_public" on public.mali_payment_channel for select to anon, authenticated using (true) $pol$;
  end if;
end;
$do$;

-- ---------------------------------------------------------------------
-- 2. CREATOR WRITE PATH (authenticated group creator + their members)
-- ---------------------------------------------------------------------
do $do$
begin
  -- creator can create a group (created_by must equal auth.uid())
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_union_group' and policyname='mali_group_insert_creator') then
    execute $pol$ create policy "mali_group_insert_creator"
      on public.mali_union_group for insert
      to authenticated
      with check ((select auth.uid()) = created_by) $pol$;
  end if;

  -- creator can add members to their own group (or a user can add themselves)
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_union_member' and policyname='mali_member_insert_group_creator') then
    execute $pol$ create policy "mali_member_insert_group_creator"
      on public.mali_union_member for insert
      to authenticated
      with check (
        group_id in (select mg.id from public.mali_union_group mg where mg.created_by = (select auth.uid()))
        or (select auth.uid()) = auth_uid
      ) $pol$;
  end if;

  -- creator can read the roster of groups they created
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_union_member' and policyname='mali_member_read_group_creator') then
    execute $pol$ create policy "mali_member_read_group_creator"
      on public.mali_union_member for select
      to authenticated
      using (
        group_id in (select mg.id from public.mali_union_group mg where mg.created_by = (select auth.uid()))
        or (select auth.uid()) = auth_uid
      ) $pol$;
  end if;

  -- creator can open a cycle in their own group
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_cycle' and policyname='mali_cycle_insert_group_creator') then
    execute $pol$ create policy "mali_cycle_insert_group_creator"
      on public.mali_cycle for insert
      to authenticated
      with check (group_id in (select mg.id from public.mali_union_group mg where mg.created_by = (select auth.uid()))) $pol$;
  end if;

  -- creator can read cycles of groups they created
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_cycle' and policyname='mali_cycle_read_group_creator') then
    execute $pol$ create policy "mali_cycle_read_group_creator"
      on public.mali_cycle for select
      to authenticated
      using (group_id in (select mg.id from public.mali_union_group mg where mg.created_by = (select auth.uid()))) $pol$;
  end if;

  -- creator can record contributions for their own groups' cycles (plus existing member policy)
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_contribution' and policyname='mali_contribution_insert_group_creator') then
    execute $pol$ create policy "mali_contribution_insert_group_creator"
      on public.mali_contribution for insert
      to authenticated
      with check (
        cycle_id in (
          select c.id from public.mali_cycle c
          join public.mali_union_group mg on mg.id = c.group_id
          where mg.created_by = (select auth.uid())
        )
      ) $pol$;
  end if;

  -- creator can read contributions for their own groups' cycles
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_contribution' and policyname='mali_contribution_read_group_creator') then
    execute $pol$ create policy "mali_contribution_read_group_creator"
      on public.mali_contribution for select
      to authenticated
      using (
        cycle_id in (
          select c.id from public.mali_cycle c
          join public.mali_union_group mg on mg.id = c.group_id
          where mg.created_by = (select auth.uid())
        )
        or (select auth.uid()) = (select mm.auth_uid from public.mali_union_member mm where mm.id = member_id)
      ) $pol$;
  end if;
end;
$do$;

-- ---------------------------------------------------------------------
-- 3. REALTIME PUBLICATION (postgres_changes for all 10 mali_* tables)
-- ---------------------------------------------------------------------
do $do$
declare t text;
begin
  foreach t in array array['mali_ethnic_group','mali_saving_type','mali_cycle_state','mali_payment_channel',
                           'mali_union_group','mali_union_member','mali_cycle','mali_contribution','mali_payout','mali_loan']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end;
$do$;

-- replica identity full so realtime carries full old/new rows (safe, additive)
do $do$
declare t text;
begin
  foreach t in array array['mali_ethnic_group','mali_saving_type','mali_cycle_state','mali_payment_channel',
                           'mali_union_group','mali_union_member','mali_cycle','mali_contribution','mali_payout','mali_loan']
  loop
    execute format('alter table public.%I replica identity full', t);
  end loop;
end;
$do$;

-- =====================================================================
-- SANITY (idempotent, read-only)
-- =====================================================================
select '008_mali_realtime_access OK' as migration;