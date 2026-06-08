getgenv().LuxyHub_State = getgenv().LuxyHub_State or {}

local VERSION = "5.1"

type AnyMap = { [any]: any }
type StringList = { string }
type Callback = (...any) -> any
type RuntimeState = {
	[string]: any,
	seenWebhookGuids: { [string]: boolean },
	seenWebhookOrder: StringList,
	favoriteQueue: StringList,
	favoriteTools: AnyMap,
	lastAutoKickActivity: number,
	lastAutoKickMatch: number,
	nextAutoKickReset: number,
	autoKickSession: number,
	flashCollectSession: number,
	cachedWeights: any?,
	cachedPlot: any?,
	cachedPlotAt: number,
	nextPlotLookup: number,
	cachedRemotesAt: number,
	cachedBattleStatus: any?,
	cachedBattleStatusAt: number,
	nextWeightBuyAttempt: { [string]: number },
	nextKickStyleAttempt: number,
	remoteLookupCache: AnyMap,
	errorLog: StringList,
	errorCounts: { [string]: number },
	errorLastSeen: { [string]: number },
	performanceMode: string,
}
type GameBuildInfo = {
	Name: string,
	Updated: string,
	PlaceVersion: number,
	KnownUpdated: string,
	KnownPlaceVersion: number,
	Changed: boolean,
	CheckedAt: string,
}
type ScriptState = {
	[string]: any,
	HubRunning: boolean?,
	Version: string?,
	NotifyOnError: boolean?,
	KnownGameUpdated: string?,
	KnownPlaceVersion: number?,
	UIQuietMode: boolean?,
}

local state: ScriptState = getgenv().LuxyHub_State
local connections: AnyMap = {}
local loops: AnyMap = {}
local loopControllers: AnyMap = {}
local runtime: RuntimeState = {
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

if state.LuxyHub_Unload then
	pcall(state.LuxyHub_Unload)
end

local defaults: AnyMap = {
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
}

local savedKeys: StringList = {
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
}

local function copyValue(value: any): any
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

local function trim(value: any): string
	return tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function notify(title: string?, text: string?, duration: number?)
	if runtime.ui and runtime.ui.Notification then
		pcall(function()
			runtime.ui:Notification({
				Title = title or "Luxy Hub",
				Content = text or "",
				Duration = duration or 4,
			})
		end)
		return
	end
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title or "Luxy Hub",
			Text = text or "",
			Duration = duration or 4,
		})
	end)
end

local function safeFileApi(name: string): any?
	local executorName = "unknown"
	if identifyexecutor then
		pcall(function()
			executorName = tostring(identifyexecutor()):lower()
		end)
	end
	if executorName:find("yub") or executorName:find("yubx") then
		return nil
	end
	local envGetter = getgenv or getfenv
	if not envGetter then
		return nil
	end
	local ok, env = pcall(envGetter)
	if not ok or type(env) ~= "table" then
		return nil
	end
	return env[name]
end

local writeFile = safeFileApi("writefile")
local readFile = safeFileApi("readfile")
local isFile = safeFileApi("isfile")
local makeFolder = safeFileApi("makefolder")
local isFolder = safeFileApi("isfolder")
local deleteFile = safeFileApi("delfile")
local listFiles = safeFileApi("listfiles")
local appendFile = safeFileApi("appendfile")
local setClipboard = safeFileApi("setclipboard") or safeFileApi("toclipboard")
local settingsFolder = "LuxyHub_Configs"
local settingsFile = string.format("%s/KickBlox_v4_%s.json", settingsFolder, tostring(LocalPlayer.UserId))
local logFile = string.format("%s/KickBlox_v4_%s.log", settingsFolder, tostring(LocalPlayer.UserId))

local function shortError(message: any): string
	message = tostring(message or "Unknown error"):gsub("%s+", " ")
	if #message > 220 then
		message = message:sub(1, 217) .. "..."
	end
	return message
end

local function logError(scope: string?, err: any, details: any?): string
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
		warn("[Luxy Hub] " .. line)
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

local function safeCall(scope: string, callback: Callback, notifyUser: boolean?): (boolean, any?)
	local ok, result = pcall(callback)
	if not ok then
		local message = logError(scope, result)
		if notifyUser and state.NotifyOnError then
			notify("Luxy Hub", tostring(scope or "Runtime") .. ": " .. message, 4)
		end
		return false, result
	end
	return true, result
end

local function saveSettings()
	if not writeFile then
		return
	end
	local output: AnyMap = {}
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

local function requestFunction(): any?
	local candidates = {
		(syn and syn.request) or nil,
		(http and http.request) or nil,
		(http_service and http_service.request) or nil,
		http_request,
		request,
		(fluxus and fluxus.request) or nil,
		(getgenv and getgenv().request) or nil,
		(getgenv and getgenv().http_request) or nil,
	}
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "function" then
			return candidate
		end
	end
	return nil
end

local function getConnectionFetcher(): any?
	local candidates = {
		getconnections,
		get_signal_cons,
		(getgenv and getgenv().getconnections) or nil,
		(getgenv and getgenv().get_signal_cons) or nil,
	}
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "function" then
			return candidate
		end
	end
	return nil
end

local function normalizeWebhookUrl(url: any): (string?, string?)
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

local function sendWebhook(url: string, payload: any): (boolean, string?)
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

local function formatRobloxTimestamp(value: any): string
	local text = tostring(value or "")
	if text == "" then
		return "Unknown"
	end
	text = text:gsub("T", " "):gsub("Z$", " UTC")
	return text
end

local function checkGameBuild(forceNotify: boolean?, acceptCurrent: boolean?): GameBuildInfo
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

local function acceptCurrentGameBuild(): GameBuildInfo
	local build = checkGameBuild(false, true)
	notify("Game Check", "Current game build saved as reviewed.", 5)
	return build
end

local function track(connection: any, key: any?): any?
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

local function safeFindRemote(network: any, aliases: StringList): any?
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

local function untrack(connection: any)
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

state.LuxyHub_Unload = function()
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

local function loadLuaSource(source: string?, label: string): any?
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
		return env.Starlight or env.Library or env.LuxyLib
	end
	return nil
end

local function loadLocalLua(path: string, label: string): any?
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
					return env.Starlight or env.Library or env.LuxyLib
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

local function loadRemoteLua(url: string, label: string): any?
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

local function patchStarlightSource(source: string): string
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

local function loadStarlight(): any?
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
	local localResult = loadLocalLua("new_ui_library_luxy_backup.lua", "Starlight Interface Suite local")
	if localResult and type(localResult.CreateWindow) == "function" then
		return localResult
	end
	return loadLocalLua("new_ui_library.lua", "Starlight Interface Suite fallback")
end

local starlight = loadStarlight()
if not starlight or type(starlight.CreateWindow) ~= "function" then
	logError("Starlight", "Starlight Interface Suite was not available; startup aborted.")
	return
end
runtime.ui = starlight

local gameData = loadRemoteLua(
	"https://raw.githubusercontent.com/Omnie7/Luxy-Core/main/Data/KickBlox.luau",
	"game data"
) or { BrainrotOptions = {}, RarityOptions = {}, MutationOptions = {} }

local function withAny(options: { any }?): StringList
	local output: StringList = { "Any" }
	local seen = { Any = true, All = true, None = true, ["--"] = true }
	for _, option in ipairs(options or {}) do
		if not seen[option] then
			table.insert(output, option)
			seen[option] = true
		end
	end
	return output
end

safeCall("LoadMutationData", function()
	local mutationData = require(ReplicatedStorage.Shared.Data.MutationData)
	if mutationData and mutationData.ValidMutations then
		gameData.MutationOptions = mutationData.ValidMutations
	end
end)
gameData.BrainrotOptions = withAny(gameData.BrainrotOptions)
gameData.RarityOptions = withAny(gameData.RarityOptions)
gameData.MutationOptions = withAny(gameData.MutationOptions)

local function listFromSelection(selection: any): StringList
	if type(selection) == "string" then
		return { selection }
	end
	if type(selection) ~= "table" then
		return {}
	end
	local output: StringList = {}
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

local function tableFind(tbl: any, value: any): boolean
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

local function hasWildcard(selection: any): boolean
	selection = listFromSelection(selection)
	return #selection == 0 or tableFind(selection, "Any") or tableFind(selection, "All")
end

local function normalizeText(value: any): string
	local text = trim(value)
	text = text:gsub("[%%[%]%(%){}]", " ")
	text = text:gsub("[%s_-]+", " ")
	return trim(text)
end


local function normalizeMutation(value: any): string
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

local function selectionMatches(selection: any, value: any, normalizer: (any) -> string): boolean
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
local function mainFilterMatches(brainrot: any, mutation: any): boolean
	local brainrotOk = selectionMatches(state.TBrainrot, brainrot, normalizeText)
	local rarityOk = selectionMatches(state.TRarity, rarityFor(brainrot, "Unknown"), normalizeText)
	local mutationOk = selectionMatches(state.TMutation, mutation, normalizeMutation)
	if not hasWildcard(state.TMutation) and normalizeMutation(mutation) == "None" then
		mutationOk = false
	end
	return brainrotOk and rarityOk and mutationOk
end

local function parseNumber(value: any): number
	if type(value) == "number" then
		return value
	end
	local text = tostring(value or ""):gsub("[,%s%$]", "")
	local mantissa, exponent = text:match("^(%-?[%d%.]+)%s*,%s*(%-?%d+)$")
	if mantissa and exponent then
		return (tonumber(mantissa) or 0) * (10 ^ (tonumber(exponent) or 0))
	end
	local number, suffix = text:match("^([%d%.]+)(%a*)$")
	local valueNumber = tonumber(number or text) or 0
	local powers: { [string]: number } = { K = 3, M = 6, B = 9, T = 12, Q = 15, Qi = 18, S = 21, Sp = 24, O = 27, N = 30, D = 33 }
	if suffix and powers[suffix] then
		return valueNumber * (10 ^ powers[suffix])
	end
	return valueNumber
end

local function mathClamp(value: number, min: number, max: number): number
	return math.min(math.max(value, min), max)
end

local function formatNumber(value: any): string
	value = parseNumber(value)
	if value < 1000 then
		return tostring(math.floor(value))
	end
	local suffixes = { "K", "M", "B", "T", "Q", "Qi", "S", "Sp", "O", "N", "D" }
	local index = math.floor(math.log10(value) / 3)
	return string.format("%.2f%s", value / (10 ^ (index * 3)), suffixes[index] or ""):gsub("%.00", "")
end

local function coerceNumber(value: any): number
	if type(value) == "table" then
		local first = value.First or value.first or value[1] or 0
		local second = value.Second or value.second or value[2] or 0
		return (tonumber(first) or 0) * (10 ^ (tonumber(second) or 0))
	end
	return parseNumber(value)
end

local modules: AnyMap = {
	entitiesData = nil,
	weightsData = nil,
	speedData = nil,
	rebirthData = nil,
	sacrificeData = nil,
	kickService = nil,
	balanceService = nil,
	rebirthService = nil,
	weatherService = nil,
}

local function loadModule(key: string, label: string, resolver: Callback): any?
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

local values: AnyMap = {
	coins = modules.balanceService and parseNumber(modules.balanceService.Balance) or 0,
	kickLevel = modules.kickService and modules.kickService.Level or 0,
	rebirthLevel = modules.rebirthService and modules.rebirthService.RebirthLevel or 0,
}

local function currentCoins(): number
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

local remotes: AnyMap = {}

local function refreshRemotes()
	if tick() - runtime.cachedRemotesAt < 5 then
		return
	end
	runtime.cachedRemotesAt = tick()
	local network = ReplicatedStorage:FindFirstChild("Shared")
	network = network and network:FindFirstChild("Packages")
	network = network and network:FindFirstChild("Network")
	remotes.kick = safeFindRemote(network, { "rev_KickEvent", "KickEvent", "rev_kickevent" })
	remotes.collect = safeFindRemote(network, { "rev_B_Collect", "B_Collect", "Collect" })
	remotes.upgradeBrainrot = safeFindRemote(network, { "rev_B_Upgrade", "B_Upgrade", "UpgradeBrainrot" })
	remotes.speedUpgrade = safeFindRemote(network, { "rev_SPEED_UPGRADE", "SPEED_UPGRADE", "SpeedUpgrade" })
	remotes.shopBuy = safeFindRemote(network, { "rev_Shop_Buy", "Shop_Buy", "ShopBuy" })
	remotes.weightEquip = safeFindRemote(network, { "rev_WeightEquip", "WeightEquip" })
	remotes.sellAll = safeFindRemote(network, { "ref_B_SellAll", "B_SellAll", "SellAll" })
	remotes.toggleFavorite = safeFindRemote(network, { "rev_ToggleFav", "ToggleFav" })
	remotes.rebirth = safeFindRemote(network, { "rev_RebirthRequest", "RebirthRequest", "Rebirth" })
	remotes.plotUpgrade = safeFindRemote(network, { "rev_bs_upgrade", "bs_upgrade", "PlotUpgrade" })
	remotes.weather = safeFindRemote(network, { "rev_sbe", "sbe", "SummonWeather" })
	remotes.place = safeFindRemote(network, { "rev_S_Interact", "S_Interact", "PlaceBrainrot" })
	remotes.battleCreate = safeFindRemote(network, { "ref_battle_create", "battle_create" })
	remotes.battleInvite = safeFindRemote(network, { "ref_battle_invite", "battle_invite" })
	remotes.battleStart = safeFindRemote(network, { "rev_battle_start", "battle_start" })
	remotes.kickStyle = safeFindRemote(network, { "rev_KickStyleEquip", "KickStyleEquip" })
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
	local base = parseNumber(brainrots[name].CPS or brainrots[name].CashPerSecond or 0)
	local multiplier = 1
	local mutationData = modules.entitiesData and modules.entitiesData.Mutations
	if mutationData and mutationData[mutation] then
		multiplier = parseNumber(mutationData[mutation].Multiplier or mutationData[mutation].Boost or 1)
	elseif mutation and mutation:lower():match("^x%d+$") then
		multiplier = tonumber(mutation:sub(2)) or 1
	end
	return base * multiplier * math.max(1, tonumber(level) or 1)
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

local function currentBattleStatus()
	if tick() - runtime.cachedBattleStatusAt < 0.75 then
		return runtime.cachedBattleStatus
	end
	local status = nil
	safeCall("BattleStatus", function()
		status = require(ReplicatedStorage.Modules.UILoader.KickBattlesUI).CurrentStatus
	end)
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
	local values = listFromSelection(selection)
	if values[1] ~= nil and values[1] ~= "" then
		return values[1]
	end
	if type(selection) == "string" or type(selection) == "number" or type(selection) == "boolean" then
		return tostring(selection)
	end
	return fallback
end

local intervalKeys: { [string]: string } = {
	AutoKick = "AutoKickInterval",
	AutoPlaceBest = "AutoPlaceInterval",
	Mastery = "MasteryInterval",
	RefreshData = "PlotRefreshInterval",
	AutoFavorite = "FavoriteScanInterval",
}

local minimumLoopIntervals: { [string]: number } = {
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

local supervisorEnabled: { [string]: () -> boolean }

local function activeAutomationCount(): number
	local count = 0
	for _, enabled in pairs(supervisorEnabled) do
		if enabled() then
			count = count + 1
		end
	end
	return count
end

local function refreshPerformanceMode(): string
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

local performanceMultipliers: { [string]: number } = {
	Aggressive = 0.9,
	Balanced = 1,
	Performance = 1.25,
	Safe = 1.6,
}

local function currentLoopInterval(name: string, fallback: number): number
	local key = intervalKeys[name]
	local value = key and tonumber(state[key])
	local minimum = minimumLoopIntervals[name] or 0
	local multiplier = performanceMultipliers[runtime.performanceMode or "Balanced"] or 1
	if value and value > 0 then
		return math.max(minimum, value * multiplier)
	end
	return math.max(minimum, fallback * multiplier)
end

local function shouldThrottleForFps(name: string): boolean
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

local function makeSupervisor(name: string, interval: number, callback: Callback): AnyMap
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
						notify("Luxy Hub", name .. " recovered: " .. tostring(err), 3)
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
			local placedName = placedBrainrotInfo(placed)
			if not placed or not placedName then
				emptySlot = emptySlot or slotNumber
			else
				local name, mutation, level = placedBrainrotInfo(placed)
				if name then
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
		if not cost or coins >= cost then
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
	if matches and state.AWebhook and state.WebhookURL ~= "" then
		local cps = brainrotCps(name, mutation, 1)
		sendWebhook(state.WebhookURL, {
			username = "Luxy Hub",
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
					footer = { text = "Luxy Hub" },
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

local function starlightIcon(icon: any): any?
	return tostring(icon or ""):match("%d+$") or ""
end

local function starlightWait(predicate: () -> any, timeout: number?): boolean
	local started = tick()
	repeat
		if predicate() then
			return true
		end
		task.wait()
	until tick() - started >= (timeout or 2)
	return false
end

local function starlightId(text: any): string
	return (tostring(text or "Element"):gsub("[^%w_]", "_"))
end

local function starlightOptions(values: any): StringList
	local output: StringList = {}
	local seen: { [string]: boolean } = {}
	for _, value in ipairs(values or {}) do
		local normalized = tostring(value)
		if not seen[normalized] then
			seen[normalized] = true
			table.insert(output, normalized)
		end
	end
	return output
end

local function starlightSearch(values: any, query: any): StringList
	query = tostring(query or ""):lower()
	if query == "" then
		return starlightOptions(values)
	end
	local filtered: StringList = {}
	for _, value in ipairs(values or {}) do
		local text = tostring(value)
		if text:lower():find(query, 1, true) then
			table.insert(filtered, text)
		end
	end
	return starlightOptions(filtered)
end

local MAX_RENDERED_DROPDOWN_OPTIONS = 80

local function compactStarlightOptions(values: any, selected: any, limit: number?): StringList
	values = starlightOptions(values)
	limit = limit or MAX_RENDERED_DROPDOWN_OPTIONS
	if #values <= limit then
		return values
	end
	local output: StringList = {}
	local seen: { [string]: boolean } = {}
	local function add(value: any)
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

local function tableClone(source: any): any
	if type(source) ~= "table" then
		return source
	end
	local output: AnyMap = {}
	for key, value in pairs(source) do
		output[key] = value
	end
	return output
end

local function starlightCurrent(default: any, multi: boolean?): any
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

local function setStarlightVisible(element: any, visible: boolean)
	starlightWait(function()
		return element and element.Instance
	end, 1)
	if element and element.Instance then
		element.Instance.Visible = visible
	end
end

local function wrapStarlightGroup(groupbox: any): AnyMap
	local group: AnyMap = {}
	local serial = 0

	local function nextId(label: any): string
		serial = serial + 1
		return starlightId(label) .. "_" .. serial
	end

	local function loggedCallback(label: any, callback: Callback?): Callback
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

	function group:AddDropdown(id: string, options: AnyMap)
		options = options or {}
		local multi = options.Multi == true or options.MultiSelection == true
		local values = starlightOptions(options.Values)
		local current = starlightCurrent(options.Default or options.CurrentValue, multi)
		local renderedValues = options.Searchable and compactStarlightOptions(values, current) or values
		local label = groupbox:CreateLabel({
			Name = options.Text or options.Name or id,
			Tooltip = options.Tooltip or options.Description,
		}, id)
		local handle: AnyMap = {
			Values = values,
			Selection = current,
			Dropdown = nil,
			Label = label,
			LastSearch = "",
		}
		local function safeCallback(selection: any)
			handle.Selection = starlightCurrent(selection, multi)
			loggedCallback(options.Text or options.Name or id, options.Callback)(selection)
		end
		local function rebuild(currentValues: any?)
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

	function group:CreateDropdown(label: string, values: any, default: any, callback: Callback?)
		return self:AddDropdown(nextId(label), {
			Text = label,
			Values = values,
			Default = default,
			Multi = false,
			Callback = callback,
		})
	end

	function group:CreateToggle(label: string, default: boolean?, description: string?, callback: Callback?)
		return groupbox:CreateToggle({
			Name = label,
			CurrentValue = default == true,
			Tooltip = description,
			Callback = loggedCallback(label, callback),
		}, nextId(label))
	end

	function group:CreateSlider(label: string, minimum: number, maximum: number, default: number?, callback: Callback?)
		return groupbox:CreateSlider({
			Name = label,
			Range = { minimum, maximum },
			CurrentValue = tonumber(default) or minimum,
			Increment = maximum <= 5 and 0.05 or 1,
			Callback = loggedCallback(label, callback),
		}, nextId(label))
	end

	function group:CreateButton(label: string, callback: Callback?)
		return groupbox:CreateButton({
			Name = label,
			Callback = loggedCallback(label, callback),
		}, nextId(label))
	end

	function group:CreateInput(label: string, placeholder: string?, icon: any?, callback: Callback?)
		return groupbox:CreateInput({
			Name = label,
			Icon = starlightIcon(icon),
			PlaceholderText = placeholder or "",
			RemoveTextOnFocus = false,
			Callback = loggedCallback(label, callback),
		}, nextId(label))
	end

	function group:CreateStatus(label: string, fields: AnyMap)
		local status: AnyMap = {
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
		function status:Update(key: any, value: any)
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
		function status:SetVisible(visible: boolean)
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

	return group
end

local starlightWindow = starlight:CreateWindow({
	Name = "Luxy Hub",
	Subtitle = "Kick a Lucky Block",
	Icon = 10723407389,
	LoadingEnabled = false,
	NotifyOnCallbackError = true,
	FileSettings = {
		RootFolder = "LuxyHub_Configs",
		ConfigFolder = "Interface",
	},
})
local starlightSection = starlightWindow:CreateTabSection("Luxy Hub", true)

local function createStarlightTab(name: string, icon: any): any
	return starlightSection:CreateTab({
		Name = name,
		Icon = starlightIcon(icon),
		Columns = 2,
	}, starlightId(name))
end

local function createStarlightGroup(tab: any, name: string, icon: any, column: number?): AnyMap
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
local protectedDropdown: any?
local upgradeDropdown: any?

local diagnosticsStatus = diagnosticsGroup:CreateStatus("Status", {
	FPS = "--",
	Mode = "--",
	Loops = "0",
	Remotes = "--",
	["Game Build"] = "--",
	["Last Update"] = "--",
	["Error Count"] = "0",
	["Last Error"] = "--",
	["Recent Error"] = "--",
	["Log File"] = appendFile and logFile or "Unavailable",
})

local profileFolder = "LuxyHub_Configs/Profiles"
local profileNameInput: string = "default"
local importBuffer: string = ""
local availableProfilesDropdown: any?

local function sanitizeProfileName(name: any): string
	name = trim(name):gsub("[^%w_%-%s]", ""):gsub("%s+", "_")
	if name == "" then
		name = "default"
	end
	return name:sub(1, 40)
end

local function profilePath(name: any): string
	return string.format("%s/%s.json", profileFolder, sanitizeProfileName(name))
end

local function listProfiles(): StringList
	if not listFiles then
		return { "default" }
	end
	local profiles: StringList = {}
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

local function refreshProfilesDropdown(defaultValue: any?)
	if availableProfilesDropdown and availableProfilesDropdown.Refresh then
		safeCall("RefreshProfilesDropdown", function()
			availableProfilesDropdown:Refresh(listProfiles(), defaultValue or profileNameInput)
		end)
	end
end

local function collectConfigSnapshot(): AnyMap
	local snapshot: AnyMap = {}
	for _, key in ipairs(savedKeys) do
		snapshot[key] = copyValue(state[key])
	end
	snapshot.__meta = {
		Version = VERSION,
		CreatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}
	return snapshot
end

local function applyConfigSnapshot(snapshot: any): (boolean, string?)
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

local function saveProfile(name: any): (boolean, string)
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

local function loadProfile(name: any): (boolean, string?)
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

local function deleteProfile(name: any): (boolean, string?)
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

local function totalLoggedErrors(): number
	local total = 0
	for _, count in pairs(runtime.errorCounts) do
		total = total + (tonumber(count) or 0)
	end
	return total
end

local function supportSummary(): string
	local build = runtime.gameBuild or checkGameBuild(false)
	local lines = {
		"Luxy Hub " .. VERSION,
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

profileGroup:CreateInput("Profile", "default", nil, function(value)
	profileNameInput = sanitizeProfileName(value)
end)
profileGroup:CreateButton("Save", function()
	local ok, result = saveProfile(profileNameInput)
	if ok then
		refreshProfilesDropdown(result)
	end
	notify(ok and "Profiles" or "Profiles Error", ok and ("Saved: " .. tostring(result)) or tostring(result), 3)
end)
profileGroup:CreateButton("Load", function()
	local ok, err = loadProfile(profileNameInput)
	notify(ok and "Profiles" or "Profiles Error", ok and ("Loaded: " .. tostring(profileNameInput)) or tostring(err), 3)
end)
profileGroup:CreateButton("Delete", function()
	local deletedName = profileNameInput
	local ok, err = deleteProfile(profileNameInput)
	if ok then
		profileNameInput = "default"
		refreshProfilesDropdown("default")
	end
	notify(ok and "Profiles" or "Profiles Error", ok and ("Deleted: " .. tostring(deletedName)) or tostring(err), 3)
end)
availableProfilesDropdown = profileGroup:CreateDropdown("Saved Profiles", listProfiles(), "default", function(value)
	profileNameInput = sanitizeProfileName(selectedDropdownValue(value, profileNameInput))
end)
profileGroup:CreateInput("Import JSON", "Paste JSON", nil, function(value)
	importBuffer = tostring(value or "")
end)
profileGroup:CreateButton("Import", function()
	local ok, decoded = safeCall("ImportProfileJson", function()
		return HttpService:JSONDecode(importBuffer)
	end)
	if not ok then
		notify("Profiles Error", "Invalid JSON: " .. shortError(decoded), 3)
		return
	end
	local applied, err = applyConfigSnapshot(decoded)
	notify(applied and "Profiles" or "Profiles Error", applied and "Imported into current config." or tostring(err), 3)
end)
profileGroup:CreateButton("Export", function()
	local encoded = HttpService:JSONEncode(collectConfigSnapshot())
	importBuffer = encoded
	if setClipboard then
		safeCall("CopyProfileExport", function()
			setClipboard(encoded)
		end)
		notify("Profiles", "Current config copied to clipboard.", 3)
	else
		notify("Profiles", "Export JSON is ready in the import box.", 3)
	end
end)
profileGroup:CreateButton("Refresh List", function()
	refreshProfilesDropdown(profileNameInput)
	notify("Profiles", "Profile list refreshed.", 3)
end)

configGroup:CreateToggle("Quiet UI Errors", state.UIQuietMode, "Limit repeated notifications", function(value)
	state.UIQuietMode = value
	saveSettings()
end)
configGroup:CreateToggle("Notify Loop Errors", state.NotifyOnError, "Show recovered loop errors", function(value)
	state.NotifyOnError = value
	saveSettings()
end)

recoveryGroup:CreateButton("Reset Stuck States", resetRuntimeLocks)
recoveryGroup:CreateButton("Pause All Automation", pauseAutomation)
recoveryGroup:CreateButton("Refresh Remotes & Plot", function()
	runtime.cachedRemotesAt = 0
	runtime.cachedPlotAt = 0
	runtime.nextPlotLookup = 0
	runtime.cachedPlot = nil
	runtime.remoteLookupCache = {}
	refreshRemotes()
	updatePlotLists(protectedDropdown, upgradeDropdown)
	notify("Runtime", "Remotes and plot cache refreshed.", 3)
end)
recoveryGroup:CreateButton("Clear Webhook Cache", function()
	runtime.seenWebhookGuids = {}
	runtime.seenWebhookOrder = {}
	notify("Webhook", "Seen-item cache cleared.", 3)
end)
diagnosticsGroup:CreateButton("Clear Error Log", clearErrorLog)
diagnosticsGroup:CreateButton("Check Game Update", function()
	checkGameBuild(true)
end)
diagnosticsGroup:CreateButton("Mark Build Reviewed", acceptCurrentGameBuild)
diagnosticsGroup:CreateButton("Copy Support Info", function()
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
end)
diagnosticsGroup:CreateButton("Refresh Status", function()
	checkGameBuild(true)
	notify("Support", "Status refreshed.", 3)
end)

tuningGroup:CreateSlider("Auto Kick Interval", 0.3, 2, state.AutoKickInterval, function(value)
	state.AutoKickInterval = math.max(0.3, value)
	saveSettings()
end)
tuningGroup:CreateSlider("Auto Place Interval", 1.5, 5, state.AutoPlaceInterval, function(value)
	state.AutoPlaceInterval = math.max(1.5, value)
	saveSettings()
end)
tuningGroup:CreateSlider("Mastery Interval", 1, 5, state.MasteryInterval, function(value)
	state.MasteryInterval = math.max(1, value)
	saveSettings()
end)
tuningGroup:CreateSlider("Plot Refresh Interval", 8, 30, state.PlotRefreshInterval, function(value)
	state.PlotRefreshInterval = math.max(8, value)
	saveSettings()
end)
tuningGroup:CreateSlider("Favorite Scan Interval", 4, 30, state.FavoriteScanInterval, function(value)
	state.FavoriteScanInterval = math.max(4, value)
	saveSettings()
end)

kickGroup:AddDropdown("FilterBrainrot", {
	Text = "Filter Brainrot",
	Values = gameData.BrainrotOptions,
	Default = state.TBrainrot,
	Multi = true,
	Searchable = true,
	Callback = function(selection)
		state.TBrainrot = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
kickGroup:AddDropdown("FilterRarity", {
	Text = "Filter Rarity",
	Values = gameData.RarityOptions,
	Default = state.TRarity,
	Multi = true,
	Searchable = true,
	Callback = function(selection)
		state.TRarity = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
kickGroup:AddDropdown("FilterMutation", {
	Text = "Filter Mutation",
	Values = gameData.MutationOptions,
	Default = state.TMutation,
	Multi = true,
	Searchable = true,
	Callback = function(selection)
		state.TMutation = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
kickGroup:CreateDropdown(
	"Minigame Accuracy",
	{ "Bad", "Mid", "Good", "Great", "Excellent", "Perfect", "Cosmic" },
	state.TargetMinigameAccuracy,
	function(value)
		state.TargetMinigameAccuracy = selectedDropdownValue(value, state.TargetMinigameAccuracy)
		saveSettings()
	end
)
kickGroup:CreateDropdown("Power Scale Mode", { "Normal", "Micro", "Nano" }, state.KickPowerMode, function(value)
	state.KickPowerMode = selectedDropdownValue(value, state.KickPowerMode)
	saveSettings()
end)
kickGroup:CreateSlider("Set Kick Power", 0, 100, state.CustomKickPowerPercent, function(value)
	state.CustomKickPowerPercent = value
	saveSettings()
end)
local predictionStatus = kickGroup:CreateStatus("Prediction", {
	Brainrot = "--",
	Rarity = "--",
	Mutation = "--",
	["CPS Value"] = "--",
})
kickGroup:CreateToggle("Prediction", state.APredict, "Show current in-game target", function(value)
	state.APredict = value
	saveSettings()
	if predictionStatus and predictionStatus.SetVisible then
		predictionStatus:SetVisible(value)
	end
end)
kickGroup:CreateToggle("Auto Kick", state.AFarm, "Kick and manage lucky block rolls", function(value)
	state.AFarm = value
	runtime.autoKickSession = runtime.autoKickSession + 1
	runtime.nextAutoKickReset = 0
	runtime.lastAutoKickActivity = tick()
	restoreCamera(select(2, characterParts()))
	saveSettings()
end)
kickGroup:CreateSlider("Tween Speed", 40, 220, state.VolcanoTweenSpeed, function(value)
	state.VolcanoTweenSpeed = value
	saveSettings()
end)

trainGroup:CreateToggle("Auto Train", state.ATrain, "Train equipped weight", function(value)
	state.ATrain = value
	saveSettings()
end)
trainGroup:CreateToggle("Auto Train + Collect Cash", state.ATrainCollect, "Train and collect plot cash", function(value)
	state.ATrainCollect = value
	if value then
		local _, _, root = characterParts()
		state.TrainAnchorCFrame = root and root.CFrame or nil
		state.NextFlashCollect = 0
	else
		state.TrainAnchorCFrame = nil
	end
	saveSettings()
end)
trainGroup:CreateSlider("Cash Collect (Delay)", 1, 60, state.TrainCollectDelay, function(value)
	state.TrainCollectDelay = value
	state.NextFlashCollect = tick() + (value * 60)
	saveSettings()
end)
trainGroup:CreateToggle("Auto Collect Cash", state.ACollect, "Collect plot cash", function(value)
	state.ACollect = value
	saveSettings()
end)
trainGroup:CreateSlider("Collect Delay", 1, 600, state.CollectDelay, function(value)
	state.CollectDelay = value
	saveSettings()
end)

protectedDropdown = placeGroup:AddDropdown("ProtectedBrainrots", {
	Text = "Protected Brainrots",
	Values = state.PlotProtectedList,
	Default = state.TProtectedBrainrots,
	Multi = true,
	Searchable = true,
	Callback = function(selection)
		state.TProtectedBrainrots = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
placeGroup:CreateToggle("Enable Protection", state.AProtectFilter, "Protect selected plot brainrots", function(value)
	state.AProtectFilter = value
	saveSettings()
end)
placeGroup:CreateToggle("Auto Place Brainrot", state.APlaceBest, "Place stronger brainrots in plot", function(value)
	state.APlaceBest = value
	saveSettings()
end)

upgradeDropdown = upgradeGroup:AddDropdown("UpgradeBrainrots", {
	Text = "Upgrade Brainrots",
	Values = state.PlotBrainrotList,
	Default = state.TUpgrade,
	Multi = true,
	Searchable = true,
	Callback = function(selection)
		state.TUpgrade = selectedDropdownKeys(selection)
		rebuildUpgradeBase()
		saveSettings()
	end,
})
upgradeGroup:CreateSlider("Max Level", 1, 75, state.MaxUpLevel, function(value)
	state.MaxUpLevel = value
	saveSettings()
end)
upgradeGroup:CreateSlider("Upgrade Delay", 1, 30, state.AutoUpgradeDelay, function(value)
	state.AutoUpgradeDelay = value
	saveSettings()
end)
upgradeGroup:CreateToggle(
	"Auto Upgrade Brainrot",
	state.AAutoUpgrade,
	"Upgrade matching plot brainrots",
	function(value)
		state.AAutoUpgrade = value
		saveSettings()
	end
)
upgradeGroup:CreateToggle("Auto Upgrade Plot", state.APlotUpgrade, "Upgrade plot buttons", function(value)
	state.APlotUpgrade = value
	saveSettings()
end)

economyGroup:CreateToggle("Auto Claim 2x", state.A2xTrain, "Claim 2x train rewards", function(value)
	state.A2xTrain = value
	saveSettings()
end)
economyGroup:CreateToggle("Auto Rebirth", state.ARebirth, "Rebirth when available", function(value)
	state.ARebirth = value
	saveSettings()
end)
economyGroup:CreateToggle("Auto Buy Speed", state.ABuySpeed, "Upgrade speed", function(value)
	state.ABuySpeed = value
	saveSettings()
end)
economyGroup:CreateToggle("Auto Buy Best Weight", state.ABuyBest, "Buy best affordable weight", function(value)
	state.ABuyBest = value
	saveSettings()
end)
economyGroup:CreateToggle("Auto Buy Selected Weight", state.ABuyWeights, "Buy selected weight", function(value)
	state.ABuyWeights = value
	saveSettings()
end)

state.WeightList = { "None" }
for _, weight in ipairs(getSortedWeights()) do
	table.insert(state.WeightList, weight)
end
local kickStyleOptions = getKickStyleOptions()
styleGroup:CreateDropdown("Target Weight", state.WeightList, state.TTargetWeight, function(value)
	state.TTargetWeight = selectedDropdownValue(value, state.TTargetWeight)
	saveSettings()
end)
styleGroup:CreateDropdown("Target Kick Style", kickStyleOptions, state.TargetKickStyle, function(value)
	state.TargetKickStyle = selectedDropdownValue(value, state.TargetKickStyle)
	saveSettings()
end)
styleGroup:CreateToggle(
	"Auto Buy & Equip Style",
	state.AAutoKickStyle,
	"Purchase and equip kick style automatically",
	function(value)
		state.AAutoKickStyle = value
		saveSettings()
	end
)

favoriteGroup:AddDropdown("FavoriteBrainrot", {
	Text = "Favorite Brainrot",
	Values = gameData.BrainrotOptions,
	Default = state.TSSellBrainrot,
	Multi = true,
	Searchable = true,
	Callback = function(selection)
		state.TSSellBrainrot = selectedDropdownKeys(selection)
		if state.AAutoFav then
			scanTools()
		end
		saveSettings()
	end,
})
favoriteGroup:AddDropdown("FavoriteRarity", {
	Text = "Favorite Rarity",
	Values = gameData.RarityOptions,
	Default = state.TSSellRarity,
	Multi = true,
	Searchable = true,
	Callback = function(selection)
		state.TSSellRarity = selectedDropdownKeys(selection)
		if state.AAutoFav then
			scanTools()
		end
		saveSettings()
	end,
})
favoriteGroup:AddDropdown("FavoriteMutation", {
	Text = "Favorite Mutation",
	Values = gameData.MutationOptions,
	Default = state.TSSellMutation,
	Multi = true,
	Searchable = true,
	Callback = function(selection)
		state.TSSellMutation = selectedDropdownKeys(selection)
		if state.AAutoFav then
			scanTools()
		end
		saveSettings()
	end,
})
favoriteGroup:CreateToggle("Auto Favorite Filter", state.AAutoFav, "Favorite matching tools", function(value)
	state.AAutoFav = value
	if value then
		scanTools()
	end
	saveSettings()
end)
favoriteGroup:CreateButton("Sell All Brainrots", function()
	refreshRemotes()
	if remotes.sellAll then
		safeCall("SellAllBrainrots", function()
			remotes.sellAll:InvokeServer()
		end, true)
		notify("Luxy Hub", "Sell All fired.", 3)
	else
		notify("Luxy Hub", "Sell All remote not found.", 3)
	end
end)

battleGroup:CreateDropdown("Battle Rounds", { "3", "5", "7" }, state.BattleRounds, function(value)
	state.BattleRounds = selectedDropdownValue(value, state.BattleRounds)
	saveSettings()
end)
battleGroup:CreateToggle("Enable Gamepass", state.BattleGamepass, "Use battle gamepass option", function(value)
	state.BattleGamepass = value
	saveSettings()
end)
battleGroup:CreateSlider("Min Players to Start", 2, 5, state.BattleMinPlayers, function(value)
	state.BattleMinPlayers = value
	saveSettings()
end)
battleGroup:CreateToggle("Auto Battle Lobby", state.AAutoBattle, "Create and start battle lobbies", function(value)
	state.AAutoBattle = value
	saveSettings()
end)
battleGroup:CreateToggle("Auto Accept Battle Invites", state.AAutoAcceptBattle, "Accept battle invites", function(value)
	state.AAutoAcceptBattle = value
	saveSettings()
end)

masteryGroup:CreateSlider("Kick Power", 0, 100, state.MasteryKickPower, function(value)
	state.MasteryKickPower = value
	saveSettings()
end)
masteryGroup:CreateDropdown("Reset Method", { "Died", "TP" }, state.MasteryResetMethod, function(value)
	state.MasteryResetMethod = selectedDropdownValue(value, state.MasteryResetMethod)
	saveSettings()
end)
local masteryStatus = masteryGroup:CreateStatus("Mastery Status", {
	State = "Idle",
	["Reset Method"] = state.MasteryResetMethod,
	["Last Reset"] = "--",
})
local function updateMasteryStatus(status, extra)
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
masteryGroup:CreateToggle("Auto Farm Mastery", state.AAutoMastery, "Farm kick mastery", function(value)
	state.AAutoMastery = value
	if not value then
		updateMasteryStatus("Idle")
	end
	saveSettings()
end)

local weatherOptions = { "None" }
if modules.sacrificeData and modules.sacrificeData.Recipes then
	for name in pairs(modules.sacrificeData.Recipes) do
		table.insert(weatherOptions, name)
	end
	table.sort(weatherOptions)
end
weatherGroup:CreateDropdown("Target Weather", weatherOptions, state.TTargetWeatherEvent, function(value)
	state.TTargetWeatherEvent = selectedDropdownValue(value, state.TTargetWeatherEvent)
	saveSettings()
end)
weatherGroup:CreateToggle("Auto Summon Weather", state.AAutoSummonWeather, "Summon selected weather", function(value)
	state.AAutoSummonWeather = value
	saveSettings()
end)

serverGroup:CreateInput("Join Server Link / JobId", "Paste JobId here", nil, function(value)
	state.JoinJobId = trim(value)
end)
serverGroup:CreateButton("Join Server Instance", function()
	local jobId = trim(state.JoinJobId)
	jobId = jobId:match("gameInstanceId=([%w%-]+)") or jobId:match("([%w%-]+)")
	if jobId and jobId ~= "" then
		TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
	else
		notify("Luxy Hub", "Failed to extract JobId.", 3)
	end
end)

webhookGroup:AddDropdown("WebhookBrainrot", {
	Text = "Webhook Brainrot",
	Values = gameData.BrainrotOptions,
	Default = state.WBBrainrot,
	Multi = true,
	Searchable = true,
	Callback = function(selection)
		state.WBBrainrot = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
webhookGroup:AddDropdown("WebhookRarity", {
	Text = "Webhook Rarity",
	Values = gameData.RarityOptions,
	Default = state.WBRarity,
	Multi = true,
	Searchable = true,
	Callback = function(selection)
		state.WBRarity = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
webhookGroup:AddDropdown("WebhookMutation", {
	Text = "Webhook Mutation",
	Values = gameData.MutationOptions,
	Default = state.WBMutation,
	Multi = true,
	Searchable = true,
	Callback = function(selection)
		state.WBMutation = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
webhookGroup:CreateInput("Webhook URL", "Paste Discord webhook", nil, function(value)
	local normalized, err = normalizeWebhookUrl(value)
	if not normalized then
		notify("Webhook Error", err, 4)
		return
	end
	state.WebhookURL = normalized
	saveSettings()
	local ok, sendError = sendWebhook(state.WebhookURL, {
		username = "Luxy Hub",
		embeds = {
			{
				title = "Webhook Connected",
				description = "Webhook checks are active.",
				color = 16733440,
				footer = { text = "Luxy Hub" },
				timestamp = DateTime.now():ToIsoDate(),
			},
		},
	})
	notify(ok and "Webhook Check" or "Webhook Error", ok and "Webhook connected." or sendError, 4)
end)
webhookGroup:CreateToggle("Enable Webhook", state.AWebhook, "Send filtered inventory webhooks", function(value)
	state.AWebhook = value
	saveSettings()
end)
webhookGroup:AddDropdown("Status Brainrot", {
	Text = "Tracker Filter: Brainrot",
	Values = gameData.BrainrotOptions,
	Default = state.StatusFilterBrainrot,
	Multi = true,
	Searchable = true,
	Callback = function(selection)
		state.StatusFilterBrainrot = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
webhookGroup:AddDropdown("Status Rarity", {
	Text = "Tracker Filter: Rarity",
	Values = gameData.RarityOptions,
	Default = state.StatusFilterRarity,
	Multi = true,
	Searchable = true,
	Callback = function(selection)
		state.StatusFilterRarity = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
webhookGroup:CreateSlider("Auto Send Interval (Mins)", 1, 120, state.AutoStatusInterval, function(value)
	state.AutoStatusInterval = value
	runtime.nextStatusWebhook = tick() + (value * 60)
	saveSettings()
end)
webhookGroup:CreateToggle("Auto Send Progress", state.AutoStatusWebhook, "Send inventory status", function(value)
	state.AutoStatusWebhook = value
	runtime.nextStatusWebhook = tick() + (state.AutoStatusInterval * 60)
	saveSettings()
end)
webhookGroup:CreateButton("Send Tracker Check Now", function()
	runtime.nextStatusWebhook = 0
end)

serverGroup:CreateToggle("Anti AFK", state.AntiAFK, "Prevent idle kick", function(value)
	state.AntiAFK = value
	saveSettings()
end)

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

makeSupervisor("RefreshData", 5, function()
	refreshRemotes()
	updatePlotLists(protectedDropdown, upgradeDropdown)
end)

makeSupervisor("Prediction", 0.3, function()
	if not state.APredict or not predictionStatus then
		return
	end
	local inGame = LocalPlayer:GetAttribute("InGame") or ""
	if inGame == "" then
		predictionStatus:Update("Brainrot", "--")
		predictionStatus:Update("Rarity", "--")
		predictionStatus:Update("Mutation", "--")
		predictionStatus:Update("CPS Value", "--")
		return
	end
	local parts = string.split(inGame, ",")
	local name = trim(parts[1] or "Unknown")
	local mutation = normalizeMutation(parts[2] or "None")
	local rarity = rarityFor(name, "Unknown")
	local cps = brainrotCps(name, mutation, 1)
	predictionStatus:Update("Brainrot", name)
	predictionStatus:Update("Rarity", rarity)
	predictionStatus:Update("Mutation", mutation)
	predictionStatus:Update("CPS Value", cps and (formatNumber(cps) .. "/s") or "N/A")
end)

makeSupervisor("AutoKick", 0.2, function()
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
				break
			end
		end
		if shouldReset and tick() >= runtime.nextAutoKickReset and tick() - runtime.lastAutoKickMatch > 5 then
			runtime.nextAutoKickReset = tick() + 10
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
	end
end)

makeSupervisor("Train", 0.45, function()
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

makeSupervisor("AutoClaim2x", 0.6, function()
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

makeSupervisor("CollectCash", 1, function()
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

makeSupervisor("TrainCollect", 0.5, function()
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

makeSupervisor("AutoPlaceBest", 1.25, function()
	autoPlaceBest()
end)

makeSupervisor("Economy", 1, function()
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

makeSupervisor("AutoUpgrade", 0.8, function()
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

makeSupervisor("AutoFavorite", 1.25, function()
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

makeSupervisor("WebhookStatus", 2, function()
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
		username = "Luxy Hub",
		embeds = {
			{
				title = "Brainrot Inventory",
				color = 16733440,
				fields = fields,
				footer = { text = "Luxy Hub" },
				timestamp = DateTime.now():ToIsoDate(),
			},
		},
	})
	if not ok then
		logError("WebhookStatus", err)
	end
end)

makeSupervisor("Battle", 3, function()
	if not state.AAutoBattle then
		return
	end
	refreshRemotes()
	local status = currentBattleStatus()
	if (status == nil or status == "None" or status == "") and remotes.battleCreate then
		if tick() < (runtime.nextBattleCreate or 0) then
			return
		end
		runtime.nextBattleCreate = tick() + 5
		task.spawn(function()
			safeCall("BattleCreate", function()
				remotes.battleCreate:InvokeServer({ GP = state.BattleGamepass, R = tonumber(state.BattleRounds) or 3 })
			end)
		end)
	elseif status == "Lobby" then
		if remotes.battleInvite and tick() >= (runtime.nextBattleInvite or 0) then
			runtime.nextBattleInvite = tick() + 5
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer then
					task.spawn(function()
						safeCall("BattleInvite", function()
							remotes.battleInvite:InvokeServer(player)
						end)
					end)
					task.wait(0.3)
				end
			end
		end
		local playersInLobby = 0
		local countedPlayers = {}
		local battleGui = LocalPlayer:FindFirstChild("PlayerGui")
			and LocalPlayer.PlayerGui:FindFirstChild("KickBattles")
		if battleGui then
			for _, label in ipairs(battleGui:GetDescendants()) do
				if label:IsA("TextLabel") and label.Visible and label.Text ~= "" then
					for _, player in ipairs(Players:GetPlayers()) do
						if
							player ~= LocalPlayer
							and (label.Text:find(player.DisplayName) or label.Text:find(player.Name))
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

makeSupervisor("AcceptBattle", 2, function()
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

makeSupervisor("Mastery", 0.6, function()
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
			finish(1.2)
		end
	elseif state.MasteryResetMethod == "TP" then
		updateMasteryStatus("Resetting (TP)")
		local timeout = tick() + 3
		while state.HubRunning and state.AAutoMastery and tick() < timeout do
			if (LocalPlayer:GetAttribute("InGame") or "") == "" then
				break
			end
			root.CFrame = kickReady.CFrame * CFrame.new(0, 3, 0)
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			task.wait(0.05)
		end
		root.CFrame = kickReady.CFrame * CFrame.new(0, -5, 0)
		finish(1)
	else
		updateMasteryStatus("Resetting (Died)")
		local gui = LocalPlayer:FindFirstChild("PlayerGui")
		local minigame = gui and gui:FindFirstChild("KickMinigame")
		local timeout = tick() + 2.5
		if minigame then
			while not minigame.Enabled and tick() < timeout and state.AAutoMastery do
				task.wait(0.05)
			end
			while minigame.Enabled and tick() < timeout and state.AAutoMastery do
				task.wait(0.05)
			end
		else
			task.wait(1.5)
		end
		restoreCamera(humanoid)
		local oldHipHeight = humanoid:GetAttribute("DefaultHipHeight") or humanoid.HipHeight
		humanoid.HipHeight = oldHipHeight
		humanoid.Health = 0
		updateMasteryStatus("Resetting (Died)", { ["Last Reset"] = os.date("%H:%M:%S") })
		local oldCharacter = LocalPlayer.Character
		local respawnTimeout = tick() + 8
		while
			state.HubRunning
			and state.AAutoMastery
			and LocalPlayer.Character == oldCharacter
			and tick() < respawnTimeout
		do
			task.wait(0.1)
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
	end
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

makeSupervisor("Weather", 2, function()
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
notify("Luxy Hub", "v" .. VERSION .. " ready.", 5)
