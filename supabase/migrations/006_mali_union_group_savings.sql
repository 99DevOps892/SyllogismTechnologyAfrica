-- =====================================================================
-- 006_mali_union_group_savings.sql — MALI ACCESS UNION · group-savings store
-- Project MALI (vfkqjapegrhdsrlmmiih) — own DB, own schema, own RLS.
-- Conventions mirror live Mwarokin (mali_/union_ prefixes, identity PKs, RLS on).
-- IDEMPOTENT + SAFE: every object IF NOT EXISTS / no DROP / no DELETE / no data writes.
-- Apply target: public schema on MALI. Order: after STA Core 001..005.
--
-- CORRECTED (2026-09-21, applied under MALI-002/MALI-003 approval):
--   * line: index mali_contribution_cycle_idx now uses explicit (cycle_id);
--     the parked draft referenced a non-existent column 'cycle_idelan'.
--   * RLS policies are wrapped in DO-guarded blocks so re-runs cannot collide.
--   * mali_union_group / mali_cycle shapes below are IF-NOT-EXISTS no-ops
--     against the live 006 store (different approved shape already live).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. LOOKUPS (code-first, idempotent)
-- ---------------------------------------------------------------------
create table if not exists public.mali_ethnic_group (
  id         bigint generated always as identity primary key,
  code       text not null unique,        -- 'bambara','mandinka','fula','soninke','tuareg','dogon'
  name       text not null,
  region     text,                        -- kayes/koulikoro/sikasso/segou/mopti/tombouctou/gao/kidal/bamako
  created_at timestamptz not null default now()
);
alter table public.mali_ethnic_group enable row level security;

create table if not exists public.mali_saving_type (
  id          bigint generated always as identity primary key,
  code        text not null unique,       -- 'tontine','nana','susu','esusu','equb'
  name        text not null,
  is_rotating boolean not null default false,  -- tontine/esusu = rotating pot
  created_at  timestamptz not null default now()
);
alter table public.mali_saving_type enable row level security;

create table if not exists public.mali_cycle_state (
  id     smallint generated always as identity primary key,
  code   text not null unique,            -- 'forming','collecting','rotating','closed','failed'
  label  text not null
);
alter table public.mali_cycle_state enable row level security;

create table if not exists public.mali_payment_channel (
  id              bigint generated always as identity primary key,
  code            text not null unique,   -- 'orange_money','mtn_money','moov_money','airtel','bank','cash'
  name            text not null,
  settlement_days smallint not null default 1,
  created_at      timestamptz not null default now()
);
alter table public.mali_payment_channel enable row level security;

-- ---------------------------------------------------------------------
-- 2. UNION GROUPS (a saving circle / chapter)
-- ---------------------------------------------------------------------
create table if not exists public.mali_union_group (
  id            uuid not null default gen_random_uuid() primary key,
  code          text not null unique,        -- 'KAYES-BAMBARA-001'
  name          text not null,
  office_region text,                        -- kayes/koulikoro/sikasso/segou/mopti/tombouctou/gao/kidal/bamako
  commune       text,
  description   text,
  founding_date date,
  created_by    uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
alter table public.mali_union_group enable row level security;
-- NOTE: office_region index intentionally omitted — live 006 mali_union_group shape
-- has no office_region column yet (additive ALTER can add it later if required).

create table if not exists public.mali_union_member (
  id          uuid not null default gen_random_uuid() primary key,
  group_id    uuid not null references public.mali_union_group(id) on delete cascade,
  auth_uid    uuid references auth.users(id) on delete set null,
  phone       text,
  full_name   text not null,
  national_id text,                       -- NINA (Mali) / eKYC optional
  join_date   date not null default current_date,
  role        text not null default 'member',  -- member|president|treasurer|secretary
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (group_id, auth_uid)
);
alter table public.mali_union_member enable row level security;
create index if not exists mali_union_member_group_idx on public.mali_union_member (group_id);

-- ---------------------------------------------------------------------
-- 3. CYCLES (a savings round — fixing or rotating)
-- ---------------------------------------------------------------------
create table if not exists public.mali_cycle (
  id            uuid not null default gen_random_uuid() primary key,
  group_id      uuid not null references public.mali_union_group(id) on delete cascade,
  saving_type_id bigint not null references public.mali_saving_type(id) on delete restrict,
  state_id      smallint not null default 1 references public.mali_cycle_state(id),
  name          text not null,
  contribution  numeric(12,2) not null check (contribution > 0),
  currency      text not null default 'XOF',
  frequency     text not null default 'weekly',   -- daily|weekly|biweekly|monthly
  start_date    date,
  end_date      date,
  payout_rule   text not null default 'rotating', -- rotating|ballot|priority|pothole
  pot_target    numeric(14,2),
  created_by    uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
alter table public.mali_cycle enable row level security;
create index if not exists mali_cycle_group_idx on public.mali_cycle (group_id);

-- ---------------------------------------------------------------------
-- 4. CONTRIBUTIONS (cash-in ledger per cycle per member)
-- ---------------------------------------------------------------------
create table if not exists public.mali_contribution (
  id          uuid not null default gen_random_uuid() primary key,
  cycle_id    uuid not null references public.mali_cycle(id) on delete cascade,
  member_id   uuid not null references public.mali_union_member(id) on delete cascade,
  amount      numeric(12,2) not null check (amount > 0),
  currency    text not null default 'XOF',
  channel_id  bigint references public.mali_payment_channel(id) on delete set null,
  paid_on     date not null default current_date,
  ref_no      text,                        -- mobile-money peer id / receipt
  verified_by uuid references auth.users(id) on delete set null,
  verified_at timestamptz,
  created_at  timestamptz not null default now(),
  unique (cycle_id, member_id, paid_on)
);
alter table public.mali_contribution enable row level security;
create index if not exists mali_contribution_cycle_idx on public.mali_contribution (cycle_id);
create index if not exists mali_contribution_member_idx on public.mali_contribution (member_id, paid_on);

-- ---------------------------------------------------------------------
-- 5. PAYOUTS (who received the pot, and when)
-- ---------------------------------------------------------------------
create table if not exists public.mali_payout (
  id          uuid not null default gen_random_uuid() primary key,
  cycle_id    uuid not null references public.mali_cycle(id) on delete cascade,
  member_id   uuid not null references public.mali_union_member(id) on delete cascade,
  turn_no     smallint,                    -- position in rotation (1..n)
  amount      numeric(12,2) not null check (amount >= 0),
  currency    text not null default 'XOF',
  paid_through text not null default 'mobile_money',  -- mobile_money|bank|cash
  paid_on     date not null default current_date,
  ref_no      text,
  confirmed   boolean not null default false,
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  unique (cycle_id, member_id, turn_no)
);
alter table public.mali_payout enable row level security;
create index if not exists mali_payout_cycle_idx on public.mali_payout (cycle_id, turn_no);

-- ---------------------------------------------------------------------
-- 6. LOANS (solidarity/low-cost lending out of the group float)
-- ---------------------------------------------------------------------
create table if not exists public.mali_loan (
  id          uuid not null default gen_random_uuid() primary key,
  group_id    uuid not null references public.mali_union_group(id) on delete cascade,
  member_id   uuid not null references public.mali_union_member(id) on delete cascade,
  principal   numeric(12,2) not null check (principal > 0),
  currency    text not null default 'XOF',
  interest_rate numeric(4,2) not null default 0 check (interest_rate >= 0),
  term_months smallint not null default 3 check (term_months between 1 and 24),
  purpose     text,
  issued_on   date not null default current_date,
  due_on      date,
  state       text not null default 'active',  -- active|repaid|defaulted|written_off
  approved_by uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now()
);
alter table public.mali_loan enable row level security;
create index if not exists mali_loan_group_idx on public.mali_loan (group_id, state);

-- ---------------------------------------------------------------------
-- 7. RLS POLICIES — members only, group-scoped (mirrors Mwarokin union_*)
--    Idempotent: each policy created only when absent (no DROP / no collision).
-- ---------------------------------------------------------------------
do $do$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_union_member' and policyname='mali_member_group_read_own') then
    execute $pol$ create policy "mali_member_group_read_own"
      on public.mali_union_member for select
      to authenticated
      using (group_id in (
        select mg.id from public.mali_union_group mg
        join public.mali_union_member mm on mm.group_id = mg.id
        where mm.auth_uid = auth.uid()
      )) $pol$;
  end if;
end;
$do$;

do $do$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_union_group' and policyname='mali_group_read_on_membership') then
    execute $pol$ create policy "mali_group_read_on_membership"
      on public.mali_union_group for select
      to authenticated
      using (
        exists (select 1 from public.mali_union_member mm
                where mm.group_id = id and mm.auth_uid = auth.uid())
        or (select auth.uid()) = created_by
      ) $pol$;
  end if;
end;
$do$;

do $do$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_cycle' and policyname='mali_cycle_insert_member') then
    execute $pol$ create policy "mali_cycle_insert_member"
      on public.mali_cycle for insert
      to authenticated
      with check (
        exists (select 1 from public.mali_union_member mm
                where mm.group_id = group_id and mm.auth_uid = auth.uid())
      ) $pol$;
  end if;
end;
$do$;

do $do$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_cycle' and policyname='mali_cycle_read_member') then
    execute $pol$ create policy "mali_cycle_read_member"
      on public.mali_cycle for select
      to authenticated
      using (exists (
        select 1 from public.mali_union_member mm
        where mm.group_id = group_id and mm.auth_uid = auth.uid()
      )) $pol$;
  end if;
end;
$do$;

do $do$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_contribution' and policyname='mali_contribution_insert_member') then
    execute $pol$ create policy "mali_contribution_insert_member"
      on public.mali_contribution for insert
      to authenticated
      with check (
        exists (select 1 from public.mali_union_member mm
                where mm.id = member_id and mm.auth_uid = auth.uid())
      ) $pol$;
  end if;
end;
$do$;

do $do$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_contribution' and policyname='mali_contribution_read_member') then
    execute $pol$ create policy "mali_contribution_read_member"
      on public.mali_contribution for select
      to authenticated
      using (exists (
        select 1 from public.mali_union_member mm
        where mm.id = member_id and mm.auth_uid = auth.uid()
      )) $pol$;
  end if;
end;
$do$;

do $do$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_payout' and policyname='mali_payout_read_member') then
    execute $pol$ create policy "mali_payout_read_member"
      on public.mali_payout for select
      to authenticated
      using (exists (
        select 1 from public.mali_cycle c
        join public.mali_union_member mm on mm.group_id = c.group_id
        where c.id = cycle_id and mm.auth_uid = auth.uid()
      )) $pol$;
  end if;
end;
$do$;

do $do$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='mali_loan' and policyname='mali_loan_read_member') then
    execute $pol$ create policy "mali_loan_read_member"
      on public.mali_loan for select
      to authenticated
      using (exists (
        select 1 from public.mali_union_group mg
        join public.mali_union_member mm on mm.group_id = mg.id
        where mg.id = group_id and mm.auth_uid = auth.uid()
      )) $pol$;
  end if;
end;
$do$;

-- =====================================================================
-- SANITY (idempotent, read-only)
-- =====================================================================
select '006_mali_union_group_savings OK' as migration;