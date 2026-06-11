--[[
	Neverlose UI layer — replaces WindUI/Alleral patch stack.
	Loaded after core_ui; overrides Core UI entry points only.
]]

return function(Core)
	local NEVERLOSE_ROOTS = {
		"ui/neverlose/",
		"kick/ui/neverlose/",
		"kick/kick/ui/neverlose/",
		".alleral/cache/ui/neverlose/",
	}
	local NEVERLOSE_MIRRORS = {
		"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/ui/neverlose/",
		"https://github.com/evanbackup1256-ship-it/kick/main/ui/neverlose/",
	}
	local LIBRARY_FILE = "library.lua"
	local SPRING_FILE = "spring.luau"
	local MIN_LIBRARY_BYTES = 80000
	local MIN_SPRING_BYTES = 400

	local function genv()
		local ok, env = pcall(function()
			return getgenv and getgenv() or getfenv()
		end)
		return ok and env or {}
	end
	local ENV = genv()

	local function readLocal(name)
		local roots = { "", "kick/", "kick/kick/", "workspace/", "scripts/" }
		for _, vendor in ipairs(NEVERLOSE_ROOTS) do
			for _, root in ipairs(roots) do
				local path = root .. vendor .. name
				local body = Core.readFile(path)
				if body then
					return body, path
				end
			end
		end
		return nil
	end

	local function fetchRemote(name, minBytes)
		minBytes = minBytes or MIN_LIBRARY_BYTES
		for _, base in ipairs(NEVERLOSE_MIRRORS) do
			local body = Core.httpGet(base .. name)
			if type(body) == "string" and #body >= minBytes then
				return body, base .. name
			end
		end
		return nil
	end

	local function compileModule(source, label)
		local loadFn = Core.loadStringFn()
		if not loadFn or not source then
			return nil, "compile unavailable"
		end
		local chunk, err = loadFn(source, label)
		if not chunk then
			return nil, tostring(err)
		end
		local ok, result = pcall(chunk)
		if not ok then
			return nil, tostring(result)
		end
		return result
	end

	local function neverloseLibraryLive(lib)
		if type(lib) ~= "table" or type(lib.Window) ~= "function" then
			return false
		end
		if type(lib.EnsureGuiRoot) == "function" then
			local ok = pcall(lib.EnsureGuiRoot, lib)
			if not ok then
				return false
			end
		end
		return lib.Holder and lib.Holder.Instance
	end

	local function loadNeverloseLibrary()
		if neverloseLibraryLive(ENV._NeverloseLibrary) then
			return ENV._NeverloseLibrary
		end
		ENV._NeverloseLibrary = nil
		if getgenv().Library then
			getgenv().Library = nil
		end

		local springFactory = compileModule(readLocal(SPRING_FILE) or fetchRemote(SPRING_FILE, MIN_SPRING_BYTES), "@Neverlose/spring")
		local Spring = type(springFactory) == "function" and springFactory() or nil

		local libSource = readLocal(LIBRARY_FILE) or fetchRemote(LIBRARY_FILE, MIN_LIBRARY_BYTES)
		if not libSource then
			return nil, "library.lua missing"
		end

		local Library = compileModule(libSource, "@Neverlose/library")
		if type(Library) ~= "table" then
			return nil, "invalid Neverlose library"
		end

		if not Spring then
			Core.logWarn("Neverlose spring unavailable — UI loads with TweenService animation fallback")
		end

		do
			local springModule = Spring
			local origNotification = type(Library.Notification) == "function" and Library.Notification or nil
			local motionProfiles = {
				fluid = { frequency = 7, damping = 0.78 },
				snappy = { frequency = 11, damping = 0.9 },
				bouncy = { frequency = 6, damping = 0.58 },
				cinematic = { frequency = 4.5, damping = 0.95 },
				reduced = { frequency = 18, damping = 1 },
			}
			local themePresets = {
				Mint = { Accent = Color3.fromHex("#53fc18"), Background = Color3.fromHex("#0c0c0e"), ["AccentGradient"] = Color3.fromHex("#30ff6a") },
				Arrrel = { Accent = Color3.fromHex("#53fc18"), Background = Color3.fromHex("#0c0c0e"), ["AccentGradient"] = Color3.fromHex("#30ff6a") },
				ArrrelNeon = { Accent = Color3.fromHex("#00ff88"), Background = Color3.fromHex("#050508") },
				ArrrelMidnight = { Accent = Color3.fromHex("#4a9eff"), Background = Color3.fromHex("#080810") },
				ArrrelAurora = { Accent = Color3.fromHex("#7c5cff"), Background = Color3.fromHex("#0a0812") },
				ArrrelObsidian = { Accent = Color3.fromHex("#30ff6a"), Background = Color3.fromHex("#050505") },
				ArrrelSynth = { Accent = Color3.fromHex("#ff3d9a"), Background = Color3.fromHex("#120818") },
				ArrrelOcean = { Accent = Color3.fromHex("#00c3ff"), Background = Color3.fromHex("#061018") },
				ArrrelEmber = { Accent = Color3.fromHex("#ff6b2b"), Background = Color3.fromHex("#120a08") },
				ArrrelStealth = { Accent = Color3.fromHex("#8a8a8a"), Background = Color3.fromHex("#101010") },
				ArrrelPaper = { Accent = Color3.fromHex("#2d6cdf"), Background = Color3.fromHex("#f0f0f2") },
				ArrrelVoid = { Accent = Color3.fromHex("#b026ff"), Background = Color3.fromHex("#030003") },
				Neverlose = { Accent = Color3.fromRGB(0, 116, 224), Background = Color3.fromRGB(12, 12, 14) },
			}
			local themeNames = {}
			for name in pairs(themePresets) do
				table.insert(themeNames, name)
			end
			table.sort(themeNames)

			Library._SpringModule = springModule
			Library._Spring = springModule
			Library._SpringMotion = motionProfiles.fluid
			Library.ALLERAL_UI_V2 = true
			Library.WindUI = Library

			local function applyTheme(name)
				name = tostring(name or "Neverlose")
				if name == "Mint" then
					name = "Arrrel"
				end
				ENV.Alleral_ActiveTheme = name
				local preset = themePresets[name] or themePresets.Neverlose
				if type(Library.ChangeTheme) == "function" then
					for key, color in pairs(preset) do
						pcall(Library.ChangeTheme, Library, key, color)
					end
				end
			end

			Library.Notification = function(self, data)
				data = type(data) == "table" and data or { Title = "Notice", Description = tostring(data) }
				local payload = {
					Title = data.Title or data.title or "Notice",
					Description = data.Description or data.Content or data.Text or data.description or "",
					Duration = data.Duration or data.Time or 4,
				}
				if type(origNotification) == "function" then
					return origNotification(self, payload)
				end
			end
			Library.Notify = Library.Notification
			Library.CreateWindow = function(_, settings)
				settings = type(settings) == "table" and settings or {}
				local icon = settings.Icon or settings.icon or "sparkles"
				if type(icon) == "string" and icon:find("rbxassetid://") then
					icon = icon:match("%d+") or icon
				elseif type(icon) == "number" then
					icon = tostring(icon)
				end
				return Library:Window({
					Name = settings.Title or settings.Name or "Alleral",
					SubName = settings.Author or settings.Subtitle or settings.SubName or "",
					Logo = Core.uiIcon(icon) ~= "" and Core.uiIcon(icon) or "10723407389",
				})
			end
			Library.SetUiScale = function() end
			Library.ApplyProfile = function(_, profile)
				profile = tostring(profile or "auto")
				ENV.Alleral_UiProfile = profile
				local holder = Library.Holder and Library.Holder.Instance
				local main = holder and holder:FindFirstChild("\0", true)
				if main and main:IsA("Frame") then
					local sizes = {
						mobile = UDim2.fromOffset(560, 620),
						compact = UDim2.fromOffset(620, 580),
						cinema = UDim2.fromOffset(760, 680),
						ultrawide = UDim2.fromOffset(920, 640),
						desktop = UDim2.fromOffset(677, 644),
					}
					local target = sizes[profile] or sizes.desktop
					if profile == "auto" then
						local cam = workspace.CurrentCamera
						if cam and cam.ViewportSize.X < 900 then
							target = sizes.mobile
						end
					end
					pcall(function()
						main.Size = target
					end)
				end
			end
			Library.Preload = function() end
			Library.GetNeverloseVersion = function()
				return Core.NEVERLOSE_UI_VERSION or "1.1.0-kick"
			end
			Library.GetAlleralVersion = Library.GetNeverloseVersion
			Library.ListMotionProfiles = function()
				return { "fluid", "snappy", "bouncy", "cinematic", "reduced" }
			end
			Library.GetMotionProfile = function()
				return ENV.Alleral_MotionProfile or "fluid"
			end
			Library.SetMotionProfile = function(_, name)
				name = tostring(name or "fluid")
				ENV.Alleral_MotionProfile = name
				Library._SpringMotion = motionProfiles[name] or motionProfiles.fluid
			end
			Library.ListThemeNames = function()
				return themeNames
			end
			Library.SetTheme = function(_, name)
				applyTheme(tostring(name or "Neverlose"))
			end
			Library.ApplyAccentPreset = function(_, name)
				name = tostring(name or "Arrrel")
				if name == "Mint" then
					name = "Arrrel"
				end
				applyTheme(name)
			end
			Library.SetAccentColor = function(_, color)
				if typeof(color) ~= "Color3" then
					return
				end
				pcall(Library.ChangeTheme, Library, "Accent", color)
				pcall(Library.ChangeTheme, Library, "AccentGradient", color:Lerp(Color3.new(1, 1, 1), 0.22))
			end
			Library.FlashAccent = function()
				local holder = Library.Holder and Library.Holder.Instance
				if not holder then
					return
				end
				local pulse = holder:FindFirstChild("AccentPulse", true)
				if not pulse then
					pulse = Instance.new("Frame")
					pulse.Name = "AccentPulse"
					pulse.BackgroundTransparency = 1
					pulse.Size = UDim2.fromScale(1, 1)
					pulse.ZIndex = 999
					pulse.Parent = holder
					local stroke = Instance.new("UIStroke")
					stroke.Thickness = 2
					stroke.Transparency = 1
					stroke.Parent = pulse
				end
				local stroke = pulse:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = Library.Theme.Accent
					stroke.Transparency = 0.2
					task.delay(0.35, function()
						stroke.Transparency = 1
					end)
				end
			end
			Library.SetReducedMotion = function(_, enabled)
				ENV.Alleral_UiReducedMotion = enabled == true
				Library._Spring = enabled and nil or Library._SpringModule
				if enabled then
					Library._SpringMotion = motionProfiles.reduced
				else
					Library._SpringMotion = motionProfiles[ENV.Alleral_MotionProfile or "fluid"] or motionProfiles.fluid
				end
			end
			Library.SetSpringMotion = function(_, enabled)
				Library.SetReducedMotion(Library, not enabled)
			end
			Library.ListProfiles = function()
				return {
					{ id = "auto", label = "Auto" },
					{ id = "desktop", label = "Desktop" },
					{ id = "mobile", label = "Mobile" },
					{ id = "compact", label = "Compact" },
					{ id = "cinema", label = "Cinema" },
					{ id = "ultrawide", label = "Ultrawide" },
				}
			end
			Library.GetGlassIntensity = function()
				return tonumber(ENV.Alleral_GlassIntensity) or 0.55
			end
			Library.SetGlassIntensity = function(_, value)
				ENV.Alleral_GlassIntensity = math.clamp(tonumber(value) or 0.55, 0, 1)
			end
			Library.SetChromeDepth = function(_, value)
				ENV.Alleral_ChromeDepth = math.clamp(tonumber(value) or 0.65, 0, 1)
			end
			Library.GetTooltipStyle = function()
				return ENV.Alleral_TooltipStyle or "rich"
			end
			Library.SetTooltipStyle = function(_, style)
				ENV.Alleral_TooltipStyle = tostring(style or "rich")
			end
			Library.GetNotificationStyle = function()
				return ENV.Alleral_ToastStyle or "glass"
			end
			Library.SetNotificationStyle = function(_, style)
				ENV.Alleral_ToastStyle = tostring(style or "glass")
			end
			Library.SetAmbientGlow = function(_, enabled)
				ENV.Alleral_AmbientGlow = enabled ~= false
			end
			Library.SetTabAurora = function(_, enabled)
				ENV.Alleral_TabAurora = enabled ~= false
			end
			Library.SetSectionLift = function(_, enabled)
				ENV.Alleral_SectionLift = enabled ~= false
			end
			Library.CycleV2Theme = function(_, step)
				step = tonumber(step) or 1
				local current = ENV.Alleral_ActiveTheme or "Arrrel"
				local index = table.find(themeNames, current) or 1
				index = ((index - 1 + step) % #themeNames) + 1
				local nextTheme = themeNames[index]
				ENV.Alleral_ActiveTheme = nextTheme
				applyTheme(nextTheme)
				return nextTheme
			end
			Library.ExportCustomization = function()
				return {
					theme = ENV.Alleral_ActiveTheme or "Arrrel",
					motion = Library.GetMotionProfile(Library),
					profile = ENV.Alleral_UiProfile or "auto",
					glass = Library.GetGlassIntensity(Library),
					chrome = ENV.Alleral_ChromeDepth or 0.65,
				}
			end
			Library.ImportCustomization = function(_, payload)
				if type(payload) ~= "table" then
					return false
				end
				if payload.theme then
					Library.SetTheme(Library, payload.theme)
					ENV.Alleral_ActiveTheme = payload.theme
				end
				if payload.motion then
					Library.SetMotionProfile(Library, payload.motion)
				end
				if payload.profile then
					Library.ApplyProfile(Library, payload.profile)
				end
				if payload.glass then
					Library.SetGlassIntensity(Library, payload.glass)
				end
				if payload.chrome then
					Library.SetChromeDepth(Library, payload.chrome)
				end
				return true
			end
			Library.ReleaseWindow = function() end
		end

		ENV._NeverloseLibrary = Library
		pcall(Library.EnsureGuiRoot, Library)
		return Library
	end

	local function uiOk(bundle)
		return type(bundle) == "table" and type(bundle.Library) == "table" and type(bundle.CreateWindow) == "function"
	end

	local function cacheUi(bundle)
		ENV.Alleral_UI = bundle
		return bundle
	end

	local function iconId(icon)
		local numeric = Core.uiIcon(icon)
		if numeric ~= "" then
			return numeric
		end
		if type(icon) == "number" then
			return tostring(icon)
		end
		if type(icon) == "string" and icon:find("%d") then
			return icon:match("%d+") or "10723407389"
		end
		return "10723407389"
	end

	function Core.loadUi()
		local cached = ENV.Alleral_UI
		if uiOk(cached) then
			return cacheUi(cached)
		end

		local Library, err = loadNeverloseLibrary()
		if not Library then
			return nil, err or "Neverlose UI missing"
		end

		Core.clearUiStateBindings()

		local bundle = {
			Library = Library,
			Neverlose = Library,
			Alleral = Library,
			WindUI = Library,
			CreateWindow = function(_, settings)
				return Library.CreateWindow(Library, settings)
			end,
			Notify = function(_, info)
				if type(info) == "table" then
					Library:Notification({
						Title = info.Title or "Alleral",
						Description = info.Content or info.Description or info.Text or "",
						Duration = info.Duration or info.Time or 4,
					})
				else
					Library:Notification({
						Title = "Alleral",
						Description = tostring(info or ""),
						Duration = 4,
					})
				end
			end,
		}
		Core.say("Neverlose UI " .. tostring(Library.GetNeverloseVersion and Library:GetNeverloseVersion() or Core.NEVERLOSE_UI_VERSION) .. " loaded")
		return cacheUi(bundle)
	end

	function Core.preloadUi()
		return Core.loadUi()
	end

	function Core.uiLibrary(bundle)
		if type(bundle) ~= "table" then
			return nil
		end
		return bundle.Neverlose or bundle.Library or bundle.Alleral
	end

	function Core.createWindUiGroupbox(rawSection, uiBundle)
		rawSection = rawSection or {}
		uiBundle = uiBundle or {}
		local serial = 0
		local windUi = Core.uiLibrary(uiBundle)

		local function attachTooltip(handle, tooltip)
			if type(handle) ~= "table" or not tooltip or tostring(tooltip) == "" then
				return
			end
			handle.Desc = handle.Desc or tostring(tooltip)
			handle.Tooltip = handle.Tooltip or tostring(tooltip)
			if windUi and type(windUi.HookElementTooltip) == "function" then
				pcall(windUi.HookElementTooltip, windUi, handle)
			end
		end

		local function nextFlag(name, explicit)
			serial = serial + 1
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
				Desc = settings.Tooltip,
				Default = settings.CurrentValue == true,
				Flag = nextFlag(settings.Name, id),
				Callback = settings.Callback or function() end,
			})
			attachTooltip(handle, settings.Tooltip)
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue ~= nil and handle and handle.Set then
					handle:Set(nextSettings.CurrentValue == true, true)
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
			local increment = Core.sliderIncrement(minValue, maxValue, settings.Increment)
			local handle = rawSection:Slider({
				Name = settings.Name,
				Desc = settings.Tooltip,
				Min = minValue,
				Max = maxValue,
				Default = tonumber(settings.CurrentValue) or minValue,
				Decimals = increment,
				Suffix = settings.Suffix or "",
				Flag = nextFlag(settings.Name, id),
				Callback = settings.Callback or function() end,
			})
			attachTooltip(handle, settings.Tooltip)
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue ~= nil and handle and handle.Set then
					handle:Set(tonumber(nextSettings.CurrentValue) or minValue, true)
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
				Desc = settings.Tooltip,
				Callback = settings.Callback or function() end,
			})
			attachTooltip(handle, settings.Tooltip)
			return { Set = function() end }
		end

		function groupbox:CreateInput(settings, id)
			local handle = rawSection:Textbox({
				Name = settings.Name,
				Desc = settings.Tooltip,
				Default = tostring(settings.CurrentValue or settings.Default or ""),
				Placeholder = settings.PlaceholderText or settings.Placeholder or "",
				Flag = nextFlag(settings.Name, id),
				Callback = settings.Callback or function() end,
			})
			attachTooltip(handle, settings.Tooltip)
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue ~= nil and handle and handle.Set then
					handle:Set(tostring(nextSettings.CurrentValue))
				end
			end)
		end

		function groupbox:CreateDropdown(settings, id)
			local values = settings.Options or settings.Values or {}
			local multi = settings.MultipleOptions == true or settings.Multi == true
			local current = dropdownDefault(values, settings.CurrentOption, multi)
			local handle = rawSection:Dropdown({
				Name = settings.Name,
				Desc = settings.Tooltip,
				Items = values,
				Default = current,
				Multi = multi,
				Flag = nextFlag(settings.Name, id),
				Callback = function(selection)
					local userCallback = settings.Callback or function() end
					if multi then
						userCallback(Core.normalizeMultiSelection(selection))
					else
						userCallback(Core.normalizeDropdownValue(selection, values[1]))
					end
				end,
			})
			attachTooltip(handle, settings.Tooltip)
			return wrapElement(function(nextSettings)
				if not handle or not handle.Set then
					return
				end
				local nextValues = nextSettings.Options or nextSettings.Values
				if nextValues and handle.Refresh then
					handle:Refresh(nextValues, nextSettings.CurrentOption or nextSettings.CurrentOptions)
				end
				local pick = nextSettings.CurrentOption or nextSettings.CurrentOptions
				if pick == nil then
					return
				end
				if multi then
					if type(pick) == "table" then
						local selected = {}
						for key, value in pairs(pick) do
							if value == true then
								table.insert(selected, type(key) == "number" and values[key] or key)
							end
						end
						if #selected > 0 then
							handle:Set(selected)
						end
					else
						handle:Set({ tostring(pick) })
					end
				else
					handle:Set(type(pick) == "table" and pick[1] or pick)
				end
			end, {
				raw = handle,
				bindKey = settings.BindKey or settings.StateKey,
				kind = "dropdown",
			})
		end

		function groupbox:CreateLabel(settings, id)
			local text = type(settings) == "table" and (settings.Name or settings.Text) or tostring(settings or "")
			local label = rawSection:Label(text)
			return {
				Set = function(_, nextSettings)
					local nextText = type(nextSettings) == "table" and (nextSettings.Name or nextSettings.Text)
						or tostring(nextSettings or "")
					if label then
						if label.SetText then
							label:SetText(nextText)
						elseif label.Set then
							label:Set(nextText)
						end
					end
				end,
			}
		end

		function groupbox:CreateDivider()
			if type(rawSection.Space) == "function" then
				rawSection:Space({ Size = 10 })
			end
			return {}
		end

		return groupbox
	end

	Core._UiTabRegistry = Core._UiTabRegistry or {}

	function Core.wrapUiTab(rawPage, uiBundle, window)
		local tab = {
			_rawPage = rawPage,
			_ui = uiBundle,
			_window = window,
			_columnCount = rawPage and rawPage.Columns or 2,
		}
		table.insert(Core._UiTabRegistry, tab)

		function tab:CreateGroupbox(settings)
			settings = settings or {}
			local name = settings.Name or "Group"
			local column = math.clamp(tonumber(settings.Column) or 1, 1, 2)
			if not rawPage or type(rawPage.Section) ~= "function" then
				Core.logWarn("CreateGroupbox skipped — page missing for " .. tostring(name))
				return Core.createStubUiGroup(name)
			end
			local section = rawPage:Section({
				Name = name,
				Side = column,
			})
			return Core.createWindUiGroupbox(section, uiBundle)
		end

		function tab:BuildThemeGroupbox(column)
			return Core.buildUiGroup(tab, "Appearance", column or 1)
		end

		return tab
	end

	function Core.buildUiWindow(ui, settings)
		settings = settings or {}
		local lib = ui and ui.Library
		if not lib or type(lib.Window) ~= "function" then
			return nil
		end
		local Players = game:GetService("Players")
		local lp = Players.LocalPlayer
		local playerLabel = lp and ((lp.DisplayName ~= "" and lp.DisplayName) or lp.Name) or ""
		local nlWindow = lib:Window({
			Name = settings.Name or "Alleral",
			SubName = settings.Subtitle or playerLabel,
			Logo = iconId(settings.Icon or "sparkles"),
		})
		if not nlWindow then
			Core.logWarn("Neverlose window create failed")
			return nil
		end
		if type(nlWindow.Toggle) ~= "function" and type(nlWindow.SetOpen) == "function" then
			function nlWindow:Toggle()
				self:SetOpen(not self.IsOpen)
			end
		end
		local window = {
			_rawWindow = nlWindow,
			_nlWindow = nlWindow,
			_ui = ui,
			_library = lib,
			_initialized = false,
		}
		Core.registerUiWindow(window)
		Core.flushPendingNotifications()
		function window:AddTab(name, icon)
			if not self._rawWindow or type(self._rawWindow.Page) ~= "function" then
				return nil
			end
			return self._rawWindow:Page({
				Name = name,
				Icon = iconId(icon),
				Columns = 2,
			})
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
		local rawPage = window._rawWindow:Page({
			Name = name,
			Icon = iconId(icon),
			Columns = math.max(1, tonumber(columns) or 2),
		})
		local wrapped = Core.wrapUiTab(rawPage, window._ui or (type(section) == "table" and section._ui) or nil, window)
		wrapped._columnCount = math.max(1, tonumber(columns) or 2)
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
		local lib = ui and (ui.Library or ui.Neverlose)
		if type(window) == "table" and window._nlWindow and not window._initialized then
			window._initialized = true
			task.defer(function()
				pcall(function()
					if type(window._nlWindow.Init) == "function" then
						window._nlWindow:Init()
					end
				end)
				if options.watermark ~= false and lib and type(lib.Watermark) == "function" then
					pcall(function()
						lib:Watermark({
							options.Name or "Alleral",
							game:GetService("RunService"):IsStudio() and "Studio" or "Live",
						})
						if lib.WatermarkFrame and lib.WatermarkFrame.Instance then
							lib.WatermarkFrame.Instance.Visible = true
						end
					end)
				end
			end)
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
