--[[
	WEAO client — https://docs.weao.xyz
	Requires User-Agent: WEAO-3PService on every request.
	Proxy: https://github.com/goodcurry/weao-proxy-api
]]

local Weao = {}
Weao.VERSION = "1.1"
Weao.DOCS_URL = "https://docs.weao.xyz"
Weao.USER_AGENT = "WEAO-3PService"

local HttpService = game:GetService("HttpService")

local DEFAULT_CONFIG = {
	version = 1,
	userAgent = Weao.USER_AGENT,
	cacheSeconds = 300,
	paths = {
		allExploits = "/api/status/exploits",
		singleExploit = "/api/status/exploits/",
	},
	bases = {
		"https://weao.xyz",
		"https://whatexpsare.online",
		"https://whatexploitsaretra.sh",
		"https://weao.gg",
	},
}

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()

function Weao.requestHeaders()
	return {
		["User-Agent"] = Weao.USER_AGENT,
		["Accept"] = "application/json",
		["Cache-Control"] = "no-cache, no-store, must-revalidate",
		["Pragma"] = "no-cache",
	}
end

function Weao.mergeConfig(remote)
	local cfg = {}
	for key, value in pairs(DEFAULT_CONFIG) do
		cfg[key] = value
	end
	if type(remote) == "table" then
		for key, value in pairs(remote) do
			if key == "bases" and type(value) == "table" and #value > 0 then
				cfg.bases = value
			elseif key == "paths" and type(value) == "table" then
				cfg.paths = cfg.paths or {}
				for pathKey, pathValue in pairs(value) do
					cfg.paths[pathKey] = pathValue
				end
			elseif value ~= nil then
				cfg[key] = value
			end
		end
	end
	if ENV.Alleral_WeaoConfig and type(ENV.Alleral_WeaoConfig) == "table" then
		for key, value in pairs(ENV.Alleral_WeaoConfig) do
			if key == "bases" and type(value) == "table" and #value > 0 then
				cfg.bases = value
			elseif value ~= nil then
				cfg[key] = value
			end
		end
	end
	cfg.userAgent = cfg.userAgent or Weao.USER_AGENT
	cfg.cacheSeconds = tonumber(cfg.cacheSeconds) or 300
	cfg.paths = cfg.paths or DEFAULT_CONFIG.paths
	cfg.bases = cfg.bases or DEFAULT_CONFIG.bases
	return cfg
end

function Weao.isRateLimitPayload(data)
	return type(data) == "table" and data.error ~= nil and data.rateLimitInfo ~= nil
end

function Weao.normalizeExploitList(data)
	if type(data) ~= "table" then
		return nil
	end
	if Weao.isRateLimitPayload(data) then
		return nil
	end
	if type(data.title) == "string" or type(data.name) == "string" then
		data.title = data.title or data.name or data.Name
		return { data }
	end
	if type(data.exploits) == "table" then
		data = data.exploits
	end
	if type(data.data) == "table" then
		data = data.data
	end
	local list = {}
	local function push(entry)
		if type(entry) ~= "table" then
			return
		end
		entry.title = entry.title or entry.name or entry.Name or entry.id or entry.slug
		if type(entry.title) ~= "string" or entry.title == "" then
			return
		end
		if entry.hidden == true then
			return
		end
		table.insert(list, entry)
	end
	if type(data) == "table" then
		if #data > 0 then
			for _, entry in ipairs(data) do
				push(entry)
			end
		else
			for _, entry in pairs(data) do
				push(entry)
			end
		end
	end
	if #list > 0 then
		ENV.Alleral_WeaoLastGood = { fetchedAt = tick(), data = list }
		return list
	end
	if type(ENV.Alleral_WeaoLastGood) == "table" and type(ENV.Alleral_WeaoLastGood.data) == "table" then
		return ENV.Alleral_WeaoLastGood.data
	end
	return nil
end

function Weao.decodeJson(body)
	if type(body) ~= "string" or body == "" then
		return nil
	end
	if body:find("Too Many Requests", 1, true) then
		return nil
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if ok then
		return decoded
	end
	return nil
end

function Weao.buildFetchUrls(config, executorSlug)
	config = Weao.mergeConfig(config)
	local urls = {}
	local seen = {}
	local allPath = config.paths.allExploits or "/api/status/exploits"
	local singlePrefix = config.paths.singleExploit or "/api/status/exploits/"

	local function add(url)
		if type(url) == "string" and url ~= "" and not seen[url] then
			seen[url] = true
			table.insert(urls, url)
		end
	end

	if type(executorSlug) == "string" and executorSlug ~= "" and executorSlug ~= "unknown" then
		for _, base in ipairs(config.bases) do
			add(base:gsub("/+$", "") .. singlePrefix .. executorSlug)
		end
	end

	for _, base in ipairs(config.bases) do
		add(base:gsub("/+$", "") .. allPath)
	end

	return urls
end

function Weao.extractBody(response)
	if type(response) == "string" then
		return response
	end
	if type(response) == "table" then
		return response.Body or response.body or response.Data or response.data
	end
	return nil
end

function Weao.fetchWithTransport(transport, url, headers)
	if type(transport) ~= "function" then
		return nil
	end
	headers = headers or Weao.requestHeaders()

	local ok, direct = pcall(transport, url)
	if ok and type(direct) == "string" and #direct > 0 then
		return direct
	end
	if ok and type(direct) == "table" then
		local body = Weao.extractBody(direct)
		if type(body) == "string" and #body > 0 then
			return body
		end
	end

	for _, spec in ipairs({
		{ Url = url, Method = "GET", Headers = headers },
		{ url = url, method = "GET", headers = headers },
	}) do
		local rok, res = pcall(transport, spec)
		if rok then
			local body = Weao.extractBody(res)
			if type(body) == "string" and #body > 0 then
				return body
			end
		end
	end

	return nil
end

function Weao.fetchExploits(opts)
	opts = type(opts) == "table" and opts or {}
	local config = Weao.mergeConfig(opts.config)
	local cacheSeconds = tonumber(config.cacheSeconds) or 300
	local cache = ENV.Alleral_WeaoCache

	if not opts.forceRefresh and type(cache) == "table" and cache.fetchedAt and (tick() - cache.fetchedAt) < cacheSeconds then
		if Weao.normalizeExploitList(cache.data) then
			return cache.data, cache.source
		end
	end

	local headers = Weao.requestHeaders()
	local transports = {}
	local function addTransport(fn)
		if type(fn) == "function" then
			for _, existing in ipairs(transports) do
				if existing == fn then
					return
				end
			end
			table.insert(transports, fn)
		end
	end

	addTransport(opts.httpFetch)
	addTransport(opts.requestFn)
	if #transports == 0 and type(game.HttpGet) == "function" then
		addTransport(function(url)
			return game.HttpGet(game, url, true)
		end)
		addTransport(function(url)
			return game:HttpGet(url, true)
		end)
	end

	local urls = Weao.buildFetchUrls(config, opts.executorSlug)
	local lastErr = "WEAO exploit list unavailable"

	for _, baseUrl in ipairs(urls) do
		local fetchUrls = {
			baseUrl .. (baseUrl:find("?") and "&" or "?") .. "t=" .. tostring(tick()),
			baseUrl,
		}
		for _, fetchUrl in ipairs(fetchUrls) do
			for _, transport in ipairs(transports) do
				local body = Weao.fetchWithTransport(transport, fetchUrl, headers)
				local decoded = Weao.decodeJson(body)
				local list = Weao.normalizeExploitList(decoded)
				if list then
					ENV.Alleral_WeaoCache = {
						fetchedAt = tick(),
						data = list,
						source = fetchUrl,
						configVersion = config.version,
					}
					return list, fetchUrl
				end
				if Weao.isRateLimitPayload(decoded) then
					lastErr = "WEAO rate limited"
				end
			end
		end
	end

	if type(cache) == "table" and Weao.normalizeExploitList(cache.data) then
		return cache.data, cache.source
	end

	if type(ENV.Alleral_WeaoLastGood) == "table" and Weao.normalizeExploitList(ENV.Alleral_WeaoLastGood.data) then
		return ENV.Alleral_WeaoLastGood.data, "last-good-cache"
	end

	return nil, lastErr
end

function Weao.refreshConfig(opts)
	opts = type(opts) == "table" and opts or {}
	local previousVersion = (ENV.Alleral_WeaoConfig or {}).version
	local remote = opts.config
	if type(remote) ~= "table" and type(opts.httpFetch) == "function" then
		for _, url in ipairs(opts.urls or {}) do
			local body = opts.httpFetch(url)
			remote = Weao.decodeJson(body)
			if type(remote) == "table" then
				break
			end
		end
	end
	if type(remote) == "table" then
		ENV._Alleral_WeaoConfigRemote = remote
		ENV.Alleral_WeaoConfig = Weao.mergeConfig(remote)
		if previousVersion ~= remote.version then
			ENV.Alleral_WeaoCache = nil
		end
		return ENV.Alleral_WeaoConfig, remote.version, previousVersion ~= remote.version
	end
	return ENV.Alleral_WeaoConfig, previousVersion, false
end

function Weao.normalizeExecutorKey(text)
	local key = tostring(text or ""):lower()
	key = key:gsub("synapse%s*z", "synapsez")
	key = key:gsub("awp%.?gg?", "volt")
	key = key:gsub("bunni%.?fun", "bunni")
	key = key:gsub("vega%s*x", "vegax")
	key = key:gsub("[^a-z0-9]", "")
	return key
end

function Weao.formatEntry(entry)
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

function Weao.matchExploit(profile, exploits)
	if type(exploits) ~= "table" then
		return nil, 0
	end

	local keys = {}
	local function addKey(key, weight)
		key = Weao.normalizeExecutorKey(key)
		if key ~= "" then
			keys[key] = math.max(keys[key] or 0, weight)
		end
	end

	if type(profile) == "table" then
		addKey(profile.rawName, 90)
		addKey(profile.slug, 85)
		addKey(profile.name, 80)
		if type(profile.envSlugs) == "table" then
			for _, envSlug in ipairs(profile.envSlugs) do
				addKey(envSlug, 75)
			end
		end
	end

	local best, bestScore = nil, 0
	for _, entry in ipairs(exploits) do
		if type(entry) == "table" and type(entry.title) == "string" then
			local titleKey = Weao.normalizeExecutorKey(entry.title)
			local score = 0
			for key, weight in pairs(keys) do
				if titleKey == key then
					score = math.max(score, weight + 10)
				elseif titleKey:find(key, 1, true) or key:find(titleKey, 1, true) then
					score = math.max(score, weight - 10)
				end
			end
			if score > bestScore then
				bestScore = score
				best = entry
			end
		end
	end

	return bestScore >= 55 and best or nil, bestScore
end

function Weao.statusLabel(weao)
	if type(weao) ~= "table" then
		return "Unknown (see docs.weao.xyz)"
	end
	if weao.offline then
		return "Offline mode · " .. tostring(weao.title or "executor")
	end
	local parts = {}
	table.insert(parts, weao.updateStatus and "Updated" or "Outdated")
	table.insert(parts, weao.detected and "Detected" or "Undetected")
	if weao.suncPercentage then
		table.insert(parts, tostring(weao.suncPercentage) .. "% sUNC")
	end
	return table.concat(parts, " · ")
end

function Weao.executorStatus(profile, opts)
	opts = type(opts) == "table" and opts or {}
	profile = profile or {}
	local exploits, err = Weao.fetchExploits({
		forceRefresh = opts.forceRefresh,
		httpFetch = opts.httpFetch,
		requestFn = opts.requestFn,
		config = opts.config,
		executorSlug = profile.slug,
	})
	local entry, score = Weao.matchExploit(profile, exploits)
	if entry then
		return Weao.formatEntry(entry), nil, score
	end
	if type(exploits) == "table" and #exploits > 0 then
		return {
			title = profile.name or profile.slug or "Unknown",
			version = profile.version,
			updateStatus = true,
			detected = false,
			offline = true,
		}, err, 0
	end
	return {
		title = profile.name or profile.slug or "Unknown",
		version = profile.version,
		updateStatus = true,
		detected = false,
		offline = true,
	}, err or "WEAO offline — using cached executor profile", 0
end

ENV.Alleral_Weao = Weao
return Weao
