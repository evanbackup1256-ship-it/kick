local LOADER_VERSION = "3.2.0"
local REPO_BASE = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main"
local FETCH_RETRIES = 3
local FETCH_BACKOFF = 0.75
local MIN_SCRIPT_BYTES = 1000

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
local OWNER_TELEMETRY_FILES = {
	"../Alleral-Private/owner_telemetry.luau",
	"../../Alleral-Private/owner_telemetry.luau",
	"kick/../Alleral-Private/owner_telemetry.luau",
	"kick/kick/../Alleral-Private/owner_telemetry.luau",
	"Alleral-Private/owner_telemetry.luau",
	"kick/Alleral-Private/owner_telemetry.luau",
	"workspace/Alleral-Private/owner_telemetry.luau",
	"workspace/../Alleral-Private/owner_telemetry.luau",
	"owner_telemetry.luau",
}
local TELEMETRY_MODULE_VERSION = "2.2"
local SHARED_CORE_URL = REPO_BASE .. "/core/alleral_core.luau"
local SHARED_ANALYTICS_URL = REPO_BASE .. "/core/analytics.luau"
local SHARED_TELEMETRY_URL = REPO_BASE .. "/core/telemetry.luau"

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
	http = httpRequest ~= nil,
	loadstring = loadStringFn ~= nil,
	readfile = readFile ~= nil,
	isfile = isFile ~= nil,
	listfiles = firstExecFunc("listfiles") ~= nil,
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
		version = "6.5",
		needsCore = true,
		placeIds = { 89469502395769 },
		universeIds = { 10004244222 },
		scriptFiles = {
			"games/kick_a_lucky_block.luau",
			"src/kick_a_lucky_block.luau",
			"kick_a_lucky_block.luau",
			"kick a lucky block.luau",
		},
		scriptUrl = REPO_BASE .. "/games/kick_a_lucky_block.luau",
		sourceMarker = "Alleral_Starlight",
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
		version = "1.1",
		needsCore = true,
		placeIds = { 95082159892680 },
		scriptFiles = {
			"games/speed_keyboard_escape.luau",
			"src/speed_keyboard_escape.luau",
			"speed_keyboard_escape.luau",
		},
		scriptUrl = REPO_BASE .. "/games/speed_keyboard_escape.luau",
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
		version = "1.1",
		needsCore = true,
		placeIds = { 92416421522960 },
		universeIds = { 9792947201 },
		scriptFiles = {
			"games/slime_rng.luau",
			"src/slime_rng.luau",
			"slime_rng.luau",
		},
		scriptUrl = REPO_BASE .. "/games/slime_rng.luau",
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
		version = "1.1",
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

local function withCacheBust(url, nonce)
	local sep = url:find("?") and "&" or "?"
	return url
		.. sep
		.. "v="
		.. LOADER_VERSION
		.. "&t="
		.. tostring(nonce or os.time())
		.. "&nocache="
		.. tostring(math.random(10000, 99999))
end

local function fetchRemote(url, label, marker)
	local lastErr = nil
	local nonces = { os.time(), os.time() + 1, math.random(100000, 999999) }

	for attempt = 1, #nonces do
		local fetchUrl = withCacheBust(url, nonces[attempt])

		if type(game.HttpGet) == "function" then
			local ok, body = pcall(game.HttpGet, game, fetchUrl, true)
			if ok and body and body ~= "" and not body:find("404: Not Found") then
				if not marker or body:find(marker, 1, true) then
					return body, nil
				end
				lastErr = label .. " HttpGet response looked cached/outdated"
			end
		end

		if httpRequest then
			local ok, response = pcall(httpRequest, {
				Url = fetchUrl,
				Method = "GET",
			})
			if ok and response then
				local status = response.StatusCode or response.status or 0
				local body = response.Body or response.body or ""
				if status >= 200 and status < 300 and body ~= "" then
					if not marker or body:find(marker, 1, true) then
						return body, nil
					end
					lastErr = label .. " response looked cached/outdated"
				else
					lastErr = string.format("%s HTTP %s (empty=%s)", label, tostring(status), tostring(body == ""))
				end
			else
				lastErr = tostring(response)
			end
		end

		if attempt < #nonces then
			task.wait(FETCH_BACKOFF * attempt)
		end
	end

	return nil, lastErr or "Download failed"
end

local function resolveFromFiles(files, label, url, marker)
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
		local source, err = fetchRemote(url, label, marker)
		if source then
			return source, url
		end
		if not devMode then
			return nil, err
		end
	end
	return nil, "No " .. label .. " source found"
end

local ENV_BRIDGE = [=[
do
	local bridge = shared
	if type(bridge) == "table" and getgenv then
		local g = getgenv()
		if type(g) == "table" then
			if bridge.Alleral_Starlight then g.Alleral_Starlight = bridge.Alleral_Starlight end
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
		shared.Alleral_Starlight = ENV.Alleral_Starlight
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
	if profile.id == "kick_a_lucky_block" then
		if source:find("HTTP is unavailable; cannot load Starlight", 1, true) then
			source = source:gsub(
				"(local function loadStarlight%(%)\r?\n)",
				"%1\tif shared and type(shared.Alleral_Starlight) == \"table\" then return shared.Alleral_Starlight end\n"
					.. "\tif getgenv and type((getgenv()).Alleral_Starlight) == \"table\" then return getgenv().Alleral_Starlight end\n",
				1
			)
			log("warn", "Patched cached Kick script to use preloaded Starlight")
		end
	end
	return ENV_BRIDGE .. "\n" .. source
end

local function compileAndRun(source, chunkName, runEnv)
	if not loadStringFn then
		return false, "loadstring is not available"
	end
	local compiled, compileErr = loadStringFn(source, chunkName)
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

local function invalidateStaleModules()
	if ENV.Alleral_LoaderVersion == LOADER_VERSION then
		return
	end
	ENV.Alleral_Core = nil
	ENV.Alleral_Starlight = nil
	ENV.Alleral_Analytics = nil
	ENV.Alleral_Telemetry = nil
	ENV.Alleral_ReportError = nil
	ENV.Alleral_LogEvent = nil
	ENV.Alleral_LoaderVersion = LOADER_VERSION
	log("info", "Cleared cached modules for loader " .. LOADER_VERSION)
end

local function preloadCore(required)
	local core = ENV.Alleral_Core
	if core and type(core.loadStarlight) == "function" and core.VERSION == "1.4" then
		return true
	end
	ENV.Alleral_Core = nil
	ENV.Alleral_Starlight = nil
	local source, sourceLabel = resolveFromFiles(SHARED_CORE_FILES, "core", SHARED_CORE_URL, "Alleral_Core")
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
	local source, sourceLabel = resolveFromFiles(SHARED_ANALYTICS_FILES, "analytics", SHARED_ANALYTICS_URL, "Alleral_Analytics")
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
			end
		end
	end

	if CAPABILITIES.readfile then
		for _, hit in ipairs(discoverLocalFiles({
			"owner_telemetry.luau",
			"../Alleral-Private/owner_telemetry.luau",
			"Alleral-Private/owner_telemetry.luau",
			"kick/../Alleral-Private/owner_telemetry.luau",
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

local function preloadTelemetry()
	local source, sourceLabel = resolveFromFiles(SHARED_TELEMETRY_FILES, "telemetry", SHARED_TELEMETRY_URL, "Alleral_Telemetry")
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
		local relayHost = ""
		pcall(function()
			local cfg = telemetry._config or ENV.Alleral_OwnerTelemetry or {}
			relayHost = tostring(cfg.relayUrl or ""):match("^https?://([^/]+)") or ""
		end)
		log("info", "Telemetry on" .. (relayHost ~= "" and (" (" .. relayHost .. ")") or ""))
	else
		log("info", "Telemetry off (set getgenv().Alleral_OwnerTelemetry before loader)")
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
		if source:find("HTTP is unavailable; cannot load Starlight", 1, true) then
			return false, "Cached Kick script is stale, run loader again"
		end
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
	preloadTelemetry()

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
