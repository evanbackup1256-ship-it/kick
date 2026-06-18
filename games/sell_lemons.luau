getgenv().Alleral_State = getgenv().Alleral_State or {}

local Core = getgenv().Alleral_Core
if not Core or not Core.assertLoader or not Core.assertLoader() then
	return
end

local VERSION = "2.1.0"
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
	getgenv().Alleral_StartupFailed = bootErr or "boot failed"
	return
end
G = Core.Game or G

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local SETTINGS_FILE = "sell_lemons.json"
local SETTINGS_EXCLUDE = {
	HubRunning = true,
	LastJump = true,
}
local defaults = {
	HubRunning = true,
	AntiAFK = true,
	AAutoLoadConfig = false,
	AutoLoadProfile = "default",
	AutoCollectLemon = false,
	AutoCollectCashDrops = false,
	AutoCollectCashVine = false,
	AutoWakeIncome = false,
	AutoAcceptOffer = false,
	HaggleBeforeAccept = false,
	AutoBuyButton = false,
	AutoUpgradeManage = false,
	AutoEvolve = false,
	AutoAscend = false,
	AutoUpgradePower = false,
	AutoRebirth = false,
	AutoSolveSewer = false,
	AutoClaimVoidAltar = false,
	AutoLemonDash = false,
	AutoLemonTrade = false,
	WalkSpeedEnabled = false,
	WalkSpeed = 24,
	InfiniteJump = false,
	CollectRadius = 90,
	CollectInterval = 0.45,
	OfferInterval = 1.5,
	UpgradeInterval = 2,
	RebirthDelayMinutes = 5,
	RebirthInterval = 300,
	EvolveInterval = 3,
	AscendInterval = 5,
	PowerUpgradeInterval = 2,
	SewerInterval = 4,
	VoidAltarInterval = 8,
	DashInterval = 2,
	TradeInterval = 3,
	MaxEvolutionLevel = 10,
	TargetManage = { "Any" },
	TargetUpgrades = { "Any" },
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
	timers = {},
	jumpConn = nil,
}

local REMOTE_ALIASES = {
	CollectLemon = { "CollectLemon", "PickLemon", "HarvestLemon", "GrabLemon" },
	CollectCash = { "CollectCash", "CollectBag", "PickupCash", "CollectAll", "CollectDrop" },
	CollectVine = { "CollectVine", "CashVine", "VineCollect", "CollectCashVine" },
	WakeIncome = { "WakeIncome", "WakeUp", "StartIncome", "ActivateIncome" },
	AcceptOffer = { "AcceptOffer", "AcceptDeal", "ConfirmOffer" },
	HaggleOffer = { "Haggle", "HaggleOffer", "Negotiate" },
	BuyButton = { "BuyButton", "PurchaseButton", "BuyStandButton" },
	UpgradeManage = { "UpgradeManage", "ManageUpgrade", "BuyManage", "ManageBuy" },
	Evolve = { "Evolve", "EvolveLemon", "Evolution" },
	Ascend = { "Ascend", "Ascension", "AscendLemon" },
	UpgradePower = { "UpgradePower", "PowerUpgrade", "BuyPower" },
	Rebirth = { "Rebirth", "Prestige" },
	SolveSewer = { "SolveSewer", "Sewer", "CompleteSewer" },
	ClaimVoidAltar = { "ClaimVoidAltar", "VoidAltar", "ClaimAltar" },
	LemonDash = { "LemonDash", "Dash", "StartDash" },
	LemonTrade = { "LemonTrade", "Trade", "StartTrade" },
	TalkAlien = { "TalkAlien", "AlienTalk", "SpeakAlien", "InteractAlien" },
}

local function refreshRemotes()
	runtime.remotes = G.indexRemotes and G.indexRemotes(ReplicatedStorage, runtime.remotes) or runtime.remotes
	local folder = waitChild(ReplicatedStorage, "Remotes", 3)
		or waitChild(ReplicatedStorage, "RemoteEvents", 3)
		or waitChild(ReplicatedStorage, "RemoteFunctions", 3)
	if not folder then
		return
	end
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
	if remote and G.fireRemote then
		return G.fireRemote(remote, ...)
	end
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
	if tick() < runtime.timers[key] then
		return
	end
	runtime.timers[key] = tick() + interval
	fn()
end

local function partsMatching(root, patterns, radius)
	local list = {}
	local _, _, charRoot = characterParts()
	if not charRoot then
		return list
	end
	radius = radius or state.CollectRadius or 90
	local scanRoot = root or Workspace
	for _, inst in ipairs(scanRoot:GetDescendants()) do
		if inst:IsA("BasePart") or inst:IsA("Model") then
			local name = string.lower(inst.Name)
			for _, pattern in ipairs(patterns) do
				if string.find(name, pattern) then
					local pos = inst:IsA("Model") and (inst.PrimaryPart and inst.PrimaryPart.Position or inst:GetPivot().Position) or inst.Position
					if (pos - charRoot.Position).Magnitude <= radius then
						table.insert(list, inst)
					end
					break
				end
			end
		end
	end
	return list
end

local function touchCollect(patterns)
	local _, _, root = characterParts()
	if not root then
		return
	end
	for _, part in ipairs(partsMatching(Workspace, patterns, state.CollectRadius)) do
		local target = part:IsA("Model") and (part.PrimaryPart or part:FindFirstChildWhichIsA("BasePart")) or part
		if target then
			if G.touchPart then
				G.touchPart(root, target)
			elseif G.fireClickDetector then
				G.fireClickDetector(target)
			end
		end
	end
end

local function applyMovement()
	local _, humanoid = characterParts()
	if not humanoid then
		return
	end
	if state.WalkSpeedEnabled and G.applyWalkSpeed then
		G.applyWalkSpeed(humanoid, state.WalkSpeed)
	elseif state.WalkSpeedEnabled then
		humanoid.WalkSpeed = state.WalkSpeed
	end
	if state.InfiniteJump then
		if runtime.jumpConn then
			return
		end
		runtime.jumpConn = UserInputService.JumpRequest:Connect(function()
			local _, hum = characterParts()
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
		Core.track(connections, runtime.jumpConn)
	elseif runtime.jumpConn then
		runtime.jumpConn:Disconnect()
		runtime.jumpConn = nil
	end
end

local function runAutomation()
	if not state.HubRunning then
		return
	end
	refreshRemotes()
	applyMovement()

	if state.AutoCollectLemon then
		tickEvery("lemon", state.CollectInterval or 0.45, function()
			if not fireKey("CollectLemon") then
				touchCollect({ "lemon", "fruit", "crop" })
			end
		end)
	end
	if state.AutoCollectCashDrops then
		tickEvery("cash", state.CollectInterval or 0.45, function()
			if not fireKey("CollectCash") then
				touchCollect({ "cash", "money", "coin", "bag" })
			end
		end)
	end
	if state.AutoCollectCashVine then
		tickEvery("vine", state.CollectInterval or 0.45, function()
			if not fireKey("CollectVine") then
				touchCollect({ "vine", "cashvine" })
			end
		end)
	end
	if state.AutoWakeIncome then
		tickEvery("wake", 2, function()
			fireKey("WakeIncome")
		end)
	end
	if state.AutoAcceptOffer then
		tickEvery("offer", state.OfferInterval or 1.5, function()
			if state.HaggleBeforeAccept then
				fireKey("HaggleOffer")
			end
			fireKey("AcceptOffer")
		end)
	end
	if state.AutoBuyButton then
		tickEvery("buyBtn", state.UpgradeInterval or 2, function()
			fireKey("BuyButton")
		end)
	end
	if state.AutoUpgradeManage then
		tickEvery("manage", state.UpgradeInterval or 2, function()
			local targets = Core.normalizeMultiSelection(state.TargetManage)
			if #targets == 0 or targets[1] == "Any" then
				fireKey("UpgradeManage")
			else
				for _, name in ipairs(targets) do
					fireKey("UpgradeManage", name)
				end
			end
		end)
	end
	if state.AutoEvolve then
		tickEvery("evolve", state.EvolveInterval or 3, function()
			fireKey("Evolve", state.MaxEvolutionLevel)
		end)
	end
	if state.AutoAscend then
		tickEvery("ascend", state.AscendInterval or 5, function()
			fireKey("Ascend")
		end)
	end
	if state.AutoUpgradePower then
		tickEvery("power", state.PowerUpgradeInterval or 2, function()
			fireKey("UpgradePower")
		end)
	end
	if state.AutoRebirth then
		tickEvery("rebirth", state.RebirthInterval or state.RebirthDelayMinutes * 60, function()
			fireKey("Rebirth")
		end)
	end
	if state.AutoSolveSewer then
		tickEvery("sewer", state.SewerInterval or 4, function()
			fireKey("SolveSewer")
		end)
	end
	if state.AutoClaimVoidAltar then
		tickEvery("void", state.VoidAltarInterval or 8, function()
			fireKey("ClaimVoidAltar")
		end)
	end
	if state.AutoLemonDash then
		tickEvery("dash", state.DashInterval or 2, function()
			fireKey("LemonDash")
		end)
	end
	if state.AutoLemonTrade then
		tickEvery("trade", state.TradeInterval or 3, function()
			fireKey("LemonTrade")
		end)
	end
end

Core.makeSupervisor(state, loops, loopControllers, "mainLoop", 0.25, runAutomation)

if state.AntiAFK ~= false then
	Core.setupAntiAfk(LocalPlayer)
end

local window = Core.buildUiWindow(ui, Core.uiWindowSettings({
	Subtitle = "Sell Lemons · v" .. VERSION,
	Icon = "lemon",
	Theme = "Default",
}))
if not window or not window._rawWindow then
	getgenv().Alleral_StartupFailed = "UI window failed"
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
		{ key = "AutoCollectLemon", label = "Collect lemon" },
		{ key = "AutoCollectCashDrops", label = "Cash drops" },
		{ key = "AutoCollectCashVine", label = "Cash vine" },
		{ key = "AutoWakeIncome", label = "Wake income" },
		{ key = "AutoAcceptOffer", label = "Accept offers" },
		{ key = "AutoRebirth", label = "Rebirth" },
	},
	saveFn = saveSettings,
	onRemoteScan = refreshRemotes,
})

local farmTab = Core.buildUiTab(section, "Farm", 10734923214, 2, "farm")
local offerTab = Core.buildUiTab(section, "Offers", 10723407389, 1, "offers")
local progTab = Core.buildUiTab(section, "Progress", 10734952479, 2, "progress")
local miscTab = Core.buildUiTab(section, "Misc", 10709789407, 1, "misc")
local settingsTab = Core.buildUiTab(section, "Settings", 10734950309, 1, "settings")
local saveWrap = Core.onUiSave(saveSettings)

local collectGroup = Core.buildUiGroup(farmTab, "Collect", 1, saveWrap, nil, "collect")
local incomeGroup = Core.buildUiGroup(farmTab, "Income", 2, saveWrap, nil, "income")
local offerGroup = Core.buildUiGroup(offerTab, "Offers", 1, saveWrap, nil, "offer")
local shopGroup = Core.buildUiGroup(offerTab, "Shop", 2, saveWrap, nil, "shop")
local evolveGroup = Core.buildUiGroup(progTab, "Evolution", 1, saveWrap, nil, "evolve")
local rebirthGroup = Core.buildUiGroup(progTab, "Rebirth", 2, saveWrap, nil, "rebirth")
local eventGroup = Core.buildUiGroup(progTab, "Events", 1, saveWrap, nil, "events")
local moveGroup = Core.buildUiGroup(miscTab, "Movement", 1, saveWrap, nil, "move")
local utilGroup = Core.buildUiGroup(miscTab, "Utilities", 2, saveWrap, nil, "util")

collectGroup:CreateToggle("Auto collect lemon", state.AutoCollectLemon, "Collects lemons from your stand area.", function(v) state.AutoCollectLemon = v end)
collectGroup:CreateToggle("Auto collect cash drops", state.AutoCollectCashDrops, "Grabs cash bags and coins.", function(v) state.AutoCollectCashDrops = v end)
collectGroup:CreateToggle("Auto collect cash vine", state.AutoCollectCashVine, "Collects vine cash nodes.", function(v) state.AutoCollectCashVine = v end)
collectGroup:CreateSlider("Collect radius", 20, 250, state.CollectRadius, function(v) state.CollectRadius = v end, "Search radius for touch collection.")
collectGroup:CreateSlider("Collect delay", 0.2, 3, state.CollectInterval, function(v) state.CollectInterval = v end, "Seconds between collect passes.")

incomeGroup:CreateToggle("Auto wake income", state.AutoWakeIncome, "Wakes idle income generators.", function(v) state.AutoWakeIncome = v end)

offerGroup:CreateToggle("Auto accept offer", state.AutoAcceptOffer, "Accepts incoming offers automatically.", function(v) state.AutoAcceptOffer = v end)
offerGroup:CreateToggle("Haggle before accepting", state.HaggleBeforeAccept, "Runs haggle remote before accept.", function(v) state.HaggleBeforeAccept = v end)
offerGroup:CreateSlider("Offer delay", 0.5, 10, state.OfferInterval, function(v) state.OfferInterval = v end, "Seconds between offer attempts.")

shopGroup:CreateToggle("Auto buy button", state.AutoBuyButton, "Purchases stand button upgrades.", function(v) state.AutoBuyButton = v end)
shopGroup:CreateToggle("Auto upgrade manage", state.AutoUpgradeManage, "Buys manage-tab upgrades.", function(v) state.AutoUpgradeManage = v end)
shopGroup:AddDropdown("Manage selection", {
	Text = "Manage upgrades",
	Values = { "Any", "Stand", "Workers", "Speed", "Capacity", "Price", "Luck" },
	Default = state.TargetManage,
	Multi = true,
	Callback = function(selected)
		state.TargetManage = Core.normalizeMultiSelection(selected)
		if #state.TargetManage == 0 then state.TargetManage = { "Any" } end
	end,
})

evolveGroup:CreateToggle("Auto evolve", state.AutoEvolve, "Evolves lemons up to max level.", function(v) state.AutoEvolve = v end)
evolveGroup:CreateToggle("Auto ascend", state.AutoAscend, "Ascends when available.", function(v) state.AutoAscend = v end)
evolveGroup:CreateToggle("Auto upgrade power", state.AutoUpgradePower, "Purchases power upgrades.", function(v) state.AutoUpgradePower = v end)
evolveGroup:CreateSlider("Max evolution level", 1, 50, state.MaxEvolutionLevel, function(v) state.MaxEvolutionLevel = v end, "Cap for auto evolve.")

rebirthGroup:CreateToggle("Auto rebirth", state.AutoRebirth, "Rebirths when affordable.", function(v) state.AutoRebirth = v end)
rebirthGroup:CreateSlider("Rebirth delay (minutes)", 1, 60, state.RebirthDelayMinutes, function(v)
	state.RebirthDelayMinutes = v
	state.RebirthInterval = v * 60
end, "Minimum minutes between rebirth attempts.")

eventGroup:CreateToggle("Auto solve sewer", state.AutoSolveSewer, "Completes sewer minigame.", function(v) state.AutoSolveSewer = v end)
eventGroup:CreateToggle("Auto claim void altar", state.AutoClaimVoidAltar, "Claims void altar rewards.", function(v) state.AutoClaimVoidAltar = v end)
eventGroup:CreateToggle("Auto lemon dash", state.AutoLemonDash, "Runs lemon dash event.", function(v) state.AutoLemonDash = v end)
eventGroup:CreateToggle("Auto lemon trade", state.AutoLemonTrade, "Runs lemon trade event.", function(v) state.AutoLemonTrade = v end)
eventGroup:CreateButton("Talk to alien", function() fireKey("TalkAlien") end, "Fires alien interaction remote.")

moveGroup:CreateToggle("Custom walk speed", state.WalkSpeedEnabled, "Overrides local walkspeed.", function(v) state.WalkSpeedEnabled = v end)
moveGroup:CreateSlider("Walk speed", 16, 120, state.WalkSpeed, function(v) state.WalkSpeed = v end, "Local movement speed.")
moveGroup:CreateToggle("Infinite jump", state.InfiniteJump, "Jump again while airborne.", function(v) state.InfiniteJump = v end)

utilGroup:CreateToggle("Anti AFK", state.AntiAFK ~= false, "Prevents idle kicks.", function(v)
	state.AntiAFK = v
	if v then Core.setupAntiAfk(LocalPlayer) end
end)
utilGroup:CreateButton("Scan remotes", function()
	refreshRemotes()
	local n = 0
	for _ in pairs(runtime.remotes) do n += 1 end
	notify("Alleral", "Indexed " .. n .. " remotes.", 3)
end)

settingsTab:BuildThemeGroupbox(1)
Core.buildConfigProfileGroup(settingsTab, {
	state = state,
	savedKeys = savedKeys,
	saveFn = saveSettings,
	version = VERSION,
	column = 1,
})
Core.buildStandardSettingsExtras(settingsTab, Core.settingsExtrasOptions(window, ui, state, savedKeys, saveSettings, SETTINGS_FILE, VERSION, {
	gameId = "sell_lemons",
	placeId = PLACE_ID,
}))

Core.finalizeGameUi(window, ui, { Subtitle = "Sell Lemons · v" .. VERSION })
saveSettings()
applyMovement()

state.Alleral_Unload = function()
	state.HubRunning = false
	if runtime.jumpConn then runtime.jumpConn:Disconnect() end
	Core.stopAutomation(state, connections, loopControllers, loops)
end
