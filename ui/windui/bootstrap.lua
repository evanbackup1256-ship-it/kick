--[[
	Loads arrrel.luau onto a WindUI instance.
	Used by main.lua; can also be required from core as a fallback.
]]

local PATCH_FILE = "arrrel.luau"
local PATCH_FALLBACK = "aller.luau"
local PATCH_ROOTS = {
	"ui/windui/",
	"vendor/windui/",
	"windui/",
	"kick/ui/windui/",
	"kick/kick/ui/windui/",
}

local PATCH_URLS = {
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

local function httpFetch(url)
	local bust = url .. (url:find("?", 1, true) and "&" or "?") .. "t=" .. tostring(tick())
	local ok, body = pcall(function()
		return game:HttpGet(bust)
	end)
	if ok and validPatchSource(body) then
		return body
	end

	local HttpService = game:GetService("HttpService")
	if HttpService and type(HttpService.GetAsync) == "function" then
		ok, body = pcall(function()
			return HttpService:GetAsync(bust, true)
		end)
		if ok and validPatchSource(body) then
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
		local body = httpFetch(url)
		if body then
			return body, url
		end
	end
	return nil
end

return function(WindUI)
	if type(WindUI) ~= "table" then
		return WindUI
	end

	local source, label = readLocalPatch()
	if not source then
		source, label = fetchRemotePatch()
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
