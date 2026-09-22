-- =============================================================================
-- 001 Extensions + Organizations/BankAccounts/Applications/BillingPlans
-- NO DROP / NO TRUNCATE. IF NOT EXISTS only.
-- Deploy order is strict: 001 -> 002 -> 003 -> 004 -> 005 -> 006
-- =============================================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pg_trgm";

-- -----------------------------------------------------------------------------
-- Organizations (top-level tenants)
-- -----------------------------------------------------------------------------
create table if not exists public.organizations (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  slug text unique not null,
  domain text,
  logo_url text,
  country_code text default 'KE',
  org_type text check (org_type in ('holding','academy','estates','union','eco_app','other')) default 'eco_app',
  status text check (status in ('active','suspended','archived')) default 'active',
  settings jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Co-operative / I&M bank account targets (business acct 01192643932500)
create table if not exists public.bank_accounts (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid references public.organizations(id) on delete cascade,
  bank_name text not null,
  account_name text not null,
  account_number text not null,
  branch_code text,
  swift_code text,
  is_primary boolean default false,
  is_sta_business boolean default false, -- true => STA treasury/business account
  status text check (status in ('active','inactive')) default 'active',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- -----------------------------------------------------------------------------
-- Applications (Mwarokin, Mali, SylloPay, SylloVibe, SAICOS, Noesis, ...)
-- -----------------------------------------------------------------------------
create table if not exists public.applications (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid references public.organizations(id) on delete cascade,
  name text not null,
  slug text unique not null,
  description text,
  project_ref text unique,          -- supabase project ref, e.g. vfkqjapegrhdsrlmmiih
  domain text,
  app_type text check (app_type in ('web','pwa','mobile','tv','wearable','automotive','tablet')) default 'web',
  status text check (status in ('active','beta','archived')) default 'active',
  config jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- -----------------------------------------------------------------------------
-- Billing plans (all eco apps)
-- -----------------------------------------------------------------------------
create table if not exists public.billing_plans (
  id text primary key,
  application_id uuid references public.applications(id) on delete cascade,
  name text not null,
  price_kes numeric default 0,
  price_usd numeric default 0,
  interval text check (interval in ('once','monthly','yearly')) default 'monthly',
  features jsonb default '{}'::jsonb,
  currency text default 'KES',
  created_at timestamptz default now()
);

create index if not exists bank_accounts_org_idx on public.bank_accounts (organization_id);
create index if not exists applications_org_idx on public.applications (organization_id);