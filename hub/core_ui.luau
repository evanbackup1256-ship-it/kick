return function(Core)
	local HttpService = game:GetService("HttpService")
	local StarterGui = game:GetService("StarterGui")

	local function genv()
		local ok, env = pcall(function()
			return getgenv and getgenv() or getfenv()
		end)
		return ok and env or {}
	end
	local ENV = genv()

	Core.httpGet = Core.httpGet or function(url)
		if type(ENV.Alleral_HTTP) == "table" and type(ENV.Alleral_HTTP.get) == "function" then
			return ENV.Alleral_HTTP.get(url)
		end
		return nil
	end

	local function signalBootFailure(msg)
		ENV.Alleral_StartupFailed = msg
	end

	function Core.prepareGame(state)
		state = state or ENV.Alleral_State
		if not state then
			local msg = "Alleral_State missing"
			signalBootFailure(msg)
			return nil, nil, msg
		end
		local security = ENV.Alleral_Security
		if type(security) == "table" and type(security.enforce) == "function" then
			local ok, reason = security.enforce({ stage = "prepareGame" })
			if not ok then
				local msg = tostring(reason or "Access denied")
				signalBootFailure(msg)
				return nil, nil, msg
			end
		end
		local core = Core.ensureCore and Core.ensureCore() or Core
		if not core then
			local msg = "Core not loaded"
			signalBootFailure(msg)
			return nil, nil, msg
		end
		for _, fnName in ipairs({ "buildUiWindow", "buildUiTab", "buildUiGroup", "wrapUiGroup", "createUiGroupbox" }) do
			if type(core[fnName]) ~= "function" then
				local msg = "Core outdated -- missing " .. fnName
				signalBootFailure(msg)
				return nil, nil, msg
			end
		end
		state.HubRunning = true
		if type(core.initAnalytics) == "function" then
			core.initAnalytics()
		end
		if type(core.installErrorLogHook) == "function" then
			core.installErrorLogHook()
		end
		if state.AntiAFK ~= false and type(core.setupAntiAfk) == "function" then
			core.setupAntiAfk(game:GetService("Players").LocalPlayer)
		end
		local cachedUi = ENV.Alleral_UI
		local uiLibrary = type(cachedUi) == "table" and type(cachedUi.Library) == "table" and cachedUi or nil
		local err
		if not uiLibrary then
			uiLibrary, err = core.loadUi()
		end
		if not uiLibrary then
			local msg = err or "UI unavailable"
			signalBootFailure(msg)
			return core, nil, msg
		end
		pcall(function()
			if core.refreshLoaderCapabilities then
				core.refreshLoaderCapabilities()
			end
			if core.fetchScriptManifest then
				core.fetchScriptManifest(false)
			end
			if core.fetchWeaoExploits then
				task.spawn(function()
					core.fetchWeaoExploits(false)
					if core.refreshLoaderCapabilities then
						core.refreshLoaderCapabilities()
					end
				end)
			end
			if core.notifyExecutorCompat then
				core.notifyExecutorCompat()
			end
		end)
		if type(ENV._Alleral_EnsureTeleportWatch) == "function" then
			pcall(ENV._Alleral_EnsureTeleportWatch)
		end
		return core, uiLibrary
	end

	function Core.wireTeleportRelaunch(state)
		state = state or ENV.Alleral_State
		if state then
			state.HubRunning = true
		end
		if type(ENV._Alleral_EnsureTeleportWatch) == "function" then
			pcall(ENV._Alleral_EnsureTeleportWatch)
		end
	end

	function Core.stopAutomation(state, connections, loopControllers, loops, onStop)
		state.HubRunning = false
		for name, controller in pairs(loopControllers or {}) do
			if controller then
				controller.enabled = false
			end
			loopControllers[name] = nil
		end
		for _, loopState in pairs(loops or {}) do
			loopState.enabled = false
		end
		for key, connection in pairs(connections or {}) do
			if connection and connection.Disconnect then
				pcall(function() connection:Disconnect() end)
			end
			connections[key] = nil
		end
		if onStop then
			pcall(onStop)
		end
		if type(Core.restorePerformanceSettings) == "function" then
			pcall(Core.restorePerformanceSettings)
		end
	end

	function Core.copyValue(value)
		if type(value) ~= "table" then
			return value
		end
		local output = {}
		for key, item in pairs(value) do
			output[key] = Core.copyValue(item)
		end
		return output
	end

	function Core.mergeDefaults(state, defaults)
		for key, value in pairs(defaults or {}) do
			if state[key] == nil then
				state[key] = Core.copyValue(value)
			end
		end
	end

	function Core.buildSavedKeys(defaults, exclude)
		exclude = exclude or { HubRunning = true }
		local keys = {}
		for key in pairs(defaults or {}) do
			if not exclude[key] then
				table.insert(keys, key)
			end
		end
		table.sort(keys)
		return keys
	end

	function Core.initSettings(state, defaults, filename, exclude)
		if type(Core.mergePerformanceDefaults) == "function" then
			Core.mergePerformanceDefaults(defaults)
		end
		Core.mergeDefaults(state, defaults)
		local savedKeys = Core.buildSavedKeys(defaults, exclude)
		if type(Core.loadSettings) == "function" then
			Core.loadSettings(state, savedKeys, filename, defaults)
		end
		local function saveSettings()
			if type(Core.saveSettings) == "function" then
				return Core.saveSettings(state, savedKeys, filename)
			end
			return false
		end
		return saveSettings, savedKeys
	end

	function Core.gameUiSettings(options)
		options = type(options) == "table" and options or {}
		local fileSettings = type(options.FileSettings) == "table" and options.FileSettings or {}
		return {
			Name = options.Name or "Alleral",
			Subtitle = options.Subtitle,
			Icon = options.Icon or "sparkles",
			FileSettings = {
				RootFolder = fileSettings.RootFolder or "Alleral_Configs",
				ConfigFolder = fileSettings.ConfigFolder or options.configFolder or "Interface",
			},
		}
	end

	function Core.settingsExtrasOptions(window, ui, state, savedKeys, saveFn, settingsFile, version, extra)
		extra = type(extra) == "table" and extra or {}
		return {
			state = state,
			savedKeys = savedKeys,
			saveFn = saveFn,
			settingsFile = settingsFile,
			settingsPath = extra.settingsPath,
			version = version,
			window = window,
			uiBundle = ui,
			gameId = extra.gameId,
			scriptId = extra.scriptId,
			onApply = extra.onApply,
			cloudOnlyTab = extra.cloudOnlyTab,
			skipCloudConfig = extra.skipCloudConfig,
			skipHubActions = extra.skipHubActions,
			skipScriptStatus = extra.skipScriptStatus,
		}
	end

	function Core.loadUi()
		return nil, "Alleral UI layer not loaded -- apply hub/alleral_ui.luau"
	end

	function Core.preloadUi()
		return Core.loadUi()
	end

	function Core.createStubUiGroup(name)
		return {
			CreateToggle = function() return { Set = function() end } end,
			CreateSlider = function() return { Set = function() end } end,
			CreateButton = function() return { Set = function() end } end,
			CreateInput = function() return { Set = function() end } end,
			CreateDropdown = function() return { Set = function() end } end,
			CreateLabel = function() return { Set = function() end, SetVisible = function() end } end,
			CreateDivider = function() return {} end,
		}
	end

	function Core.resolveUiWindow(section)
		if type(section) ~= "table" then return nil end
		if section._window then return section._window end
		if type(section._rawWindow) == "table" or type(section.AddTab) == "function" then
			return section
		end
		return nil
	end

	Core.registerUiWindow = Core.registerUiWindow or function(window)
		ENV.Alleral_UiWindow = window
		if getgenv then
			getgenv().Alleral_UiWindow = window
		end
	end

	Core.flushPendingNotifications = Core.flushPendingNotifications or function()
		local ui = ENV.Alleral_UI
		if ui and type(ui.Notify) == "function" and type(ui.ClearNotifications) == "function" then
			ui:ClearNotifications()
		end
	end

	Core.notifyBootReady = Core.notifyBootReady or function(info)
		info = type(info) == "table" and info or {}
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = info.Name or "Alleral",
				Text = (info.Subtitle and ("v" .. tostring(info.Subtitle)) or "Ready"),
				Duration = 2,
			})
		end)
	end

	Core.uiIcon = Core.uiIcon or function(icon)
		return icon
	end

	Core.uiIcon = Core.uiIcon or function(icon)
		return icon
	end

	Core.uiElementId = Core.uiElementId or function(name)
		return tostring(name):gsub("[^%w]", "_"):lower()
	end

	Core.normalizeMultiSelection = Core.normalizeMultiSelection or function(selection)
		if type(selection) == "table" then return selection end
		if type(selection) == "string" and selection ~= "" then return { selection } end
		return {}
	end

	Core.normalizeDropdownValue = Core.normalizeDropdownValue or function(selection, fallback)
		if type(selection) == "table" then return selection[1] or fallback or "" end
		if type(selection) == "string" and selection ~= "" then return selection end
		return fallback or ""
	end

	Core.sliderDisplayPrecision = Core.sliderDisplayPrecision or function(minValue, maxValue, increment)
		local step = tonumber(increment)
		if step and step >= 1 then return 0 end
		local range = math.abs((maxValue or 100) - (minValue or 0))
		if range <= 1 then return 3 end
		if range <= 10 then return 2 end
		return 1
	end

	Core.bindUiState = Core.bindUiState or function(key, wrapper, kind, raw) end

	Core.clearUiStateBindings = Core.clearUiStateBindings or function() end

	Core._UiTabRegistry = Core._UiTabRegistry or {}

	Core.setupHubKeybinds = Core.setupHubKeybinds or function() end

	Core.registerExploitCommandPalette = Core.registerExploitCommandPalette or function() end
end
