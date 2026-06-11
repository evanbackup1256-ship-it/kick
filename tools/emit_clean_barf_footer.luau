
local window = Core.buildRayfieldWindow(rayfield, {
	Name = "Alleral",
	Subtitle = "Build A Ring Farm · v" .. VERSION,
	Icon = 10723407389,
	LoadingEnabled = false,
})
local section = window:CreateTabSection("Alleral", true)
local farmTab = section:CreateTab({ Name = "Farm", Icon = 10723407389, Columns = 2 }, "farm")
local seedTab = section:CreateTab({ Name = "Seeds", Icon = 10734923214, Columns = 2 }, "seeds")
local upgradeTab = section:CreateTab({ Name = "Upgrade", Icon = 10747376638, Columns = 2 }, "upgrade")
local shopTab = section:CreateTab({ Name = "Shop", Icon = 10734952479, Columns = 2 }, "shop")
local eventTab = section:CreateTab({ Name = "Events", Icon = 10709818534, Columns = 2 }, "events")
local petTab = section:CreateTab({ Name = "Pets", Icon = 10709769841, Columns = 2 }, "pets")
local miscTab = section:CreateTab({ Name = "Misc", Icon = 10734950020, Columns = 1 }, "misc")

local plantGroup = farmTab:CreateGroupbox({ Name = "Planting", Column = 1 }, "plant")
local plotGroup = farmTab:CreateGroupbox({ Name = "Plot", Column = 2 }, "plot")
local sellGroup = farmTab:CreateGroupbox({ Name = "Selling", Column = 1 }, "sell")
local careGroup = farmTab:CreateGroupbox({ Name = "Spray & Fertilizer", Column = 2 }, "care")
local rollGroup = seedTab:CreateGroupbox({ Name = "Roll & Buy", Column = 1 }, "roll")
local discardGroup = seedTab:CreateGroupbox({ Name = "Discard", Column = 2 }, "discard")
local plantUpGroup = upgradeTab:CreateGroupbox({ Name = "Plants", Column = 1 }, "plant_up")
local farmUpGroup = upgradeTab:CreateGroupbox({ Name = "Farm & Plot", Column = 2 }, "farm_up")
local gearUpGroup = upgradeTab:CreateGroupbox({ Name = "Gear Upgrades", Column = 1 }, "gear_up")
local gearShopGroup = shopTab:CreateGroupbox({ Name = "Gear", Column = 1 }, "gear_shop")
local eggShopGroup = shopTab:CreateGroupbox({ Name = "Eggs", Column = 2 }, "egg_shop")
local contractGroup = shopTab:CreateGroupbox({ Name = "Contracts", Column = 1 }, "contracts")
local eventSeedGroup = eventTab:CreateGroupbox({ Name = "Event Seeds", Column = 1 }, "event_seed")
local eventShopGroup = eventTab:CreateGroupbox({ Name = "Event Shop", Column = 2 }, "event_shop")
local eventCombatGroup = eventTab:CreateGroupbox({ Name = "Combat & Drops", Column = 1 }, "event_combat")
local honeyGroup = eventTab:CreateGroupbox({ Name = "Honey", Column = 2 }, "honey")
local petAutoGroup = petTab:CreateGroupbox({ Name = "Pet Automation", Column = 1 }, "pet_auto")
local petSellGroup = petTab:CreateGroupbox({ Name = "Sell Pets", Column = 2 }, "pet_sell")
local compGroup = petTab:CreateGroupbox({ Name = "Composter", Column = 1 }, "comp")
local flyGroup = miscTab:CreateGroupbox({ Name = "Movement", Column = 1 }, "fly")
local utilGroup = miscTab:CreateGroupbox({ Name = "Utilities", Column = 1 }, "util")

local plant = Core.wrapUiGroup(plantGroup, saveSettings)
local plot = Core.wrapUiGroup(plotGroup, saveSettings)
local sell = Core.wrapUiGroup(sellGroup, saveSettings)
local care = Core.wrapUiGroup(careGroup, saveSettings)
local roll = Core.wrapUiGroup(rollGroup, saveSettings)
local discard = Core.wrapUiGroup(discardGroup, saveSettings)
local plantUp = Core.wrapUiGroup(plantUpGroup, saveSettings)
local farmUp = Core.wrapUiGroup(farmUpGroup, saveSettings)
local gearUp = Core.wrapUiGroup(gearUpGroup, saveSettings)
local gearShop = Core.wrapUiGroup(gearShopGroup, saveSettings)
local eggShop = Core.wrapUiGroup(eggShopGroup, saveSettings)
local contracts = Core.wrapUiGroup(contractGroup, saveSettings)
local eventSeed = Core.wrapUiGroup(eventSeedGroup, saveSettings)
local eventShop = Core.wrapUiGroup(eventShopGroup, saveSettings)
local eventCombat = Core.wrapUiGroup(eventCombatGroup, saveSettings)
local honey = Core.wrapUiGroup(honeyGroup, saveSettings)
local pets = Core.wrapUiGroup(petAutoGroup, saveSettings)
local petSell = Core.wrapUiGroup(petSellGroup, saveSettings)
local comp = Core.wrapUiGroup(compGroup, saveSettings)
local fly = Core.wrapUiGroup(flyGroup, saveSettings)
local util = Core.wrapUiGroup(utilGroup, saveSettings)

local function bindToggle(group, label, key, tooltip)
	group:CreateToggle(label, state[key], tooltip, function(value)
		state[key] = value
		saveSettings()
	end)
end

local function bindSlider(group, label, minVal, maxVal, key)
	group:CreateSlider(label, minVal, maxVal, state[key], function(value)
		state[key] = value
		saveSettings()
	end)
end

bindToggle(plant, "Auto Place Seed", "AutoPlaceSeed", "Places seeds from backpack onto plot")
bindToggle(plant, "Auto Remove Seed", "AutoRemoveSeed", "Removes plants matching filters")
bindToggle(plant, "Auto Upgrade Seed", "AutoUpgradeSeed", "Upgrades planted seeds")
bindToggle(plot, "Auto Unlock Plot", "AutoUnlockPlot", "Unlocks new plot slots")
bindToggle(plot, "Auto Expand Farm", "AutoExpandFarm", "Purchases farm expansion")
bindToggle(sell, "Auto Sell", "AutoSell", "Sells held crates at crate position")
bindSlider(sell, "Sell Delay", 1, 10, "SellDelay")
bindToggle(care, "Auto Spray", "AutoSpray", nil)
bindToggle(care, "Auto Fertilizer", "AutoFertilizer", nil)
bindToggle(roll, "Auto Buy Seed", "AutoBuySeed", nil)
bindToggle(roll, "Auto Roll Manual", "AutoRollManual", nil)
bindSlider(roll, "Roll Delay", 1, 10, "RollDelay")
bindToggle(discard, "Auto Discard Seed", "AutoDiscardSeed", nil)
bindSlider(plantUp, "Max Upgrade Level", 1, 50, "MaxUpgradeLevel")
bindToggle(plantUp, "Auto Upgrade Seed Rolls", "AutoUpgradeSeedRolls", nil)
bindToggle(plantUp, "Auto Upgrade Seed Luck", "AutoUpgradeSeedLuck", nil)
bindToggle(farmUp, "Auto Upgrade Plot Stats", "AutoUpgradePlotStats", nil)
bindToggle(gearUp, "Auto Upgrade Saw Range", "AutoUpgradeSawRange", nil)
bindToggle(gearUp, "Auto Upgrade Saw Yield", "AutoUpgradeSawYield", nil)
bindToggle(gearUp, "Auto Upgrade Sprinkler Range", "AutoUpgradeSprinklerRange", nil)
bindToggle(gearUp, "Auto Upgrade Sprinkler Power", "AutoUpgradeSprinklerPower", nil)
bindToggle(gearShop, "Auto Buy Gear", "AutoBuyGear", nil)
bindToggle(eggShop, "Auto Buy Egg", "AutoBuyEgg", nil)
bindToggle(eggShop, "Auto Unlock Egg", "AutoUnlockEgg", nil)
bindToggle(contracts, "Auto Contract Submit", "AutoContractSubmit", nil)
bindToggle(contracts, "Auto Contract Reroll", "AutoContractReroll", nil)
bindToggle(eventSeed, "Auto Submit Event Seed", "AutoSubmitEventSeed", nil)
bindToggle(eventShop, "Auto Buy Event Shop", "AutoBuyEventShop", nil)
bindToggle(eventCombat, "Auto Shoot Event", "AutoShootEvent", nil)
bindToggle(eventCombat, "Auto Collect Rush Drops", "AutoCollectRushDrops", nil)
bindToggle(eventCombat, "Auto Collect Alien Drop", "AutoCollectAlienDrop", nil)
bindToggle(honey, "Auto Honey", "AutoHoney", nil)
bindToggle(honey, "Auto Roll Honey", "AutoRollHoney", nil)
bindToggle(pets, "Auto Feed Pet", "AutoFeedPet", nil)
bindToggle(pets, "Auto Optimize Pets", "AutoOptimizePets", nil)
bindToggle(petSell, "Auto Sell Pet", "AutoSellPet", nil)
bindToggle(comp, "Auto Composter", "AutoComposter", nil)
bindToggle(comp, "Auto Pull Lever", "AutoPullLever", nil)
bindToggle(fly, "Enable Fly", "EnableFly", nil)
bindSlider(fly, "Fly Speed", 50, 500, "FlySpeed")
bindToggle(util, "Auto Claim Playtime", "AutoClaimPlaytime", nil)
bindToggle(util, "Auto Open Box", "AutoOpenBox", nil)
util:CreateToggle("Anti AFK", state.AntiAFK, "Bypass idle kick", function(value)
	state.AntiAFK = value
	if value then
		Core.setupAntiAfk(LocalPlayer)
	end
	saveSettings()
end)
util:CreateButton("Save Settings", saveSettings)

notify("Alleral", "Build A Ring Farm loaded")

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
