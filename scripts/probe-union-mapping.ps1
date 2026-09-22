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
Add-Type -TypeDefinition $src -ErrorAction Stop
$token = [TXK]::Read()
if (-not $token) { throw "no token" }
$hdr = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

function Probe {
  param([string]$ref)
  $patterns = @("union\_%","mwarokin\_%","mwarok%","%mwarok%","mali\_%","mali%","%mali%","mau\_%","mau%","%mau%","academy%","academ%","agent%","marketplace%","%marketplace%","finance%","ledger%","%ledger%")
  foreach ($pat in $patterns) {
    $q = @{ query = "select count(*)::int as n from information_schema.tables where table_schema='public' and table_name like '$pat'" } | ConvertTo-Json -Compress
    try {
      $r = Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ref/database/query" -Method Post -Headers $hdr -Body $q
      Write-Host ("  {0,-20} -> {1}" -f $pat, $r[0].n)
    } catch { Write-Host ("  {0,-20} -> ERR: {1}" -f $pat, $_.Exception.Message) }
  }
}

Write-Host "=== MWAROKIN (spnerrqumefbuuscumhw) table-family counts ==="
Probe "spnerrqumefbuuscumhw"
Write-Host ""
Write-Host "=== MALI (vfkqjapegrhdsrlmmiih) table-family counts ==="
Probe "vfkqjapegrhdsrlmmiih"
