#!/usr/bin/env python3
"""Emit readable speed_keyboard_escape.luau with evaluated route tables."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / "reference" / "speed_keyboard_escape.deobfuscated.lua"
OUT = ROOT / "src" / "speed_keyboard_escape.luau"


def eval_num(expr: str) -> float:
    expr = expr.strip()
    try:
        return eval(expr, {"__builtins__": {}})  # noqa: S307
    except Exception:
        raise ValueError(f"Cannot eval: {expr}") from None


def parse_vector3(call: str) -> tuple[float, float, float]:
    inner = call[len("Vector3.new(") : -1]
    parts = []
    depth = 0
    buf = ""
    for ch in inner:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(buf.strip())
            buf = ""
        else:
            buf += ch
    if buf.strip():
        parts.append(buf.strip())
    if len(parts) != 3:
        raise ValueError(f"Bad vector: {call}")
    return tuple(eval_num(p) for p in parts)


def iter_vector3_calls(text: str):
    needle = "Vector3.new("
    pos = 0
    while True:
        start = text.find(needle, pos)
        if start < 0:
            break
        i = start + len(needle)
        depth = 1
        while i < len(text) and depth > 0:
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                depth -= 1
            i += 1
        yield text[start:i]
        pos = i


def extract_table_vectors(src: str, start_marker: str, end_marker: str) -> list[tuple[float, float, float]]:
    start = src.index(start_marker) + len(start_marker)
    end = src.index(end_marker, start)
    chunk = src[start:end]
    return [parse_vector3(call) for call in iter_vector3_calls(chunk)]


def fmt_vector(v: tuple[float, float, float]) -> str:
    x, y, z = v
    def f(n: float) -> str:
        if n == int(n):
            return str(int(n))
        return str(n)

    return f"Vector3.new({f(x)}, {f(y)}, {f(z)})"


def extract_win_config(src: str, marker: str, next_marker: str) -> str:
    start = src.index(marker) + len(marker)
    end = src.index(next_marker, start)
    chunk = src[start:end]
    entries = re.findall(r"\['([^']+)'\]=\{([^}]+)\}", chunk)
    lines = ["{"]
    for name, body in entries:
        route = re.search(r"\['RouteIndex'\]=([^,\[]+)", body)
        block = re.search(r"\['BlockName'\]='([^']+)'", body)
        mint = re.search(r"\['MinTime'\]=([^,\[]+)", body)
        if not route or not block or not mint:
            continue
        ri = int(eval_num(route.group(1).strip()))
        mt = eval_num(mint.group(1).strip())
        lines.append(f'\t["{name}"] = {{ RouteIndex = {int(ri)}, BlockName = "{block.group(1)}", MinTime = {mt} }},')
    lines.append("}")
    return "\n".join(lines)


def main() -> None:
    src = REF.read_text(encoding="utf-8")
    w1 = extract_table_vectors(src, "local v52={", "};local v53=")
    w2 = extract_table_vectors(src, "local v54={", "};local v55=")
    w1_cfg = extract_win_config(src, "local v53={", "};local v54=")
    w2_cfg = extract_win_config(src, "local v55={", "};v14.isWorld2")

    w1_lines = ",\n\t".join(fmt_vector(v) for v in w1)
    w2_lines = ",\n\t".join(fmt_vector(v) for v in w2)

    body = HEADER.format(
        w1_routes=w1_lines,
        w2_routes=w2_lines,
        w1_config=w1_cfg,
        w2_config=w2_cfg,
    )
    OUT.write_text(body, encoding="utf-8")
    print(f"Wrote {OUT} ({len(body):,} bytes, {body.count(chr(10)) + 1} lines)")


HEADER = r'''getgenv().Alleral_State = getgenv().Alleral_State or {{}}

if not getgenv().Alleral_Boot then
	warn("[Alleral] Not the official script — grab it from the real loader")
	return
end
getgenv().Alleral_Boot = nil

local VERSION = "1.0"
local state = getgenv().Alleral_State
local Core = getgenv().Alleral_Core
local connections = {{}}
local loops = {{}}
local loopControllers = {{}}

if state.Alleral_Unload then
	pcall(state.Alleral_Unload)
end

local rayfield
local bootErr
local bootApi = getgenv().Alleral_Core
if not bootApi or not bootApi.prepareGame then
	warn("[Alleral] Core missing — run loader.luau first")
	return
end
Core, rayfield, bootErr = bootApi.prepareGame(state)
if not Core or not rayfield then
	warn("[Alleral] Boot failed: " .. tostring(bootErr))
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

local defaults = {{
	HubRunning = true,
	AutoStepFarm = false,
	AutoWinsFarm = false,
	SelectedWinTarget = workspace:FindFirstChild("WORLD 2") and "Win 250k" or "Win 500",
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
	TargetBuyItems = {{ "Common" }},
	AutoEquipBest = false,
	SelectedAura = "GlowAura",
	World2WallState = "Unknown",
	World2LavaState = "Unknown",
}}

for key, value in pairs(defaults) do
	if state[key] == nil then
		state[key] = value
	end
end

_G.TweenSpeed = state.TweenSpeed

local function notify(title, text, duration)
	Core.notify(title, text, duration)
end

-- Route data (World 1)
local ROUTE_WORLD1 = {{
	{w1_routes}
}}

local ROUTE_WORLD2 = {{
	{w2_routes}
}}

local WIN_CONFIG_WORLD1 = {w1_config}

local WIN_CONFIG_WORLD2 = {w2_config}

local ITEM_PRICES = {{
	Common = 2500,
	Uncommon = 25000,
	Rare = 250000,
	Mysterious = 3500000,
}}

local function refreshWorldRoutes()
	state.isWorld2 = workspace:FindFirstChild("WORLD 2") ~= nil
	state.CurrentRoute = state.isWorld2 and ROUTE_WORLD2 or ROUTE_WORLD1
	state.CurrentConfig = state.isWorld2 and WIN_CONFIG_WORLD2 or WIN_CONFIG_WORLD1
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

local sensors = {{
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
}}

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
		for _, entry in ipairs(eventsCfg.Trails or {{}}) do
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
	local moving = {{}}
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
		{{ CFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0)) }}
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

-- Supervisors
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

-- Rayfield UI
local window = Core.buildRayfieldWindow(rayfield, {{
	Name = "Alleral",
	Subtitle = "Speed Keyboard Escape · v" .. VERSION,
	Icon = 10723407389,
	LoadingEnabled = false,
}})
local section = window:CreateTabSection("Alleral", true)
local mainTab = section:CreateTab({{ Name = "Main", Icon = 10723407389, Columns = 2 }}, "main")
local autoTab = section:CreateTab({{ Name = "Auto", Icon = 10734923214, Columns = 2 }}, "auto")
local shopTab = section:CreateTab({{ Name = "Shop", Icon = 10734952479, Columns = 1 }}, "shop")
local miscTab = section:CreateTab({{ Name = "Misc", Icon = 10734950020, Columns = 1 }}, "misc")

local farmGroup = mainTab:CreateGroupbox({{ Name = "Farming", Column = 1 }}, "farm")
local tweenGroup = mainTab:CreateGroupbox({{ Name = "Tween", Column = 2 }}, "tween")
local auraGroup = autoTab:CreateGroupbox({{ Name = "Aura", Column = 1 }}, "aura")
local equipGroup = autoTab:CreateGroupbox({{ Name = "Equip", Column = 2 }}, "equip")
local shopGroup = shopTab:CreateGroupbox({{ Name = "Items", Column = 1 }}, "shop_items")
local utilGroup = miscTab:CreateGroupbox({{ Name = "Utilities", Column = 1 }}, "utils")

local farm = Core.wrapUiGroup(farmGroup, function() end)
local tween = Core.wrapUiGroup(tweenGroup, function() end)
local aura = Core.wrapUiGroup(auraGroup, function() end)
local equip = Core.wrapUiGroup(equipGroup, function() end)
local shop = Core.wrapUiGroup(shopGroup, function() end)
local util = Core.wrapUiGroup(utilGroup, function() end)

local winTargetsW1 = {{ "Win 1", "Win 3", "Win 10", "Win 20", "Win 50", "Win 100", "Win 150", "Win 300", "Win 500", "Win 1000", "Win 2500" }}
local winTargetsW2 = {{ "Win 250k", "Win 400k", "Win 600k", "Win 1M", "Win 1.5M", "Win 2.5M" }}

farm:CreateToggle("Auto Step Farm", state.AutoStepFarm, "Purple pop-up step training", function(enabled)
	state.AutoStepFarm = enabled
end)
farm:CreateToggle("Auto Wins Farm", state.AutoWinsFarm, "Smart route win farming", function(enabled)
	state.AutoWinsFarm = enabled
end)
farm:CreateDropdown("Win Target (W1)", winTargetsW1, state.SelectedWinTarget, function(value)
	if not state.isWorld2 then
		state.SelectedWinTarget = value
	end
end)
farm:CreateDropdown("Win Target (W2)", winTargetsW2, state.SelectedWinTarget, function(value)
	if state.isWorld2 then
		state.SelectedWinTarget = value
	end
end)

tween:CreateSlider("Tween Speed", 50, 300, state.TweenSpeed, function(value)
	state.TweenSpeed = value
	_G.TweenSpeed = value
end)
tween:CreateToggle("Freeze Position", state.FreezePosition, "Anchor while on treadmill", function(enabled)
	state.FreezePosition = enabled
end)
tween:CreateToggle("Auto Rebirth", state.AutoRebirth, nil, function(enabled)
	state.AutoRebirth = enabled
end)
tween:CreateDropdown("Treadmill", {{ "Normal", "Gold", "Diamond", "Candy", "Admin" }}, state.TargetTreadmill, function(value)
	state.TargetTreadmill = value
end)
tween:CreateButton("Bypass Treadmill", function()
	state.BypassFunction()
	notify("Alleral", "Treadmill bypass applied")
end)
tween:CreateButton("Unlock Infinity Trail", function()
	local ok = state.UnlockInfinityTrail()
	notify("Alleral", ok and "Infinity trail unlocked" or "Infinity trail failed")
end)

aura:CreateDropdown("Aura", {{ "GlowAura", "Wind Aura", "Water Aura", "Fire Aura", "Medal Aura" }}, state.SelectedAura, function(value)
	state.SelectedAura = value
end)
aura:CreateButton("Buy Aura", function()
	local ok = state.UnlockAuraBypass(state.SelectedAura)
	notify("Alleral", ok and "Aura bought" or "Aura buy failed")
end)
aura:CreateButton("Equip Aura", function()
	if EquipAuraRemote and state.SelectedAura then
		EquipAuraRemote:FireServer(state.SelectedAura:gsub("%s+", ""))
		notify("Alleral", "Aura equipped")
	end
end)

equip:CreateToggle("Auto Equip Best", state.AutoEquipBest, nil, function(enabled)
	state.AutoEquipBest = enabled
end)

shop:AddDropdown("Target Items", {{
	Text = "Buy Items",
	Values = {{ "Common", "Uncommon", "Rare", "Epic" }},
	Default = state.TargetBuyItems,
	Multi = true,
	Callback = function(selected)
		state.TargetBuyItems = selected
	end,
}})
shop:CreateToggle("Auto Buy Items", state.AutoBuyItems, nil, function(enabled)
	state.AutoBuyItems = enabled
end)

util:CreateToggle("Anti AFK", state.AntiAFK ~= false, nil, function(enabled)
	state.AntiAFK = enabled
	if enabled then
		Core.setupAntiAfk(LocalPlayer)
	end
end)

notify("Alleral", "Speed Keyboard Escape loaded")

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
'''


if __name__ == "__main__":
    main()
