-- Alleral — copy/paste this entire file into your executor and click Execute.
local LOAD_URL = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/load.luau"

local function genv()
	local ok, env = pcall(function()
		return (getgenv and getgenv()) or getfenv(0)
	end)
	return ok and env or _G
end

local ENV = genv()
local loadFn = (ENV.loadstring or ENV.LoadString or loadstring or load)
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

if type(loadFn) ~= "function" then
	notify("Executor needs loadstring")
	return warn("[Alleral] Executor needs loadstring.")
end

local source = nil
if type(game.HttpGet) == "function" then
	pcall(function()
		source = game.HttpGet(game, url, true)
	end)
	if type(source) ~= "string" or #source < 1000 then
		pcall(function()
			source = game.HttpGet(game, url)
		end)
	end
end
if type(source) ~= "string" or #source < 1000 then
	pcall(function()
		source = game:HttpGet(url, true)
	end)
end
if type(source) ~= "string" or #source < 1000 then
	pcall(function()
		source = game:HttpGet(url)
	end)
end

if type(source) ~= "string" or #source < 1000 then
	notify("HttpGet failed — enable HTTP in executor")
	return warn("[Alleral] Could not download load.luau")
end

local fn, err = loadFn(source, "Alleral/load")
if type(fn) ~= "function" then
	notify("Failed to compile")
	return warn("[Alleral] Compile failed: " .. tostring(err))
end

ENV.Alleral_Load = function()
	local ok, runErr = pcall(fn)
	if not ok then
		notify("Error — try Alleral_Load() again")
		warn("[Alleral] " .. tostring(runErr))
		return false
	end
	return true
end

local ok, runErr = pcall(fn)
if not ok then
	notify("Startup error — try Alleral_Load()")
	warn("[Alleral] " .. tostring(runErr))
end
