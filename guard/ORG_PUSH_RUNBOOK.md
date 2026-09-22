# ORG PUSH RUNBOOK — SyllogismTechnologyAfrica

Deploy order is STRICT. Each project gets ONLY its own payload — never mix apps.
Applies the outcomes documented in `task.txt` / `task2.txt` (the "2nd Agentic Brain" audits).

## Project map (source of truth)

| Project | Ref | What belongs there |
|---------|-----|--------------------|
| Mwarokin | `spnerrqumefbuuscumhw` | Mwarokin Estates only (9 tables). READ, never write for now. |
| Mali | `vfkqjapegrhdsrlmmiih` | Mali Access Union only (31 tables). Guard-gated. |
| STA Core (NEW) | `<NEW_STA_CORE_REF>` | 001..006 + shared platform + ecosystem. Create first. |

## Step 0 — Backup everything first (mandatory)

```powershell
powershell -File scripts/backup-schemas.ps1
```
Wait: both Mwarokin and Mali were found PAUSED (deploys blocked). Unpause each in
the Supabase dashboard (Settings -> General -> Restore) before running.

Manual equivalent:
```powershell
supabase login
supabase link --project-ref spnerrqumefbuuscumhw
supabase db pull                    # -> dumps remote Mwarokin schema locally
supabase link --project-ref vfkqjapegrhdsrlmmiih
supabase db pull                    # -> dumps remote Mali schema locally
```
Keep these pulls as read-only snapshots. No writes happen in this step.

## Step 1 — Create the STA Core project

In Supabase Dashboard -> org **iyngtxvchqpeayvsuvph** -> New Project. Copy the new ref into `.env` (SUPABASE_PROJECT_REF / SUPABASE_URL).

## Step 2 — Push STA Core migrations (only to STA Core)

```powershell
supabase link --project-ref <NEW_STA_CORE_REF>
supabase db push
```
The migrations directory contains only STA Core / shared / ecosystem schema in deploy order:
`001_sta_core.sql` -> `002_shared_platform.sql` -> `003_ecosystem_apps.sql` -> `004_storage_buckets.sql` -> `005_rls_policies.sql`

Do NOT push these to `spnerrqumefbuuscumhw` or `vfkqjapegrhdsrlmmiih`.

## Step 3 — Log approval before proceeding further

Append a dated, signed entry to `docs/APPROVALS_LOG.md`. No further prod pushes until approved.

## Step 4 — Mali push (guard-gated)

```powershell
supabase link --project-ref vfkqjapegrhdsrlmmiih
supabase db push --file guard/mali_deploy_guard.sql   # read-only, all checks must be true
# only after guard passes:
supabase db push --file <mali_access_union_schema>.sql
```
Originals are never moved/deleted. Mali is the ONLY project that gets Mali SQL.

## Step 5 — Edge Functions

```powershell
supabase functions deploy mobile-money-pay
supabase functions deploy mobile-money-webhook
supabase functions deploy estimate-data-cost
supabase functions deploy review-triage
supabase functions deploy payout-calculator
supabase secrets set MOBILE_MONEY_API_URL MOBILE_MONEY_API_KEY MOBILE_MONEY_WEBHOOK_SECRET OPENROUTER_API_KEY
```

## Step 6 — Frontend

See `apps/web/README.md`. `npm install` then `npm run dev`.

## NEVER

- Push `Schema.db`, `*.ps1/*.psm1`, or ecosystem docs into Mali (`vfkq...`).
- Drop/truncate any table without a signed approval in `docs/APPROVALS_LOG.md`.
- Commit `.env`, `SECRETS/`, or any API key.