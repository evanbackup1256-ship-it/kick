local Analytics = {}
Analytics.Version = "1.0"
Analytics.Config = {
	webhookUrl = "",
	webhookEnabled = false,
	brand = "Alleral",
	color = 16733440,
}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local function trim(value)
	return tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function coreApi()
	local genv = getgenv and getgenv() or {}
	return genv.Alleral_Core
end

local function postWebhook(url, payload)
	local core = coreApi()
	if core and type(core.postWebhook) == "function" then
		return core.postWebhook(url, payload)
	end
	return false, "Run loader.luau first."
end

local function executorName()
	local core = coreApi()
	if core and type(core.detectExecutor) == "function" then
		return core.detectExecutor().displayName
	end
	local env = {}
	pcall(function()
		local g = getgenv or getfenv
		if g then
			env = g() or {}
		end
	end)
	for _, id in ipairs({
		"identifyexecutor",
		"getexecutorname",
		"whatexecutor",
		"getexecutor",
	}) do
		local fn = env[id]
		if type(fn) == "function" then
			local ok, result = pcall(fn)
			if ok and type(result) == "string" and result ~= "" then
				return result
			end
		end
	end
	if type(env.syn) == "table" then
		return "Synapse"
	end
	if env.shared and type(env.shared.solara) == "table" then
		return "Solara"
	end
	return "Unknown"
end

local function isoNow()
	local ok, value = pcall(function()
		return DateTime.now():ToIsoDate()
	end)
	return ok and value or nil
end

local function embedFooter()
	return { text = Analytics.Config.brand or "Alleral" }
end

local function hashSeed(text)
	if trim(text) == "" then
		local ok, id = pcall(function()
			return HttpService:GenerateGUID(false)
		end)
		return ok and id or ("al_" .. tostring(os.time()))
	end
	local h1, h2 = 5381, 0
	for i = 1, #text do
		local byte = string.byte(text, i)
		h1 = (h1 * 33 + byte) % 2147483647
		h2 = (h2 * 31 + byte * (i % 7 + 1)) % 2147483647
	end
	return string.format("al_%x_%x_%x", h1, h2, #text)
end

function Analytics:GetClientId()
	local genv = getgenv and getgenv() or {}
	if genv.Alleral_ClientId and genv.Alleral_ClientId ~= "" then
		return genv.Alleral_ClientId
	end
	local player = Players.LocalPlayer
	local seed = table.concat({
		tostring(player and player.UserId or 0),
		tostring(game.PlaceId),
		tostring(executorName()),
	}, ":")
	local id = hashSeed(seed)
	genv.Alleral_ClientId = id
	return id
end

function Analytics:Track()
	local genv = getgenv and getgenv() or {}
	if genv.Alleral_Tracked then
		return
	end
	genv.Alleral_Tracked = true

	local player = Players.LocalPlayer
	local placeName = "Unknown"
	pcall(function()
		local info = MarketplaceService:GetProductInfo(game.PlaceId)
		placeName = info and info.Name or placeName
	end)

	local session = {
		clientId = self:GetClientId(),
		executor = executorName(),
		placeId = game.PlaceId,
		placeName = placeName,
		jobId = tostring(game.JobId),
		userId = player and player.UserId or 0,
		userName = player and player.Name or "Unknown",
		startedAt = os.time(),
		moduleVersion = self.Version,
	}

	genv.Alleral_SessionLog = genv.Alleral_SessionLog or {}
	table.insert(genv.Alleral_SessionLog, session)
	if #genv.Alleral_SessionLog > 20 then
		table.remove(genv.Alleral_SessionLog, 1)
	end

	genv.Alleral_LastSession = session
end

function Analytics:SendSatelliteLog()
	local genv = getgenv and getgenv() or {}
	local session = genv.Alleral_LastSession
	if not session then
		return
	end
	session.lastHeartbeat = os.time()
end

function Analytics:SendTestConnection(webhookUrl)
	return postWebhook(webhookUrl, {
		username = Analytics.Config.brand,
		embeds = {
			{
				title = "Webhook works",
				description = "Webhook test from " .. (Analytics.Config.brand or "Alleral") .. ".",
				color = Analytics.Config.color,
				fields = {
					{ name = "Executor", value = "```" .. executorName() .. "```", inline = true },
					{ name = "Client", value = "```" .. self:GetClientId():sub(1, 12) .. "...```", inline = true },
				},
				footer = embedFooter(),
				timestamp = isoNow(),
			},
		},
	})
end

local function breakdownToFields(breakdown)
	local fields = {}
	for rarity, brainrots in pairs(breakdown or {}) do
		local lines = {}
		for brainrot, mutations in pairs(brainrots) do
			for mutation, count in pairs(mutations) do
				table.insert(lines, string.format("%s [%s] x%s", brainrot, mutation, tostring(count)))
			end
		end
		if #lines > 0 then
			table.sort(lines)
			table.insert(fields, {
				name = rarity,
				value = "```" .. table.concat(lines, "\n") .. "```",
				inline = false,
			})
		end
	end
	return fields
end

function Analytics:SendStatusReport(webhookUrl, kickLevel, petCount, coinsText, breakdown, rebirthLevel)
	local fields = {
		{ name = "Coins", value = "```" .. tostring(coinsText or "0") .. "```", inline = true },
		{ name = "Kick level", value = "```" .. tostring(kickLevel or 0) .. "```", inline = true },
		{ name = "Rebirths", value = "```" .. tostring(rebirthLevel or 0) .. "```", inline = true },
		{ name = "Bag count", value = "```" .. tostring(petCount or 0) .. "```", inline = true },
	}
	for _, field in ipairs(breakdownToFields(breakdown)) do
		table.insert(fields, field)
	end
	if (petCount or 0) == 0 then
		table.insert(fields, { name = "Bag", value = "Nothing matched your filters.", inline = false })
	end
	return postWebhook(webhookUrl, {
		username = Analytics.Config.brand,
		embeds = {
			{
				title = "Status report",
				color = Analytics.Config.color,
				fields = fields,
				footer = embedFooter(),
				timestamp = isoNow(),
			},
		},
	})
end

function Analytics:SendNewPetClaim(webhookUrl, name, rarity, mutation, chance, cpsText, imageUrl)
	local embed = {
		title = "New brainrot",
		color = Analytics.Config.color,
		fields = {
			{ name = "Brainrot", value = "```" .. tostring(name) .. "```", inline = true },
			{ name = "Rarity", value = "```" .. tostring(rarity) .. "```", inline = true },
			{ name = "Mutation", value = "```" .. tostring(mutation) .. "```", inline = true },
			{ name = "Chance", value = "```" .. tostring(chance or "Unknown") .. "```", inline = true },
			{ name = "CPS", value = "```" .. tostring(cpsText or "N/A") .. "```", inline = true },
			{ name = "Server JobId", value = "```" .. tostring(game.JobId) .. "```", inline = false },
		},
		footer = embedFooter(),
		timestamp = isoNow(),
	}
	if imageUrl and imageUrl ~= "" then
		embed.image = { url = imageUrl }
		embed.thumbnail = { url = imageUrl }
	end
	return postWebhook(webhookUrl, {
		username = Analytics.Config.brand,
		content = "@everyone",
		embeds = { embed },
	})
end

function Analytics:SendGlobalLog(playerName, brainrot, mutation, rarity, cpsText)
	local url = self.Config.webhookUrl
	if not self.Config.webhookEnabled or trim(url) == "" then
		return false, "Webhook disabled"
	end
	return postWebhook(url, {
		username = Analytics.Config.brand,
		content = "@everyone",
		embeds = {
			{
				title = "Highlight roll",
				description = "Rare roll spotted in-server.",
				color = Analytics.Config.color,
				fields = {
					{ name = "Player", value = "```" .. tostring(playerName) .. "```", inline = true },
					{ name = "Brainrot", value = "```" .. tostring(brainrot) .. "```", inline = true },
					{ name = "Rarity", value = "```" .. tostring(rarity) .. "```", inline = true },
					{ name = "Mutation", value = "```" .. tostring(mutation) .. "```", inline = true },
					{ name = "CPS", value = "```" .. tostring(cpsText or "N/A") .. "```", inline = true },
					{ name = "Server JobId", value = "```" .. tostring(game.JobId) .. "```", inline = false },
				},
				footer = embedFooter(),
				timestamp = isoNow(),
			},
		},
	})
end

getgenv().Alleral_Analytics = Analytics
