-- Alleral Rayfield -- Native Rayfield UI loader
local ALLERAL_RAYFIELD_VERSION = 3
local RAYFIELD_SOURCE_URL = "https://sirius.menu/rayfield"

local ENV = (function()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end)()

local Rayfield = nil
local rayfieldBooted = false
local configFolder = "Alleral_Configs"

local function fetchRayfieldSource()
	if type(ENV._AlleralRayfieldBundle) == "string" and #ENV._AlleralRayfieldBundle > 1000 then
		return ENV._AlleralRayfieldBundle
	end
	if type(ENV.Alleral_HTTP) == "table" and type(ENV.Alleral_HTTP.get) == "function" then
		local src = ENV.Alleral_HTTP.get(RAYFIELD_SOURCE_URL .. "?t=" .. tostring(tick()), 1000)
		if type(src) == "string" and #src > 1000 then
			ENV._AlleralRayfieldBundle = src
			return src
		end
	end
	return nil
end

local function bootRayfield()
	if rayfieldBooted and Rayfield then
		return Rayfield
	end

	local src = fetchRayfieldSource()
	if not src then
		return nil, "Rayfield source unavailable"
	end

	local chunk = loadstring or load
	if type(chunk) ~= "function" then
		return nil, "loadstring unavailable"
	end

	local compiled, err = chunk(src, "@Rayfield/source")
	if not compiled then
		return nil, tostring(err or "Rayfield compile failed")
	end

	local ok, pkg = pcall(compiled)
	if not ok or type(pkg) ~= "table" then
		return nil, tostring(pkg or "Rayfield runtime failed")
	end

	Rayfield = pkg
	rayfieldBooted = true
	return Rayfield
end

local function getRayfield()
	return bootRayfield()
end

local function getLayoutInfo()
	return { profile = "rayfield", engine = "Rayfield", version = tostring(ALLERAL_RAYFIELD_VERSION), exploitOverlay = false }
end

return {
	Version = ALLERAL_RAYFIELD_VERSION,
	boot = bootRayfield,
	get = getRayfield,
	isBooted = function() return rayfieldBooted end,
	setConfigFolder = function(folder)
		if type(folder) == "string" and folder ~= "" then
			configFolder = folder
		end
	end,
	getConfigFolder = function() return configFolder end,
	getLayoutInfo = getLayoutInfo,
}
