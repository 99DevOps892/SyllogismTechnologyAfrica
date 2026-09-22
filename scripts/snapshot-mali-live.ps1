$src = @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class XRK {
  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, EntryPoint="CredReadW")]
  static extern bool CredReadW(string t, int ty, int fl, out IntPtr p);
  [DllImport("advapi32.dll")] static extern bool CredFree(IntPtr p);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  struct C { public uint U; public uint K; public IntPtr Cn; public IntPtr Cm; public long W; public int N; public IntPtr Blob; public uint P; public int Ac; public IntPtr At; public IntPtr Ta; public IntPtr Sn; }
  public static string Read() {
    IntPtr p;
    if (!CredReadW("Supabase CLI:supabase", 1, 0, out p)) return null;
    try { var c = (C)Marshal.PtrToStructure(p, typeof(C)); var b = new byte[c.N]; Marshal.Copy(c.Blob, b, 0, c.N); return Encoding.UTF8.GetString(b); }
    finally { CredFree(p); }
  }
}
"@
Add-Type -TypeDefinition $src -ErrorAction Stop
$token = [XRK]::Read()
if (-not $token) { throw "no token" }
$hdr = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$ref = "vfkqjapegrhdsrlmmiih"

function PGQ([string]$sql) {
  $q = @{ query = $sql } | ConvertTo-Json -Compress
  Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ref/database/query" -Method Post -Headers $hdr -Body $q
}

# --- columns (information_schema) ---
$cols = PGQ @"
select c.table_name, c.column_name, c.data_type, c.is_nullable, c.column_default, c.ordinal_position
from information_schema.columns c
join information_schema.tables t
  on t.table_schema = c.table_schema and t.table_name = c.table_name
where c.table_schema = 'public'
  and t.table_name like 'mali\_%'
order by c.table_name, c.ordinal_position
"@

# --- primary keys (pg_constraint contype='p') ---
$pks = PGQ @"
select kc.table_name, kc.column_name
from information_schema.table_constraints tc
join information_schema.key_column_usage kc
  on tc.constraint_name = kc.constraint_name and tc.table_schema = kc.table_schema
where tc.constraint_type = 'PRIMARY KEY'
  and tc.table_schema = 'public'
  and tc.table_name like 'mali\_%'
order by kc.table_name, kc.ordinal_position
"@

# --- foreign keys (pg_constraint contype='f') ---
$fks = PGQ @"
select c.conname as name,
       cl.relname as table_name,
       at.attname as col_name,
       cr.relname as ref_table,
       ft.attname as ref_col,
       c.conkey, c.confkey
from pg_constraint c
join pg_class cl on cl.oid = c.conrelid
join pg_class cr on cr.oid = c.confrelid
join pg_namespace ns on ns.oid = cl.relnamespace
join lateral unnest(c.conkey) with ordinality k(attnum, ord) on true
join lateral unnest(c.confkey) with ordinality f(attnum, ford) on true and f.ford = k.ord
join pg_attribute at on at.attrelid = cl.oid and at.attnum = k.attnum
join pg_attribute ft on ft.attrelid = cr.oid and ft.attnum = f.attnum
where c.contype = 'f'
  and ns.nspname = 'public'
  and cl.relname like 'mali\_%'
order by cl.relname, c.conname
"@

# --- enforcement status (RLS) ---
$rls = PGQ "select tablename, rowsecurity from pg_tables where schemaname = 'public' and tablename like 'mali\_%' order by tablename"

# --- views ---
$views = @()
try {
  $views = PGQ "select table_name from information_schema.views where table_schema = 'public' and table_name like 'mali\_%' order by table_name"
} catch { $views = @() }

# --- storage buckets ---
$buckets = @()
try {
  $buckets = PGQ "select id, name from storage.buckets order by name"
} catch { $buckets = @() }

# --- exact row counts (read-only, one call per table) ---
$rowCounts = @{}
$liveTables = @($cols | Group-Object table_name | ForEach-Object { $_.Name })
foreach ($t in $liveTables) {
  try {
    $c = PGQ "select count(*)::int as n from public.`"$t`""
    $rowCounts[$t] = [int]$c[0].n
  } catch { $rowCounts[$t] = -1 }
}

# --- assemble, mirroring mwarokin_schema.json ---
$byTable = @($cols | Group-Object table_name | ForEach-Object {
  $name = $_.Name
  $colObjs = @($_.Group | ForEach-Object {
    [pscustomobject]@{
      name     = $_.column_name
      type     = $_.data_type
      nullable = ($_.is_nullable -eq 'YES')
      default  = $_.column_default
    }
  })
  $pkCols  = @($pks | Where-Object { $_.table_name -eq $name } | ForEach-Object { $_.column_name })
  $fkObjs  = @($fks | Where-Object { $_.table_name -eq $name } | ForEach-Object {
    [pscustomobject]@{ name = $_.name; cols = $_.col_name; ref_table = $_.ref_table; ref_cols = $_.ref_col }
  })
  $rl = $rls | Where-Object { $_.tablename -eq $name }
  [pscustomobject]@{
    name          = $name
    columns       = $colObjs
    primary_key   = if ($pkCols.Count -eq 1) { $pkCols[0] } else { $pkCols }
    foreign_keys  = $fkObjs
    row_count     = if ($rowCounts.ContainsKey($name)) { $rowCounts[$name] } else { -1 }
    row_security  = if ($rl -and $rl.rowsecurity) { $true } else { $false }
  }
})

$snap = [pscustomobject]@{
  project     = $ref
  label       = "MALI"
  exported_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
  tables      = $byTable
  views       = @($views | ForEach-Object { $_.table_name })
  rls         = @($byTable | Where-Object { $_.row_security }).Count
  buckets     = @($buckets | ForEach-Object { $_.name })
}

$dir = "C:\Users\Administrator\OneDrive\Desktop\STA Follow-ups\SyllogismTechnologyAfrica\snapshots"
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$out = Join-Path $dir "mali_schema.json"
$snap | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $out -Encoding UTF8
"snapshot: " + $byTable.Count + " tables -> " + (Get-Item -LiteralPath $out).Length + " bytes"
$byTable | ForEach-Object {
  "  " + $_.name + " | rows=" + $_.row_count + " | rls=" + $_.row_security + " | pk=" + (@($_.primary_key) -join ',') + " | fk=" + $_.foreign_keys.Count
}