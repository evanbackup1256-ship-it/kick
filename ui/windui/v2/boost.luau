--[[
	Alleral UI V2 boost layer — themes, motion, glass, chrome, customization APIs.
	Loaded by ui/windui/arrrel.luau after the base patch initializes.
]]

return function(ctx)
	if type(ctx) ~= "table" or type(ctx.WindUI) ~= "table" then
		return false
	end

	local WindUI = ctx.WindUI
	local MAC = ctx.MAC
	local palette = ctx.palette
	local accent = ctx.accent
	local accentSoft = ctx.accentSoft
	local accentHot = ctx.accentHot
	local mergeTokens = ctx.mergeTokens
	local installThemes = ctx.installThemes
	local fullTheme = ctx.fullTheme
	local Motion = ctx.Motion
	local tween = ctx.tween
	local ANIM = ctx.ANIM
	local ensureStroke = ctx.ensureStroke
	local ensureCorner = ctx.ensureCorner
	local ensureGradient = ctx.ensureGradient
	local PROFILE_PRESETS = ctx.PROFILE_PRESETS
	local ACCENT_PRESETS = ctx.ACCENT_PRESETS
	local uiWarn = ctx.uiWarn or function(_, err)
		warn("[Alleral/V2] " .. tostring(err))
	end

	WindUI.ALLERAL_UI_V2 = true
	WindUI.ALLERAL_V2_FEATURES = WindUI.ALLERAL_V2_FEATURES or {}

	local V2 = WindUI.ALLERAL_V2_FEATURES
	V2.version = "2.1.3-alleral-v2"

	-- -------------------------------------------------------------------------
	-- V2 customization state
	-- -------------------------------------------------------------------------

	WindUI._AlleralGlassIntensity = math.clamp(tonumber(WindUI._AlleralGlassIntensity) or 0.55, 0, 1)
	WindUI._AlleralMotionProfile = WindUI._AlleralMotionProfile or "fluid"
	WindUI._AlleralTooltipStyle = WindUI._AlleralTooltipStyle or "rich"
	WindUI._AlleralNotifyStyle = WindUI._AlleralNotifyStyle or "glass"
	WindUI._AlleralChromeDepth = math.clamp(tonumber(WindUI._AlleralChromeDepth) or 0.65, 0, 1)
	WindUI._AlleralAmbientGlow = WindUI._AlleralAmbientGlow ~= false
	WindUI._AlleralTabAurora = WindUI._AlleralTabAurora ~= false
	WindUI._AlleralSectionLift = WindUI._AlleralSectionLift ~= false

	local MOTION_PROFILES = {
		reduced = { springScale = 0.35, jitter = 0, startup = false },
		snappy = { springScale = 1.15, jitter = 1, startup = true },
		fluid = { springScale = 1, jitter = 1, startup = true },
		bouncy = { springScale = 0.82, jitter = 1.2, startup = true },
		cinematic = { springScale = 0.72, jitter = 0.6, startup = true },
	}

	local TOOLTIP_STYLES = { "minimal", "card", "rich" }
	local NOTIFY_STYLES_V2 = { "glass", "rail", "banner", "pill" }

	local V2_ACCENTS = {
		Crimson = "#ff4d6d",
		Lime = "#84cc16",
		Sky = "#38bdf8",
		Gold = "#f59e0b",
		Plum = "#c084fc",
		Teal = "#2dd4bf",
		Blaze = "#fb923c",
		Mono = "#e4e4e7",
	}

	for name, hex in pairs(V2_ACCENTS) do
		ACCENT_PRESETS[name] = hex
	end

	PROFILE_PRESETS.cinema = {
		label = "Cinema",
		uiScale = 1.06,
		corner = 14,
		padding = 28,
		sidebar = 300,
		elementPad = 18,
		startup = true,
		touchFeedback = true,
		haptics = false,
		reducedMotion = false,
		notifyCompact = false,
	}
	PROFILE_PRESETS.ultrawide = {
		label = "Ultrawide",
		uiScale = 1,
		corner = 12,
		padding = 26,
		sidebar = 320,
		elementPad = 18,
		startup = true,
		touchFeedback = true,
		haptics = false,
		reducedMotion = false,
	}
	PROFILE_PRESETS.minimal = {
		label = "Minimal",
		uiScale = 0.92,
		corner = 8,
		padding = 16,
		sidebar = 220,
		elementPad = 12,
		startup = false,
		reducedMotion = true,
		notifyCompact = true,
		touchFeedback = false,
	}
	PROFILE_PRESETS.accessibility = {
		label = "Accessibility",
		uiScale = 1.08,
		corner = 10,
		padding = 26,
		sidebar = 290,
		elementPad = 20,
		startup = false,
		reducedMotion = true,
		notifyCompact = false,
		touchFeedback = true,
	}

	-- -------------------------------------------------------------------------
	-- V2 theme pack
	-- -------------------------------------------------------------------------

	local function registerV2Themes()
		if type(fullTheme) ~= "function" or type(installThemes) ~= "function" then
			return
		end
		local pack = {
			ArrrelObsidian = fullTheme(
				"ArrrelObsidian",
				Color3.fromHex("#8b5cf6"),
				Color3.fromHex("#050506"),
				Color3.fromHex("#0d0d12"),
				Color3.fromHex("#f5f5fa"),
				Color3.fromHex("#8b8b98"),
				Color3.fromHex("#a78bfa"),
				Color3.fromHex("#1a1a24")
			),
			ArrrelSynth = fullTheme(
				"ArrrelSynth",
				Color3.fromHex("#ff2fd6"),
				Color3.fromHex("#08040f"),
				Color3.fromHex("#120a1c"),
				Color3.fromHex("#ffeefe"),
				Color3.fromHex("#c084fc"),
				Color3.fromHex("#22d3ee"),
				Color3.fromHex("#2a1440")
			),
			ArrrelOcean = fullTheme(
				"ArrrelOcean",
				Color3.fromHex("#22d3ee"),
				Color3.fromHex("#030910"),
				Color3.fromHex("#0a1520"),
				Color3.fromHex("#ecfeff"),
				Color3.fromHex("#7dd3fc"),
				Color3.fromHex("#38bdf8"),
				Color3.fromHex("#102030")
			),
			ArrrelEmber = fullTheme(
				"ArrrelEmber",
				Color3.fromHex("#fb7185"),
				Color3.fromHex("#0a0406"),
				Color3.fromHex("#16080c"),
				Color3.fromHex("#fff1f2"),
				Color3.fromHex("#fda4af"),
				Color3.fromHex("#f97316"),
				Color3.fromHex("#241018")
			),
			ArrrelStealth = fullTheme(
				"ArrrelStealth",
				Color3.fromHex("#71717a"),
				Color3.fromHex("#030303"),
				Color3.fromHex("#0a0a0a"),
				Color3.fromHex("#fafafa"),
				Color3.fromHex("#a1a1aa"),
				Color3.fromHex("#52525b"),
				Color3.fromHex("#18181b")
			),
			ArrrelPaper = fullTheme(
				"ArrrelPaper",
				Color3.fromHex("#16a34a"),
				Color3.fromHex("#f4f4f5"),
				Color3.fromHex("#ffffff"),
				Color3.fromHex("#18181b"),
				Color3.fromHex("#71717a"),
				Color3.fromHex("#22c55e"),
				Color3.fromHex("#e4e4e7")
			),
			ArrrelVoid = fullTheme(
				"ArrrelVoid",
				Color3.fromHex("#7cf7ff"),
				Color3.fromHex("#000000"),
				Color3.fromHex("#050508"),
				Color3.fromHex("#eefcff"),
				Color3.fromHex("#6b7280"),
				Color3.fromHex("#53fc18"),
				Color3.fromHex("#101018")
			),
		}
		for themeName, tokens in pairs(pack) do
			if WindUI.Themes then
				WindUI.Themes[themeName] = mergeTokens(WindUI.Themes[themeName] or {}, tokens)
				WindUI.Themes[themeName].Name = themeName
			end
			if WindUI.AddTheme then
				pcall(WindUI.AddTheme, WindUI, tokens)
			end
		end
	end

	registerV2Themes()

	-- -------------------------------------------------------------------------
	-- V2 chrome
	-- -------------------------------------------------------------------------

	local function applyAmbientWindowGlow(main)
		if WindUI._AlleralAmbientGlow == false or not main or not main.Parent then
			return
		end
		local parent = main.Parent
		local glow = parent:FindFirstChild("AlleralV2Ambient")
		if not glow then
			glow = Instance.new("Frame")
			glow.Name = "AlleralV2Ambient"
			glow.BorderSizePixel = 0
			glow.ZIndex = math.max(0, main.ZIndex - 4)
			glow.Parent = parent
			ensureCorner(glow, UDim.new(0, (MAC.corner or 12) + 10))
		end
		local spread = 24 + math.floor(WindUI._AlleralChromeDepth * 18)
		glow.Size = UDim2.new(1, spread * 2, 1, spread * 2)
		glow.Position = UDim2.new(0, -spread, 0, -spread)
		glow.BackgroundColor3 = palette.accent
		glow.BackgroundTransparency = 1 - (0.04 + WindUI._AlleralGlassIntensity * 0.08)
		local gradient = ensureGradient(glow, "AlleralV2AmbientGradient", {
			ColorSequenceKeypoint.new(0, palette.accent),
			ColorSequenceKeypoint.new(0.5, palette.accentSoft),
			ColorSequenceKeypoint.new(1, palette.canvas),
		}, 125)
		if gradient then
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.78),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	end

	local function applyTopbarAurora(topbar)
		if not topbar or not topbar:IsA("GuiObject") then
			return
		end
		local band = topbar:FindFirstChild("AlleralV2TopAurora")
		if not band then
			band = Instance.new("Frame")
			band.Name = "AlleralV2TopAurora"
			band.BorderSizePixel = 0
			band.BackgroundTransparency = 1
			band.Size = UDim2.new(1, 0, 0, 3)
			band.Position = UDim2.new(0, 0, 1, -1)
			band.ZIndex = topbar.ZIndex + 8
			band.Parent = topbar
		end
		local gradient = ensureGradient(band, "AlleralV2TopAuroraGradient", {
			ColorSequenceKeypoint.new(0, palette.accent),
			ColorSequenceKeypoint.new(0.45, palette.accentSoft),
			ColorSequenceKeypoint.new(1, palette.accentHot),
		}, 0)
		if gradient then
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(1, 0.55),
			})
		end
	end

	local function applySidebarGlass(sidebar)
		if WindUI._AlleralGlassIntensity <= 0.05 or not sidebar then
			return
		end
		local frame = sidebar:FindFirstChild("Frame", true) or sidebar
		if not frame or not frame:IsA("GuiObject") then
			return
		end
		local veil = frame:FindFirstChild("AlleralV2SidebarVeil")
		if not veil then
			veil = Instance.new("Frame")
			veil.Name = "AlleralV2SidebarVeil"
			veil.BorderSizePixel = 0
			veil.Size = UDim2.fromScale(1, 1)
			veil.ZIndex = frame.ZIndex + 1
			veil.Parent = frame
		end
		veil.BackgroundColor3 = palette.surface
		veil.BackgroundTransparency = 1 - (0.02 + WindUI._AlleralGlassIntensity * 0.06)
	end

	local function applySectionLift(root)
		if WindUI._AlleralSectionLift == false or not root then
			return
		end
		for _, desc in ipairs(root:GetDescendants()) do
			if desc.Name == "SectionBox" and desc:IsA("Frame") and not desc:FindFirstChild("AlleralV2SectionLift") then
				local lift = ensureStroke(desc, "AlleralV2SectionLift", palette.accent, 0.94, 1, { inner = false })
				if lift then
					lift.Color = palette.divider
					lift.Transparency = 0.92 - WindUI._AlleralChromeDepth * 0.06
				end
				local glow = desc:FindFirstChild("AlleralV2SectionGlow")
				if not glow then
					glow = Instance.new("Frame")
					glow.Name = "AlleralV2SectionGlow"
					glow.BackgroundColor3 = palette.accent
					glow.BackgroundTransparency = 0.97
					glow.BorderSizePixel = 0
					glow.Size = UDim2.new(1, 10, 0, 2)
					glow.Position = UDim2.new(0, -5, 0, -2)
					glow.ZIndex = desc.ZIndex - 1
					glow.Parent = desc
				end
			end
		end
	end

	local function applyTabAurora(window)
		if WindUI._AlleralTabAurora == false or type(window) ~= "table" then
			return
		end
		local sidebar = window.UIElements and window.UIElements.SideBar
		if not sidebar then
			return
		end
		for _, btn in ipairs(sidebar:GetDescendants()) do
			if btn:IsA("TextButton") and btn.Name == "TabButton" and not btn:FindFirstChild("AlleralV2TabPulse") then
				local pulse = Instance.new("Frame")
				pulse.Name = "AlleralV2TabPulse"
				pulse.BackgroundColor3 = palette.accent
				pulse.BackgroundTransparency = 1
				pulse.BorderSizePixel = 0
				pulse.Size = UDim2.new(0, 3, 0.55, 0)
				pulse.AnchorPoint = Vector2.new(0, 0.5)
				pulse.Position = UDim2.new(0, 0, 0.5, 0)
				pulse.ZIndex = btn.ZIndex + 2
				pulse.Parent = btn
			end
		end
	end

	local function applyRowShimmer(root)
		if not root or WindUI._AlleralReducedMotion == true then
			return
		end
		for _, row in ipairs(root:GetDescendants()) do
			if row:IsA("Frame") and row.Name == "Main" and row.Parent and row.Parent.Name == "ToggleFrame" then
				if not row:FindFirstChild("AlleralV2RowSheen") then
					local sheen = Instance.new("Frame")
					sheen.Name = "AlleralV2RowSheen"
					sheen.BackgroundColor3 = palette.text
					sheen.BackgroundTransparency = 0.97
					sheen.BorderSizePixel = 0
					sheen.Size = UDim2.new(1, 0, 1, 0)
					sheen.ZIndex = row.ZIndex + 1
					sheen.Visible = false
					sheen.Parent = row
					row.MouseEnter:Connect(function()
						sheen.Visible = true
						tween(sheen, ANIM.micro, { BackgroundTransparency = 0.94 })
					end)
					row.MouseLeave:Connect(function()
						tween(sheen, ANIM.micro, { BackgroundTransparency = 1 })
						task.delay(0.15, function()
							if sheen.BackgroundTransparency > 0.99 then
								sheen.Visible = false
							end
						end)
					end)
				end
			end
		end
	end

	local function fixV2TextLayout(window)
		if type(window) ~= "table" then
			return
		end
		local scaleApi = WindUI._AlleralScaleApi
		local roots = {
			window.UIElements and window.UIElements.MainBar,
			window.UIElements and window.UIElements.Main,
			WindUI.DropdownGui,
		}
		for _, root in ipairs(roots) do
			if scaleApi and type(scaleApi.fixTextLayout) == "function" then
				pcall(scaleApi.fixTextLayout, root)
			elseif root then
				for _, desc in ipairs(root:GetDescendants()) do
					if desc:IsA("TextLabel") and desc.TextWrapped then
						desc.TextWrapped = false
						desc.TextTruncate = Enum.TextTruncate.None
					end
				end
			end
		end
	end

	local function refreshV2Layout(window, includeScaleRefresh)
		window = window or WindUI.Window
		if not window then
			return false
		end
		if includeScaleRefresh ~= false and type(WindUI.RefreshViewportScale) == "function" then
			pcall(function()
				WindUI:RefreshViewportScale(window)
			end)
		else
			fixV2TextLayout(window)
			polishV2Window(window)
		end
		return true
	end

	local function polishV2Window(window)
		if type(window) ~= "table" then
			return
		end
		pcall(function()
			local main = window.UIElements and window.UIElements.Main
			if main then
				applyAmbientWindowGlow(main)
			end
			local topbar = window.UIElements and window.UIElements.Topbar
			if topbar and topbar.Main then
				applyTopbarAurora(topbar.Main)
			end
			local sidebar = window.UIElements and window.UIElements.SideBar
			if sidebar then
				applySidebarGlass(sidebar)
			end
			local mainBar = window.UIElements and window.UIElements.MainBar
			if mainBar then
				applySectionLift(mainBar)
				applyRowShimmer(mainBar)
			end
			if main then
				applySectionLift(main)
				applyRowShimmer(main)
			end
			applyTabAurora(window)
			fixV2TextLayout(window)
		end)
	end

	local originalPolish = WindUI.PolishWindow
	function WindUI.PolishWindow(self, window)
		local result = originalPolish(self, window)
		polishV2Window(window)
		return result
	end

	-- -------------------------------------------------------------------------
	-- V2 public API
	-- -------------------------------------------------------------------------

	function WindUI.GetV2Features(_self)
		return {
			version = V2.version,
			scale = WindUI._AlleralAutoScale or WindUI._AlleralUiScale or 1,
			scaleApi = WindUI._AlleralScaleApi and WindUI._AlleralScaleApi.VERSION or nil,
			themes = {
				"ArrrelObsidian",
				"ArrrelSynth",
				"ArrrelOcean",
				"ArrrelEmber",
				"ArrrelStealth",
				"ArrrelPaper",
				"ArrrelVoid",
			},
			motionProfiles = MOTION_PROFILES,
			tooltipStyles = TOOLTIP_STYLES,
			notifyStyles = NOTIFY_STYLES_V2,
			layoutProfiles = { "cinema", "ultrawide", "minimal", "accessibility" },
		}
	end

	function WindUI.SetGlassIntensity(_self, value)
		WindUI._AlleralGlassIntensity = math.clamp(tonumber(value) or 0.55, 0, 1)
		if WindUI.Window then
			WindUI:RepairWindow(WindUI.Window)
		end
		return WindUI._AlleralGlassIntensity
	end

	function WindUI.GetGlassIntensity(_self)
		return WindUI._AlleralGlassIntensity
	end

	function WindUI.SetChromeDepth(_self, value)
		WindUI._AlleralChromeDepth = math.clamp(tonumber(value) or 0.65, 0, 1)
		if WindUI.Window then
			WindUI:PolishWindow(WindUI.Window)
		end
		return WindUI._AlleralChromeDepth
	end

	function WindUI.SetAmbientGlow(_self, enabled)
		WindUI._AlleralAmbientGlow = enabled ~= false
		if WindUI.Window then
			WindUI:PolishWindow(WindUI.Window)
		end
	end

	function WindUI.SetTabAurora(_self, enabled)
		WindUI._AlleralTabAurora = enabled ~= false
		if WindUI.Window then
			WindUI:PolishWindow(WindUI.Window)
		end
	end

	function WindUI.SetSectionLift(_self, enabled)
		WindUI._AlleralSectionLift = enabled ~= false
		if WindUI.Window then
			WindUI:PolishWindow(WindUI.Window)
		end
	end

	function WindUI.SetMotionProfile(_self, profileName)
		profileName = tostring(profileName or "fluid")
		local preset = MOTION_PROFILES[profileName]
		if not preset then
			return false
		end
		WindUI._AlleralMotionProfile = profileName
		if preset.springScale < 0.5 then
			WindUI._AlleralReducedMotion = true
			WindUI._AlleralSpringMotion = false
		else
			WindUI._AlleralReducedMotion = false
			WindUI._AlleralSpringMotion = true
		end
		if preset.startup == false and type(WindUI.SetStartupEffect) == "function" then
			WindUI:SetStartupEffect(false)
		end
		return true
	end

	function WindUI.GetMotionProfile(_self)
		return WindUI._AlleralMotionProfile or "fluid"
	end

	function WindUI.ListMotionProfiles(_self)
		local names = {}
		for name in pairs(MOTION_PROFILES) do
			table.insert(names, name)
		end
		table.sort(names)
		return names
	end

	function WindUI.SetTooltipStyle(_self, styleName)
		styleName = string.lower(tostring(styleName or "rich"))
		for _, allowed in ipairs(TOOLTIP_STYLES) do
			if allowed == styleName then
				WindUI._AlleralTooltipStyle = styleName
				return true
			end
		end
		return false
	end

	function WindUI.GetTooltipStyle(_self)
		return WindUI._AlleralTooltipStyle or "rich"
	end

	function WindUI.SetNotificationStyle(_self, styleName)
		styleName = string.lower(tostring(styleName or "glass"))
		for _, allowed in ipairs(NOTIFY_STYLES_V2) do
			if allowed == styleName then
				WindUI._AlleralNotifyStyle = styleName
				return true
			end
		end
		return false
	end

	function WindUI.GetNotificationStyle(_self)
		return WindUI._AlleralNotifyStyle or "glass"
	end

	function WindUI.ExportCustomization(_self)
		return {
			version = V2.version,
			glass = WindUI._AlleralGlassIntensity,
			depth = WindUI._AlleralChromeDepth,
			motion = WindUI._AlleralMotionProfile,
			tooltip = WindUI._AlleralTooltipStyle,
			notify = WindUI._AlleralNotifyStyle,
			ambient = WindUI._AlleralAmbientGlow,
			tabAurora = WindUI._AlleralTabAurora,
			sectionLift = WindUI._AlleralSectionLift,
			profile = WindUI._AlleralProfile,
			uiScale = WindUI._AlleralUiScale,
			compactNotify = WindUI._AlleralNotifyCompact,
			reducedMotion = WindUI._AlleralReducedMotion,
		}
	end

	function WindUI.ImportCustomization(_self, payload)
		if type(payload) ~= "table" then
			return false
		end
		if payload.glass ~= nil then
			WindUI:SetGlassIntensity(payload.glass)
		end
		if payload.depth ~= nil then
			WindUI:SetChromeDepth(payload.depth)
		end
		if payload.motion then
			WindUI:SetMotionProfile(payload.motion)
		end
		if payload.tooltip then
			WindUI:SetTooltipStyle(payload.tooltip)
		end
		if payload.notify then
			WindUI:SetNotificationStyle(payload.notify)
		end
		if payload.ambient ~= nil then
			WindUI:SetAmbientGlow(payload.ambient)
		end
		if payload.tabAurora ~= nil then
			WindUI:SetTabAurora(payload.tabAurora)
		end
		if payload.sectionLift ~= nil then
			WindUI:SetSectionLift(payload.sectionLift)
		end
		if payload.profile and type(WindUI.ApplyProfile) == "function" then
			pcall(function()
				WindUI:ApplyProfile(payload.profile)
			end)
		end
		if payload.uiScale ~= nil and type(WindUI.SetUiScale) == "function" then
			pcall(function()
				WindUI:SetUiScale(payload.uiScale)
			end)
		elseif WindUI.Window and type(WindUI.RefreshViewportScale) == "function" then
			pcall(function()
				WindUI:RefreshViewportScale(WindUI.Window)
			end)
		end
		if WindUI.Window then
			fixV2TextLayout(WindUI.Window)
			polishV2Window(WindUI.Window)
		end
		return true
	end

	function WindUI.RefreshV2Layout(_self, window)
		return refreshV2Layout(window, true)
	end

	function WindUI.CycleV2Theme(_self, delta)
		delta = tonumber(delta) or 1
		local names = {
			"Arrrel",
			"ArrrelNeon",
			"ArrrelMidnight",
			"ArrrelAurora",
			"ArrrelObsidian",
			"ArrrelSynth",
			"ArrrelOcean",
			"ArrrelEmber",
			"ArrrelStealth",
			"ArrrelVoid",
		}
		local current = "Arrrel"
		if type(WindUI.GetCurrentTheme) == "function" then
			local ok, theme = pcall(function()
				return WindUI:GetCurrentTheme()
			end)
			if ok and theme then
				current = theme
			end
		end
		local index = 1
		for i, name in ipairs(names) do
			if name == current then
				index = i
				break
			end
		end
		index = ((index - 1 + delta) % #names) + 1
		local nextTheme = names[index]
		if type(WindUI.SetTheme) == "function" then
			pcall(function()
				WindUI:SetTheme(nextTheme)
				if type(WindUI.FlashAccent) == "function" then
					WindUI:FlashAccent()
				end
			end)
		end
		return nextTheme
	end

	local originalGetFeatures = WindUI.GetFeatures
	function WindUI.GetFeatures(_self)
		local base = {}
		if type(originalGetFeatures) == "function" then
			local ok, result = pcall(originalGetFeatures, _self)
			if ok and type(result) == "table" then
				base = result
			end
		end
		base.v2 = true
		base.customization = true
		base.glass = true
		base.motionProfiles = true
		base.version = V2.version
		return base
	end

	local originalRepair = WindUI.RepairWindow
	function WindUI.RepairWindow(self, window)
		local target = window or WindUI.Window
		local ok = originalRepair(self, window)
		fixV2TextLayout(target)
		polishV2Window(target)
		return ok
	end

	local originalRefreshScale = WindUI.RefreshViewportScale
	if type(originalRefreshScale) == "function" then
		function WindUI.RefreshViewportScale(self, window)
			local target = window or WindUI.Window
			local scale = originalRefreshScale(self, window)
			fixV2TextLayout(target)
			polishV2Window(target)
			return scale
		end
	end

	WindUI:SetMotionProfile(WindUI._AlleralMotionProfile or "fluid")

	if WindUI.Window then
		task.defer(function()
			polishV2Window(WindUI.Window)
		end)
	end

	return true
end
