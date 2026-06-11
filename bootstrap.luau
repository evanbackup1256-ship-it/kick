-- Alleral entry shim — save to autoexec, or fetch this file (not launch.luau) via HttpGet.
local LAUNCH_URL = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/launch.luau"

local function genv()
	local ok, env = pcall(function()
		return (getgenv and getgenv()) or getfenv(0)
	end)
	return ok and env or _G
end

local ENV = genv()

local function firstFunc(...)
	for i = 1, select("#", ...) do
		local candidate = select(i, ...)
		if type(candidate) == "function" then
			return candidate
		end
		if type(candidate) == "string" then
			local fn = ENV[candidate] or _G[candidate]
			if type(fn) == "function" then
				return fn
			end
		end
	end
	return nil
end

local loadFn = firstFunc("loadstring", "LoadString", load, loadstring)
local httpRequest = firstFunc("http_request", "request") or (ENV.syn and ENV.syn.request)

local function cacheBust(url)
	local nonce = typeof(tick) == "function" and tick() or math.random()
	return url .. (url:find("?", 1, true) and "&" or "?") .. "t=" .. tostring(nonce)
end

local function httpGet(url)
	url = cacheBust(url)
	if httpRequest then
		local ok, res = pcall(httpRequest, {
			Url = url,
			Method = "GET",
			Headers = {
				["Cache-Control"] = "no-cache, no-store, must-revalidate",
				["Pragma"] = "no-cache",
			},
		})
		if ok and res then
			local status = res.StatusCode or res.status or 200
			local body = res.Body or res.body
			if status >= 200 and status < 300 and type(body) == "string" and body ~= "" then
				return body
			end
		end
	end
	if type(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, url, true)
		if ok and type(body) == "string" and body ~= "" then
			return body
		end
		ok, body = pcall(game.HttpGet, game, url)
		if ok and type(body) == "string" and body ~= "" then
			return body
		end
	end
	return nil
end

if type(loadFn) ~= "function" then
	warn("[Alleral] This executor needs loadstring.")
	return
end

local source = httpGet(LAUNCH_URL)
if type(source) ~= "string" or source == "" then
	warn("[Alleral] Could not download Alleral. Check HTTP and rejoin.")
	return
end

local fn, compileErr = loadFn(source, "Alleral/launch")
if type(fn) ~= "function" then
	warn("[Alleral] Launch failed to compile" .. (compileErr and (": " .. tostring(compileErr)) or "."))
	return
end

local ok, runErr = pcall(fn)
if not ok then
	warn("[Alleral] " .. tostring(runErr))
end
