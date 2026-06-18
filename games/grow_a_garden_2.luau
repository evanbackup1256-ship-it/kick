getgenv().Alleral_State = getgenv().Alleral_State or {}

local Core = getgenv().Alleral_Core
if not Core or not Core.assertLoader or not Core.assertLoader() then
	return
end

local VERSION = "2.1.0"
local PLACE_ID = 95204935687527
local state = getgenv().Alleral_State
local G = (Core and Core.Game) or getgenv().Alleral_GameHelpers or {}
local connections = {}
local loops = {}
local loopControllers = {}

local ui
local bootErr
Core, ui, bootErr = Core.boot(state)
if not Core or not ui then
	getgenv().Alleral_StartupFailed = bootErr or "boot failed"
	return
end
G = Core.Game or G

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local SETTINGS_FILE = "grow_a_garden_2.json"
local SETTINGS_EXCLUDE = { HubRunning = true, PlayerPlot = true }
local defaults = {
	HubRunning = true,
	AntiAFK = true,
	AAutoLoadConfig = false,
	AutoLoadProfile = "default",
	AutoPlantSeed = false,
	AutoPlantAllSeeds = false,
	AutoShovelSeed = false,
	AutoCollectSeeds = false,
	StopCollectWhenFull = true,
	AutoWateringCan = false,
	AutoSprinklerSystem = false,
	AutoBuySeedShop = false,
	AutoBuyCrate = false,
	AutoBuyGearShop = false,
	PlantSpeed = 1,
	PlantInterval = 1,
	ShovelInterval = 2,
	CollectInterval = 0.75,
	WaterAmount = 1,
	WaterDelay = 1.5,
	SprinklerAmount = 1,
	SprinklerDelay = 2,
	ShopInterval = 3,
	TargetSeeds = { "Any" },
	TargetRarities = { "Any" },
	TargetSprinklerSeeds = { "Any" },
	TargetSeedShop = { "Any" },
	TargetCrates = { "Any" },
	TargetGearShop = { "Any" },
	SprinklerVariant = "Any",
}

local savedKeys
local saveSettings
saveSettings, savedKeys = Core.initSettings(state, defaults, SETTINGS_FILE, SETTINGS_EXCLUDE)

local function notify(title, text, duration, notifyType)
	Core.notify(title, text, duration, notifyType)
end

local function waitChild(parent, name, timeout)
	if G.waitChild then return G.waitChild(parent, name, timeout) end
	return Core.waitChild(parent, name, timeout)
end

local function leaderstat(name)
	if G.leaderstatValue then return G.leaderstatValue(LocalPlayer, name) end
	local folder = LocalPlayer:FindFirstChild("leaderstats")
	local value = folder and folder:FindFirstChild(name)
	if value and (value:IsA("IntValue") or value:IsA("NumberValue") or value:IsA("StringValue")) then
		return tostring(value.Value)
	end
	return "?"
end

local runtime = { remotes = {}, timers = {}, playerPlot = nil }

local REMOTE_ALIASES = {
	PlantSeed = { "PlantSeed", "Plant", "PlantCrop", "PlantAll" },
	ShovelSeed = { "ShovelSeed", "Shovel", "RemoveSeed", "ClearSeed" },
	CollectSeed = { "CollectSeed", "CollectSeeds", "PickupSeed", "HarvestSeed" },
	Water = { "Water", "WateringCan", "UseWateringCan", "WaterPlot" },
	Sprinkler = { "Sprinkler", "PlaceSprinkler", "UseSprinkler", "SprinklerSystem" },
	BuySeed = { "BuySeed", "PurchaseSeed", "SeedShop", "BuySeedShop" },
	BuyCrate = { "BuyCrate", "PurchaseCrate", "CrateShop" },
	BuyGear = { "BuyGear", "PurchaseGear", "GearShop" },
}

local function refreshRemotes()
	runtime.remotes = G.indexRemotes and G.indexRemotes(ReplicatedStorage, runtime.remotes) or runtime.remotes
	local folder = waitChild(ReplicatedStorage, "Remotes", 3)
	if not folder then return end
	for key, names in pairs(REMOTE_ALIASES) do
		for _, name in ipairs(names) do
			local remote = folder:FindFirstChild(name)
			if remote then
				runtime.remotes[key] = remote
				break
			end
		end
	end
end
refreshRemotes()

local function fireKey(key, ...)
	local remote = runtime.remotes[key]
	if remote and G.fireRemote then return G.fireRemote(remote, ...) end
	if remote then
		local ok = pcall(function()
			if remote:IsA("RemoteEvent") then
				remote:FireServer(...)
			elseif remote:IsA("RemoteFunction") then
				remote:InvokeServer(...)
			end
		end)
		return ok
	end
	return G.probeRemote and G.probeRemote(runtime.remotes, REMOTE_ALIASES[key] or { key }, { ... }) or false
end

local function tickEvery(key, interval, fn)
	runtime.timers[key] = runtime.timers[key] or 0
	if tick() < runtime.timers[key] then return end
	runtime.timers[key] = tick() + interval
	fn()
end

local function resolvePlayerPlot()
	if runtime.playerPlot and runtime.playerPlot.Parent then return runtime.playerPlot end
	local plots = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("Farms") or Workspace:FindFirstChild("Gardens")
	if not plots then return nil end
	for _, plot in ipairs(plots:GetChildren()) do
		local owner = plot:GetAttribute("Owner") or plot:GetAttribute("UserId") or plot:GetAttribute("Player")
		if owner == LocalPlayer.Name or owner == LocalPlayer.UserId or owner == tostring(LocalPlayer.UserId) then
			runtime.playerPlot = plot
			state.PlayerPlot = plot.Name
			return plot
		end
	end
	local tagged = plots:FindFirstChild(LocalPlayer.Name)
	if tagged then
		runtime.playerPlot = tagged
		state.PlayerPlot = tagged.Name
		return tagged
	end
	return nil
end

local function inventoryFull()
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	local char = LocalPlayer.Character
	local count = 0
	if backpack then count += #backpack:GetChildren() end
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") then count += 1 end
		end
	end
	local max = LocalPlayer:GetAttribute("MaxInventory") or LocalPlayer:GetAttribute("InventoryCap") or 999
	return count >= max
end

local function selectionOk(selected, value)
	local list = Core.normalizeMultiSelection(selected)
	if #list == 0 or list[1] == "Any" then return true end
	local lower = string.lower(tostring(value or ""))
	for _, item in ipairs(list) do
		if string.lower(item) == lower then return true end
	end
	return false
end

local function plantTick()
	if not (state.AutoPlantSeed or state.AutoPlantAllSeeds) then return end
	local interval = math.max(0.25, (state.PlantInterval or 1) / math.max(state.PlantSpeed or 1, 0.1))
	tickEvery("plant", interval, function()
		if state.AutoPlantAllSeeds then
			fireKey("PlantSeed", "All")
			return
		end
		local seeds = Core.normalizeMultiSelection(state.TargetSeeds)
		if #seeds == 0 or seeds[1] == "Any" then
			fireKey("PlantSeed")
		else
			for _, seed in ipairs(seeds) do fireKey("PlantSeed", seed) end
		end
	end)
end

local function runAutomation()
	if not state.HubRunning then return end
	refreshRemotes()
	plantTick()

	if state.AutoShovelSeed then
		tickEvery("shovel", state.ShovelInterval or 2, function() fireKey("ShovelSeed") end)
	end
	if state.AutoCollectSeeds then
		tickEvery("collect", state.CollectInterval or 0.75, function()
			if state.StopCollectWhenFull and inventoryFull() then return end
			fireKey("CollectSeed")
		end)
	end
	if state.AutoWateringCan then
		tickEvery("water", state.WaterDelay or 1.5, function()
			for _ = 1, math.max(1, math.floor(state.WaterAmount or 1)) do
				fireKey("Water")
			end
		end)
	end
	if state.AutoSprinklerSystem then
		tickEvery("sprinkler", state.SprinklerDelay or 2, function()
			local seeds = Core.normalizeMultiSelection(state.TargetSprinklerSeeds)
			local variant = state.SprinklerVariant or "Any"
			for _ = 1, math.max(1, math.floor(state.SprinklerAmount or 1)) do
				if seeds[1] and seeds[1] ~= "Any" then
					for _, seed in ipairs(seeds) do fireKey("Sprinkler", seed, variant) end
				else
					fireKey("Sprinkler", variant)
				end
			end
		end)
	end
	if state.AutoBuySeedShop then
		tickEvery("seedShop", state.ShopInterval or 3, function()
			local targets = Core.normalizeMultiSelection(state.TargetSeedShop)
			if targets[1] == "Any" or #targets == 0 then fireKey("BuySeed") else
				for _, seed in ipairs(targets) do fireKey("BuySeed", seed) end
			end
		end)
	end
	if state.AutoBuyCrate then
		tickEvery("crate", state.ShopInterval or 3, function()
			local targets = Core.normalizeMultiSelection(state.TargetCrates)
			if targets[1] == "Any" or #targets == 0 then fireKey("BuyCrate") else
				for _, crate in ipairs(targets) do fireKey("BuyCrate", crate) end
			end
		end)
	end
	if state.AutoBuyGearShop then
		tickEvery("gear", state.ShopInterval or 3, function()
			local targets = Core.normalizeMultiSelection(state.TargetGearShop)
			if targets[1] == "Any" or #targets == 0 then fireKey("BuyGear") else
				for _, gear in ipairs(targets) do fireKey("BuyGear", gear) end
			end
		end)
	end
end

Core.makeSupervisor(state, loops, loopControllers, "mainLoop", 0.25, runAutomation)
if state.AntiAFK ~= false then Core.setupAntiAfk(LocalPlayer) end

local window = Core.buildUiWindow(ui, Core.uiWindowSettings({
	Subtitle = "Grow a Garden 2 · v" .. VERSION,
	Icon = "seedling",
	Theme = "Default",
}))
if not window or not window._rawWindow then
	getgenv().Alleral_StartupFailed = "UI window failed"
	return
end

local section = Core.buildUiSection(window)
Core.buildExploitHub(section, {
	window = window, ui = ui, state = state, loops = loopControllers,
	version = VERSION, scriptId = "grow_a_garden_2", gameName = "Grow a Garden 2",
	gameStats = { Coins = "?", Seeds = "?", Plot = "?" },
	statsTick = function(status)
		status:Update("Coins", leaderstat("Coins") or leaderstat("Money") or "?")
		status:Update("Seeds", leaderstat("Seeds") or "?")
		status:Update("Plot", (resolvePlayerPlot() and state.PlayerPlot) or "?")
	end,
	automationFlags = {
		{ key = "AutoPlantSeed", label = "Plant" },
		{ key = "AutoCollectSeeds", label = "Collect seeds" },
		{ key = "AutoWateringCan", label = "Water" },
		{ key = "AutoSprinklerSystem", label = "Sprinkler" },
	},
	saveFn = saveSettings,
	onRemoteScan = refreshRemotes,
})

local farmTab = Core.buildUiTab(section, "Farm", 10734923214, 2, "farm")
local waterTab = Core.buildUiTab(section, "Water", 10723407389, 1, "water")
local shopTab = Core.buildUiTab(section, "Shop", 10734952479, 1, "shop")
local settingsTab = Core.buildUiTab(section, "Settings", 10734950309, 1, "settings")
local saveWrap = Core.onUiSave(saveSettings)

local plantGroup = Core.buildUiGroup(farmTab, "Planting", 1, saveWrap, nil, "plant")
local collectGroup = Core.buildUiGroup(farmTab, "Seeds", 2, saveWrap, nil, "collect")
local waterGroup = Core.buildUiGroup(waterTab, "Watering Can", 1, saveWrap, nil, "water")
local sprinklerGroup = Core.buildUiGroup(waterTab, "Sprinkler", 2, saveWrap, nil, "sprinkler")
local seedShop = Core.buildUiGroup(shopTab, "Seed Shop", 1, saveWrap, nil, "seedshop")
local crateShop = Core.buildUiGroup(shopTab, "Crates", 2, saveWrap, nil, "crate")
local gearShop = Core.buildUiGroup(shopTab, "Gear", 1, saveWrap, nil, "gear")

plantGroup:CreateToggle("Auto plant seed", state.AutoPlantSeed, "Plants selected seeds on open slots.", function(v) state.AutoPlantSeed = v end)
plantGroup:CreateToggle("Auto plant all seeds", state.AutoPlantAllSeeds, "Plants every seed in inventory.", function(v) state.AutoPlantAllSeeds = v end)
plantGroup:CreateToggle("Auto shovel seed", state.AutoShovelSeed, "Removes unwanted planted seeds.", function(v) state.AutoShovelSeed = v end)
plantGroup:AddDropdown("Seed filter", {
	Text = "Seeds to plant",
	Values = { "Any", "Carrot", "Corn", "Tomato", "Wheat", "Pumpkin", "Common", "Rare", "Legendary" },
	Default = state.TargetSeeds, Multi = true,
	Callback = function(s) state.TargetSeeds = Core.normalizeMultiSelection(s) if #state.TargetSeeds == 0 then state.TargetSeeds = { "Any" } end end,
})
plantGroup:AddDropdown("Rarity filter", {
	Text = "Rarity",
	Values = { "Any", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" },
	Default = state.TargetRarities, Multi = true,
	Callback = function(s) state.TargetRarities = Core.normalizeMultiSelection(s) if #state.TargetRarities == 0 then state.TargetRarities = { "Any" } end end,
})
plantGroup:CreateSlider("Custom plant speed", 0.5, 5, state.PlantSpeed, function(v) state.PlantSpeed = v end, "Multiplier for plant loop speed.")
plantGroup:CreateSlider("Plant delay", 0.25, 5, state.PlantInterval, function(v) state.PlantInterval = v end, "Base seconds between plant attempts.")

collectGroup:CreateToggle("Auto collect seeds", state.AutoCollectSeeds, "Picks up seed drops on your plot.", function(v) state.AutoCollectSeeds = v end)
collectGroup:CreateToggle("Stop when inventory full", state.StopCollectWhenFull, "Pauses seed collection at cap.", function(v) state.StopCollectWhenFull = v end)
collectGroup:CreateSlider("Collect delay", 0.2, 5, state.CollectInterval, function(v) state.CollectInterval = v end, "Seconds between collection passes.")

waterGroup:CreateToggle("Auto watering can", state.AutoWateringCan, "Waters crops automatically.", function(v) state.AutoWateringCan = v end)
waterGroup:CreateSlider("Water amount", 1, 10, state.WaterAmount, function(v) state.WaterAmount = v end, "Uses per watering pass.")
waterGroup:CreateSlider("Water delay", 0.5, 10, state.WaterDelay, function(v) state.WaterDelay = v end, "Seconds between watering passes.")

sprinklerGroup:CreateToggle("Auto sprinkler system", state.AutoSprinklerSystem, "Places sprinklers on your plot.", function(v) state.AutoSprinklerSystem = v end)
sprinklerGroup:AddDropdown("Sprinkler seeds", {
	Text = "Seed selection",
	Values = { "Any", "Carrot", "Corn", "Tomato", "Wheat", "Pumpkin" },
	Default = state.TargetSprinklerSeeds, Multi = true,
	Callback = function(s) state.TargetSprinklerSeeds = Core.normalizeMultiSelection(s) if #state.TargetSprinklerSeeds == 0 then state.TargetSprinklerSeeds = { "Any" } end end,
})
sprinklerGroup:CreateDropdown("Sprinkler variant", { "Any", "Basic", "Advanced", "Golden", "Diamond" }, state.SprinklerVariant, function(v) state.SprinklerVariant = v end, "Sprinkler type to place.")
sprinklerGroup:CreateSlider("Sprinkler amount", 1, 10, state.SprinklerAmount, function(v) state.SprinklerAmount = v end, "Placements per pass.")
sprinklerGroup:CreateSlider("Sprinkler delay", 0.5, 15, state.SprinklerDelay, function(v) state.SprinklerDelay = v end, "Seconds between sprinkler passes.")

seedShop:CreateToggle("Auto buy seed shop", state.AutoBuySeedShop, "Purchases seeds from the shop.", function(v) state.AutoBuySeedShop = v end)
seedShop:AddDropdown("Target seeds", {
	Text = "Seeds to buy",
	Values = { "Any", "Carrot", "Corn", "Tomato", "Wheat", "Pumpkin" },
	Default = state.TargetSeedShop, Multi = true,
	Callback = function(s) state.TargetSeedShop = Core.normalizeMultiSelection(s) if #state.TargetSeedShop == 0 then state.TargetSeedShop = { "Any" } end end,
})

crateShop:CreateToggle("Auto buy crate", state.AutoBuyCrate, "Purchases crates from the shop.", function(v) state.AutoBuyCrate = v end)
crateShop:AddDropdown("Target crates", {
	Text = "Crates to buy",
	Values = { "Any", "Basic", "Premium", "Golden", "Diamond" },
	Default = state.TargetCrates, Multi = true,
	Callback = function(s) state.TargetCrates = Core.normalizeMultiSelection(s) if #state.TargetCrates == 0 then state.TargetCrates = { "Any" } end end,
})

gearShop:CreateToggle("Auto buy gear shop", state.AutoBuyGearShop, "Purchases gear upgrades.", function(v) state.AutoBuyGearShop = v end)
gearShop:AddDropdown("Target gear", {
	Text = "Gear to buy",
	Values = { "Any", "Shovel", "WateringCan", "Sprinkler", "Backpack", "Speed" },
	Default = state.TargetGearShop, Multi = true,
	Callback = function(s) state.TargetGearShop = Core.normalizeMultiSelection(s) if #state.TargetGearShop == 0 then state.TargetGearShop = { "Any" } end end,
})
gearShop:CreateSlider("Shop delay", 1, 15, state.ShopInterval, function(v) state.ShopInterval = v end, "Seconds between shop purchase attempts.")

settingsTab:BuildThemeGroupbox(1)
Core.buildConfigProfileGroup(settingsTab, {
	state = state, savedKeys = savedKeys, saveFn = saveSettings, version = VERSION, column = 1,
})
Core.buildStandardSettingsExtras(settingsTab, Core.settingsExtrasOptions(window, ui, state, savedKeys, saveSettings, SETTINGS_FILE, VERSION, {
	gameId = "grow_a_garden_2", placeId = PLACE_ID,
}))

Core.finalizeGameUi(window, ui, { Subtitle = "Grow a Garden 2 · v" .. VERSION })
saveSettings()

state.Alleral_Unload = function()
	state.HubRunning = false
	Core.stopAutomation(state, connections, loopControllers, loops)
end
