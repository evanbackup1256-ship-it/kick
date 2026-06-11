# Embed loader.luau into launch.luau so players always have a working fallback.
# Run after changing loader.luau:
#   powershell -ExecutionPolicy Bypass -File tools/bundle_launch.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$loaderPath = Join-Path $root "loader.luau"
$launchPath = Join-Path $root "launch.luau"
$loadPath = Join-Path $root "load.luau"
$runPath = Join-Path $root "run.luau"
$bootstrapPath = Join-Path $root "bootstrap.luau"
$pastePath = Join-Path $root "paste.luau"
$templatePath = Join-Path $root "launch.template.luau"

if (-not (Test-Path $loaderPath)) {
    Write-Error "Missing loader.luau"
}
if (-not (Test-Path $templatePath)) {
    Write-Error "Missing launch.template.luau"
}

$loader = Get-Content $loaderPath -Raw
if ($loader -notmatch 'LOADER_VERSION = "([^"]+)"') {
    Write-Error "Could not read LOADER_VERSION from loader.luau"
}
$version = $Matches[1]

$open = '[==['
$close = ']==]'
if ($loader -match '\]==\]') {
    $open = '[===['
    $close = '===]'
    if ($loader -match '\===\]') {
        Write-Error "loader.luau contains ]===]; increase long-string delimiter"
    }
}

$template = Get-Content $templatePath -Raw
$embedded = @"
local EMBEDDED_LOADER_VERSION = "$version"
local EMBEDDED_LOADER = $open
$loader
$close

"@

if ($template -notmatch '--EMBED_LOADER_HERE--') {
    Write-Error "launch.template.luau is missing --EMBED_LOADER_HERE-- placeholder"
}

$launch = $template.Replace("--EMBED_LOADER_HERE--", $embedded.TrimEnd())
Set-Content -Path $launchPath -Value $launch -Encoding UTF8 -NoNewline
foreach ($dest in @($loadPath, $runPath, $bootstrapPath, $pastePath)) {
    Copy-Item -Path $launchPath -Destination $dest -Force
}
Write-Host "[ok] Bundled loader v$version into launch.luau ($($launch.Length) bytes)"
Write-Host "[ok] Copied launch.luau -> load.luau, run.luau, bootstrap.luau, paste.luau"
