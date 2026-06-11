--[[
	Alleral public resources — Roblox-native assets (no external CDN required).
	Fonts and icon fallbacks only; UI is silent by design.
]]

return {
	meta = {
		name = "Alleral Public Resources",
		version = "1.0",
	},

	fonts = {
		ui = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
		uiSemibold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
		uiBold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
		mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium),
	},

	icons = {
		search = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		info = "rbxassetid://6031097226",
		check = "rbxassetid://6031094667",
		warn = "rbxassetid://6031071057",
	},

	preload = {
		"rbxasset://fonts/families/GothamSSm.json",
		"rbxasset://fonts/families/RobotoMono.json",
	},
}
