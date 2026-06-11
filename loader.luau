--[[
	Alleral Hub — one script.
	Detects game, fetches core + game script, runs.
]]

local LOADER_VERSION = "5.0.1"
local MIN_CORE = "1.18"
local REPO = "evanbackup1256-ship-it/kick"
local BRANCH = "main"
local RAW = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH
local CDN = "https://cdn.jsdelivr.net/gh/" .. REPO .. "@" .. BRANCH

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

local function detectExecutor()
	for _, id in ipairs({ "identifyexecutor", "getexecutorname", "whatexecutor", "getexecutor" }) do
		local fn = firstExecFunc(id)
		if fn then
			local ok, name = pcall(fn)
			if ok and type(name) == "string" and name ~= "" then
				return name
			end
		end
	end
	return ENV.syn and "Synapse" or (ENV.KRNL_LOADED and "Krnl" or "Unknown")
end

local CAPABILITIES = {
	executor = detectExecutor(),
	loadstring = loadStringFn ~= nil,
	readfile = readFile ~= nil,
}

local function httpGet(url)
	url = url .. (url:find("?") and "&" or "?") .. "t=" .. tostring(tick())
	if type(ENV.Volt) == "table" and type(ENV.Volt.request) == "function" then
		local ok, res = pcall(ENV.Volt.request, { Url = url, Method = "GET" })
		if ok and res then
			local body = res.Body or res.body
			if type(body) == "string" and #body > 0 then
				return body
			end
		end
	end
	if type(ENV.request) == "function" then
		local ok, res = pcall(ENV.request, { Url = url, Method = "GET" })
		if ok and res then
			local body = res.Body or res.body
			if type(body) == "string" and #body > 0 then
				return body
			end
		end
	end
	if type(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, url, true)
		if ok and type(body) == "string" and #body > 0 then
			return body
		end
	end
	return nil
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
	for _, base in ipairs({ CDN, RAW }) do
		local body = httpGet(base .. "/" .. relativePath)
		if body and #body >= minBytes and looksLikeLua(body) and not body:find("404: Not Found", 1, true) then
			return body, base
		end
	end
	return nil
end

local function getSource(localPaths, remotePath, opts)
	opts = type(opts) == "table" and opts or { marker = opts }
	local minBytes = opts.minBytes or 0
	local marker = opts.marker

	local src, path = readLocal(localPaths, minBytes)
	if src and (not marker or src:find(marker, 1, true)) then
		return src, "local:" .. path
	end

	src, path = fetchRemote(remotePath, minBytes)
	if src then
		if marker and not src:find(marker, 1, true) then
			log("Script may be outdated (missing " .. marker .. ")", true)
		end
		return src, "remote"
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

	log("Game: " .. profile.name .. " | executor=" .. CAPABILITIES.executor)

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
		minBytes = 5000,
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
	return { version = LOADER_VERSION, capabilities = CAPABILITIES, games = GAMES }
end

print("[Alleral] v" .. LOADER_VERSION .. " | PlaceId " .. tostring(game.PlaceId))

local ok, err = pcall(main)
if not ok then
	warn("[Alleral] " .. tostring(err))
	notify("Alleral", tostring(err), 10)
	ENV.Alleral_LoaderRunning = false
end
