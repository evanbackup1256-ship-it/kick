$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Copy-IfChanged([string]$Source, [string]$Dest) {
    $destDir = Split-Path -Parent $Dest
    if ($destDir -and -not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
    Copy-Item $Source $Dest -Force
}

$releasePath = Join-Path $root "cfg/release.json"
$commit = (git -C $root rev-parse --short HEAD).Trim()
$updatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss'Z'")
$release = Get-Content $releasePath -Raw | ConvertFrom-Json
$release.commit = $commit
$release.updatedAt = $updatedAt
Write-Utf8NoBom $releasePath (($release | ConvertTo-Json -Depth 6) + "`n")
Write-Host "release.json -> commit=$commit updatedAt=$updatedAt"

$loaderPath = Join-Path $root "loader.luau"
$loaderRaw = Get-Content $loaderPath -Raw -Encoding UTF8
$commitRx = [regex]::new('(?m)^\tcommit = "[^"]+"')
$loaderRaw = $commitRx.Replace($loaderRaw, ('commit = "' + $commit + '"'), 1)
Write-Utf8NoBom $loaderPath $loaderRaw
Write-Host "loader.luau RELEASE_FALLBACK.commit -> $commit"

$manifestSrc = Join-Path $root "cfg/scripts_manifest.json"
$siteSrc = Join-Path $root "cfg/site.json"
$siteRaw = Get-Content $siteSrc -Raw -Encoding UTF8
$siteRaw = [regex]::Replace($siteRaw, '"loaderVersion"\s*:\s*"[^"]*"', ('"loaderVersion": "' + $release.loader + '"'))
$siteRaw = [regex]::Replace($siteRaw, '"coreVersion"\s*:\s*"[^"]*"', ('"coreVersion": "' + $release.core + '"'))
$siteRaw = [regex]::Replace($siteRaw, '"updatedAt"\s*:\s*"[^"]*"', ('"updatedAt": "' + $updatedAt + '"'))
Write-Utf8NoBom $siteSrc $siteRaw

Copy-IfChanged $manifestSrc (Join-Path $root "relay/scripts_manifest.json")
Copy-IfChanged $siteSrc (Join-Path $root "relay/site.json")

$relayDir = Join-Path $root "relay"
$backendDir = Join-Path $root "backend"
New-Item -ItemType Directory -Force -Path $backendDir | Out-Null

foreach ($name in @("requirements.txt", "Dockerfile", "scripts_manifest.json", "site.json")) {
    Copy-IfChanged (Join-Path $relayDir $name) (Join-Path $backendDir $name)
}

Get-ChildItem -Path $relayDir -Filter "*.py" -File | ForEach-Object {
    Copy-IfChanged $_.FullName (Join-Path $backendDir $_.Name)
}

function Sync-Tree($src, $dest) {
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Copy-Item $src $dest -Recurse -Force
}
Sync-Tree (Join-Path $relayDir "site") (Join-Path $backendDir "site")

$generatedMarker = @"
GENERATED — do not edit files in backend/ directly.
Edit relay/ and cfg/, then run: maint/sync_repo.ps1
Synced at: $updatedAt
Commit: $commit
"@
Write-Utf8NoBom (Join-Path $backendDir "GENERATED.txt") ($generatedMarker + "`n")

$rootRailway = Join-Path $root "railway.toml"
if (Test-Path $rootRailway) {
    Copy-IfChanged $rootRailway (Join-Path $backendDir "railway.toml")
}

Write-Host "cfg + relay + backend deploy bundle synced"
