# Verify loader, core, manifest, game scripts, WEAO, and no legacy entry points.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failed = @()

function Fail($msg) { $script:failed += $msg; Write-Host "FAIL: $msg" -ForegroundColor Red }
function Pass($msg) { Write-Host "OK: $msg" -ForegroundColor Green }

$release = Get-Content (Join-Path $root "config/release.json") -Raw | ConvertFrom-Json
$manifest = Get-Content (Join-Path $root "config/scripts_manifest.json") -Raw | ConvertFrom-Json
$loader = Get-Content (Join-Path $root "loader.luau") -Raw

if ($loader -match 'LOADER_VERSION = "([^"]+)"') {
    $loaderVer = $Matches[1]
    if ($loaderVer -ne $release.loader) {
        Fail "loader.luau ($loaderVer) != release.json ($($release.loader))"
    } else {
        Pass "loader $loaderVer"
    }
} else {
    Fail "loader.luau missing LOADER_VERSION"
}

$corePath = Join-Path $root "core/alleral_core.luau"
$core = Get-Content $corePath -Raw
if ($core -match 'Core\.VERSION = "([^"]+)"') {
    $coreVer = $Matches[1]
    if ($coreVer -ne $release.core) {
        Fail "core ($coreVer) != release.json ($($release.core))"
    } else {
        Pass "core $coreVer"
    }
} else {
    Fail "core missing Core.VERSION"
}

$weaoPath = Join-Path $root "core/weao.luau"
$weao = Get-Content $weaoPath -Raw
if ($weao -match 'Weao\.VERSION = "([^"]+)"') {
    $weaoVer = $Matches[1]
    if ($release.weao -and $weaoVer -ne $release.weao) {
        Fail "weao ($weaoVer) != release.json ($($release.weao))"
    } else {
        Pass "weao $weaoVer"
    }
} else {
    Fail "core/weao.luau missing Weao.VERSION"
}

$weaoCfgPath = Join-Path $root "config/weao.json"
if (-not (Test-Path $weaoCfgPath)) {
    Fail "config/weao.json missing"
} else {
    $weaoCfg = Get-Content $weaoCfgPath -Raw | ConvertFrom-Json
    if ($weaoCfg.userAgent -ne "WEAO-3PService") {
        Fail "config/weao.json userAgent must be WEAO-3PService per docs.weao.xyz"
    } elseif ($weaoCfg.bases.Count -lt 1) {
        Fail "config/weao.json must list WEAO bases"
    } else {
        Pass "config/weao.json"
    }
}

$gameFiles = @{
    kick_a_lucky_block      = "games/kick_a_lucky_block.luau"
    speed_keyboard_escape   = "games/speed_keyboard_escape.luau"
    slime_rng               = "games/slime_rng.luau"
    build_a_ring_farm       = "games/build_a_ring_farm.luau"
    survive_a_zombie_arena  = "games/survive_a_zombie_arena.luau"
}

foreach ($id in $gameFiles.Keys) {
    $path = Join-Path $root $gameFiles[$id]
    $src = Get-Content $path -Raw
    $manifestVer = $manifest.scripts.$id.version
    if ($src -match 'local VERSION = "([^"]+)"') {
        $gameVer = $Matches[1]
        if ($gameVer -ne $manifestVer) {
            Fail "$id game ($gameVer) != manifest ($manifestVer)"
        } else {
            Pass "$id v$gameVer"
        }
        if ($loader -notmatch ('id = "' + [regex]::Escape($id) + '"[\s\S]*?version = "' + [regex]::Escape($gameVer) + '"')) {
            Fail "$id version missing or mismatched in loader.luau GAMES table"
        }
    } else {
        Fail "$id missing local VERSION"
    }
}

$forbiddenFiles = @(
    "load.luau",
    "launch.luau",
    "bootstrap.luau",
    "run.luau",
    "entry_redirect.luau",
    "launch.template.luau",
    "tools/bundle_launch.ps1",
    "tools/bundle_core.ps1"
)

foreach ($rel in $forbiddenFiles) {
    if (Test-Path (Join-Path $root $rel)) {
        Fail "forbidden legacy file exists: $rel"
    }
}

$rootLuau = @(Get-ChildItem -Path $root -Filter "*.luau" -File | ForEach-Object { $_.Name })
if ($rootLuau.Count -ne 1 -or $rootLuau[0] -ne "loader.luau") {
    Fail "repo root must contain only loader.luau (found: $($rootLuau -join ', '))"
} else {
    Pass "single root entry loader.luau"
}

$legacyPatterns = @(
    "EMBEDDED_CORE = \[=",
    'LOADER_VERSION = "3\.',
    'LOADER_VERSION = "4\.'
)

foreach ($pattern in $legacyPatterns) {
    if ($loader -match $pattern) {
        Fail "loader.luau contains legacy pattern: $pattern"
    }
}

Get-ChildItem -Path $root -Recurse -Include *.luau,*.lua,*.json,*.md,*.ps1 -File |
    Where-Object { $_.FullName -notmatch '\\vendor\\rayfield\\' } |
    ForEach-Object {
        $text = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $text) { return }
        if ($text -match 'https?://[^\s"''`]*jsdelivr[^\s"''`]*') {
            Fail "$($_.FullName.Replace($root + '\', '')) contains jsDelivr URL"
        }
    }

Get-ChildItem -Path $root -Recurse -Include *.luau,*.lua,*.ps1 -File |
    Where-Object { ($_.FullName -notmatch '\\vendor\\') -and ($_.Name -ne 'loader.luau') -and ($_.Name -ne 'verify_versions.ps1') } |
    ForEach-Object {
        $text = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $text) { return }
        if ($text -match '\[Alleral Loader v3\.' -or $text -match 'LOADER_VERSION = "3\.') {
            Fail "$($_.FullName.Replace($root + '\', '')) contains v3.x loader markers"
        }
        if ($text -match 'EMBEDDED_LOADER =') {
            Fail "$($_.FullName.Replace($root + '\', '')) contains EMBEDDED_LOADER"
        }
    }

if ($failed.Count -gt 0) {
    Write-Host "`n$($failed.Count) check(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "`nAll version checks passed." -ForegroundColor Green
