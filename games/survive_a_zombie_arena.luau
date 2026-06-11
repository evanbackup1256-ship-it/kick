getgenv().Alleral_State = getgenv().Alleral_State or {}

if not getgenv().Alleral_Boot then
	warn("[Alleral] load the hub first")
	return
end
getgenv().Alleral_Boot = nil

local VERSION = "2.1"
local state = getgenv().Alleral_State
local Core = getgenv().Alleral_Core
local G = (Core and Core.Game) or getgenv().Alleral_GameHelpers or {}
local connections = {}
local loops = {}
local loopControllers = {}

if state.Alleral_Unload then
	pcall(state.Alleral_Unload)
end

local ui
local bootErr
if not Core or not Core.prepareGame then
	local msg = "Core not loaded"
	getgenv().Alleral_StartupFailed = msg
	warn("[Alleral] " .. msg)
	return
end
Core, ui, bootErr = Core.prepareGame(state)
if not Core or not ui then
	local msg = "Boot failed: " .. tostring(bootErr)
	getgenv().Alleral_StartupFailed = msg
	warn("[Alleral] " .. msg)
	return
end
G = Core.Game or G

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

local SETTINGS_FILE = "survive_a_zombie_arena.json"
local SAFE_SPOTS = {
	Classic = CFrame.new(-92, 2, -192),
	CornerA = CFrame.new(-95, 2, -195),
	CornerB = CFrame.new(-88, 2, -188),
	High = CFrame.new(-92, 12, -192),
}

local defaults = {
	HubRunning = true,
	AAutoFarm = false,
	AKillAura = false,
	AInstantKill = true,
	AHitboxExpand = false,
	HitboxScale = 3,
	AAimbot = false,
	AAutoShoot = false,
	AGodMode = false,
	ASafeZone = false,
	SafeZoneHeight = 25,
	ATeleportSafe = false,
	SafeSpot = "Classic",
	AAutoSkip = false,
	ACollectShards = false,
	AAutoEquip = false,
	AAutoUpgrade = false,
	AAutoBuy = false,
	APlantMine = false,
	ARemoveGates = false,
	AZombieEsp = false,
	AntiAFK = true,
	AFly = false,
	ANoclip = false,
	WalkSpeed = 16,
	JumpPower = 50,
	FlySpeed = 50,
	FieldOfView = 70,
	KillAuraRange = 150,
	KillDamage = 999999,
	SkipInterval = 2,
	ShootInterval = 0.04,
	ShardScanInterval = 0.3,
	EspRange = 200,
	UpgradeInterval = 4,
	BuyInterval = 5,
	MineInterval = 6,
	GodModeInterval = 0.25,
}

local savedKeys
local saveSettings

saveSettings, savedKeys = Core.initSettings(state, defaults, SETTINGS_FILE)
state.SafeSpot = Core.normalizeDropdownValue(state.SafeSpot, "Classic")

local function notify(title, text, duration)
	Core.notify(title, text, duration)
end

local function track(connection)
	return G.track and G.track(connections, connection) or connection
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

local runtime = {
	remotes = {},
	zombieTable = nil,
	lastSkip = 0,
	lastShoot = 0,
	lastShardScan = 0,
	lastUpgrade = 0,
	lastBuy = 0,
	lastMine = 0,
	gatesRemoved = false,
	espHighlights = {},
	hitboxTouched = {},
}

local function refreshRemotes()
	runtime.remotes = G.indexRemotes and G.indexRemotes(ReplicatedStorage, runtime.remotes) or runtime.remotes
	local zombieRemotes = ReplicatedStorage:FindFirstChild("ZombieRemotes")
	if zombieRemotes then
		runtime.remotes.ZombieDamage = zombieRemotes:FindFirstChild("ZombieDamage") or runtime.remotes.ZombieDamage
	end
	local waveRemotes = ReplicatedStorage:FindFirstChild("WaveRemotes")
	if waveRemotes then
		runtime.remotes.SkipVote = waveRemotes:FindFirstChild("SkipVote") or runtime.remotes.SkipVote
	end
end

refreshRemotes()

local function resolveZombieTable()
	if runtime.zombieTable then
		return runtime.zombieTable
	end
	local ok, client = pcall(function()
		local controllers = LocalPlayer:WaitForChild("PlayerScripts", 8):FindFirstChild("Controllers")
		local zombieClient = controllers and controllers:FindFirstChild("ZombieClient")
		if not zombieClient then
			return nil
		end
		return require(zombieClient)
	end)
	if ok and client and type(client.Zombies) == "table" then
		runtime.zombieTable = client.Zombies
		return runtime.zombieTable
	end
	local gcTable = G.getGcTable and G.getGcTable(function(value)
		return rawget(value, "Zombies") and rawget(value, "ZombieModels")
	end)
	if gcTable and gcTable.Zombies then
		runtime.zombieTable = gcTable.Zombies
	end
	return runtime.zombieTable
end

local function zombieFolder()
	return Workspace:FindFirstChild("Zombies_Local") or Workspace:FindFirstChild("Zombies")
end

local function zombieModelFor(id, data)
	if data and data.Model and data.Model.Parent then
		return data.Model
	end
	local folder = zombieFolder()
	return folder and folder:FindFirstChild(tostring(id))
end

local function livingZombies()
	local zombies = resolveZombieTable()
	local list = {}
	if not zombies then
		local folder = zombieFolder()
		if folder then
			for _, model in ipairs(folder:GetChildren()) do
				if model:IsA("Model") then
					local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
					if part then
						table.insert(list, {
							id = model.Name,
							data = nil,
							model = model,
							part = part,
						})
					end
				end
			end
		end
		return list
	end
	for id, data in pairs(zombies) do
		if data and not data.IsDying and (tonumber(data.Health) or 0) > 0 then
			local model = zombieModelFor(id, data)
			local part = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
			if part then
				table.insert(list, {
					id = id,
					data = data,
					model = model,
					part = part,
				})
			end
		end
	end
	return list
end

local function inKillRange(root, part)
	if not root or not part then
		return true
	end
	return (root.Position - part.Position).Magnitude <= (tonumber(state.KillAuraRange) or 150)
end

local function fireNamed(names, payloads)
	return G.probeRemote and G.probeRemote(runtime.remotes, names, payloads) or false
end

local function killAuraTick()
	if not state.AKillAura and not state.AAutoFarm then
		return
	end
	refreshRemotes()
	local damageRemote = runtime.remotes.ZombieDamage or G.findRemote(runtime.remotes, { "ZombieDamage" })
	if not damageRemote then
		return
	end
	local _, _, root = characterParts()
	local damage = state.AInstantKill and math.huge or (tonumber(state.KillDamage) or 999999)
	for _, entry in ipairs(livingZombies()) do
		if inKillRange(root, entry.part) then
			pcall(function()
				if G.fireRemote then
					G.fireRemote(damageRemote, entry.id, damage)
				else
					damageRemote:FireServer(entry.id, damage)
				end
			end)
		end
	end
end

local function hitboxTick()
	if not state.AHitboxExpand then
		if G.restoreHitboxes then
			G.restoreHitboxes(zombieFolder(), runtime.hitboxTouched)
		end
		return
	end
	local scale = tonumber(state.HitboxScale) or 3
	for _, entry in ipairs(livingZombies()) do
		if entry.model then
			runtime.hitboxTouched[entry.model] = true
			if G.expandHitbox then
				G.expandHitbox(entry.model, scale)
			end
		end
	end
end

local function aimbotTick()
	if not state.AAimbot then
		return
	end
	local camera = Workspace.CurrentCamera
	local _, _, root = characterParts()
	if not camera or not root then
		return
	end
	local nearest = G.nearestTarget and G.nearestTarget(root.Position, livingZombies(), state.KillAuraRange)
	if nearest and G.aimAt then
		G.aimAt(camera, nearest.part)
	end
end

local function autoShootTick()
	if not state.AAutoShoot and not state.AAutoFarm then
		return
	end
	if tick() < runtime.lastShoot + (state.ShootInterval or 0.04) then
		return
	end
	runtime.lastShoot = tick()
	local character, humanoid = characterParts()
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	if state.AAutoEquip or state.AAutoFarm then
		local tool = G.bestTool and G.bestTool(LocalPlayer)
		if tool and tool.Parent ~= character then
			pcall(function()
				humanoid:EquipTool(tool)
			end)
		end
	end
	local tool = character:FindFirstChildWhichIsA("Tool")
	if not tool then
		tool = G.bestTool and G.bestTool(LocalPlayer)
		if tool then
			pcall(function()
				humanoid:EquipTool(tool)
			end)
		end
	end
	if tool then
		pcall(function()
			tool:Activate()
		end)
	end
	if state.AAimbot then
		aimbotTick()
	end
end

local function autoSkipTick()
	if not state.AAutoSkip and not state.AAutoFarm then
		return
	end
	if tick() < runtime.lastSkip + (state.SkipInterval or 2) then
		return
	end
	runtime.lastSkip = tick()
	refreshRemotes()
	local skipVote = runtime.remotes.SkipVote or G.findRemote(runtime.remotes, { "SkipVote", "WaveRemotes.SkipVote" })
	if skipVote then
		pcall(function()
			if G.fireRemote then
				G.fireRemote(skipVote, true)
			else
				skipVote:FireServer(true)
			end
		end)
	end
end

local function isPickup(instance)
	if not instance then
		return false
	end
	local name = instance.Name:lower()
	if
		name:find("shard")
		or name:find("galactic")
		or name:find("pickup")
		or name:find("drop")
		or name:find("mineral")
		or name:find("coin")
		or name:find("credit")
	then
		return true
	end
	return instance:GetAttribute("Shard")
		or instance:GetAttribute("Pickup")
		or instance:GetAttribute("Collectible")
		or instance:GetAttribute("Coin")
end

local function collectShardsTick()
	if not state.ACollectShards and not state.AAutoFarm then
		return
	end
	if tick() < runtime.lastShardScan + (state.ShardScanInterval or 0.3) then
		return
	end
	runtime.lastShardScan = tick()
	local _, humanoid, root = characterParts()
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local nearest
	local nearestDist = math.huge
	for _, item in ipairs(Workspace:GetDescendants()) do
		if isPickup(item) and (item:IsA("BasePart") or item:IsA("Model")) then
			local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
			if part and part.Parent then
				local dist = (root.Position - part.Position).Magnitude
				if dist < nearestDist and dist < 300 then
					nearestDist = dist
					nearest = part
				end
			end
		end
	end
	if nearest then
		root.CFrame = nearest.CFrame + Vector3.new(0, 2.5, 0)
	end
end

local function autoUpgradeTick()
	if not state.AAutoUpgrade and not state.AAutoFarm then
		return
	end
	if tick() < runtime.lastUpgrade + (state.UpgradeInterval or 4) then
		return
	end
	runtime.lastUpgrade = tick()
	refreshRemotes()
	fireNamed({
		"UpgradeWeapon",
		"WeaponUpgrade",
		"Upgrade",
		"UpgradeGun",
		"ShopRemotes.Upgrade",
		"UpgradeRemotes.Upgrade",
	}, { {}, { true }, { "Weapon" }, { "Gun" } })
end

local function autoBuyTick()
	if not state.AAutoBuy and not state.AAutoFarm then
		return
	end
	if tick() < runtime.lastBuy + (state.BuyInterval or 5) then
		return
	end
	runtime.lastBuy = tick()
	refreshRemotes()
	fireNamed({
		"BuyWeapon",
		"BuyGun",
		"Buy",
		"Purchase",
		"ShopBuy",
		"ShopRemotes.Buy",
		"ShopRemotes.Purchase",
	}, { {}, { true }, { "Best" }, { "Gun" }, { "Weapon" } })
end

local function plantMineTick()
	if not state.APlantMine then
		return
	end
	if tick() < runtime.lastMine + (state.MineInterval or 6) then
		return
	end
	runtime.lastMine = tick()
	refreshRemotes()
	fireNamed({
		"PlantMine",
		"PlaceMine",
		"MinePlace",
		"DeployMine",
		"MineRemotes.Plant",
	}, { {}, { true }, { "Mine" } })
end

local function applySafeZone(humanoid)
	if not humanoid then
		return
	end
	if state.ASafeZone or state.AAutoFarm then
		humanoid.HipHeight = state.SafeZoneHeight or 25
	end
end

local function teleportSafe(root, force)
	if not root then
		return
	end
	if not force and not state.ATeleportSafe and not state.AAutoFarm then
		return
	end
	local spot = SAFE_SPOTS[state.SafeSpot] or SAFE_SPOTS.Classic
	root.CFrame = spot
end

local function removeGates()
	if runtime.gatesRemoved or (not state.ARemoveGates and not state.AAutoFarm) then
		return
	end
	local gates = Workspace:FindFirstChild("Gates")
	if gates then
		pcall(function()
			gates:Destroy()
		end)
		runtime.gatesRemoved = true
	end
end

local function godModeTick()
	if not state.AGodMode and not state.AAutoFarm then
		return
	end
	local _, humanoid = characterParts()
	if G.applyGodMode then
		G.applyGodMode(humanoid, true)
	else
		if humanoid and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = humanoid.MaxHealth
		end
	end
end

local function movementTick()
	local character, humanoid, root = characterParts()
	if G.applyWalkSpeed then
		G.applyWalkSpeed(humanoid, state.WalkSpeed)
	else
		if humanoid then
			humanoid.WalkSpeed = state.WalkSpeed
		end
	end
	if G.applyJumpPower then
		G.applyJumpPower(humanoid, state.JumpPower)
	elseif humanoid then
		humanoid.JumpPower = state.JumpPower
	end
	if G.setFov then
		G.setFov(state.FieldOfView)
	end
	applySafeZone(humanoid)
	teleportSafe(root)
	removeGates()
	if state.AFly and root then
		if G.ensureFly then
			G.ensureFly(root, runtime, state.FlySpeed)
		end
	elseif G.stopFly then
		G.stopFly(runtime)
	end
	if G.applyNoclip then
		G.applyNoclip(character, state.ANoclip)
	end
end

local function espTick()
	if not state.AZombieEsp then
		if G.clearHighlights then
			G.clearHighlights(runtime.espHighlights)
		end
		return
	end
	local _, _, root = characterParts()
	local origin = root and root.Position
	local active = {}
	for _, entry in ipairs(livingZombies()) do
		if entry.model and origin and (origin - entry.part.Position).Magnitude <= (state.EspRange or 200) then
			active[entry.model] = true
			if G.setHighlight then
				G.setHighlight(entry.model, runtime.espHighlights, true, Color3.fromRGB(255, 60, 60))
			end
		end
	end
	for model, highlight in pairs(runtime.espHighlights) do
		if not active[model] then
			if G.setHighlight then
				G.setHighlight(model, runtime.espHighlights, false)
			elseif highlight then
				pcall(function()
					highlight:Destroy()
				end)
				runtime.espHighlights[model] = nil
			end
		end
	end
end

local function waveLabel()
	for _, name in ipairs({ "Wave", "Round", "CurrentWave" }) do
		local value = G.leaderstatValue and G.leaderstatValue(LocalPlayer, name)
		if value and value ~= "?" then
			return value
		end
		local folder = ReplicatedStorage:FindFirstChild(name) or Workspace:FindFirstChild(name)
		if folder then
			local num = folder:FindFirstChild("Number") or folder:FindFirstChild("Value") or folder:FindFirstChild("Current")
			if num and (num:IsA("IntValue") or num:IsA("NumberValue")) then
				return tostring(num.Value)
			end
		end
	end
	return "?"
end

local function applyAutoFarmPreset(enabled)
	if enabled then
		state.AKillAura = true
		state.AInstantKill = true
		state.AAutoSkip = true
		state.AAutoShoot = true
		state.AGodMode = true
		state.ASafeZone = true
		state.ATeleportSafe = true
		state.ACollectShards = true
		state.AAutoEquip = true
		state.AAutoUpgrade = true
		state.AAutoBuy = true
		state.ARemoveGates = true
		notify("Alleral", "Auto farm preset enabled.", 3)
	else
		notify("Alleral", "Auto farm preset disabled.", 3)
	end
	saveSettings()
end

Core.makeSupervisor(state, loops, loopControllers, "KillAura", 0.15, killAuraTick)
Core.makeSupervisor(state, loops, loopControllers, "Hitbox", 0.5, hitboxTick)
Core.makeSupervisor(state, loops, loopControllers, "AutoShoot", 0.06, autoShootTick)
Core.makeSupervisor(state, loops, loopControllers, "AutoSkip", 0.8, autoSkipTick)
Core.makeSupervisor(state, loops, loopControllers, "CollectShards", 0.2, collectShardsTick)
Core.makeSupervisor(state, loops, loopControllers, "AutoUpgrade", 1, autoUpgradeTick)
Core.makeSupervisor(state, loops, loopControllers, "AutoBuy", 1, autoBuyTick)
Core.makeSupervisor(state, loops, loopControllers, "PlantMine", 1, plantMineTick)
Core.makeSupervisor(state, loops, loopControllers, "GodMode", state.GodModeInterval or 0.25, godModeTick)
Core.makeSupervisor(state, loops, loopControllers, "Movement", 0.35, movementTick)
Core.makeSupervisor(state, loops, loopControllers, "ESP", 0.4, espTick)

if state.AntiAFK then
	Core.setupAntiAfk(LocalPlayer)
end

track(LocalPlayer.CharacterAdded:Connect(function(character)
	task.wait(1)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	applySafeZone(humanoid)
	if state.ATeleportSafe or state.AAutoFarm then
		teleportSafe(character:FindFirstChild("HumanoidRootPart"), true)
	end
end))

local window = Core.buildUiWindow(ui, {
	Subtitle = "Survive a Zombie Arena · v" .. VERSION,
})
local section = Core.buildUiSection(window)
local farmTab = Core.buildUiTab(section, "Farm", 10734923214, 2, "farm")
local combatTab = Core.buildUiTab(section, "Combat", 10723407389, 2, "combat")
local playerTab = Core.buildUiTab(section, "Player", 10734950020, 2, "player")
local visualTab = Core.buildUiTab(section, "Visual", 10709819303, 1, "visual")
local miscTab = Core.buildUiTab(section, "Misc", 10747374131, 1, "misc")
local settingsTab = Core.buildUiTab(section, "Settings", 10734950309, 1, "settings")

local saveWrap = Core.onUiSave(saveSettings)
local preset = Core.buildUiGroup(farmTab, "Auto farm", 1, saveWrap, nil, "preset")
local wave = Core.buildUiGroup(farmTab, "Waves", 2, saveWrap, nil, "waves")
local loot = Core.buildUiGroup(farmTab, "Loot & shop", 1, saveWrap, nil, "loot")
local mine = Core.buildUiGroup(farmTab, "Defense", 2, saveWrap, nil, "mine")
local aura = Core.buildUiGroup(combatTab, "Kill aura", 1, saveWrap, nil, "aura")
local shoot = Core.buildUiGroup(combatTab, "Weapons", 2, saveWrap, nil, "shoot")
local defense = Core.buildUiGroup(combatTab, "Defense", 1, saveWrap, nil, "defense")
local aim = Core.buildUiGroup(combatTab, "Aim", 2, saveWrap, nil, "aim")
local move = Core.buildUiGroup(playerTab, "Movement", 1, saveWrap, nil, "move")
local safe = Core.buildUiGroup(playerTab, "Safe zone", 2, saveWrap, nil, "safe")
local esp = Core.buildUiGroup(visualTab, "ESP", 1, saveWrap, nil, "esp")
local util = Core.buildUiGroup(miscTab, "Utilities", 1, saveWrap, nil, "util")

local function bindToggle(group, label, key, tooltip)
	group:CreateToggle(label, state[key], tooltip, function(value)
		state[key] = value
		if key == "AAutoFarm" then
			applyAutoFarmPreset(value)
		end
		saveSettings()
	end)
end

local function bindSlider(group, label, minVal, maxVal, key, tooltip, increment)
	group:CreateSlider(label, minVal, maxVal, state[key], function(value)
		state[key] = value
		saveSettings()
	end, tooltip)
end

bindToggle(preset, "Auto farm preset", "AAutoFarm", "Enables kill aura, god mode, skip, shoot, loot, shop, and safe zone.")
preset:CreateButton("One-click wave clear", function()
	state.AKillAura = true
	state.AInstantKill = true
	state.AAutoSkip = true
	saveSettings()
	notify("Alleral", "Wave clear mode armed.", 2)
end)

bindToggle(wave, "Auto skip wave", "AAutoSkip", "Votes skip through WaveRemotes.SkipVote.")
bindSlider(wave, "Skip interval", 1, 10, "SkipInterval", "Seconds between skip votes.")

bindToggle(loot, "Collect pickups", "ACollectShards", "Teleports to shards, minerals, and credit drops.")
bindToggle(loot, "Auto equip best gun", "AAutoEquip", "Equips the strongest tool in backpack.")
bindToggle(loot, "Auto upgrade", "AAutoUpgrade", "Probes upgrade remotes from public SZA scripts.")
bindSlider(loot, "Upgrade interval", 2, 15, "UpgradeInterval", "Seconds between upgrade attempts.")
bindToggle(loot, "Auto buy", "AAutoBuy", "Probes shop/buy remotes for guns and turrets.")
bindSlider(loot, "Buy interval", 2, 20, "BuyInterval", "Seconds between buy attempts.")

bindToggle(mine, "Auto plant mine", "APlantMine", "Fires mine placement remotes on cooldown.")
bindSlider(mine, "Mine interval", 3, 20, "MineInterval", "Seconds between mine plants.")
bindToggle(mine, "Remove gates", "ARemoveGates", "Deletes workspace Gates once.")

bindToggle(aura, "Kill aura", "AKillAura", "ZombieRemotes.ZombieDamage — open-source instant kill aura API.")
bindToggle(aura, "Instant kill", "AInstantKill", "Uses math.huge damage per hit.")
bindSlider(aura, "Aura range", 40, 300, "KillAuraRange", "Only hit zombies inside this range.")
bindSlider(aura, "Hit damage", 100, 999999, "KillDamage", "Used when instant kill is off.")

bindToggle(shoot, "Auto shoot", "AAutoShoot", "Keeps your weapon firing.")
bindSlider(shoot, "Shoot delay", 0.02, 0.5, "ShootInterval", "Lower = faster shooting.")

bindToggle(defense, "God mode", "AGodMode", "Locks health at max (public script god mode).")
bindToggle(defense, "Safe zone height", "ASafeZone", "Raises HipHeight so zombies cannot reach you.")
bindSlider(defense, "Hip height", 10, 80, "SafeZoneHeight", "Higher = safer.")

bindToggle(aim, "Aimbot", "AAimbot", "Snaps camera to the nearest zombie while shooting.")
bindToggle(aim, "Hitbox expander", "AHitboxExpand", "Enlarges zombie hitboxes for easier hits.")
bindSlider(aim, "Hitbox scale", 2, 8, "HitboxScale", "Multiplier applied to zombie root size.")

bindToggle(move, "Fly", "AFly", "WASD + Space/Ctrl flight (public script fly mode).")
bindSlider(move, "Fly speed", 20, 120, "FlySpeed", "Flight speed while fly is on.")
bindToggle(move, "Noclip", "ANoclip", "Disables collision on your character.")
bindSlider(move, "Walk speed", 16, 120, "WalkSpeed", "Local walkspeed.")
bindSlider(move, "Jump power", 50, 200, "JumpPower", "Local jump power.")

bindToggle(safe, "Teleport safe spot", "ATeleportSafe", "Teleports to the classic safe corner.")
safe:CreateDropdown("Safe spot", { "Classic", "CornerA", "CornerB", "High" }, state.SafeSpot, function(value)
	state.SafeSpot = value
	saveSettings()
end, "Preset safe positions from public scripts.")

bindToggle(esp, "Zombie ESP", "AZombieEsp", "Highlight zombies through walls.")
bindSlider(esp, "ESP range", 50, 400, "EspRange", "Max distance to draw ESP.")

move:CreateSlider("FOV", 40, 120, state.FieldOfView, function(value)
	state.FieldOfView = value
	saveSettings()
end, "Camera field of view.")

util:CreateToggle("Anti AFK", state.AntiAFK, "Stops idle kicks.", function(value)
	state.AntiAFK = value
	if value then
		Core.setupAntiAfk(LocalPlayer)
	end
	saveSettings()
end)
util:CreateButton("Skip wave once", function()
	autoSkipTick()
	notify("Alleral", "Skip vote sent.", 2)
end)
util:CreateButton("Teleport safe", function()
	local _, _, root = characterParts()
	teleportSafe(root, true)
	notify("Alleral", "Moved to safe spot.", 2)
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

local liveStatus = util:CreateStatus("Live stats", {
	Wave = waveLabel(),
	Kills = G.leaderstatValue and G.leaderstatValue(LocalPlayer, "Kills") or "?",
	Minerals = G.leaderstatValue and G.leaderstatValue(LocalPlayer, "Minerals") or "?",
	Credits = G.leaderstatValue and G.leaderstatValue(LocalPlayer, "Credits") or "?",
	Zombies = "0",
})

Core.makeSupervisor(state, loops, loopControllers, "Stats", 1.5, function()
	liveStatus:Update("Wave", waveLabel())
	liveStatus:Update("Kills", G.leaderstatValue and G.leaderstatValue(LocalPlayer, "Kills") or "?")
	liveStatus:Update("Minerals", G.leaderstatValue and G.leaderstatValue(LocalPlayer, "Minerals") or "?")
	liveStatus:Update("Credits", G.leaderstatValue and G.leaderstatValue(LocalPlayer, "Credits") or "?")
	liveStatus:Update("Zombies", tostring(#livingZombies()))
end)

settingsTab:BuildThemeGroupbox(1)
Core.buildScriptStatusGroupbox(settingsTab, 1, "survive_a_zombie_arena", VERSION)
Core.buildHubActionsGroup(settingsTab, 2)
Core.buildConfigProfileGroup(settingsTab, {
	state = state,
	savedKeys = savedKeys,
	saveFn = saveSettings,
	version = VERSION,
	column = 2,
})

notify("Alleral", "Survive a Zombie Arena v" .. VERSION .. " loaded.", 4)

state.Alleral_Unload = function()
	state.HubRunning = false
	if G.stopFly then
		G.stopFly(runtime)
	end
	if G.clearHighlights then
		G.clearHighlights(runtime.espHighlights)
	end
	if G.restoreHitboxes then
		G.restoreHitboxes(zombieFolder(), runtime.hitboxTouched)
	end
	Core.stopAutomation(state, connections, loopControllers, loops)
end
