--!nocheck
local LOADER_VERSION = "8.2.25"
local MIN_CORE = "2.7.0"
local DEFAULT_UPDATE_POLL_SECONDS = 120
local EXPECTED_VERSIONS_CACHE_SECONDS = 300
local COMPILE_VALIDATE_CACHE = {}
local CORE_BASE_MIN_BYTES = 30000
local CORE_BASE_MAX_BYTES = 45000
local CORE_UI_MIN_BYTES = 50000
local CORE_HUB_UI_MIN_BYTES = 60000
local CORE_ALLERAL_UI_MIN_BYTES = 12000
local CORE_MONOLITH_MIN_BYTES = 130000
local HUB = "hub"
local CFG = "cfg"
local UI = "ui"
local SYDE_SOURCE_PATH = UI .. "/syde/source.luau"
local SYDE_SOURCE_MIN_BYTES = 5000
local SYDE_PATCH_MARKER = "ALLERAL_SYDE_PATCH"
local SYDE_PATCH_VERSION = 34 -- Restores grouped two-column layout with native Syde controls
local MAX_RELAUNCHES = 3
local RELAUNCH_COOLDOWN = 15
local SYDE_PATCH_REQUIRED_FN = "sydePrepareDropdownDrop"
local SYDE_PATCHED_OVERRIDE_PATHS = {
	"syde_patched.luau",
	"patched_syde.luau",
	".alleral/syde_patched.luau",
	"kick/syde_patched.luau",
	"workspace/syde_patched.luau",
}
local CP = {
	base = HUB .. "/core_base.luau",
	legacy = HUB .. "/core.luau",
	ui = HUB .. "/core_ui.luau",
	hub = HUB .. "/core_hub_ui.luau",
	alleral = HUB .. "/alleral_ui.luau",
}

local RELEASE_FALLBACK = {
	loader = "8.2.25",
	core = "2.9.5",
	ui = "Syde",
	windui = "4.0.0-syde",
	alleral = "4.0.0-syde",
	analytics = "1.2",
	telemetry = "3.3",
	helpers = "1.0",
	weao = "1.1",
	security = "1.3",
	access = "1.1",
	commit = "41a5efc",
	updatePollSeconds = DEFAULT_UPDATE_POLL_SECONDS,
	autoUpdate = true,
}
local WORKSPACE_ROOTS = {
	"",
	"kick/",
	"workspace/",
	"scripts/",
	"autoexec/",
	"Autoexec/",
	"autoexecute/",
	"AutoExecute/",
}
local INSTALL_MANIFEST = ".alleral/versions.json"
local LOADER_LOCAL_PATHS = {
	"loader.luau",
	"kick/loader.luau",
	"Alleral/loader.luau",
}
local BOOTSTRAP_REMOTE_PATH = HUB .. "/bootstrap.luau"
local BOOTSTRAP_LOCAL_PATHS = {
	HUB .. "/bootstrap.luau",
	"kick/" .. HUB .. "/bootstrap.luau",
	"alleral_bootstrap.luau",
}
local BOOTSTRAP_LOADSTRING =
	"loadstring(game:HttpGet(\"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/bootstrap.luau?t=\" .. tick(), true))()"
local LEGACY_LOADER_MARKERS = {
	"[Alleral Loader v",
	"Alleral loader 3.",
	"Alleral loader 4.",
	"Alleral loader 3.7",
	"[Alleral Bootstrap]",
	"Alleral Bootstrap]",
	"__Alleral_LaunchHandled",
	"EMBEDDED_LOADER =",
	"launch.template.luau",
	"LOADER_VERSION = \"3.",
	"LOADER_VERSION = \"4.",
	"obfusctated_uilibrary",
}
local LEGACY_ENTRY_NAMES = {
	"loader.luau",
	"load.luau",
	"launch.luau",
	"bootstrap.luau",
	"run.luau",
	"alleral.luau",
	"alleralloader.luau",
	"AlleralLoader.luau",
	"alleral_loader.luau",
}
local SCAN_DIRS = {
	"",
	"autoexec",
	"Autoexec",
	"autoexecute",
	"AutoExecute",
	"workspace",
	"scripts",
	"kick",
}
local REPO = "evanbackup1256-ship-it/kick"
local BRANCH = "main"
local GITHUB_RAW = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH
local GITHUB_WEB = "https://github.com/" .. REPO .. "/raw/" .. BRANCH
local REMOTE_BASES = { GITHUB_RAW, GITHUB_WEB }
local JSDELIVR = "https://cdn.jsdelivr.net/gh/" .. REPO .. "@" .. BRANCH
local CORE_REMOTE_BASES = { GITHUB_RAW, GITHUB_WEB, JSDELIVR }

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local function resolveGameInstance()
	if typeof(game) == "Instance" then
		return game
	end
	if _G and typeof(_G.game) == "Instance" then
		return _G.game
	end
	local env = genv()
	if typeof(env.game) == "Instance" then
		return env.game
	end
	return nil
end

local game = resolveGameInstance()
if not game then
	error(
		"[Alleral] game is nil — run the loader inside a Roblox game session (not the executor menu outside a place)."
	)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = nil
pcall(function()
	HttpService = game:GetService("HttpService")
end)

local ENV = genv()

local function loaderRunEnv()
	local env = genv()
	if typeof(env.game) ~= "Instance" then
		env.game = game
	end
	return env
end
local PREVIOUS_LOADER_VERSION = ENV._Alleral_LoaderVersion or ENV.Alleral_LoaderVersion
ENV._Alleral_LoaderVersion = LOADER_VERSION
ENV.Alleral_LoaderRunning = false

local LOADSTRING_HINT = BOOTSTRAP_LOADSTRING

local function publishConsoleApi(name, fn)
	ENV[name] = fn
	if type(getgenv) == "function" then
		local ok, g = pcall(getgenv)
		if ok and type(g) == "table" then
			g[name] = fn
		end
	end
end

local function notLoadedApi(name)
	return function()
		warn(
			"[Alleral] "
				.. name
				.. " — loader is not running. Run the GitHub loadstring first:\n"
				.. LOADSTRING_HINT
		)
		return false
	end
end

for _, apiName in ipairs({
	"Alleral_Load",
	"Alleral_PurgeCache",
	"Alleral_CheckUpdate",
	"Alleral_Reload",
	"Alleral_ScanLegacy",
	"Alleral_LoaderInfo",
	"Alleral_SyncWeao",
}) do
	publishConsoleApi(apiName, notLoadedApi(apiName))
end
if type(ENV.Alleral_Bootstrap) ~= "function" then
	publishConsoleApi("Alleral_Bootstrap", notLoadedApi("Alleral_Bootstrap"))
end

local function firstExecFunc(...)
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		if type(name) == "function" then
			return name
		end
		if type(name) == "string" then
			local fn = ENV[name] or (_G and _G[name])
			if type(fn) == "function" then
				return fn
			end
		end
	end
	return nil
end

local loadStringFn = firstExecFunc(ENV.loadstring, ENV.LoadString, loadstring, load)
local readFile = firstExecFunc("readfile", "read_file", "ReadFile")
local isFile = firstExecFunc("isfile", "is_file", "IsFile")
local writeFileFn = firstExecFunc("writefile", "write_file", "WriteFile")
local makeFolderFn = firstExecFunc("makefolder", "make_folder", "MakeFolder")
local deleteFileFn = firstExecFunc("delfile", "deletefile", "delete_file", "DeleteFile", "removefile", "RemoveFile")
local deleteFolderFn = firstExecFunc("delfolder", "deletefolder", "delete_folder", "DeleteFolder", "removefolder", "RemoveFolder")
local listFilesFn = firstExecFunc("listfiles", "list_files", "ListFiles")
local isFolderFn = firstExecFunc("isfolder", "is_folder", "IsFolder")

local function getHttpRequestFn()
	local fn = firstExecFunc("request", "http_request", "Request", "httprequest")
	if fn then
		return fn
	end
	if type(ENV.Volt) == "table" and type(ENV.Volt.request) == "function" then
		return ENV.Volt.request
	end
	if type(ENV.syn) == "table" and type(ENV.syn.request) == "function" then
		return ENV.syn.request
	end
	return nil
end

local RunService = game:GetService("RunService")

local function tryGameHttpGet(url)
	if type(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, url, true)
		if ok and type(body) == "string" and #body > 0 then
			return body, "httpget"
		end
		ok, body = pcall(game.HttpGet, game, url)
		if ok and type(body) == "string" and #body > 0 then
			return body, "httpget"
		end
	end
	return nil
end

local function log(msg, isWarn)
	local line = "[Alleral v" .. LOADER_VERSION .. "] " .. msg
	if isWarn then
		warn(line)
	else
		print(line)
	end
end

local function safeSpawn(fn)
	if type(fn) ~= "function" then
		return
	end
	if typeof(task) == "table" and type(task.spawn) == "function" then
		task.spawn(fn)
	else
		coroutine.wrap(fn)()
	end
end

local fetchExpectedVersions

local function notify(title, text, duration)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration or 5,
		})
	end)
end

local function normalizeSlug(text)
	local key = tostring(text or ""):lower()
	key = key:gsub("synapse%s*z", "synapsez")
	key = key:gsub("awp%.?gg?", "volt")
	key = key:gsub("bunni%.?fun", "bunni")
	key = key:gsub("vega%s*x", "vegax")
	key = key:gsub("[^a-z0-9]", "")
	return key
end

local function inferSlugFromText(text)
	local lower = tostring(text or ""):lower()
	for _, pair in ipairs({
		{ "synapse z", "synapsez" },
		{ "synapse", "synapse" },
		{ "potassium", "potassium" },
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
		{ "electron", "electron" },
		{ "krnl", "krnl" },
		{ "fluxus", "fluxus" },
		{ "jjsploit", "jjsploit" },
		{ "hydrogen", "hydrogen" },
		{ "macsploit", "macsploit" },
		{ "vega x", "vegax" },
		{ "madium", "madium" },
		{ "nihon", "nihon" },
		{ "bunni", "bunni" },
		{ "celery", "celery" },
		{ "oxygen", "oxygenu" },
		{ "comet", "comet" },
		{ "trigon", "trigon" },
		{ "arceus", "arceus" },
		{ "ronix", "ronix" },
		{ "evon", "evon" },
		{ "krypton", "krypton" },
		{ "sentinel", "sentinel" },
		{ "serenity", "serenity" },
		{ "atlantis", "atlantis" },
		{ "zorara", "zorara" },
	}) do
		if lower:find(pair[1], 1, true) then
			return pair[2]
		end
	end
	return nil
end

local function extractResponseBody(response)
	if type(response) == "string" then
		return response
	end
	if type(response) == "table" then
		return response.Body or response.body or response.Data or response.data
	end
	return nil
end

local function requestVia(fn, url, headers)
	if type(fn) ~= "function" then
		return nil
	end
	headers = headers or { ["Cache-Control"] = "no-cache" }

	local ok, direct = pcall(fn, url)
	if ok and type(direct) == "string" and #direct > 0 then
		return direct
	end
	if ok and type(direct) == "table" then
		local body = extractResponseBody(direct)
		if type(body) == "string" and #body > 0 then
			return body
		end
	end

	for _, spec in ipairs({
		{ Url = url, Method = "GET", Headers = headers },
		{ url = url, method = "GET", headers = headers },
	}) do
		local rok, res = pcall(fn, spec)
		if rok then
			local body = extractResponseBody(res)
			if type(body) == "string" and #body > 0 then
				return body
			end
		end
	end
	return nil
end

local HTTP_TRANSPORTS

local function httpFetch(url, headers)
	headers = headers or {}
	local bust = url .. (url:find("?") and "&" or "?") .. "t=" .. tostring(tick())

	local body, via = tryGameHttpGet(url)
	if body then
		return body, via
	end

	if HTTP_TRANSPORTS then
		for _, transport in ipairs(HTTP_TRANSPORTS) do
			body = transport.fetch(bust)
			if type(body) == "string" and #body > 0 then
				return body, transport.id
			end
		end
	end

	local req = getHttpRequestFn()
	if req then
		body = requestVia(req, bust, headers)
		if body then
			return body, "request"
		end
	end

	if HttpService and type(HttpService.GetAsync) == "function" then
		local ok, asyncBody = pcall(function()
			return HttpService:GetAsync(bust, true)
		end)
		if ok and type(asyncBody) == "string" and #asyncBody > 0 then
			return asyncBody, "httpservice"
		end
	end

	return nil
end

local function decodeJson(body)
	if type(body) ~= "string" or body == "" or not HttpService then
		return nil
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if ok and type(decoded) == "table" then
		return decoded
	end
	return nil
end

local function weaoHttpFetch(url)
	local Weao = ENV.Alleral_Weao
	local headers = Weao and Weao.requestHeaders and Weao.requestHeaders() or { ["User-Agent"] = "WEAO-3PService" }
	return httpFetch(url, headers)
end

local function detectEnvSlugs()
	local slugs = {}
	local sharedEnv = ENV.shared or (typeof(shared) == "table" and shared) or nil
	local function add(slug, ok)
		if ok then
			table.insert(slugs, slug)
		end
	end

	add("volt", type(ENV.Volt) == "table" and type(ENV.Volt.request) == "function")
	add("synapse", type(ENV.syn) == "table" and type(ENV.syn.request) == "function")
	add("krnl", ENV.KRNL_LOADED == true)
	add("fluxus", type(ENV.fluxus) == "table")
	add("xeno", type(ENV.Xeno) == "table")
	add("wave", type(ENV.Wave) == "table")
	add("electron", type(ENV.Electron) == "table")
	add("solara", type(ENV.Solara) == "table" or (sharedEnv and type(sharedEnv.solara) == "table"))
	add("potassium", type(ENV.Potassium) == "table")
	add("velocity", type(ENV.Velocity) == "table")
	add("codex", type(ENV.Codex) == "table")
	add("hydrogen", type(ENV.Hydrogen) == "table")
	add("delta", type(ENV.delta) == "table")
	add("celery", type(ENV.celery) == "table")
	add("jjsploit", ENV.IS_JJSLOIT == true or type(ENV.jjsploit) == "table")

	return slugs
end

local function localDetectExecutor()
	local rawName = ""
	for _, id in ipairs({ "identifyexecutor", "getexecutorname", "whatexecutor", "getexecutor", "getexecutorinfo" }) do
		local fn = firstExecFunc(id)
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

	local envSlugs = detectEnvSlugs()
	local slug = inferSlugFromText(rawName) or normalizeSlug(rawName)
	if slug == "" and #envSlugs > 0 then
		slug = envSlugs[1]
	end
	if slug == "" then
		slug = "unknown"
	end

	local display = rawName ~= "" and rawName or slug:sub(1, 1):upper() .. slug:sub(2)
	return { slug = slug, name = display, rawName = rawName, envSlugs = envSlugs }
end

local function resolveExecutorProfile()
	local localProfile = localDetectExecutor()
	return {
		slug = localProfile.slug,
		name = localProfile.name,
		rawName = localProfile.rawName,
		envSlugs = localProfile.envSlugs,
		weao = nil,
		weaoSource = nil,
		weaoVerified = false,
	}
end

local function refreshWeaoProfile(profile)
	local Weao = ENV.Alleral_Weao
	if not Weao then
		return profile
	end

	local exploits, weaoSource
	local fetchOk = pcall(function()
		exploits, weaoSource = Weao.fetchExploits({
			httpFetch = weaoHttpFetch,
			requestFn = getHttpRequestFn(),
			config = ENV.Alleral_WeaoConfig,
			executorSlug = profile.slug,
		})
	end)
	if not fetchOk or type(exploits) ~= "table" then
		exploits = ENV.Alleral_WeaoLastGood and ENV.Alleral_WeaoLastGood.data
		weaoSource = "cache"
	end

	local weaoEntry, weaoScore
	pcall(function()
		weaoEntry, weaoScore = Weao.matchExploit(profile, exploits)
	end)
	local weao = Weao.formatEntry and Weao.formatEntry(weaoEntry) or weaoEntry
	if weao and weao.title then
		profile.slug = normalizeSlug(weao.title)
		if profile.slug == "synapse" and profile.rawName:lower():find("z", 1, true) then
			profile.slug = "synapsez"
		end
		profile.name = weao.title
		if weao.version and weao.version ~= "" then
			profile.name = weao.title .. " " .. weao.version
		end
		profile.weao = weao
		profile.weaoSource = weaoSource
		profile.weaoVerified = true
		log(string.format("WEAO: %s (match %d%%)", profile.name, weaoScore or 0))
	else
		profile.weaoVerified = false
		profile.weao = {
			title = profile.displayName or profile.name,
			updateStatus = true,
			detected = false,
			offline = true,
		}
	end
	EXECUTOR = profile
	return profile
end

local function syncWeaoConfig(quiet)
	local Weao = ENV.Alleral_Weao
	if not Weao or type(Weao.refreshConfig) ~= "function" then
		return false
	end
	local ok, _, version, changed = pcall(function()
		return Weao.refreshConfig({
			httpFetch = function(url)
				return httpFetch(url, { ["Accept"] = "application/json", ["User-Agent"] = "WEAO-3PService" })
			end,
			urls = {
				GITHUB_RAW .. "/" .. CFG .. "/weao.json?t=" .. tick(),
				GITHUB_WEB .. "/" .. CFG .. "/weao.json?t=" .. tick(),
			},
		})
	end)
	if not ok then
		return false
	end
	if changed then
		if not quiet then
			log("WEAO config synced to v" .. tostring(version))
		end
		pcall(function()
			refreshWeaoProfile(EXECUTOR)
		end)
		if ENV.Alleral_Core and ENV.Alleral_Core.refreshLoaderCapabilities then
			pcall(ENV.Alleral_Core.refreshLoaderCapabilities)
		end
	end
	return changed == true
end

local EXECUTOR = resolveExecutorProfile()
log("Executor: " .. EXECUTOR.name .. " (" .. EXECUTOR.slug .. ")")

-- Per-executor HTTP transport order (first = preferred for that injector)
local HTTP_STRATEGIES = {
	volt = { "volt", "request", "httpget", "httpservice" },
	awp = { "volt", "request", "httpget", "httpservice" },
	synapse = { "syn", "request", "httpget", "httpservice" },
	synapsez = { "syn", "request", "httpget", "httpservice" },
	krnl = { "request", "httpget", "httpservice" },
	fluxus = { "fluxus", "request", "httpget", "httpservice" },
	solara = { "solara", "request", "httpget", "httpservice" },
	solora = { "solara", "request", "httpget", "httpservice" },
	xeno = { "xeno", "request", "httpget", "httpservice" },
	wave = { "wave", "request", "httpget", "httpservice" },
	electron = { "electron", "request", "httpget", "httpservice" },
	potassium = { "potassium", "request", "httpget", "httpservice" },
	velocity = { "velocity", "request", "httpget", "httpservice" },
	codex = { "codex", "request", "httpget", "httpservice" },
	hydrogen = { "hydrogen", "request", "httpget", "httpservice" },
	delta = { "delta", "request", "httpget", "httpservice" },
	celery = { "celery", "request", "httpget", "httpservice" },
	jjsploit = { "httpget", "request", "httpservice" },
	default = { "request", "httpget", "httpservice" },
}

local function buildHttpTransports(slug)
	local sharedEnv = ENV.shared or (typeof(shared) == "table" and shared) or nil
	local solaraLib = sharedEnv and type(sharedEnv.solara) == "table" and sharedEnv.solara or nil
	local transports = {
		volt = function(url)
			if type(ENV.Volt) == "table" and type(ENV.Volt.request) == "function" then
				return requestVia(ENV.Volt.request, url)
			end
			return requestVia(getHttpRequestFn(), url)
		end,
		syn = function(url)
			return ENV.syn and requestVia(ENV.syn.request, url)
		end,
		fluxus = function(url)
			return ENV.fluxus and requestVia(ENV.fluxus.request, url)
		end,
		solara = function(url)
			if solaraLib and type(solaraLib.request) == "function" then
				return requestVia(solaraLib.request, url)
			end
			if type(ENV.Solara) == "table" then
				return requestVia(ENV.Solara.request, url)
			end
			return nil
		end,
		xeno = function(url)
			return type(ENV.Xeno) == "table" and requestVia(ENV.Xeno.request, url)
		end,
		wave = function(url)
			return type(ENV.Wave) == "table" and requestVia(ENV.Wave.request, url)
		end,
		electron = function(url)
			return type(ENV.Electron) == "table" and requestVia(ENV.Electron.request, url)
		end,
		potassium = function(url)
			return type(ENV.Potassium) == "table" and requestVia(ENV.Potassium.request, url)
		end,
		velocity = function(url)
			return type(ENV.Velocity) == "table" and requestVia(ENV.Velocity.request, url)
		end,
		codex = function(url)
			return type(ENV.Codex) == "table" and requestVia(ENV.Codex.request, url)
		end,
		hydrogen = function(url)
			return type(ENV.Hydrogen) == "table" and requestVia(ENV.Hydrogen.request, url)
		end,
		delta = function(url)
			return type(ENV.delta) == "table" and requestVia(ENV.delta.request, url)
		end,
		celery = function(url)
			return type(ENV.celery) == "table" and requestVia(ENV.celery.request, url)
		end,
		request = function(url)
			return requestVia(getHttpRequestFn(), url)
		end,
		httpget = function(url)
			if type(game.HttpGet) == "function" then
				local ok, body = pcall(game.HttpGet, game, url, true)
				if type(body) == "string" and #body > 0 then
					return body
				end
				ok, body = pcall(game.HttpGet, game, url)
				if type(body) == "string" and #body > 0 then
					return body
				end
			end
			local ok, body = pcall(function()
				return game:HttpGet(url, true)
			end)
			if ok and type(body) == "string" and #body > 0 then
				return body
			end
			ok, body = pcall(function()
				return game:HttpGet(url)
			end)
			if ok and type(body) == "string" and #body > 0 then
				return body
			end
			return nil
		end,
		httpservice = function(url)
			if HttpService and type(HttpService.GetAsync) == "function" then
				local ok, body = pcall(function()
					return HttpService:GetAsync(url, true)
				end)
				if ok and type(body) == "string" and #body > 0 then
					return body
				end
			end
			return nil
		end,
	}

	local order = HTTP_STRATEGIES[slug] or HTTP_STRATEGIES.default
	local list, seen = {}, {}
	for _, id in ipairs(order) do
		if transports[id] and not seen[id] then
			seen[id] = true
			table.insert(list, { id = id, fetch = transports[id] })
		end
	end
	for id, fetch in pairs(transports) do
		if not seen[id] then
			table.insert(list, { id = id, fetch = fetch })
		end
	end
	return list
end

HTTP_TRANSPORTS = buildHttpTransports(EXECUTOR.slug)

local CAPABILITIES = {
	executor = EXECUTOR.name,
	executorSlug = EXECUTOR.slug,
	weaoVerified = EXECUTOR.weaoVerified == true,
	weao = EXECUTOR.weao,
	loadstring = loadStringFn ~= nil,
	http = #HTTP_TRANSPORTS > 0,
	readfile = readFile ~= nil,
}
ENV.Alleral_LoaderCapabilities = CAPABILITIES

local function httpGet(url, minBytes)
	minBytes = minBytes or 0
	local plain = url:gsub("%?.*$", "")
	local candidates = {
		plain .. "?t=" .. tostring(tick()),
		plain,
		url,
	}

	for _, candidate in ipairs(candidates) do
		if ENV.Alleral_Core and type(ENV.Alleral_Core.httpGet) == "function" then
			local coreBody = ENV.Alleral_Core.httpGet(candidate)
			if type(coreBody) == "string" and #coreBody >= minBytes then
				return coreBody, "core"
			end
		end

		local body, via = tryGameHttpGet(candidate)
		if type(body) == "string" and #body >= minBytes then
			return body, via or "httpget"
		end

		for _, transport in ipairs(HTTP_TRANSPORTS) do
			body = transport.fetch(candidate)
			if type(body) == "string" and #body >= minBytes then
				return body, transport.id
			end
		end
	end

	return nil, "all transports failed"
end

local function looksLikeLua(body)
	if type(body) ~= "string" or #body < 50 then
		return false
	end
	if body:find("<!DOCTYPE", 1, true) or body:find("<html", 1, true) then
		return body:find("function", 1, true) ~= nil or body:find("local ", 1, true) ~= nil
	end
	return true
end

local function isRobloxHttp404(body)
	if type(body) ~= "string" then
		return false
	end
	if #body > 8192 then
		return false
	end
	return body:find("404: Not Found", 1, true) ~= nil
end

local function readLocal(paths, minBytes)
	minBytes = minBytes or 0
	if not readFile or not isFile then
		return nil
	end
	local bestSrc, bestPath, bestLen = nil, nil, 0
	for _, root in ipairs(WORKSPACE_ROOTS) do
		for _, path in ipairs(paths) do
			local full = root .. path
			local okExists, exists = pcall(isFile, full)
			if okExists and exists then
				local okRead, src = pcall(readFile, full)
				if okRead and type(src) == "string" and #src >= minBytes and #src > bestLen then
					bestSrc, bestPath, bestLen = src, full, #src
				end
			end
		end
	end
	return bestSrc, bestPath
end

local function fetchRemote(relativePath, minBytes)
	minBytes = minBytes or 0
	local lastErr = nil
	for _, base in ipairs(REMOTE_BASES) do
		local body, via = httpGet(base .. "/" .. relativePath, minBytes)
		if body and looksLikeLua(body) and not isRobloxHttp404(body) then
			local label = base .. (via and (" via " .. via) or "")
			return body, label
		end
		if body then
			lastErr = (via or "http") .. " (" .. tostring(#body) .. "b, invalid lua)"
		else
			lastErr = via or "invalid response"
		end
	end
	return nil, lastErr or ("fetch failed for " .. relativePath)
end

local function deleteWorkspaceFile(relativePath, opts)
	opts = type(opts) == "table" and opts or {}
	if type(deleteFileFn) ~= "function" or type(isFile) ~= "function" then
		return false
	end
	local okExists, exists = pcall(isFile, relativePath)
	if not (okExists and exists) then
		return false
	end
	local ok = pcall(deleteFileFn, relativePath)
	if ok and not opts.silent then
		local label = opts.label or "outdated"
		log("Removed " .. label .. " " .. relativePath)
	end
	return ok
end

local function cacheRemote(relativePath, src)
	if type(writeFileFn) ~= "function" then
		return
	end
	local dir = relativePath:match("^(.+)/[^/]+$")
	if dir and makeFolderFn then
		pcall(makeFolderFn, dir)
	end
	pcall(writeFileFn, relativePath, src)
end

local function requiredSydePatch()
	local expected = ENV._Alleral_ExpectedVersions
	if type(expected) == "table" then
		local patch = tonumber(expected.sydePatch)
		if patch then
			return patch
		end
	end
	return SYDE_PATCH_VERSION
end

local function sydePatchFromSource(src)
	if type(src) ~= "string" then
		return nil
	end
	return tonumber(src:match("ALLERAL_SYDE_PATCH%s*=%s*(%d+)"))
end

local function sydeSourceValid(src)
	if type(src) ~= "string"
		or #src < SYDE_SOURCE_MIN_BYTES
		or not src:find("sydeFindChild", 1, true)
		or not src:find(SYDE_PATCH_MARKER, 1, true)
		or not src:find("sydePrepareDropdownDrop", 1, true)
		or not src:find(SYDE_PATCH_REQUIRED_FN, 1, true)
		or not looksLikeLua(src) then
		return false
	end
	local patch = sydePatchFromSource(src)
	local need = requiredSydePatch()
	return type(patch) == "number" and patch == need
end

local function sydeSourceRejectReason(src)
	if type(src) ~= "string" then
		return "no body"
	end
	if #src < SYDE_SOURCE_MIN_BYTES then
		return "too small (" .. tostring(#src) .. "b, need " .. tostring(SYDE_SOURCE_MIN_BYTES) .. "+)"
	end
	if not looksLikeLua(src) then
		return "not lua (" .. tostring(#src) .. "b)"
	end
	if not src:find("sydeFindChild", 1, true) then
		return "missing sydeFindChild"
	end
	if not src:find(SYDE_PATCH_MARKER, 1, true) then
		return "missing patch marker"
	end
	if not src:find("sydePrepareDropdownDrop", 1, true) then
		return "missing sydePrepareDropdownDrop"
	end
	if not src:find(SYDE_PATCH_REQUIRED_FN, 1, true) then
		return "missing " .. SYDE_PATCH_REQUIRED_FN
	end
	local patch = sydePatchFromSource(src)
	local need = requiredSydePatch()
	if type(patch) ~= "number" or patch ~= need then
		return "patch v" .. tostring(patch or "?") .. " != required v" .. tostring(need)
	end
	return "ok"
end

local function sydeRemoteBases()
	local bases = { GITHUB_RAW, GITHUB_WEB }
	local expected = ENV._Alleral_ExpectedVersions
	local commit = type(expected) == "table" and expected.commit
	if type(commit) == "string" and commit ~= "" then
		table.insert(bases, "https://cdn.jsdelivr.net/gh/" .. REPO .. "@" .. commit)
	end
	table.insert(bases, JSDELIVR)
	return bases
end

local function fetchRemoteSyde()
	local lastReason = "no response"
	for attempt = 1, 3 do
		for _, base in ipairs(sydeRemoteBases()) do
			local body, via = httpGet(base .. "/" .. SYDE_SOURCE_PATH, SYDE_SOURCE_MIN_BYTES)
			if type(body) == "string" and #body >= SYDE_SOURCE_MIN_BYTES then
				if sydeSourceValid(body) then
					return body, base .. " via " .. tostring(via) .. " (" .. tostring(#body) .. "b)"
				end
				lastReason = sydeSourceRejectReason(body)
					.. " ("
					.. tostring(#body)
					.. "b via "
					.. tostring(via)
					.. ")"
			elseif type(body) == "string" then
				lastReason = "too small (" .. tostring(#body) .. "b via " .. tostring(via) .. ")"
			else
				lastReason = tostring(via or "http failed")
			end
		end
		if attempt < 3 then
			task.wait(0.25 * attempt)
		end
	end
	return nil, lastReason
end

local function clearStaleSydeRuntime()
	local env = genv()
	if type(env) ~= "table" or type(env._AlleralSyde) ~= "table" then
		return
	end
	local patch = env._AlleralSyde.__AlleralPatch
	if type(patch) ~= "number" or patch < requiredSydePatch() then
		env._AlleralSyde = nil
		env._AlleralSydeSourceKey = nil
	end
end

local function ensureSydeSource()
	clearStaleSydeRuntime()

	-- 1. Check for user-provided patched override (highest priority for local fixes)
	for _, overridePath in ipairs(SYDE_PATCHED_OVERRIDE_PATHS) do
		local src, path = readLocal({ overridePath }, SYDE_SOURCE_MIN_BYTES)
		if src and sydeSourceValid(src) then
			local patch = sydePatchFromSource(src)
			log("Using local patched Syde override: " .. tostring(path) .. " (patch v" .. tostring(patch or "?") .. ")")
			ENV._AlleralSydeSource = src
			ENV._AlleralSydeSourcePatch = patch
			ENV._AlleralSydeSourceLabel = "override:" .. tostring(path)
			ENV._AlleralSydeSourceReady = true
			cacheRemote(SYDE_SOURCE_PATH, src)
			cacheRemote(".alleral/cache/" .. SYDE_SOURCE_PATH, src)
			return true, "override:" .. tostring(path) .. ", patch v" .. tostring(patch or "?")
		end
	end

	local localPaths = {
		SYDE_SOURCE_PATH,
		"kick/" .. SYDE_SOURCE_PATH,
	}
	local cachePaths = {
		".alleral/cache/" .. SYDE_SOURCE_PATH,
	}

	local function adoptSyde(src, label)
		if not src or not sydeSourceValid(src) then
			return nil
		end
		cacheRemote(SYDE_SOURCE_PATH, src)
		cacheRemote(".alleral/cache/" .. SYDE_SOURCE_PATH, src)
		local patch = sydePatchFromSource(src)
		ENV._AlleralSydeSource = src
		ENV._AlleralSydeSourcePatch = patch
		ENV._AlleralSydeSourceLabel = label
		ENV._AlleralSydeSourceReady = true
		return true, label .. ", patch v" .. tostring(patch or "?")
	end

	local cacheSrc, cachePath = readLocal(cachePaths, SYDE_SOURCE_MIN_BYTES)
	local cacheOk = cacheSrc and sydeSourceValid(cacheSrc)
	local cachePatch = sydePatchFromSource(cacheSrc)

	local remoteSrc, remoteVia = fetchRemoteSyde()
	local remoteOk = remoteSrc and sydeSourceValid(remoteSrc)
	local remotePatch = sydePatchFromSource(remoteSrc)

	local localSrc, localPath = readLocal(localPaths, SYDE_SOURCE_MIN_BYTES)
	local localOk = localSrc and sydeSourceValid(localSrc)
	local localPatch = sydePatchFromSource(localSrc)

	if remoteOk then
		local bestSrc, bestLabel = remoteSrc, "remote:" .. tostring(remoteVia or "github")
		local bestPatch = remotePatch or 0
		if localOk and (localPatch or 0) > bestPatch then
			bestSrc, bestLabel, bestPatch = localSrc, "local:" .. tostring(localPath), localPatch or 0
		elseif cacheOk and (cachePatch or 0) > bestPatch then
			bestSrc, bestLabel = cacheSrc, "cache:" .. tostring(cachePath)
		end
		if localOk and localPath and (localPatch or 0) < (remotePatch or 0) then
			log(
				"Replacing stale Syde source (local v"
					.. tostring(localPatch or "?")
					.. " < remote v"
					.. tostring(remotePatch or "?")
					.. ")",
				true
			)
			deleteWorkspaceFile(localPath)
		end
		return adoptSyde(bestSrc, bestLabel)
	end

	if localOk then
		return adoptSyde(localSrc, "local:" .. tostring(localPath))
	end

	if cacheOk then
		return adoptSyde(cacheSrc, "cache:" .. tostring(cachePath))
	end

	local fetchDetail = type(remoteVia) == "string" and remoteVia or sydeSourceRejectReason(remoteSrc)
	return false, "patched Syde source unavailable (need v" .. tostring(requiredSydePatch()) .. "): " .. tostring(fetchDetail)
end

local function usesLegacyHttpHash(src)
	if type(src) ~= "string" then
		return false
	end
	return src:find("HttpService:Hash", 1, true) ~= nil or src:find("HttpService.Hash", 1, true) ~= nil
end

local function getSource(localPaths, remotePath, opts)
	opts = type(opts) == "table" and opts or { marker = opts }
	local minBytes = opts.minBytes or 0
	local marker = opts.marker

	local src, path = readLocal(localPaths, minBytes)
	if src then
		if usesLegacyHttpHash(src) then
			log("Removing executor-incompatible cached " .. path, true)
			deleteWorkspaceFile(path)
		elseif marker and not src:find(marker, 1, true) then
			log("Skipping outdated local " .. path, true)
			deleteWorkspaceFile(path)
		else
			return src, "local:" .. path
		end
	end

	src, path = fetchRemote(remotePath, minBytes)
	if src then
		if usesLegacyHttpHash(src) then
			log("Remote " .. remotePath .. " still uses HttpService.Hash — skipping", true)
			src = nil
		elseif marker and not src:find(marker, 1, true) then
			log("Script may be outdated (missing " .. marker .. ")", true)
		end
		if src then
			cacheRemote(remotePath, src)
			return src, "remote" .. (path and (" (" .. path .. ")") or "")
		end
	end

	return nil, path or ("Could not load " .. remotePath)
end

local function gameScriptExpectedVersion(profile, expectedVersion)
	if type(expectedVersion) == "string" and expectedVersion ~= "" then
		return expectedVersion
	end
	return profile.version
end

local function gameScriptValid(body, profile, expectedVersion)
	if type(body) ~= "string" then
		return false
	end
	local minBytes = profile.minBytes or 40000
	local version = gameScriptExpectedVersion(profile, expectedVersion)
	if #body < minBytes then
		return false
	end
	if isRobloxHttp404(body) then
		return false
	end
	if not looksLikeLua(body) then
		return false
	end
	if profile.sourceMarker and not body:find(profile.sourceMarker, 1, true) then
		return false
	end
	if version and not body:find('local VERSION = "' .. version .. '"', 1, true) then
		return false
	end
	return true
end

local function gameScriptRejectReason(body, profile, expectedVersion)
	if type(body) ~= "string" or body == "" then
		return "empty response"
	end
	local minBytes = profile.minBytes or 40000
	local version = gameScriptExpectedVersion(profile, expectedVersion)
	if #body < minBytes then
		return tostring(#body) .. "b, need " .. tostring(minBytes) .. "b+"
	end
	if isRobloxHttp404(body) then
		return "404 response"
	end
	if not looksLikeLua(body) then
		return "invalid lua"
	end
	if profile.sourceMarker and not body:find(profile.sourceMarker, 1, true) then
		return "missing " .. profile.sourceMarker
	end
	if version and not body:find('local VERSION = "' .. version .. '"', 1, true) then
		return "missing VERSION " .. version
	end
	return "unknown"
end

local function expectedGameVersion(profile)
	local expected = ENV._Alleral_ExpectedVersions
	if type(expected) == "table" and type(expected.games) == "table" then
		local remoteVersion = expected.games[profile.id]
		if type(remoteVersion) == "string" and remoteVersion ~= "" then
			return remoteVersion
		end
	end
	return profile.version
end

local function cacheLoaderSource(_src)
	return false
end

local function fetchRemoteLoaderSource()
	local body, via = httpGet(GITHUB_RAW .. "/loader.luau?t=" .. tostring(tick()), 500)
	if type(body) == "string" and #body >= 500 then
		return body, via
	end
	return nil, via or "remote loader fetch failed"
end

local function readFreshLocalLoaderSource()
	if not isFile or not readFile then
		return nil, nil
	end
	local expectedLoader = ENV._Alleral_ExpectedVersions and ENV._Alleral_ExpectedVersions.loader
	for _, path in ipairs(LOADER_LOCAL_PATHS) do
		for _, root in ipairs(WORKSPACE_ROOTS) do
			local fullPath = root .. path
			local okExists, exists = pcall(isFile, fullPath)
			if okExists and exists then
				local okRead, src = pcall(readFile, fullPath)
				if okRead and type(src) == "string" and #src >= 500 then
					local ver = extractFileVersion(src, "loader")
					if type(ver) ~= "string" or ver == "" then
						continue
					end
					if type(expectedLoader) == "string" and expectedLoader ~= "" and versionLt(ver, expectedLoader) then
						continue
					end
					if versionLt(ver, LOADER_VERSION) then
						continue
					end
					return src, fullPath, ver
				end
			end
		end
	end
	return nil, nil, nil
end

local function syncWorkspaceLoaderFromRemote()
	return false
end

local function instancePathFromMemberError(errMsg)
	local msg = tostring(errMsg)
	if not msg:find(" is not a valid member of ", 1, true) then
		return nil
	end
	local className, instName = msg:match('member of (%w+) "([^"]+)"')
	if not className or not instName then
		return nil
	end
	local paths = {}
	local function collect(root)
		if not root then
			return
		end
		for _, desc in ipairs(root:GetDescendants()) do
			if desc.Name == instName and desc.ClassName == className then
				table.insert(paths, desc:GetFullName())
			end
		end
	end
	local players = game:GetService("Players")
	local localPlayer = players.LocalPlayer
	if localPlayer then
		collect(localPlayer:FindFirstChildOfClass("PlayerGui"))
	end
	collect(game:GetService("CoreGui"))
	if #paths == 0 then
		return nil
	end
	if #paths == 1 then
		return paths[1]
	end
	return paths[1] .. " (+" .. tostring(#paths - 1) .. " matches)"
end

local function formatRuntimeError(runErr, chunkName)
	local msg = tostring(runErr)
	local instPath = instancePathFromMemberError(msg)
	if instPath then
		msg = msg .. " @ " .. instPath
	end
	local trace = debug.traceback(msg, 2)
	if chunkName and chunkName ~= "" then
		trace = trace .. "\n(chunk: " .. chunkName .. ")"
	end
	return trace
end

local function hashBootstrapAttest(placeId, jobId, at, commit)
	local text = "AlleralBootstrapGate-v5"
		.. "|"
		.. tostring(placeId)
		.. "|"
		.. tostring(jobId)
		.. "|"
		.. tostring(at)
		.. "|"
		.. tostring(commit or "")
	local h1, h2 = 5381, 0
	for i = 1, #text do
		local byte = string.byte(text, i)
		h1 = (h1 * 33 + byte) % 2147483647
		h2 = (h2 * 31 + byte * (i % 7 + 1)) % 2147483647
	end
	return string.format("ab_%x_%x", h1, h2)
end

local function verifyBootstrapAttestation()
	if ENV._Alleral_BootstrapVerified == true then
		return true
	end
	if ENV._Alleral_Bootstrapped ~= true then
		return false, "Direct loader access is disabled. Run the bootstrap loadstring only."
	end
	local token = ENV._Alleral_BootstrapToken
	local at = tonumber(ENV._Alleral_BootstrapTokenAt)
	if type(token) ~= "string" or #token < 8 or not at then
		return false, "Missing bootstrap attestation — re-run the bootstrap loadstring."
	end
	if (tick() - at) > 120 then
		return false, "Bootstrap attestation expired — re-run the bootstrap loadstring."
	end
	local expected = hashBootstrapAttest(game.PlaceId, game.JobId, at, ENV._Alleral_BootstrapCommit)
	if token ~= expected then
		return false, "Invalid bootstrap attestation."
	end
	ENV._Alleral_BootstrapVerified = true
	ENV._Alleral_BootstrapToken = nil
	return true
end

local function loadAccessConfig()
	local cfg = nil
	local localRaw = readLocal({ CFG .. "/access.json", "config/access.json" }, 20)
	if localRaw then
		cfg = decodeJson(localRaw)
	end
	if not cfg then
		cfg = decodeJson(select(1, httpFetch(GITHUB_RAW .. "/" .. CFG .. "/access.json?t=" .. tick())))
	end
	cfg = type(cfg) == "table" and cfg or { mode = "public", publicKey = "PUBLIC" }
	ENV.Alleral_OwnerAccess = cfg
	return cfg
end

local function enforceExecutorPolicy()
	loadAccessConfig()
	if type(ENV.Alleral_Access) ~= "table" then
		pcall(loadModule, { HUB .. "/access.luau", "core/access.luau" }, HUB .. "/access.luau", "Alleral_Access", "Alleral/access")
	end
	local access = ENV.Alleral_Access
	if type(access) == "table" and type(access.checkExecutor) == "function" then
		local ok, reason = access.checkExecutor({ executor = EXECUTOR, stage = "loader" })
		if not ok then
			return false, tostring(reason or "Executor not allowed")
		end
		return true
	end
	return true
end

local function compileAndRun(source, chunkName, runEnv)
	if not loadStringFn then
		return false, "loadstring unavailable"
	end
	local fn, err = loadStringFn(source, chunkName)
	if not fn and type(load) == "function" then
		fn, err = load(source, chunkName)
	end
	if not fn then
		return false, "Compile: " .. tostring(err)
	end
	if not runEnv then
		runEnv = loaderRunEnv()
	end
	if setfenv then
		pcall(setfenv, fn, runEnv)
	end
	local ok, runErr = xpcall(fn, function(err)
		return formatRuntimeError(err, chunkName)
	end)
	if not ok then
		return false, "Runtime: " .. tostring(runErr)
	end
	return true
end

local function clampNumber(value, minValue, maxValue)
	value = tonumber(value) or minValue
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

local function versionParts(value)
	local parts = {}
	for piece in tostring(value or "0"):gmatch("%d+") do
		table.insert(parts, tonumber(piece) or 0)
	end
	if #parts == 0 then
		table.insert(parts, 0)
	end
	return parts
end

local function compareVersions(a, b)
	local left, right = versionParts(a), versionParts(b)
	local count = math.max(#left, #right)
	for index = 1, count do
		local lv, rv = left[index] or 0, right[index] or 0
		if lv < rv then
			return -1
		end
		if lv > rv then
			return 1
		end
	end
	return 0
end

local function versionLt(a, b)
	return compareVersions(a, b) < 0
end

local function coreVersionOk(v)
	return type(v) == "string" and compareVersions(v, MIN_CORE) >= 0
end

local function compileCacheKey(src, label)
	return (label or "Alleral/core-check") .. "|" .. tostring(#src) .. "|" .. src:sub(1, 64) .. "|" .. src:sub(-64)
end

local LARGE_SOURCE_RELAX_BYTES = 15000

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

local function relaxedCompileOk(src)
	if type(src) ~= "string" or #src < LARGE_SOURCE_RELAX_BYTES or not looksLikeLua(src) then
		return false
	end
	return src:find("return function", 1, true) ~= nil
		or src:find("local Library do", 1, true) ~= nil
		or src:find("getgenv%(%)%.Library", 1, true) ~= nil
		or src:find("ENV%.Alleral_Core = Core", 1, true) ~= nil
end

local function compileCoreSource(src, label)
	if type(src) ~= "string" then
		return false, "invalid source"
	end
	local cacheKey = compileCacheKey(src, label)
	local cached = COMPILE_VALIDATE_CACHE[cacheKey]
	if cached ~= nil then
		if cached == true then
			return true
		end
		return false, cached
	end
	if type(loadStringFn) ~= "function" then
		COMPILE_VALIDATE_CACHE[cacheKey] = true
		return true
	end
	local fn, err = loadStringFn(src, label or "Alleral/core-check")
	if type(fn) == "function" then
		COMPILE_VALIDATE_CACHE[cacheKey] = true
		return true
	end
	local sanitized = sanitizeLuauSource(src)
	if sanitized ~= src then
		fn, err = loadStringFn(sanitized, label or "Alleral/core-check")
		if type(fn) == "function" then
			COMPILE_VALIDATE_CACHE[cacheKey] = true
			return true
		end
	end
	if relaxedCompileOk(src) then
		COMPILE_VALIDATE_CACHE[cacheKey] = true
		return true
	end
	COMPILE_VALIDATE_CACHE[cacheKey] = err or "compile failed"
	return false, err
end

local function coreMonolithValid(src)
	if type(src) ~= "string" or #src < CORE_MONOLITH_MIN_BYTES or not src:find("loadUi", 1, true) then
		return false
	end
	if not src:find("buildUiGroup", 1, true) or not src:find("buildUiWindow", 1, true) then
		return false
	end
	if not src:find("ENV.Alleral_Core = Core", 1, true) then
		return false
	end
	local ver = src:match('Core%.VERSION%s*=%s*"([%d%.]+)"')
	if not coreVersionOk(ver) then
		return false
	end
	return compileCoreSource(src, "Alleral/core-monolith")
end

local function coreBaseValid(src)
	if coreMonolithValid(src) then
		return true
	end
	if type(src) ~= "string" or #src < CORE_BASE_MIN_BYTES then
		return false
	end
	if #src > CORE_BASE_MAX_BYTES then
		return false
	end
	if not src:find("applyUiLayer", 1, true) then
		return false
	end
	if not src:find('Core._CORE_ARTIFACT = "base"', 1, true) then
		return false
	end
	if src:find("function Core.loadUi", 1, true) then
		return false
	end
	local ver = src:match('Core%.VERSION%s*=%s*"([%d%.]+)"')
	if not coreVersionOk(ver) then
		return false
	end
	local alleralVer = src:match('Core%.ALLERAL_UI_VERSION%s*=%s*"([^"]+)"')
	local expectedAlleral = (ENV._Alleral_ExpectedVersions and ENV._Alleral_ExpectedVersions.alleral)
		or RELEASE_FALLBACK.alleral
	if type(alleralVer) == "string" and type(expectedAlleral) == "string" and alleralVer ~= expectedAlleral then
		return false
	end
	return compileCoreSource(src, "Alleral/core-base")
end

local function coreUiValid(src)
	if type(src) ~= "string" or #src < CORE_UI_MIN_BYTES then
		return false
	end
	if not src:find("function Core.loadUi", 1, true) then
		return false
	end
	if not src:find("buildUiGroup", 1, true) or not src:find("buildUiWindow", 1, true) then
		return false
	end
	if not src:find("return function(Core)", 1, true) then
		return false
	end
	if not src:find("function Core.resolveUiWindow", 1, true) then
		return false
	end
	return compileCoreSource(src, "Alleral/core_ui")
end

local function coreHubUiValid(src)
	if type(src) ~= "string" or #src < CORE_HUB_UI_MIN_BYTES then
		return false
	end
	if not src:find("return function(Core)", 1, true) then
		return false
	end
	if not src:find("buildStandardSettingsExtras", 1, true) then
		return false
	end
	return compileCoreSource(src, "Alleral/core_hub_ui")
end

local function alleralUiValid(src)
	if type(src) ~= "string" or #src < CORE_ALLERAL_UI_MIN_BYTES then
		return false
	end
	if not src:find("return function%(Core%)", 1, false) then
		return false
	end
	if not src:find("function Core.loadUi", 1, true) then
		return false
	end
	if not src:find("createWindUiGroupbox", 1, true) or not src:find("buildUiWindow", 1, true) then
		return false
	end
	if not src:find("Alleral UI layer", 1, true) then
		return false
	end
	if not src:find("Syde", 1, true) then
		return false
	end
	if not src:find("loadSyde", 1, true) then
		return false
	end
	if not src:find("ALLERAL_SYDE_PATCH", 1, true) then
		return false
	end
	if compileCoreSource(src, "Alleral/alleral_ui") then
		return true
	end
	return looksLikeLua(src)
end

local function coreValid(src)
	return coreMonolithValid(src) or coreBaseValid(src)
end

local function coreRejectReason(src)
	if type(src) ~= "string" or src == "" then
		return "empty response"
	end
	if coreMonolithValid(src) or coreBaseValid(src) then
		return "valid"
	end
	if #src > CORE_BASE_MAX_BYTES and #src < CORE_MONOLITH_MIN_BYTES then
		return "stale cached core (" .. tostring(#src) .. "b)"
	end
	if #src < CORE_BASE_MIN_BYTES and #src < CORE_MONOLITH_MIN_BYTES then
		return tostring(#src) .. "b, need " .. tostring(CORE_BASE_MIN_BYTES) .. "b+ base"
	end
	if not src:find("applyUiLayer", 1, true) and not src:find("loadUi", 1, true) then
		return "missing core bootstrap"
	end
	if not src:find('Core._CORE_ARTIFACT = "base"', 1, true) and not src:find("ENV.Alleral_Core = Core", 1, true) then
		return "truncated core (" .. tostring(#src) .. "b)"
	end
	local ver = src:match('Core%.VERSION%s*=%s*"([%d%.]+)"')
	if not coreVersionOk(ver) then
		return "bad core version " .. tostring(ver)
	end
	if not looksLikeLua(src) then
		return "invalid lua"
	end
	if loadStringFn then
		local ok, err = compileCoreSource(src, "Alleral/core-check")
		if not ok then
			return "compile failed: " .. tostring(err)
		end
	end
	return "unknown"
end

local function coreUiRejectReason(src)
	if type(src) ~= "string" or src == "" then
		return "empty response"
	end
	if coreUiValid(src) then
		return "valid"
	end
	if #src < CORE_UI_MIN_BYTES then
		return tostring(#src) .. "b, need " .. tostring(CORE_UI_MIN_BYTES) .. "b+"
	end
	if not src:find("function Core.loadUi", 1, true) then
		return "missing loadUi"
	end
	if not src:find("buildUiGroup", 1, true) or not src:find("buildUiWindow", 1, true) then
		return "missing UI helpers"
	end
	if not src:find("return function(Core)", 1, true) then
		return "missing ui layer wrapper"
	end
	if loadStringFn then
		local ok, err = compileCoreSource(src, "Alleral/core_ui-check")
		if not ok then
			return "compile failed: " .. tostring(err)
		end
	end
	return "unknown"
end

local function coreHubUiRejectReason(src)
	if type(src) ~= "string" or src == "" then
		return "empty response"
	end
	if coreHubUiValid(src) then
		return "valid"
	end
	if #src < CORE_HUB_UI_MIN_BYTES then
		return tostring(#src) .. "b, need " .. tostring(CORE_HUB_UI_MIN_BYTES) .. "b+"
	end
	if not src:find("buildStandardSettingsExtras", 1, true) then
		return "missing hub UI builders"
	end
	if loadStringFn then
		local ok, err = compileCoreSource(src, "Alleral/core_hub_ui-check")
		if not ok then
			return "compile failed: " .. tostring(err)
		end
	end
	return "unknown"
end

local function alleralUiRejectReason(src)
	if type(src) ~= "string" or src == "" then
		return "empty response"
	end
	if alleralUiValid(src) then
		return "valid"
	end
	if #src < CORE_ALLERAL_UI_MIN_BYTES then
		return tostring(#src) .. "b, need " .. tostring(CORE_ALLERAL_UI_MIN_BYTES) .. "b+"
	end
	if not src:find("function Core.loadUi", 1, true) then
		return "missing loadUi override"
	end
	if not src:find("return function(Core)", 1, true) then
		return "missing return function(Core) wrapper"
	end
	if not src:find("createWindUiGroupbox", 1, true) or not src:find("buildUiWindow", 1, true) then
		return "missing Alleral UI helpers"
	end
	if not src:find("Alleral UI layer", 1, true) then
		return "missing Alleral UI layer marker"
	end
	if not src:find("Syde", 1, true) then
		return "missing Syde integration"
	end
	if not src:find("loadSyde", 1, true) then
		return "missing loadSyde bootstrap"
	end
	if not src:find("ALLERAL_SYDE_PATCH", 1, true) then
		return "missing ALLERAL_SYDE_PATCH marker"
	end
	if not looksLikeLua(src) then
		return "invalid lua body"
	end
	if loadStringFn then
		local ok, err = compileCoreSource(src, "Alleral/alleral_ui-check")
		if not ok then
			return "compile failed: " .. tostring(err)
		end
	end
	return "unknown"
end

local VERSION_PATTERNS = {
	core = 'Core%.VERSION%s*=%s*"([%d%.]+)"',
	analytics = 'Analytics%.Version%s*=%s*"([%d%.]+)"',
	telemetry = 'Telemetry%.Version%s*=%s*"([%d%.]+)"',
	helpers = 'Helpers%.VERSION%s*=%s*"([%d%.]+)"',
	weao = 'Weao%.VERSION%s*=%s*"([%d%.]+)"',
	security = 'Security%.VERSION%s*=%s*"([%d%.]+)"',
	access = 'Access%.VERSION%s*=%s*"([%d%.]+)"',
	loader = 'LOADER_VERSION%s*=%s*"([%d%.]+)"',
	bootstrap = 'BOOTSTRAP_VERSION%s*=%s*"([%d%.]+)"',
	windui = 'ALLERAL_UI_VERSION%s*=%s*"([^"]+)"',
	alleral = 'ALLERAL_UI_VERSION%s*=%s*"([^"]+)"',
	game = 'local VERSION%s*=%s*"([%d%.]+)"',
}

local function extractFileVersion(src, kind)
	if type(src) ~= "string" then
		return nil
	end
	if kind == "syde" then
		return src:match("ALLERAL_SYDE_PATCH%s*=%s*(%d+)")
	end
	if kind == "alleral" then
		return src:match('Core%.ALLERAL_UI_VERSION%s*=%s*"([^"]+)"')
			or src:match('ALLERAL_UI_VERSION%s*=%s*"([^"]+)"')
	end
	if kind == "hub_ui" then
		return src:match('HUB_UI_LAYER_VERSION%s*=%s*"([^"]+)"')
			or src:match("hub_ui_layer=([%w%.%-]+)")
	end
	if kind == "bootstrap" then
		return src:match('BOOTSTRAP_VERSION%s*=%s*"([%d%.]+)"')
			or src:match("Alleral Bootstrap v([%d%.]+)")
	end
	local pattern = VERSION_PATTERNS[kind]
	if not pattern then
		return nil
	end
	return src:match(pattern)
end

local function expectedVersionForKind(expected, kind)
	if type(expected) ~= "table" then
		return nil
	end
	if kind == "windui" or kind == "alleral" then
		return expected.alleral or expected.windui
	end
	return expected[kind] or expected.core
end

local function sourceVersionStale(src, kind, expectedVersion)
	if type(src) ~= "string" or type(expectedVersion) ~= "string" or expectedVersion == "" then
		return false
	end
	local found = extractFileVersion(src, kind or "core")
	return type(found) == "string" and found ~= expectedVersion
end

local function fetchGameScript(profile)
	local minBytes = profile.minBytes or 40000
	local gameVersion = expectedGameVersion(profile)
	local lastReason = "no local or remote game script"

	local src, path = readLocal(profile.scriptFiles, minBytes)
	if src then
		if not gameScriptValid(src, profile, gameVersion) then
			lastReason = "invalid local: " .. gameScriptRejectReason(src, profile, gameVersion)
			if path then
				deleteWorkspaceFile(path)
			end
			src = nil
		elseif sourceVersionStale(src, "game", gameVersion) then
			lastReason = "stale local game script (need v" .. tostring(gameVersion) .. ")"
			if path then
				deleteWorkspaceFile(path)
			end
			src = nil
		else
			return src, "local:" .. tostring(path)
		end
	end

	for _, base in ipairs(REMOTE_BASES) do
		local body, via = httpGet(base .. "/" .. profile.scriptUrl, minBytes)
		if type(body) == "string" then
			if gameScriptValid(body, profile, gameVersion) then
				cacheRemote(profile.scriptUrl, body)
				return body, base .. " via " .. tostring(via) .. " (" .. tostring(#body) .. "b)"
			end
			lastReason = gameScriptRejectReason(body, profile, gameVersion) .. " via " .. tostring(via)
		else
			lastReason = tostring(via or "http failed")
		end
	end

	return nil, lastReason
end

local function deleteListedWorkspaceFiles(paths)
	for _, path in ipairs(paths or {}) do
		deleteWorkspaceFile(path)
	end
end

local function fetchRemoteCoreFile(relativePath, validFn, rejectReasonFn, minBytes)
	minBytes = minBytes or CORE_BASE_MIN_BYTES
	local lastReason = "no response"
	for attempt = 1, 2 do
		for _, base in ipairs(CORE_REMOTE_BASES) do
			local body, via = httpGet(base .. "/" .. relativePath, minBytes)
			if type(body) == "string" and #body >= minBytes then
				if validFn(body) then
					cacheRemote(relativePath, body)
					return body, base .. " via " .. tostring(via) .. " (" .. tostring(#body) .. "b)"
				end
				if rejectReasonFn then
					lastReason = rejectReasonFn(body)
				else
					lastReason = "validation failed"
				end
				lastReason = lastReason .. " (" .. tostring(#body) .. "b via " .. tostring(via) .. ")"
			elseif type(body) == "string" then
				lastReason = "too small (" .. tostring(#body) .. "b, need " .. tostring(minBytes) .. "b+ via " .. tostring(via) .. ")"
			else
				lastReason = tostring(via or "http failed")
			end
		end
		if attempt == 1 then
			task.wait(0.2)
		end
	end
	return nil, relativePath .. ": " .. lastReason
end

local function runParallel(tasks)
	local remaining = #tasks
	local results = table.create(#tasks)
	if remaining == 0 then
		return results
	end
	for index, fn in ipairs(tasks) do
		task.spawn(function()
			results[index] = table.pack(pcall(fn))
			remaining -= 1
		end)
	end
	while remaining > 0 do
		RunService.Heartbeat:Wait()
	end
	for index, packed in ipairs(results) do
		if type(packed) == "table" and packed[1] == false then
			log("Startup task " .. tostring(index) .. " failed: " .. tostring(packed[2]), true)
		end
	end
	return results
end

local function resolveCoreSource(localPaths, cachePaths, remotePath, validFn, rejectReasonFn, minBytes, opts)
	opts = type(opts) == "table" and opts or {}
	local versionKind = opts.versionKind or "core"
	local expected = ENV._Alleral_ExpectedVersions or fetchExpectedVersions()
	local expectedVersion = opts.expectedVersion or expectedVersionForKind(expected, versionKind)
	local src, path = readLocal(localPaths, minBytes)
	local label
	if src then
		if not validFn(src) or sourceVersionStale(src, versionKind, expectedVersion) then
			log(
				"Removing outdated local "
					.. tostring(path or localPaths[1])
					.. (expectedVersion and (" (need " .. tostring(expectedVersion) .. ")") or ""),
				true
			)
			deleteListedWorkspaceFiles(localPaths)
			deleteListedWorkspaceFiles(cachePaths)
			src = nil
			path = nil
		end
	end
	if not src then
		src, path = readLocal(cachePaths, minBytes)
		if src then
			label = "cache:" .. tostring(path or cachePaths[1])
			if not validFn(src) or sourceVersionStale(src, versionKind, expectedVersion) then
				log("Removing outdated cache at " .. tostring(path or cachePaths[1]), true)
				deleteListedWorkspaceFiles(cachePaths)
				src = nil
				label = nil
				path = nil
			end
		end
	end
	if src and not validFn(src) then
		log("Removing broken file at " .. tostring(path or localPaths[1]), true)
		deleteListedWorkspaceFiles(localPaths)
		deleteListedWorkspaceFiles(cachePaths)
		src = nil
		label = nil
	end
	if src and validFn(src) then
		label = label or ("local:" .. tostring(path or localPaths[1]))
	else
		src, label = fetchRemoteCoreFile(remotePath, validFn, rejectReasonFn, minBytes)
		if not src then
			return nil, label
		end
	end
	return src, label
end

local function purgeStaleCorePaths()
	local expected = ENV._Alleral_ExpectedVersions
	if type(fetchExpectedVersions) == "function" and not expected then
		expected = fetchExpectedVersions()
	end
	local expectedCore = type(expected) == "table" and expected.core or nil
	local stalePaths = {
		CP.legacy,
		".alleral/cache/" .. CP.legacy,
		CP.base,
		".alleral/cache/" .. CP.base,
	}
	for _, path in ipairs(stalePaths) do
		if isFile and readFile then
			local okExists, exists = pcall(isFile, path)
			if okExists and exists then
				local okRead, src = pcall(readFile, path)
				if okRead and type(src) == "string" and src ~= "" then
					local stale = #src > CORE_BASE_MAX_BYTES
					if path:find("core.luau", 1, true) and not path:find("core_base", 1, true) then
						stale = true
					end
					if type(expectedCore) == "string" and expectedCore ~= "" then
						local cachedVersion = extractFileVersion(src, "core")
						if cachedVersion and cachedVersion ~= expectedCore then
							stale = true
						end
					end
					if stale and (not coreValid(src) or (type(expectedCore) == "string" and expectedCore ~= "" and extractFileVersion(src, "core") ~= expectedCore)) then
						deleteWorkspaceFile(path)
					end
				end
			end
		end
	end
end

local function purgeStaleHubPaths()
	local expected = ENV._Alleral_ExpectedVersions
	if type(fetchExpectedVersions) == "function" and not expected then
		expected = fetchExpectedVersions()
	end
	local hubPaths = {
		{ paths = { HUB .. "/alleral_ui.luau", CP.alleral }, valid = alleralUiValid, kind = "alleral" },
		{ paths = { HUB .. "/core_base.luau", CP.base }, valid = coreBaseValid, kind = "core" },
	}
	for _, entry in ipairs(hubPaths) do
		for _, path in ipairs(entry.paths) do
			if isFile and readFile then
				local okExists, exists = pcall(isFile, path)
				if okExists and exists then
					local okRead, src = pcall(readFile, path)
					if okRead and type(src) == "string" and src ~= "" then
						local expectedVersion = expectedVersionForKind(expected, entry.kind)
						if (entry.valid and not entry.valid(src))
							or sourceVersionStale(src, entry.kind, expectedVersion)
						then
							log("Removing outdated hub file " .. path, true)
							deleteWorkspaceFile(path)
						end
					end
				end
			end
		end
	end
end

local LEGACY_HUB_UI_FILES = {
	HUB .. "/ui/Library.luau",
	HUB .. "/ui/Maid.luau",
	HUB .. "/ui/Spring.luau",
	HUB .. "/ui/Motion.luau",
	HUB .. "/ui/Theme.luau",
	HUB .. "/ui/Components.luau",
	HUB .. "/ui/Window.luau",
	HUB .. "/ui/ModuleLoader.luau",
	HUB .. "/ui/Vendor.luau",
	HUB .. "/ui/Section.luau",
	HUB .. "/ui/Page.luau",
	HUB .. "/ui/Navigation.luau",
	HUB .. "/ui/Utils.luau",
	HUB .. "/ui/Icons.luau",
	HUB .. "/ui/Config.luau",
	HUB .. "/ui/Tooltip.luau",
	HUB .. "/ui/Notification.luau",
	HUB .. "/ui/Modal.luau",
	HUB .. "/ui/CommandPalette.luau",
	HUB .. "/ui/Signals.luau",
	HUB .. "/ui/Exploit.luau",
}

local function purgeLegacyHubUiFiles()
	local removed = 0
	for _, rel in ipairs(LEGACY_HUB_UI_FILES) do
		for _, root in ipairs(WORKSPACE_ROOTS) do
			for _, prefix in ipairs({ "", ".alleral/cache/" }) do
				if deleteWorkspaceFile(prefix .. root .. rel) then
					removed += 1
				end
			end
		end
	end
	if removed > 0 then
		log("Removed " .. tostring(removed) .. " legacy hub/ui file(s)")
	end
end

local function loadCore()
	ENV.Alleral_Core = nil
	pcall(purgeStaleCorePaths)
	pcall(purgeStaleHubPaths)
	pcall(purgeLegacyHubUiFiles)

	local baseArgs = {
		{ CP.base, CP.legacy, "core/alleral_core.luau", "alleral_core.luau" },
		{ ".alleral/cache/" .. CP.base, ".alleral/cache/" .. CP.legacy },
		CP.base,
		coreValid,
		coreRejectReason,
		CORE_BASE_MIN_BYTES,
	}
	local uiArgs = {
		{ CP.ui, HUB .. "/core_ui.luau" },
		{ ".alleral/cache/" .. CP.ui },
		CP.ui,
		coreUiValid,
		coreUiRejectReason,
		CORE_UI_MIN_BYTES,
	}
	local hubArgs = {
		{ CP.hub, HUB .. "/core_hub_ui.luau" },
		{ ".alleral/cache/" .. CP.hub },
		CP.hub,
		coreHubUiValid,
		coreHubUiRejectReason,
		CORE_HUB_UI_MIN_BYTES,
	}
	local alleralUiArgs = {
		{ CP.alleral, HUB .. "/alleral_ui.luau" },
		{ ".alleral/cache/" .. CP.alleral },
		CP.alleral,
		alleralUiValid,
		alleralUiRejectReason,
		CORE_ALLERAL_UI_MIN_BYTES,
	}

	local function resolveArgs(args, versionKind)
		return resolveCoreSource(args[1], args[2], args[3], args[4], args[5], args[6], {
			versionKind = versionKind or "core",
		})
	end

	local resolved = runParallel({
		function()
			return resolveArgs(baseArgs, "core")
		end,
		function()
			return resolveArgs(uiArgs, "core")
		end,
		function()
			return resolveArgs(alleralUiArgs, "alleral")
		end,
		function()
			return resolveArgs(hubArgs, "core")
		end,
	})
	local baseSrc, baseLabel = resolved[1][2], resolved[1][3]
	local uiSrc, uiLabel = resolved[2][2], resolved[2][3]
	local alleralUiSrc, alleralUiLabel = resolved[3][2], resolved[3][3]
	local hubUiSrc, hubUiLabel = resolved[4][2], resolved[4][3]
	if not baseSrc then
		return false, baseLabel or "core_base download failed"
	end

	local ok, err = compileAndRun(baseSrc, "Alleral/core")
	if not ok then
		ENV.Alleral_Core = nil
		return false, err
	end
	if not ENV.Alleral_Core then
		return false, "Core did not initialize"
	end

	if coreMonolithValid(baseSrc) then
		if type(ENV.Alleral_Core.loadUi) ~= "function" then
			return false, "Monolithic core missing loadUi"
		end
		cacheRemote(CP.base, baseSrc)
		cacheRemote(".alleral/cache/" .. CP.base, baseSrc)
		log("Core v" .. tostring(ENV.Alleral_Core.VERSION) .. " (monolith) from " .. tostring(baseLabel))
		return true
	end

	if type(ENV.Alleral_Core.applyUiLayer) ~= "function" then
		return false, "Split core missing applyUiLayer"
	end

	if not uiSrc then
		ENV.Alleral_Core = nil
		return false, uiLabel or "Core UI download failed"
	end

	if not alleralUiSrc then
		ENV.Alleral_Core = nil
		return false, alleralUiLabel or "Alleral UI layer download failed"
	end

	if not ENV._AlleralSydeSourceReady then
		local sydeOk, sydeLabel = ensureSydeSource()
		if sydeOk then
			log("Syde source ready (" .. tostring(sydeLabel) .. ")")
		else
			log("Syde source not cached yet: " .. tostring(sydeLabel), true)
		end
	end

	if not hubUiSrc then
		ENV.Alleral_Core = nil
		return false, hubUiLabel or "Core hub UI download failed"
	end

	local applied, applyErr = ENV.Alleral_Core.applyUiLayer(uiSrc, uiLabel or "@Alleral/core_ui")
	if not applied then
		ENV.Alleral_Core = nil
		return false, applyErr or "Core UI layer failed"
	end
	RunService.Heartbeat:Wait()

	applied, applyErr = ENV.Alleral_Core.applyUiLayer(alleralUiSrc, alleralUiLabel or "@Alleral/alleral_ui")
	if not applied then
		ENV.Alleral_Core = nil
		return false, applyErr or "Alleral UI layer failed"
	end
	RunService.Heartbeat:Wait()

	applied, applyErr = ENV.Alleral_Core.applyUiLayer(hubUiSrc, hubUiLabel or "@Alleral/core_hub_ui")
	if not applied then
		ENV.Alleral_Core = nil
		return false, applyErr or "Core hub UI layer failed"
	end

	if not ENV.Alleral_Core._UiLayerReady or type(ENV.Alleral_Core.loadUi) ~= "function" then
		ENV.Alleral_Core = nil
		return false, "Core UI layers incomplete"
	end

	cacheRemote(CP.base, baseSrc)
	cacheRemote(".alleral/cache/" .. CP.base, baseSrc)
	cacheRemote(CP.ui, uiSrc)
	cacheRemote(".alleral/cache/" .. CP.ui, uiSrc)
	cacheRemote(CP.alleral, alleralUiSrc)
	cacheRemote(".alleral/cache/" .. CP.alleral, alleralUiSrc)
	cacheRemote(CP.hub, hubUiSrc)
	cacheRemote(".alleral/cache/" .. CP.hub, hubUiSrc)

	ENV.Alleral_HTTP = ENV.Alleral_HTTP or {}
	ENV.Alleral_HTTP.get = httpGet
	if ENV.Alleral_Core then
		ENV.Alleral_Core._UiRemoteBases = CORE_REMOTE_BASES
	end

	log(
		"Core v"
			.. tostring(ENV.Alleral_Core.VERSION)
			.. " from "
			.. tostring(baseLabel)
			.. " + "
			.. tostring(uiLabel)
			.. " + "
			.. tostring(alleralUiLabel)
			.. " + "
			.. tostring(hubUiLabel)
	)
	return true
end

local function loadModule(localPaths, remotePath, marker, chunkName)
	local src, label = getSource(localPaths, remotePath, { marker = marker, minBytes = 500 })
	if not src then
		return false
	end
	local ok = compileAndRun(src, chunkName)
	if ok then
		log(chunkName .. " from " .. label)
	end
	return ok
end

local function loadWeaoStack()
	local localCfg = readLocal({ CFG .. "/weao.json", "config/weao.json" }, 20)
	local cfg = decodeJson(localCfg)
	if cfg then
		ENV.Alleral_WeaoConfig = cfg
	end

	if ENV.Alleral_Weao and type(ENV.Alleral_Weao.fetchExploits) == "function" then
		return true
	end

	if loadModule({ HUB .. "/weao.luau", "core/weao.luau" }, HUB .. "/weao.luau", "Alleral_Weao", "Alleral/weao") then
		return ENV.Alleral_Weao ~= nil
	end

	task.spawn(function()
		local cfgBody = httpFetch(GITHUB_RAW .. "/" .. CFG .. "/weao.json", { ["Accept"] = "application/json" })
		local remoteCfg = decodeJson(cfgBody)
		if remoteCfg then
			ENV.Alleral_WeaoConfig = remoteCfg
		end
	end)

	ENV.Alleral_Weao = {
		VERSION = "fallback",
		requestHeaders = function()
			return { ["User-Agent"] = "WEAO-3PService", ["Accept"] = "application/json" }
		end,
		mergeConfig = function(remote)
			if type(remote) == "table" then
				for key, value in pairs(remote) do
					ENV.Alleral_WeaoConfig = ENV.Alleral_WeaoConfig or {}
					ENV.Alleral_WeaoConfig[key] = value
				end
			end
			return ENV.Alleral_WeaoConfig or {}
		end,
		refreshConfig = function(opts)
			opts = type(opts) == "table" and opts or {}
			if type(opts.httpFetch) == "function" and type(opts.urls) == "table" then
				for _, url in ipairs(opts.urls) do
					local body = opts.httpFetch(url)
					if type(body) == "string" and body ~= "" then
						local ok, decoded = pcall(function()
							return HttpService and HttpService:JSONDecode(body)
						end)
						if ok and type(decoded) == "table" then
							opts.config = decoded
							break
						end
					end
				end
			end
			if type(opts.config) == "table" then
				for key, value in pairs(opts.config) do
					ENV.Alleral_WeaoConfig = ENV.Alleral_WeaoConfig or {}
					if key == "bases" and type(value) == "table" and #value > 0 then
						ENV.Alleral_WeaoConfig.bases = value
					elseif value ~= nil then
						ENV.Alleral_WeaoConfig[key] = value
					end
				end
			end
			return ENV.Alleral_WeaoConfig, (ENV.Alleral_WeaoConfig or {}).version, false
		end,
		fetchExploits = function()
			if ENV.Alleral_WeaoLastGood then
				return ENV.Alleral_WeaoLastGood.data, "last-good-cache"
			end
			return nil, "WEAO offline"
		end,
		matchExploit = function()
			return nil, 0
		end,
		formatEntry = function(entry)
			return entry
		end,
		statusLabel = function(weao)
			if type(weao) == "table" and weao.offline then
				return "Offline mode"
			end
			return "WEAO unavailable"
		end,
		executorStatus = function(profile)
			return {
				title = profile and (profile.name or profile.slug) or "Unknown",
				updateStatus = true,
				detected = false,
				offline = true,
			}, "fallback", 0
		end,
	}
	log("WEAO module unavailable — running in offline compatibility mode", true)
	return true
end

local function loadReturnTable(localPaths, remotePath)
	local src, _ = getSource(localPaths, remotePath, { minBytes = 20 })
	if not src or not loadStringFn then
		return nil
	end
	local fn, err = loadStringFn(src, "Alleral/return-module")
	if not fn and type(load) == "function" then
		fn, err = load(src, "Alleral/return-module")
	end
	if not fn then
		return nil
	end
	if setfenv then
		pcall(setfenv, fn, ENV)
	end
	local ok, result = pcall(fn)
	if ok and type(result) == "table" then
		return result
	end
	return nil
end

local function mergeTables(base, extra)
	if type(base) ~= "table" then
		base = {}
	end
	if type(extra) ~= "table" then
		return base
	end
	for key, value in pairs(extra) do
		base[key] = value
	end
	return base
end

local function trim(value)
	if value == nil then
		return ""
	end
	return tostring(value):match("^%s*(.-)%s*$") or ""
end

local function normalizeHttps(url)
	if type(url) ~= "string" or url == "" then
		return url
	end
	local value = trim(url)
	if value:sub(1, 7) == "http://" then
		return "https://" .. value:sub(8)
	end
	return value
end

local function loadTelemetryConfig(deferBootstrap)
	local cfg = nil
	local raw = readLocal({ CFG .. "/telemetry.json", "config/telemetry.json" }, 20)
	if raw then
		cfg = decodeJson(raw)
	end
	if not cfg then
		raw = select(1, httpFetch(GITHUB_RAW .. "/" .. CFG .. "/telemetry.json"))
		cfg = decodeJson(raw)
	end
	cfg = type(cfg) == "table" and cfg or { enabled = false }
	cfg = mergeTables(
		cfg,
		loadReturnTable({ CFG .. "/owner_telemetry.luau", "config/owner_telemetry.luau" }, CFG .. "/owner_telemetry.luau")
	)
	local function applyBootstrap()
		if trim(cfg.apiKey or "") == "" and trim(cfg.relayUrl or "") ~= "" then
			local base = cfg.relayUrl:gsub("/+$", ""):gsub("/ingest$", "")
			local boot = decodeJson(select(1, httpFetch(base .. "/api/bootstrap?t=" .. tick())))
			if type(boot) == "table" and boot.ok then
				if trim(boot.apiKey or "") ~= "" then
					cfg.apiKey = boot.apiKey
				end
				if trim(boot.relayUrl or "") ~= "" then
					cfg.relayUrl = normalizeHttps(boot.relayUrl)
				end
				if trim(boot.gateUrl or "") ~= "" then
					cfg.gateUrl = normalizeHttps(boot.gateUrl)
				end
				if trim(boot.banCheckUrl or "") ~= "" then
					cfg.banCheckUrl = normalizeHttps(boot.banCheckUrl)
					if trim(cfg.gateUrl or "") == "" then
						cfg.gateUrl = cfg.banCheckUrl
					end
				end
			end
		end
		if trim(cfg.relayUrl or "") ~= "" then
			cfg.relayUrl = normalizeHttps(cfg.relayUrl)
		end
		if trim(cfg.gateUrl or "") ~= "" then
			cfg.gateUrl = normalizeHttps(cfg.gateUrl)
		end
		ENV.Alleral_OwnerTelemetry = cfg
	end
	if deferBootstrap then
		ENV.Alleral_OwnerTelemetry = cfg
		task.spawn(applyBootstrap)
	else
		applyBootstrap()
	end
	return cfg
end

local function loadSecurityConfig()
	local cfg = nil
	local localRaw = readLocal({ CFG .. "/security.json", "config/security.json" }, 20)
	if localRaw then
		cfg = decodeJson(localRaw)
	end
	if not cfg then
		cfg = decodeJson(select(1, httpFetch(GITHUB_RAW .. "/" .. CFG .. "/security.json?t=" .. tick())))
	end
	cfg = type(cfg) == "table" and cfg or { enabled = false }
	local owner = ENV.Alleral_OwnerTelemetry
	if type(owner) == "table" then
		if trim(owner.apiKey) ~= "" and trim(cfg.apiKey) == "" then
			cfg.apiKey = owner.apiKey
		end
		if trim(cfg.gateUrl) == "" and trim(owner.relayUrl) ~= "" then
			local base = owner.relayUrl:gsub("/+$", ""):gsub("/ingest$", "")
			cfg.gateUrl = base .. "/gate/check"
		end
		if owner.gateUrl then
			cfg.gateUrl = owner.gateUrl
		end
		if trim(cfg.banCheckUrl or "") == "" and trim(owner.banCheckUrl or "") ~= "" then
			cfg.banCheckUrl = normalizeHttps(owner.banCheckUrl)
		end
		if trim(cfg.gateUrl or "") == "" and trim(cfg.banCheckUrl or "") ~= "" then
			cfg.gateUrl = cfg.banCheckUrl
		end
		if trim(cfg.apiKey) == "" and trim(owner.apiKey) ~= "" then
			cfg.apiKey = owner.apiKey
		end
		if trim(cfg.gateUrl) == "" and trim(owner.gateUrl) ~= "" then
			cfg.gateUrl = owner.gateUrl
		end
		if owner.security and type(owner.security) == "table" then
			cfg = mergeTables(cfg, owner.security)
		end
	end
	ENV.Alleral_OwnerSecurity = cfg
	return cfg
end

local function grantPublicAccess()
	local access = ENV.Alleral_Access
	if type(access) ~= "table" or type(access.ensureAccess) ~= "function" then
		getgenv().SCRIPT_KEY = "PUBLIC"
		ENV.SCRIPT_KEY = "PUBLIC"
		return true
	end
	local ok, mode = access.ensureAccess({ stage = "loader", executor = EXECUTOR })
	if ok then
		log("Access granted (" .. tostring(mode or "public") .. ", " .. EXECUTOR.slug .. ")")
	else
		log("Access denied: " .. tostring(mode or "unknown"), true)
	end
	return ok ~= false
end

local function enforceSecurityGate(profile, stage)
	local security = ENV.Alleral_Security
	if type(security) ~= "table" or type(security.enforce) ~= "function" then
		return true
	end
	local ok, reason = security.enforce({
		stage = stage or "loader",
		gameId = profile and profile.id,
	})
	if ok then
		return true
	end
	notify("Alleral", tostring(reason or "Access denied"), 10)
	log(tostring(reason or "Access denied"), true)
	return false
end

local function refreshTelemetryConfig()
	local telemetry = ENV.Alleral_Telemetry
	local cfg = ENV.Alleral_OwnerTelemetry
	if type(telemetry) ~= "table" or type(cfg) ~= "table" then
		return false
	end
	if type(telemetry.ReloadFromEnv) == "function" then
		local ok = pcall(telemetry.ReloadFromEnv, telemetry)
		return ok and telemetry:IsEnabled()
	end
	if type(telemetry.Configure) == "function" then
		pcall(telemetry.Configure, telemetry, cfg)
	end
	return type(telemetry.IsEnabled) == "function" and telemetry:IsEnabled()
end

local function ensureTelemetryLoaded()
	if ENV.Alleral_Telemetry and type(ENV.Alleral_Telemetry.ReportInject) == "function" then
		return refreshTelemetryConfig()
	end
	loadTelemetryConfig(false)
	if not loadModule(
		{ HUB .. "/telemetry.luau", "core/telemetry.luau" },
		HUB .. "/telemetry.luau",
		"Alleral_Telemetry",
		"Alleral/telemetry"
	) then
		return false
	end
	return refreshTelemetryConfig()
end

local function wireTelemetry(profile)
	if not ensureTelemetryLoaded() then
		local configError = ENV._Alleral_TelemetryConfigurationError
		if type(configError) == "string" and configError ~= "" and not ENV._Alleral_TelemetryConfigWarningShown then
			ENV._Alleral_TelemetryConfigWarningShown = true
			log("Telemetry disabled: " .. configError, true)
		end
		return
	end
	local telemetry = ENV.Alleral_Telemetry
	if type(telemetry) ~= "table" or type(telemetry.IsEnabled) ~= "function" or not telemetry:IsEnabled() then
		return
	end
	log("Telemetry active")
	telemetry:ReportSessionStart({
		gameId = profile and profile.id,
		scriptVersion = profile and profile.version,
		bootstrapVersion = ENV._Alleral_BootstrapVersion,
		releaseCommit = (ENV._Alleral_ExpectedVersions or {}).commit,
	})
	if ENV._Alleral_PlaceVersionChange and ENV._Alleral_PlaceVersionChange.changed then
		if type(telemetry.ReportPlaceUpdate) == "function" then
			telemetry:ReportPlaceUpdate(ENV._Alleral_PlaceVersionChange)
		end
		ENV._Alleral_PlaceVersionChange = nil
	end
	telemetry:StartHeartbeat()
end

local ENV_BRIDGE = [=[
do
	local bridge = shared
	if type(bridge) == "table" and getgenv then
		local g = getgenv()
		if type(g) == "table" then
			if bridge.Alleral_UI then g.Alleral_UI = bridge.Alleral_UI end
			if bridge.Alleral_Core then g.Alleral_Core = bridge.Alleral_Core end
			if bridge.Alleral_Telemetry then g.Alleral_Telemetry = bridge.Alleral_Telemetry end
			if bridge.Alleral_Weao then g.Alleral_Weao = bridge.Alleral_Weao end
			if bridge.Alleral_WeaoConfig then g.Alleral_WeaoConfig = bridge.Alleral_WeaoConfig end
			if bridge.Alleral_Boot then g.Alleral_Boot = bridge.Alleral_Boot end
			if bridge.Alleral_LoaderMeta then g.Alleral_LoaderMeta = bridge.Alleral_LoaderMeta end
			if bridge.Alleral_ReportError then g.Alleral_ReportError = bridge.Alleral_ReportError end
			if bridge.Alleral_LogEvent then g.Alleral_LogEvent = bridge.Alleral_LogEvent end
			if bridge.Alleral_OwnerTelemetry then g.Alleral_OwnerTelemetry = bridge.Alleral_OwnerTelemetry end
			if bridge.Alleral_OwnerSecurity then g.Alleral_OwnerSecurity = bridge.Alleral_OwnerSecurity end
			if bridge.Alleral_Security then g.Alleral_Security = bridge.Alleral_Security end
			if bridge.Alleral_Access then g.Alleral_Access = bridge.Alleral_Access end
			if bridge.SCRIPT_KEY then g.SCRIPT_KEY = bridge.SCRIPT_KEY end
			if bridge.Alleral_UI then g.Alleral_UI = bridge.Alleral_UI end
			g.Alleral_State = g.Alleral_State or bridge.Alleral_State or {}
			bridge.Alleral_State = g.Alleral_State
		end
	end
end
]=]

local function publishBridge()
	pcall(function()
		shared.Alleral_UI = ENV.Alleral_UI
		shared.Alleral_Core = ENV.Alleral_Core
		shared.Alleral_Analytics = ENV.Alleral_Analytics
		shared.Alleral_Telemetry = ENV.Alleral_Telemetry
		shared.Alleral_Weao = ENV.Alleral_Weao
		shared.Alleral_WeaoConfig = ENV.Alleral_WeaoConfig
		shared.Alleral_Boot = ENV.Alleral_Boot
		shared.Alleral_LoaderMeta = ENV.Alleral_LoaderMeta
		shared.Alleral_ReportError = ENV.Alleral_ReportError
		shared.Alleral_LogEvent = ENV.Alleral_LogEvent
		shared.Alleral_OwnerTelemetry = ENV.Alleral_OwnerTelemetry
		shared.Alleral_OwnerSecurity = ENV.Alleral_OwnerSecurity
		shared.Alleral_Security = ENV.Alleral_Security
		shared.Alleral_Access = ENV.Alleral_Access
		if getgenv().SCRIPT_KEY then
			shared.SCRIPT_KEY = getgenv().SCRIPT_KEY
		end
		shared.Alleral_State = ENV.Alleral_State or {}
	end)
end

local function waitForPath(root, path, timeout)
	local current = root
	for _, name in ipairs(path) do
		if not current then
			return nil
		end
		current = current:WaitForChild(name, timeout or 15)
	end
	return current
end

local GAMES = {
	-- Keep versions in sync with cfg/scripts_manifest.json
	{
		id = "kick_a_lucky_block",
		name = "Kick a Lucky Block",
		version = "6.9.0",
		placeIds = { 89469502395769 },
		universeIds = { 10004244222 },
		scriptFiles = { "games/kick_a_lucky_block.luau", "kick_a_lucky_block.luau" },
		scriptUrl = "games/kick_a_lucky_block.luau",
		sourceMarker = "buildUiWindow",
		minBytes = 100000,
		preload = function()
			waitForPath(ReplicatedStorage, { "Shared" }, 20)
			local areas = Workspace:WaitForChild("Areas", 20)
			if not areas or not areas:WaitForChild("KickReady", 10) then
				return false, "KickReady pad not found — are you in the main world?"
			end
			return true
		end,
		validate = function()
			local shared = ReplicatedStorage:FindFirstChild("Shared")
			local network = shared and shared:FindFirstChild("Packages") and shared.Packages:FindFirstChild("Network")
			local kickReady = Workspace:FindFirstChild("Areas") and Workspace.Areas:FindFirstChild("KickReady")
			return network ~= nil and kickReady ~= nil
		end,
	},
	{
		id = "speed_keyboard_escape",
		name = "Speed Keyboard Escape",
		version = "1.4.0",
		placeIds = { 95082159892680 },
		scriptFiles = { "games/speed_keyboard_escape.luau", "speed_keyboard_escape.luau" },
		scriptUrl = "games/speed_keyboard_escape.luau",
		minBytes = 22000,
		preload = function()
			waitForPath(ReplicatedStorage, { "Remotes" }, 20)
			return true
		end,
		validate = function()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			return remotes ~= nil and remotes:FindFirstChild("UpdateSpeed") ~= nil
		end,
	},
	{
		id = "slime_rng",
		name = "Slime RNG",
		version = "1.4.0",
		placeIds = { 92416421522960 },
		universeIds = { 9792947201 },
		scriptFiles = { "games/slime_rng.luau", "slime_rng.luau" },
		scriptUrl = "games/slime_rng.luau",
		minBytes = 40000,
		preload = function()
			waitForPath(ReplicatedStorage, { "Packages", "DataService" }, 25)
			return true
		end,
		validate = function()
			local packages = ReplicatedStorage:FindFirstChild("Packages")
			return packages and packages:FindFirstChild("DataService") ~= nil
		end,
	},
	{
		id = "build_a_ring_farm",
		name = "Build A Ring Farm",
		version = "1.3.1",
		placeIds = { 107646426076756 },
		scriptFiles = { "games/build_a_ring_farm.luau", "build_a_ring_farm.luau" },
		scriptUrl = "games/build_a_ring_farm.luau",
		sourceMarker = "coreRef.logWarn",
		minBytes = 55000,
		preload = function()
			waitForPath(ReplicatedStorage, { "Shared" }, 20)
			waitForPath(ReplicatedStorage, { "Remotes", "PlantSeed" }, 15)
			return true
		end,
		validate = function()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			return remotes and remotes:FindFirstChild("PlantSeed") ~= nil
		end,
	},
	{
		id = "survive_a_zombie_arena",
		name = "Survive a Zombie Arena",
		version = "2.2.0",
		placeIds = { 114204398207377 },
		scriptFiles = { "games/survive_a_zombie_arena.luau", "survive_a_zombie_arena.luau" },
		scriptUrl = "games/survive_a_zombie_arena.luau",
		minBytes = 18000,
		preload = function()
			waitForPath(ReplicatedStorage, { "ZombieRemotes", "ZombieDamage" }, 20)
			return true
		end,
		validate = function()
			local zombieRemotes = ReplicatedStorage:FindFirstChild("ZombieRemotes")
			return zombieRemotes and zombieRemotes:FindFirstChild("ZombieDamage") ~= nil
		end,
	},
}

local function readInstalledManifest()
	if not readFile or not isFile then
		return nil
	end
	for _, root in ipairs(WORKSPACE_ROOTS) do
		local path = root .. INSTALL_MANIFEST
		local okExists, exists = pcall(isFile, path)
		if okExists and exists then
			local okRead, raw = pcall(readFile, path)
			return decodeJson(okRead and raw or nil), path
		end
	end
	return nil
end

local function writeInstalledManifest(data)
	if type(writeFileFn) ~= "function" or not HttpService or type(data) ~= "table" then
		return
	end
	if makeFolderFn then
		pcall(makeFolderFn, ".alleral")
	end
	pcall(writeFileFn, INSTALL_MANIFEST, HttpService:JSONEncode(data))
end

local function fetchExpectedVersionsFast()
	local cached = ENV._Alleral_ExpectedVersions
	local cachedAt = ENV._Alleral_ExpectedVersionsAt
	if type(cached) == "table" and type(cachedAt) == "number" and tick() - cachedAt < EXPECTED_VERSIONS_CACHE_SECONDS then
		return cached
	end

	local expected = {
		loader = RELEASE_FALLBACK.loader,
		core = RELEASE_FALLBACK.core,
		analytics = RELEASE_FALLBACK.analytics,
		telemetry = RELEASE_FALLBACK.telemetry,
		helpers = RELEASE_FALLBACK.helpers,
		weao = RELEASE_FALLBACK.weao,
		alleral = RELEASE_FALLBACK.alleral,
		windui = RELEASE_FALLBACK.windui,
		commit = RELEASE_FALLBACK.commit,
		updatedAt = "",
		minLoader = LOADER_VERSION,
		minCore = MIN_CORE,
		updatePollSeconds = DEFAULT_UPDATE_POLL_SECONDS,
		autoUpdate = true,
		games = {},
	}
	for _, gameProfile in ipairs(GAMES) do
		expected.games[gameProfile.id] = gameProfile.version
	end

	local installed = readInstalledManifest()
	if type(installed) == "table" then
		for key, value in pairs(installed) do
			if expected[key] == nil or expected[key] == "" then
				expected[key] = value
			end
		end
	end

	ENV._Alleral_ExpectedVersions = expected
	ENV._Alleral_ExpectedVersionsAt = tick()
	return expected
end

fetchExpectedVersions = function(forceRefresh)
	local cached = ENV._Alleral_ExpectedVersions
	local cachedAt = ENV._Alleral_ExpectedVersionsAt
	if
		not forceRefresh
		and type(cached) == "table"
		and type(cachedAt) == "number"
		and tick() - cachedAt < EXPECTED_VERSIONS_CACHE_SECONDS
	then
		return cached
	end

	local expected = {
		loader = RELEASE_FALLBACK.loader,
		core = RELEASE_FALLBACK.core,
		analytics = RELEASE_FALLBACK.analytics,
		telemetry = RELEASE_FALLBACK.telemetry,
		helpers = RELEASE_FALLBACK.helpers,
		weao = RELEASE_FALLBACK.weao,
		alleral = RELEASE_FALLBACK.alleral,
		windui = RELEASE_FALLBACK.windui,
		commit = RELEASE_FALLBACK.commit,
		updatedAt = "",
		minLoader = LOADER_VERSION,
		minCore = MIN_CORE,
		updatePollSeconds = DEFAULT_UPDATE_POLL_SECONDS,
		autoUpdate = true,
		games = {},
	}
	for _, gameProfile in ipairs(GAMES) do
		expected.games[gameProfile.id] = gameProfile.version
	end

	local release = decodeJson(select(1, httpFetch(GITHUB_RAW .. "/" .. CFG .. "/release.json?t=" .. tick())))
	if release then
		expected.loader = release.loader or expected.loader
		expected.core = release.core or expected.core
		expected.analytics = release.analytics or expected.analytics
		expected.telemetry = release.telemetry or expected.telemetry
		expected.helpers = release.helpers or expected.helpers
		expected.weao = release.weao or expected.weao
		expected.alleral = release.alleral or release.windui or expected.alleral
		expected.windui = release.windui or expected.alleral or expected.windui
		expected.commit = release.commit or expected.commit
		expected.updatedAt = release.updatedAt or expected.updatedAt
		expected.sydePatch = tonumber(release.sydePatch) or expected.sydePatch
		expected.minLoader = release.minLoader or expected.minLoader
		expected.minCore = release.minCore or expected.minCore
		if type(release.updatePollSeconds) == "number" then
			expected.updatePollSeconds = clampNumber(release.updatePollSeconds, 15, 600)
		end
		if release.autoUpdate ~= nil then
			expected.autoUpdate = release.autoUpdate == true
		end
	end

	local manifest = decodeJson(select(1, httpFetch(GITHUB_RAW .. "/" .. CFG .. "/scripts_manifest.json?t=" .. tick())))
	if manifest and type(manifest.scripts) == "table" then
		for id, entry in pairs(manifest.scripts) do
			if type(entry) == "table" and type(entry.version) == "string" then
				expected.games[id] = entry.version
				for _, gameProfile in ipairs(GAMES) do
					if gameProfile.id == id then
						gameProfile.version = entry.version
					end
				end
			end
		end
	end

	ENV._Alleral_ExpectedVersions = expected
	ENV._Alleral_ExpectedVersionsAt = tick()
	return expected
end

local function refreshExpectedVersionsAsync()
	safeSpawn(function()
		if type(fetchExpectedVersions) ~= "function" then
			return
		end
		local expected = fetchExpectedVersions(true)
		if type(expected) == "table" then
			ENV._Alleral_ExpectedVersions = expected
		end
	end)
end

local function buildUpdateFingerprint(expected, profile)
	if type(expected) ~= "table" then
		return ""
	end
	local parts = {
		"commit=" .. tostring(expected.commit or ""),
		"updated=" .. tostring(expected.updatedAt or ""),
		"loader=" .. tostring(expected.loader or ""),
		"core=" .. tostring(expected.core or ""),
		"telemetry=" .. tostring(expected.telemetry or ""),
		"analytics=" .. tostring(expected.analytics or ""),
		"helpers=" .. tostring(expected.helpers or ""),
		"weao=" .. tostring(expected.weao or ""),
		"weaoCfg=" .. tostring((ENV.Alleral_WeaoConfig or {}).version or ""),
		"sydePatch=" .. tostring(expected.sydePatch or SYDE_PATCH_VERSION),
	}
	if profile and profile.id then
		table.insert(parts, "game=" .. tostring(profile.id) .. "@" .. tostring(expected.games and expected.games[profile.id] or profile.version or ""))
	end
	table.insert(parts, "alleral=" .. tostring(expected.alleral or ""))
	table.insert(parts, "windui=" .. tostring(expected.windui or ""))
	return table.concat(parts, "|")
end

local function stopAutoUpdater()
	ENV._Alleral_AutoUpdateRunning = false
	ENV._Alleral_AutoUpdateToken = nil
end

local function buildManagedFiles()
	local managed = {
		{
			paths = {
				CP.base,
				CP.legacy,
				"core/alleral_core.luau",
				"alleral_core.luau",
				".alleral/cache/" .. CP.base,
				".alleral/cache/" .. CP.legacy,
			},
			expectedKey = "core",
			extract = "core",
			isValid = coreValid,
		},
		{
			paths = {
				CP.ui,
				HUB .. "/core_ui.luau",
				".alleral/cache/" .. CP.ui,
			},
			expectedKey = "core",
			extract = "core",
			isValid = coreUiValid,
		},
		{
			paths = {
				CP.alleral,
				HUB .. "/alleral_ui.luau",
				".alleral/cache/" .. CP.alleral,
			},
			expectedKey = "alleral",
			extract = "alleral",
			isValid = alleralUiValid,
		},
		{
			paths = {
				UI .. "/syde/source.luau",
				".alleral/cache/" .. UI .. "/syde/source.luau",
			},
			expectedKey = "syde",
			extract = "syde",
			isValid = sydeSourceValid,
		},
		{
			paths = {
				UI .. "/alleral_maclib/init.luau",
				UI .. "/alleral_maclib/util.luau",
				UI .. "/alleral_maclib/theme.luau",
				UI .. "/alleral_maclib/notify.luau",
				UI .. "/alleral_maclib/elements.luau",
				UI .. "/alleral_maclib/section.luau",
				UI .. "/alleral_maclib/window.luau",
				".alleral/cache/" .. UI .. "/alleral_maclib/init.luau",
			},
			alwaysDelete = true,
		},
		{
			paths = {
				HUB .. "/ui_premium.luau",
				".alleral/cache/" .. HUB .. "/ui_premium.luau",
			},
			alwaysDelete = true,
		},
		{
			paths = {
				CP.hub,
				HUB .. "/core_hub_ui.luau",
				".alleral/cache/" .. CP.hub,
			},
			expectedKey = "core",
			extract = "core",
			isValid = coreHubUiValid,
		},
		{
			paths = { HUB .. "/analytics.luau" },
			expectedKey = "analytics",
			extract = "analytics",
		},
		{
			paths = { HUB .. "/telemetry.luau", "core/telemetry.luau" },
			expectedKey = "telemetry",
			extract = "telemetry",
		},
		{
			paths = { HUB .. "/helpers.luau", "core/game_helpers.luau" },
			expectedKey = "helpers",
			extract = "helpers",
		},
		{
			paths = { HUB .. "/weao.luau", "core/weao.luau" },
			expectedKey = "weao",
			extract = "weao",
		},
		{
			paths = { HUB .. "/security.luau" },
			expectedKey = "security",
			extract = "security",
		},
		{
			paths = { HUB .. "/access.luau", "core/access.luau" },
			expectedKey = "access",
			extract = "access",
		},
		{
			paths = LEGACY_HUB_UI_FILES,
			alwaysDelete = true,
		},
		{
			paths = {
				UI .. "/neverlose/library.lua",
				".alleral/cache/" .. UI .. "/neverlose/library.lua",
			},
			alwaysDelete = true,
		},
		{
			paths = {
				UI .. "/windui/main.lua",
				UI .. "/windui/bootstrap.lua",
				UI .. "/windui/aller.luau",
				UI .. "/windui/arrrel.luau",
				UI .. "/windui/autoscale.luau",
				UI .. "/windui/v2/boost.luau",
			},
			alwaysDelete = true,
		},
		{
			paths = { CFG .. "/weao.json", "config/weao.json" },
			purgeOnLoaderChange = true,
		},
		{
			paths = { CFG .. "/telemetry.json", "config/telemetry.json" },
			purgeOnLoaderChange = true,
		},
		{
			paths = { CFG .. "/security.json", "config/security.json" },
			purgeOnLoaderChange = true,
		},
		{
			paths = { CFG .. "/access.json", "config/access.json" },
			purgeOnLoaderChange = true,
		},
		{
			paths = { CFG .. "/owner_telemetry.luau", "config/owner_telemetry.luau" },
			purgeOnLoaderChange = true,
		},
		{
			paths = {
				"loader.luau",
				"kick/loader.luau",
				"workspace/loader.luau",
				"autoexec/loader.luau",
				"Autoexec/loader.luau",
				"autoexec/alleral.luau",
				"Autoexec/alleral.luau",
			},
			expectedKey = "loader",
			extract = "loader",
		},
		{
			paths = {
				BOOTSTRAP_REMOTE_PATH,
				"kick/" .. BOOTSTRAP_REMOTE_PATH,
				".alleral/cache/" .. BOOTSTRAP_REMOTE_PATH,
			},
			expectedKey = "bootstrap",
			extract = "bootstrap",
		},
		{
			paths = {
				"load.luau",
				"kick/load.luau",
				"launch.luau",
				"run.luau",
				"autoexec/load.luau",
				"autoexec/launch.luau",
				"autoexec/run.luau",
				"Autoexec/load.luau",
			},
			alwaysDelete = true,
		},
	}
	for _, gameProfile in ipairs(GAMES) do
		table.insert(managed, {
			paths = gameProfile.scriptFiles,
			gameId = gameProfile.id,
			extract = "game",
		})
	end
	return managed
end

local function shouldDeleteCachedFile(src, entry, expected, installedManifest)
	if entry.alwaysDelete then
		return true
	end

	local expectedVersion
	if entry.gameId then
		expectedVersion = expected.games and expected.games[entry.gameId]
	elseif entry.purgeOnLoaderChange then
		local installedLoader = installedManifest and installedManifest.loader
		return type(installedLoader) == "string" and installedLoader ~= expected.loader
	elseif entry.extract == "syde" then
		expectedVersion = tostring(SYDE_PATCH_VERSION)
	else
		expectedVersion = expected[entry.expectedKey]
	end

	if type(expectedVersion) ~= "string" or expectedVersion == "" then
		return entry.extract == "syde" or false
	end

	if type(src) ~= "string" or src == "" then
		return true
	end

	if usesLegacyHttpHash(src) then
		return true
	end

	if entry.isValid and not entry.isValid(src) then
		return true
	end

	local foundVersion = extractFileVersion(src, entry.extract)
	if type(foundVersion) == "string" and foundVersion ~= "" and type(expectedVersion) == "string" and expectedVersion ~= "" then
		if entry.extract == "syde" then
			local foundPatch = tonumber(foundVersion) or 0
			local needPatch = tonumber(expectedVersion) or SYDE_PATCH_VERSION
			return foundPatch < needPatch
		end
		return foundVersion ~= expectedVersion
	end

	if not foundVersion then
		if entry.isValid and entry.isValid(src) then
			return false
		end
		return true
	end

	if foundVersion ~= expectedVersion then
		if entry.expectedKey == "core" and entry.isValid and entry.isValid(src) and not foundVersion then
			return false
		end
		if entry.expectedKey == "helpers" and type(src) == "string" and #src > 500 and src:find("return", 1, true) then
			return false
		end
		if entry.gameId then
			for _, profile in ipairs(GAMES) do
				if profile.id == entry.gameId and gameScriptValid(src, profile) then
					return false
				end
			end
		end
		return true
	end

	return false
end

local function isLegacyAlleralLoader(src)
	if type(src) ~= "string" or #src < 80 then
		return false
	end
	if src:find('LOADER_VERSION = "' .. LOADER_VERSION .. '"', 1, true) then
		return false
	end
	if src:find('local LOADER_VERSION = "8.2.25"', 1, true) then
		return false
	end
	if src:find("[Alleral] v" .. LOADER_VERSION:gsub("%.", "%%."), 1, true) then
		return false
	end
	for _, marker in ipairs(LEGACY_LOADER_MARKERS) do
		if src:find(marker, 1, true) then
			return true
		end
	end
	local ver = src:match('LOADER_VERSION%s*=%s*"([%d%.]+)"')
	if ver and versionLt(ver, "5.0") then
		return true
	end
	if src:find("Alleral loader", 1, true) and src:find("Detected Kick", 1, true) then
		return true
	end
	if src:find("local=true", 1, true) and src:find("[Alleral Loader v", 1, true) then
		return true
	end
	return false
end

local function legacyVersionLabel(src)
	if type(src) ~= "string" then
		return nil
	end
	return src:match('LOADER_VERSION%s*=%s*"([%d%.]+)"')
		or src:match("%[Alleral Loader v([%d%.]+)%]")
		or src:match("Alleral loader ([%d%.]+)")
end

local function readFileIfExists(relativePath)
	if not isFile or not readFile then
		return nil
	end
	local okExists, exists = pcall(isFile, relativePath)
	if not (okExists and exists) then
		return nil
	end
	local okRead, src = pcall(readFile, relativePath)
	return okRead and src or nil
end

local function isScannableScriptPath(path)
	return path:match("%.luau$")
		or path:match("%.lua$")
		or path:match("%.txt$")
		or path:lower():find("loader", 1, true)
		or path:lower():find("alleral", 1, true)
		or path:lower():find("bootstrap", 1, true)
		or path:lower():find("launch", 1, true)
end

local function forEachWorkspaceFile(callback, depthLimit)
	depthLimit = depthLimit or 14
	local listFn = firstExecFunc("listfiles", "list_files", "ListFiles")
	local isFolderFn = firstExecFunc("isfolder", "is_folder", "IsFolder")
	if not listFn then
		return false
	end

	local seen = {}
	local function walk(dir, depth)
		if depth > depthLimit then
			return
		end
		dir = dir:gsub("^/", ""):gsub("/$", "")
		if dir == "" or dir == "." then
			return
		end
		if isFolderFn then
			local okFolder, exists = pcall(isFolderFn, dir)
			if not okFolder or exists ~= true then
				return
			end
		else
			return
		end
		local ok, entries = pcall(listFn, dir)
		if not ok or type(entries) ~= "table" then
			return
		end
		for _, entry in ipairs(entries) do
			if type(entry) == "string" then
				local path = entry:gsub("^/", "")
				if seen[path] then
					-- skip
				else
					seen[path] = true
					local isDir = false
					if isFolderFn then
						local okFolder, folder = pcall(isFolderFn, path)
						isDir = okFolder and folder == true
					end
					if isDir then
						walk(path, depth + 1)
					elseif isScannableScriptPath(path) then
						callback(path, readFileIfExists(path))
					end
				end
			end
		end
	end

	for _, dir in ipairs(SCAN_DIRS) do
		walk(dir, 0)
	end
	return true
end

local function scanLegacyLoaders()
	local hits = {}
	local function consider(path, src)
		if isLegacyAlleralLoader(src) then
			table.insert(hits, {
				path = path,
				version = legacyVersionLabel(src) or "unknown",
			})
		end
	end

	for _, dir in ipairs(SCAN_DIRS) do
		for _, name in ipairs(LEGACY_ENTRY_NAMES) do
			local path = dir == "" and name or (dir .. "/" .. name)
			consider(path, readFileIfExists(path))
		end
	end

	forEachWorkspaceFile(function(path, src)
		consider(path, src)
	end)

	return hits
end

local function clearLegacySession()
	if type(ENV.Alleral_Core) == "table" and type(ENV.Alleral_Core.releaseUiWindow) == "function" then
		pcall(ENV.Alleral_Core.releaseUiWindow)
	end
	local lib = ENV._AlleralUiLibrary
	if type(lib) == "table" and type(lib.Unload) == "function" then
		pcall(lib.Unload, lib)
	end
	ENV._AlleralUiLibrary = nil
	if getgenv().Library then
		getgenv().Library = nil
	end
	if ENV.Alleral_State and type(ENV.Alleral_State.Alleral_Unload) == "function" then
		pcall(ENV.Alleral_State.Alleral_Unload)
	end
	ENV.Alleral_LoaderRunning = false
end

local function purgeLegacyLoaders()
	if not isFile or not readFile then
		return 0, false, {}
	end

	local removed = 0
	local autoexecHit = false
	local deletedPaths = {}

	for _, hit in ipairs(scanLegacyLoaders()) do
		if deleteWorkspaceFile(hit.path) then
			removed += 1
			table.insert(deletedPaths, hit.path)
			if hit.path:lower():find("autoexec", 1, true) then
				autoexecHit = true
			end
		end
	end

	return removed, autoexecHit, deletedPaths
end

local function reportLegacyScan(hits, deletedPaths)
	if type(hits) ~= "table" then
		hits = scanLegacyLoaders()
	end
	if #hits == 0 then
		log("No legacy loader files found in executor workspace")
		return
	end
	for _, hit in ipairs(hits) do
		local deleted = false
		for _, path in ipairs(deletedPaths or {}) do
			if path == hit.path then
				deleted = true
				break
			end
		end
		if not deleted then
			log("Legacy loader still on disk: " .. hit.path .. " (v" .. hit.version .. ")", true)
		end
	end
end

local function purgeDirectoryTree(dir, opts, removedCounter)
	opts = type(opts) == "table" and opts or {}
	if type(dir) ~= "string" or dir == "" then
		return
	end
	dir = dir:gsub("^/", ""):gsub("/$", "")
	if isFolderFn then
		local okFolder, exists = pcall(isFolderFn, dir)
		if not okFolder or exists ~= true then
			return
		end
	else
		return
	end
	if not listFilesFn then
		return
	end
	local okList, entries = pcall(listFilesFn, dir)
	if not okList or type(entries) ~= "table" then
		if deleteFolderFn then
			pcall(deleteFolderFn, dir)
		end
		return
	end
	for _, entry in ipairs(entries) do
		if type(entry) == "string" then
			local path = entry:gsub("^/", "")
			local isDir = false
			if isFolderFn then
				local okFolder, folder = pcall(isFolderFn, path)
				isDir = okFolder and folder == true
			end
			if isDir then
				purgeDirectoryTree(path, opts, removedCounter)
			elseif deleteWorkspaceFile(path, { silent = true, label = opts.label or "cached" }) then
				removedCounter[1] += 1
			end
		end
	end
	if deleteFolderFn then
		pcall(deleteFolderFn, dir)
	end
end

local function collectAlleralPurgePaths()
	local paths = {}
	local seen = {}
	local function add(path)
		if type(path) ~= "string" or path == "" or seen[path] then
			return
		end
		seen[path] = true
		table.insert(paths, path)
	end
	for _, path in ipairs(LOADER_LOCAL_PATHS) do
		add(path)
	end
	for _, path in ipairs(BOOTSTRAP_LOCAL_PATHS) do
		add(path)
	end
	add("alleral_bootstrap.luau")
	add("Alleral/loader.luau")
	add(INSTALL_MANIFEST)
	for _, entry in ipairs(buildManagedFiles()) do
		for _, path in ipairs(entry.paths) do
			add(path)
		end
	end
	return paths
end

local function purgeAlleralWorkspace(opts)
	opts = type(opts) == "table" and opts or {}
	if not isFile or not deleteFileFn then
		return 0
	end

	local removedCounter = { 0 }
	local seen = {}
	local deleteOpts = { silent = true, label = opts.label or "cached" }

	local function tryDelete(relativePath)
		if type(relativePath) ~= "string" or relativePath == "" or seen[relativePath] then
			return
		end
		seen[relativePath] = true
		if deleteWorkspaceFile(relativePath, deleteOpts) then
			removedCounter[1] += 1
		end
	end

	for _, path in ipairs(collectAlleralPurgePaths()) do
		tryDelete(path)
		for _, root in ipairs(WORKSPACE_ROOTS) do
			tryDelete(root .. path)
		end
	end

	for _, dir in ipairs({ ".alleral", HUB, UI, CFG, "core", "games", "Alleral", "kick" }) do
		purgeDirectoryTree(dir, deleteOpts, removedCounter)
	end

	forEachWorkspaceFile(function(path)
		local lower = path:lower()
		if lower:find("alleral", 1, true)
			or lower:find("loader%.luau$")
			or lower:find("bootstrap%.luau$")
			or lower:find("syde", 1, true)
		then
			tryDelete(path)
		end
	end)

	if removedCounter[1] > 0 and not opts.quiet then
		local reason = opts.reason and (" (" .. tostring(opts.reason) .. ")") or ""
		log("Workspace purge: removed " .. tostring(removedCounter[1]) .. " cached Alleral file(s)" .. reason)
	end

	return removedCounter[1]
end

local function purgeOutdatedWorkspace(opts)
	opts = type(opts) == "table" and opts or {}
	local expected = opts.useNetwork and fetchExpectedVersions() or fetchExpectedVersionsFast()
	ENV._Alleral_ExpectedVersions = expected
	return purgeAlleralWorkspace({
		reason = opts.reason or "sync",
		quiet = opts.quiet,
		label = opts.label,
	})
end

local function recordInstalledVersions()
	local expected = ENV._Alleral_ExpectedVersions
	if type(expected) == "table" then
		writeInstalledManifest(expected)
	end
end

local function applyRemoteUpdate(profile, expected, reason)
	if ENV._Alleral_UpdateApplying then
		return
	end
	ENV._Alleral_UpdateApplying = true
	stopAutoUpdater()
	log("Update available (" .. tostring(reason) .. ") — refreshing from GitHub")
	local telemetry = ENV.Alleral_Telemetry
	if type(telemetry) == "table" and type(telemetry.ReportEvent) == "function" then
		pcall(function()
			telemetry:ReportEvent("milestone", "Hub auto-update: " .. tostring(reason), {
				commit = expected and expected.commit,
				loaderVersion = expected and expected.loader,
				coreVersion = expected and expected.core,
				telemetryVersion = expected and expected.telemetry,
				gameId = profile and profile.id,
				reason = reason,
			})
		end)
	end
	notify("Alleral", "update found, reloading", 4)
	ENV._Alleral_ExpectedVersions = expected
	pcall(purgeOutdatedWorkspace)
	pcall(recordInstalledVersions)
	task.defer(function()
		ENV._Alleral_UpdateApplying = false
		if ENV.Alleral_Reload then
			ENV.Alleral_Reload()
		end
	end)
end

local function checkForRemoteUpdate(profile, quiet)
	local expected = fetchExpectedVersions(true)
	local fingerprint = buildUpdateFingerprint(expected, profile)
	local previous = ENV._Alleral_UpdateFingerprint
	ENV._Alleral_ExpectedVersions = expected

	if type(previous) ~= "string" or previous == "" then
		ENV._Alleral_UpdateFingerprint = fingerprint
		if not quiet then
			log("Auto-update armed (" .. tostring(expected.commit ~= "" and expected.commit or "release") .. ")")
		end
		return false
	end

	if fingerprint == previous then
		return false
	end

	local reason = "release changed"
	if expected.commit ~= "" and not previous:find(tostring(expected.commit), 1, true) then
		reason = "commit " .. tostring(expected.commit)
	elseif expected.loader and not previous:find("loader=" .. tostring(expected.loader), 1, true) then
		reason = "loader v" .. tostring(expected.loader)
	elseif expected.sydePatch and not previous:find("sydePatch=" .. tostring(expected.sydePatch), 1, true) then
		reason = "syde patch v" .. tostring(expected.sydePatch)
	elseif profile and expected.games and expected.games[profile.id] then
		reason = profile.name .. " v" .. tostring(expected.games[profile.id])
	end

	applyRemoteUpdate(profile, expected, reason)
	return true
end

local function armAutoUpdateFingerprint(profile, quiet)
	local expected = ENV._Alleral_ExpectedVersions or fetchExpectedVersions(true)
	ENV._Alleral_ExpectedVersions = expected
	ENV._Alleral_UpdateFingerprint = buildUpdateFingerprint(expected, profile)
	if not quiet then
		log("Auto-update armed (" .. tostring(expected.commit ~= "" and expected.commit or "release") .. ")")
	end
end

local function startAutoUpdater(profile)
	stopAutoUpdater()
	local expected = ENV._Alleral_ExpectedVersions or fetchExpectedVersions()
	if expected.autoUpdate == false then
		return
	end
	local pollSeconds = tonumber(expected.updatePollSeconds) or DEFAULT_UPDATE_POLL_SECONDS
	pollSeconds = clampNumber(math.floor(pollSeconds), 15, 600)
	ENV._Alleral_AutoUpdateRunning = true
	local token = tick()
	ENV._Alleral_AutoUpdateToken = token
	task.spawn(function()
		while ENV._Alleral_AutoUpdateRunning and ENV._Alleral_AutoUpdateToken == token do
			task.wait(pollSeconds)
			if ENV._Alleral_AutoUpdateToken ~= token then
				break
			end
			pcall(function()
				checkForRemoteUpdate(profile, true)
			end)
			if ENV._Alleral_AutoUpdatePollCount == nil or ENV._Alleral_AutoUpdatePollCount % 3 == 0 then
				pcall(function()
					syncWeaoConfig(true)
				end)
			end
			ENV._Alleral_AutoUpdatePollCount = (ENV._Alleral_AutoUpdatePollCount or 0) + 1
		end
	end)
	log("Auto-update polling every " .. tostring(pollSeconds) .. "s")
end

local function initRelaunchHooks()
	if type(ENV._Alleral_EnsureTeleportWatch) == "function" then
		return true
	end
	ENV._Alleral_GAMES = GAMES
	ENV._Alleral_LoaderInternals = {
		log = log,
		notify = notify,
		httpGet = httpGet,
		compileAndRun = compileAndRun,
		loaderRunEnv = loaderRunEnv,
		stopAutoUpdater = stopAutoUpdater,
		GITHUB_RAW = GITHUB_RAW,
		BOOTSTRAP_REMOTE_PATH = BOOTSTRAP_REMOTE_PATH,
		BOOTSTRAP_LOADSTRING = BOOTSTRAP_LOADSTRING,
		writeFileFn = writeFileFn,
		makeFolderFn = makeFolderFn,
		isFolderFn = isFolderFn,
		game = game,
	}
	local commit = RELEASE_FALLBACK.commit or BRANCH
	local relaunchPath = HUB .. "/loader_relaunch.luau"
	local urls = {
		GITHUB_RAW .. "/" .. relaunchPath .. "?t=" .. tostring(tick()),
		JSDELIVR .. "/" .. relaunchPath .. "?t=" .. tostring(tick()),
		"https://raw.githubusercontent.com/" .. REPO .. "/" .. commit .. "/" .. relaunchPath .. "?t=" .. tostring(tick()),
	}
	for _, url in ipairs(urls) do
		local src, via = httpGet(url, 300)
		if type(src) == "string" and #src >= 300 then
			local ok, err = compileAndRun(src, "Alleral/loader_relaunch", loaderRunEnv())
			if ok and type(ENV._Alleral_EnsureTeleportWatch) == "function" then
				return true
			end
			if not ok then
				log("Relaunch module failed (" .. tostring(via) .. "): " .. tostring(err), true)
			end
		end
	end
	return false
end

pcall(initRelaunchHooks)

local function detectGame()
	local placeId = game.PlaceId
	local universeId = nil
	do
		local ok, id = pcall(function()
			return game.GameId
		end)
		if ok and type(id) == "number" and id > 0 then
			universeId = id
		end
	end
	local best, bestScore = nil, 0

	for _, profile in ipairs(GAMES) do
		local score = 0
		for _, id in ipairs(profile.placeIds or {}) do
			if id == placeId then
				score = score + 100
			end
		end
		for _, id in ipairs(profile.universeIds or {}) do
			if id == universeId then
				score = score + 50
			end
		end
		if profile.validate and profile.validate() then
			score = score + 25
		end
		if score > bestScore then
			bestScore = score
			best = profile
		end
	end

	if not best or bestScore < 25 then
		return nil, "No supported game (PlaceId " .. tostring(placeId) .. ")"
	end
	if bestScore < 100 and not (best.validate and best.validate()) then
		return nil, best.name .. " markers not found in this server"
	end
	return best
end

local function main()
	if ENV.Alleral_LoaderRunning then
		log("Already running — use getgenv().Alleral_Reload()", true)
		return
	end
	ENV.Alleral_LoaderRunning = true
	ENV._Alleral_LoaderVersion = LOADER_VERSION

	local bootOk, bootErr = verifyBootstrapAttestation()
	if not bootOk then
		notify("Alleral", tostring(bootErr), 10)
		log(tostring(bootErr), true)
		ENV.Alleral_LoaderRunning = false
		return
	end

	local execOk, execErr = enforceExecutorPolicy()
	if not execOk then
		notify("Alleral", tostring(execErr), 10)
		log(tostring(execErr), true)
		ENV.Alleral_LoaderRunning = false
		return
	end

	if not loadStringFn then
		notify("Alleral", "This executor needs loadstring.", 8)
		ENV.Alleral_LoaderRunning = false
		return
	end

	local prevCore = ENV.Alleral_Core
	if type(prevCore) == "table" and type(prevCore.releaseUiWindow) == "function" then
		pcall(prevCore.releaseUiWindow)
	end

	ENV.Alleral_Core = nil
	ENV.Alleral_Rayfield = nil
	ENV.Alleral_UI = nil
	ENV.Alleral_Weao = nil
	ENV.Alleral_StartupFailed = nil

	if type(PREVIOUS_LOADER_VERSION) == "string" and versionLt(PREVIOUS_LOADER_VERSION, LOADER_VERSION) then
		log("Upgrading from loader v" .. PREVIOUS_LOADER_VERSION .. " — purging stale workspace cache")
		ENV._Alleral_UpdateFingerprint = nil
	end

	if ENV._Alleral_PendingRelaunch then
		log("Continuing session after teleport")
		ENV._Alleral_PendingRelaunch = nil
	end

	if ENV.Alleral_AutoRelaunch == nil then
		ENV.Alleral_AutoRelaunch = true
	end

	if type(ENV._Alleral_InstallGlobalBootstrap) ~= "function" then
		pcall(initRelaunchHooks)
	end
	if type(ENV._Alleral_InstallGlobalBootstrap) == "function" then
		ENV._Alleral_InstallGlobalBootstrap()
	end
	if type(ENV._Alleral_MarkSupportedPlaces) == "function" then
		ENV._Alleral_MarkSupportedPlaces()
	end

	local expectedVersions = fetchExpectedVersions(true)
	ENV._Alleral_ExpectedVersions = expectedVersions
	loadTelemetryConfig(false)
	purgeAlleralWorkspace({ reason = "boot" })
	ENV.Alleral_HTTP = ENV.Alleral_HTTP or {}
	ENV.Alleral_HTTP.get = httpGet
	local sydePrefetchOk, sydePrefetchLabel = ensureSydeSource()
	if sydePrefetchOk then
		log("Syde source ready (" .. tostring(sydePrefetchLabel) .. ")")
	else
		log("Syde source not cached yet: " .. tostring(sydePrefetchLabel), true)
	end
	refreshExpectedVersionsAsync()
	if expectedVersions.loader and versionLt(LOADER_VERSION, expectedVersions.loader) then
		log(
			"Remote loader v"
				.. tostring(expectedVersions.loader)
				.. " available (session v"
				.. LOADER_VERSION
				.. ") — auto-updating via bootstrap"
		)
		ENV.Alleral_LoaderRunning = false
		task.defer(function()
			local count = tonumber(ENV._Alleral_RelaunchCount) or 0
			local last = tonumber(ENV._Alleral_LastRelaunch) or 0
			if count >= MAX_RELAUNCHES or os.time() - last < RELAUNCH_COOLDOWN then
				warn("[Alleral v" .. LOADER_VERSION .. "] Skipping relaunch (count=" .. count .. ")")
				return
			end
			ENV._Alleral_RelaunchCount = count + 1
			ENV._Alleral_LastRelaunch = os.time()
			if type(ENV._Alleral_RelaunchViaBootstrap) == "function" then
				ENV._Alleral_RelaunchViaBootstrap("loader-version-sync")
			end
		end)
		return
	end
	if expectedVersions.minLoader and versionLt(LOADER_VERSION, expectedVersions.minLoader) then
		log(
			"Loader v"
				.. LOADER_VERSION
				.. " is below minimum v"
				.. tostring(expectedVersions.minLoader)
				.. " — fetching latest bootstrap"
		)
		ENV.Alleral_LoaderRunning = false
		task.defer(function()
					local count = tonumber(ENV._Alleral_RelaunchCount) or 0
					local last = tonumber(ENV._Alleral_LastRelaunch) or 0
					if count >= MAX_RELAUNCHES or os.time() - last < RELAUNCH_COOLDOWN then return end
					ENV._Alleral_RelaunchCount = count + 1
					ENV._Alleral_LastRelaunch = os.time()
					if type(ENV._Alleral_RelaunchViaBootstrap) == "function" then
						ENV._Alleral_RelaunchViaBootstrap("min-loader-sync")
								end
							end)
						return
					end
			if expectedVersions.commit and expectedVersions.commit ~= "" and expectedVersions.commit ~= RELEASE_FALLBACK.commit then
		log(
			"Embedded commit "
				.. tostring(RELEASE_FALLBACK.commit)
				.. " != release "
				.. tostring(expectedVersions.commit)
				.. " — continuing (bootstrap may refresh on next relaunch)"
		)
	end
	local needSydePatch = tonumber(expectedVersions.sydePatch) or SYDE_PATCH_VERSION
	if needSydePatch ~= SYDE_PATCH_VERSION then
		log(
			"Embedded syde patch v"
				.. tostring(SYDE_PATCH_VERSION)
				.. " != release v"
				.. tostring(needSydePatch)
				.. " — auto-updating via bootstrap"
		)
		ENV.Alleral_LoaderRunning = false
		task.defer(function()
			local count = tonumber(ENV._Alleral_RelaunchCount) or 0
			local last = tonumber(ENV._Alleral_LastRelaunch) or 0
			if count >= MAX_RELAUNCHES or os.time() - last < RELAUNCH_COOLDOWN then
				warn("[Alleral v" .. LOADER_VERSION .. "] Skipping syde-patch relaunch (count=" .. count .. ")")
				return
			end
			ENV._Alleral_RelaunchCount = count + 1
			ENV._Alleral_LastRelaunch = os.time()
			if type(ENV._Alleral_RelaunchViaBootstrap) == "function" then
				ENV._Alleral_RelaunchViaBootstrap("syde-patch-sync")
			end
		end)
		return
	end

	task.spawn(function()
		pcall(loadWeaoStack)
		pcall(function()
			syncWeaoConfig(true)
		end)
		pcall(refreshWeaoProfile, EXECUTOR)
	end)

	clearLegacySession()

	local loaderUpgraded = type(PREVIOUS_LOADER_VERSION) == "string" and PREVIOUS_LOADER_VERSION ~= LOADER_VERSION
	task.spawn(function()
		local legacyRemoved, autoexecHit, deletedPaths = purgeLegacyLoaders()
		if legacyRemoved > 0 then
			log("Removed " .. tostring(legacyRemoved) .. " legacy loader file(s)")
			if autoexecHit and type(ENV._Alleral_InstallAutoexecRedirect) == "function" then
				ENV._Alleral_InstallAutoexecRedirect()
			end
		elseif loaderUpgraded then
			local remaining = scanLegacyLoaders()
			if #remaining > 0 then
				reportLegacyScan(remaining, deletedPaths)
				notify(
					"Alleral",
					"Old loader files found — run getgenv().Alleral_ScanLegacy() to list them",
					8
				)
			end
		end
	end)

	if type(PREVIOUS_LOADER_VERSION) == "string" and versionLt(PREVIOUS_LOADER_VERSION, "5.0") then
		local savedScriptsHint = EXECUTOR.name .. " saved scripts"
		log(
			"Old loader v"
				.. PREVIOUS_LOADER_VERSION
				.. " ran before this script — check "
				.. savedScriptsHint
				.. " and workspace loader files",
			true
		)
		notify(
			"Alleral",
			"v3.x ran earlier. Check " .. savedScriptsHint .. " and workspace loader.luau.",
			15
		)
	end

	ENV.Alleral_ScriptManifestUrl = GITHUB_RAW .. "/" .. CFG .. "/scripts_manifest.json"

	local profile, err = detectGame()
	if not profile then
		notify("Alleral", tostring(err), 8)
		log(tostring(err), true)
		ENV.Alleral_LoaderRunning = false
		return
	end

	log(string.format(
		"Game: %s | executor=%s (%s)%s",
		profile.name,
		EXECUTOR.name,
		EXECUTOR.slug,
		EXECUTOR.weaoVerified and " · WEAO" or ""
	))
	ENV._Alleral_ActiveProfile = profile

	if profile.preload then
		local ready, preloadErr = profile.preload()
		if not ready then
			notify("Alleral", tostring(preloadErr), 8)
			ENV.Alleral_LoaderRunning = false
			return
		end
	end

	local coreOk, coreErr = loadCore()
	if not coreOk then
		notify("Alleral", "Core failed: " .. tostring(coreErr), 8)
		log("Core failed: " .. tostring(coreErr), true)
		ENV.Alleral_LoaderRunning = false
		return
	end

	ENV.Alleral_ActiveScriptId = profile.id
	if ENV.Alleral_Core and type(ENV.Alleral_Core.evaluateScriptStatus) == "function" then
		task.spawn(function()
			if type(ENV.Alleral_Core.fetchScriptManifest) == "function" then
				pcall(ENV.Alleral_Core.fetchScriptManifest)
			end
		end)
		local evaluation = ENV.Alleral_Core.evaluateScriptStatus(profile.id, profile.version)
		if not evaluation.allowed then
			local status = evaluation.status
			local msg = status.label
			if status.message ~= "" then
				msg = msg .. " — " .. status.message
			end
			msg = msg .. ". Set getgenv().Alleral_ForceLoad = true and reload to bypass."
			notify("Alleral", status.icon .. " " .. msg, 12)
			log(status.icon .. " " .. msg, true)
			ENV.Alleral_LoaderRunning = false
			return
		end
		if evaluation.warn and evaluation.status.message ~= "" then
			notify("Alleral", evaluation.status.icon .. " " .. evaluation.status.message, 6)
		end
	end

	local uiBundle, uiErr
	runParallel({
		function()
			loadModule({ HUB .. "/security.luau" }, HUB .. "/security.luau", "Alleral_Security", "Alleral/security")
		end,
		function()
			loadModule({ HUB .. "/access.luau", "core/access.luau" }, HUB .. "/access.luau", "Alleral_Access", "Alleral/access")
		end,
		function()
			loadSecurityConfig()
		end,
		function()
			loadAccessConfig()
		end,
		function()
			if ENV.Alleral_Core and type(ENV.Alleral_Core.preloadUi) == "function" then
				uiBundle, uiErr = ENV.Alleral_Core.preloadUi()
			elseif ENV.Alleral_Core and type(ENV.Alleral_Core.loadUi) == "function" then
				uiBundle, uiErr = ENV.Alleral_Core.loadUi()
			end
		end,
	})
	local gameSrc, gameLabel = fetchGameScript(profile)
	ensureTelemetryLoaded()

	grantPublicAccess()
	task.spawn(function()
		pcall(loadModule, { HUB .. "/analytics.luau" }, HUB .. "/analytics.luau", "Alleral_Analytics", "Alleral/analytics")
		pcall(loadModule, { HUB .. "/helpers.luau", "core/game_helpers.luau" }, HUB .. "/helpers.luau", "GameHelpers", "Alleral/helpers")
	end)

	if not enforceSecurityGate(profile, "pre_inject") then
		ENV.Alleral_LoaderRunning = false
		return
	end

	if uiBundle then
		ENV.Alleral_UI = uiBundle
		log("Alleral ready")
	elseif uiErr then
		log("UI skipped: " .. tostring(uiErr), true)
	end

	if ensureTelemetryLoaded() then
		ENV.Alleral_Telemetry:ReportInject("start", {
			gameId = profile.id,
			scriptVersion = profile.version,
		})
	end

	local src, label = gameSrc, gameLabel
	if not src then
		notify("Alleral", "Game script failed: " .. tostring(label), 8)
		log("Game script failed: " .. tostring(label), true)
		if ENV.Alleral_Telemetry and ENV.Alleral_Telemetry.ReportInject then
			ENV.Alleral_Telemetry:ReportInject("failed", { error = tostring(label), gameId = profile.id })
		end
		ENV.Alleral_LoaderRunning = false
		return
	end

	log("Loading " .. profile.name .. " v" .. profile.version .. " from " .. label)
	ENV.Alleral_Boot = LOADER_VERSION
	ENV.Alleral_LoaderMeta = {
		version = LOADER_VERSION,
		profile = profile.id,
		source = label,
		scriptVersion = profile.version,
		bootstrapVersion = ENV._Alleral_BootstrapVersion,
		releaseCommit = (ENV._Alleral_ExpectedVersions or {}).commit,
	}
	publishBridge()
	src = ENV_BRIDGE .. "\n" .. src

	local ok, runErr = compileAndRun(src, "Alleral/" .. profile.id, ENV)
	ENV.Alleral_LoaderRunning = false

	if not ok then
		notify("Alleral", tostring(runErr), 8)
		log(tostring(runErr), true)
		return
	end
	if ENV.Alleral_StartupFailed then
		notify("Alleral", tostring(ENV.Alleral_StartupFailed), 8)
		if ENV.Alleral_Telemetry and ENV.Alleral_Telemetry.ReportInject then
			ENV.Alleral_Telemetry:ReportInject("failed", { error = tostring(ENV.Alleral_StartupFailed) })
		end
		return
	end

	if ENV.Alleral_Telemetry and ENV.Alleral_Telemetry.ReportInject then
		ENV.Alleral_Telemetry:ReportInject("loaded", {
			gameId = profile.id,
			scriptVersion = profile.version,
		})
	end

	wireTelemetry(profile)
	recordInstalledVersions()
	pcall(function()
		if type(ENV._Alleral_EnsureAutoexec) == "function" then
			ENV._Alleral_EnsureAutoexec()
		end
	end)
	pcall(function()
		if type(ENV._Alleral_EnsureTeleportWatch) == "function" then
			ENV._Alleral_EnsureTeleportWatch()
		end
	end)
	task.defer(function()
		pcall(purgeAlleralWorkspace, { reason = "post-boot", quiet = true })
		pcall(armAutoUpdateFingerprint, profile, true)
	end)
	startAutoUpdater(profile)
	ENV._Alleral_LastLoadAt = tick()
	ENV._Alleral_LastPlaceId = game.PlaceId
	ENV._Alleral_LastJobId = game.JobId
	ENV._Alleral_PendingRelaunch = nil
	notify("Alleral", profile.name .. " loaded", 4)
	if ENV._Alleral_GameRecentlyUpdated and type(ENV._Alleral_GameUpdateMessage) == "string" then
		notify("Alleral", ENV._Alleral_GameUpdateMessage, 10)
		ENV._Alleral_GameRecentlyUpdated = nil
	end
	log("ready")
end

publishConsoleApi("Alleral_Bootstrap", function(reason)
	local relaunch = ENV._Alleral_RelaunchViaBootstrap
	if type(relaunch) ~= "function" then
		return false, "bootstrap relaunch unavailable"
	end
	local ok, err = relaunch(reason or "manual-bootstrap")
	if not ok then
		warn("[Alleral v" .. LOADER_VERSION .. "] Bootstrap failed: " .. tostring(err))
		return false, err
	end
	return true, err
end)

publishConsoleApi("Alleral_Load", function()
	local relaunch = ENV._Alleral_RelaunchViaBootstrap
	if type(relaunch) ~= "function" then
		warn("[Alleral v" .. LOADER_VERSION .. "] Load failed: bootstrap relaunch unavailable")
		return false
	end
	local ok, err = relaunch("manual-load")
	if not ok then
		warn("[Alleral v" .. LOADER_VERSION .. "] Load failed: " .. tostring(err))
		return false
	end
	return true
end)

publishConsoleApi("Alleral_Reload", function()
	stopAutoUpdater()
	if type(ENV._Alleral_RunLoader) == "function" then
		ENV._Alleral_RunLoader("manual-reload")
		return true
	end
	if ENV.Alleral_State and type(ENV.Alleral_State.Alleral_Unload) == "function" then
		pcall(ENV.Alleral_State.Alleral_Unload)
	end
	ENV._Alleral_TeleportWatchConnected = nil
	if typeof(task) == "table" and task.defer then
		task.defer(main)
	else
		main()
	end
	return true
end)

publishConsoleApi("Alleral_LoaderInfo", function()
	return {
		version = LOADER_VERSION,
		capabilities = CAPABILITIES,
		executor = EXECUTOR,
		games = GAMES,
	}
end)

publishConsoleApi("Alleral_ScanLegacy", function()
	local hits = scanLegacyLoaders()
	print("[Alleral v" .. LOADER_VERSION .. "] Legacy scan (" .. tostring(#hits) .. " hit(s)):")
	for _, hit in ipairs(hits) do
		print("  - " .. hit.path .. " (v" .. hit.version .. ")")
	end
	if #hits == 0 then
		print("  (none — if you still see v3.x logs, it is a Saved Script or old one-liner, not a workspace file)")
	end
	return hits
end)

publishConsoleApi("Alleral_PurgeCache", function()
	local ok, err = pcall(function()
		purgeAlleralWorkspace({ reason = "manual" })
		checkForRemoteUpdate(ENV._Alleral_ActiveProfile, false)
	end)
	if not ok then
		warn("[Alleral v" .. LOADER_VERSION .. "] Purge failed: " .. tostring(err))
		return false
	end
	print("[Alleral v" .. LOADER_VERSION .. "] Workspace cache purge complete")
	return true
end)

publishConsoleApi("Alleral_CheckUpdate", function()
	local profile = ENV._Alleral_ActiveProfile
	if checkForRemoteUpdate(profile, false) then
		print("[Alleral v" .. LOADER_VERSION .. "] Update found — reloading")
		return true
	end
	print("[Alleral v" .. LOADER_VERSION .. "] Already up to date")
	return false
end)

publishConsoleApi("Alleral_SyncWeao", syncWeaoConfig)

log("v" .. LOADER_VERSION .. " booting on PlaceId " .. tostring(game.PlaceId) .. " (" .. EXECUTOR.slug .. ")")

task.defer(function()
	local ok, err = pcall(main)
	if not ok then
		log(tostring(err), true)
		notify("Alleral", tostring(err), 10)
		ENV.Alleral_LoaderRunning = false
	end
end)
