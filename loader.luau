--[[
	Alleral Hub — single entry point (loader.luau only).
	Fetch from CDN; do not use launch/load/bootstrap/run scripts.
]]

local LOADER_VERSION = "5.4.2"
local MIN_CORE = "1.18"
local RELEASE_FALLBACK = {
	core = "1.19",
	analytics = "1.0",
	telemetry = "2.2",
	helpers = "1.0",
	weao = "1.0",
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
local RAW = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH
local GH_WEB = "https://github.com/" .. REPO .. "/raw/" .. BRANCH
local CDN = "https://cdn.jsdelivr.net/gh/" .. REPO .. "@" .. BRANCH
local CDN_PIN = CDN

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

	local exploits, weaoSource = Weao.fetchExploits({
		httpFetch = weaoHttpFetch,
		requestFn = getHttpRequestFn(),
		config = ENV.Alleral_WeaoConfig,
		executorSlug = profile.slug,
	})
	if not exploits then
		return profile
	end

	local weaoEntry, weaoScore = Weao.matchExploit(profile, exploits)
	local weao = Weao.formatEntry(weaoEntry)
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
		log(string.format("WEAO: %s (match %d%%)", profile.name, weaoScore))
	end
	return profile
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

	if ENV.Alleral_Core and type(ENV.Alleral_Core.httpGet) == "function" then
		local body = ENV.Alleral_Core.httpGet(url)
		if type(body) == "string" and #body >= minBytes then
			return body, "core"
		end
	end

	local bestBody, bestVia, bestLen = nil, nil, 0
	local function consider(body, via)
		if type(body) == "string" and #body > bestLen then
			bestBody, bestVia, bestLen = body, via, #body
		end
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
	for _, base in ipairs({ CDN_PIN, CDN, RAW, GH_WEB }) do
		local body, via = httpGet(base .. "/" .. relativePath, minBytes)
		if body and looksLikeLua(body) and not body:find("404: Not Found", 1, true) then
			local label = base .. (via and (" via " .. via) or "")
			return body, label
		end
		lastErr = via or "invalid response"
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

local function getSource(localPaths, remotePath, opts)
	opts = type(opts) == "table" and opts or { marker = opts }
	local minBytes = opts.minBytes or 0
	local marker = opts.marker

	local src, path = readLocal(localPaths, minBytes)
	if src then
		if marker and not src:find(marker, 1, true) then
			log("Skipping outdated local " .. path, true)
			deleteWorkspaceFile(path)
		else
			return src, "local:" .. path
		end
	end

	src, path = fetchRemote(remotePath, minBytes)
	if src then
		if marker and not src:find(marker, 1, true) then
			log("Script may be outdated (missing " .. marker .. ")", true)
		end
		cacheRemote(remotePath, src)
		return src, "remote" .. (path and (" (" .. path .. ")") or "")
	end

	return nil, path or ("Could not load " .. remotePath)
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

local function coreVersionOk(v)
	return type(v) == "string" and v >= MIN_CORE
end

local function coreValid(src)
	if type(src) ~= "string" or #src < 5000 or not src:find("loadRayfield", 1, true) then
		return false
	end
	local ver = src:match('Core%.VERSION%s*=%s*"([%d%.]+)"')
	if not coreVersionOk(ver) then
		return false
	end
	if src:find("fakeUiInstance", 1, true) and not src:find("AlleralGroupShell", 1, true) then
		return false
	end
	if not loadStringFn then
		return true
	end
	local fn = loadStringFn(src, "Alleral/core-check")
	return type(fn) == "function"
end

local function loadCore()
	if ENV.Alleral_Core and type(ENV.Alleral_Core.loadRayfield) == "function" and coreVersionOk(ENV.Alleral_Core.VERSION) then
		return true
	end
	ENV.Alleral_Core = nil

	local src, label = readLocal({ "core/alleral_core.luau", "alleral_core.luau" }, 5000)
	if src and not coreValid(src) then
		log("Removing broken/outdated core at " .. tostring(label), true)
		deleteWorkspaceFile(label)
		src = nil
	end
	if src and coreValid(src) then
		label = "local:" .. label
	else
		src, label = nil, nil
		local lastErr = nil
		for _, base in ipairs({ CDN_PIN, CDN, RAW }) do
			local url = base .. "/core/alleral_core.luau"
			local body, via = httpGet(url, 0)
			if body and coreValid(body) then
				src = body
				label = url .. (via and (" via " .. via) or "")
				cacheRemote("core/alleral_core.luau", body)
				break
			end
			lastErr = via
		end
		if not src then
			return false, lastErr or "Core download failed"
		end
	end

	local ok, err = compileAndRun(src, "Alleral/core")
	if not ok then
		ENV.Alleral_Core = nil
		return false, err
	end
	if not ENV.Alleral_Core or type(ENV.Alleral_Core.loadRayfield) ~= "function" then
		return false, "Core did not initialize"
	end
	log("Core v" .. tostring(ENV.Alleral_Core.VERSION) .. " from " .. label)
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
	local cfgBody = httpFetch(CDN .. "/config/weao.json", { ["Accept"] = "application/json" })
	local cfg = decodeJson(cfgBody)
	if cfg then
		ENV.Alleral_WeaoConfig = cfg
	end

	if ENV.Alleral_Weao and type(ENV.Alleral_Weao.fetchExploits) == "function" then
		return true
	end

	if loadModule({ "core/weao.luau" }, "core/weao.luau", "Alleral_Weao", "Alleral/weao") then
		return ENV.Alleral_Weao ~= nil
	end

	log("WEAO module unavailable", true)
	return false
end

local ENV_BRIDGE = [=[
do
	local bridge = shared
	if type(bridge) == "table" and getgenv then
		local g = getgenv()
		if type(g) == "table" then
			if bridge.Alleral_Rayfield then g.Alleral_Rayfield = bridge.Alleral_Rayfield; g.Alleral_UI = bridge.Alleral_Rayfield end
			if bridge.Alleral_Core then g.Alleral_Core = bridge.Alleral_Core end
			if bridge.Alleral_Analytics then g.Alleral_Analytics = bridge.Alleral_Analytics end
			if bridge.Alleral_Telemetry then g.Alleral_Telemetry = bridge.Alleral_Telemetry end
			if bridge.Alleral_Weao then g.Alleral_Weao = bridge.Alleral_Weao end
			if bridge.Alleral_WeaoConfig then g.Alleral_WeaoConfig = bridge.Alleral_WeaoConfig end
			g.Alleral_State = g.Alleral_State or bridge.Alleral_State or {}
			bridge.Alleral_State = g.Alleral_State
		end
	end
end
]=]

local function publishBridge()
	pcall(function()
		shared.Alleral_Rayfield = ENV.Alleral_Rayfield
		shared.Alleral_UI = ENV.Alleral_UI
		shared.Alleral_Core = ENV.Alleral_Core
		shared.Alleral_Analytics = ENV.Alleral_Analytics
		shared.Alleral_Telemetry = ENV.Alleral_Telemetry
		shared.Alleral_Weao = ENV.Alleral_Weao
		shared.Alleral_WeaoConfig = ENV.Alleral_WeaoConfig
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
	-- Keep versions in sync with config/scripts_manifest.json
	{
		id = "kick_a_lucky_block",
		name = "Kick a Lucky Block",
		version = "6.6",
		placeIds = { 89469502395769 },
		universeIds = { 10004244222 },
		scriptFiles = { "games/kick_a_lucky_block.luau", "kick_a_lucky_block.luau" },
		scriptUrl = "games/kick_a_lucky_block.luau",
		sourceMarker = "Alleral_Rayfield",
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
		version = "1.2",
		placeIds = { 95082159892680 },
		scriptFiles = { "games/speed_keyboard_escape.luau", "speed_keyboard_escape.luau" },
		scriptUrl = "games/speed_keyboard_escape.luau",
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
		version = "1.2",
		placeIds = { 92416421522960 },
		universeIds = { 9792947201 },
		scriptFiles = { "games/slime_rng.luau", "slime_rng.luau" },
		scriptUrl = "games/slime_rng.luau",
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
		version = "1.2",
		placeIds = { 107646426076756 },
		scriptFiles = { "games/build_a_ring_farm.luau", "build_a_ring_farm.luau" },
		scriptUrl = "games/build_a_ring_farm.luau",
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
		version = "2.1",
		placeIds = { 114204398207377 },
		scriptFiles = { "games/survive_a_zombie_arena.luau", "survive_a_zombie_arena.luau" },
		scriptUrl = "games/survive_a_zombie_arena.luau",
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
	loader = 'LOADER_VERSION%s*=%s*"([%d%.]+)"',
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

local function fetchExpectedVersions()
	local expected = {
		loader = LOADER_VERSION,
		core = RELEASE_FALLBACK.core,
		analytics = RELEASE_FALLBACK.analytics,
		telemetry = RELEASE_FALLBACK.telemetry,
		helpers = RELEASE_FALLBACK.helpers,
		weao = RELEASE_FALLBACK.weao,
		games = {},
	}
	for _, gameProfile in ipairs(GAMES) do
		expected.games[gameProfile.id] = gameProfile.version
	end

	local release = decodeJson(select(1, httpFetch(CDN .. "/config/release.json")))
	if release then
		expected.loader = release.loader or expected.loader
		expected.core = release.core or expected.core
		expected.analytics = release.analytics or expected.analytics
		expected.telemetry = release.telemetry or expected.telemetry
		expected.helpers = release.helpers or expected.helpers
		expected.weao = release.weao or expected.weao
	end

	local weaoCfg = decodeJson(select(1, httpFetch(CDN .. "/config/weao.json")))
	if weaoCfg then
		ENV._Alleral_WeaoConfigRemote = weaoCfg
	end

	local manifest = decodeJson(select(1, httpFetch(CDN .. "/config/scripts_manifest.json")))
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

	return expected
end

local function buildManagedFiles()
	local managed = {
		{
			paths = { "core/alleral_core.luau", "alleral_core.luau" },
			expectedKey = "core",
			extract = "core",
			isValid = coreValid,
		},
		{
			paths = { "core/analytics.luau" },
			expectedKey = "analytics",
			extract = "analytics",
		},
		{
			paths = { "core/telemetry.luau" },
			expectedKey = "telemetry",
			extract = "telemetry",
		},
		{
			paths = { "core/game_helpers.luau" },
			expectedKey = "helpers",
			extract = "helpers",
		},
		{
			paths = { "core/weao.luau" },
			expectedKey = "weao",
			extract = "weao",
		},
		{
			paths = { "config/weao.json" },
			purgeOnLoaderChange = true,
		},
		{
			paths = { "config/owner_telemetry.luau" },
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

	if entry.isValid and not entry.isValid(src) then
		return true
	end

	local foundVersion = extractFileVersion(src, entry.extract)
	if not foundVersion then
		return true
	end

	return foundVersion ~= expectedVersion
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
	if ver and ver < "5.0" then
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
	local stub = 'loadstring(game:HttpGet("'
		.. CDN
		.. '/loader.luau?t=" .. tick()))()\n'
	for _, dir in ipairs({ "autoexec", "Autoexec" }) do
		if makeFolderFn then
			pcall(makeFolderFn, dir)
		end
		pcall(writeFileFn, dir .. "/alleral.luau", stub)
	end
	log("Wrote autoexec/alleral.luau → current loader")
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

	loadWeaoStack()

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

	if type(PREVIOUS_LOADER_VERSION) == "string" and PREVIOUS_LOADER_VERSION < "5.0" then
		log(
			"Old loader v"
				.. PREVIOUS_LOADER_VERSION
				.. " ran before this script — check Volt Saved Scripts / workspace files",
			true
		)
		notify("Alleral", "v3.x ran earlier. Check Saved Scripts tab and workspace loader.luau.", 15)
	end

	purgeOutdatedWorkspace()

	ENV.Alleral_Core = nil
	ENV.Alleral_Rayfield = nil
	ENV.Alleral_UI = nil
	ENV.Alleral_StartupFailed = nil
	ENV.Alleral_ScriptManifestUrl = CDN .. "/config/scripts_manifest.json"

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

	loadModule({ "core/analytics.luau" }, "core/analytics.luau", "Alleral_Analytics", "Alleral/analytics")
	loadModule({ "core/game_helpers.luau" }, "core/game_helpers.luau", "GameHelpers", "Alleral/helpers")
	loadModule({ "config/owner_telemetry.luau" }, "config/owner_telemetry.luau", nil, "Alleral/owner-telemetry")
	loadModule({ "core/telemetry.luau" }, "core/telemetry.luau", "Alleral_Telemetry", "Alleral/telemetry")

	if ENV.Alleral_Core and type(ENV.Alleral_Core.loadRayfield) == "function" then
		local ui, uiErr = ENV.Alleral_Core.loadRayfield()
		if ui then
			ENV.Alleral_Rayfield = ui
			ENV.Alleral_UI = ui
			log("Rayfield ready")
		else
			log("Rayfield skipped: " .. tostring(uiErr), true)
		end
	end

	local src, label = getSource(profile.scriptFiles, profile.scriptUrl, {
		marker = profile.sourceMarker,
		minBytes = 40000,
	})
	if not src then
		notify("Alleral", "Game script failed: " .. tostring(label), 8)
		log("Game script failed: " .. tostring(label), true)
		ENV.Alleral_LoaderRunning = false
		return
	end

	log("Loading " .. profile.name .. " v" .. profile.version .. " from " .. label)
	publishBridge()
	ENV.Alleral_LoaderMeta = { version = LOADER_VERSION, profile = profile.id, source = label }
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
		return
	end

	recordInstalledVersions()
	notify("Alleral", profile.name .. " loaded.", 4)
	log("Ready")
end

ENV.Alleral_Reload = function()
	if ENV.Alleral_State and type(ENV.Alleral_State.Alleral_Unload) == "function" then
		pcall(ENV.Alleral_State.Alleral_Unload)
	end
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

print("=== Alleral loader " .. LOADER_VERSION .. " active ===")
print("[Alleral] v" .. LOADER_VERSION .. " | PlaceId " .. tostring(game.PlaceId) .. " | executor=" .. EXECUTOR.slug)

local ok, err = pcall(main)
if not ok then
	warn("[Alleral] " .. tostring(err))
	notify("Alleral", tostring(err), 10)
	ENV.Alleral_LoaderRunning = false
end
