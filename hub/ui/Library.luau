return function(deps)
	deps = type(deps) == "table" and deps or {}
	local ALLERAL_UI_VERSION = "2.3.0-vendor"

	local Maid = deps.Maid
	local Spring = deps.Spring
	local Utils = deps.Utils
	local Icons = deps.Icons
	local Theme = deps.Theme
	local Motion = deps.Motion
	local Config = deps.Config
	local Tooltip = deps.Tooltip
	local Notification = deps.Notification
	local Modal = deps.Modal
	local CommandPalette = deps.CommandPalette
	local Components = deps.Components
	local Vendor = deps.Vendor
	local Section = deps.Section
	local Page = deps.Page
	local Navigation = deps.Navigation
	local WindowFactory = deps.Window

	local LibRef = {}
	local Library = {
		Version = ALLERAL_UI_VERSION,
		ALLERAL_UI_VERSION = ALLERAL_UI_VERSION,
		Flags = Config and Config.Flags or {},
		Config = Config,
		Motion = Motion,
		Theme = Theme,
		Utils = Utils,
		Icons = Icons,
		Notification = Notification,
		Modal = Modal,
		CommandPalette = CommandPalette,
		Tooltip = Tooltip,
		Components = Components,
		Vendor = Vendor,
		Holder = nil,
		_windows = {},
		LibRef = LibRef,
	}

	LibRef.Library = Library
	LibRef.Holder = nil
	LibRef.Motion = Motion

	function Library.GetAlleralVersion()
		return ALLERAL_UI_VERSION
	end

	function Library:GetArrrelVersion()
		return ALLERAL_UI_VERSION
	end

	function Library:EnsureGuiRoot()
		if Library.Holder and Library.Holder.Parent then
			LibRef.Holder = Library.Holder
			return Library.Holder
		end
		local Players = game:GetService("Players")
		local RunService = game:GetService("RunService")
		local player = Players.LocalPlayer
		if not player then
			return nil
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "AlleralUI"
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.DisplayOrder = 200
		gui.IgnoreGuiInset = true
		pcall(function()
			if typeof(gethui) == "function" then
				gui.Parent = gethui()
			else
				gui.Parent = player:WaitForChild("PlayerGui")
			end
		end)
		if not gui.Parent then
			gui.Parent = player:WaitForChild("PlayerGui")
		end
		Library.Holder = gui
		LibRef.Holder = gui
		return gui
	end

	function Library:CreateWindow(opts)
		opts = opts or {}
		if WindowFactory then
			return WindowFactory(Library, opts)
		end
		return nil
	end

	function Library:Window(opts)
		return Library:CreateWindow(opts)
	end

	function Library:Notification(data)
		local root = Library:EnsureGuiRoot()
		if root and Notification and Notification.push then
			Notification.push(root, data, Theme.Current or Theme.get("Midnight"))
		end
	end

	function Library:Notify(data)
		Library:Notification(data)
	end

	function Library:LoadConfig(json)
		return Config and Config.loadJson(json)
	end

	function Library:ExportConfig()
		return Config and Config.exportJson() or "{}"
	end

	function Library:ListThemeNames()
		return Theme and Theme.list() or { "Private" }
	end

	function Library:GetCurrentTheme()
		return Theme and Theme.Current and Theme.Current.Name or "Private"
	end

	function Library:SetTheme(name)
		if not Theme then
			return
		end
		for i = #Library._windows, 1, -1 do
			local win = Library._windows[i]
			if not win or not win._shell or not win._shell.Parent then
				table.remove(Library._windows, i)
			elseif type(win.SetTheme) == "function" then
				win:SetTheme(name)
			end
		end
	end

	function Library:CycleTheme(step)
		step = tonumber(step) or 1
		local names = Library:ListThemeNames()
		if #names == 0 then
			return nil
		end
		local current = Library:GetCurrentTheme()
		local index = 1
		for i, name in ipairs(names) do
			if name == current then
				index = i
				break
			end
		end
		local nextIndex = ((index - 1 + step) % #names) + 1
		local nextName = names[nextIndex]
		Library:SetTheme(nextName)
		return { Name = nextName }
	end

	function Library:ApplyProfile(name)
		local map = {
			graphite = "Graphite",
			midnight = "Midnight",
			auto = "Private",
			neon = "Neon",
		}
		Library:SetTheme(map[name] or name or "Private")
	end

	function Library:SetMotionProfile() end
	function Library:ExportCustomization()
		return { theme = Theme.Current and Theme.Current.Name or "Midnight" }
	end
	function Library:ImportCustomization(data)
		if type(data) == "table" and data.theme then
			Library:SetTheme(data.theme)
		end
	end
	function Library:Watermark() end
	function Library:Preload() end
	function Library:PolishWindow() end
	function Library:RepairWindow()
		return true
	end
	function Library:HookElementTooltip() end

	Library.CreateWindow = function(_, opts)
		return Library:CreateWindow(opts)
	end

	return Library
end
