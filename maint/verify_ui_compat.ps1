$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failed = @()

function Fail($msg) { $script:failed += $msg; Write-Host "FAIL: $msg" -ForegroundColor Red }
function Pass($msg) { Write-Host "OK: $msg" -ForegroundColor Green }

$neverloseUi = Get-Content (Join-Path $root "hub/neverlose_ui.luau") -Raw
$coreUi = Get-Content (Join-Path $root "hub/core_ui.luau") -Raw
$library = Get-Content (Join-Path $root "ui/neverlose/library.lua") -Raw

if ($coreUi -match 'function Core\.resolveUiWindow') {
    Pass "core_ui exposes resolveUiWindow"
} else {
    Fail "core_ui missing Core.resolveUiWindow"
}

if ($coreUi -match 'function Core\.buildUiSection[\s\S]*?_rawWindow = window\._rawWindow') {
    Pass "buildUiSection forwards _rawWindow"
} else {
    Fail "buildUiSection must expose _rawWindow for tab boot"
}

if ($neverloseUi -match 'Core\.resolveUiWindow') {
    Pass "neverlose_ui buildUiTab uses resolveUiWindow"
} else {
    Fail "neverlose_ui buildUiTab must call Core.resolveUiWindow"
}

if ($coreUi -match 'function Core\.createStubUiGroup[\s\S]*?stub\.CreateDivider\s*=') {
    Pass "createStubUiGroup exposes CreateDivider"
} else {
    Fail "createStubUiGroup missing CreateDivider noop"
}

if ($coreUi -match 'function group:CreateDivider\(\)[\s\S]*?groupbox\.CreateDivider') {
    Pass "wrapUiGroup guards CreateDivider"
} else {
    Fail "wrapUiGroup must guard groupbox CreateDivider"
}

$menuKeybindBlock = [regex]::Match(
    $library,
    'Settings:Keybind\(\{[\s\S]*?Name = "Menu Keybind"[\s\S]*?\}\)'
).Value
if ($menuKeybindBlock -eq "") {
    Fail "Settings Menu Keybind block not found in library.lua"
} elseif ($menuKeybindBlock -match 'Window:SetOpen') {
    Fail "Menu Keybind callback must not call Window:SetOpen"
} else {
    Pass "Menu Keybind callback avoids Window:SetOpen"
}

if ($library -match 'function Window:SetOpen[\s\S]*?Name = "Menu Keybind"') {
    Pass "Window:SetOpen defined before Menu Keybind registration"
} else {
    Fail "Window:SetOpen must be defined before Settings Menu Keybind is created"
}

if ($library -match 'Library\.EnsureGuiRoot = function') {
    Pass "library.lua exposes EnsureGuiRoot"
} else {
    Fail "library.lua missing EnsureGuiRoot for ScreenGui bootstrap"
}

if ($library -match 'Library\.Window = function\(self, Data\)[\s\S]*?self:EnsureGuiRoot\(\)') {
    Pass "Window bootstraps GUI root before building"
} else {
    Fail "Library.Window must call EnsureGuiRoot before creating frames"
}

if ($neverloseUi -match 'neverloseLibraryLive') {
    Pass "neverlose_ui validates cached library Holder"
} else {
    Fail "neverlose_ui must reject stale cached libraries missing Holder"
}

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "UI compatibility checks failed ($($failed.Count))." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All UI compatibility checks passed." -ForegroundColor Green
exit 0
