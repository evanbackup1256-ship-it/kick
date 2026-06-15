$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root "ui/rayfield/source.luau"
$c = [IO.File]::ReadAllText($path)

if ($c -notmatch "ALLERAL_RAYFIELD_VERSION") {
    $c = "local ALLERAL_RAYFIELD_VERSION = 1`r`n`r`n" + $c
}

$appleDefault = @'
		Default = {
			TextColor = Color3.fromRGB(255, 255, 255),

			Background = Color3.fromRGB(28, 28, 30),
			Topbar = Color3.fromRGB(44, 44, 46),
			Shadow = Color3.fromRGB(0, 0, 0),

			NotificationBackground = Color3.fromRGB(44, 44, 46),
			NotificationActionsBackground = Color3.fromRGB(58, 58, 60),

			TabBackground = Color3.fromRGB(58, 58, 60),
			TabStroke = Color3.fromRGB(72, 72, 74),
			TabBackgroundSelected = Color3.fromRGB(0, 122, 255),
			TabTextColor = Color3.fromRGB(235, 235, 245),
			SelectedTabTextColor = Color3.fromRGB(255, 255, 255),

			ElementBackground = Color3.fromRGB(44, 44, 46),
			ElementBackgroundHover = Color3.fromRGB(58, 58, 60),
			SecondaryElementBackground = Color3.fromRGB(28, 28, 30),
			ElementStroke = Color3.fromRGB(72, 72, 74),
			SecondaryElementStroke = Color3.fromRGB(58, 58, 60),

			SliderBackground = Color3.fromRGB(72, 72, 74),
			SliderProgress = Color3.fromRGB(0, 122, 255),
			SliderStroke = Color3.fromRGB(10, 132, 255),

			ToggleBackground = Color3.fromRGB(58, 58, 60),
			ToggleEnabled = Color3.fromRGB(52, 199, 89),
			ToggleDisabled = Color3.fromRGB(72, 72, 74),
			ToggleEnabledStroke = Color3.fromRGB(48, 209, 88),
			ToggleDisabledStroke = Color3.fromRGB(99, 99, 102),
			ToggleEnabledOuterStroke = Color3.fromRGB(72, 72, 74),
			ToggleDisabledOuterStroke = Color3.fromRGB(58, 58, 60),

			DropdownSelected = Color3.fromRGB(58, 58, 60),
			DropdownUnselected = Color3.fromRGB(44, 44, 46),

			InputBackground = Color3.fromRGB(28, 28, 30),
			InputStroke = Color3.fromRGB(72, 72, 74),
			PlaceholderColor = Color3.fromRGB(152, 152, 157)
		},

		Apple = nil,
'@

$defaultStart = $c.IndexOf("`t`tDefault = {")
$defaultEnd = $c.IndexOf("`t`t},", $defaultStart) + 4
if ($defaultStart -lt 0 -or $defaultEnd -lt 4) {
    throw "Could not locate Default theme block"
}
$c = $c.Remove($defaultStart, $defaultEnd - $defaultStart).Insert($defaultStart, $appleDefault)

$c = $c -replace "if not useStudio and math\.random\(10\) == 1 then", "if false then -- ALLERAL: analytics heartbeat disabled"

$oldIcons = "local Icons = useStudio and require(script.Parent.icons) or loadWithTimeout('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/icons.lua')"
$newIcons = @"
local Icons = nil
if getgenv and type(getgenv()._AlleralRayfieldIcons) == "table" then
	Icons = getgenv()._AlleralRayfieldIcons
elseif useStudio and script.Parent then
	Icons = require(script.Parent.icons)
else
	Icons = loadWithTimeout('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/icons.lua')
end
"@
$c = $c.Replace($oldIcons, $newIcons)

if ($c -notmatch "correctBuild = true -- ALLERAL") {
    $anchor = "local rayfieldDestroyed = false"
    $insert = @"

if ALLERAL_RAYFIELD_VERSION then
	correctBuild = true -- ALLERAL: suppress asset build mismatch for vendored Rayfield
end
"@
    $c = $c.Replace($anchor, $anchor + $insert)
}

$c = $c -replace "\.Parent = TabPage", ".Parent = elementParent()"

$tabHook = @"
		local Tab = {}

		local function elementParent()
			return Tab._AlleralParent or TabPage
		end

		function Tab:SetParent(parent)
			Tab._AlleralParent = parent
		end
		Tab.Page = TabPage
		Tab._TabButton = TabButton
		function Tab:Select()
			if Elements.UIPageLayout.CurrentPage ~= TabPage then
				Elements.UIPageLayout:JumpTo(TabPage)
			end
			for _, OtherTabButton in ipairs(TabList:GetChildren()) do
				if OtherTabButton.Name ~= "Template" and OtherTabButton.ClassName == "Frame" and OtherTabButton ~= TabButton and OtherTabButton.Name ~= "Placeholder" then
					OtherTabButton.BackgroundColor3 = SelectedTheme.TabBackground
					if OtherTabButton:FindFirstChild("Title") then
						OtherTabButton.Title.TextColor3 = SelectedTheme.TabTextColor
					end
					if OtherTabButton:FindFirstChild("Image") then
						OtherTabButton.Image.ImageColor3 = SelectedTheme.TabTextColor
					end
					OtherTabButton.BackgroundTransparency = 0.7
				end
			end
			TabButton.BackgroundColor3 = SelectedTheme.TabBackgroundSelected
			if TabButton:FindFirstChild("Title") then
				TabButton.Title.TextColor3 = SelectedTheme.SelectedTabTextColor
			end
			if TabButton:FindFirstChild("Image") then
				TabButton.Image.ImageColor3 = SelectedTheme.SelectedTabTextColor
			end
			TabButton.BackgroundTransparency = 0
		end
		function Tab:Section(name)
			return Tab:CreateSection(name)
		end

"@
$c = $c.Replace("`t`tlocal Tab = {}`r`n`r`n`t`t-- Button", $tabHook + "`t`t-- Button")

$windowHook = @"
	Window.Main = Main
	function Window:SetState(visible)
		RayfieldLibrary:SetVisibility(visible ~= false)
	end
	function Window:GetState()
		return RayfieldLibrary:IsVisible()
	end
	function Window:Toggle()
		RayfieldLibrary:SetVisibility(not RayfieldLibrary:IsVisible())
	end
	Window._rayfieldTabGroup = {
		Tab = function(_, opts)
			opts = type(opts) == "table" and opts or { Name = tostring(opts or "Tab") }
			return Window:CreateTab(opts.Name, opts.Image or opts.Icon)
		end,
	}
	Window._sydeTabGroup = Window._rayfieldTabGroup
	Window._macTabGroup = Window._rayfieldTabGroup

"@
$c = $c.Replace("`treturn Window`r`nend", $windowHook + "`treturn Window`r`nend")

$c = $c -replace "if reporter and getSetting\(""System"", ""usageAnalytics""\) then", "if reporter and getSetting(`"System`", `"usageAnalytics`") and not ALLERAL_RAYFIELD_VERSION then"

if ($c -notmatch "RayfieldLibrary\.__AlleralPatch") {
    $c = $c.Replace("return RayfieldLibrary", "RayfieldLibrary.__AlleralPatch = ALLERAL_RAYFIELD_VERSION`r`n`r`nreturn RayfieldLibrary")
}

# iOS-style toggles: hide switch shadow on Default (Apple) theme
$c = $c.Replace("if SelectedTheme ~= RayfieldLibrary.Theme.Default then`r`n`t`t`tToggle.Switch.Shadow.Visible = false`r`n`t`tend", "Toggle.Switch.Shadow.Visible = false")

[IO.File]::WriteAllText($path, $c)
Write-Host "Patched ui/rayfield/source.luau ($($c.Length) bytes)"
