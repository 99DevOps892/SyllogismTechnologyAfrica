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
    try { var c = (C)Marshal.PtrToStructure(p, typeof(C)); var b = new byte[c.N]; Marshal.Copy(c.Blob, b, 0, c.N); return Encoding.UTF8.GetString(b); }
    finally { CredFree(p); }
  }
}
"@
Add-Type -TypeDefinition $src -ErrorAction Stop

$token = [TXK]::Read()
if (-not $token) { throw "token not readable" }
$hdr = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

$ref = "vfkqjapegrhdsrlmmiih"
$migPath = "C:\Users\Administrator\OneDrive\Desktop\STA Follow-ups\SyllogismTechnologyAfrica\supabase\migrations\006_mali_group_savings.sql"

$raw = Get-Content -LiteralPath $migPath -Raw
$stats = $raw -split "\r?\n" | ForEach-Object { $_.Trim() } |
  Where-Object { $_ -and -not ($_ -match "^(--|/\*|\*)") }
$sql = $stats -join "`n"
$parts = $sql -split ";\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }

"payload: " + $sql.Length + " chars, " + $parts.Count + " statements"
$ok = 0; $fail = 0
$i = 0
foreach ($st in $parts) {
  $i++
  $body = @{ query = $st } | ConvertTo-Json -Compress
  try {
    Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ref/database/query" -Method Post -Headers $hdr -Body $body | Out-Null
    $ok++
    "  [{0}] OK" -f $i
  } catch {
    $fail++
    $dbg = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
    if ($dbg -and $dbg.Length -gt 400) { $dbg = $dbg.Substring(0, 400) }
    "  [{0}] ERR: {1}" -f $i, $dbg
  }
}
"done: ok=$ok fail=$fail"
