param(
  [string]$Token = ""
)
if (-not $Token) { $Token = Read-Host "Supabase PAT or CLI token" }

$hdr = @{ Authorization = "Bearer $Token"; "Content-Type" = "application/json" }
$projects = @(
  @{ ref = "spnerrqumefbuuscumhw"; label = "Mwarokin" },
  @{ ref = "vfkqjapegrhdsrlmmiih"; label = "Mali" }
)

foreach ($p in $projects) {
  Write-Host ("`n=== " + $p.label + " (" + $p.ref + ") ===")
  try {
    $q = @{ query = "select table_schema, count(*) as tables from information_schema.tables where table_schema='public' group by table_schema" } | ConvertTo-Json
    $r = Invoke-RestMethod -Uri ("https://api.supabase.com/v1/projects/" + $p.ref + "/database/query") -Method Post -Headers $hdr -Body $q
    $r | ForEach-Object { Write-Host ("  [OK] " + $_.table_schema + " tables=" + $_.tables) }
  } catch {
    Write-Host ("  [FAIL] " + $_.Exception.Message)
  }
}