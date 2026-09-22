$tokenSrc = @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class XLK {
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
Add-Type -TypeDefinition $tokenSrc -ErrorAction Stop

$token = [XLK]::Read()
if (-not $token) { throw "token unreadable" }
$hdr = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$ref = "vfkqjapegrhdsrlmmiih"

$all = @()
$query = "select t.table_name, c.column_name, c.data_type, c.is_nullable, c.column_default from information_schema.columns c join information_schema.tables t on t.table_schema = c.table_schema and t.table_name = c.table_name where c.table_schema = 'public' and t.table_name like 'mali\_%' order by t.table_name, c.ordinal_position"

$body = @{ query = $query } | ConvertTo-Json -Compress
try {
  $rows = Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ref/database/query" -Method Post -Headers $hdr -Body $body
  "remote rows: " + $rows.Count
  $tables = $rows | Group-Object table_name | ForEach-Object {
    [pscustomobject]@{
      table = $_.Name
      columns = $_.Group | ForEach-Object { [pscustomobject]@{ name = $_.column_name; type = $_.data_type; nullable = $_.is_nullable; default = $_.column_default } }
    }
  }
  $snap = [pscustomobject]@{
    project = "MALI"
    ref = $ref
    captured_at = (Get-Date).ToUniversalTime().ToString("o")
    groups_savings = $tables
  }
  $out = "C:\Users\Administrator\OneDrive\Desktop\STA Follow-ups\SyllogismTechnologyAfrica\snapshots\mali_schema.json"
  $snap | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $out -Encoding UTF8
  "snapshot written: " + (Get-Item -LiteralPath $out).Length + " bytes"
} catch {
  "EXPORT ERR: " + $_.Exception.Message
}
