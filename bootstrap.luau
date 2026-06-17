-- Alleral Bootstrap v2.0.4 — fetches commit-pinned loader.luau (one saved loadstring)
local BOOTSTRAP_VERSION = "2.0.4"
local LOADER_PIN_COMMIT = "ae81dd8"
local REPO = "evanbackup1256-ship-it/kick-loader"
local BRANCH = "main"
local LOADER_MIN_BYTES = 50000
local GITHUB_RAW = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH
local JSDELIVR = "https://cdn.jsdelivr.net/gh/" .. REPO
local CDN_BASE = "https://alleral-telemetry-production.up.railway.app"
local RELEASE_PATH = "cfg/release.json"

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

local function stripUtf8Bom(text)
	if type(text) ~= "string" or #text < 3 then
		return text
	end
	if string.byte(text, 1) == 0xEF and string.byte(text, 2) == 0xBB and string.byte(text, 3) == 0xBF then
		return text:sub(4)
	end
	return text
end

local function parseRelease(body)
	if type(body) ~= "string" then
		return nil
	end
	local commit = body:match('"commit"%s*:%s*"([^"]+)"')
	local loader = body:match('"loader"%s*:%s*"([^"]+)"')
	if not commit and not loader then
		return nil
	end
	return { commit = commit, loader = loader }
end

local function loaderVersionFromSource(body)
	if type(body) ~= "string" then
		return nil
	end
	return body:match('local%s+LOADER_VERSION%s*=%s*"([%d%.]+)"')
		or body:match('LOADER_VERSION%s*=%s*"([%d%.]+)"')
end

local function acceptLoader(body, expectedVersion)
	if type(body) ~= "string" or not body:find("LOADER_VERSION", 1, true) then
		return false
	end
	if #body < LOADER_MIN_BYTES then
		return false
	end
	if type(expectedVersion) == "string" and expectedVersion ~= "" then
		local ver = loaderVersionFromSource(body)
		if ver and ver ~= expectedVersion then
			return false
		end
	end
	return true
end

local function fetchRelease()
	local bust = "?v=" .. BOOTSTRAP_VERSION .. "&t=" .. tostring(tick())
	return parseRelease(fetchUrl(GITHUB_RAW .. "/" .. RELEASE_PATH .. bust, 20))
end

local function fetchLoader()
	local bust = "?v=" .. BOOTSTRAP_VERSION .. "&t=" .. tostring(tick())
	local release = fetchRelease()
	local commit = (release and release.commit) or LOADER_PIN_COMMIT
	local expectedLoader = release and release.loader

	local urls = {
		GITHUB_RAW .. "/" .. commit .. "/loader.luau" .. bust,
		JSDELIVR .. "@" .. commit .. "/loader.luau" .. bust,
		GITHUB_RAW .. "/" .. LOADER_PIN_COMMIT .. "/loader.luau" .. bust,
		JSDELIVR .. "@" .. LOADER_PIN_COMMIT .. "/loader.luau" .. bust,
		CDN_BASE .. "/api/loader/file/loader.luau" .. bust,
	}
	if not expectedLoader then
		table.insert(urls, GITHUB_RAW .. "/loader.luau" .. bust)
		table.insert(urls, JSDELIVR .. "@" .. BRANCH .. "/loader.luau" .. bust)
	end

	for _, url in ipairs(urls) do
		local body, via = fetchUrl(url, LOADER_MIN_BYTES)
		if acceptLoader(body, expectedLoader) then
			return body, via, commit, expectedLoader
		end
	end
	return nil, "stale or unavailable", commit, expectedLoader
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

local src, via, pinCommit, expectedLoader = fetchLoader()
if type(src) ~= "string" then
	ENV._Alleral_BootstrapRunning = false
	local detail = tostring(via)
	if type(expectedLoader) == "string" and expectedLoader ~= "" then
		detail = detail .. " (need loader " .. expectedLoader .. " @ " .. tostring(pinCommit) .. ")"
	end
	error("[Alleral Bootstrap] Could not download loader.luau (" .. detail .. "). Enable HTTP in your executor.")
end
src = stripUtf8Bom(src)

local ver = loaderVersionFromSource(src) or "?"
print(
	"[Alleral Bootstrap v"
		.. BOOTSTRAP_VERSION
		.. "] Running loader v"
		.. ver
		.. " ("
		.. tostring(#src)
		.. "b via "
		.. tostring(via)
		.. ", pin "
		.. tostring(pinCommit)
		.. ")"
)

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
ENV._Alleral_BootstrapCommit = pinCommit
ENV._Alleral_BootstrapToken = hashAttest(game.PlaceId, game.JobId, at, pinCommit)
ENV._Alleral_BootstrapTokenAt = at

local ok, runErr = pcall(fn)
ENV._Alleral_BootstrapRunning = false
if not ok then
	error("[Alleral Bootstrap] " .. tostring(runErr))
end
