getgenv().Alleral_State = getgenv().Alleral_State or {}

local VERSION = "5.3"

local state = getgenv().Alleral_State
local connections = {}
local loops = {}
local loopControllers = {}
local runtime = {
	seenWebhookGuids = {},
	seenWebhookOrder = {},
	favoriteQueue = {},
	favoriteTools = {},
	lastAutoKickActivity = 0,
	lastAutoKickMatch = 0,
	nextAutoKickReset = 0,
	autoKickSession = 0,
	flashCollectSession = 0,
	cachedWeights = nil,
	cachedPlot = nil,
	cachedPlotAt = 0,
	nextPlotLookup = 0,
	cachedRemotesAt = 0,
	cachedBattleStatus = nil,
	cachedBattleStatusAt = 0,
	nextWeightBuyAttempt = {},
	nextKickStyleAttempt = 0,
	remoteLookupCache = {},
	errorLog = {},
	errorCounts = {},
	errorLastSeen = {},
	performanceMode = "Balanced",
	sessionStart = tick(),
	sessionKicks = 0,
	sessionResets = 0,
	sessionMatches = 0,
	sessionBestCps = 0,
	sessionBestName = "--",
	kickRateWindow = {},
	kicksPerMin = 0,
	masteryKickCount = 0,
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

if state.Alleral_Unload then
	pcall(state.Alleral_Unload)
end

local defaults = {
	HubRunning = true,
	Version = VERSION,
	AFarm = false,
	APredict = false,
	TBrainrot = { "Any" },
	TRarity = { "Any" },
	TMutation = { "Any" },
	TargetMinigameAccuracy = "Perfect",
	KickPowerMode = "Normal",
	CustomKickPowerPercent = 100,
	VolcanoTweenSpeed = 115,
	ATrain = false,
	ATrainCollect = false,
	TrainCollectDelay = 20,
	TrainAnchorCFrame = nil,
	IsFlashCollecting = false,
	NextFlashCollect = 0,
	A2xTrain = false,
	ACollect = false,
	CollectDelay = 60,
	APlaceBest = false,
	AProtectFilter = false,
	TProtectedBrainrots = {},
	PlotBrainrotList = { "Any" },
	PlotProtectedList = { "None" },
	IsPlacingPet = false,
	AAutoUpgrade = false,
	TUpgrade = { "Any" },
	TUpgradeBase = {},
	MaxUpLevel = 75,
	AutoUpgradeDelay = 5,
	APlotUpgrade = false,
	ARebirth = false,
	ABuySpeed = false,
	ABuyWeights = false,
	ABuyBest = false,
	TTargetWeight = "None",
	WeightList = { "None" },
	AAutoFav = false,
	TSSellBrainrot = { "Any" },
	TSSellRarity = { "Any" },
	TSSellMutation = { "Any" },
	WBBrainrot = { "Any" },
	WBRarity = { "Any" },
	WBMutation = { "Any" },
	WebhookURL = "",
	AWebhook = false,
	StatusFilterBrainrot = { "Any" },
	StatusFilterRarity = { "Any" },
	AutoStatusInterval = 15,
	AutoStatusWebhook = false,
	AAutoBattle = false,
	AAutoAcceptBattle = false,
	BattleRounds = "3",
	BattleGamepass = true,
	BattleMinPlayers = 2,
	AAutoMastery = false,
	MasteryKickPower = 50,
	MasteryResetMethod = "Died",
	TTargetWeatherEvent = "None",
	AAutoSummonWeather = false,
	TargetKickStyle = "Default",
	AAutoKickStyle = false,
	AntiAFK = false,
	NotifyOnError = false,
	JoinJobId = "",
	KnownGameUpdated = "",
	KnownPlaceVersion = 0,
	UIQuietMode = true,
	FavoriteScanInterval = 8,
	PlotRefreshInterval = 10,
	AutoPlaceInterval = 1.5,
	AutoKickInterval = 0.3,
	MasteryInterval = 1,
	-- New v5.3 features
	ANotifyRare = false,
	NotifyRarityThreshold = "Legendary",
	AKickVariance = false,
	KickVarianceMs = 80,
	AAutoSell = false,
	AutoSellMaxBackpack = 25,
}

local savedKeys = {
	"AFarm",
	"APredict",
	"TBrainrot",
	"TRarity",
	"TMutation",
	"TargetMinigameAccuracy",
	"KickPowerMode",
	"CustomKickPowerPercent",
	"VolcanoTweenSpeed",
	"ATrain",
	"ATrainCollect",
	"TrainCollectDelay",
	"A2xTrain",
	"ACollect",
	"CollectDelay",
	"APlaceBest",
	"AProtectFilter",
	"TProtectedBrainrots",
	"AAutoUpgrade",
	"TUpgrade",
	"MaxUpLevel",
	"AutoUpgradeDelay",
	"APlotUpgrade",
	"ARebirth",
	"ABuySpeed",
	"ABuyWeights",
	"ABuyBest",
	"TTargetWeight",
	"AAutoFav",
	"TSSellBrainrot",
	"TSSellRarity",
	"TSSellMutation",
	"WBBrainrot",
	"WBRarity",
	"WBMutation",
	"WebhookURL",
	"AWebhook",
	"StatusFilterBrainrot",
	"StatusFilterRarity",
	"AutoStatusInterval",
	"AutoStatusWebhook",
	"AAutoBattle",
	"AAutoAcceptBattle",
	"BattleRounds",
	"BattleGamepass",
	"BattleMinPlayers",
	"AAutoMastery",
	"MasteryKickPower",
	"MasteryResetMethod",
	"TTargetWeatherEvent",
	"AAutoSummonWeather",
	"TargetKickStyle",
	"AAutoKickStyle",
	"AntiAFK",
	"JoinJobId",
	"KnownGameUpdated",
	"KnownPlaceVersion",
	"UIQuietMode",
	"FavoriteScanInterval",
	"PlotRefreshInterval",
	"AutoPlaceInterval",
	"AutoKickInterval",
	"MasteryInterval",
	"ANotifyRare",
	"NotifyRarityThreshold",
	"AKickVariance",
	"KickVarianceMs",
	"AAutoSell",
	"AutoSellMaxBackpack",
}

local function copyValue(value)
	if type(value) ~= "table" then
		return value
	end
	local output = {}
	for key, item in pairs(value) do
		output[key] = copyValue(item)
	end
	return output
end

for key, value in pairs(defaults) do
	if state[key] == nil then
		state[key] = copyValue(value)
	end
end
state.HubRunning = true
state.Version = VERSION

local function trim(value)
	return tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function notify(title, text, duration)
	if runtime.ui and runtime.ui.Notification then
		pcall(function()
			runtime.ui:Notification({
				Title = title or "Alleral",
				Content = text or "",
				Duration = duration or 4,
			})
		end)
		return
	end
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title or "Alleral",
			Text = text or "",
			Duration = duration or 4,
		})
	end)
end

-- Executor detection runs once at startup. Two goals:
--   1. Some executors (old Yub builds, Arceus) have broken file APIs we must skip.
--   2. HTTP request and connection-inspection globals vary by executor.
-- We probe namespaces and known globals rather than relying solely on the name
-- string, since many executors lie, truncate, or don't expose identifyexecutor.
local Executor = (function()
	local env = {}
	pcall(function()
		local g = getgenv or getfenv
		if g then env = g() or {} end
	end)

	local function fn(k)
		local v = env[k]
		return type(v) == "function" and v or nil
	end
	local function tbl(k)
		local v = env[k]
		return type(v) == "table" and v or nil
	end

	-- Try every common name-identification API in priority order
	local rawName = ""
	for _, id in ipairs({ "identifyexecutor", "getexecutorname", "whatexecutor" }) do
		local f = fn(id)
		if f then
			local ok, r = pcall(f)
			if ok and type(r) == "string" and #r > 0 then
				rawName = r
				break
			end
		end
	end

	-- Normalise: lowercase, drop whitespace, keep only the base token
	local name = rawName:lower():gsub("%s+", ""):match("^[%a][%w%-_%.]*") or ""

	-- Namespace/global fingerprinting — fallback when the name is missing/useless
	if name == "" then
		if tbl("syn") and type(env.syn.request) == "function" then
			name = "synapse"
		elseif env.KRNL_LOADED == true then
			name = "krnl"
		elseif tbl("fluxus") and type(env.fluxus.request) == "function" then
			name = "fluxus"
		elseif tbl("sw") then
			name = "scriptware"
		elseif tbl("celery") then
			name = "celery"
		elseif tbl("delta") then
			name = "delta"
		elseif env.OXYGEN_U == true then
			name = "oxygenu"
		elseif tbl("Electron") then
			name = "electron"
		elseif tbl("Wave") and type(env.Wave.setclipboard) == "function" then
			name = "wave"
		elseif tbl("shared") and type(env.shared.solara) == "table" then
			name = "solara"
		elseif tbl("Xeno") then
			name = "xeno"
		elseif tbl("Volt") and type(env.Volt.request) == "function" then
			name = "volt"
		elseif tbl("Potassium") then
			name = "potassium"
		elseif tbl("Madium") then
			name = "madium"
		elseif tbl("Velocity") then
			name = "velocity"
		elseif tbl("Codex") then
			name = "codex"
		elseif tbl("Ronix") then
			name = "ronix"
		elseif fn("queue_on_teleport") and fn("getgc") then
			name = "synapse"
		else
			name = "unknown"
		end
	end

	-- Executors whose file-system implementations are known broken/unsafe.
	-- We simply skip those APIs rather than letting them silently corrupt data.
	local FS_BROKEN = {
		yub = true,
		yubx = true,
		arceus = true,
	}
	local fsOk = not FS_BROKEN[name]

	return {
		name       = name,
		rawName    = rawName,
		isKnown    = name ~= "unknown",
		fsOk       = fsOk,
		hasFilesystem = fsOk and type(env.writefile) == "function" and type(env.readfile) == "function",
		hasHttp    = type(env.request) == "function"
			or type(env.http_request) == "function"
			or (tbl("syn") and type(env.syn.request) == "function")
			or (tbl("fluxus") and type(env.fluxus.request) == "function")
			or (tbl("http") and type(env.http.request) == "function")
			or (type(HttpService.RequestAsync) == "function"),
		hasGetConn = type(env.getconnections) == "function" or type(env.get_signal_cons) == "function",
		hasClipboard = type(env.setclipboard) == "function" or type(env.toclipboard) == "function",
		hasFireTouch = type(env.firetouchinterest) == "function",
		env        = env,
	}
end)()

-- Retrieve a callable from the executor env. Pass noFs=true to block it on
-- executors whose file APIs are broken (avoids silent corruption).
local function execFunc(name, noFs)
	if noFs and not Executor.fsOk then
		return nil
	end
	local v = Executor.env[name]
	return type(v) == "function" and v or nil
end

local writeFile   = execFunc("writefile",  true)
local readFile    = execFunc("readfile",   true)
local isFile      = execFunc("isfile",     true)
local makeFolder  = execFunc("makefolder", true)
local isFolder    = execFunc("isfolder",   true)
local deleteFile  = execFunc("delfile",    true)
local listFiles   = execFunc("listfiles",  true)
local appendFile  = execFunc("appendfile", true)
local setClipboard = execFunc("setclipboard") or execFunc("toclipboard")
local settingsFolder = "Alleral_Configs"
local settingsFile = string.format("%s/KickBlox_v4_%s.json", settingsFolder, tostring(LocalPlayer.UserId))
local logFile = string.format("%s/KickBlox_v4_%s.log", settingsFolder, tostring(LocalPlayer.UserId))

local function shortError(message)
	message = tostring(message or "Unknown error"):gsub("%s+", " ")
	if #message > 220 then
		message = message:sub(1, 217) .. "..."
	end
	return message
end

local function logError(scope, err, details)
	local message = shortError(err)
	local label = tostring(scope or "Runtime")
	local timestamp = os.date("%H:%M:%S")
	local line = string.format("[%s] %s: %s", timestamp, label, message)
	if details and details ~= "" then
		line = line .. " (" .. shortError(details) .. ")"
	end
	local signature = label .. "\0" .. message
	local now = tick()
	runtime.errorCounts[signature] = (runtime.errorCounts[signature] or 0) + 1
	runtime.lastError = line
	if now - (runtime.errorLastSeen[signature] or 0) >= 5 then
		runtime.errorLastSeen[signature] = now
		table.insert(runtime.errorLog, 1, line)
		while #runtime.errorLog > 12 do
			table.remove(runtime.errorLog)
		end
		warn("[Alleral] " .. line)
	end
	if appendFile then
		pcall(function()
			if isFolder and makeFolder and not isFolder(settingsFolder) then
				makeFolder(settingsFolder)
			end
			appendFile(logFile, line .. "\n")
		end)
	end
	return message
end

local function safeCall(scope, callback, notifyUser)
	local ok, result = pcall(callback)
	if not ok then
		local message = logError(scope, result)
		if notifyUser and state.NotifyOnError then
			notify("Alleral", tostring(scope or "Runtime") .. ": " .. message, 4)
		end
		return false, result
	end
	return true, result
end

local function saveSettings()
	if not writeFile then
		return
	end
	local output = {}
	for _, key in ipairs(savedKeys) do
		output[key] = state[key]
	end
	safeCall("SaveSettings", function()
		if isFolder and makeFolder and not isFolder(settingsFolder) then
			makeFolder(settingsFolder)
		end
		writeFile(settingsFile, HttpService:JSONEncode(output))
	end)
end

local function loadSettings()
	if not readFile or not isFile then
		return
	end
	if not isFile(settingsFile) then
		return
	end
	local ok, decoded = safeCall("LoadSettings", function()
		local raw = readFile(settingsFile)
		if raw and raw ~= "" then
			return HttpService:JSONDecode(raw)
		end
		return nil
	end)
	if not ok or type(decoded) ~= "table" then
		return
	end
	for key, value in pairs(decoded) do
		if defaults[key] ~= nil then
			state[key] = value
		end
	end
end

loadSettings()

for _, key in ipairs({
	"ConfigPreset",
	"LowImpactMode",
	"AdaptiveLagGuard",
	"PauseOnLowFps",
	"MinFps",
	"UltraSafeMode",
}) do
	state[key] = nil
end

local function clampSettings()
	state.FavoriteScanInterval = math.max(4, tonumber(state.FavoriteScanInterval) or defaults.FavoriteScanInterval)
	state.PlotRefreshInterval = math.max(8, tonumber(state.PlotRefreshInterval) or defaults.PlotRefreshInterval)
	state.AutoPlaceInterval = math.max(1.5, tonumber(state.AutoPlaceInterval) or defaults.AutoPlaceInterval)
	state.AutoKickInterval = math.max(0.3, tonumber(state.AutoKickInterval) or defaults.AutoKickInterval)
	state.MasteryInterval = math.max(1, tonumber(state.MasteryInterval) or defaults.MasteryInterval)
	state.CollectDelay = math.max(1, tonumber(state.CollectDelay) or defaults.CollectDelay)
	state.TrainCollectDelay = math.max(1, tonumber(state.TrainCollectDelay) or defaults.TrainCollectDelay)
	state.AutoUpgradeDelay = math.max(1, tonumber(state.AutoUpgradeDelay) or defaults.AutoUpgradeDelay)
	state.BattleMinPlayers = math.max(2, math.min(5, tonumber(state.BattleMinPlayers) or defaults.BattleMinPlayers))
	state.AutoStatusInterval = math.max(1, tonumber(state.AutoStatusInterval) or defaults.AutoStatusInterval)
end

clampSettings()

-- Uses Executor.env so we don't need to reference bare globals that might not
-- exist at parse time on strict executor environments.
local function requestFunction()
	local e = Executor.env
	local candidates = {
		-- executor-specific namespaces first (most reliable)
		type(e.syn)         == "table" and type(e.syn.request)          == "function" and e.syn.request          or nil,
		type(e.fluxus)      == "table" and type(e.fluxus.request)       == "function" and e.fluxus.request       or nil,
		type(e.http)        == "table" and type(e.http.request)         == "function" and e.http.request         or nil,
		type(e.http_service) == "table" and type(e.http_service.request) == "function" and e.http_service.request or nil,
		-- UNC globals
		e.http_request,
		e.request,
		-- Wave executor capitalises the global
		e.Request,
		-- Roblox built-in HttpService as last resort (safeCall handles errors)
		type(HttpService.RequestAsync) == "function" and function(req)
			return HttpService:RequestAsync(req)
		end or nil,
	}
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "function" then
			return candidate
		end
	end
	return nil
end

local function getConnectionFetcher()
	local e = Executor.env
	local candidates = {
		e.getconnections,
		e.get_signal_cons,
		-- some executor forks add a numeric suffix
		e.getconnections2,
		e.get_signal_connections,
	}
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "function" then
			return candidate
		end
	end
	return nil
end

local function normalizeWebhookUrl(url)
	url = trim(url)
	if url == "" then
		return nil, "Webhook URL is empty."
	end
	if not url:match("^https://") then
		return nil, "Webhook URL must start with https://."
	end
	if
		not (
			url:match("^https://discord%.com/api/webhooks/%d+/.+")
			or url:match("^https://discordapp%.com/api/webhooks/%d+/.+")
		)
	then
		return nil, "Webhook URL is not a Discord webhook."
	end
	return url, nil
end

local function sendWebhook(url, payload)
	local sender = requestFunction()
	if not sender then
		return false, "Executor HTTP request function is unavailable."
	end
	local postUrl, urlError = normalizeWebhookUrl(url)
	if not postUrl then
		return false, urlError
	end
	local ok, response = safeCall("WebhookSend", function()
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
	local code = response and (response.StatusCode or response.Status or response.status_code)
	if type(code) == "number" and (code < 200 or code >= 300) then
		return false, "Webhook returned HTTP " .. tostring(code)
	end
	return true, nil
end

local function formatRobloxTimestamp(value)
	local text = tostring(value or "")
	if text == "" then
		return "Unknown"
	end
	text = text:gsub("T", " "):gsub("Z$", " UTC")
	return text
end

local function checkGameBuild(forceNotify, acceptCurrent)
	local ok, info = safeCall("GameBuildCheck", function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	local updated = ok and info and tostring(info.Updated or "") or ""
	local placeVersion = tonumber(game.PlaceVersion) or 0
	local previousUpdated = tostring(state.KnownGameUpdated or "")
	local previousPlaceVersion = tonumber(state.KnownPlaceVersion) or 0
	local changed = false
	if previousUpdated ~= "" and updated ~= "" and previousUpdated ~= updated then
		changed = true
	end
	if previousPlaceVersion > 0 and placeVersion > 0 and previousPlaceVersion ~= placeVersion then
		changed = true
	end
	runtime.gameBuild = {
		Name = (ok and info and info.Name) or game.Name,
		Updated = updated ~= "" and updated or previousUpdated,
		PlaceVersion = placeVersion,
		KnownUpdated = previousUpdated,
		KnownPlaceVersion = previousPlaceVersion,
		Changed = changed,
		CheckedAt = os.date("%H:%M:%S"),
	}
	if acceptCurrent or previousUpdated == "" then
		state.KnownGameUpdated = updated
		state.KnownPlaceVersion = placeVersion
		runtime.gameBuild.KnownUpdated = state.KnownGameUpdated
		runtime.gameBuild.KnownPlaceVersion = state.KnownPlaceVersion
		runtime.gameBuild.Changed = false
		saveSettings()
	end
	if changed then
		notify("Game Updated", "Game changed since your last saved check. Some features may need review.", 8)
	elseif forceNotify then
		notify("Game Check", "Game metadata matches your saved baseline.", 5)
	end
	return runtime.gameBuild
end

local function acceptCurrentGameBuild()
	local build = checkGameBuild(false, true)
	notify("Game Check", "Current game build saved as reviewed.", 5)
	return build
end

local function track(connection, key)
	if not connection then
		return nil
	end
	if key then
		if connections[key] and connections[key].Disconnect then
			safeCall("Disconnect:" .. tostring(key), function()
				connections[key]:Disconnect()
			end)
		end
		connections[key] = connection
	else
		table.insert(connections, connection)
	end
	return connection
end

local function safeFindRemote(network, aliases)
	for _, alias in ipairs(aliases) do
		local cached = runtime.remoteLookupCache[alias]
		if cached and cached.Parent then
			return cached
		end
		local remote = network and network:FindFirstChild(alias)
		if not remote then
			remote = ReplicatedStorage:FindFirstChild(alias, true)
		end
		if remote then
			runtime.remoteLookupCache[alias] = remote
			return remote
		end
	end
	return nil
end

local function untrack(connection)
	if not connection then
		return
	end
	if connection.Disconnect then
		safeCall("Disconnect", function()
			connection:Disconnect()
		end)
	end
	for key, item in pairs(connections) do
		if item == connection then
			connections[key] = nil
		end
	end
end

state.Alleral_Unload = function()
	state.HubRunning = false
	for name, controller in pairs(loopControllers) do
		if controller then
			controller.enabled = false
		end
		loopControllers[name] = nil
	end
	for key, connection in pairs(connections) do
		if connection and connection.Disconnect then
			safeCall("UnloadDisconnect:" .. tostring(key), function()
				connection:Disconnect()
			end)
		end
		connections[key] = nil
	end
	for _, loopState in pairs(loops) do
		loopState.enabled = false
	end
	safeCall("UnloadRestoreHumanoid", function()
		local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
			humanoid.MaxSlopeAngle = 45
		end
	end)
end

local function loadLuaSource(source, label)
	if not source or source == "" then
		logError("Loader", "Empty source for " .. label .. ".")
		return nil
	end
	local chunk, compileError = loadstring(source, "@" .. label)
	if not chunk then
		logError("Loader", "Failed to compile " .. label .. ": " .. tostring(compileError))
		return nil
	end
	local ok, result = safeCall("RunLua:" .. tostring(label), chunk)
	if not ok then
		return nil
	end
	if result then
		return result
	end
	if getgenv then
		local env = getgenv()
		return env.Starlight or env.Library or env.AlleralLib
	end
	return nil
end

local function loadLocalLua(path, label)
	if loadfile then
		local ok, chunk = safeCall("LoadFile:" .. tostring(label), function()
			return loadfile(path)
		end)
		if ok and chunk then
			local runOk, result = safeCall("RunLocalLua:" .. tostring(label), chunk)
			if runOk then
				if result then
					return result
				end
				if getgenv then
					local env = getgenv()
					return env.Starlight or env.Library or env.AlleralLib
				end
				return nil
			end
			logError("Loader", "Failed to run " .. label .. ": " .. tostring(result))
		end
	end
	if not readFile then
		return nil
	end
	if isFile then
		local ok, exists = safeCall("IsLocalLua:" .. tostring(label), function()
			return isFile(path)
		end)
		if not ok or not exists then
			return nil
		end
	end
	local ok, source = safeCall("ReadLocalLua:" .. tostring(label), function()
		return readFile(path)
	end)
	if not ok then
		logError("Loader", "Failed to read " .. tostring(label) .. ": " .. tostring(source))
		return nil
	end
	return loadLuaSource(source, label)
end

local function loadRemoteLua(url, label)
	local ok, source = safeCall("FetchLua:" .. tostring(label), function()
		return game:HttpGet(url)
	end)
	if not ok or not source or source == "" or source:find("404: Not Found") then
		logError("Loader", ok and ("Failed to fetch " .. label .. ".") or source)
		return nil
	end
	return loadLuaSource(source, label)
end

local STARLIGHT_SOURCE_URL =
	"https://raw.githubusercontent.com/Nebula-Softworks/Starlight-Interface-Suite/master/Source.lua"

-- ── Auto-update mechanism ─────────────────────────────────────────────────────
-- Fetches the latest script version from a remote source and runs it if newer.
-- The script acts as its own launcher: always run the bleeding-edge version.
local SCRIPT_SOURCE_URL =
	"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/kick%20a%20lucky%20block.luau"

local function autoUpdate()
	if Executor.hasHttp and not getgenv().Alleral_Updated then
		local ok, source = safeCall("AutoUpdate", function()
			return game:HttpGet(SCRIPT_SOURCE_URL)
		end)
		if ok and source and source ~= "" and not source:find("404: Not Found") then
			local remoteVersion = source:match('VERSION%s*=%s*"([^"]+)"')
			if remoteVersion and remoteVersion ~= VERSION then
				getgenv().Alleral_Updated = true
				local chunk, err = loadstring(source, "@Alleral (latest)")
				if chunk then
					local runOk, runErr = pcall(chunk)
					if runOk then
						return true
					end
					logError("AutoUpdate", runErr)
				else
					logError("AutoUpdate", "Failed to compile: " .. tostring(err))
				end
			end
		end
	end
	return false
end

if autoUpdate() then
	return
end
-- ── End auto-update ───────────────────────────────────────────────────────────

local function patchStarlightSource(source)
	source = source:gsub(
		"function Tab:Show%(%)[\r\n]+%s*if Library%.ActiveTab then",
		"function Tab:Show()\n\t\t\tif Library.ActiveTab == Tab then\n\t\t\t\treturn\n\t\t\tend\n\t\t\tif Library.ActiveTab then"
	)
	local inputStart = source:find("function Groupbox:CreateInput", 1, true)
	local labelStart = inputStart and source:find("function Groupbox:CreateLabel", inputStart, true)
	if not inputStart or not labelStart then
		return source
	end
	local before = source:sub(1, inputStart - 1)
	local block = source:sub(inputStart, labelStart - 1)
	local after = source:sub(labelStart)
	block = block:gsub(
		"(Element%.Instance = GroupboxTemplateInstance%.Input_TEMPLATE:Clone%(%)[\r\n]+%s*Element%.Instance%.Visible = true)",
		"%1\n\t\t\t\t\t\tElement.Instance.Parent = Groupbox.ParentingItem",
		1
	)
	block = block:gsub(
		"\n%s*Element%.Instance%.Parent = Groupbox%.ParentingItem\n\n%s*(Starlight%.Window%.TabSections%[Name%]%.Tabs%[TabIndex%]%.Groupboxes%[GroupIndex%]%.Elements%[Index%] = Element)",
		"\n\n\t\t\t\t\t%1",
		1
	)
	return before .. block .. after
end

-- Executor compatibility notification
do
	local execName = Executor and Executor.name or "unknown"
	local execRaw = Executor and Executor.rawName or ""
	local display = execName ~= "unknown" and execName or (execRaw ~= "" and execRaw or "unknown")
	local compatMap = {
		synapse = true, krnl = true, fluxus = true, scriptware = true,
		celery = true, delta = true, electron = true, wave = true,
		oxygenu = true, awp = true, evon = true,
	}
	local compat = compatMap[display:lower()] or false
	if display == "unknown" then
		notify("Executor", "Unknown executor - features may not work", 6)
	elseif not compat then
		notify("Executor", display .. " is untested - some features may fail", 6)
	else
		notify("Executor", display .. " detected - fully supported", 4)
	end
end

local function closeLoadingGui() end
local function loadingStep(text) end

local function loadStarlight()
	-- Try the new pure-code rewrite first
	local rewriteResult = loadLocalLua("starlight_repo/Source.lua", "Starlight v3 (local rewrite)")
	if rewriteResult and type(rewriteResult.CreateWindow) == "function" then
		return rewriteResult
	end

	-- Try the patched remote library
	local ok, result = safeCall("LoadStarlightRemote", function()
		return loadstring(patchStarlightSource(game:HttpGet(STARLIGHT_SOURCE_URL)), "@" .. "Starlight")()
	end)
	if ok and type(result) == "table" and type(result.CreateWindow) == "function" then
		return result
	end
	if not ok then
		logError("Starlight", result)
	else
		logError("Starlight", "Remote Starlight returned an invalid library.")
	end

	-- Local bundle fallbacks
	local luxyBackup = loadLocalLua("new_ui_library_luxy_backup.lua", "Starlight local backup")
	if luxyBackup and type(luxyBackup.CreateWindow) == "function" then
		return luxyBackup
	end
	return loadLocalLua("new_ui_library.lua", "Starlight local fallback")
end

local starlight = loadStarlight()
if not starlight or type(starlight.CreateWindow) ~= "function" then
	logError("Starlight", "Starlight Interface Suite was not available; startup aborted.")
	return
end
runtime.ui = starlight

local gameData = loadRemoteLua(
	"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/kickblox.lua",
	"game data"
) or { BrainrotOptions = {}, RarityOptions = {}, MutationOptions = {} }

local function withAny(options)
	local output = { "Any" }
	local seen = { Any = true, All = true, None = true, ["--"] = true }
	for _, option in ipairs(options or {}) do
		if not seen[option] then
			table.insert(output, option)
			seen[option] = true
		end
	end
	return output
end

if modules.mutationData and modules.mutationData.ValidMutations then
	gameData.MutationOptions = modules.mutationData.ValidMutations
end
gameData.BrainrotOptions = withAny(gameData.BrainrotOptions)
gameData.RarityOptions = withAny(gameData.RarityOptions)
gameData.MutationOptions = withAny(gameData.MutationOptions)

local function listFromSelection(selection)
	if type(selection) == "string" then
		return { selection }
	end
	if type(selection) ~= "table" then
		return {}
	end
	local output = {}
	local arrayLike = false
	for key, value in pairs(selection) do
		if type(key) == "number" then
			arrayLike = true
			if value ~= nil and value ~= false then
				table.insert(output, tostring(value))
			end
		elseif value then
			table.insert(output, tostring(key))
		end
	end
	if arrayLike then
		table.sort(output, function(a, b)
			return tostring(a) < tostring(b)
		end)
	end
	return output
end

local function tableFind(tbl, value)
	if type(tbl) ~= "table" then
		return false
	end
	for _, item in ipairs(tbl) do
		if item == value then
			return true
		end
	end
	return false
end

local function hasWildcard(selection)
	selection = listFromSelection(selection)
	return #selection == 0 or tableFind(selection, "Any") or tableFind(selection, "All")
end

local function normalizeText(value)
	local text = trim(value)
	text = text:gsub("[%%[%]%(%){}]", " ")
	text = text:gsub("[%s_-]+", " ")
	return trim(text)
end


local function normalizeMutation(value)
	local text = normalizeText(value)
	if text == "" then
		return "None"
	end
	local lowered = text:lower()
	if lowered == "none" or lowered == "normal" or lowered == "nil" or lowered == "no mutation" then
		return "None"
	end
	local eventMultiplier = lowered:match("^x%s*(%d+)$") or lowered:match("^(%d+)%s*x$")
	if eventMultiplier then
		return "x" .. eventMultiplier
	end
	return text
end

local function selectionMatches(selection, value, normalizer: (any) -> string)
	selection = listFromSelection(selection)
	if hasWildcard(selection) then
		return true
	end
	local normalized = normalizer(value):lower()
	for _, selected in ipairs(selection) do
		if normalizer(selected):lower() == normalized then
			return true
		end
	end
	return false
end

local rarityFor
local function mainFilterMatches(brainrot, mutation)
	local brainrotOk = selectionMatches(state.TBrainrot, brainrot, normalizeText)
	local rarityOk = selectionMatches(state.TRarity, rarityFor(brainrot, "Unknown"), normalizeText)
	local mutationOk = selectionMatches(state.TMutation, mutation, normalizeMutation)
	-- Suppress non-mutated brainrots only when the filter is not a wildcard AND
	-- the user has not explicitly selected "None" in the filter list.
	if not hasWildcard(state.TMutation)
		and normalizeMutation(mutation) == "None"
		and not tableFind(listFromSelection(state.TMutation), "None")
	then
		mutationOk = false
	end
	return brainrotOk and rarityOk and mutationOk
end

local function parseNumber(value)
	if type(value) == "number" then
		return value
	end
	local text = tostring(value or ""):gsub("[,%s%$]", "")
	-- Standard scientific notation: e.g. "1.5e3" → 1500
	local mantissa, exponent = text:match("^(%-?[%d%.]+)[eE](%-?%d+)$")
	if mantissa and exponent then
		return (tonumber(mantissa) or 0) * (10 ^ (tonumber(exponent) or 0))
	end
	-- Number with optional K/M/B/T/… suffix; allow leading minus
	local number, suffix = text:match("^(%-?[%d%.]+)(%a*)$")
	local valueNumber = tonumber(number or text) or 0
	local powers = { K = 3, M = 6, B = 9, T = 12, Q = 15, Qi = 18, S = 21, Sp = 24, O = 27, N = 30, D = 33 }
	if suffix and powers[suffix] then
		return valueNumber * (10 ^ powers[suffix])
	end
	return valueNumber
end

local function mathClamp(value, min, max)
	return math.min(math.max(value, min), max)
end

local function formatNumber(value)
	value = parseNumber(value)
	if value < 1000 then
		return tostring(math.floor(value))
	end
	local suffixes = { "K", "M", "B", "T", "Q", "Qi", "S", "Sp", "O", "N", "D" }
	local index = math.floor(math.log10(value) / 3)
	return string.format("%.2f%s", value / (10 ^ (index * 3)), suffixes[index] or ""):gsub("%.00", "")
end

local function coerceNumber(value)
	if type(value) == "table" then
		local first = value.First or value.first or value[1] or 0
		local second = value.Second or value.second or value[2] or 0
		return (tonumber(first) or 0) * (10 ^ (tonumber(second) or 0))
	end
	return parseNumber(value)
end

local modules = {
	entitiesData = nil,
	mutationData = nil,
	weightsData = nil,
	speedData = nil,
	rebirthData = nil,
	sacrificeData = nil,
	kickService = nil,
	balanceService = nil,
	rebirthService = nil,
	weatherService = nil,
}

local function loadModule(key, label, resolver)
	local ok, result = safeCall("LoadModule:" .. label, function()
		local target = resolver()
		if not target then
			return nil
		end
		return require(target)
	end)
	if ok then
		modules[key] = result
	end
	return modules[key]
end

loadModule("entitiesData", "EntitiesData", function()
	return ReplicatedStorage.Shared.Data.EntitiesData
end)
loadModule("mutationData", "MutationData", function()
	return ReplicatedStorage.Shared.Data.MutationData
end)
loadModule("weightsData", "WeightsData", function()
	return ReplicatedStorage:FindFirstChild("WeightsData", true)
end)
loadModule("speedData", "SpeedData", function()
	return ReplicatedStorage.Shared.Data.SpeedData
end)
loadModule("rebirthData", "RebirthData", function()
	return ReplicatedStorage.Shared.Data.RebirthData
end)
loadModule("sacrificeData", "SacrificeData", function()
	return ReplicatedStorage.Shared.Data.SacrificeData
end)
loadModule("kickService", "KickServiceClient", function()
	return ReplicatedStorage.Modules.ServicesLoader.KickServiceClient
end)
loadModule("balanceService", "ClientBalanceService", function()
	return ReplicatedStorage.Modules.ServicesLoader.ClientBalanceService
end)
loadModule("rebirthService", "RebirthServiceClient", function()
	return ReplicatedStorage.Modules.ServicesLoader.RebirthServiceClient
end)
loadModule("weatherService", "WeatherServiceClient", function()
	return ReplicatedStorage.Modules.ServicesLoader.WeatherService_Client
end)

local values = {
	coins = modules.balanceService and parseNumber(modules.balanceService.Balance) or 0,
	kickLevel = modules.kickService and modules.kickService.Level or 0,
	rebirthLevel = modules.rebirthService and modules.rebirthService.RebirthLevel or 0,
}

local function currentCoins()
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins then
		values.coins = parseNumber(coins.Value)
	end
	return values.coins or 0
end

if modules.balanceService and modules.balanceService.CoinsChanged then
	track(modules.balanceService.CoinsChanged:Connect(function(coins)
		values.coins = parseNumber(coins)
	end))
end
if modules.kickService and modules.kickService.LevelChanged then
	track(modules.kickService.LevelChanged:Connect(function(level)
		values.kickLevel = level or 0
	end))
end
if modules.rebirthService and modules.rebirthService.RebirthChanged then
	track(modules.rebirthService.RebirthChanged:Connect(function(level)
		values.rebirthLevel = level or 0
	end))
end

local remotes = {}

local function refreshRemotes()
	if tick() - runtime.cachedRemotesAt < 5 then
		return
	end
	runtime.cachedRemotesAt = tick()
	local network = ReplicatedStorage:FindFirstChild("Shared")
	network = network and network:FindFirstChild("Packages")
	network = network and network:FindFirstChild("Network")

	-- Primary alias lookup (covers original names + common renamed variants)
	remotes.kick           = safeFindRemote(network, { "rev_KickEvent", "KickEvent", "rev_kickevent", "KickRemote", "rev_Kick" })
	remotes.collect        = safeFindRemote(network, { "rev_B_Collect", "B_Collect", "Collect", "CollectCash", "rev_Collect" })
	remotes.upgradeBrainrot= safeFindRemote(network, { "rev_B_Upgrade", "B_Upgrade", "UpgradeBrainrot", "BrainrotUpgrade", "rev_Upgrade" })
	remotes.speedUpgrade   = safeFindRemote(network, { "rev_SPEED_UPGRADE", "SPEED_UPGRADE", "SpeedUpgrade", "rev_SpeedUp" })
	remotes.shopBuy        = safeFindRemote(network, { "rev_Shop_Buy", "Shop_Buy", "ShopBuy", "BuyItem", "rev_Buy" })
	remotes.weightEquip    = safeFindRemote(network, { "rev_WeightEquip", "WeightEquip", "EquipWeight", "rev_Equip" })
	remotes.sellAll        = safeFindRemote(network, { "rev_B_SellAll", "ref_B_SellAll", "B_SellAll", "SellAll", "SellAllBrainrots" })
	remotes.toggleFavorite = safeFindRemote(network, { "rev_ToggleFav", "ToggleFav", "FavoriteTool", "rev_Fav" })
	remotes.rebirth        = safeFindRemote(network, { "rev_RebirthRequest", "RebirthRequest", "Rebirth", "DoRebirth", "rev_Rebirth" })
	remotes.plotUpgrade    = safeFindRemote(network, { "rev_bs_upgrade", "bs_upgrade", "PlotUpgrade", "UpgradePlot", "rev_PlotUpgrade" })
	remotes.weather        = safeFindRemote(network, { "rev_sbe", "sbe", "SummonWeather", "WeatherSummon", "rev_Weather" })
	remotes.place          = safeFindRemote(network, { "rev_S_Interact", "S_Interact", "PlaceBrainrot", "PlacePet", "rev_Place" })
	-- Battle remotes: confirmed names from game source use rev_bs_battle_* prefix
	remotes.battleCreate   = safeFindRemote(network, { "rev_bs_battle_create", "ref_battle_create", "rev_battle_create", "battle_create", "BattleCreate" })
	remotes.battleInvite   = safeFindRemote(network, { "rev_bs_battle_invite", "ref_battle_invite", "rev_battle_invite", "battle_invite", "BattleInvite" })
	remotes.battleStart    = safeFindRemote(network, { "rev_bs_battle_start",  "rev_battle_start",  "battle_start", "BattleStart", "StartBattle" })
	-- Kick style: confirmed name is rev_KickStyle (no 'Equip' suffix)
	remotes.kickStyle      = safeFindRemote(network, { "rev_KickStyle", "rev_KickStyleEquip", "KickStyleEquip", "EquipKickStyle" })

	-- Dynamic fallback: scan the network folder for remotes not caught above.
	-- Matches by pattern against the lowercase name; won't overwrite existing hits.
	if network then
		for _, child in ipairs(network:GetChildren()) do
			if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
				local n = child.Name:lower()
				if not remotes.kick           and n:find("kick") and not n:find("style") and not n:find("battle") then remotes.kick = child
				elseif not remotes.collect    and n:find("collect")                                               then remotes.collect = child
				elseif not remotes.sellAll    and n:find("sell")  and n:find("all")                              then remotes.sellAll = child
				elseif not remotes.rebirth    and n:find("rebirth")                                              then remotes.rebirth = child
				elseif not remotes.place      and n:find("place") and not n:find("upgrade")                     then remotes.place = child
				elseif not remotes.battleCreate and n:find("battle") and n:find("create")                       then remotes.battleCreate = child
				elseif not remotes.battleInvite and n:find("battle") and n:find("invite")                       then remotes.battleInvite = child
				elseif not remotes.battleStart  and n:find("battle") and n:find("start")                        then remotes.battleStart = child
				end
			end
		end
	end
end

refreshRemotes()

local function findPlot()
	if runtime.cachedPlot and runtime.cachedPlot.Parent and tick() - runtime.cachedPlotAt < 5 then
		return runtime.cachedPlot
	end
	if tick() < (runtime.nextPlotLookup or 0) then
		return nil
	end
	runtime.nextPlotLookup = tick() + 2
	local ok, plotService = safeCall("FindPlotService", function()
		return require(ReplicatedStorage.Modules.ServicesLoader.ClientPlotService)
	end)
	if ok and plotService and plotService.Model then
		runtime.cachedPlot = plotService.Model
		runtime.cachedPlotAt = tick()
		runtime.nextPlotLookup = 0
		return runtime.cachedPlot
	end
	local plots = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("Plot")
	if not plots then
		return nil
	end
	local userId = tostring(LocalPlayer.UserId)
	for _, plot in ipairs(plots:GetChildren()) do
		local owner = tostring(plot:GetAttribute("Owner") or "")
		local ownerId = tostring(plot:GetAttribute("OwnerId") or plot:GetAttribute("PlayerId") or "")
		local playerName = tostring(plot:GetAttribute("Player") or "")
		if
			owner == LocalPlayer.Name
			or owner == LocalPlayer.DisplayName
			or owner == userId
			or ownerId == userId
			or playerName == LocalPlayer.Name
			or playerName == userId
		then
			runtime.cachedPlot = plot
			runtime.cachedPlotAt = tick()
			runtime.nextPlotLookup = 0
			return plot
		end
	end
	return nil
end

local function mutationFromModel(model)
	if not model then
		return "None"
	end
	for _, source in ipairs({ model, model.Parent }) do
		if source then
			local mutation = source:GetAttribute("Mutation")
			if mutation and mutation ~= "" and mutation ~= "None" then
				return normalizeMutation(mutation)
			end
		end
	end
	for _, child in ipairs(model:GetChildren()) do
		local childMutation = normalizeMutation(child.Name)
		if childMutation ~= "None" and selectionMatches(gameData.MutationOptions, childMutation, normalizeMutation) then
			return childMutation
		end
	end
	return "None"
end

function rarityFor(name, fallback)
	if fallback and fallback ~= "" and fallback ~= "Unknown" then
		return fallback
	end
	local brainrots = modules.entitiesData and modules.entitiesData.Brainrots
	return (brainrots and brainrots[name] and brainrots[name].Rarity) or fallback or "Unknown"
end

local function brainrotCps(name, mutation, level)
	local brainrots = modules.entitiesData and modules.entitiesData.Brainrots
	if not brainrots or not brainrots[name] then
		return nil
	end
	local entry = brainrots[name]
	local base = parseNumber(entry.CPS or entry.CashPerSecond or entry.BaseCPS or 0)
	local lvl = math.max(1, tonumber(level) or 1)

	-- Level scaling: check for explicit per-level data before falling back to
	-- simple linear scaling. Many games add a fixed amount per upgrade rather
	-- than multiplying the whole value.
	local leveledBase
	if entry.CPSPerLevel or entry.CashPerSecondPerLevel then
		local perLvl = parseNumber(entry.CPSPerLevel or entry.CashPerSecondPerLevel or 0)
		leveledBase = base + (lvl - 1) * perLvl
	elseif entry.LevelMultiplier then
		local m = parseNumber(entry.LevelMultiplier or 1)
		leveledBase = base * (1 + (lvl - 1) * (m - 1))
	else
		-- Default: linear (base × level). Works for most KickBlox games.
		leveledBase = base * lvl
	end

	-- Mutation multiplier
	local multiplier = 1
	local mutData = modules.mutationData
	if mutData and mutData.Mutations and mutData.Mutations[mutation] then
		multiplier = parseNumber(mutData.Mutations[mutation].Multiplier or 1)
	else
		local entitiesMut = modules.entitiesData and modules.entitiesData.Mutations
		if entitiesMut and entitiesMut[mutation] then
			multiplier = parseNumber(entitiesMut[mutation].Multiplier or entitiesMut[mutation].Boost or 1)
		elseif mutation and mutation:lower():match("^x%d+$") then
			multiplier = tonumber(mutation:sub(2)) or 1
		elseif mutation and mutation:lower():match("^%d+x$") then
			multiplier = tonumber(mutation:match("^(%d+)")) or 1
		end
	end

	return leveledBase * multiplier
end

-- Sum of CPS for all brainrots currently placed in the player's plot.
-- Returns 0 when the plot is inaccessible (used for UI display only).
local function totalPlotCps()
	local plot = findPlot()
	if not plot or not plot:FindFirstChild("Slots") then return 0 end
	local total = 0
	for _, slot in ipairs(plot.Slots:GetChildren()) do
		local placed = slot:FindFirstChild("PlacedPart")
		if placed then
			local name, mutation, level = placedBrainrotInfo(placed)
			if name then
				total = total + (brainrotCps(name, mutation, level) or 0)
			end
		end
	end
	return total
end

local function kickPower()
	local accuracy = {
		Bad = 0.05,
		Mid = 0.25,
		Good = 0.45,
		Great = 0.55,
		Excellent = 0.75,
		Perfect = 0.98,
		Cosmic = 0.99,
	}
	local divisor = 1
	if state.KickPowerMode == "Micro" then
		divisor = 100
	elseif state.KickPowerMode == "Nano" then
		divisor = 10000
	end
	return accuracy[state.TargetMinigameAccuracy] or 0.98,
		mathClamp((state.CustomKickPowerPercent or 100) / 100, 0, 1) / divisor
end

local function characterParts()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

-- Fire a remote regardless of whether it is a RemoteEvent or RemoteFunction.
-- Tries FireServer first (the common case), falls back to InvokeServer.
local function fireRemote(remote, ...)
	if not remote then return false end
	local ok = pcall(function() remote:FireServer(...) end)
	if not ok then
		ok = pcall(function() remote:InvokeServer(...) end)
	end
	return ok
end

local function currentBattleStatus()
	if tick() - runtime.cachedBattleStatusAt < 0.75 then
		return runtime.cachedBattleStatus
	end
	local status = nil
	-- Primary: read from the KickBattles UI module
	safeCall("BattleStatus", function()
		local m = require(ReplicatedStorage.Modules.UILoader.KickBattlesUI)
		if m and m.CurrentStatus ~= nil then
			status = tostring(m.CurrentStatus)
		end
	end)
	-- Fallback: player attribute set by the server
	if not status then
		local attr = LocalPlayer:GetAttribute("BattleStatus")
		if attr ~= nil then
			status = tostring(attr)
		end
	end
	-- Normalise known "not in battle" variants to nil so callers can use `== nil`
	if status == "None" or status == "" then
		status = nil
	end
	runtime.cachedBattleStatus = status
	runtime.cachedBattleStatusAt = tick()
	return status
end

local function battleTimerVisible()
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	local battleGui = gui and gui:FindFirstChild("KickBattles")
	return battleGui
		and battleGui:FindFirstChild("TopFrame")
		and battleGui.TopFrame:FindFirstChild("TimerFrame")
		and battleGui.TopFrame.TimerFrame.Visible
end

local function restoreCamera(humanoid)
	local camera = Workspace.CurrentCamera
	if camera and humanoid then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end
end

local function fastMove(root, targetCFrame, speed)
	if not root or not targetCFrame then
		return false
	end
	speed = math.max(speed or 90, 1)
	local started = tick()
	while
		state.HubRunning
		and root.Parent
		and (root.Position - targetCFrame.Position).Magnitude > 3
		and tick() - started < 12
	do
		local dt = RunService.Heartbeat:Wait()
		local current = root.Position
		local target = targetCFrame.Position
		local direction = Vector3.new(target.X - current.X, 0, target.Z - current.Z)
		local distance = direction.Magnitude
		if distance <= 0 then
			break
		end
		local step = direction.Unit * math.min(distance, speed * dt)
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		root.CFrame = CFrame.new(current.X + step.X, target.Y + 3, current.Z + step.Z)
	end
	return true
end

local function selectedDropdownKeys(selection)
	return listFromSelection(selection)
end

local function selectedDropdownValue(selection, fallback)
	local items = listFromSelection(selection)
	if items[1] ~= nil and items[1] ~= "" then
		return items[1]
	end
	if type(selection) == "string" or type(selection) == "number" or type(selection) == "boolean" then
		return tostring(selection)
	end
	return fallback
end

local intervalKeys = {
	AutoKick = "AutoKickInterval",
	AutoPlaceBest = "AutoPlaceInterval",
	Mastery = "MasteryInterval",
	RefreshData = "PlotRefreshInterval",
	AutoFavorite = "FavoriteScanInterval",
}

local minimumLoopIntervals = {
	RefreshData = 8,
	Prediction = 1,
	AutoKick = 0.3,
	Train = 0.75,
	AutoClaim2x = 2,
	CollectCash = 1.5,
	TrainCollect = 1,
	AutoPlaceBest = 1.5,
	Economy = 2,
	AutoUpgrade = 1.5,
	AutoFavorite = 4,
	WebhookStatus = 5,
	Battle = 4,
	AcceptBattle = 4,
	Mastery = 1,
	Weather = 5,
}

local supervisorEnabled = {}

local function activeAutomationCount()
	local count = 0
	for _, enabled in pairs(supervisorEnabled) do
		if enabled() then
			count = count + 1
		end
	end
	return count
end

local function refreshPerformanceMode()
	local fps = tonumber(runtime.currentFps) or 60
	local active = activeAutomationCount()
	local nextMode = "Balanced"
	if fps < 22 or active >= 8 then
		nextMode = "Safe"
	elseif fps < 34 or active >= 5 then
		nextMode = "Performance"
	elseif fps >= 48 and active <= 2 then
		nextMode = "Aggressive"
	end
	runtime.performanceMode = nextMode
	return nextMode
end

local performanceMultipliers = {
	Aggressive = 0.9,
	Balanced = 1,
	Performance = 1.25,
	Safe = 1.6,
}

local function currentLoopInterval(name, fallback)
	local key = intervalKeys[name]
	local value = key and tonumber(state[key])
	local minimum = minimumLoopIntervals[name] or 0
	local multiplier = performanceMultipliers[runtime.performanceMode or "Balanced"] or 1
	if value and value > 0 then
		return math.max(minimum, value * multiplier)
	end
	return math.max(minimum, fallback * multiplier)
end

local function shouldThrottleForFps(name)
	if not runtime.currentFps or runtime.currentFps >= 28 then
		return false
	end
	return name ~= "RefreshData" and name ~= "Prediction" and name ~= "WebhookStatus"
end

supervisorEnabled = {
	Prediction = function()
		return state.APredict
	end,
	AutoKick = function()
		return state.AFarm or state.AAutoBattle
	end,
	Train = function()
		return state.ATrain or state.ATrainCollect
	end,
	AutoClaim2x = function()
		return state.A2xTrain or state.ATrainCollect
	end,
	CollectCash = function()
		return state.ACollect or state.AAutoBattle
	end,
	TrainCollect = function()
		return state.ATrainCollect
	end,
	AutoPlaceBest = function()
		return state.APlaceBest
	end,
	Economy = function()
		return state.ABuySpeed
			or state.ABuyBest
			or state.ABuyWeights
			or state.ARebirth
			or state.APlotUpgrade
			or state.AAutoKickStyle
	end,
	AutoUpgrade = function()
		return state.AAutoUpgrade
	end,
	AutoFavorite = function()
		return state.AAutoFav
	end,
	WebhookStatus = function()
		return state.AutoStatusWebhook
	end,
	Battle = function()
		return state.AAutoBattle
	end,
	AcceptBattle = function()
		return state.AAutoAcceptBattle
	end,
	Mastery = function()
		return state.AAutoMastery
	end,
	Weather = function()
		return state.AAutoSummonWeather and state.TTargetWeatherEvent ~= "None"
	end,
}

local function makeSupervisor(name, interval, callback)
	if loopControllers[name] then
		loopControllers[name].enabled = false
		loopControllers[name] = nil
	end
	local loopState = {
		enabled = true,
		errors = 0,
		lastRun = 0,
		interval = interval,
		token = HttpService:GenerateGUID(false),
	}
	loops[name] = loopState
	loopControllers[name] = loopState
	task.spawn(function()
		local myToken = loopState.token
		while state.HubRunning and loopState.enabled and loopControllers[name] == loopState and loopState.token == myToken do
			local enabledCheck = supervisorEnabled[name]
			if enabledCheck and not enabledCheck() then
				task.wait(math.max(3, currentLoopInterval(name, interval) * 4))
			else
				local ok, err = pcall(callback)
				loopState.lastRun = tick()
				if not ok then
					if name == "AutoPlaceBest" then
						state.IsPlacingPet = false
					elseif name == "Mastery" then
						runtime.masteryBusy = false
						runtime.nextMasteryAction = tick() + 1
					end
					runtime.lastLoopError = name .. ": " .. shortError(err)
					logError("Loop:" .. name, err)
					loopState.errors = loopState.errors + 1
					if state.NotifyOnError and tick() >= (loopState.nextErrorNotify or 0) then
						loopState.nextErrorNotify = tick() + (state.UIQuietMode and 20 or 10)
						notify("Alleral", name .. " recovered: " .. tostring(err), 3)
					end
					task.wait(math.min(5, 0.5 + loopState.errors))
				else
					loopState.errors = 0
					if shouldThrottleForFps(name) then
						task.wait(math.max(2, currentLoopInterval(name, interval) * 2))
					else
						task.wait(currentLoopInterval(name, interval))
					end
				end
			end
		end
	end)
	return loopState
end

local function collectFromPlot()
	refreshRemotes()
	local plot = findPlot()
	local _, humanoid, root = characterParts()
	if not plot or not root or not humanoid or humanoid.Health <= 0 or not remotes.collect then
		return
	end
	local slots = plot:FindFirstChild("Slots")
	local buttons = plot:FindFirstChild("Buttons")
	if not slots or not buttons then
		return
	end
	local oldCFrame = root.CFrame
	for _, button in ipairs(buttons:GetChildren()) do
		local slotNumber = tonumber(button.Name:match("%d+"))
		if button:IsA("BasePart") and slotNumber then
			local slot = slots:FindFirstChild(button.Name)
			local placed = slot and slot:FindFirstChild("PlacedPart")
			if placed and placed:FindFirstChildOfClass("Model") then
				root.CFrame = button.CFrame + Vector3.new(0, 3, 0)
				task.wait(0.08)
				if firetouchinterest then
					safeCall("CollectTouchStart", function()
						firetouchinterest(root, button, 0)
					end)
					safeCall("CollectTouchEnd", function()
						firetouchinterest(root, button, 1)
					end)
				end
				safeCall("CollectCashRemote", function()
					remotes.collect:FireServer(slotNumber)
				end)
			end
		end
	end
	root.CFrame = oldCFrame
end

local function isBrainrotTool(tool)
	if not tool or not tool:IsA("Tool") then
		return false
	end
	if tool:GetAttribute("GUID") then
		return true
	end
	local brainrots = modules.entitiesData and modules.entitiesData.Brainrots
	return brainrots and brainrots[tool.Name] ~= nil
end

local recentPlaceSlots = {}
local function protectedSlotLabel(name, mutation)
	return string.format("%s [%s]", tostring(name), normalizeMutation(mutation))
end

local function placedBrainrotInfo(placed)
	if not placed then
		return nil
	end
	local name = placed:GetAttribute("ID") or placed:GetAttribute("Name")
	local mutation = normalizeMutation(placed:GetAttribute("Mutation") or "None")
	local level = placed:GetAttribute("Level") or 1
	for _, child in ipairs(placed:GetChildren()) do
		if child:IsA("Model") and not child.Name:match("Hitbox") then
			name = name or child.Name
			mutation = mutationFromModel(child)
			level = child:GetAttribute("Level") or level
			break
		end
	end
	if not name or name == "" then
		return nil
	end
	return name, mutation, tonumber(level) or 1
end

local function isProtectedBrainrot(name, mutation)
	if not state.AProtectFilter then
		return false
	end
	local label = protectedSlotLabel(name, mutation)
	for _, protectedName in ipairs(listFromSelection(state.TProtectedBrainrots)) do
		local normalized = protectedName:gsub("^%[Lv%.%d+%]%s*", "")
		if normalized == label then
			return true
		end
	end
	return false
end

local function autoPlaceBest()
	if not state.APlaceBest or state.IsPlacingPet then
		return
	end
	refreshRemotes()
	if not remotes.place then
		return
	end
	local plot = findPlot()
	local character, humanoid = characterParts()
	if not plot or not plot:FindFirstChild("Slots") or not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	local weakestSlot = nil
	local weakestCps = math.huge
	local emptySlot = nil
	for _, slot in ipairs(plot.Slots:GetChildren()) do
		local slotNumber = tonumber(slot.Name:match("%d+"))
		if slotNumber and not (recentPlaceSlots[slotNumber] and tick() - recentPlaceSlots[slotNumber] < 5) then
			local placed = slot:FindFirstChild("PlacedPart")
			local name, mutation, level = placedBrainrotInfo(placed)
			if not name then
				emptySlot = emptySlot or slotNumber
			else
				if not isProtectedBrainrot(name, mutation) then
					local cps = brainrotCps(name, mutation, level) or 0
					if cps < weakestCps then
						weakestCps = cps
						weakestSlot = slotNumber
					end
				end
			end
		end
	end
	local bestTool = nil
	local bestCps = -1
	local tools = {}
	if LocalPlayer.Backpack then
		for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
			if isBrainrotTool(tool) then
				table.insert(tools, tool)
			end
		end
	end
	local equipped = character:FindFirstChildOfClass("Tool")
	if isBrainrotTool(equipped) then
		table.insert(tools, equipped)
	end
	for _, tool in ipairs(tools) do
		local mutation = normalizeMutation(tool:GetAttribute("Mutation") or "None")
		local cps = brainrotCps(tool.Name, mutation, 1) or 0
		if cps > bestCps then
			bestCps = cps
			bestTool = tool
		end
	end
	local targetSlot = nil
	if bestTool and emptySlot then
		targetSlot = emptySlot
	elseif bestTool and weakestSlot and bestCps > weakestCps then
		targetSlot = weakestSlot
	end
	if not targetSlot then
		return
	end
	state.IsPlacingPet = true
	safeCall("AutoPlaceEquip", function()
		humanoid:EquipTool(bestTool)
	end)
	local deadline = tick() + 0.75
	while state.HubRunning and tick() < deadline do
		local equippedTool = character:FindFirstChildOfClass("Tool")
		if equippedTool and equippedTool.Name == bestTool.Name then
			break
		end
		task.wait(0.05)
	end
	local equippedTool = character:FindFirstChildOfClass("Tool")
	if equippedTool and equippedTool.Name == bestTool.Name then
		safeCall("AutoPlaceRemote", function()
			remotes.place:FireServer(targetSlot)
		end)
		recentPlaceSlots[targetSlot] = tick()
	end
	task.wait(0.2)
	state.IsPlacingPet = false
end

local function updatePlotLists(protectedDropdown, upgradeDropdown)
	local plot = findPlot()
	if not plot or not plot:FindFirstChild("Slots") then
		return
	end
	local protected = {}
	local upgrades = { "Any" }
	for _, slot in ipairs(plot.Slots:GetChildren()) do
		local placed = slot:FindFirstChild("PlacedPart")
		if placed then
			local name, mutation, level = placedBrainrotInfo(placed)
			if name then
				local label = protectedSlotLabel(name, mutation)
				table.insert(protected, string.format("[Lv.%s] %s", tostring(level), label))
				table.insert(upgrades, string.format("[Lv.%s] %s", tostring(level), label))
			end
		end
	end
	if #protected == 0 then
		protected = { "None" }
	end
	state.PlotProtectedList = protected
	state.PlotBrainrotList = upgrades
	local protectedSignature = table.concat(protected, "\0")
	local upgradeSignature = table.concat(upgrades, "\0")
	if runtime.lastProtectedSignature == protectedSignature and runtime.lastUpgradeSignature == upgradeSignature then
		return
	end
	runtime.lastProtectedSignature = protectedSignature
	runtime.lastUpgradeSignature = upgradeSignature
	safeCall("RefreshPlotDropdowns", function()
		if protectedDropdown and protectedDropdown.Refresh then
			protectedDropdown:Refresh(protected)
		elseif protectedDropdown and protectedDropdown.SetValues then
			protectedDropdown:SetValues(protected)
		end
		if upgradeDropdown and upgradeDropdown.Refresh then
			upgradeDropdown:Refresh(upgrades)
		elseif upgradeDropdown and upgradeDropdown.SetValues then
			upgradeDropdown:SetValues(upgrades)
		end
	end)
end

local weightCost

local function getSortedWeights()
	if runtime.cachedWeights then
		return runtime.cachedWeights
	end
	local weights = {}
	local weightModels = ReplicatedStorage:FindFirstChild("Objects")
		and ReplicatedStorage.Objects:FindFirstChild("WeightModels")
	if weightModels then
		for _, item in ipairs(weightModels:GetChildren()) do
			table.insert(weights, item.Name)
		end
	end
	table.sort(weights, function(a, b)
		local costA = weightCost(a)
		local costB = weightCost(b)
		return costA < costB
	end)
	runtime.cachedWeights = weights
	return weights
end

weightCost = function(weight)
	local data = modules.weightsData
	local weightData = data and ((data.Weights and data.Weights[weight]) or data[weight])
	return weightData and parseNumber(weightData.Cost or weightData.Price or 0) or 0
end

local function speedUpgradeCost(tier)
	if modules.speedData and type(modules.speedData.GetCostForLevel) == "function" then
		local ok, cost = safeCall("SpeedUpgradeCost", function()
			return modules.speedData:GetCostForLevel(tier)
		end)
		if ok and cost ~= nil then
			return coerceNumber(cost)
		end
	end
	return nil
end

local equipWeight
local getOwnedWeightTools

local function buyBestWeight()
	refreshRemotes()
	if not remotes.shopBuy and not remotes.weightEquip then
		return
	end
	local chosen = nil
	local coins = currentCoins()
	for _, weight in ipairs(getSortedWeights()) do
		local cost = weightCost(weight)
		if cost <= coins then
			chosen = weight
		end
	end
	if chosen then
		equipWeight(chosen)
	end
end

local function ownsWeight(weight)
	if not weight or weight == "None" then
		return false
	end
	for _, tool in ipairs(getOwnedWeightTools()) do
		if tool.Name == weight then
			return true
		end
	end
	return false
end

local function equipOwnedWeight(weight)
	local character, humanoid = characterParts()
	if not character or not humanoid or not weight or weight == "None" then
		return
	end
	if remotes.weightEquip then
		safeCall("EquipWeightRemote", function()
			remotes.weightEquip:FireServer(weight)
		end)
	end
	local equipped = character:FindFirstChildOfClass("Tool")
	if equipped and equipped.Name == weight then
		return
	end
	if LocalPlayer.Backpack then
		local tool = LocalPlayer.Backpack:FindFirstChild(weight)
		if tool and tool:IsA("Tool") then
			safeCall("EquipWeightTool", function()
				humanoid:EquipTool(tool)
			end)
		end
	end
end

equipWeight = function(weight)
	refreshRemotes()
	if not weight or weight == "None" then
		return
	end
	if ownsWeight(weight) then
		equipOwnedWeight(weight)
		return
	end
	runtime.nextWeightBuyAttempt[weight] = runtime.nextWeightBuyAttempt[weight] or 0
	if tick() < runtime.nextWeightBuyAttempt[weight] then
		return
	end
	runtime.nextWeightBuyAttempt[weight] = tick() + 6
	safeCall("BuyWeight", function()
		if remotes.shopBuy then
			remotes.shopBuy:FireServer("WeightShop", weight)
		end
		if remotes.weightEquip then
			remotes.weightEquip:FireServer(weight)
		end
	end)
end

getOwnedWeightTools = function()
	local tools = {}
	local character = LocalPlayer.Character
	if LocalPlayer.Backpack then
		for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
			if item:IsA("Tool") then
				table.insert(tools, item)
			end
		end
	end
	if character then
		local equipped = character:FindFirstChildOfClass("Tool")
		if equipped then
			table.insert(tools, equipped)
		end
	end
	return tools
end

local function getBestOwnedWeightTool()
	local bestTool = nil
	local bestIndex = -1
	local sorted = getSortedWeights()
	for _, tool in ipairs(getOwnedWeightTools()) do
		for index, weightName in ipairs(sorted) do
			if tool.Name == weightName and index > bestIndex then
				bestTool = tool
				bestIndex = index
			end
		end
	end
	return bestTool
end

local function equipBestOwnedWeight()
	refreshRemotes()
	local character, humanoid = characterParts()
	if not character or not humanoid then
		return nil
	end
	local tool = getBestOwnedWeightTool()
	if not tool then
		return nil
	end
	local equipped = character:FindFirstChildOfClass("Tool")
	if not equipped or equipped.Name ~= tool.Name then
		if remotes.weightEquip then
			safeCall("EquipBestWeightRemote", function()
				remotes.weightEquip:FireServer(tool.Name)
			end)
		end
		if tool.Parent == LocalPlayer.Backpack then
			safeCall("EquipBestWeightTool", function()
				humanoid:EquipTool(tool)
			end)
		end
	end
	return character:FindFirstChildOfClass("Tool") or tool
end

local function buySpeedUpgrade()
	refreshRemotes()
	if not remotes.speedUpgrade then
		return false
	end
	local coins = currentCoins()
	for _, tier in ipairs({ 3, 2, 1 }) do
		local cost = speedUpgradeCost(tier)
		if cost and coins >= cost then
			local before = currentCoins()
			safeCall("BuySpeedUpgrade", function()
				remotes.speedUpgrade:FireServer(tier)
			end)
			task.wait(0.2)
			if currentCoins() < before then
				return true
			end
		end
	end
	return false
end

local function getKickStyleOptions()
	local options = { "Default" }
	safeCall("KickStyleOptions", function()
		local folder = ReplicatedStorage.Shared.Data:FindFirstChild("KickStylesData")
		if folder then
			for _, item in ipairs(folder:GetChildren()) do
				if item:IsA("ModuleScript") and item.Name ~= "Default" then
					table.insert(options, item.Name)
				end
			end
		end
	end)
	table.sort(options)
	return options
end

local function equipKickStyle(styleName)
	refreshRemotes()
	styleName = tostring(styleName or "Default")
	if styleName == "" or styleName == "Default" then
		return
	end
	if tick() < (runtime.nextKickStyleAttempt or 0) then
		return
	end
	runtime.nextKickStyleAttempt = tick() + 10
	safeCall("KickStyleBuy", function()
		if remotes.shopBuy then
			remotes.shopBuy:FireServer("KickStyles", styleName)
		end
	end)
	safeCall("KickStyleEquip", function()
		if remotes.kickStyle then
			remotes.kickStyle:FireServer(styleName)
		elseif remotes.shopBuy then
			remotes.shopBuy:FireServer("KickStyle", styleName)
		end
	end)
end

local function rebuildUpgradeBase()
	state.TUpgradeBase = {}
	for _, name in ipairs(listFromSelection(state.TUpgrade)) do
		local base = tostring(name):gsub("^%[Lv%.%d+%]%s*", "")
		if not tableFind(state.TUpgradeBase, base) then
			table.insert(state.TUpgradeBase, base)
		end
	end
end

local function upgradeSelectionMatches(label)
	if hasWildcard(state.TUpgradeBase) then
		return true
	end
	for _, selected in ipairs(state.TUpgradeBase) do
		if tostring(selected):gsub("^%[Lv%.%d+%]%s*", "") == label then
			return true
		end
	end
	return false
end

local function webhookSeen(guid)
	if not guid then
		return true
	end
	if runtime.seenWebhookGuids[guid] then
		return true
	end
	runtime.seenWebhookGuids[guid] = true
	table.insert(runtime.seenWebhookOrder, guid)
	while #runtime.seenWebhookOrder > 500 do
		local old = table.remove(runtime.seenWebhookOrder, 1)
		runtime.seenWebhookGuids[old] = nil
	end
	return false
end

local function handleClaimedTool(tool)
	if not tool:IsA("Tool") then
		return
	end
	if not state.AWebhook or state.WebhookURL == "" then
		return
	end
	local started = tick()
	while tool.Parent and not tool:GetAttribute("GUID") and tick() - started < 3 do
		task.wait(0.1)
	end
	local guid = tool:GetAttribute("GUID")
	if webhookSeen(guid) then
		return
	end
	task.wait(0.5)
	local name = tool.Name
	local rarity = rarityFor(name, tool:GetAttribute("Rarity") or "Unknown")
	local mutation = normalizeMutation(tool:GetAttribute("Mutation") or "None")
	local matches = selectionMatches(state.WBBrainrot, name, normalizeText)
		and selectionMatches(state.WBRarity, rarity, normalizeText)
		and selectionMatches(state.WBMutation, mutation, normalizeMutation)
	if matches then
		local cps = brainrotCps(name, mutation, 1)
		sendWebhook(state.WebhookURL, {
			username = "Alleral",
			content = "@everyone",
			embeds = {
				{
					title = "New Inventory Brainrot Claimed",
					color = 16733440,
					fields = {
						{ name = "Brainrot", value = "```" .. name .. "```", inline = true },
						{ name = "Rarity", value = "```" .. rarity .. "```", inline = true },
						{ name = "Mutation", value = "```" .. mutation .. "```", inline = true },
						{
							name = "CPS",
							value = "```" .. (cps and (formatNumber(cps) .. "/s") or "N/A") .. "```",
							inline = true,
						},
						{ name = "Server JobId", value = "```" .. tostring(game.JobId) .. "```", inline = false },
					},
					footer = { text = "Alleral" },
					timestamp = DateTime.now():ToIsoDate(),
				},
			},
		})
	end
end

local function watchFavoriteTool(tool)
	if not state.AAutoFav or not tool:IsA("Tool") or runtime.favoriteTools[tool] then
		return
	end
	local toolConnections = {}
	runtime.favoriteTools[tool] = toolConnections
	local function cleanup()
		for _, connection in ipairs(toolConnections) do
			untrack(connection)
		end
		runtime.favoriteTools[tool] = nil
	end
	local function evaluate()
		if not state.AAutoFav or not tool.Parent then
			return
		end
		local guid = tool:GetAttribute("GUID")
		if not guid then
			return
		end
		local rarity = rarityFor(tool.Name, tool:GetAttribute("Rarity") or "Unknown")
		local mutation = normalizeMutation(tool:GetAttribute("Mutation") or "None")
		local matches = selectionMatches(state.TSSellBrainrot, tool.Name, normalizeText)
			and selectionMatches(state.TSSellRarity, rarity, normalizeText)
			and selectionMatches(state.TSSellMutation, mutation, normalizeMutation)
		if matches and tool:GetAttribute("Favorite") ~= true and not tableFind(runtime.favoriteQueue, guid) then
			table.insert(runtime.favoriteQueue, guid)
		end
	end
	local function add(connection)
		table.insert(toolConnections, track(connection))
	end
	add(tool.AncestryChanged:Connect(function()
		if not tool.Parent then
			cleanup()
		end
	end))
	add(tool:GetAttributeChangedSignal("Favorite"):Connect(evaluate))
	add(tool:GetAttributeChangedSignal("Rarity"):Connect(evaluate))
	add(tool:GetAttributeChangedSignal("Mutation"):Connect(evaluate))
	evaluate()
end

local function scanTools()
	local seen = {}
	if LocalPlayer.Backpack then
		for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
			if item:IsA("Tool") and not seen[item] then
				seen[item] = true
				watchFavoriteTool(item)
			end
		end
	end
	local character = LocalPlayer.Character
	if character then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") and not seen[item] then
				seen[item] = true
				watchFavoriteTool(item)
			end
		end
	end
end

state.TriggerFavScan = scanTools

local function starlightIcon(icon)
	return tostring(icon or ""):match("%d+$") or ""
end

local function starlightWait(predicate: () -> any, timeout)
	local started = tick()
	repeat
		if predicate() then
			return true
		end
		task.wait()
	until tick() - started >= (timeout or 2)
	return false
end

local function starlightId(text)
	return (tostring(text or "Element"):gsub("[^%w_]", "_"))
end

local function starlightOptions(values)
	local output = {}
	local seen = {}
	for _, value in ipairs(values or {}) do
		local normalized = tostring(value)
		if not seen[normalized] then
			seen[normalized] = true
			table.insert(output, normalized)
		end
	end
	return output
end

local function starlightSearch(values, query)
	query = tostring(query or ""):lower()
	if query == "" then
		return starlightOptions(values)
	end
	local filtered = {}
	for _, value in ipairs(values or {}) do
		local text = tostring(value)
		if text:lower():find(query, 1, true) then
			table.insert(filtered, text)
		end
	end
	return starlightOptions(filtered)
end

local MAX_RENDERED_DROPDOWN_OPTIONS = 80

local function compactStarlightOptions(values, selected, limit)
	values = starlightOptions(values)
	limit = limit or MAX_RENDERED_DROPDOWN_OPTIONS
	if #values <= limit then
		return values
	end
	local output = {}
	local seen = {}
	local function add(value)
		value = tostring(value)
		if value ~= "" and not seen[value] then
			seen[value] = true
			table.insert(output, value)
		end
	end
	if type(selected) == "table" then
		for key, value in pairs(selected) do
			if value == true then
				add(key)
			else
				add(value)
			end
		end
	elseif selected ~= nil then
		add(selected)
	end
	for _, value in ipairs(values) do
		if #output >= limit then
			break
		end
		add(value)
	end
	return output
end

local function tableClone(source)
	if type(source) ~= "table" then
		return source
	end
	local output = {}
	for key, value in pairs(source) do
		output[key] = value
	end
	return output
end

local function starlightCurrent(default, multi)
	if type(default) == "table" then
		return tableClone(default)
	end
	if default == nil or default == "" then
		return multi and {} or nil
	end
	if multi then
		local single = tostring(default)
		if single == "Any" or single == "All" then
			return {}
		end
		return { single }
	end
	return tostring(default)
end

local function setStarlightVisible(element, visible)
	starlightWait(function()
		return element and element.Instance
	end, 1)
	if element and element.Instance then
		element.Instance.Visible = visible
	end
end

local function wrapStarlightGroup(groupbox)
	local group = {}
	local serial = 0

	local function nextId(label)
		serial = serial + 1
		return starlightId(label) .. "_" .. serial
	end

	local function loggedCallback(label, callback)
		return function(...)
			if type(callback) ~= "function" then
				return
			end
			local args = { ... }
			local ok, result = safeCall("UI:" .. tostring(label), function()
				return callback(table.unpack(args))
			end, true)
			if ok then
				return result
			end
			return nil
		end
	end

	function group:AddDropdown(id, options)
		options = options or {}
		local multi = options.Multi == true or options.MultiSelection == true
		local values = starlightOptions(options.Values)
		local current = starlightCurrent(options.Default or options.CurrentValue, multi)
		local renderedValues = options.Searchable and compactStarlightOptions(values, current) or values
		local label = groupbox:CreateLabel({
			Name = options.Text or options.Name or id,
			Tooltip = options.Tooltip or options.Description,
		}, id)
		local handle = {
			Values = values,
			Selection = current,
			Dropdown = nil,
			Label = label,
			LastSearch = "",
		}
		local function safeCallback(selection)
			handle.Selection = starlightCurrent(selection, multi)
			loggedCallback(options.Text or options.Name or id, options.Callback)(selection)
		end
		local function rebuild(currentValues)
			local nextValues = currentValues or handle.Values
			if options.Searchable then
				nextValues = compactStarlightOptions(nextValues, handle.Selection)
			end
			if handle.Dropdown and handle.Dropdown.Set then
				handle.Dropdown:Set({
					Options = nextValues,
					CurrentOption = handle.Selection,
					MultipleOptions = multi,
					Placeholder = options.Placeholder or "--",
					Callback = safeCallback,
				}, id)
			end
		end
		if not starlightWait(function()
			return label.Instance and label.Instance.DropdownHolder
		end, 5) then
			function handle:SetValues(newValues, newDefault)
				self.Values = starlightOptions(newValues)
				self.Selection = starlightCurrent(newDefault or self.Selection, multi)
			end
			function handle:Refresh(newValues, newDefault)
				self:SetValues(newValues, newDefault)
			end
			function handle:Search(query)
				self.LastSearch = tostring(query or "")
			end
			notify("Starlight", "Dropdown was delayed: " .. tostring(options.Text or id), 3)
			return handle
		end
		local dropdown = label:AddDropdown({
			Options = renderedValues,
			CurrentOption = current,
			MultipleOptions = multi,
			Placeholder = options.Placeholder or "--",
			Callback = safeCallback,
		}, id)
		handle.Dropdown = dropdown
		function handle:SetValues(newValues, newDefault)
			self.Values = starlightOptions(newValues)
			self.Selection = starlightCurrent(newDefault or self.Selection, multi)
			rebuild(self.Values)
		end
		function handle:Refresh(newValues, newDefault)
			self:SetValues(newValues, newDefault)
		end
		function handle:Search(query)
			self.LastSearch = tostring(query or "")
			local filtered = self.LastSearch == "" and self.Values
				or compactStarlightOptions(starlightSearch(self.Values, self.LastSearch), self.Selection)
			rebuild(filtered)
		end
		if options.Searchable then
			local searchId = tostring(id) .. "_search"
			local searchInput = groupbox:CreateInput({
				Name = tostring(options.Text or options.Name or id) .. " Search",
				PlaceholderText = "Search...",
				RemoveTextOnFocus = false,
				Callback = loggedCallback(tostring(options.Text or options.Name or id) .. " Search", function(text)
					handle:Search(text)
				end),
			}, searchId)
			handle.SearchInput = searchInput
		end
		return handle
	end

	function group:CreateDropdown(label, values, default, callback)
		return self:AddDropdown(nextId(label), {
			Text = label,
			Values = values,
			Default = default,
			Multi = false,
			Callback = callback,
		})
	end

	function group:CreateToggle(label, default, description, callback)
		return groupbox:CreateToggle({
			Name = label,
			CurrentValue = default == true,
			Tooltip = description,
			Callback = loggedCallback(label, callback),
		}, nextId(label))
	end

	function group:CreateSlider(label, minimum, maximum, default, callback, tooltip)
		return groupbox:CreateSlider({
			Name = label,
			Range = { minimum, maximum },
			CurrentValue = tonumber(default) or minimum,
			Increment = maximum <= 5 and 0.05 or 1,
			Tooltip = tooltip,
			Callback = loggedCallback(label, callback),
		}, nextId(label))
	end

	function group:CreateButton(label, callback, tooltip)
		return groupbox:CreateButton({
			Name = label,
			Tooltip = tooltip,
			Callback = loggedCallback(label, callback),
		}, nextId(label))
	end

	function group:CreateInput(label, placeholder, icon, callback, tooltip)
		return groupbox:CreateInput({
			Name = label,
			Icon = starlightIcon(icon),
			PlaceholderText = placeholder or "",
			RemoveTextOnFocus = false,
			Tooltip = tooltip,
			Callback = loggedCallback(label, callback),
		}, nextId(label))
	end

	function group:CreateStatus(label, fields)
		local status = {
			Labels = {},
			Visible = true,
			LastValues = {},
		}
		for key, value in pairs(fields or {}) do
			local rendered = tostring(value)
			status.LastValues[key] = rendered
			status.Labels[key] = groupbox:CreateLabel({
				Name = tostring(key) .. ": " .. rendered,
			}, nextId(label .. "_" .. tostring(key)))
		end
		function status:Update(key, value)
			local rendered = tostring(value)
			if self.LastValues[key] == rendered then
				return
			end
			self.LastValues[key] = rendered
			local row = self.Labels[key]
			if row and row.Set then
				row:Set({
					Name = tostring(key) .. ": " .. rendered,
				})
			end
		end
		function status:SetVisible(visible)
			self.Visible = visible
			for _, row in pairs(self.Labels) do
				setStarlightVisible(row, visible)
			end
		end
		return status
	end

	function group:CreateDivider()
		return groupbox:CreateDivider()
	end

	function group:CreateParagraph(name, content)
		return groupbox:CreateParagraph({
			Name = name,
			Content = content,
		}, nextId(name))
	end

	return group
end

local starlightWindow = starlight:CreateWindow({
	Name = "Alleral",
	Subtitle = "Kick a Lucky Block",
	Icon = 10723407389,
	LoadingEnabled = false,
	NotifyOnCallbackError = true,
	FileSettings = {
		RootFolder = "Alleral_Configs",
		ConfigFolder = "Interface",
	},
})
local starlightSection = starlightWindow:CreateTabSection("Alleral", true)

local function createStarlightTab(name, icon)
	return starlightSection:CreateTab({
		Name = name,
		Icon = starlightIcon(icon),
		Columns = 2,
	}, starlightId(name))
end

local function createStarlightGroup(tab, name, icon, column)
	local groupbox = tab:CreateGroupbox({
		Name = name,
		Icon = starlightIcon(icon),
		Column = column or 1,
	}, starlightId(name))
	starlightWait(function()
		return groupbox.Instance and groupbox.ParentingItem
	end, 2)
	return wrapStarlightGroup(groupbox)
end

local mainTab = createStarlightTab("Kick", "rbxassetid://10723407389")
local autoTab = createStarlightTab("Plot", "rbxassetid://10734923214")
local eventsTab = createStarlightTab("Events", "rbxassetid://10709789407")
local shopTab = createStarlightTab("Inventory", "rbxassetid://10734952479")
local miscTab = createStarlightTab("Tools", "rbxassetid://10734950020")
local configTab = createStarlightTab("Settings", "rbxassetid://10734950309")

local kickGroup = createStarlightGroup(mainTab, "Kicking", "rbxassetid://10734975692", 1)
local filterGroup = createStarlightGroup(mainTab, "Filters", "rbxassetid://10734975692", 2)
local trainGroup = createStarlightGroup(mainTab, "Training", "rbxassetid://10734975692", 2)
local placeGroup = createStarlightGroup(autoTab, "Placement", "rbxassetid://10734975692", 1)
local upgradeGroup = createStarlightGroup(autoTab, "Upgrades", "rbxassetid://10734975692", 2)
local economyGroup = createStarlightGroup(autoTab, "Economy", "rbxassetid://10734975692", 1)
local battleGroup = createStarlightGroup(eventsTab, "Battle", "rbxassetid://10709789407", 1)
local masteryGroup = createStarlightGroup(eventsTab, "Mastery", "rbxassetid://10709789407", 2)
local weatherGroup = createStarlightGroup(eventsTab, "Weather", "rbxassetid://10709789407", 1)
local styleGroup = createStarlightGroup(shopTab, "Styles", "rbxassetid://10734952479", 1)
local favoriteGroup = createStarlightGroup(shopTab, "Favorites", "rbxassetid://10734952479", 2)
local serverGroup = createStarlightGroup(miscTab, "Server", "rbxassetid://10734950020", 1)
local webhookGroup = createStarlightGroup(miscTab, "Webhooks", "rbxassetid://10734950020", 2)
local configGroup = createStarlightGroup(configTab, "Alerts", "rbxassetid://10734950309", 1)
local recoveryGroup = createStarlightGroup(configTab, "Recovery", "rbxassetid://10734950309", 2)
local tuningGroup = createStarlightGroup(configTab, "Timing", "rbxassetid://10734950309", 1)
local diagnosticsGroup = createStarlightGroup(configTab, "Diagnostics", "rbxassetid://10734950309", 2)
local profileGroup = createStarlightGroup(configTab, "Profiles", "rbxassetid://10734950309", 1)
local protectedDropdown
local upgradeDropdown

local diagnosticsStatus = diagnosticsGroup:CreateStatus("Status", {
	Executor       = "detecting...",
	FPS            = "--",
	Mode           = "--",
	Loops          = "0",
	Remotes        = "--",
	["Game Build"] = "--",
	["Last Update"]= "--",
	["Error Count"]= "0",
	["Last Error"] = "--",
	["Recent Error"]= "--",
	["Log File"]   = appendFile and logFile or "Unavailable",
})

local profileFolder = "Alleral_Configs/Profiles"
local profileNameInput = "default"
local importBuffer = ""
local availableProfilesDropdown

local function sanitizeProfileName(name)
	name = trim(name):gsub("[^%w_%-%s]", ""):gsub("%s+", "_")
	if name == "" then
		name = "default"
	end
	return name:sub(1, 40)
end

local function profilePath(name)
	return string.format("%s/%s.json", profileFolder, sanitizeProfileName(name))
end

local function listProfiles()
	if not listFiles then
		return { "default" }
	end
	local profiles = {}
	local ok, files = safeCall("ListProfiles", function()
		return listFiles(profileFolder)
	end)
	if ok and type(files) == "table" then
		for _, file in ipairs(files) do
			local name = tostring(file):match("([^/\\]+)%.json$")
			if name and name ~= "" then
				table.insert(profiles, name)
			end
		end
	end
	if #profiles == 0 then
		table.insert(profiles, "default")
	end
	table.sort(profiles)
	return profiles
end

local function refreshProfilesDropdown(defaultValue)
	if availableProfilesDropdown and availableProfilesDropdown.Refresh then
		safeCall("RefreshProfilesDropdown", function()
			availableProfilesDropdown:Refresh(listProfiles(), defaultValue or profileNameInput)
		end)
	end
end

local function collectConfigSnapshot()
	local snapshot = {}
	for _, key in ipairs(savedKeys) do
		snapshot[key] = copyValue(state[key])
	end
	snapshot.__meta = {
		Version = VERSION,
		CreatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}
	return snapshot
end

local function applyConfigSnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return false, "Invalid snapshot."
	end
	for _, key in ipairs(savedKeys) do
		if snapshot[key] ~= nil then
			state[key] = copyValue(snapshot[key])
		end
	end
	rebuildUpgradeBase()
	saveSettings()
	return true, nil
end

local function saveProfile(name)
	if not writeFile then
		return false, "writefile not available."
	end
	name = sanitizeProfileName(name)
	safeCall("SaveProfile", function()
		if isFolder and makeFolder and not isFolder(profileFolder) then
			makeFolder(profileFolder)
		end
	end)
	local ok, err = safeCall("SaveProfile", function()
		writeFile(profilePath(name), HttpService:JSONEncode(collectConfigSnapshot()))
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, name
end

local function loadProfile(name)
	if not (readFile and isFile) then
		return false, "readfile/isfile not available."
	end
	name = sanitizeProfileName(name)
	if not isFile(profilePath(name)) then
		return false, "Profile not found."
	end
	local ok, decoded = safeCall("LoadProfile", function()
		return HttpService:JSONDecode(readFile(profilePath(name)))
	end)
	if not ok then
		return false, "Invalid profile JSON: " .. shortError(decoded)
	end
	return applyConfigSnapshot(decoded)
end

local function deleteProfile(name)
	if not deleteFile then
		return false, "delfile not available."
	end
	name = sanitizeProfileName(name)
	local path = profilePath(name)
	if isFile and not isFile(path) then
		return false, "Profile not found."
	end
	local ok, err = safeCall("DeleteProfile", function()
		deleteFile(path)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, nil
end

local function resetRuntimeLocks()
	state.IsPlacingPet = false
	state.IsFlashCollecting = false
	runtime.masteryBusy = false
	runtime.nextMasteryAction = 0
	runtime.nextSpeedBuyAttempt = 0
	runtime.nextBattleCreate = 0
	runtime.nextBattleInvite = 0
	runtime.nextBattleStart = 0
	runtime.lastProtectedSignature = nil
	runtime.lastUpgradeSignature = nil
	notify("Runtime", "Recovered stuck locks and cooldowns.", 3)
end

local function pauseAutomation()
	for _, key in ipairs({
		"AFarm",
		"ATrain",
		"ATrainCollect",
		"ACollect",
		"APlaceBest",
		"AAutoUpgrade",
		"AAutoBattle",
		"AAutoMastery",
		"AAutoSummonWeather",
		"AAutoFav",
	}) do
		state[key] = false
	end
	resetRuntimeLocks()
	saveSettings()
	notify("Runtime", "Automation paused.", 3)
end

local function clearErrorLog()
	runtime.errorLog = {}
	runtime.errorCounts = {}
	runtime.lastError = nil
	runtime.lastLoopError = nil
	if deleteFile and isFile and isFile(logFile) then
		safeCall("ClearErrorLog", function()
			deleteFile(logFile)
		end)
	end
	notify("Diagnostics", "Error log cleared.", 3)
end

local function totalLoggedErrors()
	local total = 0
	for _, count in pairs(runtime.errorCounts) do
		total = total + (tonumber(count) or 0)
	end
	return total
end

local function supportSummary()
	local build = runtime.gameBuild or checkGameBuild(false)
	local lines = {
		"Alleral " .. VERSION,
		"Game: " .. tostring(build and build.Name or game.Name),
		"PlaceId: " .. tostring(game.PlaceId),
		"PlaceVersion: " .. tostring(build and build.PlaceVersion or game.PlaceVersion),
		"GameUpdated: " .. tostring(build and formatRobloxTimestamp(build.Updated) or "Unknown"),
		"BuildStatus: " .. tostring(build and (build.Changed and "Changed" or "Current") or "Unknown"),
		"RuntimeMode: " .. tostring(runtime.performanceMode or "Balanced"),
		"FPS: " .. tostring(runtime.currentFps or "--"),
		"Errors: " .. tostring(totalLoggedErrors()),
		"LastError: " .. tostring(runtime.lastError or runtime.lastLoopError or "None"),
	}
	return table.concat(lines, "\n")
end

profileGroup:CreateInput(
	"Profile Name",
	"default",
	nil,
	function(value)
		profileNameInput = sanitizeProfileName(value)
	end,
	"Name for the profile to save, load, or delete."
)
profileGroup:CreateButton(
	"Save Profile",
	function()
		local ok, result = saveProfile(profileNameInput)
		if ok then
			refreshProfilesDropdown(result)
		end
		notify(ok and "Profiles" or "Profiles Error", ok and ("Saved: " .. tostring(result)) or tostring(result), 3)
	end,
	"Save current settings to a named profile file on disk."
)
profileGroup:CreateButton(
	"Load Profile",
	function()
		local ok, err = loadProfile(profileNameInput)
		notify(ok and "Profiles" or "Profiles Error", ok and ("Loaded: " .. tostring(profileNameInput)) or tostring(err), 3)
	end,
	"Load settings from the named profile file and apply them immediately."
)
profileGroup:CreateButton(
	"Delete Profile",
	function()
		local deletedName = profileNameInput
		local ok, err = deleteProfile(profileNameInput)
		if ok then
			profileNameInput = "default"
			refreshProfilesDropdown("default")
		end
		notify(ok and "Profiles" or "Profiles Error", ok and ("Deleted: " .. tostring(deletedName)) or tostring(err), 3)
	end,
	"Permanently delete the named profile file from disk."
)
profileGroup:CreateDivider()
availableProfilesDropdown = profileGroup:CreateDropdown(
	"Saved Profiles",
	listProfiles(),
	"default",
	function(value)
		profileNameInput = sanitizeProfileName(selectedDropdownValue(value, profileNameInput))
	end
)
profileGroup:CreateButton(
	"Refresh List",
	function()
		refreshProfilesDropdown(profileNameInput)
		notify("Profiles", "Profile list refreshed.", 3)
	end,
	"Reload the saved profiles list from disk."
)
profileGroup:CreateDivider()
profileGroup:CreateInput(
	"Import / Export JSON",
	"Paste exported JSON here",
	nil,
	function(value)
		importBuffer = tostring(value or "")
	end,
	"Paste an exported profile JSON to import it, or use Export to fill this box."
)
profileGroup:CreateButton(
	"Import JSON",
	function()
		local ok, decoded = safeCall("ImportProfileJson", function()
			return HttpService:JSONDecode(importBuffer)
		end)
		if not ok then
			notify("Profiles Error", "Invalid JSON: " .. shortError(decoded), 3)
			return
		end
		local applied, err = applyConfigSnapshot(decoded)
		notify(applied and "Profiles" or "Profiles Error", applied and "Imported into current config." or tostring(err), 3)
	end,
	"Apply the JSON pasted above to the current session."
)
profileGroup:CreateButton(
	"Export to Clipboard",
	function()
		local encoded = HttpService:JSONEncode(collectConfigSnapshot())
		importBuffer = encoded
		if setClipboard then
			safeCall("CopyProfileExport", function()
				setClipboard(encoded)
			end)
			notify("Profiles", "Config copied to clipboard.", 3)
		else
			notify("Profiles", "Export JSON is in the Import/Export box.", 3)
		end
	end,
	"Copy the current config as JSON to clipboard (and the Import/Export box)."
)

configGroup:CreateToggle(
	"Quiet UI Errors",
	state.UIQuietMode,
	"Suppress repeated error notifications. Errors are still logged in the Diagnostics tab.",
	function(value)
		state.UIQuietMode = value
		saveSettings()
	end
)
configGroup:CreateToggle(
	"Notify Loop Errors",
	state.NotifyOnError,
	"Show a notification whenever a background loop recovers from an error.",
	function(value)
		state.NotifyOnError = value
		saveSettings()
	end
)

recoveryGroup:CreateButton(
	"Reset Stuck States",
	resetRuntimeLocks,
	"Clear all internal locks (IsPlacingPet, masteryBusy, etc.) and cooldowns. Use when Auto Place or Mastery stops responding."
)
recoveryGroup:CreateButton(
	"Pause All Automation",
	pauseAutomation,
	"Disable every active automation toggle at once and reset all stuck states."
)
recoveryGroup:CreateButton(
	"Refresh Remotes & Plot",
	function()
		runtime.cachedRemotesAt = 0
		runtime.cachedPlotAt = 0
		runtime.nextPlotLookup = 0
		runtime.cachedPlot = nil
		runtime.remoteLookupCache = {}
		refreshRemotes()
		updatePlotLists(protectedDropdown, upgradeDropdown)
		notify("Runtime", "Remotes and plot cache refreshed.", 3)
	end,
	"Re-discover all game remotes and reload the plot. Use after a game update if remotes stop firing."
)
recoveryGroup:CreateButton(
	"Clear Webhook Cache",
	function()
		runtime.seenWebhookGuids = {}
		runtime.seenWebhookOrder = {}
		notify("Webhook", "Seen-item cache cleared.", 3)
	end,
	"Reset the seen-GUID list so previously sent webhook items can be sent again."
)
diagnosticsGroup:CreateButton(
	"Clear Error Log",
	clearErrorLog,
	"Wipe the in-memory error log and delete the on-disk log file."
)
diagnosticsGroup:CreateButton(
	"Check Game Update",
	function()
		checkGameBuild(true)
	end,
	"Fetch current game metadata and compare against your saved baseline version."
)
diagnosticsGroup:CreateButton(
	"Mark Build Reviewed",
	acceptCurrentGameBuild,
	"Save the current game version as the new baseline, clearing any update warnings."
)
diagnosticsGroup:CreateButton(
	"Copy Support Info",
	function()
		local summary = supportSummary()
		if setClipboard then
			safeCall("CopySupportInfo", function()
				setClipboard(summary)
			end, true)
			notify("Support", "Support info copied.", 3)
		else
			logError("Support", "Clipboard is not available.", summary)
			notify("Support", "Clipboard is not available. Check Diagnostics.", 4)
		end
	end,
	"Copy a debug summary (version, FPS, errors) to clipboard for bug reports."
)
diagnosticsGroup:CreateButton(
	"Refresh Status",
	function()
		checkGameBuild(true)
		notify("Support", "Status refreshed.", 3)
	end,
	"Re-check game build and refresh the Diagnostics status panel."
)

tuningGroup:CreateSlider(
	"Auto Kick Interval (sec)",
	0.3,
	2,
	state.AutoKickInterval,
	function(value)
		state.AutoKickInterval = math.max(0.3, value)
		saveSettings()
	end,
	"Seconds between Auto Kick loop ticks. Lower = faster, higher = more stable on low FPS."
)
tuningGroup:CreateSlider(
	"Auto Place Interval (sec)",
	1.5,
	5,
	state.AutoPlaceInterval,
	function(value)
		state.AutoPlaceInterval = math.max(1.5, value)
		saveSettings()
	end,
	"Seconds between Auto Place Brainrot attempts."
)
tuningGroup:CreateSlider(
	"Mastery Interval (sec)",
	1,
	5,
	state.MasteryInterval,
	function(value)
		state.MasteryInterval = math.max(1, value)
		saveSettings()
	end,
	"Seconds between mastery loop ticks."
)
tuningGroup:CreateSlider(
	"Plot Refresh Interval (sec)",
	8,
	30,
	state.PlotRefreshInterval,
	function(value)
		state.PlotRefreshInterval = math.max(8, value)
		saveSettings()
	end,
	"How often the live plot is re-read to refresh the Upgrade/Protected dropdowns."
)
tuningGroup:CreateSlider(
	"Favorite Scan Interval (sec)",
	4,
	30,
	state.FavoriteScanInterval,
	function(value)
		state.FavoriteScanInterval = math.max(4, value)
		saveSettings()
	end,
	"How often the backpack is scanned to queue new tools for auto-favoriting."
)

-- AUTO KICK (primary toggle — goes first so it's immediately visible)
kickGroup:CreateToggle(
	"Auto Kick",
	state.AFarm,
	"Kick lucky blocks automatically. Moves to KickReady, fires the kick remote, and resets when a non-matching brainrot is detected.",
	function(value)
		state.AFarm = value
		runtime.autoKickSession = runtime.autoKickSession + 1
		runtime.nextAutoKickReset = 0
		runtime.lastAutoKickActivity = tick()
		restoreCamera(select(2, characterParts()))
		saveSettings()
	end
)
kickGroup:CreateSlider(
	"Move Speed",
	40,
	220,
	state.VolcanoTweenSpeed,
	function(value)
		state.VolcanoTweenSpeed = value
		saveSettings()
	end,
	"How fast the script teleports your character to the KickReady position each kick cycle. Higher = snappier movement."
)
kickGroup:CreateDivider()
-- Kick power settings
kickGroup:CreateDropdown(
	"Minigame Accuracy",
	{ "Bad", "Mid", "Good", "Great", "Excellent", "Perfect", "Cosmic" },
	state.TargetMinigameAccuracy,
	function(value)
		state.TargetMinigameAccuracy = selectedDropdownValue(value, state.TargetMinigameAccuracy)
		saveSettings()
	end
)
kickGroup:CreateDropdown(
	"Power Scale Mode",
	{ "Normal", "Micro", "Nano" },
	state.KickPowerMode,
	function(value)
		state.KickPowerMode = selectedDropdownValue(value, state.KickPowerMode)
		saveSettings()
	end
)
kickGroup:CreateSlider(
	"Kick Power %",
	0,
	100,
	state.CustomKickPowerPercent,
	function(value)
		state.CustomKickPowerPercent = value
		saveSettings()
	end,
	"Custom power as a percentage (0–100). Only applied when Power Scale Mode is Micro or Nano."
)
kickGroup:CreateDivider()
-- Forward-declare so the toggle callback below can reference it before assignment
local predictionStatus
-- Live prediction display
kickGroup:CreateToggle(
	"Show Prediction",
	state.APredict,
	"Display the brainrot currently rolling in real-time — name, rarity, mutation, and CPS.",
	function(value)
		state.APredict = value
		saveSettings()
		if predictionStatus and predictionStatus.SetVisible then
			predictionStatus:SetVisible(value)
		end
	end
)
predictionStatus = kickGroup:CreateStatus("Prediction", {
	Brainrot     = "--",
	Rarity       = "--",
	Mutation     = "--",
	["CPS (Lv.1)"] = "--",
	["Net Gain"]   = "--",
	Filter         = "--",
})
local sessionStatus = kickGroup:CreateStatus("Session", {
	Time         = "0:00",
	Kicks        = "0",
	["Kicks/min"]= "0",
	Matches      = "0",
	Resets       = "0",
	["Best CPS"] = "--",
})
kickGroup:CreateButton(
	"Reset Session Stats",
	function()
		runtime.sessionStart    = tick()
		runtime.sessionKicks    = 0
		runtime.sessionMatches  = 0
		runtime.sessionResets   = 0
		runtime.sessionBestCps  = 0
		runtime.sessionBestName = "--"
		runtime.kickRateWindow  = {}
		runtime.kicksPerMin     = 0
		notify("Session", "Stats reset.", 2)
	end,
	"Zero out kick/match/reset counters and restart the session timer."
)
-- Roll filters (what brainrots to keep vs. reset)
filterGroup:AddDropdown("FilterBrainrot", {
	Text = "Filter: Brainrot",
	Values = gameData.BrainrotOptions,
	Default = state.TBrainrot,
	Multi = true,
	Searchable = true,
	Tooltip = "Only keep rolls that match one of these brainrots. Leave as Any to accept all.",
	Callback = function(selection)
		state.TBrainrot = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
filterGroup:AddDropdown("FilterRarity", {
	Text = "Filter: Rarity",
	Values = gameData.RarityOptions,
	Default = state.TRarity,
	Multi = true,
	Searchable = true,
	Tooltip = "Only keep rolls of these rarities. Leave as Any to accept all rarities.",
	Callback = function(selection)
		state.TRarity = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
filterGroup:AddDropdown("FilterMutation", {
	Text = "Filter: Mutation",
	Values = gameData.MutationOptions,
	Default = state.TMutation,
	Multi = true,
	Searchable = true,
	Tooltip = "Filter by mutation. Select None to match only non-mutated brainrots; Any accepts everything.",
	Callback = function(selection)
		state.TMutation = selectedDropdownKeys(selection)
		saveSettings()
	end,
})

trainGroup:CreateToggle(
	"Auto Train",
	state.ATrain,
	"Activate the equipped weight tool each tick to gain training XP. Pair with Auto Buy Best/Selected Weight.",
	function(value)
		state.ATrain = value
		saveSettings()
	end
)
trainGroup:CreateDivider()
trainGroup:CreateToggle(
	"Auto Train + Collect Cash",
	state.ATrainCollect,
	"Anchors your position, keeps training, then flash-collects all plot slots at the chosen interval.",
	function(value)
		state.ATrainCollect = value
		if value then
			local _, _, root = characterParts()
			state.TrainAnchorCFrame = root and root.CFrame or nil
			state.NextFlashCollect = 0
		else
			state.TrainAnchorCFrame = nil
		end
		saveSettings()
	end
)
trainGroup:CreateSlider(
	"Flash Collect Every (min)",
	1,
	60,
	state.TrainCollectDelay,
	function(value)
		state.TrainCollectDelay = value
		state.NextFlashCollect = tick() + (value * 60)
		saveSettings()
	end,
	"Minutes between flash-collect runs during Auto Train + Collect Cash."
)
trainGroup:CreateDivider()
trainGroup:CreateToggle(
	"Auto Collect Cash",
	state.ACollect,
	"Independently collect plot cash on a timer. Does not require a weight to be equipped.",
	function(value)
		state.ACollect = value
		saveSettings()
	end
)
trainGroup:CreateSlider(
	"Collect Every (sec)",
	1,
	600,
	state.CollectDelay,
	function(value)
		state.CollectDelay = value
		saveSettings()
	end,
	"Seconds between standalone Auto Collect Cash runs."
)

placeGroup:CreateToggle(
	"Auto Place Brainrot",
	state.APlaceBest,
	"Equip and place the highest-CPS brainrot from backpack into empty or weaker plot slots.",
	function(value)
		state.APlaceBest = value
		saveSettings()
	end
)
placeGroup:CreateDivider()
placeGroup:CreateToggle(
	"Enable Protection",
	state.AProtectFilter,
	"Prevent Auto Place from replacing the brainrots listed in Protected Brainrots below.",
	function(value)
		state.AProtectFilter = value
		saveSettings()
	end
)
protectedDropdown = placeGroup:AddDropdown("ProtectedBrainrots", {
	Text = "Protected Brainrots",
	Values = state.PlotProtectedList,
	Default = state.TProtectedBrainrots,
	Multi = true,
	Searchable = true,
	Tooltip = "Brainrots selected here will not be replaced by Auto Place. The list is refreshed from your live plot.",
	Callback = function(selection)
		state.TProtectedBrainrots = selectedDropdownKeys(selection)
		saveSettings()
	end,
})

upgradeGroup:CreateToggle(
	"Auto Upgrade Brainrot",
	state.AAutoUpgrade,
	"Automatically upgrade selected plot brainrots up to Max Level.",
	function(value)
		state.AAutoUpgrade = value
		saveSettings()
	end
)
upgradeGroup:CreateToggle(
	"Auto Upgrade Plot",
	state.APlotUpgrade,
	"Continuously fire the plot upgrade remote to level up the plot structure itself.",
	function(value)
		state.APlotUpgrade = value
		saveSettings()
	end
)
upgradeGroup:CreateDivider()
upgradeDropdown = upgradeGroup:AddDropdown("UpgradeBrainrots", {
	Text = "Upgrade Targets",
	Values = state.PlotBrainrotList,
	Default = state.TUpgrade,
	Multi = true,
	Searchable = true,
	Tooltip = "Which plot brainrots to upgrade. Leave as Any to upgrade all. List uses [Lv.X] labels from the live plot.",
	Callback = function(selection)
		state.TUpgrade = selectedDropdownKeys(selection)
		rebuildUpgradeBase()
		saveSettings()
	end,
})
upgradeGroup:CreateSlider(
	"Max Level",
	1,
	75,
	state.MaxUpLevel,
	function(value)
		state.MaxUpLevel = value
		saveSettings()
	end,
	"Stop upgrading a brainrot once it reaches this level."
)
upgradeGroup:CreateSlider(
	"Upgrade Delay (sec)",
	1,
	30,
	state.AutoUpgradeDelay,
	function(value)
		state.AutoUpgradeDelay = value
		saveSettings()
	end,
	"Seconds to wait between consecutive upgrade remote calls per slot."
)

-- Weight buying (most impactful — first)
economyGroup:CreateToggle(
	"Auto Buy Best Weight",
	state.ABuyBest,
	"Automatically purchase and equip the best weight your coins can currently afford.",
	function(value)
		state.ABuyBest = value
		saveSettings()
	end
)
economyGroup:CreateToggle(
	"Auto Buy Selected Weight",
	state.ABuyWeights,
	"Buy and equip the specific weight chosen in Target Weight below.",
	function(value)
		state.ABuyWeights = value
		saveSettings()
	end
)
state.WeightList = { "None" }
for _, weight in ipairs(getSortedWeights()) do
	table.insert(state.WeightList, weight)
end
economyGroup:CreateDropdown(
	"Target Weight",
	state.WeightList,
	state.TTargetWeight,
	function(value)
		state.TTargetWeight = selectedDropdownValue(value, state.TTargetWeight)
		saveSettings()
	end
)
economyGroup:CreateDivider()
economyGroup:CreateToggle(
	"Auto Buy Speed",
	state.ABuySpeed,
	"Continuously attempt to purchase speed upgrades from the shop when affordable.",
	function(value)
		state.ABuySpeed = value
		saveSettings()
	end
)
economyGroup:CreateDivider()
economyGroup:CreateToggle(
	"Auto Rebirth",
	state.ARebirth,
	"Fire the rebirth remote whenever it becomes available.",
	function(value)
		state.ARebirth = value
		saveSettings()
	end
)
economyGroup:CreateToggle(
	"Auto Claim 2x",
	state.A2xTrain,
	"Click the 2x training bonus button automatically whenever it appears.",
	function(value)
		state.A2xTrain = value
		saveSettings()
	end
)

local kickStyleOptions = getKickStyleOptions()
styleGroup:CreateDropdown(
	"Target Kick Style",
	kickStyleOptions,
	state.TargetKickStyle,
	function(value)
		state.TargetKickStyle = selectedDropdownValue(value, state.TargetKickStyle)
		saveSettings()
	end
)
styleGroup:CreateToggle(
	"Auto Buy & Equip Style",
	state.AAutoKickStyle,
	"Automatically purchase and equip the Target Kick Style.",
	function(value)
		state.AAutoKickStyle = value
		saveSettings()
	end
)

favoriteGroup:CreateToggle(
	"Auto Favorite",
	state.AAutoFav,
	"Automatically favorite tools that match the Brainrot / Rarity / Mutation filters below.",
	function(value)
		state.AAutoFav = value
		if value then
			scanTools()
		end
		saveSettings()
	end
)
favoriteGroup:CreateDivider()
favoriteGroup:AddDropdown("FavoriteBrainrot", {
	Text = "Fav Filter: Brainrot",
	Values = gameData.BrainrotOptions,
	Default = state.TSSellBrainrot,
	Multi = true,
	Searchable = true,
	Tooltip = "Favorite tools with these brainrot names.",
	Callback = function(selection)
		state.TSSellBrainrot = selectedDropdownKeys(selection)
		if state.AAutoFav then
			scanTools()
		end
		saveSettings()
	end,
})
favoriteGroup:AddDropdown("FavoriteRarity", {
	Text = "Fav Filter: Rarity",
	Values = gameData.RarityOptions,
	Default = state.TSSellRarity,
	Multi = true,
	Searchable = true,
	Tooltip = "Favorite tools with these rarities.",
	Callback = function(selection)
		state.TSSellRarity = selectedDropdownKeys(selection)
		if state.AAutoFav then
			scanTools()
		end
		saveSettings()
	end,
})
favoriteGroup:AddDropdown("FavoriteMutation", {
	Text = "Fav Filter: Mutation",
	Values = gameData.MutationOptions,
	Default = state.TSSellMutation,
	Multi = true,
	Searchable = true,
	Tooltip = "Favorite tools with these mutations.",
	Callback = function(selection)
		state.TSSellMutation = selectedDropdownKeys(selection)
		if state.AAutoFav then
			scanTools()
		end
		saveSettings()
	end,
})
favoriteGroup:CreateDivider()
favoriteGroup:CreateButton(
	"Sell All Brainrots",
	function()
		refreshRemotes()
		if remotes.sellAll then
			safeCall("SellAllBrainrots", function()
				remotes.sellAll:InvokeServer()
			end, true)
			notify("Alleral", "Sell All fired.", 3)
		else
			notify("Alleral", "Sell All remote not found.", 3)
		end
	end,
	"Fire the Sell All remote to sell every non-favorited brainrot in your backpack."
)

battleGroup:CreateToggle(
	"Auto Battle Lobby",
	state.AAutoBattle,
	"Create a battle lobby, invite all players in the server, and start when enough join.",
	function(value)
		state.AAutoBattle = value
		saveSettings()
	end
)
battleGroup:CreateToggle(
	"Auto Accept Invites",
	state.AAutoAcceptBattle,
	"Automatically click Accept on incoming battle invite popups.",
	function(value)
		state.AAutoAcceptBattle = value
		saveSettings()
	end
)
battleGroup:CreateDivider()
battleGroup:CreateDropdown(
	"Battle Rounds",
	{ "3", "5", "7" },
	state.BattleRounds,
	function(value)
		state.BattleRounds = selectedDropdownValue(value, state.BattleRounds)
		saveSettings()
	end
)
battleGroup:CreateToggle(
	"Use Gamepass",
	state.BattleGamepass,
	"Include the battle gamepass option when creating a lobby.",
	function(value)
		state.BattleGamepass = value
		saveSettings()
	end
)
battleGroup:CreateSlider(
	"Min Players to Start",
	2,
	5,
	state.BattleMinPlayers,
	function(value)
		state.BattleMinPlayers = value
		saveSettings()
	end,
	"Minimum number of other players needed in the lobby before it will be started."
)

-- Forward-declare so the toggle callback can reference them before they're assigned
local masteryStatus
local updateMasteryStatus

masteryGroup:CreateToggle(
	"Auto Farm Mastery",
	state.AAutoMastery,
	"Kick blocks at Mastery Kick Power, then reset via the chosen method to repeat the mastery grind.",
	function(value)
		state.AAutoMastery = value
		if not value and updateMasteryStatus then
			updateMasteryStatus("Idle")
		end
		saveSettings()
	end
)
masteryGroup:CreateDivider()
masteryGroup:CreateSlider(
	"Mastery Kick Power",
	0,
	100,
	state.MasteryKickPower,
	function(value)
		state.MasteryKickPower = value
		saveSettings()
	end,
	"Power percentage used for mastery kicks. Lower values may be needed for certain mastery tiers."
)
masteryGroup:CreateDropdown(
	"Reset Method",
	{ "Died", "TP" },
	state.MasteryResetMethod,
	function(value)
		state.MasteryResetMethod = selectedDropdownValue(value, state.MasteryResetMethod)
		saveSettings()
	end
)
masteryStatus = masteryGroup:CreateStatus("Mastery Status", {
	State = "Idle",
	["Reset Method"] = state.MasteryResetMethod,
	["Last Reset"] = "--",
})
updateMasteryStatus = function(status, extra)
	if not masteryStatus or not masteryStatus.Update then
		return
	end
	masteryStatus:Update("State", status or "Idle")
	masteryStatus:Update("Reset Method", state.MasteryResetMethod or "Died")
	if extra then
		for key, value in pairs(extra) do
			masteryStatus:Update(key, value)
		end
	end
end

local weatherOptions = { "None" }
if modules.sacrificeData and modules.sacrificeData.Recipes then
	for name in pairs(modules.sacrificeData.Recipes) do
		table.insert(weatherOptions, name)
	end
	table.sort(weatherOptions)
end
weatherGroup:CreateToggle(
	"Auto Summon Weather",
	state.AAutoSummonWeather,
	"Automatically sacrifice the required items to summon the chosen weather event.",
	function(value)
		state.AAutoSummonWeather = value
		saveSettings()
	end
)
weatherGroup:CreateDropdown(
	"Target Weather",
	weatherOptions,
	state.TTargetWeatherEvent,
	function(value)
		state.TTargetWeatherEvent = selectedDropdownValue(value, state.TTargetWeatherEvent)
		saveSettings()
	end
)

serverGroup:CreateToggle(
	"Anti AFK",
	state.AntiAFK,
	"Prevent the Roblox idle-kick by disabling the AFK connection or simulating user input.",
	function(value)
		state.AntiAFK = value
		saveSettings()
	end
)
serverGroup:CreateDivider()
serverGroup:CreateInput(
	"Server JobId / Link",
	"Paste JobId or share URL",
	nil,
	function(value)
		state.JoinJobId = trim(value)
	end,
	"Paste a Roblox share URL (contains gameInstanceId=...) or a raw JobId string."
)
serverGroup:CreateButton(
	"Join Server",
	function()
		local jobId = trim(state.JoinJobId)
		jobId = jobId:match("gameInstanceId=([%w%-]+)") or jobId:match("([%w%-]+)")
		if jobId and jobId ~= "" then
			TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
		else
			notify("Alleral", "Failed to extract JobId.", 3)
		end
	end,
	"Teleport to the server whose JobId is entered above."
)

webhookGroup:CreateToggle(
	"Enable Webhook",
	state.AWebhook,
	"Send a Discord webhook notification when a matching brainrot lands in your inventory.",
	function(value)
		state.AWebhook = value
		saveSettings()
	end
)
webhookGroup:CreateInput(
	"Webhook URL",
	"Paste Discord webhook URL",
	nil,
	function(value)
		local normalized, err = normalizeWebhookUrl(value)
		if not normalized then
			notify("Webhook Error", err, 4)
			return
		end
		state.WebhookURL = normalized
		saveSettings()
		local ok, sendError = sendWebhook(state.WebhookURL, {
			username = "Alleral",
			embeds = {
				{
					title = "Webhook Connected",
					description = "Webhook checks are active.",
					color = 16733440,
					footer = { text = "Alleral" },
					timestamp = DateTime.now():ToIsoDate(),
				},
			},
		})
		notify(ok and "Webhook Check" or "Webhook Error", ok and "Webhook connected." or sendError, 4)
	end,
	"Must be a valid Discord webhook URL (https://discord.com/api/webhooks/...)."
)
webhookGroup:CreateDivider()
-- Inventory alert filters
webhookGroup:AddDropdown("WebhookBrainrot", {
	Text = "Notify: Brainrot",
	Values = gameData.BrainrotOptions,
	Default = state.WBBrainrot,
	Multi = true,
	Searchable = true,
	Tooltip = "Only send inventory webhooks for brainrots in this list.",
	Callback = function(selection)
		state.WBBrainrot = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
webhookGroup:AddDropdown("WebhookRarity", {
	Text = "Notify: Rarity",
	Values = gameData.RarityOptions,
	Default = state.WBRarity,
	Multi = true,
	Searchable = true,
	Tooltip = "Only send inventory webhooks for brainrots with these rarities.",
	Callback = function(selection)
		state.WBRarity = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
webhookGroup:AddDropdown("WebhookMutation", {
	Text = "Notify: Mutation",
	Values = gameData.MutationOptions,
	Default = state.WBMutation,
	Multi = true,
	Searchable = true,
	Tooltip = "Only send inventory webhooks for brainrots with these mutations.",
	Callback = function(selection)
		state.WBMutation = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
webhookGroup:CreateDivider()
-- Inventory status tracker
webhookGroup:CreateToggle(
	"Auto Send Progress",
	state.AutoStatusWebhook,
	"Periodically send an inventory summary webhook listing counts by rarity.",
	function(value)
		state.AutoStatusWebhook = value
		runtime.nextStatusWebhook = tick() + (state.AutoStatusInterval * 60)
		saveSettings()
	end
)
webhookGroup:CreateSlider(
	"Status Interval (min)",
	1,
	120,
	state.AutoStatusInterval,
	function(value)
		state.AutoStatusInterval = value
		runtime.nextStatusWebhook = tick() + (value * 60)
		saveSettings()
	end,
	"How many minutes between automatic inventory status sends."
)
webhookGroup:CreateButton(
	"Send Status Now",
	function()
		runtime.nextStatusWebhook = 0
	end,
	"Force an immediate inventory summary webhook, bypassing the timer."
)
webhookGroup:CreateDivider()
-- Status summary filters
webhookGroup:AddDropdown("Status Brainrot", {
	Text = "Status Filter: Brainrot",
	Values = gameData.BrainrotOptions,
	Default = state.StatusFilterBrainrot,
	Multi = true,
	Searchable = true,
	Tooltip = "Include only these brainrots in the inventory summary.",
	Callback = function(selection)
		state.StatusFilterBrainrot = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
webhookGroup:AddDropdown("Status Rarity", {
	Text = "Status Filter: Rarity",
	Values = gameData.RarityOptions,
	Default = state.StatusFilterRarity,
	Multi = true,
	Searchable = true,
	Tooltip = "Include only these rarities in the inventory summary.",
	Callback = function(selection)
		state.StatusFilterRarity = selectedDropdownKeys(selection)
		saveSettings()
	end,
})



if predictionStatus and predictionStatus.SetVisible then
	predictionStatus:SetVisible(state.APredict)
end

local fpsFrames = 0
local fpsStarted = tick()
track(
	RunService.Heartbeat:Connect(function()
		fpsFrames = fpsFrames + 1
		local now = tick()
		if now - fpsStarted >= 1 then
			runtime.currentFps = math.floor(fpsFrames / math.max(now - fpsStarted, 0.01))
			fpsFrames = 0
			fpsStarted = now
		end
	end),
	"FpsSampler"
)

checkGameBuild(false)

task.spawn(function()
	while state.HubRunning do
		if diagnosticsStatus and diagnosticsStatus.Update then
			refreshPerformanceMode()
			local remoteCount = 0
			for _, remote in pairs(remotes) do
				if remote then
					remoteCount = remoteCount + 1
				end
			end
			local loopCount = 0
			for _ in pairs(loops) do
				loopCount = loopCount + 1
			end
			diagnosticsStatus:Update("Executor", Executor.isKnown and Executor.name or ("? " .. (Executor.rawName ~= "" and ("(" .. Executor.rawName .. ")") or "unknown")))
			diagnosticsStatus:Update("FPS", tostring(runtime.currentFps or "--"))
			diagnosticsStatus:Update("Mode", tostring(runtime.performanceMode or "Balanced"))
			diagnosticsStatus:Update("Loops", tostring(loopCount))
			diagnosticsStatus:Update("Remotes", tostring(remoteCount))
			local build = runtime.gameBuild
			diagnosticsStatus:Update(
				"Game Build",
				build and ((build.Changed and "Changed" or "Current") .. " / v" .. tostring(build.PlaceVersion or "--")) or "--"
			)
			diagnosticsStatus:Update("Last Update", build and formatRobloxTimestamp(build.Updated) or "--")
			diagnosticsStatus:Update("Error Count", tostring(totalLoggedErrors()))
			diagnosticsStatus:Update("Last Error", runtime.lastError or runtime.lastLoopError or "--")
			diagnosticsStatus:Update("Recent Error", runtime.errorLog[1] or "--")

			-- Session stats (update them here since this loop already runs every 2s)
			if sessionStatus and sessionStatus.Update then
				local elapsed = math.floor(tick() - (runtime.sessionStart or tick()))
				sessionStatus:Update("Time",    string.format("%d:%02d", math.floor(elapsed / 60), elapsed % 60))
				sessionStatus:Update("Kicks",   tostring(runtime.sessionKicks  or 0))
				sessionStatus:Update("Kicks/min", tostring(runtime.kicksPerMin or 0))
				sessionStatus:Update("Matches", tostring(runtime.sessionMatches or 0))
				sessionStatus:Update("Resets",  tostring(runtime.sessionResets  or 0))
				local bestCps = runtime.sessionBestCps or 0
				sessionStatus:Update("Best CPS", bestCps > 0 and (formatNumber(bestCps) .. "/s") or "--")
			end
		end
		task.wait(2)
	end
end)

track(
	LocalPlayer.Idled:Connect(function()
		if not state.AntiAFK then
			return
		end
		local idleConnections = getConnectionFetcher()
		local disabledIdle = false
		if idleConnections then
			safeCall("AntiAfkConnections", function()
				for _, connection in ipairs(idleConnections(LocalPlayer.Idled)) do
					if connection.Disable then
						connection:Disable()
						disabledIdle = true
					end
				end
			end)
		end
		if disabledIdle then
			return
		end
		safeCall("AntiAfkVirtualUser", function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new(0, 0))
		end)
	end),
	"AntiAfk"
)

if LocalPlayer.Backpack then
	track(
		LocalPlayer.Backpack.ChildAdded:Connect(function(child)
			if not state.AAutoFav and (not state.AWebhook or state.WebhookURL == "") then
				return
			end
			task.delay(0.25, function()
				watchFavoriteTool(child)
				handleClaimedTool(child)
			end)
		end),
		"BackpackAdded"
	)
end
track(
	LocalPlayer.CharacterAdded:Connect(function(character)
		runtime.cachedPlot = nil
		restoreCamera(character:WaitForChild("Humanoid", 5))
		track(
			character.ChildAdded:Connect(function(child)
				if not state.AAutoFav and (not state.AWebhook or state.WebhookURL == "") then
					return
				end
				task.delay(0.25, function()
					watchFavoriteTool(child)
					handleClaimedTool(child)
				end)
			end),
			"CharacterToolAdded"
		)
	end),
	"CharacterAdded"
)
if LocalPlayer.Character then
	track(
		LocalPlayer.Character.ChildAdded:Connect(function(child)
			if not state.AAutoFav and (not state.AWebhook or state.WebhookURL == "") then
				return
			end
			task.delay(0.25, function()
				watchFavoriteTool(child)
				handleClaimedTool(child)
			end)
		end),
		"CharacterToolAdded"
	)
end

makeSupervisor("RefreshData", 8, function()
	refreshRemotes()
	updatePlotLists(protectedDropdown, upgradeDropdown)
end)

makeSupervisor("Prediction", 1, function()
	if not state.APredict or not predictionStatus then
		return
	end
	local inGame = LocalPlayer:GetAttribute("InGame") or ""
	if inGame == "" then
		predictionStatus:Update("Brainrot",    "--")
		predictionStatus:Update("Rarity",      "--")
		predictionStatus:Update("Mutation",    "--")
		predictionStatus:Update("CPS (Lv.1)",  "--")
		predictionStatus:Update("Net Gain",    "--")
		predictionStatus:Update("Filter",      "--")
		return
	end

	local parts = string.split(inGame, ",")
	local name     = trim(parts[1] or "Unknown")
	local mutation = normalizeMutation(parts[2] or "None")
	-- Some game versions embed rarity at index 4 (index 3 = level sent by server)
	local serverLevel  = tonumber(parts[3])
	local serverRarity = parts[4] and trim(parts[4]) ~= "" and trim(parts[4]) or nil
	local rarity   = rarityFor(name, serverRarity or "Unknown")

	-- CPS at level 1 (a fresh drop always arrives at level 1)
	local cps1 = brainrotCps(name, mutation, 1)

	-- Net-gain: difference between this brainrot's level-1 CPS and whatever
	-- is currently the weakest slot in the plot. Tells you at a glance whether
	-- placing it would actually help.
	local netGainStr = "?"
	local plot = findPlot()
	if cps1 and plot and plot:FindFirstChild("Slots") then
		local weakestCps = math.huge
		local hasEmpty   = false
		for _, slot in ipairs(plot.Slots:GetChildren()) do
			local placed = slot:FindFirstChild("PlacedPart")
			if not placed then
				hasEmpty   = true
				weakestCps = 0
				break
			end
			local pName, pMutation, pLevel = placedBrainrotInfo(placed)
			if pName then
				local pCps = brainrotCps(pName, pMutation, pLevel) or 0
				if pCps < weakestCps then
					weakestCps = pCps
				end
			end
		end
		if weakestCps < math.huge then
			local diff = cps1 - weakestCps
			if hasEmpty then
				netGainStr = "+" .. formatNumber(cps1) .. " (slot free)"
			else
				netGainStr = (diff >= 0 and "+" or "") .. formatNumber(diff) .. "/s"
			end
		end
	end

	-- Track best match seen this session
	if cps1 and cps1 > (runtime.sessionBestCps or 0) then
		runtime.sessionBestCps = cps1
		runtime.sessionBestName = name
	end

	local matchesFilter = mainFilterMatches(name, mutation)
	predictionStatus:Update("Brainrot",   name)
	predictionStatus:Update("Rarity",     rarity)
	predictionStatus:Update("Mutation",   mutation)
	predictionStatus:Update("CPS (Lv.1)", cps1 and (formatNumber(cps1) .. "/s") or "N/A")
	predictionStatus:Update("Net Gain",   netGainStr)
	predictionStatus:Update("Filter",     matchesFilter and "Keep" or "Skip")
end)

makeSupervisor("AutoKick", 0.3, function()
	local battleStatus = currentBattleStatus()
	local battleActive = state.AAutoBattle and (battleStatus == "Battle" or battleTimerVisible())
	if not state.AFarm and not battleActive then
		return
	end
	if state.IsFlashCollecting and not battleActive then
		return
	end
	refreshRemotes()
	local character, humanoid, root = characterParts()
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local kickReady = Workspace:FindFirstChild("Areas") and Workspace.Areas:FindFirstChild("KickReady")
	if not kickReady then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera and camera.CameraSubject ~= humanoid then
		restoreCamera(humanoid)
	end
	if state.AAutoBattle then
		if not battleActive then
			return
		end
	elseif battleStatus == "Lobby" or battleStatus == "Create" then
		return
	end
	runtime.lastAutoKickActivity = tick()
	local wavesFolder = Workspace:FindFirstChild("Waves")
	local hasWave = wavesFolder and #wavesFolder:GetChildren() > 0
	local inGame = LocalPlayer:GetAttribute("InGame") or ""
	if hasWave and inGame ~= "" then
		local parts = string.split(inGame, ",")
		local shouldReset = true
		for index = 1, #parts, 2 do
			local brainrot = trim(parts[index] or "")
			local mutation = normalizeMutation(parts[index + 1] or "None")
			if brainrot == "" or brainrot == "Unknown" or mainFilterMatches(brainrot, mutation) then
					shouldReset = false
					runtime.lastAutoKickMatch = tick()
					runtime.sessionMatches = (runtime.sessionMatches or 0) + 1
					break
			end
		end
		if shouldReset and tick() >= runtime.nextAutoKickReset and tick() - runtime.lastAutoKickMatch > 5 then
			runtime.nextAutoKickReset = tick() + 10
			runtime.sessionResets = (runtime.sessionResets or 0) + 1
			restoreCamera(humanoid)
			humanoid.Health = 0
			return
		end
		if not shouldReset then
			safeCall("KickSlowModeOff", function()
				if modules.kickService and modules.kickService.SlowMode then
					modules.kickService:SlowMode(false)
				end
			end)
			humanoid.PlatformStand = true
			humanoid.MaxSlopeAngle = 89
			fastMove(root, kickReady.CFrame * CFrame.new(0, -1.5, 0), state.VolcanoTweenSpeed)
			humanoid.PlatformStand = false
			humanoid.HipHeight = humanoid:GetAttribute("DefaultHipHeight") or humanoid.HipHeight
			safeCall("KickSlowModeOn", function()
				if modules.kickService and modules.kickService.SlowMode then
					modules.kickService:SlowMode(true)
				end
			end)
		end
		return
	end
	local horizontal = Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(
		kickReady.Position.X,
		0,
		kickReady.Position.Z
	)
	if horizontal.Magnitude > 3 then
		root.CFrame = kickReady.CFrame * CFrame.new(0, 3, 0)
		return
	end
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	local hud = gui and gui:FindFirstChild("HUD")
	local kickButton = hud and hud:FindFirstChild("KickButton")
	local visible = kickButton and kickButton.Visible
	if battleActive then
		visible = true
	end
	if visible and remotes.kick then
		local accuracy, power = kickPower()
		safeCall("AutoKickRemote", function()
			remotes.kick:FireServer(accuracy, power)
		end)
		runtime.sessionKicks = (runtime.sessionKicks or 0) + 1
		-- sliding-window kicks-per-minute
		local _now = tick()
		table.insert(runtime.kickRateWindow, _now)
		while runtime.kickRateWindow[1] and _now - runtime.kickRateWindow[1] > 60 do
			table.remove(runtime.kickRateWindow, 1)
		end
		runtime.kicksPerMin = #runtime.kickRateWindow
	end
end)

makeSupervisor("Train", 0.75, function()
	if not state.ATrain and not state.ATrainCollect then
		return
	end
	if state.IsPlacingPet or state.IsFlashCollecting then
		return
	end
	local _, humanoid = characterParts()
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local tool = equipBestOwnedWeight()
	if tool and tool.Parent == LocalPlayer.Character then
		safeCall("TrainToolActivate", function()
			tool:Activate()
		end)
	else
		safeCall("TrainHumanoidState", function()
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end)
	end
end)

makeSupervisor("AutoClaim2x", 2, function()
	local connectionFetcher = getConnectionFetcher()
	if not (state.A2xTrain or state.ATrainCollect) or state.IsFlashCollecting or not connectionFetcher then
		return
	end
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	local kickUpgrades = gui and gui:FindFirstChild("KickUpgrades")
	if not kickUpgrades then
		return
	end
	for _, item in ipairs(kickUpgrades:GetChildren()) do
		if item.Name == "Bonus" then
			safeCall("Claim2xReward", function()
				for _, connection in pairs(connectionFetcher(item.MouseButton1Click)) do
					connection:Fire()
				end
				for _, connection in pairs(connectionFetcher(item.Activated)) do
					connection:Fire()
				end
			end)
		end
	end
end)

makeSupervisor("CollectCash", 1.5, function()
	local battleStatus = currentBattleStatus()
	local safeBattleCollect = state.AAutoBattle
		and (battleStatus == "Lobby" or battleStatus == "Create" or battleStatus == nil)
	if not state.ACollect and not safeBattleCollect then
		return
	end
	runtime.nextCollect = runtime.nextCollect or 0
	if tick() < runtime.nextCollect then
		return
	end
	runtime.nextCollect = tick() + state.CollectDelay
	collectFromPlot()
end)

makeSupervisor("TrainCollect", 1, function()
	if not state.ATrainCollect or tick() < (state.NextFlashCollect or 0) then
		return
	end
	local _, humanoid, root = characterParts()
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	state.IsFlashCollecting = true
	runtime.flashCollectSession = runtime.flashCollectSession + 1
	local session = runtime.flashCollectSession
	task.delay(20, function()
		if state.IsFlashCollecting and runtime.flashCollectSession == session then
			state.IsFlashCollecting = false
			state.NextFlashCollect = tick() + 10
		end
	end)
	local oldCFrame = state.TrainAnchorCFrame or root.CFrame
	local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
	local toolName = tool and tool.Name
	safeCall("TrainCollectUnequip", function()
		humanoid:UnequipTools()
	end)
	task.wait(0.15)
	collectFromPlot()
	root.CFrame = oldCFrame
	if toolName and LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild(toolName) then
		safeCall("TrainCollectReequip", function()
			humanoid:EquipTool(LocalPlayer.Backpack[toolName])
		end)
	end
	state.NextFlashCollect = tick() + (state.TrainCollectDelay * 60)
	state.IsFlashCollecting = false
end)

makeSupervisor("AutoPlaceBest", 1.5, function()
	autoPlaceBest()
end)

makeSupervisor("Economy", 2, function()
	refreshRemotes()
	if state.ABuySpeed and tick() >= (runtime.nextSpeedBuyAttempt or 0) then
		if not buySpeedUpgrade() then
			runtime.nextSpeedBuyAttempt = tick() + 5
		end
	end
	if state.ABuyBest then
		buyBestWeight()
	elseif state.ABuyWeights and state.TTargetWeight ~= "None" then
		equipWeight(state.TTargetWeight)
	end
	if state.ARebirth and remotes.rebirth then
		safeCall("AutoRebirth", function()
			remotes.rebirth:FireServer()
		end)
	end
	if state.APlotUpgrade and remotes.plotUpgrade then
		safeCall("AutoPlotUpgrade", function()
			remotes.plotUpgrade:FireServer()
		end)
	end
	if state.AAutoKickStyle then
		equipKickStyle(state.TargetKickStyle)
	end
end)

makeSupervisor("AutoUpgrade", 1.5, function()
	if not state.AAutoUpgrade then
		return
	end
	refreshRemotes()
	if not remotes.upgradeBrainrot then
		return
	end
	if #state.TUpgradeBase == 0 then
		rebuildUpgradeBase()
	end
	local plot = findPlot()
	if not plot or not plot:FindFirstChild("Slots") then
		return
	end
	for _, slot in ipairs(plot.Slots:GetChildren()) do
		local placed = slot:FindFirstChild("PlacedPart")
		local slotNumber = tonumber(slot.Name:match("%d+"))
		if placed and slotNumber then
			local name, mutation, level = placedBrainrotInfo(placed)
			local label = name and protectedSlotLabel(name, mutation)
			if name and level < state.MaxUpLevel and upgradeSelectionMatches(label) then
				safeCall("AutoUpgradeBrainrot", function()
					remotes.upgradeBrainrot:FireServer(slotNumber)
				end)
				task.wait(state.AutoUpgradeDelay)
			end
		end
	end
end)

makeSupervisor("AutoFavorite", 4, function()
	if not state.AAutoFav then
		return
	end
	refreshRemotes()
	if tick() >= (runtime.nextFavoriteScan or 0) then
		runtime.nextFavoriteScan = tick() + math.max(4, tonumber(state.FavoriteScanInterval) or 8)
		scanTools()
	end
	local guid = table.remove(runtime.favoriteQueue, 1)
	if not guid then
		return
	end
	safeCall("AutoFavoriteToggle", function()
		if remotes.toggleFavorite then
			remotes.toggleFavorite:FireServer(guid)
		else
			local network = require(ReplicatedStorage.Shared.Packages.Network)
			network.FireServer("ToggleFav", guid)
		end
	end)
end)

makeSupervisor("WebhookStatus", 5, function()
	if not state.AutoStatusWebhook and runtime.nextStatusWebhook ~= 0 then
		return
	end
	if state.WebhookURL == "" then
		return
	end
	runtime.nextStatusWebhook = runtime.nextStatusWebhook or (tick() + state.AutoStatusInterval * 60)
	if tick() < runtime.nextStatusWebhook then
		return
	end
	runtime.nextStatusWebhook = tick() + state.AutoStatusInterval * 60
	local counts = {}
	local total = 0
	local function addTool(tool)
		if not tool:IsA("Tool") then
			return
		end
		local rarity = rarityFor(tool.Name, tool:GetAttribute("Rarity") or "Unknown")
		if not selectionMatches(state.StatusFilterBrainrot, tool.Name, normalizeText) then
			return
		end
		if not selectionMatches(state.StatusFilterRarity, rarity, normalizeText) then
			return
		end
		counts[rarity] = (counts[rarity] or 0) + 1
		total = total + 1
	end
	if LocalPlayer.Backpack then
		for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
			addTool(tool)
		end
	end
	if LocalPlayer.Character then
		for _, tool in ipairs(LocalPlayer.Character:GetChildren()) do
			addTool(tool)
		end
	end
	local fields = {}
	for rarity, count in pairs(counts) do
		table.insert(fields, { name = rarity, value = "```" .. tostring(count) .. "```", inline = true })
	end
	if #fields == 0 then
		table.insert(fields, { name = "Inventory", value = "No matching brainrots.", inline = false })
	end
	table.insert(fields, { name = "Total", value = "```" .. tostring(total) .. " Brainrot```", inline = true })
	local ok, err = sendWebhook(state.WebhookURL, {
		username = "Alleral",
		embeds = {
			{
				title = "Brainrot Inventory",
				color = 16733440,
				fields = fields,
				footer = { text = "Alleral" },
				timestamp = DateTime.now():ToIsoDate(),
			},
		},
	})
	if not ok then
		logError("WebhookStatus", err)
	end
end)

makeSupervisor("Battle", 4, function()
	if not state.AAutoBattle then
		return
	end
	refreshRemotes()
	local status = currentBattleStatus()

	-- Not in any battle state: try to create a new lobby
	if status == nil and remotes.battleCreate then
		if tick() < (runtime.nextBattleCreate or 0) then
			return
		end
		runtime.nextBattleCreate = tick() + 8  -- longer cooldown avoids spam
		task.spawn(function()
			-- battleCreate is a RemoteEvent (rev_bs_battle_create), use FireServer
			safeCall("BattleCreate", function()
				fireRemote(remotes.battleCreate,
					{ GP = state.BattleGamepass, R = tonumber(state.BattleRounds) or 3 })
			end)
		end)
		return
	end

	-- In the lobby: invite all players and start when ready
	if status == "Lobby" or status == "GP" then
		if remotes.battleInvite and tick() >= (runtime.nextBattleInvite or 0) then
			runtime.nextBattleInvite = tick() + 5
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer then
					task.spawn(function()
						safeCall("BattleInvite", function()
							-- battleInvite is a RemoteEvent, use FireServer
							fireRemote(remotes.battleInvite, player)
						end)
					end)
					task.wait(0.3)
				end
			end
		end

		-- Count other players shown in the KickBattles lobby GUI
		local playersInLobby = 0
		local countedPlayers = {}
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		local battleGui = playerGui and playerGui:FindFirstChild("KickBattles")
		if battleGui then
			for _, label in ipairs(battleGui:GetDescendants()) do
				if label:IsA("TextLabel") and label.Visible and label.Text ~= "" then
					for _, player in ipairs(Players:GetPlayers()) do
						if
							player ~= LocalPlayer
							and (label.Text:find(player.DisplayName, 1, true)
								or label.Text:find(player.Name, 1, true))
						then
							if not countedPlayers[player] then
								countedPlayers[player] = true
								playersInLobby = playersInLobby + 1
							end
							break
						end
					end
				end
			end
		end
		-- Also count by Players service as a fallback (if GUI count is unreliable)
		if playersInLobby == 0 then
			playersInLobby = math.max(0, #Players:GetPlayers() - 1)
		end

		if
			remotes.battleStart
			and playersInLobby >= (state.BattleMinPlayers - 1)
			and tick() >= (runtime.nextBattleStart or 0)
		then
			runtime.nextBattleStart = tick() + 4
			safeCall("BattleStart", function()
				remotes.battleStart:FireServer()
			end)
		end
	end
end)

makeSupervisor("AcceptBattle", 4, function()
	local connectionFetcher = getConnectionFetcher()
	if not state.AAutoAcceptBattle or not connectionFetcher then
		return
	end
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	if not gui then
		return
	end
	for _, item in ipairs(gui:GetDescendants()) do
		if item:IsA("TextButton") and item.Visible and item.Active then
			local text = item.Text:lower()
			if text:find("accept") or text:find("join") or text:find("terima") then
				local parent = item.Parent
				local related = false
				while parent do
					local name = parent.Name:lower()
					if name:find("battle") or name:find("kick") then
						related = true
						break
					end
					parent = parent.Parent
				end
				if related then
					for _, connection in ipairs(connectionFetcher(item.Activated)) do
						safeCall("AcceptBattleButton", function()
							connection:Fire()
						end)
					end
				end
			end
		end
	end
end)

makeSupervisor("Mastery", 1, function()
	if not state.AAutoMastery then
		runtime.masteryBusy = false
		return
	end
	if runtime.masteryBusy or tick() < (runtime.nextMasteryAction or 0) then
		return
	end
	if state.AFarm then
		updateMasteryStatus("Paused - Auto Kick On")
		runtime.nextMasteryAction = tick() + 2
		return
	end
	runtime.masteryBusy = true

	local function finish(delay)
		runtime.nextMasteryAction = tick() + (delay or 0.6)
		runtime.masteryBusy = false
	end

	-- Wrap the entire body so masteryBusy ALWAYS gets cleared even if something
	-- throws. Without this guard a single error locks mastery forever.
	local _bodyOk, _bodyErr = pcall(function()
		updateMasteryStatus("Scanning...")
		refreshRemotes()
		local _, humanoid, root = characterParts()
		local kickReady = Workspace:FindFirstChild("Areas") and Workspace.Areas:FindFirstChild("KickReady")
		if not humanoid or not root or humanoid.Health <= 0 or not kickReady or not remotes.kick then
			updateMasteryStatus("Waiting")
			finish(1)
			return
		end
		local inGame = LocalPlayer:GetAttribute("InGame") or ""
		if inGame == "" then
			if (root.Position - kickReady.Position).Magnitude > 5 then
				updateMasteryStatus("Moving")
				root.CFrame = kickReady.CFrame * CFrame.new(0, 3, 0)
				finish(0.4)
			else
				updateMasteryStatus("Kicking...")
				safeCall("MasteryKick", function()
					remotes.kick:FireServer(0, (state.MasteryKickPower or 50) / 100)
				end)
				runtime.masteryKickCount = (runtime.masteryKickCount or 0) + 1
				finish(1.2)
			end
		elseif state.MasteryResetMethod == "TP" then
			updateMasteryStatus("Resetting (TP)")
			local timeout = tick() + 4
			while state.HubRunning and state.AAutoMastery and tick() < timeout do
				if (LocalPlayer:GetAttribute("InGame") or "") == "" then
					break
				end
				root.CFrame = kickReady.CFrame * CFrame.new(0, 3, 0)
				root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				task.wait(0.05)
			end
			-- TP out of the minigame arena entirely
			root.CFrame = kickReady.CFrame * CFrame.new(0, -8, 0)
			task.wait(0.2)
			root.CFrame = kickReady.CFrame * CFrame.new(0, 3, 0)
			finish(1)
		else
			updateMasteryStatus("Resetting (Died)")
			local gui2 = LocalPlayer:FindFirstChild("PlayerGui")
			-- KickMinigame is the minigame GUI that appears while a round is active
			local minigame = gui2 and (
				gui2:FindFirstChild("KickMinigame")
				or gui2:FindFirstChild("MinigameUI")
				or gui2:FindFirstChild("Minigame")
			)
			local timeout = tick() + 3
			if minigame then
				-- Wait for minigame to become enabled (round started)
				while not minigame.Enabled and tick() < timeout and state.AAutoMastery do
					task.wait(0.05)
				end
				-- Wait for minigame to finish
				while minigame.Enabled and tick() < timeout and state.AAutoMastery do
					task.wait(0.05)
				end
			else
				task.wait(1.5)
			end
			restoreCamera(humanoid)
			humanoid.Health = 0
			updateMasteryStatus("Resetting (Died)", { ["Last Reset"] = os.date("%H:%M:%S") })
			local oldCharacter = LocalPlayer.Character
			local respawnTimeout = tick() + 10
			while
				state.HubRunning
				and state.AAutoMastery
				and LocalPlayer.Character == oldCharacter
				and tick() < respawnTimeout
			do
				task.wait(0.1)
			end
		end
		local newCharacter = LocalPlayer.Character
		local newRoot = newCharacter and newCharacter:WaitForChild("HumanoidRootPart", 5)
		local newHumanoid = newCharacter and newCharacter:WaitForChild("Humanoid", 5)
		if newRoot and newHumanoid then
			task.wait(0.2)
			newRoot.CFrame = kickReady.CFrame * CFrame.new(0, 3, 0)
			restoreCamera(newHumanoid)
		end
		finish(1.5)
	end)
end)

local function resolveWeather(name)
	if not modules.sacrificeData or not modules.sacrificeData.Recipes then
		return nil
	end
	name = tostring(name or "")
	for recipe in pairs(modules.sacrificeData.Recipes) do
		if recipe:lower() == name:lower() then
			return recipe
		end
	end
	return nil
end

local function isWeatherActive(recipe)
	if not recipe then
		return false
	end
	if modules.weatherService and modules.weatherService.Events then
		local expiresAt = modules.weatherService.Events[recipe]
		if tonumber(expiresAt) and tonumber(expiresAt) > os.time() then
			return true
		end
	end
	if modules.weatherService and modules.weatherService.ActiveWeather then
		return modules.weatherService.ActiveWeather[recipe] == true
	end
	return false
end

local function sacrificeTools()
	local tools = {}
	local function add(container)
		if not container then
			return
		end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("GUID") then
				table.insert(tools, {
					GUID = tool:GetAttribute("GUID"),
					Name = tool.Name,
					Mutation = normalizeMutation(tool:GetAttribute("Mutation") or "None"),
				})
			end
		end
	end
	add(LocalPlayer.Backpack)
	add(LocalPlayer.Character)
	return tools
end

local function canSummonWeather(recipe)
	local recipes = modules.sacrificeData and modules.sacrificeData.Recipes
	local requirements = recipes and recipes[recipe]
	if not requirements then
		return false
	end
	local used = {}
	local available = sacrificeTools()
	for _, requirement in ipairs(requirements) do
		local neededName = requirement.Name
		local neededMutation = normalizeMutation(requirement.Mutation or "Any")
		local found = false
		for _, tool in ipairs(available) do
			if
				not used[tool.GUID]
				and tool.Name == neededName
				and (neededMutation == "Any" or neededMutation == tool.Mutation)
			then
				used[tool.GUID] = true
				found = true
				break
			end
		end
		if not found then
			return false
		end
	end
	return true
end

makeSupervisor("Weather", 5, function()
	if not state.AAutoSummonWeather or state.TTargetWeatherEvent == "None" then
		return
	end
	refreshRemotes()
	local recipe = resolveWeather(state.TTargetWeatherEvent)
	if not recipe or not remotes.weather then
		return
	end
	if not isWeatherActive(recipe) and canSummonWeather(recipe) then
		safeCall("SummonWeather", function()
			remotes.weather:FireServer(recipe)
		end)
		task.wait(5)
	end
end)

if state.AAutoFav then
	scanTools()
end

closeLoadingGui()
notify("Alleral", "v" .. VERSION .. " ready.", 5)
