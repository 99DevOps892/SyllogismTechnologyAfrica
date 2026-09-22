# SyllogismTechnologyAfrica Agentic Supabase Ecosystem

Africa-first App Store / SaaS / Games / Devices ecosystem.
- Supabase (Auth, Postgres, Storage, Realtime, Edge Functions)
- Next.js / React Native / PWA frontends
- Mobile Money first (M-PESA, Airtel Money, MTN MoMo via aggregators)
- Agentic orchestration (OpenCode, OpenClaw, Saicos, Noesis)

## Quick start

1. Create STA Core project under org **iyngtxvchqpeayvsuvph** in Supabase Dashboard.
2. `supabase login` + `supabase link --project-ref <ref>`.
3. `cp .env.example .env` and fill in real values (see rotation note for OpenRouter).
4. `supabase db push` — applies 001..005 in order.
5. `supabase functions deploy <name>` for each of the 5 functions.
6. Frontend: `cd apps/web && npm install && npm run dev`.

## Project separation (never cross-push)

| Project | Ref | Payload |
|---------|-----|---------|
| Mwarokin | `spnerrqumefbuuscumhw` | Mwarokin only, read-only for now |
| Mali | `vfkqjapegrhdsrlmmiih` | Mali only, guard-gated (`guard/mali_deploy_guard.sql`) |
| STA Core | new | 001..005 + shared + ecosystem |

See `guard/ORG_PUSH_RUNBOOK.md` and `docs/APPROVALS_LOG.md`.

## Security

- `.env` and `SECRETS/` are git-ignored. Never commit keys.
- The old OpenRouter key in `STAOpenRouter APIs.txt` must be **rotated** and the file deleted.
- F-25: Edge Functions handle payments server-side; never expose service-role keys to the browser.

## Docs

- `docs/AGENTIC_BRAIN.md` — live status tracker.
- `docs/APPROVALS_LOG.md` — founder approval gates.
- `guard/ORG_PUSH_RUNBOOK.md` — strict deployment runbook.