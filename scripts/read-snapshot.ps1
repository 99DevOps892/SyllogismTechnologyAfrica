# read-snapshot.ps1
# READ-ONLY schema snapshot via Supabase Management API query endpoint.
# No DB password, no Docker, no writes. Queries information_schema only.
param(
  [string]$OutDir = ".\snapshots"
)

$ErrorActionPreference = "Stop"
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class SupaTok
{
    public static string Read()
    {
        IntPtr p;
        if (!CredReadW("Supabase CLI:supabase", 1, 0, out p)) return null;
        try
        {
            var c = (C)Marshal.PtrToStructure(p, typeof(C));
            var b = new byte[c.N];
            Marshal.Copy(c.B, b, 0, c.N);
            return Encoding.UTF8.GetString(b);
        }
        finally { CredFree(p); }
    }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct C { public uint F; public uint T; public IntPtr Tn; public IntPtr Cn; public long W; public int N; public IntPtr B; public uint P; public int Ac; public IntPtr At; public IntPtr Ta; public IntPtr U; }
    [DllImport("advapi32.dll", CharSet=CharSet.Unicode, EntryPoint="CredReadW")] static extern bool CredReadW(string t, int ty, int fl, out IntPtr p);
    [DllImport("advapi32.dll")] static extern bool CredFree(IntPtr p);
}
'@ -ErrorAction SilentlyContinue
$tok = [SupaTok]::Read()
if (-not $tok) { throw "No Supabase CLI token in Credential Manager. Run: supabase login" }
$hdr = @{ Authorization = "Bearer $tok"; "Content-Type" = "application/json" }

function Invoke-Q($ref, $sql) {
  $body = @{ query = $sql } | ConvertTo-Json -Compress
  return Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ref/database/query" -Method Post -Headers $hdr -Body $body
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$projects = @(
  @{ ref = "spnerrqumefbuuscumhw"; label = "Mwarokin" }
)

foreach ($p in $projects) {
  Write-Host ("`n=== " + $p.label + " (" + $p.ref + ") ===")
  $dir = Join-Path $OutDir ($p.ref + "-" + $stamp)
  New-Item -ItemType Directory -Path $dir -Force | Out-Null

  # --- 1. tables + column DDL ---
  $tables = Invoke-Q $p.ref "select table_name from information_schema.tables where table_schema='public' and table_type='BASE TABLE' order by table_name"
  Write-Host ("  public base tables: " + $tables.Count)
  $out = [System.Text.StringBuilder]::new()
  [void]$out.AppendLine("-- ============================================")
  [void]$out.AppendLine("-- " + $p.label + " public schema snapshot  " + $stamp)
  [void]$out.AppendLine("-- READ-ONLY dump via Management API query endpoint")
  [void]$out.AppendLine("-- ============================================")

  foreach ($t in $tables) {
    $cols = Invoke-Q $p.ref "select column_name, data_type, is_nullable, coalesce(column_default,'') as cdefault, character_maximum_length as maxlen, numeric_precision as p, numeric_scale as s from information_schema.columns where table_schema='public' and table_name='$($t.table_name)' order by ordinal_position"
    [void]$out.AppendLine("`n-- TABLE public.$($t.table_name)")
    foreach ($c in $cols) {
      $len = if ($c.maxlen) { "($($c.maxlen))" } elseif ($c.p -ne $null) { "($($c.p),$($c.s))" } else { "" }
      [void]$out.AppendLine(("  {0} {1}{2} {3} DEFAULT {4}" -f $c.column_name, $c.data_type, $len, $(if($c.is_nullable -eq "YES"){"NULL"}else{"NOT NULL"}), $c.cdefault))
    }
    # constraints
    $cons = Invoke-Q $p.ref "select con.conname, pg_get_constraintdef(con.oid) as def from pg_constraint con join pg_class c on c.oid=con.conrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='$($t.table_name)' order by con.contype"
    foreach ($cn in $cons) { [void]$out.AppendLine(("  CONSTRAINT {0}  ::  {1}" -f $cn.conname, $cn.def)) }
  }

  # --- 2. views ---
  $views = Invoke-Q $p.ref "select table_name from information_schema.views where table_schema='public' order by table_name"
  [void]$out.AppendLine("`n-- ===== VIEWS ===== total=" + $views.Count)
  foreach ($v in $views) {
    $def = (Invoke-Q $p.ref "select pg_get_viewdef('public.$($v.table_name)'::regclass, true) as d")[0].d
    [void]$out.AppendLine("-- VIEW public.$($v.table_name)")
    [void]$out.AppendLine($def)
  }

  # --- 3. functions ---
  $funcs = Invoke-Q $p.ref "select p.proname, pg_get_function_identity_arguments(p.oid) as args from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' order by p.proname"
  [void]$out.AppendLine("`n-- ===== FUNCTIONS ===== total=" + $funcs.Count)
  foreach ($f in $funcs) {
    $body = (Invoke-Q $p.ref "select pg_get_functiondef('public.$($f.proname)( $($f.args) )'::regprocedure) as d")[0].d
    [void]$out.AppendLine("-- FUNCTION public.$($f.proname)($($f.args))")
    [void]$out.AppendLine($body)
  }

  # --- 4. RLS policies ---
  $pols = Invoke-Q $p.ref "select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check from pg_policies where schemaname='public' order by tablename, policyname"
  [void]$out.AppendLine("`n-- ===== RLS POLICIES ===== total=" + $pols.Count)
  foreach ($pl in $pols) { [void]$out.AppendLine(("-- {0}.{1} [{2} {3} cmd={4}] roles={5}" -f $pl.schemaname, $pl.tablename, $pl.policyname, $pl.permissive, $pl.cmd, $pl.roles)) }

  # --- 5. storage buckets ---
  $buckets = Invoke-Q $p.ref "select id, name, public from storage.buckets order by id"
  [void]$out.AppendLine("`n-- ===== STORAGE BUCKETS ===== total=" + $buckets.Count)
  foreach ($b in $buckets) { [void]$out.AppendLine(("-- bucket {0} name={1} public={2}" -f $b.id, $b.name, $b.public)) }

  $file = Join-Path $dir "schema.sql"
  [System.IO.File]::WriteAllText($file, $out.ToString(), [System.Text.Encoding]::UTF8)
  Write-Host ("  wrote " + $file + "  (" + (Get-Item $file).Length + " bytes)")
}
Write-Host "`nDone. Read-only snapshots saved under $OutDir"
