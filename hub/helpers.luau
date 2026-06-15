local Helpers = {}
Helpers.VERSION = "1.4"

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()

function Helpers.waitChild(parent, name, timeout)
	if not parent then
		return nil
	end
	return parent:WaitForChild(name, timeout or 5)
end

function Helpers.isPickup(instance)
	if not instance then
		return false
	end
	local name = instance.Name:lower()
	if
		name:find("shard", 1, true)
		or name:find("galactic", 1, true)
		or name:find("pickup", 1, true)
		or name:find("drop", 1, true)
		or name:find("mineral", 1, true)
		or name:find("coin", 1, true)
		or name:find("credit", 1, true)
	then
		return true
	end
	return instance:GetAttribute("Shard")
		or instance:GetAttribute("Pickup")
		or instance:GetAttribute("Collectible")
		or instance:GetAttribute("Coin")
end

function Helpers.nearestPickup(origin, options)
	if not origin then
		return nil, math.huge
	end
	options = type(options) == "table" and options or {}
	local maxRange = tonumber(options.maxRange) or 300
	local nearest
	local nearestDist = maxRange
	local roots = options.roots or { "Pickups", "Drops", "Loot", "Shards", "Collectibles" }

	local function consider(item)
		if not Helpers.isPickup(item) or not (item:IsA("BasePart") or item:IsA("Model")) then
			return
		end
		local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
		if not part or not part.Parent then
			return
		end
		local dist = (origin - part.Position).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearest = part
		end
	end

	for _, rootName in ipairs(roots) do
		local folder = Workspace:FindFirstChild(rootName)
		if folder then
			for _, item in ipairs(folder:GetDescendants()) do
				consider(item)
			end
		end
	end

	if not nearest then
		for _, item in ipairs(Workspace:GetChildren()) do
			consider(item)
		end
	end

	return nearest, nearestDist
end

function Helpers.characterParts(player)
	player = player or Players.LocalPlayer
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

function Helpers.getGc()
	local exec = ENV.Alleral_LoaderCapabilities or {}
	local env = ENV
	return env.getgc or env.get_gc or env.getGc
end

function Helpers.getGcTable(predicate)
	local getgcFn = Helpers.getGc()
	if type(getgcFn) ~= "function" then
		return nil
	end
	for _, value in pairs(getgcFn(true)) do
		if type(value) == "table" and (not predicate or predicate(value)) then
			return value
		end
	end
	return nil
end

function Helpers.indexRemotes(root, cache)
	cache = cache or {}
	local searchRoot = root or game:GetService("ReplicatedStorage")
	for _, inst in ipairs(searchRoot:GetDescendants()) do
		if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
			cache[inst.Name] = inst
			local parent = inst.Parent
			if parent and parent ~= searchRoot then
				cache[parent.Name .. "." .. inst.Name] = inst
			end
		end
	end
	return cache
end

function Helpers.findRemote(cache, names)
	if not cache then
		return nil
	end
	for _, name in ipairs(names) do
		local remote = cache[name]
		if remote then
			return remote
		end
	end
	return nil
end

local MODULE_CACHE = {}
local GAME_REQUIRE_FN = nil

local function isSandboxRequireError(err)
	err = tostring(err or "")
	return err:find("RobloxScript", 1, true) ~= nil
		or err:find("non%-RobloxScript", 1, true) ~= nil
end

local function gameEnvTable(env)
	if type(env) ~= "table" then
		return false
	end
	local ok, sameGame = pcall(function()
		return env.game == game
	end)
	if ok and sameGame then
		return true
	end
	if type(env.require) == "function" and env.script and typeof(env.script) == "Instance" then
		local okScript, inGame = pcall(function()
			return env.script:IsDescendantOf(game)
		end)
		return okScript and inGame == true
	end
	return false
end

local function registryModule(moduleScript)
	local reg
	if debug and type(debug.getregistry) == "function" then
		local ok, value = pcall(debug.getregistry)
		reg = ok and value or nil
	end
	if type(reg) ~= "table" and type(getreg) == "function" then
		local ok, value = pcall(getreg)
		reg = ok and value or nil
	end
	if type(reg) ~= "table" then
		return nil
	end
	for _, value in pairs(reg) do
		if type(value) == "table" and rawget(value, moduleScript) ~= nil then
			return rawget(value, moduleScript)
		end
	end
	return nil
end

local function addRequireCandidate(list, seen, reqFn, priority)
	if type(reqFn) ~= "function" or seen[reqFn] then
		return
	end
	seen[reqFn] = true
	table.insert(list, { fn = reqFn, priority = priority or 50 })
end

local function collectRequireCandidates()
	local list = {}
	local seen = {}
	addRequireCandidate(list, seen, require, 90)

	if typeof(shared) == "table" then
		addRequireCandidate(list, seen, shared.require, 12)
	end

	if type(getrenv) == "function" then
		local ok, renv = pcall(getrenv)
		if ok and gameEnvTable(renv) then
			addRequireCandidate(list, seen, renv.require, 10)
		end
	end

	for _, key in ipairs({ "Xeno", "Volt", "Wave", "Electron", "Solara", "Krnl", "Fluxus", "Delta" }) do
		local bucket = ENV[key]
		if type(bucket) == "table" then
			addRequireCandidate(list, seen, bucket.require, 14)
		end
	end

	local scriptSet = {}
	local function consider(script)
		if not script or not script:IsDescendantOf(game) then
			return
		end
		if script:IsDescendantOf(game:GetService("CoreGui")) then
			return
		end
		scriptSet[script] = true
	end

	if type(getscripts) == "function" then
		pcall(function()
			for _, script in ipairs(getscripts()) do
				consider(script)
			end
		end)
	end

	if type(getrunningscripts) == "function" then
		pcall(function()
			for _, script in ipairs(getrunningscripts()) do
				consider(script)
			end
		end)
	end

	if type(getloadedmodules) == "function" then
		pcall(function()
			for _, module in ipairs(getloadedmodules()) do
				if typeof(module) == "Instance" and module:IsA("ModuleScript") then
					local parent = module.Parent
					while parent do
						if parent:IsA("LocalScript") then
							consider(parent)
							break
						end
						parent = parent.Parent
					end
				end
			end
		end)
	end

	local player = Players.LocalPlayer
	local playerScripts = player and player:FindFirstChild("PlayerScripts")
	if playerScripts then
		for _, inst in ipairs(playerScripts:GetDescendants()) do
			if inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
				consider(inst)
			end
		end
	end

	local starterPlayer = game:GetService("StarterPlayer")
	local starterScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
	if starterScripts then
		for _, inst in ipairs(starterScripts:GetDescendants()) do
			if inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
				consider(inst)
			end
		end
	end

	local ordered = {}
	for script in pairs(scriptSet) do
		table.insert(ordered, script)
	end
	table.sort(ordered, function(a, b)
		local aName = a:GetFullName():lower()
		local bName = b:GetFullName():lower()
		local function score(name)
			if name:find("servicesloader", 1, true) then
				return 0
			end
			if name:find("client", 1, true) and name:find("loader", 1, true) then
				return 1
			end
			if name:find("playerscripts", 1, true) then
				return 2
			end
			return 3
		end
		return score(aName) < score(bName)
	end)

	if type(getsenv) == "function" then
		for index, script in ipairs(ordered) do
			local ok, env = pcall(getsenv, script)
			if ok and gameEnvTable(env) then
				addRequireCandidate(list, seen, env.require, 5 + math.min(index, 20))
			end
		end
	end

	table.sort(list, function(a, b)
		return a.priority < b.priority
	end)
	return list
end

local function resolveGameRequire(testModule)
	if GAME_REQUIRE_FN then
		return GAME_REQUIRE_FN
	end
	local probe = testModule
	if not probe or not probe:IsA("ModuleScript") then
		local replicated = game:GetService("ReplicatedStorage")
		for _, inst in ipairs(replicated:GetDescendants()) do
			if inst:IsA("ModuleScript") then
				probe = inst
				break
			end
		end
	end
	for _, candidate in ipairs(collectRequireCandidates()) do
		if probe then
			local ok, result = pcall(candidate.fn, probe)
			if ok then
				GAME_REQUIRE_FN = candidate.fn
				return GAME_REQUIRE_FN
			end
			if not isSandboxRequireError(result) then
				GAME_REQUIRE_FN = candidate.fn
				return GAME_REQUIRE_FN
			end
		else
			GAME_REQUIRE_FN = candidate.fn
			return GAME_REQUIRE_FN
		end
	end
	return nil
end

local function compileModule(moduleScript, reqFn)
	if type(loadstring) ~= "function" then
		return nil
	end
	local source = moduleScript.Source
	if (type(source) ~= "string" or source == "") and type(decompile) == "function" then
		local okDecompile, decompiled = pcall(decompile, moduleScript)
		if okDecompile and type(decompiled) == "string" and decompiled ~= "" then
			source = decompiled
		end
	end
	if type(source) ~= "string" or source == "" then
		return nil
	end
	local fn = loadstring(source, "@" .. moduleScript:GetFullName())
	if not fn then
		return nil
	end
	local renv = ENV
	if type(getrenv) == "function" then
		local ok, env = pcall(getrenv)
		if ok and type(env) == "table" then
			renv = env
		end
	end
	local env = setmetatable({
		script = moduleScript,
		require = function(target)
			return Helpers.gameRequire(target)
		end,
	}, { __index = renv })
	if setfenv then
		setfenv(fn, env)
	end
	local ok, result = pcall(fn)
	if ok then
		return result
	end
	if reqFn and reqFn ~= require then
		env.require = function(target)
			if target == moduleScript then
				error("recursive require")
			end
			local okInner, value = pcall(reqFn, target)
			if okInner then
				return value
			end
			return Helpers.gameRequire(target)
		end
		ok, result = pcall(fn)
		if ok then
			return result
		end
	end
	return nil
end

function Helpers.invalidateGameRequire()
	GAME_REQUIRE_FN = nil
end

function Helpers.gameRequire(moduleScript)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		return nil
	end
	if MODULE_CACHE[moduleScript] ~= nil then
		return MODULE_CACHE[moduleScript]
	end

	local cached = registryModule(moduleScript)
	if cached ~= nil then
		MODULE_CACHE[moduleScript] = cached
		return cached
	end

	local candidates = collectRequireCandidates()
	for _, candidate in ipairs(candidates) do
		if candidate.fn ~= require then
			local ok, result = pcall(candidate.fn, moduleScript)
			if ok then
				MODULE_CACHE[moduleScript] = result
				GAME_REQUIRE_FN = candidate.fn
				return result
			end
		end
	end

	if GAME_REQUIRE_FN and GAME_REQUIRE_FN ~= require then
		local ok, result = pcall(GAME_REQUIRE_FN, moduleScript)
		if ok then
			MODULE_CACHE[moduleScript] = result
			return result
		end
	end

	local reqFn = resolveGameRequire(moduleScript)
	if reqFn and reqFn ~= require then
		local ok, result = pcall(reqFn, moduleScript)
		if ok then
			MODULE_CACHE[moduleScript] = result
			return result
		end
	end

	local compiled = compileModule(moduleScript, reqFn)
	if compiled ~= nil then
		MODULE_CACHE[moduleScript] = compiled
		return compiled
	end

	cached = registryModule(moduleScript)
	if cached ~= nil then
		MODULE_CACHE[moduleScript] = cached
		return cached
	end

	if type(getthreadidentity) == "function" and type(setthreadidentity) == "function" then
		local ok, result = pcall(function()
			local old = getthreadidentity()
			setthreadidentity(2)
			local value = require(moduleScript)
			setthreadidentity(old)
			return value
		end)
		if ok then
			MODULE_CACHE[moduleScript] = result
			return result
		end
	end

	return nil
end

function Helpers.fireRemote(remote, ...)
	if not remote then
		return false
	end
	local args = { ... }
	local ok = pcall(function()
		if remote:IsA("RemoteFunction") then
			remote:InvokeServer(table.unpack(args))
		else
			remote:FireServer(table.unpack(args))
		end
	end)
	return ok
end

function Helpers.leaderstatValue(player, name)
	player = player or Players.LocalPlayer
	local stats = player and player:FindFirstChild("leaderstats")
	local entry = stats and stats:FindFirstChild(name)
	if entry and (entry:IsA("IntValue") or entry:IsA("NumberValue") or entry:IsA("StringValue")) then
		return tostring(entry.Value)
	end
	return "?"
end

function Helpers.track(connections, connection)
	if connection and connections then
		table.insert(connections, connection)
	end
	return connection
end

function Helpers.clearHighlights(store)
	for model, highlight in pairs(store or {}) do
		if highlight and highlight.Parent then
			pcall(function()
				highlight:Destroy()
			end)
		end
		store[model] = nil
	end
end

function Helpers.setHighlight(model, store, enabled, color)
	if not model or not model:IsA("Model") then
		return
	end
	store = store or {}
	if not enabled then
		local existing = store[model]
		if existing then
			pcall(function()
				existing:Destroy()
			end)
			store[model] = nil
		end
		return
	end
	local highlight = store[model]
	if not highlight or not highlight.Parent then
		highlight = Instance.new("Highlight")
		highlight.FillTransparency = 0.65
		highlight.OutlineTransparency = 0
		highlight.Parent = model
		store[model] = highlight
	end
	highlight.FillColor = color or Color3.fromRGB(255, 70, 70)
	highlight.OutlineColor = color or Color3.fromRGB(255, 40, 40)
	highlight.Enabled = true
end

function Helpers.nearestTarget(origin, entries, maxRange)
	local nearest
	local nearestDist = maxRange or math.huge
	for _, entry in ipairs(entries) do
		local part = entry.part
		if part and part.Parent then
			local dist = (origin - part.Position).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearest = entry
			end
		end
	end
	return nearest, nearestDist
end

function Helpers.applyWalkSpeed(humanoid, speed)
	if humanoid and speed then
		humanoid.WalkSpeed = speed
	end
end

function Helpers.applyJumpPower(humanoid, power)
	if humanoid and power then
		humanoid.JumpPower = power
		humanoid.UseJumpPower = true
	end
end

function Helpers.applyGodMode(humanoid, enabled, maxHealth)
	if not humanoid then
		return
	end
	if enabled then
		maxHealth = maxHealth or humanoid.MaxHealth
		if humanoid.Health < maxHealth then
			humanoid.Health = maxHealth
		end
		humanoid.MaxHealth = math.max(humanoid.MaxHealth, maxHealth)
	else
		return
	end
end

function Helpers.applyNoclip(character, enabled)
	if not character then
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = not enabled
		end
	end
end

function Helpers.setFov(fov)
	local camera = Workspace.CurrentCamera
	if camera and fov then
		camera.FieldOfView = fov
	end
end

function Helpers.expandHitbox(model, scale)
	if not model then
		return
	end
	scale = scale or 2
	local target = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if target and target:IsA("BasePart") then
		local base = target:GetAttribute("AlleralBaseSize")
		if not base then
			target:SetAttribute("AlleralBaseSize", target.Size)
			base = target.Size
		end
		target.Size = base * scale
		target.CanCollide = false
	end
end

function Helpers.restoreHitboxes(folder, store)
	store = store or {}
	for model, _ in pairs(store) do
		local target = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
		if target then
			local base = target:GetAttribute("AlleralBaseSize")
			if base then
				target.Size = base
			end
		end
	end
	table.clear(store)
	if folder then
		for _, model in ipairs(folder:GetChildren()) do
			if model:IsA("Model") then
				Helpers.expandHitbox(model, 1)
			end
		end
	end
end

function Helpers.ensureFly(root, runtime, speed)
	if not root then
		return
	end
	runtime = runtime or {}
	if not runtime.flyAttachment then
		local attachment = Instance.new("Attachment")
		attachment.Name = "AlleralFly"
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Name = "AlleralFly"
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.MaxForce = math.huge
		velocity.Parent = root
		runtime.flyAttachment = attachment
		runtime.flyVelocity = velocity
	end
	local velocity = runtime.flyVelocity
	if velocity then
		local move = Vector3.zero
		local camera = Workspace.CurrentCamera
		if camera then
			if RunService:IsKeyDown(Enum.KeyCode.W) then
				move += camera.CFrame.LookVector
			end
			if RunService:IsKeyDown(Enum.KeyCode.S) then
				move -= camera.CFrame.LookVector
			end
			if RunService:IsKeyDown(Enum.KeyCode.A) then
				move -= camera.CFrame.RightVector
			end
			if RunService:IsKeyDown(Enum.KeyCode.D) then
				move += camera.CFrame.RightVector
			end
			if RunService:IsKeyDown(Enum.KeyCode.Space) then
				move += Vector3.yAxis
			end
			if RunService:IsKeyDown(Enum.KeyCode.LeftControl) then
				move -= Vector3.yAxis
			end
		end
		if move.Magnitude > 0 then
			move = move.Unit * (speed or 50)
		end
		velocity.VectorVelocity = move
	end
end

function Helpers.stopFly(runtime)
	runtime = runtime or {}
	if runtime.flyVelocity then
		pcall(function()
			runtime.flyVelocity:Destroy()
		end)
		runtime.flyVelocity = nil
	end
	if runtime.flyAttachment then
		pcall(function()
			runtime.flyAttachment:Destroy()
		end)
		runtime.flyAttachment = nil
	end
end

function Helpers.aimAt(camera, targetPart)
	if not camera or not targetPart then
		return
	end
	local origin = camera.CFrame.Position
	local goal = targetPart.Position
	camera.CFrame = CFrame.new(origin, goal)
end

function Helpers.bestTool(player)
	player = player or Players.LocalPlayer
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")
	local tools = {}
	local function consider(container)
		if not container then
			return
		end
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("Tool") then
				table.insert(tools, item)
			end
		end
	end
	consider(character)
	consider(backpack)
	table.sort(tools, function(a, b)
		local aScore = tonumber(a:GetAttribute("Damage") or a:GetAttribute("Power") or 0) or 0
		local bScore = tonumber(b:GetAttribute("Damage") or b:GetAttribute("Power") or 0) or 0
		if aScore == bScore then
			return a.Name < b.Name
		end
		return aScore > bScore
	end)
	return tools[1]
end

function Helpers.probeRemote(cache, names, payloads)
	local remote = Helpers.findRemote(cache, names)
	if not remote then
		return false
	end
	if type(payloads) ~= "table" or #payloads == 0 then
		return Helpers.fireRemote(remote)
	end
	for _, payload in ipairs(payloads) do
		if type(payload) == "table" then
			if Helpers.fireRemote(remote, table.unpack(payload)) then
				return true
			end
		else
			if Helpers.fireRemote(remote, payload) then
				return true
			end
		end
	end
	return false
end

local Core = ENV.Alleral_Core
if Core then
	Core.Game = Helpers
end
ENV.Alleral_GameHelpers = Helpers
return Helpers
