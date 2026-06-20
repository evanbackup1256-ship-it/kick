return function(Core)
	Core._AlleralUiLayer = "Alleral UI layer — Linoria"
	Core.ALLERAL_UI_VERSION = Core.ALLERAL_UI_VERSION or "5.1.0"
	Core.UI_VERSION = Core.ALLERAL_UI_VERSION
	Core.UI_LIBRARY = "Linoria"

	local DEFAULT_ICON_ID = "18821914323"

	local ENV = (function()
		local ok, env = pcall(function() return getgenv and getgenv() or getfenv() end)
		return ok and env or {}
	end)()

	local _linoriaInstance = nil
	local _tabCount = 0
	local _groupboxCount = 0
	local _controlCount = 0
	local _missingBindings = {}

	local function log(msg) if type(Core.say) == "function" then Core.say("[UI] " .. msg) end end
	local function warn(msg) if type(Core.logWarn) == "function" then Core.logWarn("[UI] " .. msg) end end

	local function safeCall(name, fn)
		local ok, result = pcall(fn)
		if not ok then warn(name .. ": " .. tostring(result)); return nil end
		return result
	end

	local function deepClone(value, seen)
		if type(value) ~= "table" then return value end
		seen = seen or {}
		if seen[value] then return seen[value] end
		local copy = {}
		seen[value] = copy
		for k, v in pairs(value) do
			copy[deepClone(k, seen)] = deepClone(v, seen)
		end
		return copy
	end

	local function iconImage(icon)
		if icon == nil or icon == "" then return DEFAULT_ICON_ID end
		if type(icon) == "number" then return tostring(icon) end
		local digits = tostring(icon):match("(%d+)$")
		if digits then return digits end
		local fn = Core.uiIcon
		if type(fn) == "function" then
			local r = fn(icon)
			if type(r) == "string" and r ~= "" then
				local d = r:match("(%d+)$")
				return d or r
			end
		end
		return DEFAULT_ICON_ID
	end

	local function iconAsset(icon) return "rbxassetid://" .. iconImage(icon) end

	local function tryReadLocal(path)
		local fn = ENV.readfile
		local isFileFn = ENV.isfile
		if type(fn) ~= "function" or type(isFileFn) ~= "function" then return nil end
		local ok, exists = pcall(isFileFn, path)
		if not ok or not exists then return nil end
		local okRead, data = pcall(fn, path)
		return okRead and data or nil
	end

	local function tryWriteLocal(path, data)
		local fn = ENV.writefile
		local mkfn = ENV.makefolder
		if type(fn) ~= "function" then return false end
		if mkfn then pcall(mkfn, ".alleral/cache") end
		return pcall(fn, path, data)
	end

	local function fetchUrl(url)
		if type(game.HttpGet) == "function" then
			local ok, b = pcall(game.HttpGet, game, url, true)
			if ok and type(b) == "string" and #b > 1000 then return b end
			ok, b = pcall(game.HttpGet, game, url)
			if ok and type(b) == "string" and #b > 1000 then return b end
		end
		if type(ENV.request) == "function" then
			local ok, res = pcall(ENV.request, { Url = url, Method = "GET" })
			if ok and type(res) == "table" then
				local body = res.Body or res.body
				if type(body) == "string" and #body > 1000 then return body end
			end
		end
		if type(ENV.Alleral_HTTP) == "table" and type(ENV.Alleral_HTTP.get) == "function" then
			return ENV.Alleral_HTTP.get(url)
		end
		return nil
	end

	local function loadLinoriaSource()
		if type(_linoriaInstance) == "table" and type(_linoriaInstance.CreateWindow) == "function" then
			log("Linoria already loaded, reusing")
			return _linoriaInstance
		end

		local loadStringFn = ENV.loadstring or loadstring or load
		if type(loadStringFn) ~= "function" then
			return nil, "loadstring not available"
		end

		local body
		local urls = {
			"https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua",
		}

		for attempt = 1, 3 do
			for _, url in ipairs(urls) do
				local bust = "?t=" .. tostring(tick()) .. tostring(math.random(10000, 99999))
				body = safeCall("HttpGet", function() return fetchUrl(url .. bust) end)
				if body then break end
			end
			if type(body) == "string" and #body > 1000 then break end
			if attempt < 3 then task.wait(0.3) end
		end

		if not body or #body <= 100 then
			local cachePath = ".alleral/cache/linoria.lua"
			local cached = tryReadLocal(cachePath)
			if cached and #cached > 1000 then
				body = cached
				log("Linoria loaded from local cache")
			else
				return nil, "Linoria unavailable after 3 attempts (no cache)"
			end
		else
			tryWriteLocal(".alleral/cache/linoria.lua", body)
		end

		body = body:gsub("^%s+", ""):gsub("%s+$", "")
		if body:find("<!DOCTYPE", 1, true) or body:find("<html", 1, true) then
			return nil, "Linoria source is HTML (rate limited?)"
		end

		log("Source downloaded (" .. tostring(#body) .. "b)")

		local chunk, compileErr = loadStringFn(body, "@Linoria/source")
		if type(chunk) ~= "function" then
			if type(load) == "function" then chunk, compileErr = load(body, "@Linoria/source") end
		end
		if type(chunk) ~= "function" then return nil, "Linoria compile: " .. tostring(compileErr) end

		log("Source compiled")

		if setfenv then pcall(setfenv, chunk, ENV) end
		local ok, pkg = pcall(chunk)
		if not ok then return nil, "Linoria runtime: " .. tostring(pkg) end
		if type(pkg) ~= "table" then return nil, "Linoria returned " .. type(pkg) end
		if type(pkg.CreateWindow) ~= "function" then return nil, "Linoria missing CreateWindow" end

		_linoriaInstance = pkg
		ENV._AlleralUI = pkg
		log("Linoria booted successfully")
		return pkg
	end

	local function buildLibrary(Linoria)
		local Library = { Version = Core.ALLERAL_UI_VERSION, _linoria = Linoria }

		function Library:GetArrrelVersion() return Core.ALLERAL_UI_VERSION end
		function Library:GetLayoutInfo() return { profile = "linoria", engine = "Linoria", version = Core.ALLERAL_UI_VERSION } end

		function Library:Notification(info)
			info = type(info) == "table" and info or { Description = tostring(info) }
			if Linoria and type(Linoria.Notify) == "function" then
				pcall(Linoria.Notify, Linoria, {
					Title = info.Title or "Alleral",
					Content = info.Description or info.Content or info.Text or "",
					Duration = info.Lifetime or info.Duration or info.Time or 4,
				})
			end
		end
		function Library:Notify(info) Library:Notification(info) end

		function Library:CreateWindow(settings)
			settings = deepClone(type(settings) == "table" and settings or {})
			log("Creating Window")

			local li = loadLinoriaSource()
			if not li then
				warn("Linoria boot failed")
				return nil
			end

			local title = settings.Title or settings.Name or "Alleral"

			local liWindow
			local okW, errW = pcall(function()
				liWindow = li:CreateWindow({ Title = title, Center = true, AutoShow = true })
			end)
			if not okW or not liWindow then
				warn("CreateWindow failed: " .. tostring(errW or "nil"))
				return nil
			end

			log("Window created")

			local window = {
				_liWindow = liWindow,
				_linoria = li,
				_library = Library,
				_tabs = {},
				_settings = settings,
				_title = title,
			}

			function window:AddTab(name, icon)
				_tabCount = _tabCount + 1
				local tabOk, liTab = pcall(function() return liWindow:AddTab(name) end)
				if tabOk and liTab then
					table.insert(window._tabs, liTab)
					log("Tab created: " .. tostring(name))
				else
					warn("Tab failed: " .. tostring(name))
					table.insert(_missingBindings, "Tab:" .. tostring(name))
				end
				return liTab, window
			end

			function window:Notify(payload)
				payload = type(payload) == "table" and payload or {}
				if li and type(li.Notify) == "function" then
					pcall(function()
						li:Notify({
							Title = payload.Title or "Alleral",
							Content = payload.Description or payload.Content or "",
							Duration = payload.Lifetime or payload.Duration or 4,
						})
					end)
				end
			end

			function window:Unload()
				pcall(function() liWindow:Destroy() end)
			end
			function window:SetState() end
			function window:GetState() return true end

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

		local Linoria = loadLinoriaSource()
		if not Linoria then
			warn("Linoria unavailable — UI will not function")
			local stub = { Library = { Version = Core.ALLERAL_UI_VERSION }, CreateWindow = function() return nil end, Notify = function() end }
			ENV.Alleral_UI = stub
			if getgenv then getgenv().Alleral_UI = stub end
			return stub
		end

		local Library = buildLibrary(Linoria)
		ENV._AlleralUiLibrary = Library

		local bundle = {
			Library = Library,
			Alleral = Library,
			CreateWindow = function(_, s) return Library:CreateWindow(s) end,
			Notify = function(_, i) Library:Notification(i) end,
			_linoria = Linoria,
		}
		ENV.Alleral_UI = bundle
		if getgenv then getgenv().Alleral_UI = bundle end

		log("Alleral UI " .. tostring(Library:GetArrrelVersion()) .. " loaded")
		return bundle
	end

	function Core.preloadUi() return Core.loadUi() end

	function Core.uiLibrary(bundle)
		if type(bundle) ~= "table" then return nil end
		return bundle.Alleral or bundle.Library
	end

	function Core.uiWindowSettings(extra)
		extra = type(extra) == "table" and extra or {}
		return {
			Title = extra.Title or extra.Name or "Alleral",
			Name = extra.Title or extra.Name or "Alleral",
			Subtitle = extra.Subtitle or extra.Author or "",
			Icon = extra.Icon or "sparkles",
			Theme = extra.Theme or "Default",
			Size = extra.Size or UDim2.fromOffset(580, 460),
			TabWidth = tonumber(extra.TabWidth) or 160,
			FileSettings = { RootFolder = extra.configFolder or "Alleral_Configs", ConfigFolder = extra.FileName or "Interface" },
		}
	end

	function Core.createUiGroupbox(section, _uiBundle)
		section = type(section) == "table" and section or {}
		local serial = 0
		local function nextFlag(name, explicit)
			serial = serial + 1
			return explicit or (Core.uiElementId and Core.uiElementId(name) or name) .. "_" .. serial
		end

		local function wrapElement(applySet, meta)
			meta = type(meta) == "table" and meta or {}
			local wrapper = { _raw = meta.raw }
			function wrapper:Set(value)
				if type(value) == "table" then applySet(value) else applySet({ CurrentValue = value }) end
			end
			if meta.bindKey and Core.bindUiState then Core.bindUiState(meta.bindKey, wrapper, meta.kind or "toggle", meta.raw) end
			return wrapper
		end

		local groupbox = {}
		function groupbox:CreateSection(name) return groupbox end

		function groupbox:CreateToggle(settings, id)
			local currentVal = settings.Default or settings.CurrentValue or settings.Value
			local flag = nextFlag(settings.Name, id)
			local raw = safeCall("Toggle " .. tostring(settings.Name), function()
				return section:AddToggle(flag, {
					Text = settings.Name or settings.Title or "Toggle",
					Default = currentVal == true,
					Callback = settings.Callback or function() end,
				})
			end)
			_controlCount = _controlCount + 1
			if not raw then table.insert(_missingBindings, "Toggle:" .. tostring(settings.Name)) end
			return wrapElement(function(next)
				if not raw then return end
				local v = next.CurrentValue; if v == nil then v = next.Value end; if v == nil then v = next end
				if raw.SetValue then pcall(raw.SetValue, raw, v == true) end
			end, { raw = raw, bindKey = settings.BindKey or settings.StateKey, kind = "toggle" })
		end

		function groupbox:CreateButton(settings, id)
			local name = settings.Name or settings.Title or settings.Text or "Button"
			local raw = safeCall("Button " .. tostring(name), function()
				return section:AddButton({ Text = name, Func = settings.Callback or function() end })
			end)
			_controlCount = _controlCount + 1
			if not raw then table.insert(_missingBindings, "Button:" .. tostring(name)) end
			return wrapElement(function() end, { raw = raw, kind = "button" })
		end

		function groupbox:CreateSlider(settings, id)
			local range = settings.Range or { 0, 100 }
			local flag = nextFlag(settings.Name, id)
			local currentVal = tonumber(settings.Default) or tonumber(settings.CurrentValue) or tonumber(settings.Value) or range[1]
			local raw = safeCall("Slider " .. tostring(settings.Name), function()
				return section:AddSlider(flag, {
					Text = settings.Name or settings.Title or "Slider",
					Default = currentVal,
					Min = range[1] or 0,
					Max = range[2] or 100,
					Suffix = settings.Suffix or "",
					Rounding = tonumber(settings.Increment) or 1,
					Compact = settings.Compact or false,
					Callback = settings.Callback or function() end,
				})
			end)
			_controlCount = _controlCount + 1
			if not raw then table.insert(_missingBindings, "Slider:" .. tostring(settings.Name)) end
			return wrapElement(function(next)
				if not raw then return end
				local v = tonumber(next.CurrentValue); if v == nil then v = tonumber(next.Value) end; if v == nil then v = tonumber(next) end; if v == nil then return end
				if raw.SetValue then pcall(raw.SetValue, raw, v) end
			end, { raw = raw, bindKey = settings.BindKey or settings.StateKey, kind = "slider" })
		end

		function groupbox:CreateInput(settings, id)
			local flag = nextFlag(settings.Name, id)
			local currentVal = tostring(settings.CurrentValue or settings.Default or settings.Value or "")
			local raw = safeCall("Input " .. tostring(settings.Name), function()
				return section:AddInput(flag, {
					Text = settings.Name or settings.Title or "Input",
					Default = currentVal,
					Placeholder = settings.PlaceholderText or settings.Placeholder or "Enter...",
					Callback = settings.Callback or function() end,
				})
			end)
			_controlCount = _controlCount + 1
			if not raw then table.insert(_missingBindings, "Input:" .. tostring(settings.Name)) end
			return wrapElement(function(next)
				if not raw then return end
				local v = next.CurrentValue; if v == nil then v = next.Value end; if v == nil then v = tostring(next) end
				if raw.SetValue then pcall(raw.SetValue, raw, tostring(v)) end
			end, { raw = raw, bindKey = settings.BindKey or settings.StateKey, kind = "input" })
		end

		function groupbox:CreateDropdown(settings, id)
			local values = settings.Options or settings.Values or {}
			local multi = settings.MultipleOptions == true or settings.Multi == true
			local current = settings.CurrentOption or (multi and {} or (values[1] or ""))
			local flag = nextFlag(settings.Name, id)
			local raw = safeCall("Dropdown " .. tostring(settings.Name), function()
				return section:AddDropdown(flag, {
					Text = settings.Name or settings.Title or "Dropdown",
					Values = values,
					Default = multi and (type(current) == "table" and current[1] or current) or (type(current) == "table" and current[1] or current or values[1] or ""),
					Multi = multi,
					Callback = function(selection)
						local cb = settings.Callback or function() end
						if multi then cb(Core.normalizeMultiSelection and Core.normalizeMultiSelection(selection) or selection)
						else cb(Core.normalizeDropdownValue and Core.normalizeDropdownValue(selection, values[1]) or selection) end
					end,
				})
			end)
			_controlCount = _controlCount + 1
			if not raw then table.insert(_missingBindings, "Dropdown:" .. tostring(settings.Name)) end
			return wrapElement(function(next)
				if not raw then return end
				local nextValues = next.Options or next.Values
				local pick = next.CurrentOption or next.CurrentOptions
				if type(nextValues) == "table" and raw.Refresh then pcall(raw.Refresh, raw, nextValues) end
				if pick ~= nil then
					if raw.SetValue then pcall(raw.SetValue, raw, tostring(pick)) end
				end
			end, { raw = raw, bindKey = settings.BindKey or settings.StateKey, kind = "dropdown" })
		end

		function groupbox:CreateLabel(settings, id)
			local text = type(settings) == "table" and (settings.Name or settings.Text) or tostring(settings or "")
			local raw = safeCall("Label", function() return section:AddLabel(text) end)
			_controlCount = _controlCount + 1
			return {
				Set = function(_, nextSettings)
					local nextText = type(nextSettings) == "table" and (nextSettings.Name or nextSettings.Text) or tostring(nextSettings or "")
					if not raw then return end
					if raw.SetText then pcall(raw.SetText, raw, nextText) end
				end,
				SetVisible = function(_, visible) if raw then pcall(function() raw.Visible = visible == true end) end end,
			}
		end

		function groupbox:CreateDivider()
			safeCall("Divider", function() return section:AddDivider() end)
			_controlCount = _controlCount + 1
			return {}
		end

		function groupbox:CreateStatus(label, fields)
			local status = { Labels = {}, LastValues = {}, Visible = true }
			for key, value in pairs(fields or {}) do
				status.LastValues[key] = tostring(value)
				local lbl = groupbox:CreateLabel({ Name = tostring(key) .. ": " .. tostring(value) }, nextFlag(label .. "_" .. tostring(key)))
				if lbl then status.Labels[key] = lbl end
			end
			local sum = groupbox:CreateLabel({ Name = "" }, nextFlag(label .. "_summary"))
			if sum then status.Labels.Summary = sum end
			function status:Update(key, value)
				local rendered = tostring(value)
				if self.LastValues[key] == rendered then return end
				self.LastValues[key] = rendered
				local row = self.Labels[key]
				if row and row.Set then row:Set({ Name = tostring(key) .. ": " .. rendered }) end
			end
			function status:SetSummary(text) local row = self.Labels.Summary; if row and row.Set then row:Set({ Name = tostring(text or "") }) end end
			function status:SetVisible(visible) self.Visible = visible == true end
			return status
		end
		return groupbox
	end

	function Core.wrapUiGroup(groupbox, callbackWrapper)
		local function wrap(label, callback)
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
			return groupbox:CreateToggle({ Name = name, CurrentValue = default == true, Default = default == true, Tooltip = tooltip, Callback = wrap(name, callback), BindKey = bindKey }, bindKey)
		end
		function group:CreateSlider(name, min, max, default, callback, tooltip, increment, bindKey)
			return groupbox:CreateSlider({ Name = name, Range = { min, max }, CurrentValue = default or min, Default = default or min, Tooltip = tooltip, Increment = increment, Callback = wrap(name, callback), BindKey = bindKey }, bindKey)
		end
		function group:CreateButton(name, callback, tooltip)
			return groupbox:CreateButton({ Name = name, Tooltip = tooltip, Callback = wrap(name, callback) })
		end
		function group:CreateInput(name, placeholder, arg3, arg4, arg5)
			local icon, default, callback, tooltip = nil, "", nil, nil
			if type(arg3) == "function" then callback, tooltip = arg3, arg4
			elseif type(arg4) == "function" then icon, callback, tooltip = arg3, arg4, arg5
			else if type(arg3) == "string" or type(arg3) == "number" then default = arg3 end; if type(arg4) == "function" then callback = arg4 end; tooltip = arg5 end
			return groupbox:CreateInput({ Name = name, PlaceholderText = placeholder, CurrentValue = default, Default = default, Tooltip = tooltip, Callback = wrap(name, callback) })
		end
		function group:CreateDropdown(name, options, default, callback, tooltip, bindKey)
			return groupbox:CreateDropdown({ Name = name, Options = options, CurrentOption = default, Tooltip = tooltip, Callback = wrap(name, callback), BindKey = bindKey }, bindKey)
		end
		function group:AddDropdown(id, config)
			config = type(config) == "table" and config or {}
			return groupbox:CreateDropdown({ Name = config.Text or config.Name or id, Options = config.Values or config.Options or {}, CurrentOption = config.Default or config.CurrentValue or config.CurrentOption, MultipleOptions = config.Multi or config.MultiSelection, Callback = config.Callback or function() end }, id)
		end
		function group:CreateLabel(text) return groupbox:CreateLabel({ Name = text }) end
		function group:CreateStatus(label, fields) return groupbox:CreateStatus(label, fields or {}) end
		function group:CreateDivider() return groupbox:CreateDivider() end
		return group
	end

	function Core.wrapUiTab(rawTab, uiBundle, window)
		local tab = { _rawTab = rawTab, _ui = uiBundle, _window = window, _columnCount = 2, _sectionIndex = 0 }
		if type(Core._UiTabRegistry) == "table" then table.insert(Core._UiTabRegistry, tab) end

		function tab:CreateGroupbox(settings)
			settings = settings or {}
			local name = settings.Name or settings.Group or "Group"
			_groupboxCount = _groupboxCount + 1
			if not rawTab then
				warn("Groupbox '" .. name .. "' — no tab (window missing)")
				table.insert(_missingBindings, "Groupbox:" .. name .. "(no tab)")
				return type(Core.createStubUiGroup) == "function" and Core.createStubUiGroup(name) or {}
			end
			local groupboxHolder = safeCall("Groupbox " .. name, function()
				local col = tonumber(settings.Column) or 1
				if col == 2 and rawTab.AddRightGroupbox then
					return rawTab:AddRightGroupbox(name)
				elseif rawTab.AddLeftGroupbox then
					return rawTab:AddLeftGroupbox(name)
				elseif rawTab.AddGroupbox then
					return rawTab:AddGroupbox(name)
				else
					return nil, "no AddGroupbox method on tab"
				end
			end)
			if not groupboxHolder then
				warn("Groupbox '" .. name .. "' creation failed")
				table.insert(_missingBindings, "Groupbox:" .. name .. "(failed)")
				return Core.createStubUiGroup and Core.createStubUiGroup(name) or {}
			end
			tab._sectionIndex = (tab._sectionIndex or 0) + 1
			return Core.createUiGroupbox(groupboxHolder, uiBundle)
		end

		function tab:Select() if rawTab and rawTab.Select then pcall(rawTab.Select, rawTab) end end
		function tab:BuildThemeGroupbox(column)
			local group = Core.buildUiGroup(tab, "Appearance", column or 1)
			group:CreateLabel("Linoria UI engine.")
			return group
		end
		return tab
	end

	function Core.buildUiWindow(ui, settings)
		settings = settings or {}
		local lib = ui and ui.Library
		if not lib then warn("buildUiWindow: lib nil"); return nil end
		if type(lib.CreateWindow) ~= "function" then warn("buildUiWindow: CreateWindow missing"); return nil end
		local rawWindow = lib:CreateWindow(settings)
		if not rawWindow then warn("buildUiWindow: CreateWindow nil"); return nil end
		local window = { _rawWindow = rawWindow, _ui = ui, _library = lib, _initialized = false, _tabGroup = rawWindow, _alleralSettings = settings }
		if type(Core.registerUiWindow) == "function" then Core.registerUiWindow(window) end
		if type(Core.flushPendingNotifications) == "function" then Core.flushPendingNotifications() end
		return window
	end

	function Core.buildUiTab(section, name, icon, columns, id)
		local resolve = Core.resolveUiWindow
		local window = type(resolve) == "function" and resolve(section) or nil
		if type(window) ~= "table" or not window._rawWindow then
			warn("buildUiTab: no window for '" .. tostring(name) .. "'")
			return Core.wrapUiTab(nil, type(section) == "table" and section._ui or nil, window)
		end
		local tabGroup = window._tabGroup or window
		if not tabGroup or type(tabGroup.AddTab) ~= "function" then
			warn("buildUiTab: no tab group for '" .. tostring(name) .. "'")
			return Core.wrapUiTab(nil, window._ui, window)
		end
		local rawTab = tabGroup:AddTab(name, icon)
		_tabCount = _tabCount + 1
		log("Tab: " .. tostring(name))
		local wrapped = Core.wrapUiTab(rawTab, window._ui or (type(section) == "table" and section._ui) or nil, window)
		wrapped._columnCount = math.max(1, tonumber(columns) or 2)
		if not window._defaultTab then window._defaultTab = rawTab end
		return wrapped
	end

	function Core.buildUiGroup(tab, name, column, callbackWrapper, icon, id)
		name = tostring(name or "Group")
		if type(tab) ~= "table" or type(tab.CreateGroupbox) ~= "function" then
			warn("buildUiGroup: invalid tab for '" .. name .. "'")
			return Core.createStubUiGroup and Core.createStubUiGroup(name) or {}
		end
		local groupbox = tab:CreateGroupbox({ Name = name, Column = column or 1, Icon = icon })
		return Core.wrapUiGroup(groupbox, callbackWrapper)
	end

	function Core.buildUiSection(window)
		if type(window) == "table" and window._alleralTabGroup then return window._alleralTabGroup end
		if type(window) == "table" and window._rawWindow then return window end
		return window
	end

	function Core.finalizeGameUi(window, ui, options)
		options = type(options) == "table" and options or {}
		if type(window) == "table" and window._rawWindow and not window._initialized then
			window._initialized = true
			task.defer(function()
				pcall(function()
					local dt = window._defaultTab
					if dt and dt.Select then pcall(dt.Select, dt) end
				end)
			end)
		end
		if type(Core.setupHubKeybinds) == "function" then pcall(Core.setupHubKeybinds, { window = window, ui = ui or window._ui or ENV.Alleral_UI }) end
		if options.notify ~= false then Core.notifyBootReady({ Name = options.Name or "Alleral", Subtitle = options.Subtitle }) end

		-- Startup validation — runs AFTER UI is fully built
		local linoriaOk = type(_linoriaInstance) == "table" and type(_linoriaInstance.CreateWindow) == "function"
		local profileId = ENV.Alleral_ActiveScriptId or "none"
		log("=== UI Validation ===")
		log("Linoria loaded: " .. tostring(linoriaOk))
		log("Tabs created: " .. tostring(_tabCount))
		log("Groupboxes created: " .. tostring(_groupboxCount))
		log("Controls created: " .. tostring(_controlCount))
		if #_missingBindings > 0 then
			log("Missing bindings: " .. tostring(#_missingBindings))
			for _, b in ipairs(_missingBindings) do
				log("  - " .. b)
			end
		else
			log("Missing bindings: none")
		end
		log("====================")

		return window
	end

	function Core.repairUiWindow(window)
		window = window or ENV.Alleral_UiWindow
		if type(window) ~= "table" or not window._rawWindow then return false end
		return true
	end

	function Core.refreshAllTabColumns() return true end

	Core.notifyUi = function(info)
		local ui = ENV.Alleral_UI
		if ui and type(ui.Notify) == "function" then pcall(ui.Notify, ui, info) end
	end

	Core.releaseAlleralRuntime = function()
		ENV._AlleralUiLibrary = nil
		ENV._AlleralUI = nil
		ENV.Alleral_UiWindow = nil
		_linoriaInstance = nil
	end
end
