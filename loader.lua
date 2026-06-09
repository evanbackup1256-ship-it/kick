--[[
	Alleral Hub Loader v2.0
	loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/loader.lua"))()
]]
local HUB_URL = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/hub.luau"

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

local code = SafeGet(HUB_URL)
if not code then
	warn("[Loader] Failed to fetch Alleral Hub.")
	return
end

local fn, err = loadstring(code)
if not fn then
	warn("[Loader] Failed to compile hub:", err)
	return
end

fn()