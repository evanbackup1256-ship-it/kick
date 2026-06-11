# Optional: embed core/alleral_core.luau into loader.luau for offline-only builds.
# Default GitHub loader stays small (~55KB) so Volt can self-update.
# Run after changing core/alleral_core.luau:
#   powershell -ExecutionPolicy Bypass -File tools/bundle_core.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$loaderPath = Join-Path $root "loader.luau"
$corePath = Join-Path $root "core/alleral_core.luau"

if (-not (Test-Path $loaderPath)) { Write-Error "Missing loader.luau" }
if (-not (Test-Path $corePath)) { Write-Error "Missing core/alleral_core.luau" }

$loader = Get-Content $loaderPath -Raw
$core = Get-Content $corePath -Raw
$version = "null"
if ($core -match 'Core\.VERSION\s*=\s*"([^"]+)"') {
    $version = '"' + $Matches[1] + '"'
}

$level = 1
while ($core -match ('\]=' + ('=' * $level) + '\]')) { $level++ }
$eq = '=' * $level
$embedded = @"
local EMBEDDED_CORE_VERSION = $version
local EMBEDDED_CORE = [$eq
$core
$eq]
"@

$pattern = '(?s)--EMBED_CORE_HERE--.*?--END_EMBED_CORE--'
if ($loader -notmatch $pattern) {
    Write-Error "loader.luau is missing --EMBED_CORE_HERE-- / --END_EMBED_CORE-- markers"
}

$loader = [regex]::Replace($loader, $pattern, $embedded.TrimEnd())
Set-Content -Path $loaderPath -Value $loader -NoNewline
Write-Host "Embedded core $version into loader.luau ($($core.Length) bytes)"
