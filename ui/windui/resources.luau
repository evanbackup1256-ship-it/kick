--[[
	Alleral UI assets — fonts, motion, tooltips, search strings.
	Reference copy; aller.luau embeds the same values at runtime.
]]

return {
	fonts = {
		ui = { family = "GothamSSm", weight = "Medium" },
		uiSemibold = { family = "GothamSSm", weight = "SemiBold" },
		uiTitle = { family = "GothamSSm", weight = "SemiBold" },
	},
	preload = {
		"rbxasset://fonts/families/GothamSSm.json",
	},
	motion = {
		human = { frequency = 5.2, damping = 1.02 },
		snappy = { frequency = 6.4, damping = 1.04 },
		soft = { frequency = 4.2, damping = 1.1 },
		micro = { frequency = 7.8, damping = 1.06 },
		open = { frequency = 4.6, damping = 0.96 },
		tab = { frequency = 5.2, damping = 0.92 },
		tooltip = { frequency = 6.0, damping = 1.0 },
		jitterMs = { min = 4, max = 14 },
	},
	tooltips = {
		showDelay = 0.32,
		showJitter = 0.07,
		hideDelay = 0.06,
		maxWidth = 248,
		padding = 10,
	},
	search = {
		placeholder = "Find a setting…",
		placeholderHint = "  ·  / or Ctrl+F",
		minChars = 1,
		maxResults = 8,
		debounce = 0.08,
		emptyHint = "No matches",
	},
	copy = {
		searchFooter = "↑↓ pick   Enter go   Esc close",
	},
}
