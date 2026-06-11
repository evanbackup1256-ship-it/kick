local Telemetry = {}
Telemetry.Version = "2.2"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local EVENT_COLORS = {
	session_start = 10181046,
	inject_start = 3447003,
	inject_loaded = 3066993,
	inject_failed = 15158332,
	error = 15105570,
	heartbeat = 9807270,
	session_end = 9936031,
	milestone = 15844367,
	log = 7506394,
}

local TITLE_MAP = {
	session_start = "Session started",
	inject_start = "Inject started",
	inject_loaded = "Inject succeeded",
	inject_failed = "Inject failed",
	error = "Runtime error",
	heartbeat = "Session heartbeat",
	session_end = "Session ended",
	milestone = "Milestone",
	log = "Event log",
}

local EXECUTOR_GLOBALS = {
	"syn", "fluxus", "http", "http_service", "Xeno", "Volt", "Madium", "Nihon",
	"Cryptic", "Sentinel", "Serenity", "Atlantis", "Zorara", "Wave", "Electron",
	"Potassium", "Velocity", "Krnl", "jjsploit", "Bunni", "Valyse", "Krypton",
	"Evon", "delta", "celery",
}

local API_CHECKS = {
	{ "http_request", "http_request" },
	{ "request", "request" },
	{ "readfile", "readfile" },
	{ "writefile", "writefile" },
	{ "isfile", "isfile" },
	{ "listfiles", "listfiles" },
	{ "makefolder", "makefolder" },
	{ "loadstring", "loadstring" },
	{ "getconnections", "getconnections" },
	{ "hookfunction", "hookfunction" },
	{ "hookmetamethod", "hookmetamethod" },
	{ "getrawmetatable", "getrawmetatable" },
	{ "setreadonly", "setreadonly" },
	{ "firetouchinterest", "firetouchinterest" },
	{ "firesignal", "firesignal" },
	{ "getnamecallmethod", "getnamecallmethod" },
	{ "checkcaller", "checkcaller" },
	{ "cloneref", "cloneref" },
	{ "gethui", "gethui" },
	{ "getcustomasset", "getcustomasset" },
	{ "identifyexecutor", "identifyexecutor" },
	{ "getexecutorname", "getexecutorname" },
}

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()

local function trim(value)
	return tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function coreApi()
	return ENV.Alleral_Core
end

local function requestFunction()
	local core = coreApi()
	if core and type(core.requestFunction) == "function" then
		local fn = core.requestFunction()
		if fn then
			return fn
		end
	end
	for _, name in ipairs({ "http_request", "request", "Request" }) do
		local fn = ENV[name]
		if type(fn) == "function" then
			return fn
		end
	end
	local syn = ENV.syn
	if type(syn) == "table" and type(syn.request) == "function" then
		return syn.request
	end
	for _, libName in ipairs({ "Volt", "Wave", "Solara", "Solora", "Cryptic", "Xeno", "Electron" }) do
		local lib = ENV[libName]
		if type(lib) == "table" and type(lib.request) == "function" then
			return lib.request
		end
	end
	if type(HttpService.RequestAsync) == "function" then
		return function(opts)
			local ok, response = pcall(function()
				return HttpService:RequestAsync({
					Url = opts.Url,
					Method = opts.Method or "GET",
					Headers = opts.Headers,
					Body = opts.Body,
				})
			end)
			if ok then
				return response
			end
			return { Success = false, StatusMessage = tostring(response) }
		end
	end
	return nil
end

local function isoNow()
	local ok, value = pcall(function()
		return DateTime.now():ToIsoDate()
	end)
	return ok and value or nil
end

local function clip(text, limit)
	text = trim(text)
	if #text <= limit then
		return text
	end
	return text:sub(1, limit - 3) .. "..."
end

local function mergeConfig(base, extra)
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

local function newSessionId()
	local ok, guid = pcall(function()
		return HttpService:GenerateGUID(false)
	end)
	if ok and type(guid) == "string" and guid ~= "" then
		return "aller-" .. guid:gsub("-", ""):sub(1, 12)
	end
	return "aller-" .. tostring(math.random(100000, 999999)) .. tostring(os.time())
end

local function executorProfile()
	local core = ENV.Alleral_Core
	if core and type(core.executorTelemetryProfile) == "function" then
		return core.executorTelemetryProfile()
	end

	local name, version = "Unknown", nil
	for _, id in ipairs({
		"identifyexecutor",
		"getexecutorname",
		"whatexecutor",
		"getexecutor",
	}) do
		local fn = ENV[id]
		if type(fn) == "function" then
			local ok, a, b = pcall(fn)
			if ok then
				if type(a) == "string" and a ~= "" then
					name = a
					if type(b) == "string" and b ~= "" then
						version = b
					elseif type(b) == "number" then
						version = tostring(b)
					end
					break
				end
			end
		end
	end
	if name == "Unknown" then
		if ENV.syn then
			name = "Synapse"
		elseif ENV.KRNL_LOADED then
			name = "Krnl"
		elseif ENV.Volt then
			name = "Volt"
		elseif ENV.fluxus then
			name = "Fluxus"
		elseif ENV.shared and type(ENV.shared.solara) == "table" then
			name = "Solara"
		elseif ENV.shared and type(ENV.shared.Solora) == "table" then
			name = "Solara"
		end
	end

	local apis = {}
	for _, pair in ipairs(API_CHECKS) do
		local key, globalName = pair[1], pair[2]
		local value = ENV[globalName]
		if type(value) == "function" then
			table.insert(apis, key)
		end
	end
	for _, globalName in ipairs(EXECUTOR_GLOBALS) do
		if ENV[globalName] ~= nil and not table.find(apis, globalName) then
			table.insert(apis, globalName .. "(lib)")
		end
	end
	table.sort(apis)

	local loaderCaps = ENV.Alleral_LoaderCapabilities or {}
	return {
		name = name,
		version = version,
		http = loaderCaps.http == true or requestFunction() ~= nil,
		loadstring = loaderCaps.loadstring == true or type(ENV.loadstring) == "function",
		readfile = loaderCaps.readfile == true or type(ENV.readfile) == "function",
		apis = apis,
	}
end

local function liveStats()
	local ping, fps, players = nil, nil, #Players:GetPlayers()
	pcall(function()
		local item = Stats.Network.ServerStatsItem["Data Ping"]
		if item and item.GetValue then
			ping = math.floor(item:GetValue())
		end
	end)
	pcall(function()
		local item = Stats.PerformanceStats.FrameRate
		if item and item.GetValue then
			fps = math.floor(item:GetValue())
		end
	end)
	local platform = nil
	pcall(function()
		platform = tostring(UserInputService:GetPlatform())
	end)
	return {
		pingMs = ping,
		fps = fps,
		players = players,
		platform = platform,
		uptimeSec = Telemetry._sessionStartedAt and math.floor(tick() - Telemetry._sessionStartedAt) or nil,
	}
end

local function serverInfo()
	local universeId = nil
	pcall(function()
		universeId = game.GameId
	end)
	local privateServer = false
	pcall(function()
		privateServer = game.PrivateServerId ~= nil and game.PrivateServerId ~= ""
	end)
	return {
		placeId = game.PlaceId,
		universeId = universeId,
		jobId = tostring(game.JobId),
		privateServer = privateServer,
	}
end

local function profileUrl(userId)
	return string.format("https://www.roblox.com/users/%d/profile", tonumber(userId) or 0)
end

local function avatarUrl(userId)
	return string.format(
		"https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png",
		tonumber(userId) or 0
	)
end

local function joinUrl(placeId, jobId)
	return string.format(
		"https://www.roblox.com/games/start?placeId=%s&gameInstanceId=%s",
		tostring(placeId or game.PlaceId),
		tostring(jobId or game.JobId)
	)
end

local function robloxJoinUrl(placeId, jobId)
	return string.format(
		"roblox://experiences/start?placeId=%s&gameInstanceId=%s",
		tostring(placeId or game.PlaceId),
		tostring(jobId or game.JobId)
	)
end

local function embedField(name, value, inline)
	local text = clip(value, 1024)
	if text == "" then
		text = "—"
	end
	return {
		name = name,
		value = "```" .. text .. "```",
		inline = inline == true,
	}
end

local function linkField(name, label, url, inline)
	url = trim(url)
	if url == "" then
		return embedField(name, "—", inline)
	end
	return {
		name = name,
		value = string.format("[%s](%s)", label, url),
		inline = inline == true,
	}
end

function Telemetry:EnsureSession()
	if self._sessionId then
		return self._sessionId
	end
	self._sessionId = newSessionId()
	self._sessionStartedAt = tick()
	self._eventLog = {}
	self._errorCounts = {}
	self._errorLastSent = {}
	self:_appendLog("session", "Session " .. self._sessionId .. " created")
	return self._sessionId
end

function Telemetry:_appendLog(kind, summary, detail)
	self:EnsureSession()
	local entry = {
		at = isoNow(),
		kind = kind,
		summary = clip(summary, 180),
		detail = detail and clip(detail, 300) or nil,
	}
	table.insert(self._eventLog, entry)
	while #self._eventLog > 30 do
		table.remove(self._eventLog, 1)
	end
end

function Telemetry:_formatEventLog(limit)
	limit = limit or 8
	local lines = {}
	local start = math.max(1, #self._eventLog - limit + 1)
	for i = start, #self._eventLog do
		local entry = self._eventLog[i]
		local line = string.format("[%s] %s: %s", entry.kind or "?", entry.at or "?", entry.summary or "?")
		table.insert(lines, line)
	end
	if #lines == 0 then
		return "—"
	end
	return table.concat(lines, "\n")
end

function Telemetry:Configure(extra)
	self._config = mergeConfig(self._config, extra)
	self:EnsureSession()
	if self:IsEnabled() and not self._lifecycleHooked then
		self:HookLifecycle()
	end
	return self._config
end

function Telemetry:UsesRelay()
	local cfg = self._config or {}
	return trim(cfg.relayUrl) ~= ""
end

function Telemetry:IsEnabled()
	local cfg = self._config or {}
	if cfg.enabled == false then
		return false
	end
	return self:UsesRelay() and trim(cfg.relayUrl) ~= "" and trim(cfg.apiKey) ~= ""
end

function Telemetry:_playerInfo()
	local player = Players.LocalPlayer
	if not player then
		return {
			name = "Unknown",
			displayName = "Unknown",
			userId = 0,
			accountAge = 0,
			profileUrl = profileUrl(0),
			avatarUrl = avatarUrl(0),
		}
	end
	return {
		name = player.Name,
		displayName = player.DisplayName,
		userId = player.UserId,
		accountAge = player.AccountAge,
		profileUrl = profileUrl(player.UserId),
		avatarUrl = avatarUrl(player.UserId),
	}
end

function Telemetry:_context(extra)
	local loaderMeta = ENV.Alleral_LoaderMeta or {}
	local caps = ENV.Alleral_LoaderCapabilities or loaderMeta.capabilities
	local placeName = "Unknown"
	pcall(function()
		local info = MarketplaceService:GetProductInfo(game.PlaceId)
		placeName = info and info.Name or placeName
	end)
	local exec = executorProfile()
	local srv = serverInfo()
	local stats = liveStats()
	local context = {
		sessionId = self:EnsureSession(),
		executor = exec.name,
		executorVersion = exec.version,
		executorProfile = exec,
		loaderVersion = loaderMeta.version or ENV.Alleral_LoaderVersion,
		gameId = loaderMeta.profile,
		gameName = placeName,
		scriptName = loaderMeta.profile,
		scriptVersion = loaderMeta.scriptVersion,
		placeId = srv.placeId,
		universeId = srv.universeId,
		jobId = srv.jobId,
		privateServer = srv.privateServer,
		joinUrl = joinUrl(srv.placeId, srv.jobId),
		robloxJoinUrl = robloxJoinUrl(srv.placeId, srv.jobId),
		source = loaderMeta.source,
		capabilities = caps,
		stats = stats,
	}
	return mergeConfig(context, extra or {})
end

function Telemetry:_buildPayload(event, contextExtra, errorInfo, notes)
	return {
		event = event,
		timestamp = isoNow(),
		sessionId = self:EnsureSession(),
		player = self:_playerInfo(),
		context = self:_context(contextExtra),
		error = errorInfo,
		notes = notes,
		eventLog = self._eventLog,
	}
end

function Telemetry:_buildDescription(event, player, context)
	local join = context.joinUrl or joinUrl(context.placeId, context.jobId)
	local lines = {}
	if event == "inject_loaded" or event == "session_start" or event == "inject_start" then
		table.insert(lines, string.format("**[Join this server](%s)**", join))
		table.insert(lines, string.format("[Open in Roblox app](%s)", context.robloxJoinUrl or robloxJoinUrl()))
	end
	if player.profileUrl then
		table.insert(lines, string.format("[Player profile](%s)", player.profileUrl))
	end
	if #lines == 0 then
		return nil
	end
	return table.concat(lines, "\n")
end

function Telemetry:_buildEmbed(payload)
	local event = tostring(payload.event or "unknown")
	local player = payload.player or {}
	local context = payload.context or {}
	local errorInfo = payload.error or {}
	local cfg = self._config or {}
	local brand = trim(cfg.brand) ~= "" and trim(cfg.brand) or "Alleral Ops"
	local exec = context.executorProfile or {}
	local stats = context.stats or {}

	local fields = {
		embedField("Session", context.sessionId or payload.sessionId, true),
		embedField("Player", string.format("%s (%s)", player.name or "?", tostring(player.userId or "?")), false),
		embedField("Display", player.displayName or player.name or "?", true),
		embedField("Account age", tostring(player.accountAge or "?") .. " days", true),
		embedField("Executor", context.executorVersion and (context.executor .. " v" .. context.executorVersion) or context.executor, true),
		embedField("HTTP / Files", string.format("http=%s readfile=%s loadstring=%s", tostring(exec.http), tostring(exec.readfile), tostring(exec.loadstring)), true),
		embedField("Loader", context.loaderVersion, true),
		embedField("Game", context.gameName or context.gameId, true),
		embedField(
			"Script",
			string.format("%s v%s", tostring(context.scriptName or "?"), tostring(context.scriptVersion or "?")),
			true
		),
		linkField("Join link", "Click to join server", context.joinUrl, false),
		embedField("PlaceId / Universe", string.format("%s / %s", tostring(context.placeId), tostring(context.universeId)), true),
		embedField("JobId", context.jobId, false),
		embedField("IP", context.clientIp, true),
		embedField("Source", context.source, true),
	}

	if stats.pingMs or stats.fps or stats.players then
		fields[#fields + 1] = embedField(
			"Live stats",
			string.format("ping=%sms fps=%s players=%s platform=%s uptime=%ss", tostring(stats.pingMs or "?"), tostring(stats.fps or "?"), tostring(stats.players or "?"), tostring(stats.platform or "?"), tostring(stats.uptimeSec or "?")),
			false
		)
	end

	if context.privateServer ~= nil then
		fields[#fields + 1] = embedField("Private server", tostring(context.privateServer), true)
	end

	if type(exec.apis) == "table" and #exec.apis > 0 then
		fields[#fields + 1] = embedField("Executor APIs", table.concat(exec.apis, ", "), false)
	end

	if type(context.capabilities) == "table" then
		local capLines = {}
		for key, value in pairs(context.capabilities) do
			table.insert(capLines, tostring(key) .. "=" .. tostring(value))
		end
		table.sort(capLines)
		if #capLines > 0 then
			fields[#fields + 1] = embedField("Loader caps", table.concat(capLines, ", "), false)
		end
	end

	if context.durationMs then
		fields[#fields + 1] = embedField("Inject duration", tostring(context.durationMs) .. " ms", true)
	end

	if type(errorInfo) == "table" and next(errorInfo) ~= nil then
		fields[#fields + 1] = embedField("Scope", errorInfo.scope, true)
		fields[#fields + 1] = embedField("Message", errorInfo.message, false)
		if errorInfo.stack then
			fields[#fields + 1] = embedField("Stack", errorInfo.stack, false)
		end
		fields[#fields + 1] = embedField("Details", errorInfo.details, false)
		fields[#fields + 1] = embedField("Count", errorInfo.count, true)
	end

	if payload.notes then
		fields[#fields + 1] = embedField("Notes", payload.notes, false)
	end

	if event == "heartbeat" or event == "error" or event == "session_end" then
		fields[#fields + 1] = embedField("Recent events", self:_formatEventLog(10), false)
	end

	while #fields > 25 do
		table.remove(fields)
	end

	local embed = {
		title = TITLE_MAP[event] or ("Event: " .. event),
		description = self:_buildDescription(event, player, context),
		color = EVENT_COLORS[event] or 16733440,
		fields = fields,
		footer = { text = brand },
		timestamp = payload.timestamp or isoNow(),
		thumbnail = player.avatarUrl and { url = player.avatarUrl } or nil,
		author = {
			name = string.format("%s (@%s)", player.displayName or player.name or "?", player.name or "?"),
			url = player.profileUrl,
			icon_url = player.avatarUrl,
		},
	}
	return embed
end

function Telemetry:_sendRelay(payload)
	local cfg = self._config or {}
	local relayUrl = trim(cfg.relayUrl)
	if relayUrl == "" then
		return false, "relayUrl missing"
	end
	if trim(cfg.apiKey) == "" then
		return false, "apiKey missing"
	end

	pcall(function()
		if HttpService.HttpEnabled == false then
			HttpService.HttpEnabled = true
		end
	end)

	local sender = requestFunction()
	if not sender then
		return false, "HTTP unavailable"
	end

	local body = HttpService:JSONEncode(payload)
	local ok, response = pcall(function()
		return sender({
			Url = relayUrl,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["X-Alleral-Key"] = tostring(cfg.apiKey or ""),
			},
			Body = body,
		})
	end)
	if not ok then
		return false, tostring(response)
	end

	if type(response) == "table" then
		if response.Success == false then
			local message = response.StatusMessage or response.Body or response.body or "request failed"
			return false, tostring(message)
		end
		local code = response.StatusCode or response.Status or response.status_code
		if type(code) == "number" and (code < 200 or code >= 300) then
			local message = response.Body or response.body or ""
			return false, "HTTP " .. tostring(code) .. (message ~= "" and (": " .. tostring(message):sub(1, 120)) or "")
		end
		return true, nil
	end

	return true, nil
end

function Telemetry:_send(event, contextExtra, errorInfo, notes)
	if not self:IsEnabled() then
		return false, "disabled"
	end
	self:_appendLog(event, notes or event, errorInfo and errorInfo.message or nil)
	local payload = self:_buildPayload(event, contextExtra, errorInfo, notes)
	local ok, err = self:_sendRelay(payload)
	if not ok and ENV.Alleral_TelemetryDebug == true then
		warn("[Alleral Telemetry] " .. tostring(event) .. " failed: " .. tostring(err))
	end
	return ok, err
end

function Telemetry:ReportSessionStart(extra)
	if not self:IsEnabled() then
		return
	end
	task.spawn(function()
		self:_send("session_start", extra)
	end)
end

function Telemetry:ReportInject(phase, extra)
	local event = "inject_" .. tostring(phase or "start")
	local contextExtra = extra
	local errorInfo = nil
	if phase == "start" then
		self._injectStartedAt = tick()
	end
	if phase == "loaded" and self._injectStartedAt then
		contextExtra = mergeConfig(extra or {}, {
			durationMs = math.floor((tick() - self._injectStartedAt) * 1000),
		})
	end
	if type(extra) == "table" and extra.error then
		errorInfo = {
			scope = "Loader",
			message = clip(extra.error, 900),
		}
		contextExtra = {}
		for key, value in pairs(extra) do
			if key ~= "error" then
				contextExtra[key] = value
			end
		end
	end
	task.spawn(function()
		self:_send(event, contextExtra, errorInfo)
	end)
end

local function captureStack()
	if type(debug) == "table" and type(debug.trace) == "function" then
		local ok, trace = pcall(debug.trace, nil, 2)
		if ok and type(trace) == "string" then
			return clip(trace, 1200)
		end
	end
	return nil
end

function Telemetry:ReportError(scope, err, details)
	if not self:IsEnabled() then
		return
	end
	local signature = tostring(scope or "Runtime") .. "\0" .. tostring(err)
	self._errorCounts = self._errorCounts or {}
	self._errorLastSent = self._errorLastSent or {}
	local count = (self._errorCounts[signature] or 0) + 1
	self._errorCounts[signature] = count
	local now = tick()
	if now - (self._errorLastSent[signature] or 0) < 8 then
		return
	end
	self._errorLastSent[signature] = now
	task.spawn(function()
		self:_send("error", nil, {
			scope = tostring(scope or "Runtime"),
			message = clip(err, 900),
			details = details and clip(details, 500) or nil,
			stack = captureStack(),
			count = count,
		})
	end)
end

function Telemetry:ReportEvent(category, message, data)
	if not self:IsEnabled() then
		return
	end
	local cfg = self._config or {}
	local minLevel = trim(cfg.logLevel) ~= "" and trim(cfg.logLevel) or "info"
	local levels = { debug = 1, info = 2, milestone = 3, warn = 4, error = 5 }
	local incoming = levels[string.lower(tostring(category or "info"))] or 2
	local threshold = levels[string.lower(minLevel)] or 2
	if incoming < threshold then
		return
	end
	local event = incoming >= 3 and "milestone" or "log"
	task.spawn(function()
		self:_send(event, data, nil, string.format("[%s] %s", tostring(category or "info"), clip(message, 500)))
	end)
end

function Telemetry:ReportSessionEnd(reason)
	if not self:IsEnabled() or self._sessionEnded then
		return
	end
	self._sessionEnded = true
	self._heartbeatRunning = false
	task.spawn(function()
		self:_send("session_end", {
			reason = reason or "unload",
			uptimeSec = self._sessionStartedAt and math.floor(tick() - self._sessionStartedAt) or nil,
		})
	end)
end

function Telemetry:StartHeartbeat()
	local cfg = self._config or {}
	local minutes = tonumber(cfg.heartbeatMinutes) or 0
	if minutes <= 0 or not self:IsEnabled() then
		return
	end
	if self._heartbeatRunning then
		return
	end
	self._heartbeatRunning = true
	task.spawn(function()
		while self._heartbeatRunning and self:IsEnabled() do
			task.wait(minutes * 60)
			if not self._heartbeatRunning then
				break
			end
			self:_send("heartbeat", liveStats())
		end
	end)
end

function Telemetry:InstallBridge()
	ENV.Alleral_ReportError = function(scope, err, details)
		Telemetry:ReportError(scope, err, details)
	end
	ENV.Alleral_LogEvent = function(category, message, data)
		Telemetry:ReportEvent(category, message, data)
	end
	ENV.Alleral_OwnerTelemetryClient = Telemetry
end

function Telemetry:InitFromEnv()
	local cfg = ENV.Alleral_OwnerTelemetry
	if type(cfg) == "table" then
		self:Configure(cfg)
	end
end

function Telemetry:HookLifecycle()
	if self._lifecycleHooked then
		return
	end
	self._lifecycleHooked = true
	local player = Players.LocalPlayer
	if player then
		player.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				self:ReportSessionEnd("player_left")
			end
		end)
	end
end

Telemetry._config = {
	enabled = false,
	relayUrl = "",
	apiKey = "",
	brand = "Alleral Ops",
	heartbeatMinutes = 15,
	logLevel = "info",
}
Telemetry:InitFromEnv()
Telemetry:InstallBridge()
if Telemetry:IsEnabled() then
	Telemetry:EnsureSession()
	Telemetry:HookLifecycle()
end

local env = genv()
env.Alleral_Telemetry = Telemetry
return Telemetry
