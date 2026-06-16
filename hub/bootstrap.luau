-- Back-compat redirect — bootstrap + loader merged into /bootstrap.luau at repo root.
-- Old saved scripts that still hit hub/bootstrap.luau get forwarded in one fetch.

local REDIRECT_VERSION = "2.0.1"
local REPO = "evanbackup1256-ship-it/kick"
local MERGED_URLS = {
	"https://raw.githubusercontent.com/" .. REPO .. "/main/bootstrap.luau?v=" .. REDIRECT_VERSION,
	"https://cdn.jsdelivr.net/gh/" .. REPO .. "@main/bootstrap.luau?v=" .. REDIRECT_VERSION,
}

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()

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
	return nil
end

local function fetchMerged()
	local requestFn = pickRequest()
	for _, baseUrl in ipairs(MERGED_URLS) do
		local url = baseUrl .. "&t=" .. tostring(tick())
		if requestFn then
			local ok, res = pcall(requestFn, {
				Url = url,
				Method = "GET",
				Headers = { ["Cache-Control"] = "no-cache, no-store" },
			})
			if ok and type(res) == "table" and type(res.Body) == "string" and #res.Body > 50000 then
				return res.Body
			end
		end
		if typeof(game) == "Instance" and type(game.HttpGet) == "function" then
			local ok, body = pcall(game.HttpGet, game, url, true)
			if ok and type(body) == "string" and #body > 50000 then
				return body
			end
		end
	end
	return nil
end

print("[Alleral Bootstrap redirect v" .. REDIRECT_VERSION .. "] Loading merged bootstrap…")
local src = fetchMerged()
if not src then
	error("[Alleral Bootstrap redirect] Could not download merged bootstrap.luau — update your saved loadstring from the site.")
end

local loadFn = loadstring or load
local chunk, err = loadFn(src, "@Alleral/bootstrap")
if not chunk then
	error("[Alleral Bootstrap redirect] Compile failed: " .. tostring(err))
end
if setfenv then
	pcall(setfenv, chunk, ENV)
end
chunk()
