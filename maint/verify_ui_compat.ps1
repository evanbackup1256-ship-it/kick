$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failures = 0

function Pass($msg) { Write-Host "OK: $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; $script:failures++ }

$alleralUi = Get-Content (Join-Path $root "hub/alleral_ui.luau") -Raw
if ($alleralUi -match 'Core\.loadUi') { Pass "alleral_ui defines loadUi" } else { Fail "alleral_ui missing loadUi" }
if ($alleralUi -match 'Core\.createWindUiGroupbox') { Pass "alleral_ui defines createWindUiGroupbox" } else { Fail "alleral_ui missing createWindUiGroupbox" }
if ($alleralUi -match 'Core\.UI_LIBRARY\s*=\s*"Fluent"') { Pass "alleral_ui declares Fluent as active UI library" } else { Fail "alleral_ui missing Fluent UI_LIBRARY" }
if ($alleralUi -match 'function Core\.buildUiWindow') { Pass "alleral_ui defines buildUiWindow" } else { Fail "alleral_ui missing buildUiWindow" }
if ($alleralUi -match 'function Core\.buildUiTab') { Pass "alleral_ui defines buildUiTab" } else { Fail "alleral_ui missing buildUiTab" }
if ($alleralUi -match 'function Core\.buildUiGroup') { Pass "alleral_ui defines buildUiGroup" } else { Fail "alleral_ui missing buildUiGroup" }
if ($alleralUi -match 'function Core\.wrapUiGroup') { Pass "alleral_ui defines wrapUiGroup" } else { Fail "alleral_ui missing wrapUiGroup" }
if ($alleralUi -match 'function Core\.buildUiSection') { Pass "alleral_ui defines buildUiSection" } else { Fail "alleral_ui missing buildUiSection" }

$fluentSource = Join-Path $root "ui/fluent/source.luau"
if (Test-Path $fluentSource) {
    Pass "ui/fluent source present"
    $fluent = Get-Content $fluentSource -Raw
} else {
    Fail "ui/fluent/source.luau missing"
    $fluent = ""
}

$fluentContracts = @(
    @{ Pattern = 'ALLERAL_FLUENT_VERSION\s*=\s*\d+'; Message = 'Fluent version marker present' },
    @{ Pattern = 'bootFluent|boot'; Message = 'Fluent boot function present' },
    @{ Pattern = 'dawid-scripts/Fluent'; Message = 'Fluent fetches from dawid-scripts/Fluent' }
)

foreach ($contract in $fluentContracts) {
    if ($fluent -match $contract.Pattern) { Pass $contract.Message } else { Fail $contract.Message }
}

$rayfieldSource = Join-Path $root "ui/rayfield/source.luau"
if (Test-Path $rayfieldSource) { Fail "ui/rayfield/source.luau should be deleted" } else { Pass "ui/rayfield/source.luau removed" }

$onyxSource = Join-Path $root "ui/onyx/source.luau"
if (Test-Path $onyxSource) { Fail "ui/onyx/source.luau should be deleted" } else { Pass "ui/onyx/source.luau removed" }

$maclibSource = Join-Path $root "ui/maclib/source.luau"
if (Test-Path $maclibSource) { Fail "ui/maclib/source.luau should be deleted" } else { Pass "ui/maclib/source.luau removed" }

$flexuiSource = Join-Path $root "ui/flexui/source.luau"
if (Test-Path $flexuiSource) { Fail "ui/flexui/source.luau should be deleted" } else { Pass "ui/flexui/source.luau removed" }

$loader = Get-Content (Join-Path $root "loader.luau") -Raw
if ($loader -match 'ensureFluentSource') { Pass "loader prefetches Fluent UI source" } else { Fail "loader missing Fluent source prefetch" }
if ($loader -match 'ui = "Fluent"') { Pass "loader release fallback sets Fluent ui engine" } else { Fail "loader missing Fluent ui release config" }
if ($loader -notmatch 'ensureOnyxSource') { Pass "loader removed Onyx source management" } else { Fail "loader still has Onyx source management" }
if ($loader -notmatch 'ensureIrisSource') { Pass "loader removed Iris source management" } else { Fail "loader still has Iris source management" }

$release = Get-Content (Join-Path $root "cfg/release.json") -Raw | ConvertFrom-Json
if ($release.ui -eq "Fluent") { Pass "release.json ui is Fluent" } else { Fail "release.json ui is not Fluent" }
if (-not $release.onyxVersion) { Pass "release.json onyxVersion removed" } else { Fail "release.json still has onyxVersion" }

if ($failures -gt 0) {
    Write-Host "`n$failures UI compatibility check(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "`nAll UI compatibility checks passed." -ForegroundColor Green
