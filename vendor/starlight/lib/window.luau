local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Util = require(script.Parent.util)
local Theme = require(script.Parent.theme)
local Tween = require(script.Parent.tween)
local Elements = require(script.Parent.elements)
local Notification = require(script.Parent.notification)

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

	ok = pcall(function()
		screenGui.Parent = playerGui
	end)
	if ok and screenGui.Parent then
		return
	end

	if typeof(gethui) == "function" then
		pcall(function()
			screenGui.Parent = gethui()
		end)
	end
end

function WindowBuilder.create(library, windowSettings)
	windowSettings = windowSettings or {}
	windowSettings.NotifyOnCallbackError = windowSettings.NotifyOnCallbackError ~= false

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
		BackgroundTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = windowSettings.DefaultSize or UDim2.fromOffset(868, 598),
		Visible = false,
		ClipsDescendants = true,
	}, { screenGui })
	Util.corner(10, main)
	Util.stroke(theme.Miscellaneous.Divider, 1, 0.35, main)

	local sidebar = Util.new("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = theme.Backgrounds.Dark,
		BackgroundTransparency = 0,
		Size = UDim2.new(0, Theme.Visual.SidebarWidth, 1, 0),
	}, { main })
	Util.padding(14, 12, 14, 12, sidebar)
	Util.list(10, false, sidebar)

	local brand = Util.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 0,
	}, { sidebar })
	Util.list(6, true, brand)

	if not Util.isEmpty(windowSettings.Icon) then
		Util.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Util.iconAsset(windowSettings.Icon),
			Size = UDim2.fromOffset(24, 24),
			ImageColor3 = theme.Accent,
			ImageTransparency = 0,
		}, { brand })
	end

	local brandText = Util.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -30, 1, 0),
	}, { brand })
	Util.list(2, false, brandText)

	Util.text({
		Parent = brandText,
		Text = windowSettings.Name or "Alleral",
		Font = Enum.Font.GothamBold,
		TextSize = 17 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
	})
	Util.text({
		Parent = brandText,
		Text = windowSettings.Subtitle or "Interface Suite",
		TextSize = 11 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Medium,
	})

	Util.new("Frame", {
		BackgroundColor3 = theme.Miscellaneous.Divider,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = 1,
	}, { sidebar })

	local navHolder = Util.new("ScrollingFrame", {
		Name = "Navigation",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -100),
		LayoutOrder = 2,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		BorderSizePixel = 0,
	}, { sidebar })
	Util.list(6, false, navHolder)

	Util.text({
		Parent = sidebar,
		Text = "Press " .. (library.WindowKeybind or "K") .. " to toggle",
		TextSize = 11 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Dark,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 3,
	})

	local divider = Util.new("Frame", {
		Name = "Divider",
		BackgroundColor3 = theme.Miscellaneous.Divider,
		BorderSizePixel = 0,
		Position = UDim2.new(0, Theme.Visual.SidebarWidth, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
	}, { main })

	local content = Util.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, Theme.Visual.SidebarWidth + 1, 0, 0),
		Size = UDim2.new(1, -(Theme.Visual.SidebarWidth + 1), 1, 0),
	}, { main })

	local topBar = Util.new("Frame", {
		Name = "TopBar",
		BackgroundColor3 = theme.Backgrounds.Medium,
		BackgroundTransparency = 0,
		Size = UDim2.new(1, 0, 0, 42),
	}, { content })

	local titleLabel = Util.text({
		Parent = topBar,
		Text = "Home",
		Font = Enum.Font.GothamBold,
		TextSize = 16 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -130, 1, 0),
	})

	local controls = Util.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(72, 26),
	}, { topBar })
	Util.list(6, true, controls)

	local function controlButton(text, color)
		local btn = Util.button({
			Parent = controls,
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = theme.Backgrounds.Highlight,
			Radius = 6,
		})
		Util.text({
			Parent = btn,
			Text = text,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 15,
			TextColor3 = color or theme.Foregrounds.Light,
			Size = UDim2.fromScale(1, 1),
		})
		return btn
	end

	local minimizeBtn = controlButton("−")
	local closeBtn = controlButton("×", theme.Miscellaneous.Danger)

	Util.new("Frame", {
		BackgroundColor3 = theme.Miscellaneous.Divider,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
	}, { topBar })

	local pages = Util.new("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 42),
		Size = UDim2.new(1, 0, 1, -42),
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
				TextSize = 10 * Theme.Visual.FontScale,
				TextColor3 = theme.Foregrounds.Dark,
				Size = UDim2.new(1, 0, 0, 14),
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
				BackgroundColor3 = theme.Backgrounds.Dark,
				BackgroundTransparency = 0,
				Size = UDim2.new(1, 0, 0, 32),
				Radius = 6,
			})

			local indicator = Util.new("Frame", {
				Name = "Indicator",
				BackgroundColor3 = theme.Accent,
				Size = UDim2.new(0, 3, 1, -10),
				Position = UDim2.fromOffset(0, 5),
				BackgroundTransparency = 1,
			}, { navButton })

			local navRow = Util.new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}, { navButton })
			Util.list(8, true, navRow)
			Util.padding(0, 10, 0, 14, navRow)

			local navIcon
			if not Util.isEmpty(tabSettings.Icon) then
				navIcon = Util.new("ImageLabel", {
					BackgroundTransparency = 1,
					Image = Util.iconAsset(tabSettings.Icon),
					Size = UDim2.fromOffset(16, 16),
					ImageColor3 = theme.Foregrounds.Medium,
					ImageTransparency = 0,
				}, { navRow })
			end

			local navLabel = Util.text({
				Parent = navRow,
				Text = tabSettings.Name or tabIndex,
				TextSize = 13 * Theme.Visual.FontScale,
				TextColor3 = theme.Foregrounds.Medium,
				Size = UDim2.new(1, 0, 1, 0),
			})

			local page = Util.new("ScrollingFrame", {
				Name = tabIndex,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = theme.Accent,
				BorderSizePixel = 0,
				Visible = false,
			}, { pages })
			Util.padding(14, 14, 14, 14, page)

			local columns = tabSettings.Columns or 2
			local columnsFrame = Util.new("Frame", {
				Name = "Columns",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			}, { page })
			Util.list(12, true, columnsFrame)

			local columnFrames = {}
			for i = 1, columns do
				columnFrames[i] = Util.new("Frame", {
					Name = "Column" .. i,
					BackgroundTransparency = 1,
					Size = UDim2.new(1 / columns, -6, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				}, { columnsFrame })
				Util.list(10, false, columnFrames[i])
			end

			local function styleNav(active)
				indicator.BackgroundTransparency = active and 0 or 1
				navButton.BackgroundColor3 = active and theme.Backgrounds.Highlight or theme.Backgrounds.Dark
				navLabel.TextColor3 = active and theme.Foregrounds.Light or theme.Foregrounds.Medium
				if navIcon then
					navIcon.ImageColor3 = active and theme.Accent or theme.Foregrounds.Medium
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
					BackgroundTransparency = 0,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				}, { holder })
				Util.corner(Theme.Visual.GroupboxRadius, box)
				if Theme.Visual.ShowShadows then
					Util.stroke(theme.Miscellaneous.Divider, 1, 0.55, box)
				end
				Util.padding(12, 12, 12, 12, box)
				Util.list(8, false, box)

				local header = Util.new("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 20),
					LayoutOrder = 1,
				}, { box })
				Util.list(6, true, header)

				if not Util.isEmpty(groupSettings.Icon) then
					Util.new("ImageLabel", {
						BackgroundTransparency = 1,
						Image = Util.iconAsset(groupSettings.Icon),
						Size = UDim2.fromOffset(14, 14),
						ImageColor3 = theme.Accent,
						ImageTransparency = 0,
					}, { header })
				end

				Util.text({
					Parent = header,
					Text = groupSettings.Name or groupIndex,
					Font = Enum.Font.GothamBold,
					TextSize = 13 * Theme.Visual.FontScale,
					TextColor3 = theme.Accent,
					Size = UDim2.new(1, 0, 1, 0),
				})

				Util.new("Frame", {
					BackgroundColor3 = theme.Miscellaneous.Divider,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 1),
					LayoutOrder = 2,
				}, { box })

				local parentingItem = Util.new("Frame", {
					Name = "Elements",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 3,
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
