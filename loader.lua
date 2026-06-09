--[[
	Alleral Loader v1.0
	Paste into your executor:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/loader.lua"))()
]]
local RepoRoot = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/"

-- Session integrity seed — changes every time so copied scripts can't run
local BootKey = game:GetService("HttpService"):GenerateGUID(false)

local Games = {
	[89469502395769] = RepoRoot .. "kick a lucky block.luau",
}

local url = Games[game.PlaceId]
if not url then
	local text = "Alleral: unsupported game (" .. game.PlaceId .. ")"
	warn(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Alleral", Text = text, Duration = 8,
		})
	end)
	return
end

local HttpService = game:GetService("HttpService")

local function fetch(url)
	local ok, src
	local env = getgenv and getgenv() or getfenv and getfenv() or {}

	if #url < 8 then return nil end

	local function valid(body)
		if type(body) ~= "string" or #body < 20 then
			return false
		end
		local head = body:sub(1, 100)
		if head:find("404") or head:find("Not Found") then
			return false
		end
		return true
	end

	local function tryHttpGet(f)
		ok, src = pcall(f)
		if ok and valid(src) then
			return src
		end
		return nil
	end

	local result = tryHttpGet(function() return game:HttpGet(url) end) or
		tryHttpGet(function() return game:HttpGet(url:gsub("%%20", " ")) end) or
		tryHttpGet(function() return game:HttpGetAsync(url) end) or
		tryHttpGet(function() return game:HttpGetAsync(url:gsub("%%20", " ")) end)
	if result then return result end

	local requestCandidates = {
		env.syn and env.syn.request,
		env.fluxus and env.fluxus.request,
		env.http and env.http.request,
		env.http_service and env.http_service.request,
		env.http_request,
		env.request,
		env.Request,
	}

	local urls = { url, url:gsub("%%20", " ") }
	for _, u in ipairs(urls) do
		for _, reqFunc in ipairs(requestCandidates) do
			if type(reqFunc) == "function" then
				ok, src = pcall(reqFunc, { Url = u, Method = "GET" })
				if ok and type(src) == "table" then
					local body = src.Body or src.Content or ""
					if valid(body) then
						return body
					end
				end
			end
		end
	end

	if type(HttpService.RequestAsync) == "function" then
		for _, u in ipairs(urls) do
			ok, src = pcall(HttpService.RequestAsync, HttpService, { Url = u, Method = "GET" })
			if ok and type(src) == "table" then
				local body = src.Body or src.Content or ""
				if valid(body) then
					return body
				end
			end
		end
	end

	return nil
end

local src = fetch(url)
if not src then
	warn("[Alleral] failed to fetch script for PlaceId", game.PlaceId)
	return
end

-- Integrity preamble — injected at runtime so copies fetched elsewhere lack it
local Guard = string.format(
	[[
if getgenv().Alleral_Boot ~= %q then
	warn("[Alleral] Unauthorized copy — exiting")
	return
end
getgenv().Alleral_Boot = nil
]],
	BootKey
)

local full = Guard .. src
local fn, err = loadstring(full)
if not fn then
	warn("[Alleral] compile error:", err)
	return
end

getgenv().Alleral_Boot = BootKey
local r, e = pcall(fn)
getgenv().Alleral_Boot = nil
if not r then
	warn("[Alleral]", e)
end
