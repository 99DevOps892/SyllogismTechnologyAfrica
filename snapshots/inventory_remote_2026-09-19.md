Live inventory probe — SyllogismTechnologyAfrica (Syslogism Technology Africa ecosystem)
Date: 2026-09-19
Source: Supabase Management API v1 (read-only, per-project database/query)
Connection mode: CLI-linked pooler (no Docker, no direct DB password used)

PROJECTS:
  Mwarokin Estates   ref=spnerrqumefbuuscumhw  status=ACTIVE_HEALTHY  org=ozbyadgmqixjjpehhksc
  Mali-Access-Union  ref=vfkqjapegrhdsrlmmiih  status=ACTIVE_HEALTHY  org=sezvtiavulawobcpscgn

FINDINGS:
  1. Mwarokin hosts the large shared/ecosystem database (221 public tables incl. agents,
     finance/ledger, knowledge_graph, observability, union_*, mau_*, marketplace, etc.)
  2. Mali currently holds only Mau + core system schemas (auth/storage/vault).
  3. Docker NOT installed -> supabase db pull / db dump / db diff require Docker shadow DB.
  4. pg_dump/psql available at C:\PostgreSQL\bin but require per-project DB password
     (found only in Supabase dashboard Settings > Database; never returned via CLI/API).
  5. Full schema backups therefore require EITHER a Docker install OR the two DB passwords.
