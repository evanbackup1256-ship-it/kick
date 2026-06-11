local Security = {}
Security.VERSION = "1.0"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()

local function trim(value)
	if value == nil then
		return ""
	end
	return tostring(value):match("^%s*(.-)%s*$") or ""
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

local function callProbe(fn)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, result = pcall(fn)
	if not ok then
		return nil
	end
	if type(result) == "string" and trim(result) ~= "" then
		return trim(result)
	end
	if type(result) == "number" then
		return tostring(result)
	end
	return nil
end

local function hashText(text)
	if trim(text) == "" then
		return ""
	end
	if HttpService and type(HttpService.Hash) == "function" then
		local ok, digest = pcall(function()
			return HttpService:Hash(text)
		end)
		if ok and type(digest) == "string" and digest ~= "" then
			return digest
		end
	end
	return text
end

local function executorSlug()
	local core = ENV.Alleral_Core
	if type(core) == "table" and type(core.executorProfile) == "function" then
		local ok, profile = pcall(function()
			return core.executorProfile()
		end)
		if ok and type(profile) == "table" then
			return trim(profile.name or profile.displayName)
		end
	end
	local caps = ENV.Alleral_LoaderCapabilities
	if type(caps) == "table" then
		return trim(caps.executorSlug or caps.executor)
	end
	return "unknown"
end

function Security.collectHwid()
	local probes = {
		function()
			return callProbe(ENV.gethwid)
		end,
		function()
			return callProbe(gethwid)
		end,
		function()
			return callProbe(get_hwid)
		end,
		function()
			if type(identifyexecutor) == "function" then
				local ok, a, b, c = pcall(identifyexecutor)
				if ok then
					if type(c) == "string" and trim(c) ~= "" then
						return c
					end
					if type(b) == "string" and #b >= 16 and not b:lower():find("executor") then
						return b
					end
				end
			end
			return nil
		end,
		function()
			if type(getexecutorinfo) == "function" then
				local ok, info = pcall(getexecutorinfo)
				if ok and type(info) == "table" then
					return info.hwid or info.HWID or info.machineId or info.MachineId or info.identifier
				end
			end
			return nil
		end,
		function()
			if type(ENV.KRNL) == "table" and type(ENV.KRNL.gethwid) == "function" then
				return callProbe(ENV.KRNL.gethwid)
			end
			return nil
		end,
		function()
			if type(ENV.Wave) == "table" then
				for _, key in ipairs({ "GetHwid", "gethwid", "GetHWID" }) do
					if type(ENV.Wave[key]) == "function" then
						local value = callProbe(ENV.Wave[key])
						if value then
							return value
						end
					end
				end
			end
			return nil
		end,
		function()
			if type(ENV.syn) == "table" and type(ENV.syn.crypt) == "table" and type(ENV.syn.crypt.hash) == "function" then
				local ok, value = pcall(function()
					return ENV.syn.crypt.hash("alleral-hwid-seed")
				end)
				if ok and type(value) == "string" and trim(value) ~= "" then
					return value
				end
			end
			return nil
		end,
		function()
			if type(ENV.Volt) == "table" then
				for _, key in ipairs({ "gethwid", "GetHwid", "hwid" }) do
					local entry = ENV.Volt[key]
					if type(entry) == "function" then
						local value = callProbe(entry)
						if value then
							return value
						end
					elseif type(entry) == "string" and trim(entry) ~= "" then
						return entry
					end
				end
			end
			return nil
		end,
	}

	for _, probe in ipairs(probes) do
		local value = probe()
		if value then
			return value
		end
	end
	return ""
end

function Security.collectFingerprint()
	local player = Players.LocalPlayer
	local userId = player and player.UserId or 0
	local parts = {
		tostring(userId),
		executorSlug(),
		Security.collectHwid(),
	}
	return hashText(table.concat(parts, ":"))
end

function Security.collectIdentity()
	local player = Players.LocalPlayer
	local hwid = Security.collectHwid()
	local fingerprint = Security.collectFingerprint()
	local identity = {
		userId = player and player.UserId or 0,
		playerName = player and player.Name or "Unknown",
		displayName = player and player.DisplayName or "Unknown",
		accountAge = player and player.AccountAge or 0,
		hwid = hwid,
		fingerprint = fingerprint,
		executor = executorSlug(),
		loaderVersion = ENV.Alleral_LoaderVersion or ENV._Alleral_LoaderVersion,
	}
	ENV.Alleral_DeviceIdentity = identity
	return identity
end

function Security.getConfig()
	local cfg = ENV.Alleral_OwnerSecurity
	if type(cfg) ~= "table" then
		cfg = { enabled = false }
	end
	local owner = ENV.Alleral_OwnerTelemetry
	if type(owner) == "table" then
		if trim(owner.apiKey) ~= "" and trim(cfg.apiKey) == "" then
			cfg.apiKey = owner.apiKey
		end
		if trim(cfg.gateUrl) == "" and trim(owner.relayUrl) ~= "" then
			local base = owner.relayUrl:gsub("/+$", ""):gsub("/ingest$", "")
			cfg.gateUrl = base .. "/gate/check"
		end
		if owner.gateUrl then
			cfg.gateUrl = owner.gateUrl
		end
	end
	return cfg
end

function Security.isEnabled()
	local cfg = Security.getConfig()
	if cfg.enabled == false then
		return false
	end
	return trim(cfg.gateUrl) ~= "" and trim(cfg.apiKey) ~= ""
end

local function getRequestFn()
	local core = ENV.Alleral_Core
	if type(core) == "table" and type(core.requestFunction) == "function" then
		local fn = core.requestFunction()
		if fn then
			return fn
		end
	end
	for _, name in ipairs({ "request", "http_request", "httprequest" }) do
		if type(ENV[name]) == "function" then
			return ENV[name]
		end
	end
	return nil
end

local function decodeBody(body)
	if type(body) ~= "string" or body == "" then
		return nil
	end
	local ok, parsed = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if ok and type(parsed) == "table" then
		return parsed
	end
	return nil
end

local function readCache()
	local cache = ENV._Alleral_GateCache
	if type(cache) ~= "table" then
		return nil
	end
	local cfg = Security.getConfig()
	local ttl = tonumber(cfg.cacheSeconds) or 300
	if cache.expiresAt and os.clock() > cache.expiresAt then
		return nil
	end
	if cache.allowed == false then
		return cache
	end
	if cache.allowed == true and cache.expiresAt then
		return cache
	end
	if ttl <= 0 then
		return nil
	end
	return cache
end

local function writeCache(allowed, reason, banType)
	local cfg = Security.getConfig()
	local ttl = tonumber(cfg.cacheSeconds) or 300
	ENV._Alleral_GateCache = {
		allowed = allowed,
		reason = reason,
		banType = banType,
		expiresAt = ttl > 0 and (os.clock() + ttl) or nil,
		checkedAt = os.time(),
	}
end

function Security.checkAccess(options)
	options = type(options) == "table" and options or {}
	if not Security.isEnabled() then
		return true, "disabled"
	end

	local cached = readCache()
	if cached and not options.force then
		if cached.allowed then
			return true, "cache"
		end
		return false, cached.reason or "banned"
	end

	local cfg = Security.getConfig()
	local requestFn = getRequestFn()
	if not requestFn then
		if cfg.failOpenOnError ~= false then
			return true, "no_http"
		end
		return false, "HTTP unavailable"
	end

	local identity = Security.collectIdentity()
	local payload = {
		userId = identity.userId,
		player = {
			name = identity.playerName,
			displayName = identity.displayName,
			userId = identity.userId,
			accountAge = identity.accountAge,
		},
		hwid = identity.hwid,
		fingerprint = identity.fingerprint,
		executor = identity.executor,
		loaderVersion = identity.loaderVersion,
		stage = options.stage or "loader",
	}

	local body = HttpService:JSONEncode(payload)
	local response = nil
	local ok = pcall(function()
		response = requestFn({
			Url = trim(cfg.gateUrl),
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["X-Alleral-Key"] = trim(cfg.apiKey),
			},
			Body = body,
		})
	end)

	if not ok or type(response) ~= "table" then
		if cfg.failOpenOnError ~= false then
			return true, "gate_unreachable"
		end
		return false, "Security gate unreachable"
	end

	local status = tonumber(response.StatusCode or response.status or response.Status or 0) or 0
	local parsed = decodeBody(response.Body or response.body)
	if status == 403 or (parsed and parsed.allowed == false) then
		local reason = (parsed and (parsed.reason or parsed.error)) or "Access denied"
		writeCache(false, reason, parsed and parsed.banType)
		return false, reason
	end
	if status == 401 then
		if cfg.failOpenOnError ~= false then
			return true, "gate_unauthorized"
		end
		return false, "Security gate misconfigured"
	end
	if status >= 400 or not parsed or parsed.ok == false then
		if cfg.failOpenOnError ~= false then
			return true, "gate_error"
		end
		return false, "Security gate error"
	end

	writeCache(true, nil, nil)
	return true, "allowed"
end

function Security.enforce(options)
	local allowed, reason = Security.checkAccess(options)
	if allowed then
		return true
	end
	local message = "You are banned from Alleral"
	if reason and reason ~= "banned" and reason ~= "Access denied" then
		message = message .. ": " .. tostring(reason)
	end
	ENV.Alleral_AccessDenied = {
		reason = reason,
		at = os.time(),
		identity = ENV.Alleral_DeviceIdentity,
	}
	local telemetry = ENV.Alleral_Telemetry
	if type(telemetry) == "table" and type(telemetry.ReportInject) == "function" then
		pcall(function()
			telemetry:ReportInject("failed", {
				error = "banned: " .. tostring(reason),
				stage = options and options.stage or "security",
			})
		end)
	end
	local report = ENV.Alleral_ReportError
	if type(report) == "function" then
		pcall(report, "ban", tostring(reason))
	end
	return false, message
end

function Security.installBridge()
	ENV.Alleral_Security = Security
	ENV.Alleral_CheckAccess = function(options)
		return Security.checkAccess(options)
	end
	pcall(function()
		if shared then
			shared.Alleral_Security = Security
		end
	end)
end

Security.installBridge()
return Security
