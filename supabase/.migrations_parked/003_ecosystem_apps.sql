-- =============================================================================
-- 003 Ecosystem Apps Schema (apps catalog, downloads, payments, payouts, etc.)
-- NO DROP / NO TRUNCATE. IF NOT EXISTS only.
-- Requires: 001 + 002 applied (profiles, organizations, applications exist).
-- =============================================================================

-- App memberships
create table if not exists public.application_memberships (
  id uuid primary key default uuid_generate_v4(),
  application_id uuid references public.applications(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  role text check (role in ('owner','admin','member','reviewer')) default 'member',
  created_at timestamptz default now(),
  unique (application_id, profile_id)
);

-- Subscriptions
create table if not exists public.subscriptions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.profiles(id),
  application_id uuid references public.applications(id),
  plan_id text references public.billing_plans(id),
  status text check (status in ('active','canceled','past_due','trialing')) default 'trialing',
  current_period_start timestamptz,
  current_period_end timestamptz,
  mobile_money_provider text,       -- mpesa | airtel | mtn | coop | im
  external_ref text,
  enabled boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- STA audit trail (financial + data changes)
create table if not exists public.sta_audit_events (
  id uuid primary key default uuid_generate_v4(),
  application_id uuid references public.applications(id),
  actor_profile_id uuid references public.profiles(id),
  event_type text not null,          -- payment, subscription, profile_change, rls_change, deploy
  entity_type text,
  entity_id uuid,
  payload jsonb default '{}'::jsonb,
  ip inet,
  created_at timestamptz default now()
);

-- Apps / Products (the Africa-first App Store catalog)
create table if not exists public.apps (
  id uuid primary key default uuid_generate_v4(),
  creator_id uuid references public.profiles(id),
  application_id uuid references public.applications(id),
  title text not null,
  slug text unique not null,
  description text,
  short_description text,
  category text, -- gaming, finance, education, agri, etc.
  tags text[],
  is_african_made boolean default true,
  region_focus text[], -- ['KE','NG','ZA']
  size_mb numeric, -- for data cost
  is_html5 boolean default false,
  is_pwa boolean default true,
  offline_capable boolean default false,
  supports_mobile_money boolean default true,
  min_android_version text,
  status text default 'draft' check (status in ('draft','pending_review','approved','rejected','suspended')),
  revenue_share_pct numeric default 90, -- 10% platform cut
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- App versions / assets (selective downloads)
create table if not exists public.app_assets (
  id uuid primary key default uuid_generate_v4(),
  app_id uuid references public.apps(id) on delete cascade,
  version text not null,
  asset_type text, -- core, optional, language_pack, high_res
  storage_path text, -- supabase storage
  size_bytes bigint,
  checksum text,
  is_required boolean default false,
  created_at timestamptz default now()
);

-- Downloads & analytics
create table if not exists public.downloads (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.profiles(id),
  app_id uuid references public.apps(id),
  asset_id uuid references public.app_assets(id),
  data_cost_estimate_usd numeric,
  network_type text, -- 3g, 4g, wifi, offline
  country_code text,
  created_at timestamptz default now()
);

-- Payments / Ledger (Mobile Money first)
create table if not exists public.payments (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.profiles(id),
  app_id uuid references public.apps(id), -- null for subscription
  application_id uuid references public.applications(id),
  amount numeric not null,
  currency text default 'KES',
  provider text, -- mpesa, airtel_money, mtn_momo, paystack, coop, im, etc.
  provider_ref text,
  status text check (status in ('pending','success','failed','refunded')) default 'pending',
  purpose text, -- subscription, iap, tip, download, rent, fee
  fee_amount numeric default 0,     -- transaction fee (1-5 Ksh per Setup task 2)
  fee_currency text default 'KES',
  metadata jsonb,
  created_at timestamptz default now()
);

-- Creator payouts (10% platform)
create table if not exists public.payouts (
  id uuid primary key default uuid_generate_v4(),
  creator_id uuid references public.profiles(id),
  amount numeric,
  currency text,
  status text default 'pending',
  period_start date,
  period_end date,
  created_at timestamptz default now()
);

-- Reviews & Curation
create table if not exists public.reviews (
  id uuid primary key default uuid_generate_v4(),
  app_id uuid references public.apps(id),
  reviewer_id uuid references public.profiles(id),
  status text,
  notes text,
  reviewed_at timestamptz
);

-- Community / Trending events
create table if not exists public.events (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.profiles(id),
  app_id uuid references public.apps(id),
  event_type text, -- download, share_whatsapp, view, play, rate
  metadata jsonb,
  created_at timestamptz default now()
);

create index if not exists apps_status_idx on public.apps (status);
create index if not exists apps_category_idx on public.apps (category);
create index if not exists payments_user_idx on public.payments (user_id, created_at desc);
create index if not exists payments_status_idx on public.payments (status);
create index if not exists downloads_app_idx on public.downloads (app_id);
create index if not exists subscriptions_user_idx on public.subscriptions (user_id);
create index if not exists sta_audit_events_app_created_idx on public.sta_audit_events (application_id, created_at desc);