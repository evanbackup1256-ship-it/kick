--[[
	Alleral patch for WindUI (Footagesus 1.6.64-fix)
	Loaded by ui/windui/main.lua after the upstream library initializes.
]]

return function(WindUI)
	if type(WindUI) ~= "table" then
		return WindUI
	end

	local TweenService = game:GetService("TweenService")

	local ACCENT = Color3.fromHex("#53fc18")
	local ACCENT_ALT = Color3.fromHex("#30ff6a")

	WindUI.ALLERAL_UI_VERSION = "1.6.64-fix-aller2"
	WindUI._AlleralNotifyCount = 0
	WindUI._AlleralMaxNotify = 6
	WindUI._AlleralWatchdogToken = 0

	local function uiWarn(scope, err)
		warn(string.format("[Alleral UI/%s] %s", tostring(scope), tostring(err)))
	end

	local function tween(instance, info, props)
		if WindUI._AlleralReducedMotion or not instance or not instance.Parent then
			return
		end
		pcall(function()
			TweenService:Create(instance, info, props):Play()
		end)
	end

	local function resolveThemeName(requested)
		local themes = WindUI.Themes or {}
		if type(requested) == "string" and themes[requested] then
			return requested
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

	local function addAccentStroke(frame, transparency, thickness)
		if not frame or not frame:IsA("GuiObject") then
			return
		end
		local stroke = frame:FindFirstChild("AlleralAccentStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = "AlleralAccentStroke"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = frame
		end
		stroke.Color = ACCENT
		stroke.Thickness = thickness or 1
		stroke.Transparency = transparency or 0.55
	end

	local function addTopGlow(topbarFrame)
		if not topbarFrame or not topbarFrame:IsA("GuiObject") then
			return
		end
		if topbarFrame:FindFirstChild("AlleralTopGlow") then
			return
		end

		local glow = Instance.new("Frame")
		glow.Name = "AlleralTopGlow"
		glow.BackgroundColor3 = ACCENT
		glow.BackgroundTransparency = 0.88
		glow.BorderSizePixel = 0
		glow.Size = UDim2.new(1, 0, 0, 2)
		glow.Position = UDim2.new(0, 0, 1, -1)
		glow.ZIndex = topbarFrame.ZIndex + 2
		glow.Parent = topbarFrame

		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, ACCENT),
			ColorSequenceKeypoint.new(0.5, ACCENT_ALT),
			ColorSequenceKeypoint.new(1, ACCENT),
		})
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(1, 0.35),
		})
		grad.Parent = glow
	end

	function WindUI.PolishWindow(self, window)
		if type(window) ~= "table" or type(window.UIElements) ~= "table" then
			return window
		end

		pcall(function()
			local main = window.UIElements.Main
			if main then
				addAccentStroke(main, 0.58, 1)
			end

			local topbar = window.UIElements.Topbar
			if topbar and topbar.Main then
				addTopGlow(topbar.Main)
			end

			local sidebar = window.UIElements.SideBar
			if sidebar then
				addAccentStroke(sidebar, 0.82, 1)
			end

			window.CanDropdown = true

			if window.SearchBar and window.SearchBar.Frame then
				addAccentStroke(window.SearchBar.Frame, 0.78, 1)
			end
		end)

		return window
	end

	local function startWatchdog(window)
		WindUI._AlleralWatchdogToken += 1
		local token = WindUI._AlleralWatchdogToken

		task.spawn(function()
			while WindUI._AlleralWatchdogToken == token and WindUI.Window == window do
				task.wait(20)
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

	local _CreateWindow = WindUI.CreateWindow
	function WindUI.CreateWindow(self, settings)
		settings = type(settings) == "table" and settings or {}
		settings.Theme = resolveThemeName(settings.Theme)
		settings.NewElements = settings.NewElements ~= false
		settings.UICorner = settings.UICorner or 14
		settings.UIPadding = settings.UIPadding or 12
		settings.SideBarWidth = settings.SideBarWidth or 218
		settings.ElementPadding = settings.ElementPadding or 8
		settings.Resizable = settings.Resizable ~= false
		settings.HideSearchBar = settings.HideSearchBar == true

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
			settings.Theme = resolveThemeName(attempt == 1 and "Alleral" or "Dark")
			task.wait(0.05)
		end

		if window then
			task.defer(function()
				WindUI:PolishWindow(window)
				startWatchdog(window)
			end)
		end

		return window
	end

	local _Notify = WindUI.Notify
	function WindUI.Notify(self, payload)
		if type(payload) ~= "table" then
			payload = { Content = tostring(payload or "") }
		end

		payload.Title = payload.Title or payload.Name or "Alleral"
		payload.Content = payload.Content or payload.Text or payload.Description or ""
		payload.Duration = math.clamp(tonumber(payload.Duration or payload.Time) or 4, 1, 30)

		local waited = 0
		while WindUI._AlleralNotifyCount >= WindUI._AlleralMaxNotify and waited < 3 do
			task.wait(0.12)
			waited += 0.12
		end
		WindUI._AlleralNotifyCount += 1

		local ok, result = pcall(function()
			return _Notify(self, payload)
		end)

		task.delay(payload.Duration + 0.35, function()
			WindUI._AlleralNotifyCount = math.max(0, WindUI._AlleralNotifyCount - 1)
		end)

		if not ok then
			uiWarn("notify", result)
			return nil
		end
		return result
	end

	local _SetTheme = WindUI.SetTheme
	function WindUI.SetTheme(self, themeName)
		themeName = resolveThemeName(themeName)
		local theme

		local ok = pcall(function()
			theme = _SetTheme(self, themeName)
		end)
		if not ok or not theme then
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
		return result
	end

	function WindUI.GetAlleralVersion(_self)
		return WindUI.ALLERAL_UI_VERSION
	end

	function WindUI.SafeNotify(self, title, content, duration)
		return WindUI:Notify({
			Title = title,
			Content = content,
			Duration = duration or 4,
		})
	end

	function WindUI.ListThemeNames(_self)
		local names = {}
		for name in pairs(WindUI.Themes or {}) do
			table.insert(names, name)
		end
		table.sort(names)
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
		return WindUI:SetTheme(names[index])
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
		local stroke = main:FindFirstChild("AlleralAccentStroke")
		if not stroke then
			addAccentStroke(main, 0.2, 2)
			stroke = main:FindFirstChild("AlleralAccentStroke")
		end

		if stroke then
			tween(stroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 0.15,
				Thickness = 2,
			})
			task.delay(0.22, function()
				tween(stroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 0.58,
					Thickness = 1,
				})
			end)
		end
	end

	function WindUI.SetReducedMotion(_self, enabled)
		WindUI._AlleralReducedMotion = enabled == true
	end

	function WindUI.RepairWindow(self, window)
		window = window or WindUI.Window
		if not window then
			return false
		end
		local ok = pcall(function()
			WindUI:PolishWindow(window)
			if type(window.CanDropdown) ~= "boolean" then
				window.CanDropdown = true
			end
		end)
		return ok == true
	end

	WindUI:OnThemeChange(function()
		if WindUI.Window then
			task.defer(function()
				WindUI:PolishWindow(WindUI.Window)
			end)
		end
	end)

	pcall(function()
		if WindUI.Themes and WindUI.Themes.Alleral then
			WindUI:SetTheme("Alleral")
		end
	end)

	return WindUI
end
