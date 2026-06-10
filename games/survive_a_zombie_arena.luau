getgenv().Alleral_State = getgenv().Alleral_State or {}

if not getgenv().Alleral_Boot then
	warn("[Alleral] run loader.luau first")
	return
end
getgenv().Alleral_Boot = nil

local VERSION = "1.0"
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
	local msg = "Core missing, run loader.luau first"
	getgenv().Alleral_StartupFailed = msg
	warn("[Alleral] " .. msg)
	return
end
Core, starlight, bootErr = bootApi.prepareGame(state)
if not Core or not starlight then
	local msg = "Boot failed: " .. tostring(bootErr)
	getgenv().Alleral_StartupFailed = msg
	warn("[Alleral] " .. msg)
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local SETTINGS_FILE = "survive_a_zombie_arena.json"
local defaults = {
	HubRunning = true,
	AKillAura = false,
	AInstantKill = true,
	ASafeZone = false,
	SafeZoneHeight = 25,
	ATeleportSafe = false,
	AAutoSkip = false,
	AAutoShoot = false,
	ACollectShards = false,
	ARemoveGates = false,
	AntiAFK = true,
	WalkSpeed = 16,
	KillAuraRange = 120,
	KillDamage = 999999,
	SkipInterval = 3,
	ShootInterval = 0.05,
	ShardScanInterval = 0.35,
}

local savedKeys = {
	"AKillAura",
	"AInstantKill",
	"ASafeZone",
	"SafeZoneHeight",
	"ATeleportSafe",
	"AAutoSkip",
	"AAutoShoot",
	"ACollectShards",
	"ARemoveGates",
	"AntiAFK",
	"WalkSpeed",
	"KillAuraRange",
	"KillDamage",
	"SkipInterval",
	"ShootInterval",
	"ShardScanInterval",
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

local runtime = {
	zombieTable = nil,
	zombieDamage = nil,
	skipVote = nil,
	safeCFrame = CFrame.new(-92, 2, -192),
	lastSkip = 0,
	lastShoot = 0,
	lastShardScan = 0,
	gatesRemoved = false,
}

local function getGc()
	local env = Core.Executor and Core.Executor.env or {}
	return env.getgc or env.get_gc or env.getGc
end

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
	local getgcFn = getGc()
	if type(getgcFn) == "function" then
		for _, value in pairs(getgcFn(true)) do
			if type(value) == "table" and rawget(value, "Zombies") and rawget(value, "ZombieModels") then
				runtime.zombieTable = value.Zombies
				return runtime.zombieTable
			end
		end
	end
	return nil
end

local function refreshRemotes()
	local zombieRemotes = ReplicatedStorage:FindFirstChild("ZombieRemotes")
	if zombieRemotes then
		runtime.zombieDamage = zombieRemotes:FindFirstChild("ZombieDamage")
	end
	local waveRemotes = ReplicatedStorage:FindFirstChild("WaveRemotes")
	if waveRemotes then
		runtime.skipVote = waveRemotes:FindFirstChild("SkipVote")
	end
end

refreshRemotes()

local function characterParts()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

local function applySafeZone(humanoid)
	if not humanoid then
		return
	end
	if state.ASafeZone then
		humanoid.HipHeight = state.SafeZoneHeight or 25
	end
end

local function teleportSafe(root)
	if not root or not state.ATeleportSafe then
		return
	end
	root.CFrame = runtime.safeCFrame
end

local function removeGates()
	if runtime.gatesRemoved or not state.ARemoveGates then
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

local function zombieModelFor(id, data)
	local folder = Workspace:FindFirstChild("Zombies_Local") or Workspace:FindFirstChild("Zombies")
	if not folder then
		return nil
	end
	if data and data.Model and data.Model.Parent then
		return data.Model
	end
	return folder:FindFirstChild(tostring(id))
end

local function inKillRange(root, model)
	if not root or not model then
		return true
	end
	local target = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not target then
		return true
	end
	local range = tonumber(state.KillAuraRange) or 120
	return (root.Position - target.Position).Magnitude <= range
end

local function killAuraTick()
	if not state.AKillAura then
		return
	end
	refreshRemotes()
	local damageRemote = runtime.zombieDamage
	if not damageRemote then
		return
	end
	local zombies = resolveZombieTable()
	if not zombies then
		return
	end
	local _, _, root = characterParts()
	local damage = state.AInstantKill and math.huge or (tonumber(state.KillDamage) or 999999)
	for id, data in pairs(zombies) do
		if data and not data.IsDying and (tonumber(data.Health) or 0) > 0 then
			local model = zombieModelFor(id, data)
			if inKillRange(root, model) then
				pcall(function()
					damageRemote:FireServer(id, damage)
				end)
			end
		end
	end
end

local function autoSkipTick()
	if not state.AAutoSkip then
		return
	end
	refreshRemotes()
	if not runtime.skipVote then
		return
	end
	if tick() < runtime.lastSkip + (state.SkipInterval or 3) then
		return
	end
	runtime.lastSkip = tick()
	pcall(function()
		runtime.skipVote:FireServer(true)
	end)
end

local function getShootTool()
	local character = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if character then
		local equipped = character:FindFirstChildWhichIsA("Tool")
		if equipped then
			return equipped
		end
	end
	if backpack then
		return backpack:FindFirstChildWhichIsA("Tool")
	end
	return nil
end

local function autoShootTick()
	if not state.AAutoShoot then
		return
	end
	if tick() < runtime.lastShoot + (state.ShootInterval or 0.05) then
		return
	end
	runtime.lastShoot = tick()
	local character, humanoid = characterParts()
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	local tool = getShootTool()
	if not tool then
		return
	end
	if tool.Parent ~= character then
		pcall(function()
			humanoid:EquipTool(tool)
		end)
	end
	pcall(function()
		tool:Activate()
	end)
end

local function isShardInstance(instance)
	if not instance then
		return false
	end
	local name = instance.Name:lower()
	if name:find("shard") or name:find("galactic") or name:find("pickup") or name:find("drop") then
		return true
	end
	local attr = instance:GetAttribute("Shard") or instance:GetAttribute("Pickup") or instance:GetAttribute("Collectible")
	return attr == true
end

local function collectShardsTick()
	if not state.ACollectShards then
		return
	end
	if tick() < runtime.lastShardScan + (state.ShardScanInterval or 0.35) then
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
		if isShardInstance(item) and (item:IsA("BasePart") or item:IsA("Model")) then
			local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
			if part and part.Parent then
				local dist = (root.Position - part.Position).Magnitude
				if dist < nearestDist and dist < 250 then
					nearestDist = dist
					nearest = part
				end
			end
		end
	end
	if nearest then
		root.CFrame = nearest.CFrame + Vector3.new(0, 2, 0)
	end
end

local function walkSpeedTick()
	local _, humanoid = characterParts()
	if humanoid and state.WalkSpeed then
		humanoid.WalkSpeed = state.WalkSpeed
	end
end

local function leaderstatValue(name)
	local stats = LocalPlayer:FindFirstChild("leaderstats")
	local entry = stats and stats:FindFirstChild(name)
	if entry and (entry:IsA("IntValue") or entry:IsA("NumberValue") or entry:IsA("StringValue")) then
		return tostring(entry.Value)
	end
	return "?"
end

Core.makeSupervisor(state, loops, loopControllers, "KillAura", 0.2, function()
	killAuraTick()
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoSkip", 1, function()
	autoSkipTick()
end)

Core.makeSupervisor(state, loops, loopControllers, "AutoShoot", 0.08, function()
	autoShootTick()
end)

Core.makeSupervisor(state, loops, loopControllers, "CollectShards", 0.2, function()
	collectShardsTick()
end)

Core.makeSupervisor(state, loops, loopControllers, "SafeZone", 0.5, function()
	local _, humanoid, root = characterParts()
	applySafeZone(humanoid)
	teleportSafe(root)
	removeGates()
	walkSpeedTick()
end)

if state.AntiAFK then
	Core.setupAntiAfk(LocalPlayer)
end

local function track(connection)
	if connection then
		table.insert(connections, connection)
	end
	return connection
end

track(LocalPlayer.CharacterAdded:Connect(function(character)
	task.wait(1)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	applySafeZone(humanoid)
	if state.ATeleportSafe then
		local root = character:FindFirstChild("HumanoidRootPart")
		teleportSafe(root)
	end
end))

local window = starlight:CreateWindow({
	Name = "Alleral",
	Subtitle = "Survive a Zombie Arena · v" .. VERSION,
	Icon = 10723407389,
	LoadingEnabled = false,
})
local section = window:CreateTabSection("Alleral", true)
local combatTab = section:CreateTab({ Name = "Combat", Icon = 10723407389, Columns = 2 }, "combat")
local farmTab = section:CreateTab({ Name = "Farm", Icon = 10734923214, Columns = 2 }, "farm")
local miscTab = section:CreateTab({ Name = "Misc", Icon = 10734950020, Columns = 1 }, "misc")

local auraGroup = combatTab:CreateGroupbox({ Name = "Kill aura", Column = 1 }, "aura")
local shootGroup = combatTab:CreateGroupbox({ Name = "Shooting", Column = 2 }, "shoot")
local waveGroup = farmTab:CreateGroupbox({ Name = "Waves", Column = 1 }, "waves")
local lootGroup = farmTab:CreateGroupbox({ Name = "Loot", Column = 2 }, "loot")
local moveGroup = miscTab:CreateGroupbox({ Name = "Movement", Column = 1 }, "move")
local utilGroup = miscTab:CreateGroupbox({ Name = "Utilities", Column = 1 }, "util")

local aura = Core.wrapStarlightGroup(auraGroup, saveSettings)
local shoot = Core.wrapStarlightGroup(shootGroup, saveSettings)
local wave = Core.wrapStarlightGroup(waveGroup, saveSettings)
local loot = Core.wrapStarlightGroup(lootGroup, saveSettings)
local move = Core.wrapStarlightGroup(moveGroup, saveSettings)
local util = Core.wrapStarlightGroup(utilGroup, saveSettings)

local function bindToggle(group, label, key, tooltip)
	group:CreateToggle(label, state[key], tooltip, function(value)
		state[key] = value
		saveSettings()
	end)
end

local function bindSlider(group, label, minVal, maxVal, key, tooltip)
	group:CreateSlider(label, minVal, maxVal, state[key], function(value)
		state[key] = value
		saveSettings()
	end, tooltip)
end

bindToggle(aura, "Kill aura", "AKillAura", "Hits zombies through ZombieRemotes.ZombieDamage.")
bindToggle(aura, "Instant kill", "AInstantKill", "Uses max damage per hit (open-source instant kill aura).")
bindSlider(aura, "Aura range", 40, 250, "KillAuraRange", "Only damage zombies within this range.")
bindSlider(aura, "Hit damage", 100, 999999, "KillDamage", "Ignored when instant kill is on.")

bindToggle(shoot, "Auto shoot", "AAutoShoot", "Keeps your equipped weapon firing.")
bindSlider(shoot, "Shoot delay", 0.03, 0.5, "ShootInterval", "Lower = faster shooting.")

bindToggle(wave, "Auto skip wave", "AAutoSkip", "Votes to skip via WaveRemotes.SkipVote.")
bindSlider(wave, "Skip interval", 1, 10, "SkipInterval", "Seconds between skip votes.")

bindToggle(loot, "Collect shards", "ACollectShards", "Runs to shard/galactic pickups in the map.")

bindToggle(move, "Safe zone height", "ASafeZone", "Raises HipHeight so zombies can't reach you.")
bindSlider(move, "Hip height", 10, 60, "SafeZoneHeight", "Higher = safer, harder to aim down.")
bindToggle(move, "Teleport safe spot", "ATeleportSafe", "Teleports to the classic safe corner.")
bindSlider(move, "Walk speed", 16, 80, "WalkSpeed", "Local walkspeed while the script runs.")
bindToggle(move, "Remove gates", "ARemoveGates", "Deletes workspace Gates once (public SZA script).")

util:CreateToggle("Anti AFK", state.AntiAFK, "Stops idle kicks.", function(value)
	state.AntiAFK = value
	if value then
		Core.setupAntiAfk(LocalPlayer)
	end
	saveSettings()
end)
util:CreateButton("Skip wave once", function()
	refreshRemotes()
	if runtime.skipVote then
		pcall(function()
			runtime.skipVote:FireServer(true)
		end)
		notify("Alleral", "Skip vote sent.", 2)
	else
		notify("Alleral", "SkipVote remote not found.", 3)
	end
end)
util:CreateButton("Teleport safe", function()
	local _, _, root = characterParts()
	teleportSafe(root)
	notify("Alleral", "Moved to safe spot.", 2)
end)
local statLabels = {
	Kills = utilGroup:CreateLabel({ Name = "Kills: ?" }, "stat_kills"),
	Minerals = utilGroup:CreateLabel({ Name = "Minerals: ?" }, "stat_minerals"),
	Credits = utilGroup:CreateLabel({ Name = "Credits: ?" }, "stat_credits"),
}
util:CreateButton("Save now", saveSettings)

Core.makeSupervisor(state, loops, loopControllers, "Stats", 2, function()
	for key, label in pairs(statLabels) do
		if label and label.Set then
			label:Set({ Name = key .. ": " .. leaderstatValue(key) })
		end
	end
end)

notify("Alleral", "Survive a Zombie Arena loaded.", 4)

state.Alleral_Unload = function()
	state.HubRunning = false
	for name, controller in pairs(loopControllers) do
		if controller then
			controller.enabled = false
		end
		loopControllers[name] = nil
	end
	for _, connection in pairs(connections) do
		if connection and connection.Disconnect then
			pcall(function()
				connection:Disconnect()
			end)
		end
	end
	table.clear(connections)
end
