local Core = {}
Core.VERSION = "1.17"
Core.UI_LIBRARY = "Rayfield"

local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local RAYFIELD_SOURCE_URL = "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"
local RAYFIELD_LOCAL_FILES = {
	"vendor/rayfield/source.lua",
	"rayfield/source.lua",
}
local RAYFIELD_THEME_NAMES = {
	"Default",
	"Ocean",
	"AmberGlow",
	"Light",
	"Amethyst",
	"Green",
	"Bloom",
	"DarkBlue",
	"Serenity",
}
local ROSCRIPTS_SEARCH_URL = "https://rscripts.net/api/v2/scripts"
local ROSCRIPTS_SCRIPT_URL = "https://rscripts.net/api/v2/script"
local ROSCRIPTS_WEB_HOME = "https://roscripts.io/"
local ROSCRIPTS_WEB_SCRIPT = "https://rscripts.net/script/"

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()

function Core.notify(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title or "Alleral",
			Text = text or "",
			Duration = duration or 4,
		})
	end)
end

function Core.requestFunction()
	local sharedEnv = ENV.shared or (typeof(shared) == "table" and shared) or nil
	local solaraLib = sharedEnv and type(sharedEnv.solara) == "table" and sharedEnv.solara or nil
	local soloraLib = sharedEnv and type(sharedEnv.Solora) == "table" and sharedEnv.Solora or nil
	local candidates = {
		solaraLib and solaraLib.request,
		soloraLib and soloraLib.request,
		type(ENV.Solara) == "table" and ENV.Solara.request or nil,
		type(ENV.Solora) == "table" and ENV.Solora.request or nil,
		type(ENV.syn) == "table" and ENV.syn.request or nil,
		type(ENV.fluxus) == "table" and ENV.fluxus.request or nil,
		type(ENV.http) == "table" and ENV.http.request or nil,
		type(ENV.http_service) == "table" and ENV.http_service.request or nil,
		type(ENV.Xeno) == "table" and ENV.Xeno.request or nil,
		type(ENV.Volt) == "table" and ENV.Volt.request or nil,
		type(ENV.Madium) == "table" and ENV.Madium.request or nil,
		type(ENV.Nihon) == "table" and ENV.Nihon.request or nil,
		type(ENV.Cryptic) == "table" and ENV.Cryptic.request or nil,
		type(ENV.Sentinel) == "table" and ENV.Sentinel.request or nil,
		type(ENV.Serenity) == "table" and ENV.Serenity.request or nil,
		type(ENV.Atlantis) == "table" and ENV.Atlantis.request or nil,
		type(ENV.Zorara) == "table" and ENV.Zorara.request or nil,
		type(ENV.Wave) == "table" and ENV.Wave.request or nil,
		type(ENV.Electron) == "table" and ENV.Electron.request or nil,
		type(ENV.Potassium) == "table" and ENV.Potassium.request or nil,
		type(ENV.Velocity) == "table" and ENV.Velocity.request or nil,
		type(ENV.Krnl) == "table" and ENV.Krnl.request or nil,
		type(ENV.jjsploit) == "table" and ENV.jjsploit.request or nil,
		type(ENV.Bunni) == "table" and ENV.Bunni.request or nil,
		type(ENV.Valyse) == "table" and ENV.Valyse.request or nil,
		type(ENV.Krypton) == "table" and ENV.Krypton.request or nil,
		type(ENV.Evon) == "table" and ENV.Evon.request or nil,
		type(ENV.delta) == "table" and ENV.delta.request or nil,
		type(ENV.celery) == "table" and ENV.celery.request or nil,
		type(ENV.Codex) == "table" and ENV.Codex.request or nil,
		type(ENV.Hydrogen) == "table" and ENV.Hydrogen.request or nil,
		type(ENV.Ronix) == "table" and ENV.Ronix.request or nil,
		type(ENV.Macsploit) == "table" and ENV.Macsploit.request or nil,
		type(ENV.Oxygen) == "table" and ENV.Oxygen.request or nil,
		type(ENV.http) == "table" and ENV.http.request or nil,
		ENV.request,
		ENV.Request,
	}
	for _, name in ipairs({ "http_request", "request", "Request" }) do
		local fn = ENV[name]
		if type(fn) == "function" then
			table.insert(candidates, 1, fn)
		end
	end
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "function" then
			return candidate
		end
	end
	if type(HttpService.RequestAsync) == "function" then
		return function(opts)
			return HttpService:RequestAsync({
				Url = opts.Url,
				Method = opts.Method or "GET",
				Headers = opts.Headers,
				Body = opts.Body,
			})
		end
	end
	return nil
end

function Core.firstExecFunc(...)
	for index = 1, select("#", ...) do
		local name = select(index, ...)
		local fn = ENV[name] or (getfenv and getfenv()[name])
		if type(fn) == "function" then
			return fn
		end
	end
	return nil
end

function Core.execFunction(name, requireFilesystem)
	if requireFilesystem then
		local profile = Core.executorProfile()
		if not profile.fsOk and not profile.hasFilesystem then
			return nil
		end
	end
	local aliases = Core.EXEC_ALIASES and Core.EXEC_ALIASES[name]
	if aliases then
		for _, alias in ipairs(aliases) do
			local fn = ENV[alias]
			if type(fn) ~= "function" then
				fn = Core.firstExecFunc(alias)
			end
			if type(fn) == "function" then
				return fn
			end
		end
	end
	local fn = ENV[name]
	if type(fn) ~= "function" then
		fn = Core.firstExecFunc(name)
	end
	return type(fn) == "function" and fn or nil
end

Core.EXEC_ALIASES = {
	readfile = { "readfile", "read_file", "ReadFile" },
	writefile = { "writefile", "write_file", "WriteFile" },
	isfile = { "isfile", "is_file", "IsFile" },
	listfiles = { "listfiles", "list_files", "ListFiles" },
	makefolder = { "makefolder", "make_folder", "MakeFolder" },
	isfolder = { "isfolder", "is_folder", "IsFolder" },
	loadstring = { "loadstring", "LoadString" },
	setclipboard = { "setclipboard", "toclipboard", "setrbxclipboard" },
	getconnections = { "getconnections", "get_signal_cons" },
	firetouchinterest = { "firetouchinterest", "FireTouchInterest", "touchinterest" },
	identifyexecutor = { "identifyexecutor", "getexecutorname", "whatexecutor", "getexecutor" },
}

local function inferSlugFromText(text)
	local lower = tostring(text or ""):lower()
	local map = {
		{ "synapse z", "synapsez" },
		{ "synapse", "synapsez" },
		{ "potassium", "potassium" },
		{ "matcha", "matcha" },
		{ "photon", "photon" },
		{ "volt", "volt" },
		{ "awp", "volt" },
		{ "velocity", "velocity" },
		{ "solara", "solara" },
		{ "solora", "solara" },
		{ "xeno", "xeno" },
		{ "wave", "wave" },
		{ "delta", "delta" },
		{ "codex", "codex" },
		{ "cryptic", "cryptic" },
		{ "sirhurt", "sirhurt" },
		{ "seliware", "seliware" },
		{ "swift", "swift" },
		{ "volcano", "volcano" },
		{ "electron", "electron" },
		{ "ronin", "ronin" },
		{ "bunni", "bunni" },
		{ "serotonin", "serotonin" },
		{ "cosmic", "cosmic" },
		{ "opiumware", "opiumware" },
		{ "lumen", "lumen" },
		{ "severe", "severe" },
		{ "isaeva", "isaeva" },
		{ "nihon", "nihon" },
		{ "zenith", "zenith" },
		{ "macsploit", "macsploit" },
		{ "vega x", "vegax" },
		{ "vega", "vegax" },
		{ "madium", "madium" },
		{ "rbxcli", "rbxcli" },
		{ "krnl", "krnl" },
		{ "fluxus", "fluxus" },
		{ "jjsploit", "jjsploit" },
		{ "comet", "comet" },
		{ "trigon", "trigon" },
		{ "hydrogen", "hydrogen" },
		{ "arceus", "arceus" },
		{ "oxygen", "oxygenu" },
	}
	for _, pair in ipairs(map) do
		if lower:find(pair[1], 1, true) then
			return pair[2]
		end
	end
	return nil
end

function Core.detectExecutor()
	local rawName = ""
	for _, id in ipairs({
		"identifyexecutor",
		"getexecutorname",
		"whatexecutor",
		"getexecutor",
		"getexecutorinfo",
	}) do
		local fn = Core.firstExecFunc(id)
		if fn then
			local ok, result, version = pcall(fn)
			if ok and type(result) == "string" and result ~= "" then
				rawName = result
				if type(version) == "string" and version ~= "" then
					rawName = rawName .. " " .. version
				end
				break
			end
		end
	end

	local slug = inferSlugFromText(rawName) or rawName:lower():gsub("%s+", ""):match("^[%a][%w%-_%.]*") or ""
	local function hasTable(key)
		local value = ENV[key]
		return type(value) == "table" and value or nil
	end
	local sharedEnv = ENV.shared or (typeof(shared) == "table" and shared) or nil

	if slug == "" then
		if hasTable("syn") and type(ENV.syn.request) == "function" then
			slug = "synapse"
		elseif ENV.KRNL_LOADED == true then
			slug = "krnl"
		elseif hasTable("fluxus") and type(ENV.fluxus.request) == "function" then
			slug = "fluxus"
		elseif hasTable("sw") then
			slug = "scriptware"
		elseif hasTable("celery") then
			slug = "celery"
		elseif hasTable("delta") then
			slug = "delta"
		elseif ENV.OXYGEN_U == true then
			slug = "oxygenu"
		elseif hasTable("Electron") then
			slug = "electron"
		elseif hasTable("Wave") and type(ENV.Wave.setclipboard) == "function" then
			slug = "wave"
		elseif sharedEnv and type(sharedEnv.solara) == "table" then
			slug = "solara"
		elseif sharedEnv and type(sharedEnv.Solora) == "table" then
			slug = "solora"
		elseif hasTable("Solara") or hasTable("solara") then
			slug = "solara"
		elseif hasTable("Solora") or hasTable("solora") then
			slug = "solora"
		elseif hasTable("Xeno") then
			slug = "xeno"
		elseif hasTable("Volt") and type(ENV.Volt.request) == "function" then
			slug = "volt"
		elseif hasTable("Potassium") then
			slug = "potassium"
		elseif hasTable("Madium") then
			slug = "madium"
		elseif hasTable("Velocity") then
			slug = "velocity"
		elseif hasTable("Codex") then
			slug = "codex"
		elseif hasTable("Ronix") then
			slug = "ronix"
		elseif hasTable("Nihon") then
			slug = "nihon"
		elseif hasTable("Vega") or hasTable("VegaX") then
			slug = "vegax"
		elseif hasTable("Comet") then
			slug = "comet"
		elseif hasTable("Trigon") then
			slug = "trigon"
		elseif hasTable("Cryptic") then
			slug = "cryptic"
		elseif hasTable("Hydrogen") then
			slug = "hydrogen"
		elseif hasTable("Sentinel") then
			slug = "sentinel"
		elseif hasTable("Serenity") then
			slug = "serenity"
		elseif hasTable("Atlantis") then
			slug = "atlantis"
		elseif hasTable("Zorara") then
			slug = "zorara"
		elseif hasTable("Aztup") then
			slug = "aztup"
		elseif hasTable("Nixware") then
			slug = "nixware"
		elseif ENV.IS_JJSLOIT == true or hasTable("jjsploit") then
			slug = "jjsploit"
		elseif hasTable("Bunni") or hasTable("bunni") then
			slug = "bunni"
		elseif hasTable("Valyse") or hasTable("valyse") then
			slug = "valyse"
		elseif hasTable("Krypton") or hasTable("krypton") then
			slug = "krypton"
		elseif hasTable("SirHurt") or hasTable("sirhurt") then
			slug = "sirhurt"
		elseif hasTable("Temple") or hasTable("temple") then
			slug = "temple"
		elseif hasTable("Evon") or hasTable("evon") then
			slug = "evon"
		elseif hasTable("AWP") or hasTable("awp") then
			slug = "awp"
		elseif hasTable("Pebble") or hasTable("pebble") then
			slug = "pebble"
		elseif hasTable("Nzxt") or hasTable("nzxt") then
			slug = "nzxt"
		elseif hasTable("Nezur") or hasTable("nezur") then
			slug = "nezur"
		elseif hasTable("Seliware") or hasTable("seliware") then
			slug = "seliware"
		elseif hasTable("Luna") or hasTable("luna") then
			slug = "luna"
		elseif hasTable("Macsploit") or hasTable("macsploit") then
			slug = "macsploit"
		elseif hasTable("Potassium") or hasTable("potassium") then
			slug = "potassium"
		elseif hasTable("Cosmic") or hasTable("cosmic") then
			slug = "cosmic"
		elseif hasTable("Opiumware") or hasTable("opiumware") then
			slug = "opiumware"
		elseif hasTable("Volcano") or hasTable("volcano") then
			slug = "volcano"
		elseif hasTable("Swift") or hasTable("swift") then
			slug = "swift"
		elseif hasTable("Ronin") or hasTable("ronin") then
			slug = "ronin"
		elseif hasTable("Synapse") or ENV.SynapseZ == true then
			slug = "synapsez"
		elseif hasTable("Arceus") or ENV.ARCEUS_LOADED == true then
			slug = "arceus"
		elseif Core.firstExecFunc("queue_on_teleport") and Core.firstExecFunc("getgc") then
			slug = "synapse"
		else
			slug = "unknown"
		end
	end

	if slug == "solora" then
		slug = "solara"
	end

	local display = slug:sub(1, 1):upper() .. slug:sub(2)
	if slug == "synapsez" then
		display = "Synapse Z"
	elseif slug == "synapse" then
		display = "Synapse"
	elseif slug == "jjsploit" then
		display = "JJSploit"
	elseif slug == "solara" then
		display = "Solara"
	elseif slug == "vegax" then
		display = "Vega X"
	elseif slug == "macsploit" then
		display = "MacSploit"
	elseif slug == "oxygenu" then
		display = "Oxygen U"
	elseif slug == "bunni" then
		display = "Bunni"
	end

	return {
		slug = slug,
		name = display,
		rawName = rawName,
		isKnown = slug ~= "unknown",
	}
end

Core.WEAO_API_URLS = {
	"https://api.weao.xyz/api/status/exploits",
	"https://whatexpsare.online/api/status/exploits",
	"https://api.whatexpsare.online/api/status/exploits",
	"http://api.weao.xyz/api/status/exploits",
}

function Core.normalizeExecutorKey(text)
	local key = tostring(text or ""):lower()
	key = key:gsub("synapse%s*z", "synapsez")
	key = key:gsub("awp%.?gg?", "volt")
	key = key:gsub("bunni%.?fun", "bunni")
	key = key:gsub("vega%s*x", "vegax")
	key = key:gsub("[^a-z0-9]", "")
	return key
end

function Core.formatWeaoEntry(entry)
	if type(entry) ~= "table" then
		return nil
	end
	return {
		title = entry.title,
		version = entry.version,
		detected = entry.detected == true,
		updateStatus = entry.updateStatus ~= false,
		uncStatus = entry.uncStatus == true,
		platform = entry.platform,
		extype = entry.extype,
		free = entry.free == true,
		suncPercentage = tonumber(entry.suncPercentage),
		uncPercentage = tonumber(entry.uncPercentage),
		updatedDate = entry.updatedDate,
		websitelink = entry.websitelink,
	}
end

function Core.matchWeaoExploit(profile, exploits)
	if type(exploits) ~= "table" then
		return nil
	end
	local slugKey = Core.normalizeExecutorKey(profile and (profile.name or profile.slug))
	local rawKey = Core.normalizeExecutorKey(profile and profile.rawName)
	if slugKey == "" and rawKey == "" then
		return nil
	end
	local best
	local bestScore = 0
	for _, entry in ipairs(exploits) do
		if type(entry) == "table" and type(entry.title) == "string" then
			local titleKey = Core.normalizeExecutorKey(entry.title)
			local score = 0
			if titleKey ~= "" then
				if titleKey == slugKey or titleKey == rawKey then
					score = 100
				elseif slugKey ~= "" and (titleKey:find(slugKey, 1, true) or slugKey:find(titleKey, 1, true)) then
					score = 80
				elseif rawKey ~= "" and (titleKey:find(rawKey, 1, true) or rawKey:find(titleKey, 1, true)) then
					score = 70
				end
			end
			if score > bestScore then
				bestScore = score
				best = entry
			end
		end
	end
	return bestScore >= 70 and best or nil
end

function Core.fetchWeaoExploits(forceRefresh)
	local cache = ENV.Alleral_WeaoCache
	if not forceRefresh and type(cache) == "table" and cache.fetchedAt and (tick() - cache.fetchedAt) < 300 then
		return cache.data, cache.source
	end

	local function decodeBody(body)
		if type(body) ~= "string" or body == "" then
			return nil
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(body)
		end)
		if ok and type(decoded) == "table" then
			return decoded
		end
		return nil
	end

	local function fetchUrl(url)
		local headers = {
			["User-Agent"] = "WEAO-3PService",
			["Accept"] = "application/json",
			["Cache-Control"] = "no-cache",
		}
		local requestFn = Core.requestFunction()
		if requestFn then
			local ok, response = pcall(function()
				return requestFn({
					Url = url .. (url:find("?") and "&" or "?") .. "t=" .. tostring(math.random(10000, 99999)),
					Method = "GET",
					Headers = headers,
				})
			end)
			if ok then
				local body = type(response) == "table" and (response.Body or response.body) or (type(response) == "string" and response)
				local decoded = decodeBody(body)
				if decoded then
					return decoded, url
				end
			end
		end
		if type(game.HttpGet) == "function" then
			local ok, body = pcall(game.HttpGet, game, url, true)
			local decoded = decodeBody(ok and body or nil)
			if decoded then
				return decoded, url
			end
		end
		return nil
	end

	for _, url in ipairs(Core.WEAO_API_URLS) do
		local data, source = fetchUrl(url)
		if data then
			ENV.Alleral_WeaoCache = {
				fetchedAt = tick(),
				data = data,
				source = source,
			}
			return data, source
		end
	end

	if type(cache) == "table" and cache.data then
		return cache.data, cache.source
	end
	return nil, "WEAO exploit list unavailable"
end

function Core.fetchWeaoExecutorStatus(profile)
	profile = profile or Core.executorProfile()
	local exploits, err = Core.fetchWeaoExploits(false)
	local entry = Core.matchWeaoExploit(profile, exploits)
	if entry then
		return Core.formatWeaoEntry(entry)
	end
	return nil, err
end

function Core.weaoStatusLabel(weao)
	if type(weao) ~= "table" then
		return "Unknown (see whatexpsare.online)"
	end
	local parts = {}
	if weao.updateStatus then
		table.insert(parts, "Updated")
	else
		table.insert(parts, "Outdated")
	end
	if weao.detected then
		table.insert(parts, "Detected")
	else
		table.insert(parts, "Undetected")
	end
	if weao.suncPercentage then
		table.insert(parts, tostring(weao.suncPercentage) .. "% sUNC")
	end
	return table.concat(parts, " · ")
end

Core.EXECUTOR_FS_BROKEN = {
	yub = true,
	yubx = true,
	arceus = true,
	vegax = true,
	comet = true,
}

Core.EXECUTOR_COMPAT = {
	synapse = true,
	krnl = true,
	fluxus = true,
	scriptware = true,
	celery = true,
	delta = true,
	oxygenu = true,
	electron = true,
	wave = true,
	solara = true,
	solora = true,
	xeno = true,
	volt = true,
	potassium = true,
	madium = true,
	velocity = true,
	codex = true,
	ronix = true,
	nihon = true,
	trigon = true,
	cryptic = true,
	hydrogen = true,
	sentinel = true,
	serenity = true,
	atlantis = true,
	zorara = true,
	aztup = true,
	nixware = true,
	jjsploit = true,
	bunni = true,
	valyse = true,
	krypton = true,
	sirhurt = true,
	temple = true,
	evon = true,
	awp = true,
	pebble = true,
	nzxt = true,
	nezur = true,
	seliware = true,
	luna = true,
	macsploit = true,
	synapsez = true,
	potassium = true,
	matcha = true,
	photon = true,
	cosmic = true,
	opiumware = true,
	volcano = true,
	swift = true,
	ronin = true,
	serotonin = true,
	lumen = true,
	severe = true,
	isaeva = true,
	rbxcli = true,
	unknown = true,
}

function Core.executorProfile()
	local detected = Core.detectExecutor()
	local slug = detected.slug
	local fsOk = not Core.EXECUTOR_FS_BROKEN[slug]
	local sharedEnv = ENV.shared or (typeof(shared) == "table" and shared) or nil
	local solaraLib = sharedEnv and type(sharedEnv.solara) == "table" and sharedEnv.solara or nil
	local soloraLib = sharedEnv and type(sharedEnv.Solora) == "table" and sharedEnv.Solora or nil

	local hasHttp = Core.requestFunction() ~= nil
	local hasFilesystem = fsOk
		and type(ENV.writefile) == "function"
		and type(ENV.readfile) == "function"
	local hasGetConn = type(ENV.getconnections) == "function" or type(ENV.get_signal_cons) == "function"
	local hasClipboard = type(ENV.setclipboard) == "function"
		or type(ENV.toclipboard) == "function"
		or (type(ENV.Wave) == "table" and type(ENV.Wave.setclipboard) == "function")
		or (type(ENV.Electron) == "table" and type(ENV.Electron.setclipboard) == "function")
	local hasFireTouch = type(ENV.firetouchinterest) == "function"
		or type(ENV.FireTouchInterest) == "function"
		or type(ENV.touchinterest) == "function"

	return {
		name = slug,
		displayName = detected.name,
		rawName = detected.rawName,
		isKnown = detected.isKnown,
		fsOk = fsOk,
		hasFilesystem = hasFilesystem,
		hasHttp = hasHttp,
		hasGetConn = hasGetConn,
		hasClipboard = hasClipboard,
		hasFireTouch = hasFireTouch,
		hasLoadstring = type(ENV.loadstring or loadstring) == "function",
		env = ENV,
		solara = solaraLib ~= nil or soloraLib ~= nil or slug == "solara",
		weao = Core.formatWeaoEntry(Core.matchWeaoExploit(detected, ENV.Alleral_WeaoCache and ENV.Alleral_WeaoCache.data)),
	}
end

function Core.executorTelemetryProfile()
	local profile = Core.executorProfile()
	local apis = {}
	for _, pair in ipairs({
		{ "http_request", "http_request" },
		{ "request", "request" },
		{ "readfile", "readfile" },
		{ "writefile", "writefile" },
		{ "loadstring", "loadstring" },
		{ "getconnections", "getconnections" },
		{ "firetouchinterest", "firetouchinterest" },
		{ "identifyexecutor", "identifyexecutor" },
		{ "gethui", "gethui" },
	}) do
		if type(ENV[pair[2]]) == "function" then
			table.insert(apis, pair[1])
		end
	end
	if profile.solara then
		table.insert(apis, "solara")
	end
	table.sort(apis)
	local loaderCaps = ENV.Alleral_LoaderCapabilities or {}
	return {
		name = profile.displayName,
		version = profile.rawName,
		http = profile.hasHttp or loaderCaps.http == true,
		loadstring = loaderCaps.loadstring == true or type(ENV.loadstring) == "function",
		readfile = profile.hasFilesystem or loaderCaps.readfile == true,
		apis = apis,
		weao = profile.weao,
	}
end

function Core.refreshLoaderCapabilities()
	local profile = Core.executorProfile()
	local caps = {
		executor = profile.displayName,
		executorSlug = profile.name,
		http = profile.hasHttp,
		loadstring = type(ENV.loadstring or loadstring) == "function",
		readfile = profile.hasFilesystem,
		isfile = type(ENV.isfile) == "function",
		listfiles = type(ENV.listfiles) == "function",
		solara = profile.solara,
		hasClipboard = profile.hasClipboard,
		hasFireTouch = profile.hasFireTouch,
		hasGetConn = profile.hasGetConn,
	}
	ENV.Alleral_LoaderCapabilities = caps
	pcall(function()
		if shared then
			shared.Alleral_LoaderCapabilities = caps
		end
	end)
	return caps
end

function Core.notifyExecutorCompat(profile)
	profile = profile or Core.executorProfile()
	local caps = {}
	if profile.hasLoadstring ~= false then
		table.insert(caps, "Lua")
	end
	if profile.hasHttp then
		table.insert(caps, "HTTP")
	end
	if profile.hasFilesystem then
		table.insert(caps, "FS")
	end
	if profile.hasFireTouch then
		table.insert(caps, "Touch")
	end
	if profile.hasGetConn then
		table.insert(caps, "Signals")
	end
	if profile.hasClipboard then
		table.insert(caps, "Clipboard")
	end
	local capText = #caps > 0 and (" | " .. table.concat(caps, ", ")) or ""
	local display = profile.displayName
	local msg = display .. capText
	if profile.weao then
		msg = msg .. " — WEAO: " .. Core.weaoStatusLabel(profile.weao)
		if profile.weao.detected then
			msg = msg .. ". Consider a different executor if you get banned."
		elseif not profile.weao.updateStatus then
			msg = msg .. ". Update your executor for best results."
		end
	elseif not profile.isKnown then
		msg = msg .. " — universal mode (any executor with loadstring)."
	else
		msg = msg .. " — ready."
	end
	Core.notify("Executor", msg, 5)
end

local SCRIPT_STATUS_META = {
	working = { label = "Working", icon = "✅" },
	detected = { label = "Detected / unstable", icon = "⚠️" },
	broken = { label = "Broken", icon = "❌" },
	maintenance = { label = "Maintenance", icon = "🛠️" },
	testing = { label = "Testing", icon = "🧪" },
}

function Core.scriptStatusMeta(status)
	return SCRIPT_STATUS_META[tostring(status or ""):lower()] or { label = tostring(status or "Unknown"), icon = "❔" }
end

function Core.defaultScriptManifestUrls()
	local urls = {}
	if ENV.Alleral_ScriptManifestUrl and ENV.Alleral_ScriptManifestUrl ~= "" then
		table.insert(urls, ENV.Alleral_ScriptManifestUrl)
	end
	local ownerCfg = ENV.Alleral_OwnerTelemetry
	if type(ownerCfg) == "table" and type(ownerCfg.relayUrl) == "string" and ownerCfg.relayUrl ~= "" then
		local relay = ownerCfg.relayUrl:gsub("/+$", "")
		table.insert(urls, relay:gsub("/ingest$", "") .. "/scripts")
		if not relay:find("/scripts$") then
			table.insert(urls, relay .. "/scripts")
		end
	end
	table.insert(urls, "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/config/scripts_manifest.json")
	return urls
end

function Core.fetchScriptManifest(forceRefresh)
	local cache = ENV.Alleral_ScriptManifestCache
	if not forceRefresh and type(cache) == "table" and cache.fetchedAt and (tick() - cache.fetchedAt) < 60 then
		return cache.data, nil
	end

	local requestFn = Core.requestFunction()
	local readFileFn = ENV.readfile
	local isFileFn = ENV.isfile
	local lastErr = "Script manifest unavailable"

	for _, path in ipairs({
		"config/scripts_manifest.json",
		"kick/config/scripts_manifest.json",
	}) do
		if type(readFileFn) == "function" and type(isFileFn) == "function" and isFileFn(path) then
			local ok, raw = pcall(readFileFn, path)
			if ok and type(raw) == "string" and raw ~= "" then
				local decodedOk, decoded = pcall(function()
					return HttpService:JSONDecode(raw)
				end)
				if decodedOk and type(decoded) == "table" then
					ENV.Alleral_ScriptManifestCache = { fetchedAt = tick(), data = decoded, source = "local:" .. path }
					ENV.Alleral_ScriptManifest = decoded
					return decoded, nil
				end
			end
		end
	end

	if requestFn then
		for _, url in ipairs(Core.defaultScriptManifestUrls()) do
			local ok, response = pcall(function()
				return requestFn({
					Url = url .. (url:find("?") and "&" or "?") .. "t=" .. tostring(math.random(10000, 99999)),
					Method = "GET",
					Headers = { ["Cache-Control"] = "no-cache" },
				})
			end)
			if ok then
				local body = type(response) == "table" and (response.Body or response.body) or (type(response) == "string" and response)
				if type(body) == "string" and body ~= "" and not body:find("404") then
					local decodedOk, decoded = pcall(function()
						return HttpService:JSONDecode(body)
					end)
					if decodedOk and type(decoded) == "table" and type(decoded.scripts) == "table" then
						ENV.Alleral_ScriptManifestCache = { fetchedAt = tick(), data = decoded, source = url }
						ENV.Alleral_ScriptManifest = decoded
						return decoded, nil
					end
				end
			end
			lastErr = "Manifest fetch failed: " .. url
		end
	end

	if type(cache) == "table" and cache.data then
		return cache.data, lastErr
	end
	return nil, lastErr
end

function Core.getScriptStatus(scriptId, profileVersion)
	scriptId = tostring(scriptId or ENV.Alleral_ActiveScriptId or "")
	local manifest = ENV.Alleral_ScriptManifest
	if not manifest then
		manifest = Core.fetchScriptManifest()
	end
	local entry = manifest and manifest.scripts and manifest.scripts[scriptId]
	if type(entry) ~= "table" then
		return {
			id = scriptId,
			status = "working",
			label = "Working",
			icon = "✅",
			message = "No remote status entry — running local build.",
			version = profileVersion or "?",
		}
	end
	local meta = Core.scriptStatusMeta(entry.status)
	return {
		id = scriptId,
		status = tostring(entry.status or "working"):lower(),
		label = meta.label,
		icon = meta.icon,
		message = tostring(entry.message or ""),
		version = tostring(entry.version or profileVersion or "?"),
		name = tostring(entry.name or scriptId),
		updatedAt = entry.updatedAt,
		updatedBy = entry.updatedBy,
	}
end

function Core.evaluateScriptStatus(scriptId, profileVersion)
	local status = Core.getScriptStatus(scriptId, profileVersion)
	local blocked = status.status == "broken" or status.status == "maintenance"
	local warn = status.status == "detected" or status.status == "testing"
	local force = ENV.Alleral_ForceLoad == true
	return {
		status = status,
		allowed = not blocked or force,
		warn = warn and not blocked,
		force = force,
	}
end

function Core.buildScriptStatusGroupbox(tab, column, scriptId, profileVersion)
	scriptId = scriptId or ENV.Alleral_ActiveScriptId
	local evaluation = Core.evaluateScriptStatus(scriptId, profileVersion)
	local status = evaluation.status
	local groupbox = tab:CreateGroupbox({
		Name = "Script status",
		Column = column or 1,
		Icon = 6031075938,
	}, "ScriptStatus")

	local labels = {}
	local function addRow(key, value)
		labels[key] = groupbox:CreateLabel({
			Name = tostring(key) .. ": " .. tostring(value),
		}, "Status_" .. tostring(key))
	end

	addRow("Status", status.icon .. " " .. status.label)
	addRow("Script", status.name)
	addRow("Version", status.version)
	addRow("Executor", (Core.executorProfile().displayName))
	local weao = Core.fetchWeaoExecutorStatus()
	if weao then
		addRow("WEAO", Core.weaoStatusLabel(weao))
		if weao.version then
			addRow("Exec version", tostring(weao.version))
		end
	end
	if status.message ~= "" then
		addRow("Notice", status.message)
	end
	if evaluation.force then
		addRow("Force load", "Enabled")
	end

	groupbox:CreateButton({
		Name = "Refresh status",
		Callback = function()
			Core.fetchScriptManifest(true)
			Core.fetchWeaoExploits(true)
			local nextEval = Core.evaluateScriptStatus(scriptId, profileVersion)
			local nextStatus = nextEval.status
			if labels.Status and labels.Status.Set then
				labels.Status:Set({ Name = "Status: " .. nextStatus.icon .. " " .. nextStatus.label })
			end
			if labels.Notice and nextStatus.message ~= "" then
				labels.Notice:Set({ Name = "Notice: " .. nextStatus.message })
			elseif labels.Notice and labels.Notice.Instance then
				labels.Notice.Instance.Visible = nextStatus.message ~= ""
			end
			local refreshedWeao = Core.fetchWeaoExecutorStatus()
			if refreshedWeao and labels.WEAO and labels.WEAO.Set then
				labels.WEAO:Set({ Name = "WEAO: " .. Core.weaoStatusLabel(refreshedWeao) })
			end
			Core.notify("Alleral", "Status refreshed — " .. nextStatus.label, 3)
		end,
	}, "RefreshStatus")

	Core._scriptStatusUI = {
		groupbox = groupbox,
		labels = labels,
		scriptId = scriptId,
		profileVersion = profileVersion,
	}
	return groupbox, evaluation
end

local function trimText(value)
	return tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
end

function Core.normalizeWebhookUrl(url)
	local text = trimText(url)
	if text == "" then
		return nil, "Webhook URL is empty."
	end
	if not text:find("^https://") and not text:find("^http://") then
		text = "https://" .. text
	end
	if
		not text:find("discord%.com/api/webhooks/")
		and not text:find("discordapp%.com/api/webhooks/")
	then
		return nil, "That doesn't look like a Discord webhook URL."
	end
	return text, nil
end

function Core.postWebhook(url, payload)
	local sender = Core.requestFunction()
	if not sender then
		return false, "HTTP is not available in this executor."
	end
	local postUrl, urlError = Core.normalizeWebhookUrl(url)
	if not postUrl then
		return false, urlError
	end
	local ok, response = pcall(function()
		return sender({
			Url = postUrl,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload),
		})
	end)
	if not ok then
		return false, tostring(response)
	end
	if type(response) == "table" then
		if response.Success == false then
			local code = response.StatusCode or response.Status or response.status_code
			return false, "Webhook failed (HTTP " .. tostring(code or "?") .. ")"
		end
		local code = response.StatusCode or response.Status or response.status_code
		if type(code) == "number" and (code < 200 or code >= 300) then
			return false, "Webhook returned HTTP " .. tostring(code)
		end
	end
	return true, nil
end

function Core.loadStringFn()
	return ENV.loadstring or loadstring
end

function Core.readFile(path)
	local readFile = Core.execFunction("readfile")
	local isFile = Core.execFunction("isfile")
	if type(readFile) ~= "function" or type(isFile) ~= "function" or not isFile(path) then
		return nil
	end
	local ok, data = pcall(readFile, path)
	return ok and data or nil
end

function Core.writeFile(path, data)
	local writeFile = Core.execFunction("writefile")
	local makeFolder = ENV.makefolder
	if type(writeFile) ~= "function" then
		return false
	end
	pcall(function()
		if type(makeFolder) == "function" then
			makeFolder("Alleral_Configs")
		end
	end)
	return pcall(writeFile, path, data)
end

local function rayfieldOk(library)
	return type(library) == "table"
		and type(library.CreateWindow) == "function"
		and type(library.Notify) == "function"
end

local function stampRayfield(library)
	if type(library) ~= "table" then
		return library
	end
	library.InterfaceBuild = Core.UI_LIBRARY
	library.UI_LIBRARY = Core.UI_LIBRARY
	return library
end

local function compileRayfieldSource(source, label)
	local loadStringFn = Core.loadStringFn()
	if not loadStringFn or not source or source == "" then
		return nil, "Empty Rayfield source"
	end
	if not source:find("RayfieldLibrary") and not source:find("CreateWindow") then
		return nil, "Not a Rayfield source file"
	end
	local compiled, compileErr = loadStringFn(source, label)
	if not compiled then
		return nil, tostring(compileErr)
	end
	local ok, result = pcall(compiled)
	if ok and rayfieldOk(result) then
		return stampRayfield(result)
	end
	return nil, ok and "Invalid Rayfield library" or tostring(result)
end

local function fetchRayfieldSource(url)
	local sep = url:find("?") and "&" or "?"
	local fetchUrl = url .. sep .. "nocache=" .. tostring(math.random(10000, 99999))
	if type(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, fetchUrl, true)
		if ok and body and body ~= "" and not body:find("404: Not Found") then
			return body
		end
	end
	local httpGet = Core.requestFunction()
	if httpGet then
		local ok, response = pcall(httpGet, {
			Url = fetchUrl,
			Method = "GET",
			Headers = {
				["Cache-Control"] = "no-cache, no-store, must-revalidate",
				["Pragma"] = "no-cache",
			},
		})
		if ok and response then
			local body = response.Body or response.body or (type(response) == "string" and response)
			if body and body ~= "" and not body:find("404: Not Found") then
				return body
			end
		end
	end
	return nil
end

local function cacheRayfield(library)
	stampRayfield(library)
	ENV.Alleral_Rayfield = library
	ENV.Alleral_UI = library
	return library
end

function Core.loadRayfield()
	local cached = ENV.Alleral_Rayfield or ENV.Alleral_UI
	if rayfieldOk(cached) then
		return cacheRayfield(cached)
	end
	ENV.Alleral_Rayfield = nil
	ENV.Alleral_UI = nil

	local loadStringFn = Core.loadStringFn()
	if not loadStringFn then
		return nil, "loadstring unavailable"
	end

	local preferLocal = ENV.Alleral_DevMode == true or ENV.Alleral_PreferLocal == true

	local function loadLocalRayfield()
		for _, path in ipairs(RAYFIELD_LOCAL_FILES) do
			local source = Core.readFile(path)
			if source then
				local library, err = compileRayfieldSource(source, "@Rayfield/local")
				if library then
					return cacheRayfield(library)
				end
				warn("[Alleral] Local Rayfield failed (" .. path .. "): " .. tostring(err))
			end
		end
		return nil
	end

	if preferLocal then
		local localLibrary = loadLocalRayfield()
		if localLibrary then
			return localLibrary
		end
	end

	local source = fetchRayfieldSource(RAYFIELD_SOURCE_URL)
	if source then
		local library, err = compileRayfieldSource(source, "@Rayfield/remote")
		if library then
			warn("[Alleral] Rayfield loaded from Sirius GitHub")
			return cacheRayfield(library)
		end
		if not preferLocal then
			return nil, err or "Invalid Rayfield library"
		end
	else
		if not preferLocal then
			return nil, "Rayfield download failed — check HTTP / docs.sirius.menu/rayfield"
		end
	end

	local localLibrary = loadLocalRayfield()
	if localLibrary then
		return localLibrary
	end

	return nil, "No Rayfield source found"
end

function Core.httpGet(url)
	if type(game.HttpGet) == "function" then
		local ok, body = pcall(game.HttpGet, game, url, true)
		if ok and type(body) == "string" and body ~= "" and not body:find("404: Not Found") then
			return body
		end
	end
	local httpGet = Core.requestFunction()
	if httpGet then
		local ok, response = pcall(httpGet, {
			Url = url,
			Method = "GET",
			Headers = {
				["Cache-Control"] = "no-cache, no-store, must-revalidate",
			},
		})
		if ok and response then
			local body = response.Body or response.body or (type(response) == "string" and response)
			if body and body ~= "" and not body:find("404: Not Found") then
				return body
			end
		end
	end
	return nil
end

function Core.httpGetJson(url)
	local body = Core.httpGet(url)
	if not body then
		return nil, "HTTP unavailable"
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok or type(decoded) ~= "table" then
		return nil, "Invalid response from RoScripts"
	end
	return decoded
end

function Core.setClipboard(text)
	local clip = Core.execFunction("setclipboard") or Core.execFunction("toclipboard")
	if clip then
		pcall(clip, tostring(text or ""))
		return true
	end
	return false
end

function Core.searchRoScripts(query, options)
	options = options or {}
	query = trimText(query)
	if query == "" then
		return nil, "Enter a search term"
	end
	local params = {
		"page=" .. tostring(options.page or 1),
		"orderBy=" .. HttpService:UrlEncode(options.orderBy or "views"),
		"sort=desc",
		"q=" .. HttpService:UrlEncode(query),
	}
	if options.freeOnly ~= false then
		table.insert(params, "notPaid=true")
	end
	if options.noKey then
		table.insert(params, "noKeySystem=true")
	end
	if options.unpatched then
		table.insert(params, "unpatched=true")
	end
	local url = ROSCRIPTS_SEARCH_URL .. "?" .. table.concat(params, "&")
	local data, err = Core.httpGetJson(url)
	if not data then
		return nil, err
	end
	if type(data.scripts) ~= "table" then
		return nil, "RoScripts returned no results"
	end
	return {
		scripts = data.scripts,
		page = data.info and data.info.currentPage or 1,
		maxPages = data.info and data.info.maxPages or 1,
	}, nil
end

function Core.formatRoScriptLabel(entry)
	local title = tostring(entry.title or "Untitled")
	if #title > 46 then
		title = title:sub(1, 43) .. "..."
	end
	local gameTitle = entry.game and entry.game.title or "Universal"
	local author = entry.user and entry.user.username or "unknown"
	local suffix = entry.keySystem and " [Key]" or ""
	return title .. " — " .. gameTitle .. " (@" .. author .. ")" .. suffix
end

function Core.roScriptWebUrl(entry)
	if type(entry) ~= "table" then
		return ROSCRIPTS_WEB_HOME
	end
	if entry.slug and entry.slug ~= "" then
		return ROSCRIPTS_WEB_SCRIPT .. entry.slug
	end
	if entry._id then
		return ROSCRIPTS_WEB_SCRIPT .. tostring(entry._id)
	end
	return ROSCRIPTS_WEB_HOME
end

function Core.executeRoScript(entry, rayfield)
	if type(entry) ~= "table" or type(entry.rawScript) ~= "string" or entry.rawScript == "" then
		return false, "No script selected"
	end
	local notify = rayfield and rayfield.Notify
	if notify then
		pcall(notify, rayfield, {
			Title = "RoScripts",
			Content = "Loading: " .. tostring(entry.title or "script"),
			Duration = 4,
		})
	end
	local source = Core.httpGet(entry.rawScript)
	if not source or source == "" then
		return false, "Could not download script source"
	end
	local loadStringFn = Core.loadStringFn()
	if not loadStringFn then
		return false, "loadstring unavailable"
	end
	local compiled, compileErr = loadStringFn(source, "@RoScripts/" .. tostring(entry.slug or entry._id or "script"))
	if not compiled then
		return false, tostring(compileErr)
	end
	local ok, runErr = pcall(compiled)
	if not ok then
		return false, tostring(runErr)
	end
	return true
end

function Core.buildRoScriptsSearch(tab, column, rayfield)
	local group = Core.buildRayfieldGroup(tab, "RoScripts", column or 2)
	local browser = {
		query = "",
		freeOnly = true,
		noKey = false,
		entries = {},
		byLabel = {},
		selected = nil,
	}

	local status = group:CreateStatus("RoScripts", {
		Status = "Ready",
		Results = "0",
		Selected = "None",
	})

	group:CreateToggle("Free scripts only", true, nil, function(value)
		browser.freeOnly = value == true
	end)
	group:CreateToggle("No key system", false, nil, function(value)
		browser.noKey = value == true
	end)

	local queryInput = group:CreateInput("Search query", "auto farm, hub, ESP...", "", function(text)
		browser.query = tostring(text or "")
	end)

	local resultsDropdown

	local function applyResults(entries)
		browser.entries = entries or {}
		browser.byLabel = {}
		local labels = {}
		for index, entry in ipairs(browser.entries) do
			local label = Core.formatRoScriptLabel(entry)
			browser.byLabel[label] = entry
			labels[index] = label
		end
		if #labels == 0 then
			labels = { "No results" }
			browser.selected = nil
		else
			browser.selected = browser.entries[1]
		end
		if resultsDropdown then
			resultsDropdown:Refresh(labels, labels[1])
		end
		status:Update("Results", tostring(#browser.entries))
		status:Update("Selected", browser.selected and browser.selected.title or "None")
	end

	local function runSearch(query)
		query = trimText(query)
		if query == "" then
			status:Update("Status", "Enter a search term")
			return
		end
		status:Update("Status", "Searching...")
		task.spawn(function()
			local data, err = Core.searchRoScripts(query, {
				freeOnly = browser.freeOnly,
				noKey = browser.noKey,
			})
			if not data then
				status:Update("Status", tostring(err or "Search failed"))
				applyResults({})
				return
			end
			status:Update("Status", "Found " .. tostring(#data.scripts) .. " script(s)")
			applyResults(data.scripts)
		end)
	end

	resultsDropdown = group:AddDropdown("roscripts_results", {
		Text = "Results",
		Values = { "Search to populate" },
		Default = "Search to populate",
		Callback = function(selected)
			browser.selected = browser.byLabel[selected]
			status:Update("Selected", browser.selected and browser.selected.title or "None")
		end,
	})

	group:CreateButton("Search RoScripts", function()
		runSearch(browser.query)
	end, "Query RoScripts.io via rscripts.net API")

	group:CreateButton("Search this game", function()
		local gameName = ""
		pcall(function()
			gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
		end)
		if gameName == "" then
			gameName = tostring(game.PlaceId)
		end
		browser.query = gameName
		if queryInput and queryInput.Set then
			queryInput:Set({ CurrentValue = gameName })
		end
		runSearch(gameName)
	end, "Find scripts for the current place")

	group:CreateButton("Load selected script", function()
		local ok, err = Core.executeRoScript(browser.selected, rayfield)
		if ok then
			status:Update("Status", "Script loaded")
			Core.notify("RoScripts", "Script executed.", 3)
		else
			status:Update("Status", tostring(err or "Load failed"))
			Core.notify("RoScripts", tostring(err or "Load failed"), 5)
		end
	end, "Runs the selected script in your executor")

	group:CreateButton("Copy RoScripts link", function()
		local url = Core.roScriptWebUrl(browser.selected)
		if Core.setClipboard(url) then
			status:Update("Status", "Link copied")
			Core.notify("RoScripts", "Link copied to clipboard.", 3)
		else
			status:Update("Status", "Clipboard unavailable")
		end
	end)

	group:CreateButton("Open RoScripts.io", function()
		if Core.setClipboard(ROSCRIPTS_WEB_HOME) then
			Core.notify("RoScripts", "Open roscripts.io in your browser.", 4)
		end
	end)

	group:CreateLabel("Powered by RoScripts.io")
	return group
end

local function fakeUiInstance(visible)

function Core.createRayfieldGroupbox(tab, sectionName)
	if sectionName and sectionName ~= "" then
		tab:CreateSection(sectionName)
	end

	local shell = fakeUiInstance(true)
	local groupbox = {
		Instance = shell,
		ParentingItem = shell,
	}
	local serial = 0

	local function nextFlag(name, explicit)
		serial += 1
		return explicit or Core.uiElementId(name) .. "_" .. serial
	end

	local function wrapElement(elem, applySet)
		return {
			Instance = shell,
			Set = function(_, settings)
				if type(settings) == "table" then
					applySet(settings, elem)
				else
					applySet({ CurrentValue = settings }, elem)
				end
			end,
		}
	end

	function groupbox:CreateToggle(settings, id)
		local elem = tab:CreateToggle({
			Name = settings.Name,
			CurrentValue = settings.CurrentValue == true,
			Flag = nextFlag(settings.Name, id),
			Callback = settings.Callback or function() end,
		})
		return wrapElement(elem, function(nextSettings)
			if nextSettings.CurrentValue ~= nil then
				elem:Set(nextSettings.CurrentValue == true)
			end
		end)
	end

	function groupbox:CreateSlider(settings, id)
		local range = settings.Range or { 0, 100 }
		local elem = tab:CreateSlider({
			Name = settings.Name,
			Range = range,
			Increment = settings.Increment or (range[2] <= 5 and 0.05 or 1),
			Suffix = settings.Suffix,
			CurrentValue = tonumber(settings.CurrentValue) or range[1],
			Flag = nextFlag(settings.Name, id),
			Callback = settings.Callback or function() end,
		})
		return wrapElement(elem, function(nextSettings)
			if nextSettings.CurrentValue ~= nil then
				elem:Set(tonumber(nextSettings.CurrentValue) or range[1])
			end
		end)
	end

	function groupbox:CreateButton(settings, id)
		local elem = tab:CreateButton({
			Name = settings.Name,
			Callback = settings.Callback or function() end,
		})
		return wrapElement(elem, function(nextSettings)
			if nextSettings.Name then
				elem:Set(nextSettings.Name)
			end
		end)
	end

	function groupbox:CreateInput(settings, id)
		local elem = tab:CreateInput({
			Name = settings.Name,
			PlaceholderText = settings.PlaceholderText or settings.Placeholder or "",
			CurrentValue = settings.CurrentValue or "",
			RemoveTextAfterFocusLost = settings.RemoveTextOnFocus == true,
			Flag = nextFlag(settings.Name, id),
			Callback = settings.Callback or function() end,
		})
		return wrapElement(elem, function(nextSettings)
			if nextSettings.CurrentValue ~= nil then
				elem:Set(tostring(nextSettings.CurrentValue))
			end
		end)
	end

	function groupbox:CreateDropdown(settings, id)
		local current = settings.CurrentOption
		if type(current) ~= "table" then
			current = current and current ~= "" and { tostring(current) } or {}
		end
		local elem = tab:CreateDropdown({
			Name = settings.Name,
			Options = settings.Options or settings.Values or {},
			CurrentOption = current,
			MultipleOptions = settings.MultipleOptions == true,
			Flag = nextFlag(settings.Name, id),
			Callback = settings.Callback or function() end,
		})
		return wrapElement(elem, function(nextSettings)
			if nextSettings.CurrentOption or nextSettings.CurrentOptions then
				elem:Set(nextSettings.CurrentOption or nextSettings.CurrentOptions)
			end
		end)
	end

	function groupbox:CreateLabel(settings, id)
		local text = type(settings) == "table" and (settings.Name or settings.Text) or tostring(settings or "")
		local elem = tab:CreateLabel(text)
		return {
			Instance = shell,
			Set = function(_, nextSettings)
				local nextText = type(nextSettings) == "table" and (nextSettings.Name or nextSettings.Text)
					or tostring(nextSettings or "")
				elem:Set(nextText)
			end,
			AddDropdown = function(_, nestedSettings, nestedId)
				return groupbox:CreateDropdown({
					Name = nestedSettings.Name or text,
					Options = nestedSettings.Options or nestedSettings.Values or {},
					CurrentOption = nestedSettings.CurrentOption,
					MultipleOptions = nestedSettings.MultipleOptions,
					Callback = nestedSettings.Callback,
				}, nestedId)
			end,
		}
	end

	function groupbox:CreateDivider()
		tab:CreateDivider()
		return { Instance = shell }
	end

	return groupbox
end

function Core.wrapRayfieldTab(rawTab, rayfield, window)
	local tab = {
		_rawTab = rawTab,
		_rayfield = rayfield,
		_window = window,
	}

	function tab:CreateGroupbox(settings)
		return Core.createRayfieldGroupbox(rawTab, settings and settings.Name)
	end

	function tab:BuildThemeGroupbox(column)
		local group = Core.buildRayfieldGroup(tab, "Appearance", column or 1)
		group:CreateDropdown("Theme preset", RAYFIELD_THEME_NAMES, "Default", function(selected)
			if window and type(window.ModifyTheme) == "function" then
				window:ModifyTheme(selected)
			elseif rayfield and rayfield.Notify then
				rayfield:Notify({
					Title = "Theme",
					Content = "Applied " .. tostring(selected),
					Duration = 2,
				})
			end
		end)
		return group
	end

	return tab
end

function Core.ensureCore()
	if ENV.Alleral_Core then
		return ENV.Alleral_Core
	end
	local loadStringFn = Core.loadStringFn()
	local isFile = ENV.isfile
	local readFile = ENV.readfile
	if type(loadStringFn) ~= "function" or type(isFile) ~= "function" or type(readFile) ~= "function" then
		return nil
	end
	for _, path in ipairs({ "core/alleral_core.luau", "src/alleral_core.luau", "alleral_core.luau" }) do
		if isFile(path) then
			local ok = pcall(loadStringFn(readFile(path), "Alleral/core")())
			if ok and ENV.Alleral_Core then
				return ENV.Alleral_Core
			end
		end
	end
	return nil
end

local function signalBootFailure(message)
	ENV.Alleral_StartupFailed = message
	if ENV.Alleral_State then
		ENV.Alleral_State.StartupFailed = message
	end
	pcall(function()
		if shared then
			shared.Alleral_StartupFailed = message
		end
	end)
	local report = ENV.Alleral_ReportError
	if type(report) == "function" then
		pcall(report, "boot", message)
	end
end

function Core.prepareGame(state)
	state = state or ENV.Alleral_State
	if not state then
		local msg = "Alleral_State missing"
		signalBootFailure(msg)
		return nil, nil, msg
	end
	local core = Core.ensureCore()
	if not core then
		local msg = "Alleral_Core missing, run loader.luau first"
		signalBootFailure(msg)
		return nil, nil, msg
	end
	state.HubRunning = state.HubRunning ~= false
	core.initAnalytics()
	if state.AntiAFK ~= false then
		core.setupAntiAfk(game:GetService("Players").LocalPlayer)
	end
	local uiLibrary, err = core.loadRayfield()
	if not uiLibrary then
		local msg = err or "Rayfield unavailable"
		signalBootFailure(msg)
		return nil, nil, msg
	end
	pcall(function()
		if core.refreshLoaderCapabilities then
			core.refreshLoaderCapabilities()
		end
		if core.fetchScriptManifest then
			core.fetchScriptManifest(false)
		end
		if core.fetchWeaoExploits then
			task.spawn(function()
				core.fetchWeaoExploits(false)
				if core.refreshLoaderCapabilities then
					core.refreshLoaderCapabilities()
				end
			end)
		end
		if core.notifyExecutorCompat then
			core.notifyExecutorCompat()
		end
	end)
	return core, uiLibrary
end

function Core.stopAutomation(state, connections, loopControllers, loops, onStop)
	state.HubRunning = false
	for name, controller in pairs(loopControllers) do
		if controller then
			controller.enabled = false
		end
		loopControllers[name] = nil
	end
	for _, loopState in pairs(loops) do
		loopState.enabled = false
	end
	for key, connection in pairs(connections) do
		if connection and connection.Disconnect then
			pcall(function()
				connection:Disconnect()
			end)
		end
		connections[key] = nil
	end
	if onStop then
		pcall(onStop)
	end
end

function Core.saveSettings(state, keys, filename)
	local payload = {}
	for _, key in ipairs(keys) do
		payload[key] = state[key]
	end
	Core.writeFile("Alleral_Configs/" .. filename, HttpService:JSONEncode(payload))
end

function Core.loadSettings(state, keys, filename)
	local raw = Core.readFile("Alleral_Configs/" .. filename)
	if not raw then
		return
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		return
	end
	for _, key in ipairs(keys) do
		if decoded[key] ~= nil then
			state[key] = decoded[key]
		end
	end
end

function Core.wrapUiGroup(groupbox, callbackWrapper)
	local group = {}
	local serial = 0
	local MAX_RENDERED_DROPDOWN_OPTIONS = 50

	local function nextId(name)
		serial += 1
		return tostring(name) .. "_" .. HttpService:GenerateGUID(false):sub(1, 8) .. "_" .. serial
	end

	local function wrap(label, callback)
		callback = callback or function() end
		if not callbackWrapper then
			return callback
		end
		for _, args in ipairs({ { label, callback }, { callback } }) do
			local ok, wrapped = pcall(callbackWrapper, table.unpack(args))
			if ok and type(wrapped) == "function" then
				return wrapped
			end
		end
		return callback
	end

	local function normalizeOptions(values)
		local output = {}
		local seen = {}
		for _, value in ipairs(values or {}) do
			local text = tostring(value)
			if text ~= "" and not seen[text] then
				seen[text] = true
				table.insert(output, text)
			end
		end
		return output
	end

	local function currentSelection(default, multi)
		if type(default) == "table" then
			local copy = {}
			for i, v in ipairs(default) do
				copy[i] = v
			end
			for k, v in pairs(default) do
				if type(k) ~= "number" then
					copy[k] = v
				end
			end
			return copy
		end
		if multi then
			return default and { tostring(default) } or {}
		end
		return tostring(default or "")
	end

	local function compactOptions(values, selected, limit)
		values = normalizeOptions(values)
		limit = limit or MAX_RENDERED_DROPDOWN_OPTIONS
		if #values <= limit then
			return values
		end
		local output = {}
		local seen = {}
		local selectedList = type(selected) == "table" and selected or { selected }
		for _, value in ipairs(selectedList) do
			local text = tostring(value)
			if text ~= "" and not seen[text] then
				seen[text] = true
				table.insert(output, text)
			end
		end
		for _, value in ipairs(values) do
			if #output >= limit then
				break
			end
			if not seen[value] then
				table.insert(output, value)
			end
		end
		return output
	end

	local function waitForElement(element, timeout)
		local started = tick()
		repeat
			if element and element.Instance then
				return true
			end
			task.wait()
		until tick() - started >= (timeout or 3)
		return element and element.Instance ~= nil
	end

	local function setVisible(element, visible)
		waitForElement(element, 1)
		if element and element.Instance then
			element.Instance.Visible = visible
		end
	end

	function group:CreateToggle(name, default, tooltip, callback)
		return groupbox:CreateToggle({
			Name = name,
			CurrentValue = default == true,
			Tooltip = tooltip,
			Callback = wrap(name, callback),
		}, nextId(name))
	end

	function group:CreateSlider(name, min, max, default, callback, tooltip)
		return groupbox:CreateSlider({
			Name = name,
			Range = { min, max },
			Increment = max <= 5 and 0.05 or 1,
			CurrentValue = tonumber(default) or min,
			Tooltip = tooltip,
			Callback = wrap(name, callback),
		}, nextId(name))
	end

	function group:CreateButton(name, callback, tooltip)
		return groupbox:CreateButton({
			Name = name,
			Tooltip = tooltip,
			Callback = wrap(name, callback),
		}, nextId(name))
	end

	function group:CreateInput(name, placeholder, arg3, arg4, arg5)
		local icon, default, callback, tip
		local function isIcon(value)
			local text = tostring(value or "")
			return text:find("rbxassetid") ~= nil or text:match("^%d+$") ~= nil
		end
		if type(arg3) == "function" then
			callback = arg3
			tip = arg4
		elseif type(arg4) == "function" and isIcon(arg3) then
			icon = Core.uiIcon(arg3)
			callback = arg4
			tip = arg5
		elseif type(arg4) == "function" then
			default = tostring(arg3 or "")
			callback = arg4
			tip = arg5
		else
			icon = Core.uiIcon(arg3)
			callback = arg4
			tip = arg5
		end
		return groupbox:CreateInput({
			Name = name,
			Icon = icon,
			Placeholder = placeholder,
			PlaceholderText = placeholder,
			CurrentValue = default or "",
			RemoveTextOnFocus = false,
			Tooltip = tip,
			Callback = wrap(name, callback),
		}, nextId(name))
	end

	function group:CreateDropdown(name, options, default, callback, tooltip)
		return groupbox:CreateDropdown({
			Name = name,
			Options = normalizeOptions(options),
			CurrentOption = default,
			Tooltip = tooltip,
			Callback = wrap(name, callback),
		}, nextId(name))
	end

	function group:AddDropdown(id, config)
		config = config or {}
		local multi = config.Multi == true or config.MultiSelection == true
		local values = normalizeOptions(config.Values or config.Options)
		local current = currentSelection(config.Default or config.CurrentValue or config.CurrentOption, multi)
		local label = groupbox:CreateLabel({
			Name = config.Text or config.Name or id,
			Tooltip = config.Tooltip or config.Description,
		}, nextId(id))
		local handle = {
			Values = values,
			Selection = current,
			Dropdown = nil,
			Label = label,
			LastSearch = "",
		}
		local function safeCallback(selection)
			handle.Selection = currentSelection(selection, multi)
			wrap(config.Text or config.Name or id, config.Callback or function() end)(selection)
		end
		local function rebuild(currentValues)
			local nextValues = currentValues or handle.Values
			if config.Searchable then
				nextValues = compactOptions(nextValues, handle.Selection)
			end
			if handle.Dropdown and handle.Dropdown.Set then
				handle.Dropdown:Set({
					Options = nextValues,
					Values = nextValues,
					CurrentOption = handle.Selection,
					CurrentOptions = type(handle.Selection) == "table" and handle.Selection or nil,
					MultipleOptions = multi,
					Placeholder = config.Placeholder or "--",
					Callback = safeCallback,
				})
			end
		end
		if not waitForElement(label, 3) or not (label.Instance and label.Instance:FindFirstChild("DropdownHolder")) then
			local renderedValues = config.Searchable and compactOptions(values, current) or values
			local dropdown = groupbox:CreateDropdown({
				Name = config.Text or config.Name or id,
				Options = renderedValues,
				Values = renderedValues,
				CurrentOption = current,
				MultipleOptions = multi,
				Callback = safeCallback,
			}, nextId(id .. "_dd"))
			handle.Dropdown = dropdown
			function handle:SetValues(newValues, newDefault)
				self.Values = normalizeOptions(newValues)
				self.Selection = currentSelection(newDefault or self.Selection, multi)
				rebuild(self.Values)
			end
			function handle:Refresh(newValues, newDefault)
				self:SetValues(newValues, newDefault)
			end
			function handle:Search(query)
				self.LastSearch = tostring(query or "")
				local filtered = self.LastSearch == "" and self.Values
					or compactOptions(Core.filterDropdownOptions(self.Values, self.LastSearch), self.Selection)
				rebuild(filtered)
			end
			if config.Searchable then
				groupbox:CreateInput({
					Name = (config.Text or config.Name or id) .. " filter",
					PlaceholderText = "search...",
					RemoveTextOnFocus = false,
					Callback = wrap((config.Text or config.Name or id) .. " Search", function(text)
						handle:Search(text)
					end),
				}, nextId(id .. "_search"))
			end
			return handle
		end
		local renderedValues = config.Searchable and compactOptions(values, current) or values
		local dropdown = label:AddDropdown({
			Options = renderedValues,
			Values = renderedValues,
			CurrentOption = current,
			CurrentOptions = multi and current or nil,
			MultipleOptions = multi,
			Placeholder = config.Placeholder or "--",
			Callback = safeCallback,
		}, nextId(id .. "_dd"))
		handle.Dropdown = dropdown
		function handle:SetValues(newValues, newDefault)
			self.Values = normalizeOptions(newValues)
			self.Selection = currentSelection(newDefault or self.Selection, multi)
			rebuild(self.Values)
		end
		function handle:Refresh(newValues, newDefault)
			self:SetValues(newValues, newDefault)
		end
		function handle:Search(query)
			self.LastSearch = tostring(query or "")
			local filtered = self.LastSearch == "" and self.Values
				or compactOptions(Core.filterDropdownOptions(self.Values, self.LastSearch), self.Selection)
			rebuild(filtered)
		end
		if config.Searchable then
			groupbox:CreateInput({
				Name = (config.Text or config.Name or id) .. " filter",
				PlaceholderText = "search...",
				RemoveTextOnFocus = false,
				Callback = wrap((config.Text or config.Name or id) .. " Search", function(text)
					handle:Search(text)
				end),
			}, nextId(id .. "_search"))
		end
		return handle
	end

	function group:CreateLabel(text)
		return groupbox:CreateLabel({
			Name = text,
		}, nextId("label"))
	end

	function group:CreateStatus(label, fields)
		local status = {
			Labels = {},
			LastValues = {},
			Visible = true,
		}
		for key, value in pairs(fields or {}) do
			local rendered = tostring(value)
			status.LastValues[key] = rendered
			status.Labels[key] = groupbox:CreateLabel({
				Name = tostring(key) .. ": " .. rendered,
			}, nextId(label .. "_" .. tostring(key)))
		end
		function status:Update(key, value)
			local rendered = tostring(value)
			if self.LastValues[key] == rendered then
				return
			end
			self.LastValues[key] = rendered
			local row = self.Labels[key]
			if row and row.Set then
				row:Set({ Name = tostring(key) .. ": " .. rendered })
			end
		end
		function status:SetVisible(visible)
			self.Visible = visible
			for _, row in pairs(self.Labels) do
				setVisible(row, visible)
			end
		end
		return status
	end

	function group:CreateDivider()
		return groupbox:CreateDivider()
	end

	return group
end

function Core.uiIcon(icon)
	return tostring(icon or ""):match("%d+$") or ""
end

function Core.uiElementId(text)
	return (tostring(text or "Element"):gsub("[^%w_]", "_"))
end

function Core.buildRayfieldWindow(rayfield, settings)
	settings = settings or {}
	local fileSettings = settings.FileSettings or {}
	local window = rayfield:CreateWindow({
		Name = settings.Name or "Alleral",
		LoadingTitle = settings.Name or "Alleral",
		LoadingSubtitle = settings.Subtitle or "",
		Icon = tonumber(Core.uiIcon(settings.Icon or 10723407389)) or 10723407389,
		ConfigurationSaving = {
			Enabled = fileSettings.Enabled ~= false,
			FolderName = fileSettings.RootFolder or fileSettings.ConfigFolder or "Alleral_Configs",
			FileName = fileSettings.FileName or tostring(game.PlaceId),
		},
		DisableRayfieldPrompts = true,
		DisableBuildWarnings = true,
		KeySystem = false,
	})
	window._rayfield = rayfield
	return window
end

function Core.buildRayfieldSection(window, name, expanded)
	return {
		_window = window,
		_rayfield = window._rayfield,
	}
end

function Core.buildRayfieldTab(section, name, icon, columns, id)
	local window = section._window or section
	local rawTab = window:CreateTab(name, tonumber(Core.uiIcon(icon or 10723407389)) or 10723407389)
	return Core.wrapRayfieldTab(rawTab, window._rayfield or section._rayfield, window)
end

function Core.onUiSave(saveFn)
	return function(_, callback)
		return function(...)
			local result = callback(...)
			if type(saveFn) == "function" then
				saveFn()
			end
			return result
		end
	end
end

function Core.buildRayfieldGroup(tab, name, column, callbackWrapper, icon, id)
	local groupbox = tab:CreateGroupbox({
		Name = name,
		Column = column or 1,
		Icon = icon and Core.uiIcon(icon) or nil,
	}, id or Core.uiElementId(name))
	if callbackWrapper then
		return Core.wrapUiGroup(groupbox, callbackWrapper)
	end
	return Core.wrapUiGroup(groupbox)
end

function Core.filterDropdownOptions(values, query)
	query = tostring(query or ""):lower()
	if query == "" then
		return values
	end
	local filtered = {}
	for _, value in ipairs(values or {}) do
		if tostring(value):lower():find(query, 1, true) then
			table.insert(filtered, value)
		end
	end
	return filtered
end

function Core.makeSupervisor(state, loops, controllers, name, interval, callback)
	if controllers[name] then
		controllers[name].enabled = false
		controllers[name] = nil
	end
	local loopState = {
		enabled = true,
		token = HttpService:GenerateGUID(false),
	}
	loops[name] = loopState
	controllers[name] = loopState
	task.spawn(function()
		local token = loopState.token
		while state.HubRunning and loopState.enabled and controllers[name] == loopState and loopState.token == token do
			local ok, err = pcall(callback)
			if not ok then
				Core.reportError("Loop:" .. name, err)
				warn("[Alleral:" .. name .. "] " .. tostring(err))
				task.wait(math.min(5, interval * 2))
			else
				task.wait(interval)
			end
		end
	end)
end

function Core.setupAntiAfk(player)
	local getConnections = ENV.getconnections or ENV.get_signal_cons
	if getConnections then
		for _, connection in ipairs(getConnections(player.Idled)) do
			if connection.Disable then
				connection:Disable()
			elseif connection.Disconnect then
				connection:Disconnect()
			end
		end
	else
		local VirtualUser = game:GetService("VirtualUser")
		player.Idled:Connect(function()
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new(0, 0))
			end)
		end)
	end
	task.spawn(function()
		local VirtualUser = game:GetService("VirtualUser")
		while player.Parent do
			task.wait(120)
			pcall(function()
				local camera = workspace.CurrentCamera
				if not camera then
					return
				end
				VirtualUser:Button2Down(Vector2.new(100, 100), camera.CFrame)
				task.wait(0.2)
				VirtualUser:Button2Up(Vector2.new(100, 100), camera.CFrame)
			end)
		end
	end)
end

function Core.initAnalytics()
	local tracker = ENV.Alleral_Analytics
	if tracker and tracker.Track then
		tracker:Track()
	end
	return tracker
end

function Core.reportError(scope, err, details)
	local reporter = ENV.Alleral_ReportError
	if type(reporter) == "function" then
		pcall(reporter, scope, err, details)
	end
end

function Core.logEvent(category, message, data)
	local logger = ENV.Alleral_LogEvent
	if type(logger) == "function" then
		pcall(logger, category, message, data)
	end
end

ENV.Alleral_Core = Core
return Core
