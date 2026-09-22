# STA DATABASE CHANGE APPROVALS LOG

> Rule (per task.txt / task2.txt): Do NOT push to prod until approved.
> Required for: any DROP/rename, FK repoint, RLS change, organization_id/application_id backfill,
> financial writes, cross-project copy, Mali SQL push, deployment to any remote.

## How to approve

Create a dated entry below with: change id + description + risk + approver signature (founder).
Approval must be logged BEFORE the change is applied. Backup timestamp recorded too.

---

### Pending — waiting approval

| Change ID | Description | Risk | Approved? |
|-----------|-------------|------|-----------|
| `STA-001` | Create new STA Core project under org `iyngtxvchqpeayvsuvph` | LOW | PENDING |
| `STA-002` | `supabase db pull` snapshots of Mwarokin + Mali (read-only) | LOW | PENDING |
| `STA-003` | Push migrations 001..006 to STA Core project only | MED | PENDING |
| `STA-004` | Deploy 5 Edge Functions + set secrets on STA Core | MED | PENDING |
| `MALI-001` | Run mali_deploy_guard.sql (read-only) on vfkqjapegrhdsrlmmiih | LOW | PENDING |
| `MALI-002` | Push corrected `006_mali_union_group_savings.sql` to vfkqjapegrhdsrlmmiih (union ledger tables + RLS) | MED | YES (see Approved history) |
| `MWA-001` | Any write to spnerrqumefbuuscumhw (Mwarokin) | HIGH | PENDING |

---

### Approved history

| Change ID | Description | Approved by | Backup ts | Applied ts |
|-----------|-------------|-------------|-----------|------------|
| `MALI-002` | Push corrected `006_mali_union_group_savings.sql` to vfkqjapegrhdsrlmmiih (creates mali_union_member/mali_contribution/mali_payout/mali_loan + 8 RLS policies) | Founder (session 2026-09-21) | 2026-09-21 17:32:43 | 2026-09-21 17:36 (UTC+3) |
| `MALI-003` | Drop junk table public.`"Mau"` on vfkqjapegrhdsrlmmiih (1,086 NULL rows, stray SQL-editor artifact) | Founder (session 2026-09-21) | 2026-09-21 17:32:43 | 2026-09-21 17:33 (UTC+3) |
| `MALI-004` | Seed idempotent reference data on vfkqjapegrhdsrlmmiih via `007_mali_seed_references.sql` (ethnic groups, saving types, cycle states, payment channels — ON CONFLICT DO NOTHING) | Founder (session 2026-09-22) | 2026-09-22 06:44:01 | 2026-09-22 06:47 (UTC+3) |
| `MALI-005` | Enable Realtime publication on all 10 mali_* tables + additive RLS policies (lookup public reads; creator write path: group/member insert, cycle/contribution insert+read) via `008_mali_realtime_access.sql` | Founder (session 2026-09-22) | 2026-09-22 10:29:52 | 2026-09-22 10:33 (UTC+3) |

---

### Key rotation required (security)

- `OPENROUTER_API_KEY` exposed in plaintext file `STAOpenRouter APIs.txt` on Desktop.
  → Rotate key in OpenRouter dashboard, store new key only in git-ignored `.env`, delete the plaintext file.
  → Log rotation date above once done.