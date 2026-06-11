--[[
	Alleral bootstrap — always run THIS via loadstring + HttpGet.
	Do not save/cache loader.luau in your executor; GitHub serves the latest copy.
]]
local REPO = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main"
local LOADER_URL = REPO .. "/loader.luau"
local DEFAULT_TELEMETRY_RELAY = "https://alleral-telemetry-production.up.railway.app/ingest"

local TELEMETRY_CONFIG_PATHS = {
	"../Alleral-Private/owner_telemetry.luau",
	"Alleral-Private/owner_telemetry.luau",
	"config/owner_telemetry.luau",
	"kick/kick/config/owner_telemetry.luau",
	"owner_telemetry.luau",
}
local TELEMETRY_ENV_PATHS = {
	"backend/.env",
	"kick/kick/backend/.env",
}

local function cacheBust(url)
	local sep = url:find("?") and "&" or "?"
	return url .. sep .. "t=" .. tostring(tick()) .. "&r=" .. tostring(math.random(100000, 999999))
end

local function trim(s)
	return type(s) == "string" and s:match("^%s*(.-)%s*$") or ""
end

local function ownerTelemetryValid(cfg)
	return type(cfg) == "table"
		and cfg.enabled ~= false
		and trim(cfg.relayUrl or "") ~= ""
		and trim(cfg.apiKey or "") ~= ""
		and trim(cfg.apiKey) ~= "aller_CHANGE_ME"
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

local function buildTelemetryFromEnv(env)
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
		relayUrl = publicUrl:find("/ingest$") and publicUrl or (publicUrl .. "/ingest")
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

local function preloadOwnerTelemetry(g)
	if ownerTelemetryValid(g.Alleral_OwnerTelemetry) then
		return
	end
	if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then
		return
	end
	for _, path in ipairs(TELEMETRY_CONFIG_PATHS) do
		if isfile(path) then
			local ok, fn = pcall(loadstring, readfile(path), "Alleral/owner_telemetry@" .. path)
			if ok and type(fn) == "function" then
				local ok2, cfg = pcall(fn)
				if ok2 and ownerTelemetryValid(cfg) then
					g.Alleral_OwnerTelemetry = cfg
					print("[Alleral Bootstrap] Telemetry config from " .. path)
					return
				end
			end
		end
	end
	for _, path in ipairs(TELEMETRY_ENV_PATHS) do
		if isfile(path) then
			local cfg = buildTelemetryFromEnv(parseEnvFile(readfile(path)))
			if ownerTelemetryValid(cfg) then
				g.Alleral_OwnerTelemetry = cfg
				print("[Alleral Bootstrap] Telemetry config from " .. path)
				return
			end
		end
	end
end

local function fetch(url)
	url = cacheBust(url)
	if typeof(request) == "function" then
		local ok, res = pcall(request, {
			Url = url,
			Method = "GET",
			Headers = {
				["Cache-Control"] = "no-cache, no-store, must-revalidate",
				["Pragma"] = "no-cache",
			},
		})
		if ok and res then
			local body = res.Body or res.body
			if type(body) == "string" and #body > 500 then
				return body
			end
		end
	end
	if typeof(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, url, true)
		if ok and type(body) == "string" and #body > 500 then
			return body
		end
	end
	return nil
end

local g = typeof(getgenv) == "function" and getgenv() or {}
if type(g) == "table" then
	g.Alleral_Core = nil
	g.Alleral_Rayfield = nil
	g.Alleral_UI = nil
	g.Alleral_LoaderVersion = nil
	preloadOwnerTelemetry(g)
end

local body = fetch(LOADER_URL)
if not body then
	error("[Alleral] Could not download loader from GitHub. Check HTTP/request support.")
end

local version = body:match('LOADER_VERSION%s*=%s*"([%d%.]+)"')
if not version then
	error("[Alleral] Downloaded payload is not a valid loader script.")
end

print("[Alleral Bootstrap] Fetched loader v" .. version .. " from GitHub")

local fn = loadstring(body, "Alleral/loader@" .. version)
if not fn then
	error("[Alleral] Loader failed to compile.")
end
fn()
