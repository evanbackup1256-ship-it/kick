-- Alleral Bootstrap v1.0.4
-- Save this loadstring once in your executor — it always fetches the latest loader from GitHub.
-- One-liner: loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/hub/bootstrap.luau?t=" .. tick(), true))()

local BOOTSTRAP_VERSION = "1.0.4"
local REPO = "evanbackup1256-ship-it/kick"
local BRANCH = "main"
local GITHUB_RAW = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH
local JSDELIVR = "https://cdn.jsdelivr.net/gh/" .. REPO
local RELEASE_URL = GITHUB_RAW .. "/cfg/release.json"

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
	for i, candidate in ipairs(candidates) do
		if i > 1 and typeof(task) == "table" and type(task.wait) == "function" then
			pcall(task.wait)
		end
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

local function parseReleaseJson(src)
	if type(src) ~= "string" then
		return nil
	end
	return {
		loader = src:match('"loader"%s*:%s*"([^"]+)"'),
		commit = src:match('"commit"%s*:%s*"([^"]+)"'),
		sydePatch = tonumber(src:match('"sydePatch"%s*:%s*(%d+)')),
	}
end

local function loaderCommitFromSource(src)
	if type(src) ~= "string" then
		return nil
	end
	return src:match('commit = "([^"]+)"')
end

local function loaderSydePatchFromSource(src)
	if type(src) ~= "string" then
		return nil
	end
	return tonumber(src:match("local SYDE_PATCH_VERSION = (%d+)"))
end

local function loaderMatchesRelease(src, meta, strictCommit)
	if type(src) ~= "string" or type(meta) ~= "table" then
		return false, "invalid loader body"
	end
	local remoteVer = loaderVersionFromSource(src)
	if type(meta.loader) == "string" and meta.loader ~= "" then
		if remoteVer ~= meta.loader then
			return false, "loader v" .. tostring(remoteVer or "?") .. " != release v" .. meta.loader
		end
	end
	if strictCommit and type(meta.commit) == "string" and meta.commit ~= "" then
		local embedded = loaderCommitFromSource(src)
		if embedded ~= meta.commit then
			return false, "embedded commit " .. tostring(embedded or "?") .. " != release " .. meta.commit
		end
	end
	if strictCommit and type(meta.sydePatch) == "number" then
		local patch = loaderSydePatchFromSource(src)
		if patch ~= meta.sydePatch then
			return false, "syde patch v" .. tostring(patch or "?") .. " != release v" .. tostring(meta.sydePatch)
		end
	end
	return true, remoteVer
end

local function fetchReleaseMeta()
	local src, via = httpGet(RELEASE_URL, 40)
	local meta = parseReleaseJson(src)
	if meta and meta.loader and meta.commit then
		return meta, via
	end
	return { loader = nil, commit = BRANCH }, via or "release-unavailable"
end

local function buildLoaderUrls(meta)
	local commit = (meta and meta.commit) or BRANCH
	local bust = "?t=" .. tostring(tick())
	return {
		{ url = "https://raw.githubusercontent.com/" .. REPO .. "/" .. commit .. "/loader.luau" .. bust, strictCommit = true },
		{ url = JSDELIVR .. "@" .. commit .. "/loader.luau" .. bust, strictCommit = true },
		{ url = GITHUB_RAW .. "/loader.luau" .. bust, strictCommit = false },
	}
end

local PURGE_ROOTS = { "", "kick/", "kick/kick/", "workspace/", "scripts/", "autoexec/", "Autoexec/" }
local SCAN_DIRS = { "", "autoexec", "Autoexec", "autoexecute", "AutoExecute", "workspace", "scripts", "kick", "kick/kick" }
local LEGACY_LOADER_MARKERS = {
	"[Alleral Loader v",
	"Alleral loader 3.",
	"Alleral loader 4.",
	"EMBEDDED_LOADER =",
	"launch.template.luau",
	'LOADER_VERSION = "3.',
	'LOADER_VERSION = "4.',
	"obfusctated_uilibrary",
}
local LEGACY_ENTRY_NAMES = {
	"loader.luau",
	"load.luau",
	"launch.luau",
	"run.luau",
	"alleral.luau",
	"alleralloader.luau",
	"AlleralLoader.luau",
	"alleral_loader.luau",
	"alleral_bootstrap.luau",
	"obfusctated_uilibrary.luau",
}
local PURGE_PATHS = {
	"loader.luau",
	"kick/loader.luau",
	"kick/kick/loader.luau",
	"Alleral/loader.luau",
	"hub/bootstrap.luau",
	"hub/loader_relaunch.luau",
	"hub/alleral_ui.luau",
	"hub/core_base.luau",
	"hub/core.luau",
	"hub/core_ui.luau",
	"hub/core_hub_ui.luau",
	"core/alleral_core.luau",
	"alleral_core.luau",
	"ui/syde/source.luau",
	"obfusctated_uilibrary.luau",
	".alleral/versions.json",
}

local function isLegacyLoaderSource(src)
	if type(src) ~= "string" or #src < 80 then
		return false
	end
	for _, marker in ipairs(LEGACY_LOADER_MARKERS) do
		if src:find(marker, 1, true) then
			return true
		end
	end
	local ver = src:match('LOADER_VERSION%s*=%s*"([%d%.]+)"')
	if ver then
		local major = tonumber(ver:match("^(%d+)")) or 99
		if major < 5 then
			return true
		end
	end
	return false
end

local function purgeLegacyWorkspaceLoaders(deleteFileFn, isFileFn, readFileFn, listFilesFn, isFolderFn)
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
		if okExists and exists and pcall(deleteFileFn, path) then
			removed += 1
		end
	end

	for _, dir in ipairs(SCAN_DIRS) do
		for _, name in ipairs(LEGACY_ENTRY_NAMES) do
			local path = dir == "" and name or (dir .. "/" .. name)
			local okExists, exists = pcall(isFileFn, path)
			if okExists and exists and readFileFn then
				local okRead, body = pcall(readFileFn, path)
				if okRead and isLegacyLoaderSource(body) then
					tryDelete(path)
				end
			end
		end
	end

	if not listFilesFn or not readFileFn then
		return removed
	end

	local function walk(dir, depth)
		if depth > 12 then
			return
		end
		dir = dir:gsub("^/", ""):gsub("/$", "")
		local okList, entries = pcall(listFilesFn, dir)
		if not okList or type(entries) ~= "table" then
			return
		end
		for _, entry in ipairs(entries) do
			if type(entry) == "string" then
				local path = entry:gsub("^/", "")
				if not seen[path] then
					local isDir = false
					if isFolderFn then
						local okFolder, folder = pcall(isFolderFn, path)
						isDir = okFolder and folder == true
					end
					if isDir then
						walk(path, depth + 1)
					elseif path:match("%.luau$")
						or path:match("%.lua$")
						or path:lower():find("loader", 1, true)
						or path:lower():find("alleral", 1, true)
					then
						local okRead, body = pcall(readFileFn, path)
						if okRead and isLegacyLoaderSource(body) then
							tryDelete(path)
						end
					end
				end
			end
		end
	end

	for _, dir in ipairs(SCAN_DIRS) do
		walk(dir, 0)
	end

	return removed
end

local PLACE_VERSION_FILE = ".alleral/place_versions.json"

local function loadPlaceVersionMap(readFileFn, isFileFn)
	local map = type(ENV._Alleral_PlaceVersions) == "table" and ENV._Alleral_PlaceVersions or {}
	if not readFileFn or not isFileFn then
		return map
	end
	local okExists, exists = pcall(isFileFn, PLACE_VERSION_FILE)
	if not (okExists and exists) then
		return map
	end
	local okRead, raw = pcall(readFileFn, PLACE_VERSION_FILE)
	if not okRead or type(raw) ~= "string" then
		return map
	end
	for placeId, version in raw:gmatch('"(%d+)"%s*:%s*(%d+)') do
		map[placeId] = tonumber(version) or map[placeId]
	end
	return map
end

local function savePlaceVersionMap(writeFileFn, makeFolderFn, map)
	ENV._Alleral_PlaceVersions = map
	if not writeFileFn then
		return
	end
	if makeFolderFn then
		pcall(makeFolderFn, ".alleral")
	end
	local parts = {}
	for placeId, version in pairs(map) do
		table.insert(parts, ('"%s":%s'):format(tostring(placeId), tostring(version)))
	end
	table.sort(parts)
	pcall(writeFileFn, PLACE_VERSION_FILE, "{" .. table.concat(parts, ",") .. "}")
end

local function checkGamePlaceUpdate()
	local placeId = game.PlaceId
	local placeVersion = tonumber(game.PlaceVersion) or 0
	if placeId == 0 or placeVersion == 0 then
		return
	end
	local readFileFn = pick({ "readfile", "read_file", "ReadFile" })
	local writeFileFn = pick({ "writefile", "write_file", "WriteFile" })
	local isFileFn = pick({ "isfile", "is_file", "IsFile" })
	local makeFolderFn = pick({ "makefolder", "make_folder", "MakeFolder", "createfolder", "CreateFolder" })
	local key = tostring(placeId)
	local known = loadPlaceVersionMap(readFileFn, isFileFn)
	local previous = tonumber(known[key]) or 0
	if previous > 0 and previous ~= placeVersion then
		local msg = "This game was recently updated (build "
			.. tostring(previous)
			.. " -> "
			.. tostring(placeVersion)
			.. "). Alleral still loads — report issues if something breaks."
		warn("[Alleral Bootstrap] " .. msg)
		ENV._Alleral_GameRecentlyUpdated = true
		ENV._Alleral_GameUpdateMessage = msg
		ENV._Alleral_PlaceVersionChange = {
			placeId = placeId,
			previousPlaceVersion = previous,
			placeVersion = placeVersion,
			changed = true,
		}
	end
	known[key] = placeVersion
	savePlaceVersionMap(writeFileFn, makeFolderFn, known)
end

local function purgeKnownPaths(deleteFileFn, isFileFn)
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
		if okExists and exists and pcall(deleteFileFn, path) then
			removed += 1
		end
	end
	for _, path in ipairs(PURGE_PATHS) do
		tryDelete(path)
		for _, root in ipairs(PURGE_ROOTS) do
			tryDelete(root .. path)
		end
	end
	return removed
end

local function purgeAlleralWorkspace(fullScan)
	local deleteFileFn = pick({ "delfile", "deletefile", "delete_file", "DeleteFile", "removefile", "RemoveFile" })
	local isFileFn = pick({ "isfile", "is_file", "IsFile" })
	local listFilesFn = pick({ "listfiles", "list_files", "ListFiles" })
	local isFolderFn = pick({ "isfolder", "is_folder", "IsFolder" })
	local deleteFolderFn = pick({ "delfolder", "deletefolder", "delete_folder", "DeleteFolder" })
	local readFileFn = pick({ "readfile", "read_file", "ReadFile" })
	if not deleteFileFn or not isFileFn then
		return 0
	end

	local removed = purgeKnownPaths(deleteFileFn, isFileFn)
	if fullScan == false then
		return removed
	end

	local seen = {}
	local function tryDelete(path)
		if type(path) ~= "string" or path == "" or seen[path] then
			return
		end
		seen[path] = true
		local okExists, exists = pcall(isFileFn, path)
		if okExists and exists and pcall(deleteFileFn, path) then
			removed += 1
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

	for _, dir in ipairs({ ".alleral", "hub", "ui", "games", "Alleral", "core", "kick" }) do
		purgeTree(dir)
	end

	removed += purgeLegacyWorkspaceLoaders(deleteFileFn, isFileFn, readFileFn, listFilesFn, isFolderFn)

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
	ENV._Alleral_BootstrapReason = reason

	pcall(checkGamePlaceUpdate)

	-- Fast path purge only — full workspace scan runs after loader boots (avoids main-thread freeze).
	local purged = purgeAlleralWorkspace(false)
	if purged > 0 then
		print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Purged " .. tostring(purged) .. " cached workspace file(s)")
	end

	print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Fetching release metadata…")
	local meta, metaVia = fetchReleaseMeta()
	local expectedLoader = meta.loader
	local urls = buildLoaderUrls(meta)
	local src, via = nil, metaVia
	local lastReject = "no matching loader"
	for i, entry in ipairs(urls) do
		if i > 1 and typeof(task) == "table" and type(task.wait) == "function" then
			pcall(task.wait)
		end
		local body, transport = httpGet(entry.url, 500)
		if type(body) == "string" and #body >= 500 then
			local ok, detail = loaderMatchesRelease(body, meta, entry.strictCommit == true)
			if ok then
				src, via = body, transport
				break
			end
			lastReject = tostring(detail) .. " (" .. tostring(#body) .. "b via " .. tostring(transport) .. ")"
		end
	end
	if type(src) ~= "string" or #src < 500 then
		ENV._Alleral_BootstrapRunning = false
		return false, "remote loader failed (" .. tostring(via) .. "; " .. lastReject .. ")"
	end

	local remoteVer = loaderVersionFromSource(src) or "unknown"
	print(
		"[Alleral Bootstrap v"
			.. BOOTSTRAP_VERSION
			.. "] Loading loader v"
			.. remoteVer
			.. " @ "
			.. tostring(meta.commit or BRANCH)
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
		local extra = purgeAlleralWorkspace(true)
		if extra > 0 then
			print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Background purge removed " .. tostring(extra) .. " stale file(s)")
		end
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
