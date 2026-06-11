--[[
	Alleral Hub — single entry point.
	Detects game.PlaceId, loads core + matching games/*.luau script.
]]
local LOADER_VERSION = "3.8.3"
local REQUIRED_CORE_VERSION = "1.17"
local REQUIRED_UI_LIBRARY = "Rayfield"
local GITHUB_REPO = "evanbackup1256-ship-it/kick"
local REPO_BRANCH = "main"
local REPO_BASE = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. REPO_BRANCH
local JSDELIVR_BASE = "https://cdn.jsdelivr.net/gh/" .. GITHUB_REPO .. "@" .. REPO_BRANCH
local GITHUB_WEB_RAW = "https://github.com/" .. GITHUB_REPO .. "/raw/" .. REPO_BRANCH
local SCRIPT_MANIFEST_PATH = "config/scripts_manifest.json"
local SCRIPT_MANIFEST_URL = JSDELIVR_BASE .. "/" .. SCRIPT_MANIFEST_PATH
local FETCH_RETRIES = 2
local FETCH_BACKOFF = 0.35
local MIN_SCRIPT_BYTES = 1000
local PINNED_COMMITS = {
	"55d3f68",
	"6a1b22c",
}

local SHARED_CORE_FILES = {
	"core/alleral_core.luau",
	"src/alleral_core.luau",
	"alleral_core.luau",
}
local SHARED_ANALYTICS_FILES = {
	"core/analytics.luau",
	"src/analytics.luau",
	"analytics.luau",
}
local SHARED_TELEMETRY_FILES = {
	"core/telemetry.luau",
	"src/telemetry.luau",
	"telemetry.luau",
}
local SHARED_HELPERS_FILES = {
	"core/game_helpers.luau",
	"src/game_helpers.luau",
	"game_helpers.luau",
}
local DEFAULT_TELEMETRY_RELAY = "https://alleral-telemetry-production.up.railway.app/ingest"

local OWNER_TELEMETRY_FILES = {
	"../Alleral-Private/owner_telemetry.luau",
	"Alleral-Private/owner_telemetry.luau",
	"kick/Alleral-Private/owner_telemetry.luau",
	"kick/../Alleral-Private/owner_telemetry.luau",
	"config/owner_telemetry.luau",
	"kick/kick/config/owner_telemetry.luau",
	"../../Alleral-Private/owner_telemetry.luau",
	"kick/kick/../Alleral-Private/owner_telemetry.luau",
	"workspace/Alleral-Private/owner_telemetry.luau",
	"workspace/../Alleral-Private/owner_telemetry.luau",
	"owner_telemetry.luau",
}
local OWNER_TELEMETRY_ENV_FILES = {
	"backend/.env",
	"kick/kick/backend/.env",
	"../backend/.env",
	"config/telemetry.env",
}
local TELEMETRY_MODULE_VERSION = "2.2"
local SHARED_CORE_PATH = "core/alleral_core.luau"
local SHARED_ANALYTICS_PATH = "core/analytics.luau"
local SHARED_TELEMETRY_PATH = "core/telemetry.luau"
local SHARED_HELPERS_PATH = "core/game_helpers.luau"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = nil
pcall(function()
	HttpService = game:GetService("HttpService")
end)
local Workspace = game:GetService("Workspace")

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()

local function safeTime()
	if type(os) == "table" and type(os.time) == "function" then
		local ok, value = pcall(os.time)
		if ok and type(value) == "number" then
			return value
		end
	end
	return typeof(tick) == "function" and tick() or 0
end

local function safeWait(seconds)
	if typeof(task) == "table" and type(task.wait) == "function" then
		task.wait(seconds)
	elseif type(wait) == "function" then
		wait(seconds)
	end
end

local function firstExecFunc(...)
	for i = 1, select("#", ...) do
		local name = select(i, ...)
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

local function resolveHttpRequest()
	local sharedEnv = ENV.shared or (typeof(shared) == "table" and shared) or nil
	local solaraLib = sharedEnv and type(sharedEnv.solara) == "table" and sharedEnv.solara or nil
	local soloraLib = sharedEnv and type(sharedEnv.Solora) == "table" and sharedEnv.Solora or nil
	local candidates = {
		solaraLib and solaraLib.request,
		soloraLib and soloraLib.request,
		type(ENV.Solara) == "table" and ENV.Solara.request or nil,
		type(ENV.Solora) == "table" and ENV.Solora.request or nil,
		type(ENV.Volt) == "table" and ENV.Volt.request or nil,
		type(ENV.Wave) == "table" and ENV.Wave.request or nil,
		type(ENV.Xeno) == "table" and ENV.Xeno.request or nil,
		type(ENV.Krnl) == "table" and ENV.Krnl.request or nil,
		type(ENV.syn) == "table" and ENV.syn.request or nil,
		type(ENV.fluxus) == "table" and ENV.fluxus.request or nil,
		type(ENV.http) == "table" and ENV.http.request or nil,
		type(ENV.http_service) == "table" and ENV.http_service.request or nil,
		type(ENV.Electron) == "table" and ENV.Electron.request or nil,
		type(ENV.Potassium) == "table" and ENV.Potassium.request or nil,
		type(ENV.Velocity) == "table" and ENV.Velocity.request or nil,
		type(ENV.delta) == "table" and ENV.delta.request or nil,
		type(ENV.Codex) == "table" and ENV.Codex.request or nil,
		type(ENV.Hydrogen) == "table" and ENV.Hydrogen.request or nil,
		ENV.request,
		ENV.Request,
		firstExecFunc("http_request", "request", "Request", "httprequest"),
	}
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "function" then
			return candidate
		end
	end
	if HttpService and type(HttpService.RequestAsync) == "function" then
		return function(opts)
			return HttpService:RequestAsync({
				Url = opts.Url or opts.url,
				Method = opts.Method or opts.method or "GET",
				Headers = opts.Headers or opts.headers,
				Body = opts.Body or opts.body,
			})
		end
	end
	return nil
end

local function resolveLoadString()
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
	return firstExecFunc("loadstring", "LoadString", "load", "Load", "compile")
end

local httpRequest = resolveHttpRequest()
local readFile = firstExecFunc("readfile", "read_file", "ReadFile")
local isFile = firstExecFunc("isfile", "is_file", "IsFile")
local loadStringFn = resolveLoadString()

local function hasHttp()
	if type(game.HttpGet) == "function" then
		return true
	end
	if httpRequest then
		return true
	end
	if HttpService and type(HttpService.GetAsync) == "function" then
		return true
	end
	return false
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

local function trim(value)
	return tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function log(level, message)
	local prefix = string.format("[Alleral Loader v%s]", LOADER_VERSION)
	if level == "warn" then
		warn(prefix .. " " .. message)
	else
		print(prefix .. " " .. message)
	end
end

local function detectExecutor()
	for _, id in ipairs({
		"identifyexecutor",
		"getexecutorname",
		"whatexecutor",
		"getexecutor",
	}) do
		local fn = firstExecFunc(id)
		if fn then
			local ok, name = pcall(fn)
			if ok and type(name) == "string" and name ~= "" then
				return name
			end
		end
	end
	if ENV.syn then
		return "Synapse"
	end
	if ENV.KRNL_LOADED then
		return "Krnl"
	end
	return "Unknown"
end

local CAPABILITIES = {
	executor = detectExecutor(),
	http = hasHttp(),
	loadstring = loadStringFn ~= nil,
	readfile = readFile ~= nil,
	isfile = isFile ~= nil,
	listfiles = firstExecFunc("listfiles", "list_files", "ListFiles") ~= nil,
}

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

local function placeIdMatches(profile, placeId)
	for _, id in ipairs(profile.placeIds or {}) do
		if id == placeId then
			return true
		end
	end
	return false
end

local function universeIdMatches(profile, universeId)
	for _, id in ipairs(profile.universeIds or {}) do
		if id == universeId then
			return true
		end
	end
	return false
end

local GAMES = {
	{
		id = "kick_a_lucky_block",
		name = "Kick a Lucky Block",
		version = "6.6",
		needsCore = true,
		placeIds = { 89469502395769 },
		universeIds = { 10004244222 },
		scriptFiles = {
			"games/kick_a_lucky_block.luau",
			"src/kick_a_lucky_block.luau",
			"kick_a_lucky_block.luau",
			"kick a lucky block.luau",
		},
		scriptUrl = "games/kick_a_lucky_block.luau",
		sourceMarker = "Alleral_Rayfield",
		preload = function()
			waitForPath(ReplicatedStorage, { "Shared" }, 20)
			local areas = Workspace:WaitForChild("Areas", 20)
			if not areas or not areas:WaitForChild("KickReady", 10) then
				return false, "KickReady pad not found, are you in the main world?"
			end
			return true
		end,
		validate = function()
			local shared = ReplicatedStorage:FindFirstChild("Shared")
			local network = shared
				and shared:FindFirstChild("Packages")
				and shared.Packages:FindFirstChild("Network")
			local kickReady = Workspace:FindFirstChild("Areas")
				and Workspace.Areas:FindFirstChild("KickReady")
			return network ~= nil and kickReady ~= nil
		end,
	},
	{
		id = "speed_keyboard_escape",
		name = "Speed Keyboard Escape",
		version = "1.2",
		needsCore = true,
		placeIds = { 95082159892680 },
		scriptFiles = {
			"games/speed_keyboard_escape.luau",
			"src/speed_keyboard_escape.luau",
			"speed_keyboard_escape.luau",
		},
		scriptUrl = "games/speed_keyboard_escape.luau",
		preload = function()
			waitForPath(ReplicatedStorage, { "Remotes" }, 20)
			return true
		end,
		validate = function()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			return remotes ~= nil
				and remotes:FindFirstChild("UpdateSpeed") ~= nil
				and ReplicatedStorage:FindFirstChild("ClientState") ~= nil
		end,
	},
	{
		id = "slime_rng",
		name = "Slime RNG",
		version = "1.2",
		needsCore = true,
		placeIds = { 92416421522960 },
		universeIds = { 9792947201 },
		scriptFiles = {
			"games/slime_rng.luau",
			"src/slime_rng.luau",
			"slime_rng.luau",
		},
		scriptUrl = "games/slime_rng.luau",
		preload = function()
			waitForPath(ReplicatedStorage, { "Packages", "DataService" }, 25)
			return true
		end,
		validate = function()
			local packages = ReplicatedStorage:FindFirstChild("Packages")
			return packages ~= nil
				and packages:FindFirstChild("DataService") ~= nil
				and ReplicatedStorage:FindFirstChild("Source") ~= nil
		end,
	},
	{
		id = "build_a_ring_farm",
		name = "Build A Ring Farm",
		version = "1.2",
		needsCore = true,
		placeIds = { 107646426076756 },
		scriptFiles = {
			"games/build_a_ring_farm.luau",
			"src/build_a_ring_farm.luau",
			"build_a_ring_farm.luau",
		},
		scriptUrl = REPO_BASE .. "/games/build_a_ring_farm.luau",
		preload = function()
			waitForPath(ReplicatedStorage, { "Shared" }, 20)
			waitForPath(ReplicatedStorage, { "Remotes", "PlantSeed" }, 15)
			return true
		end,
		validate = function()
			local shared = ReplicatedStorage:FindFirstChild("Shared")
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			return shared ~= nil
				and remotes ~= nil
				and remotes:FindFirstChild("PlantSeed") ~= nil
				and remotes:FindFirstChild("Plot") ~= nil
		end,
	},
	{
		id = "survive_a_zombie_arena",
		name = "Survive a Zombie Arena",
		version = "2.1",
		needsCore = true,
		placeIds = { 114204398207377 },
		scriptFiles = {
			"games/survive_a_zombie_arena.luau",
			"src/survive_a_zombie_arena.luau",
			"survive_a_zombie_arena.luau",
		},
		scriptUrl = "games/survive_a_zombie_arena.luau",
		preload = function()
			waitForPath(ReplicatedStorage, { "ZombieRemotes", "ZombieDamage" }, 20)
			waitForPath(ReplicatedStorage, { "WaveRemotes", "SkipVote" }, 15)
			return true
		end,
		validate = function()
			local zombieRemotes = ReplicatedStorage:FindFirstChild("ZombieRemotes")
			local waveRemotes = ReplicatedStorage:FindFirstChild("WaveRemotes")
			return zombieRemotes ~= nil
				and zombieRemotes:FindFirstChild("ZombieDamage") ~= nil
				and waveRemotes ~= nil
				and waveRemotes:FindFirstChild("SkipVote") ~= nil
		end,
	},
}

local function resolveUniverseId()
	local ok, id = pcall(function()
		return game.GameId
	end)
	if ok and type(id) == "number" and id > 0 then
		return id
	end
	return nil
end

local function scoreProfile(profile, placeId, universeId)
	local score = 0
	if placeIdMatches(profile, placeId) then
		score = score + 100
	end
	if universeId and universeIdMatches(profile, universeId) then
		score = score + 50
	end
	if profile.validate and profile.validate() then
		score = score + 25
	end
	return score
end

local function detectGame()
	local placeId = game.PlaceId
	local universeId = resolveUniverseId()
	local bestProfile, bestScore = nil, 0

	for _, profile in ipairs(GAMES) do
		local score = scoreProfile(profile, placeId, universeId)
		if score > bestScore then
			bestScore = score
			bestProfile = profile
		end
	end

	if not bestProfile or bestScore < 25 then
		return nil, string.format("No supported game detected (PlaceId %s).", tostring(placeId))
	end

	if bestScore < 100 and not (bestProfile.validate and bestProfile.validate()) then
		return nil, string.format("%s markers not found in this server.", bestProfile.name)
	end

	return bestProfile
end

local function readLocalFile(path)
	if not readFile or not isFile then
		return nil
	end
	local okExists, exists = pcall(isFile, path)
	if not okExists or not exists then
		return nil
	end
	local okRead, source = pcall(readFile, path)
	if okRead and type(source) == "string" and source ~= "" then
		return source
	end
	return nil
end

local function discoverLocalFiles(fileNames)
	local found = {}
	if not readFile then
		return found
	end
	local roots = {
		"",
		"kick/",
		"kick/kick/",
		"Alleral Hub/",
		"kick/Alleral Hub/",
		"workspace/",
		"scripts/",
	}
	for _, root in ipairs(roots) do
		for _, name in ipairs(fileNames) do
			local path = root .. name
			local source = readLocalFile(path)
			if source then
				table.insert(found, { path = path, source = source })
			end
		end
	end
	return found
end

local function telemetrySourceMarker()
	return 'Telemetry.Version = "' .. TELEMETRY_MODULE_VERSION .. '"'
end

local function coreBodyValid(body)
	if type(body) ~= "string" or #body < MIN_SCRIPT_BYTES then
		return false
	end
	if not body:find("loadRayfield", 1, true) then
		return false
	end
	local version = body:match('Core%.VERSION%s*=%s*"([%d%.]+)"')
		or body:match("Core%.VERSION%s*=%s*'([%d%.]+)'")
	return version == REQUIRED_CORE_VERSION
end

local function coreSourceMarker()
	return coreBodyValid
end

local function markerMatches(body, marker)
	if not marker then
		return true
	end
	if type(marker) == "function" then
		return marker(body) == true
	end
	if type(marker) == "table" then
		for _, entry in ipairs(marker) do
			if body:find(entry, 1, true) then
				return true
			end
		end
		return false
	end
	return body:find(marker, 1, true) ~= nil
end

local function repoRelativePath(urlOrPath)
	local path = tostring(urlOrPath or "")
	if path:find("^https?://") then
		local stripped = path
			:gsub("^https://raw%.githubusercontent%.com/" .. GITHUB_REPO:gsub("%-", "%%-") .. "/[^/]+/", "")
			:gsub("^https://cdn%.jsdelivr%.net/gh/" .. GITHUB_REPO:gsub("%-", "%%-") .. "/@[^/]+/", "")
			:gsub("^https://github%.com/" .. GITHUB_REPO:gsub("%-", "%%-") .. "/raw/[^/]+/", "")
		if stripped ~= path then
			return stripped
		end
	end
	return path:gsub("^/", "")
end

local function mirrorLabel(url)
	if url:find("jsdelivr", 1, true) then
		return "jsdelivr"
	end
	if url:find("github%.com/.+/raw/", 1) then
		return "github-web"
	end
	if url:find("raw%.githubusercontent%.com", 1) then
		return "github-raw"
	end
	return "remote"
end

local function withCacheBust(url, nonce)
	local sep = url:find("?") and "&" or "?"
	return url
		.. sep
		.. "v="
		.. LOADER_VERSION
		.. "&core="
		.. REQUIRED_CORE_VERSION
		.. "&t="
		.. tostring(nonce or tick())
		.. "&nocache="
		.. tostring(math.random(100000, 999999))
end

local function buildMirrorUrls(relativePath)
	relativePath = repoRelativePath(relativePath)
	local urls = {}
	local seen = {}
	local function add(url)
		if not seen[url] then
			seen[url] = true
			table.insert(urls, url)
		end
	end

	add(REPO_BASE .. "/" .. relativePath)
	add(GITHUB_WEB_RAW .. "/" .. relativePath)

	local commit = ENV._Alleral_ReleaseCommit
	if type(commit) == "string" and commit ~= "" and commit ~= "HEAD" then
		add("https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. commit .. "/" .. relativePath)
		add("https://cdn.jsdelivr.net/gh/" .. GITHUB_REPO .. "@" .. commit .. "/" .. relativePath)
	end

	for _, pinned in ipairs(PINNED_COMMITS) do
		if pinned ~= commit then
			add("https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. pinned .. "/" .. relativePath)
		end
	end

	add(JSDELIVR_BASE .. "/" .. relativePath)
	return urls
end

local function httpFetchBody(url, nonce)
	local fetchUrl = withCacheBust(url, nonce)
	local function accept(body)
		if type(body) ~= "string" or body == "" then
			return false
		end
		if body:find("404: Not Found", 1, true) then
			return false
		end
		if body:find("<!DOCTYPE html>", 1, true) or body:find("<html", 1, true) then
			return body:find("local ", 1, true)
				or body:find("function ", 1, true)
				or body:find("Core%.VERSION", 1, true)
				or body:find("LOADER_VERSION", 1, true)
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

	if type(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, fetchUrl, true)
		if ok and accept(body) then
			return body
		end
		ok, body = pcall(game.HttpGet, game, fetchUrl)
		if ok and accept(body) then
			return body
		end
	end

	local ok, body = pcall(function()
		return game:HttpGet(fetchUrl, true)
	end)
	if ok and accept(body) then
		return body
	end

	ok, body = pcall(function()
		return game:HttpGet(fetchUrl)
	end)
	if ok and accept(body) then
		return body
	end

	if HttpService and type(HttpService.GetAsync) == "function" then
		ok, body = pcall(function()
			return HttpService:GetAsync(fetchUrl, true)
		end)
		if ok and accept(body) then
			return body
		end
	end

	if httpRequest then
		for _, spec in ipairs({
			{
				Url = fetchUrl,
				Method = "GET",
				Headers = {
					["Cache-Control"] = "no-cache, no-store, must-revalidate",
					["Pragma"] = "no-cache",
				},
			},
			{
				url = fetchUrl,
				method = "GET",
				headers = {
					["Cache-Control"] = "no-cache, no-store, must-revalidate",
					["Pragma"] = "no-cache",
				},
			},
		}) do
			local reqOk, response = pcall(httpRequest, spec)
			if reqOk then
				body = extractBody(response)
				local status = type(response) == "table" and (response.StatusCode or response.status or response.Status or 200) or 200
				if accept(body) and (status == 0 or (status >= 200 and status < 300)) then
					return body
				end
			end
		end
	end

	return nil
end

local function ensureReleaseManifest(forceRefresh)
	if ENV._Alleral_ReleaseLoaded and not forceRefresh then
		return
	end
	for _, url in ipairs(buildMirrorUrls("config/release.json")) do
		for attempt = 1, 2 do
			local body = httpFetchBody(url, tick() + attempt)
			if body and not body:find("404: Not Found", 1, true) then
				local commit = body:match('"commit"%s*:%s*"([^"]+)"')
				if commit and commit ~= "" and commit ~= "HEAD" then
					ENV._Alleral_ReleaseCommit = commit
				end
				if HttpService then
					local ok, decoded = pcall(function()
						return HttpService:JSONDecode(body)
					end)
					if ok and type(decoded) == "table" and type(decoded.commit) == "string" then
						if decoded.commit ~= "" and decoded.commit ~= "HEAD" then
							ENV._Alleral_ReleaseCommit = decoded.commit
						end
					end
				end
				ENV._Alleral_ReleaseLoaded = true
				return
			end
		end
	end
	if not ENV._Alleral_ReleaseCommit and PINNED_COMMITS[1] then
		ENV._Alleral_ReleaseCommit = PINNED_COMMITS[1]
	end
	ENV._Alleral_ReleaseLoaded = true
end

local function fetchRemoteMirrors(urls, label, marker)
	local lastErr = nil
	local nonces = {
		tick(),
		tick() + 1,
		safeTime(),
		safeTime() + 1,
		math.random(100000, 999999),
		math.random(100000, 999999),
	}

	for _, baseUrl in ipairs(urls) do
		for attempt = 1, math.min(FETCH_RETRIES, #nonces) do
			local body = httpFetchBody(baseUrl, nonces[attempt])
			if body and body ~= "" then
				if markerMatches(body, marker) then
					return body, mirrorLabel(baseUrl)
				end
				lastErr = label .. " mirror returned stale payload (" .. mirrorLabel(baseUrl) .. ")"
			else
				lastErr = label .. " download failed (" .. mirrorLabel(baseUrl) .. ")"
			end
			if attempt < FETCH_RETRIES then
				safeWait(FETCH_BACKOFF * attempt)
			end
		end
	end

	return nil, lastErr or (label .. " download failed")
end

local function resolveLocalMarked(files, marker)
	if not CAPABILITIES.readfile then
		return nil, nil
	end
	for _, file in ipairs(files) do
		local source = readLocalFile(file)
		if source and markerMatches(source, marker) then
			return source, "local:" .. file
		end
	end
	for _, hit in ipairs(discoverLocalFiles(files)) do
		if markerMatches(hit.source, marker) then
			return hit.source, "discovered:" .. hit.path
		end
	end
	return nil, nil
end

local function resolveFromFiles(files, label, urlOrPath, marker)
	if CAPABILITIES.readfile then
		local localSource, localLabel = resolveLocalMarked(files, marker)
		if localSource then
			return localSource, localLabel
		end
	end

	local devMode = ENV.Alleral_DevMode == true
	local preferLocal = devMode or ENV.Alleral_PreferLocal == true
	if preferLocal and CAPABILITIES.readfile then
		for _, hit in ipairs(discoverLocalFiles(files)) do
			if markerMatches(hit.source, marker) then
				return hit.source, "discovered:" .. hit.path
			end
		end
	end

	ensureReleaseManifest(false)
	local mirrors = buildMirrorUrls(urlOrPath)
	local source, mirrorLabelName = fetchRemoteMirrors(mirrors, label, marker)
	if source then
		return source, mirrorLabelName
	end

	if CAPABILITIES.readfile then
		local localSource, localLabel = resolveLocalMarked(files, marker)
		if localSource then
			log("info", label .. " loaded from " .. localLabel .. " (remote mirrors stale)")
			return localSource, localLabel
		end
		for _, hit in ipairs(discoverLocalFiles(files)) do
			if markerMatches(hit.source, marker) then
				log("info", label .. " loaded from discovered:" .. hit.path .. " (remote mirrors stale)")
				return hit.source, "discovered:" .. hit.path
			end
		end
	end

	if devMode and CAPABILITIES.readfile then
		for _, hit in ipairs(discoverLocalFiles(files)) do
			return hit.source, "discovered:" .. hit.path
		end
	end

	return nil, label .. " unavailable after mirror retries"
end

local ENV_BRIDGE = [=[
do
	local bridge = shared
	if type(bridge) == "table" and getgenv then
		local g = getgenv()
		if type(g) == "table" then
			if bridge.Alleral_Rayfield
				and bridge.Alleral_Rayfield.InterfaceBuild == "Rayfield"
				and type(bridge.Alleral_Rayfield.CreateWindow) == "function" then
				g.Alleral_Rayfield = bridge.Alleral_Rayfield
				g.Alleral_UI = bridge.Alleral_Rayfield
			end
			if bridge.Alleral_UI and type(bridge.Alleral_UI.CreateWindow) == "function" then
				g.Alleral_UI = bridge.Alleral_UI
				g.Alleral_Rayfield = bridge.Alleral_UI
			end
			if bridge.Alleral_Core then g.Alleral_Core = bridge.Alleral_Core end
			if bridge.Alleral_Analytics then g.Alleral_Analytics = bridge.Alleral_Analytics end
			if bridge.Alleral_Telemetry then g.Alleral_Telemetry = bridge.Alleral_Telemetry end
			if bridge.Alleral_LoaderMeta then g.Alleral_LoaderMeta = bridge.Alleral_LoaderMeta end
			if bridge.Alleral_LoaderCapabilities then g.Alleral_LoaderCapabilities = bridge.Alleral_LoaderCapabilities end
			if bridge.Alleral_ReportError then g.Alleral_ReportError = bridge.Alleral_ReportError end
			if bridge.Alleral_LogEvent then g.Alleral_LogEvent = bridge.Alleral_LogEvent end
			if bridge.Alleral_Boot then g.Alleral_Boot = bridge.Alleral_Boot end
			g.Alleral_State = g.Alleral_State or bridge.Alleral_State or {}
			if type(bridge.Alleral_State) == "table" then
				for key, value in pairs(bridge.Alleral_State) do
					if g.Alleral_State[key] == nil then
						g.Alleral_State[key] = value
					end
				end
			end
			bridge.Alleral_State = g.Alleral_State
		end
	end
end
]=]

local function publishBridge()
	ENV.Alleral_State = ENV.Alleral_State or {}
	pcall(function()
		shared.Alleral_Rayfield = ENV.Alleral_Rayfield
		shared.Alleral_UI = ENV.Alleral_UI
		shared.Alleral_Core = ENV.Alleral_Core
		shared.Alleral_Analytics = ENV.Alleral_Analytics
		shared.Alleral_Telemetry = ENV.Alleral_Telemetry
		shared.Alleral_LoaderMeta = ENV.Alleral_LoaderMeta
		shared.Alleral_LoaderCapabilities = ENV.Alleral_LoaderCapabilities
		shared.Alleral_ReportError = ENV.Alleral_ReportError
		shared.Alleral_LogEvent = ENV.Alleral_LogEvent
		shared.Alleral_State = ENV.Alleral_State
		shared.Alleral_Boot = true
		shared.Alleral_StartupFailed = nil
	end)
end

local function patchGameSource(profile, source)
	return ENV_BRIDGE .. "\n" .. source
end

local function compileAndRun(source, chunkName, runEnv)
	local compiled, compileErr = nil, "loadstring unavailable"
	if loadStringFn then
		compiled, compileErr = loadStringFn(source, chunkName)
	end
	if not compiled and type(load) == "function" and load ~= loadStringFn then
		compiled, compileErr = load(source, chunkName)
	end
	if not compiled then
		return false, "Compile failed: " .. tostring(compileErr)
	end
	if runEnv and setfenv then
		pcall(setfenv, compiled, runEnv)
	end
	local ok, runErr = pcall(compiled)
	if not ok then
		return false, "Runtime error: " .. tostring(runErr)
	end
	return true
end

local function readStartupFailure()
	local fail = ENV.Alleral_StartupFailed
	pcall(function()
		if shared and shared.Alleral_StartupFailed then
			fail = fail or shared.Alleral_StartupFailed
		end
	end)
	if ENV.Alleral_State and ENV.Alleral_State.StartupFailed then
		fail = fail or ENV.Alleral_State.StartupFailed
	end
	ENV.Alleral_StartupFailed = nil
	pcall(function()
		shared.Alleral_StartupFailed = nil
	end)
	if ENV.Alleral_State then
		ENV.Alleral_State.StartupFailed = nil
	end
	return fail
end

local function unloadPrevious()
	local state = ENV.Alleral_State
	if state and type(state.Alleral_Unload) == "function" then
		pcall(state.Alleral_Unload)
	end
	ENV.Alleral_Boot = nil
	ENV.Alleral_LoaderRunning = false
end

local function clearSharedBridge()
	pcall(function()
		if typeof(shared) == "table" then
			shared.Alleral_Rayfield = nil
			shared.Alleral_UI = nil
			shared.Alleral_Core = nil
			shared.Alleral_Analytics = nil
			shared.Alleral_Telemetry = nil
			shared.Alleral_GameHelpers = nil
		end
	end)
end

local function invalidateStaleModules()
	if ENV.Alleral_LoaderVersion == LOADER_VERSION then
		return
	end
	ENV.Alleral_Core = nil
	ENV.Alleral_Rayfield = nil
	ENV.Alleral_UI = nil
	ENV.Alleral_Analytics = nil
	ENV.Alleral_Telemetry = nil
	ENV.Alleral_ReportError = nil
	ENV.Alleral_LogEvent = nil
	ENV.Alleral_GameHelpers = nil
	ENV.Alleral_LoaderVersion = LOADER_VERSION
	log("info", "Cleared cached modules for loader " .. LOADER_VERSION)
end

local function coreVersionOk(core)
	return core
		and type(core.loadRayfield) == "function"
		and core.VERSION == REQUIRED_CORE_VERSION
		and core.UI_LIBRARY == REQUIRED_UI_LIBRARY
end

local function tryDirectCoreLoad()
	if coreVersionOk(ENV.Alleral_Core) then
		return true
	end
	if not CAPABILITIES.http then
		return false
	end
	local nonce = tick()
	local directUrls = {
		REPO_BASE .. "/" .. SHARED_CORE_PATH,
		GITHUB_WEB_RAW .. "/" .. SHARED_CORE_PATH,
	}
	for _, url in ipairs(directUrls) do
		local body = httpFetchBody(url .. "?direct=" .. nonce, nonce)
		if body and coreBodyValid(body) then
			local ok, err = compileAndRun(body, "Alleral/core-direct")
			if ok and coreVersionOk(ENV.Alleral_Core) then
				log("info", "Core loaded via direct fetch")
				return true
			end
			ENV.Alleral_Core = nil
			ENV.Alleral_Rayfield = nil
			ENV.Alleral_UI = nil
			log("warn", "Direct core fetch rejected: " .. tostring(err or "version mismatch"))
		end
	end
	return false
end

local function tryRecoveryLoaderBootstrap()
	if not CAPABILITIES.http then
		return false
	end
	local nonce = tick()
	local loaderUrls = {
		REPO_BASE .. "/loader.luau",
		GITHUB_WEB_RAW .. "/loader.luau",
	}
	for _, url in ipairs(loaderUrls) do
		local body = httpFetchBody(url .. "?recover=" .. nonce, nonce)
		if type(body) == "string" and #body > 8000 and body:find("Alleral Hub", 1, true) then
			log("info", "Bootstrapping latest loader from GitHub...")
			ENV.Alleral_LoaderRunning = false
			local ok, err = compileAndRun(body, "Alleral/loader-recover")
			if ok then
				return true
			end
			log("warn", "Recovery loader failed: " .. tostring(err))
		end
	end
	return false
end

local function runAutoRecovery()
	if ENV._Alleral_AutoRecoveryAttempted then
		return false
	end
	ENV._Alleral_AutoRecoveryAttempted = true
	log("info", "Auto-recovering Alleral modules...")
	ENV.Alleral_LoaderRunning = false
	ENV._Alleral_ReleaseLoaded = nil
	ENV.Alleral_Core = nil
	ENV.Alleral_Rayfield = nil
	ENV.Alleral_UI = nil

	if tryDirectCoreLoad() then
		ENV.Alleral_LoaderRunning = false
		main()
		return true
	end

	if tryRecoveryLoaderBootstrap() then
		return true
	end

	safeWait(1)
	ENV.Alleral_LoaderRunning = false
	main()
	return true
end

local function preloadCore(required)
	local core = ENV.Alleral_Core
	if coreVersionOk(core) then
		return true
	end
	ENV.Alleral_Core = nil
	ENV.Alleral_Rayfield = nil
	ENV.Alleral_UI = nil

	if tryDirectCoreLoad() then
		return true
	end

	for attempt = 1, 2 do
		if attempt > 1 then
			log("info", "Retrying core download from alternate mirrors...")
			ENV._Alleral_ReleaseLoaded = nil
			ensureReleaseManifest(true)
			safeWait(FETCH_BACKOFF * 2)
		end

		local source, sourceLabel = resolveFromFiles(
			SHARED_CORE_FILES,
			"core",
			SHARED_CORE_PATH,
			coreSourceMarker()
		)
		if source then
			local ok, err = compileAndRun(source, "Alleral/core")
			if ok and coreVersionOk(ENV.Alleral_Core) then
				log("info", "Core loaded from " .. sourceLabel .. " (v" .. tostring(ENV.Alleral_Core.VERSION) .. ")")
				return true
			end
			ENV.Alleral_Core = nil
			log("warn", "Core rejected from " .. tostring(sourceLabel) .. ": " .. tostring(err or "version mismatch"))
			if required and attempt == 2 then
				return false, err or "Core failed to initialize"
			end
		elseif required then
			log("warn", "Core fetch failed: " .. tostring(sourceLabel))
			if attempt == 2 then
				return false, sourceLabel
			end
		end
	end

	if required then
		return false, "Core unavailable"
	end
	log("warn", "Core skipped")
	return false
end

local function preloadAnalytics()
	local source, sourceLabel = resolveFromFiles(SHARED_ANALYTICS_FILES, "analytics", SHARED_ANALYTICS_PATH, "Alleral_Analytics")
	if not source then
		log("warn", "Analytics skipped: " .. tostring(sourceLabel))
		return false
	end
	local ok, err = compileAndRun(source, "Alleral/analytics")
	if not ok then
		log("warn", "Analytics failed: " .. tostring(err))
		return false
	end
	log("info", "Analytics loaded from " .. sourceLabel)
	return ENV.Alleral_Analytics ~= nil
end

local function ownerTelemetryValid(cfg)
	return type(cfg) == "table"
		and cfg.enabled ~= false
		and trim(cfg.relayUrl or "") ~= ""
		and trim(cfg.apiKey or "") ~= ""
		and trim(cfg.apiKey) ~= "aller_CHANGE_ME"
		and not trim(cfg.apiKey):find("paste%-", 1, true)
end

local function parseEnvFile(raw)
	local out = {}
	for line in tostring(raw or ""):gmatch("[^\r\n]+") do
		line = trim(line)
		if line ~= "" and not line:match("^#") and line:find("=") then
			local key, value = line:match("^([^=]+)=(.*)$")
			if key then
				out[trim(key)] = trim(value)
			end
		end
	end
	return out
end

local function buildTelemetryConfigFromEnv(env)
	if type(env) ~= "table" then
		return nil
	end
	local apiKey = trim(env.TELEMETRY_API_KEY or env.ADMIN_API_KEY or "")
	if apiKey == "" or apiKey == "aller_CHANGE_ME" or #apiKey < 24 then
		return nil
	end
	local relayUrl = DEFAULT_TELEMETRY_RELAY
	local publicUrl = trim(env.TELEMETRY_PUBLIC_URL or env.TELEMETRY_RELAY_URL or "")
	if publicUrl ~= "" then
		publicUrl = publicUrl:gsub("/+$", "")
		if publicUrl:find("/ingest$") then
			relayUrl = publicUrl
		else
			relayUrl = publicUrl .. "/ingest"
		end
	end
	return {
		enabled = true,
		relayUrl = relayUrl,
		apiKey = apiKey,
		brand = trim(env.TELEMETRY_BRAND) ~= "" and trim(env.TELEMETRY_BRAND) or "Alleral Ops",
		heartbeatMinutes = tonumber(env.TELEMETRY_HEARTBEAT_MINUTES) or 15,
		logLevel = trim(env.TELEMETRY_LOG_LEVEL) ~= "" and trim(env.TELEMETRY_LOG_LEVEL) or "info",
	}
end

local function bootstrapTelemetryFromEnvFiles()
	for _, path in ipairs(OWNER_TELEMETRY_ENV_FILES) do
		local raw = readLocalFile(path)
		if raw then
			local cfg = buildTelemetryConfigFromEnv(parseEnvFile(raw))
			if ownerTelemetryValid(cfg) then
				ENV.Alleral_OwnerTelemetry = cfg
				log("info", "Telemetry config auto-loaded from " .. path)
				return true
			end
		end
	end
	if CAPABILITIES.readfile then
		for _, hit in ipairs(discoverLocalFiles(OWNER_TELEMETRY_ENV_FILES)) do
			local cfg = buildTelemetryConfigFromEnv(parseEnvFile(hit.source))
			if ownerTelemetryValid(cfg) then
				ENV.Alleral_OwnerTelemetry = cfg
				log("info", "Telemetry config auto-loaded from " .. hit.path)
				return true
			end
		end
	end
	return false
end

local function loadOwnerTelemetryTable(raw, label)
	if type(raw) ~= "string" or raw == "" or not loadStringFn then
		return nil
	end
	local compiled = loadStringFn(raw, "Alleral/owner_telemetry")
	if not compiled then
		return nil
	end
	local ok, result = pcall(compiled)
	if ok and ownerTelemetryValid(result) then
		return result, label
	end
	return nil
end

local function loadOwnerTelemetryConfig()
	if ownerTelemetryValid(ENV.Alleral_OwnerTelemetry) then
		return true
	end

	for _, path in ipairs(OWNER_TELEMETRY_FILES) do
		local raw = readLocalFile(path)
		if raw then
			local cfg, label = loadOwnerTelemetryTable(raw, path)
			if cfg then
				ENV.Alleral_OwnerTelemetry = cfg
				log("info", "Telemetry config loaded from " .. label)
				return true
			elseif raw:find("enabled%s*=%s*false") or raw:find('apiKey%s*=%s*""') then
				log("warn", "Skipping disabled/empty telemetry config: " .. path)
			end
		end
	end

	if bootstrapTelemetryFromEnvFiles() then
		return true
	end

	if CAPABILITIES.readfile then
		for _, hit in ipairs(discoverLocalFiles({
			"../Alleral-Private/owner_telemetry.luau",
			"Alleral-Private/owner_telemetry.luau",
			"config/owner_telemetry.luau",
			"owner_telemetry.luau",
		})) do
			local cfg, label = loadOwnerTelemetryTable(hit.source, hit.path)
			if cfg then
				ENV.Alleral_OwnerTelemetry = cfg
				log("info", "Telemetry config loaded from " .. label)
				return true
			end
		end
	end

	ENV.Alleral_OwnerTelemetry = nil
	return false
end

local function preloadHelpers()
	if ENV.Alleral_GameHelpers and ENV.Alleral_GameHelpers.VERSION == "1.0" then
		return true
	end
	local source, sourceLabel = resolveFromFiles(SHARED_HELPERS_FILES, "helpers", SHARED_HELPERS_PATH, "Alleral_GameHelpers")
	if not source then
		log("warn", "Game helpers skipped: " .. tostring(sourceLabel))
		return false
	end
	local ok, err = compileAndRun(source, "Alleral/helpers")
	if ok and ENV.Alleral_GameHelpers then
		log("info", "Game helpers loaded from " .. sourceLabel)
		return true
	end
	log("warn", "Game helpers failed: " .. tostring(err))
	return false
end

local function preloadTelemetry()
	loadOwnerTelemetryConfig()

	local source, sourceLabel = resolveFromFiles(
		SHARED_TELEMETRY_FILES,
		"telemetry",
		SHARED_TELEMETRY_PATH,
		telemetrySourceMarker()
	)
	if not source then
		log("warn", "Telemetry skipped: " .. tostring(sourceLabel))
		return false
	end
	local ok, err = compileAndRun(source, "Alleral/telemetry")
	if not ok then
		log("warn", "Telemetry failed: " .. tostring(err))
		return false
	end
	local telemetry = ENV.Alleral_Telemetry
	if telemetry and telemetry.Version ~= TELEMETRY_MODULE_VERSION then
		log("warn", "Telemetry version mismatch (expected " .. TELEMETRY_MODULE_VERSION .. ")")
	end
	loadOwnerTelemetryConfig()
	if type(ENV.Alleral_OwnerTelemetry) == "table" then
		local ownerCfg = ENV.Alleral_OwnerTelemetry
		if ownerCfg.shareKickWebhook == true then
			local ownerWebhook = ownerCfg.kickWebhookUrl
			if type(ownerWebhook) == "string" and ownerWebhook ~= "" then
				ENV.Alleral_DefaultWebhook = ownerWebhook
			end
		end
	end
	telemetry = ENV.Alleral_Telemetry
	if telemetry and type(telemetry.Configure) == "function" and type(ENV.Alleral_OwnerTelemetry) == "table" then
		telemetry:Configure(ENV.Alleral_OwnerTelemetry)
	end
	if telemetry and type(telemetry.InstallBridge) == "function" then
		pcall(function()
			telemetry:InstallBridge()
		end)
	end
	ENV.Alleral_ReportError = ENV.Alleral_ReportError or (telemetry and telemetry.ReportError and function(scope, err, details)
		telemetry:ReportError(scope, err, details)
	end)
	ENV.Alleral_LogEvent = ENV.Alleral_LogEvent or (telemetry and telemetry.ReportEvent and function(category, message, data)
		telemetry:ReportEvent(category, message, data)
	end)
	if telemetry and telemetry.IsEnabled and telemetry:IsEnabled() then
		if type(telemetry.ReportSessionStart) == "function" then
			pcall(function()
				telemetry:ReportSessionStart({
					loaderVersion = LOADER_VERSION,
					executor = CAPABILITIES.executor,
				})
			end)
		end
		if type(telemetry.HookLifecycle) == "function" then
			pcall(function()
				telemetry:HookLifecycle()
			end)
		end
		if type(telemetry.StartHeartbeat) == "function" then
			pcall(function()
				telemetry:StartHeartbeat()
			end)
		end
		local relayHost = ""
		pcall(function()
			local cfg = telemetry._config or ENV.Alleral_OwnerTelemetry or {}
			relayHost = tostring(cfg.relayUrl or ""):match("^https?://([^/]+)") or ""
		end)
		log("info", "Telemetry on" .. (relayHost ~= "" and (" (" .. relayHost .. ")") or ""))
	else
		log("info", "Telemetry off — run tools/sync_telemetry_config.ps1 or add config/owner_telemetry.luau")
	end
	return telemetry ~= nil
end

local function telemetryReport(phase, extra)
	local telemetry = ENV.Alleral_Telemetry
	if telemetry and type(telemetry.ReportInject) == "function" then
		pcall(function()
			telemetry:ReportInject(phase, extra)
		end)
	end
end

local function runGameScript(profile)
	local source, sourceLabel = resolveFromFiles(profile.scriptFiles, "script", profile.scriptUrl, profile.sourceMarker)
	if not source then
		return false, sourceLabel
	end

	if #source < MIN_SCRIPT_BYTES then
		return false, "Downloaded script looks truncated (" .. tostring(#source) .. " bytes)"
	end

	if profile.sourceMarker and not source:find(profile.sourceMarker, 1, true) then
		log("warn", profile.name .. " download may be outdated (missing " .. profile.sourceMarker .. ")")
	end

	log("info", string.format("Loading %s v%s from %s", profile.name, profile.version or "?", sourceLabel))

	telemetryReport("start", {
		scriptName = profile.id,
		scriptVersion = profile.version,
		gameName = profile.name,
	})

	publishBridge()
	ENV.Alleral_Boot = true
	ENV.Alleral_LoaderCapabilities = CAPABILITIES
	ENV.Alleral_LoaderMeta = {
		version = LOADER_VERSION,
		profile = profile.id,
		scriptVersion = profile.version,
		source = sourceLabel,
		executor = CAPABILITIES.executor,
		capabilities = CAPABILITIES,
		loadedAt = os.time(),
	}

	source = patchGameSource(profile, source)
	local ok, runErr = compileAndRun(source, "Alleral/" .. profile.id, ENV)
	ENV.Alleral_Boot = nil
	pcall(function()
		shared.Alleral_Boot = nil
	end)

	if not ok then
		telemetryReport("failed", {
			scriptName = profile.id,
			scriptVersion = profile.version,
			gameName = profile.name,
			error = tostring(runErr),
		})
		return false, runErr
	end
	local failMsg = readStartupFailure()
	if failMsg then
		telemetryReport("failed", {
			scriptName = profile.id,
			scriptVersion = profile.version,
			gameName = profile.name,
			error = tostring(failMsg),
		})
		return false, tostring(failMsg)
	end
	telemetryReport("loaded", {
		scriptName = profile.id,
		scriptVersion = profile.version,
		gameName = profile.name,
	})
	local telemetry = ENV.Alleral_Telemetry
	if telemetry and type(telemetry.StartHeartbeat) == "function" then
		pcall(function()
			telemetry:StartHeartbeat()
		end)
	end
	return true
end

local function preflight()
	if not CAPABILITIES.loadstring then
		return false, "This executor needs loadstring (or load) to run Alleral."
	end
	if not CAPABILITIES.http and not CAPABILITIES.readfile then
		return false, "This executor needs HTTP or readfile to download Alleral modules."
	end
	return true
end

local function applyCoreCapabilities()
	local core = ENV.Alleral_Core
	if core and type(core.refreshLoaderCapabilities) == "function" then
		local caps = core.refreshLoaderCapabilities()
		if type(caps) == "table" then
			CAPABILITIES.executor = caps.executor or CAPABILITIES.executor
			CAPABILITIES.http = caps.http == true or hasHttp()
			CAPABILITIES.readfile = caps.readfile == true or readFile ~= nil
			CAPABILITIES.isfile = type(firstExecFunc("isfile", "is_file", "IsFile")) ~= nil
			CAPABILITIES.listfiles = type(firstExecFunc("listfiles", "list_files", "ListFiles")) ~= nil
			CAPABILITIES.solara = caps.solara == true
		end
	end
end

local function resolveScriptGate(profile)
	local core = ENV.Alleral_Core
	if not core or type(core.fetchScriptManifest) ~= "function" then
		return { allowed = true, status = { label = "Working", icon = "✅", message = "" } }
	end
	ENV.Alleral_ActiveScriptId = profile.id
	ENV.Alleral_ScriptManifestUrl = ENV.Alleral_ScriptManifestUrl or SCRIPT_MANIFEST_URL
	core.fetchScriptManifest(false)
	local evaluation = core.evaluateScriptStatus(profile.id, profile.version)
	local status = evaluation.status
	if not evaluation.allowed then
		local message = string.format(
			"%s is %s. %s Set getgenv().Alleral_ForceLoad = true to override.",
			profile.name,
			status.label,
			status.message ~= "" and status.message or "Script is temporarily unavailable."
		)
		return evaluation, message
	end
	if evaluation.warn then
		notify("Alleral", string.format(
			"%s — %s%s",
			profile.name,
			status.label,
			status.message ~= "" and (": " .. status.message) or ""
		), 7)
	end
	return evaluation
end

local function main()
	log("info", "Alleral loader " .. LOADER_VERSION)
	if ENV.Alleral_LoaderRunning then
		log("warn", "Already running, call getgenv().Alleral_Reload() after unload")
		return
	end
	ENV.Alleral_LoaderRunning = true

	local ready, preflightErr = preflight()
	if not ready then
		notify("Alleral", preflightErr, 8)
		log("warn", preflightErr)
		ENV.Alleral_LoaderRunning = false
		return
	end

	invalidateStaleModules()
	clearSharedBridge()
	ensureReleaseManifest(false)
	loadOwnerTelemetryConfig()
	ENV.Alleral_StartupFailed = nil
	ENV.Alleral_Rayfield = nil
	ENV.Alleral_UI = nil
	ENV.Alleral_Core = nil
	unloadPrevious()

	local profile, detectErr = detectGame()
	if not profile then
		notify("Alleral", tostring(detectErr), 8)
		log("warn", tostring(detectErr))
		ENV.Alleral_LoaderRunning = false
		return
	end

	log("info", string.format(
		"Detected %s | executor=%s | http=%s | local=%s",
		profile.name,
		CAPABILITIES.executor,
		tostring(CAPABILITIES.http),
		tostring(CAPABILITIES.readfile)
	))

	if profile.preload then
		local preloadReady, preloadErr = profile.preload()
		if not preloadReady then
			notify("Alleral", tostring(preloadErr), 8)
			log("warn", "Preload failed: " .. tostring(preloadErr))
			ENV.Alleral_LoaderRunning = false
			return
		end
	end

	local coreOk, coreErr = preloadCore(true)
	if not coreOk then
		if runAutoRecovery() then
			return
		end
		notify("Alleral", "Alleral could not start. Please rejoin and try again.", 8)
		log("warn", "Core required but unavailable: " .. tostring(coreErr))
		telemetryReport("failed", {
			scriptName = profile.id,
			scriptVersion = profile.version,
			gameName = profile.name,
			error = "Core failed: " .. tostring(coreErr),
		})
		ENV.Alleral_LoaderRunning = false
		return
	end

	preloadAnalytics()
	preloadHelpers()
	applyCoreCapabilities()
	preloadTelemetry()

	if ENV.Alleral_Core and type(ENV.Alleral_Core.fetchWeaoExploits) == "function" then
		task.spawn(function()
			local exploits, source = ENV.Alleral_Core.fetchWeaoExploits(false)
			if exploits then
				local profile = ENV.Alleral_Core.executorProfile and ENV.Alleral_Core.executorProfile()
				local weao = profile and profile.weao
				if weao then
					log("info", string.format(
						"WEAO: %s — %s (via %s)",
						tostring(weao.title),
						ENV.Alleral_Core.weaoStatusLabel and ENV.Alleral_Core.weaoStatusLabel(weao) or "",
						tostring(source or "api")
					))
				else
					log("info", "WEAO exploit list loaded (" .. tostring(source or "api") .. ")")
				end
			end
		end)
	end

	local gateEval, gateErr = resolveScriptGate(profile)
	if gateEval and gateEval.allowed == false then
		local message = gateErr or "Script blocked by status manifest."
		notify("Alleral", message, 10)
		log("warn", tostring(message))
		telemetryReport("failed", {
			scriptName = profile.id,
			scriptVersion = profile.version,
			gameName = profile.name,
			error = message,
		})
		ENV.Alleral_LoaderRunning = false
		return
	end

	if ENV.Alleral_Core and type(ENV.Alleral_Core.loadRayfield) == "function" then
		local uiLibrary, uiErr = ENV.Alleral_Core.loadRayfield()
		if uiLibrary and uiLibrary.InterfaceBuild == REQUIRED_UI_LIBRARY then
			ENV.Alleral_Rayfield = uiLibrary
			ENV.Alleral_UI = uiLibrary
			log("info", "Rayfield preloaded (" .. tostring(uiLibrary.InterfaceBuild) .. ")")
		else
			ENV.Alleral_Rayfield = nil
			ENV.Alleral_UI = nil
			local detail = uiErr
				or ("UI library mismatch: " .. tostring(uiLibrary and uiLibrary.InterfaceBuild or "nil"))
			log("warn", "Rayfield preload failed: " .. detail)
			notify("Alleral", "Rayfield failed: " .. detail, 8)
			ENV.Alleral_LoaderRunning = false
			return
		end
	end

	local ok, runErr = runGameScript(profile)
	ENV.Alleral_LoaderRunning = false

	if not ok then
		notify("Alleral", tostring(runErr), 8)
		log("warn", tostring(runErr))
		telemetryReport("failed", {
			scriptName = profile.id,
			scriptVersion = profile.version,
			gameName = profile.name,
			error = tostring(runErr),
		})
		return
	end

	notify("Alleral", profile.name .. " loaded.", 4)
	log("info", "Ready")
	ENV._Alleral_AutoRecoveryAttempted = nil
end

ENV.Alleral_Reload = function()
	local telemetry = ENV.Alleral_Telemetry
	if telemetry and type(telemetry.ReportSessionEnd) == "function" then
		pcall(function()
			telemetry:ReportSessionEnd("reload")
			telemetry._sessionEnded = false
			telemetry._sessionId = nil
			telemetry._heartbeatRunning = false
		end)
	end
	unloadPrevious()
	if typeof(task) == "table" and type(task.defer) == "function" then
		task.defer(main)
	else
		main()
	end
end

ENV.Alleral_LoaderInfo = function()
	return {
		version = LOADER_VERSION,
		capabilities = CAPABILITIES,
		games = GAMES,
	}
end

print("[Alleral] v" .. LOADER_VERSION .. " | PlaceId " .. tostring(game.PlaceId) .. " | executor=" .. tostring(CAPABILITIES.executor))

local okBoot, bootErr = pcall(main)
if not okBoot then
	local message = tostring(bootErr)
	warn("[Alleral Loader] " .. message)
	notify("Alleral", message, 10)
	ENV.Alleral_LoaderRunning = false
end
