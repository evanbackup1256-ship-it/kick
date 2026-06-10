# Starts the local offline telemetry relay (127.0.0.1:8787).
# Roblox in-game uses Railway from ../Alleral-Private/owner_telemetry.luau — no tunnel needed.
# Keep this window open while you want offline relay running.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$backend = Join-Path $root "backend"
$envFile = Join-Path $backend ".env"
$railwayIngest = "https://alleral-telemetry-production.up.railway.app/ingest"

if (-not (Test-Path $envFile)) {
    Write-Host "Run tools/setup_telemetry.ps1 first."
    exit 1
}

function Test-RelayHealth([string]$BaseUrl) {
    try {
        $r = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 3
        return $r.ok -eq $true
    } catch {
        return $false
    }
}

if (Test-RelayHealth "http://127.0.0.1:8787") {
    Write-Host "[ok] Local relay already running at http://127.0.0.1:8787"
} else {
    Write-Host "[..] Starting local offline relay on http://127.0.0.1:8787 ..."
    pip install -r (Join-Path $backend "requirements.txt") -q
    Start-Process python -ArgumentList "telemetry_relay.py" -WorkingDirectory $backend -WindowStyle Minimized
    Start-Sleep -Seconds 2
    if (-not (Test-RelayHealth "http://127.0.0.1:8787")) {
        Write-Host "[warn] Local relay did not respond — check backend/.env and run tools/start_relay.ps1"
        exit 1
    }
    Write-Host "[ok] Local relay running"
}

if (Test-RelayHealth "https://alleral-telemetry-production.up.railway.app") {
    Write-Host "[ok] Railway relay online (Roblox in-game)"
} else {
    Write-Host "[warn] Railway relay unreachable — in-game telemetry may fail until it is back"
}

Write-Host ""
Write-Host "=== Telemetry stack ==="
Write-Host "Offline (local tests):  http://127.0.0.1:8787/ingest"
Write-Host "Roblox (in-game):       $railwayIngest"
Write-Host ""
Write-Host "Test offline ingest:"
Write-Host '  powershell -File tools/test_offline_ingest.ps1'
Write-Host ""
Write-Host "Stop local relay: close this window or end the python telemetry_relay process."
Write-Host "Press Ctrl+C to exit this status script (local relay keeps running in background)."
Write-Host ""

while ($true) {
    $localOk = Test-RelayHealth "http://127.0.0.1:8787"
    $remoteOk = Test-RelayHealth "https://alleral-telemetry-production.up.railway.app"
    $stamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$stamp] local=$localOk railway=$remoteOk"
    Start-Sleep -Seconds 30
}
