--[[
	Starlight Interface Suite  –  v3 (Complete Rewrite)
	======================================================
	A fully-coded, model-free Roblox exploit UI library.
	Creates every instance programmatically; no asset IDs
	or model imports are required.

	API overview
	────────────
	local lib = require(Source)()          -- or loadstring(...)()
	local win = lib:CreateWindow(settings)
	local sec = win:CreateTabSection(name)
	local tab = sec:CreateTab(settings, id)
	local grp = tab:CreateGroupbox(settings, id)

	grp:CreateToggle / CreateSlider / CreateButton
	grp:CreateInput  / CreateLabel  / CreateParagraph
	grp:CreateDivider

	label:AddDropdown(settings, id)  →  Dropdown element

	lib:Notification(settings)
	lib:SetTheme(name)
	lib:RegisterTheme(name, themeTable)
]]

-- ── Services ──────────────────────────────────────────────────────────────────
local Players		= game:GetService("Players")
local RunService	= game:GetService("RunService")
local UIS			= game:GetService("UserInputService")
local TweenSvc		= game:GetService("TweenService")
local TextSvc		= game:GetService("TextService")
local CoreGui		= game:GetService("CoreGui")

local LP   = Players.LocalPlayer
local Mouse = LP:GetMouse()

-- ── Tween helpers ─────────────────────────────────────────────────────────────
local TI_SHORT  = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_MED    = TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TI_SPRING = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TI_LINEAR = function(t) return TweenInfo.new(t, Enum.EasingStyle.Linear) end

local function tw(obj, goal, info)
	if obj and obj.Parent then
		TweenSvc:Create(obj, info or TI_SHORT, goal):Play()
	end
end

-- ── Instance creation helper ──────────────────────────────────────────────────
local function make(class, props)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do i[k] = v end
	return i
end

local function corner(r, p)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = p
	return c
end

local function stroke(col, thick, p, trans)
	local s = Instance.new("UIStroke")
	s.Color = col or Color3.new(1,1,1)
	s.Thickness = thick or 1
	s.Transparency = trans or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function pad(top, right, bot, left, p)
	right = right or top; bot = bot or top; left = left or right
	local u = Instance.new("UIPadding")
	u.PaddingTop    = UDim.new(0, top)
	u.PaddingRight  = UDim.new(0, right)
	u.PaddingBottom = UDim.new(0, bot)
	u.PaddingLeft   = UDim.new(0, left)
	u.Parent = p
	return u
end

local function listLayout(dir, halign, spacing, p, valign)
	local l = Instance.new("UIListLayout")
	l.FillDirection		   = dir    or Enum.FillDirection.Vertical
	l.HorizontalAlignment  = halign or Enum.HorizontalAlignment.Left
	l.VerticalAlignment    = valign or Enum.VerticalAlignment.Top
	l.SortOrder			   = Enum.SortOrder.LayoutOrder
	l.Padding			   = UDim.new(0, spacing or 4)
	l.Parent = p
	return l
end

-- ── Colour shorthand ──────────────────────────────────────────────────────────
local function c3(r, g, b) return Color3.fromRGB(r, g, b) end

-- ── Theme definitions ─────────────────────────────────────────────────────────
--
-- Each theme is a flat table of named Color3 values.  Every UI element binds
-- to exactly one key; when SetTheme() is called the binding fires for every
-- registered instance in O(n) time.
--
local Themes = {
	Starlight = {
		Background    = c3(20, 22, 28),
		Surface       = c3(27, 29, 36),
		Elevated      = c3(34, 37, 46),
		Groupbox      = c3(30, 33, 42),
		Border        = c3(50, 56, 72),
		BorderHover   = c3(80, 90, 115),
		TextPrimary   = c3(228, 232, 248),
		TextSecondary = c3(148, 158, 182),
		TextMuted     = c3(72, 80, 102),
		Accent        = c3(118, 162, 255),
		AccentHover   = c3(145, 182, 255),
		AccentDim     = c3(50, 75, 155),
		Positive      = c3(78, 198, 118),
		Negative      = c3(210, 72, 72),
		Shadow        = c3(8, 10, 15),
		ToggleOn      = c3(78, 198, 118),
		ToggleOff     = c3(50, 56, 72),
		InputBg       = c3(22, 24, 32),
	},
	Nebula = {
		Background    = c3(1,  4,  10),
		Surface       = c3(10, 14, 23),
		Elevated      = c3(16, 21, 33),
		Groupbox      = c3(12, 17, 27),
		Border        = c3(28, 40, 65),
		BorderHover   = c3(58, 80, 115),
		TextPrimary   = c3(205, 218, 255),
		TextSecondary = c3(136, 154, 202),
		TextMuted     = c3(52, 64, 98),
		Accent        = c3(92, 255, 236),
		AccentHover   = c3(138, 255, 245),
		AccentDim     = c3(28, 100, 95),
		Positive      = c3(58, 210, 138),
		Negative      = c3(198, 68, 68),
		Shadow        = c3(0,  2,  6),
		ToggleOn      = c3(58, 210, 138),
		ToggleOff     = c3(28, 40, 65),
		InputBg       = c3(6,  9,  16),
	},
	Crimson = {
		Background    = c3(10, 10, 15),
		Surface       = c3(16, 16, 24),
		Elevated      = c3(24, 22, 32),
		Groupbox      = c3(19, 18, 27),
		Border        = c3(62, 30, 42),
		BorderHover   = c3(102, 52, 64),
		TextPrimary   = c3(238, 220, 222),
		TextSecondary = c3(172, 140, 148),
		TextMuted     = c3(82, 60, 68),
		Accent        = c3(222, 78, 100),
		AccentHover   = c3(242, 105, 124),
		AccentDim     = c3(102, 28, 42),
		Positive      = c3(98, 200, 98),
		Negative      = c3(232, 68, 68),
		Shadow        = c3(5, 4, 7),
		ToggleOn      = c3(202, 68, 92),
		ToggleOff     = c3(62, 30, 42),
		InputBg       = c3(13, 12, 18),
	},
	["Tokyo Night"] = {
		Background    = c3(22, 22, 32),
		Surface       = c3(28, 28, 42),
		Elevated      = c3(35, 35, 54),
		Groupbox      = c3(26, 26, 40),
		Border        = c3(52, 52, 84),
		BorderHover   = c3(82, 82, 135),
		TextPrimary   = c3(212, 212, 255),
		TextSecondary = c3(156, 152, 202),
		TextMuted     = c3(72, 72, 112),
		Accent        = c3(128, 118, 202),
		AccentHover   = c3(155, 145, 225),
		AccentDim     = c3(55, 50, 112),
		Positive      = c3(78, 195, 128),
		Negative      = c3(202, 72, 72),
		Shadow        = c3(10, 10, 18),
		ToggleOn      = c3(98, 178, 138),
		ToggleOff     = c3(52, 52, 84),
		InputBg       = c3(18, 18, 28),
	},
	["Catppuccin Mocha"] = {
		Background    = c3(24, 24, 37),
		Surface       = c3(30, 30, 46),
		Elevated      = c3(36, 38, 58),
		Groupbox      = c3(28, 28, 44),
		Border        = c3(52, 54, 80),
		BorderHover   = c3(82, 86, 120),
		TextPrimary   = c3(204, 214, 244),
		TextSecondary = c3(148, 155, 188),
		TextMuted     = c3(80, 84, 112),
		Accent        = c3(136, 180, 250),
		AccentHover   = c3(164, 202, 255),
		AccentDim     = c3(54, 74, 132),
		Positive      = c3(164, 226, 160),
		Negative      = c3(242, 138, 168),
		Shadow        = c3(12, 12, 20),
		ToggleOn      = c3(164, 226, 160),
		ToggleOff     = c3(52, 54, 80),
		InputBg       = c3(20, 20, 32),
	},
	["Catppuccin Latte"] = {
		Background    = c3(239, 241, 245),
		Surface       = c3(230, 233, 239),
		Elevated      = c3(252, 252, 255),
		Groupbox      = c3(244, 246, 252),
		Border        = c3(196, 202, 218),
		BorderHover   = c3(152, 162, 188),
		TextPrimary   = c3(28, 36, 54),
		TextSecondary = c3(88, 106, 136),
		TextMuted     = c3(152, 166, 194),
		Accent        = c3(56, 128, 212),
		AccentHover   = c3(38, 102, 188),
		AccentDim     = c3(162, 196, 238),
		Positive      = c3(42, 172, 94),
		Negative      = c3(198, 58, 58),
		Shadow        = c3(178, 192, 212),
		ToggleOn      = c3(42, 172, 94),
		ToggleOff     = c3(196, 202, 218),
		InputBg       = c3(255, 255, 255),
	},
	Evergreen = {
		Background    = c3(36, 46, 50),
		Surface       = c3(44, 55, 59),
		Elevated      = c3(52, 64, 68),
		Groupbox      = c3(40, 51, 55),
		Border        = c3(68, 88, 90),
		BorderHover   = c3(98, 128, 124),
		TextPrimary   = c3(224, 225, 214),
		TextSecondary = c3(174, 178, 158),
		TextMuted     = c3(98, 110, 100),
		Accent        = c3(154, 194, 108),
		AccentHover   = c3(178, 215, 132),
		AccentDim     = c3(62, 90, 44),
		Positive      = c3(128, 208, 98),
		Negative      = c3(208, 84, 84),
		Shadow        = c3(18, 24, 25),
		ToggleOn      = c3(128, 208, 98),
		ToggleOff     = c3(68, 88, 90),
		InputBg       = c3(30, 40, 44),
	},
	["Hollywood Dark"] = {
		Background    = c3(8,  8,  8),
		Surface       = c3(13, 13, 13),
		Elevated      = c3(20, 20, 20),
		Groupbox      = c3(12, 12, 12),
		Border        = c3(36, 36, 36),
		BorderHover   = c3(62, 62, 62),
		TextPrimary   = c3(242, 242, 242),
		TextSecondary = c3(155, 155, 155),
		TextMuted     = c3(70, 70, 70),
		Accent        = c3(198, 168, 255),
		AccentHover   = c3(215, 190, 255),
		AccentDim     = c3(78, 58, 122),
		Positive      = c3(78, 205, 118),
		Negative      = c3(212, 72, 72),
		Shadow        = c3(0,  0,  0),
		ToggleOn      = c3(78, 205, 118),
		ToggleOff     = c3(36, 36, 36),
		InputBg       = c3(6,  6,  6),
	},
	Glacier = {
		Background    = c3(232, 238, 245),
		Surface       = c3(244, 248, 254),
		Elevated      = c3(255, 255, 255),
		Groupbox      = c3(238, 244, 252),
		Border        = c3(192, 208, 228),
		BorderHover   = c3(148, 170, 198),
		TextPrimary   = c3(28, 38, 55),
		TextSecondary = c3(88, 108, 132),
		TextMuted     = c3(152, 170, 192),
		Accent        = c3(58, 128, 212),
		AccentHover   = c3(38, 105, 188),
		AccentDim     = c3(162, 196, 238),
		Positive      = c3(42, 175, 94),
		Negative      = c3(198, 58, 58),
		Shadow        = c3(178, 195, 212),
		ToggleOn      = c3(42, 175, 94),
		ToggleOff     = c3(192, 208, 228),
		InputBg       = c3(255, 255, 255),
	},
}

-- ── Reactive theme binding ────────────────────────────────────────────────────
--
-- bindTheme(instance, property, key) installs a connection that keeps
-- instance[property] in sync with ActiveTheme[key] whenever SetTheme fires.
-- Connections are stored so Destroy() can clean them up if needed.

local ThemeSignal   = Instance.new("BindableEvent")
local ActiveTheme   = {} -- filled by deepCopy below
local _themeConns   = {} -- { {instance, property, key, connection} }

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = deepCopy(v) end
	return c
end

do
	local src = Themes.Starlight
	for k, v in pairs(src) do ActiveTheme[k] = v end
end

local function bindTheme(instance, property, key)
	local function apply()
		local val = ActiveTheme[key]
		if val ~= nil and instance and instance.Parent ~= nil then
			pcall(function() instance[property] = val end)
		end
	end
	apply()
	local conn = ThemeSignal.Event:Connect(apply)
	table.insert(_themeConns, { inst = instance, prop = property, key = key, conn = conn })
	return conn
end

-- ── Screen GUI ────────────────────────────────────────────────────────────────
local gui = make("ScreenGui", {
	Name            = "StarlightV3",
	ResetOnSpawn    = false,
	ZIndexBehavior  = Enum.ZIndexBehavior.Global,
	DisplayOrder    = 1000,
	IgnoreGuiInset  = true,
})
local ok = pcall(function() gui.Parent = CoreGui end)
if not ok then gui.Parent = LP:WaitForChild("PlayerGui") end

-- ── Tooltip ───────────────────────────────────────────────────────────────────
local tipFrame = make("Frame", {
	Name               = "_Tooltip",
	BackgroundTransparency = 1,
	BorderSizePixel    = 0,
	Size               = UDim2.fromOffset(0, 0),
	Position           = UDim2.fromOffset(0, 0),
	ZIndex             = 9999,
	Visible            = false,
	Parent             = gui,
})
local tipBg = make("Frame", {
	BackgroundColor3   = ActiveTheme.Surface,
	BorderSizePixel    = 0,
	Size               = UDim2.fromScale(1, 1),
	Parent             = tipFrame,
})
corner(5, tipBg)
local tipStroke = stroke(ActiveTheme.Border, 1, tipBg)
bindTheme(tipBg,     "BackgroundColor3", "Elevated")
bindTheme(tipStroke, "Color",            "Border")

local tipLabel = make("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel    = 0,
	Size               = UDim2.fromScale(1, 1),
	Font               = Enum.Font.Gotham,
	Text               = "",
	TextColor3         = ActiveTheme.TextSecondary,
	TextSize           = 11,
	TextXAlignment     = Enum.TextXAlignment.Left,
	TextWrapped        = true,
	ZIndex             = 10000,
	Parent             = tipBg,
})
pad(5, 8, 5, 8, tipLabel)
bindTheme(tipLabel, "TextColor3", "TextSecondary")

local _tipRsConn: RBXScriptConnection?
local function showTip(text: string, triggerFrame: Frame)
	if not text or text == "" then return end
	tipLabel.Text = text
	local bounds = TextSvc:GetTextSize(text, 11, Enum.Font.Gotham, Vector2.new(240, 200))
	local w, h   = bounds.X + 16, bounds.Y + 10
	tipFrame.Size = UDim2.fromOffset(w, h)
	tipFrame.Visible = true
	if _tipRsConn then _tipRsConn:Disconnect() end
	_tipRsConn = RunService.RenderStepped:Connect(function()
		tipFrame.Position = UDim2.fromOffset(Mouse.X + 18, Mouse.Y + 10)
	end)
	triggerFrame.MouseLeave:Connect(function()
		tipFrame.Visible = false
		if _tipRsConn then _tipRsConn:Disconnect(); _tipRsConn = nil end
	end)
end

local function attachTip(text: string?, frame: Frame)
	if not text or text == "" then return end
	frame.MouseEnter:Connect(function() showTip(text, frame) end)
end

-- ── Notification container ────────────────────────────────────────────────────
local notifHolder = make("Frame", {
	Name               = "_Notifications",
	BackgroundTransparency = 1,
	BorderSizePixel    = 0,
	AnchorPoint        = Vector2.new(1, 1),
	Position           = UDim2.new(1, -14, 1, -14),
	Size               = UDim2.fromOffset(290, 0),
	AutomaticSize      = Enum.AutomaticSize.Y,
	ZIndex             = 9000,
	Parent             = gui,
})
do
	local l = listLayout(Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Right, 6, notifHolder)
	l.VerticalAlignment = Enum.VerticalAlignment.Bottom
end

-- ── Popup overlay (dropdown popups rendered here to escape clip regions) ──────
local popupOverlay = make("Frame", {
	Name               = "_PopupOverlay",
	BackgroundTransparency = 1,
	BorderSizePixel    = 0,
	Size               = UDim2.fromScale(1, 1),
	ZIndex             = 8000,
	Visible            = false,
	Parent             = gui,
})

-- ── Starlight library object ──────────────────────────────────────────────────
local Starlight = {
	Window       = nil,
	Themes       = Themes,
	CurrentTheme = ActiveTheme,
	WindowKeybind = Enum.KeyCode.K,
	FileSystem   = {
		Folder            = "Starlight Interface Suite",
		FileExtension     = ".starlight",
		AutoloadConfigPath = nil,
		AutoloadThemePath  = nil,
		BuildFolderTree    = function() end,
		RefreshConfigList  = function() return {} end,
	},
}

-- ── Theme API ─────────────────────────────────────────────────────────────────
function Starlight:SetTheme(name: string)
	local t = Themes[name]
	if not t then return end
	for k, v in pairs(t) do ActiveTheme[k] = v end
	ThemeSignal:Fire()
end

function Starlight:RegisterTheme(name: string, tbl: {[string]: Color3})
	Themes[name] = tbl
end

-- ── Notification ─────────────────────────────────────────────────────────────
function Starlight:Notification(settings: {Title: string?, Content: string?, Duration: number?})
	settings = settings or {}
	local title    = tostring(settings.Title   or "Notification")
	local content  = tostring(settings.Content or "")
	local duration = math.max(1, tonumber(settings.Duration) or 4)

	local card = make("Frame", {
		BackgroundColor3   = ActiveTheme.Surface,
		BorderSizePixel    = 0,
		Size               = UDim2.fromOffset(290, 60),
		BackgroundTransparency = 0.04,
		ClipsDescendants   = true,
		ZIndex             = 9010,
		Parent             = notifHolder,
	})
	corner(8, card)
	local cs = stroke(ActiveTheme.Border, 1, card)
	bindTheme(card, "BackgroundColor3", "Surface")
	bindTheme(cs,   "Color",            "Border")

	local inner = make("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel    = 0,
		Size               = UDim2.fromScale(1, 1),
		ZIndex             = 9011,
		Parent             = card,
	})
	pad(10, 12, 10, 12, inner)
	local il = listLayout(Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, 4, inner)

	local tl = make("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel    = 0,
		Size               = UDim2.new(1, 0, 0, 16),
		Font               = Enum.Font.GothamBold,
		Text               = title,
		TextColor3         = ActiveTheme.TextPrimary,
		TextSize           = 13,
		TextXAlignment     = Enum.TextXAlignment.Left,
		ZIndex             = 9012,
		Parent             = inner,
	})
	bindTheme(tl, "TextColor3", "TextPrimary")

	local cl = make("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel    = 0,
		Size               = UDim2.new(1, 0, 0, 0),
		AutomaticSize      = Enum.AutomaticSize.Y,
		Font               = Enum.Font.Gotham,
		Text               = content,
		TextColor3         = ActiveTheme.TextSecondary,
		TextSize           = 12,
		TextXAlignment     = Enum.TextXAlignment.Left,
		TextWrapped        = true,
		Visible            = content ~= "",
		ZIndex             = 9012,
		Parent             = inner,
	})
	bindTheme(cl, "TextColor3", "TextSecondary")

	-- Progress bar
	local barBg = make("Frame", {
		BackgroundColor3   = ActiveTheme.Border,
		BorderSizePixel    = 0,
		Size               = UDim2.new(1, 0, 0, 2),
		ZIndex             = 9012,
		Parent             = inner,
	})
	corner(1, barBg)
	bindTheme(barBg, "BackgroundColor3", "Border")
	local bar = make("Frame", {
		BackgroundColor3   = ActiveTheme.Accent,
		BorderSizePixel    = 0,
		Size               = UDim2.fromScale(1, 1),
		ZIndex             = 9013,
		Parent             = barBg,
	})
	corner(1, bar)
	bindTheme(bar, "BackgroundColor3", "Accent")

	-- Resize card to content then animate out
	task.spawn(function()
		task.wait()
		local contentH = content ~= "" and cl.AbsoluteSize.Y + 4 or 0
		card.Size = UDim2.fromOffset(290, 10 + 16 + contentH + 4 + 2 + 10)
		tw(bar, { Size = UDim2.fromScale(0, 1) }, TI_LINEAR(duration))
		task.wait(duration)
		tw(card, { BackgroundTransparency = 1 }, TI_MED)
		for _, d in ipairs(card:GetDescendants()) do
			if d:IsA("TextLabel") then tw(d, { TextTransparency = 1 }, TI_MED) end
			if d:IsA("Frame")     then tw(d, { BackgroundTransparency = 1 }, TI_MED) end
		end
		task.wait(0.32)
		card:Destroy()
	end)
end

-- ── Window layout constants ────────────────────────────────────────────────────
local W_WIDTH    = 660
local W_HEIGHT   = 465
local SIDEBAR_W  = 166
local TOPBAR_H   = 46
local EL_H       = 30   -- standard element row height
local GB_PAD     = 9    -- groupbox inner padding

-- ── CreateWindow ─────────────────────────────────────────────────────────────
function Starlight:CreateWindow(settings)
	settings = settings or {}
	local winName      = tostring(settings.Name     or "Starlight")
	local subtitle     = tostring(settings.Subtitle or "")
	local notifyOnErr  = settings.NotifyOnCallbackError ~= false

	-- ── Root ──────────────────────────────────────────────────────────────────
	local win = make("Frame", {
		Name             = "Window",
		BackgroundColor3 = ActiveTheme.Background,
		BorderSizePixel  = 0,
		Size             = settings.DefaultSize or UDim2.fromOffset(W_WIDTH, W_HEIGHT),
		Position         = UDim2.fromScale(0.5, 0.5),
		AnchorPoint      = Vector2.new(0.5, 0.5),
		ClipsDescendants = true,
		ZIndex           = 100,
		Parent           = gui,
	})
	bindTheme(win, "BackgroundColor3", "Background")
	corner(10, win)
	local winStroke = stroke(ActiveTheme.Border, 1, win)
	bindTheme(winStroke, "Color", "Border")

	-- ── Sidebar ───────────────────────────────────────────────────────────────
	local sidebar = make("Frame", {
		Name             = "Sidebar",
		BackgroundColor3 = ActiveTheme.Surface,
		BorderSizePixel  = 0,
		Size             = UDim2.new(0, SIDEBAR_W, 1, 0),
		ZIndex           = 101,
		Parent           = win,
	})
	bindTheme(sidebar, "BackgroundColor3", "Surface")

	-- Right border on sidebar
	local sideDiv = make("Frame", {
		BackgroundColor3 = ActiveTheme.Border,
		BorderSizePixel  = 0,
		Position         = UDim2.new(1, -1, 0, 0),
		Size             = UDim2.new(0, 1, 1, 0),
		ZIndex           = 102,
		Parent           = sidebar,
	})
	bindTheme(sideDiv, "BackgroundColor3", "Border")

	-- Title block
	local titleBlock = make("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel  = 0,
		Size             = UDim2.new(1, -2, 0, TOPBAR_H + 10),
		ZIndex           = 102,
		Parent           = sidebar,
	})
	pad(14, 10, 0, 12, titleBlock)
	listLayout(Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, 2, titleBlock)

	local nameLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel  = 0,
		Size             = UDim2.new(1, 0, 0, 18),
		Font             = Enum.Font.GothamBold,
		Text             = winName,
		TextColor3       = ActiveTheme.TextPrimary,
		TextSize         = 15,
		TextXAlignment   = Enum.TextXAlignment.Left,
		ZIndex           = 103,
		Parent           = titleBlock,
	})
	bindTheme(nameLabel, "TextColor3", "TextPrimary")

	if subtitle ~= "" then
		local subLabel = make("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel  = 0,
			Size             = UDim2.new(1, 0, 0, 13),
			Font             = Enum.Font.Gotham,
			Text             = subtitle,
			TextColor3       = ActiveTheme.TextMuted,
			TextSize         = 11,
			TextXAlignment   = Enum.TextXAlignment.Left,
			ZIndex           = 103,
			Parent           = titleBlock,
		})
		bindTheme(subLabel, "TextColor3", "TextMuted")
	end

	-- Thin divider under title
	local titleDiv = make("Frame", {
		BackgroundColor3 = ActiveTheme.Border,
		BorderSizePixel  = 0,
		Position         = UDim2.new(0, 10, 0, TOPBAR_H + 12),
		Size             = UDim2.new(1, -20, 0, 1),
		ZIndex           = 102,
		Parent           = sidebar,
	})
	bindTheme(titleDiv, "BackgroundColor3", "Border")

	-- Nav scroll
	local navScroll = make("ScrollingFrame", {
		Name                  = "Nav",
		BackgroundTransparency = 1,
		BorderSizePixel       = 0,
		Position              = UDim2.new(0, 0, 0, TOPBAR_H + 14),
		Size                  = UDim2.new(1, -2, 1, -(TOPBAR_H + 14)),
		ScrollBarThickness    = 2,
		ScrollBarImageColor3  = ActiveTheme.Border,
		CanvasSize            = UDim2.fromScale(0, 0),
		AutomaticCanvasSize   = Enum.AutomaticSize.Y,
		ZIndex                = 102,
		Parent                = sidebar,
	})
	bindTheme(navScroll, "ScrollBarImageColor3", "Border")
	listLayout(Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, 1, navScroll)
	pad(4, 0, 6, 0, navScroll)

	-- ── Content area ──────────────────────────────────────────────────────────
	local content = make("Frame", {
		Name             = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel  = 0,
		Position         = UDim2.fromOffset(SIDEBAR_W, 0),
		Size             = UDim2.new(1, -SIDEBAR_W, 1, 0),
		ClipsDescendants = true,
		ZIndex           = 101,
		Parent           = win,
	})

	-- Topbar (drag handle + controls)
	local topbar = make("Frame", {
		Name             = "Topbar",
		BackgroundColor3 = ActiveTheme.Surface,
		BorderSizePixel  = 0,
		Size             = UDim2.new(1, 0, 0, TOPBAR_H),
		ZIndex           = 102,
		Parent           = content,
	})
	bindTheme(topbar, "BackgroundColor3", "Surface")
	local topDiv = make("Frame", {
		BackgroundColor3 = ActiveTheme.Border,
		BorderSizePixel  = 0,
		Position         = UDim2.new(0, 0, 1, -1),
		Size             = UDim2.new(1, 0, 0, 1),
		ZIndex           = 103,
		Parent           = topbar,
	})
	bindTheme(topDiv, "BackgroundColor3", "Border")

	-- Window title in topbar
	local topTitle = make("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel  = 0,
		Position         = UDim2.fromOffset(14, 0),
		Size             = UDim2.new(1, -80, 1, 0),
		Font             = Enum.Font.GothamBold,
		Text             = winName,
		TextColor3       = ActiveTheme.TextPrimary,
		TextSize         = 13,
		TextXAlignment   = Enum.TextXAlignment.Left,
		ZIndex           = 103,
		Parent           = topbar,
	})
	bindTheme(topTitle, "TextColor3", "TextPrimary")

	-- Control buttons
	local function mkCtrl(symbol, xOff, hoverCol)
		local btn = make("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel  = 0,
			AnchorPoint      = Vector2.new(1, 0.5),
			Position         = UDim2.new(1, xOff, 0.5, 0),
			Size             = UDim2.fromOffset(22, 22),
			Font             = Enum.Font.GothamBold,
			Text             = symbol,
			TextColor3       = ActiveTheme.TextMuted,
			TextSize         = 13,
			ZIndex           = 104,
			Parent           = topbar,
		})
		bindTheme(btn, "TextColor3", "TextMuted")
		btn.MouseEnter:Connect(function() tw(btn, { TextColor3 = hoverCol or ActiveTheme.TextPrimary }) end)
		btn.MouseLeave:Connect(function() tw(btn, { TextColor3 = ActiveTheme.TextMuted }) end)
		return btn
	end

	local closeBtn = mkCtrl("✕", -8,  ActiveTheme.Negative)
	closeBtn.MouseButton1Click:Connect(function() win.Visible = false end)

	local minimised = false
	local fullH = settings.DefaultSize and settings.DefaultSize.Y.Offset or W_HEIGHT
	local minBtn  = mkCtrl("—", -34, ActiveTheme.TextPrimary)
	minBtn.MouseButton1Click:Connect(function()
		minimised = not minimised
		tw(win, { Size = minimised
			and UDim2.fromOffset(W_WIDTH, TOPBAR_H)
			or  (settings.DefaultSize or UDim2.fromOffset(W_WIDTH, W_HEIGHT))
		}, TI_MED)
	end)

	-- Pages container
	local pagesFrame = make("Frame", {
		Name             = "Pages",
		BackgroundTransparency = 1,
		BorderSizePixel  = 0,
		Position         = UDim2.fromOffset(0, TOPBAR_H),
		Size             = UDim2.new(1, 0, 1, -TOPBAR_H),
		ClipsDescendants = true,
		ZIndex           = 101,
		Parent           = content,
	})

	-- ── Drag ──────────────────────────────────────────────────────────────────
	do
		local dragging, dragStart, startPos
		topbar.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true; dragStart = i.Position; startPos = win.Position
			end
		end)
		UIS.InputChanged:Connect(function(i)
			if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
				local d = i.Position - dragStart
				win.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + d.X,
					startPos.Y.Scale, startPos.Y.Offset + d.Y
				)
			end
		end)
		UIS.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
		end)
	end

	-- Keybind toggle
	UIS.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.KeyCode == Starlight.WindowKeybind then win.Visible = not win.Visible end
	end)

	-- ── Window object ─────────────────────────────────────────────────────────
	local Window = {
		Instance    = win,
		TabSections = {},
		CurrentTab  = nil,
		Values      = settings,
		_pages      = pagesFrame,
		_nav        = navScroll,
	}
	Starlight.Window = Window

	-- ── CreateTabSection ───────────────────────────────────────────────────────
	function Window:CreateTabSection(secName, showHeader)
		secName = tostring(secName or "Section")

		local section = { Tabs = {}, Name = secName }

		local secFrame = make("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel  = 0,
			Size             = UDim2.new(1, 0, 0, 0),
			AutomaticSize    = Enum.AutomaticSize.Y,
			ZIndex           = 102,
			Parent           = navScroll,
		})
		listLayout(Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, 1, secFrame)

		if showHeader then
			local hdr = make("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel  = 0,
				Size             = UDim2.new(1, 0, 0, 20),
				Font             = Enum.Font.GothamBold,
				Text             = secName:upper(),
				TextColor3       = ActiveTheme.TextMuted,
				TextSize         = 9,
				TextXAlignment   = Enum.TextXAlignment.Left,
				ZIndex           = 103,
				LayoutOrder      = 0,
				Parent           = secFrame,
			})
			pad(0, 0, 0, 11, hdr)
			bindTheme(hdr, "TextColor3", "TextMuted")
		end

		section.Instance = secFrame

		-- ── CreateTab ─────────────────────────────────────────────────────────
		function section:CreateTab(tabSettings, tabId)
			tabSettings = tabSettings or {}
			local tabName = tostring(tabSettings.Name   or "Tab")
			local cols    = math.max(1, math.min(3, tonumber(tabSettings.Columns) or 2))
			local iconRaw = tabSettings.Icon and tostring(tabSettings.Icon) or ""
			local iconId  = iconRaw:match("%d+$")

			-- ── Sidebar button ────────────────────────────────────────────────
			local btn = make("TextButton", {
				Name                   = "TAB_" .. tostring(tabId),
				BackgroundColor3       = ActiveTheme.Elevated,
				BackgroundTransparency = 1,
				BorderSizePixel        = 0,
				Size                   = UDim2.new(1, 0, 0, 34),
				Font                   = Enum.Font.Gotham,
				Text                   = "",
				ZIndex                 = 103,
				LayoutOrder            = #secFrame:GetChildren(),
				Parent                 = secFrame,
			})
			corner(6, btn)
			pad(0, 6, 0, 10, btn)
			local btnLayout = listLayout(
				Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, 7, btn
			)
			btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center

			-- Icon (optional)
			if iconId then
				local ic = make("ImageLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel  = 0,
					Size             = UDim2.fromOffset(15, 15),
					Image            = "rbxassetid://" .. iconId,
					ImageColor3      = ActiveTheme.TextMuted,
					ZIndex           = 104,
					Parent           = btn,
				})
				bindTheme(ic, "ImageColor3", "TextMuted")
			end

			local btnLbl = make("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel  = 0,
				Size             = UDim2.new(1, 0, 1, 0),
				Font             = Enum.Font.Gotham,
				Text             = tabName,
				TextColor3       = ActiveTheme.TextSecondary,
				TextSize         = 13,
				TextXAlignment   = Enum.TextXAlignment.Left,
				ZIndex           = 104,
				Parent           = btn,
			})
			bindTheme(btnLbl, "TextColor3", "TextSecondary")

			-- Active accent strip (left edge)
			local strip = make("Frame", {
				BackgroundColor3 = ActiveTheme.Accent,
				BorderSizePixel  = 0,
				AnchorPoint      = Vector2.new(0, 0.5),
				Position         = UDim2.new(0, 0, 0.5, 0),
				Size             = UDim2.new(0, 0, 0.65, 0),
				ZIndex           = 105,
				Parent           = btn,
			})
			corner(2, strip)
			bindTheme(strip, "BackgroundColor3", "Accent")

			-- ── Tab page ──────────────────────────────────────────────────────
			local page = make("Frame", {
				Name                   = "TAB_PAGE_" .. tostring(tabId),
				BackgroundTransparency = 1,
				BorderSizePixel        = 0,
				Size                   = UDim2.fromScale(1, 1),
				Visible                = false,
				ZIndex                 = 101,
				Parent                 = pagesFrame,
			})
			pad(8, 8, 8, 8, page)
			local pageLayout = listLayout(
				Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, 7, page
			)
			pageLayout.VerticalAlignment = Enum.VerticalAlignment.Top

			-- Columns inside page
			for ci = 1, cols do
				local col = make("ScrollingFrame", {
					Name                  = "Column_" .. ci,
					BackgroundTransparency = 1,
					BorderSizePixel       = 0,
					Size                  = UDim2.new(1/cols, ci < cols and -4 or 0, 1, 0),
					ScrollBarThickness    = 2,
					ScrollBarImageColor3  = ActiveTheme.Border,
					CanvasSize            = UDim2.fromScale(0, 0),
					AutomaticCanvasSize   = Enum.AutomaticSize.Y,
					ZIndex                = 101,
					Parent                = page,
				})
				bindTheme(col, "ScrollBarImageColor3", "Border")
				local cLayout = listLayout(Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, 6, col)
				pad(0, 3, 6, 0, col)
			end

			-- ── Tab activation ────────────────────────────────────────────────
			local Tab = {
				Instance   = { Button = btn, Page = page },
				Values     = tabSettings,
				Groupboxes = {},
				Active     = false,
			}

			local function deactivateAll()
				for _, sec in pairs(Window.TabSections) do
					for _, t in pairs(sec.Tabs) do
						if t.Active then
							t.Active = false
							t.Instance.Page.Visible = false
							tw(t.Instance.Button, { BackgroundTransparency = 1 })
							local lbl = t.Instance.Button:FindFirstChildWhichIsA("TextLabel")
							if lbl then tw(lbl, { TextColor3 = ActiveTheme.TextSecondary }) end
							local ic  = t.Instance.Button:FindFirstChildWhichIsA("ImageLabel")
							if ic  then tw(ic,  { ImageColor3 = ActiveTheme.TextMuted }) end
							local st  = t.Instance.Button:FindFirstChild("Frame")
							if st  then tw(st,  { Size = UDim2.new(0, 0, 0.65, 0) }) end
						end
					end
				end
			end

			local function activate()
				deactivateAll()
				Tab.Active = true
				Window.CurrentTab = Tab
				page.Visible = true
				tw(btn,    { BackgroundTransparency = 0.88 })
				tw(btnLbl, { TextColor3 = ActiveTheme.TextPrimary })
				tw(strip,  { Size = UDim2.new(0, 3, 0.65, 0) })
				local ic = btn:FindFirstChildWhichIsA("ImageLabel")
				if ic then tw(ic, { ImageColor3 = ActiveTheme.Accent }) end
			end

			btn.MouseButton1Click:Connect(activate)
			btn.MouseEnter:Connect(function()
				if not Tab.Active then tw(btnLbl, { TextColor3 = ActiveTheme.TextPrimary }) end
			end)
			btn.MouseLeave:Connect(function()
				if not Tab.Active then tw(btnLbl, { TextColor3 = ActiveTheme.TextSecondary }) end
			end)

			-- First tab auto-activates
			if Window.CurrentTab == nil then
				task.defer(activate)
			end

			-- ── CreateGroupbox ─────────────────────────────────────────────────
			function Tab:CreateGroupbox(gbSet, gbId)
				gbSet = gbSet or {}
				local gbName    = tostring(gbSet.Name   or "Group")
				local gbCol     = tonumber(gbSet.Column) or 1
				local gbIconRaw = gbSet.Icon and tostring(gbSet.Icon) or ""
				local gbIconId  = gbIconRaw:match("%d+$")

				local colFrame = page:FindFirstChild("Column_" .. gbCol)
					or page:FindFirstChild("Column_1")

				local Groupbox = { Values = gbSet, Elements = {}, Index = gbId }

				-- Card
				local card = make("Frame", {
					Name             = "GROUPBOX_" .. tostring(gbId),
					BackgroundColor3 = ActiveTheme.Groupbox,
					BorderSizePixel  = 0,
					Size             = UDim2.new(1, 0, 0, 0),
					AutomaticSize    = Enum.AutomaticSize.Y,
					ZIndex           = 102,
					Parent           = colFrame,
				})
				bindTheme(card, "BackgroundColor3", "Groupbox")
				corner(8, card)
				local cs2 = stroke(ActiveTheme.Border, 1, card)
				bindTheme(cs2, "Color", "Border")

				local cardLayout = listLayout(
					Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, 0, card
				)

				-- Header row
				local hdrRow = make("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel  = 0,
					Size             = UDim2.new(1, 0, 0, 26),
					ZIndex           = 103,
					Parent           = card,
				})
				pad(0, GB_PAD, 0, GB_PAD, hdrRow)
				local hdrLayout = listLayout(
					Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, 5, hdrRow
				)
				hdrLayout.VerticalAlignment = Enum.VerticalAlignment.Center

				if gbIconId then
					local hi = make("ImageLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						Size             = UDim2.fromOffset(13, 13),
						Image            = "rbxassetid://" .. gbIconId,
						ImageColor3      = ActiveTheme.TextMuted,
						ZIndex           = 104,
						Parent           = hdrRow,
					})
					bindTheme(hi, "ImageColor3", "TextMuted")
				end

				local hdrLbl = make("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel  = 0,
					Size             = UDim2.new(1, 0, 0, 12),
					Font             = Enum.Font.GothamBold,
					Text             = gbName:upper(),
					TextColor3       = ActiveTheme.TextMuted,
					TextSize         = 9,
					TextXAlignment   = Enum.TextXAlignment.Left,
					ZIndex           = 104,
					Parent           = hdrRow,
				})
				bindTheme(hdrLbl, "TextColor3", "TextMuted")

				-- Hairline under header
				local hdrDiv = make("Frame", {
					BackgroundColor3 = ActiveTheme.Border,
					BorderSizePixel  = 0,
					Size             = UDim2.new(1, 0, 0, 1),
					ZIndex           = 103,
					Parent           = card,
				})
				bindTheme(hdrDiv, "BackgroundColor3", "Border")

				-- Content frame
				local elFrame = make("Frame", {
					Name             = "PART_Content",
					BackgroundTransparency = 1,
					BorderSizePixel  = 0,
					Size             = UDim2.new(1, 0, 0, 0),
					AutomaticSize    = Enum.AutomaticSize.Y,
					ZIndex           = 103,
					Parent           = card,
				})
				listLayout(Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, 2, elFrame)
				pad(GB_PAD, GB_PAD, GB_PAD, GB_PAD, elFrame)

				Groupbox.Instance     = card
				Groupbox.ParentingItem = elFrame

				-- ── Shared element helpers ─────────────────────────────────────

				local function row(h, name_)
					return make("Frame", {
						Name             = name_ or "Row",
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						Size             = UDim2.new(1, 0, 0, h or EL_H),
						ZIndex           = 104,
						Parent           = elFrame,
					})
				end

				-- ── CreateToggle ───────────────────────────────────────────────
				function Groupbox:CreateToggle(s, id)
					s = s or {}
					local text  = tostring(s.Name or "Toggle")
					local val   = s.CurrentValue == true
					local style = tonumber(s.Style) or 1   -- 1 = checkbox  2 = switch
					local cb    = type(s.Callback) == "function" and s.Callback or function() end

					local Element = { Values = s, Class = "Toggle" }
					local r = row(EL_H, "TOGGLE_" .. tostring(id))

					-- Label
					local lbl = make("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						AnchorPoint      = Vector2.new(0, 0.5),
						Position         = UDim2.new(0, 0, 0.5, 0),
						Size             = UDim2.new(1, -48, 1, 0),
						Font             = Enum.Font.Gotham,
						Text             = text,
						TextColor3       = ActiveTheme.TextPrimary,
						TextSize         = 13,
						TextXAlignment   = Enum.TextXAlignment.Left,
						ZIndex           = 105,
						Parent           = r,
					})
					bindTheme(lbl, "TextColor3", "TextPrimary")

					-- Control widget
					local ctrl = make("Frame", {
						BackgroundColor3 = val and ActiveTheme.ToggleOn or ActiveTheme.ToggleOff,
						BorderSizePixel  = 0,
						AnchorPoint      = Vector2.new(1, 0.5),
						Position         = UDim2.new(1, 0, 0.5, 0),
						ZIndex           = 105,
						Parent           = r,
					})

					if style == 2 then
						-- Switch
						ctrl.Size = UDim2.fromOffset(36, 18)
						corner(9, ctrl)
						local knob = make("Frame", {
							Name             = "Knob",
							BackgroundColor3 = Color3.new(1,1,1),
							BorderSizePixel  = 0,
							AnchorPoint      = Vector2.new(0, 0.5),
							Position         = val and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
							Size             = UDim2.fromOffset(12, 12),
							ZIndex           = 106,
							Parent           = ctrl,
						})
						corner(6, knob)
					else
						-- Checkbox
						ctrl.Size = UDim2.fromOffset(18, 18)
						corner(4, ctrl)
						make("TextLabel", {
							Name             = "Check",
							BackgroundTransparency = 1,
							BorderSizePixel  = 0,
							Size             = UDim2.fromScale(1, 1),
							Font             = Enum.Font.GothamBold,
							Text             = "✓",
							TextColor3       = Color3.new(1,1,1),
							TextSize         = 12,
							Visible          = val,
							ZIndex           = 106,
							Parent           = ctrl,
						})
					end

					local function setVis(v)
						tw(ctrl, { BackgroundColor3 = v and ActiveTheme.ToggleOn or ActiveTheme.ToggleOff })
						if style == 2 then
							local k = ctrl:FindFirstChild("Knob")
							if k then tw(k, { Position = v and UDim2.new(1,-17,0.5,0) or UDim2.new(0,3,0.5,0) }) end
						else
							local ck = ctrl:FindFirstChild("Check")
							if ck then ck.Visible = v end
						end
					end

					-- Invisible button overlay for clicks
					local hit = make("TextButton", {
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						Size             = UDim2.fromScale(1, 1),
						Text             = "",
						ZIndex           = 107,
						Parent           = r,
					})
					hit.MouseButton1Click:Connect(function()
						val = not val
						Element.Values.CurrentValue = val
						setVis(val)
						if notifyOnErr then
							local ok2, err = pcall(cb, val)
							if not ok2 then warn("Starlight | Toggle callback: " .. tostring(err)) end
						else
							pcall(cb, val)
						end
					end)
					attachTip(s.Tooltip, r)
					Element.Instance = r
					function Element:Set(ns)
						if ns.CurrentValue ~= nil then
							val = ns.CurrentValue == true
							Element.Values.CurrentValue = val
							setVis(val)
						end
						if ns.Name then lbl.Text = ns.Name end
					end
					Groupbox.Elements[id] = Element
					return Element
				end

				-- ── CreateSlider ───────────────────────────────────────────────
				function Groupbox:CreateSlider(s, id)
					s = s or {}
					local text  = tostring(s.Name or "Slider")
					local range = s.Range or {0, 100}
					local minV  = tonumber(range[1]) or 0
					local maxV  = tonumber(range[2]) or 100
					local step  = tonumber(s.Increment) or 1
					local curV  = math.clamp(tonumber(s.CurrentValue) or minV, minV, maxV)
					local cb    = type(s.Callback) == "function" and s.Callback or function() end

					local Element = { Values = s, Class = "Slider" }
					local r = row(EL_H + 20, "SLIDER_" .. tostring(id))

					-- Top row: label + current value
					local topR = make("Frame", {
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						Size             = UDim2.new(1, 0, 0, 16),
						ZIndex           = 105,
						Parent           = r,
					})
					local lbl = make("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						Size             = UDim2.new(0.65, 0, 1, 0),
						Font             = Enum.Font.Gotham,
						Text             = text,
						TextColor3       = ActiveTheme.TextPrimary,
						TextSize         = 13,
						TextXAlignment   = Enum.TextXAlignment.Left,
						ZIndex           = 105,
						Parent           = topR,
					})
					bindTheme(lbl, "TextColor3", "TextPrimary")
					local valLbl = make("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						AnchorPoint      = Vector2.new(1, 0),
						Position         = UDim2.new(1, 0, 0, 0),
						Size             = UDim2.new(0.35, 0, 1, 0),
						Font             = Enum.Font.GothamBold,
						Text             = tostring(curV),
						TextColor3       = ActiveTheme.Accent,
						TextSize         = 12,
						TextXAlignment   = Enum.TextXAlignment.Right,
						ZIndex           = 105,
						Parent           = topR,
					})
					bindTheme(valLbl, "TextColor3", "Accent")

					-- Track
					local track = make("Frame", {
						BackgroundColor3 = ActiveTheme.Border,
						BorderSizePixel  = 0,
						Position         = UDim2.new(0, 0, 0, 22),
						Size             = UDim2.new(1, 0, 0, 6),
						ZIndex           = 105,
						Parent           = r,
					})
					corner(3, track)
					bindTheme(track, "BackgroundColor3", "Border")

					local fill = make("Frame", {
						BackgroundColor3 = ActiveTheme.Accent,
						BorderSizePixel  = 0,
						Size             = UDim2.new((curV-minV)/math.max(1,maxV-minV), 0, 1, 0),
						ZIndex           = 106,
						Parent           = track,
					})
					corner(3, fill)
					bindTheme(fill, "BackgroundColor3", "Accent")

					local knob = make("Frame", {
						BackgroundColor3 = Color3.new(1,1,1),
						BorderSizePixel  = 0,
						AnchorPoint      = Vector2.new(0.5, 0.5),
						Position         = UDim2.new((curV-minV)/math.max(1,maxV-minV), 0, 0.5, 0),
						Size             = UDim2.fromOffset(12,12),
						ZIndex           = 107,
						Parent           = track,
					})
					corner(6, knob)

					local hitBox = make("TextButton", {
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						Position         = UDim2.new(0, 0, 0, 16),
						Size             = UDim2.new(1, 0, 0, 22),
						Text             = "",
						ZIndex           = 108,
						Parent           = r,
					})

					local function snap(v)
						if step > 0 then v = math.round(v / step) * step end
						return math.clamp(v, minV, maxV)
					end
					local function setRatio(ratio)
						ratio = math.clamp(ratio, 0, 1)
						curV = snap(minV + ratio * (maxV - minV))
						Element.Values.CurrentValue = curV
						fill.Size  = UDim2.new(ratio, 0, 1, 0)
						knob.Position = UDim2.new(ratio, 0, 0.5, 0)
						valLbl.Text = step < 1 and string.format("%.2f", curV) or tostring(curV)
						pcall(cb, curV)
					end

					local drag = false
					hitBox.MouseButton1Down:Connect(function() drag = true end)
					UIS.InputEnded:Connect(function(i)
						if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
					end)
					UIS.InputChanged:Connect(function(i)
						if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
							local r2 = (i.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
							setRatio(r2)
						end
					end)
					hitBox.MouseButton1Click:Connect(function()
						local r2 = (Mouse.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
						setRatio(r2)
					end)

					attachTip(s.Tooltip, r)
					Element.Instance = r
					function Element:Set(ns)
						if ns.CurrentValue ~= nil then
							setRatio((snap(tonumber(ns.CurrentValue) or curV) - minV) / math.max(1, maxV - minV))
						end
					end
					Groupbox.Elements[id] = Element
					return Element
				end

				-- ── CreateButton ───────────────────────────────────────────────
				function Groupbox:CreateButton(s, id)
					s = s or {}
					local text = tostring(s.Name or "Button")
					local cb   = type(s.Callback) == "function" and s.Callback or function() end

					local Element = { Values = s, Class = "Button" }
					local r = row(EL_H, "BUTTON_" .. tostring(id))

					local btn2 = make("TextButton", {
						BackgroundColor3 = ActiveTheme.Elevated,
						BorderSizePixel  = 0,
						Size             = UDim2.fromScale(1, 1),
						Font             = Enum.Font.Gotham,
						Text             = text,
						TextColor3       = ActiveTheme.TextPrimary,
						TextSize         = 13,
						ZIndex           = 105,
						Parent           = r,
					})
					corner(6, btn2)
					local bs = stroke(ActiveTheme.Border, 1, btn2)
					bindTheme(btn2, "BackgroundColor3", "Elevated")
					bindTheme(btn2,  "TextColor3",       "TextPrimary")
					bindTheme(bs,   "Color",             "Border")

					btn2.MouseEnter:Connect(function()   tw(btn2, { BackgroundColor3 = ActiveTheme.Border }) end)
					btn2.MouseLeave:Connect(function()   tw(btn2, { BackgroundColor3 = ActiveTheme.Elevated }) end)
					btn2.MouseButton1Down:Connect(function() tw(btn2, { BackgroundColor3 = ActiveTheme.AccentDim }) end)
					btn2.MouseButton1Up:Connect(function()   tw(btn2, { BackgroundColor3 = ActiveTheme.Elevated }) end)
					btn2.MouseButton1Click:Connect(function() pcall(cb) end)

					attachTip(s.Tooltip, btn2)
					Element.Instance = r
					function Element:Set(ns) if ns.Name then btn2.Text = ns.Name end end
					Groupbox.Elements[id] = Element
					return Element
				end

				-- ── CreateInput ────────────────────────────────────────────────
				function Groupbox:CreateInput(s, id)
					s = s or {}
					local text     = tostring(s.Name            or "Input")
					local ph       = tostring(s.PlaceholderText or "")
					local clearFoc = s.RemoveTextOnFocus ~= false
					local cb       = type(s.Callback) == "function" and s.Callback or function() end

					local Element = { Values = s, Class = "Input", CurrentValue = "" }
					local r = row(EL_H + 10, "INPUT_" .. tostring(id))

					local lbl = make("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						Size             = UDim2.new(1, 0, 0, 13),
						Font             = Enum.Font.Gotham,
						Text             = text,
						TextColor3       = ActiveTheme.TextSecondary,
						TextSize         = 11,
						TextXAlignment   = Enum.TextXAlignment.Left,
						ZIndex           = 105,
						Parent           = r,
					})
					bindTheme(lbl, "TextColor3", "TextSecondary")

					local ibg = make("Frame", {
						BackgroundColor3 = ActiveTheme.InputBg,
						BorderSizePixel  = 0,
						Position         = UDim2.fromOffset(0, 15),
						Size             = UDim2.new(1, 0, 0, 25),
						ZIndex           = 105,
						Parent           = r,
					})
					corner(5, ibg)
					local ist = stroke(ActiveTheme.Border, 1, ibg)
					bindTheme(ibg, "BackgroundColor3", "InputBg")
					bindTheme(ist, "Color",            "Border")

					local box = make("TextBox", {
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						Size             = UDim2.fromScale(1, 1),
						Font             = Enum.Font.Gotham,
						Text             = "",
						PlaceholderText  = ph,
						TextColor3       = ActiveTheme.TextPrimary,
						PlaceholderColor3 = ActiveTheme.TextMuted,
						TextSize         = 13,
						TextXAlignment   = Enum.TextXAlignment.Left,
						ClearTextOnFocus = clearFoc,
						ZIndex           = 106,
						Parent           = ibg,
					})
					pad(0, 8, 0, 8, box)
					bindTheme(box, "TextColor3",      "TextPrimary")
					bindTheme(box, "PlaceholderColor3","TextMuted")

					box.Focused:Connect(function()   tw(ist, { Color = ActiveTheme.Accent }) end)
					box.FocusLost:Connect(function(enter)
						tw(ist, { Color = ActiveTheme.Border })
						Element.CurrentValue = box.Text
						if enter then pcall(cb, box.Text) end
					end)

					attachTip(s.Tooltip, r)
					Element.Instance = r
					function Element:Set(ns)
						if ns.CurrentValue ~= nil then
							box.Text = tostring(ns.CurrentValue)
							Element.CurrentValue = box.Text
						end
					end
					Groupbox.Elements[id] = Element
					return Element
				end

				-- ── CreateLabel  (hosts AddDropdown via DropdownHolder) ─────────
				function Groupbox:CreateLabel(s, id)
					s = s or {}
					local text = tostring(s.Name or "")

					local Element = { Values = s, Class = "Label", NestedElements = {} }

					-- Outer auto-sized frame
					local wrapper = make("Frame", {
						Name             = "LABEL_" .. tostring(id),
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						Size             = UDim2.new(1, 0, 0, 0),
						AutomaticSize    = Enum.AutomaticSize.Y,
						ZIndex           = 104,
						Parent           = elFrame,
					})
					listLayout(Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, 2, wrapper)

					-- Visible label text
					local lbl = make("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						Size             = UDim2.new(1, 0, 0, 14),
						Font             = Enum.Font.Gotham,
						Text             = text,
						TextColor3       = ActiveTheme.TextSecondary,
						TextSize         = 11,
						TextXAlignment   = Enum.TextXAlignment.Left,
						ZIndex           = 105,
						Parent           = wrapper,
					})
					bindTheme(lbl, "TextColor3", "TextSecondary")

					-- DropdownHolder child — wrapStarlightGroup checks for its existence
					local dHolder = make("Frame", {
						Name             = "DropdownHolder",
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						Size             = UDim2.new(1, 0, 0, 0),
						AutomaticSize    = Enum.AutomaticSize.Y,
						ZIndex           = 104,
						Parent           = wrapper,
					})
					listLayout(Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, 2, dHolder)

					Element.Instance = wrapper
					-- Roblox instance indexing: wrapper.DropdownHolder will find the child
					attachTip(s.Tooltip, wrapper)

					function Element:Set(ns)
						if ns.Name ~= nil then
							lbl.Text = tostring(ns.Name)
							Element.Values.Name = ns.Name
						end
					end

					-- ── AddDropdown ────────────────────────────────────────────
					function Element:AddDropdown(ds, dropId)
						ds = ds or {}
						local opts  = ds.Options or {}
						local multi = ds.MultipleOptions == true
						local ph2   = tostring(ds.Placeholder or "--")
						local cb    = type(ds.Callback) == "function" and ds.Callback or function() end

						-- Normalise initial selection
						local sel = {}
						if ds.CurrentOption ~= nil then
							if type(ds.CurrentOption) == "string" then
								if ds.CurrentOption ~= "" then sel = { ds.CurrentOption } end
							elseif type(ds.CurrentOption) == "table" then
								sel = ds.CurrentOption
							end
						end

						local Dropdown = { Values = ds, Class = "Dropdown" }
						local isOpen   = false

						-- Button
						local btnBg = make("Frame", {
							Name             = "DROPDOWN_" .. tostring(dropId),
							BackgroundColor3 = ActiveTheme.Surface,
							BorderSizePixel  = 0,
							Size             = UDim2.new(1, 0, 0, 28),
							ZIndex           = 105,
							Parent           = dHolder,
						})
						corner(5, btnBg)
						local bst = stroke(ActiveTheme.Border, 1, btnBg)
						bindTheme(btnBg, "BackgroundColor3", "Surface")
						bindTheme(bst,   "Color",            "Border")

						local function displayText()
							if #sel == 0 then return ph2 end
							if #sel == 1 then return tostring(sel[1]) end
							return tostring(sel[1]) .. " (+" .. (#sel-1) .. ")"
						end

						local dispLbl = make("TextLabel", {
							BackgroundTransparency = 1,
							BorderSizePixel  = 0,
							Position         = UDim2.fromOffset(9, 0),
							Size             = UDim2.new(1, -28, 1, 0),
							Font             = Enum.Font.Gotham,
							Text             = displayText(),
							TextColor3       = #sel > 0 and ActiveTheme.TextPrimary or ActiveTheme.TextMuted,
							TextSize         = 12,
							TextXAlignment   = Enum.TextXAlignment.Left,
							TextTruncate     = Enum.TextTruncate.AtEnd,
							ZIndex           = 106,
							Parent           = btnBg,
						})
						bindTheme(dispLbl, "TextColor3", "TextPrimary")

						make("TextLabel", {
							BackgroundTransparency = 1,
							BorderSizePixel  = 0,
							AnchorPoint      = Vector2.new(1, 0.5),
							Position         = UDim2.new(1, -6, 0.5, 0),
							Size             = UDim2.fromOffset(12, 12),
							Font             = Enum.Font.GothamBold,
							Text             = "▾",
							TextColor3       = ActiveTheme.TextMuted,
							TextSize         = 11,
							ZIndex           = 106,
							Parent           = btnBg,
						})

						local openBtn2 = make("TextButton", {
							BackgroundTransparency = 1,
							BorderSizePixel  = 0,
							Size             = UDim2.fromScale(1, 1),
							Text             = "",
							ZIndex           = 107,
							Parent           = btnBg,
						})

						-- Popup (lives in global overlay to escape ClipsDescendants)
						local popup = make("Frame", {
							BackgroundColor3 = ActiveTheme.Elevated,
							BorderSizePixel  = 0,
							Size             = UDim2.fromOffset(0, 0),
							Visible          = false,
							ZIndex           = 8100,
							Parent           = popupOverlay,
						})
						corner(6, popup)
						local pst = stroke(ActiveTheme.Border, 1, popup)
						bindTheme(popup, "BackgroundColor3", "Elevated")
						bindTheme(pst,   "Color",            "Border")

						local pScroll = make("ScrollingFrame", {
							BackgroundTransparency = 1,
							BorderSizePixel  = 0,
							Size             = UDim2.fromScale(1, 1),
							ScrollBarThickness = 3,
							ScrollBarImageColor3 = ActiveTheme.Border,
							CanvasSize       = UDim2.fromScale(0, 0),
							AutomaticCanvasSize = Enum.AutomaticSize.Y,
							ZIndex           = 8101,
							Parent           = popup,
						})
						bindTheme(pScroll, "ScrollBarImageColor3", "Border")
						listLayout(Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, 1, pScroll)
						pad(3, 3, 3, 3, pScroll)

						local function isSel(opt)
							for _, v in ipairs(sel) do if v == opt then return true end end
							return false
						end

						local function buildOpts()
							for _, ch in ipairs(pScroll:GetChildren()) do
								if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
							end
							for _, opt in ipairs(opts) do
								local active = isSel(opt)
								local ob = make("TextButton", {
									BackgroundColor3 = active and ActiveTheme.AccentDim or Color3.new(0,0,0),
									BackgroundTransparency = active and 0.45 or 1,
									BorderSizePixel  = 0,
									Size             = UDim2.new(1, 0, 0, 26),
									Font             = Enum.Font.Gotham,
									Text             = "",
									ZIndex           = 8102,
									Parent           = pScroll,
								})
								corner(4, ob)
								local ol = make("TextLabel", {
									BackgroundTransparency = 1,
									BorderSizePixel  = 0,
									Size             = UDim2.fromScale(1, 1),
									Font             = Enum.Font.Gotham,
									Text             = tostring(opt),
									TextColor3       = active and ActiveTheme.TextPrimary or ActiveTheme.TextSecondary,
									TextSize         = 12,
									TextXAlignment   = Enum.TextXAlignment.Left,
									ZIndex           = 8103,
									Parent           = ob,
								})
								pad(0, 4, 0, 8, ol)
								ob.MouseEnter:Connect(function() tw(ol, { TextColor3 = ActiveTheme.TextPrimary }) end)
								ob.MouseLeave:Connect(function()
									if not isSel(opt) then tw(ol, { TextColor3 = ActiveTheme.TextSecondary }) end
								end)
								ob.MouseButton1Click:Connect(function()
									if multi then
										if isSel(opt) then
											for i, v in ipairs(sel) do
												if v == opt then table.remove(sel, i); break end
											end
										else
											table.insert(sel, opt)
										end
										pcall(cb, sel)
									else
										sel = { opt }
										pcall(cb, opt)
										isOpen = false
										popup.Visible = false
										if not next(popupOverlay:GetChildren()) then popupOverlay.Visible = false end
									end
									dispLbl.Text = displayText()
									buildOpts()
								end)
							end
						end

						local function openPopup()
							buildOpts()
							local absPos = btnBg.AbsolutePosition
							local absSz  = btnBg.AbsoluteSize
							local popH   = math.min(#opts * 27 + 6, 210)
							popup.Size   = UDim2.fromOffset(absSz.X, popH)
							local screenH = gui.AbsoluteSize.Y
							if absPos.Y + absSz.Y + popH + 6 > screenH then
								popup.Position = UDim2.fromOffset(absPos.X, absPos.Y - popH - 4)
							else
								popup.Position = UDim2.fromOffset(absPos.X, absPos.Y + absSz.Y + 4)
							end
							popup.Visible       = true
							popupOverlay.Visible = true
							isOpen = true
						end

						local function closePopup()
							popup.Visible = false
							local anyOpen = false
							for _, ch in ipairs(popupOverlay:GetChildren()) do
								if ch:IsA("Frame") and ch.Visible then anyOpen = true; break end
							end
							if not anyOpen then popupOverlay.Visible = false end
							isOpen = false
						end

						openBtn2.MouseButton1Click:Connect(function()
							if isOpen then closePopup() else openPopup() end
						end)
						popupOverlay.InputBegan:Connect(function(inp)
							if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
							local mx, my = Mouse.X, Mouse.Y
							local pa = popup.AbsolutePosition
							local ps = popup.AbsoluteSize
							if not (mx >= pa.X and mx <= pa.X + ps.X and my >= pa.Y and my <= pa.Y + ps.Y) then
								closePopup()
							end
						end)

						-- Fire initial callback deferred
						if #sel > 0 then
							task.defer(function() pcall(cb, multi and sel or sel[1]) end)
						end

						Dropdown.Instance = btnBg
						function Dropdown:Set(ns, _nid, silent)
							if ns.Options        then opts  = ns.Options end
							if ns.MultipleOptions ~= nil then multi = ns.MultipleOptions == true end
							if ns.CurrentOption  ~= nil then
								if type(ns.CurrentOption) == "string" then
									sel = ns.CurrentOption ~= "" and { ns.CurrentOption } or {}
								elseif type(ns.CurrentOption) == "table" then
									sel = ns.CurrentOption
								else
									sel = {}
								end
							end
							if ns.Callback then cb = ns.Callback end
							dispLbl.Text = displayText()
							if isOpen then buildOpts() end
							if not silent and ns.CurrentOption ~= nil then
								pcall(cb, multi and sel or sel[1])
							end
						end

						table.insert(Element.NestedElements, Dropdown)
						return Dropdown
					end  -- AddDropdown

					Groupbox.Elements[id] = Element
					return Element
				end  -- CreateLabel

				-- ── CreateDivider ──────────────────────────────────────────────
				function Groupbox:CreateDivider()
					local div = make("Frame", {
						BackgroundColor3 = ActiveTheme.Border,
						BorderSizePixel  = 0,
						Size             = UDim2.new(1, 0, 0, 1),
						ZIndex           = 104,
						Parent           = elFrame,
					})
					bindTheme(div, "BackgroundColor3", "Border")
					return { Instance = div }
				end

				-- ── CreateParagraph ────────────────────────────────────────────
				function Groupbox:CreateParagraph(s, id)
					s = s or {}
					local nameT  = tostring(s.Name    or "")
					local bodyT  = tostring(s.Content or "")

					local Element = { Values = s, Class = "Paragraph" }
					local wrapper = make("Frame", {
						Name             = "PARAGRAPH_" .. tostring(id),
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						Size             = UDim2.new(1, 0, 0, 0),
						AutomaticSize    = Enum.AutomaticSize.Y,
						ZIndex           = 104,
						Parent           = elFrame,
					})
					listLayout(Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, 2, wrapper)

					if nameT ~= "" then
						local nl = make("TextLabel", {
							BackgroundTransparency = 1,
							BorderSizePixel  = 0,
							Size             = UDim2.new(1, 0, 0, 13),
							Font             = Enum.Font.GothamBold,
							Text             = nameT,
							TextColor3       = ActiveTheme.TextSecondary,
							TextSize         = 11,
							TextXAlignment   = Enum.TextXAlignment.Left,
							ZIndex           = 105,
							Parent           = wrapper,
						})
						bindTheme(nl, "TextColor3", "TextSecondary")
					end

					local bl = make("TextLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel  = 0,
						Size             = UDim2.new(1, 0, 0, 0),
						AutomaticSize    = Enum.AutomaticSize.Y,
						Font             = Enum.Font.Gotham,
						Text             = bodyT,
						TextColor3       = ActiveTheme.TextMuted,
						TextSize         = 12,
						TextXAlignment   = Enum.TextXAlignment.Left,
						TextWrapped      = true,
						ZIndex           = 105,
						Parent           = wrapper,
					})
					bindTheme(bl, "TextColor3", "TextMuted")

					Element.Instance = wrapper
					function Element:Set(ns)
						if ns.Content then bl.Text  = ns.Content end
						if ns.Name    then
							local nl = wrapper:FindFirstChildWhichIsA("TextLabel")
							if nl and nl ~= bl then nl.Text = ns.Name end
						end
					end
					Groupbox.Elements[id] = Element
					return Element
				end

				-- ── Tab:BuildThemeGroupbox  (built-in theme picker) ────────────
				function Tab:BuildThemeGroupbox(column, style_)
					local themeGrp = Tab:CreateGroupbox({
						Name   = "Themes",
						Column = column or 1,
						Style  = style_ or 1,
					}, "__theme_gb")

					local names = {}
					for k in pairs(Themes) do table.insert(names, k) end
					table.sort(names)

					local lbl2 = themeGrp:CreateLabel({ Name = "Active Theme" }, "__theme_lbl")
					lbl2:AddDropdown({
						Options        = names,
						CurrentOption  = "Starlight",
						MultipleOptions = false,
						Placeholder    = "Select theme...",
						Callback       = function(v)
							Starlight:SetTheme(tostring(v))
						end,
					}, "__theme_dd")

					return themeGrp
				end

				-- Register and return
				if not Tab.Groupboxes then Tab.Groupboxes = {} end
				Tab.Groupboxes[gbId] = Groupbox

				-- Keep Window.TabSections path in sync (used by patchStarlightSource compat)
				local ts = Window.TabSections[secName]
				if ts then
					ts.Tabs[tabId] = ts.Tabs[tabId] or Tab
					ts.Tabs[tabId].Groupboxes = ts.Tabs[tabId].Groupboxes or {}
					ts.Tabs[tabId].Groupboxes[gbId] = Groupbox
				end

				return Groupbox
			end  -- CreateGroupbox

			-- Register tab
			section.Tabs[tabId] = Tab
			local ts2 = Window.TabSections[secName]
			if ts2 then ts2.Tabs[tabId] = Tab end
			return Tab
		end  -- CreateTab

		Window.TabSections[secName] = section
		return section
	end  -- CreateTabSection

	return Window
end  -- CreateWindow

return Starlight
