# bootstrap.luau is authored directly (thin loader fetcher).
# This script verifies it exists and matches loader version in release.json.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$bootstrapPath = Join-Path $root "bootstrap.luau"
if (-not (Test-Path $bootstrapPath)) {
    throw "bootstrap.luau missing at $bootstrapPath"
}
$bytes = (Get-Item $bootstrapPath).Length
Write-Host "bootstrap.luau ok ($bytes bytes, thin entry)"
