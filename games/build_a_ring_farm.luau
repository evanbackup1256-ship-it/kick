getgenv().Alleral_State = getgenv().Alleral_State or {}

local Core = getgenv().Alleral_Core
if not Core or not Core.assertLoader or not Core.assertLoader() then
	return
end

local VERSION = "1.4.1"
local state = getgenv().Alleral_State
local connections = {}
local loops = {}
local loopControllers = {}

local ui
local bootErr
Core, ui, bootErr = Core.boot(state)
if not Core or not ui then
	local msg = bootErr or "boot failed"
	getgenv().Alleral_StartupFailed = msg
	local coreRef = Core or getgenv().Alleral_Core
	if coreRef and type(coreRef.logWarn) == "function" then
		coreRef.logWarn(msg)
	else
		warn("[Alleral] " .. tostring(msg))
	end
	return
end

local G = Core.Game or getgenv().Alleral_GameHelpers or {}

local function regMod(moduleScript, timeout)
	if G.registryGameModule then
		return G.registryGameModule(moduleScript, timeout or 15)
	end
	return nil
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local SETTINGS_FILE = "build_a_ring_farm.json"
local defaults = {
	AutoPlaceSeed = false,
	AutoUnlockPlot = false,
	AutoSell = false,
	AutoBuySeed = false,
	AutoRollManual = false,
	AutoDiscardSeed = false,
	TargetDiscardSeed = { "Any" },
	AutoUpgradeSeed = false,
	AutoRemoveSeed = false,
	TargetPlantAction = { "Any" },
	TargetPlantActionRarity = { "Any" },
	TargetPlaceSeed = { "Any" },
	TargetSeed = { "Any" },
	TargetSeedRarity = { "Any" },
	MaxUpgradeLevel = 10,
	SellDelay = 2,
	RollDelay = 1,
	TargetPlaceSeedRarity = { "Any" },
	TargetPlantPlot = { "Any" },
	TargetDiscardSeedRarity = { "Any" },
	AutoBuyGear = false,
	TargetGear = { "Any" },
	AutoUpgradeSeedRolls = false,
	AutoUpgradeSeedLuck = false,
	AutoExpandFarm = false,
	AutoUpgradeSawRange = false,
	AutoUpgradeSawYield = false,
	AutoUpgradeSprinklerRange = false,
	AutoUpgradeSprinklerPower = false,
	TargetUpgradeFloor = { "All" },
	AutoBuyEgg = false,
	AutoUnlockEgg = false,
	TargetEgg = { "Any" },
	AutoBuyEventShop = false,
	TargetEventItem = { "Any" },
	AutoSubmitEventSeed = false,
	TargetEventSeed = { "Any" },
	TargetEventSeedRarity = { "Any" },
	AutoShootEvent = false,
	AutoCollectRushDrops = false,
	AutoCollectAlienDrop = false,
	TargetEnemyPriority = { "Closest" },
	AutoComposter = false,
	AutoPullLever = false,
	TargetComposterTier = 10,
	TargetCompostSeed = { "Any" },
	TargetCompostRarity = { "Any" },
	TargetComposterFloor = { "Any" },
	AutoHoney = false,
	AutoRollHoney = false,
	AutoContractSubmit = false,
	AutoContractReroll = false,
	TargetContractSlot = { "Any" },
	IgnoreContractSeeds = {},
	AntiAFK = false,
	EnableFly = false,
	FlySpeed = 50,
	AutoSpray = false,
	AutoFertilizer = false,
	TargetFertilizer = { "Any" },
	AutoFeedPet = false,
	TargetFeedPet = { "Any" },
	AutoOptimizePets = false,
	TargetPetTreat = { "Any" },
	TargetSprayPlant = { "Any" },
	TargetSprayType = { "Any" },
	AutoSellPet = false,
	TargetSellPetRarity = {},
	TargetSellPetName = {},
	TargetSellPetLive = {},
	AutoClaimPlaytime = false,
	AutoOpenBox = false,
	AutoUpgradePlotStats = false,
	TargetPlotStats = { "Any" },
	ActivePresetName = "Default",
}

local savedKeys
local saveSettings

saveSettings, savedKeys = Core.initSettings(state, defaults, SETTINGS_FILE)

local function notify(title, text, duration, notifyType)
	Core.notify(title, text, duration, notifyType)
end

local runtime = {
	playerPlot = nil,
	unlockCooldowns = {},
	plantingActive = false,
	eventTarget = nil,
	honeyTarget = nil,
	combatActive = false,
	flyBody = nil,
	flyGyro = nil,
	flyVelocity = nil,
	flyConnection = nil,
	shooterSaved = nil,
	afkSpinStarted = false,
}

local function waitChild(parent, name, timeout)
	if G.waitChild then
		return G.waitChild(parent, name, timeout)
	end
	return Core.waitChild(parent, name, timeout)
end

local Remotes = waitChild(ReplicatedStorage, "Remotes", 10)
local RollSeedsRemote = Remotes and waitChild(Remotes, "RollSeeds", 5)
local BuySeedRemote = Remotes and waitChild(Remotes, "BuySeed", 5)
local DiscardSeedRemote = Remotes and waitChild(Remotes, "DiscardSeed", 5)
local PlantSeedRemote = Remotes and waitChild(Remotes, "PlantSeed", 5)
local UnlockPlotRemote = Remotes and waitChild(Remotes, "UnlockPlot", 5)
local SellCratesRemote = Remotes and waitChild(Remotes, "SellCrates", 5)
local PlotRemotes = Remotes and waitChild(Remotes, "Plot", 5)
local GetPlotRemote = PlotRemotes and waitChild(PlotRemotes, "GetPlot", 5)
local UpgradePlantRemote = Remotes and waitChild(Remotes, "UpgradePlant", 5)
local RemovePlantRemote = Remotes and waitChild(Remotes, "RemovePlant", 5)
local UpgradeSeedRollsRemote = Remotes and waitChild(Remotes, "UpgradeSeedRolls", 5)
local UpgradeSeedLuckRemote = Remotes and waitChild(Remotes, "UpgradeSeedLuck", 5)
local UpgradeFarmRemote = Remotes and waitChild(Remotes, "UpgradeFarm", 5)
local GearRemotes = Remotes and waitChild(Remotes, "Gear", 5)
local GearTransactionRemote = GearRemotes and waitChild(GearRemotes, "Transaction", 5)
local PlotUpgradeTransactionRemote = Remotes and waitChild(Remotes, "PlotUpgradeTransaction", 5)
local EggShopRemotes = Remotes and waitChild(Remotes, "EggShop", 5)
local EggShopTransactionRemote = EggShopRemotes and waitChild(EggShopRemotes, "Transaction", 5)
local ComposterRemotes = Remotes and waitChild(Remotes, "Composter", 5)
local ComposterInsertRemote = ComposterRemotes and waitChild(ComposterRemotes, "InsertSeed", 5)
local ComposterPullLeverRemote = ComposterRemotes and waitChild(ComposterRemotes, "PullLever", 5)
local ComposterRequestStateRemote = ComposterRemotes and waitChild(ComposterRemotes, "RequestState", 5)
local RollEggRemote = Remotes and waitChild(Remotes, "RollEgg", 5)
local EquipToolRemote = Remotes and waitChild(Remotes, "EquipTool", 5)
local UseSprayRemote = Remotes and waitChild(Remotes, "UseSpray", 5)
local UseFertilizerRemote = Remotes and waitChild(Remotes, "UseFertilizer", 5)
local UsePetTreatRemote = Remotes and waitChild(Remotes, "UsePetTreat", 5)
local ContractsFolder = waitChild(waitChild(ReplicatedStorage, "Contracts", 5), "RF", 5)
local ContractSubmitRemote = ContractsFolder and waitChild(ContractsFolder, "Submit", 5)
local ContractRerollRemote = ContractsFolder and waitChild(ContractsFolder, "Reroll", 5)
local PetsRemotes = Remotes and waitChild(Remotes, "Pets", 5)
local EquipPetRemote = PetsRemotes and waitChild(PetsRemotes, "EquipPet", 5)
local UnequipPetRemote = PetsRemotes and PetsRemotes:FindFirstChild("UnequipPet")
local SellPetRemote = PetsRemotes and PetsRemotes:FindFirstChild("SellPet")
local PlantRushBuyRemote = Remotes and Remotes:FindFirstChild("PlantRush") and Remotes.PlantRush:FindFirstChild("BuyShopItem")

local DataReplicator, Configuration, SharedUtils, EconomyTuning, DataAggregation, CompostCooldownClient, PlantRushShooter

local function bootstrapGameModules()
	DataReplicator = regMod(ReplicatedStorage.Packages.DataReplicator, 18)
	Configuration = regMod(ReplicatedStorage.Shared.Configuration, 18)
	SharedUtils = regMod(ReplicatedStorage.Shared.SharedUtils, 18)
	EconomyTuning = regMod(ReplicatedStorage.Shared.EconomyTuning, 18)

	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local clientLoader = playerScripts and playerScripts:FindFirstChild("ClientLoader")
	local modules = clientLoader and clientLoader:FindFirstChild("Modules")
	local dataAgg = modules and modules:FindFirstChild("DataAggregation")
	if dataAgg then
		DataAggregation = regMod(dataAgg, 18)
	end

	local handlers = clientLoader and clientLoader:FindFirstChild("Handlers")
	local compostMod = handlers and handlers:FindFirstChild("CompostCooldownClient")
	if compostMod then
		CompostCooldownClient = regMod(compostMod, 18)
	end

	local rushConfig = regMod(ReplicatedStorage.Shared.Registry.PlantRushConfig, 18)
	if rushConfig and rushConfig.Shooter then
		PlantRushShooter = rushConfig.Shooter
	end
end

task.spawn(function()
	LocalPlayer:WaitForChild("PlayerScripts", 45)
	task.wait(3)
	if G.invalidateGameRequire then
		G.invalidateGameRequire()
	end
	bootstrapGameModules()
	task.wait(5)
	if G.invalidateGameRequire then
		G.invalidateGameRequire()
	end
	bootstrapGameModules()
end)

local function getRegistryModule(moduleName)
	local registry = ReplicatedStorage:FindFirstChild("Registry")
	if registry then
		local mod = registry:FindFirstChild(moduleName)
		if mod and mod:IsA("ModuleScript") then
			return regMod(mod, 0)
		end
	end
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if shared then
		local sharedRegistry = shared:FindFirstChild("Registry")
		if sharedRegistry then
			local mod = sharedRegistry:FindFirstChild(moduleName)
			if mod and mod:IsA("ModuleScript") then
				return regMod(mod, 0)
			end
		end
		local direct = shared:FindFirstChild(moduleName)
		if direct and direct:IsA("ModuleScript") then
			return regMod(direct, 0)
		end
	end
	return nil
end

local PlantsRegistry = getRegistryModule("Plants")
local ProductsRegistry = getRegistryModule("Products") or getRegistryModule("Gear")
local EggConfig = getRegistryModule("EggConfig")
local PlantRushConfig = getRegistryModule("PlantRushConfig")
local PetsRegistry = getRegistryModule("Pets")

local seedNameOptions = { "Any" }
local seedRarityOptions = { "Any" }
local gearNameOptions = { "Any" }
local eventItemOptions = { "Any" }
local eggNameOptions = { "Any" }

local function sortAnyFirst(list)
	table.sort(list, function(a, b)
		if a == "Any" then
			return true
		end
		if b == "Any" then
			return false
		end
		return a < b
	end)
end

if PlantsRegistry then
	local seenRarity = {}
	for plantName, plantData in pairs(PlantsRegistry) do
		if type(plantData) == "table" and plantData.Rarity then
			table.insert(seedNameOptions, plantName)
			if not seenRarity[plantData.Rarity] then
				seenRarity[plantData.Rarity] = true
				table.insert(seedRarityOptions, plantData.Rarity)
			end
		end
	end
end

if ProductsRegistry then
	for productName, productData in pairs(ProductsRegistry) do
		if type(productData) == "table" and productData.Gear == true then
			table.insert(gearNameOptions, productName)
		end
	end
end

if EggConfig then
	for eggName, eggData in pairs(EggConfig) do
		if type(eggData) == "table" and string.find(eggName:lower(), "egg") then
			table.insert(eggNameOptions, eggName)
		end
	end
end

if PlantRushConfig and PlantRushConfig.MerchantItems then
	for _, item in ipairs(PlantRushConfig.MerchantItems) do
		if item.Id and item.Display then
			table.insert(eventItemOptions, item.Id)
		end
	end
end

sortAnyFirst(seedNameOptions)
sortAnyFirst(seedRarityOptions)
sortAnyFirst(gearNameOptions)
sortAnyFirst(eggNameOptions)
sortAnyFirst(eventItemOptions)

local function listContains(list, value)
	return Core.listContains(list, value)
end

local function listMatches(list, value)
	return Core.listMatches(list, value)
end

local function firePrompt(prompt)
	if not prompt or not prompt.Enabled then
		return
	end
	if fireproximityprompt then
		pcall(fireproximityprompt, prompt)
	else
		warn("[Alleral] fireproximityprompt unavailable in this executor")
	end
end

local function callRemote(remote, ...)
	if G.fireRemote then
		return G.fireRemote(remote, ...)
	end
	if not remote then
		return false, "Remote missing"
	end
	local args = { ... }
	if remote:IsA("RemoteFunction") then
		return pcall(function()
			return remote:InvokeServer(unpack(args))
		end)
	end
	if remote:IsA("RemoteEvent") then
		return pcall(function()
			remote:FireServer(unpack(args))
		end)
	end
	return false, "Invalid remote type"
end

local function normalizePlantName(name)
	if not name then
		return ""
	end
	return (name:gsub("%s+[Ss]eed$", ""))
end

local function normalizedList(list)
	return Core.normalizeMultiSelection(list)
end

local function matchesSeedFilter(plantName, nameList, rarityList)
	if not nameList or not rarityList then
		return false
	end
	local normalized = normalizePlantName(plantName)
	local nameOk = listContains(nameList, "Any")
	if not nameOk and plantName then
		for _, target in ipairs(normalizedList(nameList)) do
			if target ~= "Any" then
				local targetNorm = normalizePlantName(target)
				if normalized:lower() == targetNorm:lower() then
					nameOk = true
					break
				end
			end
		end
	end
	local rarityOk = listContains(rarityList, "Any")
	if not rarityOk and PlantsRegistry and plantName then
		local info = PlantsRegistry[plantName] or PlantsRegistry[normalized]
		if info and info.Rarity then
			rarityOk = listContains(rarityList, info.Rarity)
		end
	end
	return nameOk and rarityOk
end

local function isPlotSlotLocked(dirt)
	local plotModel = dirt and dirt.Parent
	if not plotModel or not plotModel:IsA("Model") then
		return false
	end
	local unlocked = plotModel:GetAttribute("Unlocked")
	if unlocked == false then
		return true
	end
	if unlocked ~= nil then
		return false
	end
	local grass = plotModel:FindFirstChild("Grass")
	return grass and grass:IsA("BasePart") and grass.Transparency == 0
end

local function findOwnedPlotFromMap()
	local plotsFolder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
	if not plotsFolder then
		return nil
	end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		local label = plot:FindFirstChild("HomeLabelAttachment")
		if label and #label:GetChildren() > 0 then
			return plot
		end
	end
	return nil
end

local function getPlotLabel(dirt)
	local plotModel = dirt.Parent
	if not plotModel then
		return nil
	end
	local farmPlot = plotModel.Parent
	if not farmPlot or farmPlot.Name ~= "FarmPlot" then
		return nil
	end
	local floorNum = 1
	local floorModel = farmPlot.Parent
	if floorModel then
		local matched = floorModel.Name:match("^Floor(%d+)$")
		if matched then
			floorNum = tonumber(matched) or 1
		end
	end
	local plotIndex = plotModel.Name:match("^Plot(%d+)$")
	if not plotIndex then
		return nil
	end
	return string.format("Floor %d - Plot %s", floorNum, plotIndex)
end

local function plotLabelMatches(dirt)
	local label = getPlotLabel(dirt)
	if not label then
		return listContains(state.TargetPlantPlot, "Any")
	end
	return listMatches(state.TargetPlantPlot, label)
end

local function getPlayerCash()
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	if not leaderstats then
		return 0
	end
	for _, statName in ipairs({ "Cash", "Money", "Coins" }) do
		local stat = leaderstats:FindFirstChild(statName)
		if stat then
			return tonumber(stat.Value) or 0
		end
	end
	return 0
end

local function parsePriceString(text)
	if not text then
		return 0
	end
	local cleaned = text:gsub("[$,]", ""):gsub("%s+", ""):lower()
	local numberPart, suffix = cleaned:match("^([%d%.]+)([a-z]*)$")
	local value = tonumber(numberPart) or 0
	local multipliers = { k = 1e3, m = 1e6, b = 1e9, t = 1e12 }
	if suffix and multipliers[suffix] then
		value = value * multipliers[suffix]
	end
	return value
end

local function getSeedBuyPrice(seedName)
	if not PlantsRegistry then
		return 0
	end
	local info = PlantsRegistry[seedName] or PlantsRegistry[normalizePlantName(seedName)]
	if not info then
		return 0
	end
	return info.Price or info.Cost or info.ShopPrice or 0
end

local function getBestPlaceSeedTool()
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if not backpack then
		return nil
	end
	local bestTool
	local bestPrice = -1
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local plantName = tool:GetAttribute("Plant") or tool.Name:match("^(.-)%s*[Ss]eed$") or tool.Name
			if matchesSeedFilter(plantName, state.TargetPlaceSeed, state.TargetPlaceSeedRarity) then
				local price = getSeedBuyPrice(plantName)
				if price >= bestPrice then
					bestPrice = price
					bestTool = tool
				end
			end
		end
	end
	return bestTool
end

local function findFertilizerTool(backpack, character)
	local priority = { "Prismatic Fertilizer", "Super Fertilizer", "Strong Fertilizer", "Normal Fertilizer" }
	local allowAny = listContains(state.TargetFertilizer, "Any")
	for _, fertName in ipairs(priority) do
		if allowAny or listContains(state.TargetFertilizer, fertName) then
			local tool = (backpack and backpack:FindFirstChild(fertName))
				or (character and character:FindFirstChild(fertName))
			if tool then
				return tool
			end
			for _, container in ipairs({ backpack, character }) do
				if container then
					for _, child in ipairs(container:GetChildren()) do
						if child:IsA("Tool") and string.find(child.Name, fertName, 1, true) then
							return child
						end
					end
				end
			end
		end
	end
	return nil
end

local function findSprayTool(backpack, character)
	local allowAny = listContains(state.TargetSprayType, "Any")
	for _, container in ipairs({ backpack, character }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and string.find(tool.Name:lower(), "spray") then
					if allowAny or listContains(state.TargetSprayType, tool.Name) then
						return tool
					end
				end
			end
		end
	end
	return nil
end

local function getSeedRoller()
	if not runtime.playerPlot then
		return nil
	end
	return runtime.playerPlot:FindFirstChild("SeedRoller")
end

local function getSeedStands()
	local roller = getSeedRoller()
	if not roller then
		return {}
	end
	local stands = {}
	for index = 1, 6 do
		local stand = roller:FindFirstChild("Stand" .. index)
		if stand then
			stands[index] = { index = index, position = stand:GetPivot().Position }
		end
	end
	return stands
end

local function getHeldToolsAtStands()
	local stands = getSeedStands()
	local held = {}
	for index, standInfo in pairs(stands) do
		for _, model in ipairs(workspace:GetChildren()) do
			if model:IsA("Model") and (model:GetPivot().Position - standInfo.position).Magnitude < 3 then
				held[index] = { Name = model.Name, Model = model }
				break
			end
		end
	end
	return held
end

local function hasHoneyTool()
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local character = LocalPlayer.Character
	for _, container in ipairs({ backpack, character }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") then
					local lower = item.Name:lower()
					if lower:find("honey") or lower:find("token") then
						return true
					end
				end
			end
		end
	end
	return false
end

local function getActiveMode()
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return "None"
	end
	if state.AutoHoney then
		local events = workspace:FindFirstChild("InteractiveEvents")
		local queenBee = events and events:FindFirstChild("QueenBee")
		local honeycombs = queenBee and queenBee:FindFirstChild("RuntimeHoneycombs")
		if honeycombs then
			for _, part in ipairs(honeycombs:GetChildren()) do
				if part:IsA("BasePart") or part:IsA("Model") then
					local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
					if prompt and prompt.Enabled then
						return "Honeycomb"
					end
				end
			end
		end
	end
	if state.AutoRollHoney and hasHoneyTool() then
		return "HoneyPot"
	end
	if state.AutoCollectAlienDrop then
		local events = workspace:FindFirstChild("InteractiveEvents")
		local invasion = events and events:FindFirstChild("AlienInvasion")
		if invasion then
			for _, drop in ipairs(invasion:GetChildren()) do
				if drop.Name:find("AlienDrop") and (drop:IsA("BasePart") or drop:IsA("Model")) then
					local prompt = drop:FindFirstChildWhichIsA("ProximityPrompt", true)
					if prompt and prompt.Enabled then
						return "AlienDrop"
					end
				end
			end
		end
	end
	if state.AutoShootEvent then
		return "Combat"
	end
	if state.EnableFly then
		return "ManualFly"
	end
	return "None"
end

local function collectCompostSeeds()
	local results = {}
	local function scan(container)
		if not container then
			return
		end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("InventoryCategory") == "Seeds" then
				local plantName = normalizePlantName(tool:GetAttribute("Plant") or tool.Name)
				if matchesSeedFilter(plantName, state.TargetCompostSeed, state.TargetCompostRarity) then
					local level = tostring(tool:GetAttribute("Level") or 1)
					local mutation = tostring(tool:GetAttribute("Mutation") or "Normal")
					local seedKey = plantName .. "_" .. level .. "_" .. mutation
					table.insert(results, { tool = tool, seedKey = seedKey, plantName = plantName })
				end
			end
		end
	end
	scan(LocalPlayer:FindFirstChild("Backpack"))
	scan(LocalPlayer.Character)
	return results
end

local function findEventEnemies()
	local results = {}
	local events = workspace:FindFirstChild("InteractiveEvents")
	local rush = events and events:FindFirstChild("PlantRush")
	local runtimeFolder = rush and rush:FindFirstChild("Runtime")
	if not runtimeFolder then
		return results
	end
	for _, model in ipairs(runtimeFolder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("PlantRushId") then
			local hp = model:GetAttribute("HP")
			if hp and hp > 0 then
				local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
				if part then
					table.insert(results, {
						Instance = part,
						Model = model,
						Type = model:GetAttribute("PlantRushType") or "Small",
					})
				end
			end
		end
	end
	return results
end

local function findRushDrops()
	local drops = {}
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local rushGui = playerGui and playerGui:FindFirstChild("PlantRush")
	if not rushGui then
		for _, desc in ipairs(workspace:GetDescendants()) do
			if desc:IsA("BasePart") and desc.Name:find("Drop") then
				table.insert(drops, desc)
			end
		end
		return drops
	end
	for _, desc in ipairs(workspace:GetDescendants()) do
		if (desc:IsA("BasePart") or desc:IsA("Model")) and desc.Name:lower():find("drop") then
			local prompt = desc:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt and prompt.Enabled then
				table.insert(drops, desc)
			end
		end
	end
	return drops
end

local function pickPriorityTarget(candidates, rootPosition)
	if #candidates == 0 then
		return nil
	end
	local best
	local bestScore = math.huge
	for _, entry in ipairs(candidates) do
		local part = entry.Instance or entry
		if part and part.Parent then
			local dist = (part.Position - rootPosition).Magnitude
			local score = dist
			if listContains(state.TargetEnemyPriority, "Medium (Huge)") and entry.Type == "Medium" then
				score = score - 1000
			end
			if listContains(state.TargetEnemyPriority, "Small (Normal)") and (entry.Type == "Small" or entry.Type == "Normal") then
				score = score - 500
			end
			if listContains(state.TargetEnemyPriority, "Boss (Full XP)") and entry.Type == "Boss" then
				score = score - 3000
			elseif listContains(state.TargetEnemyPriority, "Boss") and entry.Type == "Boss" then
				score = score - 2000
			end
			if score < bestScore then
				bestScore = score
				best = entry
			end
		end
	end
	return best or candidates[1]
end

local function stopFly()
	if runtime.flyConnection then
		runtime.flyConnection:Disconnect()
		runtime.flyConnection = nil
	end
	if runtime.flyBody then
		runtime.flyBody:Destroy()
		runtime.flyBody = nil
	end
	if runtime.flyGyro then
		runtime.flyGyro:Destroy()
		runtime.flyGyro = nil
	end
	if runtime.flyVelocity then
		runtime.flyVelocity:Destroy()
		runtime.flyVelocity = nil
	end
end

local function startFly()
	if runtime.flyConnection then
		return
	end
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	runtime.flyGyro = Instance.new("BodyGyro")
	runtime.flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	runtime.flyGyro.P = 9000
	runtime.flyGyro.Parent = root
	runtime.flyVelocity = Instance.new("BodyVelocity")
	runtime.flyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	runtime.flyVelocity.Parent = root
	runtime.flyConnection = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam or not root.Parent then
			return
		end
		local move = Vector3.new()
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			move = move + cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			move = move - cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			move = move - cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			move = move + cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			move = move + Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			move = move - Vector3.new(0, 1, 0)
		end
		local speed = state.FlySpeed or 50
		runtime.flyVelocity.Velocity = move.Magnitude > 0 and move.Unit * speed or Vector3.new()
		runtime.flyGyro.CFrame = cam.CFrame
	end)
	connections.fly = runtime.flyConnection
end

local function saveShooterConfig()
	if not PlantRushShooter then
		return
	end
	runtime.shooterSaved = {
		Damage = PlantRushShooter.Damage,
		ShotsPerSecond = PlantRushShooter.ShotsPerSecond,
		HitRadius = PlantRushShooter.HitRadius,
		ProjectileSpeed = PlantRushShooter.ProjectileSpeed,
		Cooldown = PlantRushShooter.Cooldown,
	}
end

local function boostShooter()
	if not PlantRushShooter then
		return
	end
	saveShooterConfig()
	PlantRushShooter.Damage = 99999
	PlantRushShooter.ShotsPerSecond = 25
	PlantRushShooter.HitRadius = 999
	PlantRushShooter.ProjectileSpeed = math.huge
	PlantRushShooter.Cooldown = 0
end

local function restoreShooter()
	if not PlantRushShooter or not runtime.shooterSaved then
		return
	end
	for key, value in pairs(runtime.shooterSaved) do
		PlantRushShooter[key] = value
	end
end

local function triggerAfkSpin()
	task.spawn(function()
		pcall(function()
			local afkFolder = Remotes and Remotes:FindFirstChild("AFKSpin")
			if not afkFolder then
				if RollSeedsRemote then
					RollSeedsRemote:FireServer()
				end
				return
			end
			local saveRemote = afkFolder:FindFirstChild("SaveSettings")
			local startRemote = afkFolder:FindFirstChild("Start")
			local stopRemote = afkFolder:FindFirstChild("Stop")
			if state.AutoBuySeed and saveRemote then
				local rarityMap = {}
				local allRarities = {
					"Common", "Uncommon", "Rare", "Epic", "Legendary",
					"Secret", "Prismatic", "Divine", "Exotic", "Transcended",
				}
				local anyRarity = listContains(state.TargetSeedRarity, "Any")
				for _, rarity in ipairs(allRarities) do
					rarityMap[rarity] = anyRarity or listContains(state.TargetSeedRarity, rarity)
				end
				callRemote(saveRemote, { Rarities = rarityMap, PauseOnRarity = false, AutoBuy = true })
				task.wait(0.5)
				if startRemote then
					callRemote(startRemote)
				end
			elseif stopRemote then
				if saveRemote then
					callRemote(saveRemote, { AutoBuy = false, PauseOnRarity = true })
					task.wait(0.15)
				end
				callRemote(stopRemote)
			end
		end)
	end)
end

local function getReplicator()
	if not DataReplicator then
		return nil
	end
	return DataReplicator.GetReplicator()
end

local function floorAllowed(floorName)
	if listContains(state.TargetUpgradeFloor, "All")
		or listContains(state.TargetUpgradeFloor, "Any")
		or listContains(state.TargetUpgradeFloor, "any") then
		return true
	end
	for _, target in ipairs(normalizedList(state.TargetUpgradeFloor)) do
		if tostring(target) == tostring(floorName) or tostring(target) == "Floor " .. tostring(floorName) then
			return true
		end
	end
	return false
end

local function statEnabled(statName)
	return listContains(state.TargetPlotStats, "Any") or listContains(state.TargetPlotStats, statName)
end

local function iterateDirtSlots(callback)
	if not runtime.playerPlot then
		return
	end
	for _, desc in ipairs(runtime.playerPlot:GetDescendants()) do
		if desc.Name == "FarmPlot" then
			for _, plotModel in ipairs(desc:GetChildren()) do
				if plotModel:IsA("Model") and plotModel.Name:match("^Plot%d+$") then
					local dirt = plotModel:FindFirstChild("Dirt")
					if dirt and dirt:IsA("BasePart") then
						callback(dirt, plotModel)
					end
				end
			end
		end
	end
end

local function getGearStock(gearFrame, gearName)
	if not gearFrame then
		return 0
	end
	local gearImage = gearFrame:FindFirstChild("GearImage")
	local rarityLabel = gearImage and gearImage:FindFirstChild("Rarity")
	if rarityLabel and rarityLabel:IsA("TextLabel") then
		local stock = tonumber((rarityLabel.Text or ""):match("Stock:%s*(%d+)"))
		return stock or 0
	end
	return 0
end

local function optimizePets()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not runtime.playerPlot or not DataAggregation then
		return
	end
	local replica = DataAggregation.GetReplica and DataAggregation.GetReplica()
		or (DataAggregation.WaitForReplica and DataAggregation.WaitForReplica())
	if not replica or not replica.Data or not replica.Data.PetInventory then
		return
	end
	local pets = {}
	for petKey, petData in pairs(replica.Data.PetInventory) do
		local mult = petData.EarningsMultiplier or petData.Multiplier or 1
		table.insert(pets, { key = petKey, mult = mult, data = petData })
	end
	table.sort(pets, function(a, b)
		return a.mult > b.mult
	end)
	local topKeys = {}
	for i = 1, math.min(4, #pets) do
		topKeys[pets[i].key] = true
	end
	for petKey in pairs(replica.Data.PetInventory) do
		if not topKeys[petKey] and UnequipPetRemote then
			pcall(function()
				UnequipPetRemote:FireServer(petKey)
			end)
		end
	end
	for i = 1, math.min(4, #pets) do
		local pet = pets[i]
		pcall(function()
			if EquipPetRemote then
				local sign = runtime.playerPlot:FindFirstChild("PlotUpgradeSign", true)
				if sign and sign:IsA("BasePart") then
					root.CFrame = sign.CFrame + Vector3.new(0, 3, 0)
					task.wait(0.4)
				end
				local tool = LocalPlayer.Backpack:FindFirstChild(pet.key)
					or LocalPlayer.Backpack:FindFirstChild(pet.data.Name or "")
				if tool then
					humanoid:EquipTool(tool)
					task.wait(0.3)
					EquipPetRemote:FireServer()
					task.wait(0.3)
					humanoid:UnequipTools()
				end
			end
		end)
	end
end

task.spawn(function()
	local attempts = 0
	while not runtime.playerPlot and state.HubRunning do
		if GetPlotRemote then
			pcall(function()
				runtime.playerPlot = GetPlotRemote:InvokeServer()
			end)
		end
		if not runtime.playerPlot then
			runtime.playerPlot = findOwnedPlotFromMap()
		end
		if not runtime.playerPlot then
			attempts = attempts + 1
			if attempts == 10 then
				warn("[Alleral] Still searching for plot...")
			end
			task.wait(0.5)
		end
	end
	if runtime.playerPlot then
		print("[Alleral] Plot locked:", runtime.playerPlot.Name)
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoPlaceSeed", 0.5, function()
	if not state.AutoPlaceSeed or not runtime.playerPlot then
		if runtime.plantingActive then
			runtime.plantingActive = false
			local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
		end
		return
	end
	runtime.plantingActive = true
	pcall(function()
		local tool = getBestPlaceSeedTool()
		if not tool then
			return
		end
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		iterateDirtSlots(function(dirt)
			if not state.AutoPlaceSeed then
				return
			end
			if isPlotSlotLocked(dirt) then
				return
			end
			if not plotLabelMatches(dirt) then
				return
			end
			if dirt:GetAttribute("PlantName") then
				return
			end
			humanoid:EquipTool(tool)
			PlantSeedRemote:FireServer(dirt)
			task.wait(0.1)
		end)
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoUnlockPlot", 0.1, function()
	if not state.AutoUnlockPlot or not runtime.playerPlot or not UnlockPlotRemote then
		return
	end
	if not (DataReplicator and SharedUtils and EconomyTuning) then
		return
	end
	local replicator = getReplicator()
	if not replicator then
		return
	end
	pcall(function()
		if replicator.GetSnapshot and not replicator:GetSnapshot() then
			replicator.Ready:Wait()
		end
		local snapshot = replicator:Snapshot()
		if not snapshot or not snapshot.FarmData then
			return
		end
		local cash = snapshot.Cash or 0
		local candidates = {}
		iterateDirtSlots(function(dirt)
			if isPlotSlotLocked(dirt) and not runtime.unlockCooldowns[dirt] then
				local label = getPlotLabel(dirt) or dirt:GetFullName()
				table.insert(candidates, { dirt = dirt, label = label })
			end
		end)
		table.sort(candidates, function(a, b)
			return a.label < b.label
		end)
		local target = candidates[1]
		if not target then
			return
		end
		local price = SharedUtils.CalculatePlotUnlockPrice(
			snapshot.FarmData,
			0,
			target.label,
			EconomyTuning.Get(LocalPlayer),
			runtime.playerPlot
		)
		if cash >= price then
			runtime.unlockCooldowns[target.dirt] = true
			UnlockPlotRemote:FireServer(target.dirt)
			task.delay(2.4, function()
				runtime.unlockCooldowns[target.dirt] = nil
			end)
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoSell", 0.15, function()
	if not state.AutoSell or not runtime.playerPlot then
		return
	end
	pcall(function()
		local cratePart = runtime.playerPlot:FindFirstChild("CratePosition", true)
		if not cratePart then
			return
		end
		local prompt = cratePart:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not prompt then
			return
		end
		local character = LocalPlayer.Character
		if not character then
			return
		end
		local tries = 0
		while not character:FindFirstChild("HeldCrates") and state.AutoSell and tries < 3 do
			if prompt.Enabled then
				firePrompt(prompt)
			end
			task.wait(0.05)
			tries = tries + 1
		end
		if character:FindFirstChild("HeldCrates") then
			SellCratesRemote:FireServer()
		end
	end)
	task.wait(state.SellDelay or 1)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoUpgradeSeed", 0.5, function()
	if not state.AutoUpgradeSeed or not runtime.playerPlot or not UpgradePlantRemote then
		return
	end
	pcall(function()
		local maxLevel = state.MaxUpgradeLevel or 10
		local bestDirt
		local bestLevel = math.huge
		iterateDirtSlots(function(dirt)
			if isPlotSlotLocked(dirt) then
				return
			end
			local plantName = dirt:GetAttribute("PlantName")
			if not plantName then
				return
			end
			local rarity = PlantsRegistry and PlantsRegistry[plantName] and PlantsRegistry[plantName].Rarity or "Unknown"
			if not matchesSeedFilter(plantName, state.TargetPlantAction, state.TargetPlantActionRarity) then
				return
			end
			local level = dirt:GetAttribute("PlantLevel") or 1
			if level < maxLevel and level < bestLevel then
				bestLevel = level
				bestDirt = dirt
			end
		end)
		if bestDirt then
			UpgradePlantRemote:InvokeServer(bestDirt)
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoRemoveSeed", 0.5, function()
	if not state.AutoRemoveSeed or not runtime.playerPlot or not RemovePlantRemote then
		return
	end
	pcall(function()
		iterateDirtSlots(function(dirt)
			local plantName = dirt:GetAttribute("PlantName")
			if not plantName then
				return
			end
			local rarity = PlantsRegistry and PlantsRegistry[plantName] and PlantsRegistry[plantName].Rarity or "Unknown"
			if matchesSeedFilter(plantName, state.TargetPlantAction, state.TargetPlantActionRarity) then
				RemovePlantRemote:FireServer(dirt)
				task.wait(0.05)
			end
		end)
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoDiscardSeed", 0.2, function()
	if not state.AutoDiscardSeed or not DiscardSeedRemote then
		return
	end
	pcall(function()
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local function tryDiscard(tool)
			if not tool or not tool:IsA("Tool") then
				return
			end
			local plantName = tool:GetAttribute("Plant") or tool.Name:match("^(.-)%s*[Ss]eed$") or tool.Name
			if matchesSeedFilter(plantName, state.TargetDiscardSeed, state.TargetDiscardSeedRarity) then
				if humanoid and tool.Parent ~= character then
					humanoid:EquipTool(tool)
				end
				DiscardSeedRemote:FireServer()
				task.wait(0.05)
			end
		end
		local held = character and character:FindFirstChildOfClass("Tool")
		if held then
			tryDiscard(held)
		end
		local backpack = LocalPlayer:FindFirstChild("Backpack")
		if backpack then
			for _, tool in ipairs(backpack:GetChildren()) do
				tryDiscard(tool)
			end
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoFertilizer", 0.5, function()
	if not state.AutoFertilizer or not runtime.playerPlot or not UseFertilizerRemote then
		return
	end
	pcall(function()
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local backpack = LocalPlayer:FindFirstChild("Backpack")
		if not humanoid then
			return
		end
		local targetDirt
		iterateDirtSlots(function(dirt)
			if targetDirt then
				return
			end
			if isPlotSlotLocked(dirt) then
				return
			end
			local plantName = dirt:GetAttribute("PlantName")
			if plantName and listMatches(state.TargetSprayPlant, plantName) and not dirt:GetAttribute("Fertilized") then
				targetDirt = dirt
			end
		end)
		if not targetDirt then
			return
		end
		local tool = findFertilizerTool(backpack, character)
		if not tool then
			return
		end
		humanoid:EquipTool(tool)
		UseFertilizerRemote:FireServer(targetDirt)
		task.wait(0.1)
		humanoid:UnequipTools()
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoSpray", 0.5, function()
	if not state.AutoSpray or not runtime.playerPlot or not UseSprayRemote then
		return
	end
	pcall(function()
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local backpack = LocalPlayer:FindFirstChild("Backpack")
		if not humanoid then
			return
		end
		local targetDirt
		iterateDirtSlots(function(dirt)
			if targetDirt then
				return
			end
			if isPlotSlotLocked(dirt) then
				return
			end
			local plantName = dirt:GetAttribute("PlantName")
			local mutation = dirt:GetAttribute("Mutation") or "Normal"
			if plantName and listMatches(state.TargetSprayPlant, plantName) and mutation == "Normal" then
				targetDirt = dirt
			end
		end)
		if not targetDirt then
			return
		end
		local tool = findSprayTool(backpack, character)
		if not tool then
			return
		end
		humanoid:EquipTool(tool)
		UseSprayRemote:FireServer(targetDirt)
		task.wait(0.1)
		humanoid:UnequipTools()
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "FarmUpgrades", 0.5, function()
	if not (state.AutoUpgradePlotStats or state.AutoUpgradeSeedRolls or state.AutoUpgradeSeedLuck or state.AutoExpandFarm) then
		return
	end
	if not DataReplicator then
		return
	end
	local replicator = getReplicator()
	if not replicator then
		return
	end
	pcall(function()
		local snapshot = replicator:Snapshot()
		if not snapshot then
			return
		end
		local cash = snapshot.Cash or 0
		if state.AutoUpgradeSeedRolls then
			UpgradeSeedRollsRemote:FireServer()
		end
		if state.AutoUpgradeSeedLuck then
			UpgradeSeedLuckRemote:FireServer()
		end
		if state.AutoExpandFarm then
			UpgradeFarmRemote:FireServer()
		end
		if state.AutoUpgradePlotStats and snapshot.FarmData and snapshot.FarmData.Floors then
			for floorName, floorData in pairs(snapshot.FarmData.Floors) do
				if floorAllowed(floorName) then
					if statEnabled("Saw Range") or state.AutoUpgradeSawRange then
						PlotUpgradeTransactionRemote:FireServer(floorName, "ExtraSawRange")
					end
					if statEnabled("Saw Yield") or state.AutoUpgradeSawYield then
						PlotUpgradeTransactionRemote:FireServer(floorName, "ExtraYield")
					end
					if statEnabled("Sprinkler Range") or state.AutoUpgradeSprinklerRange then
						PlotUpgradeTransactionRemote:FireServer(floorName, "ExtraSprinklerRange")
					end
					if statEnabled("Sprinkler Power") or state.AutoUpgradeSprinklerPower then
						PlotUpgradeTransactionRemote:FireServer(floorName, "ExtraPower")
					end
				end
			end
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoBuyGear", 0.5, function()
	if not state.AutoBuyGear or not GearTransactionRemote then
		return
	end
	pcall(function()
		local playerGui = LocalPlayer:WaitForChild("PlayerGui")
		local mainUi = playerGui:FindFirstChild("MainUI") or playerGui:FindFirstChild("Main")
		local menus = mainUi and mainUi:FindFirstChild("Menus")
		local gearFrame = menus and menus:FindFirstChild("GearShopFrame")
		local scrolling = gearFrame and gearFrame:FindFirstChild("ScrollingFrame")
		if not scrolling then
			return
		end
		for _, child in ipairs(scrolling:GetChildren()) do
			local gearName = child.Name
			if listMatches(state.TargetGear, gearName) then
				if getGearStock(child, gearName) > 0 then
					local ok = GearTransactionRemote:InvokeServer(gearName)
					if not ok then
						task.wait(8)
					end
				end
			end
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoBuyEgg", 0.5, function()
	if not (state.AutoBuyEgg or state.AutoUnlockEgg) then
		return
	end
	pcall(function()
		local merchant = workspace:FindFirstChild("PetMerchant")
		if not merchant then
			return
		end
		for _, desc in ipairs(merchant:GetDescendants()) do
			if desc:IsA("ProximityPrompt") then
				local slot = desc.Parent and desc.Parent.Name:match("Podium(%d+)")
				if state.AutoUnlockEgg and desc.ActionText == "Unlock" and slot then
					EggShopTransactionRemote:InvokeServer("UnlockSlot", tonumber(slot))
				end
				if state.AutoBuyEgg and desc.ActionText == "Buy Egg" then
					if listMatches(state.TargetEgg, desc.ObjectText or "") then
						firePrompt(desc)
						task.wait(0.3)
						RollEggRemote:FireServer()
					end
				end
			end
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoSubmitEventSeed", 0.5, function()
	if not state.AutoSubmitEventSeed then
		return
	end
	pcall(function()
		local submitPrompt
		for _, desc in ipairs(workspace:GetDescendants()) do
			if desc:IsA("ProximityPrompt") and desc.ActionText == "Submit Seed" then
				submitPrompt = desc
				break
			end
		end
		if not submitPrompt then
			return
		end
		local backpack = LocalPlayer:FindFirstChild("Backpack")
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not backpack or not humanoid then
			return
		end
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name:lower():find("seed") then
				local plantName = tool:GetAttribute("Plant") or tool.Name:match("^(.-)%s*[Ss]eed$") or tool.Name
				if matchesSeedFilter(plantName, state.TargetEventSeed, state.TargetEventSeedRarity) then
					humanoid:EquipTool(tool)
					firePrompt(submitPrompt)
					task.wait(0.5)
					break
				end
			end
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoBuyEventShop", 1, function()
	if not state.AutoBuyEventShop or not PlantRushBuyRemote then
		return
	end
	pcall(function()
		for _, itemId in ipairs(normalizedList(state.TargetEventItem)) do
			if itemId ~= "Any" then
				PlantRushBuyRemote:InvokeServer(itemId, 1)
				task.wait(0.2)
			end
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoComposter", 2, function()
	if not (state.AutoComposter and ComposterRequestStateRemote and ComposterInsertRemote and ComposterPullLeverRemote) then
		return
	end
	pcall(function()
		local floors = {}
		if listContains(state.TargetComposterFloor, "Any") then
			floors = { 2, 3, 4 }
		else
			for _, floorLabel in ipairs(normalizedList(state.TargetComposterFloor)) do
				local num = tonumber(tostring(floorLabel):match("(%d+)"))
				if num and num >= 2 and num <= 4 then
					table.insert(floors, num)
				end
			end
		end
		for _, floorIndex in ipairs(floors) do
			if CompostCooldownClient and CompostCooldownClient.IsOnCooldown and CompostCooldownClient.IsOnCooldown(floorIndex) then
				continue
			end
			local ok, compostState = pcall(function()
				return ComposterRequestStateRemote:InvokeServer(floorIndex)
			end)
			if ok and compostState then
				local tier = compostState.Tier or compostState.Value or 0
				if compostState.TooRich or tier >= (state.TargetComposterTier or 10) then
					if state.AutoPullLever then
						ComposterPullLeverRemote:FireServer(floorIndex)
					end
				else
					local seeds = collectCompostSeeds()
					if #seeds > 0 then
						ComposterInsertRemote:FireServer(floorIndex, seeds[1].seedKey)
					end
				end
			end
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "EventTargeting", 0.15, function()
	local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	runtime.eventCombatTarget = nil
	runtime.eventDropTarget = nil
	runtime.honeyTarget = nil
	if state.AutoShootEvent then
		local enemies = findEventEnemies()
		local picked = pickPriorityTarget(enemies, root.Position)
		if picked then
			runtime.eventCombatTarget = picked.Instance
		end
	end
	if state.AutoCollectRushDrops then
		local drops = findRushDrops()
		local bestDrop
		local bestDist = math.huge
		for _, drop in ipairs(drops) do
			local pos = drop:IsA("Model") and drop:GetPivot().Position or drop.Position
			local dist = (pos - root.Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestDrop = drop
			end
		end
		if bestDrop then
			runtime.eventDropTarget = bestDrop:IsA("BasePart") and bestDrop or bestDrop:FindFirstChildWhichIsA("BasePart", true)
		end
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "EventCombat", 0.2, function()
	if state.AutoShootEvent and runtime.eventCombatTarget then
		if not runtime.combatActive then
			runtime.combatActive = true
			boostShooter()
		end
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and runtime.eventCombatTarget.Parent then
			root.CFrame = CFrame.new(root.Position, runtime.eventCombatTarget.Position)
			local prompt = runtime.eventCombatTarget:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt then
				firePrompt(prompt)
			end
		end
	elseif state.AutoCollectRushDrops and runtime.eventDropTarget then
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(runtime.eventDropTarget.Position + Vector3.new(0, 3, 0))
		end
	else
		if runtime.combatActive then
			runtime.combatActive = false
			restoreShooter()
		end
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "HoneyEvents", 0.2, function()
	local mode = getActiveMode()
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if mode == "Honeycomb" then
		local events = workspace:FindFirstChild("InteractiveEvents")
		local honeycombs = events and events:FindFirstChild("QueenBee") and events.QueenBee:FindFirstChild("RuntimeHoneycombs")
		if honeycombs then
			local nearestPrompt
			local nearestDist = math.huge
			for _, part in ipairs(honeycombs:GetChildren()) do
				local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt and prompt.Enabled then
					local pos = part:IsA("Model") and part:GetPivot().Position or part.Position
					local dist = (pos - root.Position).Magnitude
					if dist < nearestDist then
						nearestDist = dist
						nearestPrompt = prompt
						root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
					end
				end
			end
			if nearestPrompt then
				firePrompt(nearestPrompt)
			end
		end
	elseif mode == "HoneyPot" then
		for _, desc in ipairs(workspace:GetDescendants()) do
			if desc:IsA("ProximityPrompt") and desc.ActionText:lower():find("roll") then
				firePrompt(desc)
				break
			end
		end
	elseif mode == "AlienDrop" then
		local events = workspace:FindFirstChild("InteractiveEvents")
		local invasion = events and events:FindFirstChild("AlienInvasion")
		if invasion then
			for _, drop in ipairs(invasion:GetChildren()) do
				if drop.Name:find("AlienDrop") then
					local prompt = drop:FindFirstChildWhichIsA("ProximityPrompt", true)
					if prompt and prompt.Enabled then
						local pos = drop:IsA("Model") and drop:GetPivot().Position or drop.Position
						root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
						firePrompt(prompt)
						break
					end
				end
			end
		end
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "EnableFly", 0.5, function()
	if getActiveMode() == "ManualFly" then
		startFly()
	else
		stopFly()
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoContract", 0.25, function()
	if not (state.AutoContractSubmit or state.AutoContractReroll) then
		return
	end
	if not (ContractSubmitRemote and ContractRerollRemote) then
		return
	end
	pcall(function()
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local backpack = LocalPlayer:FindFirstChild("Backpack")
		if not humanoid or not backpack then
			return
		end
		for slot = 1, 3 do
			if listMatches(state.TargetContractSlot, tostring(slot)) or listContains(state.TargetContractSlot, "Any") then
				local submitted = false
				for _, tool in ipairs(backpack:GetChildren()) do
					if tool:IsA("Tool") and tool:GetAttribute("InventoryCategory") == "Seeds" then
						local plantName = normalizePlantName(tool:GetAttribute("Plant") or tool.Name)
						if not listContains(state.IgnoreContractSeeds, plantName) then
							humanoid:EquipTool(tool)
							local ok, result = pcall(function()
								return ContractSubmitRemote:InvokeServer(slot)
							end)
							if ok and result ~= false then
								submitted = true
								break
							end
						end
					end
				end
				if not submitted and state.AutoContractReroll then
					pcall(function()
						ContractRerollRemote:InvokeServer(slot)
					end)
				end
			end
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoSellPet", 1.5, function()
	if not state.AutoSellPet or not DataAggregation or not SellPetRemote then
		return
	end
	pcall(function()
		local replica = DataAggregation.GetReplica and DataAggregation.GetReplica()
			or (DataAggregation.WaitForReplica and DataAggregation.WaitForReplica())
		if not replica or not replica.Data or not replica.Data.PetInventory then
			return
		end
		for petKey, petData in pairs(replica.Data.PetInventory) do
			local rarity = petData.Rarity or "Common"
			local name = petData.Name or petKey
			local liveTag = name .. " [Lvl " .. tostring(petData.Level or 1) .. "]"
			local rarityOk = #state.TargetSellPetRarity == 0 or listContains(state.TargetSellPetRarity, rarity)
			local nameOk = #state.TargetSellPetName == 0 or listContains(state.TargetSellPetName, name)
			local liveOk = #state.TargetSellPetLive == 0 or listContains(state.TargetSellPetLive, liveTag)
			if rarityOk and nameOk and liveOk and not petData.Equipped then
				SellPetRemote:InvokeServer(petKey)
				task.wait(0.2)
			end
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoOpenBox", 0.35, function()
	if not state.AutoOpenBox then
		return
	end
	pcall(function()
		local function tryOpen(container)
			if not container then
				return
			end
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and (tool.Name:lower():find("box") or tool.Name:lower():find("pack")) then
					local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:EquipTool(tool)
						if tool.Activate then
							tool:Activate()
						end
					end
				end
			end
		end
		tryOpen(LocalPlayer:FindFirstChild("Backpack"))
		tryOpen(LocalPlayer.Character)
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoClaimPlaytime", 15, function()
	if not state.AutoClaimPlaytime then
		return
	end
	pcall(function()
		local getState = Remotes:FindFirstChild("GetPlaytimeRewardState")
		local claim = Remotes:FindFirstChild("ClaimPlaytimeReward")
		if not getState or not claim then
			return
		end
		local ok, rewardState = pcall(function()
			return getState:InvokeServer()
		end)
		if ok and rewardState and rewardState.EarnedCount then
			for index = 1, rewardState.EarnedCount do
				if not rewardState["Claimed" .. index] then
					pcall(function()
						claim:InvokeServer(index)
					end)
					task.wait(0.3)
				end
			end
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoFeedPet", 0.5, function()
	if not state.AutoFeedPet or not UsePetTreatRemote then
		return
	end
	pcall(function()
		if not runtime.playerPlot then
			return
		end
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local backpack = LocalPlayer:FindFirstChild("Backpack")
		if not humanoid or not backpack then
			return
		end
		local treatTool
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and tool.Name:lower():find("treat") then
				if listMatches(state.TargetPetTreat, tool.Name) then
					treatTool = tool
					break
				end
			end
		end
		if not treatTool then
			return
		end
		for _, desc in ipairs(runtime.playerPlot:GetDescendants()) do
			if desc:IsA("Model") and desc:GetAttribute("PetKey") and not desc:GetAttribute("TreatBoosted") then
				if listMatches(state.TargetFeedPet, desc.Name) then
					humanoid:EquipTool(treatTool)
					UsePetTreatRemote:FireServer(desc)
					task.wait(0.2)
					humanoid:UnequipTools()
					break
				end
			end
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoBuySeed", state.RollDelay or 1, function()
	if not state.AutoBuySeed then
		runtime.afkSpinStarted = false
		return
	end
	if not runtime.afkSpinStarted then
		runtime.afkSpinStarted = true
		task.delay(8, triggerAfkSpin)
	end
	triggerAfkSpin()
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoRollManual", 0.1, function()
	if not state.AutoRollManual or not runtime.playerPlot then
		return
	end
	pcall(function()
		local held = getHeldToolsAtStands()
		local bought = false
		for standIndex = 1, 6 do
			local standTool = held[standIndex]
			if standTool and matchesSeedFilter(standTool.Name, state.TargetSeed, state.TargetSeedRarity) then
				local price = getSeedBuyPrice(standTool.Name)
				if getPlayerCash() >= price then
					BuySeedRemote:FireServer(standIndex)
					bought = true
					task.wait(0.25)
				end
			end
		end
		if not bought and RollSeedsRemote then
			RollSeedsRemote:FireServer()
			task.wait(state.RollDelay or 1)
		end
	end)
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoOptimizePets", 10, function()
	if state.AutoOptimizePets then
		pcall(optimizePets)
		task.wait(20)
	end
end)

local window = Core.buildUiWindow(ui, Core.uiWindowSettings({
	Subtitle = "Build A Ring Farm · v" .. VERSION,
	Icon = "leaf",
	Theme = "Default",
}))
if not window or not window._rawWindow then
	getgenv().Alleral_StartupFailed = "UI window failed"
	Core.logWarn("UI window failed — aborting")
	return
end
local section = Core.buildUiSection(window)
Core.buildExploitHub(section, {
	window = window,
	ui = ui,
	state = state,
	loops = loopControllers,
	version = VERSION,
	scriptId = "build_a_ring_farm",
	gameName = "Build A Ring Farm",
	gameStats = { Cash = tostring(getPlayerCash()), Plot = runtime.playerPlot and "Ready" or "Finding...", Planting = "Off" },
	statsTick = function(status)
		status:Update("Cash", tostring(getPlayerCash()))
		status:Update("Plot", runtime.playerPlot and tostring(runtime.playerPlot.Name or "Ready") or "Finding...")
		status:Update("Planting", state.AutoPlaceSeed and "On" or "Off")
	end,
	automationFlags = {
		{ key = "AutoPlaceSeed", label = "Plant" },
		{ key = "AutoSell", label = "Sell" },
		{ key = "AutoBuySeed", label = "Buy seeds" },
		{ key = "AutoRollManual", label = "Roll seeds" },
		{ key = "AutoFeedPet", label = "Feed pets" },
		{ key = "EnableFly", label = "Fly" },
		{ key = "AutoHoney", label = "Honey" },
		{ key = "AutoShootEvent", label = "Event shoot" },
	},
	saveFn = saveSettings,
})
local farmTab = Core.buildUiTab(section, "Farm", 10723407389, 2, "farm")
local seedTab = Core.buildUiTab(section, "Seeds", 10734923214, 2, "seeds")
local upgradeTab = Core.buildUiTab(section, "Upgrade", 10747376638, 2, "upgrade")
local shopTab = Core.buildUiTab(section, "Shop", 10734952479, 2, "shop")
local eventTab = Core.buildUiTab(section, "Events", 10709818534, 2, "events")
local petTab = Core.buildUiTab(section, "Pets", 10709769841, 2, "pets")
local miscTab = Core.buildUiTab(section, "Misc", 10734950020, 1, "misc")
local settingsTab = Core.buildUiTab(section, "Settings", 10734950309, 1, "settings")

local saveWrap = Core.onUiSave(saveSettings)
local plant = Core.buildUiGroup(farmTab, "Planting", 1, saveWrap, nil, "plant")
local plot = Core.buildUiGroup(farmTab, "Plot", 2, saveWrap, nil, "plot")
local sell = Core.buildUiGroup(farmTab, "Selling", 1, saveWrap, nil, "sell")
local care = Core.buildUiGroup(farmTab, "Spray & fert", 2, saveWrap, nil, "care")
local roll = Core.buildUiGroup(seedTab, "Roll & Buy", 1, saveWrap, nil, "roll")
local discard = Core.buildUiGroup(seedTab, "Discard", 2, saveWrap, nil, "discard")
local plantUp = Core.buildUiGroup(upgradeTab, "Plants", 1, saveWrap, nil, "plant_up")
local farmUp = Core.buildUiGroup(upgradeTab, "Farm & Plot", 2, saveWrap, nil, "farm_up")
local gearUp = Core.buildUiGroup(upgradeTab, "Gear Upgrades", 1, saveWrap, nil, "gear_up")
local gearShop = Core.buildUiGroup(shopTab, "Gear", 1, saveWrap, nil, "gear_shop")
local eggShop = Core.buildUiGroup(shopTab, "Eggs", 2, saveWrap, nil, "egg_shop")
local contracts = Core.buildUiGroup(shopTab, "Contracts", 1, saveWrap, nil, "contracts")
local eventSeed = Core.buildUiGroup(eventTab, "Event Seeds", 1, saveWrap, nil, "event_seed")
local eventShop = Core.buildUiGroup(eventTab, "Event Shop", 2, saveWrap, nil, "event_shop")
local eventCombat = Core.buildUiGroup(eventTab, "Events & drops", 1, saveWrap, nil, "event_combat")
local honey = Core.buildUiGroup(eventTab, "Honey", 2, saveWrap, nil, "honey")
local pets = Core.buildUiGroup(petTab, "Pets", 1, saveWrap, nil, "pet_auto")
local petSell = Core.buildUiGroup(petTab, "Sell Pets", 2, saveWrap, nil, "pet_sell")
local comp = Core.buildUiGroup(petTab, "Composter", 1, saveWrap, nil, "comp")
local fly = Core.buildUiGroup(miscTab, "Movement", 1, saveWrap, nil, "fly")
local util = Core.buildUiGroup(miscTab, "Utilities", 1, saveWrap, nil, "util")

local function bindToggle(group, label, key, tooltip)
	Core.bindToggle(state, saveSettings, group, label, key, { tooltip = tooltip })
end

local function bindSlider(group, label, minVal, maxVal, key)
	Core.bindSlider(state, saveSettings, group, label, minVal, maxVal, key, {})
end

bindToggle(plant, "Plant seeds", "AutoPlaceSeed", "Puts seeds from your bag onto empty plot spots.")
bindToggle(plant, "Clear plants", "AutoRemoveSeed", "Removes plants you don't want anymore.")
bindToggle(plant, "Upgrade plants", "AutoUpgradeSeed", "Levels up what's already planted.")
bindToggle(plot, "Unlock plots", "AutoUnlockPlot", "Buys new plot slots when you can afford them.")
bindToggle(plot, "Expand farm", "AutoExpandFarm", "Purchases the next farm expansion.")
bindToggle(sell, "Sell crates", "AutoSell", "Walks over and sells whatever you're holding.")
bindSlider(sell, "Wait between sells", 1, 10, "SellDelay")
bindToggle(care, "Auto spray", "AutoSpray", "Sprays your crops on a loop.")
bindToggle(care, "Auto fertilizer", "AutoFertilizer", "Fertilizes without you clicking.")
bindToggle(roll, "Buy seeds", "AutoBuySeed", "Grabs seeds from the shop.")
bindToggle(roll, "Roll seeds", "AutoRollManual", "Keeps rolling until you get something good.")
bindSlider(roll, "Roll wait (sec)", 1, 10, "RollDelay")
bindToggle(discard, "Toss bad seeds", "AutoDiscardSeed", "Discards seeds that don't match what you want.")
bindSlider(plantUp, "Stop upgrading at", 1, 50, "MaxUpgradeLevel")
bindToggle(plantUp, "Upgrade roll stat", "AutoUpgradeSeedRolls", "Puts points into seed roll upgrades.")
bindToggle(plantUp, "Upgrade luck stat", "AutoUpgradeSeedLuck", "Puts points into seed luck upgrades.")
bindToggle(farmUp, "Upgrade plot stats", "AutoUpgradePlotStats", "Buys plot stat upgrades.")
bindToggle(gearUp, "Saw range", "AutoUpgradeSawRange", "Upgrades saw reach.")
bindToggle(gearUp, "Saw yield", "AutoUpgradeSawYield", "Upgrades how much the saw gives.")
bindToggle(gearUp, "Sprinkler range", "AutoUpgradeSprinklerRange", "Upgrades sprinkler reach.")
bindToggle(gearUp, "Sprinkler power", "AutoUpgradeSprinklerPower", "Upgrades sprinkler strength.")
bindToggle(gearShop, "Buy gear", "AutoBuyGear", "Purchases gear upgrades from the shop.")
bindToggle(eggShop, "Buy eggs", "AutoBuyEgg", "Grabs eggs when you have the cash.")
bindToggle(eggShop, "Unlock eggs", "AutoUnlockEgg", "Unlocks egg types you haven't opened yet.")
bindToggle(contracts, "Turn in contracts", "AutoContractSubmit", "Submits finished contracts for you.")
bindToggle(contracts, "Reroll contracts", "AutoContractReroll", "Rerolls contracts you don't like.")
bindToggle(eventSeed, "Submit event seeds", "AutoSubmitEventSeed", "Hands in event seeds during events.")
bindToggle(eventShop, "Buy event shop", "AutoBuyEventShop", "Buys from the limited event shop.")
bindToggle(eventCombat, "Shoot event mobs", "AutoShootEvent", "Fights event enemies automatically.")
bindToggle(eventCombat, "Grab rush drops", "AutoCollectRushDrops", "Picks up rush event loot.")
bindToggle(eventCombat, "Grab alien drops", "AutoCollectAlienDrop", "Picks up alien event loot.")
bindToggle(honey, "Honey farm", "AutoHoney", "Runs the honey minigame for you.")
bindToggle(honey, "Roll honey", "AutoRollHoney", "Keeps rolling honey rewards.")
bindToggle(pets, "Feed pets", "AutoFeedPet", "Feeds your pets so they stay happy.")
bindToggle(pets, "Optimize pets", "AutoOptimizePets", "Equips your best pets and unequips the rest.")
bindToggle(petSell, "Sell pets", "AutoSellPet", "Sells pets you don't need.")
bindToggle(comp, "Run composter", "AutoComposter", "Tosses stuff into the composter.")
bindToggle(comp, "Pull lever", "AutoPullLever", "Pulls the composter lever when it's ready.")
bindToggle(fly, "Fly", "EnableFly", "Lets you fly around the map.")
bindSlider(fly, "Fly speed", 50, 500, "FlySpeed")
bindToggle(util, "Claim playtime", "AutoClaimPlaytime", "Grabs playtime rewards.")
bindToggle(util, "Open boxes", "AutoOpenBox", "Opens reward boxes in your inventory.")
util:CreateToggle("Anti AFK", state.AntiAFK, "So you don't get booted for sitting still.", function(value)
	state.AntiAFK = value
	if value then
		Core.setupAntiAfk(LocalPlayer)
	end
	saveSettings()
end)
util:CreateButton("Save now", saveSettings)

settingsTab:BuildThemeGroupbox(1)
Core.buildConfigProfileGroup(settingsTab, {
	state = state,
	savedKeys = savedKeys,
	saveFn = saveSettings,
	version = VERSION,
	column = 2,
})
Core.buildStandardSettingsExtras(settingsTab, Core.settingsExtrasOptions(window, ui, state, savedKeys, saveSettings, SETTINGS_FILE, VERSION, {
	gameId = "build_a_ring_farm",
}))

Core.finalizeGameUi(window, ui, {
	Subtitle = "Build A Ring Farm · v" .. VERSION,
})

state.Alleral_Unload = function()
	state.HubRunning = false
	stopFly()
	restoreShooter()
	for name, controller in pairs(loopControllers) do
		if controller then
			controller.enabled = false
		end
		loopControllers[name] = nil
	end
	for key, connection in pairs(connections) do
		if connection and connection.Disconnect then
			pcall(function()
				connection:Disconnect()
			end)
		end
		connections[key] = nil
	end
	for _, loopState in pairs(loops) do
		loopState.enabled = false
	end
end
