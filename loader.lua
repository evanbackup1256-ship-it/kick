--[[
	Alleral Loader v1.0
	Paste into your executor:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/loader.lua"))()
]]
local RepoRoot = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/"

-- Session integrity seed — changes every time so copied scripts can't run
local BootKey = game:GetService("HttpService"):GenerateGUID(false)

local Games = {
	[89469502395769] = RepoRoot .. "kick%20a%20lucky%20block.luau",
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

local function fetch(url)
	local funcs = {
		function() return game:HttpGet(url) end,
		function() return game:HttpGetAsync(url) end,
		function()
			local r = syn and syn.request or http_request or request
			if r then
				local resp = r({ Url = url, Method = "GET" })
				return resp and resp.Body or ""
			end
			return ""
		end,
	}
	for _, f in ipairs(funcs) do
		local ok, src = pcall(f)
		if ok and src and src ~= "" and not src:find("404") and not src:find("Not Found") then
			return src
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
