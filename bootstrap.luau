-- Alleral entry v1.0.11 — fetches hub/bootstrap via request (avoids HttpGet freeze on Xeno)
local ENTRY_VERSION = "1.0.11"
local REPO = "evanbackup1256-ship-it/kick"
local HUB_BOOT =
	"https://cdn.jsdelivr.net/gh/" .. REPO .. "@main/hub/bootstrap.luau?v=" .. ENTRY_VERSION

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()

local function pickRequest()
	local names = { "request", "http_request", "httprequest", "syn_request" }
	for _, name in ipairs(names) do
		local fn = ENV[name]
		if type(fn) ~= "function" and _G then
			fn = _G[name]
		end
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

local function fetchBootstrapSource()
	local url = HUB_BOOT .. "&t=" .. tostring(tick()) .. "&r=" .. tostring(math.random(1, 2147483646))
	local requestFn = pickRequest()
	if requestFn then
		local ok, res = pcall(requestFn, {
			Url = url,
			Method = "GET",
			Headers = {
				["Cache-Control"] = "no-cache, no-store",
				["User-Agent"] = "Alleral-Entry/" .. ENTRY_VERSION,
			},
		})
		if ok and type(res) == "table" and type(res.Body) == "string" and #res.Body > 2000 then
			return res.Body
		end
	end
	if typeof(game) == "Instance" and type(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, url, true)
		if ok and type(body) == "string" and #body > 2000 then
			return body
		end
	end
	return nil
end

print("[Alleral Entry v" .. ENTRY_VERSION .. "] Fetching bootstrap…")
local src = fetchBootstrapSource()
if not src then
	error(
		"[Alleral Entry v"
			.. ENTRY_VERSION
			.. "] Could not download bootstrap — enable HTTP/request in your executor or paste the loadstring from the site again."
	)
end

local loadFn = loadstring or load
local chunk, err = loadFn(src, "@Alleral/hub/bootstrap")
if not chunk then
	error("[Alleral Entry] Bootstrap compile failed: " .. tostring(err))
end
chunk()
