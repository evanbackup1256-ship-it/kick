--[[
	Alleral rescue — paste in Volt and Execute ONCE.
	Saves core + loader to workspace, validates compile, runs Alleral.
]]
local g = (getgenv and getgenv()) or {}
local L = g.loadstring or g.LoadString or loadstring or load
if type(L) ~= "function" then
	return warn("[Alleral] loadstring unavailable")
end

local function fetch(url)
	url = url .. "?t=" .. tostring(tick())
	if type(g.Volt) == "table" and type(g.Volt.request) == "function" then
		local ok, res = pcall(g.Volt.request, { Url = url, Method = "GET" })
		if ok and res then
			return res.Body or res.body
		end
	end
	if type(g.request) == "function" then
		local ok, res = pcall(g.request, { Url = url, Method = "GET" })
		if ok and res then
			return res.Body or res.body
		end
	end
	if type(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, url, true)
		if ok and type(body) == "string" then
			return body
		end
	end
	return nil
end

local function coreValid(src)
	if type(src) ~= "string" or #src < 5000 or not src:find("loadRayfield", 1, true) then
		return false
	end
	local version = src:match('Core%.VERSION%s*=%s*"([%d%.]+)"')
	if not version or version < "1.18" then
		return false
	end
	if src:find("fakeUiInstance", 1, true) and not src:find("AlleralGroupShell", 1, true) then
		return false
	end
	local fn = L(src, "Alleral/core-check")
	return type(fn) == "function"
end

local function loaderValid(src)
	return type(src) == "string"
		and #src > 8000
		and src:find("Alleral Hub", 1, true)
		and not src:find("EMBEDDED_CORE = [=", 1, true)
		and type(L(src, "Alleral/loader-check")) == "function"
end

local coreUrls = {
	"https://cdn.jsdelivr.net/gh/evanbackup1256-ship-it/kick@d9441a1/core/alleral_core.luau",
	"https://cdn.jsdelivr.net/gh/evanbackup1256-ship-it/kick@main/core/alleral_core.luau",
	"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/core/alleral_core.luau",
}
local loaderUrls = {
	"https://cdn.jsdelivr.net/gh/evanbackup1256-ship-it/kick@main/loader.luau",
	"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/loader.luau",
}

local writeFile = g.writefile or writefile
local makeFolder = g.makefolder or makefolder

local coreSrc = nil
for _, url in ipairs(coreUrls) do
	local body = fetch(url)
	if coreValid(body) then
		coreSrc = body
		break
	end
end
if not coreSrc then
	return warn("[Alleral] Could not download valid core (need v1.18+)")
end

if type(makeFolder) == "function" then
	pcall(makeFolder, "core")
end
if type(writeFile) == "function" then
	pcall(writeFile, "core/alleral_core.luau", coreSrc)
	print("[Alleral] Saved core/alleral_core.luau")
end

local coreFn = L(coreSrc, "Alleral/core-rescue")
if type(coreFn) == "function" then
	coreFn()
end

local loaderSrc = nil
for _, url in ipairs(loaderUrls) do
	local body = fetch(url)
	if loaderValid(body) then
		loaderSrc = body
		break
	end
end
if not loaderSrc then
	return warn("[Alleral] Could not download valid loader")
end

if type(writeFile) == "function" then
	pcall(writeFile, "loader.luau", loaderSrc)
	print("[Alleral] Saved loader.luau")
end

local fn, err = L(loaderSrc, "Alleral/loader")
if type(fn) ~= "function" then
	return warn("[Alleral] Loader compile failed: " .. tostring(err))
end
fn()
