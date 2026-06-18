$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failures = 0

function Pass($msg) { Write-Host "OK: $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; $script:failures++ }

$alleralUi = Get-Content (Join-Path $root "hub/alleral_ui.luau") -Raw
if ($alleralUi -match 'Core\.loadUi') { Pass "alleral_ui defines loadUi" } else { Fail "alleral_ui missing loadUi" }
if ($alleralUi -match 'Core\.createWindUiGroupbox') { Pass "alleral_ui defines createWindUiGroupbox" } else { Fail "alleral_ui missing createWindUiGroupbox" }
if ($alleralUi -match 'Core\.UI_LIBRARY = "Rayfield"') { Pass "alleral_ui declares Rayfield as active UI library" } else { Fail "alleral_ui missing Rayfield UI_LIBRARY" }
if ($alleralUi -match 'function Core\.buildUiWindow') { Pass "alleral_ui defines buildUiWindow" } else { Fail "alleral_ui missing buildUiWindow" }
if ($alleralUi -match 'function Core\.buildUiTab') { Pass "alleral_ui defines buildUiTab" } else { Fail "alleral_ui missing buildUiTab" }
if ($alleralUi -match 'function Core\.buildUiGroup') { Pass "alleral_ui defines buildUiGroup" } else { Fail "alleral_ui missing buildUiGroup" }
if ($alleralUi -match 'function Core\.wrapUiGroup') { Pass "alleral_ui defines wrapUiGroup" } else { Fail "alleral_ui missing wrapUiGroup" }

$rayfieldSource = Join-Path $root "ui/rayfield/source.luau"
if (Test-Path $rayfieldSource) {
    Pass "ui/rayfield source present"
    $rayfield = Get-Content $rayfieldSource -Raw
} else {
    Fail "ui/rayfield/source.luau missing"
    $rayfield = ""
}

$rayfieldContracts = @(
    @{ Pattern = 'ALLERAL_RAYFIELD_VERSION = \d+'; Message = 'Rayfield version marker present' },
    @{ Pattern = 'bootRayfield|boot'; Message = 'Rayfield boot function present' },
    @{ Pattern = 'SiriusSoftwareLtd/Rayfield'; Message = 'Rayfield fetches from SiriusSoftwareLtd' }
)

foreach ($contract in $rayfieldContracts) {
    if ($rayfield -match $contract.Pattern) { Pass $contract.Message } else { Fail $contract.Message }
}

$onyxSource = Join-Path $root "ui/onyx/source.luau"
if (Test-Path $onyxSource) { Fail "ui/onyx/source.luau should be deleted" } else { Pass "ui/onyx/source.luau removed" }

$maclibSource = Join-Path $root "ui/maclib/source.luau"
if (Test-Path $maclibSource) { Fail "ui/maclib/source.luau should be deleted" } else { Pass "ui/maclib/source.luau removed" }

$flexuiSource = Join-Path $root "ui/flexui/source.luau"
if (Test-Path $flexuiSource) { Fail "ui/flexui/source.luau should be deleted" } else { Pass "ui/flexui/source.luau removed" }

$loader = Get-Content (Join-Path $root "loader.luau") -Raw
if ($loader -match 'ensureRayfieldSource') { Pass "loader prefetches Rayfield UI source" } else { Fail "loader missing Rayfield source prefetch" }
if ($loader -match 'ui = "Rayfield"') { Pass "loader release fallback sets Rayfield ui engine" } else { Fail "loader missing Rayfield ui release config" }
if ($loader -notmatch 'ensureOnyxSource') { Pass "loader removed Onyx source management" } else { Fail "loader still has Onyx source management" }
if ($loader -notmatch 'ensureIrisSource') { Pass "loader removed Iris source management" } else { Fail "loader still has Iris source management" }

$release = Get-Content (Join-Path $root "cfg/release.json") -Raw | ConvertFrom-Json
if ($release.ui -eq "Rayfield") { Pass "release.json ui is Rayfield" } else { Fail "release.json ui is not Rayfield" }
if (-not $release.onyxVersion) { Pass "release.json onyxVersion removed" } else { Fail "release.json still has onyxVersion" }

if ($failures -gt 0) {
    Write-Host "`n$failures UI compatibility check(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "`nAll UI compatibility checks passed." -ForegroundColor Green
