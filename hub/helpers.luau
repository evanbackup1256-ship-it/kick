local Helpers = {}
Helpers.VERSION = "1.0"

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
