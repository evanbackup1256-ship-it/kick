return function(Core)
	Core._AlleralUiLayer = "Alleral Rayfield UI layer"
	Core.ALLERAL_UI_VERSION = Core.ALLERAL_UI_VERSION or "4.0.0-rayfield"
	Core.UI_VERSION = Core.ALLERAL_UI_VERSION
	Core.UI_LIBRARY = "Rayfield"

	local DEFAULT_ICON_ID = "18821914323"
	local ALLERAL_THEMES = { "Default", "DarkBlue", "Ocean", "AmberGlow", "Light", "Amethyst", "Green", "Bloom", "Serenity" }

	local ENV = (function()
		local ok, env = pcall(function() return getgenv and getgenv() or getfenv() end)
		return ok and env or {}
	end)()

	local function safeCall(name, fn)
		local ok, result = pcall(fn)
		if not ok then
			if type(Core.logWarn) == "function" then
				Core.logWarn("[UI] " .. name .. ": " .. tostring(result))
			end
			return nil
		end
		if result == nil then
			if type(Core.logWarn) == "function" then
				Core.logWarn("[UI] " .. name .. " returned nil")
			end
			return nil
		end
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

	local function iconAsset(icon)
		return "rbxassetid://" .. iconImage(icon)
	end

	local function rayfieldIcon(icon)
		if icon == nil or icon == "" then return nil end
		local s = tostring(icon)
		local digits = s:match("^(%d+)$")
		if digits then return nil end
		if s:find("^rbxassetid://") then return nil end
		if s:match("^[%a_%-]+$") then return s end
		if s:match("^rbxthumb://") or s:match("^rbxthumbid://") then return nil end
		return nil
	end

	local function mapTheme(name)
		local n = tostring(name or "Default"):lower()
		for _, theme in ipairs(ALLERAL_THEMES) do
			if theme:lower() == n then return theme end
		end
		if n == "dark" then return "Default" end
		return "Default"
	end

	local function bootRayfield()
		if type(ENV._AlleralRayfield) == "table" and type(ENV._AlleralRayfield.CreateWindow) == "function" then
			if type(Core.say) == "function" then Core.say("[UI] Rayfield already booted, reusing") end
			return ENV._AlleralRayfield
		end

		if type(Core.say) == "function" then Core.say("[UI] Loading Rayfield") end

		local loadStringFn = ENV.loadstring or loadstring or load
		if type(loadStringFn) ~= "function" then
			return nil, "loadstring not available"
		end

		local body
		local sourceLabel = "unknown"
		local maxRetries = 3

		for attempt = 1, maxRetries do
			if type(ENV._AlleralRayfieldBundle) == "string" and #ENV._AlleralRayfieldBundle > 1000 then
				body = ENV._AlleralRayfieldBundle
				sourceLabel = "cached bundle"
			elseif type(ENV._AlleralRayfieldSource) == "string" and #ENV._AlleralRayfieldSource > 1000 then
				body = ENV._AlleralRayfieldSource
				sourceLabel = "loader cache"
			else
				local urls = {
					{ url = "https://sirius.menu/rayfield", name = "primary" },
					{ url = "https://raw.githubusercontent.com/shlexware/Rayfield/main/source", name = "github" },
					{ url = "https://raw.githubusercontent.com/shlexware/Rayfield/main/source.lua", name = "github-lua" },
				}
				for _, entry in ipairs(urls) do
					local bust = "?t=" .. tostring(tick()) .. "&attempt=" .. tostring(attempt)
					if type(game) == "Instance" and type(game.HttpGet) == "function" then
						body = safeCall("HttpGet " .. entry.name, function()
							local ok, b = pcall(game.HttpGet, game, entry.url .. bust, true)
							if ok and type(b) == "string" and #b > 1000 then return b end
							ok, b = pcall(game.HttpGet, game, entry.url .. bust)
							if ok and type(b) == "string" and #b > 1000 then return b end
							return nil
						end)
						if body then sourceLabel = entry.name; break end
					end
					if not body and ENV.Alleral_HTTP and type(ENV.Alleral_HTTP.get) == "function" then
						body = safeCall("Alleral_HTTP " .. entry.name, function()
							return ENV.Alleral_HTTP.get(entry.url .. bust, 5000)
						end)
						if body then sourceLabel = entry.name .. "-http"; break end
					end
					if not body and not ENV._Alleral_InLoaderHttpGet and type(Core.httpGet) == "function" then
						body = safeCall("Core.httpGet " .. entry.name, function()
							return Core.httpGet(entry.url .. bust)
						end)
						if body then sourceLabel = entry.name .. "-core"; break end
					end
				end
			end

			if type(body) == "string" and #body > 1000 then break end

			if ENV._AlleralRayfieldBundle then ENV._AlleralRayfieldBundle = nil end
			if ENV._AlleralRayfieldSource then ENV._AlleralRayfieldSource = nil end
			if attempt < maxRetries then task.wait(0.5 * attempt) end
		end

		if type(body) ~= "string" or #body <= 100 then
			return nil, "Rayfield source unavailable (tried " .. tostring(maxRetries) .. "x, HTTP may be blocked)"
		end

		body = body:gsub("^%s+", ""):gsub("%s+$", "")
		if body:find("<!DOCTYPE", 1, true) or body:find("<html", 1, true) then
			return nil, "Rayfield source is HTML, not Lua (check URL / network)"
		end

		if type(Core.say) == "function" then
			Core.say("[UI] Source Downloaded (" .. tostring(#body) .. "b from " .. sourceLabel .. ")")
		end

		ENV._AlleralRayfieldBundle = body

		local chunk, compileErr = loadStringFn(body, "@Rayfield/source")
		if type(chunk) ~= "function" and type(load) == "function" then
			chunk, compileErr = load(body, "@Rayfield/source")
		end
		if type(chunk) ~= "function" then
			return nil, "Rayfield compile failed: " .. tostring(compileErr)
		end

		if type(Core.say) == "function" then Core.say("[UI] Source Compiled") end

		if setfenv then pcall(setfenv, chunk, ENV) end

		local ok, pkg = pcall(chunk)
		if not ok then
			if ENV._AlleralRayfieldBundle then
				ENV._AlleralRayfieldBundle = nil
				if type(Core.logWarn) == "function" then
					Core.logWarn("[UI Error] Rayfield runtime: " .. tostring(pkg))
					Core.logWarn("[UI Error] " .. tostring(debug.traceback()))
				end
			end
			return nil, "Rayfield runtime: " .. tostring(pkg)
		end

		if type(pkg) ~= "table" or type(pkg.CreateWindow) ~= "function" then
			if type(Core.say) == "function" then
				Core.say("[UI] Rayfield not returned directly (type=" .. type(pkg) .. "), checking globals...")
			end
			local candidates = { rawget(ENV, "Rayfield"), rawget(ENV, "RayfieldLibrary") }
			if typeof(shared) == "table" then
				table.insert(candidates, rawget(shared, "Rayfield"))
			end
			for _, c in ipairs({ rawget(_G, "Rayfield") }) do
				table.insert(candidates, c)
			end
			for _, candidate in ipairs(candidates) do
				if type(candidate) == "table" and type(candidate.CreateWindow) == "function" then
					pkg = candidate
					if type(Core.say) == "function" then Core.say("[UI] Found Rayfield in global scope") end
					break
				end
			end
		end

		if type(pkg) ~= "table" then
			return nil, "Rayfield returned non-table: " .. type(pkg)
		end

		local required = { "CreateWindow", "Notify" }
		for _, m in ipairs(required) do
			if type(pkg[m]) ~= "function" then
				return nil, "Rayfield module missing critical: " .. m
			end
		end

		if type(Core.say) == "function" then Core.say("[UI] Rayfield module booted (v" .. tostring(pkg.Version or "?") .. ")") end

		ENV._AlleralRayfield = pkg
		ENV._AlleralRayfieldBooted = true
		return pkg
	end

	local function createLibrary()
		local Library = {
			Version = Core.ALLERAL_UI_VERSION,
			ALLERAL_UI_VERSION = Core.ALLERAL_UI_VERSION,
		}

		function Library:GetArrrelVersion() return Core.ALLERAL_UI_VERSION end
		function Library:EnsureGuiRoot() return true end
		function Library:ClearNotifications() return 0 end
		function Library:SetNotificationLower() return true end
		function Library:SetNotifyDedupe() return true end
		function Library:SetHaptics() return true end
		function Library:ApplyAccentPreset() return true end
		function Library:SetTheme() return true end
		function Library:CycleTheme() return { Name = "Default" } end
		function Library:ListThemeNames() return ALLERAL_THEMES end
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

		function Library:CreateWindow(settings)
			settings = deepClone(type(settings) == "table" and settings or {})

			if type(Core.say) == "function" then Core.say("[UI] Creating Window") end

			local rf, err = bootRayfield()
			if not rf then
				local msg = "Rayfield boot failed: " .. tostring(err)
				if type(Core.logWarn) == "function" then Core.logWarn(msg) end
				if type(Core.pushErrorLog) == "function" then Core.pushErrorLog("UI", msg) end
				return nil
			end

			assert(type(rf) == "table", "Rayfield is not a table")
			assert(type(rf.CreateWindow) == "function", "Rayfield.CreateWindow missing")

			local title = settings.Title or settings.Name or "Alleral"
			local subtitle = settings.Subtitle or settings.Author or ""
			local icon = rayfieldIcon(settings.Icon)
			local theme = mapTheme(settings.Theme or "Default")
			local configFolder = settings.FileSettings and settings.FileSettings.RootFolder or "Alleral_Configs"
			local configName = settings.FileSettings and settings.FileSettings.ConfigFolder or "Interface"

			local rfWindow
			local windowOk, windowErr = pcall(function()
				rfWindow = rf:CreateWindow({
					Name = title,
					Icon = icon,
					LoadingTitle = title,
					LoadingSubtitle = subtitle,
					Theme = theme,
					DisableRayfieldPrompts = true,
					DisableBuildWarnings = true,
					ConfigurationSaving = {
						Enabled = true,
						FolderName = configFolder,
						FileName = configName,
					},
					KeySystem = false,
					Discord = { Enabled = false },
				})
			end)
			if not windowOk or not rfWindow then
				local msg = "Rayfield CreateWindow failed: " .. tostring(windowErr or "returned nil")
				if type(Core.logWarn) == "function" then Core.logWarn("[UI Error] " .. msg) end
				if type(Core.pushErrorLog) == "function" then Core.pushErrorLog("UI", msg) end
				return nil
			end

			if type(Core.say) == "function" then Core.say("[UI] Window Created") end

			local window = {
				_rfWindow = rfWindow,
				_library = Library,
				_fTabs = {},
				_alleralSettings = settings,
			}

			function window:AddTab(name, icon)
				local iconId = rayfieldIcon(icon)
				local tabOk, rfTab = pcall(function()
					return rfWindow:CreateTab(name, iconId)
				end)
				if tabOk and rfTab then
					table.insert(window._fTabs, rfTab)
					if type(Core.say) == "function" then Core.say("[UI] Tab Registered: " .. tostring(name)) end
				else
					if type(Core.logWarn) == "function" then
						Core.logWarn("[UI Error] Failed to add tab: " .. tostring(name) .. " - " .. tostring(rfTab))
					end
				end
				return rfTab, window
			end

			function window:Notify(payload)
				payload = deepClone(type(payload) == "table" and payload or {})
				if rf and type(rf.Notify) == "function" then
					pcall(function()
						rf:Notify({
							Title = payload.Title or "Alleral",
							Content = payload.Description or payload.Content or "",
							Duration = payload.Lifetime or payload.Duration or 4,
						})
					end)
				end
			end

			function window:SetState(state)
				pcall(function()
					if rfWindow.SetState then rfWindow:SetState(state) end
				end)
			end

			function window:GetState() return true end

			function window:Unload()
				pcall(function()
					if rfWindow.Destroy then rfWindow:Destroy() end
				end)
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
			if type(Core.say) == "function" then Core.say("[UI] UI already loaded, reusing") end
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
		if type(Core.say) == "function" then
			Core.say("[UI] Script Ready - Alleral UI " .. tostring(Library:GetArrrelVersion()) .. " (Rayfield)")
		end
		return bundle
	end

	function Core.preloadUi()
		return Core.loadUi()
	end

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
			Acrylic = extra.Acrylic ~= false,
			TabWidth = tonumber(extra.TabWidth) or 160,
			MinimizeKey = extra.MinimizeKey,
			FileSettings = {
				RootFolder = extra.configFolder or "Alleral_Configs",
				ConfigFolder = extra.FileName or "Interface",
			},
		}
	end

	function Core.createUiGroupbox(section, _uiBundle)
		section = type(section) == "table" and section or {}
		local serial = 0

		local _lookup = nil
		local _probed = false
		local function resolveMethod(names)
			if _lookup == nil then
				_lookup = {}
				local function scan(t)
					if type(t) ~= "table" then return end
					for k, v in pairs(t) do
						if type(v) == "function" then _lookup[k] = v end
					end
					local mt = getrawmetatable and getrawmetatable(t)
					if type(mt) == "table" then
						if type(mt.__index) == "table" then scan(mt.__index)
						elseif type(mt.__index) == "function" then
							local ok, idx = pcall(mt.__index, t, "__alleral_probe__")
							if ok and type(idx) == "table" then scan(idx) end
						end
					end
				end
				if type(section) == "table" then scan(section) end
				if not _probed and type(Core.say) == "function" then
					_probed = true
					local methodNames = {}
					for k in pairs(_lookup) do table.insert(methodNames, k) end
					table.sort(methodNames)
					Core.say("[UI] Tab provides " .. tostring(#methodNames) .. " methods: " .. table.concat(methodNames, ", "):sub(1, 300))
				end
			end
			for _, name in ipairs(names) do
				if _lookup[name] then return _lookup[name], name end
			end
			return nil, nil
		end

		local function safeCreate(name, names, fn)
			local method, found = resolveMethod(names)
			if not method then
				if type(Core.logWarn) == "function" then
					Core.logWarn("[UI] Tab missing methods: " .. table.concat(names, ", ") .. " for " .. name)
				end
				return nil
			end
			return safeCall(name, function()
				return fn(method)
			end)
		end

		local function nextFlag(name, explicit)
			serial = serial + 1
			return explicit or (Core.uiElementId and Core.uiElementId(name) or name) .. "_" .. serial
		end

		local function wrapElement(applySet, meta)
			meta = type(meta) == "table" and meta or {}
			local wrapper = {
				_raw = meta.raw,
				Set = function(_, value)
					if type(value) == "table" then
						applySet(value)
					else
						applySet({ CurrentValue = value })
					end
				end,
			}
			if meta.bindKey and Core.bindUiState then
				Core.bindUiState(meta.bindKey, wrapper, meta.kind or "toggle", meta.raw)
			end
			return wrapper
		end

		local groupbox = {}

		function groupbox:CreateSection(name)
			local method = resolveMethod({ "CreateSection", "AddSection", "NewSection", "Section" })
			if method then pcall(method, section, name) end
			return groupbox
		end

		function groupbox:CreateToggle(settings, id)
			local flag = nextFlag(settings.Name, id)
			local currentVal = settings.Default or settings.CurrentValue or settings.Value
			local raw = safeCreate("CreateToggle " .. tostring(settings.Name), { "CreateToggle", "AddToggle", "NewToggle", "Toggle" }, function(method)
				return method(section, {
					Name = settings.Name or settings.Title or "Toggle",
					Description = settings.Tooltip or settings.Description or "",
					CurrentValue = currentVal == true,
					Callback = settings.Callback or function() end,
					Flag = flag,
				})
			end)
			return wrapElement(function(next)
				if not raw then return end
				local v = next.CurrentValue
				if v == nil then v = next.Value end
				if v == nil then v = next end
				if raw.Set then pcall(raw.Set, raw, v == true) end
				if raw.SetValue then pcall(raw.SetValue, raw, v == true) end
			end, { raw = raw, bindKey = settings.BindKey or settings.StateKey, kind = "toggle" })
		end

		function groupbox:CreateButton(settings, id)
			local name = settings.Name or settings.Title or settings.Text or "Button"
			local desc = settings.Tooltip or settings.Description or ""
			local raw = safeCreate("CreateButton " .. tostring(name), { "CreateButton", "AddButton", "NewButton", "Button" }, function(method)
				return method(section, {
					Name = name,
					Description = desc,
					Callback = settings.Callback or function() end,
				})
			end)
			return wrapElement(function() end, { raw = raw, kind = "button" })
		end

		function groupbox:CreateSlider(settings, id)
			local range = settings.Range or { 0, 100 }
			local flag = nextFlag(settings.Name, id)
			local currentVal = tonumber(settings.Default) or tonumber(settings.CurrentValue) or tonumber(settings.Value) or range[1]
			local raw = safeCreate("CreateSlider " .. tostring(settings.Name), { "CreateSlider", "AddSlider", "NewSlider", "Slider" }, function(method)
				return method(section, {
					Name = settings.Name or settings.Title or "Slider",
					Description = settings.Tooltip or settings.Description or "",
					Range = { range[1] or 0, range[2] or 100 },
					Increment = tonumber(settings.Increment) or 1,
					Suffix = settings.Suffix or "",
					CurrentValue = currentVal,
					Callback = settings.Callback or function() end,
					Flag = flag,
				})
			end)
			return wrapElement(function(next)
				if not raw then return end
				local v = tonumber(next.CurrentValue)
				if v == nil then v = tonumber(next.Value) end
				if v == nil then v = tonumber(next) end
				if v == nil then return end
				if raw.Set then pcall(raw.Set, raw, v) end
				if raw.SetValue then pcall(raw.SetValue, raw, v) end
			end, { raw = raw, bindKey = settings.BindKey or settings.StateKey, kind = "slider" })
		end

		function groupbox:CreateInput(settings, id)
			local flag = nextFlag(settings.Name, id)
			local currentVal = tostring(settings.CurrentValue or settings.Default or settings.Value or "")
			local raw = safeCreate("CreateInput " .. tostring(settings.Name), { "CreateInput", "AddInput", "NewInput", "Input", "TextBox" }, function(method)
				return method(section, {
					Name = settings.Name or settings.Title or "Input",
					Description = settings.Tooltip or settings.Description or "",
					CurrentValue = currentVal,
					PlaceholderText = settings.PlaceholderText or settings.Placeholder or "Enter text...",
					RemoveTextAfterFocusLost = false,
					Callback = settings.Callback or function() end,
					Flag = flag,
				})
			end)
			return wrapElement(function(next)
				if not raw then return end
				local v = next.CurrentValue
				if v == nil then v = next.Value end
				if v == nil then v = tostring(next) end
				if raw.Set then pcall(raw.Set, raw, tostring(v)) end
				if raw.SetValue then pcall(raw.SetValue, raw, tostring(v)) end
			end, { raw = raw, bindKey = settings.BindKey or settings.StateKey, kind = "input" })
		end

		function groupbox:CreateDropdown(settings, id)
			local values = settings.Options or settings.Values or {}
			local multi = settings.MultipleOptions == true or settings.Multi == true
			local current = settings.CurrentOption or (multi and {} or (values[1] or ""))
			local flag = nextFlag(settings.Name, id)
			local raw = safeCreate("CreateDropdown " .. tostring(settings.Name), { "CreateDropdown", "AddDropdown", "NewDropdown", "Dropdown" }, function(method)
				return method(section, {
					Name = settings.Name or settings.Title or "Dropdown",
					Description = settings.Tooltip or settings.Description or "",
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
			end)
			return wrapElement(function(next)
				if not raw then return end
				local nextValues = next.Options or next.Values
				local pick = next.CurrentOption or next.CurrentOptions
				if type(nextValues) == "table" then
					if raw.Refresh then pcall(raw.Refresh, raw, nextValues) end
				end
				if pick ~= nil then
					if multi then
						local v = type(pick) == "table" and pick[1] or pick
						if raw.Set then pcall(raw.Set, raw, tostring(v)) end
					else
						if raw.Set then pcall(raw.Set, raw, tostring(pick)) end
					end
				end
			end, { raw = raw, bindKey = settings.BindKey or settings.StateKey, kind = "dropdown" })
		end

		function groupbox:CreateLabel(settings, id)
			local text = type(settings) == "table" and (settings.Name or settings.Text) or tostring(settings or "")
			local raw = nil
			if section and type(section.CreateLabel) == "function" then
				raw = safeCall("CreateLabel", function()
					return section:CreateLabel(text)
				end)
			end
			if not raw and section and type(section.CreateParagraph) == "function" then
				raw = safeCall("CreateParagraph", function()
					return section:CreateParagraph({ Title = "", Content = text })
				end)
			end
			return {
				Set = function(_, nextSettings)
					local nextText = type(nextSettings) == "table" and (nextSettings.Name or nextSettings.Text) or tostring(nextSettings or "")
					if not raw then return end
					if raw.SetText then pcall(raw.SetText, raw, nextText) end
					if raw.Set then pcall(raw.Set, raw, nextText) end
				end,
				SetVisible = function(_, visible)
					if raw and raw.Visible ~= nil then raw.Visible = visible == true end
				end,
			}
		end

		function groupbox:CreateDivider()
			return {}
		end

		function groupbox:CreateStatus(label, fields)
			local status = { Labels = {}, LastValues = {}, Visible = true }
			for key, value in pairs(fields or {}) do
				status.LastValues[key] = tostring(value)
				status.Labels[key] = groupbox:CreateLabel(
					{ Name = tostring(key) .. ": " .. tostring(value) },
					nextFlag(label .. "_" .. tostring(key))
				)
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

		return groupbox
	end

	function Core.wrapUiGroup(groupbox, callbackWrapper)
		local function wrap(label, callback)
			if type(callback) ~= "function" then return function() end end
			if not callbackWrapper then return callback end
			local guarded = function(...)
				local ok, result = pcall(callback, ...)
				if not ok and type(Core.pushErrorLog) == "function" then
					Core.pushErrorLog(label, result)
				end
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
				Name = name, CurrentValue = default == true, Default = default == true,
				Tooltip = tooltip, Callback = wrap(name, callback), BindKey = bindKey,
			}, bindKey)
		end
		function group:CreateSlider(name, min, max, default, callback, tooltip, increment, bindKey)
			return groupbox:CreateSlider({
				Name = name, Range = { min, max }, CurrentValue = default or min, Default = default or min,
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
				CurrentValue = default, Default = default, Tooltip = tooltip,
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
			return Core.createUiGroupbox(rawTab, uiBundle)
		end

		function tab:Select()
			if rawTab and rawTab.Select then pcall(rawTab.Select, rawTab) end
		end

		function tab:BuildThemeGroupbox(column)
			local group = Core.buildUiGroup(tab, "Appearance", column or 1)
			group:CreateLabel("Rayfield native UI engine with config saving.")
			return group
		end

		return tab
	end

	function Core.buildUiWindow(ui, settings)
		settings = settings or {}
		local lib = ui and ui.Library
		if not lib then
			if type(Core.logWarn) == "function" then Core.logWarn("buildUiWindow: ui.Library is nil") end
			return nil
		end
		if type(lib.CreateWindow) ~= "function" then
			if type(Core.logWarn) == "function" then Core.logWarn("buildUiWindow: Library.CreateWindow missing") end
			return nil
		end
		local rawWindow = lib:CreateWindow(settings)
		if not rawWindow then
			if type(Core.logWarn) == "function" then Core.logWarn("buildUiWindow: CreateWindow returned nil") end
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
			if type(Core.logWarn) == "function" then Core.logWarn("buildUiTab: window missing") end
			return Core.wrapUiTab(nil, type(section) == "table" and section._ui or nil, window)
		end
		local tabGroup = window._tabGroup or window
		if not tabGroup or type(tabGroup.AddTab) ~= "function" then
			if type(Core.logWarn) == "function" then Core.logWarn("buildUiTab: tab group missing") end
			return Core.wrapUiTab(nil, window._ui, window)
		end
		local rawTab, _ = tabGroup:AddTab(name, icon)
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

	function Core.buildUiSection(window)
		if type(window) == "table" and window._alleralTabGroup then
			return window._alleralTabGroup
		end
		if type(window) == "table" and window._rawWindow then
			return window
		end
		return window
	end

	function Core.finalizeGameUi(window, ui, options)
		options = type(options) == "table" and options or {}
		if type(window) == "table" and window._rawWindow and not window._initialized then
			window._initialized = true
			task.defer(function()
				pcall(function()
					local rawWindow = window._rawWindow
					if rawWindow and rawWindow.SetState then rawWindow:SetState(true) end
					if rawWindow and rawWindow.Select then rawWindow:Select() end
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

	Core.notifyUi = function(info)
		local ui = ENV.Alleral_UI
		if ui and type(ui.Notify) == "function" then pcall(ui.Notify, ui, info) end
	end

	Core.releaseAlleralRuntime = function()
		ENV._AlleralUiLibrary = nil
		ENV._AlleralRayfield = nil
		ENV._AlleralRayfieldBundle = nil
		ENV.Alleral_UiWindow = nil
	end
end
