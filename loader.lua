--[[
	Alleral Loader v1.2
	loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/loader.lua"))()
]]
local HttpService = game:GetService("HttpService")

local RAW_BASE = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/"

local Games = {
	[89469502395769] = "kick%20a%20lucky%20block.luau",
}

local fileName = Games[game.PlaceId]
if not fileName then
	warn("Alleral: unsupported game (" .. game.PlaceId .. ")")
	return
end

local function BuildURL()
	return RAW_BASE .. fileName
end

local function SafeGet(url)
	if type(url) ~= "string" or url == "" then
		warn("[Loader] Invalid URL:", url)
		return nil
	end

	local success, result = pcall(function()
		return game:HttpGet(url)
	end)

	if not success then
		warn("[Loader] HttpGet failed:", result)
		return nil
	end

	return result
end

local function LoadScript()
	local url = BuildURL()

	local code = SafeGet(url)
	if not code then
		warn("[Loader] Failed to fetch script.")
		return
	end

	local fn = loadstring(code)
	if not fn then
		warn("[Loader] Failed to compile script.")
		return
	end

	return fn()
end

LoadScript()