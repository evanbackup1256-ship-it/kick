-- Alleral Bootstrap v2.1.0 -- universal loadstring, never needs changing
-- Fetches the latest loader.luau from multiple CDN sources. No hardcoded pins.
local BOOTSTRAP_VERSION = "2.1.0"
local REPO = "evanbackup1256-ship-it/-kick-loader"
local BRANCH = "main"
local LOADER_MIN_BYTES = 50000

-- CDN sources ordered by speed/priority
local SOURCES = {
	{ name = "jsDelivr",  base = "https://cdn.jsdelivr.net/gh/" .. REPO .. "@" .. BRANCH },
	{ name = "GitHub",    base = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH },
	{ name = "Railway",   base = "https://alleral-telemetry-production.up.railway.app" },
}

local function safeCall(name, fn)
	local ok, result = pcall(fn)
	if not ok then
		warn("[Alleral Bootstrap Error] " .. name .. ": " .. tostring(result))
		return nil
	end
	if result == nil then
		warn("[Alleral Bootstrap Error] " .. name .. " returned nil")
		return nil
	end
	return result
end

print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Starting...")

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local function resolveGame()
	if typeof(game) == "Instance" then return game end
	if _G and typeof(_G.game) == "Instance" then return _G.game end
	local env = genv()
	if typeof(env.game) == "Instance" then return env.game end
	return nil
end

local game = resolveGame()
if not game then
	error("[Alleral Bootstrap] Run inside a Roblox game, not the executor menu.")
end

local ENV = genv()
ENV.game = game

local loadStringFn = ENV.loadstring or ENV.LoadString or ENV.load or loadstring or load
if type(loadStringFn) ~= "function" then
	error("[Alleral Bootstrap] loadstring is not available (tried loadstring, LoadString, load).")
end

local function looksLikeLua(text)
	if type(text) ~= "string" or #text < 50 then return false end
	if text:find("<!DOCTYPE", 1, true) or text:find("<html", 1, true) then
		return text:find("function", 1, true) ~= nil or text:find("local ", 1, true) ~= nil
	end
	return true
end

local function pickRequest()
	for _, name in ipairs({ "request", "http_request", "httprequest", "syn_request" }) do
		local fn = ENV[name] or (_G and _G[name])
		if type(fn) == "function" then return fn end
	end
	if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
	if type(http) == "table" and type(http.request) == "function" then return http.request end
	if type(ENV.Xeno) == "table" and type(ENV.Xeno.request) == "function" then return ENV.Xeno.request end
	return nil
end

local function fetchUrl(url, minBytes)
	minBytes = minBytes or 0
	local bust = (url:find("?") and "&" or "?") .. "v=" .. BOOTSTRAP_VERSION .. "&t=" .. tostring(tick())
	local fullUrl = url .. bust

	local requestFn = pickRequest()
	if requestFn then
		local body = safeCall("request " .. url, function()
			local res = requestFn({
				Url = fullUrl,
				Method = "GET",
				Headers = { ["Cache-Control"] = "no-cache", ["User-Agent"] = "Alleral-Bootstrap/" .. BOOTSTRAP_VERSION },
			})
			if type(res) == "table" then
				return res.Body or res.body
			end
			return type(res) == "string" and res or nil
		end)
		if type(body) == "string" and #body >= minBytes then
			if looksLikeLua(body) then return body end
		end
	end

	if type(game.HttpGet) == "function" then
		local body = safeCall("HttpGet " .. url, function()
			local ok, b = pcall(game.HttpGet, game, fullUrl, true)
			if ok and type(b) == "string" and #b > 0 then return b end
			ok, b = pcall(game.HttpGet, game, fullUrl)
			if ok and type(b) == "string" and #b > 0 then return b end
			ok, b = pcall(function() return game:HttpGet(fullUrl, true) end)
			if ok and type(b) == "string" and #b > 0 then return b end
			ok, b = pcall(function() return game:HttpGet(fullUrl) end)
			if ok and type(b) == "string" and #b > 0 then return b end
			return nil
		end)
		if type(body) == "string" and #body >= minBytes then
			if looksLikeLua(body) then return body end
			warn("[Alleral Bootstrap] " .. url .. " returned HTML, not Lua (got " .. tostring(#body) .. "b)")
			return nil
		end
	end

	return nil
end

local function stripUtf8Bom(text)
	if type(text) ~= "string" or #text < 3 then return text end
	if string.byte(text, 1) == 0xEF and string.byte(text, 2) == 0xBB and string.byte(text, 3) == 0xBF then
		return text:sub(4)
	end
	return text
end

local function parseJson(text)
	if type(text) ~= "string" or #text < 2 then return nil end
	local ok, data = pcall(function()
		return game:GetService("HttpService"):JSONDecode(text)
	end)
	return ok and type(data) == "table" and data or nil
end

local function loaderVersion(src)
	if type(src) ~= "string" then return nil end
	return src:match('local%s+LOADER_VERSION%s*=%s*"([%d%.]+)"')
end

local function acceptLoader(src)
	if type(src) ~= "string" or #src < LOADER_MIN_BYTES then
		if type(src) == "string" then
			warn("[Alleral Bootstrap] Loader too small: " .. tostring(#src) .. "b (need " .. tostring(LOADER_MIN_BYTES) .. "b+)")
		end
		return false
	end
	if not src:find("LOADER_VERSION", 1, true) then
		warn("[Alleral Bootstrap] Loader missing LOADER_VERSION marker")
		return false
	end
	return true
end

if ENV._Alleral_BootstrapRunning then return end
ENV._Alleral_BootstrapRunning = true

-- Step 1: Fetch latest release.json to get the current loader version
local release
for _, source in ipairs(SOURCES) do
	local url = source.base .. "/cfg/release.json"
	local body = fetchUrl(url, 20)
	if body then
		release = parseJson(body)
		if release and release.loader then
			print("[Alleral Bootstrap] Release v" .. tostring(release.loader) .. " from " .. source.name)
			break
		end
	end
end
if not release then
	warn("[Alleral Bootstrap] Could not fetch release.json, using fallback defaults")
end

-- Step 2: Fetch loader.luau from CDN sources
local src, via
local urls = {}
for _, source in ipairs(SOURCES) do
	if source.name == "Railway" then
		table.insert(urls, { url = source.base .. "/api/loader/file/loader.luau", name = source.name })
	else
		table.insert(urls, { url = source.base .. "/loader.luau", name = source.name })
	end
end

for _, entry in ipairs(urls) do
	local body = fetchUrl(entry.url, LOADER_MIN_BYTES)
	if acceptLoader(body) then
		if release and release.loader then
			local ver = loaderVersion(body)
			if ver and ver ~= release.loader then
				-- Try pinned commit version from CDN
				local pinUrl = "https://cdn.jsdelivr.net/gh/" .. REPO .. "@" .. (release.commit or "main") .. "/loader.luau"
				local pinned = fetchUrl(pinUrl, LOADER_MIN_BYTES)
				if acceptLoader(pinned) then body = pinned end
			end
		end
		if body then
			src = body
			via = entry.name
			print("[Alleral Bootstrap] Loader fetched from " .. entry.name .. " (" .. tostring(#src) .. "b)")
			break
		end
	end
end

if not src then
	ENV._Alleral_BootstrapRunning = false
	error("[Alleral Bootstrap] Could not download loader.luau. Enable HTTP in your executor and try again.")
end

src = stripUtf8Bom(src)

local ver = loaderVersion(src) or "?"
print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Running loader v" .. ver .. " (" .. tostring(#src) .. "b via " .. tostring(via) .. ")")

local fn = safeCall("loadstring loader", function()
	return loadStringFn(src, "Alleral/loader@" .. ver)
end)

if type(fn) ~= "function" then
	ENV._Alleral_BootstrapRunning = false
	error("[Alleral Bootstrap] Loader chunk is not a function (got " .. type(fn) .. "). The source may be corrupted or HTTP returned invalid content.")
end

if setfenv then pcall(setfenv, fn, ENV) end

local at = tick()
ENV._Alleral_BootstrapVersion = BOOTSTRAP_VERSION
ENV._Alleral_Bootstrapped = true
ENV._Alleral_BootstrapAt = at
ENV._Alleral_BootstrapCommit = release and release.commit or ""
ENV._Alleral_BootstrapToken = string.format("ab_%x_%x", 0, 0)
ENV._Alleral_BootstrapTokenAt = at

print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Executing loader...")
local ok, runErr = pcall(fn)
ENV._Alleral_BootstrapRunning = false
if not ok then
	error("[Alleral Bootstrap] Loader runtime error: " .. tostring(runErr))
end
