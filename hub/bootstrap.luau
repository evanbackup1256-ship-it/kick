-- Alleral Bootstrap v1.0.0
-- Save this loadstring once in your executor — it always fetches the latest loader from GitHub.
-- One-liner: loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/hub/bootstrap.luau?t=" .. tick(), true))()

local BOOTSTRAP_VERSION = "1.0.0"
local REPO = "evanbackup1256-ship-it/kick"
local BRANCH = "main"
local GITHUB_RAW = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH
local LOADER_URL = GITHUB_RAW .. "/loader.luau"

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local function resolveGame()
	if typeof(game) == "Instance" then
		return game
	end
	if _G and typeof(_G.game) == "Instance" then
		return _G.game
	end
	local env = genv()
	if typeof(env.game) == "Instance" then
		return env.game
	end
	return nil
end

local game = resolveGame()
if not game then
	error("[Alleral Bootstrap] game is nil — run inside a Roblox game, not the executor menu.")
end

local ENV = genv()
if typeof(ENV.game) ~= "Instance" then
	ENV.game = game
end

local function pick(names)
	for _, name in ipairs(names) do
		local fn = ENV[name]
		if type(fn) ~= "function" and _G then
			fn = _G[name]
		end
		if type(fn) == "function" then
			return fn
		end
	end
	return nil
end

local loadStringFn = pick({ "loadstring", "LoadString", "load" })
if not loadStringFn then
	error("[Alleral Bootstrap] loadstring is not available in this executor.")
end

local function httpGet(url, minBytes)
	minBytes = minBytes or 0
	local plain = url:gsub("%?.*$", "")
	local candidates = { plain .. "?t=" .. tostring(tick()), plain, url }
	for _, candidate in ipairs(candidates) do
		if type(game.HttpGet) == "function" then
			local ok, body = pcall(game.HttpGet, game, candidate, true)
			if ok and type(body) == "string" and #body >= minBytes then
				return body, "httpget"
			end
			ok, body = pcall(game.HttpGet, game, candidate)
			if ok and type(body) == "string" and #body >= minBytes then
				return body, "httpget"
			end
		end
		local ok, body = pcall(function()
			return game:HttpGet(candidate, true)
		end)
		if ok and type(body) == "string" and #body >= minBytes then
			return body, "httpget"
		end
		ok, body = pcall(function()
			return game:HttpGet(candidate)
		end)
		if ok and type(body) == "string" and #body >= minBytes then
			return body, "httpget"
		end
		local requestFn = pick({ "request", "http_request", "httprequest" })
		if requestFn then
			ok, body = pcall(function()
				local res = requestFn({
					Url = candidate,
					Method = "GET",
					Headers = { ["User-Agent"] = "Alleral-Bootstrap/" .. BOOTSTRAP_VERSION },
				})
				if type(res) == "table" and res.Body and #res.Body >= minBytes then
					return res.Body
				end
				return nil
			end)
			if ok and type(body) == "string" then
				return body, "request"
			end
		end
	end
	return nil, "all transports failed"
end

local function loaderVersionFromSource(src)
	if type(src) ~= "string" then
		return nil
	end
	return src:match('LOADER_VERSION%s*=%s*"([%d%.]+)"')
end

local PURGE_ROOTS = { "", "kick/", "kick/kick/", "workspace/", "scripts/" }
local PURGE_PATHS = {
	"loader.luau",
	"kick/loader.luau",
	"kick/kick/loader.luau",
	"Alleral/loader.luau",
	"hub/bootstrap.luau",
	"hub/alleral_ui.luau",
	"hub/core_base.luau",
	"hub/core_ui.luau",
	"hub/core_hub_ui.luau",
	"ui/syde/source.luau",
	".alleral/versions.json",
}

local function purgeAlleralWorkspace()
	local deleteFileFn = pick({ "delfile", "deletefile", "delete_file", "DeleteFile", "removefile", "RemoveFile" })
	local isFileFn = pick({ "isfile", "is_file", "IsFile" })
	local listFilesFn = pick({ "listfiles", "list_files", "ListFiles" })
	local isFolderFn = pick({ "isfolder", "is_folder", "IsFolder" })
	local deleteFolderFn = pick({ "delfolder", "deletefolder", "delete_folder", "DeleteFolder" })
	if not deleteFileFn or not isFileFn then
		return 0
	end

	local removed = 0
	local seen = {}
	local function tryDelete(path)
		if type(path) ~= "string" or path == "" or seen[path] then
			return
		end
		seen[path] = true
		local okExists, exists = pcall(isFileFn, path)
		if okExists and exists then
			if pcall(deleteFileFn, path) then
				removed += 1
			end
		end
	end

	for _, path in ipairs(PURGE_PATHS) do
		tryDelete(path)
		for _, root in ipairs(PURGE_ROOTS) do
			tryDelete(root .. path)
		end
	end

	local function purgeTree(dir)
		if type(dir) ~= "string" or dir == "" or not listFilesFn then
			return
		end
		dir = dir:gsub("^/", ""):gsub("/$", "")
		local okList, entries = pcall(listFilesFn, dir)
		if not okList or type(entries) ~= "table" then
			if deleteFolderFn then
				pcall(deleteFolderFn, dir)
			end
			return
		end
		for _, entry in ipairs(entries) do
			if type(entry) == "string" then
				local path = entry:gsub("^/", "")
				local isDir = false
				if isFolderFn then
					local okFolder, folder = pcall(isFolderFn, path)
					isDir = okFolder and folder == true
				end
				if isDir then
					purgeTree(path)
				else
					tryDelete(path)
				end
			end
		end
		if deleteFolderFn then
			pcall(deleteFolderFn, dir)
		end
	end

	for _, dir in ipairs({ ".alleral", "hub", "ui", "games", "Alleral" }) do
		purgeTree(dir)
	end

	return removed
end

local function runLoaderSource(src, label)
	local fn, err = loadStringFn(src, label or "Alleral/loader")
	if not fn then
		return false, "compile: " .. tostring(err)
	end
	if setfenv then
		pcall(setfenv, fn, ENV)
	end
	ENV._Alleral_BootstrapVersion = BOOTSTRAP_VERSION
	ENV._Alleral_Bootstrapped = true
	ENV._Alleral_BootstrapAt = tick()
	local ok, runErr = pcall(fn)
	if not ok then
		return false, "runtime: " .. tostring(runErr)
	end
	return true
end

local function Alleral_Bootstrap(reason)
	reason = reason or "bootstrap"
	if ENV._Alleral_BootstrapRunning then
		return false, "bootstrap already running"
	end
	ENV._Alleral_BootstrapRunning = true

	local purged = purgeAlleralWorkspace()
	if purged > 0 then
		print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Purged " .. tostring(purged) .. " cached workspace file(s)")
	end

	local src, via = httpGet(LOADER_URL, 500)
	if type(src) ~= "string" or #src < 500 then
		ENV._Alleral_BootstrapRunning = false
		return false, "remote loader failed (" .. tostring(via) .. ")"
	end

	local remoteVer = loaderVersionFromSource(src) or "unknown"
	print(
		"[Alleral Bootstrap v"
			.. BOOTSTRAP_VERSION
			.. "] Loading loader v"
			.. remoteVer
			.. " from GitHub ("
			.. tostring(via)
			.. ", "
			.. tostring(#src)
			.. "b) ["
			.. tostring(reason)
			.. "]"
	)

	local ok, err = runLoaderSource(src, "Alleral/loader@" .. remoteVer)
	ENV._Alleral_BootstrapRunning = false
	if not ok then
		warn("[Alleral Bootstrap] " .. tostring(err))
		return false, err
	end
	task.defer(function()
		purgeAlleralWorkspace()
	end)
	return true, remoteVer
end

ENV.Alleral_Bootstrap = Alleral_Bootstrap
if type(getgenv) == "function" then
	local ok, g = pcall(getgenv)
	if ok and type(g) == "table" then
		g.Alleral_Bootstrap = Alleral_Bootstrap
	end
end

if not ENV._Alleral_BootstrapSkipAutoRun then
	Alleral_Bootstrap("loadstring")
end
