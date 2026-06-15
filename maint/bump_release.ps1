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

$HashBumpMessagePattern = '^Update release commit hash'

$releasePath = Join-Path $root "cfg/release.json"
$head = (git -C $root rev-parse --short HEAD).Trim()
$parent = ""
$parentOut = git -C $root rev-parse --short HEAD~1 2>$null
if ($LASTEXITCODE -eq 0 -and $parentOut) {
    $parent = $parentOut.Trim()
}
$lastMsg = (git -C $root log -1 --pretty=%s).Trim()
$updatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss'Z'")
$release = Get-Content $releasePath -Raw | ConvertFrom-Json

$hashBumpNeeded = $true
if ($release.commit -eq $head) {
    $hashBumpNeeded = $false
    Write-Host "release.commit already matches HEAD ($head) - hash bump skipped"
} elseif ($parent -and $release.commit -eq $parent -and $lastMsg -match $HashBumpMessagePattern) {
    $hashBumpNeeded = $false
    Write-Host "release.commit already matches HEAD~1 ($parent) after hash bump - hash bump skipped"
}

$commit = $release.commit
$loaderPath = Join-Path $root "loader.luau"
$loaderRaw = Get-Content $loaderPath -Raw -Encoding UTF8
$loaderRaw = [regex]::Replace($loaderRaw, 'local LOADER_VERSION = "[^"]+"', ('local LOADER_VERSION = "' + $release.loader + '"'))
$loaderRaw = [regex]::Replace($loaderRaw, '(?m)^\tloader = "[^"]+"', ("`tloader = `"$($release.loader)`""), 1)
if ($null -ne $release.rayfieldVersion) {
    $rayfieldVersionVal = [int]$release.rayfieldVersion
    $loaderRaw = [regex]::Replace($loaderRaw, 'local RAYFIELD_VERSION = \d+', ('local RAYFIELD_VERSION = ' + $rayfieldVersionVal))
}
$fallbackFields = @(
    @{ Key = "core"; Prop = "core" },
    @{ Key = "telemetry"; Prop = "telemetry" },
    @{ Key = "analytics"; Prop = "analytics" },
    @{ Key = "helpers"; Prop = "helpers" },
    @{ Key = "weao"; Prop = "weao" },
    @{ Key = "security"; Prop = "security" },
    @{ Key = "access"; Prop = "access" },
    @{ Key = "alleral"; Prop = "alleral" },
    @{ Key = "windui"; Prop = "windui" },
    @{ Key = "ui"; Prop = "ui" }
)
foreach ($field in $fallbackFields) {
    $val = $release.($field.Prop)
    if ($null -ne $val -and "$val" -ne "") {
        $loaderRaw = [regex]::Replace(
            $loaderRaw,
            ('(?m)^\t' + [regex]::Escape($field.Key) + ' = "[^"]+"'),
            ("`t$($field.Key) = `"$val`""),
            1
        )
    }
}
if ($hashBumpNeeded) {
    $commit = $head
    $release.commit = $commit
    $release.updatedAt = $updatedAt
    Write-Utf8NoBom $releasePath (($release | ConvertTo-Json -Depth 6) + "`n")
    Write-Host "release.json -> commit=$commit updatedAt=$updatedAt"
} else {
    Write-Host "release.json commit remains $commit"
}
$commitRx = [regex]::new('(?m)^\tcommit = "[^"]+"')
$loaderRaw = $commitRx.Replace($loaderRaw, ("`tcommit = `"$commit`""), 1)
Write-Utf8NoBom $loaderPath $loaderRaw
Write-Host "loader.luau LOADER_VERSION -> $($release.loader)"
Write-Host "loader.luau RELEASE_FALLBACK.commit -> $commit"

$manifestSrc = Join-Path $root "cfg/scripts_manifest.json"
$siteSrc = Join-Path $root "cfg/site.json"
$siteRaw = Get-Content $siteSrc -Raw -Encoding UTF8
$siteRaw = [regex]::Replace($siteRaw, '"loaderVersion"\s*:\s*"[^"]*"', ('"loaderVersion": "' + $release.loader + '"'))
$siteRaw = [regex]::Replace($siteRaw, '"coreVersion"\s*:\s*"[^"]*"', ('"coreVersion": "' + $release.core + '"'))
$uiLibrary = if ($release.ui) { $release.ui } else { "Rayfield" }
$siteRaw = [regex]::Replace($siteRaw, '"uiLibrary"\s*:\s*"[^"]*"', ('"uiLibrary": "' + $uiLibrary + '"'))
$uiVersion = if ($release.alleral) { $release.alleral } elseif ($release.windui) { $release.windui } else { "5.2.0-rayfield" }
$siteRaw = [regex]::Replace($siteRaw, '"uiVersion"\s*:\s*"[^"]*"', ('"uiVersion": "' + $uiVersion + '"'))
if ($null -ne $release.rayfieldVersion) {
    $rayfieldVersionVal = [int]$release.rayfieldVersion
    if ($siteRaw -match '"rayfieldVersion"\s*:\s*\d+') {
        $siteRaw = [regex]::Replace($siteRaw, '"rayfieldVersion"\s*:\s*\d+', ('"rayfieldVersion": ' + $rayfieldVersionVal))
    } else {
        $siteRaw = [regex]::Replace(
            $siteRaw,
            '("uiVersion"\s*:\s*"[^"]*"\s*,)',
            ('$1' + "`n  ""rayfieldVersion"": " + $rayfieldVersionVal + ",")
        )
    }
}
if ($hashBumpNeeded) {
    $siteRaw = [regex]::Replace($siteRaw, '"updatedAt"\s*:\s*"[^"]*"', ('"updatedAt": "' + $updatedAt + '"'))
}
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

$siteDir = Join-Path $relayDir "site"
Push-Location $siteDir
try {
    $env:SKIP_BACKEND_SYNC = "1"
    npm run build | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "relay/site build failed" }
} finally {
    Pop-Location
}
Sync-Tree (Join-Path $siteDir "out") (Join-Path $backendDir "site")

if ($hashBumpNeeded) {
    $generatedMarker = @"
GENERATED - do not edit files in backend/ directly.
Edit relay/ and cfg/, then run: maint/sync_repo.ps1
Synced at: $updatedAt
Commit: $commit
"@
    Write-Utf8NoBom (Join-Path $backendDir "GENERATED.txt") ($generatedMarker + "`n")
}

$rootRailway = Join-Path $root "railway.toml"
if (Test-Path $rootRailway) {
    Copy-IfChanged $rootRailway (Join-Path $backendDir "railway.toml")
}

Write-Host "cfg + relay + backend deploy bundle synced"
