$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failures = 0

function Pass($msg) { Write-Host "OK: $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; $script:failures++ }

$alleralUi = Get-Content (Join-Path $root "hub/alleral_ui.luau") -Raw
if ($alleralUi -match 'loadMaclib') { Pass "alleral_ui loads MacLib UI library" } else { Fail "alleral_ui missing loadMaclib bootstrap" }
if ($alleralUi -match 'Core\.UI_LIBRARY = "Maclib"') { Pass "alleral_ui declares Maclib as UI library" } else { Fail "alleral_ui missing Maclib UI_LIBRARY" }

$maclibSource = Join-Path $root "ui/maclib/source.luau"
if (Test-Path $maclibSource) {
    Pass "ui/maclib source present"
    $maclib = Get-Content $maclibSource -Raw
} else {
    Fail "ui/maclib/source.luau missing"
    $maclib = ""
}

$maclibContracts = @(
    @{ Pattern = 'ALLERAL_MACLIB_VERSION = 3'; Message = 'MacLib version is 3' },
    @{ Pattern = 'function MacLib:Window'; Message = 'MacLib exposes Window' },
    @{ Pattern = 'function SectionFunctions:Toggle'; Message = 'MacLib Toggle present' },
    @{ Pattern = 'function SectionFunctions:Slider'; Message = 'MacLib Slider present' },
    @{ Pattern = 'function SectionFunctions:Dropdown'; Message = 'MacLib Dropdown present' },
    @{ Pattern = 'function WindowFunctions:Notify'; Message = 'MacLib exposes Notify toasts' },
    @{ Pattern = 'function TabFunctions:Section'; Message = 'MacLib tab sections present' }
)

foreach ($contract in $maclibContracts) {
    if ($maclib -match $contract.Pattern) { Pass $contract.Message } else { Fail $contract.Message }
}

$loader = Get-Content (Join-Path $root "loader.luau") -Raw
if ($loader -match 'ensureMaclibSource|ensureUiSource|ensureFlexUiSource') { Pass "loader prefetches UI source" } else { Fail "loader missing UI source prefetch" }
if ($loader -match 'Core\.UI_LIBRARY = "Maclib"' -or $loader -match 'ui = "Maclib"' -or $loader -match 'ui = "Flexui"') { Pass "loader release fallback sets ui engine" } else { Fail "loader missing ui release config" }

if ($failures -gt 0) {
    Write-Host "`n$failures UI compatibility check(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "`nAll UI compatibility checks passed." -ForegroundColor Green
