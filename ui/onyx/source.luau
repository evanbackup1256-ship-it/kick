-- Alleral OnyxUI — Fusion reactive state + Spring motion + Onyx-style components
-- Fusion: https://github.com/dphfox/Fusion  |  OnyxUI: https://github.com/loneka/onyx-ui
local ALLERAL_ONYX_VERSION = 1
local FUSION_API_VERSION = "0.3"
local ONYX_UI_VERSION = "1.0.4"

local MacLib = {}
MacLib.__AlleralPatch = ALLERAL_ONYX_VERSION
MacLib.__OnyxUi = true
MacLib.__FusionStack = true
MacLib.__AlleralVersion = ONYX_UI_VERSION

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local ENV = (function()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end)()

local ACCENT = Color3.fromRGB(83, 252, 24)
local BG = Color3.fromRGB(12, 12, 14)
local PANEL = Color3.fromRGB(20, 20, 24)
local CARD = Color3.fromRGB(26, 26, 30)
local STROKE = Color3.fromRGB(255, 255, 255)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json")

local gui: ScreenGui?
local openWindows: { any } = {}
local configFolder = "Alleral_Configs"
local menuKey = Enum.KeyCode.RightControl
local springMotion = ENV.Alleral_UiSpringMotion ~= false
local springBindings: { any } = {}
local fusionBooted = false
local Fusion = nil

local function Value(initial)
	local state = { _value = initial, _listeners = {} }
	function state:get()
		return self._value
	end
	function state:set(next)
		if self._value == next then
			return
		end
		self._value = next
		for _, listener in ipairs(self._listeners) do
			listener(next)
		end
	end
	function state:onChange(fn)
		table.insert(self._listeners, fn)
	end
	return state
end

local function Computed(producer)
	local state = Value(producer())
	local function refresh()
		state:set(producer())
	end
	return state, refresh
end

local function springStep(current, velocity, goal, speed, damping, dt)
	local offset = goal - current
	local accel = offset * speed * speed - velocity * 2 * damping * speed
	velocity += accel * dt
	current += velocity * dt
	return current, velocity
end

local function bindSpring(instance, property, goalFn, speed, damping)
	table.insert(springBindings, {
		instance = instance,
		property = property,
		goalFn = goalFn,
		current = goalFn(),
		velocity = if property == "BackgroundTransparency" then 0 else (if typeof(goalFn()) == "number" then 0 else nil),
		speed = speed or 22,
		damping = damping or 0.85,
	})
end

RunService.Heartbeat:Connect(function(dt)
	if not springMotion then
		return
	end
	dt = math.min(dt, 0.05)
	for index = #springBindings, 1, -1 do
		local binding = springBindings[index]
		local inst = binding.instance
		if not inst or not inst.Parent then
			table.remove(springBindings, index)
		else
			local goal = binding.goalFn()
			if typeof(goal) == "number" then
				local current = binding.current or goal
				local velocity = binding.velocity or 0
				current, velocity = springStep(current, velocity, goal, binding.speed, binding.damping, dt)
				binding.current = current
				binding.velocity = velocity
				inst[binding.property] = current
			elseif typeof(goal) == "UDim2" then
				local current = binding.current or goal
				local cx, cy = current.X.Scale, current.Y.Scale
				local ox, oy = goal.X.Scale, goal.Y.Scale
				cx, binding.vx = springStep(cx, binding.vx or 0, ox, binding.speed, binding.damping, dt)
				cy, binding.vy = springStep(cy, binding.vy or 0, oy, binding.speed, binding.damping, dt)
				binding.current = UDim2.fromScale(cx, cy)
				inst[binding.property] = binding.current
			end
		end
	end
end)

local function tween(inst, t, props, style)
	if springMotion and style == nil then
		style = Enum.EasingStyle.Back
	end
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function bootFusion()
	if fusionBooted then
		return Fusion
	end
	local bundle = ENV._AlleralFusionModule
	if type(bundle) == "table" then
		Fusion = bundle
		fusionBooted = true
		return Fusion
	end
	if type(bundle) == "string" and #bundle > 5000 then
		local loadFn = loadstring or load
		if type(loadFn) == "function" then
			local chunk = loadFn(bundle, "@Fusion/bundle")
			if chunk then
				local ok, mod = pcall(chunk)
				if ok and type(mod) == "table" then
					Fusion = mod
					fusionBooted = true
					return Fusion
				end
			end
		end
	end
	Fusion = { Value = Value, Computed = Computed, Spring = bindSpring, _lite = true }
	fusionBooted = true
	return Fusion
end
bootFusion()

local function getGui()
	if gui and gui.Parent then
		return gui
	end
	local player = Players.LocalPlayer
	local parent = player and player:FindFirstChildOfClass("PlayerGui") or nil
	if not parent then
		return nil
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "AlleralOnyxUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent
	return gui
end

local function sideKey(side)
	if side == "Right" then
		return "right"
	end
	if side == "Center" then
		return "center"
	end
	return "left"
end

local function sideOrder(side)
	if side == "Right" then
		return 300
	end
	if side == "Center" then
		return 200
	end
	return 100
end

function MacLib.SetFolder(_self, folder)
	if type(folder) == "string" and folder ~= "" then
		configFolder = folder
	end
end

function MacLib.ApplyEffectsFromEnv(_self, env)
	if type(env) == "table" and env.Alleral_UiSpringMotion ~= nil then
		springMotion = env.Alleral_UiSpringMotion ~= false
	end
	return true
end

function MacLib.SetSpringMotion(_self, enabled)
	springMotion = enabled ~= false
	return true
end

function MacLib.GetEffect(_self, key)
	if key == "springMotion" then
		return springMotion
	end
	return true
end

function MacLib.SetAutoResize(_self, _state)
	return true
end

function MacLib.GetAutoResize(_self)
	return true
end

function MacLib.ApplyProfile(_self, _profile)
	return true
end

function MacLib.RegisterLayoutRefresh(_self, _id, _fn)
	return true
end

function MacLib:GetLayoutInfo()
	return {
		profile = "onyx",
		engine = "OnyxUI",
		fusion = Fusion and Fusion._lite ~= true and "vendor" or "lite",
		fusionVersion = FUSION_API_VERSION,
		onyxVersion = ONYX_UI_VERSION,
	}
end

function MacLib:Window(Settings)
	Settings = Settings or {}
	local WindowFunctions = { Settings = Settings, _tabs = {}, _activeTab = nil }

	local root = getGui()
	if not root then
		return nil
	end

	if Settings.Keybind then
		menuKey = Settings.Keybind
	end

	local base = Instance.new("Frame")
	base.Name = "OnyxWindow"
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.Position = UDim2.fromScale(0.5, 0.5)
	base.Size = Settings.Size or UDim2.fromOffset(920, 680)
	base.BackgroundColor3 = BG
	base.BorderSizePixel = 0
	base.ClipsDescendants = true
	base.Parent = root

	local targetSize = Settings.Size or UDim2.fromOffset(920, 680)
	if springMotion then
		local w = targetSize.Width.Offset
		local h = targetSize.Height.Offset
		base.Size = UDim2.fromOffset(math.floor(w * 0.94), math.floor(h * 0.94))
		tween(base, 0.35, { Size = targetSize }, Enum.EasingStyle.Back)
	else
		base.Size = targetSize
	end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = base

	local stroke = Instance.new("UIStroke")
	stroke.Color = STROKE
	stroke.Transparency = 0.9
	stroke.Parent = base

	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.BackgroundTransparency = 1
	titleBar.Size = UDim2.new(1, 0, 0, 36)
	titleBar.Parent = base

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.FontFace = FONT
	title.Text = Settings.Title or "Alleral"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Size = UDim2.new(1, -20, 1, 0)
	title.Position = UDim2.fromOffset(14, 0)
	title.Parent = titleBar

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 36)
	body.Size = UDim2.new(1, 0, 1, -36)
	body.Parent = base

	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.BackgroundColor3 = PANEL
	sidebar.BackgroundTransparency = 0.15
	sidebar.BorderSizePixel = 0
	sidebar.Size = UDim2.new(0, 210, 1, 0)
	sidebar.Parent = body

	local tabList = Instance.new("UIListLayout")
	tabList.Padding = UDim.new(0, 6)
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Parent = sidebar

	local tabPad = Instance.new("UIPadding")
	tabPad.PaddingTop = UDim.new(0, 10)
	tabPad.PaddingLeft = UDim.new(0, 8)
	tabPad.PaddingRight = UDim.new(0, 8)
	tabPad.Parent = sidebar

	local contentHost = Instance.new("Frame")
	contentHost.Name = "ContentHost"
	contentHost.BackgroundTransparency = 1
	contentHost.Position = UDim2.fromOffset(210, 0)
	contentHost.Size = UDim2.new(1, -210, 1, 0)
	contentHost.ClipsDescendants = true
	contentHost.Parent = body

	local function refreshCanvas(scroll, inner)
		if not scroll or not inner then
			return
		end
		task.defer(function()
			local h = inner.AbsoluteSize.Y + 16
			scroll.CanvasSize = UDim2.new(0, 0, 0, math.max(h, scroll.AbsoluteSize.Y + 1))
		end)
	end

	function WindowFunctions:TabGroup()
		local TabGroupFunctions = {}

		function TabGroupFunctions:Tab(TabSettings)
			TabSettings = TabSettings or {}
			local TabFunctions = { Settings = TabSettings, _sections = {} }

			local tabBtn = Instance.new("TextButton")
			tabBtn.Name = "Tab_" .. tostring(TabSettings.Name or "Tab")
			tabBtn.AutoButtonColor = false
			tabBtn.BackgroundColor3 = PANEL
			tabBtn.BackgroundTransparency = 0.35
			tabBtn.BorderSizePixel = 0
			tabBtn.FontFace = FONT
			tabBtn.Text = "  " .. tostring(TabSettings.Name or "Tab")
			tabBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
			tabBtn.TextSize = 14
			tabBtn.TextXAlignment = Enum.TextXAlignment.Left
			tabBtn.Size = UDim2.new(1, 0, 0, 36)
			tabBtn.Parent = sidebar

			local tabBtnCorner = Instance.new("UICorner")
			tabBtnCorner.CornerRadius = UDim.new(0, 6)
			tabBtnCorner.Parent = tabBtn

			local page = Instance.new("ScrollingFrame")
			page.Name = "Page"
			page.BackgroundTransparency = 1
			page.BorderSizePixel = 0
			page.Size = UDim2.fromScale(1, 1)
			page.ScrollBarThickness = 4
			page.CanvasSize = UDim2.new(0, 0, 0, 0)
			page.Visible = false
			page.Parent = contentHost

			local pagePad = Instance.new("UIPadding")
			pagePad.PaddingTop = UDim.new(0, 10)
			pagePad.PaddingBottom = UDim.new(0, 12)
			pagePad.PaddingLeft = UDim.new(0, 12)
			pagePad.PaddingRight = UDim.new(0, 8)
			pagePad.Parent = page

			local stack = Instance.new("Frame")
			stack.Name = "Stack"
			stack.BackgroundTransparency = 1
			stack.AutomaticSize = Enum.AutomaticSize.Y
			stack.Size = UDim2.new(1, 0, 0, 0)
			stack.Parent = page

			local stackLayout = Instance.new("UIListLayout")
			stackLayout.Padding = UDim.new(0, 12)
			stackLayout.SortOrder = Enum.SortOrder.LayoutOrder
			stackLayout.Parent = stack

			pcall(function()
				stackLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					refreshCanvas(page, stack)
				end)
			end)

			local sectionSeq = { left = 0, center = 0, right = 0 }

			local function selectTab()
				for _, info in ipairs(WindowFunctions._tabs) do
					local active = info.tab == TabFunctions
					info.page.Visible = active
					info.button.BackgroundTransparency = active and 0.05 or 0.35
					info.button.TextColor3 = active and ACCENT or Color3.fromRGB(230, 230, 230)
				end
				WindowFunctions._activeTab = TabFunctions
				refreshCanvas(page, stack)
			end

			tabBtn.MouseButton1Click:Connect(selectTab)

			table.insert(WindowFunctions._tabs, {
				tab = TabFunctions,
				page = page,
				button = tabBtn,
				select = selectTab,
			})

			if #WindowFunctions._tabs == 1 then
				selectTab()
			end

			function TabFunctions:Select()
				selectTab()
			end

			function TabFunctions:Section(SectionSettings)
				SectionSettings = SectionSettings or {}
				local SectionFunctions = {}
				local sk = sideKey(SectionSettings.Side)
				sectionSeq[sk] += 1
				local elementOrder = 0

				local section = Instance.new("Frame")
				section.Name = "Section"
				section.AutomaticSize = Enum.AutomaticSize.Y
				section.BackgroundColor3 = CARD
				section.BackgroundTransparency = 0.2
				section.BorderSizePixel = 0
				section.Size = UDim2.new(1, 0, 0, 0)
				section.LayoutOrder = sideOrder(SectionSettings.Side) + sectionSeq[sk]
				section.Parent = stack

				local secCorner = Instance.new("UICorner")
				secCorner.CornerRadius = UDim.new(0, 8)
				secCorner.Parent = section

				local secStroke = Instance.new("UIStroke")
				secStroke.Color = STROKE
				secStroke.Transparency = 0.94
				secStroke.Parent = section

				local secPad = Instance.new("UIPadding")
				secPad.PaddingTop = UDim.new(0, 12)
				secPad.PaddingBottom = UDim.new(0, 12)
				secPad.PaddingLeft = UDim.new(0, 14)
				secPad.PaddingRight = UDim.new(0, 14)
				secPad.Parent = section

				local secList = Instance.new("UIListLayout")
				secList.Padding = UDim.new(0, 8)
				secList.SortOrder = Enum.SortOrder.LayoutOrder
				secList.Parent = section

				local function bump()
					task.defer(function()
						refreshCanvas(page, stack)
					end)
				end

				local function addElement(el)
					elementOrder += 1
					el.LayoutOrder = elementOrder
					el.Parent = section
					bump()
					return el
				end

				function SectionFunctions:Header(HS, _flag)
					local row = Instance.new("TextLabel")
					row.BackgroundTransparency = 1
					row.FontFace = FONT
					row.Text = (HS and (HS.Text or HS.Name)) or ""
					row.TextColor3 = Color3.fromRGB(255, 255, 255)
					row.TextSize = 15
					row.TextTransparency = 0.15
					row.TextXAlignment = Enum.TextXAlignment.Left
					row.TextWrapped = true
					row.AutomaticSize = Enum.AutomaticSize.Y
					row.Size = UDim2.new(1, 0, 0, 0)
					addElement(row)
					return {
						UpdateName = function(_, t)
							row.Text = t
							bump()
						end,
					}
				end

				function SectionFunctions:Label(LS, _flag)
					local row = Instance.new("TextLabel")
					row.BackgroundTransparency = 1
					row.FontFace = FONT
					row.Text = (LS and (LS.Text or LS.Name)) or ""
					row.TextColor3 = Color3.fromRGB(220, 220, 220)
					row.TextSize = 13
					row.TextTransparency = 0.2
					row.TextWrapped = true
					row.TextXAlignment = Enum.TextXAlignment.Left
					row.AutomaticSize = Enum.AutomaticSize.Y
					row.Size = UDim2.new(1, 0, 0, 0)
					addElement(row)
					return {
						UpdateName = function(_, t)
							row.Text = t
						end,
					}
				end

				function SectionFunctions:Divider()
					local box = Instance.new("Frame")
					box.BackgroundTransparency = 1
					box.Size = UDim2.new(1, 0, 0, 13)
					local line = Instance.new("Frame")
					line.BackgroundColor3 = STROKE
					line.BackgroundTransparency = 0.88
					line.BorderSizePixel = 0
					line.Size = UDim2.new(1, 0, 0, 1)
					line.Position = UDim2.fromOffset(0, 6)
					line.Parent = box
					addElement(box)
					return {}
				end

				function SectionFunctions:Button(BS, _flag)
					local wrap = Instance.new("Frame")
					wrap.BackgroundTransparency = 1
					wrap.Size = UDim2.new(1, 0, 0, 34)
					local btn = Instance.new("TextButton")
					btn.AutoButtonColor = false
					btn.BackgroundColor3 = PANEL
					btn.BackgroundTransparency = 0.1
					btn.BorderSizePixel = 0
					btn.FontFace = FONT
					btn.Text = BS and BS.Name or "Button"
					btn.TextColor3 = Color3.fromRGB(240, 240, 240)
					btn.TextSize = 13
					btn.Size = UDim2.fromScale(1, 1)
					btn.Parent = wrap
					local c = Instance.new("UICorner")
					c.CornerRadius = UDim.new(0, 6)
					c.Parent = btn
					btn.MouseButton1Click:Connect(function()
						if BS and BS.Callback then
							BS.Callback()
						end
					end)
					addElement(wrap)
					return {
						UpdateName = function(_, n)
							btn.Text = n
						end,
					}
				end

				function SectionFunctions:Toggle(TS, _flag)
					local state = TS and TS.Default == true
					local wrap = Instance.new("Frame")
					wrap.BackgroundTransparency = 1
					wrap.AutomaticSize = Enum.AutomaticSize.Y
					wrap.Size = UDim2.new(1, 0, 0, 0)
					local row = Instance.new("UIListLayout")
					row.FillDirection = Enum.FillDirection.Horizontal
					row.VerticalAlignment = Enum.VerticalAlignment.Center
					row.Padding = UDim.new(0, 10)
					row.Parent = wrap
					local min = Instance.new("UISizeConstraint")
					min.MinSize = Vector2.new(0, 36)
					min.Parent = wrap
					local label = Instance.new("TextLabel")
					label.BackgroundTransparency = 1
					label.FontFace = FONT
					label.Text = TS and TS.Name or "Toggle"
					label.TextColor3 = Color3.fromRGB(230, 230, 230)
					label.TextSize = 13
					label.TextWrapped = true
					label.TextXAlignment = Enum.TextXAlignment.Left
					label.AutomaticSize = Enum.AutomaticSize.Y
					label.Size = UDim2.new(1, -52, 0, 0)
					label.LayoutOrder = 1
					label.Parent = wrap
					local sw = Instance.new("TextButton")
					sw.AutoButtonColor = false
					sw.Text = ""
					sw.Size = UDim2.fromOffset(42, 22)
					sw.LayoutOrder = 2
					sw.BackgroundColor3 = state and ACCENT or Color3.fromRGB(70, 70, 74)
					sw.Parent = wrap
					local sc = Instance.new("UICorner")
					sc.CornerRadius = UDim.new(1, 0)
					sc.Parent = sw
					local function paint()
						sw.BackgroundColor3 = state and ACCENT or Color3.fromRGB(70, 70, 74)
					end
					sw.MouseButton1Click:Connect(function()
						state = not state
						if springMotion then
							tween(sw, 0.22, { BackgroundColor3 = state and ACCENT or Color3.fromRGB(70, 70, 74) })
						else
							paint()
						end
						paint()
						if TS and TS.Callback then
							TS.Callback(state)
						end
					end)
					paint()
					addElement(wrap)
					local api = {}
					function api:UpdateState(v)
						state = v == true
						paint()
					end
					function api:GetState()
						return state
					end
					return api
				end

				function SectionFunctions:Slider(SS, _flag)
					local minV = tonumber(SS and SS.Minimum) or 0
					local maxV = tonumber(SS and SS.Maximum) or 100
					local val = tonumber(SS and SS.Default) or minV
					local wrap = Instance.new("Frame")
					wrap.BackgroundTransparency = 1
					wrap.AutomaticSize = Enum.AutomaticSize.Y
					wrap.Size = UDim2.new(1, 0, 0, 0)
					local col = Instance.new("UIListLayout")
					col.Padding = UDim.new(0, 6)
					col.SortOrder = Enum.SortOrder.LayoutOrder
					col.Parent = wrap
					local name = Instance.new("TextLabel")
					name.BackgroundTransparency = 1
					name.FontFace = FONT
					name.Text = SS and SS.Name or "Slider"
					name.TextColor3 = Color3.fromRGB(230, 230, 230)
					name.TextSize = 13
					name.TextWrapped = true
					name.TextXAlignment = Enum.TextXAlignment.Left
					name.AutomaticSize = Enum.AutomaticSize.Y
					name.Size = UDim2.new(1, 0, 0, 0)
					name.LayoutOrder = 1
					name.Parent = wrap
					local row = Instance.new("Frame")
					row.BackgroundTransparency = 1
					row.Size = UDim2.new(1, 0, 0, 28)
					row.LayoutOrder = 2
					row.Parent = wrap
					local rowList = Instance.new("UIListLayout")
					rowList.FillDirection = Enum.FillDirection.Horizontal
					rowList.VerticalAlignment = Enum.VerticalAlignment.Center
					rowList.Padding = UDim.new(0, 8)
					rowList.Parent = row
					local track = Instance.new("Frame")
					track.BackgroundColor3 = Color3.fromRGB(70, 70, 74)
					track.BorderSizePixel = 0
					track.Size = UDim2.new(1, -52, 0, 4)
					track.LayoutOrder = 1
					track.Parent = row
					local fill = Instance.new("Frame")
					fill.BackgroundColor3 = ACCENT
					fill.BorderSizePixel = 0
					fill.Size = UDim2.new(0.5, 0, 1, 0)
					fill.Parent = track
					local box = Instance.new("TextBox")
					box.BackgroundColor3 = PANEL
					box.BorderSizePixel = 0
					box.FontFace = FONT
					box.TextColor3 = Color3.fromRGB(255, 255, 255)
					box.TextSize = 12
					box.Size = UDim2.fromOffset(44, 22)
					box.LayoutOrder = 2
					box.Parent = row
					local function setValue(v, fire)
						val = math.clamp(tonumber(v) or minV, minV, maxV)
						local alpha = (val - minV) / math.max(maxV - minV, 0.001)
						fill.Size = UDim2.new(alpha, 0, 1, 0)
						box.Text = tostring(val)
						if fire and SS and SS.Callback then
							SS.Callback(val)
						end
						bump()
					end
					track.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
							setValue(minV + (maxV - minV) * rel, true)
						end
					end)
					box.FocusLost:Connect(function()
						setValue(box.Text, true)
					end)
					setValue(val, false)
					addElement(wrap)
					return {
						UpdateValue = function(_, v)
							setValue(v, false)
						end,
						GetValue = function()
							return val
						end,
					}
				end

				function SectionFunctions:Input(IS, _flag)
					local wrap = Instance.new("Frame")
					wrap.BackgroundTransparency = 1
					wrap.AutomaticSize = Enum.AutomaticSize.Y
					wrap.Size = UDim2.new(1, 0, 0, 0)
					local col = Instance.new("UIListLayout")
					col.Padding = UDim.new(0, 4)
					col.SortOrder = Enum.SortOrder.LayoutOrder
					col.Parent = wrap
					if IS and IS.Name and IS.Name ~= "" then
						local lab = Instance.new("TextLabel")
						lab.BackgroundTransparency = 1
						lab.FontFace = FONT
						lab.Text = IS.Name
						lab.TextColor3 = Color3.fromRGB(220, 220, 220)
						lab.TextSize = 13
						lab.TextXAlignment = Enum.TextXAlignment.Left
						lab.Size = UDim2.new(1, 0, 0, 18)
						lab.LayoutOrder = 1
						lab.Parent = wrap
					end
					local box = Instance.new("TextBox")
					box.BackgroundColor3 = PANEL
					box.BorderSizePixel = 0
					box.FontFace = FONT
					box.PlaceholderText = IS and IS.Placeholder or ""
					box.Text = IS and IS.Default or ""
					box.TextColor3 = Color3.fromRGB(255, 255, 255)
					box.TextSize = 13
					box.ClearTextOnFocus = IS and IS.RemoveTextOnFocus == true
					box.Size = UDim2.new(1, 0, 0, 30)
					box.LayoutOrder = 2
					box.Parent = wrap
					local bc = Instance.new("UICorner")
					bc.CornerRadius = UDim.new(0, 6)
					bc.Parent = box
					box.FocusLost:Connect(function()
						if IS and IS.Callback then
							IS.Callback(box.Text)
						end
					end)
					addElement(wrap)
					return {
						UpdateText = function(_, t)
							box.Text = tostring(t)
						end,
					}
				end

				function SectionFunctions:Dropdown(DS, _flag)
					local options = DS and DS.Options or {}
					local multi = DS and DS.Multi == true
					local selected = {}
					if multi and type(DS.Default) == "table" then
						selected = DS.Default
					elseif DS and DS.Default then
						selected = { tostring(DS.Default) }
					end
					local open = false
					local wrap = Instance.new("Frame")
					wrap.BackgroundTransparency = 1
					wrap.AutomaticSize = Enum.AutomaticSize.Y
					wrap.ClipsDescendants = false
					wrap.Size = UDim2.new(1, 0, 0, 0)
					local col = Instance.new("UIListLayout")
					col.Padding = UDim.new(0, 4)
					col.SortOrder = Enum.SortOrder.LayoutOrder
					col.Parent = wrap
					local head = Instance.new("TextButton")
					head.AutoButtonColor = false
					head.BackgroundColor3 = PANEL
					head.BorderSizePixel = 0
					head.FontFace = FONT
					head.TextXAlignment = Enum.TextXAlignment.Left
					head.TextColor3 = Color3.fromRGB(230, 230, 230)
					head.TextSize = 13
					head.Size = UDim2.new(1, 0, 0, 34)
					head.LayoutOrder = 1
					head.Parent = wrap
					local hc = Instance.new("UICorner")
					hc.CornerRadius = UDim.new(0, 6)
					hc.Parent = head
					local body = Instance.new("Frame")
					body.BackgroundColor3 = PANEL
					body.BackgroundTransparency = 0.05
					body.BorderSizePixel = 0
					body.AutomaticSize = Enum.AutomaticSize.Y
					body.Size = UDim2.new(1, 0, 0, 0)
					body.Visible = false
					body.LayoutOrder = 2
					body.Parent = wrap
					local bc = Instance.new("UICorner")
					bc.CornerRadius = UDim.new(0, 6)
					bc.Parent = body
					local bl = Instance.new("UIListLayout")
					bl.Padding = UDim.new(0, 2)
					bl.SortOrder = Enum.SortOrder.LayoutOrder
					bl.Parent = body
					local bp = Instance.new("UIPadding")
					bp.PaddingTop = UDim.new(0, 4)
					bp.PaddingBottom = UDim.new(0, 4)
					bp.PaddingLeft = UDim.new(0, 6)
					bp.PaddingRight = UDim.new(0, 6)
					bp.Parent = body
					local function labelText()
						local title = DS and DS.Name or "Dropdown"
						if #selected == 0 then
							return title .. "..."
						end
						return title .. " • " .. table.concat(selected, ", ")
					end
					local function refreshHead()
						head.Text = "  " .. labelText()
					end
					local function emit()
						if DS and DS.Callback then
							if multi then
								local map = {}
								for _, v in ipairs(selected) do
									map[v] = true
								end
								DS.Callback(map)
							else
								DS.Callback(selected[1])
							end
						end
					end
					local function rebuildOptions(list)
						for _, c in ipairs(body:GetChildren()) do
							if c:IsA("TextButton") then
								c:Destroy()
							end
						end
						for i, opt in ipairs(list) do
							local optBtn = Instance.new("TextButton")
							optBtn.AutoButtonColor = false
							optBtn.BackgroundTransparency = table.find(selected, opt) and 0.05 or 1
							optBtn.BackgroundColor3 = ACCENT
							optBtn.BorderSizePixel = 0
							optBtn.FontFace = FONT
							optBtn.Text = "  " .. tostring(opt)
							optBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
							optBtn.TextSize = 12
							optBtn.TextXAlignment = Enum.TextXAlignment.Left
							optBtn.Size = UDim2.new(1, 0, 0, 28)
							optBtn.LayoutOrder = i
							optBtn.Parent = body
							optBtn.MouseButton1Click:Connect(function()
								if multi then
									local idx = table.find(selected, opt)
									if idx then
										table.remove(selected, idx)
									else
										table.insert(selected, opt)
									end
								else
									selected = { opt }
									open = false
									body.Visible = false
								end
								rebuildOptions(list)
								refreshHead()
								emit()
								bump()
							end)
						end
						bump()
					end
					head.MouseButton1Click:Connect(function()
						open = not open
						if springMotion then
							body.Visible = true
							body.BackgroundTransparency = open and 0.05 or 1
							tween(body, 0.2, { BackgroundTransparency = open and 0.05 or 1 })
							task.delay(0.2, function()
								if body.Parent then
									body.Visible = open
								end
							end)
						else
							body.Visible = open
						end
						if open then
							rebuildOptions(options)
						end
						bump()
					end)
					refreshHead()
					addElement(wrap)
					local api = {}
					function api:InsertOptions(newOpts)
						options = newOpts or options
						if open then
							rebuildOptions(options)
						end
					end
					function api:ClearOptions()
						options = {}
						selected = {}
						rebuildOptions(options)
						refreshHead()
					end
					function api:UpdateSelection(sel)
						if type(sel) == "table" then
							selected = sel
						elseif sel ~= nil then
							selected = { tostring(sel) }
						end
						refreshHead()
					end
					return api
				end

				function SectionFunctions:Keybind(KS, _flag)
					return SectionFunctions:Input({
						Name = KS and KS.Name or "Keybind",
						Default = "",
						Placeholder = "...",
					})
				end

				table.insert(TabFunctions._sections, SectionFunctions)
				return SectionFunctions
			end

			return TabFunctions
		end

		return TabGroupFunctions
	end

	function WindowFunctions:Notify(payload)
		payload = payload or {}
		local toast = Instance.new("Frame")
		toast.AnchorPoint = Vector2.new(1, 1)
		toast.BackgroundColor3 = PANEL
		toast.BorderSizePixel = 0
		toast.Position = UDim2.new(1, -14, 1, -14)
		toast.Size = UDim2.fromOffset(280, 64)
		toast.Parent = base
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(0, 8)
		tc.Parent = toast
		local titleLbl = Instance.new("TextLabel")
		titleLbl.BackgroundTransparency = 1
		titleLbl.FontFace = FONT
		titleLbl.Text = payload.Title or "Alleral"
		titleLbl.TextColor3 = ACCENT
		titleLbl.TextSize = 13
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.Size = UDim2.new(1, -16, 0, 18)
		titleLbl.Position = UDim2.fromOffset(10, 8)
		titleLbl.Parent = toast
		local bodyLbl = Instance.new("TextLabel")
		bodyLbl.BackgroundTransparency = 1
		bodyLbl.FontFace = FONT
		bodyLbl.Text = payload.Description or ""
		bodyLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
		bodyLbl.TextSize = 12
		bodyLbl.TextWrapped = true
		bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
		bodyLbl.TextYAlignment = Enum.TextYAlignment.Top
		bodyLbl.Size = UDim2.new(1, -16, 0, 34)
		bodyLbl.Position = UDim2.fromOffset(10, 26)
		bodyLbl.Parent = toast
		task.delay(tonumber(payload.Lifetime) or 4, function()
			if toast.Parent then
				toast:Destroy()
			end
		end)
	end

	function WindowFunctions:SetState(state)
		base.Visible = state ~= false
	end

	function WindowFunctions:GetState()
		return base.Visible
	end

	function WindowFunctions:Unload()
		base:Destroy()
	end

	table.insert(openWindows, WindowFunctions)

	local menuVisible = true
	WindowFunctions._menuConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == menuKey then
			menuVisible = not menuVisible
			base.Visible = menuVisible
		end
	end)

	return WindowFunctions
end

function MacLib:BootIrisOverlay(irisModule)
	if type(irisModule) ~= "table" or type(irisModule.AttachExploitMirror) ~= "function" then
		return false
	end
	for _, win in ipairs(openWindows) do
		pcall(irisModule.AttachExploitMirror, irisModule, win)
	end
	return true
end

return MacLib
