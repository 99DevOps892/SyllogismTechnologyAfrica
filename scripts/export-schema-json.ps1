# export-schema-json.ps1 — read-only thrower that exports BOTH projects' public schema
# (tables/columns/PK/FK/views/RLS/buckets) to snapshots/<label>_schema.json
# Uses Management API query endpoint with the CLI's stored session token.
# NO DB password, NO Docker, NO writes to remote.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $root "snapshots"
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$src = @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class TXV {
  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, EntryPoint="CredReadW")]
  static extern bool CredReadW(string t, int ty, int fl, out IntPtr p);
  [DllImport("advapi32.dll")] static extern bool CredFree(IntPtr p);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  struct C { public uint A; public uint B; public IntPtr Cn; public IntPtr Cm; public long W; public int N; public IntPtr Blob; public uint P; public int Ac; public IntPtr At; public IntPtr Ta; public IntPtr U; }
  public static string Read() {
    IntPtr p;
    if (!CredReadW("Supabase CLI:supabase", 1, 0, out p)) return null;
    try { var c=(C)Marshal.PtrToStructure(p, typeof(C)); var b=new byte[c.N]; Marshal.Copy(c.Blob,b,0,c.N); return Encoding.UTF8.GetString(b); }
    finally { CredFree(p); }
  }
}
"@
Add-Type -TypeDefinition $src -ErrorAction Stop | Out-Null
$tok = [TXV]::Read()
if (-not $tok) { throw "No Supabase CLI session token. Run: supabase login" }
$hdr = @{ Authorization = "Bearer $tok"; "Content-Type" = "application/json" }

function Invoke-Q([string]$ref, [string]$sql) {
  $body = @{ query = $sql } | ConvertTo-Json -Compress
  return Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ref/database/query" -Method Post -Headers $hdr -Body $body
}

function Export-One([string]$ref, [string]$label) {
  Write-Host ("`n=== {0} ({1}) ===" -f $label, $ref)
  $doc = [ordered]@{ project = $ref; label = $label; exported_at = (Get-Date -Format "s"); tables = @(); views = @(); rls = @(); buckets = @() }

  $tables = Invoke-Q $ref "select table_name from information_schema.tables where table_schema='public' and table_type='BASE TABLE' order by table_name"
  foreach ($t in $tables) {
    $tn = $t.table_name
    $cols = Invoke-Q $ref "select column_name, data_type, is_nullable, coalesce(column_default,'') as d from information_schema.columns where table_schema='public' and table_name='$tn' order by ordinal_position"
    $pk = $null
    try { $r = Invoke-Q $ref "select string_agg(a.attname, ',' order by rn) as k from (select a.attname, row_number() over() rn from pg_index i join pg_attribute a on a.attrelid=i.indrelid and a.attnum=any(i.indkey) where i.indrelid='public.$tn'::regclass and i.indisprimary) a"; $pk = $r[0].k } catch {}
    $fks = @()
    try {
      $q = "select con.conname, (select string_agg(a.attname,',' order by x.rn) from unnest(con.conkey) with ordinality x(attnum,rn) join pg_attribute a on a.attrelid=con.conrelid and a.attnum=x.attnum) as cols, (select string_agg(a.attname,',' order by y.rn) from unnest(con.confkey) with ordinality y(attnum,rn) join pg_attribute a on a.attrelid=con.confrelid and a.attnum=y.attnum) as refcols, confrelid::regclass::text as reftable from pg_constraint con where con.conrelid='public.$tn'::regclass and con.contype='f'"
      $fks = Invoke-Q $ref $q
      foreach ($fk in $fks) { $fk | Add-Member -NotePropertyName ref_schema -NotePropertyValue "public" -Force }; $fks = @($fks | ForEach-Object { @{ name=$_.conname; cols=$_.cols; ref_table=$_.reftable; ref_cols=$_.refcols } })
    } catch {}
    $doc.tables += [ordered]@{ name = $tn; columns = @($cols | ForEach-Object { [ordered]@{ name=$_.column_name; type=$_.data_type; nullable=($_.is_nullable -eq "YES"); default=if($_.d){$_.d}else{$null} } }); primary_key = $pk; foreign_keys = $fks }
  }

  try { $doc.views = @(Invoke-Q $ref "select table_name from information_schema.views where table_schema='public' order by table_name" | ForEach-Object { $_.table_name }) } catch {}
  try { $doc.rls = @(Invoke-Q $ref "select tablename, policyname, permissive, cmd, roles from pg_policies where schemaname='public' order by tablename, policyname" | ForEach-Object { [ordered]@{ table=$_.tablename; name=$_.policyname; permissive=$_.permissive; cmd=$_.cmd; roles=$_.roles } }) } catch {}
  try { $doc.buckets = @(Invoke-Q $ref "select id, name, public from storage.buckets order by id" | ForEach-Object { [ordered]@{ id=$_.id; name=$_.name; public=($_.public -eq $true) } }) } catch {}

  $file = Join-Path $OutDir ("{0}_schema.json" -f $label.ToLower())
  $doc | ConvertTo-Json -Depth 12 | Set-Content -Path $file -Encoding UTF8
  Write-Host ("  wrote {0}  ({1} bytes)" -f $file, (Get-Item $file).Length)
}

Export-One "spnerrqumefbuuscumhw" "MWAROKIN"
Export-One "vfkqjapegrhdsrlmmiih" "MALI"
Write-Host "`nDONE."