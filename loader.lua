--[[
	Alleral Loader v1.1
	loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/loader.lua"))()
]]
local RepoRoot = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/"

local Games = {
	[89469502395769] = RepoRoot .. "kick a lucky block.luau",
}

local url = Games[game.PlaceId]
if not url then
	warn("Alleral: unsupported game (" .. game.PlaceId .. ")")
	return
end

loadstring(game:HttpGet(url))()
