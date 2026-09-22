-- =============================================================================
-- 002 Shared Platform: profiles + org members + notifications + i18n + consents
-- NO DROP / NO TRUNCATE. IF NOT EXISTS only.
-- Requires: 001 (organizations) already applied.
-- =============================================================================

-- Profiles (extends auth.users) - global identity; role is property-scoped
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  full_name text,
  avatar_url text,
  country_code text,               -- KE, NG, ZA, GH, EG...
  preferred_language text default 'en',
  roles text[] default '{user}',   -- user, creator, studio, admin, reviewer, landlord, caretaker, agent
  mobile_money_phone text,
  email_verified boolean default false,
  phone_verified boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Organization membership (who belongs to which org / app)
create table if not exists public.organization_members (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid references public.organizations(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  role text check (role in ('owner','admin','member')) default 'member',
  created_at timestamptz default now(),
  unique (organization_id, profile_id)
);

-- Notifications (group-scoped per app)
create table if not exists public.notifications (
  id uuid primary key default uuid_generate_v4(),
  application_id uuid references public.applications(id),
  user_id uuid references public.profiles(id),
  title text not null,
  body text,
  channel text check (channel in ('in_app','whatsapp','email','push')) default 'in_app',
  payload jsonb default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz default now()
);

-- i18n: languages, translations, currencies, exchange rates
create table if not exists public.supported_languages (
  code text primary key,
  name text not null,
  enabled boolean default true
);

create table if not exists public.translations (
  id uuid primary key default uuid_generate_v4(),
  language_code text references public.supported_languages(code),
  namespace text default 'common',
  key text not null,
  value text not null,
  created_at timestamptz default now(),
  unique (language_code, namespace, key)
);

create table if not exists public.supported_currencies (
  code text primary key,
  name text not null,
  symbol text,
  enabled boolean default true
);

create table if not exists public.exchange_rates (
  id uuid primary key default uuid_generate_v4(),
  base_code text not null,
  quote_code text not null,
  rate numeric not null,
  updated_at timestamptz default now(),
  unique (base_code, quote_code)
);

-- Consent & Privacy (Kenya DPA / POPIA / GDPR)
create table if not exists public.consents (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.profiles(id),
  purpose text,                    -- analytics, marketing, personalization
  granted boolean,
  version text,
  created_at timestamptz default now(),
  unique (user_id, purpose)
);

-- Agentic task ledger (the "2nd Agentic Brain" execution tracker)
create table if not exists public.agent_tasks (
  id uuid primary key default uuid_generate_v4(),
  agent_name text default 'opencode',
  task_key text unique not null,             -- e.g. TASK_01
  title text not null,
  feature text,                              -- matrix feature name
  status text check (status in ('queued','in_progress','blocked','done','failed')) default 'queued',
  assigned_to text,                          -- opencode | openclaw | saicos | noesis | human
  priority text check (priority in ('P0','P1','P2')) default 'P1',
  milestone uuid,
  notes text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists agent_tasks_status_idx on public.agent_tasks (status);
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);
create index if not exists organization_members_org_idx on public.organization_members (organization_id);