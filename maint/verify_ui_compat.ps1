$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failed = @()

function Fail($msg) { $script:failed += $msg; Write-Host "FAIL: $msg" -ForegroundColor Red }
function Pass($msg) { Write-Host "OK: $msg" -ForegroundColor Green }

$alleralUi = Get-Content (Join-Path $root "hub/alleral_ui.luau") -Raw
$coreUi = Get-Content (Join-Path $root "hub/core_ui.luau") -Raw
$loader = Get-Content (Join-Path $root "loader.luau") -Raw

if ($coreUi -match 'function Core\.resolveUiWindow') {
    Pass "core_ui exposes resolveUiWindow"
} else {
    Fail "core_ui missing Core.resolveUiWindow"
}

if ($alleralUi -match 'Alleral UI layer') {
    Pass "alleral_ui declares UI layer marker"
} else {
    Fail "alleral_ui missing Alleral UI layer marker"
}

if ($alleralUi -match 'MACLIB_URL') {
    Pass "alleral_ui loads Maclib from release URL"
} else {
    Fail "alleral_ui missing Maclib URL bootstrap"
}

if ($alleralUi -match 'function Core\.loadUi') {
    Pass "alleral_ui exposes Core.loadUi"
} else {
    Fail "alleral_ui missing Core.loadUi"
}

if ($alleralUi -match 'function Core\.buildUiWindow') {
    Pass "alleral_ui overrides buildUiWindow"
} else {
    Fail "alleral_ui missing buildUiWindow override"
}

if ($alleralUi -match 'function Core\.createWindUiGroupbox') {
    Pass "alleral_ui exposes createWindUiGroupbox adapter"
} else {
    Fail "alleral_ui missing createWindUiGroupbox adapter"
}

if (Test-Path (Join-Path $root "hub/ui_spr.luau")) {
    Pass "ui_spr spring module present"
} else {
    Fail "hub/ui_spr.luau missing"
}

if (Test-Path (Join-Path $root "hub/ui_motion.luau")) {
    Pass "ui_motion animation layer present"
} else {
    Fail "hub/ui_motion.luau missing"
}

if ($alleralUi -match 'ui_motion\.luau') {
    Pass "alleral_ui loads ui_motion layer"
} else {
    Fail "alleral_ui missing ui_motion bootstrap"
}

if ($loader -match 'purgeLegacyHubUiFiles') {
    Pass "loader purges legacy hub/ui workspace files"
} else {
    Fail "loader missing purgeLegacyHubUiFiles"
}

if (-not (Test-Path (Join-Path $root "hub/ui"))) {
    Pass "legacy hub/ui tree removed from repo"
} else {
    Fail "hub/ui still exists - remove vendored UI stack"
}

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "UI compat check failed: $($failed.Count) problems." -ForegroundColor Red
    exit 1
}

Write-Host ""
Pass "All UI compat checks passed"
exit 0
