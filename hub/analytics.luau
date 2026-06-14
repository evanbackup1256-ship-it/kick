local Analytics = {}
Analytics.Version = "1.2"
Analytics.Config = {
	webhookUrl = "",
	webhookEnabled = false,
	brand = "Alleral",
	color = 5489688,
}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local RARITY_COLORS = {
	Common = 9807270,
	Uncommon = 3447003,
	Rare = 10181046,
	Epic = 10181046,
	Legendary = 15844367,
	Mythic = 16729156,
	Secret = 16766758,
	Exclusive = 5489688,
}

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

local function buildEmbed(opts)
	local core = coreApi()
	if core and type(core.buildDiscordEmbed) == "function" then
		return core.buildDiscordEmbed(opts)
	end
	return {
		title = opts.title,
		description = opts.description,
		color = opts.color or Analytics.Config.color,
		fields = opts.fields or {},
		footer = opts.footer or { text = Analytics.Config.brand or "Alleral" },
		timestamp = opts.timestamp,
		thumbnail = opts.thumbnail,
		image = opts.image,
		author = opts.author,
	}
end

local function buildPayload(opts)
	local core = coreApi()
	if core and type(core.buildDiscordPayload) == "function" then
		return core.buildDiscordPayload(opts)
	end
	return {
		username = opts.username or Analytics.Config.brand,
		avatar_url = opts.avatarUrl,
		content = opts.content,
		embeds = opts.embeds or { buildEmbed(opts) },
	}
end

local function field(name, value, inline)
	local core = coreApi()
	if core and type(core.discordField) == "function" then
		return core.discordField(name, value, inline)
	end
	return { name = name, value = "```" .. tostring(value or "—") .. "```", inline = inline == true }
end

local function playerAuthor()
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local avatarUrl = string.format(
		"https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png",
		player.UserId
	)
	return {
		name = string.format("%s (@%s)", player.DisplayName, player.Name),
		icon_url = avatarUrl,
		url = string.format("https://www.roblox.com/users/%d/profile", player.UserId),
	}
end

local function embedFooter(extra)
	return { text = (Analytics.Config.brand or "Alleral") .. (extra and (" · " .. extra) or "") }
end

local function rarityColor(rarity)
	return RARITY_COLORS[tostring(rarity or "")] or Analytics.Config.color
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

function Analytics:SendSatelliteLog(weatherName, durationText, joinPayload, playerCount, placeVersion, joinUrl)
	if type(weatherName) == "string" and weatherName ~= "" and type(durationText) == "string" then
		local url = self.Config.webhookUrl
		if not self.Config.webhookEnabled or trim(url) == "" then
			return false, "Webhook disabled"
		end
		return postWebhook(
			url,
			buildPayload({
				brand = Analytics.Config.brand,
				content = "@everyone",
				avatarUrl = playerAuthor() and playerAuthor().icon_url or nil,
				embeds = {
					buildEmbed({
						title = "Weather",
						description = string.format("%s · %s left", weatherName, durationText),
						color = 3447003,
						fields = {
							field("Join", joinPayload or joinUrl or "n/a", false),
							field("Link", joinUrl or "n/a", false),
							field("Players", tostring(playerCount or "?"), true),
							field("Build", tostring(placeVersion or "?"), true),
							field("JobId", tostring(game.JobId), false),
						},
						footer = embedFooter("weather"),
						timestamp = isoNow(),
						author = playerAuthor(),
					}),
				},
			})
		)
	end

	local genv = getgenv and getgenv() or {}
	local session = genv.Alleral_LastSession
	if not session then
		return
	end
	session.lastHeartbeat = os.time()
end

function Analytics:SendTestConnection(webhookUrl)
	return postWebhook(
		webhookUrl,
		buildPayload({
			brand = Analytics.Config.brand,
			avatarUrl = playerAuthor() and playerAuthor().icon_url or nil,
			embeds = {
				buildEmbed({
					title = "Webhook connected",
					description = "Test ping went through.",
					color = 5489688,
					fields = {
						field("Executor", executorName(), true),
						field("Client", self:GetClientId():sub(1, 16) .. "…", true),
						field("PlaceId", tostring(game.PlaceId), true),
						field("JobId", tostring(game.JobId), false),
					},
					footer = embedFooter("test ping"),
					timestamp = isoNow(),
					author = playerAuthor(),
				}),
			},
		})
	)
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
				name = "📦 " .. tostring(rarity),
				value = "```" .. table.concat(lines, "\n") .. "```",
				inline = false,
			})
		end
	end
	return fields
end

function Analytics:SendStatusReport(webhookUrl, kickLevel, petCount, coinsText, breakdown, rebirthLevel)
	local fields = {
		field("Coins", tostring(coinsText or "0"), true),
		field("Kick level", tostring(kickLevel or 0), true),
		field("Rebirths", tostring(rebirthLevel or 0), true),
		field("Bag count", tostring(petCount or 0), true),
		field("Server JobId", tostring(game.JobId), false),
	}
	for _, extra in ipairs(breakdownToFields(breakdown)) do
		table.insert(fields, extra)
	end
	if (petCount or 0) == 0 then
		table.insert(fields, { name = "Bag", value = "_No matches._", inline = false })
	end
	return postWebhook(
		webhookUrl,
		buildPayload({
			brand = Analytics.Config.brand,
			avatarUrl = playerAuthor() and playerAuthor().icon_url or nil,
			embeds = {
				buildEmbed({
					title = "Status report",
					description = "Bag check.",
					color = 5489688,
					fields = fields,
					footer = embedFooter("status report"),
					timestamp = isoNow(),
					author = playerAuthor(),
				}),
			},
		})
	)
end

function Analytics:SendNewPetClaim(webhookUrl, name, rarity, mutation, chance, cpsText, imageUrl)
	local embed = buildEmbed({
		title = "New claim",
		description = string.format("%s · %s", tostring(name), tostring(rarity)),
		color = rarityColor(rarity),
		fields = {
			field("Brainrot", name, true),
			field("Rarity", rarity, true),
			field("Mutation", mutation, true),
			field("Chance", chance or "Unknown", true),
			field("CPS", cpsText or "N/A", true),
			field("Server JobId", tostring(game.JobId), false),
		},
		footer = embedFooter("claim alert"),
		timestamp = isoNow(),
		author = playerAuthor(),
	})
	if imageUrl and imageUrl ~= "" then
		embed.image = { url = imageUrl }
		embed.thumbnail = { url = imageUrl }
	end
	return postWebhook(
		webhookUrl,
		buildPayload({
			brand = Analytics.Config.brand,
			content = "@everyone",
			avatarUrl = playerAuthor() and playerAuthor().icon_url or nil,
			embeds = { embed },
		})
	)
end

function Analytics:SendGlobalLog(playerName, brainrot, mutation, rarity, cpsText)
	local url = self.Config.webhookUrl
	if not self.Config.webhookEnabled or trim(url) == "" then
		return false, "Webhook disabled"
	end
	return postWebhook(
		url,
		buildPayload({
			brand = Analytics.Config.brand,
			content = "@everyone",
			avatarUrl = playerAuthor() and playerAuthor().icon_url or nil,
			embeds = {
				buildEmbed({
					title = "Highlight roll",
					description = "Highlight roll.",
					color = rarityColor(rarity),
					fields = {
						field("Player", playerName, true),
						field("Brainrot", brainrot, true),
						field("Rarity", rarity, true),
						field("Mutation", mutation, true),
						field("CPS", cpsText or "N/A", true),
						field("Server JobId", tostring(game.JobId), false),
					},
					footer = embedFooter("highlight"),
					timestamp = isoNow(),
					author = playerAuthor(),
				}),
			},
		})
	)
end

getgenv().Alleral_Analytics = Analytics
