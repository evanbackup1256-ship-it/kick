-- Spring motion hooks for Maclib (uses spr).
return function(Core, spr)
	if type(spr) ~= "table" or type(spr.target) ~= "function" then
		return nil
	end

	local RunService = game:GetService("RunService")

	local function genv()
		local ok, env = pcall(function()
			return getgenv and getgenv() or getfenv()
		end)
		return ok and env or {}
	end
	local ENV = genv()

	local profiles = {
		fluid = { damping = 0.72, frequency = 8.5 },
		snappy = { damping = 0.95, frequency = 11 },
		bouncy = { damping = 0.52, frequency = 9 },
		cinematic = { damping = 0.88, frequency = 5.5 },
		reduced = { damping = 1, frequency = math.huge },
	}

	local activeProfile = ENV.Alleral_MotionProfile or "fluid"
	local hooked = setmetatable({}, { __mode = "k" })

	local function motionEnabled()
		if ENV.Alleral_UiReducedMotion == true then
			return false
		end
		if ENV.Alleral_UiSpringMotion == false then
			return false
		end
		return activeProfile ~= "reduced"
	end

	local function springParams(boost)
		boost = tonumber(boost) or 1
		if not motionEnabled() then
			return 1, math.huge
		end
		local profile = profiles[activeProfile] or profiles.fluid
		return profile.damping, profile.frequency * boost
	end

	local function springTarget(instance, properties, boost)
		if not instance or not properties then
			return
		end
		local damping, frequency = springParams(boost)
		pcall(spr.target, instance, damping, frequency, properties)
	end

	local function springStop(instance, property)
		if instance then
			pcall(spr.stop, instance, property)
		end
	end

	local function markHooked(instance)
		if instance then
			hooked[instance] = true
		end
	end

	local function isHooked(instance)
		return instance and hooked[instance] == true
	end

	local Motion = {
		spr = spr,
		profile = activeProfile,
	}

	function Motion.setProfile(name)
		activeProfile = tostring(name or activeProfile)
		ENV.Alleral_MotionProfile = activeProfile
		Motion.profile = activeProfile
	end

	function Motion.enabled()
		return motionEnabled()
	end

	function Motion.target(instance, properties, boost)
		springTarget(instance, properties, boost)
	end

	local function tightenSpacing(root)
		if not root then
			return
		end
		for _, inst in ipairs(root:GetDescendants()) do
			if inst:IsA("UIListLayout") then
				local offset = inst.Padding.Offset
				if offset > 7 then
					inst.Padding = UDim.new(0, math.max(4, math.floor(offset * 0.55)))
				end
			elseif inst:IsA("UIPadding") then
				for _, edge in ipairs({ "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" }) do
					local pad = inst[edge]
					if pad and pad.Offset > 16 then
						inst[edge] = UDim.new(0, math.floor(pad.Offset * 0.62))
					end
				end
			elseif inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				if inst.TextYAlignment == Enum.TextYAlignment.Top then
					inst.TextYAlignment = Enum.TextYAlignment.Center
				end
				if inst.Name:match("Name$") and inst.AutomaticSize == Enum.AutomaticSize.Y then
					inst.AutomaticSize = Enum.AutomaticSize.XY
				end
				if inst.LineHeight and inst.LineHeight > 1.05 then
					inst.LineHeight = 1
				end
			end
		end
	end

	local function findMaclibRoot()
		local roots = {}
		local Players = game:GetService("Players")
		local lp = Players.LocalPlayer
		if lp and lp:FindFirstChildOfClass("PlayerGui") then
			table.insert(roots, lp:FindFirstChildOfClass("PlayerGui"))
		end
		if gethui then
			pcall(function()
				table.insert(roots, gethui())
			end)
		end
		for _, root in ipairs(roots) do
			if root then
				for _, desc in ipairs(root:GetDescendants()) do
					if desc.Name == "Base" and desc:IsA("Frame") and desc:FindFirstChild("Sidebar") then
						return desc.Parent, desc
					end
				end
			end
		end
		return nil, nil
	end

	local function hookButtonRow(row)
		if not row or isHooked(row) then
			return
		end
		local interact = row:FindFirstChild("ButtonInteract")
		local icon = row:FindFirstChild("ButtonImage")
		if not interact then
			return
		end
		markHooked(row)

		local baseTransparency = interact.TextTransparency
		local iconTransparency = icon and icon.ImageTransparency or 0.5

		local function hoverIn()
			springTarget(interact, { TextTransparency = math.max(0.05, baseTransparency - 0.22) }, 1.2)
			if icon then
				springTarget(icon, { ImageTransparency = math.max(0.05, iconTransparency - 0.22) }, 1.2)
			end
			springTarget(interact, { Position = UDim2.new(0, 2, interact.Position.Y.Scale, interact.Position.Y.Offset) }, 1.4)
		end

		local function hoverOut()
			springTarget(interact, { TextTransparency = baseTransparency }, 1)
			if icon then
				springTarget(icon, { ImageTransparency = iconTransparency }, 1)
			end
			springTarget(interact, { Position = UDim2.new(0, 0, interact.Position.Y.Scale, interact.Position.Y.Offset) }, 1)
		end

		interact.MouseEnter:Connect(hoverIn)
		interact.MouseLeave:Connect(hoverOut)
		interact.MouseButton1Down:Connect(function()
			springTarget(interact, { TextTransparency = 0.05 }, 1.6)
			if icon then
				springTarget(icon, { ImageTransparency = 0.05 }, 1.6)
			end
		end)
		interact.MouseButton1Up:Connect(hoverOut)
	end

	local function hookToggleRow(row)
		if not row or isHooked(row) then
			return
		end
		local toggleBtn = row:FindFirstChild("Toggle")
		local head = toggleBtn and toggleBtn:FindFirstChild("TogglerHead")
		if not toggleBtn or not head then
			return
		end
		markHooked(row)

		toggleBtn.MouseButton1Click:Connect(function()
			springTarget(head, { Size = UDim2.fromOffset(18, 18) }, 1.8)
			task.delay(0.08, function()
				springTarget(head, { Size = UDim2.fromOffset(15, 15) }, 1)
			end)
			springTarget(toggleBtn, { ImageColor3 = Color3.fromRGB(120, 220, 90) }, 1.5)
			task.delay(0.2, function()
				springTarget(toggleBtn, { ImageColor3 = Color3.fromRGB(87, 86, 86) }, 0.9)
			end)
		end)
	end

	local function hookSliderRow(row)
		if not row or isHooked(row) then
			return
		end
		local head = row:FindFirstChild("SliderHead", true)
		if not head then
			return
		end
		markHooked(row)

		head:GetPropertyChangedSignal("Position"):Connect(function()
			springTarget(head, { Size = UDim2.fromOffset(17, 17) }, 1.6)
			task.delay(0.06, function()
				springTarget(head, { Size = UDim2.fromOffset(15, 15) }, 1)
			end)
		end)
	end

	local function hookDropdownRow(row)
		if not row or isHooked(row) then
			return
		end
		local interact = row:FindFirstChild("DropdownInteract", true)
		if not interact then
			return
		end
		markHooked(row)

		interact.MouseButton1Click:Connect(function()
			springTarget(interact, { Rotation = 6 }, 1.4)
			task.delay(0.12, function()
				springTarget(interact, { Rotation = 0 }, 1)
			end)
		end)
	end

	local function hookTabSwitcher(tabSwitcher)
		if not tabSwitcher or isHooked(tabSwitcher) then
			return
		end
		markHooked(tabSwitcher)

		tabSwitcher.MouseButton1Click:Connect(function()
			springTarget(tabSwitcher, { BackgroundTransparency = 0.92 }, 1.5)
			task.delay(0.1, function()
				springTarget(tabSwitcher, { BackgroundTransparency = 0.98 }, 1)
			end)
		end)
	end

	local function hookTabContent(contentRoot)
		if not contentRoot or isHooked(contentRoot) then
			return
		end
		markHooked(contentRoot)

		contentRoot.ChildAdded:Connect(function(child)
			if not child:IsA("GuiObject") then
				return
			end
			local startX = child.Position.X.Offset + 14
			child.Position = UDim2.new(child.Position.X.Scale, startX, child.Position.Y.Scale, child.Position.Y.Offset)
			springTarget(child, {
				Position = UDim2.new(child.Position.X.Scale, startX - 14, child.Position.Y.Scale, child.Position.Y.Offset),
			}, 0.9)
			for _, desc in ipairs(child:GetDescendants()) do
				if desc:IsA("GuiObject") and desc.BackgroundTransparency < 1 then
					local target = desc.BackgroundTransparency
					desc.BackgroundTransparency = 1
					springTarget(desc, { BackgroundTransparency = target }, 0.85)
				end
			end
		end)
	end

	local function hookNotification(frame)
		if not frame or isHooked(frame) then
			return
		end
		markHooked(frame)
		local startX = frame.Position.X.Offset + 40
		local targetTransparency = frame.BackgroundTransparency
		frame.Position = UDim2.new(frame.Position.X.Scale, startX, frame.Position.Y.Scale, frame.Position.Y.Offset)
		frame.BackgroundTransparency = 1
		springTarget(frame, {
			Position = UDim2.new(frame.Position.X.Scale, startX - 40, frame.Position.Y.Scale, frame.Position.Y.Offset),
			BackgroundTransparency = targetTransparency,
		}, 1.1)
	end

	local function hookInstance(inst)
		if not inst then
			return
		end
		if inst.Name == "Button" and inst:IsA("Frame") then
			hookButtonRow(inst)
		elseif inst.Name == "Toggle" and inst:IsA("Frame") then
			hookToggleRow(inst)
		elseif inst.Name == "Slider" and inst:IsA("Frame") then
			hookSliderRow(inst)
		elseif inst.Name == "Dropdown" and inst:IsA("Frame") then
			hookDropdownRow(inst)
		elseif inst.Name == "TabSwitcher" and inst:IsA("GuiObject") then
			hookTabSwitcher(inst)
		elseif inst.Name == "Notification" and inst:IsA("Frame") then
			hookNotification(inst)
		elseif inst.Name == "Content" and inst:IsA("Frame") then
			hookTabContent(inst)
		end
	end

	local function scanTree(root)
		if not root then
			return
		end
		for _, desc in ipairs(root:GetDescendants()) do
			hookInstance(desc)
		end
	end

	local function playStartup(base)
		if not base or not motionEnabled() then
			return
		end
		local scale = base:FindFirstChild("BaseUIScale")
		local stroke = base:FindFirstChild("BaseUIStroke")
		if scale then
			scale.Scale = 0.88
			springTarget(scale, { Scale = 1 }, 0.75)
		end
		local startTransparency = base.BackgroundTransparency
		base.BackgroundTransparency = 1
		springTarget(base, { BackgroundTransparency = startTransparency }, 0.8)
		if stroke then
			local strokeTarget = stroke.Transparency
			stroke.Transparency = 1
			springTarget(stroke, { Transparency = strokeTarget }, 0.85)
		end
		base.Rotation = -1.5
		springTarget(base, { Rotation = 0 }, 0.7)
	end

	local function playOpen(base)
		if not base or not motionEnabled() then
			return
		end
		local scale = base:FindFirstChild("BaseUIScale")
		if scale then
			scale.Scale = 0.9
			springTarget(scale, { Scale = 1 }, 1.1)
		end
		local targetTransparency = base.BackgroundTransparency
		base.BackgroundTransparency = 1
		springTarget(base, { BackgroundTransparency = targetTransparency }, 0.95)
	end

	local function playClose(base, onDone)
		if not base or not motionEnabled() then
			if onDone then
				onDone()
			end
			return
		end
		local scale = base:FindFirstChild("BaseUIScale")
		if scale then
			springTarget(scale, { Scale = 0.92 }, 1.2)
		end
		springTarget(base, { BackgroundTransparency = 1 }, 1.1)
		task.delay(0.22, function()
			if onDone then
				onDone()
			end
		end)
	end

	function Motion.attachWindow(window, gui, base)
		if type(window) ~= "table" then
			return false
		end

		if not gui or not base then
			gui, base = findMaclibRoot()
		end
		if not base then
			return false
		end

		window._alleralGui = gui
		window._alleralBase = base

		tightenSpacing(base)
		scanTree(base)

		if gui then
			gui.DescendantAdded:Connect(function(inst)
				task.defer(function()
					hookInstance(inst)
				end)
			end)
		end

		local origSetState = window.SetState
		if type(origSetState) ~= "function" then
			return true
		end

		window.SetState = function(self, state, instant)
			if instant or not motionEnabled() then
				return origSetState(self, state)
			end
			if state then
				origSetState(self, true)
				playOpen(base)
			else
				playClose(base, function()
					origSetState(self, false)
				end)
			end
		end

		if type(window.Toggle) ~= "function" then
			window.Toggle = function(self)
				local nextState = not self:GetState()
				self:SetState(nextState)
			end
		end

		task.defer(function()
			playStartup(base)
		end)

		return true
	end

	function Motion.repair(window)
		local base = window and window._alleralBase
		if not base then
			local _, found = findMaclibRoot()
			base = found
		end
		if base then
			tightenSpacing(base)
			scanTree(base)
		end
		return true
	end

	-- Keep spr alive while UI exists
	local keepAlive = true
	task.spawn(function()
		while keepAlive do
			if not motionEnabled() then
				task.wait(0.5)
			else
				task.wait(1)
			end
		end
	end)

	Motion.stop = function()
		keepAlive = false
	end

	return Motion
end
