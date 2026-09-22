# Backup-schemas.ps1
# READ-ONLY remote schema snapshots via Supabase Management API (v1).
# Uses the CLI's stored session token from Windows Credential Manager.
# NO DB password, NO Docker, NO writes. Safe to re-run.
param(
  [string]$OutputDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "snapshots")
)

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# --- Read CLI session token from Windows Credential Manager ---
$src = @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class CredTokenApi
{
    public static string Read(string target)
    {
        IntPtr p;
        if (!CredReadW(target, 1, 0, out p)) return null;
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
    struct C { public uint F; public uint T; public IntPtr Tn; public IntPtr Co; public long W; public int N; public IntPtr B; public uint P; public int A; public IntPtr At; public IntPtr Ta; public IntPtr U; }
    [DllImport("advapi32.dll", CharSet=CharSet.Unicode, EntryPoint="CredReadW")] static extern bool CredReadW(string t, int ty, int fl, out IntPtr p);
    [DllImport("advapi32.dll")] static extern bool CredFree(IntPtr p);
}
'@
Add-Type -TypeDefinition $src -ErrorAction SilentlyContinue
$token = [CredTokenApi]::Read("Supabase CLI:supabase")
if (-not $token) { Write-Error "No Supabase CLI session token found. Run: supabase login"; exit 1 }
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

function Query-Project($ref, $label) {
  Write-Host "`n== $label ($ref) =="
  $body = @{ query = "select now() as ts, (select count(*) from information_schema.tables where table_schema='public') as public_tables" } | ConvertTo-Json -Compress
  try {
    $res = Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ref/database/query" -Method Post -Headers $headers -Body $body
    Write-Host "   connected OK | now=$($res[0].ts) | public_tables=$($res[0].public_tables)"
    return $true
  } catch {
    Write-Host "   FAILED: $($_.Exception.Message)"
    return $false
  }
}

# --- Projects: Mwarokin + Mali ---
$projects = @(
  @{ ref = "spnerrqumefbuuscumhw"; label = "MWAROKIN" },
  @{ ref = "vfkqjapegrhdsrlmmiih"; label = "MALI" }
)

$ok = @()
foreach ($p in $projects) {
  if (Query-Project $p.ref $p.label) { $ok += $p }
}

Write-Host "`n=== Connectivity summary ==="
$ok | ForEach-Object { Write-Host "  [OK] $($_.label) $($_.ref)" }
Write-Host "($($ok.Count)/$($projects.Count) reachable read-only)"