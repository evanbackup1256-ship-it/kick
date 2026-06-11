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
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

local defaults = {
	HubRunning = true,
	AutoStepFarm = false,
	AutoWinsFarm = false,
	SelectedWinTarget = workspace:FindFirstChild("WORLD 2") and "Win 250k" or "Win 500",
	LastWinTargetW1 = "Win 500",
	LastWinTargetW2 = "Win 250k",
	TargetTreadmill = "Diamond",
	FreezePosition = false,
	AutoRebirth = false,
	TweenSpeed = 150,
	AntiAFK = true,
	WallState = "Unknown",
	WallDistance = 100,
	LavaState = "Unknown",
	LavaDistance = 100,
	AutoBuyItems = false,
	TargetBuyItems = { "Common" },
	AutoEquipBest = false,
	SelectedAura = "GlowAura",
	World2WallState = "Unknown",
	World2LavaState = "Unknown",
}

for key, value in pairs(defaults) do
	if state[key] == nil then
		state[key] = value
	end
end

_G.TweenSpeed = state.TweenSpeed

local function notify(title, text, duration)
	Core.notify(title, text, duration)
end

local ROUTE_WORLD1 = {
	Vector3.new(4, 7, 1),
	Vector3.new(5, 6, 286),
	Vector3.new(67, 6, 423),
	Vector3.new(4, 6, 505),
	Vector3.new(20, 6, 560),
	Vector3.new(19, 74, 749),
	Vector3.new(6, 74, 775),
	Vector3.new(5, 75, 936),
	Vector3.new(104, 75, 939),
	Vector3.new(102, 75, 1009),
	Vector3.new(7, 74, 1004),
	Vector3.new(4, 75, 1109),
	Vector3.new(3, 74, 1411),
	Vector3.new(-38, 53, 1475),
	Vector3.new(-534, 51, 1469),
	Vector3.new(-1008, 52, 1466),
	Vector3.new(-1088, 51, 1466),
	Vector3.new(-1088, 51, 1466),
	Vector3.new(-1090, 293, 1466),
	Vector3.new(-1124, 293, 1466),
	Vector3.new(-1215, 294, 1467),
	Vector3.new(-1248, 302, 1467),
	Vector3.new(-1339, 279, 1468),
	Vector3.new(-1371, 280, 1469),
	Vector3.new(-1424, 333, 1467),
	Vector3.new(-1511, 334, 1466),
	Vector3.new(-1559, 318, 1469),
	Vector3.new(-1632, 318, 1467),
	Vector3.new(-1742, 288, 1464),
	Vector3.new(-1776, 288, 1466),
	Vector3.new(-1827, 301, 1467),
	Vector3.new(-1867, 315, 1466),
	Vector3.new(-1936, 305, 1466),
	Vector3.new(-2115, 303, 1471),
	Vector3.new(-2185, 324, 1471),
	Vector3.new(-2241, 312, 1467),
	Vector3.new(-2312, 312, 1470),
	Vector3.new(-2347, 324, 1474),
	Vector3.new(-2410, 321, 1473),
	Vector3.new(-2530, 320, 1472),
	Vector3.new(-2591, 292, 1490),
	Vector3.new(-2740, 292, 1483),
	Vector3.new(-2793, 307, 1478),
	Vector3.new(-2852, 282, 1473),
	Vector3.new(-2887, 281, 1472),
	Vector3.new(-2938, 295, 1468),
	Vector3.new(-2970, 294, 1466),
	Vector3.new(-3028, 294, 1465),
	Vector3.new(-3075, 294, 1566),
	Vector3.new(-3163, 294, 1613),
	Vector3.new(-3433, 294, 1595),
	Vector3.new(-3612, 294, 1467),
	Vector3.new(-3949, 293, 1469),
	Vector3.new(-4097, 294, 1466),
	Vector3.new(-4195, 293, 1465),
	Vector3.new(-4286, 292, 1465),
	Vector3.new(-4302, 294, 1466),
	Vector3.new(-4305, 340, 1466),
	Vector3.new(-4316, 340, 1443),
	Vector3.new(-4315, 341, 1340),
	Vector3.new(-4314, 349, 1309),
	Vector3.new(-4306, 348, 1302),
	Vector3.new(-4304, 367, 1302),
	Vector3.new(-4192, 367, 1301),
	Vector3.new(-4061, 367, 1301),
	Vector3.new(-4044, 367, 1303),
	Vector3.new(-4023, 372, 1304),
	Vector3.new(-4017, 389, 1304),
	Vector3.new(-4012, 389, 1327),
	Vector3.new(-4009, 389, 1425),
	Vector3.new(-4009, 389, 1569),
	Vector3.new(-4013, 391, 1607),
	Vector3.new(-4125, 390, 1610),
	Vector3.new(-4300, 390, 1610),
	Vector3.new(-4351, 397, 1611),
	Vector3.new(-4351, 397, 1594),
	Vector3.new(-4350, 405, 1567),
	Vector3.new(-4349, 403, 1460),
	Vector3.new(-4349, 432, 1409),
	Vector3.new(-4348, 432, 1391),
	Vector3.new(-4251, 430, 1392),
	Vector3.new(-4212, 441, 1394),
	Vector3.new(-4126, 439, 1384),
	Vector3.new(-4098, 451, 1411),
	Vector3.new(-4062, 444, 1463),
	Vector3.new(-4057, 456, 1500),
	Vector3.new(-4082, 444, 1557),
	Vector3.new(-4160, 444, 1571),
	Vector3.new(-4255, 454, 1543),
	Vector3.new(-4318, 472, 1540),
	Vector3.new(-4330, 468, 1536),
	Vector3.new(-4371, 468, 1532)
}

local ROUTE_WORLD2 = {
	Vector3.new(-401, 503, -171),
	Vector3.new(-394, 503, 4),
	Vector3.new(-399, 503, 53),
	Vector3.new(-400, 501, 131),
	Vector3.new(-397, 498, 194),
	Vector3.new(-397, 498, 437),
	Vector3.new(-375, 495, 464),
	Vector3.new(-349, 497, 481),
	Vector3.new(-345, 524, 568),
	Vector3.new(-425, 524, 572),
	Vector3.new(-462, 551, 475),
	Vector3.new(-373, 551, 473),
	Vector3.new(-349, 561, 515),
	Vector3.new(-350, 581, 573),
	Vector3.new(-446, 578, 572),
	Vector3.new(-447, 607, 465),
	Vector3.new(-400, 604, 470),
	Vector3.new(-399, 605, 612),
	Vector3.new(-401, 606, 670),
	Vector3.new(-422, 606, 709),
	Vector3.new(-421, 605, 742),
	Vector3.new(-402, 606, 789),
	Vector3.new(-402, 605, 842),
	Vector3.new(-350, 612, 926),
	Vector3.new(-320, 603, 1120),
	Vector3.new(-390, 612, 1233),
	Vector3.new(-401, 605, 1263),
	Vector3.new(-405, 607, 1298),
	Vector3.new(-403, 616, 1330),
	Vector3.new(-400, 605, 1429),
	Vector3.new(-388, 607, 1479),
	Vector3.new(-360, 628, 1546),
	Vector3.new(-360, 625, 1604),
	Vector3.new(-360, 603, 1700),
	Vector3.new(-362, 605, 1762),
	Vector3.new(-363, 614, 1797),
	Vector3.new(-393, 606, 1860),
	Vector3.new(-397, 607, 1925),
	Vector3.new(-398, 616, 1964),
	Vector3.new(-402, 606, 2038),
	Vector3.new(-403, 606, 2100),
	Vector3.new(-404, 616, 2138),
	Vector3.new(-403, 606, 2217),
	Vector3.new(-403, 607, 2282),
	Vector3.new(-404, 617, 2315),
	Vector3.new(-405, 620, 2371),
	Vector3.new(-403, 620, 2416)
}

local WIN_CONFIG_WORLD1 = {
	["Win 1"] = { RouteIndex = 2, BlockName = "WinBlock", MinTime = 0 },
	["Win 3"] = { RouteIndex = 4, BlockName = "WinBlock2", MinTime = 0 },
	["Win 10"] = { RouteIndex = 7, BlockName = "WinBlock3", MinTime = 0 },
	["Win 20"] = { RouteIndex = 12, BlockName = "WinBlock4", MinTime = 0 },
	["Win 50"] = { RouteIndex = 13, BlockName = "WinBlock5", MinTime = 0 },
	["Win 100"] = { RouteIndex = 15, BlockName = "WinBlock6", MinTime = 8 },
	["Win 150"] = { RouteIndex = 16, BlockName = "WinBlock7", MinTime = 10 },
	["Win 300"] = { RouteIndex = 19, BlockName = "WinBlock8", MinTime = 12 },
	["Win 500"] = { RouteIndex = 46, BlockName = "WinBlock9", MinTime = 25 },
	["Win 1000"] = { RouteIndex = 52, BlockName = "WinBlock10", MinTime = 30 },
	["Win 2500"] = { RouteIndex = 91, BlockName = "WinBlock11", MinTime = 45 },
}

local WIN_CONFIG_WORLD2 = {
	["Win 250k"] = { RouteIndex = 5, BlockName = "WinBlock16", MinTime = 0 },
	["Win 400k"] = { RouteIndex = 6, BlockName = "WinBlock17", MinTime = 0 },
	["Win 600k"] = { RouteIndex = 18, BlockName = "WinBlock18", MinTime = 12 },
	["Win 1M"] = { RouteIndex = 23, BlockName = "WinBlock19", MinTime = 15 },
	["Win 1.5M"] = { RouteIndex = 27, BlockName = "WinBlock20", MinTime = 20 },
	["Win 2.5M"] = { RouteIndex = 47, BlockName = "WinBlock21", MinTime = 30 },
}

local ITEM_PRICES = {
	Common = 2500,
	Uncommon = 25000,
	Rare = 250000,
	Mysterious = 3500000,
}

local function refreshWorldRoutes()
	state.isWorld2 = workspace:FindFirstChild("WORLD 2") ~= nil
	state.CurrentRoute = state.isWorld2 and ROUTE_WORLD2 or ROUTE_WORLD1
	state.CurrentConfig = state.isWorld2 and WIN_CONFIG_WORLD2 or WIN_CONFIG_WORLD1
	if not state.CurrentConfig[state.SelectedWinTarget] then
		if state.isWorld2 then
			state.SelectedWinTarget = state.LastWinTargetW2 or "Win 250k"
		else
			state.SelectedWinTarget = state.LastWinTargetW1 or "Win 500"
		end
		if not state.CurrentConfig[state.SelectedWinTarget] then
			state.SelectedWinTarget = state.isWorld2 and "Win 250k" or "Win 500"
		end
	end
end
refreshWorldRoutes()

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local UpdateSpeedRemote = Remotes:WaitForChild("UpdateSpeed", 10)
local TreadmillSignalRemote = Remotes:WaitForChild("TreadmillSignal", 10)
local ItemsShopRemote = Remotes:WaitForChild("ItemsShopAction", 10)
local ItemActionRemote = Remotes:FindFirstChild("ItemAction")
local RebirthRemote = Remotes:WaitForChild("Rebirth", 5)
local BuyAuraRemote = Remotes:FindFirstChild("BuyAura")
local EquipAuraRemote = Remotes:FindFirstChild("EquipAura")

local ClientState = require(ReplicatedStorage:WaitForChild("ClientState", 10))
local NotificationSystem = require(ReplicatedStorage:WaitForChild("NotificationSystem", 10))
local EventsConfig = require(ReplicatedStorage:WaitForChild("EventsConfig", 10))
local ConfigFolder = ReplicatedStorage:WaitForChild("Config", 10)
local GeneralConfig = ConfigFolder:IsA("Folder")
		and require(ConfigFolder:WaitForChild("GeneralConfig", 10))
	or require(ConfigFolder)

local sensors = {
	wallLeft = nil,
	wallRight = nil,
	lastWallDistance = 0,
	lavaTop = nil,
	lavaBottom = nil,
	lastLavaHeight = 0,
	world2WallA = nil,
	world2WallB = nil,
	world2WallMin = math.huge,
	world2WallMax = -math.huge,
	world2LavaTop = nil,
	world2LavaBottom = nil,
	lastWorld2LavaY = 0,
	onTreadmill = false,
}

function state.BypassFunction()
	pcall(function()
		local data = ClientState.Get and ClientState:Get() or nil
		if type(data) ~= "table" then
			return
		end
		data.GoldTreadmillActive = true
		data.DiamondTreadmillActive = true
		data.CandyTreadmillActive = true
		data.AdminTreadmillActive = true
		data.AdminAbuseTreadmillActive = true
		data.ManualGoldAccess = true
		data.ManualDiamondAccess = true
		data.ManualCandyAccess = true
		data.ManualAdminAccess = true
	end)
end

function state.UnlockInfinityTrail()
	local ok, result = pcall(function()
		local buy = Remotes:WaitForChild("BuyTrail", 10)
		local equip = Remotes:WaitForChild("EquipTrail", 10)
		if not buy or not equip then
			return false
		end
		local purchased = buy:InvokeServer("InfinityTrail", "Wins")
		task.wait(0.5)
		equip:FireServer("InfinityTrail")
		return purchased
	end)
	return ok, result
end

function state.UnlockAuraBypass(auraName)
	local ok, result = pcall(function()
		if not BuyAuraRemote or not EquipAuraRemote then
			return false
		end
		local key = auraName:gsub("%s+", "")
		local bought = BuyAuraRemote:InvokeServer(key, "Wins")
		task.wait(0.5)
		EquipAuraRemote:FireServer(key)
		return bought
	end)
	return ok, result
end

local function getTrailMultiplier(trailKey, generalCfg, eventsCfg)
	if not generalCfg or not generalCfg.TRAILS then
		return 1
	end
	local trail = generalCfg.TRAILS[trailKey]
	if not trail and eventsCfg then
		for _, entry in ipairs(eventsCfg.Trails or {}) do
			if entry.Key == trailKey then
				trail = entry
				break
			end
		end
	end
	return trail and trail.Multiplier or 1
end

local function refreshWallSensors()
	if sensors.wallLeft and sensors.wallRight and sensors.wallLeft.Parent and sensors.wallRight.Parent then
		return
	end
	local traps = workspace:FindFirstChild("NPC & Piege")
	local corridor = traps and traps:FindFirstChild("CorridorTrap")
	if corridor then
		sensors.wallLeft = corridor:FindFirstChild("WallL")
		sensors.wallRight = corridor:FindFirstChild("WallR")
	end
end

local function refreshLavaSensors()
	if sensors.lavaTop and sensors.lavaBottom and sensors.lavaTop.Parent and sensors.lavaBottom.Parent then
		return
	end
	local traps = workspace:FindFirstChild("NPC & Piege")
	local tower = traps and traps:FindFirstChild("LavaTower")
	if tower then
		sensors.lavaTop = tower:FindFirstChild("LavaPart")
		sensors.lavaBottom = tower:FindFirstChild("LavaBottom")
	end
end

local function refreshWorld2WallSensors()
	if sensors.world2WallA and sensors.world2WallB and sensors.world2WallA.Parent and sensors.world2WallB.Parent then
		return sensors.world2WallA, sensors.world2WallB
	end
	local stage = workspace:FindFirstChild("WORLD 2") and workspace["WORLD 2"]:FindFirstChild("Stage2")
	if not stage then
		return nil, nil
	end
	local moving = {}
	for _, child in pairs(stage:GetChildren()) do
		if child.Name == "MovingWalls" then
			table.insert(moving, child)
		end
	end
	if #moving >= 2 then
		sensors.world2WallA = moving[1]:FindFirstChild("MovingWall1")
		sensors.world2WallB = moving[2]:FindFirstChild("MovingWall1")
	end
	return sensors.world2WallA, sensors.world2WallB
end

local function refreshWorld2LavaSensors()
	if sensors.world2LavaTop and sensors.world2LavaBottom and sensors.world2LavaTop.Parent and sensors.world2LavaBottom.Parent then
		return sensors.world2LavaTop, sensors.world2LavaBottom
	end
	local folder = workspace:FindFirstChild("Pieges & Lava")
	local stage = folder and folder:FindFirstChild("Lava_Stage3")
	if stage then
		sensors.world2LavaTop = stage:FindFirstChild("LavaPart")
		sensors.world2LavaBottom = stage:FindFirstChild("LavaBottom")
	end
	return sensors.world2LavaTop, sensors.world2LavaBottom
end

local function isAlive()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.Health > 0
end

local function getRootPart()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function setAnchored(anchored)
	local root = getRootPart()
	if root then
		root.Anchored = anchored
	end
end

local function isRoutePointClear(position)
	for _, label in ipairs(CollectionService:GetTagged("Timer")) do
		if label:IsA("TextLabel") then
			local model = label:FindFirstAncestorOfClass("Model")
			local part = model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"))
			if part and (part.Position - position).Magnitude < 50 then
				local seconds = tonumber(string.gsub(label.Text, "%s+", ""))
				if seconds and seconds > 1.5 then
					return false
				end
			end
		end
	end
	return true
end

local function tweenTo(targetPosition)
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local distance = (root.Position - targetPosition).Magnitude
	local speed = _G.TempTweenSpeed or _G.TweenSpeed or state.TweenSpeed or 150
	if speed < 10 then
		speed = 150
	end
	local duration = math.max(distance / speed, 0.01)
	local tween = TweenService:Create(
		root,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0)) }
	)
	tween:Play()
	while tween.PlaybackState == Enum.PlaybackState.Playing do
		if not humanoid or humanoid.Health <= 0 then
			tween:Cancel()
			return false
		end
		task.wait()
	end
	_G.TempTweenSpeed = nil
	return true
end

local function waitForRespawn()
	while state.HubRunning and state.AutoWinsFarm and not isAlive() do
		task.wait(1)
	end
	task.wait(1)
	setAnchored(false)
end

local function waitAtRouteCheckpoint(stepIndex)
	if not state.isWorld2 and stepIndex == 16 then
		setAnchored(true)
		repeat
			task.wait(0.05)
		until state.WallState == "Opening" or not state.AutoWinsFarm or not isAlive()
		setAnchored(false)
	elseif not state.isWorld2 and stepIndex == 17 then
		setAnchored(true)
		repeat
			task.wait(0.05)
		until state.LavaState == "Safe" or not state.AutoWinsFarm or not isAlive()
		setAnchored(false)
	elseif state.isWorld2 and stepIndex == 6 then
		setAnchored(true)
		repeat
			task.wait(0.05)
		until state.World2WallState == "Open" or not state.AutoWinsFarm or not isAlive()
		setAnchored(false)
		_G.TempTweenSpeed = 110
	elseif state.isWorld2 and stepIndex == 7 then
		setAnchored(true)
		repeat
			task.wait(0.05)
		until state.World2LavaState == "Safe" or not state.AutoWinsFarm or not isAlive()
		setAnchored(false)
	end
end

local function waitForRoutePoint(position)
	setAnchored(true)
	repeat
		task.wait(0.1)
	until isRoutePointClear(position) or not state.AutoWinsFarm or not isAlive()
	setAnchored(false)
end

local function runWinFarmCycle()
	local targetName = state.SelectedWinTarget
	local config = state.CurrentConfig[targetName]
	if not config then
		task.wait(1)
		return
	end

	if not isAlive() then
		waitForRespawn()
		return
	end

	local cycleStart = tick()
	local keepGoing = true
	local needsRespawn = false

	for step = 1, config.RouteIndex do
		if not state.AutoWinsFarm or not state.HubRunning then
			return
		end
		if not isAlive() then
			needsRespawn = true
			break
		end

		local waypoint = state.CurrentRoute[step]
		waitAtRouteCheckpoint(step)

		if not isRoutePointClear(waypoint) then
			waitForRoutePoint(waypoint)
		end

		if not isAlive() then
			needsRespawn = true
			break
		end
		if not tweenTo(waypoint) then
			break
		end
	end

	if needsRespawn then
		waitForRespawn()
		return
	end

	local elapsed = tick() - cycleStart
	if elapsed < config.MinTime then
		task.wait(config.MinTime - elapsed)
	end

	local winBlock = workspace:FindFirstChild(config.BlockName, true)
	if winBlock and isAlive() then
		tweenTo(winBlock.Position + Vector3.new(0, 3, 0))
		task.wait(3)
	end
end

Core.makeSupervisor(state, loops, loopControllers, "treadmillBypass", 1, function()
	state.BypassFunction()
end)

Core.makeSupervisor(state, loops, loopControllers, "freezePosition", 0.1, function()
	local root = getRootPart()
	if root then
		root.Anchored = not state.AutoWinsFarm and state.FreezePosition
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "stepFarm", 0.05, function()
	if not state.AutoStepFarm or state.AutoWinsFarm then
		return
	end
	local data = ClientState:Get()
	if not data then
		return
	end
	if data.onTreadmill then
		sensors.onTreadmill = true
		return
	end
	if sensors.onTreadmill then
		TreadmillSignalRemote:FireServer(false)
		sensors.onTreadmill = false
		task.wait(0.1)
	end
	UpdateSpeedRemote:FireServer("Walking")
	local trailMultiplier = getTrailMultiplier(data.EquippedTrail or "None", GeneralConfig, EventsConfig)
	NotificationSystem:ShowPlusOne(
		data.StepBonus,
		data.Multiplier,
		data.SpeedBoostMultiplier,
		trailMultiplier,
		1,
		data.BonusXPMultiplier or 1
	)
end)

Core.makeSupervisor(state, loops, loopControllers, "world1Sensors", 0.05, function()
	refreshWorldRoutes()
	if state.isWorld2 then
		state.WallState = "Unknown"
		state.LavaState = "Unknown"
		return
	end
	refreshWallSensors()
	if sensors.wallLeft and sensors.wallRight then
		local distance = (sensors.wallLeft.Position - sensors.wallRight.Position).Magnitude
		local delta = distance - sensors.lastWallDistance
		if math.abs(delta) < 0.05 then
			if distance > 65 then
				state.WallState = "Open"
			else
				state.WallState = "Closed"
			end
		elseif delta > 0.05 then
			state.WallState = "Opening"
		elseif delta < -0.05 then
			state.WallState = "Closing"
		end
		sensors.lastWallDistance = distance
		state.WallDistance = distance
	else
		state.WallState = "Unknown"
	end

	refreshLavaSensors()
	if sensors.lavaTop and sensors.lavaBottom then
		local topY = sensors.lavaTop.Position.Y
		local bottomY = sensors.lavaBottom.Position.Y
		local gap = math.abs(topY - bottomY)
		local delta = topY - sensors.lastLavaHeight
		if math.abs(delta) < 0.05 then
			state.LavaState = gap < 8 and "Safe" or "Danger"
		elseif delta > 0.05 then
			state.LavaState = "Rising"
		elseif delta < -0.05 then
			state.LavaState = "Falling"
		end
		sensors.lastLavaHeight = topY
		state.LavaDistance = gap
	else
		state.LavaState = "Unknown"
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "world2WallSensor", 0.05, function()
	refreshWorldRoutes()
	if not state.isWorld2 then
		return
	end
	local wallA, wallB = refreshWorld2WallSensors()
	if not wallA or not wallB then
		state.World2WallState = "Unknown"
		return
	end
	local distance = (wallA.Position - wallB.Position).Magnitude
	sensors.world2WallMin = math.min(sensors.world2WallMin, distance)
	sensors.world2WallMax = math.max(sensors.world2WallMax, distance)
	local span = sensors.world2WallMax - sensors.world2WallMin
	if span > 1 then
		local openRatio = ((distance - sensors.world2WallMin) / span) * 100
		state.World2WallState = openRatio > 70 and "Open" or "Closed"
	else
		state.World2WallState = "Calibrating"
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "world2LavaSensor", 0.05, function()
	refreshWorldRoutes()
	if not state.isWorld2 then
		return
	end
	local top, bottom = refreshWorld2LavaSensors()
	if not top or not bottom then
		state.World2LavaState = "Unknown"
		return
	end
	local topY = top.Position.Y
	local bottomY = bottom.Position.Y
	local gap = math.abs(topY - bottomY)
	local delta = topY - sensors.lastWorld2LavaY
	sensors.lastWorld2LavaY = topY
	if math.abs(delta) < 0.05 then
		state.World2LavaState = gap < 8 and "Safe" or "Danger"
	else
		state.World2LavaState = "Danger"
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "winsFarm", 0.05, function()
	if not state.AutoWinsFarm then
		return
	end
	refreshWorldRoutes()
	runWinFarmCycle()
end)

Core.makeSupervisor(state, loops, loopControllers, "autoBuyItems", 1.5, function()
	if not state.AutoBuyItems or not ItemsShopRemote then
		return
	end
	local data = ClientState:Get()
	local wins = data and data.Wins or 0
	for key, value in pairs(state.TargetBuyItems) do
		local itemName = nil
		if type(key) == "string" and value == true then
			itemName = key
		elseif type(value) == "string" then
			itemName = value
		end
		if itemName then
			local shopKey = itemName == "Epic" and "Mysterious" or itemName
			local price = ITEM_PRICES[shopKey] or 0
			if wins >= price then
				ItemsShopRemote:FireServer("BuyWins", shopKey)
				task.wait(0.1)
			end
		end
	end
end)

Core.makeSupervisor(state, loops, loopControllers, "autoEquipBest", 2, function()
	if not state.AutoEquipBest or not ItemActionRemote then
		return
	end
	ItemActionRemote:FireServer("EquipBest")
	ItemActionRemote:FireServer("EquipBestItems")
end)

Core.makeSupervisor(state, loops, loopControllers, "autoRebirth", 0.5, function()
	if state.AutoRebirth and RebirthRemote then
		RebirthRemote:FireServer()
	end
end)

local window = Core.buildRayfieldWindow(rayfield, {
	Subtitle = "Speed Keyboard Escape · v" .. VERSION,
})
local section = Core.buildRayfieldSection(window)
local mainTab = Core.buildRayfieldTab(section, "Main", 10723407389, 2, "main")
local autoTab = Core.buildRayfieldTab(section, "Auto", 10734923214, 2, "auto")
local shopTab = Core.buildRayfieldTab(section, "Shop", 10734952479, 1, "shop")
local miscTab = Core.buildRayfieldTab(section, "Misc", 10734950020, 1, "misc")
local settingsTab = Core.buildRayfieldTab(section, "Settings", 10734950309, 1, "settings")

local farm = Core.buildRayfieldGroup(mainTab, "Farming", 1, nil, nil, "farm")
local tween = Core.buildRayfieldGroup(mainTab, "Movement", 2, nil, nil, "tween")
local aura = Core.buildRayfieldGroup(autoTab, "Auras", 1, nil, nil, "aura")
local equip = Core.buildRayfieldGroup(autoTab, "Gear", 2, nil, nil, "equip")
local shop = Core.buildRayfieldGroup(shopTab, "Shop", 1, nil, nil, "shop_items")
local util = Core.buildRayfieldGroup(miscTab, "Extras", 1, nil, nil, "utils")

local winTargetsW1 = { "Win 1", "Win 3", "Win 10", "Win 20", "Win 50", "Win 100", "Win 150", "Win 300", "Win 500", "Win 1000", "Win 2500" }
local winTargetsW2 = { "Win 250k", "Win 400k", "Win 600k", "Win 1M", "Win 1.5M", "Win 2.5M" }

farm:CreateToggle("Step farm", state.AutoStepFarm, "Hits the purple step popup for you.", function(enabled)
	state.AutoStepFarm = enabled
end)
farm:CreateToggle("Win farm", state.AutoWinsFarm, "Picks a smart route and farms wins.", function(enabled)
	state.AutoWinsFarm = enabled
end)
farm:CreateDropdown("Stop at (World 1)", winTargetsW1, state.LastWinTargetW1 or "Win 500", function(value)
	state.LastWinTargetW1 = value
	if not state.isWorld2 then
		state.SelectedWinTarget = value
	end
end)
farm:CreateDropdown("Stop at (World 2)", winTargetsW2, state.LastWinTargetW2 or "Win 250k", function(value)
	state.LastWinTargetW2 = value
	if state.isWorld2 then
		state.SelectedWinTarget = value
	end
end)

tween:CreateSlider("Move speed", 50, 300, state.TweenSpeed, function(value)
	state.TweenSpeed = value
	_G.TweenSpeed = value
end, "How fast you glide between spots.")
tween:CreateToggle("Lock in place", state.FreezePosition, "Stops you sliding around on the treadmill.", function(enabled)
	state.FreezePosition = enabled
end)
tween:CreateToggle("Auto rebirth", state.AutoRebirth, "Rebirths when you can afford it.", function(enabled)
	state.AutoRebirth = enabled
end)
tween:CreateDropdown("Treadmill", { "Normal", "Gold", "Diamond", "Candy", "Admin" }, state.TargetTreadmill, function(value)
	state.TargetTreadmill = value
end)
tween:CreateButton("Skip treadmill", function()
	state.BypassFunction()
	notify("Alleral", "Treadmill skip is on.")
end)
tween:CreateButton("Unlock infinity trail", function()
	local ok, result = state.UnlockInfinityTrail()
	notify("Alleral", ok and result and "Infinity trail unlocked." or "Couldn't unlock infinity trail.")
end)

aura:CreateDropdown("Pick aura", { "GlowAura", "Wind Aura", "Water Aura", "Fire Aura", "Medal Aura" }, state.SelectedAura, function(value)
	state.SelectedAura = value
end)
aura:CreateButton("Buy aura", function()
	local ok, result = state.UnlockAuraBypass(state.SelectedAura)
	notify("Alleral", ok and result and "Aura bought." or "Buy didn't go through.")
end)
aura:CreateButton("Wear aura", function()
	if EquipAuraRemote and state.SelectedAura then
		EquipAuraRemote:FireServer(state.SelectedAura:gsub("%s+", ""))
		notify("Alleral", "Aura equipped.")
	end
end)

equip:CreateToggle("Equip best gear", state.AutoEquipBest, "Keeps your best items on.", function(enabled)
	state.AutoEquipBest = enabled
end)

shop:AddDropdown("Target Items", {
	Text = "What to buy",
	Values = { "Common", "Uncommon", "Rare", "Epic" },
	Default = state.TargetBuyItems,
	Multi = true,
	Callback = function(selected)
		state.TargetBuyItems = selected
	end,
})
shop:CreateToggle("Auto buy", state.AutoBuyItems, "Buys whatever you picked above.", function(enabled)
	state.AutoBuyItems = enabled
end)

util:CreateToggle("Anti AFK", state.AntiAFK ~= false, "So you don't get kicked for idling.", function(enabled)
	state.AntiAFK = enabled
	if enabled then
		Core.setupAntiAfk(LocalPlayer)
	end
end)

settingsTab:BuildThemeGroupbox(1)
Core.buildScriptStatusGroupbox(settingsTab, 1, "speed_keyboard_escape", VERSION)
Core.buildRoScriptsSearch(settingsTab, 2, rayfield)

notify("Alleral", "Loaded. Tabs on the left.")

state.Alleral_Unload = function()
	state.HubRunning = false
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
	setAnchored(false)
end
