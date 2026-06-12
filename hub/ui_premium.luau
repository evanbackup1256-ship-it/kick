-- Premium Maclib chrome: mesh gradients, notification center, theme live preview,
-- window snap/dock, tab pill, page transitions, charts, acrylic, animated search.
return function(Core, spr, Motion)
	if type(Motion) ~= "table" or type(Motion.target) ~= "function" then
		return nil
	end

	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")

	local function genv()
		local ok, env = pcall(function()
			return getgenv and getgenv() or getfenv()
		end)
		return ok and env or {}
	end
	local ENV = genv()

	local spring = function(inst, props, boost)
		Motion.target(inst, props, boost)
	end

	local accentColor = typeof(ENV.Alleral_AccentColor) == "Color3" and ENV.Alleral_AccentColor
		or Color3.fromHex("#53fc18")
	local glassIntensity = tonumber(ENV.Alleral_GlassIntensity) or 0.55
	local notifyHistory = {}
	local MAX_HISTORY = 48
	local hookedSearch = setmetatable({}, { __mode = "k" })
	local windowContexts = setmetatable({}, { __mode = "k" })

	local V2_THEMES = {
		Arrrel = { mac = "Maclib", hue = 108, sat = 0.92, val = 0.96 },
		ArrrelNeon = { mac = "Dark", hue = 285, sat = 1, val = 0.98 },
		ArrrelMidnight = { mac = "Dark", hue = 220, sat = 0.55, val = 0.72 },
		ArrrelAurora = { mac = "Maclib", hue = 165, sat = 0.88, val = 0.92 },
		ArrrelObsidian = { mac = "Dark", hue = 210, sat = 0.35, val = 0.55 },
		ArrrelSynth = { mac = "Dark", hue = 310, sat = 0.95, val = 0.9 },
		ArrrelOcean = { mac = "Default", hue = 198, sat = 0.82, val = 0.88 },
		ArrrelEmber = { mac = "Dark", hue = 18, sat = 0.92, val = 0.92 },
		ArrrelStealth = { mac = "Dark", hue = 0, sat = 0, val = 0.42 },
		ArrrelPaper = { mac = "Light", hue = 42, sat = 0.35, val = 0.98 },
		ArrrelVoid = { mac = "Dark", hue = 260, sat = 0.75, val = 0.35 },
	}

	local function motionOk()
		return Motion.enabled and Motion.enabled()
	end

	local function accentFromEnv()
		if typeof(ENV.Alleral_AccentColor) == "Color3" then
			return ENV.Alleral_AccentColor
		end
		if Core.hsvToColor and ENV.Alleral_AccentHue then
			return Core.hsvToColor(
				ENV.Alleral_AccentHue,
				ENV.Alleral_AccentSat or 0.92,
				ENV.Alleral_AccentVal or 0.96
			)
		end
		return accentColor
	end

	local function applyAccent(ctx, color)
		accentColor = color
		ENV.Alleral_AccentColor = color
		if not ctx then
			return
		end
		if ctx.pill then
			ctx.pill.BackgroundColor3 = color
		end
		if ctx.previewSwatch then
			ctx.previewSwatch.BackgroundColor3 = color
		end
		if ctx.meshLayer then
			local i = 0
			for _, blob in ipairs(ctx.meshLayer:GetChildren()) do
				if blob:IsA("Frame") then
					i += 1
					local grad = blob:FindFirstChildOfClass("UIGradient")
					if grad then
						local mix = 0.35 + (i * 0.12)
						grad.Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, color),
							ColorSequenceKeypoint.new(1, Color3.new(
								math.clamp(color.R * mix + 0.08, 0, 1),
								math.clamp(color.G * mix + 0.06, 0, 1),
								math.clamp(color.B * mix + 0.14, 0, 1)
							)),
						})
					end
				end
			end
		end
	end

	local function installMeshGradient(base, ctx)
		if ENV.Alleral_AmbientGlow == false then
			return
		end
		local layer = Instance.new("Frame")
		layer.Name = "AlleralMeshLayer"
		layer.BackgroundTransparency = 1
		layer.BorderSizePixel = 0
		layer.Size = UDim2.fromScale(1, 1)
		layer.ZIndex = 0
		layer.ClipsDescendants = true
		layer.Parent = base

		local palette = accentFromEnv()
		local blobDefs = {
			{ pos = UDim2.fromScale(0.08, 0.12), size = UDim2.fromScale(0.55, 0.42), rot = 18 },
			{ pos = UDim2.fromScale(0.62, 0.04), size = UDim2.fromScale(0.48, 0.38), rot = -24 },
			{ pos = UDim2.fromScale(0.38, 0.58), size = UDim2.fromScale(0.52, 0.44), rot = 12 },
			{ pos = UDim2.fromScale(0.78, 0.62), size = UDim2.fromScale(0.36, 0.34), rot = -8 },
		}
		for index, def in ipairs(blobDefs) do
			local blob = Instance.new("Frame")
			blob.Name = "MeshBlob" .. index
			blob.BackgroundColor3 = palette
			blob.BackgroundTransparency = 0.15
			blob.BorderSizePixel = 0
			blob.Position = def.pos
			blob.Size = def.size
			blob.Rotation = def.rot
			blob.ZIndex = 0
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = blob
			local grad = Instance.new("UIGradient")
			grad.Rotation = 35 + index * 40
			grad.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.55, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			})
			grad.Parent = blob
			blob.Parent = layer
		end
		ctx.meshLayer = layer
		applyAccent(ctx, palette)

		local t = 0
		ctx.meshConn = RunService.RenderStepped:Connect(function(dt)
			if not layer.Parent then
				return
			end
			t += dt
			local i = 0
			for _, blob in ipairs(layer:GetChildren()) do
				if blob:IsA("Frame") then
					i += 1
					local ox = math.sin(t * (0.25 + i * 0.07)) * 0.015
					local oy = math.cos(t * (0.2 + i * 0.05)) * 0.012
					blob.Position = UDim2.new(
						blobDefs[i].pos.X.Scale + ox,
						blobDefs[i].pos.X.Offset,
						blobDefs[i].pos.Y.Scale + oy,
						blobDefs[i].pos.Y.Offset
					)
				end
			end
		end)
	end

	local function installAcrylicVeil(base, ctx)
		local veil = Instance.new("Frame")
		veil.Name = "AlleralAcrylicVeil"
		veil.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
		veil.BorderSizePixel = 0
		veil.Size = UDim2.fromScale(1, 1)
		veil.ZIndex = 1
		veil.Parent = base
		ctx.acrylicVeil = veil
		ctx.setGlass = function(intensity)
			glassIntensity = math.clamp(tonumber(intensity) or glassIntensity, 0, 1)
			ENV.Alleral_GlassIntensity = glassIntensity
			veil.BackgroundTransparency = 0.92 - (glassIntensity * 0.42)
			local sidebar = base:FindFirstChild("Sidebar")
			if sidebar then
				sidebar.BackgroundTransparency = math.clamp(1 - (glassIntensity * 0.08), 0.9, 1)
			end
		end
		ctx.setGlass(glassIntensity)
	end

	local function installThemePreview(base, ctx)
		local sidebar = base:FindFirstChild("Sidebar")
		local holder = sidebar and sidebar:FindFirstChild("Information", true)
		if not holder then
			return
		end
		local swatch = Instance.new("Frame")
		swatch.Name = "AlleralThemePreview"
		swatch.AnchorPoint = Vector2.new(1, 0)
		swatch.BackgroundColor3 = accentFromEnv()
		swatch.BorderSizePixel = 0
		swatch.Position = UDim2.new(1, -8, 0, 4)
		swatch.Size = UDim2.fromOffset(42, 42)
		swatch.ZIndex = 8
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = swatch
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 0.65
		stroke.Thickness = 1
		stroke.Parent = swatch
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.Text = "Live"
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 10
		label.TextTransparency = 0.15
		label.Size = UDim2.fromScale(1, 1)
		label.Parent = swatch
		swatch.Parent = holder
		ctx.previewSwatch = swatch
		applyAccent(ctx, accentFromEnv())
	end

	local function installTabPill(base, ctx)
		if ENV.Alleral_TabAurora == false then
			return
		end
		local sidebar = base:FindFirstChild("Sidebar")
		if not sidebar then
			return
		end
		local scroll = sidebar:FindFirstChild("TabSwitchersScrollingFrame", true)
		local host = scroll and scroll:FindFirstChild("SectionTabSwitchers", true) or scroll
		if not host then
			return
		end

		local pill = Instance.new("Frame")
		pill.Name = "AlleralTabPill"
		pill.BackgroundColor3 = accentFromEnv()
		pill.BackgroundTransparency = 0.78
		pill.BorderSizePixel = 0
		pill.Size = UDim2.new(1, -42, 0, 36)
		pill.ZIndex = 0
		pill.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = pill
		local stroke = Instance.new("UIStroke")
		stroke.Color = accentFromEnv()
		stroke.Transparency = 0.55
		stroke.Thickness = 1
		stroke.Parent = pill
		pill.Parent = host
		ctx.pill = pill
		ctx.pillHost = host

		local function movePillTo(tabSwitcher)
			if not tabSwitcher or not tabSwitcher:IsA("GuiObject") then
				return
			end
			pill.Visible = true
			local y = tabSwitcher.AbsolutePosition.Y - host.AbsolutePosition.Y
			local target = UDim2.new(0, 21, 0, y)
			if motionOk() then
				spring(pill, { Position = target }, 1.05)
			else
				pill.Position = target
			end
		end

		local function bindTab(tabSwitcher)
			if not tabSwitcher or tabSwitcher.Name ~= "TabSwitcher" then
				return
			end
			tabSwitcher.MouseButton1Click:Connect(function()
				movePillTo(tabSwitcher)
			end)
		end

		for _, desc in ipairs(host:GetDescendants()) do
			bindTab(desc)
		end
		host.DescendantAdded:Connect(function(desc)
			task.defer(function()
				bindTab(desc)
			end)
		end)

		local first = host:FindFirstChild("TabSwitcher", true)
		if first then
			task.defer(function()
				movePillTo(first)
			end)
		end
	end

	local function installPageTransitions(base, ctx)
		local content = base:FindFirstChild("Content")
		if not content then
			return
		end
		local activePanel = nil
		content.ChildAdded:Connect(function(child)
			if child.Name ~= "Elements" or not child:IsA("GuiObject") then
				return
			end
			local previous = activePanel
			activePanel = child
			local targetPos = UDim2.new(child.Position.X.Scale, child.Position.X.Offset, child.Position.Y.Scale, child.Position.Y.Offset)
			child.Position = UDim2.new(targetPos.X.Scale, targetPos.X.Offset + 28, targetPos.Y.Scale, targetPos.Y.Offset)
			child.BackgroundTransparency = math.clamp(child.BackgroundTransparency, 0, 1)
			if previous and previous.Parent and previous ~= child then
				if motionOk() then
					spring(previous, {
						Position = UDim2.new(
							previous.Position.X.Scale,
							previous.Position.X.Offset - 18,
							previous.Position.Y.Scale,
							previous.Position.Y.Offset
						),
						BackgroundTransparency = 1,
					}, 0.85)
				else
					previous.Visible = false
				end
				task.delay(0.22, function()
					if previous.Parent and previous ~= activePanel then
						previous.Visible = false
					end
				end)
			end
			child.Visible = true
			if motionOk() then
				spring(child, { Position = targetPos, BackgroundTransparency = 0 }, 0.95)
			else
				child.Position = targetPos
			end
		end)
	end

	local function installWindowSnap(base, ctx)
		if ENV.Alleral_WindowSnap == false then
			return
		end
		local dragging = false
		local startPos, startSize
		base.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				startPos = base.Position
				startSize = base.Size
			end
		end)
		local function snapWindow()
			if not dragging then
				return
			end
			dragging = false
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			local vp = cam.ViewportSize
			local center = base.AbsolutePosition + base.AbsoluteSize / 2
			local zone = nil
			if center.X < vp.X * 0.22 then
				zone = "left"
			elseif center.X > vp.X * 0.78 then
				zone = "right"
			elseif center.Y < vp.Y * 0.18 then
				zone = "top"
			elseif center.X > vp.X * 0.4 and center.X < vp.X * 0.6 and center.Y > vp.Y * 0.35 and center.Y < vp.Y * 0.65 then
				zone = "center"
			end
			if not zone then
				return
			end
			local targetPos, targetSize
			if zone == "left" then
				targetPos = UDim2.new(0, 12, 0.5, 0)
				targetSize = UDim2.new(0, math.floor(vp.X * 0.48), 0, math.floor(vp.Y * 0.82))
			elseif zone == "right" then
				targetPos = UDim2.new(1, -12, 0.5, 0)
				targetSize = UDim2.new(0, math.floor(vp.X * 0.48), 0, math.floor(vp.Y * 0.82))
			elseif zone == "top" then
				targetPos = UDim2.new(0.5, 0, 0, 12)
				targetSize = UDim2.new(0, math.floor(vp.X * 0.72), 0, math.floor(vp.Y * 0.55))
			else
				targetPos = UDim2.new(0.5, 0, 0.5, 0)
				targetSize = UDim2.new(0, math.min(920, math.floor(vp.X * 0.78)), 0, math.min(680, math.floor(vp.Y * 0.82)))
			end
			base.AnchorPoint = Vector2.new(zone == "right" and 1 or zone == "left" and 0 or 0.5, zone == "top" and 0 or 0.5)
			if motionOk() then
				spring(base, { Position = targetPos, Size = targetSize }, 0.9)
			else
				base.Position = targetPos
				base.Size = targetSize
			end
			ctx.dockZone = zone
		end
		base.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				snapWindow()
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				snapWindow()
			end
		end)
	end

	local function refreshNotificationList(ctx)
		if not ctx or not ctx.notifyList then
			return
		end
		for _, child in ipairs(ctx.notifyList:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for index, entry in ipairs(notifyHistory) do
			if index > 20 then
				break
			end
			local row = Instance.new("TextButton")
			row.AutoButtonColor = false
			row.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
			row.BackgroundTransparency = 0.15
			row.BorderSizePixel = 0
			row.Size = UDim2.new(1, 0, 0, 54)
			row.Font = Enum.Font.GothamMedium
			row.Text = (entry.Title or "Alleral") .. "\n" .. (entry.Description or "")
			row.TextColor3 = Color3.fromRGB(240, 242, 248)
			row.TextSize = 11
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextYAlignment = Enum.TextYAlignment.Top
			row.TextWrapped = true
			row.LayoutOrder = index
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 10)
			pad.PaddingTop = UDim.new(0, 8)
			pad.Parent = row
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = row
			row.Parent = ctx.notifyList
		end
	end

	local function installNotificationCenter(base, ctx)
		local panel = Instance.new("Frame")
		panel.Name = "AlleralNotifyCenter"
		panel.AnchorPoint = Vector2.new(1, 0)
		panel.BackgroundColor3 = Color3.fromRGB(12, 13, 18)
		panel.BackgroundTransparency = 0.08
		panel.BorderSizePixel = 0
		panel.Position = UDim2.new(1, 320, 0, 48)
		panel.Size = UDim2.new(0, 300, 1, -96)
		panel.ZIndex = 20
		panel.Visible = false
		panel.Parent = base
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = panel
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 0.88
		stroke.Parent = panel

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.Text = "Notification Center"
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextSize = 14
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Position = UDim2.fromOffset(14, 10)
		title.Size = UDim2.new(1, -28, 0, 22)
		title.Parent = panel

		local list = Instance.new("ScrollingFrame")
		list.Name = "History"
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.Position = UDim2.fromOffset(10, 38)
		list.Size = UDim2.new(1, -20, 1, -48)
		list.ScrollBarThickness = 3
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.CanvasSize = UDim2.new()
		list.Parent = panel
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
		ctx.notifyPanel = panel
		ctx.notifyList = list

		local toggle = Instance.new("TextButton")
		toggle.Name = "AlleralNotifyToggle"
		toggle.AnchorPoint = Vector2.new(1, 0)
		toggle.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
		toggle.BackgroundTransparency = 0.2
		toggle.BorderSizePixel = 0
		toggle.Font = Enum.Font.GothamBold
		toggle.Text = "Inbox"
		toggle.TextColor3 = Color3.fromRGB(230, 233, 240)
		toggle.TextSize = 11
		toggle.Position = UDim2.new(1, -18, 0, 10)
		toggle.Size = UDim2.fromOffset(58, 24)
		toggle.ZIndex = 12
		toggle.Parent = base:FindFirstChild("Content") or base
		local tCorner = Instance.new("UICorner")
		tCorner.CornerRadius = UDim.new(0, 8)
		tCorner.Parent = toggle
		toggle.MouseButton1Click:Connect(function()
			panel.Visible = not panel.Visible
			if panel.Visible then
				panel.Position = UDim2.new(1, 320, 0, 48)
				if motionOk() then
					spring(panel, { Position = UDim2.new(1, -12, 0, 48) }, 1)
				else
					panel.Position = UDim2.new(1, -12, 0, 48)
				end
			end
		end)
		ctx.toggleNotifyCenter = toggle
		refreshNotificationList(ctx)
	end

	local function hookAnimatedSearch(inst)
		if hookedSearch[inst] or not inst:IsA("TextBox") then
			return
		end
		local parent = inst.Parent
		if not parent or (parent.Name ~= "Search" and inst.PlaceholderText:lower():find("search", 1, true) == nil) then
			return
		end
		hookedSearch[inst] = true
		local baseSize = inst.Size
		local expanded = UDim2.new(baseSize.X.Scale, baseSize.X.Offset + 48, baseSize.Y.Scale, baseSize.Y.Offset)
		inst.Focused:Connect(function()
			if motionOk() then
				spring(inst, { Size = expanded, BackgroundTransparency = 0.88 }, 1.2)
			else
				inst.Size = expanded
			end
		end)
		inst.FocusLost:Connect(function()
			if motionOk() then
				spring(inst, { Size = baseSize, BackgroundTransparency = inst.BackgroundTransparency }, 1)
			else
				inst.Size = baseSize
			end
		end)
	end

	local Premium = {}

	function Premium.pushNotification(payload)
		payload = type(payload) == "table" and payload or { Description = tostring(payload) }
		payload.at = os.time()
		table.insert(notifyHistory, 1, payload)
		while #notifyHistory > MAX_HISTORY do
			table.remove(notifyHistory)
		end
		for _, ctx in pairs(windowContexts) do
			refreshNotificationList(ctx)
		end
	end

	function Premium.setAccentColor(color)
		if typeof(color) ~= "Color3" then
			return false
		end
		for _, ctx in pairs(windowContexts) do
			applyAccent(ctx, color)
			if ctx.previewSwatch and motionOk() then
				spring(ctx.previewSwatch, { Size = UDim2.fromOffset(46, 46) }, 1.4)
				task.delay(0.08, function()
					if ctx.previewSwatch then
						spring(ctx.previewSwatch, { Size = UDim2.fromOffset(42, 42) }, 1)
					end
				end)
			end
		end
		return true
	end

	function Premium.getAccentColor()
		return accentFromEnv()
	end

	function Premium.setGlassIntensity(value)
		glassIntensity = math.clamp(tonumber(value) or glassIntensity, 0, 1)
		for _, ctx in pairs(windowContexts) do
			if ctx.setGlass then
				ctx.setGlass(glassIntensity)
			end
		end
	end

	function Premium.setNotificationLower(enabled)
		for _, ctx in pairs(windowContexts) do
			if ctx.notifyPanel then
				ctx.notifyPanel.AnchorPoint = enabled and Vector2.new(1, 1) or Vector2.new(1, 0)
				ctx.notifyPanel.Position = enabled and UDim2.new(1, -12, 1, -12) or UDim2.new(1, -12, 0, 48)
			end
		end
	end

	function Premium.applyV2Theme(name, window)
		local preset = V2_THEMES[tostring(name or "Arrrel")] or V2_THEMES.Arrrel
		ENV.Alleral_AccentHue = preset.hue
		ENV.Alleral_AccentSat = preset.sat
		ENV.Alleral_AccentVal = preset.val
		ENV.Alleral_ActiveTheme = name
		local color = Core.hsvToColor and Core.hsvToColor(preset.hue, preset.sat, preset.val) or accentFromEnv()
		Premium.setAccentColor(color)
		if window and type(window.SetTheme) == "function" then
			pcall(window.SetTheme, window, preset.mac)
		end
		return color
	end

	function Premium.cycleV2Theme(step, window)
		step = tonumber(step) or 1
		local names = {}
		for name in pairs(V2_THEMES) do
			table.insert(names, name)
		end
		table.sort(names)
		local index = 1
		for i, name in ipairs(names) do
			if name == (ENV.Alleral_ActiveTheme or "Arrrel") then
				index = i
				break
			end
		end
		index = ((index - 1 + step) % #names) + 1
		local nextName = names[index]
		Premium.applyV2Theme(nextName, window)
		return nextName
	end

	function Premium.exportCustomization()
		return {
			accent = {
				h = ENV.Alleral_AccentHue,
				s = ENV.Alleral_AccentSat,
				v = ENV.Alleral_AccentVal,
			},
			theme = ENV.Alleral_ActiveTheme,
			motion = ENV.Alleral_MotionProfile,
			glass = ENV.Alleral_GlassIntensity,
			mesh = ENV.Alleral_AmbientGlow ~= false,
			tabPill = ENV.Alleral_TabAurora ~= false,
			snap = ENV.Alleral_WindowSnap ~= false,
		}
	end

	function Premium.importCustomization(data, window)
		if type(data) ~= "table" then
			return false
		end
		if type(data.accent) == "table" then
			ENV.Alleral_AccentHue = tonumber(data.accent.h) or ENV.Alleral_AccentHue
			ENV.Alleral_AccentSat = tonumber(data.accent.s) or ENV.Alleral_AccentSat
			ENV.Alleral_AccentVal = tonumber(data.accent.v) or ENV.Alleral_AccentVal
			Premium.setAccentColor(accentFromEnv())
		end
		if data.theme then
			Premium.applyV2Theme(data.theme, window)
		end
		if data.glass then
			Premium.setGlassIntensity(data.glass)
		end
		return true
	end

	function Premium.createSparkline(parent, values, color)
		values = type(values) == "table" and values or {}
		color = typeof(color) == "Color3" and color or accentFromEnv()
		local host = Instance.new("Frame")
		host.Name = "AlleralSparkline"
		host.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
		host.BackgroundTransparency = 0.2
		host.BorderSizePixel = 0
		host.Size = UDim2.new(1, 0, 0, 72)
		host.ClipsDescendants = true
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = host
		local canvas = Instance.new("Frame")
		canvas.BackgroundTransparency = 1
		canvas.Size = UDim2.new(1, -16, 1, -16)
		canvas.Position = UDim2.fromOffset(8, 8)
		canvas.Parent = host

		local maxV, minV = 1, 0
		for _, v in ipairs(values) do
			maxV = math.max(maxV, tonumber(v) or 0)
			minV = math.min(minV, tonumber(v) or 0)
		end
		local span = math.max(maxV - minV, 1)
		local count = math.max(#values, 2)
		local width = math.max(canvas.AbsoluteSize.X, 180)
		local height = math.max(canvas.AbsoluteSize.Y, 48)
		for i = 2, #values do
			local x1 = ((i - 2) / (count - 1)) * width
			local x2 = ((i - 1) / (count - 1)) * width
			local y1 = height - (((tonumber(values[i - 1]) or 0) - minV) / span) * height
			local y2 = height - (((tonumber(values[i]) or 0) - minV) / span) * height
			local dx, dy = x2 - x1, y2 - y1
			local length = math.max(math.sqrt(dx * dx + dy * dy), 1)
			local seg = Instance.new("Frame")
			seg.AnchorPoint = Vector2.new(0, 0.5)
			seg.BackgroundColor3 = color
			seg.BorderSizePixel = 0
			seg.Position = UDim2.fromOffset(x1, y1)
			seg.Size = UDim2.fromOffset(length, 2)
			seg.Rotation = math.deg(math.atan2(dy, dx))
			seg.Parent = canvas
		end
		host.Parent = parent
		return host
	end

	function Premium.createBarChart(parent, labels, values, color)
		color = typeof(color) == "Color3" and color or accentFromEnv()
		local host = Instance.new("Frame")
		host.Name = "AlleralBarChart"
		host.BackgroundTransparency = 1
		host.Size = UDim2.new(1, 0, 0, 96)
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Padding = UDim.new(0, 6)
		layout.Parent = host
		local maxV = 1
		for _, v in ipairs(values or {}) do
			maxV = math.max(maxV, tonumber(v) or 0)
		end
		for index, value in ipairs(values or {}) do
			local col = Instance.new("Frame")
			col.BackgroundTransparency = 1
			col.Size = UDim2.new(0, 36, 1, 0)
			local bar = Instance.new("Frame")
			bar.AnchorPoint = Vector2.new(0.5, 1)
			bar.BackgroundColor3 = color
			bar.BorderSizePixel = 0
			bar.Position = UDim2.new(0.5, 0, 1, -16)
			bar.Size = UDim2.new(0, 16, 0, math.floor(64 * ((tonumber(value) or 0) / maxV)))
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 4)
			corner.Parent = bar
			bar.Parent = col
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.Gotham
			label.Text = tostring(labels and labels[index] or index)
			label.TextColor3 = Color3.fromRGB(180, 184, 196)
			label.TextSize = 9
			label.Size = UDim2.new(1, 0, 0, 14)
			label.Position = UDim2.new(0, 0, 1, -14)
			label.Parent = col
			col.Parent = host
		end
		host.Parent = parent
		return host
	end

	function Premium.attachWindow(window, gui, base)
		if type(window) ~= "table" or not base then
			return false
		end
		if window._alleralPremiumAttached then
			return true
		end
		window._alleralPremiumAttached = true
		local ctx = { window = window, gui = gui, base = base }
		windowContexts[window] = ctx
		installMeshGradient(base, ctx)
		installAcrylicVeil(base, ctx)
		installThemePreview(base, ctx)
		installTabPill(base, ctx)
		installPageTransitions(base, ctx)
		installWindowSnap(base, ctx)
		installNotificationCenter(base, ctx)
		if gui then
			gui.DescendantAdded:Connect(function(inst)
				task.defer(function()
					hookAnimatedSearch(inst)
				end)
			end)
			for _, inst in ipairs(gui:GetDescendants()) do
				hookAnimatedSearch(inst)
			end
		end
		return true
	end

	function Premium.repair(window)
		local ctx = window and windowContexts[window]
		if ctx and ctx.base then
			applyAccent(ctx, accentFromEnv())
			refreshNotificationList(ctx)
		end
		return true
	end

	ENV.Alleral_WindowSnap = ENV.Alleral_WindowSnap ~= false

	return Premium
end
