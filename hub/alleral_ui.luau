return function(Core)
	local ALLERAL_UI_LAYER = "Alleral UI layer"
	Core._AlleralUiLayer = ALLERAL_UI_LAYER
	Core.ALLERAL_UI_VERSION = Core.ALLERAL_UI_VERSION or "4.0.0-syde"
	Core.WINDUI_VERSION = Core.ALLERAL_UI_VERSION
	Core.UI_LIBRARY = "Syde"

	local SYDE_SOURCE_PATH = "ui/syde/source.luau"
	local SYDE_SOURCE_PATHS = {
		"ui/syde/source.luau",
		".alleral/cache/ui/syde/source.luau",
		"kick/ui/syde/source.luau",
		"kick/kick/ui/syde/source.luau",
	}
	local SYDE_PATCH_MARKER = "ALLERAL_SYDE_PATCH"
	local SYDE_PATCH_VERSION = 3
	local SYDE_WORKSPACE_ROOTS = { "", "kick/", "kick/kick/", "workspace/", "scripts/" }
	local SYDE_RAW_URLS = {
		"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/ui/syde/source.luau",
	}

	local THEME_ACCENTS = {
		Maclib = Color3.fromRGB(83, 252, 18),
		Private = Color3.fromRGB(83, 252, 18),
		Default = Color3.fromRGB(255, 151, 227),
		Dark = Color3.fromRGB(120, 120, 255),
		Light = Color3.fromRGB(0, 122, 255),
		Linoria = Color3.fromRGB(170, 85, 235),
		Obsidian = Color3.fromRGB(255, 120, 80),
	}

	local function genv()
		local ok, env = pcall(function()
			return getgenv and getgenv() or getfenv()
		end)
		return ok and env or {}
	end
	local ENV = genv()

	local DEFAULT_ICON_ID = "18821914323"

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

	local function optionalIconImage(icon)
		if icon == nil or icon == "" then
			return nil
		end
		return iconImage(icon)
	end

	local function sydeSourceValid(src)
		return type(src) == "string"
			and #src >= 5000
			and not src:find("<!DOCTYPE", 1, true)
			and src:find("sydeFindChild", 1, true)
			and src:find(SYDE_PATCH_MARKER, 1, true)
	end

	local function sydeIoFn(name)
		if type(Core.execFunction) == "function" then
			return Core.execFunction(name)
		end
		return nil
	end

	local function purgeInvalidSydeFile(path)
		local isFile = sydeIoFn("isfile")
		local readFile = sydeIoFn("readfile")
		local deleteFile = sydeIoFn("delfile") or sydeIoFn("deletefile")
		if type(isFile) ~= "function" or type(readFile) ~= "function" or type(deleteFile) ~= "function" then
			return
		end
		local okExists, exists = pcall(isFile, path)
		if not (okExists and exists) then
			return
		end
		local okRead, src = pcall(readFile, path)
		if okRead and sydeSourceValid(src) then
			return
		end
		pcall(deleteFile, path)
	end

	local function readSydeFileAt(path)
		local readFile = sydeIoFn("readfile")
		local isFile = sydeIoFn("isfile")
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

	local function tryReadSydePath(relPath)
		for _, root in ipairs(SYDE_WORKSPACE_ROOTS) do
			local full = root .. relPath
			local src = readSydeFileAt(full)
			if sydeSourceValid(src) then
				return src, "local:" .. full
			end
		end
		return nil
	end

	local function sydeRawUrls()
		local urls = {}
		local seen = {}
		local function add(url)
			if type(url) == "string" and url ~= "" and not seen[url] then
				seen[url] = true
				table.insert(urls, url)
			end
		end
		for _, url in ipairs(SYDE_RAW_URLS) do
			add(url)
		end
		local bases = (type(Core._UiRemoteBases) == "table" and Core._UiRemoteBases)
			or (type(ENV.Alleral_Core) == "table" and ENV.Alleral_Core._UiRemoteBases)
		if type(bases) == "table" then
			for _, base in ipairs(bases) do
				add(tostring(base) .. "/ui/syde/source.luau")
			end
		end
		return urls
	end

	local function readSydeSource()
		for _, path in ipairs(SYDE_SOURCE_PATHS) do
			purgeInvalidSydeFile(path)
			local src, label = tryReadSydePath(path)
			if src then
				return src, label
			end
		end

		for _, baseUrl in ipairs(sydeRawUrls()) do
			local url = baseUrl .. "?t=" .. tostring(tick())
			local src
			if type(Core.httpGet) == "function" then
				src = Core.httpGet(url)
			end
			if not sydeSourceValid(src) then
				local http = ENV.Alleral_HTTP
				if type(http) == "table" and type(http.get) == "function" then
					src = http.get(url, 8000)
				end
			end
			if sydeSourceValid(src) then
				if type(Core.writeFile) == "function" then
					pcall(Core.writeFile, SYDE_SOURCE_PATH, src)
					pcall(Core.writeFile, ".alleral/cache/" .. SYDE_SOURCE_PATH, src)
				end
				return src, "remote:" .. baseUrl
			end
		end

		return nil, nil
	end

	local function loadSyde()
		if type(ENV._AlleralSyde) == "table" then
			local patch = ENV._AlleralSyde.__AlleralPatch
			if type(patch) ~= "number" or patch < SYDE_PATCH_VERSION then
				ENV._AlleralSyde = nil
				ENV._AlleralSydeSourceKey = nil
			end
		end

		local source, sourceLabel = readSydeSource()
		if not source then
			return nil, "Syde source missing (need patched ui/syde/source.luau v" .. tostring(SYDE_PATCH_VERSION) .. "+)"
		end
		local sourceKey = tostring(#source) .. ":" .. tostring(sourceLabel or "unknown")
		if ENV._AlleralSydeSourceKey == sourceKey and type(ENV._AlleralSyde) == "table" and type(ENV._AlleralSyde.Init) == "function" then
			local patch = ENV._AlleralSyde.__AlleralPatch
			if type(patch) == "number" and patch >= SYDE_PATCH_VERSION then
				return ENV._AlleralSyde
			end
		end
		ENV._AlleralSyde = nil
		local loadFn = Core.loadStringFn()
		if not loadFn then
			return nil, "load unavailable"
		end
		local chunk, err = loadFn(source, "@Syde/source")
		if not chunk then
			return nil, tostring(err or "Syde compile failed")
		end
		local ok, Syde = pcall(chunk)
		if not ok or type(Syde) ~= "table" or type(Syde.Init) ~= "function" then
			return nil, tostring(Syde or "Syde runtime failed")
		end
		if type(Syde.__AlleralPatch) ~= "number" or Syde.__AlleralPatch < SYDE_PATCH_VERSION then
			ENV._AlleralSyde = nil
			ENV._AlleralSydeSourceKey = nil
			return nil, "Syde patch outdated (need v" .. tostring(SYDE_PATCH_VERSION) .. "+)"
		end
		ENV._AlleralSydeSourceKey = sourceKey
		ENV._AlleralSyde = Syde
		if type(Core.say) == "function" then
			Core.say("Syde patch v" .. tostring(Syde.__AlleralPatch) .. " from " .. tostring(sourceLabel or "unknown"))
		end
		return Syde
	end

	local function applyAccent(Syde, themeName)
		local accent = THEME_ACCENTS[themeName] or THEME_ACCENTS.Default
		if type(Syde.UpdateTheme) == "function" then
			pcall(Syde.UpdateTheme, Syde, {
				Accent = accent,
				HitBox = accent,
			})
		end
		return accent
	end

	local function wrapLibrary(Syde)
		local themes = { "Default", "Maclib", "Private", "Dark", "Light", "Linoria", "Obsidian" }
		local activeTheme = "Default"
		local activeWindow = nil
		local notificationsEnabled = true

		local Library = {
			Syde = Syde,
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
				pcall(function()
					Syde:Notify({
						Title = payload.Title or "Alleral",
						Content = payload.Description or "",
						Duration = payload.Lifetime or 4,
					})
				end)
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
			if activeWindow then
				pcall(function()
					Syde:Notify({
						Title = payload.Title,
						Content = payload.Description,
						Duration = payload.Lifetime,
					})
				end)
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
			ENV.Alleral_ActiveTheme = activeTheme
			applyAccent(Syde, activeTheme)
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
			return { "fluid", "reduced" }
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
			return { "auto", "desktop" }
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

		function Library:ApplyAccentPreset(name)
			Library:SetTheme(name or activeTheme)
		end

		function Library:FlashAccent()
			return true
		end

		function Library:CreateWindow(settings)
			settings = type(settings) == "table" and settings or {}
			local menuKey = settings.Keybind or ENV.Alleral_UiKeybind or Enum.KeyCode.RightControl
			ENV.Alleral_UiKeybind = menuKey

			local themeName = settings.Theme or activeTheme
			activeTheme = themeName
			applyAccent(Syde, themeName)

			local sydeWindow = Syde:Init({
				Title = settings.Title or settings.Name or "Alleral",
				SubText = settings.Subtitle or settings.SubName or "",
				Home = { Enabled = false },
				Keybind = menuKey,
			})

			if not sydeWindow then
				return nil
			end

			sydeWindow._sydeTabGroup = {
				Tab = function(_, opts)
					opts = type(opts) == "table" and opts or { Name = tostring(opts or "Tab") }
					return sydeWindow:InitTab({
						Title = opts.Name or "Tab",
						Icon = opts.Image and iconImage(opts.Image) or nil,
					})
				end,
			}

			activeWindow = sydeWindow
			Library.Window = sydeWindow
			flushPendingNotifies()
			return sydeWindow
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

		local Syde, err = loadSyde()
		if not Syde then
			Core.logWarn("Alleral UI load failed: " .. tostring(err or "Syde missing"))
			return nil, err or "Syde missing"
		end

		local Library = wrapLibrary(Syde)
		ENV._AlleralUiLibrary = Library
		Core.clearUiStateBindings()

		local bundle = {
			Library = Library,
			Alleral = Library,
			WindUI = Library,
			Syde = Syde,
			CreateWindow = function(_, settings)
				return Library:CreateWindow(settings)
			end,
			Notify = function(_, info)
				Library:Notification(info)
			end,
		}
		Core.say("Alleral UI " .. tostring(Library:GetAlleralVersion()) .. " (Syde)")
		return cacheUi(bundle)
	end

	function Core.preloadUi()
		return Core.loadUi()
	end

	Core.releaseAlleralRuntime = function()
		ENV._AlleralUiLibrary = nil
		ENV._AlleralSyde = nil
		ENV._AlleralMaclib = nil
	end

	function Core.uiLibrary(bundle)
		if type(bundle) ~= "table" then
			return nil
		end
		return bundle.Alleral or bundle.Library or bundle.Syde
	end

	function Core.createWindUiGroupbox(sydeTab, uiBundle)
		sydeTab = sydeTab or {}
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
			local handle = sydeTab:Toggle({
				Title = settings.Name,
				Value = settings.CurrentValue == true,
				CallBack = settings.Callback or function() end,
			})
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue == nil or not handle then
					return
				end
				local value = nextSettings.CurrentValue == true
				if type(handle.Set) == "function" then
					pcall(handle.Set, handle, value, true)
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
			local handle = sydeTab:Slider({
				Title = settings.Name,
				Description = settings.Description or "",
				Sliders = {
					{
						Title = settings.Name or "Value",
						Range = { minValue, maxValue },
						Increment = increment,
						StarterValue = tonumber(settings.CurrentValue) or minValue,
						CallBack = settings.Callback or function() end,
					},
				},
			})
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue == nil then
					return
				end
				-- Syde slider handles are internal; best-effort via stored slider row if present
				if handle and type(handle.Set) == "function" then
					pcall(handle.Set, handle, tonumber(nextSettings.CurrentValue))
				end
			end, {
				raw = handle,
				bindKey = settings.BindKey or settings.StateKey,
				kind = "slider",
			})
		end

		function groupbox:CreateButton(settings, id)
			local userCallback = settings.Callback or function() end
			local handle = sydeTab:Button({
				Title = settings.Name,
				Description = settings.Description or "",
				CallBack = function()
					userCallback()
				end,
			})
			return wrapElement(function(nextSettings)
				if type(nextSettings) ~= "table" then
					return
				end
				if nextSettings.Callback then
					userCallback = nextSettings.Callback
				end
				if handle and type(handle.Set) == "function" then
					pcall(handle.Set, handle, nextSettings)
				end
			end, {
				raw = handle,
				kind = "button",
			})
		end

		function groupbox:CreateInput(settings, id)
			local handle = sydeTab:TextInput({
				Title = settings.Name,
				PlaceHolder = settings.PlaceholderText or settings.Placeholder or "",
				NumberOnly = settings.AcceptedCharacters == "Numeric",
				CallBack = settings.Callback or function() end,
			})
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue == nil then
					return
				end
				if handle and type(handle.Set) == "function" then
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
			local starter = multi and current or tostring(current or values[1] or "")
			local handle = sydeTab:Dropdown({
				Title = settings.Name,
				Options = values,
				StarterOption = starter,
				Multi = multi,
				CallBack = function(selection)
					local userCallback = settings.Callback or function() end
					if multi then
						userCallback(Core.normalizeMultiSelection(selection))
					else
						userCallback(Core.normalizeDropdownValue(selection, values[1]))
					end
				end,
			})
			return wrapElement(function(nextSettings)
				local pick = nextSettings.CurrentOption or nextSettings.CurrentOptions
				if pick == nil or not handle then
					return
				end
				if type(handle.Set) == "function" then
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
			local handle = sydeTab:Paragraph({
				Title = "",
				Content = text,
			})
			return {
				_raw = handle,
				Set = function(_, nextSettings)
					local nextText = type(nextSettings) == "table" and (nextSettings.Name or nextSettings.Text)
						or tostring(nextSettings or "")
					if handle and type(handle.Set) == "function" then
						pcall(handle.Set, handle, nextText, "")
					end
				end,
				SetVisible = function() end,
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
			groupbox:CreateLabel({ Name = "────────────" })
			return {}
		end

		return groupbox
	end

	Core._UiTabRegistry = Core._UiTabRegistry or {}

	function Core.wrapUiTab(rawTab, uiBundle, window)
		local tab = {
			_sydeTab = rawTab,
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
			pcall(function()
				rawTab:Section(name, optionalIconImage(settings.Icon))
			end)
			return Core.createWindUiGroupbox(rawTab, uiBundle)
		end

		function tab:BuildThemeGroupbox(column)
			local group = Core.buildUiGroup(tab, "Appearance", column or 1)
			local lib = Core.uiLibrary(uiBundle)
			local themes = (lib and type(lib.ListThemeNames) == "function" and lib:ListThemeNames())
				or { "Default", "Maclib", "Linoria", "Obsidian" }
			local current = ENV.Alleral_ActiveTheme or "Default"
			group:CreateDropdown("Theme preset", themes, current, function(selected)
				if lib and type(lib.SetTheme) == "function" then
					pcall(lib.SetTheme, lib, selected)
				end
				ENV.Alleral_ActiveTheme = selected
				Core.notify("Theme", "Applied " .. tostring(selected), 2, "success")
			end, "Syde accent themes.")
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
			Core.logWarn("Syde window create failed")
			return nil
		end
		local window = {
			_rawWindow = rawWindow,
			_nlWindow = rawWindow,
			_ui = ui,
			_library = lib,
			_initialized = false,
			_tabGroup = rawWindow._sydeTabGroup or rawWindow._macTabGroup,
		}
		Core.registerUiWindow(window)
		Core.flushPendingNotifications()

		function window:AddTab(name, icon)
			local tabGroup = self._tabGroup
			if not tabGroup or type(tabGroup.Tab) ~= "function" then
				return nil
			end
			return tabGroup:Tab({ Name = name, Image = icon and iconImage(icon) or nil })
		end

		function window:Toggle()
			if self._rawWindow and type(self._rawWindow.Toggle) == "function" then
				pcall(self._rawWindow.Toggle, self._rawWindow)
			elseif self._rawWindow and type(self._rawWindow.SetState) == "function" then
				pcall(self._rawWindow.SetState, self._rawWindow, not self._rawWindow:GetState())
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
		local tabGroup = window._tabGroup or window._rawWindow._sydeTabGroup
		if not tabGroup or type(tabGroup.Tab) ~= "function" then
			Core.logWarn("buildUiTab skipped — tab group missing")
			return Core.wrapUiTab(nil, window._ui, window)
		end
		local rawTab = tabGroup:Tab({ Name = name, Image = icon and iconImage(icon) or nil })
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
