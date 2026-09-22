-- =============================================================================
-- 005 RLS Policies (expand per table; verified against remote before prod push)
-- Principle: no DROP. Policies are created via guarded DO blocks (idempotent).
-- =============================================================================

alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.applications enable row level security;
alter table public.apps enable row level security;
alter table public.app_assets enable row level security;
alter table public.payments enable row level security;
alter table public.subscriptions enable row level security;
alter table public.payouts enable row level security;
alter table public.downloads enable row level security;
alter table public.reviews enable row level security;
alter table public.consents enable row level security;
alter table public.agent_tasks enable row level security;
alter table public.bank_accounts enable row level security;
alter table public.application_memberships enable row level security;
alter table public.organization_members enable row level security;
alter table public.sta_audit_events enable row level security;

-- Idempotent policy creator: skips creating a policy when it already exists.
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='profiles_select_own') then
    create policy "profiles_select_own" on public.profiles
      for select using (auth.uid() = id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='profiles' and policyname='profiles_update_own') then
    create policy "profiles_update_own" on public.profiles
      for update using (auth.uid() = id) with check (auth.uid() = id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='apps' and policyname='apps_read_approved') then
    create policy "apps_read_approved" on public.apps
      for select using (status = 'approved' or auth.uid() = creator_id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='apps' and policyname='apps_write_creator') then
    create policy "apps_write_creator" on public.apps
      for insert with check (auth.uid() = creator_id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='payments' and policyname='payments_select_own') then
    create policy "payments_select_own" on public.payments
      for select using (auth.uid() = user_id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='consents' and policyname='consents_select_own') then
    create policy "consents_select_own" on public.consents
      for select using (auth.uid() = user_id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='consents' and policyname='consents_update_own') then
    create policy "consents_update_own" on public.consents
      for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='agent_tasks' and policyname='agent_tasks_admin_only') then
    create policy "agent_tasks_admin_only" on public.agent_tasks
      for all using (
        auth.role() = 'service_role'
        or coalesce(auth.jwt()->>'role','') in ('admin','service_role')
      )
      with check (
        auth.role() = 'service_role'
        or coalesce(auth.jwt()->>'role','') in ('admin','service_role')
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='organizations' and policyname='orgs_select_member') then
    create policy "orgs_select_member" on public.organizations
      for select using (exists (
        select 1 from public.organization_members m
        where m.organization_id = organizations.id
          and m.profile_id = auth.uid()
      ));
  end if;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='applications' and policyname='apps_select_public') then
    create policy "apps_select_public" on public.applications
      for select using (true);
  end if;
end $$;

-- Storage object policies (guard against re-run too)
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='assets_read_owner') then
    create policy "assets_read_owner" on storage.objects
      for select using (
        bucket_id = 'assets'
        and auth.role() = 'authenticated'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;

  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='apps_public_read') then
    create policy "apps_public_read" on storage.objects
      for select using (bucket_id = 'apps');
  end if;

  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='avatars_public_read') then
    create policy "avatars_public_read" on storage.objects
      for select using (bucket_id = 'avatars');
  end if;

  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='assets_insert_owner') then
    create policy "assets_insert_owner" on storage.objects
      for insert with check (
        bucket_id = 'assets'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;
end $$;