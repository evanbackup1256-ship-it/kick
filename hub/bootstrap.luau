-- Back-compat redirect — bootstrap + loader merged into /bootstrap.luau at repo root.
-- Old saved scripts that still hit hub/bootstrap.luau get forwarded in one fetch.

local REPO = "evanbackup1256-ship-it/-kick-loader"
local MERGED_URLS = {
	"https://raw.githubusercontent.com/" .. REPO .. "/main/bootstrap.luau",
	"https://cdn.jsdelivr.net/gh/" .. REPO .. "@main/bootstrap.luau",
}

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()

local function safeCall(name, fn)
	local ok, result = pcall(fn)
	if not ok then
		warn("[Alleral Redirect Error] " .. name .. " failed: " .. tostring(result))
		return nil
	end
	if result == nil then
		warn("[Alleral Redirect Error] " .. name .. " returned nil")
		return nil
	end
	return result
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
	return nil
end

local function fetchMerged()
	local requestFn = pickRequest()
	for _, baseUrl in ipairs(MERGED_URLS) do
		local url = baseUrl .. "?t=" .. tostring(tick())
		if requestFn then
			local body = safeCall("request fetch " .. baseUrl, function()
				local res = requestFn({
					Url = url,
					Method = "GET",
					Headers = { ["Cache-Control"] = "no-cache, no-store" },
				})
				if type(res) == "table" then
					return res.Body or res.body
				end
				return type(res) == "string" and res or nil
			end)
			if type(body) == "string" and #body > 1000 then
				warn("[Alleral Redirect] Fetched " .. tostring(#body) .. "b via request from " .. baseUrl)
				return body
			end
		end
		if typeof(game) == "Instance" and type(game.HttpGet) == "function" then
			local body = safeCall("HttpGet " .. baseUrl, function()
				local ok, b = pcall(game.HttpGet, game, url, true)
				if ok and type(b) == "string" and #b > 0 then
					return b
				end
				ok, b = pcall(game.HttpGet, game, url)
				if ok and type(b) == "string" and #b > 0 then
					return b
				end
				return nil
			end)
			if type(body) == "string" and #body > 1000 then
				return body
			end
		end
	end
	return nil
end

print("[Alleral Bootstrap redirect] Loading merged bootstrap...")
local src = fetchMerged()
if not src then
	error("[Alleral Bootstrap redirect] Could not download merged bootstrap.luau — HTTP blocked or all sources unreachable.")
end

local loadFn = ENV.loadstring or ENV.LoadString or ENV.load or loadstring or load
if type(loadFn) ~= "function" then
	error("[Alleral Bootstrap redirect] loadstring is not available in this executor.")
end

local chunk = safeCall("loadstring bootstrap", function()
	return loadFn(src, "@Alleral/bootstrap")
end)

if type(chunk) ~= "function" then
	error("[Alleral Bootstrap redirect] Compiled chunk is not a function (got " .. type(chunk) .. ").")
end

if setfenv then
	pcall(setfenv, chunk, ENV)
end

local ok, runErr = pcall(chunk)
if not ok then
	error("[Alleral Bootstrap redirect] Runtime: " .. tostring(runErr))
end
