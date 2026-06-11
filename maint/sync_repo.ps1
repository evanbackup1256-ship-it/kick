$ErrorActionPreference = "Stop"
$here = $PSScriptRoot

Write-Host "=== bump_release ===" -ForegroundColor Cyan
& (Join-Path $here "bump_release.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`n=== verify_versions ===" -ForegroundColor Cyan
& (Join-Path $here "verify_versions.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`nRepo sync complete." -ForegroundColor Green
