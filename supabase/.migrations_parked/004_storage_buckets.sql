-- =============================================================================
-- 004 Storage Buckets (apps, avatars, assets) + object-level access
-- NO DROP. IF NOT EXISTS semantics via WHERE NOT EXISTS.
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit)
select 'apps', 'apps', true, 524288000  -- 500 MB
where not exists (select 1 from storage.buckets where id = 'apps');

insert into storage.buckets (id, name, public, file_size_limit)
select 'avatars', 'avatars', true, 5242880  -- 5 MB
where not exists (select 1 from storage.buckets where id = 'avatars');

insert into storage.buckets (id, name, public, file_size_limit)
select 'assets', 'assets', false, 524288000  -- 500 MB, private selective downloads
where not exists (select 1 from storage.buckets where id = 'assets');

-- app_assets must keep a storage path per asset (referenced at runtime)
-- Assets bucket is private: fine-grained RLS below (owner/creator + admin only).