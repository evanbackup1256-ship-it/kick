local Core = {}
Core.VERSION = "2.7.0"
Core.UI_LIBRARY = "WindUI"
Core.WINDUI_VERSION = "1.6.64-fix-aller17"

local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local WINDUI_MIRROR_URLS = {
	"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/ui/windui/",
	"https://github.com/evanbackup1256-ship-it/kick/raw/main/ui/windui/",
	"https://github.com/Footagesus/WindUI/releases/download/1.6.64-fix/",
	"https://raw.githubusercontent.com/Footagesus/WindUI/1.6.64-fix/dist/",
}
local WINDUI_LOCAL_ROOTS = {
	"ui/windui/",
	"kick/ui/windui/",
	"kick/kick/ui/windui/",
	"vendor/windui/",
	"windui/",
}
local WINDUI_FILE = "main.lua"
local WINDUI_PATCH_FILE = "aller.luau"
local WINDUI_MIN_BYTES = 50000
local ALLERAL_ACCENT = Color3.fromHex("#53fc18")
local ALLERAL_ACCENT_ALT = Color3.fromHex("#30ff6a")

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
	state = state or ENV.Alleral_State or getgenv().Alleral_State
	if type(state) ~= "table" then
		return nil, nil, "state missing"
	end
	if type(state.Alleral_Unload) == "function" then
		pcall(state.Alleral_Unload)
	end
	if type(Core.prepareGame) ~= "function" then
		return nil, nil, "core missing"
	end
	return Core.prepareGame(state)
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
		"buildStandardSettingsExtras",
		"buildUiPreferencesGroup",
		"buildConfigProfileGroup",
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
	local ui = ENV.Alleral_UI or ENV.Alleral_Rayfield
	if type(ui) ~= "table" then
		return nil
	end
	return ui.WindUI or ui.Library
end

function Core.notifyWindUi(payload)
	local windUi = Core.getWindUi()
	if not windUi or type(windUi.Notify) ~= "function" then
		return false
	end
	local ok = pcall(function()
		windUi:Notify(payload)
	end)
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
	table.insert(lines, profile.displayName .. " ready · tabs on the left")
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

function Core.buildScriptStatusGroupbox(tab, column, scriptId, profileVersion)
	scriptId = scriptId or ENV.Alleral_ActiveScriptId
	local evaluation = Core.evaluateScriptStatus(scriptId, profileVersion)
	local status = evaluation.status
	local groupbox = tab:CreateGroupbox({
		Name = "Script status",
		Column = column or 1,
		Icon = 6031075938,
	}, "ScriptStatus")

	local labels = {}
	local function addRow(key, value)
		labels[key] = groupbox:CreateLabel({
			Name = tostring(key) .. ": " .. tostring(value),
		}, "Status_" .. tostring(key))
	end

	addRow("Status", status.icon .. " " .. status.label)
	addRow("Script", status.name)
	addRow("Version", status.version)
	addRow("Executor", (Core.executorProfile().displayName))
	addRow("Access", "Public · no key required")
	local weao = Core.fetchWeaoExecutorStatus()
	if weao then
		addRow("WEAO", Core.weaoStatusLabel(weao))
		if weao.version then
			addRow("Exec version", tostring(weao.version))
		end
	end
	if status.message ~= "" then
		addRow("Notice", status.message)
	end
	if evaluation.force then
		addRow("Force load", "Enabled")
	end

	if not evaluation.allowed then
		groupbox:CreateToggle({
			Name = "Force load anyway",
			Value = ENV.Alleral_ForceLoad == true,
			Tooltip = "Skip maintenance gate this session.",
			Callback = function(value)
				ENV.Alleral_ForceLoad = value == true
				getgenv().Alleral_ForceLoad = value == true
				Core.notify("Alleral", value and "force load on — reload to use it" or "force load off", 4)
			end,
		}, "ForceLoadToggle")
	end

	groupbox:CreateButton({
		Name = "Refresh status",
		Callback = function()
			Core.fetchScriptManifest(true)
			Core.fetchWeaoExploits(true)
			local nextEval = Core.evaluateScriptStatus(scriptId, profileVersion)
			local nextStatus = nextEval.status
			if labels.Status and labels.Status.Set then
				labels.Status:Set({ Name = "Status: " .. nextStatus.icon .. " " .. nextStatus.label })
			end
			if labels.Notice and nextStatus.message ~= "" then
				labels.Notice:Set({ Name = "Notice: " .. nextStatus.message })
			end
			local refreshedWeao = Core.fetchWeaoExecutorStatus()
			if refreshedWeao and labels.WEAO and labels.WEAO.Set then
				labels.WEAO:Set({ Name = "WEAO: " .. Core.weaoStatusLabel(refreshedWeao) })
			end
			Core.notify("Alleral", "status: " .. nextStatus.label, 3)
		end,
	}, "RefreshStatus")

	Core._scriptStatusUI = {
		groupbox = groupbox,
		labels = labels,
		scriptId = scriptId,
		profileVersion = profileVersion,
	}
	return groupbox, evaluation
end

function Core.buildHubActionsGroup(tab, column)
	local groupbox = tab:CreateGroupbox({
		Name = "Hub controls",
		Column = column or 2,
		Icon = 6031075938,
	}, "HubActions")
	local group = Core.wrapUiGroup(groupbox)

	group:CreateButton("Reload script", function()
		local reload = getgenv().Alleral_Reload
		if type(reload) == "function" then
			Core.notify("Alleral", "reloading...", 3)
			task.defer(reload)
		else
			Core.notify("Alleral", "can't reload here — run the loadstring again", 5)
		end
	end, "Runs getgenv().Alleral_Reload().")

	group:CreateButton("Check for update", function()
		local check = getgenv().Alleral_CheckUpdate
		if type(check) == "function" then
			check()
		else
			Core.notify("Alleral", "Update check unavailable.", 4)
		end
	end, "Pulls the latest loader/core from GitHub.")

	group:CreateButton("Stop automation", function()
		stateHubStop()
	end, "Stops loops without closing the UI.")

	group:CreateButton("Purge cache", function()
		local purge = getgenv().Alleral_PurgeCache
		if type(purge) == "function" then
			purge()
			Core.notify("Alleral", "cache cleared", 4)
		else
			Core.notify("Alleral", "Purge unavailable.", 4)
		end
	end, "Clears cached hub files and reloads fresh.")

	group:CreateButton("Sync WEAO config", function()
		Core.syncWeaoConfigNow()
	end, "Pulls the latest WEAO API endpoints without reloading.")

	group:CreateButton("Copy JobId", function()
		Core.copyJobId()
	end, "Copies this server's JobId to clipboard.")

	group:CreateButton("Copy join link", function()
		Core.copyPlaceJoinLink()
	end, "Copies a roblox:// link for this server.")

	group:CreateButton("Copy web join link", function()
		Core.copyWebJoinLink()
	end, "Copies the https:// join link for this server.")

	group:CreateButton("Rejoin server", function()
		Core.rejoinServer()
	end, "Teleports you back into this same server instance.")

	Core.buildJoinServerControls(group, { dividerFirst = true })

	return group
end

local ERROR_LOG_MAX = 40
ENV.Alleral_ErrorLog = ENV.Alleral_ErrorLog or {}

function Core.pushErrorLog(scope, err, details)
	local entry = {
		at = os.date("%H:%M:%S"),
		scope = tostring(scope or "Runtime"),
		message = tostring(err or "?"),
		details = details and tostring(details) or nil,
	}
	local log = ENV.Alleral_ErrorLog
	table.insert(log, 1, entry)
	while #log > ERROR_LOG_MAX do
		table.remove(log)
	end
	if Core._errorLogStatus then
		pcall(function()
			Core._errorLogStatus:Update("Latest", entry.scope .. ": " .. entry.message:sub(1, 80))
			Core._errorLogStatus:Update("Count", tostring(#log))
		end)
	end
end

function Core.installErrorLogHook()
	if ENV._Alleral_ErrorLogHooked then
		return
	end
	ENV._Alleral_ErrorLogHooked = true
	local previous = ENV.Alleral_ReportError
	ENV.Alleral_ReportError = function(scope, err, details)
		Core.pushErrorLog(scope, err, details)
		if type(previous) == "function" then
			pcall(previous, scope, err, details)
		end
	end
	getgenv().Alleral_ReportError = ENV.Alleral_ReportError
end

function Core.getErrorLogText(limit)
	limit = limit or 20
	local lines = {}
	for index, entry in ipairs(ENV.Alleral_ErrorLog or {}) do
		if index > limit then
			break
		end
		table.insert(lines, string.format("[%s] %s: %s", entry.at, entry.scope, entry.message))
	end
	return #lines > 0 and table.concat(lines, "\n") or "No errors logged this session."
end

function Core.registerUiWindow(window)
	if type(window) == "table" and window._rawWindow then
		ENV.Alleral_UiWindow = window
		getgenv().Alleral_UiWindow = window
	end
	return window
end

Core._UiStateBindings = Core._UiStateBindings or {}

function Core.clearUiStateBindings()
	Core._UiStateBindings = {}
end

function Core.bindUiState(stateKey, widget, kind, rawHandle)
	if type(stateKey) ~= "string" or stateKey == "" then
		return widget
	end
	Core._UiStateBindings[stateKey] = {
		widget = widget,
		kind = kind or "toggle",
		raw = rawHandle,
	}
	return widget
end

function Core.sliderIncrement(minValue, maxValue, explicit)
	if explicit ~= nil then
		return explicit
	end
	minValue = tonumber(minValue) or 0
	maxValue = tonumber(maxValue) or 100
	local range = maxValue - minValue
	if range <= 0 then
		return 1
	end
	if range <= 1 then
		return 0.01
	end
	if range <= 5 then
		return 0.05
	end
	if range <= 10 then
		return 0.1
	end
	if range <= 50 then
		return 0.5
	end
	if range <= 200 then
		return 1
	end
	return math.max(1, math.floor(range / 80))
end

function Core.syncUiState(state, options)
	if type(state) ~= "table" then
		return 0
	end
	options = type(options) == "table" and options or {}
	local synced = 0
	for key, entry in pairs(Core._UiStateBindings or {}) do
		local value = state[key]
		if value ~= nil then
			local raw = entry.raw
			if not raw and type(entry.widget) == "table" then
				raw = entry.widget._raw
			end
			if entry.kind == "toggle" and raw and type(raw.Set) == "function" then
				pcall(function()
					local prev = raw.Callback
					raw.Callback = function() end
					raw:Set(value == true, nil, false)
					raw.Callback = prev
				end)
				synced += 1
			elseif entry.kind == "slider" and raw and type(raw.Set) == "function" then
				pcall(function()
					local prev = raw.Callback
					raw.Callback = function() end
					raw:Set(tonumber(value) or 0)
					raw.Callback = prev
				end)
				synced += 1
			elseif entry.kind == "dropdown" and raw then
				pcall(function()
					if raw.Select then
						raw:Select(value)
					elseif raw.Set then
						raw:Set(value)
					elseif entry.widget and entry.widget.Set then
						entry.widget:Set({ CurrentOption = value })
					end
				end)
				synced += 1
			elseif entry.widget and type(entry.widget.Set) == "function" then
				pcall(function()
					if entry.kind == "toggle" then
						entry.widget:Set({ CurrentValue = value == true })
					elseif entry.kind == "slider" then
						entry.widget:Set({ CurrentValue = tonumber(value) or 0 })
					else
						entry.widget:Set({ CurrentOption = value })
					end
				end)
				synced += 1
			end
		end
	end
	if options.notify == true and synced > 0 then
		Core.notify("UI", "Synced " .. tostring(synced) .. " controls.", 2, "info")
	end
	return synced
end

function Core.releaseUiWindow()
	local ui = ENV.Alleral_UI or ENV.Alleral_Rayfield
	local wind = ui and (ui.WindUI or ui.Library)
	if type(wind) == "table" and type(wind.ReleaseWindow) == "function" then
		pcall(function()
			wind:ReleaseWindow(wind.Window)
		end)
	end
	ENV.Alleral_UiWindow = nil
	getgenv().Alleral_UiWindow = nil
end

function Core.toggleUiVisibility()
	local window = ENV.Alleral_UiWindow
	if not window or not window._rawWindow then
		return false
	end
	local raw = window._rawWindow
	if type(raw.Toggle) == "function" then
		pcall(raw.Toggle, raw)
		return true
	end
	return false
end

function Core.setGlobalMusicMuted(muted)
	local SoundService = game:GetService("SoundService")
	if muted then
		if ENV.Alleral_MusicMuted ~= true then
			ENV._Alleral_PrevMasterVolume = SoundService.Volume
		end
		SoundService.Volume = 0
	else
		SoundService.Volume = ENV._Alleral_PrevMasterVolume or 0.5
	end
	ENV.Alleral_MusicMuted = muted == true
end

function Core.setLowGraphics(enabled)
	local Lighting = game:GetService("Lighting")
	local ok, gameSettings = pcall(function()
		return game:GetService("UserSettings"):GetService("UserGameSettings")
	end)
	if enabled then
		ENV._Alleral_PrevShadows = Lighting.GlobalShadows
		Lighting.GlobalShadows = false
		if ok and gameSettings then
			ENV._Alleral_PrevQuality = gameSettings.SavedQualityLevel
			pcall(function()
				gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
			end)
		end
	else
		if ENV._Alleral_PrevShadows ~= nil then
			Lighting.GlobalShadows = ENV._Alleral_PrevShadows
		else
			Lighting.GlobalShadows = true
		end
		if ok and gameSettings and ENV._Alleral_PrevQuality then
			pcall(function()
				gameSettings.SavedQualityLevel = ENV._Alleral_PrevQuality
			end)
		end
	end
	ENV.Alleral_LowGraphics = enabled == true
end

function Core.buildWebJoinUrl(placeId, jobId)
	placeId = tonumber(placeId) or game.PlaceId
	jobId = tostring(jobId or game.JobId or "")
	return string.format(
		"https://www.roblox.com/games/start?placeId=%s&gameInstanceId=%s",
		tostring(placeId),
		jobId
	)
end

function Core.buildRobloxJoinUrl(placeId, jobId)
	placeId = tonumber(placeId) or game.PlaceId
	jobId = tostring(jobId or game.JobId or "")
	return string.format(
		"roblox://experiences/start?placeId=%s&gameInstanceId=%s",
		tostring(placeId),
		jobId
	)
end

function Core.currentWebJoinUrl()
	return Core.buildWebJoinUrl(game.PlaceId, game.JobId)
end

local function decodeLuxyJoinPayload(raw)
	local luxyPayload = tostring(raw or ""):match("LUXY:<([^>]+)>")
	if not luxyPayload then
		return nil
	end
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local cleaned = luxyPayload:gsub("[^" .. alphabet .. "=]", "")
	local bits = cleaned:gsub(".", function(char)
		if char == "=" then
			return ""
		end
		local index = alphabet:find(char, 1, true)
		if not index then
			return ""
		end
		local output = ""
		for bitIndex = 6, 1, -1 do
			output = output .. (((index % (2 ^ bitIndex)) - (index % (2 ^ (bitIndex - 1))) > 0) and "1" or "0")
		end
		return output
	end)
	local decoded = bits:gsub("%d%d%d?%d?%d?%d?%d?%d?", function(chunk)
		if #chunk ~= 8 then
			return ""
		end
		local value = 0
		for bitIndex = 1, 8 do
			if chunk:sub(bitIndex, bitIndex) == "1" then
				value = value + (2 ^ (8 - bitIndex))
			end
		end
		return string.char(value)
	end)
	if decoded == "" then
		return nil
	end
	return decoded
end

function Core.parseJoinJobId(raw, defaultPlaceId)
	raw = tostring(raw or ""):gsub("^%s*(.-)%s*$", "%1")
	local placeId = tonumber(defaultPlaceId) or game.PlaceId
	if raw == "" then
		return nil, placeId
	end
	local luxyDecoded = decodeLuxyJoinPayload(raw)
	if luxyDecoded then
		raw = luxyDecoded
	end
	placeId = tonumber(raw:match("placeId=(%d+)")) or placeId
	local jobId = raw:match("gameInstanceId=([%w%-]+)")
		or raw:match("instanceId=([^&%s]+)")
		or raw:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)")
		or raw:match("([%w]+%-[%w]+%-[%w]+%-[%w]+%-[%w]+)")
		or raw
	jobId = tostring(jobId or ""):gsub("^%s*(.-)%s*$", "%1")
	if jobId == "" then
		return nil, placeId
	end
	return jobId, placeId
end

function Core.teleportToJoinInput(raw, defaultPlaceId)
	local jobId, placeId = Core.parseJoinJobId(raw, defaultPlaceId)
	if not jobId or jobId == "" then
		return false, "invalid_join_input"
	end
	local TeleportService = game:GetService("TeleportService")
	local Players = game:GetService("Players")
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(placeId or game.PlaceId, jobId, Players.LocalPlayer)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true
end

function Core.buildJoinServerControls(group, options)
	options = options or {}
	local key = options.key or "JoinJobId"
	local state = type(options.state) == "table" and options.state or getgenv().Alleral_State
	local saveSettings = options.saveSettings
	local inputLabel = options.inputLabel or "Server link or job id"
	local inputPlaceholder = options.inputPlaceholder or "paste invite link"
	local buttonLabel = options.buttonLabel or "Hop to server"
	local buttonTooltip = options.buttonTooltip or "Full roblox share link or raw job id both work."

	local function readJoinInput()
		if type(state) == "table" and state[key] ~= nil then
			return tostring(state[key])
		end
		local g = getgenv()
		g.Alleral_JoinJobId = g.Alleral_JoinJobId or ""
		return g.Alleral_JoinJobId
	end

	local function writeJoinInput(value)
		value = tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
		if type(state) == "table" then
			state[key] = value
		end
		getgenv().Alleral_JoinJobId = value
		if type(saveSettings) == "function" then
			saveSettings()
		end
	end

	if options.dividerFirst == true then
		group:CreateDivider()
	end
	group:CreateInput(
		inputLabel,
		inputPlaceholder,
		readJoinInput(),
		function(value)
			writeJoinInput(value)
		end,
		buttonTooltip
	)
	group:CreateButton(buttonLabel, function()
		local ok, err = Core.teleportToJoinInput(readJoinInput())
		if not ok then
			Core.notify("Alleral", "That doesn't look like a valid link or job id.", 3, "warn")
			if err and err ~= "invalid_join_input" and ENV.Alleral_TelemetryDebug == true then
				warn("[Alleral] Join hop failed: " .. tostring(err))
			end
		end
	end, buttonTooltip)
end

function Core.copyJobId()
	local clip = Core.execFunction("setclipboard") or Core.execFunction("setclipboard", true)
	if type(clip) == "function" then
		pcall(clip, game.JobId)
		Core.notify("Alleral", "JobId copied.", 3)
		return true
	end
	Core.notify("Alleral", game.JobId, 8)
	return false
end

function Core.copyPlaceJoinLink()
	local link = Core.buildRobloxJoinUrl(game.PlaceId, game.JobId)
	local clip = Core.execFunction("setclipboard") or Core.execFunction("setclipboard", true)
	if type(clip) == "function" then
		pcall(clip, link)
		Core.notify("Alleral", "Join link copied.", 3)
		return true
	end
	Core.notify("Alleral", link, 8)
	return false
end

function Core.copyWebJoinLink()
	local link = Core.currentWebJoinUrl()
	local clip = Core.execFunction("setclipboard") or Core.execFunction("setclipboard", true)
	if type(clip) == "function" then
		pcall(clip, link)
		Core.notify("Alleral", "Web join link copied.", 3)
		return true
	end
	Core.notify("Alleral", link, 8)
	return false
end

function Core.rejoinServer()
	local TeleportService = game:GetService("TeleportService")
	local Players = game:GetService("Players")
	pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Players.LocalPlayer)
	end)
end

function Core.syncWeaoConfigNow()
	local sync = getgenv().Alleral_SyncWeao
	if type(sync) == "function" then
		local ok = sync(false)
		Core.notify(
			"Alleral",
			ok and "WEAO config updated" or "WEAO config unchanged (or offline)",
			4
		)
		return ok
	end
	Core.notify("Alleral", "WEAO sync unavailable — reload the loader.", 5)
	return false
end

function Core.backupSettings(filename, jsonBody)
	local writeFile = Core.execFunction("writefile")
	local makeFolder = Core.execFunction("makefolder")
	local listFiles = Core.execFunction("listfiles")
	local deleteFile = Core.execFunction("delfile")
	if type(writeFile) ~= "function" then
		return false
	end
	pcall(makeFolder, "Alleral_Configs")
	pcall(makeFolder, "Alleral_Configs/backups")
	local base = tostring(filename or "settings.json"):gsub("%.json$", ""):gsub("[^%w%-_]", "_")
	local stamp = os.date("!%Y%m%d-%H%M%S")
	local path = "Alleral_Configs/backups/" .. base .. "_" .. stamp .. ".json"
	pcall(writeFile, path, jsonBody)
	if type(listFiles) == "function" and type(deleteFile) == "function" then
		local matches = {}
		for _, filePath in ipairs(listFiles("Alleral_Configs/backups")) do
			if tostring(filePath):find(base .. "_", 1, true) then
				table.insert(matches, tostring(filePath))
			end
		end
		table.sort(matches)
		while #matches > 8 do
			pcall(deleteFile, matches[1])
			table.remove(matches, 1)
		end
	end
	return true
end

function Core.settingsFilePath(options)
	options = type(options) == "table" and options or {}
	if type(options.settingsPath) == "string" and options.settingsPath ~= "" then
		return options.settingsPath
	end
	local file = options.settingsFile or "settings.json"
	if file:find("/", 1, true) or file:find("\\", 1, true) then
		return file
	end
	return "Alleral_Configs/" .. file
end

function Core.buildSessionStatsGroup(tab, column)
	local RunService = game:GetService("RunService")
	local Stats = game:GetService("Stats")
	local Players = game:GetService("Players")
	local startedAt = tick()
	local frameCount = 0
	local frameConn = RunService.RenderStepped:Connect(function()
		frameCount += 1
	end)
	local group = Core.buildUiGroup(tab, "Session stats", column or 1, nil, nil, "SessionStats")
	local status = group:CreateStatus("Live", {
		FPS = "--",
		Ping = "--",
		Players = "--",
		Uptime = "0s",
		Memory = "--",
	})
	task.spawn(function()
		local lastTick = tick()
		while ENV.Alleral_State and ENV.Alleral_State.HubRunning ~= false do
			local now = tick()
			local elapsed = math.max(now - lastTick, 0.001)
			local fps = math.floor(frameCount / elapsed)
			frameCount = 0
			lastTick = now
			local ping = "--"
			pcall(function()
				local item = Stats.Network.ServerStatsItem["Data Ping"]
				if item then
					ping = item:GetValueString()
				end
			end)
			local memory = "--"
			pcall(function()
				memory = string.format("%.0f MB", Stats:GetTotalMemoryUsageMb())
			end)
			local uptime = math.floor(tick() - startedAt)
			status:Update("FPS", tostring(fps))
			status:Update("Ping", ping)
			status:Update("Players", tostring(#Players:GetPlayers()))
			status:Update("Uptime", uptime .. "s")
			status:Update("Memory", memory)
			task.wait(2)
		end
		if frameConn then
			frameConn:Disconnect()
		end
	end)
	return group, status
end

function Core.buildQuickTogglesGroup(tab, options)
	options = type(options) == "table" and options or {}
	local state = options.state or ENV.Alleral_State or {}
	local saveFn = options.saveFn
	local column = options.column or 2
	local group = Core.buildUiGroup(tab, "Quick toggles", column, nil, nil, "QuickToggles")

	group:CreateToggle("Mute all audio", ENV.Alleral_MusicMuted == true, "Sets SoundService volume to 0.", function(value)
		Core.setGlobalMusicMuted(value)
		if type(saveFn) == "function" then
			saveFn()
		end
	end)

	group:CreateToggle("Low graphics", ENV.Alleral_LowGraphics == true, "Lowest quality + no shadows.", function(value)
		Core.setLowGraphics(value)
		if type(saveFn) == "function" then
			saveFn()
		end
	end)

	group:CreateToggle(
		"Auto relaunch on teleport",
		getgenv().Alleral_AutoRelaunch ~= false,
		"Reload the hub after server hops (loader setting).",
		function(value)
			getgenv().Alleral_AutoRelaunch = value == true
			ENV.Alleral_AutoRelaunch = value == true
		end
	)

	if state.AntiAFK ~= nil then
		group:CreateToggle("Anti AFK", state.AntiAFK ~= false, "Prevents idle kick.", function(value)
			state.AntiAFK = value
			if value then
				Core.setupAntiAfk(game:GetService("Players").LocalPlayer)
			end
			if type(saveFn) == "function" then
				saveFn()
			end
		end)
	end

	return group
end

function Core.buildServerToolsGroup(tab, column)
	local group = Core.buildUiGroup(tab, "Server tools", column or 1, nil, nil, "ServerTools")
	group:CreateButton("Copy JobId", Core.copyJobId, "Copy this server's instance id.")
	group:CreateButton("Copy join link", Core.copyPlaceJoinLink, "Share a direct join link.")
	group:CreateButton("Rejoin server", Core.rejoinServer, "Reconnect to this exact server.")
	group:CreateButton("Copy PlaceId", function()
		local clip = Core.execFunction("setclipboard") or Core.execFunction("setclipboard", true)
		if type(clip) == "function" then
			pcall(clip, tostring(game.PlaceId))
			Core.notify("Alleral", "PlaceId copied.", 3)
		else
			Core.notify("Alleral", tostring(game.PlaceId), 5)
		end
	end, "Copy the experience PlaceId.")
	return group
end

function Core.buildErrorLogGroup(tab, column)
	local group = Core.buildUiGroup(tab, "Error log", column or 2, nil, nil, "ErrorLog")
	Core.installErrorLogHook()
	local status = group:CreateStatus("Errors", {
		Count = tostring(#(ENV.Alleral_ErrorLog or {})),
		Latest = "None",
	})
	Core._errorLogStatus = status
	if #(ENV.Alleral_ErrorLog or {}) > 0 then
		local latest = ENV.Alleral_ErrorLog[1]
		status:Update("Latest", latest.scope .. ": " .. latest.message:sub(1, 80))
	end
	group:CreateButton("Copy log", function()
		local clip = Core.execFunction("setclipboard") or Core.execFunction("setclipboard", true)
		if type(clip) ~= "function" then
			Core.notify("Alleral", "Clipboard not supported.", 4)
			return
		end
		pcall(clip, Core.getErrorLogText(25))
		Core.notify("Alleral", "Error log copied.", 3)
	end, "Copy the last 25 errors.")
	group:CreateButton("Clear log", function()
		table.clear(ENV.Alleral_ErrorLog)
		status:Update("Count", "0")
		status:Update("Latest", "None")
		Core.notify("Alleral", "Error log cleared.", 3)
	end)
	return group, status
end

function Core.buildSettingsBackupGroup(tab, options)
	options = type(options) == "table" and options or {}
	local column = options.column or 2
	local settingsPath = Core.settingsFilePath(options)
	local readFile = Core.execFunction("readfile")
	local writeFile = Core.execFunction("writefile")
	local isFile = Core.execFunction("isfile")
	local listFiles = Core.execFunction("listfiles")
	local group = Core.buildUiGroup(tab, "Settings backup", column, nil, nil, "SettingsBackup")

	local function listBackups()
		local names = {}
		if type(listFiles) == "function" then
			local base = (options.settingsFile or "settings"):gsub("%.json$", ""):gsub("[^%w%-_]", "_")
			for _, path in ipairs(listFiles("Alleral_Configs/backups")) do
				local name = tostring(path):match("([^/\\]+)$")
				if name and name:find("^" .. base .. "_", 1, true) then
					table.insert(names, name)
				end
			end
		end
		table.sort(names, function(a, b)
			return a > b
		end)
		if #names == 0 then
			table.insert(names, "(none yet)")
		end
		return names
	end

	local selected = listBackups()[1]
	group:CreateDropdown("Backups", listBackups(), selected, function(value)
		selected = value
	end, "Rolling backups created whenever settings save.")

	group:CreateButton("Restore backup", function()
		if selected == "(none yet)" then
			Core.notify("Alleral", "No backups found yet.", 4)
			return
		end
		if type(readFile) ~= "function" or type(writeFile) ~= "function" or type(isFile) ~= "function" then
			Core.notify("Alleral", "Filesystem not supported.", 5)
			return
		end
		local backupPath = "Alleral_Configs/backups/" .. selected
		if not isFile(backupPath) then
			Core.notify("Alleral", "Backup missing.", 4)
			return
		end
		local raw = readFile(backupPath)
		pcall(writeFile, settingsPath, raw)
		Core.notify("Alleral", "Backup restored — reload the script.", 5)
	end, "Overwrites your current settings file.")

	group:CreateButton("Backup now", function()
		if type(readFile) ~= "function" or not isFile or not isFile(settingsPath) then
			Core.notify("Alleral", "Nothing to backup yet.", 4)
			return
		end
		local raw = readFile(settingsPath)
		Core.backupSettings(options.settingsFile or settingsPath, raw)
		Core.notify("Alleral", "Manual backup saved.", 3)
	end)

	return group
end

function Core.setupHubKeybinds(options)
	options = type(options) == "table" and options or {}
	if ENV._Alleral_KeybindConn then
		pcall(function()
			ENV._Alleral_KeybindConn:Disconnect()
		end)
		ENV._Alleral_KeybindConn = nil
	end
	local UserInputService = game:GetService("UserInputService")
	local panicKey = options.panicKey or Enum.KeyCode.Delete
	local uiKey = options.uiKey or Enum.KeyCode.RightControl
	ENV._Alleral_KeybindConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == panicKey then
			Core.stateHubStop()
			Core.notify("Alleral", "everything stopped", 4)
		elseif input.KeyCode == uiKey then
			if Core.toggleUiVisibility() then
				Core.notify("Alleral", "UI toggled.", 2)
			end
		end
	end)
end

function Core.buildUiPreferencesGroup(tab, options)
	options = type(options) == "table" and options or {}
	local column = options.column or 2
	local uiBundle = options.uiBundle
	if not uiBundle and type(options.window) == "table" then
		uiBundle = options.window._ui
	end
	local windUi = uiBundle and (uiBundle.WindUI or uiBundle.Library)
	local group = Core.buildUiGroup(tab, "UI tools", column, nil, nil, "UiPreferences")

	group:CreateButton("Test success toast", function()
		Core.notify("Alleral", "Success toast.", 4, "success")
	end, "Fire a success toast.")

	group:CreateButton("Test warning toast", function()
		Core.notify("Alleral", "Warning toast.", 4, "warn")
	end, "Fire a warning toast.")

	group:CreateButton("Clear all toasts", function()
		if windUi and type(windUi.ClearNotifications) == "function" then
			local cleared = windUi:ClearNotifications()
			Core.notify("Alleral", "cleared " .. tostring(cleared or 0), 2, "info")
		else
			Core.notify("Alleral", "Clear unavailable.", 3, "warn")
		end
	end, "Dismiss visible toasts.")

	group:CreateButton("Repair UI chrome", function()
		if windUi and type(windUi.RepairWindow) == "function" then
			local ok = windUi:RepairWindow()
			Core.notify("Alleral", ok and "UI repaired." or "Repair failed.", 3, ok and "success" or "error")
		else
			Core.notify("Alleral", "Repair unavailable.", 3, "warn")
		end
	end, "Re-apply theme rails and polish.")

	group:CreateToggle(
		"Bottom notifications",
		ENV.Alleral_NotifyLower == true,
		"Move toasts to the bottom-right.",
		function(value)
			ENV.Alleral_NotifyLower = value == true
			if windUi and type(windUi.SetNotificationLower) == "function" then
				pcall(function()
					windUi:SetNotificationLower(value)
				end)
			end
		end
	)

	return group
end

function Core.buildAutomationStatusGroup(tab, options)
	options = type(options) == "table" and options or {}
	local state = options.state or ENV.Alleral_State or {}
	local loops = options.loops or {}
	local column = options.column or 1
	local flags = options.flags or {
		{ key = "AFarm", label = "Auto kick" },
		{ key = "APlaceBest", label = "Auto place" },
		{ key = "AAutoUpgrade", label = "Auto upgrade" },
		{ key = "AAutoFav", label = "Auto favorite" },
		{ key = "ATrain", label = "Auto train" },
		{ key = "ACollect", label = "Auto collect" },
		{ key = "AAutoBattle", label = "Auto battle" },
		{ key = "AAutoMastery", label = "Auto mastery" },
	}

	local group = Core.buildUiGroup(tab, "Automation", column, nil, nil, "AutomationStatus")
	local status = group:CreateStatus("Live loops", {
		Active = "0",
		Total = tostring(#flags),
		Hub = state.HubRunning ~= false and "running" or "stopped",
	})

	local function refresh()
		local active = 0
		local lines = {}
		for _, entry in ipairs(flags) do
			local on = state[entry.key] == true
			if on then
				active += 1
			end
			local loopState = loops[entry.key] or loops[entry.label]
			local pulse = on and (loopState and loopState.enabled ~= false and "●" or "○") or "·"
			table.insert(lines, pulse .. " " .. entry.label)
		end
		status:Update("Active", tostring(active))
		status:Update("Hub", state.HubRunning ~= false and "running" or "stopped")
		if status.SetSummary and type(status.SetSummary) == "function" then
			status:SetSummary(table.concat(lines, "  "))
		end
	end

	group:CreateButton("Refresh status", refresh, "Update loop indicators.")
	task.spawn(function()
		while state.HubRunning ~= false do
			refresh()
			task.wait(2)
		end
	end)

	return group, status, refresh
end

function Core.buildStandardSettingsExtras(tab, options)
	options = type(options) == "table" and options or {}
	Core.installErrorLogHook()
	if type(options.window) == "table" then
		Core.registerUiWindow(options.window)
	end
	Core.buildSessionStatsGroup(tab, options.sessionColumn or 1)
	Core.buildServerToolsGroup(tab, options.serverColumn or 1)
	Core.buildQuickTogglesGroup(tab, options)
	Core.buildUiPreferencesGroup(tab, options)
	Core.buildErrorLogGroup(tab, options.errorColumn or 2)
	Core.buildSettingsBackupGroup(tab, options)
	if options.setupKeybinds ~= false then
		Core.setupHubKeybinds(options)
	end
end

function stateHubStop()
	local state = ENV.Alleral_State
	if type(state) == "table" then
		state.HubRunning = false
		if type(state.Alleral_Unload) == "function" then
			pcall(state.Alleral_Unload)
		end
	end
	local telemetry = ENV.Alleral_Telemetry
	if type(telemetry) == "table" and type(telemetry.ReportSessionEnd) == "function" then
		telemetry:ReportSessionEnd("stopped")
	end
	Core.notify("Alleral", "loops stopped", 3)
end

Core.stateHubStop = stateHubStop

local function trimText(value)
	return tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
end

function Core.sanitizeProfileName(name)
	name = trimText(name):gsub("[^%w%-_%s]", ""):gsub("%s+", "_")
	if name == "" then
		return "Default"
	end
	return name:sub(1, 32)
end

function Core.buildConfigProfileGroup(tab, options)
	options = type(options) == "table" and options or {}
	local state = options.state or ENV.Alleral_State or {}
	local savedKeys = options.savedKeys or {}
	local profileFolder = options.profileFolder or "Alleral_Configs/Profiles"
	local saveFn = options.saveFn or function() end
	local onApply = options.onApply
	local scriptVersion = options.version or "1.0"
	local column = options.column or 2

	local writeFile = Core.execFunction("writefile")
	local readFile = Core.execFunction("readfile")
	local isFile = Core.execFunction("isfile")
	local isFolder = Core.execFunction("isfolder")
	local makeFolder = Core.execFunction("makefolder")
	local listFiles = Core.execFunction("listfiles")
	local deleteFile = Core.execFunction("delfile")
	local setClipboard = Core.execFunction("setclipboard") or Core.execFunction("setclipboard", true)

	local function ensureFolder()
		if type(makeFolder) ~= "function" then
			return false
		end
		pcall(makeFolder, "Alleral_Configs")
		pcall(makeFolder, profileFolder)
		return true
	end

	local function profilePath(name)
		return profileFolder .. "/" .. Core.sanitizeProfileName(name) .. ".json"
	end

	local function collectSnapshot()
		local snapshot = {}
		for _, key in ipairs(savedKeys) do
			snapshot[key] = Core.copyValue(state[key])
		end
		snapshot.__meta = {
			version = scriptVersion,
			createdAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		}
		return snapshot
	end

	local function applySnapshot(snapshot)
		if type(snapshot) ~= "table" then
			return false, "Invalid profile file."
		end
		for _, key in ipairs(savedKeys) do
			if snapshot[key] ~= nil then
				state[key] = Core.copyValue(snapshot[key])
			end
		end
		if type(onApply) == "function" then
			pcall(onApply, snapshot)
		end
		saveFn()
		return true, nil
	end

	local function listProfiles()
		local names = {}
		if type(listFiles) == "function" and type(isFolder) == "function" and isFolder(profileFolder) then
			for _, path in ipairs(listFiles(profileFolder)) do
				local name = tostring(path):match("([^/\\]+)%.json$")
				if name then
					table.insert(names, name)
				end
			end
		end
		table.sort(names)
		if #names == 0 then
			table.insert(names, "Default")
		end
		return names
	end

	local profileName = Core.sanitizeProfileName(state.ActiveProfileName or "Default")
	local groupbox = tab:CreateGroupbox({
		Name = "Config profiles",
		Column = column,
		Icon = 6031075938,
	}, "ConfigProfiles")
	local group = Core.wrapUiGroup(groupbox)

	group:CreateInput("Profile name", "my setup", profileName, function(value)
		profileName = Core.sanitizeProfileName(value)
		state.ActiveProfileName = profileName
		saveFn()
	end, "Name used when saving or loading.")

	group:CreateButton("Save profile", function()
		if type(writeFile) ~= "function" then
			Core.notify("Alleral", "Your executor can't save files.", 5)
			return
		end
		ensureFolder()
		local ok = Core.writeFile(profilePath(profileName), HttpService:JSONEncode(collectSnapshot()))
		if ok then
			state.ActiveProfileName = profileName
			saveFn()
			Core.notify("Alleral", "Saved '" .. profileName .. "'.", 4)
		end
	end, "Writes all settings to disk under this name.")

	group:CreateButton("Load profile", function()
		if type(readFile) ~= "function" or type(isFile) ~= "function" then
			Core.notify("Alleral", "Your executor can't read files.", 5)
			return
		end
		local path = profilePath(profileName)
		if not isFile(path) then
			Core.notify("Alleral", "No profile named '" .. profileName .. "'.", 5)
			return
		end
		local raw = readFile(path)
		local decodedOk, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if not decodedOk then
			Core.notify("Alleral", "Profile JSON is corrupt.", 5)
			return
		end
		local applied, err = applySnapshot(decoded)
		if applied then
			Core.notify("Alleral", "Loaded '" .. profileName .. "'. Reload to refresh UI.", 5)
		else
			Core.notify("Alleral", tostring(err), 5)
		end
	end, "Applies a saved profile to this session.")

	group:CreateButton("Delete profile", function()
		if type(deleteFile) ~= "function" then
			Core.notify("Alleral", "Your executor can't delete files.", 5)
			return
		end
		local path = profilePath(profileName)
		if type(isFile) == "function" and not isFile(path) then
			Core.notify("Alleral", "Nothing to delete.", 4)
			return
		end
		pcall(deleteFile, path)
		Core.notify("Alleral", "Deleted '" .. profileName .. "'.", 4)
	end)

	group:CreateButton("Copy to clipboard", function()
		if type(setClipboard) ~= "function" then
			Core.notify("Alleral", "Clipboard not supported.", 4)
			return
		end
		pcall(setClipboard, HttpService:JSONEncode(collectSnapshot()))
		Core.notify("Alleral", "Profile copied — paste to share.", 4)
	end)

	group:CreateButton("Paste from clipboard", function()
		local clip = Core.execFunction("getclipboard") or Core.execFunction("getclipboard", true)
		if type(clip) ~= "function" then
			Core.notify("Alleral", "Clipboard not supported.", 4)
			return
		end
		local ok, raw = pcall(clip)
		if not ok or type(raw) ~= "string" or raw == "" then
			Core.notify("Alleral", "Clipboard is empty.", 4)
			return
		end
		local decodedOk, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if not decodedOk then
			Core.notify("Alleral", "Clipboard doesn't contain valid JSON.", 5)
			return
		end
		local applied, err = applySnapshot(decoded)
		if applied then
			Core.notify("Alleral", "Imported profile from clipboard.", 4)
		else
			Core.notify("Alleral", tostring(err), 5)
		end
	end)

	local names = listProfiles()
	group:CreateDropdown("Saved profiles", names, profileName, function(value)
		profileName = Core.sanitizeProfileName(value)
		state.ActiveProfileName = profileName
		saveFn()
	end, "Quick-pick a profile you've saved before.")

	return group
end

function Core.normalizeWebhookUrl(url)
	local text = trimText(url)
	if text == "" then
		return nil, "Webhook URL is empty."
	end
	if not text:find("^https://") and not text:find("^http://") then
		text = "https://" .. text
	end
	if
		not text:find("discord%.com/api/webhooks/")
		and not text:find("discordapp%.com/api/webhooks/")
	then
		return nil, "That doesn't look like a Discord webhook URL."
	end
	return text, nil
end

function Core.buildDiscordEmbed(opts)
	opts = type(opts) == "table" and opts or {}
	local embed = {
		title = opts.title,
		description = opts.description,
		color = opts.color or 5489688,
		fields = opts.fields,
		footer = opts.footer or { text = opts.brand or "Alleral" },
		timestamp = opts.timestamp,
		thumbnail = opts.thumbnail,
		image = opts.image,
		author = opts.author,
	}
	if embed.fields == nil then
		embed.fields = {}
	end
	return embed
end

function Core.buildDiscordPayload(opts)
	opts = type(opts) == "table" and opts or {}
	local embeds = opts.embeds
	if type(embeds) ~= "table" or #embeds == 0 then
		embeds = { Core.buildDiscordEmbed(opts) }
	end
	return {
		username = opts.username or opts.brand or "Alleral",
		avatar_url = opts.avatarUrl,
		content = opts.content,
		embeds = embeds,
	}
end

function Core.discordField(name, value, inline)
	local text = trimText(value)
	if text == "" then
		text = "—"
	end
	if #text > 1024 then
		text = text:sub(1, 1021) .. "..."
	end
	return {
		name = tostring(name or "Field"),
		value = "```" .. text .. "```",
		inline = inline == true,
	}
end

function Core.discordLinkField(name, label, url, inline)
	url = trimText(url)
	if url == "" then
		return Core.discordField(name, "—", inline)
	end
	return {
		name = tostring(name or "Link"),
		value = string.format("[%s](%s)", label or "Open", url),
		inline = inline == true,
	}
end

function Core.postWebhook(url, payload)
	local sender = Core.requestFunction()
	if not sender then
		return false, "HTTP is not available in this executor."
	end
	local postUrl, urlError = Core.normalizeWebhookUrl(url)
	if not postUrl then
		return false, urlError
	end
	local ok, response = pcall(function()
		return sender({
			Url = postUrl,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload),
		})
	end)
	if not ok then
		return false, tostring(response)
	end
	if type(response) == "table" then
		if response.Success == false then
			local code = response.StatusCode or response.Status or response.status_code
			return false, "Webhook failed (HTTP " .. tostring(code or "?") .. ")"
		end
		local code = response.StatusCode or response.Status or response.status_code
		if type(code) == "number" and (code < 200 or code >= 300) then
			return false, "Webhook returned HTTP " .. tostring(code)
		end
	end
	return true, nil
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

local function uiOk(bundle)
	return type(bundle) == "table"
		and type(bundle.Library) == "table"
		and type(bundle.CreateWindow) == "function"
end

local function stampUi(bundle)
	if type(bundle) ~= "table" then
		return bundle
	end
	bundle.InterfaceBuild = Core.UI_LIBRARY
	bundle.UI_LIBRARY = Core.UI_LIBRARY
	return bundle
end

local function windUiSourceValid(body)
	if type(body) ~= "string" or body == "" then
		return false
	end
	if #body < WINDUI_MIN_BYTES then
		return false
	end
	return body:find("CreateWindow", 1, true) ~= nil or body:find("WindUI", 1, true) ~= nil
end

local function compileWindUiModule(source, label)
	local loadStringFn = Core.loadStringFn()
	if not loadStringFn or not source or source == "" then
		return nil, "Empty WindUI source"
	end
	local cacheKey = tostring(#source) .. ":" .. tostring(label)
	local cache = ENV._AlleralWindUiCompileCache
	if cache and cache.key == cacheKey and type(cache.module) == "table" then
		return cache.module
	end
	if not windUiSourceValid(source) then
		return nil, "WindUI source invalid (" .. tostring(#source) .. " bytes)"
	end
	local compiled, compileErr = loadStringFn(source, label)
	if not compiled and type(load) == "function" and load ~= loadStringFn then
		compiled, compileErr = load(source, label)
	end
	if not compiled then
		return nil, tostring(compileErr)
	end
	local ok, result = pcall(compiled)
	if ok and type(result) == "table" and type(result.CreateWindow) == "function" then
		ENV.Alleral_WindUiLastGood = result
		ENV._AlleralWindUiCompileCache = {
			key = tostring(#source) .. ":" .. tostring(label),
			module = result,
		}
		return result
	end
	if not ok then
		Core.logWarn("WindUI compile error: " .. tostring(result))
	end
	if ENV.Alleral_WindUiLastGood and type(ENV.Alleral_WindUiLastGood.CreateWindow) == "function" then
		Core.logWarn("WindUI compile failed, using last good copy")
		return ENV.Alleral_WindUiLastGood
	end
	return nil, ok and "Invalid WindUI module" or tostring(result)
end

local function readWindUiLocal(relativePath)
	local cacheKey = "_AlleralWindPath_" .. tostring(relativePath):gsub("[^%w]", "_")
	local cachedPath = ENV[cacheKey]
	if type(cachedPath) == "string" then
		local cachedSource = Core.readFile(cachedPath)
		if cachedSource then
			return cachedSource, cachedPath
		end
	end

	local roots = { "", "kick/", "kick/kick/", "workspace/", "scripts/" }
	for _, vendorRoot in ipairs(WINDUI_LOCAL_ROOTS) do
		for _, root in ipairs(roots) do
			local fullPath = root .. vendorRoot .. relativePath
			local source = Core.readFile(fullPath)
			if source then
				ENV[cacheKey] = fullPath
				return source, fullPath
			end
		end
	end
	return nil
end

local function fetchWindUiRemote(relativePath)
	for _, base in ipairs(WINDUI_MIRROR_URLS) do
		local url = base .. relativePath
		local body = Core.httpGet(url)
		if windUiSourceValid(body) then
			return body, url
		end
	end
	return nil
end

local function patchSourceValid(body)
	return type(body) == "string"
		and #body > 400
		and body:find("ALLERAL_UI_VERSION", 1, true) ~= nil
		and body:find("return function", 1, true) ~= nil
end

local function bootstrapSourceValid(body)
	return type(body) == "string"
		and #body > 200
		and body:find("return function", 1, true) ~= nil
end

local function applyAlleralWindUiPatch(windUi)
	if type(windUi) ~= "table" or type(windUi.GetAlleralVersion) == "function" then
		return windUi
	end

	local loadStringFn = Core.loadStringFn()
	if type(loadStringFn) ~= "function" then
		return windUi
	end

	local function runPatchLoader(source, label)
		if not source then
			return false
		end
		local chunk, compileErr = loadStringFn(source, label)
		if not chunk then
			Core.logWarn("UI loader compile: " .. tostring(compileErr))
			return false
		end
		local ok, loader = pcall(chunk)
		if not ok or type(loader) ~= "function" then
			Core.logWarn("UI loader: " .. tostring(loader))
			return false
		end
		local applied, applyErr = pcall(loader, windUi)
		if not applied then
			Core.logWarn("UI patch: " .. tostring(applyErr))
			return false
		end
		return type(windUi.GetAlleralVersion) == "function"
	end

	local bootstrapSource, bootstrapPath = readWindUiLocal("bootstrap.lua")
	if runPatchLoader(bootstrapSource, "@Alleral/bootstrap:" .. tostring(bootstrapPath or "local")) then
		return windUi
	end

	for _, base in ipairs(WINDUI_MIRROR_URLS) do
		local body = Core.httpGet(base .. "bootstrap.lua")
		if bootstrapSourceValid(body) and runPatchLoader(body, "@Alleral/bootstrap:remote") then
			return windUi
		end
	end

	local patchSource, patchPath = readWindUiLocal(WINDUI_PATCH_FILE)
	if patchSource and patchSourceValid(patchSource) then
		local chunk, compileErr = loadStringFn(patchSource, "@Alleral/aller:" .. tostring(patchPath))
		if chunk then
			local ok, patchFn = pcall(chunk)
			if ok and type(patchFn) == "function" then
				pcall(patchFn, windUi)
			end
		else
			Core.logWarn("UI patch compile: " .. tostring(compileErr))
		end
	end

	for _, base in ipairs(WINDUI_MIRROR_URLS) do
		local body = Core.httpGet(base .. WINDUI_PATCH_FILE)
		if patchSourceValid(body) then
			local chunk, compileErr = loadStringFn(body, "@Alleral/aller:remote")
			if chunk then
				local ok, patchFn = pcall(chunk)
				if ok and type(patchFn) == "function" then
					pcall(patchFn, windUi)
					break
				end
			else
				Core.logWarn("UI patch compile: " .. tostring(compileErr))
			end
		end
	end

	return windUi
end

local function loadWindUiModule()
	if ENV.Alleral_WindUiLastGood and type(ENV.Alleral_WindUiLastGood.CreateWindow) == "function" then
		local cache = ENV._AlleralWindUiCompileCache
		if cache and type(cache.module) == "table" then
			return applyAlleralWindUiPatch(cache.module)
		end
	end

	local localSource, localPath = readWindUiLocal(WINDUI_FILE)
	if localSource then
		local module, err = compileWindUiModule(localSource, "@WindUI/local:" .. localPath)
		if module then
			return applyAlleralWindUiPatch(module)
		end
		Core.logWarn("local WindUI failed (" .. tostring(localPath) .. "): " .. tostring(err))
	end
	local remoteSource, remoteUrl = fetchWindUiRemote(WINDUI_FILE)
	if remoteSource then
		local module, err = compileWindUiModule(remoteSource, "@WindUI/remote:" .. tostring(remoteUrl))
		if module then
			Core.say("WindUI pulled from " .. tostring(remoteUrl))
			return applyAlleralWindUiPatch(module)
		end
		Core.logWarn("remote WindUI failed: " .. tostring(err))
	end
	localSource = readWindUiLocal(WINDUI_FILE)
	if localSource then
		return applyAlleralWindUiPatch(compileWindUiModule(localSource, "@WindUI/local"))
	end
	return nil, "WindUI download failed for " .. WINDUI_FILE
end

local function listUiThemes(windUi)
	local names = {}
	if type(windUi) == "table" and type(windUi.GetThemes) == "function" then
		local ok, themes = pcall(function()
			return windUi:GetThemes()
		end)
		if ok and type(themes) == "table" then
			for name in pairs(themes) do
				table.insert(names, name)
			end
			table.sort(names)
		end
	end
	if #names == 0 then
		return { "Alleral", "AlleralNeon", "AlleralMidnight", "Dark", "Light" }
	end
	return names
end

local function applyAlleralTheme(bundle)
	if type(bundle) ~= "table" then
		return
	end
	local windUi = bundle.WindUI or bundle.Library
	if type(windUi) ~= "table" or type(windUi.SetTheme) ~= "function" then
		return
	end
	pcall(function()
		windUi:SetTheme("Alleral")
	end)
end

local function cacheUi(bundle)
	stampUi(bundle)
	ENV.Alleral_UI = bundle
	ENV.Alleral_Rayfield = bundle
	return bundle
end

function Core.loadUi()
	local cached = ENV.Alleral_UI or ENV.Alleral_Rayfield
	if uiOk(cached) then
		return cacheUi(cached)
	end
	ENV.Alleral_UI = nil
	ENV.Alleral_Rayfield = nil

	local loadStringFn = Core.loadStringFn()
	if not loadStringFn then
		return nil, "loadstring unavailable"
	end

	local WindUI, libErr = loadWindUiModule()
	if not WindUI and ENV.Alleral_WindUiLastGood then
		WindUI = ENV.Alleral_WindUiLastGood
		libErr = nil
		Core.say("using cached WindUI")
	end
	if not WindUI then
		return nil, libErr or "WindUI missing"
	end

	ENV.Alleral_WindUiLastGood = WindUI

	Core.clearUiStateBindings()

	local bundle = {
		WindUI = WindUI,
		Library = WindUI,
		CreateWindow = function(_, settings)
			return Core.safeCall("UI:CreateWindow", function()
				return WindUI:CreateWindow(settings)
			end)
		end,
		Notify = function(_, info)
			Core.safeCall("UI:Notify", function()
				if type(info) == "table" then
					WindUI:Notify({
						Title = info.Title,
						Content = info.Content or info.Description or info.Text or "",
						Duration = info.Duration or info.Time or 4,
						Type = info.Type or info.Level,
						Icon = info.Icon,
					})
				else
					WindUI:Notify({
						Title = "Alleral",
						Content = tostring(info or ""),
						Duration = 4,
						Type = "info",
					})
				end
			end)
		end,
	}
	applyAlleralTheme(bundle)
	bundle.ThemeNames = listUiThemes(WindUI)
	if ENV.Alleral_UiReducedMotion == true and type(WindUI.SetReducedMotion) == "function" then
		WindUI:SetReducedMotion(true)
	end
	if ENV.Alleral_UiSpringMotion == false and type(WindUI.SetSpringMotion) == "function" then
		pcall(function()
			WindUI:SetSpringMotion(false)
		end)
	end
	if ENV.Alleral_UiStartup == false and type(WindUI.SetStartupEffect) == "function" then
		pcall(function()
			WindUI:SetStartupEffect(false)
		end)
	elseif ENV.Alleral_UiStartup == true and type(WindUI.SetStartupEffect) == "function" then
		pcall(function()
			WindUI:SetStartupEffect(true)
		end)
	end
	if ENV.Alleral_UiTouchFeedback == false and type(WindUI.SetTouchFeedback) == "function" then
		pcall(function()
			WindUI:SetTouchFeedback(false)
		end)
	end
	if ENV.Alleral_NotifyDedupe == false and type(WindUI.SetNotifyDedupe) == "function" then
		pcall(function()
			WindUI:SetNotifyDedupe(false)
		end)
	end
	if ENV.Alleral_NotifyLower == true and type(WindUI.SetNotificationLower) == "function" then
		pcall(function()
			WindUI:SetNotificationLower(true)
		end)
	end
	if ENV.Alleral_NotifyCompact == true and type(WindUI.SetNotificationCompact) == "function" then
		pcall(function()
			WindUI:SetNotificationCompact(true)
		end)
	end
	if type(WindUI.ApplyProfile) == "function" then
		pcall(function()
			WindUI:ApplyProfile(ENV.Alleral_UiProfile or "auto")
		end)
	end
	if ENV.Alleral_UiScale and type(WindUI.SetUiScale) == "function" then
		pcall(function()
			WindUI:SetUiScale(ENV.Alleral_UiScale)
		end)
	end
	if ENV.Alleral_UiHaptics == true and type(WindUI.SetHaptics) == "function" then
		pcall(function()
			WindUI:SetHaptics(true)
		end)
	end
	Core.say("WindUI " .. tostring(WindUI.GetAlleralVersion and WindUI:GetAlleralVersion() or Core.WINDUI_VERSION) .. " loaded")
	task.defer(function()
		if type(WindUI.Preload) == "function" then
			pcall(function()
				WindUI:Preload()
			end)
		end
	end)
	return cacheUi(bundle)
end

Core.loadRayfield = Core.loadUi

function Core.preloadUi()
	local cached = ENV.Alleral_UI or ENV.Alleral_Rayfield
	if uiOk(cached) then
		return cacheUi(cached)
	end
	if ENV._AlleralUiPreloadRunning == true then
		local started = tick()
		while ENV._AlleralUiPreloadRunning == true and tick() - started < 15 do
			task.wait()
		end
		cached = ENV.Alleral_UI or ENV.Alleral_Rayfield
		if uiOk(cached) then
			return cacheUi(cached)
		end
	end
	ENV._AlleralUiPreloadRunning = true
	local bundle, err = Core.loadUi()
	ENV._AlleralUiPreloadRunning = false
	return bundle, err
end

function Core.httpGet(url)
	if type(url) ~= "string" or url == "" then
		return nil
	end

	local plain = url:gsub("%?.*$", "")
	local urls = {
		plain .. "?t=" .. tostring(tick()),
		plain,
		url,
	}

	local function accept(body)
		if type(body) ~= "string" or body == "" then
			return false
		end
		if #body <= 8192 and body:find("404: Not Found", 1, true) then
			return false
		end
		if body:find("<!DOCTYPE html>", 1, true) or body:find("<html", 1, true) then
			return body:find("function", 1, true) ~= nil or body:find("local ", 1, true) ~= nil
		end
		return true
	end

	local function extractBody(response)
		if type(response) == "string" then
			return response
		end
		if type(response) == "table" then
			return response.Body or response.body or response.Data or response.data
		end
		return nil
	end

	local function tryRequest(fn, fetchUrl)
		if type(fn) ~= "function" then
			return nil
		end
		local ok, direct = pcall(fn, fetchUrl)
		if ok and accept(direct) then
			return direct
		end
		if ok and type(direct) == "table" then
			local body = extractBody(direct)
			if accept(body) then
				return body
			end
		end
		for _, spec in ipairs({
			{
				Url = fetchUrl,
				Method = "GET",
				Headers = { ["Cache-Control"] = "no-cache" },
			},
			{
				url = fetchUrl,
				method = "GET",
				headers = { ["Cache-Control"] = "no-cache" },
			},
		}) do
			local rok, response = pcall(fn, spec)
			if rok then
				local body = extractBody(response)
				local status = type(response) == "table" and (response.StatusCode or response.status or response.Status or 200) or 200
				if accept(body) and (status == 0 or (status >= 200 and status < 300)) then
					return body
				end
			end
		end
		return nil
	end

	local bestBody, bestLen = nil, 0
	local function consider(body)
		if type(body) == "string" and accept(body) and #body > bestLen then
			bestBody, bestLen = body, #body
		end
	end

	for _, fetchUrl in ipairs(urls) do
		if type(game.HttpGet) == "function" then
			local ok, body = pcall(game.HttpGet, game, fetchUrl, true)
			consider(body)
			ok, body = pcall(game.HttpGet, game, fetchUrl)
			consider(body)
		end
		local ok, body = pcall(function()
			return game:HttpGet(fetchUrl, true)
		end)
		if ok then
			consider(body)
		end
		ok, body = pcall(function()
			return game:HttpGet(fetchUrl)
		end)
		if ok then
			consider(body)
		end
		if type(HttpService.GetAsync) == "function" then
			ok, body = pcall(function()
				return HttpService:GetAsync(fetchUrl, true)
			end)
			if ok then
				consider(body)
			end
		end
		consider(tryRequest(Core.requestFunction(), fetchUrl))
	end

	return bestBody
end

function Core.httpGetJson(url)
	local body = Core.httpGet(url)
	if not body then
		return nil, "HTTP unavailable"
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok or type(decoded) ~= "table" then
		return nil, "Invalid JSON response"
	end
	return decoded
end

function Core.setClipboard(text)
	local clip = Core.execFunction("setclipboard") or Core.execFunction("toclipboard")
	if clip then
		pcall(clip, tostring(text or ""))
		return true
	end
	return false
end

function Core.windUiIcon(icon)
	if type(icon) == "number" then
		return "rbxassetid://" .. tostring(icon)
	end
	local numeric = Core.uiIcon(icon)
	if numeric ~= "" then
		return "rbxassetid://" .. numeric
	end
	if type(icon) == "string" and icon ~= "" and not icon:find("rbxassetid", 1, true) then
		return icon
	end
	return "circle"
end

local function windUiVisibilityTarget(label)
	if type(label) ~= "table" then
		return nil
	end
	local frame = label.ParagraphFrame or label
	if type(frame.UIElements) == "table" and frame.UIElements.Main then
		return frame.UIElements.Main
	end
	if label.Instance then
		return label.Instance
	end
	return nil
end

function Core.createWindUiGroupbox(rawGroup, uiBundle)
	rawGroup = rawGroup or {}
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

	local function labelVisibilityTarget(label)
		return windUiVisibilityTarget(label)
	end

	local function setElementValue(element, value)
		if not element then
			return
		end
		if element.Select then
			element:Select(value)
		elseif element.Set then
			element:Set(value)
		elseif element.SetValue then
			element:SetValue(value)
		end
	end

	local groupbox = {}

	function groupbox:CreateToggle(settings, id)
		local handle
		handle = rawGroup:Toggle({
			Title = settings.Name,
			Value = settings.CurrentValue == true,
			Desc = settings.Tooltip,
			Callback = settings.Callback or function() end,
		})
		return wrapElement(function(nextSettings)
			if nextSettings.CurrentValue ~= nil then
				setElementValue(handle, nextSettings.CurrentValue == true)
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
		local defaultValue = tonumber(settings.CurrentValue) or minValue
		local handle = rawGroup:Slider({
			Title = settings.Name,
			Desc = settings.Tooltip,
			Step = Core.sliderIncrement(minValue, maxValue, settings.Increment),
			Value = {
				Min = minValue,
				Max = maxValue,
				Default = defaultValue,
			},
			Callback = settings.Callback or function() end,
		})
		return wrapElement(function(nextSettings)
			if nextSettings.CurrentValue ~= nil then
				setElementValue(handle, tonumber(nextSettings.CurrentValue) or minValue)
			end
		end, {
			raw = handle,
			bindKey = settings.BindKey or settings.StateKey,
			kind = "slider",
		})
	end

	function groupbox:CreateButton(settings, id)
		rawGroup:Button({
			Title = settings.Name,
			Desc = settings.Tooltip,
			Callback = settings.Callback or function() end,
		})
		return { Set = function() end }
	end

	function groupbox:CreateInput(settings, id)
		local initialValue = tostring(settings.CurrentValue or settings.Default or "")
		local userCallback = settings.Callback or function() end
		local acceptInput = false
		local handle = rawGroup:Input({
			Title = settings.Name,
			Value = initialValue,
			Placeholder = settings.PlaceholderText or settings.Placeholder or "",
			Desc = settings.Tooltip,
			Callback = function(value)
				if not acceptInput then
					return
				end
				userCallback(value)
			end,
		})
		acceptInput = true
		return wrapElement(function(nextSettings)
			if nextSettings.CurrentValue ~= nil then
				setElementValue(handle, tostring(nextSettings.CurrentValue))
			end
		end)
	end

	function groupbox:CreateDropdown(settings, id)
		local values = settings.Options or settings.Values or {}
		local multi = settings.MultipleOptions == true or settings.Multi == true
		local current = dropdownDefault(values, settings.CurrentOption, multi)
		local userCallback = settings.Callback or function() end
		local handle = rawGroup:Dropdown({
			Title = settings.Name,
			Values = values,
			Value = multi and current or current,
			Multi = multi,
			Desc = settings.Tooltip,
			Callback = function(selection)
				if multi then
					userCallback(Core.normalizeMultiSelection(selection))
				else
					userCallback(Core.normalizeDropdownValue(selection, current))
				end
			end,
		})
		return wrapElement(function(nextSettings)
			if not handle then
				return
			end
			local nextValues = nextSettings.Options or nextSettings.Values
			if nextValues and handle.Refresh then
				handle:Refresh(nextValues)
			elseif nextValues and handle.SetValues then
				handle:SetValues(nextValues)
			end
			local pick = nextSettings.CurrentOption or nextSettings.CurrentOptions
			if pick == nil then
				return
			end
			if multi and type(pick) == "table" then
				local selected = {}
				for index, value in ipairs(pick) do
					table.insert(selected, tostring(value))
				end
				for key, value in pairs(pick) do
					if type(key) ~= "number" and value == true then
						table.insert(selected, tostring(key))
					end
				end
				setElementValue(handle, selected)
			else
				setElementValue(handle, type(pick) == "table" and pick[1] or pick)
			end
		end, {
			raw = handle,
			bindKey = settings.BindKey or settings.StateKey,
			kind = "dropdown",
		})
	end

	function groupbox:CreateLabel(settings, id)
		local text = type(settings) == "table" and (settings.Name or settings.Text) or tostring(settings or "")
		local label = rawGroup:Paragraph({
			Title = text,
		})
		local visibleTarget = labelVisibilityTarget(label)
		return {
			Set = function(_, nextSettings)
				local nextText = type(nextSettings) == "table" and (nextSettings.Name or nextSettings.Text)
					or tostring(nextSettings or "")
				if label and label.SetTitle then
					label:SetTitle(nextText)
				elseif label and label.Set then
					label:Set(nextText)
				end
			end,
			_windLabel = label,
			_visibleTarget = visibleTarget,
			TextLabel = visibleTarget,
		}
	end

	function groupbox:CreateDivider()
		if rawGroup.Space then
			rawGroup:Space()
		end
		return {}
	end

	return groupbox
end

Core.createObsidianGroupbox = Core.createWindUiGroupbox

function Core.wrapUiTab(rawTab, uiBundle, window)
	local tab = {
		_rawTab = rawTab,
		_ui = uiBundle,
		_window = window,
		_columnCount = 1,
	}

	local function resolveSectionParent(column)
		column = math.clamp(tonumber(column) or 1, 1, 2)
		if not rawTab or tab._columnCount < 2 or type(rawTab.HStack) ~= "function" then
			return rawTab, column
		end
		tab._layout = tab._layout or {}
		local layout = tab._layout
		if not layout.ready then
			layout.hstack = rawTab:HStack({})
			if layout.hstack and type(layout.hstack.VStack) == "function" then
				layout.cols = {
					layout.hstack:VStack({}),
					layout.hstack:VStack({}),
				}
				layout.ready = layout.cols[1] ~= nil and layout.cols[2] ~= nil
			end
		end
		if layout.ready and layout.cols and layout.cols[column] and type(layout.cols[column].Section) == "function" then
			return layout.cols[column], column
		end
		return rawTab, column
	end

	function tab:CreateGroupbox(settings)
		settings = settings or {}
		local name = settings.Name or "Group"
		local parent = select(1, resolveSectionParent(settings.Column or 1))
		if not parent or type(parent.Section) ~= "function" then
			parent = rawTab
		end
		local rawGroup = parent:Section({
			Title = name,
			Box = true,
			BoxBorder = true,
			Opened = true,
		})
		return Core.createWindUiGroupbox(rawGroup, uiBundle)
	end

	function tab:BuildThemeGroupbox(column)
		local group = Core.buildUiGroup(tab, "Appearance", column or 1)
		local windUi = uiBundle and (uiBundle.WindUI or uiBundle.Library)
		local themes = (uiBundle and uiBundle.ThemeNames) or { "Alleral", "AlleralNeon", "Dark", "Light" }
		if windUi and type(windUi.ListThemeNames) == "function" then
			local ok, listed = pcall(function()
				return windUi:ListThemeNames()
			end)
			if ok and type(listed) == "table" and #listed > 0 then
				themes = listed
			end
		end
		local current = "Alleral"
		if windUi and type(windUi.GetCurrentTheme) == "function" then
			local ok, theme = pcall(function()
				return windUi:GetCurrentTheme()
			end)
			if ok and theme then
				current = theme
			end
		end
		group:CreateDropdown("Theme preset", themes, current, function(selected)
			if windUi and type(windUi.SetTheme) == "function" then
				pcall(function()
					windUi:SetTheme(selected)
					if type(windUi.FlashAccent) == "function" then
						windUi:FlashAccent()
					end
				end)
			end
			Core.notify("Theme", "theme: " .. tostring(selected), 2, "success")
		end, "Choose a color preset.")
		group:CreateButton("Next theme", function()
			if windUi and type(windUi.CycleTheme) == "function" then
				local ok, nextTheme = pcall(function()
					return windUi:CycleTheme(1)
				end)
				if ok and nextTheme and nextTheme.Name then
					Core.notify("Theme", "Applied " .. tostring(nextTheme.Name), 2, "success")
				end
			end
		end, "Cycles through available presets.")

		local accentPresets = { "Mint", "Cyan", "Violet", "Rose", "Amber", "Ice" }
		group:CreateDropdown("Accent color", accentPresets, "Mint", function(selected)
			if windUi and type(windUi.ApplyAccentPreset) == "function" then
				pcall(function()
					windUi:ApplyAccentPreset(selected)
					if type(windUi.FlashAccent) == "function" then
						windUi:FlashAccent()
					end
				end)
			elseif windUi and type(windUi.SetAccentColor) == "function" then
				local hex = ({
					Mint = "#53fc18",
					Cyan = "#22d3ee",
					Violet = "#a78bfa",
					Rose = "#fb7185",
					Amber = "#fbbf24",
					Ice = "#93c5fd",
				})[selected] or "#53fc18"
				pcall(function()
					windUi:SetAccentColor(Color3.fromHex(hex))
					if type(windUi.FlashAccent) == "function" then
						windUi:FlashAccent()
					end
				end)
			end
		end, "Accent for toggles and highlights.")

		local profileNames = { "auto", "desktop", "mobile", "compact", "performance" }
		local profileLabels = {
			auto = "Auto",
			desktop = "Desktop",
			mobile = "Mobile",
			compact = "Compact",
			performance = "Performance",
		}
		local currentProfile = ENV.Alleral_UiProfile or "auto"
		group:CreateDropdown("Layout profile", profileNames, currentProfile, function(selected)
			ENV.Alleral_UiProfile = selected
			if windUi and type(windUi.ApplyProfile) == "function" then
				pcall(function()
					windUi:ApplyProfile(selected)
				end)
			end
			Core.notify("UI", "Profile: " .. tostring(profileLabels[selected] or selected), 2, "info")
		end, "Auto picks mobile or desktop from your device.")

		group:CreateSlider("UI scale", 0.85, 1.1, tonumber(ENV.Alleral_UiScale) or 1, function(value)
			ENV.Alleral_UiScale = value
			if windUi and type(windUi.SetUiScale) == "function" then
				pcall(function()
					windUi:SetUiScale(value)
				end)
			end
		end, "Shrink or enlarge the whole menu.")

		group:CreateToggle("Reduced motion", ENV.Alleral_UiReducedMotion == true, "Disables animations.", function(value)
			ENV.Alleral_UiReducedMotion = value == true
			if windUi and type(windUi.SetReducedMotion) == "function" then
				pcall(function()
					windUi:SetReducedMotion(value == true)
				end)
			end
		end)

		group:CreateToggle("Spring motion", ENV.Alleral_UiSpringMotion ~= false, "Springs on menus and controls.", function(value)
			ENV.Alleral_UiSpringMotion = value ~= false
			if windUi and type(windUi.SetSpringMotion) == "function" then
				pcall(function()
					windUi:SetSpringMotion(value ~= false)
				end)
			end
		end)

		group:CreateToggle("Startup animation", ENV.Alleral_UiStartup ~= false, "Opening sweep when the menu loads.", function(value)
			ENV.Alleral_UiStartup = value == true
			if windUi and type(windUi.SetStartupEffect) == "function" then
				pcall(function()
					windUi:SetStartupEffect(value == true)
				end)
			end
		end)

		group:CreateToggle("Compact notifications", ENV.Alleral_NotifyCompact == true, "Tighter toast stack.", function(value)
			ENV.Alleral_NotifyCompact = value == true
			if windUi and type(windUi.SetNotificationCompact) == "function" then
				pcall(function()
					windUi:SetNotificationCompact(value == true)
				end)
			end
		end)

		group:CreateToggle("Touch feedback", ENV.Alleral_UiTouchFeedback ~= false, "Button press scale on click.", function(value)
			ENV.Alleral_UiTouchFeedback = value ~= false
			if windUi and type(windUi.SetTouchFeedback) == "function" then
				pcall(function()
					windUi:SetTouchFeedback(value ~= false)
				end)
			end
		end)

		group:CreateToggle("Haptics", ENV.Alleral_UiHaptics == true, "Light vibration on toggles (mobile).", function(value)
			ENV.Alleral_UiHaptics = value == true
			if windUi and type(windUi.SetHaptics) == "function" then
				pcall(function()
					windUi:SetHaptics(value == true)
				end)
			end
		end)

		group:CreateToggle("Dedupe notifications", ENV.Alleral_NotifyDedupe ~= false, "Skip identical toasts within 2s.", function(value)
			ENV.Alleral_NotifyDedupe = value ~= false
			if windUi and type(windUi.SetNotifyDedupe) == "function" then
				pcall(function()
					windUi:SetNotifyDedupe(value ~= false)
				end)
			end
		end)

		return group
	end

	return tab
end

Core.wrapRayfieldTab = Core.wrapUiTab


function Core.ensureCore()
	if ENV.Alleral_Core then
		return ENV.Alleral_Core
	end
	local loadStringFn = Core.loadStringFn()
	local isFile = ENV.isfile
	local readFile = ENV.readfile
	if type(loadStringFn) ~= "function" or type(isFile) ~= "function" or type(readFile) ~= "function" then
		return nil
	end
	for _, path in ipairs({ "hub/core.luau", "core/alleral_core.luau", "src/alleral_core.luau", "alleral_core.luau" }) do
		if isFile(path) then
			local ok = pcall(loadStringFn(readFile(path), "Alleral/core")())
			if ok and ENV.Alleral_Core then
				return ENV.Alleral_Core
			end
		end
	end
	return nil
end

local function signalBootFailure(message)
	ENV.Alleral_StartupFailed = message
	if ENV.Alleral_State then
		ENV.Alleral_State.StartupFailed = message
	end
	pcall(function()
		if shared then
			shared.Alleral_StartupFailed = message
		end
	end)
	local report = ENV.Alleral_ReportError
	if type(report) == "function" then
		pcall(report, "boot", message)
	end
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
	local core = Core.ensureCore()
	if not core then
		local msg = "Core not loaded"
		signalBootFailure(msg)
		return nil, nil, msg
	end
	state.HubRunning = true
	core.initAnalytics()
	core.installErrorLogHook()
	if state.AntiAFK ~= false then
		core.setupAntiAfk(game:GetService("Players").LocalPlayer)
	end
	local cachedUi = ENV.Alleral_UI or ENV.Alleral_Rayfield
	local uiLibrary = type(cachedUi) == "table" and type(cachedUi.Library) == "table" and cachedUi or nil
	local err
	if not uiLibrary then
		uiLibrary, err = core.loadUi()
	end
	if not uiLibrary then
		task.wait(0.2)
		uiLibrary, err = core.loadUi()
	end
	if not uiLibrary then
		local msg = err or "UI unavailable"
		signalBootFailure(msg)
		return nil, nil, msg
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
	for name, controller in pairs(loopControllers) do
		if controller then
			controller.enabled = false
		end
		loopControllers[name] = nil
	end
	for _, loopState in pairs(loops) do
		loopState.enabled = false
	end
	for key, connection in pairs(connections) do
		if connection and connection.Disconnect then
			pcall(function()
				connection:Disconnect()
			end)
		end
		connections[key] = nil
	end
	if onStop then
		pcall(onStop)
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
	Core.mergeDefaults(state, defaults)
	local savedKeys = Core.buildSavedKeys(defaults, exclude)
	Core.loadSettings(state, savedKeys, filename, defaults)
	local function saveSettings()
		return Core.saveSettings(state, savedKeys, filename)
	end
	return saveSettings, savedKeys
end

function Core.saveSettings(state, keys, filename)
	local payload = {}
	for _, key in ipairs(keys) do
		payload[key] = state[key]
	end
	local encodeOk, json = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if not encodeOk or type(json) ~= "string" or json == "" then
		Core.notify("Alleral", "Couldn't encode settings — nothing saved.", 5)
		return false
	end
	Core.backupSettings(filename, json)
	local target = "Alleral_Configs/" .. filename
	local previous = Core.readFile(target)
	local ok = Core.writeFile(target, json)
	if not ok and previous then
		pcall(function()
			Core.writeFile(target, previous)
		end)
		Core.notify("Alleral", "Save failed — restored previous settings file.", 5)
		return false
	end
	if not ok then
		Core.notify("Alleral", "Couldn't save settings. Your executor may not support writefile.", 5)
	end
	return ok
end

function Core.loadSettings(state, keys, filename, defaults)
	local target = "Alleral_Configs/" .. filename
	local raw = Core.readFile(target)
	if not raw then
		return false
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		if Core.restoreSettingsFromBackup(filename, state, keys, defaults) then
			Core.notify("Alleral", "settings were busted — loaded a backup", 5)
			return true
		end
		return false
	end
	for _, key in ipairs(keys) do
		if decoded[key] ~= nil then
			state[key] = Core.copyValue(decoded[key])
		end
	end
	return true
end

function Core.wrapUiGroup(groupbox, callbackWrapper)
	local group = {}
	local serial = 0
	local MAX_RENDERED_DROPDOWN_OPTIONS = 50

	local function nextId(name)
		serial += 1
		return tostring(name) .. "_" .. HttpService:GenerateGUID(false):sub(1, 8) .. "_" .. serial
	end

	local function wrap(label, callback)
		callback = callback or function() end
		local function guarded(...)
			local ok, err = pcall(callback, ...)
			if not ok then
				Core.pushErrorLog("UI:" .. tostring(label), err)
				Core.reportError("UI:" .. tostring(label), err)
				warn("[Alleral UI:" .. tostring(label) .. "] " .. tostring(err))
			end
		end
		if not callbackWrapper then
			return guarded
		end
		for _, args in ipairs({ { label, guarded }, { guarded } }) do
			local ok, wrapped = pcall(callbackWrapper, table.unpack(args))
			if ok and type(wrapped) == "function" then
				return function(...)
					local innerOk, innerErr = pcall(wrapped, ...)
					if not innerOk then
						Core.pushErrorLog("UI:" .. tostring(label), innerErr)
						Core.reportError("UI:" .. tostring(label), innerErr)
					end
				end
			end
		end
		return guarded
	end

	local function normalizeOptions(values)
		local output = {}
		local seen = {}
		for _, value in ipairs(values or {}) do
			local text = tostring(value)
			if text ~= "" and not seen[text] then
				seen[text] = true
				table.insert(output, text)
			end
		end
		return output
	end

	local function currentSelection(default, multi)
		if type(default) == "table" then
			local copy = {}
			for i, v in ipairs(default) do
				copy[i] = v
			end
			for k, v in pairs(default) do
				if type(k) ~= "number" then
					copy[k] = v
				end
			end
			return copy
		end
		if multi then
			return default and { tostring(default) } or {}
		end
		return tostring(default or "")
	end

	local function compactOptions(values, selected, limit)
		values = normalizeOptions(values)
		limit = limit or MAX_RENDERED_DROPDOWN_OPTIONS
		if #values <= limit then
			return values
		end
		local output = {}
		local seen = {}
		local selectedList = type(selected) == "table" and selected or { selected }
		for _, value in ipairs(selectedList) do
			local text = tostring(value)
			if text ~= "" and not seen[text] then
				seen[text] = true
				table.insert(output, text)
			end
		end
		for _, value in ipairs(values) do
			if #output >= limit then
				break
			end
			if not seen[value] then
				table.insert(output, value)
			end
		end
		return output
	end

	local function instanceHasChild(parent, childName)
		if type(parent) ~= "table" or type(parent.FindFirstChild) ~= "function" then
			return false
		end
		return parent:FindFirstChild(childName) ~= nil
	end

	local function waitForElement(element, timeout)
		local started = tick()
		repeat
			if element and (element._visibleTarget or element.TextLabel or element._windLabel) then
				return true
			end
			task.wait()
		until tick() - started >= (timeout or 3)
		return element and (element._visibleTarget or element.TextLabel or element._windLabel) ~= nil
	end

	local function setVisible(element, visible)
		if not element then
			return
		end
		local target = element._visibleTarget or element.TextLabel
		if target and target.Visible ~= nil then
			target.Visible = visible
			return
		end
		if element._windLabel then
			local fallback = windUiVisibilityTarget(element._windLabel)
			if fallback and fallback.Visible ~= nil then
				fallback.Visible = visible
			end
		end
	end

	function group:CreateToggle(name, default, tooltip, callback, bindKey)
		return groupbox:CreateToggle({
			Name = name,
			CurrentValue = default == true,
			Tooltip = tooltip,
			Callback = wrap(name, callback),
			BindKey = bindKey,
		}, nextId(name))
	end

	function group:CreateSlider(name, min, max, default, callback, tooltip, increment, bindKey)
		return groupbox:CreateSlider({
			Name = name,
			Range = { min, max },
			Increment = increment,
			CurrentValue = tonumber(default) or min,
			Tooltip = tooltip,
			Callback = wrap(name, callback),
			BindKey = bindKey,
		}, nextId(name))
	end

	function group:CreateButton(name, callback, tooltip)
		return groupbox:CreateButton({
			Name = name,
			Tooltip = tooltip,
			Callback = wrap(name, callback),
		}, nextId(name))
	end

	function group:CreateInput(name, placeholder, arg3, arg4, arg5)
		local icon, default, callback, tip
		local function isIcon(value)
			local text = tostring(value or "")
			return text:find("rbxassetid") ~= nil or text:match("^%d+$") ~= nil
		end
		if type(arg3) == "function" then
			callback = arg3
			tip = arg4
		elseif type(arg4) == "function" and isIcon(arg3) then
			icon = Core.uiIcon(arg3)
			callback = arg4
			tip = arg5
		elseif type(arg4) == "function" then
			default = tostring(arg3 or "")
			callback = arg4
			tip = arg5
		else
			icon = Core.uiIcon(arg3)
			callback = arg4
			tip = arg5
		end
		return groupbox:CreateInput({
			Name = name,
			Icon = icon,
			Placeholder = placeholder,
			PlaceholderText = placeholder,
			CurrentValue = default or "",
			RemoveTextOnFocus = false,
			Tooltip = tip,
			Callback = wrap(name, callback),
		}, nextId(name))
	end

	function group:CreateDropdown(name, options, default, callback, tooltip, bindKey)
		return groupbox:CreateDropdown({
			Name = name,
			Options = normalizeOptions(options),
			CurrentOption = default,
			Tooltip = tooltip,
			Callback = wrap(name, callback),
			BindKey = bindKey,
		}, nextId(name))
	end

	function group:AddDropdown(id, config)
		config = config or {}
		local multi = config.Multi == true or config.MultiSelection == true
		local values = normalizeOptions(config.Values or config.Options)
		local current = currentSelection(config.Default or config.CurrentValue or config.CurrentOption, multi)
		local handle = {
			Values = values,
			Selection = current,
			Dropdown = nil,
			LastSearch = "",
		}
		local function safeCallback(selection)
			local normalized = multi and Core.normalizeMultiSelection(selection)
				or Core.normalizeDropdownValue(selection, current)
			handle.Selection = multi and normalized or currentSelection(normalized, false)
			wrap(config.Text or config.Name or id, config.Callback or function() end)(normalized)
		end
		local function rebuild(currentValues)
			local nextValues = currentValues or handle.Values
			if config.Searchable then
				nextValues = compactOptions(nextValues, handle.Selection)
			end
			if handle.Dropdown and handle.Dropdown.Set then
				handle.Dropdown:Set({
					Options = nextValues,
					Values = nextValues,
					CurrentOption = handle.Selection,
					CurrentOptions = type(handle.Selection) == "table" and handle.Selection or nil,
					MultipleOptions = multi,
					Placeholder = config.Placeholder or "--",
					Callback = safeCallback,
				})
			end
		end
		local renderedValues = config.Searchable and compactOptions(values, current) or values
		local dropdown = groupbox:CreateDropdown({
			Name = config.Text or config.Name or id,
			Options = renderedValues,
			Values = renderedValues,
			CurrentOption = current,
			MultipleOptions = multi,
			Callback = safeCallback,
		}, nextId(id .. "_dd"))
		handle.Dropdown = dropdown
		function handle:SetValues(newValues, newDefault)
			self.Values = normalizeOptions(newValues)
			self.Selection = currentSelection(newDefault or self.Selection, multi)
			rebuild(self.Values)
		end
		function handle:Refresh(newValues, newDefault)
			self:SetValues(newValues, newDefault)
		end
		function handle:Search(query)
			self.LastSearch = tostring(query or "")
			local filtered = self.LastSearch == "" and self.Values
				or compactOptions(Core.filterDropdownOptions(self.Values, self.LastSearch), self.Selection)
			rebuild(filtered)
		end
		if config.Searchable then
			groupbox:CreateInput({
				Name = (config.Text or config.Name or id) .. " filter",
				PlaceholderText = "search...",
				RemoveTextOnFocus = false,
				Callback = wrap((config.Text or config.Name or id) .. " Search", function(text)
					handle:Search(text)
				end),
			}, nextId(id .. "_search"))
		end
		return handle
	end

	function group:CreateLabel(text)
		return groupbox:CreateLabel({
			Name = text,
		}, nextId("label"))
	end

	function group:CreateStatus(label, fields)
		local status = {
			Labels = {},
			LastValues = {},
			Visible = true,
		}
		for key, value in pairs(fields or {}) do
			local rendered = tostring(value)
			status.LastValues[key] = rendered
			status.Labels[key] = groupbox:CreateLabel({
				Name = tostring(key) .. ": " .. rendered,
			}, nextId(label .. "_" .. tostring(key)))
		end
		status.Labels.Summary = groupbox:CreateLabel({
			Name = "",
		}, nextId(label .. "_summary"))
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
			self.Visible = visible
			for _, row in pairs(self.Labels) do
				setVisible(row, visible)
			end
		end
		return status
	end

	function group:CreateDivider()
		return groupbox:CreateDivider()
	end

	return group
end

function Core.dropdownEntryText(value)
	if type(value) == "table" then
		return tostring(value.Title or value.Name or value.Text or value[1] or "")
	end
	return tostring(value or "")
end

function Core.normalizeMultiSelection(selection)
	local picked = {}
	if type(selection) == "string" then
		if selection ~= "" then
			table.insert(picked, selection)
		end
		return picked
	end
	if type(selection) ~= "table" then
		return picked
	end
	local hasBooleanMap = false
	for key, value in pairs(selection) do
		if type(key) ~= "number" and type(value) == "boolean" then
			hasBooleanMap = true
			break
		end
	end
	if hasBooleanMap then
		for item, enabled in pairs(selection) do
			if type(item) == "number" then
				if enabled ~= nil and enabled ~= false then
					local text = Core.dropdownEntryText(enabled)
					if text ~= "" then
						table.insert(picked, text)
					end
				end
			elseif enabled then
				local text = Core.dropdownEntryText(item)
				if text ~= "" then
					table.insert(picked, text)
				end
			end
		end
		return picked
	end
	for _, value in ipairs(selection) do
		local text = Core.dropdownEntryText(value)
		if text ~= "" then
			table.insert(picked, text)
		end
	end
	if #picked == 0 then
		for key, value in pairs(selection) do
			if type(key) ~= "number" and value == true then
				local text = Core.dropdownEntryText(key)
				if text ~= "" then
					table.insert(picked, text)
				end
			end
		end
	end
	return picked
end

function Core.normalizeDropdownValue(selection, fallback)
	if type(selection) == "table" then
		local text = Core.dropdownEntryText(selection)
		if text ~= "" then
			return text
		end
		if selection[1] ~= nil then
			return Core.normalizeDropdownValue(selection[1], fallback)
		end
	elseif type(selection) == "string" or type(selection) == "number" or type(selection) == "boolean" then
		return tostring(selection)
	end
	return fallback
end

function Core.selectionFirst(selection, fallback)
	local items = Core.normalizeMultiSelection(selection)
	if items[1] and items[1] ~= "" then
		return items[1]
	end
	return fallback or ""
end

function Core.listContains(selection, value)
	local list = Core.normalizeMultiSelection(selection)
	if #list == 0 then
		return false
	end
	return table.find(list, value) ~= nil
end

function Core.listMatches(selection, value)
	local list = Core.normalizeMultiSelection(selection)
	if #list == 0 then
		return true
	end
	if Core.listContains(list, "Any") or Core.listContains(list, "All") or Core.listContains(list, "any") then
		return true
	end
	return Core.listContains(list, value)
end

function Core.uiIcon(icon)
	return tostring(icon or ""):match("%d+$") or ""
end

function Core.uiElementId(text)
	return (tostring(text or "Element"):gsub("[^%w_]", "_"))
end

function Core.hasPremiumAccess()
	if getgenv().JD_IS_PREMIUM == true then
		return true
	end
	local access = ENV.Alleral_Access
	if type(access) == "table" and type(access.isPremium) == "function" then
		return access.isPremium() == true
	end
	return true
end

function Core.accessMode()
	local access = ENV.Alleral_Access
	if type(access) == "table" and type(access.mode) == "function" then
		return access.mode()
	end
	return "public"
end

function Core.buildUiWindow(ui, settings)
	settings = settings or {}
	local lib = ui and (ui.WindUI or ui.Library)
	if not lib then
		return nil
	end
	local windowSettings = {
		Title = settings.Name or "Alleral",
		Author = settings.Subtitle or "",
		Folder = (settings.FileSettings or {}).RootFolder or (settings.FileSettings or {}).ConfigFolder or "Alleral_Configs",
		Icon = Core.windUiIcon(settings.Icon or "leaf"),
		Theme = "Alleral",
		NewElements = true,
		HideSearchBar = false,
		UICorner = 20,
		UIPadding = 20,
		SideBarWidth = 256,
		ElementPadding = 14,
		Resizable = true,
		OpenButton = {
			Title = "Alleral",
			Enabled = true,
			Draggable = true,
			OnlyMobile = false,
			Color = ColorSequence.new(ALLERAL_ACCENT, ALLERAL_ACCENT_ALT),
		},
	}
	local rawWindow = lib:CreateWindow(windowSettings)
	if not rawWindow and type(lib.ReleaseWindow) == "function" then
		pcall(function()
			lib:ReleaseWindow(lib.Window)
		end)
		task.wait(0.05)
		rawWindow = lib:CreateWindow(windowSettings)
	end
	if not rawWindow then
		Core.logWarn("WindUI window create failed")
		return nil
	end
	applyAlleralTheme(ui)
	local window = {
		_rawWindow = rawWindow,
		_ui = ui,
		_library = lib,
		_windSection = nil,
	}
	Core.registerUiWindow(window)
	Core.flushPendingNotifications()
	function window:AddTab(name, icon)
		if not self._rawWindow or type(self._rawWindow.Section) ~= "function" then
			Core.logWarn("AddTab skipped — window missing")
			return nil
		end
		if not self._windSection then
			self._windSection = self._rawWindow:Section({
				Title = "Alleral",
			})
		end
		return self._windSection:Tab({
			Title = name,
			Icon = Core.windUiIcon(icon),
			Border = true,
		})
	end
	window._ui = ui
	window._library = lib
	return window
end

function Core.buildUiSection(window)
	return {
		_window = window,
		_ui = window._ui,
	}
end

function Core.buildUiTab(section, name, icon, columns, id)
	local window = section._window or section
	if not window or not window._rawWindow then
		Core.logWarn("buildUiTab skipped — window missing")
		return Core.wrapUiTab(nil, section._ui, window)
	end
	local iconArg = nil
	if icon then
		local numeric = tonumber(Core.uiIcon(icon))
		if numeric then
			iconArg = numeric
		elseif type(icon) == "string" and icon ~= "" and not icon:find("rbxassetid", 1, true) then
			iconArg = icon
		end
	end
	local rawTab = iconArg and window:AddTab(name, iconArg) or window:AddTab(name)
	local wrapped = Core.wrapUiTab(rawTab, window._ui or section._ui, window)
	wrapped._columnCount = math.max(1, tonumber(columns) or 1)
	return wrapped
end

Core.buildRayfieldWindow = Core.buildUiWindow
Core.buildRayfieldSection = Core.buildUiSection
Core.buildRayfieldTab = Core.buildUiTab

function Core.onUiSave(saveFn)
	return function(_, callback)
		return function(...)
			local result = callback(...)
			if type(saveFn) == "function" then
				saveFn()
			end
			return result
		end
	end
end

function Core.buildUiGroup(tab, name, column, callbackWrapper, icon, id)
	local groupbox = tab:CreateGroupbox({
		Name = name,
		Column = column or 1,
		Icon = icon and Core.uiIcon(icon) or nil,
	}, id or Core.uiElementId(name))
	if callbackWrapper then
		return Core.wrapUiGroup(groupbox, callbackWrapper)
	end
	return Core.wrapUiGroup(groupbox)
end

Core.buildRayfieldGroup = Core.buildUiGroup

function Core.filterDropdownOptions(values, query)
	query = tostring(query or ""):lower()
	if query == "" then
		return values
	end
	local filtered = {}
	for _, value in ipairs(values or {}) do
		if tostring(value):lower():find(query, 1, true) then
			table.insert(filtered, value)
		end
	end
	return filtered
end

function Core.makeSupervisor(state, loops, controllers, name, interval, callback)
	if controllers[name] then
		controllers[name].enabled = false
		controllers[name] = nil
	end
	local loopState = {
		enabled = true,
		token = HttpService:GenerateGUID(false),
	}
	loops[name] = loopState
	controllers[name] = loopState
	task.spawn(function()
		local token = loopState.token
		while state.HubRunning and loopState.enabled and controllers[name] == loopState and loopState.token == token do
			local ok, err = pcall(callback)
			if not ok then
				Core.reportError("Loop:" .. name, err)
				warn("[Alleral:" .. name .. "] " .. tostring(err))
				task.wait(math.min(5, interval * 2))
			else
				task.wait(interval)
			end
		end
	end)
end

function Core.setupAntiAfk(player)
	local getConnections = ENV.getconnections or ENV.get_signal_cons
	if getConnections then
		for _, connection in ipairs(getConnections(player.Idled)) do
			if connection.Disable then
				connection:Disable()
			elseif connection.Disconnect then
				connection:Disconnect()
			end
		end
	else
		local VirtualUser = game:GetService("VirtualUser")
		player.Idled:Connect(function()
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new(0, 0))
			end)
		end)
	end
	task.spawn(function()
		local VirtualUser = game:GetService("VirtualUser")
		while player.Parent do
			task.wait(120)
			pcall(function()
				local camera = workspace.CurrentCamera
				if not camera then
					return
				end
				VirtualUser:Button2Down(Vector2.new(100, 100), camera.CFrame)
				task.wait(0.2)
				VirtualUser:Button2Up(Vector2.new(100, 100), camera.CFrame)
			end)
		end
	end)
end

function Core.initAnalytics()
	local tracker = ENV.Alleral_Analytics
	if tracker and tracker.Track then
		tracker:Track()
	end
	return tracker
end

function Core.reportError(scope, err, details)
	local reporter = ENV.Alleral_ReportError
	if type(reporter) == "function" then
		pcall(reporter, scope, err, details)
	end
end

function Core.logEvent(category, message, data)
	local logger = ENV.Alleral_LogEvent
	if type(logger) == "function" then
		pcall(logger, category, message, data)
	end
end

Core.installResilience()

ENV.Alleral_Core = Core
return Core
