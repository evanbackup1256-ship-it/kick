--[[
	Alleral UI V2 — WindUI engine layer (Footagesus 1.6.64-fix base)
	Premium chrome, V2 boost, profiles, motion, search, tooltips, notifications.
	Tokens: ui/design/tokens.json · V2: ui/windui/v2/boost.luau
]]

return function(WindUI)
	if type(WindUI) ~= "table" then
		return WindUI
	end

	-- -------------------------------------------------------------------------
	-- Tokens
	-- -------------------------------------------------------------------------

	local TweenService = game:GetService("TweenService")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local Workspace = game:GetService("Workspace")

	-- Layout tokens — mirror ui/design/tokens.json
	local MAC = {
		corner = 12,
		windowPad = 24,
		sidebarWidth = 280,
		elementGap = 16,
		sectionGap = 15,
		sectionInner = 10,
		sectionPadTop = 22,
		sectionPadBottom = 20,
		sectionPadLeft = 20,
		sectionPadRight = 18,
		contentPadX = 20,
		scrollPadTop = 10,
		scrollPadBottom = 15,
		scrollPadLeft = 11,
		scrollPadRight = 3,
		sidebarPadTop = 31,
		sidebarPadX = 10,
		tabHeight = 40,
		tabPadLeft = 24,
		tabPadRight = 12,
		tabGroupGap = 17,
		rowHeight = 38,
		dividerTransparency = 0.9,
		sectionFillTransparency = 0.98,
		sectionStrokeTransparency = 0.95,
		tabInactiveText = 0.42,
		tabInactiveIcon = 0.45,
		topbarHeight = 68,
		rowLabelTransparency = 0.5,
		notifyCorner = 10,
		cardStrokeTransparency = 0.95,
		windowStrokeTransparency = 0.9,
		sliderTrackTransparency = 0.88,
		sliderFillTransparency = 0.22,
		sliderThumbSize = 15,
		glowSpread = 18,
	}

	local ACCENT_PRESETS = {
		Mint = "#53fc18",
		Cyan = "#22d3ee",
		Violet = "#a78bfa",
		Rose = "#fb7185",
		Amber = "#fbbf24",
		Ice = "#93c5fd",
		Emerald = "#34d399",
		Fuchsia = "#e879f9",
		Aurora = "#7cf7ff",
	}

	-- Arrrel palette — deep canvas, lifted surfaces, mint signal accent.
	local palette = {
		accent = Color3.fromHex("#53fc18"),
		accentSoft = Color3.fromHex("#8dff52"),
		accentHot = Color3.fromHex("#2dff62"),
		canvas = Color3.fromHex("#070708"),
		surface = Color3.fromHex("#0e0e11"),
		card = Color3.fromHex("#131318"),
		cardHover = Color3.fromHex("#1a1a22"),
		line = Color3.fromHex("#ffffff"),
		divider = Color3.fromHex("#ffffff"),
		text = Color3.fromHex("#f4f4f8"),
		muted = Color3.fromHex("#9ca3af"),
		trackOff = Color3.fromHex("#24242e"),
		trackOn = Color3.fromHex("#163512"),
		knob = Color3.fromHex("#fafafc"),
		glow = Color3.fromHex("#53fc18"),
	}

	local function accent()
		return palette.accent
	end
	local function accentSoft()
		return palette.accentSoft
	end
	local function accentHot()
		return palette.accentHot
	end

	WindUI.ARRREL_UI_VERSION = "2.0.0-alleral-v2"
	WindUI.ARRREL_BRAND = "Alleral"
	WindUI.ALLERAL_UI_VERSION = WindUI.ARRREL_UI_VERSION
	WindUI.ALLERAL_BRAND = "Alleral UI V2"
	WindUI._AlleralNotifyCount = 0
	WindUI._AlleralMaxNotify = 8
	WindUI._AlleralWatchdogToken = 0
	WindUI._AlleralReducedMotion = WindUI._AlleralReducedMotion == true
	WindUI._AlleralNotifyCompact = WindUI._AlleralNotifyCompact == true
	WindUI._AlleralNotifyHolder = WindUI._AlleralNotifyHolder
	WindUI._AlleralPendingNotifyStyle = nil
	WindUI._AlleralProfile = WindUI._AlleralProfile or "auto"
	WindUI._AlleralUiScale = tonumber(WindUI._AlleralUiScale) or 1
	WindUI._AlleralTouchFeedback = WindUI._AlleralTouchFeedback ~= false
	WindUI._AlleralHaptics = WindUI._AlleralHaptics == true
	WindUI._AlleralNotifyDedupe = WindUI._AlleralNotifyDedupe ~= false
	WindUI._AlleralLastNotify = WindUI._AlleralLastNotify or {}

	local NOTIFY_STYLES = {
		info = {
			accent = palette.text,
			icon = "info",
		},
		success = {
			accent = accent(),
			icon = "check",
		},
		warn = {
			accent = Color3.fromHex("#ffd166"),
			icon = "triangle-alert",
		},
		error = {
			accent = Color3.fromHex("#ff5c5c"),
			icon = "x",
		},
	}

	local function resolveNotifyStyle(payload)
		local key = string.lower(tostring(payload.Type or payload.Level or payload.Style or "info"))
		if key == "warning" then
			key = "warn"
		elseif key == "danger" or key == "fail" or key == "failed" then
			key = "error"
		elseif key == "ok" or key == "done" then
			key = "success"
		end
		return NOTIFY_STYLES[key] or NOTIFY_STYLES.info, key
	end

	local function mergeTokens(base, extra)
		local out = {}
		for key, value in pairs(base) do
			out[key] = value
		end
		for key, value in pairs(extra or {}) do
			out[key] = value
		end
		return out
	end

	local function uiWarn(scope, err)
		warn(string.format("[Arrrel/%s] %s", tostring(scope), tostring(err)))
	end

	local function snapProps(instance, props)
		if not instance or not props then
			return
		end
		pcall(function()
			for key, value in pairs(props) do
				instance[key] = value
			end
		end)
	end

	local Motion = (function()
		local springStates = setmetatable({}, { __mode = "k" })
		local heartbeatConn = nil
		local EPSILON = 0.0008
		local MAX_DT = 1 / 30

		local PRESETS = {
			instant = { f = math.huge, d = 1 },
			human = { f = 5.2, d = 1.02 },
			snappy = { f = 6.4, d = 1.04 },
			soft = { f = 4.2, d = 1.1 },
			bouncy = { f = 5.2, d = 0.82 },
			pop = { f = 5.8, d = 0.88 },
			micro = { f = 7.8, d = 1.06 },
			open = { f = 4.6, d = 0.96 },
			close = { f = 6.4, d = 1.08 },
			notify = { f = 5.4, d = 0.94 },
			dropdown = { f = 7.2, d = 1.02 },
			sweep = { f = 3.8, d = 1.02 },
			tab = { f = 5.2, d = 0.92 },
			toggle = { f = 6.4, d = 0.84 },
			press = { f = 9.5, d = 0.78 },
			slider = { f = 10, d = 1.02 },
			tooltip = { f = 6, d = 1 },
		}

		local function resolvePreset(name)
			if type(name) == "table" and name.f then
				return name
			end
			return PRESETS[name] or PRESETS.snappy
		end

		local function stepScalar(pos, vel, goal, dt, freq, damp)
			if freq == math.huge then
				return goal, 0
			end
			local omega = math.pi * 2 * freq
			local zeta = damp
			local offset = pos - goal
			if zeta >= 1 then
				local expTerm = math.exp(-omega * dt)
				local newPos = goal + (offset + (vel + omega * offset) * dt) * expTerm
				local newVel = (vel - omega * (vel + omega * offset) * dt) * expTerm
				return newPos, newVel
			end
			local omegaD = omega * math.sqrt(1 - zeta * zeta)
			if omegaD < 1e-4 then
				omegaD = 1e-4
			end
			local expTerm = math.exp(-zeta * omega * dt)
			local cosTerm = math.cos(omegaD * dt)
			local sinTerm = math.sin(omegaD * dt)
			local newPos = goal
				+ expTerm
					* (offset * (cosTerm + (zeta * omega / omegaD) * sinTerm) + (vel / omegaD) * sinTerm)
			local newVel = expTerm
				* (vel * cosTerm - ((offset * omega * omega + vel * zeta * omega) / omegaD) * sinTerm)
			return newPos, newVel
		end

		local function packValue(value)
			local t = typeof(value)
			if t == "number" then
				return "number", { value }, function(ch)
					return ch[1]
				end
			elseif t == "UDim2" then
				return "udim2", { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }, function(ch)
					return UDim2.new(ch[1], ch[2], ch[3], ch[4])
				end
			elseif t == "UDim" then
				return "udim", { value.Scale, value.Offset }, function(ch)
					return UDim.new(ch[1], ch[2])
				end
			elseif t == "Color3" then
				return "color3", { value.R, value.G, value.B }, function(ch)
					return Color3.new(ch[1], ch[2], ch[3])
				end
			elseif t == "Vector2" then
				return "vector2", { value.X, value.Y }, function(ch)
					return Vector2.new(ch[1], ch[2])
				end
			end
			return nil
		end

		local function readProperty(instance, propName)
			local ok, value = pcall(function()
				return instance[propName]
			end)
			if ok then
				return value
			end
			return nil
		end

		local function writeProperty(instance, propName, value)
			pcall(function()
				instance[propName] = value
			end)
		end

		local function stepHeartbeat(dt)
			dt = math.min(dt, MAX_DT)
			for instance, props in pairs(springStates) do
				if not instance or not instance.Parent then
					springStates[instance] = nil
					continue
				end
				for propName, state in pairs(props) do
					local allSettled = true
					for i = 1, #state.pos do
						state.pos[i], state.vel[i] =
							stepScalar(state.pos[i], state.vel[i], state.goal[i], dt, state.f, state.d)
						if math.abs(state.pos[i] - state.goal[i]) > EPSILON or math.abs(state.vel[i]) > EPSILON then
							allSettled = false
						end
					end
					if allSettled then
						writeProperty(instance, propName, state.pack(state.goal))
						props[propName] = nil
					else
						writeProperty(instance, propName, state.pack(state.pos))
					end
				end
				if not next(props) then
					springStates[instance] = nil
				end
			end
			if not next(springStates) and heartbeatConn then
				heartbeatConn:Disconnect()
				heartbeatConn = nil
			end
		end

		local function ensureHeartbeat()
			if heartbeatConn then
				return
			end
			heartbeatConn = RunService.RenderStepped:Connect(stepHeartbeat)
		end

		local function target(instance, presetName, props)
			if not instance or type(props) ~= "table" then
				return
			end
			local preset = resolvePreset(presetName)
			if preset.f == math.huge then
				for propName, goal in pairs(props) do
					writeProperty(instance, propName, goal)
				end
				return
			end

			local bag = springStates[instance]
			if not bag then
				bag = {}
				springStates[instance] = bag
			end

			for propName, goal in pairs(props) do
				local kind, goalChannels, pack = packValue(goal)
				if not kind then
					writeProperty(instance, propName, goal)
					continue
				end
				local current = readProperty(instance, propName)
				local _, startChannels = packValue(current)
				if not startChannels then
					writeProperty(instance, propName, goal)
					continue
				end
				local pos, vel = {}, {}
				for i = 1, #goalChannels do
					pos[i] = startChannels[i]
					vel[i] = 0
				end
				bag[propName] = {
					pos = pos,
					vel = vel,
					goal = goalChannels,
					pack = pack,
					f = preset.f,
					d = preset.d,
				}
			end
			ensureHeartbeat()
		end

		local function stop(instance, propName)
			local bag = springStates[instance]
			if not bag then
				return
			end
			if propName then
				bag[propName] = nil
				if not next(bag) then
					springStates[instance] = nil
				end
			else
				springStates[instance] = nil
			end
		end

		local function tweenInfoToPreset(info)
			if not info or not info.Time then
				return "snappy"
			end
			local style = info.EasingStyle
			local t = info.Time
			if style == Enum.EasingStyle.Back then
				return "bouncy"
			end
			if style == Enum.EasingStyle.Exponential or style == Enum.EasingStyle.Elastic then
				return "pop"
			end
			if t <= 0.12 then
				return "micro"
			end
			if t >= 0.38 then
				return "soft"
			end
			if style == Enum.EasingStyle.Quint or style == Enum.EasingStyle.Quart then
				return "open"
			end
			return "snappy"
		end

		return {
			Presets = PRESETS,
			target = target,
			stop = stop,
			tweenInfoToPreset = tweenInfoToPreset,
		}
	end)()

	if WindUI._AlleralSpringMotion == nil then
		WindUI._AlleralSpringMotion = true
	end

	local sliderTrackFrames = setmetatable({}, { __mode = "k" })

	local function stubTween(instance)
		return {
			Play = function() end,
			Cancel = function()
				if instance then
					Motion.stop(instance)
				end
			end,
			Pause = function() end,
			Destroy = function()
				if instance then
					Motion.stop(instance)
				end
			end,
		}
	end

	local function tween(instance, infoOrPreset, props)
		if not instance or not props then
			return
		end
		if not instance.Parent or WindUI._AlleralReducedMotion == true then
			snapProps(instance, props)
			return
		end
		local function run()
			if WindUI._AlleralSpringMotion ~= false then
				local preset = type(infoOrPreset) == "string" and infoOrPreset or Motion.tweenInfoToPreset(infoOrPreset)
				Motion.target(instance, preset, props)
				return
			end
			pcall(function()
				local info = infoOrPreset
				if type(info) == "string" then
					info = TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				end
				TweenService:Create(instance, info, props):Play()
			end)
		end
		if motionEnabled() and infoOrPreset ~= "instant" then
			local jitterMin = RESOURCES.motion.jitterMin or 0.004
			local jitterMax = RESOURCES.motion.jitterMax or 0.014
			local jitter = tonumber(instance:GetAttribute("AlleralMotionJitter"))
			if not jitter then
				jitter = jitterMin + math.random() * (jitterMax - jitterMin)
				instance:SetAttribute("AlleralMotionJitter", jitter)
			end
			if jitter > jitterMin then
				task.delay(jitter, run)
				return
			end
		end
		run()
	end

	local function installTweenCreateHook()
		local ok, original = pcall(function()
			return TweenService.Create
		end)
		if not ok or type(original) ~= "function" then
			return false
		end
		local hooked, hookErr = pcall(function()
			TweenService.Create = function(self, instance, tweenInfo, props)
				if sliderTrackFrames[instance] and props and props.Size and tweenInfo and tweenInfo.Time <= 0.08 then
					snapProps(instance, props)
					return stubTween(instance)
				end
				if WindUI._AlleralSpringMotion ~= false and WindUI._AlleralReducedMotion ~= true and props and instance then
					Motion.target(instance, Motion.tweenInfoToPreset(tweenInfo), props)
					return stubTween(instance)
				end
				return original(self, instance, tweenInfo, props)
			end
		end)
		if not hooked then
			warn("[Arrrel] TweenService hook skipped: " .. tostring(hookErr))
		end
		return hooked
	end

	installTweenCreateHook()

	-- Spring motion presets (fraktality/spr-style: frequency Hz + damping ratio).
	local ANIM = {
		open = "open",
		close = "close",
		page = "soft",
		pageOut = "micro",
		micro = "micro",
		notify = "notify",
		dropdown = "dropdown",
		sweep = "sweep",
		toggle = "toggle",
		tab = "tab",
		press = "press",
		slider = "slider",
	}

	local ALLERAL_TAB_GAP = MAC.elementGap

	if WindUI._AlleralStartupEffect == nil then
		WindUI._AlleralStartupEffect = true
	end

	local POLISH_SKIP = {
		AlleralPageFade = true,
		AlleralStartupSweep = true,
		AlleralSidebarDivider = true,
		AlleralToggleGlow = true,
		AlleralNotifyRail = true,
		AlleralTopbarLine = true,
		AlleralCardShell = true,
		AlleralTabPill = true,
		AlleralTabActiveBg = true,
		AlleralTabHoverBg = true,
		AlleralSearchHook = true,
		AlleralBtnScale = true,
		AlleralRowHover = true,
		AlleralRevealScale = true,
		AlleralTabHoverScale = true,
		MenuCanvas = true,
		Menu = true,
	}

	local function motionEnabled()
		return WindUI._AlleralReducedMotion ~= true
	end

	local function isDropdownDescendant(gui)
		local dropdownGui = WindUI.DropdownGui
		return dropdownGui and gui and gui:IsDescendantOf(dropdownGui)
	end

	local function cleanupLegacyPolish(root)
		if not root then
			return
		end
		for _, desc in ipairs(root:GetDescendants()) do
			if desc.Name == "AlleralMenuScale" or desc.Name == "AlleralNotifyScale" then
				desc:Destroy()
			end
		end
	end

	local function ensureUiScale(gui, name)
		if not gui or not gui:IsA("GuiObject") then
			return nil
		end
		local scale = gui:FindFirstChild(name)
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = name
			scale.Parent = gui
		end
		return scale
	end

	local function ensurePageFade(container)
		if not container or not container:IsA("GuiObject") then
			return nil
		end
		local fade = container:FindFirstChild("AlleralPageFade")
		if not fade then
			fade = Instance.new("Frame")
			fade.Name = "AlleralPageFade"
			fade.BackgroundColor3 = palette.canvas
			fade.BackgroundTransparency = 1
			fade.BorderSizePixel = 0
			fade.Size = UDim2.fromScale(1, 1)
			fade.Position = UDim2.fromOffset(0, 0)
			fade.ZIndex = 8
			fade.Active = false
			fade.Selectable = false
			fade.Parent = container
		end
		return fade
	end

	local function playStartupEffect(window)
		if not motionEnabled() or WindUI._AlleralStartupEffect ~= true then
			return
		end
		local main = window.UIElements and window.UIElements.Main
		if not main then
			return
		end

		cleanupLegacyPolish(main)

		local scale = ensureUiScale(main, "AlleralStartupScale")
		if scale then
			scale.Scale = 0.962
			tween(scale, ANIM.open, { Scale = 1 })
		end

		local topbar = window.UIElements.Topbar and window.UIElements.Topbar.Main
		if topbar then
			local sweep = topbar:FindFirstChild("AlleralStartupSweep")
			if not sweep then
				sweep = Instance.new("Frame")
				sweep.Name = "AlleralStartupSweep"
				sweep.BackgroundColor3 = accent()
				sweep.BorderSizePixel = 0
				sweep.Size = UDim2.new(0, 0, 0, 2)
				sweep.Position = UDim2.new(0, 0, 1, -1)
				sweep.ZIndex = topbar.ZIndex + 5
				sweep.Parent = topbar
			end
			sweep.BackgroundTransparency = 0.35
			sweep.Size = UDim2.new(0, 0, 0, 2)
			tween(sweep, ANIM.sweep, {
				Size = UDim2.new(1, 0, 0, 2),
				BackgroundTransparency = 0.78,
			})
		end

		WindUI:FlashAccent(window)
	end

	local function animateNotificationIn(card, rail)
		if not motionEnabled() or not card then
			return
		end
		cleanupLegacyPolish(card)

		local nScale = ensureUiScale(card, "AlleralNotifyScale")
		if nScale then
			nScale.Scale = 0.96
			tween(nScale, ANIM.notify, { Scale = 1 })
		end

		if card:IsA("ImageLabel") or card:IsA("ImageButton") then
			local target = card.ImageTransparency
			card.ImageTransparency = math.clamp(target + 0.14, 0, 1)
			tween(card, ANIM.notify, { ImageTransparency = target })
		end
		local stroke = card:FindFirstChild("AlleralNotifyStroke", true)
		if stroke then
			stroke.Transparency = 0.94
			tween(stroke, ANIM.micro, { Transparency = 0.88 })
		end
		if rail then
			local full = rail.Size
			rail.Size = UDim2.new(0, 0, full.Y.Scale, full.Y.Offset)
			tween(rail, ANIM.notify, { Size = full })
		end
	end

	local function animateDropdownMenu(canvas)
		if not motionEnabled() or not canvas then
			return
		end
		cleanupLegacyPolish(canvas)

		local menu = canvas:FindFirstChild("Menu")
		if not menu or not menu:IsA("GuiObject") then
			return
		end

		if menu:IsA("ImageLabel") then
			local target = menu.ImageTransparency
			menu.ImageTransparency = math.clamp(target + 0.16, 0, 1)
			tween(menu, ANIM.dropdown, { ImageTransparency = target })
		end
		local menuScale = ensureUiScale(menu, "AlleralMenuScale")
		if menuScale then
			menuScale.Scale = 0.97
			tween(menuScale, ANIM.dropdown, { Scale = 1 })
		end

		local stroke = menu:FindFirstChild("AlleralMenuStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = "AlleralMenuStroke"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Color = palette.line
			stroke.Thickness = 1
			stroke.Parent = menu
		end
		stroke.Transparency = 0.82
		tween(stroke, ANIM.dropdown, { Transparency = 0.52 })
	end

	local function resetDropdownMenu(canvas)
		if not canvas then
			return
		end
		cleanupLegacyPolish(canvas)
		local menu = canvas:FindFirstChild("Menu")
		if menu and menu:IsA("ImageLabel") then
			menu.ImageTransparency = 0.05
		end
	end

	local function trackDropdownCanvas(canvas)
		if not canvas or canvas._AlleralDropdownTracked then
			return
		end
		canvas._AlleralDropdownTracked = true
		pcall(function()
			canvas:GetPropertyChangedSignal("Visible"):Connect(function()
				if canvas.Visible then
					task.defer(function()
						animateDropdownMenu(canvas)
					end)
				else
					resetDropdownMenu(canvas)
				end
			end)
		end)
	end

	local function installDropdownAnimations()
		if WindUI._AlleralDropdownHook then
			return
		end
		local gui = WindUI.DropdownGui
		if not gui then
			WindUI._AlleralDropdownRetries = (WindUI._AlleralDropdownRetries or 0) + 1
			if WindUI._AlleralDropdownRetries < 12 then
				task.delay(0.35, installDropdownAnimations)
			end
			return
		end
		WindUI._AlleralDropdownHook = true
		for _, desc in ipairs(gui:GetDescendants()) do
			if desc.Name == "MenuCanvas" then
				trackDropdownCanvas(desc)
			end
		end
		gui.DescendantAdded:Connect(function(desc)
			if desc.Name == "MenuCanvas" then
				trackDropdownCanvas(desc)
			end
		end)
	end

	local function installWindowAnimations(window)
		if type(window) ~= "table" or window._AlleralAnimWrapped then
			return window
		end
		window._AlleralAnimWrapped = true

		if type(window.Open) == "function" and not window._AlleralOpenWrapped then
			window._AlleralOpenWrapped = true
			local origOpen = window.Open
			function window:Open(...)
				local result = origOpen(self, ...)
				if WindUI._AlleralStartupEffect == true then
					task.defer(function()
						task.wait(0.06)
						playStartupEffect(self)
					end)
				end
				return result
			end
		end

		if type(window.Close) == "function" and not window._AlleralCloseWrapped then
			window._AlleralCloseWrapped = true
			local origClose = window.Close
			function window:Close(...)
				if motionEnabled() then
					local main = self.UIElements and self.UIElements.Main
					local scale = main and main:FindFirstChild("AlleralStartupScale")
					if scale then
						tween(scale, ANIM.close, { Scale = 0.988 })
					end
				end
				local result = origClose(self, ...)
				task.delay(0.45, function()
					local main = self.UIElements and self.UIElements.Main
					local scale = main and main:FindFirstChild("AlleralStartupScale")
					if scale then
						scale.Scale = 1
					end
				end)
				return result
			end
		end

		if type(window.SelectTab) == "function" and not window._AlleralSelectTabWrapped then
			window._AlleralSelectTabWrapped = true
			local origSelectTab = window.SelectTab
			function window:SelectTab(index)
				if not motionEnabled() then
					return origSelectTab(self, index)
				end
				local result = origSelectTab(self, index)
				local tabMod = self.TabModule
				local nextContainer = tabMod and tabMod.Containers and tabMod.Containers[index]
				if nextContainer then
					local fade = ensurePageFade(nextContainer)
					if fade then
						fade.BackgroundTransparency = 0.22
						tween(fade, ANIM.page, { BackgroundTransparency = 1 })
					end
				end
				return result
			end
		end

		return window
	end

	local WINDOW_DEFAULTS = {
		Theme = "Arrrel",
		NewElements = true,
		UICorner = MAC.corner,
		UIPadding = MAC.windowPad,
		SideBarWidth = MAC.sidebarWidth,
		ElementPadding = MAC.elementGap,
		Resizable = true,
		HideSearchBar = false,
	}

	local PROFILE_PRESETS = {
		desktop = {
			label = "Desktop",
			uiScale = 1,
			corner = MAC.corner,
			padding = MAC.windowPad,
			sidebar = MAC.sidebarWidth,
			elementPad = MAC.elementGap,
			startup = true,
			touchFeedback = true,
			haptics = false,
			reducedMotion = false,
			notifyCompact = false,
		},
		mobile = {
			label = "Mobile",
			uiScale = 0.9,
			corner = 12,
			padding = 18,
			sidebar = 228,
			elementPad = 14,
			startup = false,
			touchFeedback = true,
			haptics = true,
			notifyCompact = true,
			reducedMotion = false,
			openButton = {
				Enabled = true,
				OnlyMobile = false,
				Draggable = true,
			},
		},
		compact = {
			label = "Compact",
			uiScale = 0.94,
			corner = 12,
			padding = 20,
			sidebar = 248,
			elementPad = 14,
			notifyCompact = true,
			touchFeedback = true,
			startup = true,
			haptics = false,
			reducedMotion = false,
		},
		performance = {
			label = "Performance",
			uiScale = 1,
			corner = 10,
			padding = 18,
			sidebar = 248,
			elementPad = 12,
			startup = false,
			reducedMotion = true,
			notifyCompact = false,
			touchFeedback = false,
			haptics = false,
		},
	}

	local function viewportShortSide()
		local camera = Workspace.CurrentCamera
		if not camera then
			return 1080
		end
		local size = camera.ViewportSize
		return math.min(size.X, size.Y)
	end

	local function detectDeviceKind()
		local touch = UserInputService.TouchEnabled
		local keyboard = UserInputService.KeyboardEnabled
		local mouse = UserInputService.MouseEnabled
		local shortSide = viewportShortSide()
		if touch and not keyboard and not mouse then
			return "mobile"
		end
		if touch and shortSide <= 900 then
			return "mobile"
		end
		if shortSide <= 820 then
			return "compact"
		end
		return "desktop"
	end

	local function resolveProfileName(name)
		name = name or WindUI._AlleralProfile or "auto"
		if name == "auto" then
			return detectDeviceKind()
		end
		if PROFILE_PRESETS[name] then
			return name
		end
		return "desktop"
	end

	local function applyPresetToDefaults(preset)
		if not preset then
			return
		end
		WINDOW_DEFAULTS.UICorner = preset.corner or WINDOW_DEFAULTS.UICorner
		WINDOW_DEFAULTS.UIPadding = preset.padding or WINDOW_DEFAULTS.UIPadding
		WINDOW_DEFAULTS.SideBarWidth = preset.sidebar or WINDOW_DEFAULTS.SideBarWidth
		WINDOW_DEFAULTS.ElementPadding = preset.elementPad or WINDOW_DEFAULTS.ElementPadding
		if preset.uiScale ~= nil then
			WindUI._AlleralUiScale = preset.uiScale
		end
		if preset.touchFeedback ~= nil then
			WindUI._AlleralTouchFeedback = preset.touchFeedback ~= false
		end
		if preset.haptics ~= nil then
			WindUI._AlleralHaptics = preset.haptics == true
		end
		if preset.reducedMotion ~= nil then
			WindUI._AlleralReducedMotion = preset.reducedMotion == true
		end
		if preset.notifyCompact ~= nil then
			WindUI._AlleralNotifyCompact = preset.notifyCompact == true
		end
		if preset.startup ~= nil then
			WindUI._AlleralStartupEffect = preset.startup == true
		end
	end

	local function syncProfileEnv(preset)
		if not preset then
			return
		end
		local env
		pcall(function()
			if type(_G) == "table" and type(_G.ENV) == "table" then
				env = _G.ENV
			elseif type(shared) == "table" and type(shared.ENV) == "table" then
				env = shared.ENV
			end
		end)
		if not env then
			return
		end
		if preset.reducedMotion ~= nil then
			env.Alleral_UiReducedMotion = preset.reducedMotion == true
		end
		if preset.notifyCompact ~= nil then
			env.Alleral_NotifyCompact = preset.notifyCompact == true
		end
		if preset.startup ~= nil then
			env.Alleral_UiStartup = preset.startup == true
		end
		if preset.touchFeedback ~= nil then
			env.Alleral_UiTouchFeedback = preset.touchFeedback ~= false
		end
		if preset.haptics ~= nil then
			env.Alleral_UiHaptics = preset.haptics == true
		end
		if preset.uiScale ~= nil then
			env.Alleral_UiScale = preset.uiScale
		end
	end

	local function resolveElementGap(window)
		local gap = tonumber(WindUI._AlleralElementGap)
			or (window and tonumber(window.ElementPadding))
			or WINDOW_DEFAULTS.ElementPadding
			or ALLERAL_TAB_GAP
		return math.clamp(math.floor(gap + 0.5), MAC.elementGap, 24)
	end

	local function polishScrollPadding(scroll)
		if not scroll or not scroll:IsA("ScrollingFrame") then
			return
		end
		scroll.ScrollBarThickness = 1
		scroll.ScrollBarImageTransparency = 0.5
		local pad = scroll:FindFirstChildOfClass("UIPadding")
		if not pad then
			pad = Instance.new("UIPadding")
			pad.Parent = scroll
		end
		pad.PaddingTop = UDim.new(0, MAC.scrollPadTop)
		pad.PaddingBottom = UDim.new(0, MAC.scrollPadBottom)
		pad.PaddingLeft = UDim.new(0, MAC.scrollPadLeft)
		pad.PaddingRight = UDim.new(0, MAC.scrollPadRight)
		local layout = scroll:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout.Padding = UDim.new(0, MAC.sectionGap)
		end
	end

	local function polishElementRowHeights(root)
		if not root then
			return
		end
		for _, desc in ipairs(root:GetDescendants()) do
			if desc:IsA("GuiObject") and desc.Name == "ToggleFrame" then
				local main = desc:FindFirstChild("Main")
				if main and main:IsA("GuiObject") and main.Size.Y.Offset < MAC.rowHeight then
					main.Size = UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, MAC.rowHeight)
				end
			elseif desc:IsA("GuiObject") and (desc.Name == "Button" or desc.Name == "Slider" or desc.Name == "Dropdown") then
				if desc.Size.Y.Offset > 0 and desc.Size.Y.Offset < MAC.rowHeight then
					desc.Size = UDim2.new(desc.Size.X.Scale, desc.Size.X.Offset, 0, MAC.rowHeight)
				end
			end
		end
	end

	local function applyTabGap(tab, gap)
		if type(tab) ~= "table" then
			return
		end
		tab.Gap = gap
		local scroll = tab.UIElements and tab.UIElements.ContainerFrame
		if scroll then
			local layout = scroll:FindFirstChildOfClass("UIListLayout")
			if layout then
				layout.Padding = UDim.new(0, gap)
			end
			polishScrollPadding(scroll)
		end
	end

	local function polishTabScrolling(window)
		if type(window) ~= "table" then
			return
		end
		local gap = resolveElementGap(window)
		window.Gap = gap
		window.ElementPadding = gap
		WindUI._AlleralElementGap = gap

		local tabMod = window.TabModule
		if tabMod and tabMod.Tabs then
			for _, tab in pairs(tabMod.Tabs) do
				applyTabGap(tab, gap)
			end
		end
	end

	local function hapticPulse()
		if WindUI._AlleralHaptics ~= true then
			return
		end
		pcall(function()
			local HapticService = game:GetService("HapticService")
			local inputType = UserInputService.TouchEnabled and Enum.UserInputType.Touch or Enum.UserInputType.Gamepad1
			HapticService:SetMotor(inputType, Enum.VibrationMotor.Small, 0.35)
			task.delay(0.06, function()
				pcall(function()
					HapticService:SetMotor(inputType, Enum.VibrationMotor.Small, 0)
				end)
			end)
		end)
	end

	local function safeFontFace(family, weight)
		local ok, font = pcall(function()
			return Font.new(family, weight)
		end)
		return ok and font or nil
	end

	local RESOURCES = {
		fonts = {
			ui = safeFontFace("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
			uiSemibold = safeFontFace("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
			uiTitle = safeFontFace("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
		},
		preload = {
			"rbxasset://fonts/families/GothamSSm.json",
		},
		tooltips = {
			showDelay = 0.32,
			showJitter = 0.07,
			hideDelay = 0.05,
			maxWidth = 248,
		},
		search = {
			placeholder = "Find a setting…",
			placeholderHint = "  ·  / or Ctrl+F",
			minChars = 1,
			maxResults = 8,
			debounce = 0.08,
			emptyHint = "No matches",
			footer = "↑↓   Enter   Esc",
		},
		motion = {
			jitterMin = 0.004,
			jitterMax = 0.014,
		},
	}

	local function preloadAssets()
		if WindUI._AlleralResourcesReady then
			return true
		end
		local list = RESOURCES.preload
		if not list or #list == 0 then
			return false
		end
		pcall(function()
			local ContentProvider = game:GetService("ContentProvider")
			ContentProvider:PreloadAsync(list)
		end)
		WindUI._AlleralResourcesReady = true
		return true
	end

	local tooltipState = {
		frame = nil,
		label = nil,
		token = 0,
	}

	local function ensureTooltipGui()
		if tooltipState.frame and tooltipState.frame.Parent then
			return tooltipState.frame, tooltipState.label
		end
		local parent = WindUI.TooltipGui
		if not parent then
			parent = Instance.new("ScreenGui")
			parent.Name = "AlleralTooltips"
			parent.ResetOnSpawn = false
			parent.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			parent.DisplayOrder = 950
			pcall(function()
				parent.Parent = game:GetService("CoreGui")
			end)
			if not parent.Parent then
				parent.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
			end
			WindUI.TooltipGui = parent
		end
		local card = Instance.new("Frame")
		card.Name = "AlleralTipCard"
		card.BackgroundColor3 = palette.card
		card.BackgroundTransparency = 0.06
		card.BorderSizePixel = 0
		card.AutomaticSize = Enum.AutomaticSize.XY
		card.Visible = false
		card.ZIndex = 20
		card.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = palette.divider
		stroke.Transparency = 0.88
		stroke.Thickness = 1
		stroke.Parent = card
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = card
		local scale = Instance.new("UIScale")
		scale.Name = "TipScale"
		scale.Scale = 0.96
		scale.Parent = card
		local label = Instance.new("TextLabel")
		label.Name = "Body"
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		pcall(function()
			label.FontFace = RESOURCES.fonts.ui
		end)
		label.TextSize = 13
		label.TextColor3 = palette.text
		label.TextTransparency = 0.12
		label.TextWrapped = true
		label.AutomaticSize = Enum.AutomaticSize.XY
		label.Size = UDim2.fromOffset(220, 0)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = card
		tooltipState.frame = card
		tooltipState.label = label
		return card, label
	end

	local function hideTooltip()
		tooltipState.token += 1
		local card = tooltipState.frame
		if not card then
			return
		end
		local hideDelay = RESOURCES.tooltips.hideDelay or 0.05
		task.delay(hideDelay, function()
			if card.Parent and card.Visible then
				local scale = card:FindFirstChild("TipScale")
				if scale and motionEnabled() then
					tween(scale, ANIM.micro, { Scale = 0.97 })
					tween(card, ANIM.micro, { BackgroundTransparency = 1 })
					task.delay(0.1, function()
						if card.Parent then
							card.Visible = false
						end
					end)
				else
					card.Visible = false
				end
			end
		end)
	end

	local function clampTooltipOffset(x, y, card)
		local camera = workspace.CurrentCamera
		if not camera or not card then
			return x, y
		end
		local viewport = camera.ViewportSize
		local width = math.max(card.AbsoluteSize.X, RESOURCES.tooltips.maxWidth or 220)
		local height = math.max(card.AbsoluteSize.Y, 40)
		x = math.clamp(x, width * 0.5 + 10, viewport.X - width * 0.5 - 10)
		y = math.clamp(y, height + 14, viewport.Y - 10)
		return x, y
	end

	local function showTooltip(text, anchor)
		text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" or not anchor or not anchor:IsA("GuiObject") then
			return
		end
		local card, label = ensureTooltipGui()
		if not card or not label then
			return
		end
		tooltipState.token += 1
		local title, body = text:match("^([^\n]+)\n(.+)$")
		if body then
			label.Text = title .. "\n" .. body
			label.TextSize = 13
		else
			label.Text = text
		end
		label.Size = UDim2.fromOffset(RESOURCES.tooltips.maxWidth or 248, 0)
		card.Visible = true
		card.BackgroundTransparency = 0.1
		local scale = card:FindFirstChild("TipScale")
		local pos = anchor.AbsolutePosition
		local size = anchor.AbsoluteSize
		local x = pos.X + size.X * 0.5
		local y = pos.Y - 6
		x, y = clampTooltipOffset(x, y, card)
		card.AnchorPoint = Vector2.new(0.5, 1)
		card.Position = UDim2.fromOffset(x, y)
		if scale then
			scale.Scale = 0.97
			tween(scale, ANIM.tooltip, { Scale = 1 })
		end
		tween(card, ANIM.tooltip, { BackgroundTransparency = 0.06 })
	end

	local function findTooltipTargets(row)
		local targets = {}
		if not row or not row:IsA("GuiObject") then
			return targets
		end
		local function addTarget(instance)
			if instance and instance:IsA("GuiObject") and not instance:FindFirstChild("AlleralTipHook") then
				table.insert(targets, instance)
			end
		end
		if row:IsA("TextButton") or row:IsA("ImageButton") then
			addTarget(row)
		end
		local hitbox = row:FindFirstChild("Hitbox", true)
		if hitbox and hitbox:IsA("GuiObject") then
			addTarget(hitbox)
		end
		for _, desc in ipairs(row:GetDescendants()) do
			if desc:IsA("TextButton") or desc:IsA("ImageButton") then
				addTarget(desc)
			end
		end
		if #targets == 0 then
			pcall(function()
				row.Active = true
				row.Selectable = true
			end)
			addTarget(row)
		end
		return targets
	end

	local function attachRowTooltip(row, text)
		text = tostring(text or "")
		if text == "" then
			return
		end
		local targets = findTooltipTargets(row)
		if #targets == 0 then
			return
		end
		local hoverToken = 0
		local showDelay = RESOURCES.tooltips.showDelay or 0.32
		local showJitter = RESOURCES.tooltips.showJitter or 0.07
		for _, target in ipairs(targets) do
			if target:FindFirstChild("AlleralTipHook") then
				continue
			end
			local hook = Instance.new("BoolValue")
			hook.Name = "AlleralTipHook"
			hook.Parent = target
			local function scheduleShow()
				hoverToken += 1
				local token = hoverToken
				local waitFor = showDelay + (math.random() * showJitter)
				task.delay(waitFor, function()
					if token == hoverToken and target.Parent then
						showTooltip(text, target)
					end
				end)
			end
			local function cancelShow()
				hoverToken += 1
				hideTooltip()
			end
			target.MouseEnter:Connect(scheduleShow)
			target.MouseLeave:Connect(cancelShow)
			if target:IsA("GuiButton") then
				target.SelectionGained:Connect(scheduleShow)
				target.SelectionLost:Connect(cancelShow)
			end
			target.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.Touch
					or input.UserInputType == Enum.UserInputType.MouseButton1
				then
					scheduleShow()
				end
			end)
		end
	end

	local function resolveElementRow(elem)
		if type(elem) ~= "table" then
			return nil
		end
		local row = elem.UIElements and elem.UIElements.Main
		local frames = {
			"ToggleFrame",
			"SliderFrame",
			"DropdownFrame",
			"InputFrame",
			"ButtonFrame",
			"CheckboxFrame",
			"KeybindFrame",
			"ParagraphFrame",
		}
		for _, key in ipairs(frames) do
			local frame = elem[key]
			if frame and frame.UIElements and frame.UIElements.Main then
				row = row or frame.UIElements.Main
			end
		end
		return row
	end

	local function hookElementTooltip(elem)
		if type(elem) ~= "table" or elem._ArrrelTipHooked then
			return
		end
		local text = elem.Desc or elem.Description or elem.Tooltip
		if (not text or text == "") and type(elem.UIElements) == "table" then
			text = elem.UIElements.Desc or elem.UIElements.Description
		end
		if not text or text == "" then
			return
		end
		elem._ArrrelTipHooked = true
		task.spawn(function()
			for _ = 1, 40 do
				local row = resolveElementRow(elem)
				if row and row.Parent then
					attachRowTooltip(row, text)
					return
				end
				task.wait(0.05)
			end
		end)
	end

	local function normalizeSearchText(value)
		return string.lower(tostring(value or "")):gsub("[%s%p]+", " ")
	end

	local function searchTokens(query)
		local tokens = {}
		for token in normalizeSearchText(query):gmatch("%S+") do
			if #token >= 1 then
				table.insert(tokens, token)
			end
		end
		return tokens
	end

	local function searchMatches(haystack, query)
		local tokens = searchTokens(query)
		if #tokens == 0 then
			return normalizeSearchText(haystack):find(normalizeSearchText(query), 1, true) ~= nil
		end
		for _, token in ipairs(tokens) do
			if not normalizeSearchText(haystack):find(token, 1, true) then
				return false
			end
		end
		return true
	end

	local function rankMatch(haystack, query, title)
		haystack = normalizeSearchText(haystack)
		title = normalizeSearchText(title)
		query = normalizeSearchText(query)
		if query == "" then
			return 0
		end
		if title == query then
			return 1200
		end
		if title:find("^" .. query, 1, true) then
			return 900 + math.min(80, #query * 8)
		end
		if haystack:find(query, 1, true) then
			return 650 + math.min(60, #query * 6)
		end
		local tokens = searchTokens(query)
		if #tokens == 0 then
			return haystack:find(query, 1, true) and 400 or 0
		end
		local score = 120
		for _, token in ipairs(tokens) do
			if title:find("^" .. token, 1, true) then
				score += 180
			elseif haystack:find(token, 1, true) then
				score += 100
			else
				return 0
			end
		end
		return score
	end

	local function walkSearchElements(container, tabIndex, tab, sectionPath, bucket)
		if type(container) ~= "table" then
			return
		end
		for elemIndex, elem in pairs(container.Elements or {}) do
			if type(elem) == "table" then
				local title = elem.Title or elem.Name
				local desc = elem.Desc or elem.Description
				local kind = elem.__type or "Item"
				local path = sectionPath
				if kind == "Section" and title then
					path = path == "" and tostring(title) or (path .. " / " .. tostring(title))
				end
				if title or desc then
					table.insert(bucket, {
						tabIndex = tabIndex,
						elemIndex = elemIndex,
						tabTitle = tab and tab.Title,
						title = title,
						desc = desc,
						kind = kind,
						path = path,
						element = elem,
						haystack = normalizeSearchText(
							(tab and tab.Title or "")
								.. " "
								.. path
								.. " "
								.. tostring(title or "")
								.. " "
								.. tostring(desc or "")
						),
					})
				end
				if kind == "Section" and elem.Elements then
					walkSearchElements(elem, tabIndex, tab, path, bucket)
				end
			end
		end
	end

	local function buildSearchIndex(window)
		local index = {}
		local tabMod = window and window.TabModule
		if not tabMod or not tabMod.Tabs then
			return index
		end
		for tabIndex, tab in pairs(tabMod.Tabs) do
			walkSearchElements(tab, tabIndex, tab, "", index)
		end
		window._AlleralSearchIndex = index
		return index
	end

	local function jumpToSearchHit(window, hit)
		if not window or not hit then
			return
		end
		local tabMod = window.TabModule
		if tabMod and type(tabMod.SelectTab) == "function" then
			pcall(function()
				tabMod:SelectTab(hit.tabIndex)
			end)
		elseif type(window.SelectTab) == "function" then
			pcall(function()
				window:SelectTab(hit.tabIndex)
			end)
		end
		task.defer(function()
			local tab = tabMod and tabMod.Tabs and tabMod.Tabs[hit.tabIndex]
			if tab and type(tab.ScrollToTheElement) == "function" and hit.elemIndex then
				pcall(function()
					tab:ScrollToTheElement(hit.elemIndex)
				end)
			elseif hit.element and type(hit.element.Highlight) == "function" then
				pcall(function()
					hit.element:Highlight()
				end)
			end
		end)
	end

	local function filterSettings(window, query)
		query = tostring(query or "")
		local index = window._AlleralSearchIndex or buildSearchIndex(window)
		local hits = {}
		local minChars = RESOURCES.search.minChars or 1
		if #normalizeSearchText(query) < minChars then
			window._AlleralSearchHits = hits
			window._AlleralSearchSelected = 0
			return hits
		end
		for _, entry in ipairs(index) do
			local score = rankMatch(entry.haystack, query, tostring(entry.title or ""))
			if score > 0 then
				entry._score = score
				table.insert(hits, entry)
			end
		end
		table.sort(hits, function(a, b)
			if a._score ~= b._score then
				return a._score > b._score
			end
			return tostring(a.title or "") < tostring(b.title or "")
		end)
		local maxResults = RESOURCES.search.maxResults or 8
		while #hits > maxResults do
			table.remove(hits)
		end
		window._AlleralSearchHits = hits
		window._AlleralSearchSelected = math.clamp(window._AlleralSearchSelected or 1, 1, math.max(1, #hits))
		return hits
	end

	local function getSearchPanel(window, anchor)
		if window._AlleralSearchPanel and window._AlleralSearchPanel.Parent then
			return window._AlleralSearchPanel
		end
		if not anchor or not anchor:IsA("GuiObject") then
			return nil
		end
		local host = anchor:FindFirstAncestorWhichIsA("Frame") or anchor.Parent
		if not host then
			return nil
		end

		local panel = Instance.new("Frame")
		panel.Name = "AlleralSearchPanel"
		panel.BackgroundColor3 = palette.card
		panel.BackgroundTransparency = 0.04
		panel.BorderSizePixel = 0
		panel.Visible = false
		panel.ClipsDescendants = true
		panel.ZIndex = anchor.ZIndex + 12
		panel.Parent = host
		safeEnsureCorner(panel, UDim.new(0, MAC.corner))
		ensureStroke(panel, "AlleralSearchPanelStroke", palette.divider, 0.9, 1, { inner = true })

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		pad.Parent = panel

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = panel

		local footer = Instance.new("TextLabel")
		footer.Name = "Footer"
		footer.BackgroundTransparency = 1
		footer.FontFace = RESOURCES.fonts.ui
		footer.TextSize = 11
		footer.TextColor3 = palette.muted
		footer.TextTransparency = 0.35
		footer.TextXAlignment = Enum.TextXAlignment.Left
		footer.Text = RESOURCES.search.footer or ""
		footer.Size = UDim2.new(1, 0, 0, 14)
		footer.LayoutOrder = 999
		footer.Parent = panel

		window._AlleralSearchPanel = panel
		window._AlleralSearchPanelRows = {}
		return panel
	end

	local function clearSearchPanelRows(window)
		local rows = window._AlleralSearchPanelRows
		if type(rows) == "table" then
			for _, row in ipairs(rows) do
				if row and row.Parent then
					row:Destroy()
				end
			end
		end
		window._AlleralSearchPanelRows = {}
	end

	local function drawSearchList(window, hits, query, anchor)
		local panel = getSearchPanel(window, anchor)
		if not panel then
			return
		end
		clearSearchPanelRows(window)
		local selected = window._AlleralSearchSelected or 1

		if #hits == 0 then
			local empty = Instance.new("TextLabel")
			empty.BackgroundTransparency = 1
			empty.FontFace = RESOURCES.fonts.ui
			empty.TextSize = 12
			empty.TextColor3 = palette.muted
			empty.TextTransparency = 0.25
			empty.TextXAlignment = Enum.TextXAlignment.Left
			empty.Text = RESOURCES.search.emptyHint or "No matches"
			empty.Size = UDim2.new(1, 0, 0, 28)
			empty.Parent = panel
			table.insert(window._AlleralSearchPanelRows, empty)
			panel.Size = UDim2.new(1, -8, 0, 52)
			panel.Position = UDim2.new(0, 4, 1, 6)
			panel.Visible = query ~= ""
			return
		end

		for index, hit in ipairs(hits) do
			local row = Instance.new("TextButton")
			row.Name = "Hit" .. tostring(index)
			row.AutoButtonColor = false
			row.BackgroundColor3 = palette.text
			row.BackgroundTransparency = index == selected and 0.9 or 1
			row.BorderSizePixel = 0
			row.FontFace = RESOURCES.fonts.uiSemibold
			row.TextSize = 12
			row.TextColor3 = palette.text
			row.TextTransparency = index == selected and 0.08 or 0.38
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Text = tostring(hit.title or "Setting")
			row.Size = UDim2.new(1, 0, 0, 28)
			row.LayoutOrder = index
			row.Parent = panel
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = row
			local sub = Instance.new("TextLabel")
			sub.BackgroundTransparency = 1
			sub.FontFace = RESOURCES.fonts.ui
			sub.TextSize = 11
			sub.TextColor3 = palette.muted
			sub.TextTransparency = 0.4
			sub.TextXAlignment = Enum.TextXAlignment.Left
			sub.Text = tostring(hit.path or hit.tabTitle or "")
			sub.Size = UDim2.new(1, -8, 0, 14)
			sub.Position = UDim2.new(0, 8, 0, 14)
			sub.Parent = row
			row.Size = UDim2.new(1, 0, 0, 34)
			row.MouseButton1Click:Connect(function()
				window._AlleralSearchSelected = index
				jumpToSearchHit(window, hit)
				panel.Visible = false
			end)
			table.insert(window._AlleralSearchPanelRows, row)
		end

		local rowH = 38
		panel.Size = UDim2.new(1, -8, 0, math.min(240, #hits * rowH + 26))
		panel.Position = UDim2.new(0, 4, 1, 6)
		panel.Visible = true
	end

	local function hideSearchPanel(window)
		local panel = window and window._AlleralSearchPanel
		if panel then
			panel.Visible = false
		end
	end

	local function setupSearch(window)
		if not window or window._AlleralSearchOn then
			return
		end
		window._AlleralSearchOn = true
		window._AlleralSearchSelected = 1
		buildSearchIndex(window)

		local function bindSearchBox(box)
			if not box or box:FindFirstChild("AlleralSearchBind") then
				return
			end
			local mark = Instance.new("BoolValue")
			mark.Name = "AlleralSearchBind"
			mark.Parent = box
			local placeholder = RESOURCES.search.placeholder or "Find a setting…"
			local hint = RESOURCES.search.placeholderHint or ""
			if box.PlaceholderText == "" or box.PlaceholderText == "Search" then
				box.PlaceholderText = placeholder .. hint
			end
			box.ClearTextOnFocus = false
			local debounceToken = 0
			local function refreshResults()
				local hits = filterSettings(window, box.Text)
				window._AlleralLastSearchQuery = box.Text
				window._AlleralLastSearchCount = #hits
				drawSearchList(window, hits, box.Text, box)
			end
			box:GetPropertyChangedSignal("Text"):Connect(function()
				debounceToken += 1
				local token = debounceToken
				task.delay(RESOURCES.search.debounce or 0.08, function()
					if token == debounceToken and box.Parent then
						refreshResults()
					end
				end)
			end)
			box.Focused:Connect(function()
				if box.Text ~= "" then
					refreshResults()
				end
			end)
			box.FocusLost:Connect(function()
				task.delay(0.12, function()
					if not box:IsFocused() then
						hideSearchPanel(window)
					end
				end)
			end)
			window._AlleralSearchBox = box
		end

		local sidebar = window.UIElements and window.UIElements.SideBarContainer
		if sidebar then
			for _, desc in ipairs(sidebar:GetDescendants()) do
				if desc:IsA("TextBox") then
					bindSearchBox(desc)
				end
			end
			sidebar.DescendantAdded:Connect(function(desc)
				if desc:IsA("TextBox") then
					task.defer(function()
						bindSearchBox(desc)
					end)
				end
			end)
		end

		if window.SearchBar and window.SearchBar.Frame then
			local box = window.SearchBar.Frame:FindFirstChildWhichIsA("TextBox", true)
			bindSearchBox(box)
		end

		pcall(function()
			if not WindUI._AlleralSearchKeys then
				WindUI._AlleralSearchKeys = true
				UserInputService.InputBegan:Connect(function(input, processed)
					local active = WindUI.Window
					if not active or not active._AlleralSearchOn then
						return
					end
					local sidebarActive = active.UIElements and active.UIElements.SideBarContainer
					local hits = active._AlleralSearchHits or {}
					local selected = active._AlleralSearchSelected or 1

					if input.KeyCode == Enum.KeyCode.Escape then
						hideSearchPanel(active)
						return
					end

					if input.KeyCode == Enum.KeyCode.Up then
						if #hits > 0 then
							active._AlleralSearchSelected = math.clamp(selected - 1, 1, #hits)
							drawSearchList(active, hits, active._AlleralLastSearchQuery or "", active._AlleralSearchBox)
						end
						return
					end

					if input.KeyCode == Enum.KeyCode.Down then
						if #hits > 0 then
							active._AlleralSearchSelected = math.clamp(selected + 1, 1, #hits)
							drawSearchList(active, hits, active._AlleralLastSearchQuery or "", active._AlleralSearchBox)
						end
						return
					end

					if processed then
						return
					end

					if input.KeyCode == Enum.KeyCode.F and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
						local searchBtn = sidebarActive and sidebarActive:FindFirstChild("Search", true)
						if searchBtn and searchBtn:IsA("GuiButton") then
							searchBtn:Activate()
						end
					elseif input.KeyCode == Enum.KeyCode.Slash and not UserInputService:GetFocusedTextBox() then
						local searchBtn = sidebarActive and sidebarActive:FindFirstChild("Search", true)
						if searchBtn and searchBtn:IsA("GuiButton") then
							searchBtn:Activate()
						end
					elseif input.KeyCode == Enum.KeyCode.Return and #hits > 0 then
						local hit = hits[selected] or hits[1]
						if hit then
							jumpToSearchHit(active, hit)
							hideSearchPanel(active)
						end
					end
				end)
			end
		end)
	end

	local function getSharedChrome()
		return {
			WindowShadow = Color3.fromHex("#000000"),
			WindowTopbarButtonIcon = palette.muted,
			SearchBarBorder = palette.line,
			SectionExpandIcon = palette.muted,
			DropdownTabBorder = palette.line,
			CheckboxBorder = palette.line,
			SliderThumb = Color3.fromHex("#ffffff"),
			Hover = accent(),
			BackgroundTransparency = 0,
		}
	end

	local function fullTheme(name, accentCol, bg, panel, text, muted, button, tabActive)
		return mergeTokens(getSharedChrome(), {
			Name = name,
			Accent = accentCol,
			Primary = accentCol,
			Outline = palette.divider,
			Icon = accentCol,
			Toggle = accentCol,
			Slider = button,
			Checkbox = accentCol,
			SliderIcon = button,
			Dialog = panel,
			Background = bg,
			Button = button,
			Text = text,
			Placeholder = muted,
			PanelBackground = panel,
			PanelBackgroundTransparency = 0.04,
			LabelBackground = palette.surface,
			LabelBackgroundTransparency = 0.06,
			ElementBackground = palette.card,
			ElementBackgroundTransparency = 1,
			ElementTitle = text,
			ElementDesc = muted,
			ElementIcon = accentCol,
			TabBackground = bg,
			TabBackgroundHover = palette.cardHover,
			TabBackgroundHoverTransparency = 0.96,
			TabBackgroundActive = palette.text,
			TabBackgroundActiveTransparency = 0.92,
			TabText = text,
			TabTextTransparency = MAC.tabInactiveText,
			TabTextTransparencyActive = 0.08,
			TabIcon = muted,
			TabIconTransparency = MAC.tabInactiveIcon,
			TabIconTransparencyActive = 0.12,
			TabBorder = palette.divider,
			TabBorderTransparency = 0.94,
			TabBorderTransparencyActive = 0.9,
			WindowBackground = bg,
			WindowTopbarTitle = text,
			WindowTopbarAuthor = muted,
			WindowTopbarIcon = accentCol,
			WindowSearchBarBackground = palette.surface,
			SearchBarBorderTransparency = 0.92,
			SectionBoxBackground = palette.text,
			SectionBoxBackgroundTransparency = MAC.sectionFillTransparency,
			SectionBoxBorder = palette.divider,
			SectionBoxBorderTransparency = MAC.sectionStrokeTransparency,
			SectionExpandIconTransparency = 0.35,
			Notification = palette.card,
			NotificationTitle = text,
			NotificationContent = muted,
			NotificationBorder = palette.divider,
			NotificationBorderTransparency = 0.92,
			PopupBackground = palette.card,
			DialogBackground = palette.card,
			ToggleBar = accentCol,
			CheckboxBorderTransparency = 0.92,
			Tooltip = palette.card,
			TooltipText = text,
		})
	end

	local function buildThemePack()
		local arrrel = fullTheme(
			"Arrrel",
			accent(),
			palette.canvas,
			palette.surface,
			palette.text,
			palette.muted,
			accentSoft(),
			palette.cardHover
		)
		local arrrelNeon = fullTheme(
			"ArrrelNeon",
			accentHot(),
			Color3.fromHex("#040406"),
			Color3.fromHex("#0c0c12"),
			palette.text,
			palette.muted,
			accent(),
			Color3.fromHex("#22222c")
		)
		local arrrelMidnight = fullTheme(
			"ArrrelMidnight",
			Color3.fromHex("#3ddc84"),
			Color3.fromHex("#030304"),
			Color3.fromHex("#0b0b10"),
			Color3.fromHex("#ececf1"),
			Color3.fromHex("#7c7c86"),
			Color3.fromHex("#2ecc71"),
			Color3.fromHex("#181820")
		)
		local arrrelAurora = fullTheme(
			"ArrrelAurora",
			Color3.fromHex("#7cf7ff"),
			Color3.fromHex("#05050a"),
			Color3.fromHex("#0d0d16"),
			Color3.fromHex("#eef6ff"),
			Color3.fromHex("#8b9cb8"),
			Color3.fromHex("#5ee7ff"),
			Color3.fromHex("#151522")
		)
		local dark = fullTheme(
			"Dark",
			accent(),
			palette.canvas,
			palette.surface,
			palette.text,
			palette.muted,
			accentSoft(),
			palette.cardHover
		)
		return {
			Arrrel = arrrel,
			ArrrelNeon = arrrelNeon,
			ArrrelMidnight = arrrelMidnight,
			ArrrelAurora = arrrelAurora,
			Dark = dark,
			Alleral = arrrel,
			AlleralNeon = arrrelNeon,
			AlleralMidnight = arrrelMidnight,
		}
	end

	local THEME_PACK = buildThemePack()

	local function installThemes()
		local pack = buildThemePack()
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

	installThemes()

	local function resolveThemeName(requested)
		local themes = WindUI.Themes or {}
		if type(requested) == "string" and themes[requested] then
			return requested
		end
		if themes.Arrrel then
			return "Arrrel"
		end
		if themes.Alleral then
			return "Alleral"
		end
		if themes.Dark then
			return "Dark"
		end
		for name in pairs(themes) do
			return name
		end
		return "Dark"
	end

	-- -------------------------------------------------------------------------
	-- Visual polish
	-- -------------------------------------------------------------------------

	local function ensureStroke(frame, name, color, transparency, thickness, opts)
		opts = opts or {}
		if not frame or not frame:IsA("GuiObject") then
			return nil
		end
		if isDropdownDescendant(frame) then
			return nil
		end
		local stroke = frame:FindFirstChild(name)
		if not stroke and opts.reuseExisting ~= false then
			stroke = frame:FindFirstChildOfClass("UIStroke")
			if stroke and stroke.Name:sub(1, 7) ~= "Alleral" then
				stroke.Name = name
			end
		end
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = name
			stroke.Parent = frame
		end
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.BorderStrokePosition = opts.inner == false and Enum.BorderStrokePosition.Center
			or Enum.BorderStrokePosition.Inner
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Color = color or palette.line
		stroke.Thickness = thickness or 1
		stroke.Transparency = transparency or 0.55
		return stroke
	end

	local function ensureCorner(frame, radius)
		if not frame or not frame:IsA("GuiObject") then
			return nil
		end
		local corner = frame:FindFirstChildOfClass("UICorner")
		if not corner then
			corner = Instance.new("UICorner")
			corner.CornerRadius = radius or UDim.new(0, 10)
			corner.Parent = frame
		end
		return corner
	end

	local function ensureGradient(frame, name, keypoints, rotation)
		if not frame or not frame:IsA("GuiObject") then
			return nil
		end
		local gradient = frame:FindFirstChild(name)
		if not gradient then
			gradient = Instance.new("UIGradient")
			gradient.Name = name
			gradient.Parent = frame
		end
		gradient.Color = ColorSequence.new(keypoints or {
			ColorSequenceKeypoint.new(0, palette.accent),
			ColorSequenceKeypoint.new(1, palette.accentSoft),
		})
		gradient.Rotation = rotation or 0
		return gradient
	end

	local function addWindowGlow(main)
		if not main or not main:IsA("GuiObject") then
			return
		end
		local parent = main.Parent
		if not parent or parent:FindFirstChild("ArrrelWindowGlow") then
			return
		end
		local glow = Instance.new("Frame")
		glow.Name = "ArrrelWindowGlow"
		glow.BackgroundColor3 = palette.glow
		glow.BackgroundTransparency = 0.94
		glow.BorderSizePixel = 0
		glow.Size = UDim2.new(1, MAC.glowSpread * 2, 1, MAC.glowSpread * 2)
		glow.Position = UDim2.new(0, -MAC.glowSpread, 0, -MAC.glowSpread)
		glow.ZIndex = math.max(0, main.ZIndex - 3)
		glow.Parent = parent
		if parent then
			glow.LayoutOrder = (main.LayoutOrder or 0) - 1
		end
		ensureCorner(glow, UDim.new(0, MAC.corner + 6))
		local gradient = ensureGradient(glow, "ArrrelGlowGradient", {
			ColorSequenceKeypoint.new(0, palette.accent),
			ColorSequenceKeypoint.new(0.55, palette.accentSoft),
			ColorSequenceKeypoint.new(1, palette.canvas),
		}, 135)
		if gradient then
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.82),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	end

	local function addTopbarSheen(topbar)
		if not topbar or not topbar:IsA("GuiObject") or topbar:FindFirstChild("ArrrelTopbarSheen") then
			return
		end
		local sheen = Instance.new("Frame")
		sheen.Name = "ArrrelTopbarSheen"
		sheen.BackgroundColor3 = palette.text
		sheen.BackgroundTransparency = 0.97
		sheen.BorderSizePixel = 0
		sheen.Size = UDim2.new(1, 0, 0.55, 0)
		sheen.ZIndex = topbar.ZIndex + 1
		sheen.Parent = topbar
		ensureGradient(sheen, "ArrrelTopbarSheenGradient", {
			ColorSequenceKeypoint.new(0, palette.accent),
			ColorSequenceKeypoint.new(1, palette.canvas),
		}, 90)
		local sheenGradient = sheen:FindFirstChild("ArrrelTopbarSheenGradient")
		if sheenGradient then
			sheenGradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.92),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	end

	local SLICE_GLASS_IMAGES = {
		["rbxassetid://79047752995006"] = true,
		["rbxassetid://97324581055162"] = true,
		["rbxassetid://95071123641270"] = true,
	}

	local function isSliceChrome(gui)
		return gui:IsA("ImageLabel") and gui.ScaleType == Enum.ScaleType.Slice
	end

	local function isGlassOrOutlineOverlay(gui)
		if not isSliceChrome(gui) then
			return false
		end
		if gui.Name == "Outline" or gui.Name == "Shadow" then
			return true
		end
		return SLICE_GLASS_IMAGES[gui.Image] == true
	end

	local function hideSliceOverlay(gui)
		if not gui or not gui:IsA("ImageLabel") then
			return
		end
		gui.Visible = false
		gui.ImageTransparency = 1
	end

	local function stripSliceChrome(root)
		if not root then
			return
		end
		for _, desc in ipairs(root:GetDescendants()) do
			if isGlassOrOutlineOverlay(desc) then
				hideSliceOverlay(desc)
			end
		end
		if root:IsA("GuiObject") then
			for _, child in ipairs(root:GetChildren()) do
				if isGlassOrOutlineOverlay(child) then
					hideSliceOverlay(child)
				end
			end
		end
	end

	local function safeEnsureCorner(gui, radius)
		if not gui or not gui:IsA("GuiObject") or isSliceChrome(gui) then
			return nil
		end
		return ensureCorner(gui, radius)
	end

	local function polishSectionOutlines(root)
		if not root then
			return
		end
		for _, desc in ipairs(root:GetDescendants()) do
			if desc.Name == "Outline" and desc:IsA("ImageLabel") and not isDropdownDescendant(desc) then
				hideSliceOverlay(desc)
				local box = desc.Parent
				if box and box:IsA("GuiObject") and not box:FindFirstChild("AlleralCardShell") then
					stripSliceChrome(box)
					local shell = Instance.new("Frame")
					shell.Name = "AlleralCardShell"
					shell.BackgroundTransparency = 1
					shell.Size = UDim2.fromScale(1, 1)
					shell.ZIndex = box.ZIndex + 1
					shell.Active = false
					shell.ClipsDescendants = false
					shell.Parent = box
					ensureStroke(shell, "AlleralCardStroke", palette.divider, MAC.sectionStrokeTransparency, 1, {
						inner = true,
						reuseExisting = false,
					})
					local wash = Instance.new("Frame")
					wash.Name = "ArrrelCardWash"
					wash.BackgroundColor3 = palette.accent
					wash.BackgroundTransparency = 0.97
					wash.BorderSizePixel = 0
					wash.Size = UDim2.fromScale(1, 1)
					wash.ZIndex = shell.ZIndex
					wash.Parent = shell
					safeEnsureCorner(wash, UDim.new(0, MAC.corner))
					ensureGradient(wash, "ArrrelCardWashGradient", {
						ColorSequenceKeypoint.new(0, palette.accent),
						ColorSequenceKeypoint.new(1, palette.canvas),
					}, 160)
				end
			end
		end
	end

	local function polishSectionSpacing(root, gap)
		if not root then
			return
		end
		local innerGap = math.max(MAC.sectionInner, gap - 4)
		for _, desc in ipairs(root:GetDescendants()) do
			if desc.Name == "Content" and desc:IsA("Frame") then
				local layout = desc:FindFirstChildOfClass("UIListLayout")
				if layout then
					layout.Padding = UDim.new(0, innerGap)
				end
				local pad = desc:FindFirstChildOfClass("UIPadding")
				if not pad then
					pad = Instance.new("UIPadding")
					pad.Parent = desc
				end
				pad.PaddingTop = UDim.new(0, MAC.sectionPadTop)
				pad.PaddingBottom = UDim.new(0, MAC.sectionPadBottom)
				pad.PaddingLeft = UDim.new(0, MAC.sectionPadLeft)
				pad.PaddingRight = UDim.new(0, MAC.sectionPadRight)
			end
		end
	end

	local function polishRowChrome(root)
		if not root then
			return
		end
		for _, desc in ipairs(root:GetDescendants()) do
			if desc.Name == "Outline" and desc:IsA("ImageLabel") and not isDropdownDescendant(desc) then
				local box = desc.Parent
				if box and box:FindFirstChild("AlleralCardShell") then
					continue
				end
				hideSliceOverlay(desc)
				if box then
					stripSliceChrome(box)
				end
			end
		end
	end

	local function polishSidebarSpacing(sidebar)
		if not sidebar then
			return
		end
		local frame = sidebar:FindFirstChild("Frame") or sidebar
		local layout = frame:FindFirstChildWhichIsA("UIListLayout", true)
		if layout then
			layout.Padding = UDim.new(0, 4)
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		end
		for _, pad in ipairs(frame:GetDescendants()) do
			if pad:IsA("UIPadding") then
				local parent = pad.Parent
				if parent and (parent.Name == "Frame" or parent:IsA("ScrollingFrame")) then
					pad.PaddingLeft = UDim.new(0, MAC.sidebarPadX)
					pad.PaddingRight = UDim.new(0, MAC.sidebarPadX)
					pad.PaddingTop = UDim.new(0, MAC.sidebarPadTop)
					pad.PaddingBottom = UDim.new(0, 88)
				end
			end
		end
	end

	local function installSidebarProfile(window)
		if not window or window._ArrrelSidebarProfile then
			return
		end
		local sidebar = window.UIElements and window.UIElements.SideBar
		if not sidebar or not sidebar:IsA("GuiObject") then
			return
		end
		local host = sidebar:FindFirstChild("Frame") or sidebar
		if host:FindFirstChild("ArrrelSidebarProfile") then
			window._ArrrelSidebarProfile = true
			return
		end
		window._ArrrelSidebarProfile = true

		local Players = game:GetService("Players")
		local lp = Players.LocalPlayer
		local displayName = lp and ((lp.DisplayName ~= "" and lp.DisplayName) or lp.Name) or "Player"
		local userName = lp and lp.Name or "player"

		local card = Instance.new("Frame")
		card.Name = "ArrrelSidebarProfile"
		card.BackgroundColor3 = palette.card
		card.BackgroundTransparency = 0.35
		card.BorderSizePixel = 0
		card.Size = UDim2.new(1, -(MAC.sidebarPadX * 2), 0, 62)
		card.AnchorPoint = Vector2.new(0.5, 1)
		card.Position = UDim2.new(0.5, 0, 1, -14)
		card.ZIndex = sidebar.ZIndex + 4
		card.Parent = host
		ensureCorner(card, UDim.new(0, 10))
		ensureStroke(card, "ArrrelProfileStroke", palette.divider, 0.9, 1, { inner = true })

		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.BackgroundColor3 = palette.surface
		avatar.BackgroundTransparency = 0.2
		avatar.BorderSizePixel = 0
		avatar.Size = UDim2.fromOffset(36, 36)
		avatar.Position = UDim2.fromOffset(12, 13)
		avatar.ZIndex = card.ZIndex + 1
		avatar.Parent = card
		ensureCorner(avatar, UDim.new(1, 0))
		ensureStroke(avatar, "ArrrelAvatarStroke", accent(), 0.55, 1, { inner = true })

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "DisplayName"
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, -62, 0, 18)
		nameLabel.Position = UDim2.fromOffset(56, 14)
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextSize = 13
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextColor3 = palette.text
		nameLabel.TextTransparency = 0.06
		nameLabel.Text = displayName
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.ZIndex = card.ZIndex + 1
		nameLabel.Parent = card

		local handleLabel = Instance.new("TextLabel")
		handleLabel.Name = "UserName"
		handleLabel.BackgroundTransparency = 1
		handleLabel.Size = UDim2.new(1, -62, 0, 14)
		handleLabel.Position = UDim2.fromOffset(56, 32)
		handleLabel.Font = Enum.Font.Gotham
		handleLabel.TextSize = 11
		handleLabel.TextXAlignment = Enum.TextXAlignment.Left
		handleLabel.TextColor3 = palette.muted
		handleLabel.TextTransparency = 0.2
		handleLabel.Text = "@" .. userName
		handleLabel.TextTruncate = Enum.TextTruncate.AtEnd
		handleLabel.ZIndex = card.ZIndex + 1
		handleLabel.Parent = card

		local dot = Instance.new("Frame")
		dot.Name = "OnlineDot"
		dot.BackgroundColor3 = accent()
		dot.BackgroundTransparency = 0.12
		dot.BorderSizePixel = 0
		dot.Size = UDim2.fromOffset(8, 8)
		dot.Position = UDim2.fromOffset(42, 42)
		dot.ZIndex = card.ZIndex + 2
		dot.Parent = card
		ensureCorner(dot, UDim.new(1, 0))

		if lp and lp.UserId > 0 then
			task.spawn(function()
				local ok, content = pcall(function()
					return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				end)
				if ok and content and avatar.Parent then
					avatar.Image = content
				end
			end)
		end
	end

	local function addTopbarLine(topbar)
		if not topbar or not topbar:IsA("GuiObject") then
			return
		end
		if topbar:FindFirstChild("AlleralTopbarLine") then
			return
		end
		local line = Instance.new("Frame")
		line.Name = "AlleralTopbarLine"
		line.BackgroundColor3 = palette.accent
		line.BackgroundTransparency = 0.72
		line.BorderSizePixel = 0
		line.Size = UDim2.new(1, 0, 0, 1)
		line.Position = UDim2.new(0, 0, 1, -1)
		line.ZIndex = topbar.ZIndex + 2
		line.Parent = topbar
		ensureGradient(line, "ArrrelTopbarLineGradient", {
			ColorSequenceKeypoint.new(0, palette.accent),
			ColorSequenceKeypoint.new(0.5, palette.accentSoft),
			ColorSequenceKeypoint.new(1, palette.divider),
		}, 0)
	end

	local function polishTopbarBrand(window)
		local topbar = window.UIElements and window.UIElements.Topbar
		local main = topbar and topbar.Main
		if not main or not main:IsA("GuiObject") then
			return
		end
		if main.Size.Y.Offset > 0 and main.Size.Y.Offset ~= MAC.topbarHeight then
			main.Size = UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, MAC.topbarHeight)
		end
		addTopbarSheen(main)
		for _, desc in ipairs(main:GetDescendants()) do
			if desc:IsA("TextLabel") then
				if desc.TextSize >= 18 then
					desc.TextTransparency = math.min(desc.TextTransparency, 0.04)
				elseif desc.TextSize >= 17 then
					desc.TextTransparency = math.min(desc.TextTransparency, 0.06)
				elseif desc.TextSize <= 14 and desc.TextTransparency < 0.35 then
					desc.TextTransparency = 0.4
				end
			end
		end
	end

	local function polishLabelTone(root)
		if not root then
			return
		end
		for _, desc in ipairs(root:GetDescendants()) do
			if desc:IsA("TextLabel") then
				local name = desc.Name:lower()
				if name:find("desc") or name:find("description") or name:find("subtitle") then
					if desc.TextTransparency < 0.4 then
						desc.TextTransparency = MAC.rowLabelTransparency
					end
				elseif name == "title" and desc.TextSize >= 13 and desc.TextSize <= 15 then
					if desc.TextTransparency > 0.35 and desc.TextTransparency < 0.85 then
						desc.TextTransparency = MAC.rowLabelTransparency
					end
				elseif name == "title" and desc.TextSize >= 14 and desc.TextSize <= 16 then
					local parent = desc.Parent
					if parent and parent.Name == "Title" then
						desc.TextTransparency = math.min(desc.TextTransparency, 0.08)
					end
				end
			end
		end
	end

	local function polishContentChrome(window)
		local tabMod = window.TabModule
		if tabMod and tabMod.Tabs then
			for _, tab in pairs(tabMod.Tabs) do
				local canvas = tab.UIElements and tab.UIElements.ContainerFrameCanvas
				if canvas then
					local pad = canvas:FindFirstChildOfClass("UIPadding")
					if not pad then
						pad = Instance.new("UIPadding")
						pad.Parent = canvas
					end
					pad.PaddingLeft = UDim.new(0, MAC.contentPadX)
					pad.PaddingRight = UDim.new(0, MAC.contentPadX)
				end
				local scroll = tab.UIElements and tab.UIElements.ContainerFrame
				if scroll then
					polishScrollPadding(scroll)
				end
			end
		end
		if window.UIElements and window.UIElements.MainBar then
			polishLabelTone(window.UIElements.MainBar)
		end
		if window.UIElements and window.UIElements.Main then
			polishLabelTone(window.UIElements.Main)
		end
	end

	local function syncWindowStroke(main)
		if not main then
			return nil
		end
		safeEnsureCorner(main, UDim.new(0, MAC.corner))
		addWindowGlow(main)
		return ensureStroke(main, "AlleralWindowStroke", palette.divider, MAC.windowStrokeTransparency, 1, { inner = true })
	end

	local function addSidebarDivider(sidebar)
		if not sidebar or not sidebar:IsA("GuiObject") then
			return
		end
		if sidebar:FindFirstChild("AlleralSidebarDivider") then
			return
		end

		local divider = Instance.new("Frame")
		divider.Name = "AlleralSidebarDivider"
		divider.BackgroundColor3 = palette.divider
		divider.BackgroundTransparency = MAC.dividerTransparency
		divider.BorderSizePixel = 0
		divider.Size = UDim2.new(0, 1, 1, 0)
		divider.Position = UDim2.new(1, -1, 0, 0)
		divider.ZIndex = sidebar.ZIndex + 2
		divider.Parent = sidebar
	end

	local function polishSearchBar(searchBar)
		if not searchBar or not searchBar.Frame then
			return
		end
		local search = searchBar.Frame
		safeEnsureCorner(search, UDim.new(0, 8))
		local stroke = ensureStroke(search, "AlleralSearchStroke", palette.divider, 0.92, 1, { inner = true })
		local box = search:FindFirstChildWhichIsA("TextBox", true)
		if not box or box:FindFirstChild("AlleralSearchHook") then
			return
		end
		local hook = Instance.new("BoolValue")
		hook.Name = "AlleralSearchHook"
		hook.Parent = box
		box.Focused:Connect(function()
			if stroke then
				tween(stroke, ANIM.micro, {
					Color = accent(),
					Transparency = 0.78,
				})
			end
		end)
		box.FocusLost:Connect(function()
			if stroke then
				tween(stroke, ANIM.micro, {
					Color = palette.divider,
					Transparency = 0.92,
				})
			end
		end)
		if box.PlaceholderText == "" or box.PlaceholderText == "Search" then
			box.PlaceholderText = (RESOURCES.search.placeholder or "Find a setting…")
				.. (RESOURCES.search.placeholderHint or "")
		end
	end

	local function installTabRail(window)
		if not window or window._AlleralTabRail then
			return
		end
		local tabMod = window.TabModule
		if not tabMod or type(tabMod.OnChange) ~= "function" then
			return
		end
		window._AlleralTabRail = true

		local function ensureTabChrome(main)
			if not main or not main:IsA("GuiObject") then
				return nil, nil
			end
			local pad = main:FindFirstChild("AlleralTabPad")
			if not pad then
				pad = Instance.new("UIPadding")
				pad.Name = "AlleralTabPad"
				pad.PaddingLeft = UDim.new(0, MAC.tabPadLeft)
				pad.PaddingRight = UDim.new(0, MAC.tabPadRight)
				pad.Parent = main
			end
			if main.Size.Y.Offset > 0 and main.Size.Y.Offset < MAC.tabHeight then
				main.Size = UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, MAC.tabHeight)
			end
			main.BackgroundTransparency = 1
			local iconFrame = main:FindFirstChild("ArrrelTabIconRing")
			if not iconFrame then
				for _, desc in ipairs(main:GetDescendants()) do
					if desc:IsA("ImageLabel") and desc.Name:lower():find("icon") then
						iconFrame = Instance.new("Frame")
						iconFrame.Name = "ArrrelTabIconRing"
						iconFrame.BackgroundColor3 = palette.text
						iconFrame.BackgroundTransparency = 1
						iconFrame.BorderSizePixel = 0
						iconFrame.Size = UDim2.fromOffset(math.max(desc.AbsoluteSize.X, 22) + 8, math.max(desc.AbsoluteSize.Y, 22) + 8)
						iconFrame.AnchorPoint = Vector2.new(0.5, 0.5)
						iconFrame.Position = UDim2.new(desc.Position.X.Scale, desc.Position.X.Offset + desc.Size.X.Offset * 0.5, desc.Position.Y.Scale, desc.Position.Y.Offset + desc.Size.Y.Offset * 0.5)
						iconFrame.ZIndex = desc.ZIndex - 1
						iconFrame.Parent = main
						ensureCorner(iconFrame, UDim.new(1, 0))
						break
					end
				end
			end
			local activeBg = main:FindFirstChild("AlleralTabActiveBg")
			if not activeBg then
				activeBg = Instance.new("Frame")
				activeBg.Name = "AlleralTabActiveBg"
				activeBg.BackgroundColor3 = palette.text
				activeBg.BackgroundTransparency = 1
				activeBg.BorderSizePixel = 0
				activeBg.Size = UDim2.new(1, -(MAC.tabPadRight + 4), 1, -8)
				activeBg.Position = UDim2.new(0, 2, 0, 4)
				activeBg.ZIndex = math.max(1, main.ZIndex - 1)
				activeBg.Parent = main
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 8)
				corner.Parent = activeBg
				ensureStroke(activeBg, "AlleralTabActiveStroke", palette.divider, 1, 1, {
					reuseExisting = false,
				})
			end
			local tabRail = main:FindFirstChild("ArrrelTabRail")
			if not tabRail then
				tabRail = Instance.new("Frame")
				tabRail.Name = "ArrrelTabRail"
				tabRail.BackgroundColor3 = accent()
				tabRail.BackgroundTransparency = 1
				tabRail.BorderSizePixel = 0
				tabRail.Size = UDim2.new(0, 3, 1, -12)
				tabRail.Position = UDim2.new(0, 0, 0, 6)
				tabRail.ZIndex = main.ZIndex + 3
				tabRail.Parent = main
				ensureCorner(tabRail, UDim.new(1, 0))
			end
			local hoverBg = main:FindFirstChild("AlleralTabHoverBg")
			if not hoverBg then
				hoverBg = Instance.new("Frame")
				hoverBg.Name = "AlleralTabHoverBg"
				hoverBg.BackgroundColor3 = palette.text
				hoverBg.BackgroundTransparency = 1
				hoverBg.BorderSizePixel = 0
				hoverBg.Size = activeBg.Size
				hoverBg.Position = activeBg.Position
				hoverBg.ZIndex = activeBg.ZIndex
				hoverBg.Parent = main
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 8)
				corner.Parent = hoverBg
			end
			local legacyPill = main:FindFirstChild("AlleralTabPill")
			if legacyPill then
				legacyPill:Destroy()
			end
			return activeBg, hoverBg
		end

		local function syncTabLabels(main, isActive)
			for _, label in ipairs(main:GetDescendants()) do
				if label:IsA("TextLabel") then
					tween(label, ANIM.micro, {
						TextTransparency = isActive and 0.08 or MAC.tabInactiveText,
					})
				elseif label:IsA("ImageLabel") and label.Name:lower():find("icon") then
					tween(label, ANIM.micro, {
						ImageTransparency = isActive and 0.12 or MAC.tabInactiveIcon,
					})
				end
			end
		end

		local function hookTabHover(main, hoverBg, tabIndex)
			if not main or main:FindFirstChild("AlleralTabHover") then
				return
			end
			local hook = Instance.new("BoolValue")
			hook.Name = "AlleralTabHover"
			hook.Parent = main
			main.MouseEnter:Connect(function()
				local current = tabMod.SelectedTab or window.CurrentTab
				if tabIndex == current or not hoverBg then
					return
				end
				tween(hoverBg, ANIM.micro, { BackgroundTransparency = 0.96 })
			end)
			main.MouseLeave:Connect(function()
				if hoverBg then
					tween(hoverBg, ANIM.micro, { BackgroundTransparency = 1 })
				end
			end)
		end

		local function syncMacTabs(index)
			if not tabMod.Tabs then
				return
			end
			for tabIndex, tab in pairs(tabMod.Tabs) do
				local main = tab.UIElements and tab.UIElements.Main
				if main and main:IsA("GuiObject") then
					local activeBg, hoverBg = ensureTabChrome(main)
					local isActive = tabIndex == index
					if activeBg then
						tween(activeBg, ANIM.tab, {
							BackgroundColor3 = isActive and accent() or palette.text,
							BackgroundTransparency = isActive and 0.88 or 1,
						})
						local iconRing = main:FindFirstChild("ArrrelTabIconRing")
						if iconRing then
							tween(iconRing, ANIM.micro, {
								BackgroundTransparency = isActive and 0.9 or 1,
								BackgroundColor3 = isActive and accent() or palette.text,
							})
						end
						local stroke = activeBg:FindFirstChild("AlleralTabActiveStroke")
						if stroke then
							tween(stroke, ANIM.micro, {
								Color = isActive and accent() or palette.divider,
								Transparency = isActive and 0.72 or 1,
							})
						end
						local rail = main:FindFirstChild("ArrrelTabRail")
						if rail then
							tween(rail, ANIM.micro, {
								BackgroundTransparency = isActive and 0.18 or 1,
							})
						end
					end
					if hoverBg and isActive then
						hoverBg.BackgroundTransparency = 1
					end
					syncTabLabels(main, isActive)
					hookTabHover(main, hoverBg, tabIndex)
				end
			end
		end

		local function syncPill(index)
			syncMacTabs(index)
		end

		tabMod:OnChange(function(index)
			syncPill(index)
		end)

		local active = tabMod.SelectedTab or window.CurrentTab
		if active then
			task.defer(function()
				syncPill(active)
			end)
		end
	end

	local function applyWindowScale(window)
		if not window or type(window.SetUIScale) ~= "function" then
			return
		end
		local scale = tonumber(WindUI._AlleralUiScale) or 1
		if scale > 0 and scale ~= 1 then
			pcall(function()
				window:SetUIScale(scale)
			end)
		end
	end

	function WindUI.PolishWindow(_self, window)
		if type(window) ~= "table" or type(window.UIElements) ~= "table" then
			return window
		end

		pcall(function()
			local main = window.UIElements.Main
			if main then
				cleanupLegacyPolish(main)
				syncWindowStroke(main)
			end

			local topbar = window.UIElements.Topbar
			if topbar and topbar.Main then
				addTopbarLine(topbar.Main)
				polishTopbarBrand(window)
			end

			local sidebar = window.UIElements.SideBar
			if sidebar then
				addSidebarDivider(sidebar)
				polishSidebarSpacing(sidebar)
				installSidebarProfile(window)
			end

			if window.SearchBar and window.SearchBar.Frame then
				polishSearchBar(window.SearchBar)
			end

			if window.UIElements.MainBar then
				polishSectionOutlines(window.UIElements.MainBar)
				polishRowChrome(window.UIElements.MainBar)
				polishSectionSpacing(window.UIElements.MainBar, resolveElementGap(window))
				polishElementRowHeights(window.UIElements.MainBar)
				polishLabelTone(window.UIElements.MainBar)
			end
			polishContentChrome(window)
			if main then
				task.defer(function()
					if window.UIElements and window.UIElements.Main == main and main.Parent then
						local gap = resolveElementGap(window)
						polishSectionOutlines(main)
						polishRowChrome(main)
						polishSectionSpacing(main, gap)
						polishElementRowHeights(main)
						polishTabScrolling(window)
						local tabMod = window.TabModule
						if tabMod and tabMod.Tabs then
							for _, tab in pairs(tabMod.Tabs) do
								local scroll = tab.UIElements and tab.UIElements.ContainerFrame
								if scroll then
									polishScrollPadding(scroll)
								end
							end
						end
					end
				end)
			end

			window.CanDropdown = true
			installTabRail(window)
			polishTabScrolling(window)
			setupSearch(window)
			buildSearchIndex(window)
		end)

		return window
	end

	local function normalizeWindowSettings(settings)
		settings = type(settings) == "table" and settings or {}
		local userKeys = {}
		for key in pairs(settings) do
			userKeys[key] = true
		end

		local presetName = resolveProfileName(WindUI._AlleralProfile)
		local preset = PROFILE_PRESETS[presetName]
		if preset then
			if not userKeys.UICorner and preset.corner then
				settings.UICorner = preset.corner
			end
			if not userKeys.UIPadding and preset.padding then
				settings.UIPadding = preset.padding
			end
			if not userKeys.SideBarWidth and preset.sidebar then
				settings.SideBarWidth = preset.sidebar
			end
			if not userKeys.ElementPadding and preset.elementPad then
				settings.ElementPadding = preset.elementPad
			end
			if preset.openButton then
				settings.OpenButton = type(settings.OpenButton) == "table" and settings.OpenButton or {}
				for key, value in pairs(preset.openButton) do
					if settings.OpenButton[key] == nil then
						settings.OpenButton[key] = value
					end
				end
			end
		end

		for key, value in pairs(WINDOW_DEFAULTS) do
			if settings[key] == nil then
				settings[key] = value
			end
		end
		settings.Theme = resolveThemeName(settings.Theme)
		settings.NewElements = settings.NewElements ~= false
		settings.Resizable = settings.Resizable ~= false
		settings.HideSearchBar = settings.HideSearchBar == true

		settings.OpenButton = type(settings.OpenButton) == "table" and settings.OpenButton or {}
		if settings.OpenButton.Color == nil then
			settings.OpenButton.Color = ColorSequence.new(accent(), accentSoft())
		end
		if settings.OpenButton.Enabled == nil then
			settings.OpenButton.Enabled = true
		end
		if settings.OpenButton.Draggable == nil then
			settings.OpenButton.Draggable = true
		end
		if settings.OpenButton.OnlyMobile == nil then
			settings.OpenButton.OnlyMobile = false
		end

		WindUI._AlleralElementGap = settings.ElementPadding or WindUI._AlleralElementGap or ALLERAL_TAB_GAP

		return settings
	end

	-- -------------------------------------------------------------------------
	-- Notification polish
	-- -------------------------------------------------------------------------

	local function findNotificationCard(wrapper)
		if not wrapper then
			return nil
		end
		for _, child in ipairs(wrapper:GetDescendants()) do
			if child.Name == "DurationFrame" and child.Parent then
				return child.Parent
			end
		end
		return wrapper:FindFirstChildWhichIsA("Frame", true)
	end

	local function stripNotificationChrome(card)
		if not card then
			return nil
		end

		if card:IsA("GuiObject") then
			card.ClipsDescendants = true
		end

		stripSliceChrome(card)

		local bg = card:FindFirstChild("Background", true)
		if bg then
			safeEnsureCorner(bg, UDim.new(0, MAC.notifyCorner))
		end

		local oldStroke = card:FindFirstChild("AlleralNotifyStroke", true)
		if oldStroke then
			oldStroke:Destroy()
		end

		local strokeTarget = bg
		if not strokeTarget and card:IsA("Frame") then
			strokeTarget = card
			safeEnsureCorner(strokeTarget, UDim.new(0, MAC.notifyCorner))
		end
		if not strokeTarget then
			return nil
		end
		return ensureStroke(strokeTarget, "AlleralNotifyStroke", palette.divider, 0.92, 1, {
			inner = true,
			reuseExisting = false,
		})
	end

	local function polishNotificationWrapper(wrapper, style)
		if not wrapper or wrapper:FindFirstChild("AlleralNotifyRail", true) then
			return
		end

		local card = findNotificationCard(wrapper)
		if not card or not card:IsA("GuiObject") then
			return
		end

		stripNotificationChrome(card)

		local rail = Instance.new("Frame")
		rail.Name = "AlleralNotifyRail"
		rail.BackgroundColor3 = style.accent
		rail.BackgroundTransparency = 0.06
		rail.BorderSizePixel = 0
		rail.Size = UDim2.new(0, 3, 1, 0)
		rail.Position = UDim2.new(0, 0, 0, 0)
		rail.ZIndex = card.ZIndex + 4
		rail.Parent = card
		local railCorner = Instance.new("UICorner")
		railCorner.CornerRadius = UDim.new(1, 0)
		railCorner.Parent = rail

		local stroke = card:FindFirstChild("AlleralNotifyStroke", true)
		if stroke then
			stroke.Color = palette.divider
			stroke.Transparency = 0.94
			tween(stroke, ANIM.micro, { Transparency = 0.92 })
		end

		animateNotificationIn(card, rail)

		if WindUI._AlleralNotifyCompact then
			for _, label in ipairs(card:GetDescendants()) do
				if label:IsA("TextLabel") then
					label.TextSize = math.max(13, label.TextSize - 2)
				end
			end
		end
	end

	local function resolveNotificationHolder()
		if WindUI._AlleralNotifyHolder and WindUI._AlleralNotifyHolder.Parent then
			return WindUI._AlleralNotifyHolder
		end
		local gui = WindUI.NotificationGui
		if not gui then
			return nil
		end
		for _, child in ipairs(gui:GetDescendants()) do
			if child:IsA("UIListLayout") and child.Parent and child.Parent:IsA("Frame") then
				WindUI._AlleralNotifyHolder = child.Parent
				return child.Parent
			end
		end
		local frame = gui:FindFirstChild("Frame", true)
		if frame and frame:IsA("Frame") then
			WindUI._AlleralNotifyHolder = frame
			return frame
		end
		return nil
	end

	local function installNotificationModuleHook()
		local mod = WindUI.NotificationModule
		if type(mod) ~= "table" or mod._AlleralNewHooked or type(mod.New) ~= "function" then
			return
		end
		mod._AlleralNewHooked = true
		local originalNew = mod.New
		function mod.New(self, payload)
			local style = WindUI._AlleralPendingNotifyStyle or NOTIFY_STYLES.info
			if type(payload) == "table" and payload.Holder then
				WindUI._AlleralNotifyHolder = payload.Holder
			end
			local result = originalNew(self, payload)
			task.defer(function()
				local holder = resolveNotificationHolder()
				if not holder then
					return
				end
				for _, child in ipairs(holder:GetChildren()) do
					if child:IsA("GuiObject") then
						polishNotificationWrapper(child, style)
					end
				end
			end)
			return result
		end
	end

	local function ensureNotificationHook()
		installNotificationModuleHook()

		local holder = resolveNotificationHolder()
		if not holder then
			return false
		end

		if WindUI._AlleralNotifyHook then
			return true
		end

		WindUI._AlleralNotifyHook = true
		local layout = holder:FindFirstChildWhichIsA("UIListLayout")
		if layout then
			layout.Padding = UDim.new(0, WindUI._AlleralNotifyCompact and 6 or 10)
		end
		local function applyNotifyLayoutPadding()
			local activeLayout = holder:FindFirstChildWhichIsA("UIListLayout")
			if activeLayout then
				activeLayout.Padding = UDim.new(0, WindUI._AlleralNotifyCompact and 6 or 10)
			end
		end
		WindUI._AlleralApplyNotifyPadding = applyNotifyLayoutPadding
		holder.ChildAdded:Connect(function(wrapper)
			local style = WindUI._AlleralPendingNotifyStyle or NOTIFY_STYLES.info
			task.defer(function()
				polishNotificationWrapper(wrapper, style)
			end)
		end)
		for _, child in ipairs(holder:GetChildren()) do
			if child:IsA("GuiObject") then
				task.defer(function()
					polishNotificationWrapper(child, NOTIFY_STYLES.info)
				end)
			end
		end
		return true
	end

	local function wrapWindowElements(window)
		if type(window) ~= "table" or window._AlleralWrapped then
			return window
		end
		window._AlleralWrapped = true

		local function findToggleSwitch(row)
			for _, child in ipairs(row:GetChildren()) do
				if child:FindFirstChild("Hitbox", true) then
					return child
				end
			end
			return nil
		end

		local function findToggleParts(switch)
			if not switch then
				return nil
			end
			local knob = switch:FindFirstChild("Frame")
			local bar = knob and knob:FindFirstChild("Bar")
			local highlight = bar and bar:FindFirstChild("Highlight")
			if not highlight then
				return nil
			end
			return {
				switch = switch,
				knob = knob,
				overlay = highlight:FindFirstChild("BarOverlay"),
				glass = highlight:FindFirstChild("Glass"),
				glassBg = highlight:FindFirstChild("GlassBackground"),
				layer = switch:FindFirstChild("Layer"),
			}
		end

		local function playElementReveal(root)
			if WindUI._AlleralReducedMotion == true or WindUI._AlleralSpringMotion == false then
				return
			end
			if not root or not root:IsA("GuiObject") then
				return
			end
			local scale = ensureUiScale(root, "AlleralRevealScale")
			if not scale then
				return
			end
			scale.Scale = 0.985
			task.defer(function()
				if root.Parent then
					tween(scale, ANIM.notify, { Scale = 1 })
				end
			end)
		end

		local function hookRowHover(row)
			if not row or not row:IsA("GuiObject") or row:FindFirstChild("AlleralRowHover") then
				return
			end
			local hook = Instance.new("BoolValue")
			hook.Name = "AlleralRowHover"
			hook.Parent = row
			local labels = {}
			for _, desc in ipairs(row:GetDescendants()) do
				if desc:IsA("TextLabel") and desc.TextTransparency < 1 then
					table.insert(labels, {
						label = desc,
						idle = desc.TextTransparency,
					})
				end
			end
			row.MouseEnter:Connect(function()
				if WindUI._AlleralTouchFeedback == false then
					return
				end
				for _, entry in ipairs(labels) do
					local label = entry.label
					if label.Parent then
						tween(label, ANIM.micro, {
							TextTransparency = math.max(0.22, entry.idle - 0.18),
						})
					end
				end
			end)
			row.MouseLeave:Connect(function()
				for _, entry in ipairs(labels) do
					local label = entry.label
					if label.Parent then
						tween(label, ANIM.micro, { TextTransparency = entry.idle })
					end
				end
			end)
		end

		local function polishElementChrome(elem)
			if type(elem) ~= "table" then
				return
			end
			local roots = {}
			if elem.UIElements then
				if elem.UIElements.Main then
					table.insert(roots, elem.UIElements.Main)
				end
				if elem.UIElements.Container then
					table.insert(roots, elem.UIElements.Container)
				end
			end
			if elem.ToggleFrame and elem.ToggleFrame.UIElements and elem.ToggleFrame.UIElements.Main then
				table.insert(roots, elem.ToggleFrame.UIElements.Main)
			end
			for _, root in ipairs(roots) do
				stripSliceChrome(root)
				if root.Parent and root.Parent:IsA("GuiObject") then
					stripSliceChrome(root.Parent)
				end
				playElementReveal(root)
				hookRowHover(root)
			end
		end

		local function polishToggleElement(elem)
			if type(elem) ~= "table" or elem._AlleralToggleDone then
				return elem
			end
			elem._AlleralToggleDone = true

			pcall(function()
				local row = elem.ToggleFrame and elem.ToggleFrame.UIElements and elem.ToggleFrame.UIElements.Main
				if not row then
					return
				end

				polishElementChrome(elem)

				local parts = findToggleParts(findToggleSwitch(row))
				if not parts then
					return
				end

				local oldGlow = row:FindFirstChild("AlleralToggleGlow", true)
				if oldGlow then
					oldGlow:Destroy()
				end
				local oldStroke = row:FindFirstChild("AlleralToggleStroke", true)
				if oldStroke then
					oldStroke:Destroy()
				end

				if parts.switch then
					ensureCorner(parts.switch, UDim.new(1, 0))
					ensureStroke(parts.switch, "AlleralToggleStroke", palette.line, 0.55, 1, {
						inner = true,
						reuseExisting = false,
					})
					local glow = parts.switch:FindFirstChild("ArrrelToggleGlow")
					if not glow then
						glow = Instance.new("Frame")
						glow.Name = "ArrrelToggleGlow"
						glow.BackgroundColor3 = palette.glow
						glow.BackgroundTransparency = 1
						glow.BorderSizePixel = 0
						glow.Size = UDim2.new(1, 10, 1, 10)
						glow.Position = UDim2.new(0.5, 0, 0.5, 0)
						glow.AnchorPoint = Vector2.new(0.5, 0.5)
						glow.ZIndex = parts.switch.ZIndex - 1
						glow.Parent = parts.switch
						ensureCorner(glow, UDim.new(1, 0))
					end
				end
				if parts.glass then
					local glassCorner = parts.glass:FindFirstChildOfClass("UICorner")
					if not glassCorner then
						glassCorner = Instance.new("UICorner")
						glassCorner.CornerRadius = UDim.new(1, 0)
						glassCorner.Parent = parts.glass
					end
				end

				local function syncToggleVisual(on)
					local stroke = parts.switch and parts.switch:FindFirstChild("AlleralToggleStroke")
					local glow = parts.switch and parts.switch:FindFirstChild("ArrrelToggleGlow")
					if parts.overlay then
						tween(parts.overlay, ANIM.toggle, {
							ImageColor3 = on and accent() or palette.trackOff,
							ImageTransparency = on and 0.18 or 1,
						})
					end
					if parts.glassBg then
						tween(parts.glassBg, ANIM.toggle, {
							ImageColor3 = on and palette.trackOn or palette.trackOff,
							ImageTransparency = on and 0.08 or 0.22,
						})
					end
					if parts.glass then
						tween(parts.glass, ANIM.toggle, {
							ImageColor3 = on and palette.knob or palette.muted,
							ImageTransparency = on and 0.04 or 0.12,
						})
					end
					if parts.layer then
						tween(parts.layer, ANIM.micro, {
							ImageTransparency = on and 0.35 or 1,
						})
					end
					if stroke then
						tween(stroke, ANIM.micro, {
							Color = on and accent() or palette.line,
							Transparency = on and 0.35 or 0.62,
						})
					end
					if glow then
						tween(glow, ANIM.toggle, {
							BackgroundTransparency = on and 0.78 or 1,
						})
					end
					if on then
						hapticPulse()
					end
				end

				syncToggleVisual(elem.Value == true)

				if type(elem.Set) == "function" and not elem._AlleralSetWrapped then
					elem._AlleralSetWrapped = true
					local origSet = elem.Set
					function elem:Set(value, ...)
						local result = origSet(self, value, ...)
						task.defer(function()
							syncToggleVisual(value == true)
						end)
						return result
					end
				end
			end)

			return elem
		end

		local function polishButtonElement(elem)
			if type(elem) ~= "table" or elem._AlleralButtonDone then
				return elem
			end
			elem._AlleralButtonDone = true
			task.defer(function()
				polishElementChrome(elem)
				local row = elem.UIElements and (elem.UIElements.Main or elem.UIElements.Container)
				if not row then
					return
				end
				local btn = row:FindFirstChildWhichIsA("TextButton", true)
					or row:FindFirstChildWhichIsA("ImageButton", true)
				if not btn then
					return
				end
				local scale = ensureUiScale(btn, "AlleralBtnScale")
				if not scale then
					return
				end
				scale.Scale = 1
				btn.MouseButton1Down:Connect(function()
					if WindUI._AlleralTouchFeedback == false then
						return
					end
					tween(scale, ANIM.press, { Scale = 0.96 })
				end)
				local function release()
					if WindUI._AlleralTouchFeedback == false then
						return
					end
					tween(scale, ANIM.micro, { Scale = 1 })
				end
				btn.MouseButton1Up:Connect(release)
				btn.MouseLeave:Connect(release)
			end)
			return elem
		end

		local function polishSliderElement(elem)
			if type(elem) ~= "table" or elem._AlleralSliderDone then
				return elem
			end
			elem._AlleralSliderDone = true
			task.defer(function()
				local icon = elem.UIElements and elem.UIElements.SliderIcon
				local track = icon and icon:FindFirstChild("Frame")
				local fill = track and track:FindFirstChild("Frame")
				local thumb = fill and fill:FindFirstChild("Thumb")

				if track then
					sliderTrackFrames[track] = true
				end
				if fill then
					sliderTrackFrames[fill] = true
				end

				if icon and icon:IsA("GuiObject") then
					safeEnsureCorner(icon, UDim.new(1, 0))
					ensureStroke(icon, "AlleralSliderTrackStroke", palette.divider, MAC.sliderTrackTransparency, 1, {
						inner = true,
						reuseExisting = false,
					})
				end

				if fill and fill:IsA("GuiObject") then
					fill.ImageColor3 = accent()
					fill.ImageTransparency = MAC.sliderFillTransparency
				end

				if thumb and thumb:IsA("GuiObject") then
					ensureCorner(thumb, UDim.new(1, 0))
					ensureStroke(thumb, "AlleralSliderThumbStroke", palette.line, 0.42, 1, {
						inner = true,
						reuseExisting = false,
					})
					local highlight = thumb:FindFirstChild("Highlight")
					if highlight and highlight:IsA("GuiObject") then
						highlight.ImageTransparency = 0.72
					end
					if motionEnabled() then
						local thumbScale = ensureUiScale(thumb, "AlleralThumbScale")
						if thumbScale then
							thumbScale.Scale = 1
							thumb.MouseEnter:Connect(function()
								tween(thumbScale, ANIM.micro, { Scale = 1.08 })
							end)
							thumb.MouseLeave:Connect(function()
								tween(thumbScale, ANIM.micro, { Scale = 1 })
							end)
						end
					end
				end

				if type(elem.Set) == "function" and not elem._AlleralSliderHook then
					elem._AlleralSliderHook = true
					local originalSet = elem.Set
					elem.Set = function(self, val, input, ...)
						local result = originalSet(self, val, input, ...)
						if fill and motionEnabled() then
							tween(fill, ANIM.slider, { ImageTransparency = 0.12, ImageColor3 = accentHot() })
							task.delay(0.18, function()
								if fill.Parent then
									tween(fill, ANIM.micro, {
										ImageTransparency = MAC.sliderFillTransparency,
										ImageColor3 = accent(),
									})
								end
							end)
						end
						if input and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
							hapticPulse()
						end
						return result
					end
				end

				polishElementChrome(elem)
			end)
			return elem
		end

		local wrapTab
		local wrapLayoutStack
		local wrapSection

		wrapSection = function(section)
			if type(section) ~= "table" or section._AlleralSectionWrapped then
				return section
			end
			section._AlleralSectionWrapped = true

			local methods = { "Toggle", "Checkbox", "Slider", "Button", "Dropdown", "Input", "Keybind", "Paragraph" }
			for _, methodName in ipairs(methods) do
				local original = section[methodName]
				if type(original) == "function" then
					section[methodName] = function(self, opts, ...)
						local elem = original(self, opts, ...)
						if methodName == "Toggle" or methodName == "Checkbox" then
							polishToggleElement(elem)
							task.defer(function()
								hookElementTooltip(elem)
							end)
						elseif methodName == "Button" then
							polishButtonElement(elem)
						elseif methodName == "Slider" then
							polishSliderElement(elem)
							task.defer(function()
								hookElementTooltip(elem)
							end)
						elseif methodName == "Paragraph" then
							task.defer(function()
								pcall(function()
									polishElementChrome(elem)
								end)
							end)
						elseif methodName == "Dropdown" or methodName == "Input" or methodName == "Keybind" then
							task.defer(function()
								polishElementChrome(elem)
								hookElementTooltip(elem)
							end)
						end
						if WindUI.Window and WindUI.Window._AlleralSearchOn then
							task.defer(function()
								buildSearchIndex(WindUI.Window)
							end)
						end
						return elem
					end
				end
			end

			if type(section.Tab) == "function" then
				local origTab = section.Tab
				function section:Tab(opts)
					local tab = origTab(self, opts)
					if type(wrapTab) == "function" then
						return wrapTab(tab)
					end
					return tab
				end
			end

			if type(section.HStack) == "function" then
				local origHStack = section.HStack
				function section:HStack(opts)
					return wrapLayoutStack(origHStack(self, opts))
				end
			end

			return section
		end

		wrapLayoutStack = function(stack)
			if type(stack) ~= "table" or stack._AlleralLayoutWrapped or type(stack.VStack) ~= "function" then
				return stack
			end
			stack._AlleralLayoutWrapped = true
			local origVStack = stack.VStack
			function stack:VStack(vopts)
				local col = origVStack(self, vopts)
				if type(col) == "table" and type(col.Section) == "function" then
					local origColSection = col.Section
					function col:Section(sopts)
						return wrapSection(origColSection(self, sopts))
					end
				end
				return col
			end
			return stack
		end

		wrapTab = function(tab)
			if type(tab) ~= "table" or tab._AlleralTabWrapped then
				return tab
			end
			tab._AlleralTabWrapped = true

			if type(tab.Section) == "function" then
				local origSection = tab.Section
				function tab:Section(opts)
					return wrapSection(origSection(self, opts))
				end
			end

			if type(tab.HStack) == "function" then
				local origHStack = tab.HStack
				function tab:HStack(opts)
					return wrapLayoutStack(origHStack(self, opts))
				end
			end

			return tab
		end

		WindUI._ArrrelWrapSection = wrapSection

		if type(window.Tab) == "function" then
			local origTab = window.Tab
			function window:Tab(opts)
				local tab = origTab(self, opts)
				if tab then
					applyTabGap(tab, resolveElementGap(window))
				end
				if type(wrapTab) == "function" then
					return wrapTab(tab)
				end
				return tab
			end
		end

		if type(window.Section) == "function" then
			local origSection = window.Section
			function window:Section(opts)
				return wrapSection(origSection(self, opts))
			end
		end

		return window
	end

	local function startWatchdog(window)
		WindUI._AlleralWatchdogToken += 1
		local token = WindUI._AlleralWatchdogToken

		task.spawn(function()
			while WindUI._AlleralWatchdogToken == token and WindUI.Window == window do
				task.wait(24)
				if WindUI._AlleralWatchdogToken ~= token or WindUI.Window ~= window then
					break
				end
				pcall(function()
					if window.UIElements and window.UIElements.Main and window.UIElements.Main.Parent then
						WindUI:PolishWindow(window)
					else
						WindUI._AlleralWatchdogToken += 1
					end
				end)
			end
		end)
	end

	-- -------------------------------------------------------------------------
	-- Window API
	-- -------------------------------------------------------------------------

	local _CreateWindow = WindUI.CreateWindow

	function WindUI.ReleaseWindow(self, window)
		window = window or WindUI.Window
		if not window then
			return false
		end
		WindUI._AlleralWatchdogToken = (WindUI._AlleralWatchdogToken or 0) + 1
		pcall(function()
			if type(window.Close) == "function" then
				window:Close()
			end
		end)
		if WindUI.Window == window then
			WindUI.Window = nil
		end
		return true
	end

	function WindUI.CreateWindow(self, settings)
		settings = normalizeWindowSettings(settings)

		if WindUI.Window then
			WindUI:ReleaseWindow(WindUI.Window)
		end

		local window
		for attempt = 1, 2 do
			local ok, result = pcall(function()
				return _CreateWindow(self, settings)
			end)
			if ok and result then
				window = result
				break
			end
			uiWarn("window", result)
			if WindUI.Window then
				WindUI:ReleaseWindow(WindUI.Window)
			end
			settings.Theme = resolveThemeName(attempt == 1 and "Arrrel" or "Dark")
		end

		if window then
			WindUI.Window = window
			wrapWindowElements(window)
			installWindowAnimations(window)
			applyWindowScale(window)
			task.spawn(preloadAssets)
			task.defer(function()
				installDropdownAnimations()
				ensureNotificationHook()
				WindUI:PolishWindow(window)
				startWatchdog(window)
			end)
		end

		return window
	end

	local _Notify
	do
		local ok, original = pcall(function()
			return WindUI.Notify
		end)
		if ok and type(original) == "function" then
			_Notify = original
		end
	end
	function WindUI.Notify(self, payload)
		if type(_Notify) ~= "function" then
			uiWarn("notify", "WindUI.Notify unavailable")
			return nil
		end
		if type(payload) ~= "table" then
			payload = { Content = tostring(payload or "") }
		end

		local style = resolveNotifyStyle(payload)
		payload.Title = payload.Title or payload.Name or "Arrrel"
		payload.Content = payload.Content or payload.Text or payload.Description or ""
		payload.Duration = math.clamp(tonumber(payload.Duration or payload.Time) or 4, 1, 30)
		if not payload.Icon and style.icon then
			payload.Icon = style.icon
			payload.IconThemed = false
		end

		if WindUI._AlleralNotifyDedupe ~= false then
			local key = tostring(payload.Title) .. "\0" .. tostring(payload.Content)
			local now = tick()
			local last = WindUI._AlleralLastNotify[key]
			if last and now - last.at < 2.5 then
				last.at = now
				return last.result
			end
		end

		ensureNotificationHook()
		WindUI._AlleralPendingNotifyStyle = style

		local waited = 0
		while WindUI._AlleralNotifyCount >= WindUI._AlleralMaxNotify and waited < 3 do
			task.wait(0.12)
			waited += 0.12
		end
		WindUI._AlleralNotifyCount += 1

		local ok, result = pcall(function()
			return _Notify(self, payload)
		end)

		if not ok and payload.Icon then
			local retryPayload = {}
			for key, value in pairs(payload) do
				retryPayload[key] = value
			end
			retryPayload.Icon = nil
			ok, result = pcall(function()
				return _Notify(self, retryPayload)
			end)
		end

		task.delay(payload.Duration + 0.35, function()
			WindUI._AlleralNotifyCount = math.max(0, WindUI._AlleralNotifyCount - 1)
		end)
		WindUI._AlleralPendingNotifyStyle = nil

		if not ok then
			uiWarn("notify", result)
			return nil
		end

		if WindUI._AlleralNotifyDedupe ~= false then
			local key = tostring(payload.Title) .. "\0" .. tostring(payload.Content)
			WindUI._AlleralLastNotify[key] = {
				at = tick(),
				result = result,
			}
		end
		return result
	end

	local _SetNotificationLower = WindUI.SetNotificationLower
	function WindUI.SetNotificationLower(self, enabled)
		if type(_SetNotificationLower) == "function" then
			pcall(_SetNotificationLower, self, enabled == true)
		end
		WindUI._AlleralNotifyLower = enabled == true
	end

	function WindUI.SetNotificationCompact(_self, enabled)
		WindUI._AlleralNotifyCompact = enabled == true
		if type(WindUI._AlleralApplyNotifyPadding) == "function" then
			pcall(WindUI._AlleralApplyNotifyPadding)
		else
			local holder = WindUI._AlleralNotifyHolder
			local layout = holder and holder:FindFirstChildWhichIsA("UIListLayout")
			if layout then
				layout.Padding = UDim.new(0, WindUI._AlleralNotifyCompact and 6 or 10)
			end
		end
	end

	function WindUI.ClearNotifications(_self)
		local mod = WindUI.NotificationModule
		local cleared = 0
		if mod and type(mod.Notifications) == "table" then
			for index, notif in pairs(mod.Notifications) do
				if type(notif) == "table" and type(notif.Close) == "function" and not notif.Closed then
					pcall(function()
						notif:Close()
					end)
					cleared += 1
				end
				mod.Notifications[index] = nil
			end
			mod.NotificationIndex = 0
		end
		WindUI._AlleralNotifyCount = 0
		return cleared
	end

	local _SetTheme = WindUI.SetTheme
	function WindUI.SetTheme(self, themeName)
		themeName = resolveThemeName(themeName)
		local theme

		pcall(function()
			theme = _SetTheme(self, themeName)
		end)
		if not theme then
			pcall(function()
				theme = _SetTheme(self, "Alleral")
			end)
		end
		if not theme then
			pcall(function()
				theme = _SetTheme(self, "Dark")
			end)
		end

		if theme and WindUI.Window then
			task.defer(function()
				WindUI:PolishWindow(WindUI.Window)
			end)
		end
		return theme
	end

	local _AddTheme = WindUI.AddTheme
	function WindUI.AddTheme(self, themeTable)
		if type(themeTable) ~= "table" or type(themeTable.Name) ~= "string" then
			return nil
		end
		local ok, result = pcall(function()
			return _AddTheme(self, themeTable)
		end)
		if not ok then
			uiWarn("theme", result)
			return nil
		end
		if WindUI.Themes and themeTable.Name then
			WindUI.Themes[themeTable.Name] = mergeTokens(WindUI.Themes[themeTable.Name] or {}, themeTable)
		end
		return result
	end

	local _Popup = WindUI.Popup
	function WindUI.Popup(self, payload)
		payload = type(payload) == "table" and payload or {}
		local ok, result = pcall(function()
			return _Popup(self, payload)
		end)
		if not ok then
			uiWarn("popup", result)
			return nil
		end
		if result and motionEnabled() then
			task.defer(function()
				local main = type(result) == "table" and result.UIElements and result.UIElements.Main
				if main and main:IsA("GuiObject") then
					safeEnsureCorner(main, UDim.new(0, 14))
					local stroke = ensureStroke(main, "AlleralPopupStroke", palette.line, 0.72, 1, { inner = true })
					if main:IsA("ImageLabel") then
						local target = main.ImageTransparency
						main.ImageTransparency = math.clamp(target + 0.2, 0, 1)
						tween(main, ANIM.open, { ImageTransparency = target })
					end
					if stroke then
						stroke.Transparency = 0.9
						tween(stroke, ANIM.open, { Transparency = 0.58 })
					end
				end
			end)
		end
		return result
	end

	-- Exports
	-- -------------------------------------------------------------------------

	function WindUI.GetArrrelVersion(_self)
		return WindUI.ARRREL_UI_VERSION
	end

	function WindUI.GetAlleralVersion(_self)
		return WindUI.GetArrrelVersion(_self)
	end

	function WindUI.HookElementTooltip(_self, elem)
		hookElementTooltip(elem)
		return elem
	end

	function WindUI.WrapSection(_self, section)
		if type(WindUI._ArrrelWrapSection) == "function" then
			return WindUI._ArrrelWrapSection(section)
		end
		return section
	end

	function WindUI.SetAccentColor(_self, color)
		if typeof(color) ~= "Color3" then
			return false
		end
		palette.accent = color
		palette.accentSoft = color:Lerp(Color3.new(1, 1, 1), 0.28)
		palette.accentHot = color:Lerp(Color3.new(0, 0, 0), 0.12)
		NOTIFY_STYLES.success.accent = palette.accent
		installThemes()
		if WindUI.Window then
			WindUI:RepairWindow(WindUI.Window)
		end
		return true
	end

	function WindUI.ListAccentPresets(_self)
		local names = {}
		for name in pairs(ACCENT_PRESETS) do
			table.insert(names, name)
		end
		table.sort(names)
		return names
	end

	function WindUI.ApplyAccentPreset(_self, presetName)
		local hex = ACCENT_PRESETS[tostring(presetName or "")]
		if not hex then
			return false
		end
		return WindUI:SetAccentColor(Color3.fromHex(hex))
	end

	function WindUI.FlashRow(_self, elementTable, duration)
		if type(elementTable) ~= "table" or type(elementTable.Highlight) ~= "function" then
			return false
		end
		pcall(function()
			elementTable:Highlight()
		end)
		if duration and duration > 0 then
			task.delay(duration, function()
				pcall(function()
					if elementTable.Unhighlight then
						elementTable:Unhighlight()
					end
				end)
			end)
		end
		return true
	end

	function WindUI.SetCompactSidebar(_self, enabled)
		WindUI._AlleralSidebarCompact = enabled == true
		if WindUI.Window then
			WindUI:PolishWindow(WindUI.Window)
		end
		return WindUI._AlleralSidebarCompact
	end

	function WindUI.SafeNotify(self, title, content, duration, notifyType)
		return WindUI:Notify({
			Title = title,
			Content = content,
			Duration = duration or 4,
			Type = notifyType or "info",
		})
	end

	function WindUI.NotifySuccess(self, title, content, duration)
		return WindUI:Notify({
			Title = title,
			Content = content,
			Duration = duration or 4,
			Type = "success",
		})
	end

	function WindUI.NotifyWarn(self, title, content, duration)
		return WindUI:Notify({
			Title = title,
			Content = content,
			Duration = duration or 5,
			Type = "warn",
		})
	end

	function WindUI.NotifyError(self, title, content, duration)
		return WindUI:Notify({
			Title = title,
			Content = content,
			Duration = duration or 6,
			Type = "error",
		})
	end

	function WindUI.ListThemeNames(_self)
		local names = {}
		for name in pairs(WindUI.Themes or {}) do
			table.insert(names, name)
		end
		table.sort(names, function(a, b)
			if a == "Arrrel" then
				return true
			end
			if b == "Arrrel" then
				return false
			end
			if a == "Alleral" then
				return true
			end
			if b == "Alleral" then
				return false
			end
			return a < b
		end)
		return names
	end

	function WindUI.CycleTheme(self, delta)
		delta = tonumber(delta) or 1
		local names = WindUI:ListThemeNames()
		if #names == 0 then
			return nil
		end

		local current = "Alleral"
		if WindUI.GetCurrentTheme then
			local ok, value = pcall(function()
				return WindUI:GetCurrentTheme()
			end)
			if ok and value then
				current = value
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
		local nextTheme = WindUI:SetTheme(names[index])
		WindUI:FlashAccent()
		return nextTheme
	end

	function WindUI.FlashAccent(self, window)
		if WindUI._AlleralReducedMotion then
			return
		end

		window = window or WindUI.Window
		if not window or not window.UIElements or not window.UIElements.Main then
			return
		end

		local main = window.UIElements.Main
		local stroke = main:FindFirstChild("AlleralWindowStroke")
		if not stroke then
			stroke = syncWindowStroke(main)
		end

		if stroke then
			tween(stroke, ANIM.micro, {
				Color = accent(),
				Transparency = 0.28,
				Thickness = 1.5,
			})
			task.delay(0.2, function()
				tween(stroke, ANIM.open, {
					Color = palette.line,
					Transparency = 0.62,
					Thickness = 1,
				})
			end)
		end
	end

	function WindUI.SetReducedMotion(_self, enabled)
		WindUI._AlleralReducedMotion = enabled == true
	end

	function WindUI.SetSpringMotion(_self, enabled)
		WindUI._AlleralSpringMotion = enabled == true
	end

	function WindUI.Spring(_self, instance, preset, props)
		if not instance or type(props) ~= "table" then
			return
		end
		if WindUI._AlleralReducedMotion == true then
			snapProps(instance, props)
			return
		end
		Motion.target(instance, preset or "snappy", props)
	end

	function WindUI.GetMotionPresets(_self)
		local names = {}
		for name in pairs(Motion.Presets) do
			table.insert(names, name)
		end
		table.sort(names)
		return names
	end

	function WindUI.SetStartupEffect(_self, enabled)
		WindUI._AlleralStartupEffect = enabled ~= false
	end

	function WindUI.GetDeviceProfile(_self)
		return detectDeviceKind(), viewportShortSide()
	end

	function WindUI.ListProfiles(_self)
		local names = {}
		for name, preset in pairs(PROFILE_PRESETS) do
			table.insert(names, {
				id = name,
				label = preset.label or name,
			})
		end
		table.sort(names, function(a, b)
			return a.id < b.id
		end)
		table.insert(names, 1, { id = "auto", label = "Auto (detect device)" })
		return names
	end

	function WindUI.ApplyProfile(_self, profileName)
		local resolved = resolveProfileName(profileName)
		local preset = PROFILE_PRESETS[resolved]
		if not preset and profileName ~= "auto" then
			return false
		end
		WindUI._AlleralProfile = profileName or resolved
		if preset then
			applyPresetToDefaults(preset)
			syncProfileEnv(preset)
		end
		if preset and preset.reducedMotion ~= nil and type(WindUI.SetReducedMotion) == "function" then
			pcall(function()
				WindUI:SetReducedMotion(WindUI._AlleralReducedMotion == true)
			end)
		end
		if preset and preset.startup ~= nil and type(WindUI.SetStartupEffect) == "function" then
			pcall(function()
				WindUI:SetStartupEffect(WindUI._AlleralStartupEffect == true)
			end)
		end
		if preset and preset.notifyCompact ~= nil and type(WindUI.SetNotificationCompact) == "function" then
			pcall(function()
				WindUI:SetNotificationCompact(WindUI._AlleralNotifyCompact == true)
			end)
		end
		if WindUI.Window then
			applyWindowScale(WindUI.Window)
			WindUI:RepairWindow(WindUI.Window)
		end
		return resolved, preset
	end

	function WindUI.SetUiScale(_self, scale)
		scale = tonumber(scale) or 1
		scale = math.clamp(scale, 0.75, 1.25)
		WindUI._AlleralUiScale = scale
		if WindUI.Window then
			applyWindowScale(WindUI.Window)
		end
		return scale
	end

	function WindUI.SetTouchFeedback(_self, enabled)
		WindUI._AlleralTouchFeedback = enabled ~= false
		return WindUI._AlleralTouchFeedback
	end

	function WindUI.SetHaptics(_self, enabled)
		WindUI._AlleralHaptics = enabled == true
		return WindUI._AlleralHaptics
	end

	function WindUI.SetNotifyDedupe(_self, enabled)
		WindUI._AlleralNotifyDedupe = enabled ~= false
		return WindUI._AlleralNotifyDedupe
	end

	function WindUI.Preload(_self)
		return preloadAssets()
	end

	function WindUI.GetResources(_self)
		return RESOURCES
	end

	function WindUI.RebuildSearchIndex(_self, window)
		window = window or WindUI.Window
		if not window then
			return 0
		end
		return #buildSearchIndex(window)
	end

	function WindUI.FindSettings(_self, query, window)
		window = window or WindUI.Window
		if not window then
			return {}
		end
		return filterSettings(window, query)
	end

	function WindUI.GoToSetting(_self, hit, window)
		window = window or WindUI.Window
		jumpToSearchHit(window, hit)
		return true
	end

	function WindUI.GetFeatures(_self)
		return {
			brand = WindUI.ARRREL_BRAND,
			version = WindUI.ARRREL_UI_VERSION,
			profiles = true,
			search = true,
			tooltips = true,
			themes = WindUI.Themes ~= nil,
		}
	end

	function WindUI.RepairWindow(self, window)
		window = window or WindUI.Window
		if not window then
			return false
		end
		local ok = pcall(function()
			installThemes()
			cleanupLegacyPolish(WindUI.DropdownGui)
			wrapWindowElements(window)
			installWindowAnimations(window)
			applyWindowScale(window)
			WindUI:PolishWindow(window)
			if type(window.CanDropdown) ~= "boolean" then
				window.CanDropdown = true
			end
			ensureNotificationHook()
		end)
		return ok == true
	end

	function WindUI.SelfTest(_self)
		local checks = {
			create = type(WindUI.CreateWindow) == "function",
			theme = (WindUI.Themes and (WindUI.Themes.Arrrel or WindUI.Themes.Alleral)) ~= nil,
			patch = WindUI.ARRREL_UI_VERSION ~= nil,
			notify = type(WindUI.Notify) == "function",
			clear = type(WindUI.ClearNotifications) == "function",
			profiles = type(WindUI.ApplyProfile) == "function",
			mobile = type(WindUI.GetDeviceProfile) == "function",
			spring = type(WindUI.Spring) == "function",
			motion = Motion and type(Motion.target) == "function",
		}
		local ok = checks.create and checks.theme and checks.patch and checks.notify and checks.profiles
		return ok, checks
	end

	pcall(function()
		WindUI:OnThemeChange(function()
			if WindUI.Window then
				task.defer(function()
					WindUI:PolishWindow(WindUI.Window)
				end)
			end
		end)
	end)

	pcall(function()
		WindUI:SetTheme("Arrrel")
	end)

	ensureNotificationHook()
	task.defer(function()
		installDropdownAnimations()
	end)
	if WindUI._AlleralNotifyCompact then
		WindUI:SetNotificationCompact(true)
	end

	pcall(function()
		WindUI:ApplyProfile(WindUI._AlleralProfile or "auto")
	end)

	local passed = WindUI:SelfTest()
	if not passed then
		uiWarn("selftest", "theme bootstrap incomplete")
	end

	local function loadV2BoostLayer()
		local readFn = readfile or (syn and syn.readfile) or (fluxus and fluxus.readfile)
		local isFileFn = isfile or (syn and syn.isfile)
		local boostUrls = {
			"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/ui/windui/v2/boost.luau",
			"https://github.com/evanbackup1256-ship-it/kick/raw/main/ui/windui/v2/boost.luau",
		}
		local function validBoostSource(body)
			return type(body) == "string"
				and #body > 400
				and body:find("ALLERAL_UI_V2", 1, true) ~= nil
				and body:find("return function", 1, true) ~= nil
		end
		local function fetchBoostRemote()
			for _, url in ipairs(boostUrls) do
				local bust = url .. (url:find("?", 1, true) and "&" or "?") .. "t=" .. tostring(tick())
				local ok, body = pcall(function()
					return game:HttpGet(bust)
				end)
				if ok and validBoostSource(body) then
					return body
				end
			end
			return nil
		end
		local roots = {
			"ui/windui/v2/",
			"vendor/windui/v2/",
			"windui/v2/",
			"kick/ui/windui/v2/",
			"kick/kick/ui/windui/v2/",
		}
		local source
		if type(readFn) == "function" and type(isFileFn) == "function" then
			for _, root in ipairs(roots) do
				local path = root .. "boost.luau"
				if isFileFn(path) then
					local ok, body = pcall(readFn, path)
					if ok and validBoostSource(body) then
						source = body
						break
					end
				end
			end
		end
		if not source then
			source = fetchBoostRemote()
		end
		if not source then
			uiWarn("v2", "boost.luau missing — V2 layer skipped")
			return false
		end
		local compile = loadstring or load
		if type(compile) ~= "function" then
			return false
		end
		local chunk, err = compile(source, "@Alleral/v2/boost")
		if not chunk then
			uiWarn("v2", err)
			return false
		end
		local ok, boostFn = pcall(chunk)
		if not ok or type(boostFn) ~= "function" then
			uiWarn("v2", boostFn)
			return false
		end
		local applied, applyErr = pcall(boostFn, {
			WindUI = WindUI,
			MAC = MAC,
			palette = palette,
			accent = accent,
			accentSoft = accentSoft,
			accentHot = accentHot,
			mergeTokens = mergeTokens,
			installThemes = installThemes,
			fullTheme = fullTheme,
			Motion = Motion,
			tween = tween,
			ANIM = ANIM,
			ensureStroke = ensureStroke,
			ensureCorner = ensureCorner,
			ensureGradient = ensureGradient,
			PROFILE_PRESETS = PROFILE_PRESETS,
			ACCENT_PRESETS = ACCENT_PRESETS,
			uiWarn = uiWarn,
		})
		if not applied then
			uiWarn("v2", applyErr)
			return false
		end
		return true
	end

	loadV2BoostLayer()

	WindUI._AlleralPatchComplete = true

	return WindUI
end
