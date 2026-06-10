#!/usr/bin/env python3
"""Emit fully readable build_a_ring_farm.luau (slime_rng quality)."""

from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "src" / "build_a_ring_farm.luau"

# The Luau source is stored in emit_clean_barf.luau.part files or inline below.
# Run: python tools/emit_clean_barf.py

LUau = r'''getgenv().Alleral_State = getgenv().Alleral_State or {}

if not getgenv().Alleral_Boot then
	warn("[Alleral] Not the official script — grab it from the real loader")
	return
end
getgenv().Alleral_Boot = nil

local VERSION = "1.1"
local state = getgenv().Alleral_State
local Core = getgenv().Alleral_Core
local connections = {}
local loops = {}
local loopControllers = {}

if state.Alleral_Unload then
	pcall(state.Alleral_Unload)
end

local starlight
local bootErr
local bootApi = getgenv().Alleral_Core
if not bootApi or not bootApi.prepareGame then
	warn("[Alleral] Core missing — run loader.luau first")
	return
end
Core, starlight, bootErr = bootApi.prepareGame(state)
if not Core or not starlight then
	warn("[Alleral] Boot failed: " .. tostring(bootErr))
	return
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

local savedKeys = {
	"AutoPlaceSeed", "AutoUnlockPlot", "AutoSell", "AutoBuySeed", "AutoRollManual",
	"AutoDiscardSeed", "TargetDiscardSeed", "AutoUpgradeSeed", "AutoRemoveSeed",
	"TargetPlantAction", "TargetPlantActionRarity", "TargetPlaceSeed", "TargetSeed",
	"TargetSeedRarity", "MaxUpgradeLevel", "SellDelay", "RollDelay", "TargetPlaceSeedRarity",
	"TargetPlantPlot", "TargetDiscardSeedRarity", "AutoBuyGear", "TargetGear",
	"AutoUpgradeSeedRolls", "AutoUpgradeSeedLuck", "AutoExpandFarm", "AutoUpgradeSawRange",
	"AutoUpgradeSawYield", "AutoUpgradeSprinklerRange", "AutoUpgradeSprinklerPower",
	"TargetUpgradeFloor", "AutoBuyEgg", "AutoUnlockEgg", "TargetEgg", "AutoBuyEventShop",
	"TargetEventItem", "AutoSubmitEventSeed", "TargetEventSeed", "TargetEventSeedRarity",
	"AutoShootEvent", "AutoCollectRushDrops", "AutoCollectAlienDrop", "TargetEnemyPriority",
	"AutoComposter", "AutoPullLever", "TargetComposterTier", "TargetCompostSeed",
	"TargetCompostRarity", "TargetComposterFloor", "AutoHoney", "AutoRollHoney",
	"AutoContractSubmit", "AutoContractReroll", "TargetContractSlot", "IgnoreContractSeeds",
	"AntiAFK", "EnableFly", "FlySpeed", "AutoSpray", "AutoFertilizer", "TargetFertilizer",
	"AutoFeedPet", "TargetFeedPet", "AutoOptimizePets", "TargetPetTreat", "TargetSprayPlant",
	"TargetSprayType", "AutoSellPet", "TargetSellPetRarity", "TargetSellPetName",
	"TargetSellPetLive", "AutoClaimPlaytime", "AutoOpenBox", "AutoUpgradePlotStats",
	"TargetPlotStats", "ActivePresetName",
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

local function notify(title, text, duration)
	Core.notify(title, text, duration)
end

-- Runtime cache (not persisted)
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

'''

def main() -> None:
	part_path = Path(__file__).with_name("emit_clean_barf_body.luau")
	if not part_path.exists():
		raise SystemExit(f"Missing body file: {part_path}")
	body = part_path.read_text(encoding="utf-8")
	footer_path = Path(__file__).with_name("emit_clean_barf_footer.luau")
	footer = footer_path.read_text(encoding="utf-8")
	out = LUau + body + footer
	OUT.write_text(out, encoding="utf-8")
	lines = out.count("\n") + 1
	import re
	vpat = len(re.findall(r"\bv\d+\b", out))
	tmppat = len(re.findall(r"\btmp\d+\b", out))
	sm = out.count("while true do\n\t\tif (")
	print(f"Wrote {OUT} ({lines} lines, {len(out):,} bytes)")
	print(f"v### count: {vpat}, tmp### count: {tmppat}, state-machine-ish: {sm}")


if __name__ == "__main__":
	main()
