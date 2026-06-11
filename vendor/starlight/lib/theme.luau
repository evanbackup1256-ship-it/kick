local Util = require(script.Parent.util)

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
