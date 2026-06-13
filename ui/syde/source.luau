--[[

.dP"Y8 Yb  dP 8888b.  888888
`Ybo."  YbdP   8I  Yb 88__
o.`Y8b   8P    8I  dY 88""
8bodP'  dP    8888Y"  888888  v0

]]

local inputservice =	game:GetService("InsertService")
local tweenservice = 	game:GetService("TweenService")
local https = 			game:GetService("HttpService")
local runservice =		game:GetService("RunService")
local userinput =		game:GetService("UserInputService")
local players =         game:GetService("Players"):GetPlayers()
local textservice =     game:GetService('TextService')
local player =          game:GetService('Players')
local coregui =         game:GetService("CoreGui")

local ALLERAL_SYDE_PATCH = 25

-- update check
local update = false
if update then
	local updategui = game:GetObjects("rbxassetid://122225389943465")[1]
	updategui.Parent = coregui
	local cord = '/GzumVvz3QM'
	task.wait(0.5)
	updategui.Enabled = true
	updategui.main.BackgroundTransparency = 1
	updategui.main.Size = UDim2.new(0, 150,0, 150)
	updategui.main.time.TextTransparency = 1
	updategui.main.info.TextTransparency = 1
	updategui.main.text.TextLabel.TextTransparency = 1
	updategui.main.text.more.TextTransparency = 1
	tweenservice:Create(updategui.main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
	tweenservice:Create(updategui.main, TweenInfo.new(0.75, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 350,0, 230)}):Play()
	task.wait(0.07)
	tweenservice:Create(updategui.main.time, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	tweenservice:Create(updategui.main.info, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	task.wait(0.07)
	tweenservice:Create(updategui.main.text.TextLabel, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	task.wait(0.07)
	tweenservice:Create(updategui.main.text.more, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	local duration = 25
	local startTime = tick()
	local connection
	connection = runservice.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local remaining = math.max(duration - elapsed, 0)
		updategui.main.time.Text = "Destroying in " .. string.format("%.1f", remaining) .. " secs"
		if remaining <= 0 then
			connection:Disconnect()
			tweenservice:Create(updategui.main.text.TextLabel, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
			task.wait(0.07)
			tweenservice:Create(updategui.main.text.more, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
			task.wait(0.2)
			tweenservice:Create(updategui.main, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
			tweenservice:Create(updategui.main, TweenInfo.new(0.75, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 150,0, 130)}):Play()
			updategui.main.s2.Visible = false
			task.wait(0.07)
			tweenservice:Create(updategui.main.time, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
			tweenservice:Create(updategui.main.info, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
			task.wait(0.75)
			updategui:Destroy()
		end
	end)
	updategui.main.s2.interact.MouseButton1Click:Connect(function()
		tweenservice:Create(updategui.main.s2.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Color = Color3.fromRGB(74, 255, 33)}):Play()
		tweenservice:Create(updategui.main.s2.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Transparency = 0}):Play()
		task.wait(0.5)
		tweenservice:Create(updategui.main.s2.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Color = Color3.fromRGB(87, 101, 242)}):Play()
		tweenservice:Create(updategui.main.s2.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Transparency = 0.5}):Play()
		setclipboard(cord)
	end)
end

if update then return end

local Library = game:GetObjects("rbxassetid://123800669522471")[1]
local Loader = game:GetObjects("rbxassetid://110221114597158")[1]

local resizing = false
local screenSize = workspace.CurrentCamera.ViewportSize
local isMobile = userinput.TouchEnabled or (screenSize.X < 1024 and screenSize.Y < 768)
local camera = workspace.CurrentCamera

Library.Enabled = false
Loader.Enabled = false

local loaded = false

local syde = {
	theme = {
		['Accent'] = Color3.fromRGB(255, 151, 227);
		['HitBox'] = Color3.fromRGB(255, 151, 227);
		['DropShadow'] = ColorSequence.new(Color3.fromRGB(0, 0, 0));
	};
	Connections = {};
	Comms = Instance.new('BindableEvent');
	ParentOverride = nil;
	Build = 'Sv0';
	plugins = {};
	ConfigEnabled = false;
	ConfigFolder = 'Syde';
	ConfigFile = 'Config';
	Flags = {};
	SettingsFlags = {};
	DefaultCSS = [[
.syde-window { background-color: #111111; border-radius: 12px; border-size: 0px; }
.topbar { background-color: transparent; }
.syde-tab { background-color: transparent; border-radius: 8px; font-size: 13px; transition: 0.3s; }
.syde-tab:hover { background-color: #1a1a1a; }
.syde-tab.active { background-color: #1c1c1c; }
.sidebar { background-color: #0d0d0d; }
.syde-toggle { background-color: #161616; border-radius: 10px; font-size: 13px; }
.syde-toggle .tog { background-color: #1c1c1c; border-radius: 50%; transition: 0.3s; }
.syde-toggle.on .tog { background-color: #ff97e3; }
.syde-toggle .tog .check { opacity: 0; transition: 0.3s; }
.syde-toggle.on .tog .check { opacity: 1; }
.syde-btn { background-color: #161616; border-radius: 10px; font-size: 13px; transition: 0.2s; }
.syde-btn:hover { background-color: #1e1e1e; }
.syde-slider { background-color: #161616; border-radius: 10px; font-size: 12px; }
.syde-dropdown { background-color: #161616; border-radius: 10px; font-size: 13px; }
.syde-input { background-color: #161616; border-radius: 10px; border-color: #222222; border-size: 1px; }
.syde-colorpicker { background-color: #161616; border-radius: 10px; }
.syde-keybind { background-color: #161616; border-radius: 10px; }
.syde-keybind .bind { background-color: #1c1c1c; border-radius: 6px; font-size: 12px; }
.syde-paragraph { background-color: #141414; border-radius: 10px; font-size: 12px; }
.syde-section { color: #888888; font-size: 11px; font-weight: bold; }
.syde-label { color: #cccccc; font-size: 12px; }
.syde-modal { background-color: #1a1a1a; border-radius: 14px; }
.syde-notif { background-color: #1a1a1a; border-radius: 10px; }
.syde-toast { background-color: #1a1a1a; border-radius: 8px; font-size: 12px; }
.syde-minihome { background-color: #111111; border-radius: 12px; }
]];
}

-- Alleral compatibility layer for upstream Syde (essencejs/syde).
-- Applied after the original library body; keeps upstream logic intact.

local function sydeLog(...) end
local function sydeWarn(...) end

local SYDE_CANONICAL_NAMES = {
	Main = "main",
	Top = "top",
	Tabs = "tabs",
	Pages = "pages",
	Settings = "settings",
	Dim = "dim",
	Modal = "modal",
	User = "user",
	Search = "search",
	-- Render: keep PascalCase — upstream uses ui.Render.ToggleConfiguration
	Minihome = "minihome",
	Toastholder = "toastholder",
	ToastHolder = "toastholder",
	Toast = "toast",
	Title = "title",
	Sub = "sub",
	Subtitle = "sub",
	Tog = "tog",
	Check = "check",
	Gradfr = "gradfr",
	GradFr = "gradfr",
	Glow = "glow",
	Interact = "interact",
	Configure = "configure",
	ClipFrame = "clipframe",
	Clipframe = "clipframe",
	Separator = "separator",
	Desc = "desc",
	Icon = "icon",
	Timer = "timer",
	Slide = "slide",
	SlideFrame = "slideframe",
	Slideframe = "slideframe",
	DropHolder = "dropholder",
	Dropholder = "dropholder",
	Drop = "drop",
	Selected = "selected",
	Down = "down",
	Shadow = "shadow",
	Functions = "functions",
	Resize = "resize",
	Wallpaper = "wallpaper",
	Homeicon = "homeicon",
	HomeIcon = "homeicon",
	Tb = "tb",
	Btn = "btn",
	Tab = "tab",
	Page = "page",
	Indicator = "indicator",
	Buttons = "buttons",
	Confirm = "confirm",
	Cancel = "cancel",
	Option = "Option",
}

local function sydeFindChild(parent, ...)
	if not parent then
		return nil
	end
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		local child = parent:FindFirstChild(name)
		if child then
			return child
		end
	end
	return nil
end

local function sydeButtonLabel(button)
	if not button then
		return nil
	end
	return sydeFindChild(button, "TextLabel", "text", "title")
end

local function sydeSliderLabel(slider)
	if not slider then
		return nil
	end
	return sydeFindChild(slider, "title", "Title")
end

local function sydeOptionLabel(option)
	if not option then
		return nil
	end
	return sydeFindChild(option, "title", "Title", "TextLabel", "text")
end

local function sydeTitleLabel(instance)
	return sydeOptionLabel(instance)
end

local function sydeOptionText(option)
	local label = sydeOptionLabel(option)
	return label and label.Text or ""
end

local function sydeLoaderProfileLabel(loaderGui)
	local root = loaderGui or Loader
	if not root then
		return nil
	end
	local loaderFrame = sydeFindChild(root, "loader")
	local profile = loaderFrame and sydeFindChild(loaderFrame, "profile")
	return profile and sydeTitleLabel(profile)
end

local function sydeBindUi(root)
	root = root or Library
	local main = sydeFindChild(root, "main", "Main")
	local render = sydeFindChild(root, "Render", "render")
	local toastholder = sydeFindChild(root, "toastholder", "Toastholder", "ToastHolder")
	local bound = {
		_root = root,
		main = main,
		Main = main,
		Render = render,
		render = render,
		toastholder = toastholder,
		Toastholder = toastholder,
	}
	return setmetatable(bound, {
		__index = function(_, key)
			local value = rawget(bound, key)
			if value ~= nil then
				return value
			end
			if key == "main" or key == "Main" then
				return main
			end
			return root[key]
		end,
	})
end

local function sydeButtonStroke(button)
	if not button then
		return nil
	end
	return button:FindFirstChildOfClass("UIStroke") or sydeFindChild(button, "UIStroke")
end

local function sydeResolveModal(instance)
	local buttonsFrame = sydeFindChild(instance, "Buttons", "buttons")
	local confirm = buttonsFrame and sydeFindChild(buttonsFrame, "Confirm", "confirm")
		or sydeFindChild(instance, "Confirm", "confirm")
	local cancel = buttonsFrame and sydeFindChild(buttonsFrame, "Cancel", "cancel")
		or sydeFindChild(instance, "Cancel", "cancel")
	return {
		Instance = instance,
		Title = sydeFindChild(instance, "Title", "title"),
		Content = sydeFindChild(instance, "Content", "content"),
		UIStroke = instance:FindFirstChildOfClass("UIStroke"),
		Confirm = confirm,
		Cancel = cancel,
		ConfirmLabel = sydeButtonLabel(confirm),
		CancelLabel = sydeButtonLabel(cancel),
		ConfirmStroke = sydeButtonStroke(confirm),
		CancelStroke = sydeButtonStroke(cancel),
	}
end

local function sydeSetInteractable(button, enabled)
	if not button then
		return
	end
	if typeof(button.Interactable) == "boolean" then
		button.Interactable = enabled
	end
	local interact = sydeFindChild(button, "interact", "Interact")
	if interact and typeof(interact.Interactable) == "boolean" then
		interact.Interactable = enabled
	end
end

local function sydeConnectClick(button, callback)
	if not button or type(callback) ~= "function" then
		return
	end
	if button:IsA("GuiButton") then
		button.MouseButton1Click:Connect(callback)
		return
	end
	local interact = sydeFindChild(button, "interact", "Interact")
	if interact and interact:IsA("GuiButton") then
		interact.MouseButton1Click:Connect(callback)
	end
end

local function sydeConnectSliderDrag(slideFrame, onDown, onUp)
	if not slideFrame or type(onDown) ~= "function" or type(onUp) ~= "function" then
		return
	end
	local handle = sydeFindChild(slideFrame, "interact", "Interact")
	if not handle and slideFrame:IsA("GuiButton") then
		handle = slideFrame
	end
	if handle and handle:IsA("GuiButton") then
		handle.MouseButton1Down:Connect(onDown)
		handle.MouseButton1Up:Connect(onUp)
		return
	end
	slideFrame.Active = true
	slideFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			onDown()
		end
	end)
	slideFrame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			onUp()
		end
	end)
end

local function sydeDropSelectedLabel(drop)
	if not drop then
		return nil
	end
	local label = sydeFindChild(
		drop,
		"selected",
		"Selected",
		"select",
		"Select",
		"value",
		"Value",
		"placeholder",
		"Placeholder"
	)
	if label then
		return label
	end
	for _, child in ipairs(drop:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			return child
		end
	end
	return nil
end

local function sydeBindDropFrame(drop)
	if not drop then
		return nil
	end
	local selectedLabel = sydeDropSelectedLabel(drop)
	local selectContainer = sydeFindChild(drop, "selectContainer", "SelectContainer", "selectedContainer", "SelectedContainer")
	local container = sydeFindChild(drop, "Container", "container")
	local search = sydeFindChild(drop, "search", "Search")
	local down = sydeFindChild(drop, "down", "Down")
	local v0 = sydeFindChild(drop, "v0", "V0")
	local bound = {
		_drop = drop,
		selected = selectedLabel,
		Selected = selectedLabel,
		selectContainer = selectContainer,
		SelectContainer = selectContainer,
		Container = container,
		container = container,
		search = search,
		Search = search,
		down = down,
		Down = down,
		v0 = v0,
		V0 = v0,
	}
	return setmetatable(bound, {
		__index = function(_, key)
			if key == "_drop" then
				return drop
			end
			local value = rawget(bound, key)
			if value ~= nil then
				return value
			end
			local instValue = drop[key]
			if type(instValue) == "function" then
				return function(first, ...)
					if first == drop or first == bound then
						return instValue(drop, ...)
					end
					return instValue(drop, first, ...)
				end
			end
			return instValue
		end,
		__newindex = function(_, key, value)
			drop[key] = value
		end,
	})
end

local function sydeUnwrapDropFrame(drop)
	if type(drop) == "table" and drop._drop then
		return drop._drop
	end
	return drop
end

local function sydeSetDropSelectedText(drop, text)
	local frame = sydeUnwrapDropFrame(drop)
	local label = drop and (drop.selected or sydeDropSelectedLabel(frame))
	if label then
		label.Text = tostring(text or "")
	end
end

local function sydeSanitizeAssetRoot(root)
	if not root then
		return
	end
	for _, desc in ipairs(root:GetDescendants()) do
		if desc:IsA("LocalScript") or desc:IsA("Script") or desc:IsA("ModuleScript") then
			pcall(function()
				desc:Destroy()
			end)
		end
	end
end

local function sydeShouldSkipNormalize(instance)
	local current = instance
	while current do
		if current.Name == "Render" then
			return true
		end
		current = current.Parent
	end
	return false
end

local function sydeNormalizeTemplateNames(root)
	-- DISABLED: renaming PascalCase→lowercase breaks dot-notation access (e.g. window.clipframe, toggle.tog, Slider.slide)
	return
end

local function sydePrepareAssetRoot(root)
	sydeSanitizeAssetRoot(root)
	sydeNormalizeTemplateNames(root)
end

local function sydeSanitizeUiClone(root)
	sydePrepareAssetRoot(root)
end

sydePrepareAssetRoot(Library)
sydePrepareAssetRoot(Loader)

local function sydeEnsureDropholderDropFrame(dropholder)
	if not dropholder then
		return nil
	end
	local drop = sydeFindChild(dropholder, "drop", "Drop")
	if drop then
		return drop
	end
	drop = Instance.new("Frame")
	drop.Name = "drop"
	drop.BackgroundTransparency = 1
	drop.BorderSizePixel = 0
	drop.Size = UDim2.new(1, 0, 1, 0)
	drop.Position = UDim2.new(0, 0, 0, 0)
	drop.ZIndex = dropholder.ZIndex
	local children = dropholder:GetChildren()
	drop.Parent = dropholder
	for _, child in ipairs(children) do
		if child ~= drop then
			child.Parent = drop
		end
	end
	return drop
end

local function sydeResolveDropFrame(dropholder)
	if not dropholder then
		return nil
	end
	local drop = sydeFindChild(dropholder, "drop", "Drop")
	if drop then
		return drop
	end
	if sydeFindChild(dropholder, "Container", "container") or sydeDropSelectedLabel(dropholder) then
		return dropholder
	end
	for _, child in ipairs(dropholder:GetChildren()) do
		if child:IsA("GuiObject") then
			if sydeFindChild(child, "Container", "container") or sydeDropSelectedLabel(child) then
				return child
			end
		end
	end
	return nil
end

local function sydeDropHasContainer(dropFrame)
	return dropFrame ~= nil and sydeFindChild(dropFrame, "Container", "container") ~= nil
end

local function sydePrepareDropdownDrop(dropdown)
	if not dropdown then
		return nil
	end
	sydeSanitizeUiClone(dropdown)
	local holder = sydeFindChild(dropdown, "dropholder", "DropHolder", "Dropholder", "dropHolder")
	if not holder then
		for _, child in ipairs(dropdown:GetChildren()) do
			if sydeResolveDropFrame(child) then
				holder = child
				break
			end
		end
	end
	local dropFrame = nil
	if holder then
		dropFrame = sydeEnsureDropholderDropFrame(holder) or sydeResolveDropFrame(holder)
	end
	if not sydeDropHasContainer(dropFrame) then
		local altDrop = sydeFindChild(dropdown, "drop", "Drop")
		if sydeDropHasContainer(altDrop) then
			dropFrame = altDrop
		else
			for _, child in ipairs(dropdown:GetChildren()) do
				if child ~= holder then
					local resolved = sydeResolveDropFrame(child)
					if sydeDropHasContainer(resolved) then
						dropFrame = resolved
						break
					end
				end
			end
		end
	end
	if not dropFrame then
		return nil
	end
	return sydeBindDropFrame(dropFrame) or dropFrame
end

local PAGE_TEMPLATE_ALIASES = {
	Button = { "Button", "button" },
	Toggle = { "Toggle", "toggle" },
	KeyBind = { "KeyBind", "keybind", "Keybind" },
	ColorPicker = { "ColorPicker", "colorpicker", "Colorpicker" },
	Dropdown = { "Dropdown", "dropdown" },
	Slider = { "Slider", "slider" },
	Paragraph = { "Paragraph", "paragraph", "Para", "para" },
	Input = { "Input", "input", "TextInput", "textinput" },
	Label = { "Label", "label" },
	Section = { "Section", "section" },
	["3DView"] = { "3DView", "3dview", "View3D", "view3d" },
}

local function sydePageTemplate(pageContainer, templateName)
	if not pageContainer then
		return nil
	end
	local aliases = PAGE_TEMPLATE_ALIASES[templateName]
	if aliases then
		return sydeFindChild(pageContainer, table.unpack(aliases))
	end
	local lower = templateName:sub(1, 1):lower() .. templateName:sub(2)
	return sydeFindChild(pageContainer, templateName, lower)
end

local function sydeClonePageTemplate(pageContainer, templateName)
	local template = sydePageTemplate(pageContainer, templateName)
	if not template then
		sydeWarn("[Syde] Missing page template: " .. tostring(templateName))
		return nil
	end
	local clone = template:Clone()
	sydeSanitizeUiClone(clone)
	return clone
end

function syde:DeepMerge(target, source)
	for k, v in pairs(source) do
		if type(v) == "table" and type(target[k]) == "table" then
			self:DeepMerge(target[k], v)
		else
			target[k] = v
		end
	end
end

function syde:UpdateTheme(Config)
	if type(Config) ~= "table" then warn("[UpdateTheme] Invalid configuration table") return end
	local updatedKeys = {}
	for key, value in pairs(Config) do
		if self.theme[key] ~= nil then
			if typeof(self.theme[key]) == typeof(value) then
				if type(value) == "table" then self:DeepMerge(self.theme[key], value)
				else self.theme[key] = value end
				table.insert(updatedKeys, key)
			else
				warn(("[UpdateTheme] Type mismatch for key '%s'"):format(key))
			end
		else
			warn("[UpdateTheme] Key '" .. key .. "' does not exist in theme")
		end
	end
	if #updatedKeys > 0 then
		for _, key in ipairs(updatedKeys) do
			self.Comms:Fire(key, self.theme[key])
		end
	end
end

local RunService = game:GetService'RunService'

do
	local function IsNotNaN(x) return x == x end
	local continue = IsNotNaN(camera:ScreenPointToRay(0,0).Origin.x)
	while not continue do
		RunService.RenderStepped:wait()
		continue = IsNotNaN(camera:ScreenPointToRay(0,0).Origin.x)
	end
end

local binds = {}
local root = Instance.new('Folder', camera)
root.Name = 'neon'

local GenUid
do
	local id = 0
	function GenUid()
		id = id + 1
		return 'neon::'..tostring(id)
	end
end

local DrawQuad
do
	local acos, max, pi, sqrt = math.acos, math.max, math.pi, math.sqrt
	local sz = 0.2
	function DrawTriangle(v1, v2, v3, p0, p1)
		local s1 = (v1 - v2).magnitude
		local s2 = (v2 - v3).magnitude
		local s3 = (v3 - v1).magnitude
		local smax = max(s1, s2, s3)
		local A, B, C
		if s1 == smax then A, B, C = v1, v2, v3
		elseif s2 == smax then A, B, C = v2, v3, v1
		elseif s3 == smax then A, B, C = v3, v1, v2 end
		local para = ((B-A).x*(C-A).x + (B-A).y*(C-A).y + (B-A).z*(C-A).z) / (A-B).magnitude
		local perp = sqrt((C-A).magnitude^2 - para*para)
		local dif_para = (A - B).magnitude - para
		local st = CFrame.new(B, A)
		local za = CFrame.Angles(pi/2,0,0)
		local cf0 = st
		local Top_Look = (cf0 * za).lookVector
		local Mid_Point = A + CFrame.new(A, B).lookVector * para
		local Needed_Look = CFrame.new(Mid_Point, C).lookVector
		local dot = Top_Look.x*Needed_Look.x + Top_Look.y*Needed_Look.y + Top_Look.z*Needed_Look.z
		local ac = CFrame.Angles(0, 0, acos(dot))
		cf0 = cf0 * ac
		if ((cf0 * za).lookVector - Needed_Look).magnitude > 0.01 then
			cf0 = cf0 * CFrame.Angles(0, 0, -2*acos(dot))
		end
		cf0 = cf0 * CFrame.new(0, perp/2, -(dif_para + para/2))
		local cf1 = st * ac * CFrame.Angles(0, pi, 0)
		if ((cf1 * za).lookVector - Needed_Look).magnitude > 0.01 then
			cf1 = cf1 * CFrame.Angles(0, 0, 2*acos(dot))
		end
		cf1 = cf1 * CFrame.new(0, perp/2, dif_para/2)
		if not p0 then
			p0 = Instance.new('Part')
			p0.FormFactor = 'Custom'
			p0.TopSurface = 0
			p0.BottomSurface = 0
			p0.Anchored = true
			p0.CanCollide = false
			p0.Material = 'Glass'
			p0.Size = Vector3.new(sz, sz, sz)
			local mesh = Instance.new('SpecialMesh', p0)
			mesh.MeshType = 2
			mesh.Name = 'WedgeMesh'
		end
		p0.WedgeMesh.Scale = Vector3.new(0, perp/sz, para/sz)
		p0.CFrame = cf0
		if not p1 then p1 = p0:clone() end
		p1.WedgeMesh.Scale = Vector3.new(0, perp/sz, dif_para/sz)
		p1.CFrame = cf1
		return p0, p1
	end
	function DrawQuad(v1, v2, v3, v4, parts)
		parts[1], parts[2] = DrawTriangle(v1, v2, v3, parts[1], parts[2])
		parts[3], parts[4] = DrawTriangle(v3, v2, v4, parts[3], parts[4])
	end
end

function syde:BindFrame(frame, properties)
	if binds[frame] then return binds[frame].parts end
	local uid = GenUid()
	local parts = {}
	local f = Instance.new('Folder', root)
	f.Name = frame.Name
	local parents = {}
	do
		local function add(child)
			if child:IsA'GuiObject' then
				parents[#parents + 1] = child
				add(child.Parent)
			end
		end
		add(frame)
	end
	local function UpdateOrientation(fetchProps)
		local zIndex = 1 - 0.05*frame.ZIndex
		local tl, br = frame.AbsolutePosition, frame.AbsolutePosition + frame.AbsoluteSize
		local tr, bl = Vector2.new(br.x, tl.y), Vector2.new(tl.x, br.y)
		do
			local rot = 0
			for _, v in ipairs(parents) do rot = rot + v.Rotation end
			if rot ~= 0 and rot%180 ~= 0 then
				local mid = tl:lerp(br, 0.5)
				local s, c = math.sin(math.rad(rot)), math.cos(math.rad(rot))
				tl = Vector2.new(c*(tl.x - mid.x) - s*(tl.y - mid.y), s*(tl.x - mid.x) + c*(tl.y - mid.y)) + mid
				tr = Vector2.new(c*(tr.x - mid.x) - s*(tr.y - mid.y), s*(tr.x - mid.x) + c*(tr.y - mid.y)) + mid
				bl = Vector2.new(c*(bl.x - mid.x) - s*(bl.y - mid.y), s*(bl.x - mid.x) + c*(bl.y - mid.y)) + mid
				br = Vector2.new(c*(br.x - mid.x) - s*(br.y - mid.y), s*(br.x - mid.x) + c*(br.y - mid.y)) + mid
			end
		end
		DrawQuad(
			camera:ScreenPointToRay(tl.x, tl.y, zIndex).Origin,
			camera:ScreenPointToRay(tr.x, tr.y, zIndex).Origin,
			camera:ScreenPointToRay(bl.x, bl.y, zIndex).Origin,
			camera:ScreenPointToRay(br.x, br.y, zIndex).Origin,
			parts
		)
		if fetchProps then
			for _, pt in pairs(parts) do pt.Parent = f end
			for propName, propValue in pairs(properties) do
				for _, pt in pairs(parts) do pt[propName] = propValue end
			end
		end
	end
	UpdateOrientation(true)
	RunService:BindToRenderStep(uid, 2000, UpdateOrientation)
	binds[frame] = { uid = uid; parts = parts }
	return binds[frame].parts
end

function syde:Modify(frame, properties)
	local parts = syde:GetBoundParts(frame)
	if parts then
		for propName, propValue in pairs(properties) do
			for _, pt in pairs(parts) do pt[propName] = propValue end
		end
	end
end

function syde:UnbindFrame(frame)
	local cb = binds[frame]
	if cb then
		RunService:UnbindFromRenderStep(cb.uid)
		for _, v in pairs(cb.parts) do v:Destroy() end
		binds[frame] = nil
	end
end

function syde:HasBinding(frame) return binds[frame] ~= nil end
function syde:GetBoundParts(frame) return binds[frame] and binds[frame].parts end

function syde:GetDark(Color, val, mode)
	if typeof(Color) ~= "Color3" or type(val) ~= "number" then return Color end
	local H, S, V = Color:ToHSV()
	val = math.clamp(val, 0.1, 10)
	if mode == "subtract" then V = math.clamp(V - (val / 10), 0, 1)
	else V = math.clamp(V / val, 0, 1) end
	return Color3.fromHSV(H, S, V)
end

function syde:GetLighter(color, strength)
	strength = math.clamp(strength or 0.2, 0, 1)
	return Color3.new(
		color.R + (1 - color.R) * strength,
		color.G + (1 - color.G) * strength,
		color.B + (1 - color.B) * strength
	)
end

function syde:ColorPack(color)
	assert(typeof(color) == "Color3", "PackColor expects a Color3 value.")
	return { R = math.round(color.R * 255), G = math.round(color.G * 255), B = math.round(color.B * 255) }
end

function syde:ColorUnpack(color)
	assert(type(color) == "table" or type(color) == "string", "Invalid color format.")
	if type(color) == "table" then
		assert(color.R and color.G and color.B, "RGB table must contain 'R', 'G', and 'B' keys.")
		return Color3.fromRGB(math.clamp(color.R, 0, 255), math.clamp(color.G, 0, 255), math.clamp(color.B, 0, 255))
	elseif type(color) == "string" then
		local hex = color:match("^#?(%x%x%x%x%x%x)$")
		assert(hex, "Invalid HEX color format.")
		local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
		return Color3.fromRGB(r, g, b)
	end
end

function syde:HidePH(instance, placeholder, recursive)
	if typeof(instance) ~= "Instance" or type(placeholder) ~= "string" then return end
	local target = instance:FindFirstChild(placeholder)
	if not target then return end
	if target:IsA("GuiObject") then target.Visible = false else return end
	if recursive then
		for _, child in ipairs(target:GetDescendants()) do
			if child:IsA("GuiObject") then child.Visible = false end
		end
	end
end

function syde:AddConnection(Type, Callback)
	if typeof(Type) ~= "RBXScriptSignal" then error("[AddConnection] Invalid Type: Expected RBXScriptSignal") end
	if typeof(Callback) ~= "function" then error("[AddConnection] Invalid Callback: Expected function") end
	local Connection = Type:Connect(Callback)
	local ConnectionData = { Connection = Connection }
	syde.Connections = syde.Connections or {}
	table.insert(syde.Connections, ConnectionData)
	local function Disconnect()
		if Connection.Connected then Connection:Disconnect() end
		for i = #syde.Connections, 1, -1 do
			if syde.Connections[i] == ConnectionData then
				table.remove(syde.Connections, i)
				break
			end
		end
	end
	task.spawn(function()
		task.wait(10)
		for i = #syde.Connections, 1, -1 do
			if not syde.Connections[i].Connection.Connected then
				table.remove(syde.Connections, i)
			end
		end
	end)
	return Connection, Disconnect
end

local Bento = {}
Bento.__index = Bento
function Bento.new(container, config)
	local self = setmetatable({}, Bento)
	self.Container = container
	self.Items = {}
	self.Rows = {}
	self.Gap = config.Gap or 8
	self.RightPadding = config.RightPadding or 16
	self.TweenTime = config.TweenTime or 0.3
	self.OriginalContainerSize = container.Size
	self.Original = {}
	self.ActiveTweens = {}
	return self
end
function Bento:NewRow() local row = {} table.insert(self.Rows,row) return row end
function Bento:AddItem(frame, options, row)
	frame.AnchorPoint = Vector2.new(0,0)
	local item = { Frame = frame, Bottom = options and options.Bottom, Row = row }
	self.Original[frame] = { Position = frame.Position, Size = frame.Size }
	table.insert(self.Items,item)
	if row then table.insert(row,item) end
end
function Bento:Tween(frame, goal)
	if self.ActiveTweens[frame] then self.ActiveTweens[frame]:Cancel() end
	local tween = tweenservice:Create(frame, TweenInfo.new(self.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	self.ActiveTweens[frame] = tween
	tween:Play()
	tween.Completed:Connect(function()
		if self.ActiveTweens[frame] == tween then self.ActiveTweens[frame] = nil end
	end)
end
function Bento:Update()
	local containerWidth = self.Container.AbsoluteSize.X
	local normalItems = {}
	local bottomItems = {}
	for _,item in ipairs(self.Items) do
		if item.Bottom then table.insert(bottomItems,item) else table.insert(normalItems,item) end
	end
	local sortedRows = {}
	if #self.Rows > 0 then
		for _,row in ipairs(self.Rows) do table.insert(sortedRows,{ Items = row }) end
	else
		local rows = {}
		for _,item in ipairs(normalItems) do
			local original = self.Original[item.Frame]
			local y = original.Position.Y.Offset
			rows[y] = rows[y] or {}
			table.insert(rows[y],item)
		end
		for y,row in pairs(rows) do table.insert(sortedRows,{ Y = y, Items = row }) end
		table.sort(sortedRows,function(a,b) return a.Y < b.Y end)
	end
	local widestRow = 0
	for _,row in ipairs(sortedRows) do
		local width = 0
		for _,item in ipairs(row.Items) do width = width + self.Original[item.Frame].Size.X.Offset end
		width = width + (#row.Items-1) * self.Gap
		if width > widestRow then widestRow = width end
	end
	local stacked = widestRow > containerWidth
	if stacked then
		local y = 0
		local function stackItem(item)
			local frame = item.Frame
			local original = self.Original[frame]
			self:Tween(frame,{ Position = UDim2.fromOffset(0,y), Size = UDim2.fromOffset(containerWidth - self.RightPadding, original.Size.Y.Offset) })
			y = y + original.Size.Y.Offset + self.Gap
		end
		for _,row in ipairs(sortedRows) do
			for _,item in ipairs(row.Items) do if not item.Bottom then stackItem(item) end end
		end
		for _,item in ipairs(bottomItems) do stackItem(item) end
		self.Container.Size = UDim2.new(self.OriginalContainerSize.X.Scale, self.OriginalContainerSize.X.Offset, 0, y - self.Gap)
		return
	end
	for _,row in ipairs(sortedRows) do
		table.sort(row.Items,function(a,b) return self.Original[a.Frame].Position.X.Offset < self.Original[b.Frame].Position.X.Offset end)
		for i,item in ipairs(row.Items) do
			local frame = item.Frame
			local original = self.Original[frame]
			local currentX = original.Position.X.Offset
			local height = original.Size.Y.Offset
			local nextItem = row.Items[i+1]
			local width
			if nextItem then
				width = self.Original[nextItem.Frame].Position.X.Offset - currentX - self.Gap
			else
				width = containerWidth - currentX - self.RightPadding
			end
			self:Tween(frame,{ Position = original.Position, Size = UDim2.fromOffset(width,height) })
		end
	end
	for _,item in ipairs(bottomItems) do
		local frame = item.Frame
		local original = self.Original[frame]
		local width = containerWidth - original.Position.X.Offset - self.RightPadding
		self:Tween(frame,{ Position = original.Position, Size = UDim2.fromOffset(width,original.Size.Y.Offset) })
	end
	self.Container.Size = self.OriginalContainerSize
end
function Bento:Bind()
	local busy = false
	self.Container:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if busy then return end
		busy = true
		task.defer(function() self:Update() busy = false end)
	end)
end

function syde:MakeResizable(Dragger, Object, MinSize, Callback, LockAspectRatio)
	assert(typeof(Dragger) == "Instance" and Dragger:IsA("GuiObject"), "[MakeResizable] Dragger must be a GuiObject")
	assert(typeof(Object) == "Instance" and Object:IsA("GuiObject"), "[MakeResizable] Object must be a GuiObject")
	assert(typeof(MinSize) == "Vector2", "[MakeResizable] MinSize must be a Vector2")
	local userInput = game:GetService("UserInputService")
	local startPosition, startSize = nil, nil
	local isResizing = false
	local function getInputPos(input)
		if input.UserInputType == Enum.UserInputType.Touch then return Vector2.new(input.Position.X, input.Position.Y)
		else return userInput:GetMouseLocation() end
	end
	local function onInputBegan(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isResizing = true
			resizing = true
			startPosition = getInputPos(input)
			startSize = Object.AbsoluteSize
		end
	end
	local function onInputChanged(input)
		if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local mouse = getInputPos(input)
			if startPosition and mouse then
				local delta = mouse - startPosition
				local newWidth = math.max(MinSize.X, startSize.X + delta.X)
				local newHeight = math.max(MinSize.Y, startSize.Y + delta.Y)
				if LockAspectRatio then newHeight = newWidth / (startSize.X / startSize.Y) end
				Object:TweenSize(UDim2.fromOffset(newWidth, newHeight), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.4, true)
				if Callback then Callback(Vector2.new(newWidth, newHeight)) end
			end
		end
	end
	local function onInputEnded(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isResizing = false
			resizing = false
			startPosition, startSize = nil, nil
		end
	end
	syde:AddConnection(Dragger.InputBegan, onInputBegan)
	syde:AddConnection(userInput.InputChanged, onInputChanged)
	syde:AddConnection(Dragger.InputEnded, onInputEnded)
end

local loadTweens = {}
function syde:registerLoadTween(object, properties, initialState, tweenInfo)
	assert(typeof(object) == "Instance", "[registerLoadTween] Object must be an Instance")
	assert(typeof(properties) == "table", "[registerLoadTween] Properties must be a table")
	assert(typeof(initialState) == "table", "[registerLoadTween] Initial state must be a table")
	assert(typeof(tweenInfo) == "TweenInfo", "[registerLoadTween] TweenInfo must be of type TweenInfo")
	loadTweens[object] = { tween = tweenservice:Create(object, tweenInfo, properties), properties = properties, initialState = initialState, tweenInfo = tweenInfo }
end
function syde:resetToInitialState(animated, resetTweenInfo)
	for object, tweenData in pairs(loadTweens) do
		if object and object.Parent then
			tweenData.tween:Cancel()
			if animated then
				local resetTween = tweenservice:Create(object, resetTweenInfo or TweenInfo.new(0.3), tweenData.initialState)
				resetTween:Play()
				resetTween.Completed:Wait()
			else
				for property, value in pairs(tweenData.initialState) do object[property] = value end
			end
		end
	end
end
function syde:replayLoadTweens(targetObject)
	syde:resetToInitialState(false)
	for object, tweenData in pairs(loadTweens) do
		if object and object.Parent then
			if not targetObject or object == targetObject then
				tweenData.tween:Cancel()
				tweenData.tween:Play()
			end
		end
	end
end
function syde:removeLoadTween(object)
	if loadTweens[object] then loadTweens[object].tween:Cancel() loadTweens[object] = nil end
end

function syde:WiggleText(label)
	if not label or not label:IsA("TextLabel") then return end
	if not label.Text or label.Text == "" then return end
	if label:FindFirstChild("WiggleContainer") then label.WiggleContainer:Destroy() end
	local container = Instance.new("Folder")
	container.Name = "WiggleContainer"
	container.Parent = label
	label.TextTransparency = 1
	local baseText = label.Text:gsub("<.->", "")
	local fontFace = label.FontFace
	local baseSize = label.TextSize
	local textColor = label.TextColor3
	local chars = {}
	local xOffset = 0
	for i = 1, #baseText do
		local char = baseText:sub(i, i)
		local charLabel = Instance.new("TextLabel")
		charLabel.BackgroundTransparency = 1
		charLabel.Text = char
		charLabel.TextColor3 = textColor
		charLabel.TextSize = baseSize
		charLabel.FontFace = fontFace
		charLabel.TextXAlignment = Enum.TextXAlignment.Left
		charLabel.TextYAlignment = Enum.TextYAlignment.Center
		charLabel.AnchorPoint = Vector2.new(0, 0.5)
		charLabel.Position = UDim2.new(0, xOffset, 0.5, 0)
		charLabel.Parent = container
		charLabel.ZIndex = 99
		xOffset = xOffset + charLabel.TextBounds.X
		table.insert(chars, charLabel)
	end
	local t = 0
	local id = "Wiggle_" .. tostring(math.random(1, 999999))
	RunService:BindToRenderStep(id, Enum.RenderPriority.First.Value, function(dt)
		t = t + dt * 6
		for i, charLabel in ipairs(chars) do
			local offset = math.sin(t + i * 0.3) * 3
			charLabel.Position = UDim2.new(0, charLabel.Position.X.Offset, 0.5, offset)
		end
	end)
	label.Destroying:Connect(function() RunService:UnbindFromRenderStep(id) end)
end

function syde:StopWiggle(label)
	for i, data in ipairs(self.Connections) do
		if data.label == label then data.conn:Disconnect() table.remove(self.Connections, i) break end
	end
end

function syde:updateLayout(container, spacing)
	spacing = spacing or 5
	local yOffset = 0
	for _, v in ipairs(container:GetChildren()) do
		if v:IsA('UIListLayout') then v:Destroy() end
	end
	if resizing == false then
		for _, child in ipairs(container:GetChildren()) do
			if (child:IsA("Frame") or child:IsA("ImageLabel") or child:IsA("TextLabel") or child:IsA("TextButton")) and child.Visible then
				tweenservice:Create(child, TweenInfo.new(0.45, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, 0, 0, yOffset)}):Play()
				yOffset = yOffset + child.AbsoluteSize.Y + spacing
			end
		end
	end
	container.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

local dragSpeed = 0.6
local LockToScreen = false

function syde:AddDrag(Object, Main, ConstrainToParent)
	assert(typeof(Object) == "Instance" and Object:IsA("GuiObject"))
	assert(typeof(Main) == "Instance" and Main:IsA("GuiObject"))
	local userInput = game:GetService("UserInputService")
	local dragging, startMousePos, startFramePos = false, nil, nil
	local function getConstrainedPosition(newPos)
		if not LockToScreen then return newPos end
		local screenSize = workspace.CurrentCamera.ViewportSize
		local frameSize = Main.AbsoluteSize
		local anchorPoint = Main.AnchorPoint
		local absX = newPos.X.Offset
		local absY = newPos.Y.Offset
		local minX = 0 + (frameSize.X * anchorPoint.X)
		local maxX = screenSize.X - (frameSize.X * (1 - anchorPoint.X))
		local minY = 0 + (frameSize.Y * anchorPoint.Y)
		local maxY = screenSize.Y - (frameSize.Y * (1 - anchorPoint.Y))
		return UDim2.new(0, math.clamp(absX, minX, maxX), 0, math.clamp(absY, minY, maxY))
	end
	local function getInputPos(input)
		if input.UserInputType == Enum.UserInputType.Touch then return Vector2.new(input.Position.X, input.Position.Y)
		else return userInput:GetMouseLocation() end
	end
	syde:AddConnection(Object.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			startMousePos = getInputPos(input)
			local screenSize = workspace.CurrentCamera.ViewportSize
			local absX = screenSize.X * Main.Position.X.Scale + Main.Position.X.Offset
			local absY = screenSize.Y * Main.Position.Y.Scale + Main.Position.Y.Offset
			Main.Position = UDim2.new(0, absX, 0, absY)
			startFramePos = Main.Position
		end
	end)
	syde:AddConnection(userInput.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local currentMousePos = getInputPos(input)
			if currentMousePos and startMousePos then
				local delta = currentMousePos - startMousePos
				local newPos = UDim2.new(startFramePos.X.Scale, startFramePos.X.Offset + delta.X, startFramePos.Y.Scale, startFramePos.Y.Offset + delta.Y)
				Main:TweenPosition(getConstrainedPosition(newPos), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, dragSpeed, true)
			end
		end
	end)
	syde:AddConnection(Object.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
end

function syde:HidePlaceHolder(instance, placeholder, recursive)
	if typeof(instance) ~= "Instance" or type(placeholder) ~= "string" then return end
	local target = instance:FindFirstChild(placeholder)
	if not target then return end
	if target:IsA("GuiObject") then target.Visible = false else return end
	if recursive then
		for _, child in ipairs(target:GetDescendants()) do
			if child:IsA("GuiObject") then child.Visible = false end
		end
	end
end

local rs
local ss
local mh = true

do
	function syde:Load(Config)
		task.wait(1)
		print('[SYED] Loader Loaded')
		local LOADER = Loader
		LOADER.Enabled = true
		LOADER.Parent = coregui
		Config.Name = Config.Name or 'Syde™'
		Config.Logo = Config.Logo or 'rbxassetid://14554547135'
		Config.ConfigFolder = Config.ConfigFolder or 'syde'
		Config.Status = Config.Status or false
		Config.Accent = Config.Accent or syde.theme.Accent
		Config.HitBox = Config.HitBox or syde.theme.HitBox
		do local _profileTitle = sydeLoaderProfileLabel(LOADER); if _profileTitle then _profileTitle.TextTransparency = 1 end end
		LOADER.loader.profile.ImageTransparency = 1
		do local _profileTitle = sydeLoaderProfileLabel(LOADER); if _profileTitle then _profileTitle.Text = Config.Name end end
		local LoaderConfig = {
			Name = Config.Name;
			Logo = 'rbxassetid://'..Config.Logo;
			ConfigFolder = Config.ConfigFolder;
			Status = Config.Status;
			Accent = Config.Accent or syde.theme.Accent;
			Hitbox = Config.HitBox or syde.theme.HitBox;
			Socials = {}
		}
		if LoaderConfig.Status == false then
			do local _profileTitle = sydeLoaderProfileLabel(LOADER); if _profileTitle then _profileTitle.Text = LoaderConfig.Name end end
		end
		local statusColors = {
			Stable = { Color = Color3.fromRGB(25, 229, 22), Text = '<font color="#24bf48">Stable</font>' },
			Unstable = { Color = Color3.fromRGB(227, 229, 81), Text = '<font color="#e3e551">Unstable</font>' },
			Detected = { Color = Color3.fromRGB(229, 44, 47), Text = '<font color="#e52c2f">Detected</font>' },
			Patched = { Color = Color3.fromRGB(229, 229, 229), Text = '<font color="#e52c2f">Patched</font>' }
		}
		local statusData = statusColors[LoaderConfig.Status]
		if statusData then LOADER.loader.profile.status.BackgroundColor3 = statusData.Color end
		LOADER.loader.profile.Image = LoaderConfig.Logo
		LOADER.loader.ImageLabel.Image = LoaderConfig.Logo
		local ti = TweenInfo.new(0.5, Enum.EasingStyle.Exponential)
		task.spawn(function()
			while LOADER and LOADER.Parent do
				task.wait()
				local loaderFrame = LOADER:FindFirstChild("loader")
				if not loaderFrame then break end
				local dots = loaderFrame:FindFirstChild("dots")
				if not dots then break end
				local function resetDots()
					for _, v in ipairs(dots:GetChildren()) do
						if v:IsA("Frame") then tweenservice:Create(v, ti, {BackgroundTransparency = 0.6}):Play() end
					end
				end
				if dots:FindFirstChild("dot1") then tweenservice:Create(dots.dot1, ti, {BackgroundTransparency = 0}):Play() end
				task.wait(0.5)
				resetDots()
				if dots:FindFirstChild("dot3") then tweenservice:Create(dots.dot3, ti, {BackgroundTransparency = 0}):Play() end
				task.wait(0.5)
				resetDots()
				if dots:FindFirstChild("dot2") then tweenservice:Create(dots.dot2, ti, {BackgroundTransparency = 0}):Play() end
				task.wait(0.5)
				resetDots()
			end
		end)
		local Styles = {
			GitHub = { BackGroundColor = Color3.fromRGB(39, 39, 39); StrokeColor = Color3.fromRGB(39, 39, 39); Icon = 'rbxassetid://112129825794851' },
			Discord = { BackGroundColor = Color3.fromRGB(88, 141, 255); StrokeColor = Color3.fromRGB(88, 141, 255); Icon = 'rbxassetid://113723018301753' },
			Site = { BackGroundColor = Color3.fromRGB(242, 83, 112); StrokeColor = Color3.fromRGB(242, 83, 112); Icon = 'rbxassetid://127485237503891' }
		}
		local logo = LOADER.loader.profile
		local Socials = Config.Socials or {}
		local maxSocials = 3
		local count = 0
		local SocialTemplate = LOADER.loader.profile.socials.s1
		for platform, value in pairs(Socials) do
			if count >= maxSocials then break end
			if not Styles[platform] then continue end
			if not SocialTemplate then break end
			count = count + 1
			local clone = SocialTemplate:Clone()
			clone.Visible = true
			clone.Name = platform .. "_Social"
			clone.Parent = SocialTemplate.Parent
			clone.BackgroundColor3 = Styles[platform].BackGroundColor
			clone.ImageLabel.Image = Styles[platform].Icon
			if clone.Frame:FindFirstChild("UIStroke") then clone.Frame.UIStroke.Color = Styles[platform].StrokeColor end
			if clone:FindFirstChild("Title") then clone.Title.Text = value end
			clone.interact.MouseButton1Click:Connect(function()
				if value ~= '' then
					tweenservice:Create(clone.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Color = Color3.fromRGB(74, 255, 33)}):Play()
					tweenservice:Create(clone.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Transparency = 0}):Play()
					task.wait(0.5)
					tweenservice:Create(clone.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Color = Styles[platform].BackGroundColor}):Play()
					tweenservice:Create(clone.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Transparency = 0.5}):Play()
				else
					tweenservice:Create(clone.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Color = Color3.fromRGB(255, 41, 45)}):Play()
					tweenservice:Create(clone.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Transparency = 0}):Play()
					task.wait(0.5)
					tweenservice:Create(clone.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Color = Styles[platform].BackGroundColor}):Play()
					tweenservice:Create(clone.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Transparency = 0.5}):Play()
				end
				setclipboard(value)
			end)
			clone.MouseEnter:Connect(function() tweenservice:Create(clone.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Transparency = 0.5}):Play() end)
			clone.MouseLeave:Connect(function() tweenservice:Create(clone.Frame.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Transparency = 0}):Play() end)
		end
		tweenservice:Create(logo, TweenInfo.new(1, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
		do local _logoTitle = sydeTitleLabel(logo); if _logoTitle then tweenservice:Create(_logoTitle, TweenInfo.new(2, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play() end end
		task.wait(1)
		local function TweenWorkLabel(Finish, icon, Text)
			LOADER.loader.work.Position = UDim2.new(0.5, 0,1, -40)
			LOADER.loader.work.Text = Text
			LOADER.loader.work.ImageLabel.Image = icon
			tweenservice:Create(LOADER.loader.work, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
			tweenservice:Create(LOADER.loader.work.ImageLabel, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
			tweenservice:Create(LOADER.loader.work, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5, 0,1, -73)}):Play()
			task.wait(Finish)
			tweenservice:Create(LOADER.loader.work, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
			tweenservice:Create(LOADER.loader.work.ImageLabel, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
			tweenservice:Create(LOADER.loader.work, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5, 0,1, -100)}):Play()
			task.wait(0.6)
		end
		local function load()
			TweenWorkLabel(1,'rbxassetid://136002400178503', '')
			if Config.ConfigurationSaving and Config.ConfigurationSaving.Enabled then
				local folderName = Config.ConfigurationSaving.FolderName or "SydeSec"
				local fileName = Config.ConfigurationSaving.FileName or "default_config"
				local fullPath = folderName .. "/" .. fileName .. ".lua"
				syde.ConfigEnabled = true
				syde.ConfigFolder = folderName
				syde.ConfigFile = fileName
				if isfolder and not isfolder(folderName) then
					pcall(function() makefolder(folderName) end)
				end
			end
			TweenWorkLabel(1,'rbxassetid://105810189969774', '')
			local UI_TAG = "sydeUILoader"
			local MARKER_NAME = "SYDEUIDetector"
			local INTERNAL_UUID = ("SYDE-" .. tostring(game.JobId):gsub("-", "") .. tostring(tick())):gsub("%.", "")
			local function deepCleanup()
				for _, v in ipairs(coregui:GetChildren()) do
					if v:IsA("ScreenGui") and v:FindFirstChild(MARKER_NAME) then
						pcall(function() v:Destroy() end)
					end
				end
			end
			deepCleanup()
			Library.Name = UI_TAG
			Library.ResetOnSpawn = false
			local marker = Instance.new("StringValue")
			marker.Name = MARKER_NAME
			marker.Value = INTERNAL_UUID
			marker.Parent = Library
			pcall(function() Library.Parent = coregui end)
			task.spawn(function()
				while Library and Library.Parent do
					task.wait(1)
					if Library.Parent ~= coregui then
						pcall(function() Library.Parent = coregui end)
					end
				end
			end)
			TweenWorkLabel(1,'rbxassetid://108012241529487', '')
			TweenWorkLabel(1,'rbxassetid://136405833725573', '')
			task.wait(1)
			loaded = true
		end
		task.wait(0.08)
		load()
		task.wait(2)
		syde.theme.Accent = Config.Accent
		syde.theme.HitBox = Config.HitBox
		LOADER:Destroy()
	end
end

local HttpService = https
local CONFIG_VERSION = 1
local SaveDebounce
local SAVE_DELAY = 0.2

local function SafeDecode(data)
	local success, result = pcall(function() return HttpService:JSONDecode(data) end)
	return success and result or nil
end

local function ApplyFlag(Flag, Value)
	if Value == nil then return false end
	if Flag.Type == "ColorPicker" then
		local unpacked = syde:ColorUnpack(Value)
		if Flag.Set then Flag:Set(unpacked) elseif Flag.Color then Flag.Color = unpacked end
		return true
	end
	if Flag.Set then Flag:Set(Value) return true end
	if Flag.V ~= nil then Flag.V = Value return true end
	if Flag.StarterValue ~= nil then Flag.StarterValue = Value return true end
	return false
end

function LoadConfig(Configuration)
	if type(Configuration) ~= "string" then return false end
	local Decoded = SafeDecode(Configuration)
	if not Decoded then return false end
	local changed = false
	for FlagName, Flag in pairs(syde.Flags) do
		local SavedValue = Decoded[FlagName]
		if SavedValue ~= nil then
			if ApplyFlag(Flag, SavedValue) then changed = true end
		end
	end
	return changed
end

local function PerformSave()
	if not syde.ConfigEnabled then return end
	if not writefile then return end
	local Data = { _version = CONFIG_VERSION }
	for FlagName, Flag in pairs(syde.Flags) do
		if Flag.Type == "ColorPicker" then Data[FlagName] = syde:ColorPack(Flag.Color)
		else Data[FlagName] = Flag.V ~= nil and Flag.V or Flag.Color or Flag.StarterValue or false end
	end
	if makefolder and not isfolder(syde.ConfigFolder) then makefolder(syde.ConfigFolder) end
	local path = string.format("%s/%s.json", syde.ConfigFolder, syde.ConfigFile)
	pcall(function() writefile(path, HttpService:JSONEncode(Data)) end)
end

function SaveConfig()
	if SaveDebounce then task.cancel(SaveDebounce) end
	SaveDebounce = task.delay(SAVE_DELAY, PerformSave)
end

local ui = Library
local window = ui.main
local top = window.top
local tabs = window.tabs.tab
local pages = window.pages

local settingsOpen = false
local uiclosed = false
local userinfodisabled = false
local bluron = false
local glow = false
local uitoggle = Enum.KeyCode.RightShift

function applyLayout(isMobile)
	if window then
		tweenservice:Create(window, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Size = isMobile and UDim2.new(0, 543,0, 321) or UDim2.new(0, 715, 0, 575)}):Play()
	end
	local shadow = window:FindFirstChild("Shadow")
	if shadow then shadow.Visible = not isMobile end
end
local function updateLayout()
	local screenSize = camera.ViewportSize
	local mobile = userinput.TouchEnabled
	applyLayout(mobile)
end

local notifications = {}
local notificationSpacing = 10
local tweenInfoN = TweenInfo.new(0.7, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
function updatePositions()
	local screenHeight = workspace.CurrentCamera.ViewportSize.Y - 200
	local currentY = screenHeight
	for i = #notifications, 1, -1 do
		local notif = notifications[i]
		tweenservice:Create(notif, tweenInfoN, { Position = UDim2.new(0, 250, 0, currentY - notif.Size.Y.Offset + 60) }):Play()
		currentY = currentY - (notif.Size.Y.Offset + notificationSpacing)
	end
end
for _, temp in ipairs(Library.Notification:GetChildren()) do
	if temp:IsA("Frame") then temp.Visible = false end
end

function syde:Notify(Notification)
	task.spawn(function()
		local NotifData = {
			Title = Notification.Title; Content = Notification.Content; Duration = Notification.Duration or 5;
			Icon = Notification.Icon or ''; Varient = Notification.Varient or 'Default'; Animation = Notification.Animation;
			ConfirmCallback = Notification.ConfirmCallback
		}
		local Notif = Library.Notification.Default:Clone()
		Notif.Visible = true
		Notif.Parent = Library.Notification
		Notif.Title.Text = NotifData.Title
		Notif.Content.Text = NotifData.Content
		Notif.Content.Size = UDim2.new(0, 200,0, Notif.Content.TextBounds.Y)
		Notif.icon.Image = 'rbxassetid://'..NotifData.Icon
		Notif.icon.Visible = true
		local function CloseNotif()
			if Notif and Notif.Parent then
				table.remove(notifications, table.find(notifications, Notif))
				tweenservice:Create(Notif.UIScale, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Scale = 0.9}):Play()
				tweenservice:Create(Notif.close, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0.95}):Play()
				tweenservice:Create(Notif, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.75}):Play()
				tweenservice:Create(Notif.Content, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0.78}):Play()
				task.wait(0.15)
				tweenservice:Create(Notif, TweenInfo.new(0.95, Enum.EasingStyle.Exponential), {Position = UDim2.new(0, Notif.Position.X.Offset + 400, 0, Notif.Position.Y.Offset)}):Play()
				task.wait(0.4)
				Notif:Destroy()
				updatePositions()
			end
		end
		if NotifData.Animation == 'Wiggle' then syde:WiggleText(Notif.Title) end
		if NotifData.Varient == 'Options' then
			Notif.Block.Visible = true
			Notif.Size = UDim2.new(1, 0,0, Notif.Content.TextBounds.Y + 80)
			Notif.Block.Cancel.MouseButton1Click:Connect(function() CloseNotif() end)
			Notif.Block.Confirm.MouseButton1Click:Connect(function()
				if NotifData.ConfirmCallback then NotifData.ConfirmCallback() CloseNotif() end
			end)
		else
			Notif.Size = UDim2.new(1, 0,0, Notif.Content.TextBounds.Y + 45)
		end
		table.insert(notifications, Notif)
		updatePositions()
		Notif.close.ImageTransparency = 0.95
		Notif.BackgroundTransparency = 0.75
		Notif.Content.TextTransparency = 0.78
		Notif.Position = UDim2.new(0, 600, 0, 637)
		task.wait(0.45)
		if NotifData.Icon ~= '' then
			tweenservice:Create(Notif.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 40,0, 10)}):Play()
			task.wait(0.035)
			tweenservice:Create(Notif.Content, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 40,0, 30)}):Play()
			tweenservice:Create(Notif.icon, TweenInfo.new(1, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
		end
		tweenservice:Create(Notif.UIScale, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Scale = 1}):Play()
		tweenservice:Create(Notif.close, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0.75}):Play()
		tweenservice:Create(Notif, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
		tweenservice:Create(Notif.Content, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
		Notif.close.MouseEnter:Connect(function() tweenservice:Create(Notif.close, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0.25}):Play() end)
		Notif.close.MouseLeave:Connect(function() tweenservice:Create(Notif.close, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0.75}):Play() end)
		Notif.close.MouseButton1Click:Connect(function() CloseNotif() end)
		task.delay(NotifData.Duration, function() CloseNotif() end)
	end)
end

local activeModals = 0
function syde:Modal(Modal)
	task.spawn(function()
		local ModalData = {
			Title = Modal.Title;
			Content = Modal.Content;
			ConfirmCallBack = Modal.ConfimCallBack
		}

		local modalTemplate = window and sydeFindChild(window, "modal", "Modal")
		local ModalInstance = modalTemplate and modalTemplate:Clone()
		if not ModalInstance or not window then
			return
		end
		sydeSanitizeUiClone(ModalInstance)
		ModalInstance.Visible = true
		ModalInstance.Parent = window
		local modalParts = sydeResolveModal(ModalInstance)
		local dimOverlay = window and sydeFindChild(window, "dim", "Dim")
		if modalParts.Title then
			modalParts.Title.Text = ModalData.Title
			modalParts.Title.TextTransparency = 1
		end
		if modalParts.Content then
			modalParts.Content.Text = ModalData.Content
			modalParts.Content.TextTransparency = 1
		end
		ModalInstance.Size = UDim2.new(0, 350, 0, 144)
		ModalInstance.BackgroundTransparency = 1
		if modalParts.Confirm then
			modalParts.Confirm.BackgroundTransparency = 1
		end
		if modalParts.ConfirmLabel then
			modalParts.ConfirmLabel.TextTransparency = 1
		end
		if modalParts.Cancel then
			modalParts.Cancel.BackgroundTransparency = 1
		end
		if modalParts.CancelLabel then
			modalParts.CancelLabel.TextTransparency = 1
		end
		if modalParts.CancelStroke then
			modalParts.CancelStroke.Transparency = 1
		end

		local function openModal()
			if modalParts.Content then
				tweenservice:Create(
					modalParts.Content,
					TweenInfo.new(0.35, Enum.EasingStyle.Quint),
					{ Size = UDim2.new(1, modalParts.Content.Size.X.Offset, 1, modalParts.Content.TextBounds.Y) }
				):Play()
			end
			activeModals += 1
			local contentHeight = modalParts.Content and modalParts.Content.TextBounds.Y or 0
			tweenservice:Create(
				ModalInstance,
				TweenInfo.new(0.32, Enum.EasingStyle.Quint),
				{ Size = UDim2.new(0, 350, 0, contentHeight + 150) }
			):Play()
			tweenservice:Create(ModalInstance, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { BackgroundTransparency = 0 }):Play()
			if modalParts.UIStroke then
				tweenservice:Create(modalParts.UIStroke, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { Transparency = 0 }):Play()
			end
			if modalParts.Title then
				tweenservice:Create(modalParts.Title, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			end
			if modalParts.Content then
				tweenservice:Create(modalParts.Content, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			end
			if modalParts.Confirm then
				tweenservice:Create(modalParts.Confirm, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { BackgroundTransparency = 0.5 }):Play()
			end
			if modalParts.ConfirmLabel then
				tweenservice:Create(modalParts.ConfirmLabel, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			end
			if modalParts.Cancel then
				tweenservice:Create(modalParts.Cancel, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { BackgroundTransparency = 1 }):Play()
			end
			if modalParts.CancelLabel then
				tweenservice:Create(modalParts.CancelLabel, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			end
			if modalParts.CancelStroke then
				tweenservice:Create(modalParts.CancelStroke, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { Transparency = 0 }):Play()
			end
		end
		openModal()

		local function closeModal()
			activeModals -= 1
			sydeSetInteractable(modalParts.Cancel, false)
			sydeSetInteractable(modalParts.Confirm, false)
			tweenservice:Create(ModalInstance, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Size = UDim2.new(0, 350, 0, 147) }):Play()
			tweenservice:Create(ModalInstance, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), { BackgroundTransparency = 1 }):Play()
			if modalParts.Title then
				tweenservice:Create(modalParts.Title, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), { TextTransparency = 1 }):Play()
			end
			if modalParts.UIStroke then
				tweenservice:Create(modalParts.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), { Transparency = 1 }):Play()
			end
			if modalParts.Content then
				tweenservice:Create(modalParts.Content, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), { TextTransparency = 1 }):Play()
			end
			if modalParts.Confirm then
				tweenservice:Create(modalParts.Confirm, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), { BackgroundTransparency = 1 }):Play()
			end
			if modalParts.ConfirmLabel then
				tweenservice:Create(modalParts.ConfirmLabel, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), { TextTransparency = 1 }):Play()
			end
			if modalParts.Cancel then
				tweenservice:Create(modalParts.Cancel, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), { BackgroundTransparency = 1 }):Play()
			end
			if modalParts.CancelLabel then
				tweenservice:Create(modalParts.CancelLabel, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), { TextTransparency = 1 }):Play()
			end
			if modalParts.CancelStroke then
				tweenservice:Create(modalParts.CancelStroke, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), { Transparency = 1 }):Play()
			end
			task.wait(0.22)
			ModalInstance:Destroy()
		end



		if activeModals == 1 and dimOverlay then
			dimOverlay.Visible = true
			tweenservice:Create(dimOverlay, TweenInfo.new(0.32, Enum.EasingStyle.Exponential), {
				BackgroundTransparency = 0.3
			}):Play()
		end

		sydeConnectClick(modalParts.Confirm, function()
			if typeof(ModalData.ConfirmCallBack) == "function" then
				ModalData.ConfirmCallBack()
			end

			closeModal()

			if activeModals == 0 and dimOverlay then
				tweenservice:Create(dimOverlay, TweenInfo.new(0.32, Enum.EasingStyle.Exponential), {
					BackgroundTransparency = 1
				}):Play()
				task.wait(0.25)
				dimOverlay.Visible = false
			end
		end)

		sydeConnectClick(modalParts.Cancel, function()
			closeModal()
			if dimOverlay then
				tweenservice:Create(dimOverlay, TweenInfo.new(0.32, Enum.EasingStyle.Exponential), {
					BackgroundTransparency = 1
				}):Play()
				task.wait(0.25)
				dimOverlay.Visible = false
			end
		end)

	end)
end

local toasts = {}
local toastSpacing = 8
local tweenInfoT = TweenInfo.new(0.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local function updateToastPositions()
	local startY = 10
	local currentY = startY
	for i = 1, #toasts do
		local toast = toasts[i]
		if toast and toast.Parent then
			tweenservice:Create(toast, tweenInfoT, {Position = UDim2.new(0.5, 0, 0, currentY)}):Play()
			currentY = currentY + toast.Size.Y.Offset + toastSpacing
		end
	end
end
function syde:Toast(Toasty)
	task.spawn(function()
		local Data = { Content = Toasty.Content or "", Duration = Toasty.Duration or 5, Icon = Toasty.Icon or "" }
		local Toast = ui.toastholder.toast:Clone()
		Toast.Visible = true
		Toast.Parent = ui.toastholder
		Toast.AnchorPoint = Vector2.new(0.5, 0)
		Toast.Content.Text = Data.Content
		Toast.Size = UDim2.new(1, Toast.Content.TextBounds.X - 140,0, 40)
		if Data.Icon ~= "" then Toast.icon.ImageLabel.Image = "rbxassetid://" .. Data.Icon Toast.icon.ImageLabel.ImageTransparency = 0 end
		Toast.Position = UDim2.new(0.5, 0, 0, -Toast.Size.Y.Offset - 20)
		table.insert(toasts, 1, Toast)
		updateToastPositions()
		task.delay(Data.Duration, function()
			if not Toast or not Toast.Parent then return end
			table.remove(toasts, table.find(toasts, Toast))
			tweenservice:Create(Toast, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Position = Toast.Position - UDim2.fromOffset(0, 30), BackgroundTransparency = 1}):Play()
			for _, v in ipairs(Toast:GetDescendants()) do
				if v:IsA("TextLabel") then tweenservice:Create(v, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
				elseif v:IsA("ImageLabel") then tweenservice:Create(v, TweenInfo.new(0.3), {ImageTransparency = 1}):Play()
				elseif v:IsA("Frame") then tweenservice:Create(v, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play() end
			end
			task.wait(0.35)
			Toast:Destroy()
			updateToastPositions()
		end)
	end)
end

function SetUserInfo()
	local LocalPlayer = player.LocalPlayer
	local PLACEHOLDER_IMAGE = "rbxassetid://0"
	local imageLabel = window:WaitForChild("user"):WaitForChild("headshot")
	imageLabel.Image = PLACEHOLDER_IMAGE
	local success, thumbnail = pcall(function()
		return player:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	end)
	if success and thumbnail then
		imageLabel.Image = thumbnail
		window.user.headshot.id.username.Text = LocalPlayer.Name
		window.user.headshot.id.displayname.Text = "@"..LocalPlayer.DisplayName
	else
		imageLabel.Image = PLACEHOLDER_IMAGE
	end
end

local searchopen = false
function opensearch()
	searchopen = true
	window.dim.Visible = true
	window.search.Visible = true
	window.search.Container.Visible = true
	if window.search.Frame.TextBox.Text ~= '' then
		tweenservice:Create(window.search, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 350,0, 230)}):Play()
	else
		tweenservice:Create(window.search, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 350,0, 60)}):Play()
	end
	tweenservice:Create(window.dim, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.45}):Play()
	tweenservice:Create(window.search, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
	tweenservice:Create(window.search.Frame.ImageLabel, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
	tweenservice:Create(window.search.close, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
	tweenservice:Create(window.search.close.ImageLabel, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
	tweenservice:Create(window.search.Frame.TextBox, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
end
function closesearch()
	searchopen = false
	window.search.Container.Visible = false
	tweenservice:Create(window.search, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 350,0, 60)}):Play()
	tweenservice:Create(window.dim, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
	tweenservice:Create(window.search, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
	tweenservice:Create(window.search.Frame.ImageLabel, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
	tweenservice:Create(window.search.close, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
	tweenservice:Create(window.search.close.ImageLabel, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
	tweenservice:Create(window.search.Frame.TextBox, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
	task.wait(0.5)
	window.dim.Visible = false
	window.search.Visible = false
end

function openui()
	window.pages.Visible = true
	window.tabs.Visible = true
	window.user.Visible = true
	window.Visible = true
	uiclosed = false
	if bluron then
		syde:BindFrame(window, {Transparency = 0.98; BrickColor = BrickColor.new('Institutional white')})
		tweenservice:Create(window, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.45}):Play()
	else
		tweenservice:Create(window, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
	end
	tweenservice:Create(window, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 700,0, 560)}):Play()
	tweenservice:Create(window.top.separator, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
	tweenservice:Create(window.top.title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	tweenservice:Create(window.top.title.sub, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
	tweenservice:Create(window.top.functions, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
	if window.wallpaper.ison.Value then
		tweenservice:Create(window.wallpaper, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 0.84}):Play()
	end
	for i,v in pairs(window.top.functions:GetChildren()) do
		if v:IsA("Frame") then
			tweenservice:Create(v, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.8}):Play()
			v.Visible = true
			for i,v2 in pairs(v:GetChildren()) do
				if v2:IsA("ImageLabel") then
					tweenservice:Create(v2, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
					v2.Visible = true
				end
			end
			if v:FindFirstChild("rainbow") then tweenservice:Create(v.rainbow, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play() end
		end
	end
	tweenservice:Create(window.shadow.ImageLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 0.5}):Play()
	tweenservice:Create(window.resize, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 0.3}):Play()
	if glow == true then
		for i, glow in pairs(window.clipframe:GetChildren()) do
			if glow:IsA("ImageLabel") then tweenservice:Create(glow, TweenInfo.new(0.5, Enum.EasingStyle.Exponential),{ImageTransparency = 0.8}):Play() end
		end
		tweenservice:Create(window.shadow.glow, TweenInfo.new(0.5, Enum.EasingStyle.Exponential),{ImageTransparency = 0.9}):Play()
		tweenservice:Create(window.shadow.glow1, TweenInfo.new(0.5, Enum.EasingStyle.Exponential),{ImageTransparency = 0.9}):Play()
	end
end

function closeui()
	pages.Visible = false
	window.tabs.Visible = false
	window.user.Visible = false
	tweenservice:Create(window, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
	tweenservice:Create(window, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Size = UDim2.new(window.Size.X.Scale, window.Size.X.Offset, window.Size.Y.Scale, 200)}):Play()
	tweenservice:Create(window.top.separator, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
	tweenservice:Create(window.top.title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
	tweenservice:Create(window.top.title.sub, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
	if window.wallpaper.ison.Value then tweenservice:Create(window.wallpaper, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play() end
	syde:UnbindFrame(window)
	tweenservice:Create(window.top.functions, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
	for i,v in pairs(window.top.functions:GetChildren()) do
		if v:IsA("Frame") then
			tweenservice:Create(v, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
			v.Visible = false
			for i,v2 in pairs(v:GetChildren()) do
				if v2:IsA("ImageLabel") then
					tweenservice:Create(v2, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
					v2.Visible = false
				end
			end
		end
	end
	for i, glow in pairs(window.clipframe:GetChildren()) do
		if glow:IsA("ImageLabel") then tweenservice:Create(glow, TweenInfo.new(0.5, Enum.EasingStyle.Exponential),{ImageTransparency = 1}):Play() end
	end
	tweenservice:Create(window.shadow.glow, TweenInfo.new(0.5, Enum.EasingStyle.Exponential),{ImageTransparency = 1}):Play()
	tweenservice:Create(window.shadow.glow1, TweenInfo.new(0.5, Enum.EasingStyle.Exponential),{ImageTransparency = 1}):Play()
	tweenservice:Create(window.shadow.ImageLabel, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
	tweenservice:Create(window.resize, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
	closesettings()
	closesearch()
	settingsOpen = false
	window.Visible = false
	uiclosed = true
	syde:Toast({Content = 'UI Hidden, Use '.. uitoggle.Name ..' To Open Back.', Duration = 2})
end

local bounce = false
function ToggleUI()
	if bounce then return end
	bounce = true
	if uiclosed then
		openui()
		updateLayout()
	else
		closeui()
	end
	task.delay(0.2, function() bounce = false end)
end

window.top.functions.close.interact.MouseButton1Click:Connect(function()
	syde:Modal({
		Title = 'Please Confirm Below.',
		Content = 'Are You Sure You Want To Close This UI?',
		ConfimCallBack = function()
			mh = false
			pcall(function() if rs and typeof(rs.Disconnect) == 'function' then rs:Disconnect() end end)
			pcall(function() if ss and typeof(ss.Disconnect) == 'function' then ss:Disconnect() end end)
			task.wait(1)
			Library:Destroy()
		end,
	})
end)

syde:HidePH(tabs, 'btn')
syde:HidePH(pages, 'page')

function syde:Init(library)
	ui.Enabled = true
	-- CSS engine — intercept all cosmetic Tweens, set CSSTransition on element
	local origTweenCreate = tweenservice.Create
	tweenservice.Create = function(self, el, info, props)
		if props and el and el:IsA("GuiObject") then
			local hasCosmetic = false
			for k, _ in pairs(props) do
				if k == "BackgroundTransparency" or k == "TextTransparency" or k == "ImageTransparency"
					or k == "BackgroundColor3" or k == "TextColor3" or k == "ImageColor3" or k == "BorderColor3" then
					hasCosmetic = true
				end
			end
			if hasCosmetic then el:SetAttribute("CSSTransition", info and info.Time or 0.3) end
		end
		return origTweenCreate(tweenservice, el, info, props)
	end
	if loaded == false then
		local UI_TAG = "sydeUILoader"
		local MARKER_NAME = "SYDEUIDetector"
		local INTERNAL_UUID = ("SYDE-" .. tostring(game.JobId):gsub("-", "") .. tostring(tick())):gsub("%.", "")
		local function deepCleanup()
			for _, v in ipairs(coregui:GetChildren()) do
				if v:IsA("ScreenGui") and v:FindFirstChild(MARKER_NAME) then
					pcall(function() v:Destroy() end)
				end
			end
		end
		deepCleanup()
		Library.Name = UI_TAG
		Library.ResetOnSpawn = false
		local marker = Instance.new("StringValue")
		marker.Name = MARKER_NAME
		marker.Value = INTERNAL_UUID
		marker.Parent = Library
		pcall(function() Library.Parent = coregui end)
		task.spawn(function()
			while Library and Library.Parent do
				task.wait(1)
				if Library.Parent ~= coregui then
					pcall(function() Library.Parent = coregui end)
				end
			end
		end)
	end
	task.wait(0.1)
	local Data = { Title = library.Title or "Syde"; SubText = library.SubText or "Google"; Home = library.Home or {} }
	Data.Home.Enabled = (Data.Home.Enabled == true)
	Data.Home.hTitle = Data.Home.hTitle or Data.Title
	Data.Home.hSubText = Data.Home.hSubText or Data.SubText
	Data.Home.profileImage = Data.Home.profileImage or Data.profileImage
	local Minihome = ui.minihome
	local MinihomeData = { QuickActions = library.QuickActions or false }
	local lastTime = tick()
	local frames = 0
	if mh then
		rs = RunService.RenderStepped:Connect(function()
			frames = frames + 1
			local now = tick()
			if now - lastTime >= 1 then
				local fps = math.floor(frames / (now - lastTime))
				lastTime = now
				frames = 0
				Minihome.info.fps.Text = fps .. " FPS"
			end
			local hour = tonumber(os.date("%I"))
			Minihome.info.time.Text = hour .. os.date(":%M")
		end)
		if MinihomeData.QuickActions == false then
			ui.minihome.quick.Visible = false
			ui.minihome:TweenSize(UDim2.new(0, 150, 0, 40), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.8, true)
		end
	end
	if not uiclosed then
		ui.minihome.open.quickfunc.interact.MouseButton1Click:Connect(function() ToggleUI() end)
	end
	top.title.Text = Data.Title
	top.title.sub.Text = Data.SubText
	syde:AddDrag(top, window, true)
	syde:MakeResizable(window.resize, window, Vector2.new(454, 228))
	top.title.TextTransparency = 1
	top.title.sub.TextTransparency = 1
	tweenservice:Create(top.title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
	tweenservice:Create(top.title.sub, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
	task.spawn(function()
		task.wait(0.5)
		local titleTween = tweenservice:Create(top.title, TweenInfo.new(1.65, Enum.EasingStyle.Exponential), {TextTransparency = 0})
		titleTween:Play()
		task.wait(0.1)
		local subTitleTween = tweenservice:Create(top.title.sub, TweenInfo.new(1.65, Enum.EasingStyle.Exponential), {TextTransparency = 0})
		subTitleTween:Play()
		task.wait()
		local textSize = top.title.TextBounds.X + 3
		tweenservice:Create(top.title, TweenInfo.new(1.55, Enum.EasingStyle.Quint), {Size = UDim2.new(0, textSize, 0, 20)}):Play()
	end)
	local RainbowStates = {}
	for _, v in ipairs(top.functions:GetChildren()) do
		if not v:IsA("Frame") then continue end
		if not v:FindFirstChild("ImageLabel") then continue end
		local image = v.ImageLabel
		local rain, gradient
		if v.Name == "plugins" then rain = v.rainbow gradient = rain:FindFirstChildOfClass("UIGradient") end
		if v.Name == "plugins" then RainbowStates[v] = { hue = math.random(), connection = nil } end
		v.MouseEnter:Connect(function()
			if not uiclosed then
				if v.Name ~= "plugins" then
					tweenservice:Create(image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0.7}):Play()
				end
			end
			if v.Name == "plugins" and gradient then
				tweenservice:Create(v.rainbow, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
				local state = RainbowStates[v]
				if state.connection then return end
				state.connection = RunService.RenderStepped:Connect(function(dt)
					state.hue = (state.hue + dt * 0.6) % 1
					gradient.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(state.hue, 1, 1)),
						ColorSequenceKeypoint.new(0.2, Color3.fromHSV((state.hue + 0.2) % 1, 1, 1)),
						ColorSequenceKeypoint.new(0.4, Color3.fromHSV((state.hue + 0.4) % 1, 1, 1)),
						ColorSequenceKeypoint.new(0.6, Color3.fromHSV((state.hue + 0.6) % 1, 1, 1)),
						ColorSequenceKeypoint.new(0.8, Color3.fromHSV((state.hue + 0.8) % 1, 1, 1)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV((state.hue + 1) % 1, 1, 1)),
					})
				end)
			end
		end)
		v.MouseLeave:Connect(function()
			if not uiclosed then
				if v.Name ~= "plugins" then
					tweenservice:Create(image, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
				end
			end
			if v.Name == "plugins" then
				tweenservice:Create(v.rainbow, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
				local state = RainbowStates[v]
				if state and state.connection then state.connection:Disconnect() state.connection = nil end
			end
		end)
	end
	window.search.close.interact.MouseButton1Click:Connect(function() closesearch() end)
	local debounce = false
	local DEBOUNCE_TIME = 0.1
	top.functions.search.interact.MouseButton1Click:Connect(function()
		if debounce then return end
		debounce = true
		if not searchopen then opensearch() else closesearch() end
		task.delay(DEBOUNCE_TIME, function() debounce = false end)
	end)
	syde:AddConnection(syde.Comms.Event, function(p, value)
		if p == "Accent" then
			for i, glow in pairs(window.clipframe:GetChildren()) do
				if glow:IsA("ImageLabel") then tweenservice:Create(glow, TweenInfo.new(0.5, Enum.EasingStyle.Exponential),{ImageColor3 = value}):Play() end
			end
			tweenservice:Create(window.shadow.glow, TweenInfo.new(0.5, Enum.EasingStyle.Exponential),{ImageColor3 = value}):Play()
			tweenservice:Create(window.shadow.glow1, TweenInfo.new(0.5, Enum.EasingStyle.Exponential),{ImageColor3 = value}):Play()
		end
	end)
	SetUserInfo()
	tweenservice:Create(window.user.headshot.id.username, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Size = UDim2.new(0, window.user.headshot.id.username.TextBounds.X + 10,0, 10)}):Play()
	if userinfodisabled == false then
		tweenservice:Create(window.tabs, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 200,1, -115)}):Play()
	else
		tweenservice:Create(window.tabs, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, 200,1, -75)}):Play()
	end
	if Data.Home.Enabled then
		window.pages.home.general.presence.Profile.ImageLabel.Text.Header.Text = Data.Home.hTitle
		window.pages.home.general.presence.Profile.ImageLabel.Text.Sub.Text = Data.Home.hSubText
		window.pages.home.general.presence.Profile.ImageLabel.Image = 'rbxassetid://'..Data.Home.profileImage
		window.pages.home.general.presence.wallpaper.Image = 'rbxassetid://'..Data.Home.profileImage
		local placeId = game.PlaceId
		window.pages.home.general.presence.PlaceID.Text = "Place ID: "..placeId
		local layout = Bento.new(window.pages.home.general.Quick,{Gap = 6, RightPadding = 20, TweenTime = 0.35})
		local row1 = layout:NewRow()
		local row2 = layout:NewRow()
		local row3 = layout:NewRow()
		layout:AddItem(window.pages.home.general.Quick.QuickPlay,nil,row1)
		layout:AddItem(window.pages.home.general.Quick.Player,nil,row1)
		layout:AddItem(window.pages.home.general.Quick.Latency,nil,row3)
		layout:AddItem(window.pages.home.general.Quick.QuickSettings,{Bottom = true},row2)
		layout:Bind()
		layout:Update()
		local bh = window.pages.home.general.Quick.QuickSettings.QuickButtons.holder
		for i,v in ipairs(bh:GetChildren()) do
			if v:IsA('Frame') then
				v.MouseEnter:Connect(function() tweenservice:Create(v.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 0}):Play() end)
				v.MouseLeave:Connect(function() tweenservice:Create(v.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {Transparency = 1}):Play() end)
			end
		end
		bh.Leave.interact.MouseButton1Click:Connect(function() game:GetService("Players").LocalPlayer:Kick("Left the experience") end)
		bh.Rejoin.interact.MouseButton1Click:Connect(function()
			local TeleportService = game:GetService("TeleportService")
			TeleportService:Teleport(game.PlaceId, game:GetService("Players").LocalPlayer)
		end)
		local QuickPlay = window.pages.home.general.Quick.QuickPlay
		local lastGamePlFile = syde.ConfigFolder .. "/last_game.json"
		local function LoadLastGame()
			if not syde.ConfigEnabled then return nil end
			if not isfile(lastGamePlFile) then return nil end
			local success, result = pcall(function() return HttpService:JSONDecode(readfile(lastGamePlFile)) end)
			if success then return result end
		end
		local lastGame = LoadLastGame()
		local resumePlaceId = game.PlaceId
		if lastGame and lastGame.PlaceId then resumePlaceId = lastGame.PlaceId end
		local success, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfoAsync(resumePlaceId, Enum.InfoType.Asset) end)
		if success and info then
			QuickPlay.gtitle.Text = info.Name
			QuickPlay.thumb.Image = "https://www.roblox.com/asset-thumbnail/image?assetId="..resumePlaceId.."&width=768&height=432&format=png"
		end
		QuickPlay.Resume.interact.MouseButton1Click:Connect(function()
			local lastGame = LoadLastGame()
			if lastGame and lastGame.PlaceId then
				game:GetService("TeleportService"):Teleport(resumePlaceId)
			end
		end)
	else
		window.pages.home.Visible = false
		window.tabs.Home.homeicon.interact.Interactable = false
	end

	function opensettings()
		window.settings.Visible = true
		window.dim.Visible = true
		tweenservice:Create(window.settings, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 360,0, 400)}):Play()
		tweenservice:Create(window.dim, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0.2}):Play()
		tweenservice:Create(window.settings, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
		window.settings.pages.Visible = true
		window.settings.tabs.Visible = true
		tweenservice:Create(window.settings.top.title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
		tweenservice:Create(window.settings.top.separator, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
		tweenservice:Create(window.settings.top.functions.close, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
		tweenservice:Create(window.settings.top.functions.close.ImageLabel, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
	end

	function closesettings()
		tweenservice:Create(window.settings, TweenInfo.new(0.35, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 360,0, 150)}):Play()
		tweenservice:Create(window.dim, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
		tweenservice:Create(window.settings, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
		window.settings.pages.Visible = false
		window.settings.tabs.Visible = false
		tweenservice:Create(window.settings.top.title, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
		tweenservice:Create(window.settings.top.separator, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
		tweenservice:Create(window.settings.top.functions.close, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
		tweenservice:Create(window.settings.top.functions.close.ImageLabel, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
		task.wait(0.6)
		window.settings.Visible = false
		window.dim.Visible = false
	end

	if not settingsOpen then closesettings() end
	window.top.functions.settings.interact.MouseButton1Click:Connect(function()
		if not settingsOpen then settingsOpen = true opensettings() end
	end)
	window.settings.top.functions.close.interact.MouseButton1Click:Connect(function()
		if settingsOpen then settingsOpen = false closesettings() end
	end)
	window.top.functions.mini.interact.MouseButton1Click:Connect(function()
		if not uiclosed then ToggleUI() end
	end)

	do -- Settings
		local settings = {}
		local tbdataS = { first = false, selected = false }
		function settings:inittab(tab)
			local telement = {}
			local tdata = { Title = tab.Title }
			local tabsContainer = window.settings.tabs.ScrollingFrame
			local pagesContainer = window.settings.pages
			local Tab = tabsContainer.tb:Clone()
			Tab.Visible = true
			Tab.Parent = tabsContainer
			Tab.Name = tdata.Title
			Tab.title.Text = tdata.Title
			local Page = pagesContainer.page:Clone()
			Page.Visible = false
			Page.Parent = pagesContainer
			Page.Name = tdata.Title
			for _, v in ipairs(Page:GetChildren()) do
				if v:IsA("Frame") then v:Destroy() end
			end
			local bgTween = TweenInfo.new(0.4, Enum.EasingStyle.Exponential)
			local textTween = TweenInfo.new(0.25, Enum.EasingStyle.Exponential)
			local function ApplyTabStyle(tabButton, selected)
				tweenservice:Create(tabButton, bgTween, {BackgroundColor3 = selected and Color3.fromRGB(31, 31, 31) or Color3.fromRGB(16, 16, 16)}):Play()
				tweenservice:Create(tabButton.title, textTween, {TextTransparency = selected and 0 or 0.6}):Play()
			end
			if not tbdataS.selectedTab then tbdataS.selectedTab = Tab Page.Visible = true ApplyTabStyle(Tab, true) else ApplyTabStyle(Tab, false) end
			Tab.interact.MouseButton1Click:Connect(function()
				if tbdataS.selectedTab == Tab then return end
				for _, p in ipairs(pagesContainer:GetChildren()) do if p:IsA("ScrollingFrame") then p.Visible = false end end
				for _, t in ipairs(tabsContainer:GetChildren()) do if t:IsA("Frame") then ApplyTabStyle(t, t == Tab) end end
				Page.Visible = true
				tbdataS.selectedTab = Tab
			end)

			function telement:Button(Button)
				local data = {Title = Button.Title or "Temp Button"; CallBack = Button.CallBack; Desc = Button.Description or ""; Type = Button.Type or 'Default'; HoldTime = Button.HoldTime or 3}
				local button = window.settings.pages.page.Button:Clone()
				button.Visible = true
				button.Parent = Page
				button.title.Text = data.Title
				button.Name = data.Title
				button.title.Size = UDim2.new(0, button.title.TextBounds.X + 15,0, 35)
				local c = data.CallBack
				local fOTween = TweenInfo.new(0.7, Enum.EasingStyle.Exponential)
				local fITween = TweenInfo.new(0.7, Enum.EasingStyle.Exponential)
				if data.Type == 'Default' then
					button.interact.MouseButton1Down:Connect(function()
						tweenservice:Create(button.UIStroke, fOTween, {Transparency = 1}):Play()
						tweenservice:Create(button.ImageLabel, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
					end)
					button.interact.MouseButton1Up:Connect(function()
						tweenservice:Create(button.UIStroke, fITween, {Transparency = 0}):Play()
						tweenservice:Create(button.ImageLabel, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {ImageTransparency = 0.95}):Play()
					end)
					button.interact.MouseButton1Click:Connect(function()
						if data.CallBack then pcall(c) end
					end)
					button.interact.MouseLeave:Connect(function()
						tweenservice:Create(button.UIStroke, fITween, {Transparency = 0}):Play()
						tweenservice:Create(button.ImageLabel, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {ImageTransparency = 0.95}):Play()
					end)
				elseif data.Type == 'Hold' then
					local HoldTime = data.HoldTime
					local Holding = false
					local TimeLeft = HoldTime
					local Complete = false
					button.ImageLabel.Image = 'rbxassetid://127075195365098'
					button.ImageLabel.Size = UDim2.new(0, 16,0, 16)
					button.ImageLabel.Position = UDim2.new(1, -41,0.5, 0)
					local function CancelOperation()
						Holding = false
						tweenservice:Create(button.ImageLabel, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {ImageTransparency = 0.95}):Play()
						tweenservice:Create(button.title.timer, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
						if not Complete then
							tweenservice:Create(button.UIStroke, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
							tweenservice:Create(button.UIStroke.UIGradient, TweenInfo.new(1, Enum.EasingStyle.Linear), {Offset = Vector2.new(-1, 0)}):Play()
							tweenservice:Create(button, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(0,-15,0,button.Position.Y.Offset)}):Play()
							task.wait(0.15)
							tweenservice:Create(button, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(0,30,0,button.Position.Y.Offset)}):Play()
							task.wait(0.15)
							tweenservice:Create(button, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {Position = UDim2.new(0,0,0,button.Position.Y.Offset)}):Play()
							task.wait(1)
							tweenservice:Create(button.UIStroke, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
						end
						TimeLeft = HoldTime
						button.title.timer.Text = tostring(HoldTime)
						task.wait(0.1)
						Complete = false
					end
					button.interact.MouseButton1Down:Connect(function()
						Holding = true
						TimeLeft = HoldTime
						button.title.timer.Text = tostring(TimeLeft)
						tweenservice:Create(button.ImageLabel, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
						tweenservice:Create(button.title.timer, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
						tweenservice:Create(button.UIStroke.UIGradient, TweenInfo.new(HoldTime, Enum.EasingStyle.Linear), {Offset = Vector2.new(0.7, 0)}):Play()
						tweenservice:Create(button.UIStroke, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Transparency = 0}):Play()
						while Holding and TimeLeft > 0 do
							TimeLeft = math.max(0, TimeLeft - runservice.Heartbeat:Wait())
							button.title.timer.Text = string.format("%.1f", TimeLeft)
						end
						if TimeLeft <= 0 then
							Complete = true
							if data.CallBack then pcall(data.CallBack) end
							tweenservice:Create(button, TweenInfo.new(0.34, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(24, 24, 24)}):Play()
							task.wait(0.34)
							tweenservice:Create(button, TweenInfo.new(0.34, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(17, 17, 17)}):Play()
						end
					end)
					button.interact.MouseButton1Up:Connect(function() CancelOperation() end)
					button.interact.MouseLeave:Connect(function() if Holding then CancelOperation() end end)
				end
			end

			function telement:Toggle(Toggle)
				local data = {Title = Toggle.Title or "Temp Toggle"; Desc = Toggle.Description or ""; V = Toggle.Value or false; Config = Toggle.Config or false; CallBack = Toggle.CallBack; SFlag = Toggle.SFlag; SettingsConfig = true}
				local toggle = window.settings.pages.page.Toggle:Clone()
				toggle.Visible = true
				toggle.Parent = Page
				toggle.title.Text = data.Title
				toggle.Name = data.Title
				local toggleConfiguration = ui.Render.ToggleConfiguration:Clone()
				toggleConfiguration.Parent = ui.Render
				toggleConfiguration.Visible = false
				toggleConfiguration.Container.KeyBind.Bind.v.Text = 'None'
				tweenservice:Create(toggleConfiguration.Container.KeyBind.Bind, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, toggleConfiguration.Container.KeyBind.Bind.v.TextBounds.X + 20,0, 25)}):Play()
				toggleConfiguration.BackgroundTransparency = 1
				toggleConfiguration.Container.KeyBind.Title.TextTransparency = 1
				toggleConfiguration.Container.KeyBind.Bind.BackgroundTransparency = 1
				toggleConfiguration.Container.KeyBind.Bind.v.TextTransparency = 1
				toggleConfiguration.Container.Clear.Title.TextTransparency = 1
				toggleConfiguration.Container.Clear.clear.ImageLabel.ImageTransparency = 1
				toggleConfiguration.Size = UDim2.new(0, 75,0, 53)
				if not data.Config then toggle.configure:Destroy() end
				local function UpdateToggleUI(state)
					toggle:SetAttribute("Class", "syde-toggle" .. (state and " on" or ""))
					syde:ReapplyCSS()
				end
				UpdateToggleUI(data.V)
				toggle.interact.MouseButton1Click:Connect(function()
					data.V = not data.V
					UpdateToggleUI(data.V)
					if data.CallBack then pcall(function() data.CallBack(data.V) end) end
				end)
				if data.Config then
					local enterTween = TweenInfo.new(0.5, Enum.EasingStyle.Exponential)
					toggle.configure.MouseEnter:Connect(function() tweenservice:Create(toggle.configure, enterTween, {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play() end)
					toggle.configure.MouseLeave:Connect(function() tweenservice:Create(toggle.configure, enterTween, {ImageColor3 = Color3.fromRGB(104, 104, 104)}):Play() end)
					local function ToggleConfigOpen()
						toggleConfiguration.Visible = true
						tweenservice:Create(toggleConfiguration, enterTween, {BackgroundTransparency = 0}):Play()
						tweenservice:Create(toggleConfiguration.Container.KeyBind.Title, enterTween, {TextTransparency = 0}):Play()
						tweenservice:Create(toggleConfiguration.Container.KeyBind.Bind, enterTween, {BackgroundTransparency = 0}):Play()
						tweenservice:Create(toggleConfiguration.Container.KeyBind.Bind.UIStroke, enterTween, {Transparency = 0}):Play()
						tweenservice:Create(toggleConfiguration.Container.KeyBind.Bind.v, enterTween, {TextTransparency = 0}):Play()
						tweenservice:Create(toggleConfiguration.Container.Clear.clear.ImageLabel, enterTween, {ImageTransparency = 0}):Play()
						tweenservice:Create(toggleConfiguration.Container.Clear.Title, enterTween, {TextTransparency = 0}):Play()
						tweenservice:Create(toggleConfiguration, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 174,0, 88)}):Play()
					end
					local function ToggleConfigClose()
						tweenservice:Create(toggleConfiguration, enterTween, {BackgroundTransparency = 1}):Play()
						tweenservice:Create(toggleConfiguration.Container.KeyBind.Title, enterTween, {TextTransparency = 1}):Play()
						tweenservice:Create(toggleConfiguration.Container.KeyBind.Bind, enterTween, {BackgroundTransparency = 1}):Play()
						tweenservice:Create(toggleConfiguration.Container.KeyBind.Bind.UIStroke, enterTween, {Transparency = 1}):Play()
						tweenservice:Create(toggleConfiguration.Container.KeyBind.Bind.v, enterTween, {TextTransparency = 1}):Play()
						tweenservice:Create(toggleConfiguration.Container.Clear.clear.ImageLabel, enterTween, {ImageTransparency = 1}):Play()
						tweenservice:Create(toggleConfiguration.Container.Clear.Title, enterTween, {TextTransparency = 1}):Play()
						tweenservice:Create(toggleConfiguration, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 75,0, 53)}):Play()
						task.wait(0.5)
						toggleConfiguration.Visible = false
					end
					local TogService
					local debounce1 = false
					local function ToggleConfig()
						if debounce1 then return end
						debounce1 = true
						if not toggleConfiguration.Visible then
							TogService = runservice.RenderStepped:Connect(function()
								toggleConfiguration:TweenPosition(UDim2.new(0,toggle.configure.AbsolutePosition.X - 190,0,toggle.configure.AbsolutePosition.Y + toggle.configure.AbsoluteSize.Y + 65), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
								if not toggleConfiguration.Visible then TogService:Disconnect() end
							end)
							ToggleConfigOpen()
						else
							if TogService then TogService:Disconnect() end
							ToggleConfigClose()
						end
						task.delay(0.4, function() debounce1 = false end)
					end
					toggle.configure.MouseButton1Click:Connect(function() ToggleConfig() end)
				end
				syde:AddConnection(syde.Comms.Event, function(p, color)
					if p == 'HitBox' then
						if data.V then
							task.wait(0.5)
							toggle.tog.BackgroundColor3 = color
							toggle.tog.glow.ImageColor3 = color
						end
					end
				end)
				function data:Set(NewValue)
					data.V = NewValue
					UpdateToggleUI(NewValue)
					if data.CallBack then pcall(function() data.CallBack(NewValue) end) end
				end
				if data.SFlag then syde.SettingsFlags[data.SFlag] = data end
			end

			function telement:Keybind(Keybind)
				local data = {Title = Keybind.Title; Key = Keybind.Key; Desc = Keybind.Description or ""; CallBack = Keybind.CallBack; WaitingForKey = false}
				local KeyBind = window.settings.pages.page.KeyBind:Clone()
				KeyBind.Visible = true
				KeyBind.Parent = Page
				KeyBind.title.Text = data.Title
				KeyBind.Name = data.Title
				KeyBind.Bind.v.Text = data.Key and data.Key.Name or "NONE"
				tweenservice:Create(KeyBind.Bind, TweenInfo.new(0.55, Enum.EasingStyle.Quint), {Size = UDim2.new(0, KeyBind.Bind.v.TextBounds.X + 30, 0, KeyBind.Bind.Size.Y.Offset)}):Play()
				KeyBind.interact.MouseButton1Click:Connect(function()
					KeyBind.Bind.v.Text = '...'
					tweenservice:Create(KeyBind.Bind.UIStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Thickness = 1}):Play()
					data.WaitingForKey = true
				end)
				local function SetKeybind(keyCode)
					if keyCode and keyCode ~= Enum.KeyCode.Unknown then
						data.Key = keyCode
						KeyBind.Bind.v.Text = keyCode.Name
						tweenservice:Create(KeyBind.Bind.UIStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {Thickness = 0}):Play()
						if typeof(Keybind.OnKeyChanged) == "function" then pcall(Keybind.OnKeyChanged, keyCode) end
					else
						data.Key = nil
						KeyBind.Bind.v.Text = "NONE"
					end
				end
				syde:AddConnection(userinput.InputBegan, function(input)
					if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
					if data.WaitingForKey then data.WaitingForKey = false SetKeybind(input.KeyCode) return end
					if input.KeyCode == data.Key then pcall(data.CallBack) end
				end)
			end

			function telement:ColorPicker(ColorPicker)
				local data = {Title = ColorPicker.Title; Color = ColorPicker.Color; Color2 = ColorPicker.Color2; Linkable = ColorPicker.Linkable; Type = ColorPicker.Type or 'ColorPicker'; GradientPath = ColorPicker.GradientPath; CallBack = ColorPicker.CallBack; SFlag = ColorPicker.SFlag}
				ColorPicker.Linkable = ColorPicker.Linkable or true
				local colorpicker = window.settings.pages.page.ColorPicker:Clone()
				colorpicker.Visible = true
				colorpicker.Parent = Page
				colorpicker.title.Text = data.Title
				colorpicker.Name = data.Title
				local isLinkable = Instance.new("BoolValue")
				isLinkable.Name = 'isLinkable'
				isLinkable.Value = data.Linkable
				isLinkable.Parent = colorpicker
				local HueSat = Instance.new("Color3Value")
				HueSat.Name = 'HueSat'
				HueSat.Value = data.Color
				HueSat.Parent = colorpicker
				local Open = false
				local DeBounce = false
				local HSV = {data.Color and data.Color:ToHSV() or {0, 0, 0}}
				local SVPicker = colorpicker.color.SVPicker
				local HUESlider = colorpicker.color.Values.Hue
				local function updatestuff()
					data.Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3])
					colorpicker.color.BackgroundColor3 = data.Color
					colorpicker.color.glow.ImageColor3 = data.Color
					HueSat.Value = data.Color
					tweenservice:Create(HUESlider.Pin, TweenInfo.new(0.1, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromHSV(HSV[1], 1, 1)}):Play()
					tweenservice:Create(SVPicker.Pin, TweenInfo.new(0.1, Enum.EasingStyle.Exponential), {BackgroundColor3 = data.Color}):Play()
					if data.CallBack then data.CallBack(data.Color) end
				end
				updatestuff()
				colorpicker.QuickClose.Interactable = false
				tweenservice:Create(colorpicker.color, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundColor3 = data.Color}):Play()
				local function OpenPicker()
					Open = true
					DeBounce = true
					colorpicker.color.Values.Visible = true
					colorpicker.color.SVPicker.Visible = true
					colorpicker.HueValues.Visible = true
					colorpicker.interact.Interactable = false
					colorpicker.QuickClose.Interactable = true
					tweenservice:Create(colorpicker.color, TweenInfo.new(0.95, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 1,0, 1)}):Play()
					tweenservice:Create(colorpicker, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(35, 35, 35)}):Play()
					tweenservice:Create(colorpicker.color, TweenInfo.new(1, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromHSV(HSV[1], 1, 1)}):Play()
					tweenservice:Create(colorpicker.QuickClose, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
					task.wait(0.12)
					tweenservice:Create(colorpicker.color, TweenInfo.new(0.9, Enum.EasingStyle.Quart), {Size = UDim2.new(1, -40,0, 160)}):Play()
					tweenservice:Create(colorpicker.color, TweenInfo.new(0.9, Enum.EasingStyle.Quart), {Position = UDim2.new(0.5, 0,0, 40)}):Play()
					tweenservice:Create(colorpicker, TweenInfo.new(0.8, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(17, 17, 17)}):Play()
					tweenservice:Create(colorpicker, TweenInfo.new(0.8, Enum.EasingStyle.Quart), {Size = UDim2.new(1, -35,0, 300)}):Play()
					DeBounce = false
				end
				colorpicker.interact.MouseButton1Click:Connect(function()
					if DeBounce then return end
					if not Open then OpenPicker() end
				end)
				local function ClosePicker()
					Open = false
					DeBounce = true
					tweenservice:Create(colorpicker, TweenInfo.new(0.55, Enum.EasingStyle.Quint), {Size = UDim2.new(1, -35,0, 40)}):Play()
					tweenservice:Create(colorpicker.color, TweenInfo.new(0.7, Enum.EasingStyle.Quart), {Position = UDim2.new(1, -30,0, 10)}):Play()
					tweenservice:Create(colorpicker.color, TweenInfo.new(0.55, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 20,0, 20)}):Play()
					tweenservice:Create(colorpicker.color, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundColor3 = data.Color}):Play()
					tweenservice:Create(colorpicker.QuickClose, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
					colorpicker.interact.Interactable = true
					colorpicker.QuickClose.Interactable = false
					task.wait(0.7)
					DeBounce = false
				end
				colorpicker.QuickClose.hitbox.MouseButton1Click:Connect(function()
					if DeBounce then return end
					if Open then ClosePicker() end
				end)
				local SV, HUE = nil, nil
				syde:AddConnection(SVPicker.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						SV = runservice.RenderStepped:Connect(function()
							local mouse = game.Players.LocalPlayer:GetMouse()
							local ColorX = math.clamp(mouse.X - SVPicker.AbsolutePosition.X, 0, SVPicker.AbsoluteSize.X) / SVPicker.AbsoluteSize.X
							local ColorY = math.clamp(mouse.Y - SVPicker.AbsolutePosition.Y, 0, SVPicker.AbsoluteSize.Y) / SVPicker.AbsoluteSize.Y
							HSV[2] = ColorX
							HSV[3] = 1 - ColorY
							updatestuff()
						end)
					end
				end)
				syde:AddConnection(SVPicker.InputEnded, function(i)
					if i.UserInputType == Enum.UserInputType.MouseButton1 and SV then SV:Disconnect() SV = nil end
				end)
				syde:AddConnection(HUESlider.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						HUE = runservice.RenderStepped:Connect(function()
							local mouse = game.Players.LocalPlayer:GetMouse()
							local ColorX = math.clamp(mouse.X - HUESlider.AbsolutePosition.X, 0, HUESlider.AbsoluteSize.X) / HUESlider.AbsoluteSize.X
							HSV[1] = 1 - ColorX
							updatestuff()
						end)
					end
				end)
				syde:AddConnection(HUESlider.InputEnded, function(i)
					if i.UserInputType == Enum.UserInputType.MouseButton1 and HUE then HUE:Disconnect() HUE = nil end
				end)
				function data:Set(RGBColor)
					if typeof(RGBColor) == "table" then RGBColor = Color3.fromRGB(RGBColor.R, RGBColor.G, RGBColor.B) end
					data.Color = RGBColor
					local h, s, v = RGBColor:ToHSV()
					HSV[1], HSV[2], HSV[3] = h, s, v
					updatestuff()
				end
				if data.SFlag then syde.SettingsFlags[data.SFlag] = data end
			end

			function telement:Dropdown(Dropdown)
				local data = {Title = Dropdown.Title or "Temp Dropdown"; Options = Dropdown.Options or {}; StarterOption = Dropdown.StarterOption; PlaceHolder = Dropdown.PlaceHolder or "Select Option..."; Multi = Dropdown.Multi or false; CallBack = Dropdown.CallBack}
				local dropdown = window.settings.pages.page.Dropdown:Clone()
				dropdown.Visible = true
				dropdown.Parent = Page
				dropdown.title.Text = data.Title
				dropdown.Name = data.Title
				dropdown.dropholder.drop.Container.Option.Visible = false
				dropdown.dropholder.drop.Container.Visible = false
				dropdown.dropholder.drop.selected.Text = data.PlaceHolder
				local DropOpen = false
				local DeBounce = false
				local OptionButton = dropdown.dropholder.drop.Container.Option
				local SelectedOptions = {}
				local SelectedOrder = {}
				local function OpenDrop()
					DropOpen = true
					dropdown.dropholder.drop.Container.Visible = true
					tweenservice:Create(dropdown, TweenInfo.new(1.34, Enum.EasingStyle.Quint), {Size = UDim2.new(1, -35, 0, 300)}):Play()
					tweenservice:Create(dropdown.dropholder.drop.v0, TweenInfo.new(1.34, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
				end
				local function CloseDrop()
					DropOpen = false
					tweenservice:Create(dropdown, TweenInfo.new(1, Enum.EasingStyle.Quint), {Size = UDim2.new(1, -35, 0, 95)}):Play()
					tweenservice:Create(dropdown.dropholder.drop.v0, TweenInfo.new(1.34, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
					task.wait(0.6)
					dropdown.dropholder.drop.Container.Visible = false
				end
				dropdown.dropholder.drop.down.MouseButton1Click:Connect(function()
					if DeBounce then return end
					DeBounce = true
					if DropOpen then CloseDrop() else OpenDrop() end
					task.delay(1.2, function() DeBounce = false end)
				end)
				for _, OptionText in ipairs(data.Options) do
					local option = OptionButton:Clone()
					option.Title.Text = OptionText
					option.Parent = dropdown.dropholder.drop.Container
					option.Visible = true
					option.Name = OptionText
					if OptionText == data.StarterOption then
						dropdown.dropholder.drop.selected.Text = OptionText
						SelectedOptions = {[OptionText] = true}
						SelectedOrder = {OptionText}
					end
					option.Interact.MouseButton1Click:Connect(function()
						dropdown.dropholder.drop.selected.Text = OptionText
						SelectedOptions = {[OptionText] = true}
						SelectedOrder = {OptionText}
						if data.CallBack then data.CallBack(OptionText) end
						CloseDrop()
					end)
				end
			end

			function telement:Slider(Slider)
				local data = {Title = Slider.Title; Desc = Slider.Description; Sliders = Slider.Sliders}
				local slider = window.settings.pages.page.Slider:Clone()
				slider.Visible = true
				slider.Parent = Page
				slider.title.Text = data.Title
				slider.Name = data.Title
				slider.slideholder.slider.Visible = false
				for _, Options in ipairs(data.Sliders) do
					local Slider = window.settings.pages.page.Slider.slideholder.slider:Clone()
					Options = {Title = Options.Title or "Slider"; Increment = Options.Increment or 1; Range = Options.Range or {0, 100}; StarterValue = Options.StarterValue or 16; CallBack = Options.CallBack; SFlag = Options.SFlag; SettingsConfig = true}
					Slider.Name = Options.Title
					do local _sliderTitle = sydeSliderLabel(Slider); if _sliderTitle then _sliderTitle.Text = Options.Title end end
					Options.Value = Options.StarterValue
					local dragging = false
					Slider.Visible = true
					Slider.Parent = slider.slideholder

					Slider.slide.Interact.MouseButton1Down:Connect(function() dragging = true end)
					Slider.slide.Interact.MouseButton1Up:Connect(function() dragging = false end)
					syde:AddConnection(userinput.InputEnded, function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
					syde:AddConnection(userinput.InputChanged, function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
						local sliderStart = Slider.slide.AbsolutePosition.X
						local sliderWidth = Slider.slide.AbsoluteSize.X
						local sliderPosition = math.clamp((input.Position.X - sliderStart) / sliderWidth, 0, 1)
						local range = Options.Range[2] - Options.Range[1]
						local newValue = Options.Range[1] + sliderPosition * range
						newValue = math.floor((newValue - Options.Range[1]) / Options.Increment + 0.5) * Options.Increment + Options.Range[1]
						local snapPosition = (newValue - Options.Range[1]) / range
						Slider.slide.slideframe:TweenSize(UDim2.new(snapPosition, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.55, true)
						if Options.CallBack then pcall(function() Options.CallBack(newValue) end) end
						Options.StarterValue = newValue
					end end)
					Slider.slide.slideframe.BackgroundColor3 = syde.theme.HitBox
					syde:AddConnection(syde.Comms.Event, function(p, color) if p == 'HitBox' then Slider.slide.slideframe.BackgroundColor3 = color end end)
					function Options:Set(NewVal, skipSave)
						local range = Options.Range[2] - Options.Range[1]
						NewVal = math.floor((NewVal - Options.Range[1]) / Options.Increment + 0.5) * Options.Increment + Options.Range[1]
						local sliderPosition = (NewVal - Options.Range[1]) / range
						Slider.slide.slideframe:TweenSize(UDim2.new(sliderPosition, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.55, true)
						if Options.CallBack then pcall(function() Options.CallBack(NewVal) end) end
						Options.StarterValue = NewVal
					end
					if Options.SFlag then syde.SettingsFlags[Options.SFlag] = Options end
				end
			end

			function telement:TextInput(TextInput)
				local data = {Title = TextInput.Title or "Text Input"; PlaceHolder = TextInput.PlaceHolder or "Enter text..."; NumbersOnly = TextInput.NumberOnly or false; ClearOnLost = TextInput.ClearOnLost == nil and true or TextInput.ClearOnLost; CallBack = TextInput.CallBack}
				local textinput = window.settings.pages.page.Input:Clone()
				textinput.Visible = true
				textinput.Parent = Page
				textinput.Name = data.Title
				textinput.title.Text = data.Title
				textinput.TextFrame.TextBox.PlaceholderText = data.PlaceHolder
				local textBox = textinput.TextFrame.TextBox
				textBox.FocusLost:Connect(function(enterPressed)
					if not enterPressed then return end
					if data.CallBack then pcall(function() data.CallBack(textBox.Text) end) end
					if data.ClearOnLost then textBox.Text = "" end
				end)
			end

			function telement:Paragraph(Paragraph)
				local Para = window.settings.pages.page.Paragraph:Clone()
				Para.Visible = true
				Para.Parent = Page
				Para.Frame.title.Text = Paragraph.Title
				Para.Content.Text = Paragraph.Content
			end

			return telement
		end

		local a = settings:inittab({Title = 'Theme'})
		local b = settings:inittab({Title = 'Privacy'})
		local c = settings:inittab({Title = 'Info'})
		a:Keybind({Title = 'Toggle UI', Key = uitoggle, OnKeyChanged = function(newKey) uitoggle = newKey end, CallBack = function() ToggleUI() end})
		a:ColorPicker({Title = 'Accent', Linkable = true, Color = syde.theme.Accent; CallBack = function(v) syde:UpdateTheme({['Accent'] = v}) end, SFlag = 'AC'})
		a:ColorPicker({Title = 'Hitbox', Linkable = true, Color = syde.theme.HitBox; CallBack = function(c) syde:UpdateTheme({['HitBox'] = c}) end, SFlag = 'HB'})
		a:Toggle({Title = 'Glow', Description = 'Shine on the ui.', CallBack = function(v) glow = v end, SFlag = 'GLW'})
		a:Toggle({Title = 'Blur', Description = 'Make sure your graphics are above 8.', CallBack = function(v) bluron = v end, SFlag = 'BLUR'})
		a:Toggle({Title = 'LockToScreen', Description = 'Prevents UI from moving off screen.', Value = LockToScreen, CallBack = function(v) LockToScreen = v end, SFlag = 'LS'})
		b:Toggle({Title = 'Anonymous', Description = 'Hides your info in User Info.', CallBack = function(v) if v then window.user.headshot.Image = 'rbxassetid://139956761561818' else SetUserInfo() end end, SFlag = 'ANON'})
		c:Paragraph({Title = 'Status', Content = 'Your Up To Date!'})
	end

	-- Tabs
	local tbdata = {first = false, selected = false}
	function tbdata:InitTab(tab)
		if type(tab) == "string" then tab = {Title = tab} end
		if Data.Home.Enabled then
			if not tbdata.__homeBootstrapped then
				tbdata.__homeBootstrapped = true
				tbdata.first = "Home"
				tbdata.homeActive = true
				for _, temp in ipairs(pages:GetChildren()) do if temp:IsA("ScrollingFrame") then temp.Visible = false end end
				if window and window.pages and window.pages.home then window.pages.home.Visible = true end
			end
		end
		local isFirstTab = not tbdata.first
		local tdata = {Title = tab.Title; Locked = tab.Locked or false; Key = tab.Key}
		local Tab = tabs.btn:Clone()
		Tab.Visible = true
		Tab.Parent = tabs
		Tab.title.Text = tdata.Title
		Tab.Name = tdata.Title
		Tab.title.TextTransparency = 1
		Tab.indicator.BackgroundTransparency = 1
		local Page = pages.page:Clone()
		Page.Visible = false
		Page.Parent = pages
		Page.Name = tdata.Title
		for _, temp in ipairs(Page:GetChildren()) do if temp:IsA("Frame") then temp:Destroy() end end
		Page.ChildAdded:Connect(function(child)
			child:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() syde:updateLayout(Page, 7) end)
			child:GetPropertyChangedSignal("Visible"):Connect(function() syde:updateLayout(Page, 7) end)
			syde:updateLayout(Page, 7)
		end)
		Page.ChildRemoved:Connect(function() syde:updateLayout(Page, 7) end)
		Page:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() syde:updateLayout(Page, 7) end)
		syde:updateLayout(Page, 7)
		local function ChangeName(Name)
			tweenservice:Create(pages.clipframe.title, TweenInfo.new(0), {TextTransparency = pages.clipframe.title.TextTransparency}):Play()
			local fadeOut = tweenservice:Create(pages.clipframe.title, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {TextTransparency = 1})
			fadeOut:Play()
			task.wait(0.2)
			pages.clipframe.title.Text = Name
			local fadeIn = tweenservice:Create(pages.clipframe.title, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {TextTransparency = 0})
			fadeIn:Play()
		end
		if isFirstTab then ChangeName(tdata.Title) Page.Visible = true tbdata.first = tdata.Title end
		if tbdata.first then
			tweenservice:Create(Tab.indicator, TweenInfo.new(1, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
			syde:AddConnection(syde.Comms.Event, function(p, color)
				if p == 'Accent' then if tbdata.first ~= tdata.Title then return end
					tweenservice:Create(Tab.indicator, TweenInfo.new(0.25, Enum.EasingStyle.Exponential), {BackgroundColor3 = color}):Play()
				end
			end)
		else
			tbdata.first = tdata.Title
			tweenservice:Create(Tab.indicator, TweenInfo.new(1, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
			tweenservice:Create(Tab.indicator, TweenInfo.new(2, Enum.EasingStyle.Exponential), {BackgroundColor3 = syde.theme.Accent}):Play()
		end
		local function ApplyTabStyle(tabButton, isSelected)
			local targetColor = isSelected and syde.theme.Accent or Color3.fromRGB(29, 29, 29)
			tweenservice:Create(tabButton.indicator, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundColor3 = targetColor}):Play()
			tweenservice:Create(tabButton.indicator, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), {BackgroundTransparency = isSelected and 0 or 1}):Play()
		end
		ApplyTabStyle(Tab, isFirstTab)
		if Data.Home.Enabled then ApplyTabStyle(Tab, false) end
		Tab.interact.MouseButton1Click:Connect(function()
			if tbdata.first == tdata.Title then return end
			if Data.Home.Enabled and tbdata.homeActive then tbdata.homeActive = false end
			local previous = tbdata.first
			tbdata.first = tdata.Title
			if pages:FindFirstChild(previous) and pages:FindFirstChild(tdata.Title) then ChangeName(tdata.Title) else pages.clipframe.title.Text = tdata.Title end
			for _, otherPage in ipairs(pages:GetChildren()) do if otherPage:IsA("ScrollingFrame") then otherPage.Visible = false end end
			Page.Visible = true
			syde:replayLoadTweens()
			for _, otherTab in ipairs(tabs:GetChildren()) do if otherTab:IsA("Frame") then ApplyTabStyle(otherTab, otherTab == Tab) end end
		end)
		local function SwitchToTab(tabName)
			local selectedTab, targetPage
			for _, tab in ipairs(tabs:GetChildren()) do if tab:IsA("Frame") and tab.Name == tabName then selectedTab = tab break end end
			targetPage = pages:FindFirstChild(tabName)
			if not (selectedTab and targetPage) then return end
			if tbdata.first == tabName then return end
			ChangeName(tabName)
			for _, page in ipairs(pages:GetChildren()) do if page:IsA("ScrollingFrame") then page.Visible = false end end
			targetPage.Visible = true
			tbdata.first = tabName
			for _, tab in ipairs(tabs:GetChildren()) do if tab:IsA("Frame") then ApplyTabStyle(tab, tab == selectedTab) end end
			syde:replayLoadTweens()
			return targetPage
		end
		local Pages = pages
		local Results = window.search.Container
		local Template = Results.option
		local activeResults = {}
		local function getFunctionType(frame) local attr = frame:GetAttribute("FunctionType") if typeof(attr) == "string" then return attr end return "Function" end
		local function clearResults() for _, v in ipairs(Results:GetChildren()) do if v:IsA("Frame") and v ~= Template then v:Destroy() end end table.clear(activeResults) end
		local function createResult(page, func)
			local key = func:GetFullName()
			if activeResults[key] then return end
			activeResults[key] = true
			local result = Template:Clone()
			result.Visible = true
			result.Parent = Results
			result.info.title.Text = func.Name
			result.info.badge["function"].Text = getFunctionType(func)
			result.info.badge.Size = UDim2.new(0, result.info.badge["function"].TextBounds.X + 20,0, 20)
			result.interact.MouseButton1Click:Connect(function()
				closesearch()
				local openedPage = pages:FindFirstChild(page.Name)
				if not openedPage or not openedPage:IsA("ScrollingFrame") then return end
				SwitchToTab(page.Name)
				task.wait(0.05)
				local y = func.AbsolutePosition.Y - openedPage.AbsolutePosition.Y + openedPage.CanvasPosition.Y
				tweenservice:Create(openedPage, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {CanvasPosition = Vector2.new(0, math.max(0, y - 20))}):Play()
			end)
		end
		local function searchFunctions(query)
			local thisSearch = (searchDebounce or 0) + 1; searchDebounce = thisSearch
			task.delay(0.05, function()
				if thisSearch ~= searchDebounce then return end
				clearResults()
				query = query:lower()
				if query == "" then return end
				for _, page in ipairs(Pages:GetChildren()) do
					if page:IsA("ScrollingFrame") then
						for _, child in ipairs(page:GetChildren()) do
							if child:IsA("Frame") and child:GetAttribute("Searchable") then
								local name = child.Name:lower()
								if name:find(query) then createResult(page, child) end
							end
						end
					end
				end
			end)
		end
		local SearchBox = window.search.Frame.TextBox
		SearchBox:GetPropertyChangedSignal("Text"):Connect(function() searchFunctions(SearchBox.Text) end)

		local initelement = {}
		function initelement:Button(Button)
			local data = {Title = Button.Title or "Temp Button"; CallBack = Button.CallBack; Desc = Button.Description or ""; Type = Button.Type or 'Default'; HoldTime = Button.HoldTime or 3}
			local button = pages.page.Button:Clone()
			button.Visible = true
			button.Parent = Page
			button.title.Text = data.Title
			button.Name = data.Title
			button.title.Size = UDim2.new(0, button.title.TextBounds.X + 15,0, 35)
			button:SetAttribute("Searchable", true)
			local c = data.CallBack
			button.interact.MouseButton1Click:Connect(function()
				if data.Type == 'Default' then
					if data.CallBack then pcall(c) end
				elseif data.Type == 'Hold' then
					local HoldTime = data.HoldTime
					local Holding = false
					local TimeLeft = HoldTime
					button.interact.MouseButton1Down:Connect(function()
						Holding = true
						TimeLeft = HoldTime
						while Holding and TimeLeft > 0 do
							TimeLeft = math.max(0, TimeLeft - runservice.Heartbeat:Wait())
							button.title.timer.Text = string.format("%.1f", TimeLeft)
						end
						if TimeLeft <= 0 then if data.CallBack then pcall(data.CallBack) end end
					end)
					button.interact.MouseButton1Up:Connect(function() Holding = false end)
				end
			end)
		end

		function initelement:Toggle(Toggle)
			local data = {Title = Toggle.Title or "Temp Toggle"; Desc = Toggle.Description or ""; V = Toggle.Value or false; Config = Toggle.Config or false; CallBack = Toggle.CallBack; Flag = Toggle.Flag}
			local toggle = pages.page.Toggle:Clone()
			toggle.Visible = true
			toggle.Parent = Page
			toggle.title.Text = data.Title
			toggle.Name = data.Title
			toggle:SetAttribute("Searchable", true)
			if not data.Config then toggle.configure:Destroy() end
			local function UpdateToggleUI(state)
				toggle:SetAttribute("Class", "syde-toggle" .. (state and " on" or ""))
				syde:ReapplyCSS()
			end
			UpdateToggleUI(data.V)
			toggle.interact.MouseButton1Click:Connect(function()
				data.V = not data.V
				UpdateToggleUI(data.V)
				if data.CallBack then pcall(function() data.CallBack(data.V) end) end
				SaveConfig()
			end)
			syde:AddConnection(syde.Comms.Event, function(p, color)
				if p == 'HitBox' then if data.V then toggle.tog.BackgroundColor3 = color toggle.tog.glow.ImageColor3 = color end end
			end)
			function data:Set(NewValue, skipSave)
				if data.V == NewValue then return end
				data.V = NewValue
				UpdateToggleUI(NewValue)
				if data.CallBack then pcall(function() data.CallBack(data.V) end) end
				if not skipSave then SaveConfig() end
			end
			if syde.ConfigEnabled then if data.Flag then syde.Flags[data.Flag] = data end end
			return data
		end

		function initelement:Slider(Slider)
			local data = {Title = Slider.Title; Desc = Slider.Description; Sliders = Slider.Sliders}
			local slider = pages.page.Slider:Clone()
			slider.Visible = true
			slider.Parent = Page
			slider.title.Text = data.Title
			slider.Name = data.Title
			slider.slideholder.slider.Visible = false
			slider:SetAttribute("Searchable", true)
			for _, Options in ipairs(data.Sliders) do
				local Slider = pages.page.Slider.slideholder.slider:Clone()
				Options = {Title = Options.Title or "Slider"; Increment = Options.Increment or 1; Range = Options.Range or {0, 100}; StarterValue = Options.StarterValue or 16; CallBack = Options.CallBack; Flag = Options.Flag}
				Slider.Name = Options.Title
				do local _sliderTitle = sydeSliderLabel(Slider); if _sliderTitle then _sliderTitle.Text = Options.Title end end
				Options.Value = Options.StarterValue
				local dragging = false
				Slider.Visible = true
				Slider.Parent = slider.slideholder
				local SliderPosition = 0
				if Options.StarterValue > Options.Range[1] then
					local range = Options.Range[2] - Options.Range[1]
					SliderPosition = (Options.StarterValue - Options.Range[1]) / range
				end
				Slider.slide.slideframe:TweenSize(UDim2.new(SliderPosition, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.5, true)
				Slider.slide.Interact.MouseButton1Down:Connect(function() dragging = true end)
				Slider.slide.Interact.MouseButton1Up:Connect(function() dragging = false end)
				syde:AddConnection(userinput.InputEnded, function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
				syde:AddConnection(userinput.InputChanged, function(input)
					if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
						local sliderStart = Slider.slide.AbsolutePosition.X
						local sliderWidth = Slider.slide.AbsoluteSize.X
						local sliderPosition = math.clamp((input.Position.X - sliderStart) / sliderWidth, 0, 1)
						local range = Options.Range[2] - Options.Range[1]
						local newValue = Options.Range[1] + sliderPosition * range
						newValue = math.floor((newValue - Options.Range[1]) / Options.Increment + 0.5) * Options.Increment + Options.Range[1]
						local snapPosition = (newValue - Options.Range[1]) / range
						Slider.slide.slideframe:TweenSize(UDim2.new(snapPosition, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.55, true)
						Options.StarterValue = newValue
						if Options.CallBack then Options.CallBack(newValue) end
						SaveConfig()
					end
				end)
				Slider.slide.slideframe.BackgroundColor3 = syde.theme.HitBox
				syde:AddConnection(syde.Comms.Event, function(p, color) if p == 'HitBox' then Slider.slide.slideframe.BackgroundColor3 = color end end)
				function Options:Set(NewVal, skipSave)
					local range = Options.Range[2] - Options.Range[1]
					local sliderPosition = (NewVal - Options.Range[1]) / range
					Slider.slide.slideframe:TweenSize(UDim2.new(sliderPosition, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.55, true)
					Options.StarterValue = NewVal
					if not skipSave then SaveConfig() end
				end
				if syde.ConfigEnabled then if Options.Flag then syde.Flags[Options.Flag] = Options end end
			end
		end

		function initelement:Keybind(Keybind)
			local data = {Title = Keybind.Title; Key = Keybind.Key; Desc = Keybind.Description or ""; CallBack = Keybind.CallBack; WaitingForKey = false}
			local KeyBind = pages.page.KeyBind:Clone()
			KeyBind.Visible = true
			KeyBind.Parent = Page
			KeyBind.title.Text = data.Title
			KeyBind.Name = data.Title
			KeyBind:SetAttribute("Searchable", true)
			KeyBind.Bind.v.Text = data.Key and data.Key.Name or "NONE"
			KeyBind.interact.MouseButton1Click:Connect(function()
				KeyBind.Bind.v.Text = '...'
				data.WaitingForKey = true
			end)
			syde:AddConnection(userinput.InputBegan, function(input)
				if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
				if data.WaitingForKey then data.WaitingForKey = false KeyBind.Bind.v.Text = input.KeyCode.Name data.Key = input.KeyCode return end
				if input.KeyCode == data.Key then pcall(data.CallBack) end
			end)
		end

		function initelement:TextInput(TextInput)
			local data = {Title = TextInput.Title or "Text Input"; PlaceHolder = TextInput.PlaceHolder or "Enter text..."; NumbersOnly = TextInput.NumberOnly or false; ClearOnLost = TextInput.ClearOnLost == nil and true or TextInput.ClearOnLost; CallBack = TextInput.CallBack}
			local textinput = pages.page.Input:Clone()
			textinput.Visible = true
			textinput.Parent = Page
			textinput.Name = data.Title
			textinput.title.Text = data.Title
			textinput.TextFrame.TextBox.PlaceholderText = data.PlaceHolder
			textinput:SetAttribute("Searchable", true)
			local textBox = textinput.TextFrame.TextBox
			textBox.FocusLost:Connect(function(enterPressed)
				if not enterPressed then return end
				if data.CallBack then pcall(function() data.CallBack(textBox.Text) end) end
				if data.ClearOnLost then textBox.Text = "" end
			end)
		end

		function initelement:Dropdown(Dropdown)
			local data = {
				Title = Dropdown.Title or "Temp Dropdown";
				Options = Dropdown.Options or {};
				StarterOption = Dropdown.StarterOption;
				PlaceHolder = Dropdown.PlaceHolder or "Select Option...";
				Multi = Dropdown.Multi or false;
				CallBack = Dropdown.CallBack;
			}

			local dropdown = sydeClonePageTemplate(window.settings.pages.page, "Dropdown")
			sydeSanitizeUiClone(dropdown)
			dropdown.Visible = true
			dropdown.Parent = Page
			dropdown.title.Text = data.Title
			dropdown.Name = data.Title
			local drop = sydePrepareDropdownDrop(dropdown)
			if not drop or not drop.Container then
				warn("[Syde] Skipping dropdown: " .. tostring(data.Title))
				return initelement
			end
			drop.Container.Option.Visible = false
			drop.Container.Visible = false
			tweenservice:Create(drop.Container, TweenInfo.new(1, Enum.EasingStyle.Quint), { Size = UDim2.new(0.33, -20,0.576, -75) }):Play()
			sydeSetDropSelectedText(drop, data.PlaceHolder)

			local DropOpen = false
			local DeBounce = false
			local OptionButton = drop.Container.Option
			local SelectedOptions = {}
			local SelectedOrder = {}

			local function UpdateCustomLayout()
				local yOffset = 0
				for _, option in ipairs(drop.Container:GetChildren()) do
					if option:IsA("Frame") and option.Visible then
						tweenservice:Create(option, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 0, 0, yOffset)}):Play()
						yOffset = yOffset + option.Size.Y.Offset + 7
					end
				end
			end

			local function OpenDrop()
				DropOpen = true
				drop.Container.Visible = true
				drop.search.Visible = true

				tweenservice:Create(dropdown, TweenInfo.new(1.34, Enum.EasingStyle.Quint), { Size = UDim2.new(1, -35, 0, 300) }):Play()
				tweenservice:Create(drop.UICorner, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { CornerRadius = UDim.new(0, 20) }):Play()
				tweenservice:Create(drop.Container, TweenInfo.new(1, Enum.EasingStyle.Quint), { Size = UDim2.new(1, -20, 1, -75) }):Play()
				tweenservice:Create(drop.v0, TweenInfo.new(1.34, Enum.EasingStyle.Exponential), { BackgroundTransparency = 0 }):Play()
				tweenservice:Create(drop.down, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Rotation = 180 }):Play()

				tweenservice:Create(drop.search, TweenInfo.new(1, Enum.EasingStyle.Exponential), { BackgroundTransparency = 0.65 }):Play()
				tweenservice:Create(drop.search.UIStroke, TweenInfo.new(1, Enum.EasingStyle.Exponential), { Transparency = 0.4 }):Play()
				tweenservice:Create(drop.search.TextBox, TweenInfo.new(1, Enum.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
				tweenservice:Create(drop.search.ImageLabel, TweenInfo.new(1, Enum.EasingStyle.Exponential), { ImageTransparency = 0.9 }):Play()
				tweenservice:Create(drop.search.icon, TweenInfo.new(1, Enum.EasingStyle.Exponential), { ImageTransparency = 0.85 }):Play()

			end

			local function CloseDrop()
				DropOpen = false
				tweenservice:Create(dropdown, TweenInfo.new(1, Enum.EasingStyle.Quint), { Size = UDim2.new(1, -35, 0, 95) }):Play()
				tweenservice:Create(drop.UICorner, TweenInfo.new(1, Enum.EasingStyle.Quint), { CornerRadius = UDim.new(1,0) }):Play()
				tweenservice:Create(drop.Container, TweenInfo.new(1, Enum.EasingStyle.Quint), { Size = UDim2.new(0.33, -20, 0.576, -75) }):Play()
				tweenservice:Create(drop.v0, TweenInfo.new(1.34, Enum.EasingStyle.Exponential), { BackgroundTransparency = 1 }):Play()
				tweenservice:Create(drop.down, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Rotation = 0 }):Play()

				tweenservice:Create(drop.search, TweenInfo.new(1, Enum.EasingStyle.Exponential), { BackgroundTransparency = 1 }):Play()
				tweenservice:Create(drop.search.UIStroke, TweenInfo.new(1, Enum.EasingStyle.Exponential), { Transparency = 1 }):Play()
				tweenservice:Create(drop.search.TextBox, TweenInfo.new(1, Enum.EasingStyle.Exponential), { TextTransparency = 1 }):Play()
				tweenservice:Create(drop.search.ImageLabel, TweenInfo.new(1, Enum.EasingStyle.Exponential), { ImageTransparency = 1 }):Play()
				tweenservice:Create(drop.search.icon, TweenInfo.new(1, Enum.EasingStyle.Exponential), { ImageTransparency = 1 }):Play()

				task.wait(0.6)
				drop.Container.Visible = false
				drop.search.Visible = false

			end

			drop.down.MouseButton1Click:Connect(function()
				if DeBounce then return end
				DeBounce = true

				if DropOpen then
					CloseDrop()
				else
					OpenDrop()
				end

				task.delay(1.2, function()
					DeBounce = false
				end)
			end)

			local function AddToSelected(option)
				if not SelectedOptions[option] then
					SelectedOptions[option] = true

					local originalIndex
					for i, opt in ipairs(data.Options) do
						if opt == option then
							originalIndex = i
							break
						end
					end

					local insertIndex = 1
					for i, selected in ipairs(SelectedOrder) do
						local selectedIndex = table.find(data.Options, selected)
						if selectedIndex and selectedIndex < originalIndex then
							insertIndex = i + 1
						else
							break
						end
					end
					table.insert(SelectedOrder, insertIndex, option)
				end
			end

			local function RemoveFromSelected(option)
				if SelectedOptions[option] then
					SelectedOptions[option] = nil
					for i = #SelectedOrder, 1, -1 do
						if SelectedOrder[i] == option then
							table.remove(SelectedOrder, i)
							break
						end
					end
				end

				local selectedContainer = drop.selectContainer.ScrollingFrame
				for _, child in ipairs(selectedContainer:GetChildren()) do
					if child:IsA("Frame") and child.Name == option then
						child:Destroy()
						break
					end
				end
			end

			local function UpdateSelectedText()
				local selectedContainer = drop.selectContainer.ScrollingFrame
				local placeholderText = drop.selected
				selectedContainer.Visible = data.Multi
				drop.selected.Visible = false


				if data.Multi then

					if #SelectedOrder == 0 then
						placeholderText.Visible = true
						selectedContainer.Visible = false
						return
					end


					-- Create chips for each selected option
					for _, option in ipairs(SelectedOrder) do
						-- Prevent duplicate pills
						if not selectedContainer:FindFirstChild(option) then
							local optionGroup = selectedContainer.result:Clone()
							optionGroup.Visible = true
							optionGroup.Name = option
							optionGroup.TextLabel.Text = option

							-- Set up remove button
							optionGroup.X.MouseButton1Click:Connect(function()
								RemoveFromSelected(option)
								UpdateSelectedText()

								-- Visually update the dropdown list
								for _, opt in ipairs(drop.Container:GetChildren()) do
									if opt:IsA("Frame") and opt.Name == option then
										tweenservice:Create(opt, TweenInfo.new(1, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
										tweenservice:Create(opt, TweenInfo.new(1, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(33, 33, 33)}):Play()
										do local _optionLabel = sydeOptionLabel(opt); if _optionLabel then tweenservice:Create(_optionLabel, TweenInfo.new(1, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play() end end
										tweenservice:Create(opt.UIStroke, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
										tweenservice:Create(opt.ImageLabel, TweenInfo.new(1, Enum.EasingStyle.Exponential), {ImageTransparency = 0.9}):Play()
									end
								end

								if data.CallBack then
									data.CallBack(SelectedOrder)
								end
							end)

							optionGroup.Parent = selectedContainer

							-- Optional: auto-size width
							task.defer(function()
								local padding = 40
								local textWidth = optionGroup.TextLabel.TextBounds.X
								local totalWidth = textWidth + padding

								optionGroup.TextLabel.Size = UDim2.new(0, textWidth, 1, 0)

								tweenservice:Create(optionGroup, TweenInfo.new(0.67, Enum.EasingStyle.Exponential), {Size = UDim2.new(0, totalWidth, 0, 20)}):Play()
							end)
						end
					end

				else
					-- Single option text fallback
					drop.selected.Visible = true
					if #SelectedOrder > 0 then
						drop.selected.Text = SelectedOrder[1]
					else
						drop.selected.Text = data.PlaceHolder
					end
				end
			end

			--[SEARCH]
			drop.search.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
				local searchText = drop.search.TextBox.Text:lower()

				for _, option in ipairs(drop.Container:GetChildren()) do
					local optionLabel = sydeTitleLabel(option)
					if option:IsA("Frame") and optionLabel then
						local optionText = optionLabel.Text:lower()
						local isTemplate = option.Name == "Option"
						local shouldShow = not isTemplate and (searchText == "" or optionText:find(searchText, 1, true) or SelectedOptions[optionLabel.Text])

						if shouldShow then
							option.Visible = true
							if SelectedOptions[optionLabel.Text] then
								tweenservice:Create(option, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
								tweenservice:Create(option, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(39, 39, 39)}):Play()
								tweenservice:Create(optionLabel, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
								tweenservice:Create(option.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
								tweenservice:Create(option.ImageLabel, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 0}):Play()
							else
								tweenservice:Create(option, TweenInfo.new(1, Enum.EasingStyle.Exponential), {BackgroundTransparency = 0}):Play()
								tweenservice:Create(option, TweenInfo.new(1, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(33, 33, 33)}):Play()
								tweenservice:Create(optionLabel, TweenInfo.new(1, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()
								tweenservice:Create(option.UIStroke, TweenInfo.new(1, Enum.EasingStyle.Exponential), {Transparency = 0.5}):Play()
								tweenservice:Create(option.ImageLabel, TweenInfo.new(1, Enum.EasingStyle.Exponential), {ImageTransparency = 0.9}):Play()
							end
						else
							-- Hide with animation, but wait before setting Visible = false
							tweenservice:Create(option, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundTransparency = 1}):Play()
							tweenservice:Create(option, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {BackgroundColor3 = Color3.fromRGB(33, 33, 33)}):Play()
							tweenservice:Create(optionLabel, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {TextTransparency = 1}):Play()
							tweenservice:Create(option.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {Transparency = 1}):Play()
							tweenservice:Create(option.ImageLabel, TweenInfo.new(0.7, Enum.EasingStyle.Exponential), {ImageTransparency = 1}):Play()
							option.Visible = false
						end
					end
				end

				UpdateCustomLayout()
			end)



			local function SetDropdownOptions()
				local starterSet = false
				for _, OptionText in ipairs(data.Options) do
					local option = OptionButton:Clone()
					sydeSanitizeUiClone(option)
					local optionLabel = sydeTitleLabel(option)
					if optionLabel then
						optionLabel.Text = OptionText
					end
					option.Parent = drop.Container
					option.Visible = true
					option.Name = OptionText

					if OptionText == data.StarterOption and not starterSet then
						starterSet = true
						drop.selected.Text = OptionText
						SelectedOptions = {[OptionText] = true}
						SelectedOrder = {OptionText}

						tweenservice:Create(option, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(39, 39, 39)}):Play()
						tweenservice:Create(option.ImageLabel, TweenInfo.new(0.3), {ImageTransparency = 0}):Play()
					end

					sydeConnectClick(option, function()
						if data.Multi then
							if SelectedOptions[OptionText] then
								RemoveFromSelected(OptionText)
								tweenservice:Create(option, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(33, 33, 33)}):Play()
								tweenservice:Create(option.ImageLabel, TweenInfo.new(0.3), {ImageTransparency = 0.9}):Play()
							else
								AddToSelected(OptionText)
								tweenservice:Create(option, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(39, 39, 39)}):Play()
								tweenservice:Create(option.ImageLabel, TweenInfo.new(0.3), {ImageTransparency = 0}):Play()
							end

							if data.CallBack then
								data.CallBack(SelectedOrder)
							end
						else
							drop.selected.Text = OptionText

							SelectedOptions = {[OptionText] = true}
							SelectedOrder = {OptionText}

							for _, opt in ipairs(drop.Container:GetChildren()) do
								if opt:IsA("Frame") then
									tweenservice:Create(opt, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(33, 33, 33)}):Play()
									tweenservice:Create(opt.ImageLabel, TweenInfo.new(0.3), {ImageTransparency = 0.9}):Play()
								end
							end

							tweenservice:Create(option, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(39, 39, 39)}):Play()
							tweenservice:Create(option.ImageLabel, TweenInfo.new(0.3), {ImageTransparency = 0}):Play()


							if data.CallBack then
								data.CallBack(OptionText)
							end


							CloseDrop()
						end

						UpdateSelectedText()

					end)
				end

				if not starterSet then
					drop.selected.Text = data.PlaceHolder
				end

				UpdateCustomLayout()
			end

			SetDropdownOptions()
		end

		function initelement:ColorPicker(ColorPicker)
			local data = {Title = ColorPicker.Title; Color = ColorPicker.Color; Color2 = ColorPicker.Color2; Linkable = ColorPicker.Linkable; Type = ColorPicker.Type or 'ColorPicker'; GradientPath = ColorPicker.GradientPath; CallBack = ColorPicker.CallBack; Flag = ColorPicker.Flag}
			ColorPicker.Linkable = ColorPicker.Linkable or true
			local colorpicker = pages.page.ColorPicker:Clone()
			colorpicker.Visible = true
			colorpicker.Parent = Page
			colorpicker.title.Text = data.Title
			colorpicker.Name = data.Title
			colorpicker:SetAttribute("Searchable", true)
			local HueSat = Instance.new("Color3Value")
			HueSat.Name = 'HueSat'
			HueSat.Value = data.Color
			HueSat.Parent = colorpicker
			local Open = false
			local DeBounce = false
			local HSV = {data.Color and data.Color:ToHSV() or {0, 0, 0}}
			local SVPicker = colorpicker.color.SVPicker
			local HUESlider = colorpicker.color.Values.Hue
			local function updatestuff()
				data.Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3])
				colorpicker.color.glow.ImageColor3 = data.Color
				colorpicker.color.BackgroundColor3 = data.Color
				HueSat.Value = data.Color
				if data.CallBack then data.CallBack(data.Color) end
			end
			updatestuff()
			colorpicker.QuickClose.Interactable = false
			tweenservice:Create(colorpicker.color, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundColor3 = data.Color}):Play()
			local function OpenPicker()
				Open = true
				DeBounce = true
				colorpicker.color.Values.Visible = true
				colorpicker.color.SVPicker.Visible = true
				colorpicker.HueValues.Visible = true
				colorpicker.interact.Interactable = false
				colorpicker.QuickClose.Interactable = true
				tweenservice:Create(colorpicker, TweenInfo.new(0.8, Enum.EasingStyle.Quart), {Size = UDim2.new(1, -35,0, 300)}):Play()
				DeBounce = false
			end
			colorpicker.interact.MouseButton1Click:Connect(function()
				if DeBounce then return end
				if not Open then OpenPicker() end
			end)
			local function ClosePicker()
				Open = false
				DeBounce = true
				tweenservice:Create(colorpicker, TweenInfo.new(0.55, Enum.EasingStyle.Quint), {Size = UDim2.new(1, -35,0, 40)}):Play()
				tweenservice:Create(colorpicker.color, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {BackgroundColor3 = data.Color}):Play()
				colorpicker.interact.Interactable = true
				colorpicker.QuickClose.Interactable = false
				task.wait(0.7)
				DeBounce = false
			end
			colorpicker.QuickClose.hitbox.MouseButton1Click:Connect(function()
				if DeBounce then return end
				if Open then ClosePicker() end
			end)
			local SV, HUE = nil, nil
			syde:AddConnection(SVPicker.InputBegan, function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					SV = runservice.RenderStepped:Connect(function()
						local mouse = game.Players.LocalPlayer:GetMouse()
						local ColorX = math.clamp(mouse.X - SVPicker.AbsolutePosition.X, 0, SVPicker.AbsoluteSize.X) / SVPicker.AbsoluteSize.X
						local ColorY = math.clamp(mouse.Y - SVPicker.AbsolutePosition.Y, 0, SVPicker.AbsoluteSize.Y) / SVPicker.AbsoluteSize.Y
						HSV[2] = ColorX
						HSV[3] = 1 - ColorY
						updatestuff()
					end)
				end
			end)
			syde:AddConnection(SVPicker.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 and SV then SV:Disconnect() SV = nil SaveConfig() end end)
			syde:AddConnection(HUESlider.InputBegan, function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					HUE = runservice.RenderStepped:Connect(function()
						local mouse = game.Players.LocalPlayer:GetMouse()
						local ColorX = math.clamp(mouse.X - HUESlider.AbsolutePosition.X, 0, HUESlider.AbsoluteSize.X) / HUESlider.AbsoluteSize.X
						HSV[1] = 1 - ColorX
						updatestuff()
					end)
				end
			end)
			syde:AddConnection(HUESlider.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 and HUE then HUE:Disconnect() HUE = nil SaveConfig() end end)
			function data:Set(RGBColor, skipSave)
				if typeof(RGBColor) ~= "Color3" then return end
				data.Color = RGBColor
				HSV[1], HSV[2], HSV[3] = RGBColor:ToHSV()
				updatestuff()
				if not skipSave then SaveConfig() end
			end
			if syde.ConfigEnabled then if data.Flag then syde.Flags[data.Flag] = data end end
			return data
		end

		function initelement:Paragraph(Paragraph)
			local Para = pages.page.Paragraph:Clone()
			Para.Visible = true
			Para.Parent = Page
			Para.Frame.title.Text = Paragraph.Title
			Para.Content.Text = Paragraph.Content
			Para:SetAttribute("Searchable", true)
		end

		function initelement:Label(Text, Alignment)
			local Label = pages.page.Label:Clone()
			Label.Visible = true
			Label.Parent = Page
			Label.text.Text = Text
			Label:SetAttribute("Searchable", true)
			if Alignment == 'Center' then Label.text.TextXAlignment = Enum.TextXAlignment.Center
			elseif Alignment == 'Right' then Label.text.TextXAlignment = Enum.TextXAlignment.Right end
		end

		function initelement:Section(Title, Icon)
			local Section = pages.page.Section:Clone()
			Section.Visible = true
			Section.Title.Text = Title
			Section.Parent = Page
			if Icon then Section.icon.Image = 'rbxassetid://'..Icon else Section.icon.Visible = false end
		end

		return initelement
	end

	function tbdata:Toggle() ToggleUI() end
	function tbdata:GetState() return not uiclosed end
	function tbdata:SetState(state)
		if state == true and uiclosed then ToggleUI()
		elseif state == false and not uiclosed then ToggleUI() end
	end
	if syde.DefaultCSS then task.defer(function() syde:LoadCSS(syde.DefaultCSS) end) end
	return tbdata
end

syde.__AlleralPatch = ALLERAL_SYDE_PATCH

-- CSS Engine — parse real CSS and apply to Syde UI
function syde:LoadCSS(cssString)
	if type(cssString) ~= "string" then return end
	syde.LastCSS = cssString
	local rules = {}
	cssString = cssString:gsub("/%*.-%*/", "")
	for selector, body in cssString:gmatch("([^{]+)%s*{(.-)}") do
		selector = selector:gsub("^%s+", ""):gsub("%s+$", "")
		local decls = {}
		for prop, value in body:gmatch("([%w%-]+)%s*:%s*([^;]+);?") do
			prop = prop:gsub("^%s+", ""):gsub("%s+$", ""):lower()
			value = value:gsub("^%s+", ""):gsub("%s+$", "")
			decls[prop] = value
		end
		table.insert(rules, {selector = selector, decls = decls})
	end

	local function matches(el, sel)
		if not el or not el:IsA("GuiObject") then return false end
		local name = el.Name:lower()
		-- Auto-detect element type from parent template name
		local detectedClass = el:GetAttribute("Class") or ""
		if detectedClass == "" then
			local parent = el.Parent
			if parent and parent:IsA("Frame") then
				local pn = parent.Name:lower()
				if pn == "toggle" or pn == "button" or pn == "slider" or pn == "dropdown"
					or pn == "keybind" or pn == "colorpicker" or pn == "input"
					or pn == "paragraph" or pn == "section" or pn == "label" then
					detectedClass = "syde-" .. pn
				end
			end
		end
		for part in sel:gmatch("[^%s]+") do
			part = part:lower()
			if part:sub(1,1) == "." then
				local cls = " "..detectedClass:lower().." "
				if not cls:find(" "..part:sub(2).." ") then return false end
			elseif part:sub(1,1) == "#" then
				local id = el:GetAttribute("ID") or ""
				if id:lower() ~= part:sub(2) then return false end
			elseif part ~= "*" and name ~= part then
				return false
			end
		end
		return true
	end

	local function apply(el, prop, value)
		local n = tonumber(value:match("%d+"))
		local t = el:GetAttribute("CSSTransition") or 0.3
		local function tween(p, v) tweenservice:Create(el, TweenInfo.new(t, Enum.EasingStyle.Exponential), {[p] = v}):Play() end
		if prop == "background-color" or prop == "background" then
			if value:match("^#[%x]+") then tween("BackgroundColor3", Color3.fromHex(value)) end
		elseif prop == "color" or prop == "text-color" then
			if value:match("^#[%x]+") then tween("TextColor3", Color3.fromHex(value)) end
		elseif prop == "border-color" then
			if value:match("^#[%x]+") then tween("BorderColor3", Color3.fromHex(value)) end
		elseif prop == "font-size" and n then
			pcall(function() el.TextSize = n end)
		elseif prop == "border-radius" and n then
			local corner = el:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, n)
			pcall(function() corner.Parent = el end)
		elseif prop == "border-size" and n then
			pcall(function() el.BorderSizePixel = n end)
		elseif prop == "opacity" and n then
			local o = 1 - math.clamp(n > 1 and n/100 or n, 0, 1)
			tween("BackgroundTransparency", o)
			tween("TextTransparency", o)
			tween("ImageTransparency", o)
		elseif prop == "transition" and n then
			el:SetAttribute("CSSTransition", n)
		elseif prop == "font-weight" and (value == "bold" or value == "700") then
			pcall(function() el.RichText = true end)
		end
	end

	local function walk(instance)
		if not instance or not instance:IsA("GuiObject") then return end
		for _, rule in ipairs(rules) do
			if matches(instance, rule.selector) then
				for prop, value in pairs(rule.decls) do
					apply(instance, prop, value)
				end
			end
		end
		for _, child in ipairs(instance:GetChildren()) do
			walk(child)
		end
	end

	if ui and ui:IsA("Instance") then walk(ui) end
	end

	-- Re-apply CSS after class changes (lightweight, walks entire tree)
	function syde:ReapplyCSS()
		if syde.LastCSS and ui and ui:IsA("Instance") then
			syde:LoadCSS(syde.LastCSS)
		end
	end

	return syde
