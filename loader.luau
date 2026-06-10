--[[
	Alleral Universal Loader
	Detects the current Roblox game, preloads core + analytics, and injects the matching script.

	Usage (executor, from repo root):
		loadstring(readfile("loader.luau"))()

	Remote:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/loader.luau"))()

	Reload after unload:
		getgenv().Alleral_Reload()
]]

local LOADER_VERSION = "2.4"
local REPO_BASE = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main"
local FETCH_RETRIES = 3
local FETCH_BACKOFF = 0.75
local MIN_SCRIPT_BYTES = 1000

local SHARED_CORE_FILES = {
	"src/alleral_core.luau",
	"alleral_core.luau",
}
local SHARED_ANALYTICS_FILES = {
	"src/analytics.luau",
	"analytics.luau",
}
local SHARED_CORE_URL = REPO_BASE .. "/src/alleral_core.luau"
local SHARED_ANALYTICS_URL = REPO_BASE .. "/src/analytics.luau"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()

local function firstExecFunc(...)
	for _, name in ipairs({ ... }) do
		local fn = ENV[name] or (getfenv and getfenv()[name])
		if type(fn) == "function" then
			return fn
		end
	end
	return nil
end

local httpRequest = firstExecFunc("http_request", "request") or (ENV.syn and ENV.syn.request)
local readFile = firstExecFunc("readfile")
local listFiles = firstExecFunc("listfiles")
local isFile = firstExecFunc("isfile")
local loadStringFn = firstExecFunc("loadstring", "LoadString") or loadstring

local function notify(title, text, duration)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration or 5,
		})
	end)
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
	http = httpRequest ~= nil,
	loadstring = loadStringFn ~= nil,
	readfile = readFile ~= nil,
	isfile = isFile ~= nil,
	listfiles = listFiles ~= nil,
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
		version = "6.4",
		needsCore = true,
		placeIds = { 89469502395769 },
		universeIds = { 10004244222 },
		scriptFiles = {
			"src/kick_a_lucky_block.luau",
			"kick_a_lucky_block.luau",
			"kick a lucky block.luau",
		},
		scriptUrl = REPO_BASE .. "/src/kick_a_lucky_block.luau",
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
		version = "1.0",
		needsCore = true,
		placeIds = { 95082159892680 },
		scriptFiles = {
			"src/speed_keyboard_escape.luau",
			"speed_keyboard_escape.luau",
		},
		scriptUrl = REPO_BASE .. "/src/speed_keyboard_escape.luau",
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
		version = "1.0",
		needsCore = true,
		placeIds = { 92416421522960 },
		universeIds = { 9792947201 },
		scriptFiles = {
			"src/slime_rng.luau",
			"slime_rng.luau",
		},
		scriptUrl = REPO_BASE .. "/src/slime_rng.luau",
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
		version = "1.0",
		needsCore = true,
		placeIds = { 107646426076756 },
		scriptFiles = {
			"src/build_a_ring_farm.luau",
			"build_a_ring_farm.luau",
		},
		scriptUrl = REPO_BASE .. "/src/build_a_ring_farm.luau",
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
	if not listFiles or not isFile then
		return found
	end
	local roots = { "", "kick/", "kick/kick/", "workspace/", "scripts/" }
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

local function withCacheBust(url)
	local sep = url:find("?") and "&" or "?"
	return url .. sep .. "v=" .. LOADER_VERSION
end

local function fetchRemote(url, label)
	if not httpRequest then
		return nil, "HTTP is not available"
	end
	local fetchUrl = withCacheBust(url)
	local lastErr = nil
	for attempt = 1, FETCH_RETRIES do
		local ok, response = pcall(httpRequest, {
			Url = fetchUrl,
			Method = "GET",
		})
		if ok and response then
			local status = response.StatusCode or response.status or 0
			local body = response.Body or response.body or ""
			if status >= 200 and status < 300 and body ~= "" then
				return body, nil
			end
			lastErr = string.format("%s HTTP %s (empty=%s)", label, tostring(status), tostring(body == ""))
		else
			lastErr = tostring(response)
		end
		if attempt < FETCH_RETRIES then
			task.wait(FETCH_BACKOFF * attempt)
		end
	end
	return nil, lastErr or "Download failed"
end

local function resolveFromFiles(files, label, url)
	local devMode = ENV.Alleral_DevMode == true
	local preferLocal = devMode or ENV.Alleral_PreferLocal == true
	if preferLocal and CAPABILITIES.readfile then
		for _, file in ipairs(files) do
			local source = readLocalFile(file)
			if source then
				return source, "local:" .. file
			end
		end
		if devMode then
			for _, hit in ipairs(discoverLocalFiles(files)) do
				return hit.source, "discovered:" .. hit.path
			end
		end
	end
	if url then
		local source, err = fetchRemote(url, label)
		if source then
			return source, url
		end
		if not devMode then
			return nil, err
		end
	end
	return nil, "No " .. label .. " source found"
end

local function compileAndRun(source, chunkName)
	if not loadStringFn then
		return false, "loadstring is not available"
	end
	local compiled, compileErr = loadStringFn(source, chunkName)
	if not compiled then
		return false, "Compile failed: " .. tostring(compileErr)
	end
	local ok, runErr = pcall(compiled)
	if not ok then
		return false, "Runtime error: " .. tostring(runErr)
	end
	return true
end

local function unloadPrevious()
	local state = ENV.Alleral_State
	if state and type(state.Alleral_Unload) == "function" then
		pcall(state.Alleral_Unload)
	end
	ENV.Alleral_Boot = nil
	ENV.Alleral_LoaderRunning = false
end

local function invalidateStaleModules()
	if ENV.Alleral_LoaderVersion == LOADER_VERSION then
		return
	end
	ENV.Alleral_Core = nil
	ENV.Alleral_Starlight = nil
	ENV.Alleral_Analytics = nil
	ENV.Alleral_LoaderVersion = LOADER_VERSION
	log("info", "Cleared cached modules for loader " .. LOADER_VERSION)
end

local function preloadCore(required)
	local core = ENV.Alleral_Core
	if core and type(core.loadStarlight) == "function" and core.VERSION == "1.1" then
		return true
	end
	ENV.Alleral_Core = nil
	ENV.Alleral_Starlight = nil
	local source, sourceLabel = resolveFromFiles(SHARED_CORE_FILES, "core", SHARED_CORE_URL)
	if not source then
		if required then
			return false, sourceLabel
		end
		log("warn", "Core skipped: " .. tostring(sourceLabel))
		return false
	end
	local ok, err = compileAndRun(source, "Alleral/core")
	if ok and ENV.Alleral_Core then
		log("info", "Core loaded from " .. sourceLabel)
		return true
	end
	if required then
		return false, err or "Core failed to initialize"
	end
	log("warn", "Core failed: " .. tostring(err))
	return false
end

local function preloadAnalytics()
	local source, sourceLabel = resolveFromFiles(SHARED_ANALYTICS_FILES, "analytics", SHARED_ANALYTICS_URL)
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

local function runGameScript(profile)
	local source, sourceLabel = resolveFromFiles(profile.scriptFiles, "script", profile.scriptUrl)
	if not source then
		return false, sourceLabel
	end

	if #source < MIN_SCRIPT_BYTES then
		return false, "Downloaded script looks truncated (" .. tostring(#source) .. " bytes)"
	end

	log("info", string.format("Loading %s v%s from %s", profile.name, profile.version or "?", sourceLabel))

	ENV.Alleral_Boot = true
	ENV.Alleral_LoaderMeta = {
		version = LOADER_VERSION,
		profile = profile.id,
		source = sourceLabel,
		executor = CAPABILITIES.executor,
		loadedAt = os.time(),
	}

	local ok, runErr = compileAndRun(source, "Alleral/" .. profile.id)
	ENV.Alleral_Boot = nil

	if not ok then
		return false, runErr
	end
	if ENV.Alleral_StartupFailed then
		local failMsg = tostring(ENV.Alleral_StartupFailed)
		ENV.Alleral_StartupFailed = nil
		return false, failMsg
	end
	return true
end

local function preflight()
	local missing = {}
	if not CAPABILITIES.loadstring then
		table.insert(missing, "loadstring")
	end
	if not CAPABILITIES.http and not CAPABILITIES.readfile then
		table.insert(missing, "http or readfile")
	end
	if #missing > 0 then
		return false, "Missing: " .. table.concat(missing, ", ")
	end
	return true
end

local function main()
	if ENV.Alleral_LoaderRunning then
		log("warn", "Already running — call getgenv().Alleral_Reload() after unload")
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
	ENV.Alleral_StartupFailed = nil
	ENV.Alleral_Starlight = nil
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
		notify("Alleral", "Core failed: " .. tostring(coreErr), 8)
		log("warn", "Core required but unavailable: " .. tostring(coreErr))
		ENV.Alleral_LoaderRunning = false
		return
	end

	preloadAnalytics()

	if ENV.Alleral_Core and type(ENV.Alleral_Core.loadStarlight) == "function" then
		local starlight, starlightErr = ENV.Alleral_Core.loadStarlight()
		if starlight then
			ENV.Alleral_Starlight = starlight
			log("info", "Starlight preloaded")
		else
			log("warn", "Starlight preload skipped: " .. tostring(starlightErr))
		end
	end

	local ok, runErr = runGameScript(profile)
	ENV.Alleral_LoaderRunning = false

	if not ok then
		notify("Alleral", tostring(runErr), 8)
		log("warn", tostring(runErr))
		return
	end

	notify("Alleral", profile.name .. " loaded.", 4)
	log("info", "Ready")
end

ENV.Alleral_Reload = function()
	unloadPrevious()
	task.defer(main)
end

ENV.Alleral_LoaderInfo = function()
	return {
		version = LOADER_VERSION,
		capabilities = CAPABILITIES,
		games = GAMES,
	}
end

main()
