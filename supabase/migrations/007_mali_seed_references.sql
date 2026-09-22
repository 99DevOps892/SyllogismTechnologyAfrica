-- =====================================================================
-- 007_mali_seed_references.sql — MALI ACCESS UNION · reference-data seed
-- Project MALI (vfkqjapegrhdsrlmmiih) — public schema lookups.
-- SAFE: INSERT ... ON CONFLICT (code) DO NOTHING — idempotent, re-runnable,
-- no UPDATE, no DELETE, no DDL. Approved under MALI-004 (2026-09-21).
-- =====================================================================

insert into public.mali_ethnic_group (code, name, region)
values
  ('bambara','Bambara','segou'),
  ('mandinka','Mandinka','koulikoro'),
  ('fula','Fula','mopti'),
  ('soninke','Soninke','kayes'),
  ('tuareg','Tuareg','gao'),
  ('dogon','Dogon','mopti')
on conflict (code) do nothing;

insert into public.mali_saving_type (code, name, is_rotating)
values
  ('tontine','Tontine / susu circle', true),
  ('nana','Nana (fixed-cycle)', false),
  ('susu','Susu (fixed-cycle)', false),
  ('esusu','Esusu (rotating pot)', true),
  ('equb','Equb (rotating pot)', false)
on conflict (code) do nothing;

insert into public.mali_cycle_state (code, label)
values
  ('forming','Forming / recruiting members'),
  ('collecting','Collecting contributions'),
  ('rotating','Rotating pot payouts'),
  ('closed','Closed / completed'),
  ('failed','Failed / dissolved')
on conflict (code) do nothing;

insert into public.mali_payment_channel (code, name, settlement_days)
values
  ('orange_money','Orange Money', 1),
  ('mtn_money','MTN MoMo', 1),
  ('moov_money','Moov Money', 1),
  ('airtel','Airtel Money', 1),
  ('bank','Bank transfer', 3),
  ('cash','Cash in hand', 0)
on conflict (code) do nothing;

select '007_mali_seed_references OK' as seed;