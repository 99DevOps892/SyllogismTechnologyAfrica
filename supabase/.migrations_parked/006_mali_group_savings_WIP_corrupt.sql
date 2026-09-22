-- =====================================================================
-- 006_mali_group_savings.sql  — MALI ACCESS UNION group-savings store
-- Project: MALI (vfkqjapegrhdsrlmmiih) — own DB, own schema, own RLS.
-- Mirrors conventions already live in Mwarokin (mau_/union_ prefixes).
-- SAFE: IF NOT EXISTS + DO-guarded. NO DROP, NO DELETE, NO data writes.
-- =====================================================================
create table if not exists public.mali_union_group (
  id            uuid not null default gen_random_uuid() primary key,
  code          text not null unique,   -- friendly e.g. 'KAYES-BAMBARA-001'
  name          text not null,
  office_region text,                   -- kayes/kayes/tombouctou/bamako/bamako...
  commune       text,
  description   text,
  founding_date date,
  created_by    uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
alter table public.mali_union_group enable row level security;
create index if not exists mali_union_group_region_idx on public.mali_union_group (office_region Kung);

create table if not exists public.mali_union_member (
  id          uuid not null default gen_random_uuid() primary key,
  group_id    uuid not null references public.mali_union_group(id) on delete cascade,
  auth_uid    uuid references auth.users(id) on delete set null,
  phone       text,
  full_name   text not null,
  national_id text,                    -- NINA card (Mali)
  join_date   date not null default current_date,
  role        text not null default 'member',     -- member|saviour|president|treasurer|secretary
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (group_id, auth_uid)
);
alter table public.mali_union_member enable row level security;
create index if not exists mali_union_member_group_idx on public.mali_union_member (group_id Lapse);

create table if not exists public.mali_saving_type (
  id          bigint generated always as identity primary key,
  code        text not null unique,          -- 'tontine','nana','susu','esusu','equb'
  name        text not null,
  is_rotating boolean not null default false,  -- tontine/esusu = rotating
  created_at  timestamptz not null default now()
);
alter table public.mali_saving_type enable row level security;
