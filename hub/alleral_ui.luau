return function(Core)
	local ALLERAL_UI_LAYER = "Alleral UI layer"
	Core._AlleralUiLayer = ALLERAL_UI_LAYER
	Core.ALLERAL_UI_VERSION = Core.ALLERAL_UI_VERSION or "2.3.0-vendor"
	Core.WINDUI_VERSION = Core.ALLERAL_UI_VERSION
	Core.UI_LIBRARY = "Alleral"

	local UI_ROOTS = {
		"hub/ui/",
		"kick/hub/ui/",
		"kick/kick/hub/ui/",
		".alleral/cache/hub/ui/",
	}
	local UI_MIRRORS = {
		"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/hub/ui/",
		"https://github.com/evanbackup1256-ship-it/kick/raw/main/hub/ui/",
		"https://cdn.jsdelivr.net/gh/evanbackup1256-ship-it/kick@main/hub/ui/",
	}
	local LIBRARY_FILE = "Library.luau"
	local MIN_LIBRARY_BYTES = 8000
	local MIN_MODULE_BYTES = 50

	local function genv()
		local ok, env = pcall(function()
			return getgenv and getgenv() or getfenv()
		end)
		return ok and env or {}
	end
	local ENV = genv()
	local agentDebug = ENV._AlleralAgentDebug or function() end

	local function moduleSourceValid(source, minBytes)
		minBytes = minBytes or MIN_MODULE_BYTES
		if type(source) ~= "string" or #source < minBytes then
			return false
		end
		if #source <= 8192 and source:find("404: Not Found", 1, true) then
			return false
		end
		if source:find("<!DOCTYPE", 1, true) or source:find("<html", 1, true) then
			return false
		end
		return source:find("return", 1, true) ~= nil or source:find("function", 1, true) ~= nil
	end

	local function readLocal(name, minBytes)
		minBytes = minBytes or MIN_MODULE_BYTES
		local roots = { "", "kick/", "kick/kick/", "workspace/", "scripts/" }
		for _, vendor in ipairs(UI_ROOTS) do
			for _, root in ipairs(roots) do
				local path = root .. vendor .. name
				local body = Core.readFile(path)
				if moduleSourceValid(body, minBytes) then
					return body, path
				end
			end
		end
		return nil
	end

	local function cacheUiSource(name, body)
		if type(body) ~= "string" or not moduleSourceValid(body) then
			return
		end
		local rel = "hub/ui/" .. name:gsub("\\", "/")
		local cacheRel = ".alleral/cache/" .. rel
		if Core.writeFile then
			pcall(Core.writeFile, rel, body)
			pcall(Core.writeFile, cacheRel, body)
		end
	end

	local function uiHttpGet(url, minBytes)
		minBytes = minBytes or 0
		if type(Core.httpGet) == "function" then
			local body = Core.httpGet(url)
			if type(body) == "string" and #body >= minBytes then
				return body
			end
		end
		local http = ENV.Alleral_HTTP
		if type(http) == "table" and type(http.get) == "function" then
			local body = http.get(url, minBytes)
			if type(body) == "string" and #body >= minBytes then
				return body
			end
		end
		return nil
	end

	local function librarySourceValid(source)
		if type(source) ~= "string" or #source < MIN_LIBRARY_BYTES then
			return false
		end
		if source:find("writefile(`", 1, true) or source:find("return `", 1, true) then
			return false
		end
		return source:find("LibRef", 1, true) ~= nil and source:find("EnsureGuiRoot", 1, true) ~= nil
	end

	local function fetchRemote(name, minBytes, opts)
		minBytes = minBytes or MIN_LIBRARY_BYTES
		opts = type(opts) == "table" and opts or {}
		local validate = opts.validate or moduleSourceValid
		local versionTag = tostring(Core.ALLERAL_UI_VERSION or "kick"):gsub("[^%w%.%-]", "")
		local bases = UI_MIRRORS
		if type(Core._UiRemoteBases) == "table" and #Core._UiRemoteBases > 0 then
			local merged = {}
			for _, base in ipairs(Core._UiRemoteBases) do
				table.insert(merged, base .. "/hub/ui/")
			end
			for _, base in ipairs(UI_MIRRORS) do
				table.insert(merged, base)
			end
			bases = merged
		end
		for _, base in ipairs(bases) do
			local plain = base .. name
			local candidates = {
				plain .. (plain:find("?", 1, true) and "&" or "?") .. "v=" .. versionTag .. "&t=" .. tostring(tick()),
				plain,
			}
			if opts.bustOnly then
				candidates = { candidates[1] }
			end
			for _, url in ipairs(candidates) do
				local body = uiHttpGet(url, minBytes)
				if type(body) == "string" and #body >= minBytes and validate(body, minBytes) then
					cacheUiSource(name, body)
					return body, url
				end
			end
		end
		return nil
	end

	local function resolveUiSource(name, minBytes)
		minBytes = minBytes or MIN_MODULE_BYTES
		local source, path = readLocal(name, minBytes)
		if source then
			return source, path, nil
		end
		source, path = fetchRemote(name, minBytes, { validate = moduleSourceValid })
		if source then
			return source, path or ("remote:" .. name), nil
		end
		return nil, nil, "missing module " .. name
	end

	local function sanitizeLuauSource(source)
		if type(source) ~= "string" or source == "" then
			return source
		end
		source = source:gsub("\r\n", "\n")
		local out = {}
		for line in (source .. "\n"):gmatch("(.-)\n") do
			if not line:match("^%-%-![%w_]+") then
				table.insert(out, line)
			end
		end
		return table.concat(out, "\n")
	end

	local moduleCache = {}

	local function loadUiModule(name)
		if moduleCache[name] then
			return moduleCache[name]
		end
		local source, path, resolveErr = resolveUiSource(name, MIN_MODULE_BYTES)
		if not source then
			-- #region agent log
			agentDebug("H7", "alleral_ui:loadUiModule", "module source missing", {
				name = name,
				err = resolveErr,
			})
			-- #endregion
			return nil, resolveErr or ("missing module " .. name)
		end
		local loadFn = Core.loadStringFn()
		if not loadFn then
			return nil, "load unavailable"
		end
		local chunk, err = loadFn(sanitizeLuauSource(source), "@Alleral/ui/" .. name .. ":" .. tostring(path))
		if not chunk then
			-- #region agent log
			agentDebug("H8", "alleral_ui:loadUiModule", "module compile failed", {
				name = name,
				path = path,
				bytes = #source,
				err = tostring(err),
			})
			-- #endregion
			return nil, tostring(err)
		end
		local ok, result = pcall(chunk)
		if not ok then
			-- #region agent log
			agentDebug("H8", "alleral_ui:loadUiModule", "module execute failed", {
				name = name,
				path = path,
				err = tostring(result),
			})
			-- #endregion
			return nil, tostring(result)
		end
		if name == LIBRARY_FILE and type(result) ~= "function" then
			return nil, "invalid Alleral library: " .. tostring(result)
		end
		moduleCache[name] = result
		return result
	end

	local function loadUiLibrary()
		local moduleLoaderFactory, mlErr = loadUiModule("ModuleLoader.luau")
		local vendorFactory, vendorErr = loadUiModule("Vendor.luau")
		if not moduleLoaderFactory or not vendorFactory then
			-- #region agent log
			agentDebug("H7", "alleral_ui:loadUiLibrary", "vendor bootstrap missing", {
				hasModuleLoader = moduleLoaderFactory ~= nil,
				moduleLoaderErr = mlErr,
				hasVendor = vendorFactory ~= nil,
				vendorErr = vendorErr,
			})
			-- #endregion
			local detail = mlErr or vendorErr or "unknown"
			return nil, "Alleral UI vendor loader missing: " .. tostring(detail)
		end
		local readVendorSource = function(rel)
			rel = tostring(rel or ""):gsub("\\", "/")
			local body, path = readLocal(rel, MIN_MODULE_BYTES)
			if body then
				return body
			end
			local alt = rel:gsub("^vendor/", "")
			body, path = readLocal("vendor/" .. alt, MIN_MODULE_BYTES)
			if body then
				return body
			end
			body = fetchRemote(rel, MIN_MODULE_BYTES, { validate = moduleSourceValid })
			if body then
				return body
			end
			return fetchRemote("vendor/" .. alt, MIN_MODULE_BYTES, { validate = moduleSourceValid })
		end
		local loadChunk = function(source, name)
			local loadFn = Core.loadStringFn()
			if not loadFn then
				error("load unavailable", 0)
			end
			local chunk, err = loadFn(sanitizeLuauSource(source), name)
			if not chunk then
				error(tostring(err), 0)
			end
			return chunk
		end
		local ModuleLoader = moduleLoaderFactory({
			readSource = readVendorSource,
			loadChunk = loadChunk,
			root = "vendor",
		})
		local Vendor = vendorFactory({ ModuleLoader = ModuleLoader })
		if not Vendor or not Vendor.spr or not Vendor.Fusion then
			return nil, "Alleral UI vendor stack incomplete"
		end

		local Maid = loadUiModule("Maid.luau")
		local springFactory = loadUiModule("Spring.luau")
		local Spring = springFactory and springFactory({ Vendor = Vendor }) or nil
		local Utils = loadUiModule("Utils.luau")
		local Icons = loadUiModule("Icons.luau")
		local Theme = loadUiModule("Theme.luau")
		if not Maid or not Spring or not Utils or not Theme or not Icons then
			return nil, "Alleral UI foundation modules missing"
		end
		local MotionFactory = loadUiModule("Motion.luau")
		local ConfigFactory = loadUiModule("Config.luau")
		local Motion = MotionFactory and MotionFactory({ Spring = Spring, Utils = Utils }) or nil
		local Config = ConfigFactory and ConfigFactory({}) or nil
		local baseDeps = {
			Utils = Utils,
			Motion = Motion,
			Theme = Theme,
			Maid = Maid,
			Icons = Icons,
			Config = Config,
			Vendor = Vendor,
		}
		local TooltipFactory = loadUiModule("Tooltip.luau")
		local NotificationFactory = loadUiModule("Notification.luau")
		local ModalFactory = loadUiModule("Modal.luau")
		local CommandPaletteFactory = loadUiModule("CommandPalette.luau")
		local Tooltip = TooltipFactory and TooltipFactory(baseDeps) or nil
		local Notification = NotificationFactory and NotificationFactory(baseDeps) or nil
		local Modal = ModalFactory and ModalFactory(baseDeps) or nil
		local CommandPalette = CommandPaletteFactory and CommandPaletteFactory(baseDeps) or nil
		local fullDeps = {}
		for k, v in pairs(baseDeps) do
			fullDeps[k] = v
		end
		fullDeps.Tooltip = Tooltip
		fullDeps.Notification = Notification
		fullDeps.Modal = Modal
		fullDeps.CommandPalette = CommandPalette
		local ComponentsFactory = loadUiModule("Components.luau")
		local SectionFactory = loadUiModule("Section.luau")
		local PageFactory = loadUiModule("Page.luau")
		local NavigationFactory = loadUiModule("Navigation.luau")
		local WindowFactory = loadUiModule("Window.luau")
		fullDeps.Components = ComponentsFactory and ComponentsFactory(fullDeps) or nil
		fullDeps.Section = SectionFactory and SectionFactory(fullDeps) or nil
		fullDeps.Page = PageFactory and PageFactory(fullDeps) or nil
		fullDeps.Navigation = NavigationFactory and NavigationFactory(fullDeps) or nil
		fullDeps.Window = WindowFactory and WindowFactory({
			Utils = Utils,
			Motion = Motion,
			Theme = Theme,
			Maid = Maid,
			Page = fullDeps.Page,
			Navigation = fullDeps.Navigation,
			Notification = Notification,
			Modal = Modal,
			CommandPalette = CommandPalette,
		}) or nil
		local LibraryFactory = loadUiModule(LIBRARY_FILE)
		if not LibraryFactory or type(LibraryFactory) ~= "function" then
			return nil, "invalid Alleral library: factory missing"
		end
		if not Motion or not Components or not fullDeps.Section or not fullDeps.Page or not fullDeps.Navigation or not fullDeps.Window then
			return nil, "Alleral UI modules incomplete"
		end
		local Library = LibraryFactory(fullDeps)
		if not Library or type(Library.EnsureGuiRoot) ~= "function" then
			return nil, "invalid Alleral library: EnsureGuiRoot missing"
		end
		ENV._AlleralUiLibrary = Library
		return Library
	end

	local function releaseUiRuntime()
		local lib = ENV._AlleralUiLibrary
		if type(lib) == "table" and lib.Holder and typeof(lib.Holder) == "Instance" then
			pcall(function()
				lib.Holder:Destroy()
			end)
			lib.Holder = nil
		end
		ENV._AlleralUiLibrary = nil
		moduleCache = {}
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

	local function iconId(icon)
		if type(icon) == "number" then
			return tostring(icon)
		end
		if type(icon) == "string" and icon:find("%d") then
			return icon:match("%d+") or "layout-dashboard"
		end
		return icon or "layout-dashboard"
	end

	function Core.loadUi()
		local cached = ENV.Alleral_UI
		if uiOk(cached) then
			return cacheUi(cached)
		end
		if cached then
			releaseUiRuntime()
			ENV.Alleral_UI = nil
		end

		local Library, err = loadUiLibrary()
		if not Library then
			Core.logWarn("Alleral UI load failed: " .. tostring(err or "unknown"))
			return nil, err or "Alleral UI missing"
		end

		Core.clearUiStateBindings()

		local bundle = {
			Library = Library,
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
						Type = info.Type or info.type,
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
		Core.say("Alleral UI " .. tostring(Library.GetAlleralVersion and Library:GetAlleralVersion() or Core.ALLERAL_UI_VERSION))
		return cacheUi(bundle)
	end

	function Core.preloadUi()
		return Core.loadUi()
	end

	Core.releaseAlleralRuntime = releaseUiRuntime

	function Core.uiLibrary(bundle)
		if type(bundle) ~= "table" then
			return nil
		end
		return bundle.Alleral or bundle.Library
	end

	function Core.createWindUiGroupbox(rawSection, uiBundle)
		rawSection = rawSection or {}
		uiBundle = uiBundle or {}
		local serial = 0
		local lib = Core.uiLibrary(uiBundle)

		local function attachTooltip(handle, tooltip)
			if type(handle) ~= "table" or not tooltip or tostring(tooltip) == "" then
				return
			end
			handle.Desc = handle.Desc or tostring(tooltip)
			handle.Tooltip = handle.Tooltip or tostring(tooltip)
			local target = handle._instance
			if not target and type(handle._raw) == "table" then
				target = handle._raw._instance
			end
			if lib and lib.Tooltip and type(lib.Tooltip.attach) == "function" and target then
				pcall(lib.Tooltip.attach, target, tooltip)
			end
		end

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
				Description = settings.Tooltip,
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
			local handle = rawSection:Slider({
				Name = settings.Name,
				Description = settings.Tooltip,
				Min = minValue,
				Max = maxValue,
				Default = tonumber(settings.CurrentValue) or minValue,
				Increment = Core.sliderIncrement(minValue, maxValue, settings.Increment),
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
				Callback = settings.Callback or function() end,
			})
			attachTooltip(handle, settings.Tooltip)
			return { Set = function() end }
		end

		function groupbox:CreateInput(settings, id)
			local handle = rawSection:Textbox({
				Name = settings.Name,
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
				Options = values,
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
				handle:Set(pick)
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
					if label and label.Set then
						label:Set(nextText)
					elseif label and label.SetText then
						label:SetText(nextText)
					end
				end,
			}
		end

		function groupbox:CreateStatus(label, fields)
			if type(rawSection.CreateStatus) == "function" then
				return rawSection:CreateStatus(label, fields)
			end
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
				self.Visible = visible == true
				for _, row in pairs(self.Labels) do
					if type(row) == "table" and row._raw and row._raw._frame then
						row._raw._frame.Visible = self.Visible
					end
				end
			end
			return status
		end

		function groupbox:CreateDivider()
			if type(rawSection.Space) == "function" then
				rawSection:Space({ Size = 10 })
			elseif type(rawSection.CreateDivider) == "function" then
				rawSection:CreateDivider()
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
			local pageColumns = math.max(1, tonumber(rawPage and rawPage.Columns) or 2)
			local column = math.clamp(tonumber(settings.Column) or 1, 1, pageColumns)
			if not rawPage or (type(rawPage.Section) ~= "function" and type(rawPage.CreateSection) ~= "function") then
				Core.logWarn("CreateGroupbox skipped — page missing for " .. tostring(name))
				return Core.createStubUiGroup(name)
			end
			local section
			if type(rawPage.CreateSection) == "function" then
				section = rawPage:CreateSection({ Name = name, Side = column, Column = column })
			else
				section = rawPage:Section({ Name = name, Side = column, Column = column })
			end
			return Core.createWindUiGroupbox(section, uiBundle)
		end

		function tab:BuildThemeGroupbox(column)
			local group = Core.buildUiGroup(tab, "Appearance", column or 1)
			local lib = Core.uiLibrary(uiBundle)
			local themes = (lib and type(lib.ListThemeNames) == "function" and lib:ListThemeNames())
				or { "Private", "Obsidian", "Graphite", "Midnight", "Neon", "Linoria" }
			local current = (lib and type(lib.GetCurrentTheme) == "function" and lib:GetCurrentTheme()) or "Private"
			group:CreateDropdown("Theme preset", themes, current, function(selected)
				if lib and type(lib.SetTheme) == "function" then
					pcall(lib.SetTheme, lib, selected)
				end
				Core.notify("Theme", "Applied " .. tostring(selected), 2, "success")
			end, "Dark presets tuned for exploit menus.")
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

		return tab
	end

	function Core.buildUiWindow(ui, settings)
		settings = settings or {}
		local lib = ui and ui.Library
		if not lib or type(lib.CreateWindow) ~= "function" then
			return nil
		end
		local Players = game:GetService("Players")
		local lp = Players.LocalPlayer
		local playerLabel = lp and ((lp.DisplayName ~= "" and lp.DisplayName) or lp.Name) or ""
		local rawWindow = lib:CreateWindow({
			Title = settings.Name or settings.Title or "Alleral",
			Subtitle = settings.Subtitle or settings.SubName or playerLabel,
			Theme = settings.Theme or "Private",
			Size = settings.Size or UDim2.fromOffset(860, 580),
			Acrylic = settings.Acrylic ~= false,
			Icon = iconId(settings.Icon or "sparkles"),
		})
		if not rawWindow then
			Core.logWarn("Alleral window create failed")
			return nil
		end
		local window = {
			_rawWindow = rawWindow,
			_nlWindow = rawWindow,
			_premiumWindow = rawWindow,
			_ui = ui,
			_library = lib,
			_initialized = false,
		}
		Core.registerUiWindow(window)
		Core.flushPendingNotifications()
		function window:AddTab(name, icon)
			if not self._rawWindow then
				return nil
			end
			if type(self._rawWindow.AddTab) == "function" then
				return self._rawWindow:AddTab(name, icon)
			end
			if type(self._rawWindow.CreatePage) == "function" then
				return self._rawWindow:CreatePage({ Name = name, Icon = iconId(icon), Columns = 2 })
			end
			return nil
		end
		function window:Toggle()
			if self._rawWindow and self._rawWindow.Toggle then
				self._rawWindow:Toggle()
			elseif self._rawWindow and self._rawWindow.SetOpen then
				self._rawWindow:SetOpen(not self._rawWindow.IsOpen)
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
		local requested = math.max(1, tonumber(columns) or 2)
		local pageColumns = math.max(1, requested)
		local rawPage
		if type(window._rawWindow.CreatePage) == "function" then
			rawPage = window._rawWindow:CreatePage({
				Name = name,
				Icon = iconId(icon),
				Columns = pageColumns,
			})
		elseif type(window._rawWindow.AddTab) == "function" then
			rawPage = window._rawWindow:AddTab(name, iconId(icon))
		end
		local wrapped = Core.wrapUiTab(rawPage, window._ui or (type(section) == "table" and section._ui) or nil, window)
		wrapped._columnCount = requested
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
		local lib = ui and (ui.Library or ui.Alleral)
		if type(window) == "table" and window._rawWindow and not window._initialized then
			window._initialized = true
			task.defer(function()
				pcall(function()
					if type(window._rawWindow.Init) == "function" then
						window._rawWindow:Init()
					end
				end)
			end)
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
