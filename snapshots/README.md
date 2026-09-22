# Schema Baseline — read-only snapshot (frozen 2026-09-19)

Mode: MANAGEMENT API, read-only, NO credentials, NO Docker, NO writes. Safe backup baseline.

| Artifact | Bytes | Purpose |
|---|---|---|
| snapshots/mali_schema.json | 1,356 | MALI project (vfkqjapegrhdsrlmmiih) public schema. Currently EMPTY (no store yet). |
| snapshots/mwarokin_schema.json | 1,105,979 | MWAROKIN project (spnerrqumefbuuscumhw) full schema. 218 base tables + 46 views. Live shared estate. |

## Key facts (live, verified this session)
- MWAROKIN = real-estate estate + shared catalog (mau_/union_/academy/agent/marketplace/ledger). ACTIVE_HEALTHY.
- MALI = group-savings store (to be built from supabase/migrations/006_mali_group_savings.sql). Public schema currently empty. ACTIVE_HEALTHY.
- Cross-project sharing = read-only via Management API. No cross-DB writes by design.

## Restore path (if ever needed)
1. Mali: supabase.com dashboard -> SQL Editor -> paste 006_mali_group_savings.sql -> Run.
2. Mwarokin: identical migration stack 001..005 (STA Core) is already live; snapshots/mwarokin_schema.json is the verification baseline.

## Freeze rule
Do NOT modify snapshots/* after this date. New snapshots go to snapshots/<YYYYMMDD>/.
