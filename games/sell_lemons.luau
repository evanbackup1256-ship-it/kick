getgenv().Alleral_State = getgenv().Alleral_State or {}

local Core = getgenv().Alleral_Core
if not Core or not Core.assertLoader or not Core.assertLoader() then
	return
end

local VERSION = "1.0.0"
local PLACE_ID = 79268393072444
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

local SETTINGS_FILE = "sell_lemons.json"
local SETTINGS_EXCLUDE = {
	HubRunning = true,
	LastCashScan = true,
	LastStandClick = true,
}
local defaults = {
	HubRunning = true,
	AutoClickStand = false,
	AutoCollectCash = false,
	AutoBuyUpgrades = false,
	AutoRebirth = false,
	AntiAFK = true,
	ClickInterval = 0.15,
	CollectInterval = 0.5,
	UpgradeInterval = 2,
	RebirthInterval = 5,
	TargetUpgrades = { "Any" },
	CollectRadius = 80,
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

local function characterParts()
	if G.characterParts then
		return G.characterParts(LocalPlayer)
	end
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
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
	lastClick = 0,
	lastCollect = 0,
	lastUpgrade = 0,
	lastRebirth = 0,
}

local function refreshRemotes()
	runtime.remotes = G.indexRemotes and G.indexRemotes(ReplicatedStorage, runtime.remotes) or runtime.remotes
	local remotesFolder = waitChild(ReplicatedStorage, "Remotes", 3)
	if remotesFolder then
		runtime.remotes.ClickStand = remotesFolder:FindFirstChild("ClickStand")
			or remotesFolder:FindFirstChild("TapStand")
			or remotesFolder:FindFirstChild("SellLemon")
			or runtime.remotes.ClickStand
		runtime.remotes.CollectCash = remotesFolder:FindFirstChild("CollectCash")
			or remotesFolder:FindFirstChild("CollectBag")
			or remotesFolder:FindFirstChild("PickupCash")
			or runtime.remotes.CollectCash
		runtime.remotes.BuyUpgrade = remotesFolder:FindFirstChild("BuyUpgrade")
			or remotesFolder:FindFirstChild("PurchaseUpgrade")
			or remotesFolder:FindFirstChild("UpgradeStand")
			or runtime.remotes.BuyUpgrade
		runtime.remotes.Rebirth = remotesFolder:FindFirstChild("Rebirth")
			or remotesFolder:FindFirstChild("Prestige")
			or runtime.remotes.Rebirth
	end
end

refreshRemotes()

local function fireNamed(names, payloads)
	return G.probeRemote and G.probeRemote(runtime.remotes, names, payloads) or false
end

local function findStandPart()
	local stand = Workspace:FindFirstChild("Stand", true)
		or Workspace:FindFirstChild("LemonStand", true)
		or Workspace:FindFirstChild("MyStand", true)
	if stand and stand:IsA("BasePart") then
		return stand
	end
	if stand and stand:IsA("Model") then
		return stand.PrimaryPart or stand:FindFirstChildWhichIsA("BasePart")
	end
	local plots = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("PlayerPlots")
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			local owner = plot:GetAttribute("Owner") or plot:GetAttribute("UserId")
			if owner == LocalPlayer.Name or owner == LocalPlayer.UserId then
				return plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart")
			end
		end
	end
	return nil
end

local function cashBagParts()
	local list = {}
	local radius = tonumber(state.CollectRadius) or 80
	local _, _, root = characterParts()
	if not root then
		return list
	end
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local name = string.lower(descendant.Name)
			if string.find(name, "cash") or string.find(name, "bag") or string.find(name, "money") then
				if (descendant.Position - root.Position).Magnitude <= radius then
					table.insert(list, descendant)
				end
			end
		end
	end
	return list
end

local function clickStandTick()
	if not state.AutoClickStand or not state.HubRunning then
		return
	end
	if tick() < runtime.lastClick + (state.ClickInterval or 0.15) then
		return
	end
	runtime.lastClick = tick()
	refreshRemotes()
	local clicked = fireNamed({ "ClickStand", "TapStand", "SellLemon", "StandClick" }, { true })
	if not clicked then
		local stand = findStandPart()
		if stand and G.fireClickDetector then
			G.fireClickDetector(stand)
		end
	end
end

local function collectCashTick()
	if not state.AutoCollectCash or not state.HubRunning then
		return
	end
	if tick() < runtime.lastCollect + (state.CollectInterval or 0.5) then
		return
	end
	runtime.lastCollect = tick()
	refreshRemotes()
	local collected = fireNamed({ "CollectCash", "CollectBag", "PickupCash", "CollectAll" })
	if collected then
		return
	end
	local _, _, root = characterParts()
	if not root then
		return
	end
	for _, part in ipairs(cashBagParts()) do
		if G.touchPart then
			G.touchPart(root, part)
		elseif G.fireClickDetector then
			G.fireClickDetector(part)
		end
	end
end

local function buyUpgradesTick()
	if not state.AutoBuyUpgrades or not state.HubRunning then
		return
	end
	if tick() < runtime.lastUpgrade + (state.UpgradeInterval or 2) then
		return
	end
	runtime.lastUpgrade = tick()
	refreshRemotes()
	local targets = Core.normalizeMultiSelection(state.TargetUpgrades)
	if #targets == 0 then
		targets = { "Any" }
	end
	for _, upgradeName in ipairs(targets) do
		if upgradeName == "Any" then
			fireNamed({ "BuyUpgrade", "PurchaseUpgrade", "UpgradeStand", "BuyAllUpgrades" })
		else
			fireNamed({ "BuyUpgrade", "PurchaseUpgrade", "UpgradeStand" }, { upgradeName })
		end
	end
end

local function rebirthTick()
	if not state.AutoRebirth or not state.HubRunning then
		return
	end
	if tick() < runtime.lastRebirth + (state.RebirthInterval or 5) then
		return
	end
	runtime.lastRebirth = tick()
	refreshRemotes()
	fireNamed({ "Rebirth", "Prestige" })
end

Core.makeSupervisor(state, loops, loopControllers, "clickStand", state.ClickInterval or 0.15, clickStandTick)
Core.makeSupervisor(state, loops, loopControllers, "collectCash", state.CollectInterval or 0.5, collectCashTick)
Core.makeSupervisor(state, loops, loopControllers, "buyUpgrades", state.UpgradeInterval or 2, buyUpgradesTick)
Core.makeSupervisor(state, loops, loopControllers, "rebirth", state.RebirthInterval or 5, rebirthTick)

if state.AntiAFK ~= false then
	Core.setupAntiAfk(LocalPlayer)
end

local window = Core.buildUiWindow(ui, Core.uiWindowSettings({
	Subtitle = "Sell Lemons · v" .. VERSION,
	Icon = "lemon",
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
	scriptId = "sell_lemons",
	gameName = "Sell Lemons",
	gameStats = { Cash = "?", Lemons = "?", Rebirths = "?" },
	statsTick = function(status)
		status:Update("Cash", leaderstat("Cash") or leaderstat("Money") or "?")
		status:Update("Lemons", leaderstat("Lemons") or leaderstat("Lemon") or "?")
		status:Update("Rebirths", leaderstat("Rebirths") or leaderstat("Prestige") or "?")
	end,
	automationFlags = {
		{ key = "AutoClickStand", label = "Click stand" },
		{ key = "AutoCollectCash", label = "Collect cash" },
		{ key = "AutoBuyUpgrades", label = "Buy upgrades" },
		{ key = "AutoRebirth", label = "Rebirth" },
	},
	saveFn = saveSettings,
	onRemoteScan = function()
		refreshRemotes()
	end,
})
local mainTab = Core.buildUiTab(section, "Main", 10723407389, 2, "main")
local autoTab = Core.buildUiTab(section, "Auto", 10734923214, 2, "auto")
local shopTab = Core.buildUiTab(section, "Shop", 10734952479, 1, "shop")
local settingsTab = Core.buildUiTab(section, "Settings", 10734950309, 1, "settings")

local saveWrap = Core.onUiSave(saveSettings)
local farm = Core.buildUiGroup(mainTab, "Stand", 1, saveWrap, nil, "stand")
local cash = Core.buildUiGroup(mainTab, "Cash", 2, saveWrap, nil, "cash")
local loopsGroup = Core.buildUiGroup(autoTab, "Automation", 1, saveWrap, nil, "loops")
local shop = Core.buildUiGroup(shopTab, "Upgrades", 1, saveWrap, nil, "shop")
local util = Core.buildUiGroup(shopTab, "Utilities", 2, saveWrap, nil, "util")

farm:CreateToggle("Auto click stand", state.AutoClickStand, "Keeps tapping your lemonade stand.", function(enabled)
	state.AutoClickStand = enabled
end)
farm:CreateSlider("Click speed", 0.05, 1, state.ClickInterval, function(value)
	state.ClickInterval = value
end, "Seconds between stand clicks.")

cash:CreateToggle("Auto collect cash bags", state.AutoCollectCash, "Grabs nearby cash drops.", function(enabled)
	state.AutoCollectCash = enabled
end)
cash:CreateSlider("Collect radius", 20, 200, state.CollectRadius, function(value)
	state.CollectRadius = value
end, "How far to look for cash bags.")
cash:CreateSlider("Collect delay", 0.2, 3, state.CollectInterval, function(value)
	state.CollectInterval = value
end, "Seconds between collection passes.")

loopsGroup:CreateToggle("Auto buy upgrades", state.AutoBuyUpgrades, "Purchases stand upgrades when affordable.", function(enabled)
	state.AutoBuyUpgrades = enabled
end)
loopsGroup:CreateToggle("Auto rebirth", state.AutoRebirth, "Rebirths when requirements are met.", function(enabled)
	state.AutoRebirth = enabled
end)
loopsGroup:CreateSlider("Upgrade delay", 1, 10, state.UpgradeInterval, function(value)
	state.UpgradeInterval = value
end, "Seconds between upgrade attempts.")
loopsGroup:CreateSlider("Rebirth delay", 2, 30, state.RebirthInterval, function(value)
	state.RebirthInterval = value
end, "Seconds between rebirth attempts.")

shop:AddDropdown("Target upgrades", {
	Text = "What to buy",
	Values = { "Any", "Stand", "Speed", "Capacity", "Price", "Workers" },
	Default = state.TargetUpgrades,
	Multi = true,
	Callback = function(selected)
		state.TargetUpgrades = Core.normalizeMultiSelection(selected)
		if #state.TargetUpgrades == 0 then
			state.TargetUpgrades = { "Any" }
		end
	end,
})

util:CreateToggle("Anti AFK", state.AntiAFK ~= false, "Prevents idle kicks.", function(enabled)
	state.AntiAFK = enabled
	if enabled then
		Core.setupAntiAfk(LocalPlayer)
	end
end)
util:CreateButton("Scan remotes", function()
	refreshRemotes()
	local count = 0
	for _ in pairs(runtime.remotes) do
		count += 1
	end
	notify("Alleral", "Indexed " .. tostring(count) .. " remotes.", 3)
end)
util:CreateButton("Save now", saveSettings)

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
	gameId = "sell_lemons",
	placeId = PLACE_ID,
}))

Core.finalizeGameUi(window, ui, {
	Subtitle = "Sell Lemons · v" .. VERSION,
})

saveSettings()

state.Alleral_Unload = function()
	state.HubRunning = false
	Core.stopAutomation(state, connections, loopControllers, loops)
end
