return function(Core)
	local ALLERAL_UI_LAYER = "Alleral UI layer"
	Core._AlleralUiLayer = ALLERAL_UI_LAYER
	Core.ALLERAL_UI_VERSION = Core.ALLERAL_UI_VERSION or "3.0.3-maclib"
	Core.WINDUI_VERSION = Core.ALLERAL_UI_VERSION
	Core.UI_LIBRARY = "Maclib"

	local MACLIB_URL = "https://github.com/biggaboy212/Maclib/releases/download/9.Maclib/maclib.txt"
	local MACLIB_FALLBACK = "https://raw.githubusercontent.com/biggaboy212/Maclib/main/maclib.txt"

	local function genv()
		local ok, env = pcall(function()
			return getgenv and getgenv() or getfenv()
		end)
		return ok and env or {}
	end
	local ENV = genv()

	local HUB_RAW_BASE = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/hub/"

	local function loadHubSource(filename)
		local rel = "hub/" .. filename
		local src = Core.readFile and Core.readFile(rel)
		if type(src) ~= "string" or #src < 100 then
			local url = HUB_RAW_BASE .. filename .. "?t=" .. tostring(tick())
			if type(Core.httpGet) == "function" then
				src = Core.httpGet(url)
			end
		end
		return type(src) == "string" and #src >= 100 and src or nil
	end

	local function loadHubModule(filename)
		local src = loadHubSource(filename)
		if not src then
			return nil
		end
		local loadFn = Core.loadStringFn()
		if not loadFn then
			return nil
		end
		local chunk, err = loadFn(src, "@Alleral/" .. filename)
		if not chunk then
			Core.logWarn("Hub module compile failed: " .. filename .. " " .. tostring(err))
			return nil
		end
		local ok, result = pcall(chunk)
		if not ok then
			Core.logWarn("Hub module runtime failed: " .. filename .. " " .. tostring(result))
			return nil
		end
		return result
	end

	local UiSpr = loadHubModule("ui_spr.luau")
	local UiMotion = nil
	if UiSpr then
		local motionFactory = loadHubModule("ui_motion.luau")
		if type(motionFactory) == "function" then
			UiMotion = motionFactory(Core, UiSpr)
		end
	end
	ENV.Alleral_UiMotion = UiMotion

	local function iconImage(icon)
		if type(icon) == "number" then
			return "rbxassetid://" .. tostring(icon)
		end
		local text = tostring(icon or "")
		if text:find("rbxassetid", 1, true) then
			return text
		end
		if text:match("^%d+$") then
			return "rbxassetid://" .. text
		end
		local mapped = Core.windUiIcon and Core.windUiIcon(icon)
		if type(mapped) == "string" and mapped ~= "" then
			if mapped:find("rbxassetid", 1, true) then
				return mapped
			end
			if mapped:match("^%d+$") then
				return "rbxassetid://" .. mapped
			end
		end
		return "rbxassetid://18821914323"
	end

	local function fetchMaclibSource()
		local urls = {
			MACLIB_URL,
			MACLIB_URL .. "?t=" .. tostring(tick()),
			MACLIB_FALLBACK,
		}
		for _, url in ipairs(urls) do
			local body = type(Core.httpGet) == "function" and Core.httpGet(url)
			if type(body) ~= "string" or #body < 5000 then
				local http = ENV.Alleral_HTTP
				if type(http) == "table" and type(http.get) == "function" then
					body = http.get(url, 5000)
				end
			end
			if type(body) == "string" and #body >= 5000 and not body:find("<!DOCTYPE", 1, true) then
				return body, url
			end
		end
		return nil
	end

	local function loadMaclib()
		local cached = ENV._AlleralMaclib
		if type(cached) == "table" and type(cached.Window) == "function" then
			return cached
		end
		local source, label = fetchMaclibSource()
		if not source then
			return nil, "Maclib download failed"
		end
		local loadFn = Core.loadStringFn()
		if not loadFn then
			return nil, "load unavailable"
		end
		local chunk, err = loadFn(source, "@Maclib/" .. tostring(label))
		if not chunk then
			return nil, tostring(err or "Maclib compile failed")
		end
		local ok, MacLib = pcall(chunk)
		if not ok or type(MacLib) ~= "table" then
			return nil, tostring(MacLib or "Maclib runtime failed")
		end
		ENV._AlleralMaclib = MacLib
		pcall(function()
			MacLib:SetFolder("Alleral_Maclib")
		end)
		return MacLib
	end

	local function wrapLibrary(MacLib)
		local themes = { "Maclib", "Default", "Dark", "Light" }
		local motionProfiles = { "fluid", "snappy", "bouncy", "cinematic", "reduced" }
		local layoutProfiles = { "auto", "desktop", "mobile", "compact" }
		local activeTheme = "Maclib"
		local motionProfile = "fluid"
		local glassIntensity = 0.55
		local chromeDepth = 0.65
		local tooltipStyle = "rich"
		local notificationStyle = "glass"
		local ambientGlow = true
		local tabAurora = true
		local sectionLift = true
		local activeWindow = nil
		local notificationsEnabled = true
		local notifyLower = false

		local Library = {
			MacLib = MacLib,
			Holder = nil,
			Window = nil,
			Version = Core.ALLERAL_UI_VERSION,
			ALLERAL_UI_VERSION = Core.ALLERAL_UI_VERSION,
			_pendingNotifies = {},
			CommandPalette = {
				register = function() end,
				toggle = function() end,
			},
		}

		local function flushPendingNotifies(targetWindow)
			targetWindow = targetWindow or activeWindow or Library.Window
			if not targetWindow or type(targetWindow.Notify) ~= "function" then
				return
			end
			while #Library._pendingNotifies > 0 do
				local payload = table.remove(Library._pendingNotifies, 1)
				pcall(targetWindow.Notify, targetWindow, payload)
			end
		end

		local function pushNotification(info)
			info = type(info) == "table" and info or { Description = tostring(info) }
			local payload = {
				Title = info.Title or "Alleral",
				Description = info.Description or info.Content or info.Text or "",
				Lifetime = info.Lifetime or info.Duration or info.Time or 4,
			}
			local win = activeWindow or Library.Window
			if win and type(win.Notify) == "function" and notificationsEnabled then
				if type(win.GetNotificationsState) == "function" and not win:GetNotificationsState() then
					return
				end
				pcall(win.Notify, win, payload)
				return
			end
			table.insert(Library._pendingNotifies, payload)
		end

		function Library:GetAlleralVersion()
			return Core.ALLERAL_UI_VERSION
		end

		function Library:GetArrrelVersion()
			return Core.ALLERAL_UI_VERSION
		end

		function Library:EnsureGuiRoot()
			return true
		end

		function Library:Notification(info)
			pushNotification(info)
		end

		function Library:Notify(info)
			pushNotification(info)
		end

		function Library:ClearNotifications()
			local win = activeWindow or Library.Window
			if win and type(win.ClearNotifications) == "function" then
				local ok, cleared = pcall(win.ClearNotifications, win)
				if ok and type(cleared) == "number" then
					return cleared
				end
			end
			Library._pendingNotifies = {}
			return 0
		end

		function Library:SetNotificationLower(enabled)
			notifyLower = enabled == true
			ENV.Alleral_NotifyLower = notifyLower
		end

		function Library:RepairWindow(window)
			window = window or activeWindow or Library.Window
			if UiMotion and window and type(UiMotion.repair) == "function" then
				pcall(UiMotion.repair, window)
			end
			if window and type(window.Toggle) == "function" then
				pcall(window.Toggle, window)
			end
			return true
		end

		function Library:ListThemeNames()
			return themes
		end

		function Library:SetTheme(name)
			activeTheme = tostring(name or activeTheme)
			if activeWindow and type(activeWindow.SetTheme) == "function" then
				pcall(activeWindow.SetTheme, activeWindow, activeTheme)
			end
		end

		function Library:CycleTheme(step)
			step = tonumber(step) or 1
			local index = 1
			for i, name in ipairs(themes) do
				if name == activeTheme then
					index = i
					break
				end
			end
			index = ((index - 1 + step) % #themes) + 1
			Library:SetTheme(themes[index])
			return { Name = themes[index] }
		end

		function Library:ListMotionProfiles()
			return motionProfiles
		end

		function Library:GetMotionProfile()
			return motionProfile
		end

		function Library:SetMotionProfile(name)
			motionProfile = tostring(name or motionProfile)
			ENV.Alleral_MotionProfile = motionProfile
			if UiMotion and type(UiMotion.setProfile) == "function" then
				pcall(UiMotion.setProfile, motionProfile)
			end
		end

		function Library:SetSpringMotion(enabled)
			ENV.Alleral_UiSpringMotion = enabled ~= false
		end

		function Library:SetReducedMotion(enabled)
			ENV.Alleral_UiReducedMotion = enabled == true
		end

		function Library:GetSpringMotion()
			return ENV.Alleral_UiSpringMotion ~= false
		end

		function Library:ListProfiles()
			return layoutProfiles
		end

		function Library:ApplyProfile(name)
			ENV.Alleral_UiProfile = tostring(name or "auto")
		end

		function Library:GetGlassIntensity()
			return glassIntensity
		end

		function Library:SetGlassIntensity(value)
			glassIntensity = tonumber(value) or glassIntensity
			if activeWindow and type(activeWindow.SetAcrylicBlurState) == "function" then
				pcall(activeWindow.SetAcrylicBlurState, activeWindow, glassIntensity > 0.2)
			end
		end

		function Library:SetChromeDepth(value)
			chromeDepth = tonumber(value) or chromeDepth
			ENV.Alleral_ChromeDepth = chromeDepth
		end

		function Library:GetTooltipStyle()
			return tooltipStyle
		end

		function Library:SetTooltipStyle(style)
			tooltipStyle = tostring(style or tooltipStyle)
		end

		function Library:GetNotificationStyle()
			return notificationStyle
		end

		function Library:SetNotificationStyle(style)
			notificationStyle = tostring(style or notificationStyle)
		end

		function Library:SetAmbientGlow(enabled)
			ambientGlow = enabled == true
			ENV.Alleral_AmbientGlow = ambientGlow
		end

		function Library:SetTabAurora(enabled)
			tabAurora = enabled == true
			ENV.Alleral_TabAurora = tabAurora
		end

		function Library:SetSectionLift(enabled)
			sectionLift = enabled == true
			ENV.Alleral_SectionLift = sectionLift
		end

		function Library:ApplyAccentPreset(_name)
			if type(Core.applyThemeAccent) == "function" then
				pcall(Core.applyThemeAccent, Library, Color3.fromHex("#53fc18"))
			end
		end

		function Library:FlashAccent()
			return true
		end

		function Library:CreateWindow(settings)
			settings = type(settings) == "table" and settings or {}
			local Players = game:GetService("Players")
			local lp = Players.LocalPlayer
			local playerLabel = lp and ((lp.DisplayName ~= "" and lp.DisplayName) or lp.Name) or ""
			local menuKey = settings.Keybind or ENV.Alleral_UiKeybind or Enum.KeyCode.RightControl
			ENV.Alleral_UiKeybind = menuKey
			local window = MacLib:Window({
				Title = settings.Title or settings.Name or "Alleral",
				Subtitle = settings.Subtitle or settings.SubName or playerLabel,
				Size = settings.Size or UDim2.fromOffset(868, 650),
				DragStyle = 1,
				ShowUserInfo = true,
				Keybind = menuKey,
				AcrylicBlur = settings.Acrylic ~= false,
			})
			activeWindow = window
			Library.Window = window
			window._macTabGroup = window:TabGroup()
			window._macTabs = {}

			if type(window.GlobalSetting) == "function" then
				pcall(function()
					window:GlobalSetting({
						Name = "UI Blur",
						Default = type(window.GetAcrylicBlurState) == "function" and window:GetAcrylicBlurState()
							or settings.Acrylic ~= false,
						Callback = function(enabled)
							if type(window.SetAcrylicBlurState) == "function" then
								window:SetAcrylicBlurState(enabled == true)
							end
						end,
					})
				end)
				pcall(function()
					window:GlobalSetting({
						Name = "Notifications",
						Default = type(window.GetNotificationsState) == "function" and window:GetNotificationsState()
							or true,
						Callback = function(enabled)
							notificationsEnabled = enabled == true
							if type(window.SetNotificationsState) == "function" then
								window:SetNotificationsState(enabled == true)
							end
						end,
					})
				end)
				pcall(function()
					window:GlobalSetting({
						Name = "Show User Info",
						Default = type(window.GetUserInfoState) == "function" and window:GetUserInfoState() or true,
						Callback = function(enabled)
							if type(window.SetUserInfoState) == "function" then
								window:SetUserInfoState(enabled == true)
							end
						end,
					})
				end)
			end

			flushPendingNotifies(window)
			if UiMotion and type(UiMotion.attachWindow) == "function" then
				task.defer(function()
					pcall(UiMotion.attachWindow, window)
				end)
			end
			return window
		end

		return Library
	end

	local function uiOk(bundle)
		return type(bundle) == "table"
			and type(bundle.Library) == "table"
			and type(bundle.CreateWindow) == "function"
	end

	local function cacheUi(bundle)
		ENV.Alleral_UI = bundle
		if getgenv then
			getgenv().Alleral_UI = bundle
		end
		return bundle
	end

	function Core.loadUi()
		local cached = ENV.Alleral_UI
		if uiOk(cached) then
			return cacheUi(cached)
		end
		if cached then
			ENV.Alleral_UI = nil
		end

		local MacLib, err = loadMaclib()
		if not MacLib then
			Core.logWarn("Alleral UI load failed: " .. tostring(err or "Maclib missing"))
			return nil, err or "Maclib missing"
		end

		local Library = wrapLibrary(MacLib)
		ENV._AlleralUiLibrary = Library
		Core.clearUiStateBindings()

		local bundle = {
			Library = Library,
			Alleral = Library,
			WindUI = Library,
			MacLib = MacLib,
			CreateWindow = function(_, settings)
				return Library:CreateWindow(settings)
			end,
			Notify = function(_, info)
				Library:Notification(info)
			end,
		}
		Core.say("Alleral UI " .. tostring(Library:GetAlleralVersion()) .. " (Maclib)")
		return cacheUi(bundle)
	end

	function Core.preloadUi()
		return Core.loadUi()
	end

	Core.releaseAlleralRuntime = function()
		ENV._AlleralUiLibrary = nil
		ENV._AlleralMaclib = nil
	end

	function Core.uiLibrary(bundle)
		if type(bundle) ~= "table" then
			return nil
		end
		return bundle.Alleral or bundle.Library or bundle.MacLib
	end

	function Core.createWindUiGroupbox(rawSection, uiBundle)
		rawSection = rawSection or {}
		uiBundle = uiBundle or {}
		local serial = 0

		local function nextFlag(name, explicit)
			serial += 1
			return explicit or Core.uiElementId(name) .. "_" .. serial
		end

		local function wrapElement(applySet, meta)
			meta = type(meta) == "table" and meta or {}
			local wrapper = {
				_raw = meta.raw,
				Set = function(_, settings)
					if type(settings) == "table" then
						applySet(settings)
					else
						applySet({ CurrentValue = settings })
					end
				end,
			}
			if meta.bindKey then
				Core.bindUiState(meta.bindKey, wrapper, meta.kind or "toggle", meta.raw)
			end
			return wrapper
		end

		local function dropdownDefault(values, current, multi)
			values = values or {}
			if multi then
				local selected = Core.normalizeMultiSelection(current)
				if #selected > 0 then
					return selected
				end
				return {}
			end
			if type(current) == "table" then
				return Core.normalizeDropdownValue(current, values[1])
			end
			if current and current ~= "" then
				return tostring(current)
			end
			return values[1]
		end

		local groupbox = {}

		function groupbox:CreateToggle(settings, id)
			local handle = rawSection:Toggle({
				Name = settings.Name,
				Default = settings.CurrentValue == true,
				Callback = settings.Callback or function() end,
			}, nextFlag(settings.Name, id))
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue == nil or not handle then
					return
				end
				local value = nextSettings.CurrentValue == true
				if type(handle.UpdateState) == "function" then
					pcall(handle.UpdateState, handle, value)
				elseif handle.Set then
					pcall(handle.Set, handle, value)
				end
			end, {
				raw = handle,
				bindKey = settings.BindKey or settings.StateKey,
				kind = "toggle",
			})
		end

		function groupbox:CreateSlider(settings, id)
			local range = settings.Range or { 0, 100 }
			local minValue, maxValue = range[1], range[2]
			local increment = tonumber(settings.Increment) or Core.sliderIncrement(minValue, maxValue, settings.Increment)
			local precision = 0
			if increment and increment < 1 then
				local text = tostring(increment)
				local dot = text:find("%.")
				precision = dot and (#text - dot) or 1
			end
			local handle = rawSection:Slider({
				Name = settings.Name,
				Default = tonumber(settings.CurrentValue) or minValue,
				Minimum = minValue,
				Maximum = maxValue,
				Precision = precision,
				DisplayMethod = "Value",
				Callback = settings.Callback or function() end,
			}, nextFlag(settings.Name, id))
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue == nil or not handle then
					return
				end
				local value = tonumber(nextSettings.CurrentValue) or minValue
				if type(handle.UpdateValue) == "function" then
					pcall(handle.UpdateValue, handle, value)
				elseif handle.Set then
					pcall(handle.Set, handle, value)
				end
			end, {
				raw = handle,
				bindKey = settings.BindKey or settings.StateKey,
				kind = "slider",
			})
		end

		function groupbox:CreateButton(settings, id)
			local handle = rawSection:Button({
				Name = settings.Name,
				Callback = settings.Callback or function() end,
			}, nextFlag(settings.Name, id))
			return wrapElement(function(nextSettings)
				if nextSettings.Name and handle and type(handle.UpdateName) == "function" then
					pcall(handle.UpdateName, handle, nextSettings.Name)
				end
			end, {
				raw = handle,
			})
		end

		function groupbox:CreateInput(settings, id)
			local handle = rawSection:Input({
				Name = settings.Name,
				Placeholder = settings.PlaceholderText or settings.Placeholder or "",
				Default = settings.CurrentValue or settings.Default or "",
				AcceptedCharacters = settings.AcceptedCharacters or "All",
				Callback = settings.Callback or function() end,
				onChanged = settings.onChanged,
			}, nextFlag(settings.Name, id))
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue == nil then
					return
				end
				if handle and type(handle.UpdateText) == "function" then
					pcall(handle.UpdateText, handle, tostring(nextSettings.CurrentValue))
				elseif handle and handle.Set then
					pcall(handle.Set, handle, tostring(nextSettings.CurrentValue))
				end
			end, {
				raw = handle,
				bindKey = settings.BindKey or settings.StateKey,
				kind = "input",
			})
		end

		function groupbox:CreateDropdown(settings, id)
			local values = settings.Options or settings.Values or {}
			local multi = settings.MultipleOptions == true or settings.Multi == true
			local current = dropdownDefault(values, settings.CurrentOption, multi)
			local defaultIndex = 1
			if not multi then
				for i, value in ipairs(values) do
					if tostring(value) == tostring(current) then
						defaultIndex = i
						break
					end
				end
			end
			local handle = rawSection:Dropdown({
				Name = settings.Name,
				Options = values,
				Default = multi and current or defaultIndex,
				Multi = multi,
				Search = settings.Searchable == true,
				Callback = function(selection)
					local userCallback = settings.Callback or function() end
					if multi then
						userCallback(Core.normalizeMultiSelection(selection))
					else
						userCallback(Core.normalizeDropdownValue(selection, values[1]))
					end
				end,
			}, nextFlag(settings.Name, id))
			return wrapElement(function(nextSettings)
				if not handle then
					return
				end
				local pick = nextSettings.CurrentOption or nextSettings.CurrentOptions
				if pick == nil then
					return
				end
				if type(handle.UpdateSelection) == "function" then
					pcall(handle.UpdateSelection, handle, pick)
				elseif handle.Set then
					pcall(handle.Set, handle, pick)
				end
			end, {
				raw = handle,
				bindKey = settings.BindKey or settings.StateKey,
				kind = "dropdown",
			})
		end

		function groupbox:CreateLabel(settings, id)
			local text = type(settings) == "table" and (settings.Name or settings.Text) or tostring(settings or "")
			local label = rawSection:Label({ Text = text })
			return {
				_raw = label,
				Set = function(_, nextSettings)
					local nextText = type(nextSettings) == "table" and (nextSettings.Name or nextSettings.Text)
						or tostring(nextSettings or "")
					if label and type(label.UpdateName) == "function" then
						pcall(label.UpdateName, label, nextText)
					elseif label and label.Set then
						pcall(label.Set, label, nextText)
					end
				end,
				SetVisible = function(_, visible)
					if label and type(label.SetVisibility) == "function" then
						pcall(label.SetVisibility, label, visible == true)
					end
				end,
			}
		end

		function groupbox:CreateStatus(label, fields)
			local status = {
				Labels = {},
				LastValues = {},
				Visible = true,
			}
			for key, value in pairs(fields or {}) do
				status.LastValues[key] = tostring(value)
				status.Labels[key] = groupbox:CreateLabel({
					Name = tostring(key) .. ": " .. tostring(value),
				}, nextFlag(label .. "_" .. tostring(key)))
			end
			status.Labels.Summary = groupbox:CreateLabel({ Name = "" }, nextFlag(label .. "_summary"))
			function status:Update(key, value)
				local rendered = tostring(value)
				if self.LastValues[key] == rendered then
					return
				end
				self.LastValues[key] = rendered
				local row = self.Labels[key]
				if row and row.Set then
					row:Set({ Name = tostring(key) .. ": " .. rendered })
				end
			end
			function status:SetSummary(text)
				local row = self.Labels.Summary
				if row and row.Set then
					row:Set({ Name = tostring(text or "") })
				end
			end
			function status:SetVisible(visible)
				local show = visible == true
				self.Visible = show
				for _, row in pairs(self.Labels) do
					if row and type(row.SetVisible) == "function" then
						row:SetVisible(show)
					elseif row and row._raw and type(row._raw.SetVisibility) == "function" then
						pcall(row._raw.SetVisibility, row._raw, show)
					end
				end
			end
			return status
		end

		function groupbox:CreateDivider()
			if type(rawSection.Divider) == "function" then
				rawSection:Divider()
			end
			return {}
		end

		return groupbox
	end

	Core._UiTabRegistry = Core._UiTabRegistry or {}

	function Core.wrapUiTab(rawTab, uiBundle, window)
		local tab = {
			_macTab = rawTab,
			_ui = uiBundle,
			_window = window,
			_columnCount = 2,
		}
		table.insert(Core._UiTabRegistry, tab)

		function tab:CreateGroupbox(settings)
			settings = settings or {}
			local name = settings.Name or "Group"
			local column = math.clamp(tonumber(settings.Column) or 1, 1, 2)
			local side = column == 2 and "Right" or "Left"
			if not rawTab or type(rawTab.Section) ~= "function" then
				Core.logWarn("CreateGroupbox skipped — tab missing for " .. tostring(name))
				return Core.createStubUiGroup(name)
			end
			local section = rawTab:Section({ Side = side })
			if name ~= "" and type(section.Header) == "function" then
				pcall(function()
					section:Header({ Name = name })
				end)
			end
			return Core.createWindUiGroupbox(section, uiBundle)
		end

		function tab:BuildThemeGroupbox(column)
			local group = Core.buildUiGroup(tab, "Appearance", column or 1)
			local lib = Core.uiLibrary(uiBundle)
			local themes = (lib and type(lib.ListThemeNames) == "function" and lib:ListThemeNames())
				or { "Maclib", "Default", "Dark", "Light" }
			local current = ENV.Alleral_ActiveTheme or "Maclib"
			group:CreateDropdown("Theme preset", themes, current, function(selected)
				if lib and type(lib.SetTheme) == "function" then
					pcall(lib.SetTheme, lib, selected)
				end
				ENV.Alleral_ActiveTheme = selected
				Core.notify("Theme", "Applied " .. tostring(selected), 2, "success")
			end, "Maclib interface themes.")
			group:CreateButton("Next theme", function()
				if lib and type(lib.CycleTheme) == "function" then
					local ok, nextTheme = pcall(function()
						return lib:CycleTheme(1)
					end)
					if ok and type(nextTheme) == "table" and nextTheme.Name then
						Core.notify("Theme", "Applied " .. tostring(nextTheme.Name), 2, "success")
					end
				end
			end, "Cycle through theme presets.")
			return group
		end

		function tab:Select()
			if rawTab and type(rawTab.Select) == "function" then
				pcall(rawTab.Select, rawTab)
			end
		end

		return tab
	end

	function Core.buildUiWindow(ui, settings)
		settings = settings or {}
		local lib = ui and ui.Library
		if not lib or type(lib.CreateWindow) ~= "function" then
			return nil
		end
		local rawWindow = lib:CreateWindow(settings)
		if not rawWindow then
			Core.logWarn("Maclib window create failed")
			return nil
		end
		local window = {
			_rawWindow = rawWindow,
			_nlWindow = rawWindow,
			_premiumWindow = rawWindow,
			_ui = ui,
			_library = lib,
			_initialized = false,
			_tabGroup = rawWindow._macTabGroup,
		}
		Core.registerUiWindow(window)
		Core.flushPendingNotifications()
		ENV.Alleral_MaclibKeybind = ENV.Alleral_UiKeybind or Enum.KeyCode.RightControl
		function window:AddTab(name, icon)
			if not self._tabGroup or type(self._tabGroup.Tab) ~= "function" then
				return nil
			end
			return self._tabGroup:Tab({
				Name = name,
				Image = iconImage(icon),
			})
		end
		function window:Toggle()
			if self._rawWindow and type(self._rawWindow.Toggle) == "function" then
				pcall(self._rawWindow.Toggle, self._rawWindow)
			end
		end
		return window
	end

	function Core.buildUiTab(section, name, icon, columns, id)
		local resolve = Core.resolveUiWindow
		local window = type(resolve) == "function" and resolve(section) or nil
		if type(window) ~= "table" or not window._rawWindow then
			Core.logWarn("buildUiTab skipped — window missing")
			return Core.wrapUiTab(nil, type(section) == "table" and section._ui or nil, window)
		end
		local tabGroup = window._tabGroup or window._rawWindow._macTabGroup
		if not tabGroup or type(tabGroup.Tab) ~= "function" then
			Core.logWarn("buildUiTab skipped — tab group missing")
			return Core.wrapUiTab(nil, window._ui, window)
		end
		local rawTab = tabGroup:Tab({
			Name = name,
			Image = iconImage(icon),
		})
		local wrapped = Core.wrapUiTab(rawTab, window._ui or (type(section) == "table" and section._ui) or nil, window)
		wrapped._columnCount = math.max(1, tonumber(columns) or 2)
		if not window._defaultTab then
			window._defaultTab = rawTab
		end
		return wrapped
	end

	function Core.buildUiGroup(tab, name, column, callbackWrapper, icon, id)
		name = tostring(name or "Group")
		if type(tab) ~= "table" or type(tab.CreateGroupbox) ~= "function" then
			return Core.createStubUiGroup(name)
		end
		local groupbox = tab:CreateGroupbox({
			Name = name,
			Column = column or 1,
			Icon = icon,
		})
		if callbackWrapper then
			return Core.wrapUiGroup(groupbox, callbackWrapper)
		end
		return Core.wrapUiGroup(groupbox)
	end

	function Core.finalizeGameUi(window, ui, options)
		options = type(options) == "table" and options or {}
		if type(window) == "table" and window._rawWindow and not window._initialized then
			window._initialized = true
			task.defer(function()
				pcall(function()
					local defaultTab = window._defaultTab
					if defaultTab and type(defaultTab.Select) == "function" then
						defaultTab:Select()
					end
				end)
			end)
		end
		if type(Core.setupHubKeybinds) == "function" then
			pcall(Core.setupHubKeybinds, {
				window = window,
				ui = ui or window._ui or ENV.Alleral_UI,
				uiKey = ENV.Alleral_UiKeybind or ENV.Alleral_MaclibKeybind,
			})
		end
		if type(Core.registerExploitCommandPalette) == "function" then
			pcall(Core.registerExploitCommandPalette, window, ui)
		end
		if options.notify ~= false then
			Core.notifyBootReady({
				Name = options.Name or "Alleral",
				Subtitle = options.Subtitle,
			})
		end
		return window
	end

	function Core.repairUiWindow(_window)
		return true
	end

	function Core.refreshAllTabColumns()
		return true
	end

	Core.notifyWindUi = function(info)
		local ui = ENV.Alleral_UI
		if ui and type(ui.Notify) == "function" then
			pcall(ui.Notify, ui, info)
		end
	end
end
