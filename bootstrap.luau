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

local loadStringFn = ENV.loadstring or ENV.LoadString or loadstring or load
if not loadStringFn then
	error("[Alleral Bootstrap] loadstring is not available.")
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

	local requestFn = pickRequest()
	if requestFn then
		local ok, res = pcall(requestFn, {
			Url = url .. bust,
			Method = "GET",
			Headers = { ["Cache-Control"] = "no-cache", ["User-Agent"] = "Alleral-Bootstrap/" .. BOOTSTRAP_VERSION },
		})
		if ok and type(res) == "table" then
			local body = res.Body or res.body
			if type(body) == "string" and #body >= minBytes then
				return body
			end
		end
	end

	if type(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, url .. bust, true)
		if ok and type(body) == "string" and #body >= minBytes then return body end
		ok, body = pcall(game.HttpGet, game, url .. bust)
		if ok and type(body) == "string" and #body >= minBytes then return body end
	end

	if type(game.HttpGet) == "function" then
		local ok, body = pcall(function() return game:HttpGet(url .. bust, true) end)
		if ok and type(body) == "string" and #body >= minBytes then return body end
		ok, body = pcall(function() return game:HttpGet(url .. bust) end)
		if ok and type(body) == "string" and #body >= minBytes then return body end
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
	return type(src) == "string" and #src >= LOADER_MIN_BYTES and src:find("LOADER_VERSION", 1, true) ~= nil
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
		if release and release.loader then break end
	end
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
				body = fetchUrl(pinUrl, LOADER_MIN_BYTES)
				if not acceptLoader(body) then body = nil end
			end
		end
		if body then
			src = body
			via = entry.name
			break
		end
	end
end

if not src then
	ENV._Alleral_BootstrapRunning = false
	error("[Alleral Bootstrap] Could not download loader.luau. Enable HTTP in your executor.")
end

src = stripUtf8Bom(src)

local ver = loaderVersion(src) or "?"
print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Running loader v" .. ver .. " (" .. tostring(#src) .. "b via " .. tostring(via) .. ")")

local fn, err = loadStringFn(src, "Alleral/loader@" .. ver)
if not fn then
	ENV._Alleral_BootstrapRunning = false
	error("[Alleral Bootstrap] Loader compile failed: " .. tostring(err))
end

if setfenv then pcall(setfenv, fn, ENV) end

local at = tick()
ENV._Alleral_BootstrapVersion = BOOTSTRAP_VERSION
ENV._Alleral_Bootstrapped = true
ENV._Alleral_BootstrapAt = at
ENV._Alleral_BootstrapCommit = release and release.commit or ""
ENV._Alleral_BootstrapToken = string.format("ab_%x_%x", 0, 0)
ENV._Alleral_BootstrapTokenAt = at

local ok, runErr = pcall(fn)
ENV._Alleral_BootstrapRunning = false
if not ok then
	error("[Alleral Bootstrap] " .. tostring(runErr))
end
