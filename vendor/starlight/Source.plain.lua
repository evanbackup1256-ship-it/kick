--[[ Starlight bundle — edit vendor/starlight/lib/ then run bundle.py ]]


local modules = {}
local function requireModule(name)
	return modules[name]
end

do
	modules['util'] = (function()
local Util = {}

function Util.deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = Util.deepCopy(child)
	end
	return copy
end

function Util.clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

function Util.isEmpty(text)
	return text == nil or tostring(text) == ""
end

function Util.trim(text)
	return tostring(text or ""):gsub("^%s*(.-)%s*$", "%1")
end

function Util.iconAsset(icon)
	if Util.isEmpty(icon) then
		return ""
	end
	local text = tostring(icon)
	if text:find("rbxassetid://") then
		return text
	end
	local digits = text:match("%d+$")
	return digits and ("rbxassetid://" .. digits) or text
end

function Util.safeCall(label, callback, onError)
	local ok, result = pcall(callback)
	if not ok and onError then
		onError(label, result)
	end
	return ok, result
end

function Util.merge(base, overrides)
	local merged = Util.deepCopy(base)
	for key, value in pairs(overrides or {}) do
		merged[key] = value
	end
	return merged
end

function Util.new(className, props, children)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		if typeof(child) == "Instance" then
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Util.corner(radius, parent)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function Util.padding(top, right, bottom, left, parent)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, top)
	pad.PaddingRight = UDim.new(0, right or top)
	pad.PaddingBottom = UDim.new(0, bottom or top)
	pad.PaddingLeft = UDim.new(0, left or right or top)
	pad.Parent = parent
	return pad
end

function Util.stroke(color, thickness, transparency, parent)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Util.gradient(colorSequence, rotation, parent)
	local gradient = Instance.new("UIGradient")
	gradient.Color = colorSequence
	gradient.Rotation = rotation or 0
	gradient.Parent = parent
	return gradient
end

function Util.list(padding, horizontal, parent)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding or 6)
	layout.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function Util.fontFace(weight)
	weight = weight or Enum.FontWeight.Medium
	local ok, font = pcall(function()
		return Font.new("rbxassetid://12187365364", weight)
	end)
	if ok and font then
		return font
	end
	if weight == Enum.FontWeight.SemiBold or weight == Enum.FontWeight.Bold then
		return Enum.Font.GothamBold
	end
	return Enum.Font.GothamMedium
end

function Util.divider(parent, theme, layoutOrder)
	local t = theme and theme.Transparency
	return Util.new("Frame", {
		BackgroundColor3 = (theme and theme.Miscellaneous.Divider) or Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = (t and t.Divider) or 0.9,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = layoutOrder,
	}, { parent })
end

function Util.text(props)
	local label = Util.new("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = props.FontFace or Util.fontFace(props.FontWeight or Enum.FontWeight.Medium),
		Font = props.Font,
		Text = props.Text or "",
		TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255),
		TextTransparency = props.TextTransparency or 0,
		TextSize = props.TextSize or 14,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		TextWrapped = props.TextWrapped == true,
		TextTruncate = props.TextTruncate,
		RichText = props.RichText == true,
		Size = props.Size or UDim2.new(1, 0, 0, 20),
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = props.AutomaticSize,
	})
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

function Util.button(props)
	local frame = Util.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(42, 44, 52),
		BackgroundTransparency = props.BackgroundTransparency or 0,
		BorderSizePixel = 0,
		Text = "",
		Size = props.Size or UDim2.new(1, 0, 0, 34),
		LayoutOrder = props.LayoutOrder,
	})
	Util.corner(props.Radius or 8, frame)
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

function Util.inputBox(props)
	local box = Util.new("TextBox", {
		AutoButtonColor = false,
		BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(38, 38, 48),
		BackgroundTransparency = props.BackgroundTransparency or 0,
		BorderSizePixel = 0,
		ClearTextOnFocus = props.ClearTextOnFocus == true,
		Font = props.Font or Enum.Font.Gotham,
		PlaceholderText = props.PlaceholderText or "",
		Text = props.Text or "",
		TextColor3 = props.TextColor3 or Color3.fromRGB(240, 240, 245),
		TextTransparency = 0,
		PlaceholderColor3 = props.PlaceholderColor3 or Color3.fromRGB(120, 120, 135),
		TextSize = props.TextSize or 13,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		Size = props.Size or UDim2.fromScale(1, 1),
	})
	Util.corner(props.Radius or 6, box)
	if props.Parent then
		box.Parent = props.Parent
	end
	return box
end

return Util

	end)()
end

do
	modules['theme'] = (function()
local Util = requireModule('util')

local Theme = {}

Theme.Assets = {
	Inter = "rbxassetid://12187365364",
	ToggleBackground = "rbxassetid://18772190202",
	ToggleHead = "rbxassetid://18772309008",
	ButtonArrow = "rbxassetid://10709791437",
	MoveIcon = "rbxassetid://10734900011",
}

Theme.Palettes = {
	Alleral = {
		Accent = Color3.fromRGB(255, 255, 255),
		AccentSoft = Color3.fromRGB(200, 200, 210),
		Backgrounds = {
			Dark = Color3.fromRGB(15, 15, 15),
			Medium = Color3.fromRGB(15, 15, 15),
			Light = Color3.fromRGB(255, 255, 255),
			Groupbox = Color3.fromRGB(255, 255, 255),
			Highlight = Color3.fromRGB(255, 255, 255),
			Elevated = Color3.fromRGB(15, 15, 15),
		},
		Foregrounds = {
			Active = Color3.fromRGB(255, 255, 255),
			Light = Color3.fromRGB(255, 255, 255),
			Medium = Color3.fromRGB(255, 255, 255),
			Dark = Color3.fromRGB(255, 255, 255),
			MediumHover = Color3.fromRGB(255, 255, 255),
			DarkHover = Color3.fromRGB(255, 255, 255),
		},
		Miscellaneous = {
			Divider = Color3.fromRGB(255, 255, 255),
			Shadow = Color3.fromRGB(0, 0, 0),
			TrafficClose = Color3.fromRGB(250, 93, 86),
			TrafficMinimize = Color3.fromRGB(252, 190, 57),
			TrafficMaximize = Color3.fromRGB(119, 174, 94),
			ToggleOff = Color3.fromRGB(61, 61, 61),
			ToggleOn = Color3.fromRGB(87, 86, 86),
			ToggleHeadOff = Color3.fromRGB(91, 91, 91),
			ToggleHeadOn = Color3.fromRGB(255, 255, 255),
			Success = Color3.fromRGB(119, 174, 94),
			Warning = Color3.fromRGB(252, 190, 57),
			Danger = Color3.fromRGB(250, 93, 86),
		},
		Transparency = {
			Title = 0.2,
			Subtitle = 0.7,
			Tab = 0.4,
			TabActive = 0.2,
			Label = 0.5,
			LabelHover = 0.3,
			Divider = 0.9,
			Stroke = 0.9,
			Section = 0.98,
			SectionStroke = 0.95,
			Input = 0.95,
			Window = 0.05,
		},
	},
	Midnight = {
		Accent = Color3.fromRGB(168, 85, 247),
		AccentSoft = Color3.fromRGB(192, 132, 252),
		Backgrounds = {
			Dark = Color3.fromRGB(12, 10, 18),
			Medium = Color3.fromRGB(12, 10, 18),
			Light = Color3.fromRGB(255, 255, 255),
			Groupbox = Color3.fromRGB(255, 255, 255),
			Highlight = Color3.fromRGB(34, 30, 48),
			Elevated = Color3.fromRGB(18, 16, 26),
		},
		Foregrounds = {
			Active = Color3.fromRGB(255, 255, 255),
			Light = Color3.fromRGB(236, 232, 248),
			Medium = Color3.fromRGB(164, 156, 188),
			Dark = Color3.fromRGB(96, 88, 118),
			MediumHover = Color3.fromRGB(196, 188, 220),
			DarkHover = Color3.fromRGB(124, 116, 148),
		},
		Miscellaneous = {
			Divider = Color3.fromRGB(255, 255, 255),
			Shadow = Color3.fromRGB(0, 0, 0),
			TrafficClose = Color3.fromRGB(250, 93, 86),
			TrafficMinimize = Color3.fromRGB(252, 190, 57),
			TrafficMaximize = Color3.fromRGB(119, 174, 94),
			ToggleOff = Color3.fromRGB(61, 61, 61),
			ToggleOn = Color3.fromRGB(124, 58, 237),
			ToggleHeadOff = Color3.fromRGB(91, 91, 91),
			ToggleHeadOn = Color3.fromRGB(255, 255, 255),
			Success = Color3.fromRGB(52, 211, 153),
			Warning = Color3.fromRGB(251, 191, 36),
			Danger = Color3.fromRGB(248, 113, 113),
		},
		Transparency = {
			Title = 0.2,
			Subtitle = 0.7,
			Tab = 0.4,
			TabActive = 0.15,
			Label = 0.5,
			LabelHover = 0.3,
			Divider = 0.9,
			Stroke = 0.9,
			Section = 0.97,
			SectionStroke = 0.92,
			Input = 0.95,
			Window = 0.05,
		},
	},
	Aurora = {
		Accent = Color3.fromRGB(45, 212, 191),
		AccentSoft = Color3.fromRGB(94, 234, 212),
		Backgrounds = {
			Dark = Color3.fromRGB(10, 16, 18),
			Medium = Color3.fromRGB(10, 16, 18),
			Light = Color3.fromRGB(255, 255, 255),
			Groupbox = Color3.fromRGB(255, 255, 255),
			Highlight = Color3.fromRGB(24, 42, 48),
			Elevated = Color3.fromRGB(14, 22, 26),
		},
		Foregrounds = {
			Active = Color3.fromRGB(255, 255, 255),
			Light = Color3.fromRGB(230, 250, 246),
			Medium = Color3.fromRGB(148, 188, 182),
			Dark = Color3.fromRGB(88, 118, 114),
			MediumHover = Color3.fromRGB(178, 214, 208),
			DarkHover = Color3.fromRGB(108, 142, 136),
		},
		Miscellaneous = {
			Divider = Color3.fromRGB(255, 255, 255),
			Shadow = Color3.fromRGB(0, 0, 0),
			TrafficClose = Color3.fromRGB(250, 93, 86),
			TrafficMinimize = Color3.fromRGB(252, 190, 57),
			TrafficMaximize = Color3.fromRGB(119, 174, 94),
			ToggleOff = Color3.fromRGB(61, 61, 61),
			ToggleOn = Color3.fromRGB(20, 184, 166),
			ToggleHeadOff = Color3.fromRGB(91, 91, 91),
			ToggleHeadOn = Color3.fromRGB(255, 255, 255),
			Success = Color3.fromRGB(52, 211, 153),
			Warning = Color3.fromRGB(251, 191, 36),
			Danger = Color3.fromRGB(248, 113, 113),
		},
		Transparency = {
			Title = 0.2,
			Subtitle = 0.7,
			Tab = 0.4,
			TabActive = 0.15,
			Label = 0.5,
			LabelHover = 0.3,
			Divider = 0.9,
			Stroke = 0.9,
			Section = 0.97,
			SectionStroke = 0.92,
			Input = 0.95,
			Window = 0.05,
		},
	},
	Rose = {
		Accent = Color3.fromRGB(244, 114, 182),
		AccentSoft = Color3.fromRGB(251, 182, 206),
		Backgrounds = {
			Dark = Color3.fromRGB(16, 10, 14),
			Medium = Color3.fromRGB(16, 10, 14),
			Light = Color3.fromRGB(255, 255, 255),
			Groupbox = Color3.fromRGB(255, 255, 255),
			Highlight = Color3.fromRGB(48, 24, 38),
			Elevated = Color3.fromRGB(24, 14, 20),
		},
		Foregrounds = {
			Active = Color3.fromRGB(255, 255, 255),
			Light = Color3.fromRGB(252, 236, 244),
			Medium = Color3.fromRGB(196, 156, 176),
			Dark = Color3.fromRGB(118, 84, 102),
			MediumHover = Color3.fromRGB(220, 184, 202),
			DarkHover = Color3.fromRGB(142, 104, 124),
		},
		Miscellaneous = {
			Divider = Color3.fromRGB(255, 255, 255),
			Shadow = Color3.fromRGB(0, 0, 0),
			TrafficClose = Color3.fromRGB(250, 93, 86),
			TrafficMinimize = Color3.fromRGB(252, 190, 57),
			TrafficMaximize = Color3.fromRGB(119, 174, 94),
			ToggleOff = Color3.fromRGB(61, 61, 61),
			ToggleOn = Color3.fromRGB(219, 39, 119),
			ToggleHeadOff = Color3.fromRGB(91, 91, 91),
			ToggleHeadOn = Color3.fromRGB(255, 255, 255),
			Success = Color3.fromRGB(52, 211, 153),
			Warning = Color3.fromRGB(251, 191, 36),
			Danger = Color3.fromRGB(248, 113, 113),
		},
		Transparency = {
			Title = 0.2,
			Subtitle = 0.7,
			Tab = 0.4,
			TabActive = 0.15,
			Label = 0.5,
			LabelHover = 0.3,
			Divider = 0.9,
			Stroke = 0.9,
			Section = 0.97,
			SectionStroke = 0.92,
			Input = 0.95,
			Window = 0.05,
		},
	},
	Starlight = {
		Accent = Color3.fromRGB(99, 132, 255),
		AccentSoft = Color3.fromRGB(72, 98, 196),
		Backgrounds = {
			Dark = Color3.fromRGB(14, 15, 18),
			Medium = Color3.fromRGB(14, 15, 18),
			Light = Color3.fromRGB(255, 255, 255),
			Groupbox = Color3.fromRGB(255, 255, 255),
			Highlight = Color3.fromRGB(36, 40, 52),
			Elevated = Color3.fromRGB(20, 22, 28),
		},
		Foregrounds = {
			Active = Color3.fromRGB(255, 255, 255),
			Light = Color3.fromRGB(240, 242, 248),
			Medium = Color3.fromRGB(156, 160, 174),
			Dark = Color3.fromRGB(92, 98, 114),
			MediumHover = Color3.fromRGB(196, 200, 212),
			DarkHover = Color3.fromRGB(118, 124, 142),
		},
		Miscellaneous = {
			Divider = Color3.fromRGB(255, 255, 255),
			Shadow = Color3.fromRGB(0, 0, 0),
			TrafficClose = Color3.fromRGB(250, 93, 86),
			TrafficMinimize = Color3.fromRGB(252, 190, 57),
			TrafficMaximize = Color3.fromRGB(119, 174, 94),
			ToggleOff = Color3.fromRGB(61, 61, 61),
			ToggleOn = Color3.fromRGB(99, 132, 255),
			ToggleHeadOff = Color3.fromRGB(91, 91, 91),
			ToggleHeadOn = Color3.fromRGB(255, 255, 255),
			Success = Color3.fromRGB(72, 199, 142),
			Warning = Color3.fromRGB(255, 184, 77),
			Danger = Color3.fromRGB(255, 96, 112),
		},
		Transparency = {
			Title = 0.2,
			Subtitle = 0.7,
			Tab = 0.4,
			TabActive = 0.15,
			Label = 0.5,
			LabelHover = 0.3,
			Divider = 0.9,
			Stroke = 0.9,
			Section = 0.97,
			SectionStroke = 0.92,
			Input = 0.95,
			Window = 0.05,
		},
	},
}

Theme.Visual = {
	ThemeName = "Alleral",
	Accent = Theme.Palettes.Alleral.Accent,
	CornerRadius = 6,
	GroupboxRadius = 8,
	WindowTransparency = 0,
	GroupboxTransparency = 0.98,
	BlurEnabled = true,
	BlurSize = 16,
	AnimationSpeed = 1,
	FontScale = 1,
	CompactMode = false,
	ShowShadows = true,
	SidebarWidth = 0.325,
}

function Theme.current()
	local palette = Util.deepCopy(Theme.Palettes[Theme.Visual.ThemeName] or Theme.Palettes.Alleral)
	palette.Accent = Theme.Visual.Accent
	if not palette.Transparency then
		palette.Transparency = Theme.Palettes.Alleral.Transparency
	end
	return palette
end

function Theme.applyAccent(color)
	Theme.Visual.Accent = color
	local palette = Theme.Palettes[Theme.Visual.ThemeName]
	if palette then
		palette.Accent = color
	end
end

function Theme.setTheme(name)
	if Theme.Palettes[name] then
		Theme.Visual.ThemeName = name
		Theme.Visual.Accent = Theme.Palettes[name].Accent
	end
end

function Theme.tweenInfo(time, style, direction)
	local speed = Theme.Visual.AnimationSpeed
	return TweenInfo.new((time or 0.2) / speed, style or Enum.EasingStyle.Sine, direction or Enum.EasingDirection.Out)
end

return Theme

	end)()
end

do
	modules['tween'] = (function()
local TweenService = game:GetService("TweenService")
local Theme = requireModule('theme')

local Tween = {}

function Tween.set(instance, props)
	if not instance or type(props) ~= "table" then
		return
	end
	for key, value in pairs(props) do
		pcall(function()
			instance[key] = value
		end)
	end
end

function Tween.play(instance, goal, callback, info)
	if not instance or type(goal) ~= "table" then
		if callback then
			callback()
		end
		return nil
	end

	Tween.set(instance, goal)

	local tween
	local ok = pcall(function()
		tween = TweenService:Create(instance, info or Theme.tweenInfo(), goal)
	end)
	if ok and tween then
		if callback then
			tween.Completed:Once(callback)
		end
		tween:Play()
	end
	return tween
end

function Tween.fade(instance, visible, callback)
	local props = {}
	if instance:IsA("GuiObject") then
		props.BackgroundTransparency = visible and (instance:GetAttribute("TargetTransparency") or 0) or 1
	end
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		props.TextTransparency = visible and 0 or 1
	end
	if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		props.ImageTransparency = visible and 0 or 1
	end
	return Tween.play(instance, props, callback, Theme.tweenInfo(0.2))
end

return Tween

	end)()
end

do
	modules['filesystem'] = (function()
local HttpService = game:GetService("HttpService")

local FileSystem = {}
FileSystem.Folder = "Starlight Interface Suite"
FileSystem.FileExtension = ".starlight"
FileSystem.AutoloadConfigPath = nil
FileSystem.AutoloadThemePath = nil

local function hasFileApi()
	return type(writefile) == "function"
end

local function writeFile(path, data)
	local fn = writefile
	if fn then
		return pcall(fn, path, data)
	end
	return false
end

local function readFile(path)
	local fn = readfile
	if fn and isfile and isfile(path) then
		local ok, data = pcall(fn, path)
		return ok and data or nil
	end
	return nil
end

local function makeFolder(path)
	local fn = makefolder
	if not fn or not path or path == "" then
		return
	end
	local parts = string.split(path:gsub("\\", "/"), "/")
	local built = ""
	for _, part in ipairs(parts) do
		if part ~= "" then
			built = built == "" and part or (built .. "/" .. part)
			pcall(fn, built)
		end
	end
end

function FileSystem:BuildFolderTree(fileSettings)
	if not hasFileApi() then
		return
	end
	local root = fileSettings and fileSettings.RootFolder
	local configFolder = fileSettings and fileSettings.ConfigFolder or "configs"
	local base = self.Folder
	if root then
		base = base .. "/" .. root
	end
	makeFolder(self.Folder)
	makeFolder(base)
	makeFolder(base .. "/" .. configFolder)
	makeFolder(base .. "/" .. configFolder .. "/configs")
	makeFolder(base .. "/themes")
	self.AutoloadConfigPath = base .. "/" .. configFolder .. "/configs/"
	self.AutoloadThemePath = base .. "/themes/"
end

function FileSystem:SaveConfig(file, path, library)
	if not hasFileApi() then
		return false
	end
	local payload = {}
	local window = library and library.Window
	for sectionName, section in pairs((window and window.TabSections) or {}) do
		for _, tab in pairs(section.Tabs or {}) do
			for _, groupbox in pairs(tab.Groupboxes or {}) do
				for index, element in pairs(groupbox.Elements or {}) do
					if element.Class and element.Values and not element.IgnoreConfig then
						local data = {}
						if element.Class == "Toggle" or element.Class == "Slider" or element.Class == "Input" then
							data.CurrentValue = element.Values.CurrentValue
						elseif element.Class == "Dropdown" then
							data.CurrentOption = element.Values.CurrentOption or element.Values.CurrentOptions
						elseif element.Class == "ColorPicker" then
							local c = element.Values.CurrentValue
							data.CurrentValue = { c.R, c.G, c.B }
							data.Transparency = element.Values.Transparency
						end
						table.insert(payload, {
							path = sectionName .. "." .. (tab.Index or "") .. "." .. (groupbox.Index or "") .. "." .. tostring(index),
							type = element.Class,
							data = data,
						})
					end
				end
			end
		end
	end
	local target = (path or self.AutoloadConfigPath or "") .. file .. self.FileExtension
	local folder = (path or self.AutoloadConfigPath or ""):gsub("/+$", "")
	if folder ~= "" then
		makeFolder(folder)
	end
	return writeFile(target, HttpService:JSONEncode(payload))
end

function FileSystem:LoadConfig(file, path, library)
	local target = (path or self.AutoloadConfigPath or "") .. file .. self.FileExtension
	local raw = readFile(target)
	if not raw then
		return false
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		return false
	end
	local window = library and library.Window
	for _, entry in ipairs(decoded) do
		local parts = string.split(entry.path or "", ".")
		local section = window and window.TabSections[parts[1]]
		local tab = section and section.Tabs[parts[2]]
		local groupbox = tab and tab.Groupboxes[parts[3]]
		local element = groupbox and groupbox.Elements[parts[4]]
		if element and element.Set and entry.data then
			if entry.type == "ColorPicker" and type(entry.data.CurrentValue) == "table" then
				local c = entry.data.CurrentValue
				entry.data.CurrentValue = Color3.new(c[1], c[2], c[3])
			end
			element:Set(entry.data)
		end
	end
	return true
end

function FileSystem:RefreshConfigList(path)
	local folder = path or self.AutoloadConfigPath
	if not listfiles or not folder then
		return {}
	end
	local ok, files = pcall(listfiles, folder)
	if not ok or type(files) ~= "table" then
		return {}
	end
	local names = {}
	for _, file in ipairs(files) do
		if file:sub(-#self.FileExtension) == self.FileExtension then
			table.insert(names, file:match("([^/\\]+)" .. self.FileExtension:gsub("%.", "%%.") .. "$") or file)
		end
	end
	table.sort(names)
	return names
end

return FileSystem

	end)()
end

do
	modules['notification'] = (function()
local Util = requireModule('util')
local Theme = requireModule('theme')
local Tween = requireModule('tween')

local Notification = {}
Notification._container = nil

function Notification.init(gui, library)
	Notification._library = library
	Notification._container = Util.new("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 500,
	}, { gui })

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = Notification._container

	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 10)
	pad.Parent = Notification._container
end

function Notification.show(data)
	if not Notification._container then
		return
	end
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	data = data or {}

	local card = Util.new("Frame", {
		Name = "Notification",
		BackgroundColor3 = theme.Backgrounds.Dark,
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 500,
	}, { Notification._container })
	Util.corner(Theme.Visual.CornerRadius, card)
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, card)
	Util.padding(14, 14, 14, 14, card)
	Util.list(4, false, card)

	Util.text({
		Parent = card,
		Text = data.Title or "Notification",
		FontWeight = Enum.FontWeight.SemiBold,
		TextSize = 14 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Title,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	Util.text({
		Parent = card,
		Text = data.Content or "",
		TextWrapped = true,
		TextSize = 13 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Subtitle,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	local duration = data.Duration or math.clamp((#tostring(data.Content or "") * 0.08) + 3, 3, 12)
	task.delay(duration, function()
		if card.Parent then
			card:Destroy()
		end
	end)
	return card
end

return Notification

	end)()
end

do
	modules['elements'] = (function()
local UserInputService = game:GetService("UserInputService")
local Util = requireModule('util')
local Theme = requireModule('theme')
local Tween = requireModule('tween')

local Elements = {}

function Elements.runCallback(windowSettings, label, callback, library)
	local ok, err = pcall(callback)
	if not ok and windowSettings.NotifyOnCallbackError ~= false then
		warn("[Starlight] Callback error:", err)
		if library and library.Notification then
			library:Notification({
				Title = label .. " Error",
				Content = tostring(err),
				Icon = 6031075938,
			})
		end
	end
	return ok, err
end

function Elements.createRow(parent, settings, theme)
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local height = Theme.Visual.CompactMode and 34 or 38
	local row = Util.new("Frame", {
		Name = settings.Name or "Row",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = settings.LayoutOrder or 0,
	}, { parent })

	local label = Util.text({
		Parent = row,
		Text = settings.Name or "",
		FontWeight = Enum.FontWeight.Medium,
		TextSize = 13 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Label,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, -120, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	label.Name = "Header"

	if not Util.isEmpty(settings.Icon) then
		Util.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Util.iconAsset(settings.Icon),
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromOffset(0, 12),
			ImageColor3 = theme.Foregrounds.Light,
			ImageTransparency = transp.Label,
		}, { row })
		label.Position = UDim2.fromOffset(20, 0.5)
		label.Size = UDim2.new(1, -140, 0, 0)
	end

	local slot = Util.new("Frame", {
		Name = "ElementContainer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(120, 26),
	}, { row })

	local dropdownHolder = Util.new("Frame", {
		Name = "DropdownHolder",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 1, 4),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = true,
	}, { row })
	Util.list(6, false, dropdownHolder)

	return row, label, slot, dropdownHolder
end

function Elements.glassBox(parent, theme, size)
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local box = Util.new("Frame", {
		BackgroundColor3 = theme.Backgrounds.Light,
		BackgroundTransparency = transp.Input,
		Size = size or UDim2.fromScale(1, 1),
	}, { parent })
	Util.corner(4, box)
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, box)
	return box
end

function Elements.createToggle(groupbox, settings, index, windowSettings, library)
	local theme = Theme.current()
	local element = { Class = "Toggle", Values = settings, NestedElements = {} }
	settings.CurrentValue = settings.CurrentValue == true
	settings.Callback = settings.Callback or function() end

	local row, label = Elements.createRow(groupbox.ParentingItem, settings, theme)
	element.Instance = row
	local slot = row:FindFirstChild("ElementContainer")

	local toggleBtn = Util.new("ImageButton", {
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(41, 21),
		BackgroundTransparency = 1,
		Image = Theme.Assets.ToggleBackground,
		ImageColor3 = theme.Miscellaneous.ToggleOff,
	}, { slot })

	local head = Util.new("ImageLabel", {
		Name = "TogglerHead",
		BackgroundTransparency = 1,
		Image = Theme.Assets.ToggleHead,
		ImageColor3 = theme.Miscellaneous.ToggleHeadOff,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(15, 15),
		ZIndex = 2,
	}, { toggleBtn })

	local function paint(on)
		toggleBtn.ImageColor3 = on and theme.Miscellaneous.ToggleOn or theme.Miscellaneous.ToggleOff
		head.ImageColor3 = on and theme.Miscellaneous.ToggleHeadOn or theme.Miscellaneous.ToggleHeadOff
		head.Position = on and UDim2.new(1, 0, 0.5, 0) or UDim2.new(0.5, 0, 0.5, 0)
		Tween.play(toggleBtn, { ImageColor3 = toggleBtn.ImageColor3 }, nil, Theme.tweenInfo(0.2))
		Tween.play(head, { ImageColor3 = head.ImageColor3, Position = head.Position }, nil, Theme.tweenInfo(0.2))
	end
	paint(settings.CurrentValue)

	toggleBtn.MouseButton1Click:Connect(function()
		settings.CurrentValue = not settings.CurrentValue
		paint(settings.CurrentValue)
		Elements.runCallback(windowSettings, settings.Name or "Toggle", function()
			settings.Callback(settings.CurrentValue)
		end, library)
	end)

	function element:Set(newSettings)
		for key, value in pairs(element.Values) do
			newSettings[key] = newSettings[key] ~= nil and newSettings[key] or value
		end
		element.Values = newSettings
		settings = newSettings
		label.Text = settings.Name or label.Text
		paint(settings.CurrentValue == true)
	end
	function element:Destroy()
		row:Destroy()
	end

	groupbox.Elements[index] = element
	return element
end

function Elements.createSlider(groupbox, settings, index, windowSettings, library)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local element = { Class = "Slider", Values = settings, NestedElements = {} }
	local minValue = settings.Range and settings.Range[1] or 0
	local maxValue = settings.Range and settings.Range[2] or 100
	local increment = settings.Increment or 1
	settings.CurrentValue = Util.clamp(settings.CurrentValue or minValue, minValue, maxValue)

	local function snapValue(raw)
		local steps = math.floor((raw - minValue) / increment + 0.5)
		return Util.clamp(minValue + steps * increment, minValue, maxValue)
	end

	local row, label = Elements.createRow(groupbox.ParentingItem, settings, theme)
	element.Instance = row
	local slot = row:FindFirstChild("ElementContainer")
	slot.Size = UDim2.fromOffset(150, 26)

	local valueBox = Util.new("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(41, 21),
		BackgroundColor3 = theme.Backgrounds.Light,
		BackgroundTransparency = transp.Input,
		BorderSizePixel = 0,
		FontFace = Util.fontFace(Enum.FontWeight.Medium),
		Text = tostring(settings.CurrentValue),
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = 0.4,
		TextSize = 12 * Theme.Visual.FontScale,
		ClearTextOnFocus = false,
	}, { slot })
	Util.corner(4, valueBox)
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, valueBox)

	local bar = Util.new("Frame", {
		BackgroundColor3 = theme.Miscellaneous.ToggleOff,
		Size = UDim2.new(1, -48, 0, 4),
		Position = UDim2.new(0, 0, 0.5, -2),
	}, { slot })
	Util.corner(999, bar)

	local fill = Util.new("Frame", {
		BackgroundColor3 = theme.Foregrounds.Light,
		BackgroundTransparency = 0.5,
		Size = UDim2.new(0, 0, 1, 0),
	}, { bar })
	Util.corner(999, fill)

	local dragging = false
	local function setValue(raw, fire)
		settings.CurrentValue = snapValue(raw)
		local alpha = (settings.CurrentValue - minValue) / math.max(maxValue - minValue, increment)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		valueBox.Text = tostring(settings.CurrentValue)
		if fire and settings.Callback then
			Elements.runCallback(windowSettings, settings.Name or "Slider", function()
				settings.Callback(settings.CurrentValue)
			end, library)
		end
	end
	setValue(settings.CurrentValue, false)

	local hit = Util.button({
		Parent = bar,
		Size = UDim2.new(1, 0, 4, 0),
		Position = UDim2.new(0, 0, 0.5, -2),
		BackgroundTransparency = 1,
		Radius = 999,
	})
	hit.ZIndex = 3
	hit.MouseButton1Down:Connect(function()
		dragging = true
		local mouse = UserInputService:GetMouseLocation()
		local rel = Util.clamp((mouse.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		setValue(minValue + (maxValue - minValue) * rel, true)
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			setValue(settings.CurrentValue, true)
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local rel = Util.clamp((input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
			setValue(minValue + (maxValue - minValue) * rel, dragging)
		end
	end)

	function element:Set(newSettings)
		for key, value in pairs(element.Values) do
			newSettings[key] = newSettings[key] ~= nil and newSettings[key] or value
		end
		element.Values = newSettings
		settings = newSettings
		if newSettings.Range then
			minValue = settings.Range[1] or minValue
			maxValue = settings.Range[2] or maxValue
		end
		if newSettings.Increment then
			increment = newSettings.Increment
		end
		label.Text = settings.Name or label.Text
		setValue(settings.CurrentValue, false)
	end
	function element:Destroy()
		row:Destroy()
	end

	groupbox.Elements[index] = element
	return element
end

function Elements.createButton(groupbox, settings, index, windowSettings, library)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local element = { Class = "Button", Values = settings, NestedElements = {} }

	local row = Util.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Theme.Visual.CompactMode and 34 or 38),
	}, { groupbox.ParentingItem })
	element.Instance = row

	local btn = Util.new("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	}, { row })

	local label = Util.text({
		Parent = btn,
		Text = settings.Name or "Button",
		FontWeight = Enum.FontWeight.Medium,
		TextSize = 13 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Label,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -20, 1, 0),
	})

	Util.new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Theme.Assets.ButtonArrow,
		ImageTransparency = transp.Label,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(15, 15),
	}, { btn })

	btn.MouseEnter:Connect(function()
		label.TextTransparency = transp.LabelHover
	end)
	btn.MouseLeave:Connect(function()
		label.TextTransparency = transp.Label
	end)
	btn.MouseButton1Click:Connect(function()
		Elements.runCallback(windowSettings, settings.Name or "Button", settings.Callback or function() end, library)
	end)

	function element:Set(newSettings)
		element.Values = Util.merge(element.Values, newSettings)
		label.Text = element.Values.Name or "Button"
	end
	function element:Destroy()
		row:Destroy()
	end
	groupbox.Elements[index] = element
	return element
end

function Elements.createInput(groupbox, settings, index, windowSettings, library)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local element = { Class = "Input", Values = settings, NestedElements = {} }
	settings.CurrentValue = settings.CurrentValue or settings.Placeholder or ""

	local row, label = Elements.createRow(groupbox.ParentingItem, settings, theme)
	element.Instance = row
	local slot = row:FindFirstChild("ElementContainer")
	slot.Size = UDim2.fromOffset(160, 26)

	local box = Util.inputBox({
		Parent = slot,
		BackgroundColor3 = theme.Backgrounds.Light,
		BackgroundTransparency = transp.Input,
		PlaceholderText = settings.PlaceholderText or settings.Placeholder or "",
		Text = settings.CurrentValue,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = 0.4,
		TextSize = 13 * Theme.Visual.FontScale,
		ClearTextOnFocus = settings.RemoveTextOnFocus == true,
		Radius = 4,
	})
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, box)
	Util.padding(0, 8, 0, 8, box)

	box.FocusLost:Connect(function()
		settings.CurrentValue = box.Text
		Elements.runCallback(windowSettings, settings.Name or "Input", function()
			settings.Callback(settings.CurrentValue)
		end, library)
	end)

	function element:Set(newSettings)
		element.Values = Util.merge(element.Values, newSettings)
		label.Text = element.Values.Name or label.Text
		if newSettings.CurrentValue ~= nil then
			box.Text = newSettings.CurrentValue
		end
	end
	function element:Destroy()
		row:Destroy()
	end
	groupbox.Elements[index] = element
	return element
end

function Elements.createLabel(groupbox, settings, index, windowSettings, library)
	local theme = Theme.current()
	local element = { Class = "Label", Values = settings, NestedElements = {} }
	local row, label, slot, dropdownHolder = Elements.createRow(groupbox.ParentingItem, settings, theme)
	element.Instance = row
	slot.Visible = false
	slot.Size = UDim2.fromOffset(0, 0)

	function element:Set(newSettings)
		element.Values = Util.merge(element.Values, newSettings)
		label.Text = element.Values.Name or ""
	end
	function element:Destroy()
		row:Destroy()
	end
	function element:Lock(reason)
		label.Text = reason or element.Values.Name or ""
	end
	function element:Unlock()
		label.Text = element.Values.Name or ""
	end
	function element:AddDropdown(nestedSettings, nestedIndex)
		return Elements.createDropdown(groupbox, nestedSettings, nestedIndex or #element.NestedElements + 1, windowSettings, element, dropdownHolder, library)
	end
	function element:AddBind(nestedSettings, nestedIndex)
		slot.Visible = true
		slot.Size = UDim2.fromOffset(80, 24)
		return Elements.createBind(groupbox, nestedSettings, nestedIndex or #element.NestedElements + 1, windowSettings, element, slot, library)
	end
	function element:AddColorPicker(nestedSettings, nestedIndex)
		slot.Visible = true
		slot.Size = UDim2.fromOffset(24, 24)
		return Elements.createColorPicker(groupbox, nestedSettings, nestedIndex or #element.NestedElements + 1, windowSettings, element, slot, library)
	end

	groupbox.Elements[index] = element
	return element
end

function Elements.createDivider(groupbox)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local line = Util.new("Frame", {
		BackgroundColor3 = theme.Miscellaneous.Divider,
		BackgroundTransparency = transp.Divider,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
	}, { groupbox.ParentingItem })
	return {
		Class = "Divider",
		Instance = line,
		Destroy = function()
			line:Destroy()
		end,
	}
end

function Elements.createParagraph(groupbox, settings, index)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local element = { Class = "Paragraph", Values = settings, NestedElements = {} }
	local frame = Util.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { groupbox.ParentingItem })
	Util.list(4, false, frame)
	Util.text({
		Parent = frame,
		Text = settings.Name or settings.Title or "",
		FontWeight = Enum.FontWeight.SemiBold,
		TextSize = 16 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Tab,
	})
	Util.text({
		Parent = frame,
		Text = settings.Content or settings.Description or "",
		TextWrapped = true,
		TextSize = 13 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Subtitle,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	element.Instance = frame
	function element:Set(newSettings)
		element.Values = Util.merge(element.Values, newSettings)
	end
	function element:Destroy()
		frame:Destroy()
	end
	groupbox.Elements[index] = element
	return element
end

function Elements.createDropdown(groupbox, settings, index, windowSettings, parentElement, holderOverride, library)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local element = { Class = "Dropdown", Values = settings, NestedElements = {} }
	settings.Options = settings.Options or settings.Values or {}
	settings.Callback = settings.Callback or function() end
	settings.Multi = settings.Multi == true or settings.MultiSelection == true or settings.MultipleOptions == true
	settings.Placeholder = settings.Placeholder or "--"
	if settings.Multi then
		settings.CurrentOptions = settings.CurrentOptions or settings.CurrentOption or settings.Default or {}
		if type(settings.CurrentOptions) ~= "table" then
			settings.CurrentOptions = { settings.CurrentOptions }
		end
		if type(settings.CurrentOption) == "table" and settings.CurrentOptions ~= settings.CurrentOption then
			settings.CurrentOptions = settings.CurrentOption
		end
	else
		settings.CurrentOption = settings.CurrentOption or settings.Default or settings.Options[1] or ""
	end

	local parentFrame
	local rowLabel
	if not holderOverride then
		local row, label, slot = Elements.createRow(groupbox.ParentingItem, settings, theme)
		rowLabel = label
		element.Instance = row
		parentFrame = slot
		parentFrame.Size = UDim2.fromOffset(160, 26)
	else
		local wrapper = Util.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 32),
		}, { holderOverride })
		parentFrame = wrapper
		element.Instance = wrapper
	end

	local closed = Util.button({
		Parent = parentFrame,
		BackgroundColor3 = theme.Backgrounds.Light,
		BackgroundTransparency = transp.Input,
		Size = UDim2.fromScale(1, 1),
		Radius = 4,
	})
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, closed)

	local valueText = Util.text({
		Parent = closed,
		Text = "",
		TextSize = 12 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = 0.4,
		Size = UDim2.new(1, -24, 1, 0),
	})
	Util.padding(0, 8, 0, 8, closed)

	local popupRoot = library and (library._screenGui or library._popupRoot) or parentFrame
	local popup = Util.new("ScrollingFrame", {
		Name = "DropdownPopup",
		BackgroundColor3 = theme.Backgrounds.Dark,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(200, 180),
		Position = UDim2.fromOffset(0, 0),
		Visible = false,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 1,
		ScrollBarImageTransparency = 0.5,
		ZIndex = 300,
		ClipsDescendants = true,
	}, { popupRoot })
	Util.corner(6, popup)
	local popupLayout = Util.list(2, false, popup)
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, popup)
	Util.padding(4, 4, 4, 4, popup)

	local openDropdowns = library and library._openDropdowns
	if not openDropdowns and library then
		openDropdowns = {}
		library._openDropdowns = openDropdowns
	end

	local function positionPopup()
		local anchor = closed.AbsolutePosition
		local size = closed.AbsoluteSize
		popup.Size = UDim2.fromOffset(math.max(size.X, 200), 180)
		popup.Position = UDim2.fromOffset(anchor.X, anchor.Y + size.Y + 4)
	end

	local function closePopup()
		popup.Visible = false
		if openDropdowns then
			openDropdowns[popup] = nil
		end
	end

	local function openPopup()
		if openDropdowns then
			for other in pairs(openDropdowns) do
				if other ~= popup and other.Parent then
					other.Visible = false
				end
			end
			for key in pairs(openDropdowns) do
				openDropdowns[key] = nil
			end
			openDropdowns[popup] = true
		end
		positionPopup()
		popup.Visible = true
	end

	local function displayValue()
		if settings.Multi then
			valueText.Text = #settings.CurrentOptions == 0 and settings.Placeholder
				or table.concat(settings.CurrentOptions, ", ")
		else
			local text = tostring(settings.CurrentOption or "")
			valueText.Text = (text == "" and settings.Placeholder) or text
		end
	end

	local function rebuildOptions(filtered)
		for _, child in ipairs(popup:GetChildren()) do
			if child:IsA("GuiObject") and child.Name == "Option" then
				child:Destroy()
			end
		end
		local options = filtered or settings.Options
		for i, option in ipairs(options) do
			local selected = settings.Multi
				and table.find(settings.CurrentOptions, option) ~= nil
				or settings.CurrentOption == option
			local opt = Util.button({
				Name = "Option",
				Parent = popup,
				BackgroundColor3 = theme.Backgrounds.Light,
				BackgroundTransparency = selected and 0.9 or 0.98,
				Size = UDim2.new(1, -4, 0, 28),
				Radius = 4,
			})
			opt.ZIndex = popup.ZIndex + 1
			opt.LayoutOrder = i
			Util.text({
				Parent = opt,
				Text = tostring(option),
				TextSize = 12 * Theme.Visual.FontScale,
				TextColor3 = theme.Foregrounds.Light,
				TextTransparency = selected and 0.2 or 0.5,
				Size = UDim2.fromScale(1, 1),
			})
			opt.MouseButton1Click:Connect(function()
				if settings.Multi then
					local found = table.find(settings.CurrentOptions, option)
					if found then
						table.remove(settings.CurrentOptions, found)
					else
						table.insert(settings.CurrentOptions, option)
					end
					Elements.runCallback(windowSettings, settings.Name or "Dropdown", function()
						settings.Callback(settings.CurrentOptions)
					end, library)
					displayValue()
					rebuildOptions(filtered)
				else
					settings.CurrentOption = option
					closePopup()
					Elements.runCallback(windowSettings, settings.Name or "Dropdown", function()
						settings.Callback(option)
					end, library)
					displayValue()
				end
			end)
		end
		task.defer(function()
			popup.CanvasSize = UDim2.new(0, 0, 0, popupLayout.AbsoluteContentSize.Y + 8)
		end)
	end

	displayValue()
	rebuildOptions()

	closed.MouseButton1Click:Connect(function()
		if popup.Visible then
			closePopup()
		else
			openPopup()
		end
	end)

	if library and library._screenGui then
		library._screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if popup.Visible then
				positionPopup()
			end
		end)
	end

	local dismissConnection
	dismissConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if not popup.Visible or processed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local pos = input.Position
		local function inside(gui)
			if not gui or not gui.Visible then
				return false
			end
			local ap, sz = gui.AbsolutePosition, gui.AbsoluteSize
			return pos.X >= ap.X and pos.X <= ap.X + sz.X and pos.Y >= ap.Y and pos.Y <= ap.Y + sz.Y
		end
		if not inside(closed) and not inside(popup) then
			closePopup()
		end
	end)
	element._dismissConnection = dismissConnection

	function element:Set(newSettings)
		element.Values = Util.merge(element.Values, newSettings)
		settings = element.Values
		if newSettings.Options or newSettings.Values then
			settings.Options = newSettings.Options or newSettings.Values
		end
		if newSettings.MultipleOptions ~= nil then
			settings.Multi = newSettings.MultipleOptions == true
		end
		if newSettings.CurrentOption ~= nil then
			if settings.Multi and type(newSettings.CurrentOption) == "table" then
				settings.CurrentOptions = newSettings.CurrentOption
			else
				settings.CurrentOption = newSettings.CurrentOption
			end
		end
		if newSettings.CurrentOptions ~= nil then
			settings.CurrentOptions = newSettings.CurrentOptions
		end
		if newSettings.Callback then
			settings.Callback = newSettings.Callback
		end
		if rowLabel then
			rowLabel.Text = settings.Name or rowLabel.Text
		end
		displayValue()
		rebuildOptions(newSettings.Options or newSettings.Values)
	end
	function element:SetValues(newValues, newDefault)
		settings.Options = newValues or settings.Options
		if settings.Multi then
			settings.CurrentOptions = type(newDefault) == "table" and newDefault or settings.CurrentOptions
		else
			settings.CurrentOption = newDefault or settings.CurrentOption
		end
		element:Set({
			Options = settings.Options,
			CurrentOption = settings.CurrentOption,
			CurrentOptions = settings.CurrentOptions,
		})
	end
	function element:Refresh(newValues, newDefault)
		self:SetValues(newValues, newDefault)
	end
	function element:Search(query)
		local needle = tostring(query or ""):lower()
		if needle == "" then
			rebuildOptions()
			return
		end
		local filtered = {}
		for _, option in ipairs(settings.Options) do
			if tostring(option):lower():find(needle, 1, true) then
				table.insert(filtered, option)
			end
		end
		rebuildOptions(filtered)
	end
	function element:Destroy()
		if element._dismissConnection then
			element._dismissConnection:Disconnect()
		end
		if popup and popup.Parent then
			popup:Destroy()
		end
		if element.Instance then
			element.Instance:Destroy()
		end
	end

	if parentElement then
		parentElement.NestedElements[index] = element
	else
		groupbox.Elements[index] = element
	end
	return element
end

function Elements.createBind(groupbox, settings, index, windowSettings, parentElement, slot)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local element = { Class = "Bind", Values = settings, NestedElements = {} }
	settings.CurrentValue = settings.CurrentValue or "None"
	local bindButton = Util.button({
		Parent = slot or groupbox.ParentingItem,
		BackgroundColor3 = theme.Backgrounds.Light,
		BackgroundTransparency = transp.Input,
		Size = UDim2.fromOffset(80, 24),
		Radius = 4,
	})
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, bindButton)
	element.Instance = bindButton
	Util.text({
		Parent = bindButton,
		Text = tostring(settings.CurrentValue),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
	})
	local listening = false
	bindButton.MouseButton1Click:Connect(function()
		listening = true
		bindButton:FindFirstChildOfClass("TextLabel").Text = "..."
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not listening or processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			settings.CurrentValue = input.KeyCode.Name
			listening = false
			bindButton:FindFirstChildOfClass("TextLabel").Text = settings.CurrentValue
			if settings.OnChangedCallback then
				settings.OnChangedCallback(settings.CurrentValue)
			end
		end
	end)
	parentElement.NestedElements[index] = element
	return element
end

function Elements.createColorPicker(groupbox, settings, index, windowSettings, parentElement, slot)
	local theme = Theme.current()
	local element = { Class = "ColorPicker", Values = settings, NestedElements = {} }
	settings.CurrentValue = settings.CurrentValue or Color3.fromRGB(255, 255, 255)
	settings.Transparency = settings.Transparency or 0
	local swatch = Util.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = settings.CurrentValue,
		BackgroundTransparency = settings.Transparency,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(24, 24),
		Text = "",
	}, { slot or groupbox.ParentingItem })
	Util.corner(6, swatch)
	element.Instance = swatch
	swatch.MouseButton1Click:Connect(function()
		local presets = {
			Color3.fromRGB(76, 110, 245),
			Color3.fromRGB(72, 199, 142),
			Color3.fromRGB(255, 184, 77),
			Color3.fromRGB(255, 96, 112),
			Color3.fromRGB(168, 85, 247),
		}
		local nextIndex = (table.find(presets, settings.CurrentValue) or 0) % #presets + 1
		settings.CurrentValue = presets[nextIndex]
		swatch.BackgroundColor3 = settings.CurrentValue
		if settings.Callback then
			settings.Callback(settings.CurrentValue, settings.Transparency)
		end
	end)
	parentElement.NestedElements[index] = element
	return element
end

return Elements

	end)()
end

do
	modules['window'] = (function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Util = requireModule('util')
local Theme = requireModule('theme')
local Tween = requireModule('tween')
local Elements = requireModule('elements')
local Notification = requireModule('notification')

local WindowBuilder = {}
WindowBuilder._themeListeners = {}

function WindowBuilder.addThemeListener(callback)
	table.insert(WindowBuilder._themeListeners, callback)
end

function WindowBuilder.refreshTheme(root)
	local theme = Theme.current()
	for _, listener in ipairs(WindowBuilder._themeListeners) do
		listener(theme)
	end
	if root then
		root:SetAttribute("ThemeVersion", tick())
	end
end

local function protectGui(instance)
	pcall(function()
		if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
			syn.protect_gui(instance)
		elseif typeof(protectgui) == "function" then
			protectgui(instance)
		end
	end)
end

local function parentGui(screenGui)
	local coreGui = game:GetService("CoreGui")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	protectGui(screenGui)
	local ok = pcall(function()
		screenGui.Parent = coreGui
	end)
	if ok and screenGui.Parent then
		return
	end
	pcall(function()
		screenGui.Parent = playerGui
	end)
	if not screenGui.Parent and typeof(gethui) == "function" then
		pcall(function()
			screenGui.Parent = gethui()
		end)
	end
end

local function trafficLight(parent, color, enabled, onClick)
	local btn = Util.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		BackgroundTransparency = enabled and 0 or 1,
		BorderSizePixel = 0,
		Size = enabled and UDim2.fromOffset(8, 8) or UDim2.fromOffset(7, 7),
		Text = "",
	}, { parent })
	Util.corner(999, btn)
	if not enabled then
		Util.stroke(Color3.fromRGB(255, 255, 255), 1, 0.9, btn)
	end
	if onClick then
		btn.MouseButton1Click:Connect(onClick)
	end
	return btn
end

function WindowBuilder.create(library, windowSettings)
	windowSettings = windowSettings or {}
	windowSettings.NotifyOnCallbackError = windowSettings.NotifyOnCallbackError ~= false

	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency

	if windowSettings.FileSettings then
		library.FileSystem:BuildFolderTree(windowSettings.FileSettings)
	end

	local screenGui = Util.new("ScreenGui", {
		Name = (getgenv and getgenv().InterfaceName) or windowSettings.Name or "Alleral Interface",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 999,
		Enabled = true,
	})
	parentGui(screenGui)
	library.Instance = screenGui
	library._screenGui = screenGui
	library._popupRoot = screenGui
	Notification.init(screenGui, library)

	local lighting = game:GetService("Lighting")
	local blur = lighting:FindFirstChild("AlleralBlur") or lighting:FindFirstChild("StarlightBlur")
	if blur then
		blur.Name = "AlleralBlur"
	else
		blur = Instance.new("BlurEffect")
		blur.Name = "AlleralBlur"
		blur.Parent = lighting
	end
	blur.Size = 0

	local function setBlur(active)
		blur.Size = (active and Theme.Visual.BlurEnabled) and Theme.Visual.BlurSize or 0
	end

	local main = Util.new("Frame", {
		Name = "MainWindow",
		BackgroundColor3 = theme.Backgrounds.Medium,
		BackgroundTransparency = Theme.Visual.BlurEnabled and transp.Window or 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = windowSettings.DefaultSize or UDim2.fromOffset(868, 650),
		Visible = false,
		ClipsDescendants = true,
	}, { screenGui })
	Util.corner(10, main)
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, main)

	local sidebar = Util.new("Frame", {
		Name = "Sidebar",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(Theme.Visual.SidebarWidth, 1),
	}, { main })

	Util.new("Frame", {
		Name = "Divider",
		BackgroundColor3 = theme.Miscellaneous.Divider,
		BackgroundTransparency = transp.Divider,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
	}, { sidebar })

	local windowControls = Util.new("Frame", {
		Name = "WindowControls",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 31),
	}, { sidebar })
	local controls = Util.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, { windowControls })
	Util.list(5, true, controls)
	Util.padding(0, 0, 0, 11, controls)

	local function setVisible(state)
		window.Visible = state
		main.Visible = state
		setBlur(state)
	end

	trafficLight(controls, theme.Miscellaneous.TrafficClose, true, function()
		setVisible(false)
	end)
	trafficLight(controls, theme.Miscellaneous.TrafficMinimize, true, function()
		setVisible(false)
	end)
	trafficLight(controls, theme.Miscellaneous.TrafficMaximize, false)

	Util.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		BackgroundColor3 = theme.Miscellaneous.Divider,
		BackgroundTransparency = transp.Divider,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
	}, { windowControls })

	local information = Util.new("Frame", {
		Name = "Information",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 31),
		Size = UDim2.new(1, 0, 0, 60),
	}, { sidebar })
	Util.padding(10, 22, 10, 23, information)

	Util.text({
		Parent = information,
		Text = windowSettings.Name or "Alleral",
		FontWeight = Enum.FontWeight.SemiBold,
		TextSize = 20 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Title,
		Size = UDim2.new(1, -20, 0, 24),
	})
	Util.text({
		Parent = information,
		Text = windowSettings.Subtitle or "Interface Suite",
		FontWeight = Enum.FontWeight.Medium,
		TextSize = 12 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Subtitle,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, -20, 0, 18),
	})

	Util.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		BackgroundColor3 = theme.Miscellaneous.Divider,
		BackgroundTransparency = transp.Divider,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
	}, { information })

	local sidebarGroup = Util.new("Frame", {
		Name = "SidebarGroup",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 91),
		Size = UDim2.new(1, 0, 1, -91),
	}, { sidebar })
	Util.padding(31, 10, 17, 10, sidebarGroup)

	local navHolder = Util.new("ScrollingFrame", {
		Name = "Navigation",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -40),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 1,
		ScrollBarImageTransparency = 0.8,
		BorderSizePixel = 0,
	}, { sidebarGroup })
	Util.list(17, false, navHolder)
	Util.padding(0, 0, 15, 0, navHolder)

	Util.text({
		Parent = sidebarGroup,
		Text = "Press " .. (library.WindowKeybind or "K") .. " to toggle",
		TextSize = 11 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = 0.7,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 16),
	})

	local content = Util.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(1 - Theme.Visual.SidebarWidth, 1),
	}, { main })

	local topBar = Util.new("Frame", {
		Name = "Topbar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 63),
	}, { content })
	Util.padding(0, 20, 0, 20, topBar)

	local titleLabel = Util.text({
		Parent = topBar,
		Text = "Home",
		FontWeight = Enum.FontWeight.SemiBold,
		TextSize = 15 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = 0.5,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, -40, 0, 20),
	})

	local moveIcon = Util.new("ImageButton", {
		Name = "MoveIcon",
		Image = Theme.Assets.MoveIcon,
		ImageTransparency = 0.5,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(15, 15),
	}, { topBar })

	Util.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		BackgroundColor3 = theme.Miscellaneous.Divider,
		BackgroundTransparency = transp.Divider,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
	}, { topBar })

	local pages = Util.new("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 63),
		Size = UDim2.new(1, 0, 1, -63),
	}, { content })

	local window = {
		Settings = windowSettings,
		TabSections = {},
		CurrentTab = nil,
		Instance = main,
		Visible = false,
	}

	local dragging = false
	local dragStart
	local startPos

	local function onDragStart(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end

	moveIcon.InputBegan:Connect(onDragStart)
	moveIcon.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end)

	library.Minimized = false
	library.Window = window

	function window:Toggle()
		setVisible(not self.Visible)
	end

	function window:Destroy()
		blur.Size = 0
		screenGui:Destroy()
	end

	function window:CreateTabSection(name, expanded)
		local section = {
			Name = name,
			Tabs = {},
			Expanded = expanded ~= false,
		}

		local sectionFrame = Util.new("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, { navHolder })

		if name and name ~= "" then
			Util.divider(sectionFrame, theme)
			Util.text({
				Parent = sectionFrame,
				Text = string.upper(name),
				TextSize = 10 * Theme.Visual.FontScale,
				TextColor3 = theme.Foregrounds.Light,
				TextTransparency = 0.6,
				Size = UDim2.new(1, 0, 0, 14),
			})
		end

		local tabsFrame = Util.new("Frame", {
			Name = "Tabs",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, { sectionFrame })
		Util.list(0, false, tabsFrame)

		function section:CreateTab(tabSettings, tabIndex)
			tabSettings = tabSettings or {}
			tabIndex = tabIndex or tostring(#self.Tabs + 1)
			local tab = {
				Index = tabIndex,
				Values = tabSettings,
				Groupboxes = {},
				Active = false,
			}

			local navButton = Util.button({
				Parent = tabsFrame,
				BackgroundColor3 = theme.Backgrounds.Light,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -21, 0, 40),
				Radius = 6,
			})
			local navStroke = Util.stroke(Color3.fromRGB(255, 255, 255), 1, 1, navButton)
			Util.padding(1, 35, 0, 24, navButton)
			Util.list(9, true, navButton)

			local navIcon
			if not Util.isEmpty(tabSettings.Icon) then
				navIcon = Util.new("ImageLabel", {
					BackgroundTransparency = 1,
					Image = Util.iconAsset(tabSettings.Icon),
					Size = UDim2.fromOffset(16, 16),
					ImageColor3 = theme.Foregrounds.Light,
					ImageTransparency = transp.Tab,
				}, { navButton })
			end

			local navLabel = Util.text({
				Parent = navButton,
				Text = tabSettings.Name or tabIndex,
				FontWeight = Enum.FontWeight.SemiBold,
				TextSize = 16 * Theme.Visual.FontScale,
				TextColor3 = theme.Foregrounds.Light,
				TextTransparency = transp.Tab,
				Size = UDim2.new(1, 0, 0, 20),
				AutomaticSize = Enum.AutomaticSize.Y,
			})

			local page = Util.new("ScrollingFrame", {
				Name = tabIndex,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 1,
				ScrollBarImageTransparency = 0.5,
				BorderSizePixel = 0,
				Visible = false,
			}, { pages })
			Util.padding(5, 3, 15, 11, page)

			local columns = tabSettings.Columns or 2
			local columnsFrame = Util.new("Frame", {
				Name = "Columns",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			}, { page })
			Util.list(15, true, columnsFrame)

			local columnFrames = {}
			for i = 1, columns do
				columnFrames[i] = Util.new("Frame", {
					Name = "Column" .. i,
					BackgroundTransparency = 1,
					Size = UDim2.new(1 / columns, -10, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				}, { columnsFrame })
				Util.list(15, false, columnFrames[i])
			end

			local function styleNav(active)
				navButton.BackgroundTransparency = active and transp.Section or 1
				navStroke.Transparency = active and transp.SectionStroke or 1
				navLabel.TextTransparency = active and transp.TabActive or transp.Tab
				if navIcon then
					navIcon.ImageTransparency = active and transp.TabActive or transp.Tab
				end
			end

			local function activate()
				for _, other in pairs(self.Tabs) do
					other.Active = false
					if other.Page then
						other.Page.Visible = false
					end
					if other.StyleNav then
						other.StyleNav(false)
					end
				end
				tab.Active = true
				tab.Page.Visible = true
				titleLabel.Text = tabSettings.Name or tabIndex
				styleNav(true)
				window.CurrentTab = tab
			end

			tab.Page = page
			tab.NavButton = navButton
			tab.NavLabel = navLabel
			tab.StyleNav = styleNav
			navButton.MouseButton1Click:Connect(activate)
			self.Tabs[tabIndex] = tab

			if not window.CurrentTab then
				task.defer(activate)
			end

			function tab:Show()
				if tab.Active then
					return
				end
				activate()
			end

			function tab:CreateGroupbox(groupSettings, groupIndex)
				groupSettings = groupSettings or {}
				groupIndex = groupIndex or tostring(#self.Groupboxes + 1)
				local column = groupSettings.Column or 1
				local holder = columnFrames[column] or columnFrames[1]

				local groupbox = {
					Index = groupIndex,
					Values = groupSettings,
					Elements = {},
				}

				local box = Util.new("Frame", {
					Name = groupIndex,
					BackgroundColor3 = theme.Backgrounds.Groupbox,
					BackgroundTransparency = transp.Section,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				}, { holder })
				Util.corner(Theme.Visual.GroupboxRadius, box)
				Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.SectionStroke, box)
				Util.padding(22, 18, 20, 20, box)
				Util.list(10, false, box)

				Util.text({
					Parent = box,
					Text = groupSettings.Name or groupIndex,
					FontWeight = Enum.FontWeight.SemiBold,
					TextSize = 16 * Theme.Visual.FontScale,
					TextColor3 = theme.Foregrounds.Light,
					TextTransparency = transp.Tab,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 1,
				})

				local parentingItem = Util.new("Frame", {
					Name = "Elements",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 2,
				}, { box })
				Util.list(10, false, parentingItem)

				groupbox.Instance = box
				groupbox.ParentingItem = parentingItem
				self.Groupboxes[groupIndex] = groupbox

				function groupbox:CreateToggle(s, i)
					return Elements.createToggle(self, s, i, windowSettings, library)
				end
				function groupbox:CreateSlider(s, i)
					return Elements.createSlider(self, s, i, windowSettings, library)
				end
				function groupbox:CreateButton(s, i)
					return Elements.createButton(self, s, i, windowSettings, library)
				end
				function groupbox:CreateInput(s, i)
					return Elements.createInput(self, s, i, windowSettings, library)
				end
				function groupbox:CreateLabel(s, i)
					return Elements.createLabel(self, s, i, windowSettings, library)
				end
				function groupbox:CreateDivider()
					return Elements.createDivider(self)
				end
				function groupbox:CreateParagraph(s, i)
					return Elements.createParagraph(self, s, i)
				end
				function groupbox:CreateDropdown(s, i)
					return Elements.createDropdown(self, s, i, windowSettings, nil, nil, library)
				end
				function groupbox:Set(newSettings)
					self.Values = Util.merge(self.Values, newSettings)
				end
				function groupbox:Destroy()
					box:Destroy()
				end

				return groupbox
			end

			function tab:BuildThemeGroupbox(column, style, buttonsCentered)
				local groupbox = self:CreateGroupbox({ Name = "Appearance", Column = column or 1 }, "Theme")
				local themeGroup = {
					CreateToggle = function(_, ...) return groupbox:CreateToggle(...) end,
					CreateSlider = function(_, ...) return groupbox:CreateSlider(...) end,
					CreateDropdown = function(_, ...) return groupbox:CreateDropdown(...) end,
					CreateButton = function(_, ...) return groupbox:CreateButton(...) end,
					CreateLabel = function(_, text)
						return groupbox:CreateLabel({ Name = text })
					end,
				}

				groupbox:CreateDropdown({
					Name = "Theme preset",
					Options = { "Alleral", "Midnight", "Aurora", "Rose", "Starlight" },
					CurrentOption = Theme.Visual.ThemeName,
					Callback = function(selected)
						Theme.setTheme(selected)
						WindowBuilder.refreshTheme(main)
						library:Notification({ Title = "Theme", Content = "Applied " .. selected .. " theme.", Duration = 2 })
					end,
				}, "ThemePreset")

				groupbox:CreateSlider({
					Name = "Corner radius",
					Range = { 4, 18 },
					Increment = 1,
					CurrentValue = Theme.Visual.CornerRadius,
					Callback = function(value)
						Theme.Visual.CornerRadius = value
						Theme.Visual.GroupboxRadius = value + 2
					end,
				}, "CornerRadius")

				groupbox:CreateSlider({
					Name = "Animation speed",
					Range = { 0.5, 2 },
					Increment = 0.1,
					CurrentValue = Theme.Visual.AnimationSpeed,
					Callback = function(value)
						Theme.Visual.AnimationSpeed = value
					end,
				}, "AnimSpeed")

				groupbox:CreateToggle({
					Name = "Background blur",
					CurrentValue = Theme.Visual.BlurEnabled,
					Callback = function(value)
						Theme.Visual.BlurEnabled = value
						setBlur(window.Visible)
					end,
				}, "Blur")

				groupbox:CreateToggle({
					Name = "Compact layout",
					CurrentValue = Theme.Visual.CompactMode,
					Callback = function(value)
						Theme.Visual.CompactMode = value
					end,
				}, "Compact")

				return themeGroup
			end

			function tab:BuildConfigGroupbox(column, style, buttonsCentered)
				local groupbox = self:CreateGroupbox({ Name = "Configuration", Column = column or 1 }, "Config")
				local configName = "default"

				groupbox:CreateInput({
					Name = "Config name",
					Placeholder = "default",
					CurrentValue = configName,
					Callback = function(value)
						configName = Util.trim(value) ~= "" and Util.trim(value) or "default"
					end,
				}, "ConfigName")

				groupbox:CreateButton({
					Name = "Save config",
					Callback = function()
						library.FileSystem:SaveConfig(configName, nil, library)
						library:Notification({ Title = "Saved", Content = "Config '" .. configName .. "' saved.", Duration = 3 })
					end,
				}, "SaveConfig")

				groupbox:CreateButton({
					Name = "Load config",
					Callback = function()
						local ok = library.FileSystem:LoadConfig(configName, nil, library)
						library:Notification({
							Title = ok and "Loaded" or "Failed",
							Content = ok and ("Config '" .. configName .. "' loaded.") or "Could not load config.",
							Duration = 3,
						})
					end,
				}, "LoadConfig")

				return groupbox
			end

			function tab:Set(newSettings)
				tab.Values = Util.merge(tab.Values, newSettings)
				navLabel.Text = tab.Values.Name or tabIndex
			end
			function tab:Destroy()
				page:Destroy()
				navButton:Destroy()
			end

			return tab
		end

		function section:Set(newName)
			self.Name = newName
		end
		function section:Destroy()
			sectionFrame:Destroy()
		end

		window.TabSections[name] = section
		return section
	end

	local keybind = library.WindowKeybind or "K"
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode[keybind] then
			window:Toggle()
		end
	end)

	if windowSettings.LoadingEnabled ~= false then
		task.defer(function()
			task.wait(0.1)
			setVisible(true)
		end)
	else
		setVisible(true)
	end

	library.OnDestroy = function()
		window:Destroy()
	end

	return window
end

return WindowBuilder

	end)()
end


local FileSystem = requireModule('filesystem')
local Theme = requireModule('theme')
local Notification = requireModule('notification')
local WindowBuilder = requireModule('window')
local Util = requireModule('util')

local Starlight = {
	InterfaceBuild = "Alleral-1",
	WindowKeybind = "K",
	Minimized = false,
	Maximized = false,
	NotificationsOpen = false,
	DialogOpen = false,
	Window = nil,
	Notifications = nil,
	Instance = nil,
	OnDestroy = nil,
	FileSystem = FileSystem,
	Themes = Theme.Palettes,
	CurrentTheme = Theme.current(),
}

function Starlight:Notification(data)
	return Notification.show(data)
end

function Starlight:CreateWindow(windowSettings)
	local window = WindowBuilder.create(self, windowSettings)
	self.Window = window
	self.CurrentTheme = Theme.current()
	return window
end

function Starlight:SetTheme(themeName)
	Theme.setTheme(themeName)
	self.CurrentTheme = Theme.current()
	if self.Window and self.Window.Instance then
		WindowBuilder.refreshTheme(self.Window.Instance)
	end
end

function Starlight:SetAccent(color)
	Theme.applyAccent(color)
	self.CurrentTheme = Theme.current()
end

function Starlight:GetVisualSettings()
	return Util.deepCopy(Theme.Visual)
end

function Starlight:SetVisualSettings(settings)
	for key, value in pairs(settings or {}) do
		if Theme.Visual[key] ~= nil then
			Theme.Visual[key] = value
		end
	end
	self.CurrentTheme = Theme.current()
end

return Starlight
