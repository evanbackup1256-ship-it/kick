$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$loaderPath = Join-Path $root "loader.luau"
$bootstrapPath = Join-Path $root "bootstrap.luau"

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

if (-not (Test-Path $loaderPath)) {
    throw "loader.luau not found at $loaderPath"
}

$loaderRaw = Get-Content $loaderPath -Raw -Encoding UTF8
$bootstrapVer = "2.0.0"
if ($loaderRaw -match 'local BOOTSTRAP_VERSION = "([^"]+)"') {
    $bootstrapVer = $Matches[1]
}
$loaderVer = "unknown"
if ($loaderRaw -match 'local LOADER_VERSION = "([^"]+)"') {
    $loaderVer = $Matches[1]
}

$header = @"
-- Alleral merged bootstrap + loader
-- Bootstrap v$bootstrapVer / Loader v$loaderVer
-- One loadstring - no hub/bootstrap hop, no separate loader download on boot.
-- Generated from loader.luau by maint/build_merged_bootstrap.ps1

"@

if ($loaderRaw -match '^--!nocheck') {
    $body = $loaderRaw -replace '^--!nocheck\r?\n', ''
    $bootstrapRaw = $header + "--!nocheck`n" + $body
} else {
    $bootstrapRaw = $header + $loaderRaw
}

Write-Utf8NoBom $bootstrapPath $bootstrapRaw
Write-Host "bootstrap.luau <- loader.luau (merged, $($bootstrapRaw.Length) bytes)"
