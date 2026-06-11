--[[
	Loads arrrel.luau onto a WindUI instance.
	Used by main.lua; can also be required from core as a fallback.
]]

local ALLERAL_UI_VERSION = "2.1.4-alleral-v2"

local PATCH_FILE = "arrrel.luau"
local PATCH_FALLBACK = "aller.luau"
local AUTOSCALE_FILE = "autoscale.luau"
local PATCH_ROOTS = {
	"ui/windui/",
	"windui/",
	"kick/ui/windui/",
	"kick/kick/ui/windui/",
}

local PATCH_URLS = {
	"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/ui/windui/autoscale.luau",
	"https://github.com/evanbackup1256-ship-it/kick/raw/main/ui/windui/autoscale.luau",
	"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/ui/windui/arrrel.luau",
	"https://github.com/evanbackup1256-ship-it/kick/raw/main/ui/windui/arrrel.luau",
	"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/ui/windui/aller.luau",
	"https://github.com/evanbackup1256-ship-it/kick/raw/main/ui/windui/aller.luau",
}

local function validPatchSource(body)
	return type(body) == "string"
		and #body > 800
		and (body:find("ARRREL_UI_VERSION", 1, true) ~= nil or body:find("ALLERAL_UI_VERSION", 1, true) ~= nil)
		and body:find("return function", 1, true) ~= nil
end

local function httpFetch(url, validator)
	local bust = url .. (url:find("?", 1, true) and "&" or "?") .. "t=" .. tostring(tick())
	local ok, body = pcall(function()
		return game:HttpGet(bust)
	end)
	if ok and type(body) == "string" and (not validator or validator(body)) then
		return body
	end

	local HttpService = game:GetService("HttpService")
	if HttpService and type(HttpService.GetAsync) == "function" then
		ok, body = pcall(function()
			return HttpService:GetAsync(bust, true)
		end)
		if ok and type(body) == "string" and (not validator or validator(body)) then
			return body
		end
	end

	return nil
end

local function readLocalPatch()
	local readFn = readfile
		or (syn and syn.readfile)
		or (fluxus and fluxus.readfile)
	local isFileFn = isfile or (syn and syn.isfile)
	if type(readFn) ~= "function" or type(isFileFn) ~= "function" then
		return nil
	end

	for _, fileName in ipairs({ PATCH_FILE, PATCH_FALLBACK }) do
		for _, root in ipairs(PATCH_ROOTS) do
			local path = root .. fileName
			if isFileFn(path) then
				local ok, body = pcall(readFn, path)
				if ok and validPatchSource(body) then
					return body, path
				end
			end
		end
	end

	return nil
end

local function fetchRemotePatch()
	for _, url in ipairs(PATCH_URLS) do
		if url:find("arrrel", 1, true) or url:find("aller", 1, true) then
			local body = httpFetch(url, validPatchSource)
			if body then
				return body, url
			end
		end
	end
	return nil
end

return function(WindUI)
	if type(WindUI) ~= "table" then
		return WindUI
	end

	local function loadModule(fileName, marker)
		for _, url in ipairs(PATCH_URLS) do
			if url:find(fileName, 1, true) then
				local body = httpFetch(url, function(source)
					return type(source) == "string" and source:find(marker, 1, true) ~= nil
				end)
				if body then
					return body, url
				end
			end
		end
		local readFn = readfile or (syn and syn.readfile) or (fluxus and fluxus.readfile)
		local isFileFn = isfile or (syn and syn.isfile)
		if type(readFn) == "function" and type(isFileFn) == "function" then
			for _, root in ipairs(PATCH_ROOTS) do
				local path = root .. fileName
				if isFileFn(path) then
					local ok, body = pcall(readFn, path)
					if ok and type(body) == "string" and body:find(marker, 1, true) then
						return body, path
					end
				end
			end
		end
		return nil
	end

	local autoscaleSource = loadModule(AUTOSCALE_FILE, "registerLayoutRefresh")
	if autoscaleSource then
		local compile = loadstring or load
		if type(compile) == "function" then
			local chunk = compile(autoscaleSource, "@Arrrel/autoscale")
			if chunk then
				local ok, factory = pcall(chunk)
				if ok and type(factory) == "function" then
					pcall(factory, WindUI)
				end
			end
		end
	end

	local source, label = fetchRemotePatch()
	if not source then
		source, label = readLocalPatch()
	end
	if not source then
		warn("[Arrrel] arrrel.luau missing — UI patch skipped")
		return WindUI
	end

	local compile = loadstring or load
	if type(compile) ~= "function" then
		warn("[Arrrel] loadstring missing — UI patch skipped")
		return WindUI
	end

	local chunk, compileErr = compile(source, "@" .. tostring(label or PATCH_FILE))
	if not chunk then
		warn("[Arrrel] UI patch compile: " .. tostring(compileErr))
		return WindUI
	end

	local ok, patchOrErr = pcall(chunk)
	if not ok or type(patchOrErr) ~= "function" then
		warn("[Arrrel] UI patch load: " .. tostring(patchOrErr))
		return WindUI
	end

	local applied, applyErr = pcall(patchOrErr, WindUI)
	if not applied then
		warn("[Arrrel] UI patch apply: " .. tostring(applyErr))
	end

	return WindUI
end
