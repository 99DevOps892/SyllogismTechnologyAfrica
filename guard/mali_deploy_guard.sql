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

-- CHECK 3: Finance-state sanity (no payments without a valid provider_ref)
select
  'check_3_finance_sanity' as check_name,
  (
    select count(*) = 0
    from public.payments p
    where p.status = 'success' and p.provider_ref is null
  ) as passed;

-- Expected: all three checks return true before any push to vfkqjapegrhdsrlmmiih.