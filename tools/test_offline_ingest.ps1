# POST a test event to the local offline relay (127.0.0.1:8787).
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root "backend\.env"

if (-not (Test-Path $envFile)) {
    Write-Host "Missing backend/.env - run tools/setup_telemetry.ps1 first."
    exit 1
}

$apiKey = (Get-Content $envFile | Where-Object { $_ -match "^TELEMETRY_API_KEY=" }) -replace "TELEMETRY_API_KEY=", ""
if (-not $apiKey) {
    Write-Host "TELEMETRY_API_KEY not set in backend/.env"
    exit 1
}

$body = @{
    event = "inject_loaded"
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss+00:00")
    sessionId = "offline-test"
    player = @{ name = "OfflineTest"; userId = 1; displayName = "Offline"; accountAge = 0 }
    context = @{
        executor = "powershell"
        loaderVersion = "5.4.6"
        gameName = "Offline Relay Test"
        scriptName = "test"
        scriptVersion = "1"
        placeId = 0
        jobId = "offline"
    }
} | ConvertTo-Json -Depth 6

$headers = @{
    "X-Alleral-Key" = $apiKey
    "Content-Type" = "application/json"
}

$resp = Invoke-RestMethod -Uri "http://127.0.0.1:8787/ingest" -Method Post -Headers $headers -Body $body -ErrorAction Stop
Write-Host "[ok] Local ingest: $($resp.status) - check Discord for the test event"
