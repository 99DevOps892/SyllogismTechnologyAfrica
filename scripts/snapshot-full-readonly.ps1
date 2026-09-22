# snapshot-full-readonly.ps1
# READ-ONLY full schema snapshot for BOTH Supabase projects via Management API query endpoint.
# NO DB password, NO Docker, NO writes to remote. Emits SQL files into snapshots/.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $root "snapshots"
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

$src = @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class TXK {
  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, EntryPoint="CredReadW")]
  static extern bool CredReadW(string t, int ty, int fl, out IntPtr p);
  [DllImport("advapi32.dll")] static extern bool CredFree(IntPtr p);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  struct C { public uint A; public uint B; public IntPtr Cn; public IntPtr Cm; public long W; public int N; public IntPtr Blob; public uint P; public int Ac; public IntPtr At; public IntPtr Ta; public IntPtr Un; }
  public static string Read() {
    IntPtr p;
    if (!CredReadW("Supabase CLI:supabase", 1, 0, out p)) return null;
    try { var c=(C)Marshal.PtrToStructure(p, typeof(C)); var b=new byte[c.N]; Marshal.Copy(c.Blob,b,0,c.N); return Encoding.UTF8.GetString(b); }
    finally { CredFree(p); }
  }
}
"@
Add-Type -TypeDefinition $src -ErrorAction Stop | Out-Null
$token = [TXK]::Read()
if (-not $token) { throw "No Supabase CLI token. Run: supabase login" }
$hdr = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

function Invoke-Q([string]$ref, [string]$sql) {
  $body = @{ query = $sql } | ConvertTo-Json -Compress
  return Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ref/database/query" -Method Post -Headers $hdr -Body $body
}

$projects = @(
  @{ ref = "spnerrqumefbuuscumhw"; label = "MWAROKIN" },
  @{ ref = "vfkqjapegrhdsrlmmiih"; label = "MALI" }
)

$results = @()
foreach ($p in $projects) {
  $ref = $p.ref; $label = $p.label
  Write-Host ("`n=== {0} ({1}) â€” snapshotting ===" -f $label, $ref)
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("-- ==================================================")
  [void]$sb.AppendLine("-- {0} â€” full read-only schema backup" -f $label)
  [void]$sb.AppendLine("-- project {0}  date {1}  mode=Management API (read-only)" -f $ref, $stamp)
  [void]$sb.AppendLine("-- ==================================================")

  # 1. EXTENSIONS
  try {
    $x = Invoke-Q $ref "select extname, extversion from pg_extension order by extname"
    [void]$sb.AppendLine("`n-- == EXTENSIONS == total=" + $x.Count)
    foreach ($e in $x) { [void]$sb.AppendLine(("-- {0} {1}" -f $e.extname, $e.extversion)) }
  } catch {}

  # 2. TABLES + COLUMNS + PK
  $tables = Invoke-Q $ref "select table_name from information_schema.tables where table_schema='public' and table_type='BASE TABLE' order by table_name"
  [void]$sb.AppendLine("`n-- == TABLES (base) == total=" + $tables.Count)
  foreach ($t in $tables) {
    $tn = $t.table_name
    $cols = Invoke-Q $ref "select column_name, data_type, is_nullable, coalesce(column_default,'') as d from information_schema.columns where table_schema='public' and table_name='$tn' order by ordinal_position"
    $pk = ""; try { $pk = (Invoke-Q $ref "select string_agg(a.attname,',' order by rn) as k from (select a.attname, row_number() over() as rn from pg_index i join pg_attribute a on a.attrelid=i.indrelid and a.attnum=any(i.indkey) where i.indrelid='public.$tn'::regclass and i.indisprimary) a")[0].k } catch {}
    [void]$sb.AppendLine("`nCREATE TABLE IF NOT EXISTS public.$tn (")
    $i = 0
    foreach ($c in $cols) {
      $i++
      $nullsuff = if ($c.is_nullable -eq "YES") { "NULL" } else { "NOT NULL" }
      $dflt = if ($c.d) { " DEFAULT " + $c.d } else { "" }
      $sep = if ($i -lt $cols.Count) { "," } else { "" }
      [void]$sb.AppendLine(("  {0,-40} {1} {2}{3}{4}" -f $c.column_name, $c.data_type, $nullsuff, $dflt, $sep))
    }
    [void]$sb.AppendLine(");")
    if ($pk) { [void]$sb.AppendLine("ALTER TABLE public.$tn ADD PRIMARY KEY ($pk);") }
  }

  # 3. VIEWS
  try {
    $vws = Invoke-Q $ref "select table_name from information_schema.views where table_schema='public' order by table_name"
    [void]$sb.AppendLine("`n-- == VIEWS == total=" + $vws.Count)
    foreach ($v in $vws) {
      try { $def = (Invoke-Q $ref "select pg_get_viewdef('public.$($v.table_name)'::regclass, true) as d")[0].d; [void]$sb.AppendLine("-- VIEW public.$($v.table_name)"); [void]$sb.AppendLine($def) } catch {}
    }
  } catch {}

  # 4. RLS POLICIES
  try {
    $pols = Invoke-Q $ref "select tablename, policyname, permissive, roles, cmd, qual, with_check from pg_policies where schemaname='public' order by tablename, policyname"
    [void]$sb.AppendLine("`n-- == RLS POLICIES == total=" + $pols.Count)
    foreach ($pl in $pols) { [void]$sb.AppendLine(("-- RLS {0}.{1} [{2} {3} cmd={4}] qual={5} check={6}" -f $pl.tablename, $pl.policyname, $pl.permissive, $pl.roles, $pl.cmd, $pl.qual, $pl.with_check)) }
  } catch {}

  # 5. STORAGE BUCKETS
  try {
    $bk = Invoke-Q $ref "select id, name, public from storage.buckets order by id"
    [void]$sb.AppendLine("`n-- == STORAGE BUCKETS == total=" + $bk.Count)
    foreach ($b in $bk) { [void]$sb.AppendLine(("-- bucket {0} name={1} public={2}" -f $b.id, $b.name, $b.public)) }
  } catch {}

  $file = Join-Path $OutDir ("schema_{0}_{1}.sql" -f $label.ToLower(), $stamp)
  [System.IO.File]::WriteAllText($file, $sb.ToString(), [System.Text.Encoding]::UTF8)
  Write-Host ("  wrote {0}  ({1} bytes)" -f $file, (Get-Item $file).Length)
  $results += $file
}

Write-Host "`nDONE. Files:"
$results | ForEach-Object { Write-Host "  $_" }
