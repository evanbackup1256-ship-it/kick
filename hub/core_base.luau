local Core = {}
Core.VERSION = "2.9.4"
Core._CORE_ARTIFACT = "base"
Core.UI_LIBRARY = "Alleral"
Core.ALLERAL_UI_VERSION = "3.0.3-maclib"
Core.WINDUI_VERSION = Core.ALLERAL_UI_VERSION

local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local function safeHex(hex, fallback)
	fallback = fallback or Color3.fromRGB(83, 252, 24)
	if Color3.fromHex then
		local ok, color = pcall(Color3.fromHex, hex)
		if ok and typeof(color) == "Color3" then
			return color
		end
	end
	local raw = tostring(hex or ""):gsub("#", "")
	if #raw >= 6 then
		return Color3.fromRGB(
			tonumber(raw:sub(1, 2), 16) or 255,
			tonumber(raw:sub(3, 4), 16) or 255,
			tonumber(raw:sub(5, 6), 16) or 255
		)
	end
	return fallback
end

local ALLERAL_ACCENT = safeHex("#53fc18")
local ALLERAL_ACCENT_ALT = safeHex("#30ff6a")

-- Keep in sync with loader.luau GAMES (place/universe ids for runtime resolution).
Core.GAME_REGISTRY = {
	kick_a_lucky_block = {
		name = "Kick a Lucky Block",
		placeIds = { 89469502395769 },
		universeIds = { 10004244222 },
	},
	speed_keyboard_escape = {
		name = "Speed Keyboard Escape",
		placeIds = { 95082159892680 },
	},
	slime_rng = {
		name = "Slime RNG",
		placeIds = { 92416421522960 },
		universeIds = { 9792947201 },
	},
	build_a_ring_farm = {
		name = "Build A Ring Farm",
		placeIds = { 107646426076756 },
	},
	survive_a_zombie_arena = {
		name = "Survive a Zombie Arena",
		placeIds = { 114204398207377 },
	},
}

function Core.resolveActiveGameId(options)
	options = type(options) == "table" and options or {}
	local explicit = options.scriptId or options.gameId or options.id
	if explicit and tostring(explicit) ~= "" then
		return tostring(explicit)
	end
	if ENV.Alleral_ActiveScriptId and tostring(ENV.Alleral_ActiveScriptId) ~= "" then
		return tostring(ENV.Alleral_ActiveScriptId)
	end
	local placeId = game.PlaceId
	local universeId = game.GameId
	for gameId, meta in pairs(Core.GAME_REGISTRY) do
		if type(meta.placeIds) == "table" then
			for _, pid in ipairs(meta.placeIds) do
				if pid == placeId then
					return gameId
				end
			end
		end
		if type(meta.universeIds) == "table" then
			for _, uid in ipairs(meta.universeIds) do
				if uid == universeId then
					return gameId
				end
			end
		end
	end
	return nil
end

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()
local LOG_TAG = "[Alleral]"

function Core.say(msg)
	print(LOG_TAG .. " " .. tostring(msg))
end

function Core.logWarn(msg)
	warn(LOG_TAG .. " " .. tostring(msg))
end

function Core.assertLoader()
	if not getgenv().Alleral_Boot then
		Core.logWarn("run the loader before this script")
		return false
	end
	getgenv().Alleral_Boot = nil
	return true
end

function Core.boot(state)
	local priorCore = ENV.Alleral_Core or getgenv().Alleral_Core
	state = state or ENV.Alleral_State or getgenv().Alleral_State
	if type(state) ~= "table" then
		if priorCore then
			return priorCore, nil, "state missing"
		end
		return nil, nil, "state missing"
	end
	if type(state.Alleral_Unload) == "function" then
		pcall(state.Alleral_Unload)
	end
	if type(Core.prepareGame) ~= "function" then
		if priorCore then
			return priorCore, nil, "core missing"
		end
		return nil, nil, "core missing"
	end
	local core, ui, msg = Core.prepareGame(state)
	if not core then
		core = priorCore or ENV.Alleral_Core or getgenv().Alleral_Core
	end
	return core, ui, msg
end

function Core.safeCall(scope, fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local packed = table.pack(pcall(fn, ...))
	if packed[1] then
		return table.unpack(packed, 2, packed.n)
	end
	local err = packed[2]
	if Core.pushErrorLog then
		Core.pushErrorLog(tostring(scope or "Core"), err)
	else
		ENV.Alleral_ErrorLog = ENV.Alleral_ErrorLog or {}
		table.insert(ENV.Alleral_ErrorLog, 1, {
			at = os.date("%H:%M:%S"),
			scope = tostring(scope or "Core"),
			message = tostring(err or "?"),
		})
	end
	Core.reportError(tostring(scope or "Core"), err)
	Core.logWarn(tostring(scope or "Core") .. ": " .. tostring(err))
	return nil
end

function Core.guard(scope, fn)
	scope = tostring(scope or "Core")
	return function(...)
		return Core.safeCall(scope, fn, ...)
	end
end

function Core.coerceSettingsTable(decoded, keys, defaults)
	if type(decoded) ~= "table" then
		return nil
	end
	local output = {}
	for _, key in ipairs(keys or {}) do
		if decoded[key] ~= nil then
			output[key] = decoded[key]
		elseif type(defaults) == "table" and defaults[key] ~= nil then
			output[key] = Core.copyValue(defaults[key])
		end
	end
	return output
end

function Core.restoreSettingsFromBackup(filename, state, keys, defaults)
	local listFiles = Core.execFunction("listfiles")
	local readFile = Core.execFunction("readfile")
	local isFile = Core.execFunction("isfile")
	if type(listFiles) ~= "function" or type(readFile) ~= "function" or type(isFile) ~= "function" then
		return false
	end
	local base = tostring(filename or "settings.json"):gsub("%.json$", ""):gsub("[^%w%-_]", "_")
	local matches = {}
	for _, filePath in ipairs(listFiles("Alleral_Configs/backups")) do
		local name = tostring(filePath):match("([^/\\]+)$")
		if name and name:find("^" .. base .. "_", 1, true) then
			table.insert(matches, tostring(filePath))
		end
	end
	table.sort(matches, function(a, b)
		return a > b
	end)
	for _, backupPath in ipairs(matches) do
		if isFile(backupPath) then
			local raw = readFile(backupPath)
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			local coerced = Core.coerceSettingsTable(decoded, keys, defaults)
			if coerced then
				for _, key in ipairs(keys) do
					if coerced[key] ~= nil then
						state[key] = Core.copyValue(coerced[key])
					end
				end
				return true
			end
		end
	end
	return false
end

function Core.installResilience()
	if ENV._Alleral_CoreResilience then
		return
	end
	ENV._Alleral_CoreResilience = true
	local guarded = {
		"prepareGame",
		"loadUi",
		"preloadUi",
		"buildUiWindow",
		"buildUiTab",
		"buildUiGroup",
		"saveSettings",
		"loadSettings",
		"initSettings",
		"makeSupervisor",
		"fetchScriptManifest",
		"fetchWeaoExploits",
		"fetchWeaoExecutorStatus",
		"buildHubActionsGroup",
		"buildThemeStudioGroup",
		"buildCustomizationStudioGroup",
		"buildSystemPanelGroup",
		"buildAdvancedHubGroup",
		"buildStandardSettingsExtras",
		"resolveActiveGameId",
		"buildUiPreferencesGroup",
		"buildConfigProfileGroup",
		"buildCloudConfigStudio",
		"buildCloudConfigTab",
		"repairUiWindow",
		"finalizeGameUi",
		"gameUiSettings",
		"buildScriptStatusGroupbox",
		"postWebhook",
		"writeFile",
	}
	for _, name in ipairs(guarded) do
		local fn = Core[name]
		if type(fn) == "function" and Core["_raw_" .. name] == nil then
			Core["_raw_" .. name] = fn
			Core[name] = Core.guard(name, fn)
		end
	end
end

function Core.getWindUi()
	local ui = ENV.Alleral_UI
	if type(ui) ~= "table" then
		return nil
	end
	return ui.Library or ui.Alleral
end

function Core.notifyWindUi(payload)
	local windUi = Core.getWindUi()
	if not windUi then
		return false
	end
	local notifyPayload = type(payload) == "table" and payload or { Description = tostring(payload) }
	if notifyPayload.Content and not notifyPayload.Description then
		notifyPayload.Description = notifyPayload.Content
	end
	if notifyPayload.Duration and not notifyPayload.Lifetime then
		notifyPayload.Lifetime = notifyPayload.Duration
	end
	local ok = false
	if type(windUi.Notify) == "function" then
		ok = pcall(windUi.Notify, windUi, notifyPayload)
	end
	if not ok and type(windUi.Notification) == "function" then
		ok = pcall(windUi.Notification, windUi, notifyPayload)
	end
	return ok == true
end

function Core.queueNotification(payload)
	if type(payload) ~= "table" then
		return
	end
	ENV._AlleralPendingNotifies = ENV._AlleralPendingNotifies or {}
	table.insert(ENV._AlleralPendingNotifies, payload)
end

function Core.flushPendingNotifications()
	local queue = ENV._AlleralPendingNotifies
	if type(queue) ~= "table" or #queue == 0 then
		return
	end
	ENV._AlleralPendingNotifies = {}
	for _, payload in ipairs(queue) do
		Core.notifyWindUi(payload)
	end
end

function Core.notifyBootReady(settings)
	settings = type(settings) == "table" and settings or {}
	local profile = Core.executorProfile()
	local scriptVer = ENV.Alleral_ActiveScriptVersion
		or (type(ENV.Alleral_LoaderMeta) == "table" and ENV.Alleral_LoaderMeta.scriptVersion)
	local loaderVer = ENV.Alleral_LoaderVersion
		or (type(ENV.Alleral_LoaderMeta) == "table" and ENV.Alleral_LoaderMeta.version)
	local lines = {}
	if settings.Subtitle and settings.Subtitle ~= "" then
		table.insert(lines, tostring(settings.Subtitle))
	end
	if scriptVer then
		table.insert(lines, "Script v" .. tostring(scriptVer))
	elseif loaderVer then
		table.insert(lines, "Loader v" .. tostring(loaderVer))
	end
	local keyHint = "Insert"
	if Core.UI_LIBRARY == "Maclib" then
		local key = ENV.Alleral_UiKeybind or ENV.Alleral_MaclibKeybind or Enum.KeyCode.RightControl
		if type(key) == "userdata" and key.Name then
			keyHint = key.Name
		end
	end
	table.insert(lines, profile.displayName .. " ready · " .. keyHint .. " toggles UI · Insert backup toggle")
	Core.notify(settings.Name or "Alleral", table.concat(lines, "\n"), 5, "success")
end

function Core.notify(title, text, duration, notifyType)
	title = title or "Alleral"
	text = text or ""
	duration = duration or 4
	notifyType = notifyType or "info"

	local payload = {
		Title = title,
		Content = text,
		Duration = duration,
		Type = notifyType,
	}

	if Core.notifyWindUi(payload) then
		return
	end

	if Core.getWindUi() then
		Core.queueNotification(payload)
		return
	end

	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration,
		})
	end)
end

function Core.requestFunction()
	local fn = Core.firstExecFunc("request", "http_request", "Request", "httprequest")
	if fn then
		return fn
	end

	local sharedEnv = ENV.shared or (typeof(shared) == "table" and shared) or nil
	local solaraLib = sharedEnv and type(sharedEnv.solara) == "table" and sharedEnv.solara or nil
	local soloraLib = sharedEnv and type(sharedEnv.Solora) == "table" and sharedEnv.Solora or nil
	local candidates = {
		solaraLib and solaraLib.request,
		soloraLib and soloraLib.request,
		type(ENV.Solara) == "table" and ENV.Solara.request or nil,
		type(ENV.Solora) == "table" and ENV.Solora.request or nil,
		type(ENV.syn) == "table" and ENV.syn.request or nil,
		type(ENV.fluxus) == "table" and ENV.fluxus.request or nil,
		type(ENV.http) == "table" and ENV.http.request or nil,
		type(ENV.http_service) == "table" and ENV.http_service.request or nil,
		type(ENV.Xeno) == "table" and ENV.Xeno.request or nil,
		type(ENV.Volt) == "table" and ENV.Volt.request or nil,
		type(ENV.Madium) == "table" and ENV.Madium.request or nil,
		type(ENV.Nihon) == "table" and ENV.Nihon.request or nil,
		type(ENV.Cryptic) == "table" and ENV.Cryptic.request or nil,
		type(ENV.Sentinel) == "table" and ENV.Sentinel.request or nil,
		type(ENV.Serenity) == "table" and ENV.Serenity.request or nil,
		type(ENV.Atlantis) == "table" and ENV.Atlantis.request or nil,
		type(ENV.Zorara) == "table" and ENV.Zorara.request or nil,
		type(ENV.Wave) == "table" and ENV.Wave.request or nil,
		type(ENV.Electron) == "table" and ENV.Electron.request or nil,
		type(ENV.Potassium) == "table" and ENV.Potassium.request or nil,
		type(ENV.Velocity) == "table" and ENV.Velocity.request or nil,
		type(ENV.Krnl) == "table" and ENV.Krnl.request or nil,
		type(ENV.jjsploit) == "table" and ENV.jjsploit.request or nil,
		type(ENV.Bunni) == "table" and ENV.Bunni.request or nil,
		type(ENV.Valyse) == "table" and ENV.Valyse.request or nil,
		type(ENV.Krypton) == "table" and ENV.Krypton.request or nil,
		type(ENV.Evon) == "table" and ENV.Evon.request or nil,
		type(ENV.delta) == "table" and ENV.delta.request or nil,
		type(ENV.celery) == "table" and ENV.celery.request or nil,
		type(ENV.Codex) == "table" and ENV.Codex.request or nil,
		type(ENV.Hydrogen) == "table" and ENV.Hydrogen.request or nil,
		type(ENV.Ronix) == "table" and ENV.Ronix.request or nil,
		type(ENV.Macsploit) == "table" and ENV.Macsploit.request or nil,
		type(ENV.Oxygen) == "table" and ENV.Oxygen.request or nil,
	}
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "function" then
			return candidate
		end
	end
	if type(HttpService.RequestAsync) == "function" then
		return function(opts)
			return HttpService:RequestAsync({
				Url = opts.Url,
				Method = opts.Method or "GET",
				Headers = opts.Headers,
				Body = opts.Body,
			})
		end
	end
	return nil
end

function Core.firstExecFunc(...)
	for index = 1, select("#", ...) do
		local name = select(index, ...)
		if type(name) == "function" then
			return name
		end
		if type(name) == "string" then
			local fn = ENV[name] or (_G and _G[name]) or (getfenv and getfenv()[name])
			if type(fn) == "function" then
				return fn
			end
		end
	end
	return nil
end

function Core.execFunction(name, requireFilesystem)
	if requireFilesystem then
		local profile = Core.executorProfile()
		if not profile.fsOk and not profile.hasFilesystem then
			return nil
		end
	end
	local aliases = Core.EXEC_ALIASES and Core.EXEC_ALIASES[name]
	if aliases then
		for _, alias in ipairs(aliases) do
			local fn = ENV[alias]
			if type(fn) ~= "function" then
				fn = Core.firstExecFunc(alias)
			end
			if type(fn) == "function" then
				return fn
			end
		end
	end
	local fn = ENV[name]
	if type(fn) ~= "function" then
		fn = Core.firstExecFunc(name)
	end
	return type(fn) == "function" and fn or nil
end

Core.EXEC_ALIASES = {
	readfile = { "readfile", "read_file", "ReadFile" },
	writefile = { "writefile", "write_file", "WriteFile" },
	isfile = { "isfile", "is_file", "IsFile" },
	listfiles = { "listfiles", "list_files", "ListFiles" },
	makefolder = { "makefolder", "make_folder", "MakeFolder" },
	isfolder = { "isfolder", "is_folder", "IsFolder" },
	loadstring = { "loadstring", "LoadString" },
	setclipboard = { "setclipboard", "toclipboard", "setrbxclipboard" },
	getconnections = { "getconnections", "get_signal_cons" },
	firetouchinterest = { "firetouchinterest", "FireTouchInterest", "touchinterest" },
	identifyexecutor = { "identifyexecutor", "getexecutorname", "whatexecutor", "getexecutor" },
}

local function inferSlugFromText(text)
	local lower = tostring(text or ""):lower()
	local map = {
		{ "synapse z", "synapsez" },
		{ "synapse", "synapsez" },
		{ "potassium", "potassium" },
		{ "matcha", "matcha" },
		{ "photon", "photon" },
		{ "volt", "volt" },
		{ "awp", "volt" },
		{ "velocity", "velocity" },
		{ "solara", "solara" },
		{ "solora", "solara" },
		{ "xeno", "xeno" },
		{ "wave", "wave" },
		{ "delta", "delta" },
		{ "codex", "codex" },
		{ "cryptic", "cryptic" },
		{ "sirhurt", "sirhurt" },
		{ "seliware", "seliware" },
		{ "swift", "swift" },
		{ "volcano", "volcano" },
		{ "electron", "electron" },
		{ "ronin", "ronin" },
		{ "bunni", "bunni" },
		{ "serotonin", "serotonin" },
		{ "cosmic", "cosmic" },
		{ "opiumware", "opiumware" },
		{ "lumen", "lumen" },
		{ "severe", "severe" },
		{ "isaeva", "isaeva" },
		{ "nihon", "nihon" },
		{ "zenith", "zenith" },
		{ "macsploit", "macsploit" },
		{ "vega x", "vegax" },
		{ "vega", "vegax" },
		{ "madium", "madium" },
		{ "rbxcli", "rbxcli" },
		{ "krnl", "krnl" },
		{ "fluxus", "fluxus" },
		{ "jjsploit", "jjsploit" },
		{ "comet", "comet" },
		{ "trigon", "trigon" },
		{ "hydrogen", "hydrogen" },
		{ "arceus", "arceus" },
		{ "oxygen", "oxygenu" },
	}
	for _, pair in ipairs(map) do
		if lower:find(pair[1], 1, true) then
			return pair[2]
		end
	end
	return nil
end

function Core.detectExecutor()
	local rawName = ""
	for _, id in ipairs({
		"identifyexecutor",
		"getexecutorname",
		"whatexecutor",
		"getexecutor",
		"getexecutorinfo",
	}) do
		local fn = Core.firstExecFunc(id)
		if fn then
			local ok, result, version = pcall(fn)
			if ok and type(result) == "string" and result ~= "" then
				rawName = result
				if type(version) == "string" and version ~= "" then
					rawName = rawName .. " " .. version
				end
				break
			end
		end
	end

	local slug = inferSlugFromText(rawName) or rawName:lower():gsub("%s+", ""):match("^[%a][%w%-_%.]*") or ""
	local function hasTable(key)
		local value = ENV[key]
		return type(value) == "table" and value or nil
	end
	local sharedEnv = ENV.shared or (typeof(shared) == "table" and shared) or nil

	if slug == "" then
		if hasTable("syn") and type(ENV.syn.request) == "function" then
			slug = "synapse"
		elseif ENV.KRNL_LOADED == true then
			slug = "krnl"
		elseif hasTable("fluxus") and type(ENV.fluxus.request) == "function" then
			slug = "fluxus"
		elseif hasTable("sw") then
			slug = "scriptware"
		elseif hasTable("celery") then
			slug = "celery"
		elseif hasTable("delta") then
			slug = "delta"
		elseif ENV.OXYGEN_U == true then
			slug = "oxygenu"
		elseif hasTable("Electron") then
			slug = "electron"
		elseif hasTable("Wave") and type(ENV.Wave.setclipboard) == "function" then
			slug = "wave"
		elseif sharedEnv and type(sharedEnv.solara) == "table" then
			slug = "solara"
		elseif sharedEnv and type(sharedEnv.Solora) == "table" then
			slug = "solora"
		elseif hasTable("Solara") or hasTable("solara") then
			slug = "solara"
		elseif hasTable("Solora") or hasTable("solora") then
			slug = "solora"
		elseif hasTable("Xeno") then
			slug = "xeno"
		elseif hasTable("Volt") and type(ENV.Volt.request) == "function" then
			slug = "volt"
		elseif hasTable("Potassium") then
			slug = "potassium"
		elseif hasTable("Madium") then
			slug = "madium"
		elseif hasTable("Velocity") then
			slug = "velocity"
		elseif hasTable("Codex") then
			slug = "codex"
		elseif hasTable("Ronix") then
			slug = "ronix"
		elseif hasTable("Nihon") then
			slug = "nihon"
		elseif hasTable("Vega") or hasTable("VegaX") then
			slug = "vegax"
		elseif hasTable("Comet") then
			slug = "comet"
		elseif hasTable("Trigon") then
			slug = "trigon"
		elseif hasTable("Cryptic") then
			slug = "cryptic"
		elseif hasTable("Hydrogen") then
			slug = "hydrogen"
		elseif hasTable("Sentinel") then
			slug = "sentinel"
		elseif hasTable("Serenity") then
			slug = "serenity"
		elseif hasTable("Atlantis") then
			slug = "atlantis"
		elseif hasTable("Zorara") then
			slug = "zorara"
		elseif hasTable("Aztup") then
			slug = "aztup"
		elseif hasTable("Nixware") then
			slug = "nixware"
		elseif ENV.IS_JJSLOIT == true or hasTable("jjsploit") then
			slug = "jjsploit"
		elseif hasTable("Bunni") or hasTable("bunni") then
			slug = "bunni"
		elseif hasTable("Valyse") or hasTable("valyse") then
			slug = "valyse"
		elseif hasTable("Krypton") or hasTable("krypton") then
			slug = "krypton"
		elseif hasTable("SirHurt") or hasTable("sirhurt") then
			slug = "sirhurt"
		elseif hasTable("Temple") or hasTable("temple") then
			slug = "temple"
		elseif hasTable("Evon") or hasTable("evon") then
			slug = "evon"
		elseif hasTable("AWP") or hasTable("awp") then
			slug = "awp"
		elseif hasTable("Pebble") or hasTable("pebble") then
			slug = "pebble"
		elseif hasTable("Nzxt") or hasTable("nzxt") then
			slug = "nzxt"
		elseif hasTable("Nezur") or hasTable("nezur") then
			slug = "nezur"
		elseif hasTable("Seliware") or hasTable("seliware") then
			slug = "seliware"
		elseif hasTable("Luna") or hasTable("luna") then
			slug = "luna"
		elseif hasTable("Macsploit") or hasTable("macsploit") then
			slug = "macsploit"
		elseif hasTable("Potassium") or hasTable("potassium") then
			slug = "potassium"
		elseif hasTable("Cosmic") or hasTable("cosmic") then
			slug = "cosmic"
		elseif hasTable("Opiumware") or hasTable("opiumware") then
			slug = "opiumware"
		elseif hasTable("Volcano") or hasTable("volcano") then
			slug = "volcano"
		elseif hasTable("Swift") or hasTable("swift") then
			slug = "swift"
		elseif hasTable("Ronin") or hasTable("ronin") then
			slug = "ronin"
		elseif hasTable("Synapse") or ENV.SynapseZ == true then
			slug = "synapsez"
		elseif hasTable("Arceus") or ENV.ARCEUS_LOADED == true then
			slug = "arceus"
		elseif Core.firstExecFunc("queue_on_teleport") and Core.firstExecFunc("getgc") then
			slug = "synapse"
		else
			slug = "unknown"
		end
	end

	if slug == "solora" then
		slug = "solara"
	end

	local display = slug:sub(1, 1):upper() .. slug:sub(2)
	if slug == "synapsez" then
		display = "Synapse Z"
	elseif slug == "synapse" then
		display = "Synapse"
	elseif slug == "jjsploit" then
		display = "JJSploit"
	elseif slug == "solara" then
		display = "Solara"
	elseif slug == "vegax" then
		display = "Vega X"
	elseif slug == "macsploit" then
		display = "MacSploit"
	elseif slug == "oxygenu" then
		display = "Oxygen U"
	elseif slug == "bunni" then
		display = "Bunni"
	end

	return {
		slug = slug,
		name = display,
		rawName = rawName,
		isKnown = slug ~= "unknown",
	}
end

function Core.weaoClient()
	local client = ENV.Alleral_Weao
	if client and type(client.fetchExploits) == "function" then
		return client
	end
	return nil
end

function Core.weaoRequestHeaders()
	local client = Core.weaoClient()
	if client and client.requestHeaders then
		return client.requestHeaders()
	end
	return {
		["User-Agent"] = "WEAO-3PService",
		["Accept"] = "application/json",
		["Cache-Control"] = "no-cache",
	}
end

function Core.fetchWeaoExploits(forceRefresh)
	local Weao = Core.weaoClient()
	if not Weao then
		return nil, "WEAO module missing"
	end
	local profile = Core.detectExecutor()
	return Weao.fetchExploits({
		forceRefresh = forceRefresh == true,
		httpFetch = function(url)
			return Core.httpGet(url)
		end,
		requestFn = Core.requestFunction(),
		config = ENV.Alleral_WeaoConfig or ENV._Alleral_WeaoConfigRemote,
		executorSlug = profile and profile.slug,
	})
end

function Core.formatWeaoEntry(entry)
	local Weao = Core.weaoClient()
	if Weao and Weao.formatEntry then
		return Weao.formatEntry(entry)
	end
	return nil
end

function Core.matchWeaoExploit(profile, exploits)
	local Weao = Core.weaoClient()
	if Weao and Weao.matchExploit then
		return Weao.matchExploit(profile, exploits)
	end
	return nil
end

function Core.fetchWeaoExecutorStatus(profile)
	profile = profile or Core.executorProfile()
	local Weao = Core.weaoClient()
	if not Weao then
		return nil, "WEAO module missing"
	end
	local weao, err = Weao.executorStatus(profile, {
		forceRefresh = false,
		httpFetch = function(url)
			return Core.httpGet(url)
		end,
		requestFn = Core.requestFunction(),
		config = ENV.Alleral_WeaoConfig or ENV._Alleral_WeaoConfigRemote,
	})
	if weao then
		return weao, nil
	end
	return nil, err
end

function Core.weaoStatusLabel(weao)
	local Weao = Core.weaoClient()
	if Weao and Weao.statusLabel then
		return Weao.statusLabel(weao)
	end
	if type(weao) ~= "table" then
		return "Unknown (see docs.weao.xyz)"
	end
	return "Unknown"
end

function Core.normalizeExecutorKey(text)
	local key = tostring(text or ""):lower()
	key = key:gsub("synapse%s*z", "synapsez")
	key = key:gsub("awp%.?gg?", "volt")
	key = key:gsub("bunni%.?fun", "bunni")
	key = key:gsub("vega%s*x", "vegax")
	key = key:gsub("[^a-z0-9]", "")
	return key
end

Core.EXECUTOR_FS_BROKEN = {
	yub = true,
	yubx = true,
	arceus = true,
	vegax = true,
	comet = true,
}

Core.EXECUTOR_COMPAT = {
	synapse = true,
	krnl = true,
	fluxus = true,
	scriptware = true,
	celery = true,
	delta = true,
	oxygenu = true,
	electron = true,
	wave = true,
	solara = true,
	solora = true,
	xeno = true,
	volt = true,
	potassium = true,
	madium = true,
	velocity = true,
	codex = true,
	ronix = true,
	nihon = true,
	trigon = true,
	cryptic = true,
	hydrogen = true,
	sentinel = true,
	serenity = true,
	atlantis = true,
	zorara = true,
	aztup = true,
	nixware = true,
	jjsploit = true,
	bunni = true,
	valyse = true,
	krypton = true,
	sirhurt = true,
	temple = true,
	evon = true,
	awp = true,
	pebble = true,
	nzxt = true,
	nezur = true,
	seliware = true,
	luna = true,
	macsploit = true,
	synapsez = true,
	potassium = true,
	matcha = true,
	photon = true,
	cosmic = true,
	opiumware = true,
	volcano = true,
	swift = true,
	ronin = true,
	serotonin = true,
	lumen = true,
	severe = true,
	isaeva = true,
	rbxcli = true,
	unknown = true,
}

function Core.executorProfile()
	local detected = Core.detectExecutor()
	local slug = detected.slug
	local fsOk = not Core.EXECUTOR_FS_BROKEN[slug]
	local sharedEnv = ENV.shared or (typeof(shared) == "table" and shared) or nil
	local solaraLib = sharedEnv and type(sharedEnv.solara) == "table" and sharedEnv.solara or nil
	local soloraLib = sharedEnv and type(sharedEnv.Solora) == "table" and sharedEnv.Solora or nil

	local hasHttp = Core.requestFunction() ~= nil
	local hasFilesystem = fsOk
		and type(ENV.writefile) == "function"
		and type(ENV.readfile) == "function"
	local hasGetConn = type(ENV.getconnections) == "function" or type(ENV.get_signal_cons) == "function"
	local hasClipboard = type(ENV.setclipboard) == "function"
		or type(ENV.toclipboard) == "function"
		or (type(ENV.Wave) == "table" and type(ENV.Wave.setclipboard) == "function")
		or (type(ENV.Electron) == "table" and type(ENV.Electron.setclipboard) == "function")
	local hasFireTouch = type(ENV.firetouchinterest) == "function"
		or type(ENV.FireTouchInterest) == "function"
		or type(ENV.touchinterest) == "function"

	return {
		name = slug,
		displayName = detected.name,
		rawName = detected.rawName,
		isKnown = detected.isKnown,
		fsOk = fsOk,
		hasFilesystem = hasFilesystem,
		hasHttp = hasHttp,
		hasGetConn = hasGetConn,
		hasClipboard = hasClipboard,
		hasFireTouch = hasFireTouch,
		hasLoadstring = type(ENV.loadstring or loadstring) == "function",
		env = ENV,
		solara = solaraLib ~= nil or soloraLib ~= nil or slug == "solara",
		weao = Core.formatWeaoEntry(Core.matchWeaoExploit(detected, ENV.Alleral_WeaoCache and ENV.Alleral_WeaoCache.data)),
	}
end

function Core.executorTelemetryProfile()
	local profile = Core.executorProfile()
	local apis = {}
	for _, pair in ipairs({
		{ "http_request", "http_request" },
		{ "request", "request" },
		{ "readfile", "readfile" },
		{ "writefile", "writefile" },
		{ "loadstring", "loadstring" },
		{ "getconnections", "getconnections" },
		{ "firetouchinterest", "firetouchinterest" },
		{ "identifyexecutor", "identifyexecutor" },
		{ "gethui", "gethui" },
	}) do
		if type(ENV[pair[2]]) == "function" then
			table.insert(apis, pair[1])
		end
	end
	if profile.solara then
		table.insert(apis, "solara")
	end
	table.sort(apis)
	local loaderCaps = ENV.Alleral_LoaderCapabilities or {}
	return {
		name = profile.displayName,
		version = profile.rawName,
		http = profile.hasHttp or loaderCaps.http == true,
		loadstring = loaderCaps.loadstring == true or type(ENV.loadstring) == "function",
		readfile = profile.hasFilesystem or loaderCaps.readfile == true,
		apis = apis,
		weao = profile.weao,
	}
end

function Core.refreshLoaderCapabilities()
	local profile = Core.executorProfile()
	local caps = {
		executor = profile.displayName,
		executorSlug = profile.name,
		http = profile.hasHttp,
		loadstring = type(ENV.loadstring or loadstring) == "function",
		readfile = profile.hasFilesystem,
		isfile = type(ENV.isfile) == "function",
		listfiles = type(ENV.listfiles) == "function",
		solara = profile.solara,
		hasClipboard = profile.hasClipboard,
		hasFireTouch = profile.hasFireTouch,
		hasGetConn = profile.hasGetConn,
	}
	ENV.Alleral_LoaderCapabilities = caps
	pcall(function()
		if shared then
			shared.Alleral_LoaderCapabilities = caps
		end
	end)
	return caps
end

function Core.notifyExecutorCompat(profile)
	profile = profile or Core.executorProfile()
	local caps = {}
	if profile.hasLoadstring ~= false then
		table.insert(caps, "Lua")
	end
	if profile.hasHttp then
		table.insert(caps, "HTTP")
	end
	if profile.hasFilesystem then
		table.insert(caps, "FS")
	end
	if profile.hasFireTouch then
		table.insert(caps, "Touch")
	end
	if profile.hasGetConn then
		table.insert(caps, "Signals")
	end
	if profile.hasClipboard then
		table.insert(caps, "Clipboard")
	end
	local capText = #caps > 0 and (" | " .. table.concat(caps, ", ")) or ""
	local display = profile.displayName
	local msg = display .. capText
	if profile.weao then
		msg = msg .. " — WEAO: " .. Core.weaoStatusLabel(profile.weao)
		if profile.weao.detected then
			msg = msg .. ". Consider a different executor if you get banned."
		elseif not profile.weao.updateStatus then
			msg = msg .. ". Update your executor for best results."
		end
	elseif not profile.isKnown then
		msg = msg .. " — universal mode (any executor with loadstring)."
	else
		msg = msg .. " — ready."
	end
	Core.say("Executor: " .. msg)
end

local SCRIPT_STATUS_META = {
	working = { label = "Working", icon = "✅" },
	detected = { label = "Detected / unstable", icon = "⚠️" },
	broken = { label = "Broken", icon = "❌" },
	maintenance = { label = "Maintenance", icon = "🛠️" },
	testing = { label = "Testing", icon = "🧪" },
}

function Core.scriptStatusMeta(status)
	return SCRIPT_STATUS_META[tostring(status or ""):lower()] or { label = tostring(status or "Unknown"), icon = "❔" }
end

function Core.defaultScriptManifestUrls()
	local urls = {}
	if ENV.Alleral_ScriptManifestUrl and ENV.Alleral_ScriptManifestUrl ~= "" then
		table.insert(urls, ENV.Alleral_ScriptManifestUrl)
	end
	local ownerCfg = ENV.Alleral_OwnerTelemetry
	if type(ownerCfg) == "table" and type(ownerCfg.relayUrl) == "string" and ownerCfg.relayUrl ~= "" then
		local relay = ownerCfg.relayUrl:gsub("/+$", "")
		table.insert(urls, relay:gsub("/ingest$", "") .. "/scripts")
		if not relay:find("/scripts$") then
			table.insert(urls, relay .. "/scripts")
		end
	end
	table.insert(urls, "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/cfg/scripts_manifest.json")
	table.insert(urls, "https://github.com/evanbackup1256-ship-it/kick/raw/main/cfg/scripts_manifest.json")
	return urls
end

function Core.fetchScriptManifest(forceRefresh)
	local cache = ENV.Alleral_ScriptManifestCache
	if not forceRefresh and type(cache) == "table" and cache.fetchedAt and (tick() - cache.fetchedAt) < 60 then
		return cache.data, nil
	end

	local requestFn = Core.requestFunction()
	local readFileFn = ENV.readfile
	local isFileFn = ENV.isfile
	local lastErr = "Script manifest unavailable"

	for _, path in ipairs({
		"cfg/scripts_manifest.json",
		"config/scripts_manifest.json",
		"kick/cfg/scripts_manifest.json",
		"kick/config/scripts_manifest.json",
	}) do
		if type(readFileFn) == "function" and type(isFileFn) == "function" and isFileFn(path) then
			local ok, raw = pcall(readFileFn, path)
			if ok and type(raw) == "string" and raw ~= "" then
				local decodedOk, decoded = pcall(function()
					return HttpService:JSONDecode(raw)
				end)
				if decodedOk and type(decoded) == "table" then
					ENV.Alleral_ScriptManifestCache = { fetchedAt = tick(), data = decoded, source = "local:" .. path }
					ENV.Alleral_ScriptManifest = decoded
					return decoded, nil
				end
			end
		end
	end

	if requestFn then
		for _, url in ipairs(Core.defaultScriptManifestUrls()) do
			local fetchUrl = url .. (url:find("?") and "&" or "?") .. "t=" .. tostring(math.random(10000, 99999))
			local ok, response = pcall(function()
				return requestFn({
					Url = fetchUrl,
					Method = "GET",
					Headers = { ["Cache-Control"] = "no-cache" },
				})
			end)
			if ok then
				local body = type(response) == "table" and (response.Body or response.body) or (type(response) == "string" and response)
				if type(body) == "string" and body ~= "" and not body:find("404") then
					local decodedOk, decoded = pcall(function()
						return HttpService:JSONDecode(body)
					end)
					if decodedOk and type(decoded) == "table" and type(decoded.scripts) == "table" then
						ENV.Alleral_ScriptManifestCache = { fetchedAt = tick(), data = decoded, source = url }
						ENV.Alleral_ScriptManifest = decoded
						return decoded, nil
					end
				end
			end
			local decoded, jsonErr = Core.httpGetJson(fetchUrl)
			if type(decoded) == "table" and type(decoded.scripts) == "table" then
				ENV.Alleral_ScriptManifestCache = { fetchedAt = tick(), data = decoded, source = url }
				ENV.Alleral_ScriptManifest = decoded
				return decoded, nil
			end
			lastErr = "Manifest fetch failed: " .. url
		end
	end

	if type(cache) == "table" and cache.data then
		return cache.data, lastErr
	end
	return nil, lastErr
end

function Core.getScriptStatus(scriptId, profileVersion)
	scriptId = tostring(scriptId or ENV.Alleral_ActiveScriptId or "")
	local manifest = ENV.Alleral_ScriptManifest
	if not manifest then
		manifest = Core.fetchScriptManifest()
	end
	local entry = manifest and manifest.scripts and manifest.scripts[scriptId]
	if type(entry) ~= "table" then
		return {
			id = scriptId,
			status = "working",
			label = "Working",
			icon = "✅",
			message = "No remote status; local build.",
			version = profileVersion or "?",
		}
	end
	local meta = Core.scriptStatusMeta(entry.status)
	return {
		id = scriptId,
		status = tostring(entry.status or "working"):lower(),
		label = meta.label,
		icon = meta.icon,
		message = tostring(entry.message or ""),
		version = tostring(entry.version or profileVersion or "?"),
		name = tostring(entry.name or scriptId),
		updatedAt = entry.updatedAt,
		updatedBy = entry.updatedBy,
	}
end

function Core.evaluateScriptStatus(scriptId, profileVersion)
	local status = Core.getScriptStatus(scriptId, profileVersion)
	local blocked = status.status == "broken" or status.status == "maintenance"
	local warn = status.status == "detected" or status.status == "testing"
	local force = ENV.Alleral_ForceLoad == true
	return {
		status = status,
		allowed = not blocked or force,
		warn = warn and not blocked,
		force = force,
	}
end


function Core.loadStringFn()
	local candidates = {
		ENV.loadstring,
		ENV.LoadString,
		ENV.load,
		ENV.Load,
		loadstring,
		load,
	}
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "function" then
			return candidate
		end
	end
	return Core.firstExecFunc("loadstring", "LoadString", "load", "Load")
end

function Core.readFile(path)
	local readFile = Core.execFunction("readfile")
	local isFile = Core.execFunction("isfile")
	if type(readFile) ~= "function" or type(isFile) ~= "function" or not isFile(path) then
		return nil
	end
	local ok, data = pcall(readFile, path)
	return ok and data or nil
end

function Core.writeFile(path, data)
	local writeFile = Core.execFunction("writefile")
	local makeFolder = ENV.makefolder
	if type(writeFile) ~= "function" then
		return false
	end
	pcall(function()
		if type(makeFolder) == "function" then
			makeFolder("Alleral_Configs")
		end
	end)
	return pcall(writeFile, path, data)
end

function Core.applyUiLayer(source, label)
	if type(source) ~= "string" or source == "" then
		return false, "empty ui layer"
	end
	local loadFn = Core.loadStringFn()
	if not loadFn then
		return false, "loadstring unavailable"
	end
	local chunk, compileErr = loadFn(source, label or "@Alleral/core_ui")
	if not chunk then
		return false, tostring(compileErr)
	end
	local ok, layer = pcall(chunk)
	if not ok or type(layer) ~= "function" then
		return false, ok and "ui layer must return function(Core)" or tostring(layer)
	end
	local applied, applyErr = pcall(layer, Core)
	if not applied then
		return false, tostring(applyErr)
	end
	Core._UiLayerCount = (Core._UiLayerCount or 0) + 1
	if type(Core.loadUi) == "function"
		and type(Core.buildUiGroup) == "function"
		and type(Core.buildStandardSettingsExtras) == "function" then
		Core._UiLayerReady = true
	end
	return true
end

Core.installResilience()

ENV.Alleral_Core = Core
return Core