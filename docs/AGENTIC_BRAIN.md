# AGENTIC BRAIN — Status Tracker

SyllogismTechnologyAfrica agentic execution source of truth. Mirrors the feature matrix
from `Agenti sta Supabase.txt`, task map from `Setup.txt`, and audit results from task.txt / task2.txt.

Legend: ⛔ not started · 🔨 building · 🧪 testing · ✅ done · 🚧 gated (needs approval)

## 1. Feature Completion Matrix

| # | Feature | Status | Priority | Owner |
|---|---------|--------|----------|-------|
| F01 | Mobile Money First (M-PESA, Airtel, MTN) | 🔨 edge functions | P0 | opencode |
| F02 | HTML5 / PWA + Sub-50MB Slim Install | ⛔ | P0 | opencode |
| F03 | Smart Download Manager (data cost) | 🔨 estimate-data-cost | P0 | opencode |
| F04 | Made in Africa Curated Hub | ⛔ | P1 | saicos |
| F05 | Context-Aware Search | ⛔ | P1 | saicos |
| F06 | Community Trending (WhatsApp velocity) | ⛔ | P1 | noesis |
| F07 | Studio Builder Toolkit + Localization | ⛔ | P1 | saicos |
| F08 | Performance Analytics | ⛔ | P1 | noesis |
| F09 | Fast-Track Review (24h) | 🔨 review-triage | P2 | opencode |
| F10 | Cloud Gaming / Server saves | ⛔ | P2 | opencode |
| F11 | Privacy-First (DPA/POPIA/GDPR) | ⛔ consents schema | P0 | opencode |
| F12 | Alt Monetization Dashboard | ⛔ | P1 | saicos |
| F13 | Community Hub + Beta cohorts | ⛔ | P2 | noesis |
| F14 | 10% Creator Revenue Share | 🔨 payout-calculator | P0 | opencode |
| F15 | Login/Logout/Subs/Downloads/Financials | 🔨 schema done | P0 | opencode |

## 2. Setup.txt task status (0-21)

| Task | Title | Status |
|------|-------|--------|
| 0 | OpenCode&OpenClaw real-time activation | ⛔ workstation step |
| 1 | Backend connections (Supabase→Mwarokin/Mali, 3 domains, PesaPal, Daraja) | ⛔ needs credentials |
| 2 | 1-5 Ksh fee per tenant transaction + subscriptions | 🔨 fee fn in payments.ts |
| 3 | OpenClaw activity + Ollama LLMs + UI TARS | 🧪 |
| 4 | Co-operative & I&M banking to 01192643932500 | ⛔ needs bank API access |
| 5 | Annual subscriptions (Claude, Resend, Vercel, Netlify, GCP, etc.) | ⛔ provider tokens |
| 6 | Data entry for rent/home/landlord/building/geolocation | ⛔ app tables |
| 7 | Legal: CR12, KRA, GDPR, patents, copyrights | ⛔ |
| 8 | AI Systems: Saicos, Noesis, Agents.md | ⛔ |
| 9 | GitHub zips, OpenClaw workstation, decentralization | ⛔ |
| 10 | Digital marketing & social media | ⛔ |
| 11 | CDN/Podman/Hostinger VPS/Tailscale/Nginx/app.js/S3 | ⛔ S3 later |
| 12 | DB setup: constraints, indexes, migrations, cache, monitoring | 🔨 migrations built |
| 13 | Payments: SylloPay, Mpesa, Airtel, Stripe, Sendgrid, Zapier + backups | 🔨 partially |
| 14 | Multi-platform confirm (Android, iOS, Web, TV, Tablet, Auto, Wear) | ⛔ |
| 17 | Testing/debugging AI timetable | ⛔ |
| 18 | Prometheus, Datadog, API protection (rate limit, CORS, SQLi, CSRF, XSS) | ⛔ |
| 19 | Mirrors: GitHub→GitLab/GitBucket + offline PWA + Omnistrate | ⛔ |
| 20 | "Safe Proof hack" penetration list (STA-owned ONLY) | 🚧 requires owned targets |
| 21 | Git mirror + Akamai/Cloudflare/Fastly/GCP CDN | ⛔ |

## 3. Database separation state (task.txt / task2.txt)

- ✅ STA_Supabase_Separation classification complete (Mali pure, Schema.db mixed, deployments ordered)
- ✅ guard/mali_deploy_guard.sql (read-only 3-check)
- ✅ deploy order documented in guard/ORG_PUSH_RUNBOOK.md
- ✅ originals never moved/deleted
- 🚧 remote RLS/auth/storage/edge functions UNVERIFIED — need `supabase db pull` before prod push

## 4. Open loops needing founder input

1. **Rotate OpenRouter key** — exposed in plaintext Desktop file.
2. **Create STA Core project** under org `iyngtxvchqpeayvsuvph` → activate `.env`.
3. **Approve STA-001..004 + MALI-001/002** in docs/APPROVALS_LOG.md.
4. **Choose mobile-money aggregator** (PesaPal vs Daraja direct vs Payfonte) → plug credentials.
5. Task 20: confirm penetration targets are **owned by STA** only.

## 5. Repo map

```
SyllogismTechnologyAfrica/
├── supabase/migrations/001..005   # schema, storage, RLS (deploy-ordered)
├── supabase/functions/            # 5 edge functions
├── guard/                         # mali guard + runbook
├── packages/supabase-client/      # shared client helper
├── apps/web/                      # Next.js PWA scaffold
├── docs/APPROVALS_LOG.md          # founder gates
└── docs/AGENTIC_BRAIN.md          # this file
```