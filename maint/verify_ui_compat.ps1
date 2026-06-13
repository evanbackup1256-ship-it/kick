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

if ($alleralUi -match 'loadSyde') {
    Pass "alleral_ui loads Syde UI library"
} else {
    Fail "alleral_ui missing loadSyde bootstrap"
}

$sydeSource = Join-Path $root "ui/syde/source.luau"
if (Test-Path $sydeSource) {
    Pass "ui/syde source present"
    $syde = Get-Content $sydeSource -Raw
} else {
    Fail "ui/syde/source.luau missing"
    $syde = ""
}

$sydeContracts = @(
    @{ Pattern = 'ALLERAL_SYDE_PATCH = 28'; Message = 'Syde patch version is 28' },
    @{ Pattern = 'function syde:DisconnectAll\(\)'; Message = 'Syde disconnects tracked runtime connections' },
    @{ Pattern = 'function data:Refresh\(options, value\)'; Message = 'dropdown handles support Refresh' },
    @{ Pattern = 'Options = sydeNormalizeSliderOptions\(Options\)'; Message = 'slider inputs are normalized' },
    @{ Pattern = 'data\.Instance = textinput'; Message = 'text input handles expose their instance' },
    @{ Pattern = 'data\.Instance = button'; Message = 'button handles expose their instance' }
)

foreach ($contract in $sydeContracts) {
    if ($syde -match $contract.Pattern) {
        Pass $contract.Message
    } else {
        Fail $contract.Message
    }
}

if ($syde -notmatch 'ColorPicker\.Linkable = ColorPicker\.Linkable or true') {
    Pass "ColorPicker preserves explicit Linkable=false"
} else {
    Fail "ColorPicker overwrites explicit Linkable=false"
}

if ($alleralUi -match 'pcall\(handle\.Refresh, handle, values, pick\)') {
    Pass "adapter refreshes dropdown options and selection together"
} else {
    Fail "adapter dropdown Refresh contract missing"
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

if (-not (Test-Path (Join-Path $root "ui/alleral_maclib"))) {
    Pass "legacy alleral_maclib tree removed"
} else {
    Fail "ui/alleral_maclib still exists"
}

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "UI compat check failed: $($failed.Count) problems." -ForegroundColor Red
    exit 1
}

Write-Host ""
Pass "All UI compat checks passed"
exit 0
