local ALLERAL_RAYFIELD_VERSION = 1
local RAYFIELD_SOURCE_URL = "https://sirius.menu/rayfield"
local RAYFIELD_FALLBACK_URLS = {
	"https://raw.githubusercontent.com/shlexware/Rayfield/main/source.lua",
}

local ENV = (function()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end)()

local Rayfield = nil
local rayfieldBooted = false

local function deepClone(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local copy = {}
	seen[value] = copy
	for k, v in pairs(value) do
		copy[deepClone(k, seen)] = deepClone(v, seen)
	end
	return copy
end

local function fetchRayfieldSource()
	if type(ENV._AlleralRayfieldBundle) == "string" and #ENV._AlleralRayfieldBundle > 1000 then
		return ENV._AlleralRayfieldBundle, "cached bundle"
	end
	if type(ENV._AlleralRayfieldSource) == "string" and #ENV._AlleralRayfieldSource > 1000 then
		return ENV._AlleralRayfieldSource, "loader cache"
	end

	for attempt = 1, 3 do
		local urls = { RAYFIELD_SOURCE_URL }
		for _, url in ipairs(RAYFIELD_FALLBACK_URLS) do
			table.insert(urls, url)
		end

		for _, url in ipairs(urls) do
			local bust = "?t=" .. tostring(tick()) .. "&attempt=" .. tostring(attempt)

			if type(game) == "Instance" and type(game.HttpGet) == "function" then
				local ok, body = pcall(game.HttpGet, game, url .. bust, true)
				if ok and type(body) == "string" and #body > 1000 then
					body = body:gsub("^%s+", ""):gsub("%s+$", "")
					if not body:find("<!DOCTYPE", 1, true) and not body:find("<html", 1, true) then
						ENV._AlleralRayfieldBundle = body
						return body, url
					end
				end
				ok, body = pcall(game.HttpGet, game, url .. bust)
				if ok and type(body) == "string" and #body > 1000 then
					body = body:gsub("^%s+", ""):gsub("%s+$", "")
					if not body:find("<!DOCTYPE", 1, true) and not body:find("<html", 1, true) then
						ENV._AlleralRayfieldBundle = body
						return body, url
					end
				end
			end

			if type(ENV.Alleral_HTTP) == "table" and type(ENV.Alleral_HTTP.get) == "function" then
				local ok, body = pcall(ENV.Alleral_HTTP.get, url .. bust, 5000)
				if ok and type(body) == "string" and #body > 1000 then
					body = body:gsub("^%s+", ""):gsub("%s+$", "")
					if not body:find("<!DOCTYPE", 1, true) and not body:find("<html", 1, true) then
						ENV._AlleralRayfieldBundle = body
						return body, url
					end
				end
			end
		end

		if attempt < 3 then task.wait(0.5 * attempt) end
	end

	return nil
end

local function bootRayfield()
	if rayfieldBooted and Rayfield then
		return Rayfield
	end

	local loadStringFn = ENV.loadstring or loadstring or load
	if type(loadStringFn) ~= "function" then
		return nil, "loadstring not available"
	end

	local src, sourceLabel = fetchRayfieldSource()
	if type(src) ~= "string" or #src <= 100 then
		return nil, "Rayfield source download empty (HTTP blocked or URLs unreachable)"
	end

	local chunk, err = loadStringFn(src, "@Rayfield/source")
	if type(chunk) ~= "function" then
		if type(load) == "function" then
			chunk, err = load(src, "@Rayfield/source")
		end
		if type(chunk) ~= "function" then
			return nil, "Rayfield compile failed: " .. tostring(err)
		end
	end

	if setfenv then pcall(setfenv, chunk, ENV) end

	local ok, pkg = pcall(chunk)
	if not ok then
		ENV._AlleralRayfieldBundle = nil
		warn("[Alleral Rayfield Error] Runtime: " .. tostring(pkg))
		warn("[Alleral Rayfield Error] " .. tostring(debug.traceback()))
		return nil, "Rayfield runtime failed: " .. tostring(pkg)
	end

	if type(pkg) ~= "table" or type(pkg.CreateWindow) ~= "function" then
		local candidates = { rawget(ENV, "Rayfield"), rawget(ENV, "RayfieldLibrary") }
		if typeof(shared) == "table" then
			table.insert(candidates, rawget(shared, "Rayfield"))
		end
		for _, c in ipairs({ rawget(_G, "Rayfield") }) do
			table.insert(candidates, c)
		end
		for _, candidate in ipairs(candidates) do
			if type(candidate) == "table" and type(candidate.CreateWindow) == "function" then
				pkg = candidate
				break
			end
		end
	end

	if type(pkg) ~= "table" then
		return nil, "Rayfield returned non-table: " .. type(pkg)
	end

	if type(pkg.CreateWindow) ~= "function" then
		return nil, "Rayfield missing CreateWindow"
	end

	Rayfield = pkg
	rayfieldBooted = true
	ENV._AlleralRayfield = pkg
	return Rayfield
end

return {
	Version = ALLERAL_RAYFIELD_VERSION,
	boot = bootRayfield,
	get = function() return bootRayfield() end,
	isBooted = function() return rayfieldBooted end,
	getLayoutInfo = function()
		return { profile = "rayfield", engine = "Rayfield", version = tostring(ALLERAL_RAYFIELD_VERSION) }
	end,
}
