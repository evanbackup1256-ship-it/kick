-- Alleral Bootstrap v2.0.1 — fetches loader.luau and runs it (one saved loadstring)
local BOOTSTRAP_VERSION = "2.0.1"
local REPO = "evanbackup1256-ship-it/kick"
local BRANCH = "main"
local LOADER_MIN_BYTES = 50000
local GITHUB_RAW = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH
local JSDELIVR = "https://cdn.jsdelivr.net/gh/" .. REPO .. "@" .. BRANCH

print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Starting…")

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local function resolveGame()
	if typeof(game) == "Instance" then
		return game
	end
	if _G and typeof(_G.game) == "Instance" then
		return _G.game
	end
	local env = genv()
	if typeof(env.game) == "Instance" then
		return env.game
	end
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
		if type(fn) == "function" then
			return fn
		end
	end
	if type(syn) == "table" and type(syn.request) == "function" then
		return syn.request
	end
	if type(http) == "table" and type(http.request) == "function" then
		return http.request
	end
	if type(ENV.Xeno) == "table" and type(ENV.Xeno.request) == "function" then
		return ENV.Xeno.request
	end
	return nil
end

local function fetchUrl(url, minBytes)
	minBytes = minBytes or 0
	local requestFn = pickRequest()
	if requestFn then
		local ok, res = pcall(requestFn, {
			Url = url,
			Method = "GET",
			Headers = { ["Cache-Control"] = "no-cache, no-store", ["User-Agent"] = "Alleral-Bootstrap/" .. BOOTSTRAP_VERSION },
		})
		if ok and type(res) == "table" then
			local body = res.Body or res.body
			if type(body) == "string" and #body >= minBytes then
				return body, "request"
			end
		end
	end
	if type(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, url, true)
		if ok and type(body) == "string" and #body >= minBytes then
			return body, "httpget"
		end
	end
	return nil, "fetch failed"
end

local function fetchLoader()
	local bust = "?v=" .. BOOTSTRAP_VERSION .. "&t=" .. tostring(tick())
	local urls = {
		GITHUB_RAW .. "/loader.luau" .. bust,
		JSDELIVR .. "/loader.luau" .. bust,
	}
	for _, url in ipairs(urls) do
		local body, via = fetchUrl(url, LOADER_MIN_BYTES)
		if type(body) == "string" and body:find("LOADER_VERSION", 1, true) then
			return body, via
		end
	end
	return nil, "all sources failed"
end

local function hashAttest(placeId, jobId, at, commit)
	local text = "AlleralBootstrapGate-v5|" .. tostring(placeId) .. "|" .. tostring(jobId) .. "|" .. tostring(at) .. "|" .. tostring(commit or "")
	local h1, h2 = 5381, 0
	for i = 1, #text do
		local byte = string.byte(text, i)
		h1 = (h1 * 33 + byte) % 2147483647
		h2 = (h2 * 31 + byte * (i % 7 + 1)) % 2147483647
	end
	return string.format("ab_%x_%x", h1, h2)
end

if ENV._Alleral_BootstrapRunning then
	return
end
ENV._Alleral_BootstrapRunning = true

local src, via = fetchLoader()
if type(src) ~= "string" then
	ENV._Alleral_BootstrapRunning = false
	error("[Alleral Bootstrap] Could not download loader.luau (" .. tostring(via) .. "). Enable HTTP in your executor.")
end

local ver = src:match('LOADER_VERSION%s*=%s*"([%d%.]+)"') or "?"
print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Running loader v" .. ver .. " (" .. tostring(#src) .. "b via " .. tostring(via) .. ")")

local fn, err = loadStringFn(src, "Alleral/loader@" .. ver)
if not fn then
	ENV._Alleral_BootstrapRunning = false
	error("[Alleral Bootstrap] Loader compile failed: " .. tostring(err))
end

if setfenv then
	pcall(setfenv, fn, ENV)
end

local at = tick()
ENV._Alleral_BootstrapVersion = BOOTSTRAP_VERSION
ENV._Alleral_Bootstrapped = true
ENV._Alleral_BootstrapAt = at
ENV._Alleral_BootstrapCommit = nil
ENV._Alleral_BootstrapToken = hashAttest(game.PlaceId, game.JobId, at, nil)
ENV._Alleral_BootstrapTokenAt = at

local ok, runErr = pcall(fn)
ENV._Alleral_BootstrapRunning = false
if not ok then
	error("[Alleral Bootstrap] " .. tostring(runErr))
end
