local LOADER_VERSION = "7.7.3"
local MIN_CORE = "2.7.0"
local DEFAULT_UPDATE_POLL_SECONDS = 120
local EXPECTED_VERSIONS_CACHE_SECONDS = 60
local CORE_MIN_BYTES = 50000
local CORE_BASE_MIN_BYTES = 30000
local CORE_BASE_MAX_BYTES = 45000
local CORE_UI_MIN_BYTES = 50000
local CORE_UI_MAX_BYTES = 70000
local CORE_HUB_UI_MIN_BYTES = 60000
local CORE_HUB_UI_MAX_BYTES = 75000
local CORE_MONOLITH_MIN_BYTES = 130000
local HUB = "hub"
local CFG = "cfg"
local UI = "ui"
local CORE_BASE_PATH = HUB .. "/core_base.luau"
local CORE_BASE_LEGACY_PATH = HUB .. "/core.luau"
local CORE_UI_PATH = HUB .. "/core_ui.luau"
local CORE_HUB_UI_PATH = HUB .. "/core_hub_ui.luau"

local RELEASE_FALLBACK = {
	loader = "7.7.3",
	core = "2.8.3",
	ui = "Alleral",
	windui = "2.1.3-alleral-v2",
	analytics = "1.2",
	telemetry = "3.2",
	helpers = "1.0",
	weao = "1.0",
	security = "1.3",
	access = "1.0",
	commit = "c99d6b7",
	updatePollSeconds = DEFAULT_UPDATE_POLL_SECONDS,
	autoUpdate = true,
}
local WORKSPACE_ROOTS = {
	"",
	"kick/",
	"kick/kick/",
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
	"kick/kick/loader.luau",
	"Alleral/loader.luau",
}
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
	"kick/kick",
}
local REPO = "evanbackup1256-ship-it/kick"
local BRANCH = "main"
local GITHUB_RAW = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH
local GITHUB_WEB = "https://github.com/" .. REPO .. "/raw/" .. BRANCH
local REMOTE_BASES = { GITHUB_RAW, GITHUB_WEB }
local JSDELIVR = "https://cdn.jsdelivr.net/gh/" .. REPO .. "@" .. BRANCH
local CORE_REMOTE_BASES = { GITHUB_RAW, GITHUB_WEB, JSDELIVR }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = nil
pcall(function()
	HttpService = game:GetService("HttpService")
end)

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()
local PREVIOUS_LOADER_VERSION = ENV._Alleral_LoaderVersion or ENV.Alleral_LoaderVersion
ENV._Alleral_LoaderVersion = LOADER_VERSION
ENV.Alleral_LoaderRunning = false

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

local function tryGameHttpGet(url)
	local urls = { url .. "?t=" .. tostring(tick()), url }
	for _, fetchUrl in ipairs(urls) do
		if type(game.HttpGet) == "function" then
			local ok, body = pcall(game.HttpGet, game, fetchUrl, true)
			if type(body) == "string" and #body > 0 then
				return body, "httpget"
			end
			ok, body = pcall(game.HttpGet, game, fetchUrl)
			if type(body) == "string" and #body > 0 then
				return body, "httpget"
			end
		end
		local ok, body = pcall(function()
			return game:HttpGet(fetchUrl, true)
		end)
		if ok and type(body) == "string" and #body > 0 then
			return body, "httpget"
		end
		ok, body = pcall(function()
			return game:HttpGet(fetchUrl)
		end)
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

local function httpFetch(url, headers)
	headers = headers or {}
	local bust = url .. (url:find("?") and "&" or "?") .. "t=" .. tostring(tick())

	local body, via = tryGameHttpGet(url)
	if body then
		return body, via
	end

	local req = getHttpRequestFn()
	if req then
		body = requestVia(req, bust, headers)
		if body then
			return body, "request"
		end
	end

	local sharedEnv = ENV.shared or (typeof(shared) == "table" and shared) or nil
	local solaraLib = sharedEnv and type(sharedEnv.solara) == "table" and sharedEnv.solara or nil
	for _, fn in ipairs({
		type(ENV.fluxus) == "table" and ENV.fluxus.request,
		solaraLib and solaraLib.request,
		type(ENV.Xeno) == "table" and ENV.Xeno.request,
		type(ENV.Wave) == "table" and ENV.Wave.request,
	}) do
		body = requestVia(fn, bust, headers)
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

local HTTP_TRANSPORTS = buildHttpTransports(EXECUTOR.slug)

local CAPABILITIES = {
	executor = EXECUTOR.name,
	executorSlug = EXECUTOR.slug,
	weaoVerified = EXECUTOR.weaoVerified == true,
	loadstring = loadStringFn ~= nil,
	readfile = readFile ~= nil,
}

local function httpGet(url, minBytes)
	minBytes = minBytes or 0

	local bestBody, bestVia, bestLen = nil, nil, 0
	local function consider(body, via)
		if type(body) == "string" and #body > bestLen then
			bestBody, bestVia, bestLen = body, via, #body
		end
	end

	if ENV.Alleral_Core and type(ENV.Alleral_Core.httpGet) == "function" then
		consider(ENV.Alleral_Core.httpGet(url), "core")
	end

	local body, via = tryGameHttpGet(url)
	consider(body, via)

	local req = getHttpRequestFn()
	if req then
		consider(requestVia(req, url .. "?t=" .. tick()), "request")
	end

	for _, transport in ipairs(HTTP_TRANSPORTS) do
		consider(transport.fetch(url), transport.id)
		consider(transport.fetch(url .. "?t=" .. tick()), transport.id)
	end

	body, via = httpFetch(url)
	consider(body, via)

	if bestBody and #bestBody >= minBytes then
		return bestBody, bestVia
	end
	if bestBody then
		return nil, (bestVia or "http") .. " (" .. tostring(bestLen) .. "b, need " .. tostring(minBytes) .. "b)"
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

local function deleteWorkspaceFile(relativePath)
	if type(deleteFileFn) ~= "function" or type(isFile) ~= "function" then
		return false
	end
	local okExists, exists = pcall(isFile, relativePath)
	if not (okExists and exists) then
		return false
	end
	local ok = pcall(deleteFileFn, relativePath)
	if ok then
		log("Removed outdated " .. relativePath)
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

local function usesLegacyHttpHash(src)
	if type(src) ~= "string" then
		return false
	end
	return src:find("HttpService:Hash", 1, true) ~= nil or src:find("HttpService%.Hash", 1, true) ~= nil
end

local function getSource(localPaths, remotePath, opts)
	opts = type(opts) == "table" and opts or { marker = opts }
	local minBytes = opts.minBytes or 0
	local marker = opts.marker

	local src, path = readLocal(localPaths, minBytes)
	if src then
		if usesLegacyHttpHash(src) then
			log("Removing Volt-incompatible cached " .. path, true)
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

local function gameScriptValid(body, profile)
	if type(body) ~= "string" then
		return false
	end
	local minBytes = profile.minBytes or 40000
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
	if profile.version and not body:find('local VERSION = "' .. profile.version .. '"', 1, true) then
		return false
	end
	return true
end

local function gameScriptRejectReason(body, profile)
	if type(body) ~= "string" or body == "" then
		return "empty response"
	end
	local minBytes = profile.minBytes or 40000
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
	if profile.version and not body:find('local VERSION = "' .. profile.version .. '"', 1, true) then
		return "missing VERSION " .. profile.version
	end
	return "unknown"
end

local function collectHttpBodies(url)
	local results = {}
	local seen = {}
	local function add(body, via)
		if type(body) ~= "string" or #body == 0 or seen[via] then
			return
		end
		seen[via] = true
		table.insert(results, { body = body, via = via, len = #body })
	end

	if ENV.Alleral_Core and type(ENV.Alleral_Core.httpGet) == "function" then
		add(ENV.Alleral_Core.httpGet(url), "core")
	end

	add(select(1, tryGameHttpGet(url)), "httpget")

	local req = getHttpRequestFn()
	if req then
		add(requestVia(req, url .. "?t=" .. tick()), "request")
	end

	for _, transport in ipairs(HTTP_TRANSPORTS) do
		add(transport.fetch(url), transport.id)
		add(transport.fetch(url .. "?t=" .. tick()), transport.id)
	end

	add(select(1, httpFetch(url)), "httpfetch")
	return results
end

local function collectCoreHttpBodies(url)
	local results = {}
	local seen = {}
	local function add(body, via)
		if type(body) ~= "string" or #body == 0 or seen[via] then
			return
		end
		seen[via] = true
		table.insert(results, { body = body, via = via, len = #body })
	end

	local bustUrl = url .. (url:find("?", 1, true) and "&" or "?") .. "alleral=" .. LOADER_VERSION .. "&t=" .. tick()

	for _, transport in ipairs(HTTP_TRANSPORTS) do
		if transport.id == "httpget" then
			add(transport.fetch(bustUrl), "httpget")
			add(transport.fetch(url), "httpget-plain")
		end
	end
	add(select(1, tryGameHttpGet(bustUrl)), "httpget-fallback")

	if HttpService and type(HttpService.GetAsync) == "function" then
		local ok, body = pcall(function()
			return HttpService:GetAsync(bustUrl, true)
		end)
		if ok then
			add(body, "httpservice")
		end
	end

	for _, transport in ipairs(HTTP_TRANSPORTS) do
		if transport.id ~= "httpget" and transport.id ~= "request" then
			add(transport.fetch(bustUrl), transport.id)
		end
	end

	add(select(1, httpFetch(bustUrl)), "httpfetch")

	local req = getHttpRequestFn()
	if req then
		add(requestVia(req, bustUrl), "request")
	end
	return results
end

local function fetchGameScript(profile)
	local minBytes = profile.minBytes or 40000

	local src, path = readLocal(profile.scriptFiles, minBytes)
	if src and gameScriptValid(src, profile) then
		return src, "local:" .. path
	end
	if src and path then
		log("Removing invalid local game script at " .. path, true)
		deleteWorkspaceFile(path)
	end

	local best, bestInvalid, lastErr = nil, nil, nil
	for _, base in ipairs(REMOTE_BASES) do
		for _, suffix in ipairs({ "", "?t=" .. tick() }) do
			local url = base .. "/" .. profile.scriptUrl .. suffix
			for _, item in ipairs(collectHttpBodies(url)) do
				if gameScriptValid(item.body, profile) then
					if not best or item.len > best.len then
						best = { body = item.body, via = item.via, base = base, len = item.len }
					end
				elseif item.len > (bestInvalid and bestInvalid.len or 0) then
					bestInvalid = item
				end
			end
		end
		if best then
			break
		end
	end

	if best then
		cacheRemote(profile.scriptUrl, best.body)
		return best.body, best.base .. " via " .. best.via .. " (" .. tostring(best.len) .. "b)"
	end

	if bestInvalid then
		lastErr = bestInvalid.via .. " (" .. gameScriptRejectReason(bestInvalid.body, profile) .. ")"
	elseif lastErr == nil then
		lastErr = "all transports failed"
	end

	return nil, lastErr
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
	if runEnv and setfenv then
		pcall(setfenv, fn, runEnv)
	end
	local ok, runErr = pcall(fn)
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

local function compileCoreSource(src, label)
	if type(loadStringFn) ~= "function" then
		return true
	end
	local fn, err = loadStringFn(src, label or "Alleral/core-check")
	if type(fn) == "function" then
		return true
	end
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

local function fetchRemoteCoreFile(relativePath, validFn, rejectReasonFn)
	local best, bestInvalid = nil, nil
	for _, base in ipairs(CORE_REMOTE_BASES) do
		local url = base .. "/" .. relativePath
		for _, item in ipairs(collectCoreHttpBodies(url)) do
			if validFn(item.body) then
				if not best or item.len > best.len then
					best = { body = item.body, via = item.via, base = base, len = item.len }
				end
			elseif item.len > (bestInvalid and bestInvalid.len or 0) then
				bestInvalid = item
			end
		end
	end

	if best then
		cacheRemote(relativePath, best.body)
		return best.body, best.base .. " via " .. best.via .. " (" .. tostring(best.len) .. "b)"
	end

	if bestInvalid then
		return nil, bestInvalid.via .. " (" .. rejectReasonFn(bestInvalid.body) .. ")"
	end
	return nil, "all transports failed"
end

local function fetchCoreRemote()
	return fetchRemoteCoreFile(CORE_BASE_PATH, coreValid, coreRejectReason)
end

local function fetchCoreUiRemote()
	return fetchRemoteCoreFile(CORE_UI_PATH, coreUiValid, coreUiRejectReason)
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
		task.wait()
	end
	return results
end

local function resolveCoreSource(localPaths, cachePaths, remotePath, validFn, rejectReasonFn, minBytes)
	local src, path = readLocal(localPaths, minBytes)
	local label
	if not src then
		src, path = readLocal(cachePaths, minBytes)
		if src then
			label = "cache:" .. tostring(path or cachePaths[1])
		end
	end
	if src and not validFn(src) then
		log("Removing broken file at " .. tostring(path or localPaths[1]), true)
		for _, localPath in ipairs(localPaths) do
			deleteWorkspaceFile(localPath)
		end
		for _, cachePath in ipairs(cachePaths) do
			deleteWorkspaceFile(cachePath)
		end
		src = nil
		label = nil
	end
	if src and validFn(src) then
		label = label or ("local:" .. tostring(path or localPaths[1]))
	else
		src, label = fetchRemoteCoreFile(remotePath, validFn, rejectReasonFn)
		if not src then
			return nil, label
		end
	end
	return src, label
end

local function purgeStaleCorePaths()
	local stalePaths = {
		CORE_BASE_LEGACY_PATH,
		".alleral/cache/" .. CORE_BASE_LEGACY_PATH,
		CORE_BASE_PATH,
		".alleral/cache/" .. CORE_BASE_PATH,
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
					if stale and not coreValid(src) then
						deleteWorkspaceFile(path)
					end
				end
			end
		end
	end
end

local function loadCore()
	ENV.Alleral_Core = nil
	purgeStaleCorePaths()

	local baseSrc, baseLabel = resolveCoreSource(
		{ CORE_BASE_PATH, CORE_BASE_LEGACY_PATH, "core/alleral_core.luau", "alleral_core.luau" },
		{ ".alleral/cache/" .. CORE_BASE_PATH, ".alleral/cache/" .. CORE_BASE_LEGACY_PATH },
		CORE_BASE_PATH,
		coreValid,
		coreRejectReason,
		CORE_BASE_MIN_BYTES
	)
	if not baseSrc then
		return false, baseLabel or "Core download failed"
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
		cacheRemote(CORE_BASE_PATH, baseSrc)
		cacheRemote(".alleral/cache/" .. CORE_BASE_PATH, baseSrc)
		log("Core v" .. tostring(ENV.Alleral_Core.VERSION) .. " (monolith) from " .. tostring(baseLabel))
		return true
	end

	if type(ENV.Alleral_Core.applyUiLayer) ~= "function" then
		return false, "Split core missing applyUiLayer"
	end

	local uiSrc, uiLabel = resolveCoreSource(
		{ CORE_UI_PATH, HUB .. "/core_ui.luau" },
		{ ".alleral/cache/" .. CORE_UI_PATH },
		CORE_UI_PATH,
		coreUiValid,
		coreUiRejectReason,
		CORE_UI_MIN_BYTES
	)
	if not uiSrc then
		ENV.Alleral_Core = nil
		return false, uiLabel or "Core UI download failed"
	end

	local hubUiSrc, hubUiLabel = resolveCoreSource(
		{ CORE_HUB_UI_PATH, HUB .. "/core_hub_ui.luau" },
		{ ".alleral/cache/" .. CORE_HUB_UI_PATH },
		CORE_HUB_UI_PATH,
		coreHubUiValid,
		coreHubUiRejectReason,
		CORE_HUB_UI_MIN_BYTES
	)
	if not hubUiSrc then
		ENV.Alleral_Core = nil
		return false, hubUiLabel or "Core hub UI download failed"
	end

	local applied, applyErr = ENV.Alleral_Core.applyUiLayer(uiSrc, uiLabel or "@Alleral/core_ui")
	if not applied then
		ENV.Alleral_Core = nil
		return false, applyErr or "Core UI layer failed"
	end

	applied, applyErr = ENV.Alleral_Core.applyUiLayer(hubUiSrc, hubUiLabel or "@Alleral/core_hub_ui")
	if not applied then
		ENV.Alleral_Core = nil
		return false, applyErr or "Core hub UI layer failed"
	end

	if not ENV.Alleral_Core._UiLayerReady or type(ENV.Alleral_Core.loadUi) ~= "function" then
		ENV.Alleral_Core = nil
		return false, "Core UI layers incomplete"
	end

	cacheRemote(CORE_BASE_PATH, baseSrc)
	cacheRemote(".alleral/cache/" .. CORE_BASE_PATH, baseSrc)
	cacheRemote(CORE_UI_PATH, uiSrc)
	cacheRemote(".alleral/cache/" .. CORE_UI_PATH, uiSrc)
	cacheRemote(CORE_HUB_UI_PATH, hubUiSrc)
	cacheRemote(".alleral/cache/" .. CORE_HUB_UI_PATH, hubUiSrc)
	log(
		"Core v"
			.. tostring(ENV.Alleral_Core.VERSION)
			.. " from "
			.. tostring(baseLabel)
			.. " + "
			.. tostring(uiLabel)
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
	local cfgBody = httpFetch(GITHUB_RAW .. "/" .. CFG .. "/weao.json", { ["Accept"] = "application/json" })
	local cfg = decodeJson(cfgBody)
	if cfg then
		ENV.Alleral_WeaoConfig = cfg
	end

	if ENV.Alleral_Weao and type(ENV.Alleral_Weao.fetchExploits) == "function" then
		return true
	end

	if loadModule({ HUB .. "/weao.luau", "core/weao.luau" }, HUB .. "/weao.luau", "Alleral_Weao", "Alleral/weao") then
		return ENV.Alleral_Weao ~= nil
	end

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

local function loadTelemetryConfig()
	local cfg = nil
	local raw = select(1, httpFetch(GITHUB_RAW .. "/" .. CFG .. "/telemetry.json"))
	cfg = decodeJson(raw)
	if not cfg then
		local localRaw = readLocal({ CFG .. "/telemetry.json", "config/telemetry.json" }, 20)
		if localRaw then
			cfg = decodeJson(localRaw)
		end
	end
	cfg = type(cfg) == "table" and cfg or { enabled = false }
	cfg = mergeTables(
		cfg,
		loadReturnTable({ CFG .. "/owner_telemetry.luau", "config/owner_telemetry.luau" }, CFG .. "/owner_telemetry.luau")
	)
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
	return cfg
end

local function loadSecurityConfig()
	local cfg = decodeJson(select(1, httpFetch(GITHUB_RAW .. "/" .. CFG .. "/security.json?t=" .. tick())))
	if not cfg then
		local localRaw = readLocal({ CFG .. "/security.json", "config/security.json" }, 20)
		cfg = localRaw and decodeJson(localRaw) or nil
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

local function loadAccessConfig()
	local cfg = decodeJson(select(1, httpFetch(GITHUB_RAW .. "/" .. CFG .. "/access.json?t=" .. tick())))
	if not cfg then
		local localRaw = readLocal({ CFG .. "/access.json", "config/access.json" }, 20)
		cfg = localRaw and decodeJson(localRaw) or nil
	end
	cfg = type(cfg) == "table" and cfg or { mode = "public", publicKey = "PUBLIC" }
	ENV.Alleral_OwnerAccess = cfg
	return cfg
end

local function grantPublicAccess()
	local access = ENV.Alleral_Access
	if type(access) ~= "table" or type(access.ensureAccess) ~= "function" then
		getgenv().SCRIPT_KEY = "PUBLIC"
		ENV.SCRIPT_KEY = "PUBLIC"
		return true
	end
	local ok, mode = access.ensureAccess({ stage = "loader" })
	if ok then
		log("Access granted (" .. tostring(mode or "public") .. ")")
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

local function wireTelemetry(profile)
	local telemetry = ENV.Alleral_Telemetry
	if type(telemetry) ~= "table" or type(telemetry.IsEnabled) ~= "function" or not telemetry:IsEnabled() then
		return
	end
	log("Telemetry on")
	telemetry:ReportSessionStart({
		gameId = profile and profile.id,
		scriptVersion = profile and profile.version,
	})
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

local VERSION_PATTERNS = {
	core = 'Core%.VERSION%s*=%s*"([%d%.]+)"',
	analytics = 'Analytics%.Version%s*=%s*"([%d%.]+)"',
	telemetry = 'Telemetry%.Version%s*=%s*"([%d%.]+)"',
	helpers = 'Helpers%.VERSION%s*=%s*"([%d%.]+)"',
	weao = 'Weao%.VERSION%s*=%s*"([%d%.]+)"',
	security = 'Security%.VERSION%s*=%s*"([%d%.]+)"',
	access = 'Access%.VERSION%s*=%s*"([%d%.]+)"',
	loader = 'LOADER_VERSION%s*=%s*"([%d%.]+)"',
	windui = 'ARRREL_UI_VERSION%s*=%s*"([^"]+)"',
	game = 'local VERSION%s*=%s*"([%d%.]+)"',
}

local function extractFileVersion(src, kind)
	if type(src) ~= "string" then
		return nil
	end
	local pattern = VERSION_PATTERNS[kind]
	if not pattern then
		return nil
	end
	return src:match(pattern)
end

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

local function fetchExpectedVersions(forceRefresh)
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
		expected.windui = release.windui or expected.windui
		expected.commit = release.commit or expected.commit
		expected.updatedAt = release.updatedAt or expected.updatedAt
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
	}
	if profile and profile.id then
		table.insert(parts, "game=" .. tostring(profile.id) .. "@" .. tostring(expected.games and expected.games[profile.id] or profile.version or ""))
	end
	return table.concat(parts, "|")
end

local function stopAutoUpdater()
	ENV._Alleral_AutoUpdateRunning = false
	ENV._Alleral_AutoUpdateToken = nil
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
	purgeOutdatedWorkspace()
	recordInstalledVersions()
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
	elseif profile and expected.games and expected.games[profile.id] then
		reason = profile.name .. " v" .. tostring(expected.games[profile.id])
	end

	applyRemoteUpdate(profile, expected, reason)
	return true
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

local function buildManagedFiles()
	local managed = {
		{
			paths = { CORE_BASE_PATH, CORE_BASE_LEGACY_PATH, "core/alleral_core.luau", "alleral_core.luau" },
			expectedKey = "core",
			extract = "core",
			isValid = coreValid,
		},
		{
			paths = { CORE_UI_PATH, HUB .. "/core_ui.luau" },
			expectedKey = "core",
			extract = "core",
			isValid = coreUiValid,
		},
		{
			paths = { CORE_HUB_UI_PATH, HUB .. "/core_hub_ui.luau" },
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
			paths = {
				UI .. "/windui/main.lua",
				UI .. "/windui/arrrel.luau",
				UI .. "/windui/autoscale.luau",
				UI .. "/windui/aller.luau",
				UI .. "/windui/bootstrap.lua",
				UI .. "/windui/v2/boost.luau",
				UI .. "/windui/VERSION",
			},
			expectedKey = "windui",
			extract = "windui",
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
				"kick/kick/loader.luau",
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
				"load.luau",
				"kick/load.luau",
				"kick/kick/load.luau",
				"launch.luau",
				"bootstrap.luau",
				"run.luau",
				"autoexec/load.luau",
				"autoexec/launch.luau",
				"autoexec/bootstrap.luau",
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
	else
		expectedVersion = expected[entry.expectedKey]
	end

	if type(expectedVersion) ~= "string" or expectedVersion == "" then
		return false
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
	if src:find('local LOADER_VERSION = "' .. LOADER_VERSION .. '"', 1, true) then
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

	for _, root in ipairs({ "", ".", "workspace", "scripts" }) do
		walk(root, 0)
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
	if ENV.Alleral_State and type(ENV.Alleral_State.Alleral_Unload) == "function" then
		pcall(ENV.Alleral_State.Alleral_Unload)
	end
	ENV.Alleral_LoaderRunning = false
end

local function installAutoexecRedirect()
	if type(writeFileFn) ~= "function" then
		return
	end
	local stub = table.concat({
		"local g = getgenv()",
		"if g.Alleral_AutoRelaunch == false then return end",
		"if not g._Alleral_SessionWasActive and not g._Alleral_PendingRelaunch then return end",
		"local placeOk = g._Alleral_LastPlaceId == game.PlaceId",
		"if type(g._Alleral_SupportedPlaces) == 'table' and g._Alleral_SupportedPlaces[game.PlaceId] then placeOk = true end",
		"if not placeOk and not g._Alleral_PendingRelaunch then return end",
		"if type(g._Alleral_RunLoader) == 'function' then g._Alleral_RunLoader('autoexec') end",
		"",
	}, "\n")
	for _, dir in ipairs({ "autoexec", "Autoexec" }) do
		if makeFolderFn then
			pcall(makeFolderFn, dir)
		end
		pcall(writeFileFn, dir .. "/alleral.luau", stub)
	end
	log("Wrote autoexec/alleral.luau (local-first relaunch)")
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

local function purgeOutdatedWorkspace()
	if not isFile or not readFile then
		return
	end

	local expected = fetchExpectedVersions()
	local installedManifest = readInstalledManifest()
	local removed = 0

	for _, entry in ipairs(buildManagedFiles()) do
		for _, root in ipairs(WORKSPACE_ROOTS) do
			for _, path in ipairs(entry.paths) do
				local fullPath = root .. path
				local okExists, exists = pcall(isFile, fullPath)
				if okExists and exists then
					local okRead, src = pcall(readFile, fullPath)
					if shouldDeleteCachedFile(okRead and src or nil, entry, expected, installedManifest) then
						if deleteWorkspaceFile(fullPath) then
							removed += 1
						end
					end
				end
			end
		end
	end

	if removed > 0 then
		log("Workspace cleanup: removed " .. tostring(removed) .. " outdated file(s)")
	end

	ENV._Alleral_ExpectedVersions = expected
end

local function recordInstalledVersions()
	local expected = ENV._Alleral_ExpectedVersions
	if type(expected) == "table" then
		writeInstalledManifest(expected)
	end
end

local TELEPORT_RELAUNCH_COOLDOWN = 5

local function markSupportedPlaces()
	local places = {}
	for _, profile in ipairs(GAMES) do
		for _, placeId in ipairs(profile.placeIds or {}) do
			places[placeId] = true
		end
	end
	ENV._Alleral_SupportedPlaces = places
end

local function installGlobalBootstrap()
	if ENV._Alleral_BootstrapInstalled then
		return
	end
	ENV._Alleral_BootstrapInstalled = true

	ENV._Alleral_RunLoader = function(reason)
		local g = getgenv()
		if g.Alleral_AutoRelaunch == false then
			return
		end
		g._Alleral_RunLoaderToken = (g._Alleral_RunLoaderToken or 0) + 1
		local token = g._Alleral_RunLoaderToken
		task.delay(0.75, function()
			if g._Alleral_RunLoaderToken ~= token then
				return
			end
			if g.Alleral_LoaderRunning then
				return
			end

			if g.Alleral_State and type(g.Alleral_State.Alleral_Unload) == "function" then
				pcall(g.Alleral_State.Alleral_Unload)
			end
			local prevCore = g.Alleral_Core
			if type(prevCore) == "table" and type(prevCore.releaseUiWindow) == "function" then
				pcall(prevCore.releaseUiWindow)
			end
			g.Alleral_LoaderRunning = false
			g._Alleral_TeleportWatchConnected = nil
			g._Alleral_RelaunchScheduledAt = nil
			g._Alleral_AutoUpdateRunning = false
			g._Alleral_AutoUpdateToken = nil
			if reason then
				g._Alleral_PendingRelaunch = true
			end

			local function pick(names)
				for _, name in ipairs(names) do
					local fn = g[name]
					if type(fn) ~= "function" and _G then
						fn = _G[name]
					end
					if type(fn) == "function" then
						return fn
					end
				end
				return nil
			end

			local readFileFn = pick({ "readfile", "ReadFile", "read_file" })
			local isFileFn = pick({ "isfile", "IsFile", "is_file" })
			local loadStringFn = pick({ "loadstring", "LoadString", "load" })

			for _, path in ipairs(LOADER_LOCAL_PATHS) do
				if isFileFn and readFileFn and isFileFn(path) then
					local ok, src = pcall(readFileFn, path)
					if ok and type(src) == "string" and #src > 500 and loadStringFn then
						local compiled, compileErr = loadStringFn(src, "Alleral/loader")
						if compiled then
							task.defer(compiled)
							return
						end
						warn("[Alleral] Local loader compile failed: " .. tostring(compileErr))
					end
				end
			end

			local url = GITHUB_RAW .. "/loader.luau?t=" .. tostring(tick())
			local src
			pcall(function()
				src = game:HttpGet(url, true)
			end)
			if type(src) ~= "string" or #src < 500 then
				pcall(function()
					src = game:HttpGet(url)
				end)
			end
			if type(src) == "string" and #src > 500 and loadStringFn then
				local compiled, compileErr = loadStringFn(src, "Alleral/loader")
				if compiled then
					local writeFileFn = pick({ "writefile", "WriteFile", "write_file" })
					local makeFolderFn = pick({ "makefolder", "MakeFolder", "make_folder" })
					if writeFileFn and makeFolderFn then
						pcall(makeFolderFn, "kick")
						pcall(writeFileFn, "loader.luau", src)
					end
					task.defer(compiled)
					return
				end
				warn("[Alleral] Remote loader compile failed: " .. tostring(compileErr))
			end
			warn("[Alleral] Could not relaunch loader after teleport")
		end)
	end

	pcall(function()
		local TeleportService = game:GetService("TeleportService")
		TeleportService.LocalPlayerArrivedFromTeleport:Connect(function()
			local g = getgenv()
			g._Alleral_PendingRelaunch = true
			task.delay(2.5, function()
				if type(g._Alleral_RunLoader) == "function" then
					g._Alleral_RunLoader("arrived-from-teleport")
				end
			end)
		end)
	end)
end

local function scheduleHubRelaunch(reason, delaySeconds)
	if ENV.Alleral_AutoRelaunch == false then
		return
	end
	delaySeconds = delaySeconds or 2
	local now = tick()
	if ENV._Alleral_RelaunchScheduledAt and (now - ENV._Alleral_RelaunchScheduledAt) < 1 then
		return
	end
	if ENV._Alleral_LastLoadAt and (now - ENV._Alleral_LastLoadAt) < TELEPORT_RELAUNCH_COOLDOWN then
		if ENV._Alleral_LastJobId and tostring(ENV._Alleral_LastJobId) == tostring(game.JobId) then
			return
		end
	end
	ENV._Alleral_RelaunchScheduledAt = now
	task.delay(delaySeconds, function()
		ENV._Alleral_RelaunchScheduledAt = nil
		if type(ENV._Alleral_RunLoader) == "function" then
			log("Teleport relaunch: " .. tostring(reason))
			notify("Alleral", "new server — reloading hub", 3)
			ENV._Alleral_RunLoader(reason)
		elseif type(ENV.Alleral_Reload) == "function" then
			ENV.Alleral_Reload()
		else
			log("Relaunch unavailable after teleport — re-run the loader", true)
		end
	end)
end

local function ensureAutoexecLoader()
	if ENV.Alleral_AutoRelaunch == false then
		return
	end
	if type(writeFileFn) ~= "function" then
		log("Teleport auto-relaunch works best with writefile (autoexec stub skipped)", true)
		return
	end
	installAutoexecRedirect()
end

local function wireTeleportRelaunch()
	if ENV.Alleral_AutoRelaunch == nil then
		ENV.Alleral_AutoRelaunch = true
	end
	installGlobalBootstrap()
	if ENV._Alleral_TeleportWatchConnected then
		return
	end
	ENV._Alleral_TeleportWatchConnected = true
	ENV._Alleral_SessionWasActive = true
	ENV._Alleral_LastPlaceId = game.PlaceId
	ENV._Alleral_LastJobId = game.JobId
	markSupportedPlaces()

	pcall(function()
		local Players = game:GetService("Players")
		local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

		LocalPlayer.OnTeleport:Connect(function(_teleportState, placeId)
			ENV._Alleral_PendingRelaunch = true
			ENV._Alleral_PendingPlaceId = placeId
			ENV._Alleral_TeleportAt = tick()
			log("Teleport detected — hub will reload when you arrive")
		end)

		LocalPlayer.CharacterAdded:Connect(function()
			local teleAt = ENV._Alleral_TeleportAt
			if type(teleAt) ~= "number" or (tick() - teleAt) > 60 then
				return
			end
			ENV._Alleral_TeleportAt = nil
			scheduleHubRelaunch("spawn-after-teleport", 2)
		end)
	end)
end

ENV._Alleral_EnsureTeleportWatch = wireTeleportRelaunch
ENV._Alleral_ScheduleRelaunch = scheduleHubRelaunch

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
	end

	if ENV._Alleral_PendingRelaunch then
		log("Continuing session after teleport")
		ENV._Alleral_PendingRelaunch = nil
	end

	if ENV.Alleral_AutoRelaunch == nil then
		ENV.Alleral_AutoRelaunch = true
	end

	installGlobalBootstrap()
	markSupportedPlaces()

	local expectedVersions = fetchExpectedVersions()
	ENV._Alleral_ExpectedVersions = expectedVersions
	if expectedVersions.minLoader and versionLt(LOADER_VERSION, expectedVersions.minLoader) then
		local msg = "Loader v"
			.. LOADER_VERSION
			.. " is below minimum v"
			.. tostring(expectedVersions.minLoader)
			.. ". Re-run the GitHub loadstring."
		notify("Alleral", msg, 10)
		log(msg, true)
		ENV.Alleral_LoaderRunning = false
		return
	end

	loadWeaoStack()
	pcall(function()
		syncWeaoConfig(true)
	end)

	if typeof(task) == "table" and type(task.spawn) == "function" then
		task.spawn(function()
			refreshWeaoProfile(EXECUTOR)
		end)
	end

	clearLegacySession()

	local legacyRemoved, autoexecHit, deletedPaths = purgeLegacyLoaders()
	if legacyRemoved > 0 then
		log("Removed " .. tostring(legacyRemoved) .. " legacy loader file(s)")
		if autoexecHit then
			installAutoexecRedirect()
		end
	else
		local remaining = scanLegacyLoaders()
		if #remaining > 0 then
			reportLegacyScan(remaining, deletedPaths)
			notify(
				"Alleral",
				"Old loader files found — check console or run getgenv().Alleral_ScanLegacy()",
				12
			)
		end
	end

	if type(PREVIOUS_LOADER_VERSION) == "string" and versionLt(PREVIOUS_LOADER_VERSION, "5.0") then
		log(
			"Old loader v"
				.. PREVIOUS_LOADER_VERSION
				.. " ran before this script — check Volt Saved Scripts / workspace files",
			true
		)
		notify("Alleral", "v3.x ran earlier. Check Saved Scripts tab and workspace loader.luau.", 15)
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
		if type(ENV.Alleral_Core.fetchScriptManifest) == "function" then
			pcall(ENV.Alleral_Core.fetchScriptManifest)
		end
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

	loadTelemetryConfig()
	loadSecurityConfig()
	loadAccessConfig()

	local uiBundle, uiErr, gameSrc, gameLabel
	local _ = runParallel({
		function()
			if ENV.Alleral_Core and type(ENV.Alleral_Core.preloadUi) == "function" then
				uiBundle, uiErr = ENV.Alleral_Core.preloadUi()
			elseif ENV.Alleral_Core and type(ENV.Alleral_Core.loadUi) == "function" then
				uiBundle, uiErr = ENV.Alleral_Core.loadUi()
			end
		end,
		function()
			gameSrc, gameLabel = fetchGameScript(profile)
		end,
		function()
			loadModule({ HUB .. "/analytics.luau" }, HUB .. "/analytics.luau", "Alleral_Analytics", "Alleral/analytics")
		end,
		function()
			loadModule({ HUB .. "/helpers.luau", "core/game_helpers.luau" }, HUB .. "/helpers.luau", "GameHelpers", "Alleral/helpers")
		end,
		function()
			loadModule({ HUB .. "/telemetry.luau", "core/telemetry.luau" }, HUB .. "/telemetry.luau", "Alleral_Telemetry", "Alleral/telemetry")
		end,
		function()
			loadModule({ HUB .. "/security.luau" }, HUB .. "/security.luau", "Alleral_Security", "Alleral/security")
		end,
		function()
			loadModule({ HUB .. "/access.luau", "core/access.luau" }, HUB .. "/access.luau", "Alleral_Access", "Alleral/access")
		end,
	})
	grantPublicAccess()

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

	if ENV.Alleral_Telemetry and ENV.Alleral_Telemetry.ReportInject then
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
	purgeOutdatedWorkspace()
	checkForRemoteUpdate(profile, true)
	startAutoUpdater(profile)
	ENV._Alleral_LastLoadAt = tick()
	ENV._Alleral_LastPlaceId = game.PlaceId
	ENV._Alleral_LastJobId = game.JobId
	ENV._Alleral_PendingRelaunch = nil
	ensureAutoexecLoader()
	wireTeleportRelaunch()
	notify("Alleral", profile.name .. " loaded", 4)
	log("ready (auto-relaunch on hop)")
end

ENV.Alleral_Reload = function()
	stopAutoUpdater()
	if type(ENV._Alleral_RunLoader) == "function" then
		ENV._Alleral_RunLoader("manual-reload")
		return
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
end

ENV.Alleral_LoaderInfo = function()
	return {
		version = LOADER_VERSION,
		capabilities = CAPABILITIES,
		executor = EXECUTOR,
		games = GAMES,
	}
end

ENV.Alleral_ScanLegacy = function()
	local hits = scanLegacyLoaders()
	print("[Alleral v" .. LOADER_VERSION .. "] Legacy scan (" .. tostring(#hits) .. " hit(s)):")
	for _, hit in ipairs(hits) do
		print("  - " .. hit.path .. " (v" .. hit.version .. ")")
	end
	if #hits == 0 then
		print("  (none — if you still see v3.x logs, it is a Saved Script or old one-liner, not a workspace file)")
	end
	return hits
end

ENV.Alleral_PurgeCache = function()
	purgeOutdatedWorkspace()
	checkForRemoteUpdate(ENV._Alleral_ActiveProfile, false)
	print("[Alleral v" .. LOADER_VERSION .. "] Workspace cache purge complete")
end

ENV.Alleral_CheckUpdate = function()
	local profile = ENV._Alleral_ActiveProfile
	if checkForRemoteUpdate(profile, false) then
		print("[Alleral v" .. LOADER_VERSION .. "] Update found — reloading")
		return true
	end
	print("[Alleral v" .. LOADER_VERSION .. "] Already up to date")
	return false
end

ENV.Alleral_SyncWeao = syncWeaoConfig
getgenv().Alleral_SyncWeao = syncWeaoConfig

print("=== Alleral " .. LOADER_VERSION .. " active ===")
print("[Alleral] v" .. LOADER_VERSION .. " | PlaceId " .. tostring(game.PlaceId) .. " | executor=" .. EXECUTOR.slug)

local ok, err = pcall(main)
if not ok then
	warn("[Alleral] " .. tostring(err))
	notify("Alleral", tostring(err), 10)
	ENV.Alleral_LoaderRunning = false
end