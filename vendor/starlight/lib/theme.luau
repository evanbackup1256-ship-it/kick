local Util = require(script.Parent.util)

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
			Section = 0.94,
			SectionStroke = 0.88,
			Input = 0.92,
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
