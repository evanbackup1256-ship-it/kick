return function(Core)
	Core._AlleralUiLayer = "Alleral UI layer"
	Core.ALLERAL_UI_VERSION = Core.ALLERAL_UI_VERSION or "2.0.0-rayfield"
	Core.WINDUI_VERSION = Core.ALLERAL_UI_VERSION
	Core.UI_LIBRARY = "Rayfield"

	local RAYFIELD_SOURCE_PATH = "ui/rayfield/source.luau"
	local RAYFIELD_SOURCE_URL = "https://sirius.menu/rayfield"
	local DEFAULT_ICON_ID = "18821914323"

	local ENV = (function()
		local ok, env = pcall(function() return getgenv and getgenv() or getfenv() end)
		return ok and env or {}
	end)()

	local function iconImage(icon)
		if icon == nil or icon == "" then return DEFAULT_ICON_ID end
		if type(icon) == "number" then return tostring(icon) end
		local digits = tostring(icon):match("(%d+)$")
		if digits then return digits end
		local fn = Core.windUiIcon or Core.uiIcon
		if type(fn) == "function" then
			local r = fn(icon)
			if type(r) == "string" and r ~= "" then
				local d = r:match("(%d+)$")
				return d or r
			end
		end
		return DEFAULT_ICON_ID
	end

	local function iconAsset(icon)
		return "rbxassetid://" .. iconImage(icon)
	end

	local function fetchRayfieldSource()
		if type(ENV._AlleralRayfieldBundle) == "string" and #ENV._AlleralRayfieldBundle > 1000 then
			return ENV._AlleralRayfieldBundle
		end
		local httpGet = ENV.Alleral_HTTP and ENV.Alleral_HTTP.get
		if type(httpGet) == "function" then
			local src = httpGet(RAYFIELD_SOURCE_URL .. "?t=" .. tostring(tick()), 1000)
			if type(src) == "string" and #src > 1000 then
				ENV._AlleralRayfieldBundle = src
				return src
			end
		end
		return nil
	end

	local function bootRayfield()
		if type(ENV._AlleralRayfield) == "table" and type(ENV._AlleralRayfield.CreateWindow) == "function" then
			return ENV._AlleralRayfield
		end

		ENV.DISABLE_RAYFIELD_REQUESTS = true
		if type(getgenv) == "function" then
			local g = getgenv()
			if type(g) == "table" then
				g.DISABLE_RAYFIELD_REQUESTS = true
			end
		end

		ENV.loadstring = ENV.loadstring or loadstring or load
		if type(task) == "table" then
			ENV.task = task
			ENV.task.spawn = ENV.task.spawn or coroutine.wrap
			ENV.task.delay = ENV.task.delay or function(t, f) task.spawn(function() task.wait(t); f() end) end
			ENV.task.wait = ENV.task.wait or task.wait
			ENV.task.cancel = ENV.task.cancel or function() end
		end

		local src = fetchRayfieldSource()
		if not src then return nil, "Rayfield source unavailable" end

		local loadFn = Core.execFunction and Core.execFunction("loadstring") or loadstring or load
		if type(loadFn) ~= "function" then return nil, "loadstring unavailable" end

		ENV.loadstring = ENV.loadstring or loadstring or load
		ENV.task = ENV.task or task
		ENV.debug = ENV.debug or debug
		ENV.coroutine = ENV.coroutine or coroutine

		local chunk, err = loadFn(src, "@Rayfield/source")
		if not chunk then return nil, "Rayfield compile: " .. tostring(err) end

		if setfenv then pcall(setfenv, chunk, ENV) end

		local ok, pkg = pcall(chunk)
		if not ok then
			local errMsg = tostring(pkg)
			if type(Core.logWarn) == "function" then Core.logWarn("Rayfield runtime error: " .. errMsg) end
			return nil, "Rayfield runtime: " .. errMsg
		end
		if type(pkg) ~= "table" or type(pkg.CreateWindow) ~= "function" then
			return nil, "Rayfield returned non-window: " .. type(pkg)
		end

		ENV._AlleralRayfield = pkg
		return pkg
	end

	local function createLibrary()
		local Library = {
			Version = Core.ALLERAL_UI_VERSION,
			ALLERAL_UI_VERSION = Core.ALLERAL_UI_VERSION,
			_pendingNotifies = {},
		}

		function Library:GetAlleralVersion() return Core.ALLERAL_UI_VERSION end
		function Library:GetArrrelVersion() return Core.ALLERAL_UI_VERSION end
		function Library:EnsureGuiRoot() return true end

		function Library:Notification(info)
			info = type(info) == "table" and info or { Description = tostring(info) }
			local rf = ENV._AlleralRayfield
			if rf and type(rf.Notify) == "function" then
				pcall(rf.Notify, rf, {
					Title = info.Title or "Alleral",
					Content = info.Description or info.Content or info.Text or "",
					Duration = info.Lifetime or info.Duration or info.Time or 4,
				})
			end
		end

		function Library:Notify(info) Library:Notification(info) end
		function Library:ClearNotifications() return 0 end
		function Library:SetNotificationLower() return true end
		function Library:SetNotifyDedupe() return true end
		function Library:SetHaptics() return true
		function Library:ApplyAccentPreset() return true
		function Library:SetTheme() return true
		function Library:CycleTheme() return { Name = "Default" } end
		function Library:ListThemeNames() return { "Default", "Ocean", "AmberGlow", "Light", "Amethyst", "Green", "Bloom", "DarkBlue", "Serenity" } end
		function Library:GetAutoResize() return true end
		function Library:GetUiScale() return tonumber(ENV.Alleral_UiScale) or 1 end
		function Library:SetAutoResize() return true end
		function Library:SetUiScale() return true end
		function Library:ListProfiles() return { "auto", "desktop", "mobile", "compact" } end
		function Library:ApplyProfile() return true end
		function Library:GetLayoutInfo() return { profile = "rayfield", engine = "Rayfield", version = Core.ALLERAL_UI_VERSION } end
		function Library:RepairWindow() return true end
		function Library:SetMotionProfile() return true end
		function Library:GetMotionProfile() return "fluid" end
		function Library:ListMotionProfiles() return { "fluid" } end
		function Library:GetGlassIntensity() return 0.55 end
		function Library:SetGlassIntensity() return true end
		function Library:GetTooltipStyle() return "rich" end
		function Library:SetTooltipStyle() return true end
		function Library:SetSpringMotion() return true end
		function Library:SetReducedMotion() return true end
		function Library:SetTouchFeedback() return true end
		function Library:SetStartupEffect() return true end
		function Library:SetNotificationAnimations() return true end
		function Library:SetNotificationStyle() return true end
		function Library:SetNotificationCompact() return true end
		function Library:GetNotificationStyle() return "glass" end
		function Library:GetSpringMotion() return true end
		function Library:RegisterLayoutRefresh() return true end

		function Library:CreateWindow(settings)
			settings = type(settings) == "table" and settings or {}
			local rf, err = bootRayfield()
			if not rf then
				Core.logWarn("Rayfield boot failed: " .. tostring(err))
				return nil
			end

			local folder = settings.Folder
				or (type(settings.FileSettings) == "table" and (settings.FileSettings.RootFolder or settings.FileSettings.ConfigFolder))
				or "Alleral_Configs"

			local ok, rfWindow = pcall(function()
				return rf:CreateWindow({
					Name = settings.Title or settings.Name or "Alleral",
					Subtitle = settings.Subtitle or settings.Author or "",
					LoadingTitle = "Alleral",
					LoadingSubtitle = "Loading...",
					ConfigurationSaving = {
						Enabled = true,
						FolderName = folder,
					},
					Discord = { Enabled = false },
					KeySystem = false,
				})
			end)

			if not ok or not rfWindow then
				Core.logWarn("Rayfield window creation failed: " .. tostring(rfWindow))
				return nil
			end

			local window = {
				_rfWindow = rfWindow,
				_library = Library,
				_initialized = false,
				_rfTabs = {},
				_alleralSettings = settings,
				Windows = {},
			}

			function window:AddTab(name, icon)
				local rfTab = rfWindow:CreateTab({ Name = name, Icon = icon or "" })
				table.insert(window._rfTabs, rfTab)
				return rfTab, window
			end

			function window:Notify(payload)
				payload = type(payload) == "table" and payload or {}
				if rf and type(rf.Notify) == "function" then
					rf:Notify({
						Title = payload.Title or "Alleral",
						Content = payload.Description or payload.Content or "",
						Duration = payload.Lifetime or payload.Duration or 4,
					})
				end
			end

			function window:SetState(state)
				if rfWindow.SetState then pcall(rfWindow.SetState, rfWindow, state) end
			end

			function window:GetState()
				return true
			end

			function window:Unload()
				if rfWindow.Destroy then pcall(rfWindow.Destroy, rfWindow) end
			end

			window._alleralTabGroup = window
			window._macTabGroup = window

			ENV.Alleral_UiWindow = window
			return window
		end

		return Library
	end

	function Core.loadUi()
		local cached = ENV.Alleral_UI
		if type(cached) == "table" and type(cached.Library) == "table" and type(cached.CreateWindow) == "function" then
			return cached
		end

		local Library = createLibrary()
		ENV._AlleralUiLibrary = Library

		local bundle = {
			Library = Library,
			Alleral = Library,
			CreateWindow = function(_, s) return Library:CreateWindow(s) end,
			Notify = function(_, i) Library:Notification(i) end,
		}

		ENV.Alleral_UI = bundle
		if getgenv then getgenv().Alleral_UI = bundle end

	if type(Core.say) == "function" then Core.say("Alleral UI " .. tostring(Library:GetAlleralVersion()) .. " (Rayfield native)") end
	return bundle
	end

	function Core.preloadUi()
		return Core.loadUi()
	end

	function Core.uiLibrary(bundle)
		if type(bundle) ~= "table" then return nil end
		return bundle.Alleral or bundle.Library
	end

	function Core.createWindUiGroupbox(section, _uiBundle)
		section = type(section) == "table" and section or {}
		local serial = 0

		local function nextFlag(name, explicit)
			serial = serial + 1
			return explicit or (Core.uiElementId and Core.uiElementId(name) or name) .. "_" .. serial
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
			if meta.bindKey and Core.bindUiState then
				Core.bindUiState(meta.bindKey, wrapper, meta.kind or "toggle", meta.raw)
			end
			return wrapper
		end

		local groupbox = {}

		function groupbox:CreateToggle(settings, id)
			local flag = nextFlag(settings.Name, id)
			local element = section.CreateToggle and section:CreateToggle({
				Name = settings.Name,
				CurrentValue = settings.CurrentValue == true,
				Callback = settings.Callback or function() end,
				Flag = flag,
			})
			return wrapElement(function(next)
				if element and element.Set and next.CurrentValue ~= nil then
					pcall(element.Set, element, next.CurrentValue == true)
				end
			end, { raw = element, bindKey = settings.BindKey or settings.StateKey, kind = "toggle" })
		end

		function groupbox:CreateSlider(settings, id)
			local range = settings.Range or { 0, 100 }
			local flag = nextFlag(settings.Name, id)
			local element = section.CreateSlider and section:CreateSlider({
				Name = settings.Name,
				Min = range[1], Max = range[2],
				Default = tonumber(settings.CurrentValue) or range[1],
				Increment = tonumber(settings.Increment) or 1,
				Callback = settings.Callback or function() end,
				Flag = flag,
			})
			return wrapElement(function(next)
				if element and element.Set and next.CurrentValue ~= nil then
					pcall(element.Set, element, tonumber(next.CurrentValue))
				end
			end, { raw = element, bindKey = settings.BindKey or settings.StateKey, kind = "slider" })
		end

		function groupbox:CreateButton(settings, id)
			local element = section.CreateButton and section:CreateButton({
				Name = settings.Name,
				Callback = settings.Callback or function() end,
			})
			return wrapElement(function() end, { raw = element, kind = "button" })
		end

		function groupbox:CreateInput(settings, id)
			local flag = nextFlag(settings.Name, id)
			local element = section.CreateInput and section:CreateInput({
				Name = settings.Name,
				PlaceholderText = settings.PlaceholderText or settings.Placeholder or "",
				CurrentValue = settings.CurrentValue or settings.Default or "",
				Callback = settings.Callback or function() end,
				Flag = flag,
			})
			return wrapElement(function(next)
				if element and element.Set and next.CurrentValue ~= nil then
					pcall(element.Set, element, tostring(next.CurrentValue))
				end
			end, { raw = element, bindKey = settings.BindKey or settings.StateKey, kind = "input" })
		end

		function groupbox:CreateDropdown(settings, id)
			local values = settings.Options or settings.Values or {}
			local multi = settings.MultipleOptions == true or settings.Multi == true
			local current = settings.CurrentOption or (multi and {} or (values[1] or ""))
			local flag = nextFlag(settings.Name, id)
			local element = section.CreateDropdown and section:CreateDropdown({
				Name = settings.Name,
				Options = values,
				CurrentOption = multi and (current[1] or values[1] or "") or (current or values[1] or ""),
				MultipleOptions = multi,
				Callback = function(selection)
					local cb = settings.Callback or function() end
					if multi then
						cb(Core.normalizeMultiSelection and Core.normalizeMultiSelection(selection) or selection)
					else
						cb(Core.normalizeDropdownValue and Core.normalizeDropdownValue(selection, values[1]) or selection)
					end
				end,
				Flag = flag,
			})
			return wrapElement(function(next)
				if not element then return end
				local nextValues = next.Options or next.Values
				local pick = next.CurrentOption or next.CurrentOptions
				if type(nextValues) == "table" and element.Set then
					pcall(element.Set, element, { Options = nextValues })
				end
				if pick ~= nil and element.Set then
					pcall(element.Set, element, { CurrentOption = multi and pick[1] or tostring(pick) })
				end
			end, { raw = element, bindKey = settings.BindKey or settings.StateKey, kind = "dropdown" })
		end

		function groupbox:CreateLabel(settings, id)
			local text = type(settings) == "table" and (settings.Name or settings.Text) or tostring(settings or "")
			local element = section.CreateLabel and section:CreateLabel(text)
			return {
				Set = function(_, nextSettings)
					local nextText = type(nextSettings) == "table" and (nextSettings.Name or nextSettings.Text) or tostring(nextSettings or "")
					if element and element.Set then pcall(element.Set, element, nextText) end
				end,
				SetVisible = function(_, visible)
					if element and element.SetVisible then pcall(element.SetVisible, element, visible == true) end
				end,
			}
		end

		function groupbox:CreateStatus(label, fields)
			local status = { Labels = {}, LastValues = {}, Visible = true }
			for key, value in pairs(fields or {}) do
				status.LastValues[key] = tostring(value)
				status.Labels[key] = groupbox:CreateLabel({ Name = tostring(key) .. ": " .. tostring(value) }, nextFlag(label .. "_" .. tostring(key)))
			end
			status.Labels.Summary = groupbox:CreateLabel({ Name = "" }, nextFlag(label .. "_summary"))
			function status:Update(key, value)
				local rendered = tostring(value)
				if self.LastValues[key] == rendered then return end
				self.LastValues[key] = rendered
				local row = self.Labels[key]
				if row and row.Set then row:Set({ Name = tostring(key) .. ": " .. rendered }) end
			end
			function status:SetSummary(text)
				local row = self.Labels.Summary
				if row and row.Set then row:Set({ Name = tostring(text or "") }) end
			end
			function status:SetVisible(visible) self.Visible = visible == true end
			return status
		end

		function groupbox:CreateDivider()
			if section.CreateDivider then pcall(section.CreateDivider, section) end
			return {}
		end

		return groupbox
	end

	Core.wrapUiGroup = function(groupbox, callbackWrapper)
		local wrap = function(label, callback)
			if type(callback) ~= "function" then return function() end end
			if not callbackWrapper then return callback end
			local guarded = function(...)
				local ok, result = pcall(callback, ...)
				if not ok and type(Core.pushErrorLog) == "function" then Core.pushErrorLog(label, result) end
				return result
			end
			return function(...)
				local ok, r1 = pcall(callbackWrapper, label, guarded, ...)
				if ok then return r1 end
				return callbackWrapper(guarded, ...)
			end
		end

		local group = {}
		function group:CreateToggle(name, default, tooltip, callback, bindKey)
			return groupbox:CreateToggle({
				Name = name, CurrentValue = default == true, Tooltip = tooltip,
				Callback = wrap(name, callback), BindKey = bindKey,
			}, bindKey)
		end
		function group:CreateSlider(name, min, max, default, callback, tooltip, increment, bindKey)
			return groupbox:CreateSlider({
				Name = name, Range = { min, max }, CurrentValue = default or min,
				Tooltip = tooltip, Increment = increment,
				Callback = wrap(name, callback), BindKey = bindKey,
			}, bindKey)
		end
		function group:CreateButton(name, callback, tooltip)
			return groupbox:CreateButton({ Name = name, Tooltip = tooltip, Callback = wrap(name, callback) })
		end
		function group:CreateInput(name, placeholder, arg3, arg4, arg5)
			local icon, default, callback, tooltip = nil, "", nil, nil
			if type(arg3) == "function" then callback, tooltip = arg3, arg4
			elseif type(arg4) == "function" then icon, callback, tooltip = arg3, arg4, arg5
			else
				if type(arg3) == "string" or type(arg3) == "number" then default = arg3 end
				if type(arg4) == "function" then callback = arg4 end
				tooltip = arg5
			end
			return groupbox:CreateInput({
				Name = name, Icon = icon, PlaceholderText = placeholder,
				CurrentValue = default, Tooltip = tooltip,
				Callback = wrap(name, callback),
			})
		end
		function group:CreateDropdown(name, options, default, callback, tooltip, bindKey)
			return groupbox:CreateDropdown({
				Name = name, Options = options, CurrentOption = default,
				Tooltip = tooltip, Callback = wrap(name, callback), BindKey = bindKey,
			}, bindKey)
		end
		function group:AddDropdown(id, config)
			config = type(config) == "table" and config or {}
			return groupbox:CreateDropdown({
				Name = config.Text or config.Name or id,
				Options = config.Values or config.Options or {},
				CurrentOption = config.Default or config.CurrentValue or config.CurrentOption,
				MultipleOptions = config.Multi or config.MultiSelection,
				Callback = config.Callback or function() end,
			}, id)
		end
		function group:CreateLabel(text)
			return groupbox:CreateLabel({ Name = text })
		end
		function group:CreateStatus(label, fields)
			return groupbox:CreateStatus(label, fields or {})
		end
		function group:CreateDivider()
			return groupbox:CreateDivider()
		end
		return group
	end

	function Core.wrapUiTab(rawTab, uiBundle, window)
		local tab = {
			_rawTab = rawTab,
			_ui = uiBundle,
			_window = window,
			_columnCount = 2,
			_sectionIndex = 0,
		}
		if type(Core._UiTabRegistry) == "table" then
			table.insert(Core._UiTabRegistry, tab)
		end

		function tab:CreateGroupbox(settings)
			settings = settings or {}
			local name = settings.Name or "Group"
			if not rawTab then
			return type(Core.createStubUiGroup) == "function" and Core.createStubUiGroup(name) or {}
			end
			tab._sectionIndex = (tab._sectionIndex or 0) + 1
			if rawTab.CreateSection then
				pcall(rawTab.CreateSection, rawTab, name)
			end
			return Core.createWindUiGroupbox(rawTab, uiBundle)
		end

		function tab:Select()
			if rawTab and rawTab.Select then pcall(rawTab.Select, rawTab) end
		end

		function tab:BuildThemeGroupbox(column)
			local group = Core.buildUiGroup(tab, "Appearance", column or 1)
			group:CreateLabel("Rayfield native UI engine with Lucide icons and config saving.")
			return group
		end

		return tab
	end

	function Core.buildUiWindow(ui, settings)
		settings = settings or {}
		local lib = ui and ui.Library
		if not lib or type(lib.CreateWindow) ~= "function" then return nil end
		if not settings.Size then settings.Size = UDim2.fromOffset(920, 680) end
		local rawWindow = lib:CreateWindow(settings)
		if not rawWindow then
			Core.logWarn("Rayfield window creation failed")
			return nil
		end
		local window = {
			_rawWindow = rawWindow,
			_ui = ui,
			_library = lib,
			_initialized = false,
			_tabGroup = rawWindow,
			_alleralSettings = settings,
		}
		if type(Core.registerUiWindow) == "function" then Core.registerUiWindow(window) end
		if type(Core.flushPendingNotifications) == "function" then Core.flushPendingNotifications() end
		return window
	end

	function Core.buildUiTab(section, name, icon, columns, id)
		local resolve = Core.resolveUiWindow
		local window = type(resolve) == "function" and resolve(section) or nil
		if type(window) ~= "table" or not window._rawWindow then
			Core.logWarn("buildUiTab skipped -- window missing")
			return Core.wrapUiTab(nil, type(section) == "table" and section._ui or nil, window)
		end
		local tabGroup = window._tabGroup or window
		if not tabGroup or type(tabGroup.AddTab) ~= "function" then
			Core.logWarn("buildUiTab skipped -- tab group missing")
			return Core.wrapUiTab(nil, window._ui, window)
		end
		local rawTab, _ = tabGroup:AddTab(name, iconAsset(icon))
		local wrapped = Core.wrapUiTab(rawTab, window._ui or (type(section) == "table" and section._ui) or nil, window)
		wrapped._columnCount = math.max(1, tonumber(columns) or 2)
		if not window._defaultTab then window._defaultTab = rawTab end
		return wrapped
	end

	function Core.buildUiGroup(tab, name, column, callbackWrapper, icon, id)
		name = tostring(name or "Group")
		if type(tab) ~= "table" or type(tab.CreateGroupbox) ~= "function" then
			return Core.createStubUiGroup and Core.createStubUiGroup(name) or {}
		end
		local groupbox = tab:CreateGroupbox({ Name = name, Column = column or 1, Icon = icon })
		return Core.wrapUiGroup(groupbox, callbackWrapper)
	end

	function Core.finalizeGameUi(window, ui, options)
		options = type(options) == "table" and options or {}
		if type(window) == "table" and window._rawWindow and not window._initialized then
			window._initialized = true
			task.defer(function()
				pcall(function()
					local rawWindow = window._rawWindow
					if rawWindow and rawWindow.SetState then rawWindow:SetState(true) end
					local defaultTab = window._defaultTab
					if defaultTab and defaultTab.Select then defaultTab:Select() end
				end)
			end)
		end
		if type(Core.setupHubKeybinds) == "function" then
			pcall(Core.setupHubKeybinds, { window = window, ui = ui or window._ui or ENV.Alleral_UI, uiKey = ENV.Alleral_UiKeybind })
		end
		if options.notify ~= false then
			Core.notifyBootReady({ Name = options.Name or "Alleral", Subtitle = options.Subtitle })
		end
		return window
	end

	function Core.repairUiWindow(window)
		window = window or ENV.Alleral_UiWindow
		if type(window) ~= "table" or not window._rawWindow then return false end
		local rawWindow = window._rawWindow
		if rawWindow.SetState then pcall(rawWindow.SetState, rawWindow, true) end
		return true
	end

	function Core.refreshAllTabColumns()
		return true
	end

	Core.notifyWindUi = function(info)
		local ui = ENV.Alleral_UI
		if ui and type(ui.Notify) == "function" then pcall(ui.Notify, ui, info) end
	end

	Core.releaseAlleralRuntime = function()
		ENV._AlleralUiLibrary = nil
		ENV._AlleralRayfield = nil
		ENV._AlleralRayfieldBundle = nil
	end
end
