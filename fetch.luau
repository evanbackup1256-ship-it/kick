-- Alleral fetch bootstrap (small). Prefer paste.luau bundled copy if HttpGet fails on your executor.
local LOAD_URL = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/load.luau"

local function genv()
	local ok, env = pcall(function()
		return (getgenv and getgenv()) or getfenv(0)
	end)
	return ok and env or _G
end

local ENV = genv()
local HttpService = nil
pcall(function()
	HttpService = game:GetService("HttpService")
end)

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

local function resolveLoad()
	return firstFunc(
		ENV.loadstring,
		ENV.LoadString,
		"loadstring",
		"LoadString",
		load,
		loadstring
	)
end

local function resolveRequest()
	local candidates = {
		ENV.Volt and ENV.Volt.request,
		ENV.Wave and ENV.Wave.request,
		ENV.Solara and ENV.Solara.request,
		ENV.Xeno and ENV.Xeno.request,
		ENV.Krnl and ENV.Krnl.request,
		ENV.syn and ENV.syn.request,
		ENV.http and ENV.http.request,
		firstFunc("http_request", "request", "Request"),
	}
	for _, fn in ipairs(candidates) do
		if type(fn) == "function" then
			return fn
		end
	end
	if HttpService and type(HttpService.RequestAsync) == "function" then
		return function(opts)
			return HttpService:RequestAsync({
				Url = opts.Url or opts.url,
				Method = opts.Method or opts.method or "GET",
				Headers = opts.Headers or opts.headers,
			})
		end
	end
	return nil
end

local loadFn = resolveLoad()
local httpRequest = resolveRequest()
local url = LOAD_URL .. "?t=" .. tostring(typeof(tick) == "function" and tick() or math.random())

local function notify(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Alleral",
			Text = text,
			Duration = 8,
		})
	end)
end

local function accept(body)
	return type(body) == "string" and #body > 10000 and body:find("EMBEDDED_LOADER", 1, true)
end

local function extractBody(response)
	if type(response) == "string" then
		return response
	end
	if type(response) == "table" then
		return response.Body or response.body or response.Data or response.data
	end
	return nil
end

local function httpFetch(fetchUrl)
	if httpRequest then
		for _, spec in ipairs({
			{ Url = fetchUrl, Method = "GET", Headers = { ["Cache-Control"] = "no-cache" } },
			{ url = fetchUrl, method = "GET", headers = { ["Cache-Control"] = "no-cache" } },
		}) do
			local ok, res = pcall(httpRequest, spec)
			local body = ok and extractBody(res)
			if accept(body) then
				return body
			end
		end
	end

	if type(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, fetchUrl, true)
		if ok and accept(body) then
			return body
		end
		ok, body = pcall(game.HttpGet, game, fetchUrl)
		if ok and accept(body) then
			return body
		end
	end

	local ok, body = pcall(function()
		return game:HttpGet(fetchUrl, true)
	end)
	if ok and accept(body) then
		return body
	end

	ok, body = pcall(function()
		return game:HttpGet(fetchUrl)
	end)
	if ok and accept(body) then
		return body
	end

	if HttpService and type(HttpService.GetAsync) == "function" then
		ok, body = pcall(function()
			return HttpService:GetAsync(fetchUrl, true)
		end)
		if ok and accept(body) then
			return body
		end
	end

	return nil
end

if type(loadFn) ~= "function" then
	notify("Need loadstring — paste full paste.luau from GitHub")
	return warn("[Alleral] Need loadstring. Open paste.luau on GitHub, copy ALL, paste here.")
end

local source = httpFetch(url)
if type(source) ~= "string" then
	notify("HTTP failed — paste full paste.luau from GitHub")
	return warn("[Alleral] HTTP failed. Open paste.luau on GitHub, copy ALL, paste here.")
end

local fn, err = loadFn(source, "Alleral/load")
if type(fn) ~= "function" then
	notify("Compile failed")
	return warn("[Alleral] Compile failed: " .. tostring(err))
end

local ok, runErr = pcall(fn)
if not ok then
	notify("Startup error")
	warn("[Alleral] " .. tostring(runErr))
end
