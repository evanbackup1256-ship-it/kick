return function(Core)
	local ALLERAL_UI_LAYER = "Alleral UI layer"
	Core._AlleralUiLayer = ALLERAL_UI_LAYER
	Core.ALLERAL_UI_VERSION = Core.ALLERAL_UI_VERSION or "5.3.0-maclib"
	Core.WINDUI_VERSION = Core.ALLERAL_UI_VERSION
	Core.UI_LIBRARY = "Maclib"

	local MACLIB_SOURCE_PATH = "ui/maclib/source.luau"
	local MACLIB_SOURCE_PATHS = {
		"ui/maclib/source.luau",
		".alleral/cache/ui/maclib/source.luau",
		"kick/ui/maclib/source.luau",
	}
	local MACLIB_VERSION_MARKER = "ALLERAL_MACLIB_VERSION"
	local MACLIB_VERSION = 1
	local MACLIB_REQUIRED_FN = "function MacLib:Window"
	local MACLIB_MIN_BYTES = 150000
	local MACLIB_WORKSPACE_ROOTS = { "", "kick/", "workspace/", "scripts/" }
	local MACLIB_RAW_URLS = {
		"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/ui/maclib/source.luau",
	}
	local DEFAULT_ICON_ID = "18821914323"

	local function genv()
		local ok, env = pcall(function()
			return getgenv and getgenv() or getfenv()
		end)
		return ok and env or {}
	end
	local ENV = genv()

	local function extractIconId(icon)
		if icon == nil or icon == "" then
			return nil
		end
		if type(icon) == "number" then
			return tostring(icon)
		end
		local text = tostring(icon)
		local digits = text:match("(%d+)$")
		if digits then
			return digits
		end
		if type(Core.uiIcon) == "function" then
			local numeric = Core.uiIcon(icon)
			if type(numeric) == "string" and numeric ~= "" then
				return numeric
			end
		end
		if type(Core.windUiIcon) == "function" then
			local mapped = Core.windUiIcon(icon)
			if type(mapped) == "string" then
				local fromMapped = mapped:match("(%d+)$")
				if fromMapped then
					return fromMapped
				end
			end
		end
		return nil
	end

	local function iconImage(icon)
		return extractIconId(icon) or DEFAULT_ICON_ID
	end

	local function iconAsset(icon)
		return "rbxassetid://" .. iconImage(icon)
	end

	local function requiredMaclibVersion()
		local expected = ENV._Alleral_ExpectedVersions
		if type(expected) == "table" then
			local version = tonumber(expected.maclibVersion)
			if version then
				return version
			end
		end
		return MACLIB_VERSION
	end

	local function maclibVersionFromSource(src)
		if type(src) ~= "string" then
			return nil
		end
		return tonumber(src:match("ALLERAL_MACLIB_VERSION%s*=%s*(%d+)"))
	end

	local function maclibSourceValid(src)
		if type(src) ~= "string"
			or #src < MACLIB_MIN_BYTES
			or src:find("<!DOCTYPE", 1, true)
			or not src:find(MACLIB_VERSION_MARKER, 1, true)
			or not src:find(MACLIB_REQUIRED_FN, 1, true)
			or not src:find("function MacLib:Window", 1, true) then
			return false
		end
		local version = maclibVersionFromSource(src)
		return type(version) == "number" and version == requiredMaclibVersion()
	end

	local function maclibIoFn(name)
		if type(Core.execFunction) == "function" then
			return Core.execFunction(name)
		end
		return nil
	end

	local function readMaclibFileAt(path)
		local readFile = maclibIoFn("readfile")
		local isFile = maclibIoFn("isfile")
		if type(readFile) ~= "function" or type(isFile) ~= "function" then
			return Core.readFile and Core.readFile(path)
		end
		local okExists, exists = pcall(isFile, path)
		if not (okExists and exists) then
			return nil
		end
		local okRead, src = pcall(readFile, path)
		return okRead and src or nil
	end

	local function tryReadMaclibPath(relPath)
		for _, root in ipairs(MACLIB_WORKSPACE_ROOTS) do
			local full = root .. relPath
			local src = readMaclibFileAt(full)
			if maclibSourceValid(src) then
				return src, "local:" .. full
			end
		end
		return nil
	end

	local function maclibRawUrls()
		local urls = {}
		local seen = {}
		local function add(url)
			if type(url) == "string" and url ~= "" and not seen[url] then
				seen[url] = true
				table.insert(urls, url)
			end
		end
		for _, url in ipairs(MACLIB_RAW_URLS) do
			add(url)
		end
		local bases = (type(Core._UiRemoteBases) == "table" and Core._UiRemoteBases)
			or (type(ENV.Alleral_Core) == "table" and ENV.Alleral_Core._UiRemoteBases)
		if type(bases) == "table" then
			for _, base in ipairs(bases) do
				add(tostring(base) .. "/ui/maclib/source.luau")
			end
		end
		return urls
	end

	local function readMaclibSource()
		local bestSrc, bestLabel, bestVersion = nil, nil, -1
		local function consider(src, label)
			if not maclibSourceValid(src) then
				return
			end
			local version = maclibVersionFromSource(src) or 0
			if version > bestVersion then
				bestSrc, bestLabel, bestVersion = src, label, version
			end
		end

		if type(ENV._AlleralMaclibSource) == "string" then
			consider(ENV._AlleralMaclibSource, ENV._AlleralMaclibSourceLabel or "memory:loader")
		end

		for _, path in ipairs(MACLIB_SOURCE_PATHS) do
			local src, label = tryReadMaclibPath(path)
			if src then
				consider(src, label)
			end
		end

		if type(ENV.Alleral_HTTP) == "table" and type(ENV.Alleral_HTTP.get) == "function" then
			for _, baseUrl in ipairs(maclibRawUrls()) do
				local src = ENV.Alleral_HTTP.get(baseUrl .. "?t=" .. tostring(tick()), MACLIB_MIN_BYTES)
				if type(src) == "string" then
					consider(src, "remote:" .. baseUrl)
				end
			end
		end

		if not bestSrc or bestVersion ~= requiredMaclibVersion() then
			return nil, "MacLib source missing (need v" .. tostring(requiredMaclibVersion()) .. ")"
		end
		return bestSrc, bestLabel
	end

	local function loadMaclib()
		if type(ENV._AlleralMaclib) == "table" then
			local version = ENV._AlleralMaclib.__AlleralPatch
			local need = requiredMaclibVersion()
			if type(version) ~= "number" or version ~= need then
				ENV._AlleralMaclib = nil
				ENV._AlleralMaclibSourceKey = nil
			else
				return ENV._AlleralMaclib
			end
		end

		local source, sourceLabel = readMaclibSource()
		if not source then
			return nil, sourceLabel or "MacLib source missing"
		end

		local sourceKey = tostring(#source) .. ":" .. source:sub(1, 64)
		if ENV._AlleralMaclibSourceKey == sourceKey and type(ENV._AlleralMaclib) == "table" then
			return ENV._AlleralMaclib
		end

		local loadFn = Core.execFunction and Core.execFunction("loadstring") or loadstring or load
		if type(loadFn) ~= "function" then
			return nil, "loadstring unavailable"
		end

		local chunk, err = loadFn(source, "@MacLib/source")
		if not chunk then
			return nil, tostring(err or "MacLib compile failed")
		end

		local ok, MacLib = pcall(chunk)
		if not ok or type(MacLib) ~= "table" or type(MacLib.Window) ~= "function" then
			return nil, tostring(MacLib or "MacLib runtime failed")
		end

		if type(MacLib.__AlleralPatch) ~= "number" or MacLib.__AlleralPatch ~= requiredMaclibVersion() then
			return nil, "MacLib version outdated (need v" .. tostring(requiredMaclibVersion()) .. ")"
		end

		ENV._AlleralMaclibSourceKey = sourceKey
		ENV._AlleralMaclib = MacLib
		ENV._AlleralMaclibSource = source
		ENV._AlleralMaclibSourceLabel = sourceLabel
		if type(Core.say) == "function" then
			Core.say("MacLib v" .. tostring(MacLib.__AlleralVersion or "1.2.6") .. " from " .. tostring(sourceLabel or "unknown"))
		end
		return MacLib
	end

	local function wrapLibrary(MacLib)
		local activeWindow = nil
		local notificationsEnabled = true

		local Library = {
			Maclib = MacLib,
			Window = nil,
			Version = Core.ALLERAL_UI_VERSION,
			ALLERAL_UI_VERSION = Core.ALLERAL_UI_VERSION,
			_pendingNotifies = {},
			CommandPalette = {
				register = function() end,
				toggle = function() end,
			},
		}

		local function flushPendingNotifies()
			while #Library._pendingNotifies > 0 do
				local payload = table.remove(Library._pendingNotifies, 1)
				if activeWindow and type(activeWindow.Notify) == "function" then
					pcall(activeWindow.Notify, activeWindow, payload)
				end
			end
		end

		local function pushNotification(info)
			info = type(info) == "table" and info or { Description = tostring(info) }
			local payload = {
				Title = info.Title or "Alleral",
				Description = info.Description or info.Content or info.Text or "",
				Lifetime = info.Lifetime or info.Duration or info.Time or 4,
			}
			if not notificationsEnabled then
				return
			end
			if activeWindow and type(activeWindow.Notify) == "function" then
				pcall(activeWindow.Notify, activeWindow, payload)
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
			Library._pendingNotifies = {}
			return 0
		end

		function Library:SetNotificationLower(_enabled)
			return true
		end

		function Library:RepairWindow(window)
			window = window or activeWindow or Library.Window
			if window and type(window.SetState) == "function" then
				pcall(window.SetState, window, true)
			end
			return true
		end

		function Library:ListThemeNames()
			return { "Maclib", "Default" }
		end

		function Library:SetTheme(_name)
			return true
		end

		function Library:CycleTheme(_step)
			return { Name = "Maclib" }
		end

		function Library:ListMotionProfiles()
			return { "fluid" }
		end

		function Library:GetMotionProfile()
			return "fluid"
		end

		function Library:SetMotionProfile(_name)
			return true
		end

		function Library:SetSpringMotion(_enabled)
			return true
		end

		function Library:SetReducedMotion(_enabled)
			return true
		end

		function Library:GetSpringMotion()
			return true
		end

		function Library:ListProfiles()
			return { "auto" }
		end

		function Library:ApplyProfile(_name)
			return true
		end

		function Library:GetGlassIntensity()
			return 0.55
		end

		function Library:SetGlassIntensity(_value)
			return true
		end

		function Library:SetChromeDepth(_value)
			return true
		end

		function Library:GetTooltipStyle()
			return "rich"
		end

		function Library:SetTooltipStyle(_style)
			return true
		end

		function Library:GetNotificationStyle()
			return "glass"
		end

		function Library:SetNotificationStyle(_style)
			return true
		end

		function Library:SetAmbientGlow(_enabled)
			return true
		end

		function Library:SetTabAurora(_enabled)
			return true
		end

		function Library:SetSectionLift(_enabled)
			return true
		end

		function Library:ApplyAccentPreset(_name)
			return true
		end

		function Library:FlashAccent()
			return true
		end

		function Library:CreateWindow(settings)
			settings = type(settings) == "table" and settings or {}
			local menuKey = settings.Keybind or ENV.Alleral_UiKeybind or Enum.KeyCode.RightControl
			ENV.Alleral_UiKeybind = menuKey

			local folder = settings.Folder
			if not folder and type(settings.FileSettings) == "table" then
				folder = settings.FileSettings.RootFolder or settings.FileSettings.ConfigFolder
			end
			if type(folder) == "string" and folder ~= "" then
				pcall(MacLib.SetFolder, MacLib, folder)
			else
				pcall(MacLib.SetFolder, MacLib, "Alleral_Configs")
			end

			local macWindow = MacLib:Window({
				Title = settings.Title or settings.Name or "Alleral",
				Subtitle = settings.Subtitle or settings.SubName or settings.Author or "",
				Size = settings.Size or UDim2.fromOffset(868, 650),
				Keybind = menuKey,
				AcrylicBlur = true,
				ShowUserInfo = true,
			})

			if not macWindow then
				return nil
			end

			local tabGroup = macWindow:TabGroup()
			macWindow._macTabGroup = tabGroup
			macWindow._alleralTabGroup = tabGroup

			activeWindow = macWindow
			Library.Window = macWindow
			flushPendingNotifies()
			return macWindow
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
			Core.logWarn("Alleral UI load failed: " .. tostring(err or "MacLib missing"))
			return nil, err or "MacLib missing"
		end

		local Library = wrapLibrary(MacLib)
		ENV._AlleralUiLibrary = Library
		Core.clearUiStateBindings()

		local bundle = {
			Library = Library,
			Alleral = Library,
			Maclib = MacLib,
			CreateWindow = function(_, settings)
				return Library:CreateWindow(settings)
			end,
			Notify = function(_, info)
				Library:Notification(info)
			end,
		}
		Core.say("Alleral UI " .. tostring(Library:GetAlleralVersion()) .. " (MacLib)")
		return cacheUi(bundle)
	end

	function Core.preloadUi()
		return Core.loadUi()
	end

	Core.releaseAlleralRuntime = function()
		ENV._AlleralUiLibrary = nil
		ENV._AlleralMaclib = nil
		ENV._AlleralMaclibSourceKey = nil
	end

	function Core.uiLibrary(bundle)
		if type(bundle) ~= "table" then
			return nil
		end
		return bundle.Alleral or bundle.Library or bundle.Maclib
	end

	function Core.createWindUiGroupbox(section, _uiBundle)
		section = section or {}
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
			local flag = nextFlag(settings.Name, id)
			local handle = section:Toggle({
				Name = settings.Name,
				Default = settings.CurrentValue == true,
				Callback = settings.Callback or function() end,
			}, flag)
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue == nil or not handle then
					return
				end
				if type(handle.UpdateState) == "function" then
					pcall(handle.UpdateState, handle, nextSettings.CurrentValue == true)
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
			local flag = nextFlag(settings.Name, id)
			local handle = section:Slider({
				Name = settings.Name,
				Default = tonumber(settings.CurrentValue) or minValue,
				Minimum = minValue,
				Maximum = maxValue,
				Precision = tonumber(settings.Increment) or Core.sliderIncrement(minValue, maxValue, settings.Increment),
				Callback = settings.Callback or function() end,
			}, flag)
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue == nil or not handle then
					return
				end
				if type(handle.UpdateValue) == "function" then
					pcall(handle.UpdateValue, handle, tonumber(nextSettings.CurrentValue))
				end
			end, {
				raw = handle,
				bindKey = settings.BindKey or settings.StateKey,
				kind = "slider",
			})
		end

		function groupbox:CreateButton(settings, id)
			local userCallback = settings.Callback or function() end
			local handle = section:Button({
				Name = settings.Name,
				Callback = function()
					userCallback()
				end,
			})
			return wrapElement(function(nextSettings)
				if type(nextSettings) == "table" and nextSettings.Callback then
					userCallback = nextSettings.Callback
				end
			end, {
				raw = handle,
				kind = "button",
			})
		end

		function groupbox:CreateInput(settings, id)
			local flag = nextFlag(settings.Name, id)
			local handle = section:Input({
				Name = settings.Name,
				Placeholder = settings.PlaceholderText or settings.Placeholder or "",
				Callback = settings.Callback or function() end,
				onChanged = settings.onChanged,
			}, flag)
			if settings.CurrentValue and type(handle.UpdateText) == "function" then
				pcall(handle.UpdateText, handle, tostring(settings.CurrentValue))
			end
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue == nil or not handle then
					return
				end
				if type(handle.UpdateText) == "function" then
					pcall(handle.UpdateText, handle, tostring(nextSettings.CurrentValue))
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
			local flag = nextFlag(settings.Name, id)
			local default = current
			if multi and type(current) == "table" then
				default = current
			elseif type(current) == "string" then
				default = current
			else
				default = 1
			end
			local handle = section:Dropdown({
				Name = settings.Name,
				Options = values,
				Multi = multi,
				Default = default,
				Callback = function(selection)
					local userCallback = settings.Callback or function() end
					if multi then
						userCallback(Core.normalizeMultiSelection(selection))
					else
						userCallback(Core.normalizeDropdownValue(selection, values[1]))
					end
				end,
			}, flag)
			return wrapElement(function(nextSettings)
				if not handle then
					return
				end
				local nextValues = nextSettings.Options or nextSettings.Values
				local pick = nextSettings.CurrentOption or nextSettings.CurrentOptions
				if type(nextValues) == "table" and type(handle.InsertOptions) == "function" then
					pcall(handle.ClearOptions, handle)
					pcall(handle.InsertOptions, handle, nextValues)
				end
				if pick ~= nil and type(handle.UpdateSelection) == "function" then
					pcall(handle.UpdateSelection, handle, pick)
				end
			end, {
				raw = handle,
				bindKey = settings.BindKey or settings.StateKey,
				kind = "dropdown",
			})
		end

		function groupbox:CreateLabel(settings, id)
			local text = type(settings) == "table" and (settings.Name or settings.Text) or tostring(settings or "")
			local handle = section:Label({ Text = text })
			return {
				Set = function(_, nextSettings)
					local nextText = type(nextSettings) == "table" and (nextSettings.Name or nextSettings.Text)
						or tostring(nextSettings or "")
					if handle and type(handle.UpdateName) == "function" then
						pcall(handle.UpdateName, handle, nextText)
					end
				end,
				SetVisible = function(_, visible)
					if handle and type(handle.SetVisibility) == "function" then
						pcall(handle.SetVisibility, handle, visible == true)
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
			function status:SetVisible(_visible)
				self.Visible = _visible == true
			end
			return status
		end

		function groupbox:CreateDivider()
			if type(section.Divider) == "function" then
				pcall(section.Divider, section)
			end
			return {}
		end

		return groupbox
	end

	function Core.wrapUiTab(rawTab, uiBundle, window)
		local tab = {
			_rawTab = rawTab,
			_macTab = rawTab,
			_ui = uiBundle,
			_window = window,
			_columnCount = 2,
		}
		table.insert(Core._UiTabRegistry, tab)

		function tab:CreateGroupbox(settings)
			settings = settings or {}
			local name = settings.Name or "Group"
			if not rawTab or type(rawTab.Section) ~= "function" then
				Core.logWarn("CreateGroupbox skipped — tab missing for " .. tostring(name))
				return Core.createStubUiGroup(name)
			end
			local side = (tonumber(settings.Column) or 1) == 2 and "Right" or "Left"
			local section = rawTab:Section({ Side = side })
			if name ~= "" and type(section.Header) == "function" then
				pcall(section.Header, section, { Name = name })
			end
			return Core.createWindUiGroupbox(section, uiBundle)
		end

		function tab:BuildThemeGroupbox(column)
			local group = Core.buildUiGroup(tab, "Appearance", column or 1)
			group:CreateLabel("MacLib is the active UI layer.")
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
		if not settings.Size then
			settings.Size = UDim2.fromOffset(868, 650)
		end
		local rawWindow = lib:CreateWindow(settings)
		if not rawWindow then
			Core.logWarn("MacLib window create failed")
			return nil
		end
		local window = {
			_rawWindow = rawWindow,
			_ui = ui,
			_library = lib,
			_initialized = false,
			_tabGroup = rawWindow._macTabGroup or rawWindow._alleralTabGroup,
			_alleralSettings = settings,
		}
		Core.registerUiWindow(window)
		Core.flushPendingNotifications()
		return window
	end

	function Core.buildUiTab(section, name, icon, columns, id)
		local resolve = Core.resolveUiWindow
		local window = type(resolve) == "function" and resolve(section) or nil
		if type(window) ~= "table" or not window._rawWindow then
			Core.logWarn("buildUiTab skipped — window missing")
			return Core.wrapUiTab(nil, type(section) == "table" and section._ui or nil, window)
		end
		local tabGroup = window._tabGroup
		if not tabGroup or type(tabGroup.Tab) ~= "function" then
			Core.logWarn("buildUiTab skipped — tab group missing")
			return Core.wrapUiTab(nil, window._ui, window)
		end
		local rawTab = tabGroup:Tab({
			Name = name,
			Image = iconAsset(icon),
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
					local rawWindow = window._rawWindow
					if rawWindow and type(rawWindow.SetState) == "function" then
						rawWindow:SetState(true)
					end
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
				uiKey = ENV.Alleral_UiKeybind,
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

	function Core.repairUiWindow(window)
		window = window or ENV.Alleral_UiWindow
		if type(window) ~= "table" or not window._rawWindow then
			return false
		end
		local rawWindow = window._rawWindow
		if type(rawWindow.SetState) == "function" then
			pcall(rawWindow.SetState, rawWindow, true)
		end
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
