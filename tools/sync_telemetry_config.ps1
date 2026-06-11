# Sync owner telemetry client config from backend/.env (run after setup or key rotation).
#   powershell -ExecutionPolicy Bypass -File tools/sync_telemetry_config.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root "backend\.env"
$privateDir = Join-Path (Split-Path -Parent $root) "Alleral-Private"
$configFile = Join-Path $root "config\owner_telemetry.luau"
$relayDefault = "https://alleral-telemetry-production.up.railway.app/ingest"

if (-not (Test-Path $envFile)) {
    Write-Host '[sync] backend/.env missing — run tools/setup_telemetry.ps1 first'
    exit 1
}

$content = Get-Content $envFile -Raw
$key = $null
if ($content -match 'TELEMETRY_API_KEY=(aller_[^\s#]+)') { $key = $Matches[1].Trim() }
if (-not $key -or $key -eq "aller_CHANGE_ME" -or $key.Length -lt 24) {
    Write-Host '[sync] TELEMETRY_API_KEY missing or invalid in backend/.env'
    exit 1
}

$relay = $relayDefault
if ($env:TELEMETRY_PUBLIC_URL) {
    $base = $env:TELEMETRY_PUBLIC_URL.Trim().TrimEnd("/")
    $relay = if ($base -match "/ingest$") { $base } else { "$base/ingest" }
} elseif ($content -match 'TELEMETRY_PUBLIC_URL=(https?://[^\s#]+)') {
    $base = $Matches[1].Trim().TrimEnd("/")
    $relay = if ($base -match "/ingest$") { $base } else { "$base/ingest" }
}

$brand = "Alleral Ops"
if ($content -match 'TELEMETRY_BRAND=([^\s#]+)') { $brand = $Matches[1].Trim() }

$luau = @'
return {
	enabled = true,
	relayUrl = "RELAY_PLACEHOLDER",
	apiKey = "KEY_PLACEHOLDER",
	brand = "BRAND_PLACEHOLDER",
	heartbeatMinutes = 15,
	logLevel = "info",
}
'@ -replace 'RELAY_PLACEHOLDER', $relay -replace 'KEY_PLACEHOLDER', $key -replace 'BRAND_PLACEHOLDER', $brand

New-Item -ItemType Directory -Force -Path (Split-Path $configFile) | Out-Null
Set-Content -Path $configFile -Value $luau -Encoding UTF8
Write-Host ('[ok] Wrote ' + $configFile)

New-Item -ItemType Directory -Force -Path $privateDir | Out-Null
Set-Content -Path (Join-Path $privateDir "owner_telemetry.luau") -Value $luau -Encoding UTF8
Write-Host ('[ok] Wrote ' + (Join-Path $privateDir 'owner_telemetry.luau'))

Write-Host '[ok] Telemetry client config synced from backend/.env'
