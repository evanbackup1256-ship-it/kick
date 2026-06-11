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

function Util.text(props)
	local label = Util.new("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = props.Font or Enum.Font.GothamMedium,
		Text = props.Text or "",
		TextColor3 = props.TextColor3 or Color3.fromRGB(235, 235, 240),
		TextSize = props.TextSize or 14,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		TextWrapped = props.TextWrapped == true,
		RichText = props.RichText == true,
		TextTransparency = 0,
		Size = props.Size or UDim2.new(1, 0, 0, 20),
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
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

return Util

	end)()
end

do
	modules['theme'] = (function()
local Util = requireModule('util')

local Theme = {}

Theme.Palettes = {
	Alleral = {
		Accent = Color3.fromRGB(124, 92, 255),
		AccentSoft = Color3.fromRGB(56, 189, 248),
		Backgrounds = {
			Dark = Color3.fromRGB(12, 13, 20),
			Medium = Color3.fromRGB(18, 19, 28),
			Light = Color3.fromRGB(26, 28, 40),
			Groupbox = Color3.fromRGB(22, 24, 36),
			Highlight = Color3.fromRGB(34, 36, 52),
			Elevated = Color3.fromRGB(30, 32, 48),
		},
		Foregrounds = {
			Active = Color3.fromRGB(255, 255, 255),
			Light = Color3.fromRGB(232, 234, 244),
			Medium = Color3.fromRGB(142, 146, 168),
			Dark = Color3.fromRGB(82, 86, 108),
			MediumHover = Color3.fromRGB(188, 192, 212),
			DarkHover = Color3.fromRGB(108, 112, 134),
		},
		Miscellaneous = {
			Divider = Color3.fromRGB(38, 40, 58),
			Shadow = Color3.fromRGB(0, 0, 0),
			Success = Color3.fromRGB(52, 211, 153),
			Warning = Color3.fromRGB(251, 191, 36),
			Danger = Color3.fromRGB(248, 113, 113),
		},
	},
	Starlight = {
		Accent = Color3.fromRGB(99, 132, 255),
		AccentSoft = Color3.fromRGB(72, 98, 196),
		Backgrounds = {
			Dark = Color3.fromRGB(14, 15, 18),
			Medium = Color3.fromRGB(20, 22, 28),
			Light = Color3.fromRGB(28, 30, 38),
			Groupbox = Color3.fromRGB(24, 26, 34),
			Highlight = Color3.fromRGB(36, 40, 52),
			Elevated = Color3.fromRGB(32, 35, 45),
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
			Divider = Color3.fromRGB(56, 60, 72),
			Shadow = Color3.fromRGB(0, 0, 0),
			Success = Color3.fromRGB(72, 199, 142),
			Warning = Color3.fromRGB(255, 184, 77),
			Danger = Color3.fromRGB(255, 96, 112),
		},
	},
	Midnight = {
		Accent = Color3.fromRGB(168, 85, 247),
		AccentSoft = Color3.fromRGB(124, 58, 237),
		Backgrounds = {
			Dark = Color3.fromRGB(8, 8, 12),
			Medium = Color3.fromRGB(14, 14, 20),
			Light = Color3.fromRGB(22, 22, 30),
			Groupbox = Color3.fromRGB(18, 18, 26),
			Highlight = Color3.fromRGB(34, 30, 48),
			Elevated = Color3.fromRGB(28, 26, 38),
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
			Divider = Color3.fromRGB(48, 42, 68),
			Shadow = Color3.fromRGB(0, 0, 0),
			Success = Color3.fromRGB(52, 211, 153),
			Warning = Color3.fromRGB(251, 191, 36),
			Danger = Color3.fromRGB(248, 113, 113),
		},
	},
	Aurora = {
		Accent = Color3.fromRGB(45, 212, 191),
		AccentSoft = Color3.fromRGB(20, 184, 166),
		Backgrounds = {
			Dark = Color3.fromRGB(10, 16, 18),
			Medium = Color3.fromRGB(14, 22, 26),
			Light = Color3.fromRGB(20, 30, 36),
			Groupbox = Color3.fromRGB(16, 26, 30),
			Highlight = Color3.fromRGB(24, 42, 48),
			Elevated = Color3.fromRGB(22, 36, 42),
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
			Divider = Color3.fromRGB(36, 58, 64),
			Shadow = Color3.fromRGB(0, 0, 0),
			Success = Color3.fromRGB(52, 211, 153),
			Warning = Color3.fromRGB(251, 191, 36),
			Danger = Color3.fromRGB(248, 113, 113),
		},
	},
	Rose = {
		Accent = Color3.fromRGB(244, 114, 182),
		AccentSoft = Color3.fromRGB(219, 39, 119),
		Backgrounds = {
			Dark = Color3.fromRGB(16, 10, 14),
			Medium = Color3.fromRGB(24, 14, 20),
			Light = Color3.fromRGB(34, 20, 28),
			Groupbox = Color3.fromRGB(28, 16, 24),
			Highlight = Color3.fromRGB(48, 24, 38),
			Elevated = Color3.fromRGB(40, 22, 32),
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
			Divider = Color3.fromRGB(64, 36, 52),
			Shadow = Color3.fromRGB(0, 0, 0),
			Success = Color3.fromRGB(52, 211, 153),
			Warning = Color3.fromRGB(251, 191, 36),
			Danger = Color3.fromRGB(248, 113, 113),
		},
	},
}

Theme.Visual = {
	ThemeName = "Alleral",
	Accent = Theme.Palettes.Alleral.Accent,
	CornerRadius = 8,
	GroupboxRadius = 10,
	WindowTransparency = 0,
	GroupboxTransparency = 0,
	BlurEnabled = true,
	BlurSize = 22,
	AnimationSpeed = 1,
	FontScale = 1,
	CompactMode = false,
	ShowShadows = true,
	SidebarWidth = 196,
}

function Theme.current()
	local palette = Util.deepCopy(Theme.Palettes[Theme.Visual.ThemeName] or Theme.Palettes.Alleral)
	palette.Accent = Theme.Visual.Accent
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

function Theme.accentGradient()
	local palette = Theme.current()
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, palette.Accent),
		ColorSequenceKeypoint.new(1, palette.AccentSoft or palette.Accent),
	})
end

function Theme.tweenInfo(time, style, direction)
	local speed = Theme.Visual.AnimationSpeed
	return TweenInfo.new((time or 0.25) / speed, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
end

return Theme

	end)()
end

do
	modules['tween'] = (function()
local TweenService = game:GetService("TweenService")
local Theme = requireModule('theme')

local Tween = {}

function Tween.play(instance, goal, callback, info)
	local tween = TweenService:Create(instance, info or Theme.tweenInfo(), goal)
	if callback then
		tween.Completed:Once(callback)
	end
	tween:Play()
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
Notification._library = nil

function Notification.init(gui, library)
	Notification._library = library
	Notification._container = Util.new("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 320, 1, -40),
		Position = UDim2.new(1, -340, 0, 20),
	}, { gui })
	Util.list(10, false, Notification._container)
end

function Notification.show(data)
	if not Notification._container then
		return
	end
	local theme = Theme.current()
	data = data or {}
	local layoutOrder = 0
	for _, child in ipairs(Notification._container:GetChildren()) do
		if child:IsA("GuiObject") then
			layoutOrder += 1
		end
	end
	local card = Util.new("Frame", {
		Name = "Notification",
		BackgroundColor3 = theme.Backgrounds.Elevated,
		BackgroundTransparency = 0.05,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = layoutOrder,
	}, { Notification._container })
	Util.corner(Theme.Visual.CornerRadius, card)
	if Theme.Visual.ShowShadows then
		Util.stroke(theme.Miscellaneous.Divider, 1, 0.35, card)
	end
	Util.padding(12, 14, 12, 14, card)
	Util.list(6, false, card)

	local headerRow = Util.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
	}, { card })
	Util.list(8, true, headerRow)

	if not Util.isEmpty(data.Icon) then
		local icon = Util.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Util.iconAsset(data.Icon),
			Size = UDim2.fromOffset(18, 18),
			ImageColor3 = theme.Accent,
		}, { headerRow })
	end

	Util.text({
		Parent = headerRow,
		Text = data.Title or "Notification",
		Font = Enum.Font.GothamBold,
		TextSize = 15 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		Size = UDim2.new(1, -26, 1, 0),
	})

	local body = Util.text({
		Parent = card,
		Text = data.Content or "",
		TextWrapped = true,
		TextSize = 13 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Medium,
		Size = UDim2.new(1, 0, 0, 0),
	})
	body.AutomaticSize = Enum.AutomaticSize.Y

	local duration = data.Duration or math.clamp((#tostring(data.Content or "") * 0.08) + 3, 3, 12)
	task.delay(duration, function()
		if card.Parent then
			Tween.play(card, { BackgroundTransparency = 1 }, function()
				card:Destroy()
			end, Theme.tweenInfo(0.2))
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
		TextSize = 14 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		Size = UDim2.new(1, -120, 1, 0),
	})
	label.Name = "Header"

	if not Util.isEmpty(settings.Icon) then
		local icon = Util.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Util.iconAsset(settings.Icon),
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.fromOffset(0, 10),
			ImageColor3 = theme.Accent,
		}, { row })
		label.Position = UDim2.fromOffset(22, 0)
		label.Size = UDim2.new(1, -142, 1, 0)
	end

	local slot = Util.new("Frame", {
		Name = "ElementContainer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(110, 24),
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

function Elements.createToggle(groupbox, settings, index, windowSettings, library)
	local theme = Theme.current()
	local element = {
		Class = "Toggle",
		Values = settings,
		NestedElements = {},
	}
	settings.CurrentValue = settings.CurrentValue == true
	settings.Callback = settings.Callback or function() end

	local row, label, slot = Elements.createRow(groupbox.ParentingItem, settings, theme)
	element.Instance = row

	local track = Util.new("Frame", {
		BackgroundColor3 = theme.Backgrounds.Highlight,
		Size = UDim2.fromOffset(46, 24),
	}, { slot })
	Util.corner(999, track)
	local trackGradient = Util.gradient(Theme.accentGradient(), 0, track)
	trackGradient.Enabled = settings.CurrentValue == true

	local knob = Util.new("Frame", {
		BackgroundColor3 = theme.Foregrounds.Medium,
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromOffset(3, 3),
	}, { track })
	Util.corner(999, knob)
	Util.stroke(theme.Backgrounds.Dark, 1, 0.4, knob)

	local function paint(on)
		trackGradient.Enabled = on
		Tween.play(track, {
			BackgroundColor3 = on and theme.Accent or theme.Backgrounds.Highlight,
			BackgroundTransparency = on and 0.15 or 0,
		}, nil, Theme.tweenInfo(0.15))
		Tween.play(knob, {
			BackgroundColor3 = on and theme.Foregrounds.Active or theme.Foregrounds.Medium,
			Position = on and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
		}, nil, Theme.tweenInfo(0.15))
	end
	paint(settings.CurrentValue)

	local button = Util.button({
		Parent = row,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Radius = 0,
	})
	button.ZIndex = 5
	button.MouseButton1Click:Connect(function()
		settings.CurrentValue = not settings.CurrentValue
		paint(settings.CurrentValue)
		Elements.runCallback(windowSettings, settings.Name or "Toggle", function()
			if settings.Callback then
				settings.Callback(settings.CurrentValue)
			end
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
	local element = { Class = "Slider", Values = settings, NestedElements = {} }
	local minValue = settings.Range and settings.Range[1] or 0
	local maxValue = settings.Range and settings.Range[2] or 100
	local increment = settings.Increment or 1
	settings.CurrentValue = Util.clamp(settings.CurrentValue or minValue, minValue, maxValue)

	local function snapValue(raw)
		local steps = math.floor((raw - minValue) / increment + 0.5)
		return Util.clamp(minValue + steps * increment, minValue, maxValue)
	end

	local row, label, slot = Elements.createRow(groupbox.ParentingItem, settings, theme)
	element.Instance = row
	slot.Size = UDim2.fromOffset(140, 24)

	local bar = Util.new("Frame", {
		BackgroundColor3 = theme.Backgrounds.Highlight,
		Size = UDim2.new(1, -36, 0, 6),
		Position = UDim2.new(0, 0, 0.5, -3),
	}, { slot })
	Util.corner(999, bar)

	local fill = Util.new("Frame", {
		BackgroundColor3 = theme.Accent,
		Size = UDim2.new(0, 0, 1, 0),
	}, { bar })
	Util.corner(999, fill)
	Util.gradient(Theme.accentGradient(), 0, fill)

	local valueLabel = Util.text({
		Parent = slot,
		Text = tostring(settings.CurrentValue),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 12 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Medium,
		Size = UDim2.fromOffset(32, 24),
		Position = UDim2.new(1, -32, 0, 0),
	})

	local dragging = false
	local function setValue(raw, fire)
		settings.CurrentValue = snapValue(raw)
		local alpha = (settings.CurrentValue - minValue) / math.max(maxValue - minValue, increment)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		valueLabel.Text = tostring(settings.CurrentValue)
		if fire and settings.Callback then
			Elements.runCallback(windowSettings, settings.Name or "Slider", function()
				settings.Callback(settings.CurrentValue)
			end, library)
		end
	end
	setValue(settings.CurrentValue, false)

	local function updateFromInput(input)
		local rel = Util.clamp((input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		setValue(minValue + (maxValue - minValue) * rel, dragging)
	end

	local hit = Util.button({ Parent = bar, Size = UDim2.fromScale(1, 3), Position = UDim2.fromScale(0, -1), BackgroundTransparency = 1, Radius = 999 })
	hit.MouseButton1Down:Connect(function()
		dragging = true
		local mouse = UserInputService:GetMouseLocation()
		local rel = Util.clamp((mouse.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		setValue(minValue + (maxValue - minValue) * rel, true)
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			if dragging then
				setValue(settings.CurrentValue, true)
			end
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			updateFromInput(input)
		end
	end)
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromInput(input)
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
	local element = { Class = "Button", Values = settings, NestedElements = {} }
	local row = Util.button({
		Parent = groupbox.ParentingItem,
		BackgroundColor3 = theme.Backgrounds.Elevated,
		Size = UDim2.new(1, 0, 0, Theme.Visual.CompactMode and 32 or 36),
		Radius = Theme.Visual.CornerRadius,
	})
	element.Instance = row
	local btnStroke = Util.stroke(theme.Accent, 1, 0.82, row)
	Util.text({
		Parent = row,
		Text = settings.Name or "Button",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		Size = UDim2.fromScale(1, 1),
	})
	row.MouseEnter:Connect(function()
		Tween.play(row, { BackgroundColor3 = theme.Backgrounds.Highlight }, nil, Theme.tweenInfo(0.12))
		Tween.play(btnStroke, { Transparency = 0.35 }, nil, Theme.tweenInfo(0.12))
	end)
	row.MouseLeave:Connect(function()
		Tween.play(row, { BackgroundColor3 = theme.Backgrounds.Elevated }, nil, Theme.tweenInfo(0.12))
		Tween.play(btnStroke, { Transparency = 0.82 }, nil, Theme.tweenInfo(0.12))
	end)
	row.MouseButton1Click:Connect(function()
		Elements.runCallback(windowSettings, settings.Name or "Button", settings.Callback or function() end, library)
	end)

	function element:Set(newSettings)
		element.Values = Util.merge(element.Values, newSettings)
		row:FindFirstChildOfClass("TextLabel").Text = element.Values.Name or "Button"
	end
	function element:Destroy()
		row:Destroy()
	end
	groupbox.Elements[index] = element
	return element
end

function Elements.createInput(groupbox, settings, index, windowSettings, library)
	local theme = Theme.current()
	local element = { Class = "Input", Values = settings, NestedElements = {} }
	settings.CurrentValue = settings.CurrentValue or settings.Placeholder or ""

	local row, label, slot = Elements.createRow(groupbox.ParentingItem, settings, theme)
	element.Instance = row
	slot.Size = UDim2.fromOffset(150, 28)

	local box = Util.new("TextBox", {
		BackgroundColor3 = theme.Backgrounds.Highlight,
		BorderSizePixel = 0,
		ClearTextOnFocus = settings.RemoveTextOnFocus == true,
		Font = Enum.Font.Gotham,
		PlaceholderText = settings.PlaceholderText or settings.Placeholder or "",
		Text = settings.CurrentValue,
		TextColor3 = theme.Foregrounds.Light,
		TextSize = 13 * Theme.Visual.FontScale,
		Size = UDim2.fromScale(1, 1),
	}, { slot })
	Util.corner(8, box)
	Util.padding(0, 8, 0, 8, box)

	box.FocusLost:Connect(function()
		settings.CurrentValue = box.Text
		Elements.runCallback(windowSettings, settings.Name or "Input", function()
			if settings.Callback then
				settings.Callback(settings.CurrentValue)
			end
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
	local line = Util.new("Frame", {
		BackgroundColor3 = theme.Miscellaneous.Divider,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
	}, { groupbox.ParentingItem })
	return { Class = "Divider", Instance = line, Destroy = function()
		line:Destroy()
	end }
end

function Elements.createParagraph(groupbox, settings, index)
	local theme = Theme.current()
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
		Font = Enum.Font.GothamBold,
		TextSize = 15 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
	})
	Util.text({
		Parent = frame,
		Text = settings.Content or settings.Description or "",
		TextWrapped = true,
		TextSize = 13 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Medium,
		Size = UDim2.new(1, 0, 0, 0),
	}).AutomaticSize = Enum.AutomaticSize.Y
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
		if type(settings.CurrentOption) == "table" and settings.CurrentOptions == settings.CurrentOption then
			-- already aligned
		elseif type(settings.CurrentOption) == "table" then
			settings.CurrentOptions = settings.CurrentOption
		end
	else
		settings.CurrentOption = settings.CurrentOption or settings.Default or settings.Options[1] or ""
	end

	local parentFrame = holderOverride
	local rowLabel
	if not parentFrame then
		local row, label, slot = Elements.createRow(groupbox.ParentingItem, settings, theme)
		rowLabel = label
		element.Instance = row
		parentFrame = slot
		parentFrame.Size = UDim2.fromOffset(150, 28)
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
		BackgroundColor3 = theme.Backgrounds.Highlight,
		Size = UDim2.fromScale(1, 1),
		Radius = 8,
	})
	local valueText = Util.text({
		Parent = closed,
		Text = "",
		TextSize = 13 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		Size = UDim2.new(1, -24, 1, 0),
	})
	Util.padding(0, 10, 0, 10, closed)

	local popupRoot = library and (library._screenGui or library._popupRoot) or parentFrame
	local popup = Util.new("ScrollingFrame", {
		Name = "DropdownPopup",
		BackgroundColor3 = theme.Backgrounds.Elevated,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(180, 160),
		Position = UDim2.fromOffset(0, 0),
		Visible = false,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ZIndex = 250,
		ClipsDescendants = true,
	}, { popupRoot })
	Util.corner(8, popup)
	local popupLayout = Util.list(2, false, popup)
	Util.stroke(theme.Miscellaneous.Divider, 1, 0.4, popup)

	local openDropdowns = library and library._openDropdowns
	if not openDropdowns and library then
		openDropdowns = {}
		library._openDropdowns = openDropdowns
	end

	local function positionPopup()
		local anchor = closed.AbsolutePosition
		local size = closed.AbsoluteSize
		popup.Size = UDim2.fromOffset(math.max(size.X, 180), 160)
		popup.Position = UDim2.fromOffset(anchor.X, anchor.Y + size.Y + 4)
	end

	local function closePopup()
		popup.Visible = false
		if openDropdowns then
			openDropdowns[popup] = nil
		end
	end

	local function clearOpenDropdowns()
		if not openDropdowns then
			return
		end
		for key in pairs(openDropdowns) do
			openDropdowns[key] = nil
		end
	end

	local function openPopup()
		if openDropdowns then
			for other, _ in pairs(openDropdowns) do
				if other ~= popup and other.Parent then
					other.Visible = false
				end
			end
			clearOpenDropdowns()
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
			local opt = Util.button({
				Name = "Option",
				Parent = popup,
				BackgroundColor3 = theme.Backgrounds.Light,
				Size = UDim2.new(1, -8, 0, 28),
				Radius = 6,
			})
			opt.ZIndex = popup.ZIndex + 1
			opt.LayoutOrder = i
			local selected = settings.Multi
				and table.find(settings.CurrentOptions, option) ~= nil
				or settings.CurrentOption == option
			if selected then
				opt.BackgroundColor3 = theme.AccentSoft
			end
			Util.text({
				Parent = opt,
				Text = tostring(option),
				TextSize = 13 * Theme.Visual.FontScale,
				TextColor3 = theme.Foregrounds.Light,
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
		popup.CanvasSize = UDim2.new(0, 0, 0, math.max(#options * 30, popupLayout.AbsoluteContentSize.Y))
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
		element:Set({ Options = settings.Options, CurrentOption = settings.CurrentOption, CurrentOptions = settings.CurrentOptions })
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
	local element = { Class = "Bind", Values = settings, NestedElements = {} }
	settings.CurrentValue = settings.CurrentValue or "No Bind"
	local bindButton = Util.button({
		Parent = slot or groupbox.ParentingItem,
		Size = UDim2.fromOffset(80, 24),
		Radius = 6,
	})
	element.Instance = bindButton
	Util.text({
		Parent = bindButton,
		Text = tostring(settings.CurrentValue),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		TextColor3 = theme.Foregrounds.Medium,
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
			Color3.fromRGB(99, 132, 255),
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
local RunService = game:GetService("RunService")

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

local function parentGui(screenGui)
	local coreGui = game:GetService("CoreGui")
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local function protect(instance)
		pcall(function()
			if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
				syn.protect_gui(instance)
			elseif typeof(protectgui) == "function" then
				protectgui(instance)
			end
		end)
	end

	if typeof(gethui) == "function" then
		local ok = pcall(function()
			screenGui.Parent = gethui()
		end)
		if ok and screenGui.Parent then
			return
		end
	end

	protect(screenGui)
	local ok = pcall(function()
		screenGui.Parent = coreGui
	end)
	if not ok or not screenGui.Parent then
		screenGui.Parent = playerGui
	end
end

function WindowBuilder.create(library, windowSettings)
	windowSettings = windowSettings or {}
	windowSettings.NotifyOnCallbackError = windowSettings.NotifyOnCallbackError ~= false

	local player = Players.LocalPlayer
	local theme = Theme.current()

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
	Notification.init(screenGui, library)

	local overlay = Util.new("Frame", {
		Name = "Overlay",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, { screenGui })

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

	library._popupRoot = screenGui
	library._screenGui = screenGui

	local main = Util.new("Frame", {
		Name = "MainWindow",
		BackgroundColor3 = theme.Backgrounds.Medium,
		BackgroundTransparency = Theme.Visual.WindowTransparency,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = windowSettings.DefaultSize or UDim2.fromOffset(900, 560),
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 100,
	}, { overlay })
	main:SetAttribute("TargetTransparency", Theme.Visual.WindowTransparency)
	Util.corner(Theme.Visual.GroupboxRadius + 6, main)
	local mainStroke = Util.stroke(theme.Accent, 1, 0.35, main)

	local accentRail = Util.new("Frame", {
		Name = "AccentRail",
		BackgroundColor3 = theme.Accent,
		Size = UDim2.new(0, 3, 1, -24),
		Position = UDim2.new(0, 0, 0, 12),
		ZIndex = 2,
	}, { main })
	Util.corner(999, accentRail)
	Util.gradient(Theme.accentGradient(), 90, accentRail)

	local sidebar = Util.new("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = theme.Backgrounds.Dark,
		BackgroundTransparency = 0,
		Position = UDim2.fromOffset(3, 0),
		Size = UDim2.new(0, Theme.Visual.SidebarWidth, 1, 0),
	}, { main })
	Util.padding(16, 14, 16, 14, sidebar)
	Util.list(12, false, sidebar)

	local brand = Util.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
	}, { sidebar })
	Util.list(4, false, brand)

	if not Util.isEmpty(windowSettings.Icon) then
		Util.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Util.iconAsset(windowSettings.Icon),
			Size = UDim2.fromOffset(28, 28),
			ImageColor3 = theme.Accent,
		}, { brand })
	end

	Util.text({
		Parent = brand,
		Text = windowSettings.Name or "Alleral",
		Font = Enum.Font.GothamBold,
		TextSize = 19 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
	})
	Util.text({
		Parent = brand,
		Text = windowSettings.Subtitle or "Interface Suite",
		TextSize = 11 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Medium,
	})

	local brandStripe = Util.new("Frame", {
		Name = "BrandStripe",
		BackgroundColor3 = theme.Accent,
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
	}, { brand })
	Util.gradient(Theme.accentGradient(), 0, brandStripe)

	local navHolder = Util.new("ScrollingFrame", {
		Name = "Navigation",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -120),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
	}, { sidebar })
	Util.list(6, false, navHolder)

	local content = Util.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, Theme.Visual.SidebarWidth + 3, 0, 0),
		Size = UDim2.new(1, -(Theme.Visual.SidebarWidth + 3), 1, 0),
	}, { main })

	local topBar = Util.new("Frame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
	}, { content })
	Util.padding(0, 16, 0, 16, topBar)

	local topAccent = Util.new("Frame", {
		Name = "TopAccent",
		BackgroundColor3 = theme.Accent,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundTransparency = 0.35,
	}, { topBar })
	Util.gradient(Theme.accentGradient(), 0, topAccent)

	local titleLabel = Util.text({
		Parent = topBar,
		Text = "Dashboard",
		Font = Enum.Font.GothamBold,
		TextSize = 18 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		Size = UDim2.new(1, -120, 1, 0),
	})

	local controls = Util.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(96, 28),
	}, { topBar })
	Util.list(8, true, controls)

	local function controlButton(text, color)
		local btn = Util.button({
			Parent = controls,
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = theme.Backgrounds.Highlight,
			Radius = 8,
		})
		Util.text({
			Parent = btn,
			Text = text,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 16,
			TextColor3 = color or theme.Foregrounds.Light,
			Size = UDim2.fromScale(1, 1),
		})
		return btn
	end

	local minimizeBtn = controlButton("—")
	local closeBtn = controlButton("×", theme.Miscellaneous.Danger)

	local pages = Util.new("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 1, -48),
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

	topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)
	topBar.InputEnded:Connect(function(input)
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

	local function setVisible(state)
		window.Visible = state
		main.Visible = state
		setBlur(state)
		main.BackgroundTransparency = state and Theme.Visual.WindowTransparency or 1
	end

	closeBtn.MouseButton1Click:Connect(function()
		setVisible(false)
	end)
	minimizeBtn.MouseButton1Click:Connect(function()
		setVisible(false)
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
		Util.list(4, false, sectionFrame)

		if name and name ~= "" then
			Util.text({
				Parent = sectionFrame,
				Text = string.upper(name),
				TextSize = 11 * Theme.Visual.FontScale,
				TextColor3 = theme.Foregrounds.Dark,
				Size = UDim2.new(1, 0, 0, 16),
			})
		end

		local tabsFrame = Util.new("Frame", {
			Name = "Tabs",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, { sectionFrame })

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
				BackgroundColor3 = theme.Backgrounds.Highlight,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 34),
				Radius = 999,
			})
			local navStroke = Util.stroke(theme.Accent, 1, 1, navButton)

			local navRow = Util.new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}, { navButton })
			Util.list(10, true, navRow)
			Util.padding(0, 12, 0, 12, navRow)

			if not Util.isEmpty(tabSettings.Icon) then
				Util.new("ImageLabel", {
					BackgroundTransparency = 1,
					Image = Util.iconAsset(tabSettings.Icon),
					Size = UDim2.fromOffset(16, 16),
					ImageColor3 = theme.Foregrounds.Medium,
				}, { navRow })
			end

			local navLabel = Util.text({
				Parent = navRow,
				Text = tabSettings.Name or tabIndex,
				TextSize = 14 * Theme.Visual.FontScale,
				TextColor3 = theme.Foregrounds.Medium,
				Size = UDim2.new(1, 0, 1, 0),
			})

			local page = Util.new("ScrollingFrame", {
				Name = tabIndex,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
				Visible = false,
			}, { pages })
			Util.padding(16, 16, 16, 16, page)

			local columns = tabSettings.Columns or 2
			local columnsFrame = Util.new("Frame", {
				Name = "Columns",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			}, { page })
			Util.list(14, true, columnsFrame)

			local columnFrames = {}
			for i = 1, columns do
				columnFrames[i] = Util.new("Frame", {
					Name = "Column" .. i,
					BackgroundTransparency = 1,
					Size = UDim2.new(1 / columns, -8, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				}, { columnsFrame })
				Util.list(12, false, columnFrames[i])
			end

			local function activate()
				for _, other in pairs(self.Tabs) do
					other.Active = false
					if other.Page then
						other.Page.Visible = false
					end
					if other.NavButton then
						Tween.play(other.NavButton, { BackgroundTransparency = 1 })
						if other.NavStroke then
							Tween.play(other.NavStroke, { Transparency = 1 })
						end
						if other.NavLabel then
							Tween.play(other.NavLabel, { TextColor3 = theme.Foregrounds.Medium })
						end
					end
				end
				tab.Active = true
				tab.Page.Visible = true
				titleLabel.Text = tabSettings.Name or tabIndex
				Tween.play(navButton, { BackgroundTransparency = 0.15, BackgroundColor3 = theme.Backgrounds.Highlight })
				Tween.play(navStroke, { Transparency = 0.55, Color = theme.Accent })
				Tween.play(navLabel, { TextColor3 = theme.Foregrounds.Light })
				window.CurrentTab = tab
			end

			tab.Page = page
			tab.NavButton = navButton
			tab.NavStroke = navStroke
			tab.NavLabel = navLabel
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
					BackgroundTransparency = Theme.Visual.GroupboxTransparency,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				}, { holder })
				Util.corner(Theme.Visual.GroupboxRadius, box)
				Util.stroke(theme.Miscellaneous.Divider, 1, 0.45, box)

				local header = Util.new("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 24),
				}, { box })
				Util.list(8, true, header)

				local groupAccent = Util.new("Frame", {
					Name = "Accent",
					BackgroundColor3 = theme.Accent,
					Size = UDim2.new(1, 0, 0, 2),
					Position = UDim2.new(0, 0, 0, -6),
				}, { header })
				Util.gradient(Theme.accentGradient(), 0, groupAccent)

				if not Util.isEmpty(groupSettings.Icon) then
					Util.new("ImageLabel", {
						BackgroundTransparency = 1,
						Image = Util.iconAsset(groupSettings.Icon),
						Size = UDim2.fromOffset(16, 16),
						ImageColor3 = theme.Accent,
					}, { header })
				end

				Util.text({
					Parent = header,
					Text = groupSettings.Name or groupIndex,
					Font = Enum.Font.GothamBold,
					TextSize = 14 * Theme.Visual.FontScale,
					TextColor3 = theme.Foregrounds.Light,
					Size = UDim2.new(1, 0, 1, 0),
				})

				Util.padding(14, 12, 12, 12, box)
				Util.list(8, false, box)

				local parentingItem = Util.new("Frame", {
					Name = "Elements",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				}, { box })
				Util.list(6, false, parentingItem)

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

				groupbox:CreateToggle({
					Name = "Soft shadows",
					CurrentValue = Theme.Visual.ShowShadows,
					Callback = function(value)
						Theme.Visual.ShowShadows = value
					end,
				}, "Shadows")

				return themeGroup
			end

			function tab:BuildConfigGroupbox(column, style, buttonsCentered)
				local groupbox = self:CreateGroupbox({ Name = "Configuration", Column = column or 1 }, "Config")
				local configName = "default"
				local nameInput = groupbox:CreateInput({
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
			task.wait(0.15)
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
