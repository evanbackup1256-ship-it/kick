$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failed = @()

function Fail($msg) { $script:failed += $msg; Write-Host "FAIL: $msg" -ForegroundColor Red }
function Pass($msg) { Write-Host "OK: $msg" -ForegroundColor Green }

$alleralUi = Get-Content (Join-Path $root "hub/alleral_ui.luau") -Raw
$coreUi = Get-Content (Join-Path $root "hub/core_ui.luau") -Raw
$loader = Get-Content (Join-Path $root "loader.luau") -Raw

if ($coreUi -match 'function Core\.resolveUiWindow') { Pass "core_ui exposes resolveUiWindow" } else { Fail "core_ui missing Core.resolveUiWindow" }
if ($alleralUi -match 'Alleral UI layer') { Pass "alleral_ui declares UI layer marker" } else { Fail "alleral_ui missing Alleral UI layer marker" }
if ($alleralUi -match 'loadRayfield') { Pass "alleral_ui loads Rayfield UI library" } else { Fail "alleral_ui missing loadRayfield bootstrap" }

$rayfieldSource = Join-Path $root "ui/rayfield/source.luau"
if (Test-Path $rayfieldSource) {
    Pass "ui/rayfield source present"
    $rayfield = Get-Content $rayfieldSource -Raw
} else {
    Fail "ui/rayfield/source.luau missing"
    $rayfield = ""
}

$rayfieldContracts = @(
    @{ Pattern = 'ALLERAL_RAYFIELD_VERSION = 2'; Message = 'Rayfield version is 2' },
    @{ Pattern = 'function RayfieldLibrary:CreateWindow'; Message = 'Rayfield exposes CreateWindow' },
    @{ Pattern = 'function Tab:CreateToggle'; Message = 'Rayfield CreateToggle present' },
    @{ Pattern = 'function Tab:CreateSlider'; Message = 'Rayfield CreateSlider present' },
    @{ Pattern = 'function Tab:CreateDropdown'; Message = 'Rayfield CreateDropdown present' },
    @{ Pattern = 'function RayfieldLibrary:Notify'; Message = 'Rayfield exposes Notify toasts' },
    @{ Pattern = 'function Tab:SetParent\(parent\)'; Message = 'Rayfield tabs expose scoped control parenting' },
    @{ Pattern = 'function DropdownSettings:Refresh'; Message = 'dropdown handles support Refresh' },
    @{ Pattern = 'function Window:GetState\(\)'; Message = 'window state reads open flag' },
    @{ Pattern = 'function Window:CreateTab'; Message = 'window CreateTab creates tabs' }
)

foreach ($contract in $rayfieldContracts) {
    if ($rayfield -match $contract.Pattern) { Pass $contract.Message } else { Fail $contract.Message }
}

if ($alleralUi -match 'pcall\(handle\.Refresh, handle, nextValues\)') { Pass "adapter refreshes dropdown options" } else { Fail "adapter dropdown Refresh contract missing" }
if ($alleralUi -match 'function Core\.loadUi') { Pass "alleral_ui exposes Core.loadUi" } else { Fail "alleral_ui missing Core.loadUi" }
if ($alleralUi -match 'function Core\.buildUiWindow') { Pass "alleral_ui overrides buildUiWindow" } else { Fail "alleral_ui missing buildUiWindow override" }
if ($loader -match 'ensureRayfieldSource') { Pass "loader prefetches Rayfield source" } else { Fail "loader missing ensureRayfieldSource" }
if ($loader -match 'purgeLegacyHubUiFiles') { Pass "loader purges legacy hub/ui workspace files" } else { Fail "loader missing purgeLegacyHubUiFiles" }

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "UI compat check failed: $($failed.Count) problems." -ForegroundColor Red
    exit 1
}

Write-Host ""
Pass "All UI compat checks passed"
exit 0
