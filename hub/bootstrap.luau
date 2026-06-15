-- Alleral Bootstrap v1.0.12
-- Save this loadstring once in your executor — it always fetches the latest loader from GitHub.
-- One-liner: loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/bootstrap.luau?v=1.0.12&t=" .. tick(), true))()

local BOOTSTRAP_VERSION = "1.0.12"
print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Starting…")
local HTTP_GET_TIMEOUT = 12
local LOADER_FETCH_TIMEOUT = 28
local LOADER_MIN_BYTES = 50000
local FALLBACK_RELEASE = {
	loader = "8.7.1",
	maclibVersion = 3,
}
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

local function pickRequestFn()
	local fn = pick({ "request", "http_request", "httprequest", "syn_request", "http_request_async" })
	if fn then
		return fn
	end
	if type(syn) == "table" and type(syn.request) == "function" then
		return syn.request
	end
	if type(http) == "table" and type(http.request) == "function" then
		return http.request
	end
	if type(ENV.Xeno) == "table" and type(ENV.Xeno.request) == "function" then
		return ENV.Xeno.request
	end
	return nil
end

local function httpRequestOnce(url, minBytes)
	minBytes = minBytes or 0
	local requestFn = pickRequestFn()
	if not requestFn then
		return nil, "request API missing"
	end
	local ok, body = pcall(function()
		local res = requestFn({
			Url = url,
			Method = "GET",
			Headers = {
				["User-Agent"] = "Alleral-Bootstrap/" .. BOOTSTRAP_VERSION,
				["Cache-Control"] = "no-cache, no-store",
			},
		})
		if type(res) == "table" and type(res.Body) == "string" and #res.Body >= minBytes then
			return res.Body
		end
		if type(res) == "table" and type(res.body) == "string" and #res.body >= minBytes then
			return res.body
		end
		return nil
	end)
	if ok and type(body) == "string" then
		return body, "request"
	end
	return nil, "request failed"
end

local function httpGetOnce(url, minBytes)
	minBytes = minBytes or 0
	local body, via = httpRequestOnce(url, minBytes)
	if body then
		return body, via
	end
	if type(game.HttpGet) == "function" then
		local ok, fetched = pcall(game.HttpGet, game, url, true)
		if ok and type(fetched) == "string" and #fetched >= minBytes then
			return fetched, "httpget"
		end
		ok, fetched = pcall(game.HttpGet, game, url)
		if ok and type(fetched) == "string" and #fetched >= minBytes then
			return fetched, "httpget"
		end
	end
	local ok, fetched = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and type(fetched) == "string" and #fetched >= minBytes then
		return fetched, "httpget"
	end
	ok, fetched = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(fetched) == "string" and #fetched >= minBytes then
		return fetched, "httpget"
	end
	return nil, "transport failed"
end

local function httpFetchLoader(url, minBytes, label)
	minBytes = minBytes or LOADER_MIN_BYTES
	label = label or "loader"
	local plain = url:gsub("%?.*$", "")
	local candidates = {
		plain .. "?t=" .. tostring(tick()) .. "&r=" .. tostring(math.random(1, 2147483646)),
		plain,
		url,
	}
	for i, candidate in ipairs(candidates) do
		if i > 1 and typeof(task) == "table" and type(task.wait) == "function" then
			pcall(task.wait, 0.02)
		end
		print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Downloading " .. label .. " via request…")
		local body, via = httpRequestOnce(candidate, minBytes)
		if type(body) == "string" then
			return body, via
		end
		warn("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] request failed for " .. label .. " — trying HttpGet fallback")
		body, via = httpGetOnce(candidate, minBytes)
		if type(body) == "string" then
			return body, via
		end
	end
	return nil, "request API could not download loader (enable HTTP in executor)"
end

local function httpGet(url, minBytes)
	minBytes = minBytes or 0
	local plain = url:gsub("%?.*$", "")
	local candidates = { plain .. "?t=" .. tostring(tick()), plain, url }
	for i, candidate in ipairs(candidates) do
		if i > 1 and typeof(task) == "table" and type(task.wait) == "function" then
			pcall(task.wait, 0.05)
		end
		local body, via = httpGetOnce(candidate, minBytes)
		if type(body) == "string" then
			return body, via
		end
	end
	return nil, "all transports failed"
end

local function httpGetWithTimeout(url, minBytes, timeoutSec, label)
	timeoutSec = timeoutSec or HTTP_GET_TIMEOUT
	minBytes = minBytes or 0
	label = label or url:gsub("%?.*$", "")
	local body, via, finished = nil, nil, false
	local worker = task.spawn(function()
		body, via = httpGet(url, minBytes)
		finished = true
	end)
	local deadline = tick() + timeoutSec
	local lastPulse = tick()
	while not finished and tick() < deadline do
		if tick() - lastPulse >= 2.5 then
			print(
				"[Alleral Bootstrap v"
					.. BOOTSTRAP_VERSION
					.. "] Still fetching "
					.. label
					.. " ("
					.. tostring(math.floor(deadline - tick()))
					.. "s left)…"
			)
			lastPulse = tick()
		end
		task.wait(0.05)
	end
	if finished then
		return body, via
	end
	pcall(function()
		task.cancel(worker)
	end)
	warn("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Timed out fetching " .. label)
	return nil, "timeout after " .. tostring(timeoutSec) .. "s"
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
		maclibVersion = tonumber(src:match('"maclibVersion"%s*:%s*(%d+)')),
	}
end

local function loaderCommitFromSource(src)
	if type(src) ~= "string" then
		return nil
	end
	return src:match('commit = "([^"]+)"')
end

local function loaderMaclibVersionFromSource(src)
	if type(src) ~= "string" then
		return nil
	end
	return tonumber(src:match("local MACLIB_VERSION = (%d+)"))
end

local function loaderVersionParts(ver)
	local parts = {}
	for n in tostring(ver or ""):gmatch("%d+") do
		table.insert(parts, tonumber(n) or 0)
	end
	return parts
end

local function loaderVersionCompatible(remoteVer, expectedVer)
	if remoteVer == expectedVer then
		return true
	end
	local remote = loaderVersionParts(remoteVer)
	local expected = loaderVersionParts(expectedVer)
	if remote[1] ~= expected[1] or remote[2] ~= expected[2] then
		return false
	end
	return (remote[3] or 0) >= (expected[3] or 0)
end

local function loaderMatchesRelease(src, meta)
	if type(src) ~= "string" or type(meta) ~= "table" then
		return false, "invalid loader body"
	end
	if not src:find("LOADER_VERSION", 1, true) or not src:find("Alleral", 1, true) then
		return false, "not an Alleral loader"
	end
	if #src < LOADER_MIN_BYTES then
		return false, "too small (" .. tostring(#src) .. "b, need " .. tostring(LOADER_MIN_BYTES) .. "+)"
	end
	local remoteVer = loaderVersionFromSource(src)
	if type(meta.loader) == "string" and meta.loader ~= "" then
		if not loaderVersionCompatible(remoteVer, meta.loader) then
			return false, "loader v" .. tostring(remoteVer or "?") .. " != release v" .. meta.loader
		end
	end
	return true, remoteVer
end

local function releaseMetaUrls()
	local bust = "?t=" .. tostring(tick())
	return {
		GITHUB_RAW .. "/cfg/release.json" .. bust,
		JSDELIVR .. "@" .. BRANCH .. "/cfg/release.json" .. bust,
		"https://cdn.jsdelivr.net/gh/" .. REPO .. "@" .. BRANCH .. "/cfg/release.json" .. bust,
	}
end

local function fetchReleaseMeta()
	local builtin = {
		loader = FALLBACK_RELEASE.loader,
		commit = BRANCH,
		maclibVersion = FALLBACK_RELEASE.maclibVersion,
	}
	task.spawn(function()
		for _, url in ipairs(releaseMetaUrls()) do
			local src = select(1, httpGetWithTimeout(url, 40, 6, "release.json"))
			local meta = parseReleaseJson(src)
			if meta and meta.loader then
				ENV._Alleral_ReleaseMeta = meta
				break
			end
		end
	end)
	print(
		"[Alleral Bootstrap v"
			.. BOOTSTRAP_VERSION
			.. "] Using loader v"
			.. builtin.loader
			.. " (skipping slow CDN release.json)"
	)
	return builtin, "builtin"
end

local function buildLoaderUrls(meta)
	local commit = (meta and meta.commit) or BRANCH
	local bust = "?t=" .. tostring(tick())
	-- GitHub raw first — jsDelivr often lags main by hours.
	return {
		{ url = GITHUB_RAW .. "/loader.luau" .. bust, label = "github@main/loader.luau" },
		{ url = JSDELIVR .. "@main/loader.luau" .. bust, label = "jsdelivr@main/loader.luau" },
		{ url = JSDELIVR .. "@" .. commit .. "/loader.luau" .. bust, label = "jsdelivr@" .. commit .. "/loader.luau" },
		{
			url = "https://raw.githubusercontent.com/" .. REPO .. "/" .. commit .. "/loader.luau" .. bust,
			label = "github@" .. commit .. "/loader.luau",
		},
	}
end

local PURGE_ROOTS = { "", "kick/", "workspace/", "scripts/", "autoexec/", "Autoexec/" }
local SCAN_DIRS = { "", "autoexec", "Autoexec", "autoexecute", "AutoExecute", "workspace", "scripts", "kick" }
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
	"ui/maclib/source.luau",
	"ui/rayfield/source.luau",
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
		if dir == "" then
			return
		end
		if isFolderFn then
			local okFolder, exists = pcall(isFolderFn, dir)
			if not okFolder or exists ~= true then
				return
			end
		else
			return
		end
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
		if isFolderFn then
			local okFolder, exists = pcall(isFolderFn, dir)
			if not okFolder or exists ~= true then
				return
			end
		else
			return
		end
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

local function hashAttest(placeId, jobId, at, commit)
	local text = "AlleralBootstrapGate-v5"
		.. "|"
		.. tostring(placeId)
		.. "|"
		.. tostring(jobId)
		.. "|"
		.. tostring(at)
		.. "|"
		.. tostring(commit or "")
	local h1, h2 = 5381, 0
	for i = 1, #text do
		local byte = string.byte(text, i)
		h1 = (h1 * 33 + byte) % 2147483647
		h2 = (h2 * 31 + byte * (i % 7 + 1)) % 2147483647
	end
	return string.format("ab_%x_%x", h1, h2)
end

local function runLoaderSource(src, label, meta)
	local fn, err = loadStringFn(src, label or "Alleral/loader")
	if not fn then
		return false, "compile: " .. tostring(err)
	end
	if setfenv then
		pcall(setfenv, fn, ENV)
	end
	local at = tick()
	ENV._Alleral_BootstrapVersion = BOOTSTRAP_VERSION
	ENV._Alleral_Bootstrapped = true
	ENV._Alleral_BootstrapAt = at
	ENV._Alleral_BootstrapCommit = meta and meta.commit or nil
	ENV._Alleral_BootstrapToken = hashAttest(game.PlaceId, game.JobId, at, meta and meta.commit)
	ENV._Alleral_BootstrapTokenAt = at
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

	print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Preparing loader download…")
	local meta, metaVia = fetchReleaseMeta()
	local expectedLoader = meta.loader
	local urls = buildLoaderUrls(meta)
	local src, via = nil, metaVia
	local lastReject = "no matching loader"
	for i, entry in ipairs(urls) do
		if i > 1 and typeof(task) == "table" and type(task.wait) == "function" then
			pcall(task.wait, 0.05)
		end
		local label = entry.label or entry.url:gsub("%?.*$", "")
		print("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Loader fetch: " .. label)
		local body, transport = httpFetchLoader(entry.url, LOADER_MIN_BYTES, label)
		if type(body) == "string" and #body >= LOADER_MIN_BYTES then
			local ok, detail = loaderMatchesRelease(body, meta)
			if ok then
				src, via = body, transport
				break
			end
			lastReject = tostring(detail) .. " (" .. tostring(#body) .. "b via " .. tostring(transport) .. ")"
			warn("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Loader rejected: " .. lastReject)
		else
			lastReject = tostring(transport or "empty response")
			warn("[Alleral Bootstrap v" .. BOOTSTRAP_VERSION .. "] Loader fetch failed: " .. label .. " — " .. lastReject)
		end
	end
	if type(src) ~= "string" or #src < LOADER_MIN_BYTES then
		ENV._Alleral_BootstrapRunning = false
		warn(
			"[Alleral Bootstrap v"
				.. BOOTSTRAP_VERSION
				.. "] Could not load remote loader (expected v"
				.. tostring(expectedLoader or FALLBACK_RELEASE.loader)
				.. "). Last error: "
				.. lastReject
		)
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

	local ok, err = runLoaderSource(src, "Alleral/loader@" .. remoteVer, meta)
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
