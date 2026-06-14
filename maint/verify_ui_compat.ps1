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
    @{ Pattern = 'ALLERAL_SYDE_PATCH = 34'; Message = 'Syde patch version is 34' },
    @{ Pattern = 'local Minihome = sydeFindChild\(ui\._root'; Message = 'Minihome lookup tolerates missing executor assets' },
    @{ Pattern = 'local paraTitle, paraContent = sydeParagraphParts\(Para\)'; Message = 'paragraph templates use compatible child lookup' },
    @{ Pattern = 'return ui\._root\.Enabled ~= false and window\.Visible == true'; Message = 'window state reads the real ScreenGui visibility' },
    @{ Pattern = 'local needsOpen = window\.Visible ~= true or uiclosed'; Message = 'SetState detects initially hidden asset roots' },
    @{ Pattern = 'ui\._root\.Enabled = true\s+window\.Visible = true'; Message = 'SetState forces the real GUI root visible' },
    @{ Pattern = '__newindex = function\(_, key, value\)'; Message = 'UI proxy forwards ScreenGui property writes' },
    @{ Pattern = 'function initelement:SetParent\(parent\)'; Message = 'Syde tabs expose scoped control parenting' },
    @{ Pattern = '\.Parent = defaultParent'; Message = 'Syde controls honor scoped group parents' },
    @{ Pattern = 'local data = \{ Instance = Label \}'; Message = 'native labels expose update handles' },
    @{ Pattern = 'for _, child in ipairs\(page:GetDescendants\(\)\) do'; Message = 'search discovers controls inside grouped columns' },
    @{ Pattern = 'for _, otherPicker in pairs\(Page:GetDescendants\(\)\) do'; Message = 'linked color pickers work across grouped columns' },
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

$upstreamSyde = Get-Content (Join-Path $root "ui/syde/upstream.luau") -Raw
if ($upstreamSyde -match "\['Accent'\]\s*=\s*Color3\.fromRGB\(255, 151, 227\)" -and
    $upstreamSyde -match "\['HitBox'\]\s*=\s*Color3\.fromRGB\(255, 151, 227\)") {
    Pass "vendored Syde retains the original accent colors"
} else {
    Fail "vendored Syde default colors differ from upstream"
}

$gameUiSources = @(
    "games/kick_a_lucky_block.luau",
    "games/build_a_ring_farm.luau",
    "games/slime_rng.luau"
)
foreach ($relativePath in $gameUiSources) {
    $gameUiSource = Get-Content (Join-Path $root $relativePath) -Raw
    if ($gameUiSource -match 'Theme\s*=\s*"Default"' -and $gameUiSource -notmatch 'Theme\s*=\s*"Private"') {
        Pass "$relativePath starts with the original Syde theme"
    } else {
        Fail "$relativePath overrides the original Syde theme"
    }
}

if ($syde -match 'task\.wait\(0\.45\)\s+ModalInstance:Destroy\(\)' -and
    ([regex]::Matches($syde, 'task\.wait\(0\.7\)\s+dimOverlay\.Visible = false')).Count -eq 2) {
    Pass "modal close and dim timings match upstream Syde"
} else {
    Fail "modal animation timings differ from upstream Syde"
}

if ($alleralUi -match 'pcall\(rawWindow\.SetState, rawWindow, true\)' -and $alleralUi -notmatch '(?m)^\s*window:Toggle\(\)\s*$') {
    Pass "Syde windows open explicitly without blind toggle"
} else {
    Fail "Syde window creation can toggle an initially-open window closed"
}

if ($alleralUi -match 'row\.Name = "AlleralColumns"' -and
    $alleralUi -match 'return Core\.createWindUiGroupbox\(rawTab, uiBundle, group\)') {
    Pass "Syde adapter preserves requested two-column group layout"
} else {
    Fail "Syde adapter does not preserve requested group columns"
}

if ($alleralUi -match 'local handle = sydeTab:Label\(text\)' -and
    $alleralUi -notmatch 'local handle = sydeTab:Paragraph\(\{\s*Title = "",\s*Content = text') {
    Pass "status and divider rows use compact native labels"
} else {
    Fail "status rows still use oversized paragraph cards"
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
