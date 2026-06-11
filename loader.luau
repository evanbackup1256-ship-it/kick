--[[
	Alleral Hub — one script.
	Detects game, fetches core + game script, runs.
]]

local LOADER_VERSION = "5.2.0"
local MIN_CORE = "1.18"
local REPO = "evanbackup1256-ship-it/kick"
local BRANCH = "main"
local RAW = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH
local GH_WEB = "https://github.com/" .. REPO .. "/raw/" .. BRANCH
local CDN = "https://cdn.jsdelivr.net/gh/" .. REPO .. "@" .. BRANCH

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

local WEAO_API_URLS = {
	"https://api.weao.xyz/api/status/exploits",
	"https://api.whatexpsare.online/api/status/exploits",
	"https://whatexpsare.online/api/status/exploits",
	"https://api.whatexploitsaretra.sh/api/status/exploits",
	"http://api.weao.xyz/api/status/exploits",
}

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
	for _, spec in ipairs({
		{ Url = url, Method = "GET", Headers = headers },
		{ url = url, method = "GET", headers = headers },
	}) do
		local ok, res = pcall(fn, spec)
		if ok then
			local body = extractResponseBody(res)
			if type(body) == "string" and #body > 0 then
				return body
			end
		end
	end
	return nil
end

local function bootstrapHttpGet(url, headers)
	headers = headers or {}
	local bust = url .. (url:find("?") and "&" or "?") .. "t=" .. tostring(tick())
	local sharedEnv = ENV.shared or (typeof(shared) == "table" and shared) or nil
	local solaraLib = sharedEnv and type(sharedEnv.solara) == "table" and sharedEnv.solara or nil

	local requestFns = {
		type(ENV.Volt) == "table" and ENV.Volt.request,
		type(ENV.syn) == "table" and ENV.syn.request,
		type(ENV.fluxus) == "table" and ENV.fluxus.request,
		solaraLib and solaraLib.request,
		type(ENV.Solara) == "table" and ENV.Solara.request,
		type(ENV.Xeno) == "table" and ENV.Xeno.request,
		type(ENV.Wave) == "table" and ENV.Wave.request,
		type(ENV.Electron) == "table" and ENV.Electron.request,
		type(ENV.Potassium) == "table" and ENV.Potassium.request,
		type(ENV.Velocity) == "table" and ENV.Velocity.request,
		type(ENV.Codex) == "table" and ENV.Codex.request,
		type(ENV.Hydrogen) == "table" and ENV.Hydrogen.request,
		type(ENV.delta) == "table" and ENV.delta.request,
		type(ENV.celery) == "table" and ENV.celery.request,
		ENV.request,
		ENV.http_request,
		ENV.Request,
	}

	for _, fn in ipairs(requestFns) do
		local body = requestVia(fn, bust, headers)
		if body then
			return body, "request"
		end
	end

	if type(game.HttpGet) == "function" then
		for _, fetchUrl in ipairs({ bust, url }) do
			local ok, body = pcall(game.HttpGet, game, fetchUrl, true)
			if type(body) == "string" and #body > 0 then
				return body, "httpget"
			end
			ok, body = pcall(game.HttpGet, game, fetchUrl)
			if type(body) == "string" and #body > 0 then
				return body, "httpget"
			end
		end
	end

	if HttpService and type(HttpService.GetAsync) == "function" then
		local ok, body = pcall(function()
			return HttpService:GetAsync(bust, true)
		end)
		if ok and type(body) == "string" and #body > 0 then
			return body, "httpservice"
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

local function fetchWeaoExploits()
	local cache = ENV.Alleral_WeaoCache
	if type(cache) == "table" and cache.fetchedAt and (tick() - cache.fetchedAt) < 300 and type(cache.data) == "table" then
		return cache.data, cache.source
	end

	local headers = {
		["User-Agent"] = "WEAO-3PService",
		["Accept"] = "application/json",
		["Cache-Control"] = "no-cache",
	}

	for _, apiUrl in ipairs(WEAO_API_URLS) do
		local body, via = bootstrapHttpGet(apiUrl, headers)
		local decoded = decodeJson(body)
		if decoded then
			ENV.Alleral_WeaoCache = { fetchedAt = tick(), data = decoded, source = apiUrl }
			return decoded, apiUrl .. (via and (" (" .. via .. ")") or "")
		end
	end

	if type(cache) == "table" and cache.data then
		return cache.data, cache.source
	end
	return nil
end

local function formatWeaoEntry(entry)
	if type(entry) ~= "table" then
		return nil
	end
	return {
		title = entry.title,
		version = entry.version,
		detected = entry.detected == true,
		updateStatus = entry.updateStatus ~= false,
		uncStatus = entry.uncStatus == true,
		platform = entry.platform,
		extype = entry.extype,
		free = entry.free == true,
		suncPercentage = tonumber(entry.suncPercentage),
		uncPercentage = tonumber(entry.uncPercentage),
	}
end

local function matchWeaoExploit(hints, exploits)
	if type(exploits) ~= "table" then
		return nil, 0
	end

	local keys = {}
	local function addKey(key, weight)
		key = normalizeSlug(key)
		if key ~= "" then
			keys[key] = math.max(keys[key] or 0, weight)
		end
	end

	addKey(hints.rawName, 90)
	addKey(hints.slug, 85)
	addKey(inferSlugFromText(hints.rawName), 88)
	for _, envSlug in ipairs(hints.envSlugs or {}) do
		addKey(envSlug, 75)
	end

	local best, bestScore = nil, 0
	for _, entry in ipairs(exploits) do
		if type(entry) == "table" and type(entry.title) == "string" then
			local titleKey = normalizeSlug(entry.title)
			local score = 0
			for key, weight in pairs(keys) do
				if titleKey == key then
					score = math.max(score, weight + 10)
				elseif titleKey:find(key, 1, true) or key:find(titleKey, 1, true) then
					score = math.max(score, weight - 10)
				end
			end
			if score > bestScore then
				bestScore = score
				best = entry
			end
		end
	end

	return bestScore >= 70 and best or nil, bestScore
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
	local exploits, weaoSource = fetchWeaoExploits()
	local weaoEntry, weaoScore = matchWeaoExploit(localProfile, exploits)
	local weao = formatWeaoEntry(weaoEntry)

	local profile = {
		slug = localProfile.slug,
		name = localProfile.name,
		rawName = localProfile.rawName,
		envSlugs = localProfile.envSlugs,
		weao = weao,
		weaoSource = weaoSource,
		weaoVerified = weao ~= nil,
	}

	if weao and weao.title then
		profile.slug = normalizeSlug(weao.title)
		if profile.slug == "synapse" and (localProfile.rawName:lower():find("z", 1, true) or normalizeSlug(localProfile.rawName) == "synapsez") then
			profile.slug = "synapsez"
		end
		profile.name = weao.title
		if weao.version and weao.version ~= "" then
			profile.name = weao.title .. " " .. weao.version
		end
		log(string.format(
			"Executor: %s (WEAO match %d%%, via %s)",
			profile.name,
			weaoScore,
			tostring(weaoSource or "cache")
		))
	elseif #localProfile.envSlugs > 0 then
		profile.slug = localProfile.envSlugs[1]
		profile.name = profile.slug:sub(1, 1):upper() .. profile.slug:sub(2)
		log("Executor: " .. profile.name .. " (env fingerprint, WEAO unavailable)", true)
	else
		log("Executor: " .. profile.name .. " (local detect, WEAO unavailable)", true)
	end

	return profile
end

local EXECUTOR = resolveExecutorProfile()

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
			return ENV.Volt and requestVia(ENV.Volt.request, url)
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
			return requestVia(ENV.request, url) or requestVia(ENV.http_request, url) or requestVia(ENV.Request, url)
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
	local bust = url .. (url:find("?") and "&" or "?") .. "t=" .. tostring(tick())

	local core = ENV.Alleral_Core
	if core and type(core.httpGet) == "function" then
		local body = core.httpGet(bust)
		if type(body) == "string" and #body >= minBytes then
			return body, "core"
		end
	end

	local bestBody, bestVia, bestLen = nil, nil, 0
	for _, transport in ipairs(HTTP_TRANSPORTS) do
		local body = transport.fetch(bust)
		if type(body) == "string" and #body >= minBytes and #body > bestLen then
			bestBody, bestVia, bestLen = body, transport.id, #body
		end
	end
	return bestBody, bestVia
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
	local roots = { "", "kick/", "kick/kick/", "workspace/" }
	for _, root in ipairs(roots) do
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
	for _, base in ipairs({ RAW, GH_WEB, CDN }) do
		local body, via = httpGet(base .. "/" .. relativePath, minBytes)
		if body and looksLikeLua(body) and not body:find("404: Not Found", 1, true) then
			local label = base
			if via then
				label = label .. " via " .. via
			end
			return body, label
		end
	end
	return nil
end

local function cacheRemote(relativePath, src)
	local writeFile = firstExecFunc("writefile")
	local makeFolder = firstExecFunc("makefolder")
	if type(writeFile) ~= "function" then
		return
	end
	local dir = relativePath:match("^(.+)/[^/]+$")
	if dir and makeFolder then
		pcall(makeFolder, dir)
	end
	pcall(writeFile, relativePath, src)
end

local function getSource(localPaths, remotePath, opts)
	opts = type(opts) == "table" and opts or { marker = opts }
	local minBytes = opts.minBytes or 0
	local marker = opts.marker

	local src, path = readLocal(localPaths, minBytes)
	if src then
		if marker and not src:find(marker, 1, true) then
			log("Skipping outdated local " .. path, true)
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

	return nil, "Could not load " .. remotePath
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

	local src, label = getSource(
		{ "core/alleral_core.luau", "alleral_core.luau" },
		"core/alleral_core.luau",
		{ minBytes = 5000 }
	)
	if not src or not coreValid(src) then
		return false, label or "Core download failed"
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

	if not loadStringFn then
		notify("Alleral", "This executor needs loadstring.", 8)
		ENV.Alleral_LoaderRunning = false
		return
	end

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

print("[Alleral] v" .. LOADER_VERSION .. " | PlaceId " .. tostring(game.PlaceId) .. " | executor=" .. EXECUTOR.slug)

local ok, err = pcall(main)
if not ok then
	warn("[Alleral] " .. tostring(err))
	notify("Alleral", tostring(err), 10)
	ENV.Alleral_LoaderRunning = false
end
