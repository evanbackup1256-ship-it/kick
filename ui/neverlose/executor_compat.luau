-- NEVERLOSE_UI_VERSION = "1.5.3-kick"
--[[
	Cross-executor compatibility helpers for Neverlose UI.
	Sanitizes Luau sources and provides safe fallbacks for missing exploit APIs.
]]

return function()
	local function sanitizeLuauSource(source)
		if type(source) ~= "string" or source == "" then
			return source
		end
		source = source:gsub("\r\n", "\n")
		local out = {}
		for line in (source .. "\n"):gmatch("(.-)\n") do
			if not line:match("^%-%-![%w_]+") then
				table.insert(out, line)
			end
		end
		return table.concat(out, "\n")
	end

	local function hexColor(value, fallback)
		fallback = fallback or Color3.new(1, 1, 1)
		if Color3.fromHex then
			local ok, color = pcall(Color3.fromHex, value)
			if ok and typeof(color) == "Color3" then
				return color
			end
		end
		local hex = tostring(value or ""):gsub("#", "")
		if #hex >= 6 then
			return Color3.fromRGB(
				tonumber(hex:sub(1, 2), 16) or 255,
				tonumber(hex:sub(3, 4), 16) or 255,
				tonumber(hex:sub(5, 6), 16) or 255
			)
		end
		return fallback
	end

	local function bindGlobal(name, fallback)
		local fn
		if type(getgenv) == "function" then
			local ok, env = pcall(getgenv)
			if ok and type(env) == "table" then
				fn = env[name]
			end
		end
		if type(fn) ~= "function" and _G then
			fn = _G[name]
		end
		if type(fn) ~= "function" then
			return fallback
		end
		return fn
	end

	local function bindFilesystem()
		return {
			isfile = bindGlobal("isfile", function()
				return false
			end),
			writefile = bindGlobal("writefile", function() end),
			readfile = bindGlobal("readfile", function()
				return nil
			end),
			makefolder = bindGlobal("makefolder", function() end),
			isfolder = bindGlobal("isfolder", function()
				return true
			end),
			listfiles = bindGlobal("listfiles", function()
				return {}
			end),
			delfile = bindGlobal("delfile", function() end),
			getcustomasset = bindGlobal("getcustomasset", function(path)
				return tostring(path)
			end),
		}
	end

	local function looksLikeLua(body)
		if type(body) ~= "string" or #body < 32 then
			return false
		end
		if body:find("<!DOCTYPE", 1, true) or body:find("<html", 1, true) then
			return false
		end
		return body:find("function", 1, true) ~= nil
			or body:find("local ", 1, true) ~= nil
			or body:find("return ", 1, true) ~= nil
	end

	local function relaxedStructureOk(src, markers)
		if type(src) ~= "string" or not looksLikeLua(src) then
			return false
		end
		markers = type(markers) == "table" and markers or {}
		for _, marker in ipairs(markers) do
			if type(marker) == "string" and marker ~= "" and not src:find(marker, 1, true) then
				return false
			end
		end
		return true
	end

	return {
		sanitizeLuauSource = sanitizeLuauSource,
		hexColor = hexColor,
		bindFilesystem = bindFilesystem,
		looksLikeLua = looksLikeLua,
		relaxedStructureOk = relaxedStructureOk,
	}
end
