--[[
	Starlight Interface Suite — Alleral Rewrite
	Modern programmatic UI library with visual settings, themes, and full backward compatibility.
]]

local FileSystem = require(script.Parent.lib.filesystem)
local Theme = require(script.Parent.lib.theme)
local Notification = require(script.Parent.lib.notification)
local WindowBuilder = require(script.Parent.lib.window)
local Util = require(script.Parent.lib.util)

local Starlight = {
	InterfaceBuild = "Alleral-5",
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
