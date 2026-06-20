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
$fallbackFields = @(
    @{ Key = "core"; Prop = "core" },
    @{ Key = "telemetry"; Prop = "telemetry" },
    @{ Key = "analytics"; Prop = "analytics" },
    @{ Key = "helpers"; Prop = "helpers" },
    @{ Key = "weao"; Prop = "weao" },
    @{ Key = "security"; Prop = "security" },
    @{ Key = "access"; Prop = "access" },
    @{ Key = "uiVersion"; Prop = "uiVersion" },
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

& (Join-Path $PSScriptRoot "build_merged_bootstrap.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$manifestSrc = Join-Path $root "cfg/scripts_manifest.json"
$siteSrc = Join-Path $root "cfg/site.json"
$siteRaw = Get-Content $siteSrc -Raw -Encoding UTF8
$siteRaw = [regex]::Replace($siteRaw, '"loaderVersion"\s*:\s*"[^"]*"', ('"loaderVersion": "' + $release.loader + '"'))
$siteRaw = [regex]::Replace($siteRaw, 'bootstrap\.luau\?v=[^"&]+&t=', 'bootstrap.luau?t=')
$siteRaw = [regex]::Replace($siteRaw, 'bootstrap\.luau\?v=[^"&]+', 'bootstrap.luau')
$siteRaw = [regex]::Replace($siteRaw, '"coreVersion"\s*:\s*"[^"]*"', ('"coreVersion": "' + $release.core + '"'))
$uiLibrary = if ($release.ui) { $release.ui } else { "Linoria" }
$siteRaw = [regex]::Replace($siteRaw, '"uiLibrary"\s*:\s*"[^"]*"', ('"uiLibrary": "' + $uiLibrary + '"'))
$uiVersion = if ($release.uiVersion) { $release.uiVersion } else { "5.1.0" }
$siteRaw = [regex]::Replace($siteRaw, '"uiVersion"\s*:\s*"[^"]*"', ('"uiVersion": "' + $uiVersion + '"'))
if ($hashBumpNeeded) {
    $siteRaw = [regex]::Replace($siteRaw, '"updatedAt"\s*:\s*"[^"]*"', ('"updatedAt": "' + $updatedAt + '"'))
}
Write-Utf8NoBom $siteSrc $siteRaw

$siteDir = Join-Path $root "relay" "site"
Push-Location $siteDir
try {
    npm run build | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "relay/site build failed" }
} finally {
    Pop-Location
}

Write-Host "release bumped and site built"
