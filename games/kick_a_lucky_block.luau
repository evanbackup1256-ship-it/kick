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

getgenv().Alleral_State = getgenv().Alleral_State or {}

if not getgenv().Alleral_Boot then
	warn("[Alleral] run loader.luau first")
	return
end
getgenv().Alleral_Boot = nil

local VERSION = "6.5"

local state = getgenv().Alleral_State
local connections = {}
local loops = {}
local loopControllers = {}
local runtime = {
	seenWebhookGuids = {},
	seenWebhookOrder = {},
	favoriteQueue = {},
	favoriteTools = {},
	lastAutoKickMatch = 0,
	nextAutoKickReset = 0,
	flashCollectSession = 0,
	cachedWeights = nil,
	brainrotCpsCache = {},
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
	kickRateWindow = {},
	kicksPerMin = 0,
	nextAutoSell = 0,
	lastRareNotify = "",
	lastHighlightRoll = "",
	lastHighlightRollAt = 0,
	nextAcceptBattleScan = 0,
	nextBattleLobbyScan = 0,
	cachedBattleLobbyCount = 0,
	plotListRefreshPending = false,
	rebirthLevel = 0,
	kickLevel = 0,
	waveResetBusy = false,
	nextPlotUpgrade = 0,
	nextRebirthAttempt = 0,
	kickLevelBound = false,
	rebirthLevelBound = false,
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

local Tracker = getgenv().Alleral_Analytics
if not Tracker then
	local ok, loaded = pcall(function()
		local env = getgenv and getgenv() or {}
		local readFileFn = env.readfile
		local isFileFn = env.isfile
		local loadStringLocal = env.loadstring or loadstring
		local source
		if type(readFileFn) == "function" and type(isFileFn) == "function" then
			for _, path in ipairs({ "core/analytics.luau", "src/analytics.luau", "analytics.luau" }) do
				if isFileFn(path) then
					source = readFileFn(path)
					break
				end
			end
		end
		if source and type(loadStringLocal) == "function" then
			loadStringLocal(source, "Alleral/analytics")()
		end
		return getgenv().Alleral_Analytics
	end)
	Tracker = ok and loaded or nil
end

local function syncTrackerConfig()
	if not Tracker then
		return
	end
	Tracker.Config = Tracker.Config or {}
	Tracker.Config.webhookUrl = state.WebhookURL or ""
	Tracker.Config.webhookEnabled = state.AWebhook == true
	Tracker.Config.brand = "Alleral"
end

if state.Alleral_Unload then
	pcall(state.Alleral_Unload)
end

local defaults = {
	HubRunning = true,
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

local function trim(value)
	return tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function notify(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title or "Alleral",
			Text = text or "",
			Duration = duration or 4,
		})
	end)
end

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

	local rawName = ""
	for _, id in ipairs({
		"identifyexecutor",
		"getexecutorname",
		"whatexecutor",
		"getexecutor",
		"getexecutorinfo",
	}) do
		local f = fn(id)
		if f then
			local ok, r = pcall(f)
			if ok and type(r) == "string" and #r > 0 then
				rawName = r
				break
			end
		end
	end

	local name = rawName:lower():gsub("%s+", ""):match("^[%a][%w%-_%.]*") or ""

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
		elseif tbl("Nihon") then
			name = "nihon"
		elseif tbl("Vega") or tbl("VegaX") then
			name = "vegax"
		elseif tbl("Comet") then
			name = "comet"
		elseif tbl("Trigon") then
			name = "trigon"
		elseif tbl("Cryptic") then
			name = "cryptic"
		elseif tbl("Hydrogen") then
			name = "hydrogen"
		elseif tbl("Sentinel") then
			name = "sentinel"
		elseif tbl("Serenity") then
			name = "serenity"
		elseif tbl("Atlantis") then
			name = "atlantis"
		elseif tbl("Zorara") then
			name = "zorara"
		elseif tbl("Aztup") then
			name = "aztup"
		elseif tbl("Nixware") then
			name = "nixware"
		elseif env.IS_JJSLOIT == true or tbl("jjsploit") then
			name = "jjsploit"
		elseif tbl("Bunni") or tbl("bunni") then
			name = "bunni"
		elseif tbl("Valyse") or tbl("valyse") then
			name = "valyse"
		elseif tbl("Krypton") or tbl("krypton") then
			name = "krypton"
		elseif tbl("SirHurt") or tbl("sirhurt") then
			name = "sirhurt"
		elseif tbl("Temple") or tbl("temple") then
			name = "temple"
		elseif tbl("Evon") or tbl("evon") then
			name = "evon"
		elseif tbl("AWP") or tbl("awp") then
			name = "awp"
		elseif tbl("Pebble") or tbl("pebble") then
			name = "pebble"
		elseif tbl("Nzxt") or tbl("nzxt") then
			name = "nzxt"
		elseif tbl("Nezur") or tbl("nezur") then
			name = "nezur"
		elseif tbl("Seliware") or tbl("seliware") then
			name = "seliware"
		elseif tbl("Luna") or tbl("luna") then
			name = "luna"
		elseif tbl("Macsploit") or tbl("macsploit") then
			name = "macsploit"
		elseif tbl("Arceus") or env.ARCEUS_LOADED == true then
			name = "arceus"
		elseif fn("queue_on_teleport") and fn("getgc") then
			name = "synapse"
		else
			name = "unknown"
		end
	end

	local FS_BROKEN = {
		yub = true,
		yubx = true,
		arceus = true,
		vegax = true,
		comet = true,
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
		hasFireTouch = type(env.firetouchinterest) == "function"
			or type(env.FireTouchInterest) == "function"
			or type(env.touchinterest) == "function",
		env        = env,
	}
end)()

local function execFunc(name, noFs)
	if noFs and not Executor.fsOk then
		return nil
	end
	local v = Executor.env[name]
	return type(v) == "function" and v or nil
end

local function firstExecFunc(...)
	for index = 1, select("#", ...) do
		local candidate = execFunc(select(index, ...))
		if candidate then
			return candidate
		end
	end
	return nil
end

local fireTouchInterest = firstExecFunc(
	"firetouchinterest",
	"FireTouchInterest",
	"touchinterest",
	"fire_touch_interest"
)
local loadStringFn = firstExecFunc("loadstring", "LoadString") or loadstring

local writeFile   = execFunc("writefile",  true)
local readFile    = execFunc("readfile",   true)
local isFile      = execFunc("isfile",     true)
local makeFolder  = execFunc("makefolder", true)
local isFolder    = execFunc("isfolder",   true)
local deleteFile  = execFunc("delfile",    true)
local listFiles   = execFunc("listfiles",  true)
local appendFile  = execFunc("appendfile", true)
local setClipboard = execFunc("setclipboard")
	or execFunc("toclipboard")
	or (type(Executor.env.Wave) == "table" and type(Executor.env.Wave.setclipboard) == "function" and Executor.env.Wave.setclipboard)
	or (type(Executor.env.Electron) == "table" and type(Executor.env.Electron.setclipboard) == "function" and Executor.env.Electron.setclipboard)
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
		pcall(function()
			local report = getgenv().Alleral_ReportError
			if type(report) == "function" then
				report(label, message, details)
			end
		end)
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

local function safeFireTouch(part0, part1, toggle)
	if not fireTouchInterest or not part0 or not part1 then
		return false
	end
	return safeCall("FireTouch", function()
		fireTouchInterest(part0, part1, toggle)
	end)
end

local function restoreHumanoidMovement(humanoid)
	if not humanoid or not humanoid.Parent then
		return
	end
	safeCall("RestoreHumanoid", function()
		humanoid.PlatformStand = false
		humanoid.MaxSlopeAngle = 45
		humanoid.HipHeight = humanoid:GetAttribute("DefaultHipHeight") or humanoid.HipHeight
	end)
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

local function requestFunction()
	local core = getgenv and getgenv().Alleral_Core
	if core and type(core.requestFunction) == "function" then
		local shared = core.requestFunction()
		if shared then
			return shared
		end
	end
	local e = Executor.env
	local candidates = {
		type(e.syn)         == "table" and type(e.syn.request)          == "function" and e.syn.request          or nil,
		type(e.fluxus)      == "table" and type(e.fluxus.request)       == "function" and e.fluxus.request       or nil,
		type(e.http)        == "table" and type(e.http.request)         == "function" and e.http.request         or nil,
		type(e.http_service) == "table" and type(e.http_service.request) == "function" and e.http_service.request or nil,
		type(e.Xeno)        == "table" and type(e.Xeno.request)         == "function" and e.Xeno.request         or nil,
		type(e.Volt)        == "table" and type(e.Volt.request)         == "function" and e.Volt.request         or nil,
		type(e.Madium)      == "table" and type(e.Madium.request)       == "function" and e.Madium.request       or nil,
		type(e.Nihon)       == "table" and type(e.Nihon.request)        == "function" and e.Nihon.request        or nil,
		type(e.Cryptic)     == "table" and type(e.Cryptic.request)      == "function" and e.Cryptic.request      or nil,
		type(e.Sentinel)    == "table" and type(e.Sentinel.request)     == "function" and e.Sentinel.request     or nil,
		type(e.Serenity)    == "table" and type(e.Serenity.request)     == "function" and e.Serenity.request     or nil,
		type(e.Atlantis)    == "table" and type(e.Atlantis.request)     == "function" and e.Atlantis.request     or nil,
		type(e.Zorara)      == "table" and type(e.Zorara.request)       == "function" and e.Zorara.request       or nil,
		type(e.Wave)        == "table" and type(e.Wave.request)         == "function" and e.Wave.request         or nil,
		type(e.Electron)    == "table" and type(e.Electron.request)     == "function" and e.Electron.request     or nil,
		type(e.Potassium)   == "table" and type(e.Potassium.request)    == "function" and e.Potassium.request    or nil,
		type(e.Velocity)    == "table" and type(e.Velocity.request)     == "function" and e.Velocity.request     or nil,
		type(e.Krnl)        == "table" and type(e.Krnl.request)         == "function" and e.Krnl.request         or nil,
		type(e.jjsploit)    == "table" and type(e.jjsploit.request)     == "function" and e.jjsploit.request     or nil,
		type(e.Bunni)       == "table" and type(e.Bunni.request)        == "function" and e.Bunni.request        or nil,
		type(e.Valyse)      == "table" and type(e.Valyse.request)       == "function" and e.Valyse.request       or nil,
		type(e.Krypton)     == "table" and type(e.Krypton.request)      == "function" and e.Krypton.request      or nil,
		type(e.Evon)        == "table" and type(e.Evon.request)          == "function" and e.Evon.request          or nil,
		type(e.delta)       == "table" and type(e.delta.request)        == "function" and e.delta.request        or nil,
		type(e.celery)      == "table" and type(e.celery.request)       == "function" and e.celery.request       or nil,
		e.http_request,
		e.request,
		e.Request,
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

local function withNoCache(url)
	local sep = url:find("?") and "&" or "?"
	return url .. sep .. "nocache=" .. tostring(math.random(10000, 99999))
end

local function fetchUrl(url)
	url = withNoCache(url)
	if type(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, url, true)
		if ok and body and body ~= "" and not body:find("404: Not Found") then
			return body
		end
	end
	local httpGet = requestFunction()
	if httpGet then
		local ok, response = safeCall("FetchUrl", function()
			return httpGet({ Url = url, Method = "GET" })
		end)
		if ok and response then
			local body = response.Body or response.body
			if body and body ~= "" and not body:find("404: Not Found") then
				return body
			end
		end
	end
	return nil
end

local function getConnectionFetcher()
	local e = Executor.env
	local candidates = {
		e.getconnections,
		e.get_signal_cons,
		e.getconnections2,
		e.get_signal_connections,
		e.debug_getconnections,
		e.getconnections3,
		e.get_signal_connections2,
		e.getconnections4,
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
		return nil, "Paste your Discord webhook URL first."
	end
	if not url:match("^https://") then
		return nil, "URL needs to start with https://"
	end
	if
		not (
			url:match("^https://discord%.com/api/webhooks/%d+/.+")
			or url:match("^https://discordapp%.com/api/webhooks/%d+/.+")
		)
	then
		return nil, "That doesn't look like a Discord webhook link."
	end
	return url, nil
end

do
	local genv = getgenv and getgenv() or {}
	local defaultWebhook = genv.Alleral_DefaultWebhook
	if trim(state.WebhookURL or "") == "" and type(defaultWebhook) == "string" and defaultWebhook ~= "" then
		local normalized = normalizeWebhookUrl(defaultWebhook)
		if normalized then
			state.WebhookURL = normalized
			state.AWebhook = true
		end
	end
end

local function sendWebhook(url, payload)
	local core = getgenv and getgenv().Alleral_Core
	if core and type(core.postWebhook) == "function" then
		local postUrl, urlError = normalizeWebhookUrl(url)
		if not postUrl then
			return false, urlError
		end
		return core.postWebhook(postUrl, payload)
	end
	local sender = requestFunction()
	if not sender then
		return false, "Your executor can't send webhooks (no HTTP)."
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
		notify("Game update", "New patch dropped. Toggle stuff off and on if things feel weird.", 8)
	elseif forceNotify then
		notify("Game check", "Same build as last time.", 5)
	end
	return runtime.gameBuild
end

local function acceptCurrentGameBuild()
	local build = checkGameBuild(false, true)
	notify("Game check", "Won't nag about updates until the next patch.", 5)
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
	restoreHumanoidMovement(LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid"))
end

local function loadLuaSource(source, label)
	if not source or source == "" then
		logError("Loader", "Empty source for " .. label .. ".")
		return nil
	end
	local chunk, compileError = loadStringFn(source, "@" .. label)
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

local function loadRemoteLua(url, label)
	local source = fetchUrl(url)
	if not source then
		logError("Loader", "Failed to fetch " .. label .. ".")
		return nil
	end
	return loadLuaSource(source, label)
end

local STARLIGHT_REMOTE_URLS = {
	"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/vendor/starlight/Source.lua",
	"https://raw.githubusercontent.com/Nebula-Softworks/Starlight-Interface-Suite/master/Source.lua",
}

do
	local execName = Executor and Executor.name or "unknown"
	local execRaw = Executor and Executor.rawName or ""
	local display = execName ~= "unknown" and execName or (execRaw ~= "" and execRaw or "unknown")
	local compatMap = {
		synapse = true, krnl = true, fluxus = true, scriptware = true,
		celery = true, delta = true, electron = true, wave = true,
		oxygenu = true, awp = true, evon = true,
		solara = true, xeno = true, volt = true, potassium = true,
		madium = true, velocity = true, codex = true, ronix = true,
		nihon = true, vegax = true, comet = true, trigon = true,
		cryptic = true, hydrogen = true, sentinel = true, serenity = true,
		atlantis = true, zorara = true, aztup = true, nixware = true,
		jjsploit = true, bunni = true, valyse = true, krypton = true,
		sirhurt = true, temple = true, pebble = true, nzxt = true,
		nezur = true, seliware = true, luna = true, macsploit = true,
		arceus = true,
	}
	local caps = {}
	if Executor.hasHttp then table.insert(caps, "HTTP") end
	if Executor.hasFilesystem then table.insert(caps, "FS") end
	if Executor.hasFireTouch then table.insert(caps, "Touch") end
	if Executor.hasGetConn then table.insert(caps, "Signals") end
	if Executor.hasClipboard then table.insert(caps, "Clipboard") end
	local capText = #caps > 0 and (" [" .. table.concat(caps, ", ") .. "]") or ""
	local compat = compatMap[display:lower()] or Executor.isKnown
	if display == "unknown" then
		notify("Executor", "Couldn't tell what you're on" .. capText .. ". Most stuff should still run.", 6)
	elseif not compat and (#caps < 2) then
		notify("Executor", display .. capText .. ". A few features might not run.", 6)
	else
		notify("Alleral", display .. capText .. ". Good to go.", 4)
	end
end

local function patchStarlightSource(source)
	if not source or source == "" then
		return source
	end
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

local STARLIGHT_LOCAL_FILES = {
	"vendor/starlight/Source.lua",
	"starlight/Source.lua",
	"kick/vendor/starlight/Source.lua",
	"kick/kick/vendor/starlight/Source.lua",
}

local function compileStarlightSource(source, label)
	if not source or source == "" or not loadStringFn then
		return nil
	end
	local ok, result = safeCall("CompileStarlight:" .. label, function()
		return loadStringFn(patchStarlightSource(source), "@" .. label)()
	end)
	if ok and type(result) == "table" and type(result.CreateWindow) == "function" then
		return result
	end
	return nil
end

local function loadStarlightFromLocal()
	if not readFile or not isFile then
		return nil
	end
	for _, path in ipairs(STARLIGHT_LOCAL_FILES) do
		if isFile(path) then
			local source = readFile(path)
			local starlight = compileStarlightSource(source, "Starlight/local")
			if starlight then
				return starlight
			end
		end
	end
	return nil
end

local function loadStarlight()
	if type(shared) == "table" and type(shared.Alleral_Starlight) == "table" and type(shared.Alleral_Starlight.CreateWindow) == "function" then
		return shared.Alleral_Starlight
	end

	local env = getgenv and getgenv() or {}
	if type(env.Alleral_Starlight) == "table" and type(env.Alleral_Starlight.CreateWindow) == "function" then
		return env.Alleral_Starlight
	end

	local core = env.Alleral_Core
	if core and type(core.loadStarlight) == "function" then
		local cached, err = core.loadStarlight()
		if cached then
			env.Alleral_Starlight = cached
			return cached
		end
		if err then
			logError("Starlight", "Core.loadStarlight: " .. tostring(err))
		end
	end

	local localStarlight = loadStarlightFromLocal()
	if localStarlight then
		env.Alleral_Starlight = localStarlight
		return localStarlight
	end

	local source
	for _, url in ipairs(STARLIGHT_REMOTE_URLS) do
		source = fetchUrl(url)
		if source then
			break
		end
	end
	if not source then
		logError("Starlight", "Could not load Starlight (no local copy and HTTP fetch failed).")
		return nil
	end
	local remoteStarlight = compileStarlightSource(source, "Starlight/remote")
	if remoteStarlight then
		env.Alleral_Starlight = remoteStarlight
	end
	return remoteStarlight
end

local starlight = loadStarlight()
if not starlight or type(starlight.CreateWindow) ~= "function" then
	logError("Starlight", "Starlight Interface Suite was not available; startup aborted.")
	local failMsg = "Starlight unavailable"
	if getgenv then
		getgenv().Alleral_StartupFailed = failMsg
		if getgenv().Alleral_State then
			getgenv().Alleral_State.StartupFailed = failMsg
		end
	end
	pcall(function()
		shared.Alleral_StartupFailed = failMsg
	end)
	return
end

local KICKBLOX_URLS = {
	"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/games/kickblox.luau",
	"https://raw.githubusercontent.com/Omnie7/Luxy-Core/main/Data/KickBlox.luau",
}
local KICKBLOX_LOCAL_FILES = {
	"games/kickblox.luau",
	"src/kickblox.luau",
	"kickblox.luau",
}

local function loadGameData()
	if readFile and isFile then
		for _, path in ipairs(KICKBLOX_LOCAL_FILES) do
			if isFile(path) then
				local ok, data = safeCall("KickBloxLocal", function()
					return loadStringFn(readFile(path), "@KickBlox/local")()
				end)
				if ok and type(data) == "table" then
					return data
				end
			end
		end
	end
	for _, url in ipairs(KICKBLOX_URLS) do
		local loaded = loadRemoteLua(url, "game data")
		if type(loaded) == "table" then
			return loaded
		end
	end
	return { BrainrotOptions = {}, RarityOptions = {}, MutationOptions = {} }
end

local gameData = loadGameData()

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
	local mantissa, exponent = text:match("^(%-?[%d%.]+)[eE](%-?%d+)$")
	if mantissa and exponent then
		return (tonumber(mantissa) or 0) * (10 ^ (tonumber(exponent) or 0))
	end
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

local function rsChild(...)
	local node = ReplicatedStorage
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		if not node then
			return nil
		end
		node = node:FindFirstChild(name)
	end
	return node
end

local modules = {
	entitiesData = nil,
	mutationData = nil,
	weightsData = nil,
	speedData = nil,
	sacrificeData = nil,
	kickService = nil,
	balanceService = nil,
	weatherService = nil,
	rebirthData = nil,
	rebirthService = nil,
}

local moduleResolvers = {}

local function loadModule(key, label, resolver, optional)
	local entry = moduleResolvers[key] or { label = label, resolver = resolver, optional = optional ~= false }
	entry.label = label
	entry.resolver = resolver
	entry.optional = optional ~= false
	moduleResolvers[key] = entry

	if entry.giveUp then
		return modules[key]
	end

	local okResolve, target = pcall(resolver)
	if not okResolve or not target then
		if entry.optional then
			entry.giveUp = true
		end
		return nil
	end

	local ok, result = safeCall("LoadModule:" .. label, function()
		return require(target)
	end)
	if ok and result then
		modules[key] = result
		entry.giveUp = true
	elseif entry.optional then
		entry.giveUp = true
	end
	return modules[key]
end

local function syncKickServicePercent()
	if modules.kickService then
		safeCall("KickServicePercent", function()
			modules.kickService.Percent = mathClamp((state.CustomKickPowerPercent or 100) / 100, 0, 1)
		end)
	end
end

local function bindProgressionModules()
	if modules.kickService then
		syncKickServicePercent()
		if modules.kickService.Level ~= nil then
			runtime.kickLevel = modules.kickService.Level
		end
		if modules.kickService.LevelChanged and not runtime.kickLevelBound then
			runtime.kickLevelBound = true
			track(modules.kickService.LevelChanged:Connect(function(level)
				runtime.kickLevel = level
			end), "KickLevelChanged")
		end
	end
	if modules.rebirthService then
		if modules.rebirthService.RebirthLevel ~= nil then
			runtime.rebirthLevel = modules.rebirthService.RebirthLevel
		end
		if modules.rebirthService.RebirthChanged and not runtime.rebirthLevelBound then
			runtime.rebirthLevelBound = true
			track(modules.rebirthService.RebirthChanged:Connect(function(level)
				runtime.rebirthLevel = level
			end), "RebirthChanged")
		end
	end
end

local function retryMissingModules()
	for key, entry in pairs(moduleResolvers) do
		if not modules[key] and not entry.giveUp then
			loadModule(key, entry.label, entry.resolver, entry.optional)
		end
	end
	if modules.entitiesData and not next(runtime.brainrotCpsCache) then
		refreshBrainrotCpsCache()
	end
	bindProgressionModules()
end

loadModule("entitiesData", "EntitiesData", function()
	return rsChild("Shared", "Data", "EntitiesData")
end, false)
loadModule("mutationData", "MutationData", function()
	return rsChild("Shared", "Data", "MutationData")
end, true)
loadModule("weightsData", "WeightsData", function()
	return ReplicatedStorage:FindFirstChild("WeightsData", true)
		or rsChild("Shared", "Data", "WeightsData")
end, true)
loadModule("speedData", "SpeedData", function()
	return rsChild("Shared", "Data", "SpeedData")
end, true)
loadModule("sacrificeData", "SacrificeData", function()
	return rsChild("Shared", "Data", "SacrificeData")
end, true)
loadModule("kickService", "KickServiceClient", function()
	return rsChild("Modules", "ServicesLoader", "KickServiceClient")
end, false)
loadModule("rebirthData", "RebirthData", function()
	return rsChild("Shared", "Data", "RebirthData")
end, true)
loadModule("rebirthService", "RebirthServiceClient", function()
	return rsChild("Modules", "ServicesLoader", "RebirthServiceClient")
end, true)

syncKickServicePercent()
bindProgressionModules()
loadModule("balanceService", "ClientBalanceService", function()
	return rsChild("Modules", "ServicesLoader", "ClientBalanceService")
end, true)
loadModule("weatherService", "WeatherServiceClient", function()
	return rsChild("Modules", "ServicesLoader", "WeatherService_Client")
end, true)
loadModule("serverLuckClient", "ServerLuckClient", function()
	return rsChild("Modules", "ServicesLoader", "ServerLuckClient")
end, true)

local function refreshBrainrotCpsCache()
	runtime.brainrotCpsCache = {}
	local brainrots = modules.entitiesData and modules.entitiesData.Brainrots
	if not brainrots then
		return
	end
	for name, entry in pairs(brainrots) do
		if entry and entry.CPS ~= nil then
			runtime.brainrotCpsCache[name] = coerceNumber(entry.CPS)
		end
	end
end

if modules.entitiesData then
	refreshBrainrotCpsCache()
end

if modules.mutationData and modules.mutationData.ValidMutations then
	gameData.MutationOptions = modules.mutationData.ValidMutations
end
gameData.BrainrotOptions = withAny(gameData.BrainrotOptions)
gameData.RarityOptions = withAny(gameData.RarityOptions)
gameData.MutationOptions = withAny(gameData.MutationOptions)

local cachedCoins = modules.balanceService and parseNumber(modules.balanceService.Balance) or 0

local function currentCoins()
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins then
		cachedCoins = parseNumber(coins.Value)
	end
	return cachedCoins or 0
end

if modules.balanceService and modules.balanceService.CoinsChanged then
	track(modules.balanceService.CoinsChanged:Connect(function(coins)
		cachedCoins = parseNumber(coins)
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

	remotes.kick           = safeFindRemote(network, { "rev_KickEvent", "KickEvent", "rev_kickevent", "KickRemote", "rev_Kick" })
	remotes.collect        = safeFindRemote(network, { "rev_B_Collect", "B_Collect", "Collect", "CollectCash", "rev_Collect" })
	remotes.upgradeBrainrot= safeFindRemote(network, { "rev_B_Upgrade", "B_Upgrade", "UpgradeBrainrot", "BrainrotUpgrade", "rev_Upgrade" })
	remotes.speedUpgrade   = safeFindRemote(network, { "rev_SPEED_UPGRADE", "SPEED_UPGRADE", "SpeedUpgrade", "rev_SpeedUp" })
	remotes.shopBuy        = safeFindRemote(network, { "rev_Shop_Buy", "Shop_Buy", "ShopBuy", "BuyItem", "rev_Buy" })
	remotes.weightEquip    = safeFindRemote(network, { "rev_WeightEquip", "WeightEquip", "EquipWeight", "rev_Equip" })
	remotes.sellAll        = safeFindRemote(network, { "ref_B_SellAll", "rev_B_SellAll", "B_SellAll", "SellAll", "SellAllBrainrots" })
	remotes.sell           = safeFindRemote(network, { "ref_B_Sell", "rev_B_Sell", "B_Sell", "SellBrainrot", "Sell" })
	remotes.toggleFavorite = safeFindRemote(network, { "rev_ToggleFav", "ToggleFav", "FavoriteTool", "rev_Fav" })
	remotes.rebirth        = safeFindRemote(network, { "rev_RebirthRequest", "RebirthRequest", "Rebirth", "DoRebirth", "rev_Rebirth" })
	remotes.plotUpgrade    = safeFindRemote(network, { "rev_bs_upgrade", "bs_upgrade", "PlotUpgrade", "UpgradePlot", "rev_PlotUpgrade" })
	remotes.weather        = safeFindRemote(network, { "rev_sbe", "sbe", "SummonWeather", "WeatherSummon", "rev_Weather" })
	remotes.place          = safeFindRemote(network, { "rev_S_Interact", "S_Interact", "PlaceBrainrot", "PlacePet", "rev_Place" })
	remotes.battleCreate   = safeFindRemote(network, { "rev_bs_battle_create", "ref_battle_create", "rev_battle_create", "battle_create", "BattleCreate" })
	remotes.battleInvite   = safeFindRemote(network, { "rev_bs_battle_invite", "ref_battle_invite", "rev_battle_invite", "battle_invite", "BattleInvite" })
	remotes.battleStart    = safeFindRemote(network, { "rev_bs_battle_start",  "rev_battle_start",  "battle_start", "BattleStart", "StartBattle" })
	remotes.kickStyle      = safeFindRemote(network, { "rev_KickStyle", "rev_KickStyleEquip", "KickStyleEquip", "EquipKickStyle" })

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

local RARITY_RANK = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Secret = 7,
	Divine = 8,
	Cosmic = 9,
	Godly = 10,
	Exotic = 11,
}

local function rarityMeetsThreshold(rarity, threshold)
	local rank = RARITY_RANK[normalizeText(rarity)] or 0
	local minimum = RARITY_RANK[normalizeText(threshold)] or RARITY_RANK.Legendary or 5
	return rank >= minimum
end

local FALLBACK_MUTATION_MULTIPLIERS = {
	Golden = 1.5,
	Diamond = 2,
	Plasma = 4,
	Molten = 6,
	Radioactive = 8,
	Void = 10,
	Shadow = 12,
	Electrified = 16,
	Rainbow = 30,
	Virus = 10,
	Wet = 16,
	Alien = 22,
	Bacon = 30,
	Enchanted = 12,
	Phantom = 35,
	Astral = 35,
	Volcanic = 35,
}

local function brainrotCps(name, mutation, level)
	local brainrots = modules.entitiesData and modules.entitiesData.Brainrots
	if not brainrots or not brainrots[name] then
		return nil
	end
	local entry = brainrots[name]
	local base = runtime.brainrotCpsCache[name]
		or parseNumber(entry.CPS or entry.CashPerSecond or entry.BaseCPS or 0)
	local lvl = math.max(1, tonumber(level) or 1)

	local leveledBase
	if entry.CPSPerLevel or entry.CashPerSecondPerLevel then
		local perLvl = parseNumber(entry.CPSPerLevel or entry.CashPerSecondPerLevel or 0)
		leveledBase = base + (lvl - 1) * perLvl
	elseif entry.LevelMultiplier then
		local m = parseNumber(entry.LevelMultiplier or 1)
		leveledBase = base * (1 + (lvl - 1) * (m - 1))
	else
		leveledBase = base * lvl
	end

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
		elseif mutation and FALLBACK_MUTATION_MULTIPLIERS[mutation] then
			multiplier = FALLBACK_MUTATION_MULTIPLIERS[mutation]
		end
	end

	return leveledBase * multiplier
end

local function rollChanceFor(name)
	local data = modules.entitiesData
	if not data or not data.LuckyBlocks then
		return "Unknown"
	end
	for _, block in pairs(data.LuckyBlocks) do
		local pool = block.Pool
		if pool then
			for _, entry in ipairs(pool) do
				if entry.Name == name and entry.Chance then
					return tostring(entry.Chance) .. "%"
				end
			end
		end
	end
	return "Unknown"
end

local function brainrotThumbnail(name)
	local brainrots = modules.entitiesData and modules.entitiesData.Brainrots
	local image = brainrots and brainrots[name] and brainrots[name].Image or ""
	local assetId = tostring(image):match("rbxassetid://(%d+)")
	if assetId then
		return "https://www.roblox.com/Thumbs/Asset.ashx?width=420&height=420&assetId=" .. assetId
	end
	return ""
end

local HIGHLIGHT_MUTATIONS = {
	Bacon = true,
	Phantom = true,
	Volcanic = true,
	Astral = true,
	Enchanted = true,
	Rainbow = true,
}

local HIGHLIGHT_RARITIES = {
	Celestial = true,
	Eternal = true,
	Ethernal = true,
}

local function parseJobIdInput(raw)
	raw = trim(raw)
	if raw == "" then
		return nil, game.PlaceId
	end
	local luxyPayload = raw:match("LUXY:<([^>]+)>")
	if luxyPayload then
		local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
		local cleaned = luxyPayload:gsub("[^" .. alphabet .. "=]", "")
		local bits = cleaned:gsub(".", function(char)
			if char == "=" then
				return ""
			end
			local index = alphabet:find(char, 1, true)
			if not index then
				return ""
			end
			local output = ""
			for bitIndex = 6, 1, -1 do
				output = output .. (((index % (2 ^ bitIndex)) - (index % (2 ^ (bitIndex - 1))) > 0) and "1" or "0")
			end
			return output
		end)
		local decoded = bits:gsub("%d%d%d?%d?%d?%d?%d?%d?", function(chunk)
			if #chunk ~= 8 then
				return ""
			end
			local value = 0
			for bitIndex = 1, 8 do
				if chunk:sub(bitIndex, bitIndex) == "1" then
					value = value + (2 ^ (8 - bitIndex))
				end
			end
			return string.char(value)
		end)
		if decoded ~= "" then
			raw = decoded
		end
	end
	local placeId = tonumber(raw:match("placeId=(%d+)")) or game.PlaceId
	local jobId = raw:match("instanceId=([^&%s]+)")
		or raw:match("gameInstanceId=([%w%-]+)")
		or raw:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)")
		or raw:match("([%w]+%-[%w]+%-[%w]+%-[%w]+%-[%w]+)")
		or raw
	jobId = trim(jobId)
	if jobId == "" then
		return nil, placeId
	end
	return jobId, placeId
end

local function sendHighlightRollWebhook(name, mutation, rarity)
	if not state.AWebhook or state.WebhookURL == "" then
		return
	end
	local signature = name .. "_" .. mutation
	if runtime.lastHighlightRoll == signature and tick() - (runtime.lastHighlightRollAt or 0) < 10 then
		return
	end
	runtime.lastHighlightRoll = signature
	runtime.lastHighlightRollAt = tick()
	local cps = brainrotCps(name, mutation, 1)
	local cpsText = cps and (formatNumber(cps) .. "/s") or "N/A"
	syncTrackerConfig()
	if Tracker and Tracker.SendGlobalLog then
		local ok, err = Tracker:SendGlobalLog(LocalPlayer.Name, name, mutation, rarity, cpsText)
		if not ok and err then
			logError("HighlightWebhook", err)
		end
		return
	end
	sendWebhook(state.WebhookURL, {
		username = "Alleral",
		content = "@everyone",
		embeds = {
			{
				title = "Highlight roll",
				color = 16733440,
				fields = {
					{ name = "Brainrot", value = "```" .. name .. "```", inline = true },
					{ name = "Rarity", value = "```" .. rarity .. "```", inline = true },
					{ name = "Mutation", value = "```" .. mutation .. "```", inline = true },
					{ name = "CPS", value = "```" .. cpsText .. "```", inline = true },
					{ name = "Server JobId", value = "```" .. tostring(game.JobId) .. "```", inline = false },
				},
				footer = { text = "Alleral" },
				timestamp = DateTime.now():ToIsoDate(),
			},
		},
	})
end

local function handleInGameRoll(inGame)
	if inGame == "" then
		return
	end
	local parts = string.split(inGame, ",")
	local name = trim(parts[1] or "Unknown")
	local mutation = normalizeMutation(parts[2] or "None")
	if name == "" or name == "Unknown" then
		return
	end
	local serverRarity = parts[4] and trim(parts[4]) ~= "" and trim(parts[4]) or nil
	local rarity = rarityFor(name, serverRarity)
	if HIGHLIGHT_MUTATIONS[mutation] or HIGHLIGHT_RARITIES[rarity] then
		sendHighlightRollWebhook(name, mutation, rarity)
	end
end

local function rebirthCoinRequirement()
	local level = tonumber(runtime.rebirthLevel) or 0
	if modules.rebirthData and type(modules.rebirthData.GetKickRequirement) == "function" then
		local ok, requirement = safeCall("RebirthRequirement", function()
			return modules.rebirthData:GetKickRequirement(level + 1)
		end)
		if ok and requirement ~= nil then
			return parseNumber(requirement)
		end
	end
	return math.huge
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

local function fireRemote(remote, ...)
	if not remote then return false end
	local args = { ... }
	local ok = pcall(function() remote:FireServer(table.unpack(args)) end)
	if not ok then
		ok = pcall(function() remote:InvokeServer(table.unpack(args)) end)
	end
	return ok
end

local function currentBattleStatus()
	if tick() - runtime.cachedBattleStatusAt < 0.75 then
		return runtime.cachedBattleStatus
	end
	local status = nil
	safeCall("BattleStatus", function()
		local m = require(ReplicatedStorage.Modules.UILoader.KickBattlesUI)
		if m and m.CurrentStatus ~= nil then
			status = tostring(m.CurrentStatus)
		end
	end)
	if not status then
		local attr = LocalPlayer:GetAttribute("BattleStatus")
		if attr ~= nil then
			status = tostring(attr)
		end
	end
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
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	speed = math.max(speed or 90, 1)
	local started = tick()
	while
		state.HubRunning
		and root.Parent
		and humanoid
		and humanoid.Parent
		and humanoid.Health > 0
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

local function approachWavePad(root, humanoid, kickReady)
	if not root or not humanoid or not kickReady then
		return
	end
	local startPos = root.Position
	local padPos = kickReady.Position
	local horizontalDistance = (
		Vector3.new(startPos.X, 0, startPos.Z) - Vector3.new(padPos.X, 0, padPos.Z)
	).Magnitude
	if horizontalDistance <= 0 then
		return
	end
	safeCall("KickSlowModeOff", function()
		if modules.kickService and modules.kickService.SlowMode then
			modules.kickService:SlowMode(false)
		end
	end)
	safeCall("KickWaveApproach", function()
		humanoid.PlatformStand = true
		humanoid.MaxSlopeAngle = 89
		while state.HubRunning and state.AFarm do
			local waves = Workspace:FindFirstChild("Waves")
			if not waves or #waves:GetChildren() == 0 then
				break
			end
			if not root.Parent or not humanoid.Parent or humanoid.Health <= 0 then
				break
			end
			local dt = task.wait()
			local pos = root.Position
			local toPad = Vector3.new(padPos.X, 0, padPos.Z) - Vector3.new(pos.X, 0, pos.Z)
			local distance = toPad.Magnitude
			if distance < 3 then
				break
			end
			local progress = math.clamp(1 - (distance / horizontalDistance), 0, 1)
			progress = progress * progress * progress * progress
			local y = math.lerp(startPos.Y + 0.5, padPos.Y - 5, progress)
			local step = toPad.Unit * humanoid.WalkSpeed * dt
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			root.CFrame = CFrame.new(pos.X + step.X, y, pos.Z + step.Z)
		end
	end)
	restoreHumanoidMovement(humanoid)
	if root.Parent then
		root.CFrame = kickReady.CFrame * CFrame.new(0, -1.5, 0)
	end
	safeCall("KickSlowModeOn", function()
		if modules.kickService and modules.kickService.SlowMode then
			modules.kickService:SlowMode(true)
		end
	end)
	task.wait(0.3)
end

local function resetForBadWaveRoll(character, humanoid, kickReady)
	if runtime.waveResetBusy or not character or not humanoid or not kickReady then
		return
	end
	runtime.waveResetBusy = true
	task.spawn(function()
		local defaultHip = humanoid:GetAttribute("DefaultHipHeight") or humanoid.HipHeight
		local camera = Workspace.CurrentCamera
		safeCall("AutoKickWaveReset", function()
			humanoid.HipHeight = defaultHip
			if camera then
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = kickReady.CFrame * CFrame.new(0, 3, -1)
				camera.CFrame = CFrame.lookAt(camera.CFrame.Position, kickReady.Position)
			end
			task.wait(0.2)
			humanoid.Health = 0
		end)
		local oldCharacter = character
		local respawnTimeout = tick() + 12
		while state.HubRunning and LocalPlayer.Character == oldCharacter and tick() < respawnTimeout do
			task.wait(0.1)
		end
		local newCharacter = LocalPlayer.Character
		local newHumanoid = newCharacter and newCharacter:FindFirstChild("Humanoid")
		local newRoot = newCharacter and newCharacter:FindFirstChild("HumanoidRootPart")
		if newRoot and newHumanoid and kickReady.Parent then
			newRoot.CFrame = kickReady.CFrame * CFrame.new(0, 3, 0)
			restoreCamera(newHumanoid)
		end
		runtime.waveResetBusy = false
	end)
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
	AcceptBattle = 6,
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
	return name ~= "RefreshData"
		and name ~= "Prediction"
		and name ~= "WebhookStatus"
		and name ~= "AcceptBattle"
		and name ~= "Battle"
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
		return state.ACollect
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
					elseif name == "TrainCollect" then
						state.IsFlashCollecting = false
					elseif name == "Mastery" then
						runtime.masteryBusy = false
						runtime.nextMasteryAction = tick() + 1
					end
					runtime.lastLoopError = name .. ": " .. shortError(err)
					logError("Loop:" .. name, err)
					loopState.errors = loopState.errors + 1
					if state.NotifyOnError and tick() >= (loopState.nextErrorNotify or 0) then
						loopState.nextErrorNotify = tick() + (state.UIQuietMode and 20 or 10)
						notify("Alleral", name .. " hit a snag: " .. tostring(err), 3)
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
	local collected = 0
	for _, button in ipairs(buttons:GetChildren()) do
		if collected >= 14 or not state.HubRunning then
			break
		end
		local slotNumber = tonumber(button.Name:match("%d+"))
		if button:IsA("BasePart") and slotNumber then
			local slot = slots:FindFirstChild(button.Name)
			local placed = slot and slot:FindFirstChild("PlacedPart")
			if placed and placed:FindFirstChildOfClass("Model") then
				root.CFrame = button.CFrame + Vector3.new(0, 3, 0)
				task.wait(0.06)
				safeFireTouch(root, button, 0)
				task.wait(0.04)
				safeFireTouch(root, button, 1)
				safeCall("CollectCashRemote", function()
					remotes.collect:FireServer(slotNumber)
				end)
				collected = collected + 1
				task.wait(0.05)
			end
		end
	end
	if root.Parent then
		root.CFrame = oldCFrame
	end
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

local function backpackBrainrotCount()
	local count = 0
	local function tally(container)
		if not container then
			return
		end
		for _, item in ipairs(container:GetChildren()) do
			if isBrainrotTool(item) then
				count = count + 1
			end
		end
	end
	tally(LocalPlayer.Backpack)
	tally(LocalPlayer.Character)
	return count
end

local function tryAutoSell()
	if not state.AAutoSell or not remotes.sellAll then
		return
	end
	local limit = math.max(5, tonumber(state.AutoSellMaxBackpack) or 25)
	if backpackBrainrotCount() < limit then
		return
	end
	if tick() < (runtime.nextAutoSell or 0) then
		return
	end
	runtime.nextAutoSell = tick() + 45
	if state.AAutoFav then
		scanTools()
		task.wait(1)
	end
	safeCall("AutoSellAll", function()
		remotes.sellAll:InvokeServer()
	end)
	notify("Auto sell", "Bag was full so I sold everything.", 3)
end

local recentPlaceSlots = {}
local function protectedSlotLabel(name, mutation)
	return string.format("%s [%s]", tostring(name), normalizeMutation(mutation))
end

function placedBrainrotInfo(placed)
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
	if runtime.plotListRefreshPending then
		return
	end
	runtime.plotListRefreshPending = true
	task.defer(function()
		runtime.plotListRefreshPending = false
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
	if not remotes.shopBuy then
		return
	end
	local sorted = getSortedWeights()
	if #sorted == 0 then
		return
	end
	local ownedIndex = 0
	for _, tool in ipairs(getOwnedWeightTools()) do
		for index, weightName in ipairs(sorted) do
			if tool.Name == weightName and index > ownedIndex then
				ownedIndex = index
			end
		end
	end
	local target = nil
	if ownedIndex > 0 and ownedIndex < #sorted then
		target = sorted[ownedIndex + 1]
	elseif ownedIndex == 0 then
		target = sorted[1]
	end
	if not target or ownsWeight(target) then
		return
	end
	local cost = weightCost(target)
	if currentCoins() < cost then
		return
	end
	runtime.nextWeightBuyAttempt[target] = runtime.nextWeightBuyAttempt[target] or 0
	if tick() < runtime.nextWeightBuyAttempt[target] then
		return
	end
	local before = currentCoins()
	safeCall("BuyBestWeight", function()
		remotes.shopBuy:FireServer("WeightShop", target)
	end)
	task.wait(1.5)
	local after = currentCoins()
	if after < before then
		equipOwnedWeight(target)
		runtime.nextWeightBuyAttempt[target] = tick() + 3
	else
		runtime.nextWeightBuyAttempt[target] = tick() + 8
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
	local before = currentCoins()
	safeCall("BuyWeight", function()
		if remotes.shopBuy then
			remotes.shopBuy:FireServer("WeightShop", weight)
		end
	end)
	task.wait(1.5)
	if currentCoins() < before then
		if remotes.weightEquip then
			safeCall("EquipWeightRemote", function()
				remotes.weightEquip:FireServer(weight)
			end)
		end
		equipOwnedWeight(weight)
	else
		runtime.nextWeightBuyAttempt[weight] = tick() + 8
	end
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
		local cpsText = cps and (formatNumber(cps) .. "/s") or "N/A"
		syncTrackerConfig()
		if Tracker and Tracker.SendNewPetClaim then
			local ok, err = Tracker:SendNewPetClaim(
				state.WebhookURL,
				name,
				rarity,
				mutation,
				rollChanceFor(name),
				cpsText,
				brainrotThumbnail(name)
			)
			if not ok then
				logError("ClaimWebhook", err)
			end
		else
			sendWebhook(state.WebhookURL, {
				username = "Alleral",
				content = "@everyone",
				embeds = {
					{
						title = "New brainrot",
						color = 16733440,
						fields = {
							{ name = "Brainrot", value = "```" .. name .. "```", inline = true },
							{ name = "Rarity", value = "```" .. rarity .. "```", inline = true },
							{ name = "Mutation", value = "```" .. mutation .. "```", inline = true },
							{ name = "CPS", value = "```" .. cpsText .. "```", inline = true },
							{ name = "Server JobId", value = "```" .. tostring(game.JobId) .. "```", inline = false },
						},
						footer = { text = "Alleral" },
						timestamp = DateTime.now():ToIsoDate(),
					},
				},
			})
		end
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
			while #runtime.favoriteQueue > 60 do
				table.remove(runtime.favoriteQueue, 1)
			end
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
	add(tool:GetAttributeChangedSignal("GUID"):Connect(evaluate))
	add(tool:GetAttributeChangedSignal("Favorite"):Connect(evaluate))
	add(tool:GetAttributeChangedSignal("Rarity"):Connect(evaluate))
	add(tool:GetAttributeChangedSignal("Mutation"):Connect(evaluate))
	if tool:GetAttribute("GUID") then
		evaluate()
	else
		task.delay(5, function()
			if runtime.favoriteTools[tool] and not tool:GetAttribute("GUID") then
				cleanup()
			end
		end)
	end
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

local function totalLoggedErrors()
	local total = 0
	for _, count in pairs(runtime.errorCounts) do
		total = total + (tonumber(count) or 0)
	end
	return total
end

local function buildInterface()
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

local MAX_RENDERED_DROPDOWN_OPTIONS = 50

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
					end, 3) then
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
			notify("UI", "Dropdown took a sec to load: " .. tostring(options.Text or id), 3)
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
				Name = tostring(options.Text or options.Name or id) .. " filter",
				PlaceholderText = "search...",
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

	return group
end

local starlightWindow = starlight:CreateWindow({
	Name = "Alleral",
	Subtitle = "Kick a Lucky Block · v" .. VERSION,
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
		end, 1.5)
	return wrapStarlightGroup(groupbox)
end

local mainTab = createStarlightTab("Kick", "rbxassetid://10723407389")
local autoTab = createStarlightTab("Plot", "rbxassetid://10734923214")
local eventsTab = createStarlightTab("Events", "rbxassetid://10709789407")
local shopTab = createStarlightTab("Inventory", "rbxassetid://10734952479")
local miscTab = createStarlightTab("Tools", "rbxassetid://10734950020")
local configTab = createStarlightTab("Settings", "rbxassetid://10734950309")

local kickGroup = createStarlightGroup(mainTab, "Auto Kick", "rbxassetid://10734975692", 1)
local filterGroup = createStarlightGroup(mainTab, "Keep / Skip", "rbxassetid://10734975692", 2)
local trainGroup = createStarlightGroup(mainTab, "Train", "rbxassetid://10734975692", 2)
local placeGroup = createStarlightGroup(autoTab, "Auto Place", "rbxassetid://10734975692", 1)
local upgradeGroup = createStarlightGroup(autoTab, "Upgrades", "rbxassetid://10734975692", 2)
local economyGroup = createStarlightGroup(autoTab, "Shop", "rbxassetid://10734975692", 1)
local battleGroup = createStarlightGroup(eventsTab, "Battle", "rbxassetid://10709789407", 1)
local masteryGroup = createStarlightGroup(eventsTab, "Mastery", "rbxassetid://10709789407", 2)
local weatherGroup = createStarlightGroup(eventsTab, "Weather", "rbxassetid://10709789407", 1)
local styleGroup = createStarlightGroup(shopTab, "Styles", "rbxassetid://10734952479", 1)
local favoriteGroup = createStarlightGroup(shopTab, "Favorites", "rbxassetid://10734952479", 2)
local serverGroup = createStarlightGroup(miscTab, "Server", "rbxassetid://10734950020", 1)
local webhookGroup = createStarlightGroup(miscTab, "Webhooks", "rbxassetid://10734950020", 2)
local configGroup = createStarlightGroup(configTab, "Alerts", "rbxassetid://10734950309", 1)
local recoveryGroup = createStarlightGroup(configTab, "Stuck?", "rbxassetid://10734950309", 2)
local tuningGroup = createStarlightGroup(configTab, "Speed tweaks", "rbxassetid://10734950309", 1)
local diagnosticsGroup = createStarlightGroup(configTab, "Debug info", "rbxassetid://10734950309", 2)
local profileGroup = createStarlightGroup(configTab, "Save slots", "rbxassetid://10734950309", 1)
local protectedDropdown
local upgradeDropdown

local diagnosticsStatus = diagnosticsGroup:CreateStatus("Live stats", {
	Executor    = "checking...",
	FPS         = "--",
	Perf        = "--",
	Tasks       = "0",
	Remotes     = "--",
	Build       = "--",
	Updated     = "--",
	Errors      = "0",
	Latest      = "--",
	Previous    = "--",
	Log         = appendFile and logFile or "n/a",
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
		return false, "That config file doesn't look right."
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
		return false, "Your executor can't save files."
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
		return false, "Your executor can't read files."
	end
	name = sanitizeProfileName(name)
	if not isFile(profilePath(name)) then
		return false, "No profile with that name."
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
		return false, "Your executor can't delete files."
	end
	name = sanitizeProfileName(name)
	local path = profilePath(name)
	if isFile and not isFile(path) then
		return false, "No profile with that name."
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
	notify("Fixed", "Cleared stuck flags and timers.", 3)
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
	notify("Paused", "Turned off all automation.", 3)
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
	notify("Debug", "Error log wiped.", 3)
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
	"Save name",
	"my setup",
	nil,
	function(value)
		profileNameInput = sanitizeProfileName(value)
	end,
	"main, alt, webhook-only, whatever."
)
profileGroup:CreateButton(
	"Save setup",
	function()
		local ok, result = saveProfile(profileNameInput)
		if ok then
			refreshProfilesDropdown(result)
		end
		notify(ok and "Saved" or "Didn't save", ok and ("'" .. tostring(result) .. "' is on disk.") or tostring(result), 3)
	end,
	"Stores every toggle and slider under that name."
)
profileGroup:CreateButton(
	"Load setup",
	function()
		local ok, err = loadProfile(profileNameInput)
		notify(ok and "Loaded" or "Couldn't load", ok and ("Applied '" .. profileNameInput .. "'.") or tostring(err), 3)
	end,
	"Loads a saved setup."
)
profileGroup:CreateButton(
	"Delete setup",
	function()
		local deletedName = profileNameInput
		local ok, err = deleteProfile(profileNameInput)
		if ok then
			profileNameInput = "default"
			refreshProfilesDropdown("default")
		end
		notify(ok and "Deleted" or "Couldn't delete", ok and ("Removed '" .. deletedName .. "'.") or tostring(err), 3)
	end,
	"Deletes it from your executor folder."
)
profileGroup:CreateDivider()
availableProfilesDropdown = profileGroup:CreateDropdown(
	"Saved setups",
	listProfiles(),
	"default",
	function(value)
		profileNameInput = sanitizeProfileName(selectedDropdownValue(value, profileNameInput))
	end
)
profileGroup:CreateButton(
	"Rescan folder",
	function()
		refreshProfilesDropdown(profileNameInput)
		notify("Setups", "Found whatever's on disk.", 3)
	end,
	"Use this if you added files manually."
)
profileGroup:CreateDivider()
profileGroup:CreateInput(
	"Paste a friend's setup",
	"paste JSON here",
	nil,
	function(value)
		importBuffer = tostring(value or "")
	end,
	"Drop shared JSON here, or hit Export and send yours to someone."
)
profileGroup:CreateButton(
	"Import JSON",
	function()
		local ok, decoded = safeCall("ImportProfileJson", function()
			return HttpService:JSONDecode(importBuffer)
		end)
		if not ok then
			notify("Nope", "Bad JSON: " .. shortError(decoded), 3)
			return
		end
		local applied, err = applyConfigSnapshot(decoded)
		notify(applied and "Imported" or "Didn't work", applied and "Your toggles just swapped over." or tostring(err), 3)
	end,
	"Runs whatever's in the box above."
)
profileGroup:CreateButton(
	"Export JSON",
	function()
		local encoded = HttpService:JSONEncode(collectConfigSnapshot())
		importBuffer = encoded
		if setClipboard then
			safeCall("CopyProfileExport", function()
				setClipboard(encoded)
			end)
			notify("Exported", "Copied to clipboard.", 3)
		else
			notify("Exported", "JSON is sitting in the box above.", 3)
		end
	end,
	"Full dump of your settings as JSON."
)

configGroup:CreateToggle(
	"Quiet mode",
	state.UIQuietMode,
	"Same error twice won't spam popups. Still logged under Debug.",
	function(value)
		state.UIQuietMode = value
		saveSettings()
	end
)
configGroup:CreateToggle(
	"Error popups",
	state.NotifyOnError,
	"Popup when a background loop errors.",
	function(value)
		state.NotifyOnError = value
		saveSettings()
	end
)

recoveryGroup:CreateButton(
	"Unstick loops",
	resetRuntimeLocks,
	"Place, mastery, or collect frozen? This clears the flags."
)
recoveryGroup:CreateButton(
	"Kill all autos",
	pauseAutomation,
	"Turns off every automation toggle."
)
recoveryGroup:CreateButton(
	"Refresh hooks",
	function()
		runtime.cachedRemotesAt = 0
		runtime.cachedPlotAt = 0
		runtime.nextPlotLookup = 0
		runtime.cachedPlot = nil
		runtime.remoteLookupCache = {}
		refreshRemotes()
		updatePlotLists(protectedDropdown, upgradeDropdown)
		notify("Refreshed", "Plot lists and remotes are live again.", 3)
	end,
	"Game updated and stuff broke? Try this first."
)
recoveryGroup:CreateButton(
	"Reset Discord memory",
	function()
		runtime.seenWebhookGuids = {}
		runtime.seenWebhookOrder = {}
		notify("Discord", "Same brainrot can ping you again.", 3)
	end,
	"Forgot which items already got a webhook ping."
)
diagnosticsGroup:CreateButton(
	"Wipe error log",
	clearErrorLog,
	"Clears the list and deletes the log file."
)
diagnosticsGroup:CreateButton(
	"Check game version",
	function()
		checkGameBuild(true)
	end,
	"See if the devs pushed an update since you last ran."
)
diagnosticsGroup:CreateButton(
	"Yeah I'm updated",
	acceptCurrentGameBuild,
	"Mutes update warnings until the next patch."
)
diagnosticsGroup:CreateButton(
	"Copy debug dump",
	function()
		local summary = supportSummary()
		if setClipboard then
			safeCall("CopySupportInfo", function()
				setClipboard(summary)
			end, true)
			notify("Copied", "Paste that if you're asking for help.", 3)
		else
			logError("Support", "Clipboard is not available.", summary)
			notify("No clipboard", "Your executor can't copy text.", 4)
		end
	end,
	"Version, FPS, last error, all of it."
)
diagnosticsGroup:CreateButton(
	"Refresh panel",
	function()
		checkGameBuild(true)
		notify("Debug", "Numbers should be current now.", 3)
	end,
	"Re-reads build info and live stats."
)

tuningGroup:CreateSlider(
	"Kick speed (sec)",
	0.3,
	2,
	state.AutoKickInterval,
	function(value)
		state.AutoKickInterval = math.max(0.3, value)
		saveSettings()
	end,
	"Time between kick attempts. Lower is faster; raise it if you're lagging."
)
tuningGroup:CreateSlider(
	"Place speed (sec)",
	1.5,
	5,
	state.AutoPlaceInterval,
	function(value)
		state.AutoPlaceInterval = math.max(1.5, value)
		saveSettings()
	end,
	"How often it tries to place a brainrot on your plot."
)
tuningGroup:CreateSlider(
	"Mastery speed (sec)",
	1,
	5,
	state.MasteryInterval,
	function(value)
		state.MasteryInterval = math.max(1, value)
		saveSettings()
	end,
	"Delay between mastery kick cycles."
)
tuningGroup:CreateSlider(
	"Plot list refresh (sec)",
	8,
	30,
	state.PlotRefreshInterval,
	function(value)
		state.PlotRefreshInterval = math.max(8, value)
		saveSettings()
	end,
	"How often the protected / upgrade lists pull from your live plot."
)
tuningGroup:CreateSlider(
	"Favorite scan (sec)",
	4,
	30,
	state.FavoriteScanInterval,
	function(value)
		state.FavoriteScanInterval = math.max(4, value)
		saveSettings()
	end,
	"How often it checks your backpack for stuff to favorite."
)

kickGroup:CreateToggle(
	"Auto kick",
	state.AFarm,
	"Runs to the pad, kicks, and resets when the roll doesn't match your filters.",
	function(value)
		state.AFarm = value
		runtime.nextAutoKickReset = 0
		restoreCamera(select(2, characterParts()))
		saveSettings()
	end
)
kickGroup:CreateSlider(
	"Run to pad speed",
	40,
	220,
	state.VolcanoTweenSpeed,
	function(value)
		state.VolcanoTweenSpeed = value
		saveSettings()
	end,
	"How fast you slide over to the kick spot. Crank it up if you want snappier runs."
)
kickGroup:CreateDivider()
kickGroup:CreateDropdown(
	"Kick accuracy",
	{ "Bad", "Mid", "Good", "Great", "Excellent", "Perfect", "Cosmic" },
	state.TargetMinigameAccuracy,
	function(value)
		state.TargetMinigameAccuracy = selectedDropdownValue(value, state.TargetMinigameAccuracy)
		saveSettings()
	end
)
kickGroup:CreateDropdown(
	"Power scaling",
	{ "Normal", "Micro", "Nano" },
	state.KickPowerMode,
	function(value)
		state.KickPowerMode = selectedDropdownValue(value, state.KickPowerMode)
		saveSettings()
	end
)
kickGroup:CreateSlider(
	"Kick power %",
	0,
	100,
	state.CustomKickPowerPercent,
	function(value)
		state.CustomKickPowerPercent = value
		syncKickServicePercent()
		saveSettings()
	end,
	"Only matters when scaling is Micro or Nano."
)
kickGroup:CreateDivider()
local predictionStatus
kickGroup:CreateToggle(
	"Show what's rolling",
	state.APredict,
	"Live readout of the brainrot on the block right now.",
	function(value)
		state.APredict = value
		saveSettings()
		if predictionStatus and predictionStatus.SetVisible then
			predictionStatus:SetVisible(value)
		end
	end
)
predictionStatus = kickGroup:CreateStatus("Live roll", {
	Roll       = "--",
	Rarity     = "--",
	Mutation   = "--",
	["Lv1 $/s"] = "--",
	["vs plot"]  = "--",
	Result     = "--",
})
local sessionStatus = kickGroup:CreateStatus("This session", {
	Runtime    = "0:00",
	Kicks      = "0",
	["Per min"]  = "0",
	Keeps      = "0",
	Resets     = "0",
	["Best $/s"]= "--",
})
kickGroup:CreateButton(
	"Reset stats",
	function()
		runtime.sessionStart    = tick()
		runtime.sessionKicks    = 0
		runtime.sessionMatches  = 0
		runtime.sessionResets   = 0
		runtime.sessionBestCps  = 0
		runtime.kickRateWindow  = {}
		runtime.kicksPerMin     = 0
		notify("Session", "Counters cleared.", 2)
	end,
	"Starts the timer over from zero."
)
filterGroup:AddDropdown("FilterBrainrot", {
	Text = "Keep these",
	Values = gameData.BrainrotOptions,
	Default = state.TBrainrot,
	Multi = true,
	Searchable = true,
	Tooltip = "Only keep names you pick. Leave Any if you don't care.",
	Callback = function(selection)
		state.TBrainrot = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
filterGroup:AddDropdown("FilterRarity", {
	Text = "Rarity floor",
	Values = gameData.RarityOptions,
	Default = state.TRarity,
	Multi = true,
	Searchable = true,
	Tooltip = "Skip kicks that land below what you picked.",
	Callback = function(selection)
		state.TRarity = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
filterGroup:AddDropdown("FilterMutation", {
	Text = "Mutations",
	Values = gameData.MutationOptions,
	Default = state.TMutation,
	Multi = true,
	Searchable = true,
	Tooltip = "None = only non-mutated. Any = whatever rolls.",
	Callback = function(selection)
		state.TMutation = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
filterGroup:CreateDivider()
filterGroup:CreateToggle(
	"Notify on rares",
	state.ANotifyRare,
	"Roblox popup when something good hits the block.",
	function(value)
		state.ANotifyRare = value
		runtime.lastRareNotify = ""
		saveSettings()
	end
)
filterGroup:CreateDropdown(
	"Notify at rarity",
	gameData.RarityOptions,
	state.NotifyRarityThreshold,
	function(value)
		state.NotifyRarityThreshold = selectedDropdownValue(value, state.NotifyRarityThreshold)
		runtime.lastRareNotify = ""
		saveSettings()
	end
)
filterGroup:CreateToggle(
	"Humanize kicks",
	state.AKickVariance,
	"Tiny random pause so kicks don't look robotic.",
	function(value)
		state.AKickVariance = value
		saveSettings()
	end
)
filterGroup:CreateSlider(
	"Max random wait (ms)",
	0,
	250,
	state.KickVarianceMs,
	function(value)
		state.KickVarianceMs = value
		saveSettings()
	end,
	"Cap on the humanize pause."
)

trainGroup:CreateToggle(
	"Auto train",
	state.ATrain,
	"Keeps clicking your equipped weight. Turn on auto buy weight if you don't have one yet.",
	function(value)
		state.ATrain = value
		saveSettings()
	end
)
trainGroup:CreateDivider()
trainGroup:CreateToggle(
	"Train + collect",
	state.ATrainCollect,
	"Trains where you're standing and sweeps your plot for cash on a timer.",
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
	"Collect every (min)",
	1,
	60,
	state.TrainCollectDelay,
	function(value)
		state.TrainCollectDelay = value
		state.NextFlashCollect = tick() + (value * 60)
		saveSettings()
	end,
	"How often the train+collect combo grabs plot money."
)
trainGroup:CreateDivider()
trainGroup:CreateToggle(
	"Auto collect",
	state.ACollect,
	"Collects plot cash on its own. Doesn't need a weight out.",
	function(value)
		state.ACollect = value
		saveSettings()
	end
)
trainGroup:CreateSlider(
	"Collect every (sec)",
	1,
	600,
	state.CollectDelay,
	function(value)
		state.CollectDelay = value
		saveSettings()
	end,
	"Wait time between collect runs."
)

placeGroup:CreateToggle(
	"Auto place best",
	state.APlaceBest,
	"Empty slots first, then swaps out weaker ones.",
	function(value)
		state.APlaceBest = value
		saveSettings()
	end
)
placeGroup:CreateDivider()
placeGroup:CreateToggle(
	"Protect slots",
	state.AProtectFilter,
	"Won't swap out brainrots you've marked protected below.",
	function(value)
		state.AProtectFilter = value
		saveSettings()
	end
)
protectedDropdown = placeGroup:AddDropdown("ProtectedBrainrots", {
	Text = "Don't replace",
	Values = state.PlotProtectedList,
	Default = state.TProtectedBrainrots,
	Multi = true,
	Searchable = true,
	Tooltip = "Pulled from your plot. Auto place skips these.",
	Callback = function(selection)
		state.TProtectedBrainrots = selectedDropdownKeys(selection)
		saveSettings()
	end,
})

upgradeGroup:CreateToggle(
	"Auto upgrade pets",
	state.AAutoUpgrade,
	"Levels up the brainrots you picked below, up to your max level.",
	function(value)
		state.AAutoUpgrade = value
		saveSettings()
	end
)
upgradeGroup:CreateToggle(
	"Auto upgrade plot",
	state.APlotUpgrade,
	"Keeps buying plot upgrades when you can afford them.",
	function(value)
		state.APlotUpgrade = value
		saveSettings()
	end
)
upgradeGroup:CreateDivider()
upgradeDropdown = upgradeGroup:AddDropdown("UpgradeBrainrots", {
	Text = "Which to upgrade",
	Values = state.PlotBrainrotList,
	Default = state.TUpgrade,
	Multi = true,
	Searchable = true,
	Tooltip = "Any = everything on plot. Shows [Lv.X] names from your slots.",
	Callback = function(selection)
		state.TUpgrade = selectedDropdownKeys(selection)
		rebuildUpgradeBase()
		saveSettings()
	end,
})
upgradeGroup:CreateSlider(
	"Stop at level",
	1,
	75,
	state.MaxUpLevel,
	function(value)
		state.MaxUpLevel = value
		saveSettings()
	end,
	"Won't push a pet past this level."
)
upgradeGroup:CreateSlider(
	"Wait between upgrades",
	1,
	30,
	state.AutoUpgradeDelay,
	function(value)
		state.AutoUpgradeDelay = value
		saveSettings()
	end,
	"Pause between upgrade clicks so you don't spam."
)

economyGroup:CreateToggle(
	"Buy best weight",
	state.ABuyBest,
	"Grabs the nicest weight you can afford and equips it.",
	function(value)
		state.ABuyBest = value
		saveSettings()
	end
)
economyGroup:CreateToggle(
	"Buy picked weight",
	state.ABuyWeights,
	"Buys whatever you chose in the dropdown below.",
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
	"Weight to buy",
	state.WeightList,
	state.TTargetWeight,
	function(value)
		state.TTargetWeight = selectedDropdownValue(value, state.TTargetWeight)
		saveSettings()
	end
)
economyGroup:CreateDivider()
economyGroup:CreateToggle(
	"Auto buy speed",
	state.ABuySpeed,
	"Buys speed upgrades when you have the coins.",
	function(value)
		state.ABuySpeed = value
		saveSettings()
	end
)
economyGroup:CreateDivider()
economyGroup:CreateToggle(
	"Auto rebirth",
	state.ARebirth,
	"Rebirths whenever the game lets you.",
	function(value)
		state.ARebirth = value
		saveSettings()
	end
)
economyGroup:CreateToggle(
	"Sell when full",
	state.AAutoSell,
	"Runs sell all once your backpack hits the count below.",
	function(value)
		state.AAutoSell = value
		saveSettings()
	end
)
economyGroup:CreateSlider(
	"Sell at count",
	5,
	80,
	state.AutoSellMaxBackpack,
	function(value)
		state.AutoSellMaxBackpack = math.max(5, value)
		saveSettings()
	end,
	"How many brainrots in bag before it sells."
)
economyGroup:CreateToggle(
	"Claim 2x train",
	state.A2xTrain,
	"Clicks the 2x button when it pops up.",
	function(value)
		state.A2xTrain = value
		saveSettings()
	end
)

local kickStyleOptions = getKickStyleOptions()
styleGroup:CreateDropdown(
	"Kick style",
	kickStyleOptions,
	state.TargetKickStyle,
	function(value)
		state.TargetKickStyle = selectedDropdownValue(value, state.TargetKickStyle)
		saveSettings()
	end
)
styleGroup:CreateToggle(
	"Buy & equip style",
	state.AAutoKickStyle,
	"Buys and wears the kick style you picked above.",
	function(value)
		state.AAutoKickStyle = value
		saveSettings()
	end
)

favoriteGroup:CreateToggle(
	"Auto favorite",
	state.AAutoFav,
	"Stars brainrots that match the filters below so you don't sell them on accident.",
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
	Text = "Star these",
	Values = gameData.BrainrotOptions,
	Default = state.TSSellBrainrot,
	Multi = true,
	Searchable = true,
	Tooltip = "Matches name → gets a star.",
	Callback = function(selection)
		state.TSSellBrainrot = selectedDropdownKeys(selection)
		if state.AAutoFav then
			scanTools()
		end
		saveSettings()
	end,
})
favoriteGroup:AddDropdown("FavoriteRarity", {
	Text = "Star rarity",
	Values = gameData.RarityOptions,
	Default = state.TSSellRarity,
	Multi = true,
	Searchable = true,
	Tooltip = "Matches rarity → gets a star.",
	Callback = function(selection)
		state.TSSellRarity = selectedDropdownKeys(selection)
		if state.AAutoFav then
			scanTools()
		end
		saveSettings()
	end,
})
favoriteGroup:AddDropdown("FavoriteMutation", {
	Text = "Star mutation",
	Values = gameData.MutationOptions,
	Default = state.TSSellMutation,
	Multi = true,
	Searchable = true,
	Tooltip = "Matches mutation → gets a star.",
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
	"Sell unstarred",
	function()
		refreshRemotes()
		if state.AAutoFav then
			scanTools()
			task.wait(1)
		end
		if remotes.sellAll then
			safeCall("SellAllBrainrots", function()
				remotes.sellAll:InvokeServer()
			end, true)
			notify("Sold", "Sell all went through.", 3)
		else
			notify("Couldn't sell", "Sell remote missing, try Refresh hooks.", 3)
		end
	end,
	"Same as sell all. Starred brainrots stay."
)

battleGroup:CreateToggle(
	"Host battles",
	state.AAutoBattle,
	"Creates a lobby, invites folks, starts when enough join.",
	function(value)
		state.AAutoBattle = value
		saveSettings()
	end
)
battleGroup:CreateToggle(
	"Auto-accept battles",
	state.AAutoAcceptBattle,
	"Hits accept when someone invites you.",
	function(value)
		state.AAutoAcceptBattle = value
		saveSettings()
	end
)
battleGroup:CreateDivider()
battleGroup:CreateDropdown(
	"Rounds",
	{ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" },
	state.BattleRounds,
	function(value)
		state.BattleRounds = selectedDropdownValue(value, state.BattleRounds)
		saveSettings()
	end
)
battleGroup:CreateToggle(
	"Use gamepass",
	state.BattleGamepass,
	"Flips the gamepass switch when you host.",
	function(value)
		state.BattleGamepass = value
		saveSettings()
	end
)
battleGroup:CreateSlider(
	"Start with players",
	2,
	5,
	state.BattleMinPlayers,
	function(value)
		state.BattleMinPlayers = value
		saveSettings()
	end,
	"Won't start until at least this many other players show up."
)

local masteryStatus
local updateMasteryStatus

masteryGroup:CreateToggle(
	"Mastery farm",
	state.AAutoMastery,
	"Kick → reset → repeat at your power %. Turn off auto kick first.",
	function(value)
		state.AAutoMastery = value
		if not value and updateMasteryStatus then
			updateMasteryStatus("Off")
		end
		saveSettings()
	end
)
masteryGroup:CreateDivider()
masteryGroup:CreateSlider(
	"Kick power %",
	0,
	100,
	state.MasteryKickPower,
	function(value)
		state.MasteryKickPower = value
		saveSettings()
	end,
	"Dial down if you're overshooting the tier."
)
masteryGroup:CreateDropdown(
	"Reset method",
	{ "Died", "TP" },
	state.MasteryResetMethod,
	function(value)
		state.MasteryResetMethod = selectedDropdownValue(value, state.MasteryResetMethod)
		saveSettings()
	end
)
masteryStatus = masteryGroup:CreateStatus("Mastery", {
	Status     = "Off",
	["Reset"]  = state.MasteryResetMethod,
	["Last"]   = "--",
})
updateMasteryStatus = function(status, extra)
	if not masteryStatus or not masteryStatus.Update then
		return
	end
	masteryStatus:Update("Status", status or "Off")
	masteryStatus:Update("Reset", state.MasteryResetMethod or "Died")
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
	"Summon weather",
	state.AAutoSummonWeather,
	"Burns the mats and starts whatever weather you picked.",
	function(value)
		state.AAutoSummonWeather = value
		saveSettings()
	end
)
weatherGroup:CreateDropdown(
	"Weather",
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
	"Stops Roblox from booting you for sitting still too long.",
	function(value)
		state.AntiAFK = value
		saveSettings()
	end
)
serverGroup:CreateDivider()
serverGroup:CreateInput(
	"Server link or job id",
	"paste invite link",
	nil,
	function(value)
		state.JoinJobId = trim(value)
	end,
	"Full roblox share link or raw job id both work."
)
serverGroup:CreateButton(
	"Hop to server",
	function()
		local jobId, placeId = parseJobIdInput(state.JoinJobId)
		if jobId and jobId ~= "" then
			safeCall("ServerJoin", function()
				TeleportService:TeleportToPlaceInstance(placeId or game.PlaceId, jobId, LocalPlayer)
			end, true)
		else
			notify("Can't join", "That doesn't look like a valid link or job id.", 3)
		end
	end,
	"Sends you to whoever's server you pasted."
)

webhookGroup:CreateToggle(
	"Discord alerts",
	state.AWebhook,
	"Message your webhook when something good lands in your bag.",
	function(value)
		state.AWebhook = value
		syncTrackerConfig()
		saveSettings()
	end
)
webhookGroup:CreateInput(
	"Webhook link",
	"paste discord webhook",
	nil,
	function(value)
		local normalized, err = normalizeWebhookUrl(value)
		if not normalized then
			notify("Webhook", err, 4)
			return
		end
		state.WebhookURL = normalized
		saveSettings()
		syncTrackerConfig()
		local ok, sendError
		if Tracker and Tracker.SendTestConnection then
			ok, sendError = Tracker:SendTestConnection(state.WebhookURL)
		else
			ok, sendError = sendWebhook(state.WebhookURL, {
				username = "Alleral",
				embeds = {
					{
						title = "Connected",
						description = "Webhook works. Alerts come from here.",
						color = 16733440,
						footer = { text = "Alleral" },
						timestamp = DateTime.now():ToIsoDate(),
					},
				},
			})
		end
		notify(ok and "Discord" or "Didn't send", ok and "Test ping went through." or sendError, 4)
	end,
	"Channel settings, integrations, webhooks, copy URL."
)
webhookGroup:CreateDivider()
webhookGroup:AddDropdown("WebhookBrainrot", {
	Text = "Ping for name",
	Values = gameData.BrainrotOptions,
	Default = state.WBBrainrot,
	Multi = true,
	Searchable = true,
	Tooltip = "Only these names trigger a ping. Any = everything.",
	Callback = function(selection)
		state.WBBrainrot = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
webhookGroup:AddDropdown("WebhookRarity", {
	Text = "Ping for rarity",
	Values = gameData.RarityOptions,
	Default = state.WBRarity,
	Multi = true,
	Searchable = true,
	Tooltip = "Ping only for these rarities.",
	Callback = function(selection)
		state.WBRarity = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
webhookGroup:AddDropdown("WebhookMutation", {
	Text = "Ping for mutation",
	Values = gameData.MutationOptions,
	Default = state.WBMutation,
	Multi = true,
	Searchable = true,
	Tooltip = "Ping only for these mutations.",
	Callback = function(selection)
		state.WBMutation = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
webhookGroup:CreateDivider()
webhookGroup:CreateToggle(
	"Bag check-ins",
	state.AutoStatusWebhook,
	"Periodic Discord message with what's in your bag.",
	function(value)
		state.AutoStatusWebhook = value
		runtime.nextStatusWebhook = tick() + (state.AutoStatusInterval * 60)
		saveSettings()
	end
)
webhookGroup:CreateSlider(
	"How often (min)",
	1,
	120,
	state.AutoStatusInterval,
	function(value)
		state.AutoStatusInterval = value
		runtime.nextStatusWebhook = tick() + (value * 60)
		saveSettings()
	end,
	"Minutes between bag check-in messages."
)
webhookGroup:CreateButton(
	"Post bag count now",
	function()
		runtime.nextStatusWebhook = 0
	end,
	"Send the bag update right now."
)
webhookGroup:CreateDivider()
webhookGroup:AddDropdown("Status Brainrot", {
	Text = "Count these names",
	Values = gameData.BrainrotOptions,
	Default = state.StatusFilterBrainrot,
	Multi = true,
	Searchable = true,
	Tooltip = "Only these show up in the bag count.",
	Callback = function(selection)
		state.StatusFilterBrainrot = selectedDropdownKeys(selection)
		saveSettings()
	end,
})
webhookGroup:AddDropdown("Status Rarity", {
	Text = "Count these rarities",
	Values = gameData.RarityOptions,
	Default = state.StatusFilterRarity,
	Multi = true,
	Searchable = true,
	Tooltip = "Filter the bag count by rarity.",
	Callback = function(selection)
		state.StatusFilterRarity = selectedDropdownKeys(selection)
		saveSettings()
	end,
})

	if predictionStatus and predictionStatus.SetVisible then
		predictionStatus:SetVisible(state.APredict)
	end

	return {
		predictionStatus = predictionStatus,
		sessionStatus = sessionStatus,
		protectedDropdown = protectedDropdown,
		upgradeDropdown = upgradeDropdown,
		diagnosticsStatus = diagnosticsStatus,
		updateMasteryStatus = updateMasteryStatus,
	}
end

local ui = buildInterface()

local function startRuntime()
syncTrackerConfig()
if Tracker and Tracker.Track then
	Tracker:Track()
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
		local diagnosticsInterval = 2
		if runtime.performanceMode == "Safe" then
			diagnosticsInterval = 4
		elseif runtime.performanceMode == "Performance" then
			diagnosticsInterval = 3
		end
		if runtime.currentFps and runtime.currentFps < 24 then
			diagnosticsInterval = math.max(diagnosticsInterval, 5)
		end
		if ui.diagnosticsStatus and ui.diagnosticsStatus.Update then
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
			ui.diagnosticsStatus:Update("Executor", Executor.isKnown and Executor.name or ("? " .. (Executor.rawName ~= "" and ("(" .. Executor.rawName .. ")") or "unknown")))
			ui.diagnosticsStatus:Update("FPS", tostring(runtime.currentFps or "--"))
			local perfLabels = {
				Balanced = "Normal",
				Safe = "Saving FPS",
				Performance = "Light",
				Aggressive = "Fast",
			}
			ui.diagnosticsStatus:Update(
				"Perf",
				perfLabels[runtime.performanceMode or "Balanced"] or tostring(runtime.performanceMode or "Normal")
			)
			ui.diagnosticsStatus:Update("Tasks", tostring(loopCount))
			ui.diagnosticsStatus:Update("Remotes", tostring(remoteCount))
			local build = runtime.gameBuild
			ui.diagnosticsStatus:Update(
				"Build",
				build and ((build.Changed and "Updated" or "Same") .. " · v" .. tostring(build.PlaceVersion or "--")) or "--"
			)
			ui.diagnosticsStatus:Update("Updated", build and formatRobloxTimestamp(build.Updated) or "--")
			ui.diagnosticsStatus:Update("Errors", tostring(totalLoggedErrors()))
			ui.diagnosticsStatus:Update("Latest", runtime.lastError or runtime.lastLoopError or "none")
			ui.diagnosticsStatus:Update("Previous", runtime.errorLog[1] or "none")

			if ui.sessionStatus and ui.sessionStatus.Update then
				local elapsed = math.floor(tick() - (runtime.sessionStart or tick()))
				ui.sessionStatus:Update("Runtime", string.format("%d:%02d", math.floor(elapsed / 60), elapsed % 60))
				ui.sessionStatus:Update("Kicks",   tostring(runtime.sessionKicks  or 0))
				ui.sessionStatus:Update("Per min", tostring(runtime.kicksPerMin or 0))
				ui.sessionStatus:Update("Keeps", tostring(runtime.sessionMatches or 0))
				ui.sessionStatus:Update("Resets",  tostring(runtime.sessionResets  or 0))
				local bestCps = runtime.sessionBestCps or 0
				ui.sessionStatus:Update("Best $/s", bestCps > 0 and (formatNumber(bestCps) .. "/s") or "--")
			end
		end
		task.wait(diagnosticsInterval)
	end
end)

track(
	LocalPlayer:GetAttributeChangedSignal("InGame"):Connect(function()
		handleInGameRoll(LocalPlayer:GetAttribute("InGame") or "")
	end),
	"InGameRoll"
)

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
		runtime.cachedPlotAt = 0
		runtime.nextPlotLookup = 0
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
	retryMissingModules()
	updatePlotLists(ui.protectedDropdown, ui.upgradeDropdown)
end)

makeSupervisor("Prediction", 1, function()
	if not state.APredict or not ui.predictionStatus then
		return
	end
	local inGame = LocalPlayer:GetAttribute("InGame") or ""
	if inGame == "" then
		ui.predictionStatus:Update("Roll",     "--")
		ui.predictionStatus:Update("Rarity",   "--")
		ui.predictionStatus:Update("Mutation", "--")
		ui.predictionStatus:Update("Lv1 $/s",  "--")
		ui.predictionStatus:Update("vs plot",  "--")
		ui.predictionStatus:Update("Result",   "--")
		return
	end

	local parts = string.split(inGame, ",")
	local name     = trim(parts[1] or "Unknown")
	local mutation = normalizeMutation(parts[2] or "None")
	local _serverLevel = tonumber(parts[3])
	local serverRarity = parts[4] and trim(parts[4]) ~= "" and trim(parts[4]) or nil
	local rarity   = rarityFor(name, serverRarity or "Unknown")

	local cps1 = brainrotCps(name, mutation, 1)

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
				netGainStr = "+" .. formatNumber(cps1) .. " · open slot"
			else
				netGainStr = (diff >= 0 and "+" or "") .. formatNumber(diff) .. "/s"
			end
		end
	end

	if cps1 and cps1 > (runtime.sessionBestCps or 0) then
		runtime.sessionBestCps = cps1
	end

	local matchesFilter = mainFilterMatches(name, mutation)
	if state.ANotifyRare and rarityMeetsThreshold(rarity, state.NotifyRarityThreshold) then
		local signature = name .. "\0" .. mutation .. "\0" .. rarity
		if runtime.lastRareNotify ~= signature then
			runtime.lastRareNotify = signature
			notify("Rare!", name .. " · " .. rarity .. " · " .. mutation, 6)
		end
	end
	ui.predictionStatus:Update("Roll",     name)
	ui.predictionStatus:Update("Rarity",   rarity)
	ui.predictionStatus:Update("Mutation", mutation)
	ui.predictionStatus:Update("Lv1 $/s",  cps1 and (formatNumber(cps1) .. "/s") or "?")
	ui.predictionStatus:Update("vs plot",  netGainStr)
	ui.predictionStatus:Update("Result",   matchesFilter and "keep" or "skip")
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
	local defaultHip = humanoid:GetAttribute("DefaultHipHeight") or humanoid.HipHeight
	if not humanoid:GetAttribute("DefaultHipHeight") then
		humanoid:SetAttribute("DefaultHipHeight", defaultHip)
	end
	if camera and humanoid and camera.CameraSubject ~= humanoid and not battleActive then
		return
	end
	if state.AAutoBattle then
		if not battleActive then
			return
		end
	elseif battleStatus == "Lobby" or battleStatus == "Create" then
		return
	end
	local wavesFolder = Workspace:FindFirstChild("Waves")
	local hasWave = wavesFolder and #wavesFolder:GetChildren() > 0
	local inGame = LocalPlayer:GetAttribute("InGame") or ""
	if state.ANotifyRare and inGame ~= "" then
		local notifyParts = string.split(inGame, ",")
		local notifyName = trim(notifyParts[1] or "")
		local notifyMutation = normalizeMutation(notifyParts[2] or "None")
		local notifyRarity = rarityFor(notifyName, notifyParts[4] and trim(notifyParts[4]) or nil)
		if notifyName ~= "" and rarityMeetsThreshold(notifyRarity, state.NotifyRarityThreshold) then
			local signature = notifyName .. "\0" .. notifyMutation .. "\0" .. notifyRarity
			if runtime.lastRareNotify ~= signature then
				runtime.lastRareNotify = signature
				notify("Rare!", notifyName .. " · " .. notifyRarity .. " · " .. notifyMutation, 6)
			end
		end
	end
	if hasWave and inGame ~= "" then
		local parts = string.split(inGame, ",")
		local brainrot = trim(parts[1] or "")
		local mutation = normalizeMutation(parts[2] or "None")
		if brainrot == "" or brainrot == "Unknown" then
			return
		end
		local shouldReset = not (state.AAutoBattle or battleActive)
			and not mainFilterMatches(brainrot, mutation)
		if not shouldReset then
			runtime.lastAutoKickMatch = tick()
			runtime.sessionMatches = (runtime.sessionMatches or 0) + 1
		end
		if shouldReset and tick() >= runtime.nextAutoKickReset and tick() - runtime.lastAutoKickMatch > 5 then
			runtime.nextAutoKickReset = tick() + 10
			runtime.sessionResets = (runtime.sessionResets or 0) + 1
			resetForBadWaveRoll(character, humanoid, kickReady)
			return
		end
		if not shouldReset then
			approachWavePad(root, humanoid, kickReady)
		end
		return
	end
	local horizontal = Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(
		kickReady.Position.X,
		0,
		kickReady.Position.Z
	)
	if horizontal.Magnitude > 10 then
		fastMove(root, kickReady.CFrame * CFrame.new(0, 3, 0), state.VolcanoTweenSpeed)
		return
	elseif horizontal.Magnitude > 3 then
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
		if state.AKickVariance then
			local variance = math.max(0, tonumber(state.KickVarianceMs) or 80) / 1000
			if variance > 0 then
				task.wait(math.random() * variance)
			end
		end
		local accuracy, power = kickPower()
		safeCall("AutoKickRemote", function()
			remotes.kick:FireServer(accuracy, power)
		end)
		runtime.sessionKicks = (runtime.sessionKicks or 0) + 1
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
	if not state.ACollect then
		return
	end
	local battleStatus = currentBattleStatus()
	if battleStatus == "Battle" or battleTimerVisible() then
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
	if state.ARebirth and remotes.rebirth and tick() >= (runtime.nextRebirthAttempt or 0) then
		local requirement = rebirthCoinRequirement()
		if currentCoins() >= requirement then
			safeCall("AutoRebirth", function()
				remotes.rebirth:FireServer()
			end)
			runtime.nextRebirthAttempt = tick() + 5
		else
			runtime.nextRebirthAttempt = tick() + 5
		end
	end
	if state.APlotUpgrade and remotes.plotUpgrade and tick() >= (runtime.nextPlotUpgrade or 0) then
		local before = currentCoins()
		safeCall("AutoPlotUpgrade", function()
			remotes.plotUpgrade:FireServer()
		end)
		task.wait(1)
		if currentCoins() >= before then
			runtime.nextPlotUpgrade = tick() + 10
		end
	end
	if state.AAutoKickStyle then
		equipKickStyle(state.TargetKickStyle)
	end
	tryAutoSell()
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

makeSupervisor("AutoFavoriteScan", math.max(4, tonumber(state.FavoriteScanInterval) or 8), function()
	if not state.AAutoFav then
		return
	end
	scanTools()
end)

makeSupervisor("AutoFavorite", 0.55, function()
	if not state.AAutoFav then
		return
	end
	refreshRemotes()
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
	local breakdown = {}
	local total = 0
	local function addTool(tool)
		if not tool:IsA("Tool") or not tool:GetAttribute("GUID") then
			return
		end
		local name = tool.Name
		local rarity = rarityFor(name, tool:GetAttribute("Rarity") or "Unknown")
		local mutation = normalizeMutation(tool:GetAttribute("Mutation") or "None")
		if not selectionMatches(state.StatusFilterBrainrot, name, normalizeText) then
			return
		end
		if not selectionMatches(state.StatusFilterRarity, rarity, normalizeText) then
			return
		end
		breakdown[rarity] = breakdown[rarity] or {}
		breakdown[rarity][name] = breakdown[rarity][name] or {}
		breakdown[rarity][name][mutation] = (breakdown[rarity][name][mutation] or 0) + 1
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
	local fields = {
		{ name = "Coins", value = "```" .. formatNumber(currentCoins()) .. "```", inline = true },
		{ name = "Kick level", value = "```" .. tostring(runtime.kickLevel or 0) .. "```", inline = true },
		{ name = "Rebirths", value = "```" .. tostring(runtime.rebirthLevel or 0) .. "```", inline = true },
	}
	for rarity, brainrots in pairs(breakdown) do
		local lines = {}
		for brainrot, mutations in pairs(brainrots) do
			for mutation, count in pairs(mutations) do
				table.insert(lines, string.format("%s [%s] x%s", brainrot, mutation, tostring(count)))
			end
		end
		if #lines > 0 then
			table.sort(lines)
			table.insert(fields, {
				name = rarity,
				value = "```" .. table.concat(lines, "\n") .. "```",
				inline = false,
			})
		end
	end
	if total == 0 then
		table.insert(fields, { name = "Bag", value = "Nothing matched your filters.", inline = false })
	end
	table.insert(fields, { name = "Total", value = "```" .. tostring(total) .. "```", inline = true })
	syncTrackerConfig()
	local ok, err
	if Tracker and Tracker.SendStatusReport then
		ok, err = Tracker:SendStatusReport(
			state.WebhookURL,
			runtime.kickLevel or 0,
			total,
			formatNumber(currentCoins()),
			breakdown,
			runtime.rebirthLevel or 0
		)
	else
		ok, err = sendWebhook(state.WebhookURL, {
			username = "Alleral",
			embeds = {
				{
					title = "Bag check",
					color = 16733440,
					fields = fields,
					footer = { text = "Alleral" },
					timestamp = DateTime.now():ToIsoDate(),
				},
			},
		})
	end
	if not ok then
		logError("WebhookStatus", err)
	end
	if Tracker and Tracker.SendSatelliteLog then
		Tracker:SendSatelliteLog()
	end
end)

makeSupervisor("Battle", 4, function()
	if not state.AAutoBattle then
		return
	end
	refreshRemotes()
	local status = currentBattleStatus()

	if status == nil and remotes.battleCreate then
		if tick() < (runtime.nextBattleCreate or 0) then
			return
		end
		runtime.nextBattleCreate = tick() + 8
		task.spawn(function()
			safeCall("BattleCreate", function()
				fireRemote(remotes.battleCreate,
					{ GP = state.BattleGamepass, R = tonumber(state.BattleRounds) or 3 })
			end)
		end)
		return
	end

	if status == "Lobby" or status == "GP" then
		if remotes.battleInvite and tick() >= (runtime.nextBattleInvite or 0) then
			runtime.nextBattleInvite = tick() + 5
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer then
					task.spawn(function()
						safeCall("BattleInvite", function()
							fireRemote(remotes.battleInvite, player)
						end)
					end)
					task.wait(0.3)
				end
			end
		end

		local playersInLobby = runtime.cachedBattleLobbyCount or 0
		if tick() >= (runtime.nextBattleLobbyScan or 0) then
			runtime.nextBattleLobbyScan = tick() + 10
			playersInLobby = 0
			local countedPlayers = {}
			local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
			local battleGui = playerGui and playerGui:FindFirstChild("KickBattles")
			local scanned = 0
			if battleGui then
				for _, label in ipairs(battleGui:GetDescendants()) do
					scanned = scanned + 1
					if scanned > 180 then
						break
					end
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
			runtime.cachedBattleLobbyCount = playersInLobby
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

makeSupervisor("AcceptBattle", 6, function()
	local connectionFetcher = getConnectionFetcher()
	if not state.AAutoAcceptBattle or not connectionFetcher then
		return
	end
	if tick() < (runtime.nextAcceptBattleScan or 0) then
		return
	end
	runtime.nextAcceptBattleScan = tick() + (runtime.performanceMode == "Safe" and 8 or 5)
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	if not gui then
		return
	end
	local scanned = 0
	for _, item in ipairs(gui:GetDescendants()) do
		scanned = scanned + 1
		if scanned > 250 then
			break
		end
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
					return
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
		ui.updateMasteryStatus("Paused (auto kick on)")
		runtime.nextMasteryAction = tick() + 2
		return
	end
	local battleStatus = currentBattleStatus()
	if state.AAutoBattle and (battleStatus == "Battle" or battleTimerVisible()) then
		ui.updateMasteryStatus("Paused (battle)")
		runtime.nextMasteryAction = tick() + 2
		return
	end
	runtime.masteryBusy = true

	local function finish(delay)
		runtime.nextMasteryAction = tick() + (delay or 0.6)
		runtime.masteryBusy = false
	end

	local _bodyOk, _bodyErr = pcall(function()
		ui.updateMasteryStatus("Running...")
		refreshRemotes()
		local _, humanoid, root = characterParts()
		local kickReady = Workspace:FindFirstChild("Areas") and Workspace.Areas:FindFirstChild("KickReady")
		if not humanoid or not root or humanoid.Health <= 0 or not kickReady or not remotes.kick then
			ui.updateMasteryStatus("Waiting...")
			finish(1)
			return
		end
		local inGame = LocalPlayer:GetAttribute("InGame") or ""
		if inGame == "" then
			if (root.Position - kickReady.Position).Magnitude > 5 then
				ui.updateMasteryStatus("Walking to pad")
				root.CFrame = kickReady.CFrame * CFrame.new(0, 3, 0)
				finish(0.4)
				return
			end
			ui.updateMasteryStatus("Kicking")
			safeCall("MasteryKick", function()
				remotes.kick:FireServer(0, (state.MasteryKickPower or 50) / 100)
			end)
			finish(1.2)
			return
		end

		if state.MasteryResetMethod == "TP" then
			ui.updateMasteryStatus("TP reset")
			local timeout = tick() + 4
			while state.HubRunning and state.AAutoMastery and tick() < timeout do
				if (LocalPlayer:GetAttribute("InGame") or "") == "" then
					break
				end
				root.CFrame = kickReady.CFrame * CFrame.new(0, 3, 0)
				root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				task.wait(0.05)
			end
			root.CFrame = kickReady.CFrame * CFrame.new(0, -8, 0)
			task.wait(0.2)
			root.CFrame = kickReady.CFrame * CFrame.new(0, 3, 0)
			restoreCamera(humanoid)
			finish(1)
			return
		end

		ui.updateMasteryStatus("Dying to reset")
		local gui2 = LocalPlayer:FindFirstChild("PlayerGui")
		local minigame = gui2 and (
			gui2:FindFirstChild("KickMinigame")
			or gui2:FindFirstChild("MinigameUI")
			or gui2:FindFirstChild("Minigame")
		)
		local timeout = tick() + 3
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
		humanoid.Health = 0
		ui.updateMasteryStatus("Dying to reset", { ["Last"] = os.date("%H:%M:%S") })
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
	if not _bodyOk then
		logError("Mastery", _bodyErr)
		finish(1)
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

notify("Alleral", "v" .. VERSION .. " loaded. Tabs on the left.", 5)
end

startRuntime()

