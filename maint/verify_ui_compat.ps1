$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failures = 0

function Pass($msg) { Write-Host "OK: $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; $script:failures++ }

$alleralUi = Get-Content (Join-Path $root "hub/alleral_ui.luau") -Raw
if ($alleralUi -match 'loadOnyx') { Pass "alleral_ui loads Onyx resource library" } else { Fail "alleral_ui missing loadOnyx resource bootstrap" }
if ($alleralUi -match 'loadIris') { Pass "alleral_ui loads Iris UI library" } else { Fail "alleral_ui missing loadIris bootstrap" }
if ($alleralUi -match 'Core\.UI_LIBRARY = "Iris"') { Pass "alleral_ui declares Iris as active UI library" } else { Fail "alleral_ui missing Iris UI_LIBRARY" }

$onyxSource = Join-Path $root "ui/onyx/source.luau"
if (Test-Path $onyxSource) {
    Pass "ui/onyx source present"
    $onyx = Get-Content $onyxSource -Raw
} else {
    Fail "ui/onyx/source.luau missing"
    $onyx = ""
}

$onyxContracts = @(
    @{ Pattern = 'ALLERAL_ONYX_VERSION = 1'; Message = 'Onyx adapter version is 1' },
    @{ Pattern = 'MacLib\.__FusionStack = true'; Message = 'Fusion stack marker present' },
    @{ Pattern = 'MacLib\.__OnyxUi = true'; Message = 'Onyx adapter marker present' },
    @{ Pattern = 'function MacLib:Window'; Message = 'Onyx exposes MacLib:Window' },
    @{ Pattern = 'SetSpringMotion'; Message = 'Onyx Spring motion toggle present' },
    @{ Pattern = 'function SectionFunctions:Dropdown'; Message = 'Onyx Dropdown present' },
    @{ Pattern = 'function SectionFunctions:Slider'; Message = 'Onyx Slider present' }
)

foreach ($contract in $onyxContracts) {
    if ($onyx -match $contract.Pattern) { Pass $contract.Message } else { Fail $contract.Message }
}

$irisSource = Join-Path $root "ui/iris/source.luau"
if (Test-Path $irisSource) {
    Pass "ui/iris source present"
    $iris = Get-Content $irisSource -Raw
} else {
    Fail "ui/iris/source.luau missing"
    $iris = ""
}

$irisContracts = @(
    @{ Pattern = 'ALLERAL_IRIS_VERSION = 2'; Message = 'Iris exploit adapter version is 2' },
    @{ Pattern = 'MacLib\.__IrisExploitUi = true'; Message = 'Iris exploit overlay marker present' },
    @{ Pattern = 'AttachExploitMirror'; Message = 'Iris exploit mirror hook present' }
)

foreach ($contract in $irisContracts) {
    if ($iris -match $contract.Pattern) { Pass $contract.Message } else { Fail $contract.Message }
}

$loader = Get-Content (Join-Path $root "loader.luau") -Raw
if ($loader -match 'ensureOnyxSource|ensureUiSource') { Pass "loader prefetches UI source" } else { Fail "loader missing UI source prefetch" }
if ($loader -match 'ui = "Iris"') { Pass "loader release fallback sets Iris ui engine" } else { Fail "loader missing Iris ui release config" }

$release = Get-Content (Join-Path $root "cfg/release.json") -Raw | ConvertFrom-Json
if ($release.ui -eq "Iris") { Pass "release.json ui is Iris" } else { Fail "release.json ui is not Iris" }

if ($failures -gt 0) {
    Write-Host "`n$failures UI compatibility check(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "`nAll UI compatibility checks passed." -ForegroundColor Green
