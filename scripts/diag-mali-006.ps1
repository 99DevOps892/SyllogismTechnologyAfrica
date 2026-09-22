$src = @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class TXK {
  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, EntryPoint="CredReadW")]
  static extern bool CredReadW(string t, int ty, int fl, out IntPtr p);
  [DllImport("advapi32.dll")] static extern bool CredFree(IntPtr p);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  struct C { public uint U; public uint K; public IntPtr Cn; public IntPtr Cm; public long W; public int N; public IntPtr Blob; public uint P; public int Ac; public IntPtr At; public IntPtr Ta; public IntPtr Sn; }
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
$ref = "vfkqjapegrhdsrlmmiih"

$mig = "C:\Users\Administrator\OneDrive\Desktop\STA Follow-ups\SyllogismTechnologyAfrica\supabase\migrations\006_mali_group_savings.sql"
$clean = Get-Content -LiteralPath $mig | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not ($_ -match "^(--|/\*|\*)") }
$sql = $clean -join "`n"
$parts = $sql -split ";\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }

"re-send $($parts.Count) idempotent statements, capture REAL bodies on failure:"
$i = 0
foreach ($st in $parts) {
  $i++
  $body = @{ query = $st } | ConvertTo-Json -Compress
  try {
    Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ref/database/query" -Method Post -Headers $hdr -Body $body | Out-Null
    "  [{0}] OK" -f $i
  } catch {
    $txt = ""
    $resp = $_.Exception.Response
    if ($resp) {
      try { $sr = New-Object System.IO.StreamReader($resp.GetResponseStream()); $txt = $sr.ReadToEnd() } catch { $txt = "(stream unreadable)" }
    } else { $txt = $_.Exception.Message }
    if ($txt.Length -gt 400) { $txt = $txt.Substring(0, 400) }
    "  [{0}] ERR: {1}" -f $i, $txt
  }
}
"diag done"