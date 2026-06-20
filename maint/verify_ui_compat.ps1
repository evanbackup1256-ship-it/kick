$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failures = 0

function Pass($msg) { Write-Host "OK: $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; $script:failures++ }

$alleralUi = Get-Content (Join-Path $root "hub/alleral_ui.luau") -Raw
if ($alleralUi -match 'Core\.loadUi') { Pass "alleral_ui defines loadUi" } else { Fail "alleral_ui missing loadUi" }
if ($alleralUi -match 'Core\.createUiGroupbox') { Pass "alleral_ui defines createUiGroupbox" } else { Fail "alleral_ui missing createUiGroupbox" }
if ($alleralUi -match 'Core\.UI_LIBRARY\s*=\s*"Rayfield"') { Pass "alleral_ui declares Rayfield as active UI library" } else { Fail "alleral_ui missing Rayfield UI_LIBRARY" }
if ($alleralUi -match 'function Core\.buildUiWindow') { Pass "alleral_ui defines buildUiWindow" } else { Fail "alleral_ui missing buildUiWindow" }
if ($alleralUi -match 'function Core\.buildUiTab') { Pass "alleral_ui defines buildUiTab" } else { Fail "alleral_ui missing buildUiTab" }
if ($alleralUi -match 'function Core\.buildUiGroup') { Pass "alleral_ui defines buildUiGroup" } else { Fail "alleral_ui missing buildUiGroup" }
if ($alleralUi -match 'Core\.wrapUiGroup\s*=') { Pass "alleral_ui defines wrapUiGroup" } else { Fail "alleral_ui missing wrapUiGroup" }
if ($alleralUi -match 'function Core\.buildUiSection') { Pass "alleral_ui defines buildUiSection" } else { Fail "alleral_ui missing buildUiSection" }
$unclosedInlineFunctions = Select-String -Path (Join-Path $root "hub/alleral_ui.luau") -Pattern 'function .*return ' | Where-Object { $_.Line -notmatch '\bend\s*$' }
if ($unclosedInlineFunctions) {
    foreach ($match in $unclosedInlineFunctions) {
        Fail "alleral_ui inline function missing end at line $($match.LineNumber)"
    }
} else {
    Pass "alleral_ui inline return functions close with end"
}

$rayfieldSource = Join-Path $root "ui/rayfield/source.luau"
if (Test-Path $rayfieldSource) {
    Pass "ui/rayfield source present"
    $rayfield = Get-Content $rayfieldSource -Raw
} else {
    Fail "ui/rayfield/source.luau missing"
    $rayfield = ""
}

$rayfieldContracts = @(
    @{ Pattern = 'ALLERAL_RAYFIELD_VERSION\s*=\s*\d+'; Message = 'Rayfield version marker present' },
    @{ Pattern = 'bootRayfield|boot'; Message = 'Rayfield boot function present' },
    @{ Pattern = 'sirius\.menu/rayfield|shlexware/Rayfield'; Message = 'Rayfield source fetches from valid CDN' }
)

foreach ($contract in $rayfieldContracts) {
    if ($rayfield -match $contract.Pattern) { Pass $contract.Message } else { Fail $contract.Message }
}

$loader = Get-Content (Join-Path $root "loader.luau") -Raw
if ($loader -match 'ensureRayfieldSource') { Pass "loader prefetches Rayfield UI source" } else { Fail "loader missing Rayfield source prefetch" }
if ($loader -match 'ui = "Rayfield"') { Pass "loader release fallback sets Rayfield ui engine" } else { Fail "loader missing Rayfield ui release config" }

$release = Get-Content (Join-Path $root "cfg/release.json") -Raw | ConvertFrom-Json
if ($release.ui -eq "Rayfield") { Pass "release.json ui is Rayfield" } else { Fail "release.json ui is not Rayfield" }

if ($failures -gt 0) {
    Write-Host "`n$failures UI compatibility check(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "`nAll UI compatibility checks passed." -ForegroundColor Green
