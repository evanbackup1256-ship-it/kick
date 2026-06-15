getgenv().Alleral_State = getgenv().Alleral_State or {}

local Core = getgenv().Alleral_Core
if not Core or not Core.assertLoader or not Core.assertLoader() then
	return
end

local VERSION = "1.0.0"
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
G = Core.Game or G

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local SETTINGS_FILE = "grow_a_garden_2.json"
local SETTINGS_EXCLUDE = {
	HubRunning = true,
	PlayerPlot = true,
}
local defaults = {
	HubRunning = true,
	AutoPlantSeeds = false,
	AutoHarvest = false,
	AutoSell = false,
	AntiAFK = true,
	PlantInterval = 1,
	HarvestInterval = 0.75,
	SellInterval = 2,
	TargetSeeds = { "Any" },
	TargetCrops = { "Any" },
	SellMode = "All",
}

local savedKeys
local saveSettings
saveSettings, savedKeys = Core.initSettings(state, defaults, SETTINGS_FILE, SETTINGS_EXCLUDE)

local function notify(title, text, duration, notifyType)
	Core.notify(title, text, duration, notifyType)
end

local function waitChild(parent, name, timeout)
	if G.waitChild then
		return G.waitChild(parent, name, timeout)
	end
	return Core.waitChild(parent, name, timeout)
end

local function leaderstat(name)
	if G.leaderstatValue then
		return G.leaderstatValue(LocalPlayer, name)
	end
	local folder = LocalPlayer:FindFirstChild("leaderstats")
	local value = folder and folder:FindFirstChild(name)
	if value and (value:IsA("IntValue") or value:IsA("NumberValue") or value:IsA("StringValue")) then
		return tostring(value.Value)
	end
	return "?"
end

local runtime = {
	remotes = {},
	playerPlot = nil,
	lastPlant = 0,
	lastHarvest = 0,
	lastSell = 0,
}

local function refreshRemotes()
	runtime.remotes = G.indexRemotes and G.indexRemotes(ReplicatedStorage, runtime.remotes) or runtime.remotes
	local remotesFolder = waitChild(ReplicatedStorage, "Remotes", 3)
	if remotesFolder then
		runtime.remotes.PlantSeed = remotesFolder:FindFirstChild("PlantSeed")
			or remotesFolder:FindFirstChild("Plant")
			or runtime.remotes.PlantSeed
		runtime.remotes.Harvest = remotesFolder:FindFirstChild("Harvest")
			or remotesFolder:FindFirstChild("PickCrop")
			or remotesFolder:FindFirstChild("CollectCrop")
			or runtime.remotes.Harvest
		runtime.remotes.Sell = remotesFolder:FindFirstChild("Sell")
			or remotesFolder:FindFirstChild("SellAll")
			or remotesFolder:FindFirstChild("SellCrops")
			or runtime.remotes.Sell
	end
end

refreshRemotes()

local function fireNamed(names, payloads)
	return G.probeRemote and G.probeRemote(runtime.remotes, names, payloads) or false
end

local function resolvePlayerPlot()
	if runtime.playerPlot and runtime.playerPlot.Parent then
		return runtime.playerPlot
	end
	local plots = Workspace:FindFirstChild("Plots")
		or Workspace:FindFirstChild("Farms")
		or Workspace:FindFirstChild("Gardens")
	if not plots then
		return nil
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local owner = plot:GetAttribute("Owner")
			or plot:GetAttribute("UserId")
			or plot:GetAttribute("Player")
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

local function plotSlots(plot)
	local slots = {}
	if not plot then
		return slots
	end
	for _, child in ipairs(plot:GetDescendants()) do
		if child:IsA("BasePart") then
			local lower = string.lower(child.Name)
			if string.find(lower, "plot") or string.find(lower, "soil") or string.find(lower, "slot") or string.find(lower, "patch") then
				table.insert(slots, child)
			end
		end
	end
	return slots
end

local function ripeCrops(plot)
	local crops = {}
	if not plot then
		return crops
	end
	for _, child in ipairs(plot:GetDescendants()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			local lower = string.lower(child.Name)
			if string.find(lower, "crop") or string.find(lower, "plant") or string.find(lower, "harvest") then
				local ready = child:GetAttribute("Ready")
					or child:GetAttribute("Ripe")
					or child:GetAttribute("Grown")
				if ready == true or ready == 1 or child:FindFirstChild("Ready") or child:FindFirstChild("HarvestPrompt") then
					table.insert(crops, child)
				end
			end
		end
	end
	return crops
end

local function plantSeedsTick()
	if not state.AutoPlantSeeds or not state.HubRunning then
		return
	end
	if tick() < runtime.lastPlant + (state.PlantInterval or 1) then
		return
	end
	runtime.lastPlant = tick()
	refreshRemotes()
	local plot = resolvePlayerPlot()
	local targets = Core.normalizeMultiSelection(state.TargetSeeds)
	if #targets == 0 then
		targets = { "Any" }
	end
	for _, seedName in ipairs(targets) do
		if seedName == "Any" then
			if not fireNamed({ "PlantSeed", "Plant", "PlantCrop" }) then
				for _, slot in ipairs(plotSlots(plot)) do
					fireNamed({ "PlantSeed", "Plant" }, { slot.Name })
				end
			end
		else
			fireNamed({ "PlantSeed", "Plant" }, { seedName })
		end
	end
end

local function harvestTick()
	if not state.AutoHarvest or not state.HubRunning then
		return
	end
	if tick() < runtime.lastHarvest + (state.HarvestInterval or 0.75) then
		return
	end
	runtime.lastHarvest = tick()
	refreshRemotes()
	local plot = resolvePlayerPlot()
	local targets = Core.normalizeMultiSelection(state.TargetCrops)
	if fireNamed({ "Harvest", "PickCrop", "CollectCrop", "HarvestAll" }) then
		return
	end
	for _, crop in ipairs(ripeCrops(plot)) do
		local cropName = crop.Name
		if #targets == 0 or targets[1] == "Any" or Core.listMatches and Core.listMatches(targets, cropName) then
			fireNamed({ "Harvest", "PickCrop", "CollectCrop" }, { cropName })
		end
	end
end

local function sellTick()
	if not state.AutoSell or not state.HubRunning then
		return
	end
	if tick() < runtime.lastSell + (state.SellInterval or 2) then
		return
	end
	runtime.lastSell = tick()
	refreshRemotes()
	local mode = state.SellMode or "All"
	if mode == "All" then
		fireNamed({ "SellAll", "Sell", "SellCrops", "SellInventory" })
	else
		fireNamed({ "Sell", "SellCrops" }, { mode })
	end
end

Core.makeSupervisor(state, loops, loopControllers, "plantSeeds", state.PlantInterval or 1, plantSeedsTick)
Core.makeSupervisor(state, loops, loopControllers, "harvest", state.HarvestInterval or 0.75, harvestTick)
Core.makeSupervisor(state, loops, loopControllers, "sell", state.SellInterval or 2, sellTick)

if state.AntiAFK ~= false then
	Core.setupAntiAfk(LocalPlayer)
end

local window = Core.buildUiWindow(ui, Core.uiWindowSettings({
	Subtitle = "Grow a Garden 2 · v" .. VERSION,
	Icon = "seedling",
	Theme = "Linoria",
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
	scriptId = "grow_a_garden_2",
	gameName = "Grow a Garden 2",
	gameStats = { Coins = "?", Crops = "?", Plot = "?" },
	statsTick = function(status)
		status:Update("Coins", leaderstat("Coins") or leaderstat("Money") or "?")
		status:Update("Crops", leaderstat("Crops") or leaderstat("Harvested") or "?")
		local plot = resolvePlayerPlot()
		status:Update("Plot", plot and plot.Name or "?")
	end,
	automationFlags = {
		{ key = "AutoPlantSeeds", label = "Plant seeds" },
		{ key = "AutoHarvest", label = "Harvest" },
		{ key = "AutoSell", label = "Sell" },
	},
	saveFn = saveSettings,
	onRemoteScan = function()
		refreshRemotes()
	end,
})
local farmTab = Core.buildUiTab(section, "Farm", 10734923214, 2, "farm")
local autoTab = Core.buildUiTab(section, "Auto", 10723407389, 2, "auto")
local settingsTab = Core.buildUiTab(section, "Settings", 10734950309, 1, "settings")

local saveWrap = Core.onUiSave(saveSettings)
local planting = Core.buildUiGroup(farmTab, "Planting", 1, saveWrap, nil, "plant")
local harvestGroup = Core.buildUiGroup(farmTab, "Harvest", 2, saveWrap, nil, "harvest")
local selling = Core.buildUiGroup(farmTab, "Selling", 1, saveWrap, nil, "sell")
local timing = Core.buildUiGroup(autoTab, "Timing", 1, saveWrap, nil, "timing")
local util = Core.buildUiGroup(autoTab, "Utilities", 2, saveWrap, nil, "util")

planting:CreateToggle("Auto plant seeds", state.AutoPlantSeeds, "Plants seeds on open plot slots.", function(enabled)
	state.AutoPlantSeeds = enabled
end)
planting:AddDropdown("Target seeds", {
	Text = "Seeds to plant",
	Values = { "Any", "Carrot", "Corn", "Tomato", "Wheat", "Pumpkin" },
	Default = state.TargetSeeds,
	Multi = true,
	Callback = function(selected)
		state.TargetSeeds = Core.normalizeMultiSelection(selected)
		if #state.TargetSeeds == 0 then
			state.TargetSeeds = { "Any" }
		end
	end,
})
planting:CreateSlider("Plant delay", 0.5, 5, state.PlantInterval, function(value)
	state.PlantInterval = value
end, "Seconds between plant attempts.")

harvestGroup:CreateToggle("Auto harvest", state.AutoHarvest, "Collects ripe crops from your plot.", function(enabled)
	state.AutoHarvest = enabled
end)
harvestGroup:AddDropdown("Target crops", {
	Text = "Crops to harvest",
	Values = { "Any", "Carrot", "Corn", "Tomato", "Wheat", "Pumpkin" },
	Default = state.TargetCrops,
	Multi = true,
	Callback = function(selected)
		state.TargetCrops = Core.normalizeMultiSelection(selected)
		if #state.TargetCrops == 0 then
			state.TargetCrops = { "Any" }
		end
	end,
})
harvestGroup:CreateSlider("Harvest delay", 0.25, 5, state.HarvestInterval, function(value)
	state.HarvestInterval = value
end, "Seconds between harvest passes.")

selling:CreateToggle("Auto sell", state.AutoSell, "Sells harvested crops for coins.", function(enabled)
	state.AutoSell = enabled
end)
selling:CreateDropdown("Sell mode", { "All", "Carrot", "Corn", "Tomato", "Wheat", "Pumpkin" }, state.SellMode, function(value)
	state.SellMode = value
end, "Which crops to sell when auto sell runs.")
selling:CreateSlider("Sell delay", 1, 10, state.SellInterval, function(value)
	state.SellInterval = value
end, "Seconds between sell attempts.")

util:CreateToggle("Anti AFK", state.AntiAFK ~= false, "Prevents idle kicks.", function(enabled)
	state.AntiAFK = enabled
	if enabled then
		Core.setupAntiAfk(LocalPlayer)
	end
end)
util:CreateButton("Refresh plot", function()
	runtime.playerPlot = nil
	local plot = resolvePlayerPlot()
	notify("Alleral", plot and ("Plot found: " .. plot.Name) or "No plot found yet.", 3)
end)
util:CreateButton("Scan remotes", function()
	refreshRemotes()
	local count = 0
	for _ in pairs(runtime.remotes) do
		count += 1
	end
	notify("Alleral", "Indexed " .. tostring(count) .. " remotes.", 3)
end)

local config = Core.buildUiGroup(settingsTab, "Save / reset", 1, nil, nil, "config")
config:CreateButton("Save now", saveSettings, "Write every toggle and slider to disk.")
config:CreateButton("Reset settings", function()
	local env = getgenv and getgenv() or {}
	if type(env.delfile) == "function" then
		pcall(env.delfile, "Alleral_Configs/" .. SETTINGS_FILE)
	end
	Core.mergeDefaults(state, defaults)
	for key in pairs(SETTINGS_EXCLUDE) do
		if key ~= "HubRunning" then
			state[key] = defaults[key]
		end
	end
	saveSettings()
	notify("Alleral", "Settings reset. Re-open the script to refresh the UI.", 5)
end, "Clears saved config and restores defaults.")

settingsTab:BuildThemeGroupbox(1)
Core.buildConfigProfileGroup(settingsTab, {
	state = state,
	savedKeys = savedKeys,
	saveFn = saveSettings,
	version = VERSION,
	column = 2,
})
Core.buildStandardSettingsExtras(settingsTab, Core.settingsExtrasOptions(window, ui, state, savedKeys, saveSettings, SETTINGS_FILE, VERSION, {
	gameId = "grow_a_garden_2",
	placeId = PLACE_ID,
}))

Core.finalizeGameUi(window, ui, {
	Subtitle = "Grow a Garden 2 · v" .. VERSION,
})

saveSettings()

state.Alleral_Unload = function()
	state.HubRunning = false
	Core.stopAutomation(state, connections, loopControllers, loops)
end
