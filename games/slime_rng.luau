getgenv().Alleral_State = getgenv().Alleral_State or {}

if not getgenv().Alleral_Boot then
	warn("[Alleral] run loader.luau first")
	return
end
getgenv().Alleral_Boot = nil

local VERSION = "1.2"
local state = getgenv().Alleral_State
local Core = getgenv().Alleral_Core
local connections = {}
local loops = {}
local loopControllers = {}

if state.Alleral_Unload then
	pcall(state.Alleral_Unload)
end

local rayfield
local bootErr
local bootApi = getgenv().Alleral_Core
if not bootApi or not bootApi.prepareGame then
	local msg = "Core missing, run loader.luau first"
	getgenv().Alleral_StartupFailed = msg
	warn("[Alleral] " .. msg)
	return
end
Core, rayfield, bootErr = bootApi.prepareGame(state)
if not Core or not rayfield then
	local msg = "Boot failed: " .. tostring(bootErr)
	getgenv().Alleral_StartupFailed = msg
	warn("[Alleral] " .. msg)
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local SETTINGS_FILE = "slime_rng.json"
local defaults = {
	HubRunning = true,
	AutoBestArea = false,
	TargetZone = { "Any" },
	AutoRoll = false,
	AutoEquip = false,
	BestMode = { "Any" },
	AutoRebirth = false,
	RunSpeed = 16,
	AutoClaimIndex = false,
	TargetIndexCategory = { "Any" },
	AutoCollectLoot = false,
	TargetLoot = { "Any" },
	AutoGun = false,
	ShootPriority = { "Closest" },
	TargetType = { "Any" },
	AutoUpgradeTree = false,
	TargetTree = { "Any" },
	AutoUnlockMachine = false,
	AutoCollectRecipes = false,
	AutoCraft = false,
	TargetCraft = { "Any" },
	AutoFeedPet = false,
	FeedSlime = { "Best" },
	FeedFood = { "Any" },
	AutoPotion = false,
	TargetPotion = { "Any" },
	PotionMaxUses = 1,
	PotionTracker = {},
	AutoFruit = false,
	TargetSlimeFruit = { "Best" },
	TargetFruit = { "Any" },
	Noclip = false,
	FPSBoost = false,
	DisableMusic = false,
	Freecam = false,
	AntiAFK = true,
	LastTeleportedZone = nil,
	PreviousKnownMaxZone = nil,
}

local savedKeys = {
	"AutoBestArea",
	"TargetZone",
	"AutoRoll",
	"AutoEquip",
	"BestMode",
	"AutoRebirth",
	"RunSpeed",
	"AutoClaimIndex",
	"TargetIndexCategory",
	"AutoCollectLoot",
	"TargetLoot",
	"AutoGun",
	"ShootPriority",
	"TargetType",
	"AutoUpgradeTree",
	"TargetTree",
	"AutoUnlockMachine",
	"AutoCollectRecipes",
	"AutoCraft",
	"TargetCraft",
	"AutoFeedPet",
	"FeedSlime",
	"FeedFood",
	"AutoPotion",
	"TargetPotion",
	"PotionMaxUses",
	"AutoFruit",
	"TargetSlimeFruit",
	"TargetFruit",
	"Noclip",
	"FPSBoost",
	"DisableMusic",
	"Freecam",
	"AntiAFK",
}

for key, value in pairs(defaults) do
	if state[key] == nil then
		state[key] = value
	end
end

Core.loadSettings(state, savedKeys, SETTINGS_FILE)

local function saveSettings()
	Core.saveSettings(state, savedKeys, SETTINGS_FILE)
end

local function resetSettings()
	local env = getgenv and getgenv() or {}
	if type(env.delfile) == "function" then
		pcall(env.delfile, "Alleral_Configs/" .. SETTINGS_FILE)
	end
	for key, value in pairs(defaults) do
		state[key] = value
	end
	state.PotionTracker = {}
	saveSettings()
end

local function listContains(list, value)
	if not list or #list == 0 then
		return false
	end
	return table.find(list, value) ~= nil
end

local function listMatches(list, value)
	if not list or #list == 0 then
		return true
	end
	if listContains(list, "Any") then
		return true
	end
	return listContains(list, value)
end

local function getRemoteFunction(serviceName)
	local packages = ReplicatedStorage:FindFirstChild("Packages")
	local index = packages and packages:FindFirstChild("_Index")
	if not index then
		return nil
	end
	for _, child in ipairs(index:GetChildren()) do
		local networker = child:FindFirstChild("networker")
		if networker then
			local remotes = networker:FindFirstChild("_remotes")
			local serviceFolder = remotes and remotes:FindFirstChild(serviceName)
			local remote = serviceFolder and serviceFolder:FindFirstChild("RemoteFunction")
			if remote then
				return remote
			end
		end
	end
	return nil
end

local dataClient
pcall(function()
	dataClient = require(ReplicatedStorage.Packages.DataService).client
end)

local function waitForGameData(maxAttempts)
	for _ = 1, maxAttempts or 10 do
		if dataClient and type(dataClient.get) == "function" then
			local inventory = dataClient:get("inventory")
			local zone = dataClient:get("maxZone") or dataClient:get("zone")
			if inventory and zone then
				return true
			end
		end
		task.wait(0.5)
	end
	warn("[Alleral] Timeout loading Slime RNG data.")
	return false
end

task.spawn(function()
	waitForGameData(10)
end)

local Zones
pcall(function()
	Zones = require(ReplicatedStorage.Source.Game.Items.Zones)
end)

local UpgradeServiceUtils
pcall(function()
	UpgradeServiceUtils = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeServiceUtils)
end)

local GoopGunServiceClient
pcall(function()
	GoopGunServiceClient = require(ReplicatedStorage.Source.Features.GoopGun.GoopGunServiceClient)
end)

local UpgradeTree
pcall(function()
	UpgradeTree = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeTree)
end)

local GameplayServiceClient
pcall(function()
	GameplayServiceClient = require(ReplicatedStorage.Source.Features.Gameplay.GameplayServiceClient)
end)

local Mutations
pcall(function()
	Mutations = require(ReplicatedStorage.Source.Features.Mutations.Mutations)
end)

local InventoryServiceUtils
pcall(function()
	InventoryServiceUtils = require(ReplicatedStorage.Source.Features.Inventory.InventoryServiceUtils)
end)

local XpTransferServiceUtils
pcall(function()
	XpTransferServiceUtils = require(ReplicatedStorage.Source.Features.XpTransfer.XpTransferServiceUtils)
end)

local CraftingServiceUtils
pcall(function()
	CraftingServiceUtils = require(ReplicatedStorage.Source.Features.Crafting.CraftingServiceUtils)
end)

local InventoryItemUtils
pcall(function()
	InventoryItemUtils = require(ReplicatedStorage.Source.Features.Inventory.InventoryItemUtils)
end)

local SlimeUpgradeTree
pcall(function()
	SlimeUpgradeTree = require(ReplicatedStorage.Source.Features.Upgrades.SlimeUpgradeTree)
end)

local Slimes
pcall(function()
	Slimes = require(ReplicatedStorage.Source.Game.Items.Slimes)
end)

local Recipes
pcall(function()
	Recipes = require(ReplicatedStorage.Source.Features.Crafting.Recipes)
end)

local Food
pcall(function()
	Food = require(ReplicatedStorage.Source.Game.Items.Food)
end)

local Fruits
pcall(function()
	Fruits = require(ReplicatedStorage.Source.Game.Items.Fruits)
end)

local LootServiceUtils
pcall(function()
	LootServiceUtils = require(ReplicatedStorage.Source.Features.Loot.LootServiceUtils)
end)

local IndexRewards
pcall(function()
	IndexRewards = require(ReplicatedStorage.Source.Features.Index.IndexRewards)
end)

local zonesList = { "Any" }
local function refreshZones()
	if not Zones or not Zones.getMaxZone or not Zones.getZone then
		return
	end
	zonesList = { "Any" }
	for zoneId = 1, Zones.getMaxZone() do
		local zone = Zones.getZone(zoneId)
		if zone and zone.name then
			table.insert(zonesList, zone.name)
		end
	end
end
refreshZones()

local function zoneIdFromName(name)
	local numeric = tonumber(tostring(name):match("%d+"))
	if numeric then
		return numeric
	end
	if not Zones or not Zones.getMaxZone or not Zones.getZone then
		return nil
	end
	for zoneId = 1, Zones.getMaxZone() do
		local zone = Zones.getZone(zoneId)
		if zone and zone.name == name then
			return zoneId
		end
	end
	return nil
end

local lootList = { "Any" }
local lootIdToName = {}
if LootServiceUtils and LootServiceUtils.getDefinitions then
	for _, loot in ipairs(LootServiceUtils.getDefinitions()) do
		if loot.name and loot.id then
			table.insert(lootList, loot.name)
			lootIdToName[loot.id] = loot.name
		end
	end
end
if Fruits and Fruits.getSortedFruits then
	for _, fruit in ipairs(Fruits.getSortedFruits()) do
		if fruit.name and fruit.id then
			table.insert(lootList, fruit.name)
			lootIdToName[fruit.id] = fruit.name
		end
	end
end
table.sort(lootList, function(a, b)
	if a == "Any" then
		return true
	end
	if b == "Any" then
		return false
	end
	return a < b
end)

local treeList = { "Any" }
if UpgradeTree then
	for name in pairs(UpgradeTree) do
		if type(name) == "string" then
			table.insert(treeList, name)
		end
	end
	table.sort(treeList, function(a, b)
		if a == "Any" then
			return true
		end
		if b == "Any" then
			return false
		end
		return a < b
	end)
end

local indexCategoryList = { "Any" }
if IndexRewards then
	for category in pairs(IndexRewards) do
		table.insert(indexCategoryList, category)
	end
	table.sort(indexCategoryList, function(a, b)
		if a == "Any" then
			return true
		end
		if b == "Any" then
			return false
		end
		return a < b
	end)
end

local bestModeList = { "Any", "Damage", "DPS", "Level", "XP", "Base Power", "Health", "Rarity", "Mutation" }
local shootPriorityList = { "Closest", "Lowest HP", "Highest HP", "Max HP" }
local targetTypeList = { "Any", "Normal", "Huge", "Golden", "Diamond", "Shiny" }

local craftTargets = { "Any" }
if Recipes and Recipes.getRecipes and Slimes and Slimes.getSlime then
	for _, recipe in ipairs(Recipes.getRecipes()) do
		if recipe.outputId then
			local slime = Slimes.getSlime(recipe.outputId)
			if slime and slime.name then
				table.insert(craftTargets, slime.name)
			end
		end
	end
	table.sort(craftTargets, function(a, b)
		if a == "Any" then
			return true
		end
		if b == "Any" then
			return false
		end
		return a < b
	end)
end

local foodList = { "Any" }
local foodNameToId = {}
if Food and Food.getSortedFoods then
	for _, entry in ipairs(Food.getSortedFoods()) do
		if entry.name and entry.id then
			table.insert(foodList, entry.name)
			foodNameToId[entry.name] = entry.id
		end
	end
	table.sort(foodList, function(a, b)
		if a == "Any" then
			return true
		end
		if b == "Any" then
			return false
		end
		return a < b
	end)
end

local slimeNameList = { "Best", "Any" }
local function refreshSlimeNameList()
	if not dataClient or not InventoryServiceUtils or not Mutations or not Slimes then
		return
	end
	slimeNameList = { "Best", "Any" }
	local inventory = dataClient:get("inventory")
	if not inventory then
		return
	end
	for slimeKey, slimeValue in pairs(inventory) do
		local slimeData = InventoryServiceUtils.getSlimeData(slimeKey, slimeValue)
		local slimeInfo = slimeData and Slimes.getSlime(slimeData.id)
		if slimeInfo and slimeInfo.name then
			local displayName = Mutations.getDisplayName(slimeInfo.name, slimeData.mutations)
			if type(slimeValue) == "number" then
				displayName = displayName .. " x" .. slimeValue
			else
				displayName = displayName .. " [Lv " .. tostring(slimeData.level or 1) .. "]"
			end
			table.insert(slimeNameList, displayName)
		end
	end
	table.sort(slimeNameList, function(a, b)
		if a == "Best" then
			return true
		end
		if b == "Best" then
			return false
		end
		if a == "Any" then
			return true
		end
		if b == "Any" then
			return false
		end
		return a < b
	end)
end
refreshSlimeNameList()

local potionList = { "Any" }
local potionNameToId = {}
if InventoryItemUtils and InventoryItemUtils.getDefinition then
	for _, potionId in ipairs({ "luck", "ultraLuck", "currency", "rollSpeed" }) do
		local definition = InventoryItemUtils.getDefinition(potionId)
		if definition and definition.name then
			table.insert(potionList, definition.name)
			potionNameToId[definition.name] = potionId
		end
	end
	table.sort(potionList, function(a, b)
		if a == "Any" then
			return true
		end
		if b == "Any" then
			return false
		end
		return a < b
	end)
end

local fruitList = { "Any" }
local fruitUnlockInfo = {}
if Fruits and Fruits.getSortedFruits then
	local originDependency = UpgradeServiceUtils and UpgradeServiceUtils.enums and UpgradeServiceUtils.enums.originDependency
	for _, fruit in ipairs(Fruits.getSortedFruits()) do
		if fruit.name and fruit.treeId then
			table.insert(fruitList, fruit.name)
			local tree = (SlimeUpgradeTree or UpgradeTree) and (SlimeUpgradeTree or UpgradeTree)[fruit.treeId]
			if tree then
				for nodeId, node in pairs(tree) do
					if node.dependency == originDependency then
						fruitUnlockInfo[fruit.name] = {
							id = fruit.id,
							treeId = fruit.treeId,
							originNodeId = nodeId,
						}
						break
					end
				end
			end
		end
	end
	table.sort(fruitList, function(a, b)
		if a == "Any" then
			return true
		end
		if b == "Any" then
			return false
		end
		return a < b
	end)
end

local runtime = {
	freecamPart = nil,
	freecamConnection = nil,
	freecamSubject = nil,
	aimlockConnection = nil,
	noclipConnection = nil,
	fpsBackup = nil,
	musicBackup = {},
	rollFailCount = 0,
	lastGunShot = 0,
}

local function setFPSBoost(enabled)
	if enabled then
		if not runtime.fpsBackup then
			runtime.fpsBackup = {
				GlobalShadows = Lighting.GlobalShadows,
				QualityLevel = settings().Rendering.QualityLevel,
			}
		end
		Lighting.GlobalShadows = false
		pcall(function()
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		end)
	else
		if runtime.fpsBackup then
			Lighting.GlobalShadows = runtime.fpsBackup.GlobalShadows
			pcall(function()
				settings().Rendering.QualityLevel = runtime.fpsBackup.QualityLevel
			end)
			runtime.fpsBackup = nil
		end
	end
end

local function setMusicMuted(enabled)
	if enabled then
		runtime.musicBackup = {}
		for _, sound in ipairs(game:GetDescendants()) do
			if sound:IsA("Sound") then
				runtime.musicBackup[sound] = sound.Volume
				sound.Volume = 0
			end
		end
	else
		for sound, volume in pairs(runtime.musicBackup) do
			if sound and sound.Parent then
				sound.Volume = volume
			end
		end
		runtime.musicBackup = {}
	end
end

local function setNoclip(enabled)
	if enabled and not runtime.noclipConnection then
		runtime.noclipConnection = RunService.Stepped:Connect(function()
			if not state.Noclip then
				return
			end
			local character = LocalPlayer.Character
			if not character then
				return
			end
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end)
		connections.noclip = runtime.noclipConnection
	elseif not enabled and runtime.noclipConnection then
		runtime.noclipConnection:Disconnect()
		runtime.noclipConnection = nil
	end
end

local function setFreecam(enabled)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if enabled then
		if not runtime.freecamPart then
			runtime.freecamPart = Instance.new("Part")
			runtime.freecamPart.Size = Vector3.new(1, 1, 1)
			runtime.freecamPart.Anchored = true
			runtime.freecamPart.CanCollide = false
			runtime.freecamPart.Transparency = 1
			runtime.freecamPart.Parent = workspace
		end
		local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if root then
			runtime.freecamPart.CFrame = root.CFrame
		end
		runtime.freecamSubject = camera.CameraSubject
		camera.CameraSubject = runtime.freecamPart
		if runtime.freecamConnection then
			runtime.freecamConnection:Disconnect()
		end
		runtime.freecamConnection = RunService.RenderStepped:Connect(function()
			local offset = Vector3.new()
			local frame = camera.CFrame
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				offset = offset + frame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				offset = offset - frame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				offset = offset - frame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				offset = offset + frame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.E) then
				offset = offset + Vector3.new(0, 1, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
				offset = offset - Vector3.new(0, 1, 0)
			end
			if offset.Magnitude > 0 then
				runtime.freecamPart.CFrame = runtime.freecamPart.CFrame + offset.Unit * 1.5
			end
		end)
		connections.freecam = runtime.freecamConnection
	else
		if runtime.freecamConnection then
			runtime.freecamConnection:Disconnect()
			runtime.freecamConnection = nil
		end
		if runtime.freecamSubject then
			camera.CameraSubject = runtime.freecamSubject
		else
			local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		if runtime.freecamPart then
			runtime.freecamPart:Destroy()
			runtime.freecamPart = nil
		end
	end
end

local function sanitizeDisplayName(name)
	if not name then
		return ""
	end
	local trimmed = string.gsub(name, "%s+x%d+$", "")
	return string.gsub(trimmed, "%s*%[Lv %d+.*%]$", "")
end

local function pickSlimeKey(targetList, inventory)
	if not InventoryServiceUtils or not Slimes or not Mutations then
		return nil
	end
	if listContains(targetList, "Best") then
		local bestKey
		local bestScore = -1
		for slimeKey, slimeValue in pairs(inventory) do
			local slimeData = InventoryServiceUtils.getSlimeData(slimeKey, slimeValue)
			local dps = InventoryServiceUtils.getDpsFromData(slimeData) or 0
			if dps > bestScore then
				bestScore = dps
				bestKey = slimeKey
			end
		end
		return bestKey
	end
	if listContains(targetList, "Any") then
		for slimeKey in pairs(inventory) do
			return slimeKey
		end
	end
	for slimeKey, slimeValue in pairs(inventory) do
		local slimeData = InventoryServiceUtils.getSlimeData(slimeKey, slimeValue)
		local slimeInfo = Slimes.getSlime(slimeData.id)
		if slimeInfo and slimeInfo.name then
			local displayName = Mutations.getDisplayName(slimeInfo.name, slimeData.mutations)
			if listContains(targetList, displayName) or listContains(targetList, sanitizeDisplayName(displayName)) then
				return slimeKey
			end
		end
	end
	return nil
end

local function getGunTarget()
	if not GameplayServiceClient or not GameplayServiceClient.gameplay then
		return nil
	end
	local enemies = GameplayServiceClient.gameplay.enemies
	if not enemies then
		return nil
	end
	local candidates = {}
	for _, enemy in pairs(enemies) do
		if enemy.model and enemy.health and enemy.health > 0 then
			table.insert(candidates, enemy)
		end
	end
	if #candidates == 0 then
		return nil
	end
	local filtered = {}
	local allowAny = listContains(state.TargetType, "Any")
	for _, enemy in ipairs(candidates) do
		if allowAny then
			table.insert(filtered, enemy)
		else
			local matches = false
			local mutations = enemy.mutations
			if listContains(state.TargetType, "Huge") and Mutations and Mutations.has and Mutations.has(mutations, "huge") then
				matches = true
			end
			if listContains(state.TargetType, "Golden") and Mutations and Mutations.has and Mutations.has(mutations, "golden") then
				matches = true
			end
			if listContains(state.TargetType, "Diamond") and Mutations and Mutations.has and Mutations.has(mutations, "diamond") then
				matches = true
			end
			if listContains(state.TargetType, "Shiny") and Mutations and Mutations.has and Mutations.has(mutations, "shiny") then
				matches = true
			end
			if listContains(state.TargetType, "Normal") and Mutations and Mutations.hasAny and not Mutations.hasAny(mutations) then
				matches = true
			end
			if matches then
				table.insert(filtered, enemy)
			end
		end
	end
	if #filtered == 0 then
		return nil
	end
	if listContains(state.ShootPriority, "Closest") then
		local character = LocalPlayer.Character
		if character then
			table.sort(filtered, function(a, b)
				local pos = character:GetPivot().Position
				return (pos - a.model:GetPivot().Position).Magnitude < (pos - b.model:GetPivot().Position).Magnitude
			end)
		end
	elseif listContains(state.ShootPriority, "Lowest HP") then
		table.sort(filtered, function(a, b)
			return a.health < b.health
		end)
	elseif listContains(state.ShootPriority, "Highest HP") then
		table.sort(filtered, function(a, b)
			return a.health > b.health
		end)
	elseif listContains(state.ShootPriority, "Max HP") then
		table.sort(filtered, function(a, b)
			return (a.maxHealth or 0) > (b.maxHealth or 0)
		end)
	end
	return filtered[1]
end

local function setAutoGun(enabled)
	if runtime.aimlockConnection then
		runtime.aimlockConnection:Disconnect()
		runtime.aimlockConnection = nil
	end
	if not enabled then
		pcall(function()
			if GoopGunServiceClient and GoopGunServiceClient.wrapper then
				GoopGunServiceClient.wrapper.isHoldingInput = false
			end
		end)
		return
	end
	task.spawn(function()
		task.wait(0.5)
		pcall(function()
			if not GoopGunServiceClient or not GoopGunServiceClient.wrapper then
				return
			end
			local wrapper = GoopGunServiceClient.wrapper
			if not wrapper._alleralAimlock then
				wrapper._alleralAimlock = true
				wrapper._getFireRay = function()
					local camera = workspace.CurrentCamera
					if not camera then
						return Ray.new(Vector3.new(), Vector3.new())
					end
					local origin = camera.CFrame.Position
					local target = getGunTarget()
					if target and target.model and target.model.PrimaryPart then
						local targetPos = target.model:GetPivot().Position + Vector3.new(0, 2, 0)
						local direction = targetPos - origin
						if direction.Magnitude > 0 then
							return Ray.new(origin, direction.Unit * 1000)
						end
					end
					return Ray.new(origin, camera.CFrame.LookVector * 1000)
				end
			end
			if not wrapper.isEquipped then
				wrapper:equip()
			end
			wrapper.isHoldingInput = true
		end)
	end)
	runtime.aimlockConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not GoopGunServiceClient or not GoopGunServiceClient.wrapper then
				return
			end
			local wrapper = GoopGunServiceClient.wrapper
			if not wrapper.isEquipped then
				wrapper:equip()
			end
			wrapper.isHoldingInput = true
			if tick() - runtime.lastGunShot > 0.15 then
				wrapper:onActivated()
				runtime.lastGunShot = tick()
			end
		end)
	end)
	connections.autoGun = runtime.aimlockConnection
end

local function equipBestSlimes()
	if state.equipLock then
		return
	end
	if not dataClient or not InventoryServiceUtils then
		return
	end
	local inventory = dataClient:get("inventory")
	if not inventory or next(inventory) == nil then
		return
	end
	local inventoryRemote = getRemoteFunction("InventoryService")
	if not inventoryRemote then
		return
	end
	state.equipLock = true
	local ok, err = pcall(function()
		local upgrades = dataClient:get("upgrades") or {}
		local slotCount = InventoryServiceUtils.getOwnedSlotCount(upgrades, 0) or 1
		local mode = state.BestMode[1] or "Any"
		local ranked = {}
		for slimeKey, slimeValue in pairs(inventory) do
			local slimeData = InventoryServiceUtils.getSlimeData(slimeKey, slimeValue)
			if slimeData then
				local stats = InventoryServiceUtils.getSlimeStatsFromData(slimeData)
				local damage = (stats and stats.damage) or 0
				local health = (stats and stats.health) or 0
				local dps = InventoryServiceUtils.getDpsFromData(slimeData) or 0
				local level = slimeData.level or 1
				local xp = InventoryServiceUtils.getAccumulatedXp(slimeData) or 0
				local rarity = InventoryServiceUtils.getRarity(slimeData) or 0
				local hasMutation = slimeData.mutations and next(slimeData.mutations) ~= nil
				local score
				if mode == "Damage" then
					score = damage
				elseif mode == "Health" then
					score = health
				elseif mode == "DPS" then
					score = dps
				elseif mode == "Level" then
					score = level
				elseif mode == "XP" then
					score = xp
				elseif mode == "Rarity" then
					score = rarity
				elseif mode == "Mutation" then
					score = (hasMutation and 10000000 or 0) + dps
				elseif mode == "Base Power" then
					score = (stats and stats.basePower) or damage
				else
					score = damage + health
				end
				local copies = type(slimeValue) == "number" and slimeValue or 1
				for _ = 1, copies do
					table.insert(ranked, { id = slimeKey, score = score, rarity = rarity })
				end
			end
		end
		table.sort(ranked, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end
			if a.rarity ~= b.rarity then
				return a.rarity > b.rarity
			end
			return a.id < b.id
		end)
		local targetEquip = {}
		for i = 1, math.min(slotCount, #ranked) do
			table.insert(targetEquip, ranked[i].id)
		end
		local equipped = dataClient:get("equipped") or {}
		local needsEquip = false
		if #equipped == #targetEquip then
			for i = 1, #targetEquip do
				if equipped[i] ~= targetEquip[i] then
					needsEquip = true
					break
				end
			end
		else
			needsEquip = true
		end
		if not needsEquip then
			return
		end
		for idx = #equipped, 1, -1 do
			pcall(function()
				inventoryRemote:InvokeServer("requestUnequip", idx)
			end)
			task.wait(0.08)
		end
		local waited = 0
		while #(dataClient:get("equipped") or {}) > 0 and waited < 0.75 do
			task.wait(0.05)
			waited = waited + 0.05
		end
		for _, slimeKey in ipairs(targetEquip) do
			pcall(function()
				inventoryRemote:InvokeServer("requestEquip", slimeKey)
			end)
			task.wait(0.08)
		end
	end)
	if not ok then
		warn("[Alleral] equipBestSlimes: " .. tostring(err))
	end
	state.equipLock = false
end

local function usePotionIfAvailable()
	if not dataClient then
		return
	end
	local items = dataClient:get("items") or {}
	local inventoryRemote = getRemoteFunction("InventoryService")
	if not inventoryRemote then
		return
	end
	local selectedPotion = state.TargetPotion[1] or "Any"
	local potionId
	if selectedPotion == "Any" then
		for name, id in pairs(potionNameToId) do
			if items[id] and items[id] > 0 then
				potionId = id
				selectedPotion = name
				break
			end
		end
	else
		potionId = potionNameToId[selectedPotion]
	end
	if not potionId or not items[potionId] or items[potionId] <= 0 then
		return
	end
	state.PotionTracker = state.PotionTracker or {}
	local usedCount = state.PotionTracker[selectedPotion] or 0
	if usedCount >= state.PotionMaxUses then
		return
	end
	local ok, result = pcall(function()
		return inventoryRemote:InvokeServer("requestUseItem", potionId)
	end)
	if ok and result == true then
		state.PotionTracker[selectedPotion] = usedCount + 1
	end
end

local function useFruitIfAvailable()
	if not dataClient or not InventoryServiceUtils then
		return
	end
	local items = dataClient:get("items") or {}
	local inventoryRemote = getRemoteFunction("InventoryService")
	if not inventoryRemote then
		return
	end
	local targetFruit = state.TargetFruit[1] or "Any"
	local fruitInfo = fruitUnlockInfo[targetFruit]
	if targetFruit == "Any" then
		for name, info in pairs(fruitUnlockInfo) do
			if info.id and items[info.id] and items[info.id] > 0 then
				fruitInfo = info
				targetFruit = name
				break
			end
		end
	end
	if not fruitInfo or not fruitInfo.id or not items[fruitInfo.id] or items[fruitInfo.id] <= 0 then
		return
	end
	local inventory = dataClient:get("inventory") or {}
	local slimeKey = pickSlimeKey(state.TargetSlimeFruit, inventory)
	if not slimeKey then
		return
	end
	local ok, result = pcall(function()
		return inventoryRemote:InvokeServer("requestUseFruit", fruitInfo.id, slimeKey)
	end)
	if ok and result == false then
		task.wait(0.5)
	end
end

LocalPlayer.CharacterAdded:Connect(function()
	state.LastTeleportedZone = nil
	state.PreviousKnownMaxZone = nil
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoFarmZone", 2, function()
	if not state.AutoBestArea then
		state.LastTeleportedZone = nil
		state.PreviousKnownMaxZone = nil
		return
	end
	if not dataClient then
		return
	end
	local currentMaxZone = tonumber(dataClient:get("maxZone") or dataClient:get("zone")) or 1
	if state.PreviousKnownMaxZone and currentMaxZone > state.PreviousKnownMaxZone then
		state.LastTeleportedZone = nil
	end
	state.PreviousKnownMaxZone = currentMaxZone
	local zoneRemote = getRemoteFunction("ZonesService")
	if not zoneRemote then
		return
	end
	if listContains(state.TargetZone, "Any") then
		pcall(function()
			zoneRemote:InvokeServer("requestPurchaseZone")
		end)
		if state.LastTeleportedZone ~= currentMaxZone then
			local ok = pcall(function()
				zoneRemote:InvokeServer("requestTeleportZone", currentMaxZone)
			end)
			if ok then
				state.LastTeleportedZone = currentMaxZone
			end
		end
	else
		for _, zoneName in ipairs(state.TargetZone) do
			local zoneId = zoneIdFromName(zoneName)
			if zoneId and state.LastTeleportedZone ~= zoneId then
				local ok = pcall(function()
					zoneRemote:InvokeServer("requestTeleportZone", zoneId)
				end)
				if ok then
					state.LastTeleportedZone = zoneId
				end
				break
			end
		end
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoRebirth", 1, function()
	if not state.AutoRebirth then
		return
	end
	local rebirthRemote = getRemoteFunction("RebirthService")
	if not rebirthRemote then
		return
	end
	local ok, result = pcall(function()
		return rebirthRemote:InvokeServer("requestRebirth")
	end)
	if ok then
		if result == true then
			task.wait(5)
		elseif result == "Not enough goop" then
			task.wait(30)
		elseif result == "Profile unavailable" then
			task.wait(10)
		else
			task.wait(15)
		end
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoClaimIndex", 3, function()
	if not state.AutoClaimIndex then
		return
	end
	local indexRemote = getRemoteFunction("IndexService")
	if not indexRemote then
		return
	end
	if listContains(state.TargetIndexCategory, "Any") then
		for _, category in ipairs({ "basic", "big", "huge", "shiny", "inverted" }) do
			pcall(function()
				indexRemote:InvokeServer("requestClaimReward", category)
			end)
			task.wait(0.5)
		end
	else
		for _, category in ipairs(state.TargetIndexCategory) do
			pcall(function()
				indexRemote:InvokeServer("requestClaimReward", category)
			end)
			task.wait(0.5)
		end
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "RunSpeed", 0.1, function()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.WalkSpeed ~= state.RunSpeed then
		humanoid.WalkSpeed = state.RunSpeed
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoRoll", 0.5, function()
	if not state.AutoRoll then
		return
	end
	local rollRemote = getRemoteFunction("RollService")
	if not rollRemote then
		return
	end
	local ok = pcall(function()
		rollRemote:InvokeServer("requestRoll")
	end)
	if ok then
		runtime.rollFailCount = 0
	else
		runtime.rollFailCount = runtime.rollFailCount + 1
		if runtime.rollFailCount >= 5 then
			task.wait(2)
			runtime.rollFailCount = 0
		end
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoEquip", 3, function()
	if state.AutoEquip then
		equipBestSlimes()
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoUpgradeTree", 1, function()
	if not state.AutoUpgradeTree then
		return
	end
	if not UpgradeTree or not UpgradeServiceUtils or not dataClient then
		return
	end
	local upgradeRemote = getRemoteFunction("UpgradeService")
	if not upgradeRemote then
		return
	end
	local upgrades = dataClient:get("upgrades") or {}
	local coins = dataClient:get("coins") or 0
	local rollCurrency = dataClient:get("rollCurrency") or 0
	local originDependency = UpgradeServiceUtils.enums and UpgradeServiceUtils.enums.originDependency
	local cheapest
	local cheapestCost = math.huge
	for treeName, tree in pairs(UpgradeTree) do
		if listMatches(state.TargetTree, treeName) and type(tree) == "table" then
			for nodeId, node in pairs(tree) do
				if type(node) == "table" and node.cost and node.dependency then
					local currency = node.cost.currency
					if currency == "slimeUpgradePoints" or (type(currency) == "string" and currency:find("Fruit")) then
						continue
					end
					local ownsNode = UpgradeServiceUtils.ownsUpgrade(nodeId, upgrades)
					local dependencyMet = node.dependency == originDependency
						or UpgradeServiceUtils.ownsUpgrade(node.dependency, upgrades)
					if not ownsNode and dependencyMet then
						local amount = node.cost.amount or math.huge
						local available = (currency == "coins" and coins)
							or (currency == "rollCurrency" and rollCurrency)
							or 0
						if available >= amount and amount < cheapestCost then
							cheapestCost = amount
							cheapest = nodeId
						end
					end
				end
			end
		end
	end
	if cheapest then
		upgradeRemote:InvokeServer("requestUnlock", cheapest)
		task.wait(0.5)
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoUnlockMachine", 5, function()
	if not state.AutoUnlockMachine then
		return
	end
	if not dataClient then
		return
	end
	local unlocks = dataClient:get("unlocks") or {}
	if CraftingServiceUtils and not CraftingServiceUtils.isMachineUnlocked(unlocks) then
		local craftingRemote = getRemoteFunction("CraftingService")
		if craftingRemote then
			local ok, result = pcall(function()
				return craftingRemote:InvokeServer("requestUnlockMachine")
			end)
			if ok and result then
				task.wait(5)
			end
		end
	end
	if XpTransferServiceUtils and not XpTransferServiceUtils.isMachineUnlocked(unlocks) then
		local xpRemote = getRemoteFunction("XpTransferService")
		if xpRemote then
			local ok, result = pcall(function()
				return xpRemote:InvokeServer("requestUnlockMachine")
			end)
			if ok and result then
				task.wait(5)
			end
		end
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoCollectLoot", 0.5, function()
	if not state.AutoCollectLoot then
		return
	end
	local lootFolder = workspace:FindFirstChild("Loot")
	local lootRemote = getRemoteFunction("LootService")
	if not lootFolder or not lootRemote then
		return
	end
	for _, loot in ipairs(lootFolder:GetChildren()) do
		if loot:IsA("Model") or loot:IsA("BasePart") then
			local lootId = loot:GetAttribute("lootId") or (loot:FindFirstChild("lootId") and loot.lootId.Value)
			local lootName = lootId and lootIdToName[lootId]
			if lootName and listMatches(state.TargetLoot, lootName) then
				local ok, result = pcall(function()
					return lootRemote:InvokeServer("requestCollect", loot.Name)
				end)
				if ok or result == "Loot not found" or result == "Loot expired" then
					pcall(function()
						loot:Destroy()
					end)
				end
				task.wait(0.1)
			end
		end
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoCollectRecipes", 5, function()
	if not state.AutoCollectRecipes then
		return
	end
	if not dataClient or not CraftingServiceUtils then
		return
	end
	local craftingRemote = getRemoteFunction("CraftingService")
	if not craftingRemote then
		return
	end
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local ownedRecipes = dataClient:get("craftingRecipes") or {}
	local zonesFolder = workspace:FindFirstChild("Zones")
	if not zonesFolder then
		return
	end
	local originalCFrame = root.CFrame
	local moved = false
	for _, zone in ipairs(zonesFolder:GetChildren()) do
		local recipe = zone:FindFirstChild("Recipe")
		if recipe then
			local recipeKey = CraftingServiceUtils.getRecipeKeyFromInstance(recipe)
			if recipeKey and not CraftingServiceUtils.isRecipeOwned(ownedRecipes, recipeKey) then
				local recipeCFrame = recipe:IsA("Model") and recipe:GetPivot() or recipe.CFrame
				if recipeCFrame then
					moved = true
					root.CFrame = recipeCFrame + Vector3.new(0, 3, 0)
					local ok = pcall(function()
						return craftingRemote:InvokeServer("requestClaimRecipe", recipeKey, recipe)
					end)
					if ok then
						ownedRecipes[recipeKey] = true
					end
				end
			end
		end
	end
	if moved then
		root.CFrame = originalCFrame
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoCraft", 3, function()
	if not state.AutoCraft then
		return
	end
	if not dataClient or not CraftingServiceUtils then
		return
	end
	local craftingRemote = getRemoteFunction("CraftingService")
	if not craftingRemote then
		return
	end
	local inventory = dataClient:get("inventory") or {}
	local ownedRecipes = dataClient:get("craftingRecipes") or {}
	local recipes = CraftingServiceUtils.getRecipes()
	local allowAny = listContains(state.TargetCraft, "Any")
	for _, recipe in ipairs(recipes) do
		if not state.AutoCraft then
			break
		end
		if CraftingServiceUtils.isRecipeOwned(ownedRecipes, recipe.id) then
			local matches = allowAny
			if not matches and Slimes and Slimes.getSlime then
				local slimeInfo = Slimes.getSlime(recipe.outputId)
				if slimeInfo and listContains(state.TargetCraft, slimeInfo.name) then
					matches = true
				end
			end
			if matches and CraftingServiceUtils.canCraftRecipe(recipe, inventory) then
				local plan = CraftingServiceUtils.getRecipeMatchPlan(recipe, inventory)
				if plan then
					local ingredients = {}
					for itemId, count in pairs(plan) do
						for _ = 1, count do
							table.insert(ingredients, itemId)
						end
					end
					local ok = pcall(function()
						return craftingRemote:InvokeServer("requestCraftRecipe", recipe.id, ingredients, 1)
					end)
					if ok then
						for itemId, count in pairs(plan) do
							if type(inventory[itemId]) == "number" then
								inventory[itemId] = math.max(0, inventory[itemId] - count)
								if inventory[itemId] == 0 then
									inventory[itemId] = nil
								end
							else
								inventory[itemId] = nil
							end
						end
						task.wait(0.5)
					end
				end
			end
		end
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoFeedPet", 1, function()
	if not state.AutoFeedPet then
		return
	end
	if not dataClient or not InventoryServiceUtils then
		return
	end
	local inventory = dataClient:get("inventory") or {}
	local items = dataClient:get("items") or {}
	local slimeKey = pickSlimeKey(state.FeedSlime, inventory)
	if not slimeKey then
		return
	end
	local foodId
	if listContains(state.FeedFood, "Any") then
		for itemId, count in pairs(items) do
			if type(count) == "number" and count > 0 then
				foodId = itemId
				break
			end
		end
	else
		for _, foodName in ipairs(state.FeedFood) do
			local candidate = foodNameToId[foodName]
			if candidate and items[candidate] and items[candidate] > 0 then
				foodId = candidate
				break
			end
		end
	end
	if not foodId then
		return
	end
	local inventoryRemote = getRemoteFunction("InventoryService")
	if inventoryRemote then
		local ok = pcall(function()
			return inventoryRemote:InvokeServer("requestUseFood", foodId, slimeKey, 1)
		end)
		if not ok then
			task.wait(2)
		end
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoPotion", 1.5, function()
	if state.AutoPotion then
		usePotionIfAvailable()
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoFruit", 2, function()
	if state.AutoFruit then
		useFruitIfAvailable()
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoGun", 0.5, function()
	if state.AutoGun then
		if not runtime.aimlockConnection then
			setAutoGun(true)
		end
	else
		if runtime.aimlockConnection then
			setAutoGun(false)
		end
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "Noclip", 0.5, function()
	setNoclip(state.Noclip)
end)

Core.makeSupervisor(state, loops, loopControllers, "FPSBoost", 1, function()
	setFPSBoost(state.FPSBoost)
end)

Core.makeSupervisor(state, loops, loopControllers, "DisableMusic", 1, function()
	setMusicMuted(state.DisableMusic)
end)

Core.makeSupervisor(state, loops, loopControllers, "Freecam", 0.5, function()
	if state.Freecam then
		if not runtime.freecamConnection then
			setFreecam(true)
		end
	else
		if runtime.freecamConnection then
			setFreecam(false)
		end
	end
end)

local window = Core.buildRayfieldWindow(rayfield, {
	Subtitle = "Slime RNG · v" .. VERSION,
})
local section = Core.buildRayfieldSection(window)
local mainTab = Core.buildRayfieldTab(section, "Main", 10723407389, 2, "main")
local autoTab = Core.buildRayfieldTab(section, "Auto", 10734923214, 2, "auto")
local inventoryTab = Core.buildRayfieldTab(section, "Inventory", 10709769841, 2, "inventory")
local miscTab = Core.buildRayfieldTab(section, "Misc", 10734950020, 2, "misc")
local settingsTab = Core.buildRayfieldTab(section, "Settings", 10734950309, 1, "settings")

local saveWrap = Core.onUiSave(saveSettings)
local zone = Core.buildRayfieldGroup(mainTab, "Zones", 1, saveWrap, nil, "zone")
local roll = Core.buildRayfieldGroup(mainTab, "Rolling", 2, saveWrap, nil, "roll")
local gun = Core.buildRayfieldGroup(mainTab, "Combat", 1, saveWrap, nil, "gun")
local tree = Core.buildRayfieldGroup(autoTab, "Skill tree", 1, saveWrap, nil, "tree")
local craft = Core.buildRayfieldGroup(autoTab, "Crafting", 2, saveWrap, nil, "craft")
local loot = Core.buildRayfieldGroup(autoTab, "Loot & index", 1, saveWrap, nil, "loot")
local pet = Core.buildRayfieldGroup(inventoryTab, "Feeding", 1, saveWrap, nil, "feed")
local potion = Core.buildRayfieldGroup(inventoryTab, "Potions", 2, saveWrap, nil, "potions")
local fruit = Core.buildRayfieldGroup(inventoryTab, "Fruit tree", 1, saveWrap, nil, "fruit")
local movement = Core.buildRayfieldGroup(miscTab, "Movement", 1, saveWrap, nil, "movement")
local performance = Core.buildRayfieldGroup(miscTab, "Lag fixes", 2, saveWrap, nil, "performance")
local visuals = Core.buildRayfieldGroup(miscTab, "Camera", 1, saveWrap, nil, "visuals")
local config = Core.buildRayfieldGroup(miscTab, "Save / reset", 2, nil, nil, "config")

local function addMultiDropdown(group, name, label, values, default, callback)
	group:AddDropdown(name, {
		Text = label,
		Values = values,
		Default = default,
		Multi = true,
		Searchable = true,
		Callback = function(selection)
			local picked = {}
			for item, enabled in pairs(selection) do
				if type(item) == "number" then
					if enabled ~= nil and enabled ~= false then
						table.insert(picked, tostring(enabled))
					end
				elseif enabled then
					table.insert(picked, tostring(item))
				end
			end
			callback(picked)
			saveSettings()
		end,
	})
end

addMultiDropdown(zone, "TargetZone", "Zones to farm", zonesList, state.TargetZone, function(value)
	state.TargetZone = value
end)
zone:CreateToggle("Farm best zone", state.AutoBestArea, "Farms your best unlocked zone.", function(value)
	state.AutoBestArea = value
	if value then
		state.LastTeleportedZone = nil
	end
end)
zone:CreateToggle("Auto rebirth", state.AutoRebirth, "Rebirths when you've got enough for it.", function(value)
	state.AutoRebirth = value
end)
zone:CreateToggle("Unlock machines", state.AutoUnlockMachine, "Opens crafting and XP transfer when you can.", function(value)
	state.AutoUnlockMachine = value
end)

roll:CreateToggle("Keep rolling", state.AutoRoll, "Spins for slimes on its own.", function(value)
	state.AutoRoll = value
end)
addMultiDropdown(roll, "BestMode", "Equip if you get", bestModeList, state.BestMode, function(value)
	state.BestMode = value
end)
roll:CreateToggle("Equip best", state.AutoEquip, "Swaps to your best slime based on the filter above.", function(value)
	state.AutoEquip = value
end)

addMultiDropdown(gun, "ShootPriority", "Shoot order", shootPriorityList, state.ShootPriority, function(value)
	state.ShootPriority = value
end)
addMultiDropdown(gun, "TargetType", "What to shoot", targetTypeList, state.TargetType, function(value)
	state.TargetType = value
end)
gun:CreateToggle("Auto shoot", state.AutoGun, "Fires at enemies for you.", function(value)
	state.AutoGun = value
	setAutoGun(value)
end)

addMultiDropdown(tree, "TargetTree", "Skill tree", treeList, state.TargetTree, function(value)
	state.TargetTree = value
end)
tree:CreateToggle("Upgrade tree", state.AutoUpgradeTree, "Buys the cheapest node it can afford.", function(value)
	state.AutoUpgradeTree = value
end)

addMultiDropdown(craft, "TargetCraft", "Craft target", craftTargets, state.TargetCraft, function(value)
	state.TargetCraft = value
end)
craft:CreateToggle("Auto craft", state.AutoCraft, "Trades your worst slimes in for what you picked above.", function(value)
	state.AutoCraft = value
end)
craft:CreateToggle("Grab recipes", state.AutoCollectRecipes, "Picks up recipe scrolls floating around.", function(value)
	state.AutoCollectRecipes = value
end)

addMultiDropdown(loot, "TargetLoot", "Loot to grab", lootList, state.TargetLoot, function(value)
	state.TargetLoot = value
end)
loot:CreateToggle("Collect loot", state.AutoCollectLoot, "Snags drops that match your filter.", function(value)
	state.AutoCollectLoot = value
end)
addMultiDropdown(loot, "TargetIndexCategory", "Index tab", indexCategoryList, state.TargetIndexCategory, function(value)
	state.TargetIndexCategory = value
end)
loot:CreateToggle("Claim index", state.AutoClaimIndex, "Grabs index rewards when they're ready.", function(value)
	state.AutoClaimIndex = value
end)

addMultiDropdown(pet, "FeedSlime", "Feed this slime", slimeNameList, state.FeedSlime, function(value)
	state.FeedSlime = value
end)
addMultiDropdown(pet, "FeedFood", "With this food", foodList, state.FeedFood, function(value)
	state.FeedFood = value
end)
pet:CreateToggle("Auto feed", state.AutoFeedPet, "Feeds the slime + food you picked.", function(value)
	state.AutoFeedPet = value
end)

addMultiDropdown(potion, "TargetPotion", "Potions to use", potionList, state.TargetPotion, function(value)
	state.TargetPotion = value
end)
potion:CreateSlider("Uses per potion", 1, 10, state.PotionMaxUses, function(value)
	state.PotionMaxUses = value
	state.PotionTracker = {}
end, "How many times to drink each one before moving on.")
potion:CreateToggle("Auto potion", state.AutoPotion, "Drinks potions from your list.", function(value)
	state.AutoPotion = value
end)

addMultiDropdown(fruit, "TargetSlimeFruit", "Fruit this slime", slimeNameList, state.TargetSlimeFruit, function(value)
	state.TargetSlimeFruit = value
end)
addMultiDropdown(fruit, "TargetFruit", "Fruit type", fruitList, state.TargetFruit, function(value)
	state.TargetFruit = value
end)
fruit:CreateToggle("Auto fruit", state.AutoFruit, "Unlocks fruit nodes on that slime's tree.", function(value)
	state.AutoFruit = value
end)

movement:CreateSlider("Walk speed", 16, 250, state.RunSpeed, function(value)
	state.RunSpeed = value
end, "Your run speed. Go wild if your executor allows it.")
movement:CreateToggle("Noclip", state.Noclip, "Walk through walls.", function(value)
	state.Noclip = value
	setNoclip(value)
end)

performance:CreateToggle("FPS boost", state.FPSBoost, "Turns off shadows and dials graphics down a bit.", function(value)
	state.FPSBoost = value
	setFPSBoost(value)
end)
performance:CreateToggle("Mute music", state.DisableMusic, "Kills in-game music.", function(value)
	state.DisableMusic = value
	setMusicMuted(value)
end)

visuals:CreateToggle("Freecam", state.Freecam, "Fly the camera with WASD + Q/E.", function(value)
	state.Freecam = value
	setFreecam(value)
end)

config:CreateButton("Save settings", function()
	saveSettings()
end)
config:CreateButton("Reset settings", function()
	resetSettings()
end)

performance:CreateToggle("Anti AFK", state.AntiAFK ~= false, "Stops Roblox from kicking you while you farm.", function(value)
	state.AntiAFK = value
	if value then
		Core.setupAntiAfk(LocalPlayer)
	end
end)

settingsTab:BuildThemeGroupbox(1)
Core.buildScriptStatusGroupbox(settingsTab, 1, "slime_rng", VERSION)
Core.buildRoScriptsSearch(settingsTab, 2, rayfield)

state.Alleral_Unload = function()
	Core.stopAutomation(state, connections, loopControllers, loops, function()
		setAutoGun(false)
		setFreecam(false)
		setNoclip(false)
		setFPSBoost(false)
		setMusicMuted(false)
	end)
end

saveSettings()
