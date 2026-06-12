$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failed = @()

function Fail($msg) { $script:failed += $msg; Write-Host "FAIL: $msg" -ForegroundColor Red }
function Pass($msg) { Write-Host "OK: $msg" -ForegroundColor Green }

$release = Get-Content (Join-Path $root "cfg/release.json") -Raw | ConvertFrom-Json
$manifest = Get-Content (Join-Path $root "cfg/scripts_manifest.json") -Raw | ConvertFrom-Json
$loader = Get-Content (Join-Path $root "loader.luau") -Raw
$HashBumpMessagePattern = '^Update release commit hash'

$head = (git -C $root rev-parse --short HEAD).Trim()
$parent = ""
$parentOut = git -C $root rev-parse --short HEAD~1 2>$null
if ($LASTEXITCODE -eq 0 -and $parentOut) {
    $parent = $parentOut.Trim()
}
$lastMsg = (git -C $root log -1 --pretty=%s).Trim()

if ($release.commit -eq $head) {
    Pass "release commit $head matches HEAD"
} elseif ($parent -and $release.commit -eq $parent -and $lastMsg -match $HashBumpMessagePattern) {
    Pass "release commit $parent matches HEAD~1 (hash bump on $head)"
} else {
    Fail "release.json commit ($($release.commit)) out of sync with HEAD ($head) - run maint/sync_repo.ps1"
}

$commitMatch = [regex]::Match($loader, '(?m)^\tcommit = "([^"]+)"')
if ($commitMatch.Success) {
    $fallbackCommit = $commitMatch.Groups[1].Value
    if ($fallbackCommit -ne $release.commit) {
        Fail "loader RELEASE_FALLBACK.commit ($fallbackCommit) != release.json ($($release.commit))"
    } else {
        Pass "loader RELEASE_FALLBACK.commit $($release.commit)"
    }
} else {
    Fail "loader.luau missing RELEASE_FALLBACK.commit"
}

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

$corePath = Join-Path $root "hub/core_base.luau"
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

$weaoPath = Join-Path $root "hub/weao.luau"
$weao = Get-Content $weaoPath -Raw
if ($weao -match 'Weao\.VERSION = "([^"]+)"') {
    $weaoVer = $Matches[1]
    if ($release.weao -and $weaoVer -ne $release.weao) {
        Fail "weao ($weaoVer) != release.json ($($release.weao))"
    } else {
        Pass "weao $weaoVer"
    }
} else {
    Fail "hub/weao.luau missing Weao.VERSION"
}

$telemetryPath = Join-Path $root "hub/telemetry.luau"
$telemetry = Get-Content $telemetryPath -Raw
if ($telemetry -match 'Telemetry\.Version = "([^"]+)"') {
    $telemetryVer = $Matches[1]
    if ($release.telemetry -and $telemetryVer -ne $release.telemetry) {
        Fail "telemetry ($telemetryVer) != release.json ($($release.telemetry))"
    } else {
        Pass "telemetry $telemetryVer"
    }
} else {
    Fail "hub/telemetry.luau missing Telemetry.Version"
}

$securityPath = Join-Path $root "hub/security.luau"
$security = Get-Content $securityPath -Raw
if ($security -match 'Security\.VERSION = "([^"]+)"') {
    $securityVer = $Matches[1]
    if ($release.security -and $securityVer -ne $release.security) {
        Fail "security ($securityVer) != release.json ($($release.security))"
    } else {
        Pass "security $securityVer"
    }
} else {
    Fail "hub/security.luau missing Security.VERSION"
}

$weaoCfgPath = Join-Path $root "cfg/weao.json"
if (-not (Test-Path $weaoCfgPath)) {
    Fail "cfg/weao.json missing"
} else {
    $weaoCfg = Get-Content $weaoCfgPath -Raw | ConvertFrom-Json
    if ($weaoCfg.userAgent -ne "WEAO-3PService") {
        Fail "cfg/weao.json userAgent must be WEAO-3PService"
    } elseif ($weaoCfg.bases.Count -lt 1) {
        Fail "cfg/weao.json must list WEAO bases"
    } else {
        Pass "cfg/weao.json"
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

function Same-FileText($a, $b) {
    if (-not (Test-Path $a) -or -not (Test-Path $b)) { return $false }
    return ((Get-FileHash $a -Algorithm SHA256).Hash -eq (Get-FileHash $b -Algorithm SHA256).Hash)
}

$deployCopies = @(
    @{ Name = "scripts_manifest.json"; Cfg = "cfg/scripts_manifest.json"; Relay = "relay/scripts_manifest.json"; Backend = "backend/scripts_manifest.json" },
    @{ Name = "site.json"; Cfg = "cfg/site.json"; Relay = "relay/site.json"; Backend = "backend/site.json" }
)
foreach ($item in $deployCopies) {
    $cfgPath = Join-Path $root $item.Cfg
    $relayPath = Join-Path $root $item.Relay
    $backendPath = Join-Path $root $item.Backend
    if (-not (Same-FileText $cfgPath $relayPath)) {
        Fail "$($item.Name) drift: cfg vs relay (run maint/sync_repo.ps1)"
    } elseif (-not (Same-FileText $cfgPath $backendPath)) {
        Fail "$($item.Name) drift: cfg vs backend (run maint/sync_repo.ps1)"
    } else {
        Pass "$($item.Name) copies match cfg"
    }
}

$sitePath = Join-Path $root "cfg/site.json"
$site = Get-Content $sitePath -Raw | ConvertFrom-Json
if ($site.loaderVersion -ne $release.loader) {
    Fail "site.json loaderVersion ($($site.loaderVersion)) != release.json ($($release.loader))"
} else {
    Pass "site loaderVersion $($site.loaderVersion)"
}
if ($site.coreVersion -ne $release.core) {
    Fail "site.json coreVersion ($($site.coreVersion)) != release.json ($($release.core))"
} else {
    Pass "site coreVersion $($site.coreVersion)"
}
if ($release.sydePatch -and $site.sydePatch -ne $release.sydePatch) {
    Fail "site.json sydePatch ($($site.sydePatch)) != release.json ($($release.sydePatch))"
} elseif ($release.sydePatch) {
    Pass "site sydePatch $($site.sydePatch)"
}

$analyticsPath = Join-Path $root "hub/analytics.luau"
$analytics = Get-Content $analyticsPath -Raw
if ($analytics -match 'Analytics\.Version = "([^"]+)"') {
    $analyticsVer = $Matches[1]
    if ($release.analytics -and $analyticsVer -ne $release.analytics) {
        Fail "analytics ($analyticsVer) != release.json ($($release.analytics))"
    } else {
        Pass "analytics $analyticsVer"
    }
} else {
    Fail "hub/analytics.luau missing Analytics.Version"
}

foreach ($pair in @(
    @{ File = "hub/helpers.luau"; Pattern = 'Helpers\.VERSION = "([^"]+)"'; Key = "helpers" },
    @{ File = "hub/access.luau"; Pattern = 'Access\.VERSION = "([^"]+)"'; Key = "access" }
)) {
    $path = Join-Path $root $pair.File
    $src = Get-Content $path -Raw
    if ($src -match $pair.Pattern) {
        $ver = $Matches[1]
        $expected = $release.($pair.Key)
        if ($expected -and $ver -ne $expected) {
            Fail "$($pair.Key) ($ver) != release.json ($expected)"
        } else {
            Pass "$($pair.Key) $ver"
        }
    } else {
        Fail "$($pair.File) missing version constant"
    }
}

$relayPy = Get-ChildItem (Join-Path $root "relay") -Filter "*.py" -File | ForEach-Object { $_.Name } | Sort-Object
$backendPy = Get-ChildItem (Join-Path $root "backend") -Filter "*.py" -File | ForEach-Object { $_.Name } | Sort-Object
$missingInBackend = Compare-Object $relayPy $backendPy | Where-Object { $_.SideIndicator -eq "<=" } | ForEach-Object { $_.InputObject }
if ($missingInBackend) {
    Fail "backend missing relay python files: $($missingInBackend -join ', ')"
} else {
    Pass "backend python files match relay"
}

foreach ($pyName in $relayPy) {
    $relayFile = Join-Path $root "relay/$pyName"
    $backendFile = Join-Path $root "backend/$pyName"
    if (-not (Same-FileText $relayFile $backendFile)) {
        Fail "python drift: relay/$pyName != backend/$pyName (run maint/sync_repo.ps1)"
    }
}
if ($relayPy.Count -gt 0) {
    Pass "relay/backend python copies identical"
}

$forbiddenFiles = @(
    "load.luau",
    "launch.luau",
    "bootstrap.luau",
    "run.luau",
    "entry_redirect.luau",
    "launch.template.luau",
    "README.md",
    "relay/Dockerfile.repo",
    "relay/railway.toml"
)

foreach ($rel in $forbiddenFiles) {
    if (Test-Path (Join-Path $root $rel)) {
        Fail "forbidden file exists: $rel"
    }
}

$rootLuau = @(git -C $root ls-files | Where-Object { $_ -match '^[^/]+\.luau$' } | ForEach-Object { Split-Path $_ -Leaf } | Sort-Object -Unique)
if ($rootLuau.Count -ne 1 -or $rootLuau[0] -ne "loader.luau") {
    Fail "tracked repo root must contain only loader.luau (found: $($rootLuau -join ', '))"
} else {
    Pass "single tracked root entry loader.luau"
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
    Where-Object { $_.FullName -notmatch '\\ui\\' -and $_.Name -ne 'verify_versions.ps1' } |
    ForEach-Object {
        $text = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $text) { return }
        if ($_.Name -ne 'loader.luau' -and $text -match 'kick@main') {
            Fail "$($_.FullName.Replace($root + '\', '')) contains legacy mirror path kick@main"
        }
        if ($_.Name -ne 'loader.luau' -and $text -match '\.net/gh/') {
            Fail "$($_.FullName.Replace($root + '\', '')) contains legacy .net/gh/ mirror URL"
        }
    }

Get-ChildItem -Path $root -Recurse -Include *.luau,*.lua,*.ps1 -File |
    Where-Object { ($_.FullName -notmatch '\\ui\\') -and ($_.Name -ne 'loader.luau') -and ($_.Name -ne 'verify_versions.ps1') } |
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
