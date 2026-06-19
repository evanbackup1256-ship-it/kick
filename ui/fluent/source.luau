local ALLERAL_FLUENT_VERSION = 1
local FLUENT_SOURCE_URL = "https://raw.githubusercontent.com/dawid-scripts/Fluent/main/Built.lua"

local ENV = (function()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end)()

local Fluent = nil
local fluentBooted = false
local configFolder = "Alleral_Configs"

local function fetchFluentSource()
	if type(ENV._AlleralFluentBundle) == "string" and #ENV._AlleralFluentBundle > 1000 then
		return ENV._AlleralFluentBundle
	end

	local body

	if type(game) == "Instance" and type(game.HttpGet) == "function" then
		pcall(function()
			body = game:HttpGet(FLUENT_SOURCE_URL .. "?t=" .. tostring(tick()), true)
		end)
	end

	if type(body) ~= "string" or #body <= 1000 then
		if type(ENV.Alleral_HTTP) == "table" and type(ENV.Alleral_HTTP.get) == "function" then
			body = ENV.Alleral_HTTP.get(FLUENT_SOURCE_URL .. "?t=" .. tostring(tick()), 5000)
		end
	end

	if type(body) ~= "string" or #body <= 1000 then
		if type(game) == "Instance" and type(game.HttpGet) == "function" then
			pcall(function()
				body = game:HttpGet(FLUENT_SOURCE_URL .. "?t=" .. tostring(tick()))
			end)
		end
	end

	if type(body) ~= "string" or #body <= 1000 then
		return nil
	end

	body = body:gsub("^%s+", ""):gsub("%s+$", "")
	if body:find("<!DOCTYPE", 1, true) or body:find("<html", 1, true) then
		return nil
	end

	ENV._AlleralFluentBundle = body
	return body
end

local function bootFluent()
	if fluentBooted and Fluent then
		return Fluent
	end

	local loadStringFn = ENV.loadstring or loadstring or load
	if type(loadStringFn) ~= "function" then
		return nil, "loadstring not available"
	end

	ENV.loadstring = loadStringFn
	ENV.game = ENV.game or game

	if type(task) == "table" then
		ENV.task = task
		ENV.task.spawn = ENV.task.spawn or function(f) coroutine.wrap(f)() end
		ENV.task.delay = ENV.task.delay or function(t, f) ENV.task.spawn(function() task.wait(t); f() end) end
		ENV.task.wait = ENV.task.wait or task.wait
		ENV.task.cancel = ENV.task.cancel or function() end
	end

	local src = fetchFluentSource()
	if type(src) ~= "string" or #src <= 100 then
		return nil, "Fluent source download empty"
	end

	local chunk, err = loadStringFn(src, "@Fluent/source")
	if type(chunk) ~= "function" then
		return nil, "Fluent compile failed: " .. tostring(err)
	end

	if setfenv then pcall(setfenv, chunk, ENV) end

	local ok, pkg = pcall(chunk)
	if not ok then
		return nil, "Fluent runtime failed: " .. tostring(pkg)
	end

	if type(pkg) ~= "table" then
		return nil, "Fluent returned non-table: " .. type(pkg)
	end

	if type(pkg.CreateWindow) ~= "function" then
		return nil, "Fluent missing CreateWindow"
	end

	Fluent = pkg
	fluentBooted = true
	return Fluent
end

return {
	Version = ALLERAL_FLUENT_VERSION,
	boot = bootFluent,
	get = function() return bootFluent() end,
	isBooted = function() return fluentBooted end,
	setConfigFolder = function(f) configFolder = f or configFolder end,
	getConfigFolder = function() return configFolder end,
	getLayoutInfo = function()
		return { profile = "fluent", engine = "Fluent", version = tostring(ALLERAL_FLUENT_VERSION) }
	end,
}
