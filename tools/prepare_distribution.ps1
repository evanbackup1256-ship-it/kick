# Strip secrets before sharing Alleral Hub. Run from repo root.
$root = Split-Path -Parent $PSScriptRoot

$toScrub = @(
    (Join-Path $root "backend\.env"),
    (Join-Path $root "config\owner_telemetry.luau")
)

foreach ($path in $toScrub) {
    if (-not (Test-Path $path)) { continue }
    if ($path -like "*\.env") {
        @"
# NEVER share this file. Fill in locally after distribution.

DISCORD_WEBHOOK_URL=
TELEMETRY_API_KEY=
TELEMETRY_BRAND=Alleral Ops
TELEMETRY_HOST=0.0.0.0
TELEMETRY_PORT=8787
"@ | Set-Content -Path $path -Encoding UTF8
        Write-Host "Scrubbed $path"
    }
    if ($path -like "*owner_telemetry.luau") {
        Copy-Item (Join-Path $root "config\owner_telemetry.example.luau") $path -Force
        Write-Host "Reset $path to disabled example"
    }
}

Write-Host ""
Write-Host "Distribution prep done. Do NOT include ../Alleral-Private/ in any zip."
Write-Host "Verify: git status should not show backend/.env or owner_telemetry.luau"
