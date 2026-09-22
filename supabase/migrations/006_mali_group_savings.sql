-- =====================================================================
-- 006_mali_group_savings.sql — MALI ACCESS UNION · group-savings store
-- Project: MALI (vfkqjapegrhdsrlmmiih) — own DB, own schema, no shared writes.
-- Mirrors the live conventions already in Mwarokin (mau_/union_/mali_ prefixes).
-- SAFE: IF NOT EXISTS everywhere, NO DROP, NO DELETE, RLS on, idempotent.
-- APPLY ORDER: after 001..005 (STA Core) on THIS project.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. LOOKUPS
-- ---------------------------------------------------------------------
create table if not exists public.mali_ethnic_group (
  id          bigint generated always as identity primary key,
  code        text not null unique,          -- 'bambara','mandinka','fula','soninke','tuareg','dogon'
  name        text not null,
  region      text,                          -- kayes/koulikoro/sikasso/segou/mopti/tombouctou/gao/kidal/bamako
  created_at  timestamptz not null default now()
);
alter table public.mali_ethnic_group enable row level security;

create table if not exists public.mali_saving_type (
  id          bigint generated always as identity primary key,
  code        text not null unique,          -- 'tontine','nana','susu','esusu','equb'
  name        text not null,
  is_rotating boolean not null default false, -- tontine/esusu = rotating pot
  created_at  timestamptz not null default now()
);
alter table public.mali_saving_type enable row level security;

create table if not exists public.mali_cycle_state (
  id     smallint generated always as identity primary key,
  code   text not null unique,               -- 'forming','collecting','rotating','closed','failed'
  label  text not null
);
alter table public.mali_cycle_state enable row level security;

create table if not exists public.mali_payment_channel (
  id          bigint generated always as identity primary key,
  code        text not null unique,          -- 'orange_money','mtn_money','moov_money','airtel','bank','cash'
  name        text not null,
  settlement_days smallint not null default 1,
  created_at  timestamptz not null default now()
);
alter table public.mali_payment_channel enable row level security;


-- ---------------------------------------------------------------------
-- 3b. UNION GROUPS (the parent of cycles/members/contributions/payouts)
--     added to fix the 42P01: mali_cycle declares an FK to it, but 006
--     never created it. Purely additive: IF NOT EXISTS, RLS on, no DROP.
-- ---------------------------------------------------------------------
create table if not exists public.mali_union_group (
  id          uuid         not null default gen_random_uuid() primary key,
  name        text         not null,
  currency    text         not null default 'XOF',
  description text,
  is_active   boolean      not null default true,
  created_by  uuid         references auth.users(id) on delete set null,
  created_at  timestamptz  not null default now(),
  updated_at  timestamptz  not null default now(),
  unique (name)
);
alter table public.mali_union_group enable row level security collate "C";

-- ---------------------------------------------------------------------
-- 4. CYCLES  (one saving round: forming -> collecting -> rotating -> closed)
-- ---------------------------------------------------------------------
create table if not exists public.mali_cycle (
  id            uuid not null default gen_random_uuid() primary key,
  group_id      uuid not null references public.mali_union_group(id) on delete cascade,
  saving_type   bigint not null references public.mali_saving_type(id),
  state         smallint not null default 1 references public.mali_cycle_state(id),
  name          text not null,
  contribution  numeric(12,2) not null check (contribution > 0),
  currency      text not null default 'XOF',
  frequency     text not null default 'weekly',
  start_date    date,
  end_date      date,
  frequence     text not null default 'weekly',
  pot_target    numeric(14,2),
  is_rotating   boolean not null default false,
  created_by    uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (group_id, name)
);
alter table public.mali_cycle enable row level security;
create index if not exists mali_cycle_group_idx on public.mali_cycle (group_id);
