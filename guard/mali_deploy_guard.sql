-- =============================================================================
-- mali_deploy_guard.sql (READ-ONLY — 3 checks)
-- Run BEFORE pushing anything to Mali project (vfkqjapegrhdsrlmmiih).
-- Every check returns a boolean; a FALSE means STOP and fix before deploy.
-- =============================================================================

-- CHECK 1: prerequisite shared/STA tables exist (Mali FKs dangle otherwise)
select
  'check_1_dependencies' as check_name,
  not exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname in ('organizations','bank_accounts','profiles')
    group by n.nspname
    having count(*) < 3
  ) as passed;

-- CHECK 2: non-MAU contamination present? (Mwarokin tables must NOT be here)
select
  'check_2_no_contamination' as check_name,
  (
    select count(*) = 0
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in ('properties','tenants','leases','maintenance_requests','property_views')  -- Mwarokin-only names
  ) as passed;

-- CHECK 3: Finance-state sanity (no payouts committed without a ref number)
-- Mali schema: mali_payout is a cycle-based payout schedule with ref_no + confirmed.
-- Self-skips when the table is absent (pure pre-finance scaffolding) - returns true.
select
  'check_3_finance_sanity' as check_name,
  (
    case
      when exists (
        select 1 from pg_catalog.pg_class c
        join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'mali_payout'
      ) then
        (select count(*) = 0 from public.mali_payout p
          where p.confirmed and coalesce(p.ref_no, '') = '')
      else true
    end
  ) as passed;

-- Expected: all three checks return true before any push to vfkqjapegrhdsrlmmiih.