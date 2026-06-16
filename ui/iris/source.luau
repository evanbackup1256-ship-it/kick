-- Alleral Iris — exploit ImGui overlay (GhostDuckyy Iris 2.0.4) + MacLib adapter
local ALLERAL_IRIS_VERSION = 2
local IRIS_VERSION = "2.0.4"
local IRIS_BUNDLE_URL =
	"https://raw.githubusercontent.com/GhostDuckyy/UI-Libraries/main/ImGui/Iris/Versions/2.0.4/Source.lua"
local IRIS_BUNDLE_MIN_BYTES = 250000

local MacLib = {}
MacLib.__AlleralPatch = ALLERAL_IRIS_VERSION
MacLib.__IrisUi = true
MacLib.__IrisExploitUi = true
MacLib.__AlleralVersion = IRIS_VERSION

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local ENV = (function()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end)()

local IrisModule = nil
local Iris = nil
local irisBooted = false
local configFolder = "Alleral_Configs"
local windows = {}
local menuKey = Enum.KeyCode.RightControl
local exploitOverlayKey = Enum.KeyCode.RightShift
local mirrorWindows = {}

local function fetchBundle()
	if type(ENV._AlleralIrisBundle) == "string" and #ENV._AlleralIrisBundle >= IRIS_BUNDLE_MIN_BYTES then
		return ENV._AlleralIrisBundle
	end
	if type(ENV.Alleral_HTTP) == "table" and type(ENV.Alleral_HTTP.get) == "function" then
		local src = ENV.Alleral_HTTP.get(IRIS_BUNDLE_URL .. "?t=" .. tostring(tick()), IRIS_BUNDLE_MIN_BYTES)
		if type(src) == "string" then
			ENV._AlleralIrisBundle = src
			return src
		end
	end
	return nil
end

local function bootIris()
	if irisBooted and Iris then
		return Iris
	end
	local src = fetchBundle()
	if not src then
		return nil, "Iris bundle missing"
	end
	local chunk = loadstring or load
	if type(chunk) ~= "function" then
		return nil, "loadstring unavailable"
	end
	local compiled, err = chunk(src, "@Iris/bundle")
	if not compiled then
		return nil, tostring(err or "Iris compile failed")
	end
	local ok, pkg = pcall(compiled)
	if not ok or type(pkg) ~= "table" then
		return nil, tostring(pkg or "Iris bundle runtime failed")
	end
	IrisModule = pkg
	local player = Players.LocalPlayer
	local parent = player and player:FindFirstChildOfClass("PlayerGui") or nil
	if not parent then
		return nil, "PlayerGui unavailable"
	end
	Iris = pkg.Init(parent, RunService.Heartbeat)
	if type(Iris) ~= "table" then
		return nil, "Iris.Init failed"
	end
	pcall(function()
		Iris.UpdateGlobalConfig({
			Color = {
				TextColor = Color3.fromRGB(235, 235, 235),
				TextDisabledColor = Color3.fromRGB(150, 150, 150),
				WindowBgColor = Color3.fromRGB(18, 18, 20),
				PopupBgColor = Color3.fromRGB(22, 22, 26),
				BorderColor = Color3.fromRGB(60, 60, 66),
				BorderShadowColor = Color3.fromRGB(0, 0, 0),
				ResizeGripColor = Color3.fromRGB(83, 252, 24),
				ResizeGripHoveredColor = Color3.fromRGB(110, 255, 60),
				ResizeGripActiveColor = Color3.fromRGB(83, 252, 24),
				ScrollbarBgColor = Color3.fromRGB(14, 14, 16),
				ScrollbarGrabColor = Color3.fromRGB(70, 70, 74),
				ScrollbarGrabHoveredColor = Color3.fromRGB(90, 90, 96),
				ScrollbarGrabActiveColor = Color3.fromRGB(83, 252, 24),
				SliderGrabColor = Color3.fromRGB(83, 252, 24),
				SliderGrabActiveColor = Color3.fromRGB(110, 255, 60),
				ButtonColor = Color3.fromRGB(34, 34, 38),
				ButtonHoveredColor = Color3.fromRGB(48, 48, 54),
				ButtonActiveColor = Color3.fromRGB(83, 252, 24),
				HeaderColor = Color3.fromRGB(34, 34, 38),
				HeaderHoveredColor = Color3.fromRGB(48, 48, 54),
				HeaderActiveColor = Color3.fromRGB(83, 252, 24),
				TabColor = Color3.fromRGB(28, 28, 32),
				TabHoveredColor = Color3.fromRGB(48, 48, 54),
				TabActiveColor = Color3.fromRGB(34, 34, 38),
				TableHeaderBgColor = Color3.fromRGB(28, 28, 32),
				TableBorderStrongColor = Color3.fromRGB(60, 60, 66),
				TableBorderLightColor = Color3.fromRGB(44, 44, 48),
				TableRowBgColor = Color3.fromRGB(0, 0, 0),
				TableRowBgAltColor = Color3.fromRGB(255, 255, 255),
				TextSelectedBgColor = Color3.fromRGB(83, 252, 24),
				DragDropTargetColor = Color3.fromRGB(83, 252, 24),
				NavHighlightColor = Color3.fromRGB(83, 252, 24),
				NavWindowingHighlightColor = Color3.fromRGB(255, 255, 255),
				NavWindowingDimBgColor = Color3.fromRGB(0, 0, 0),
				ModalWindowDimBgColor = Color3.fromRGB(0, 0, 0),
			},
		})
	end)
	Iris:Connect(function()
		for _, win in ipairs(windows) do
			if win.visible ~= false then
			local opened = Iris.Window({
				Title = win.title,
				NoClose = false,
				NoResize = false,
			}, win.openState)
			if opened then
				for index, tab in ipairs(win.tabs) do
					if Iris.Button({ tab.name .. "##tab_" .. tostring(index) }) then
						win.activeTab = index
					end
					if index < #win.tabs then
						pcall(Iris.SameLine, Iris)
					end
				end
				Iris.Separator()
				local tab = win.tabs[win.activeTab]
				if tab then
					for _, section in ipairs(tab.sections) do
						local expanded = Iris.CollapsingHeader({ section.name }, section.openState)
						if expanded then
							for _, element in ipairs(section.elements) do
								if element.kind == "toggle" then
									Iris.Checkbox({ element.name }, element.state)
									local value = element.state:get()
									if value ~= element.last then
										element.last = value
										if element.callback then
											element.callback(value)
										end
									end
								elseif element.kind == "slider" then
									Iris.SliderNum({
										Text = element.name,
										Min = element.min,
										Max = element.max,
										Increment = element.step,
									}, element.state)
									local value = element.state:get()
									if value ~= element.last then
										element.last = value
										if element.callback then
											element.callback(value)
										end
									end
								elseif element.kind == "button" then
									if Iris.Button({ element.name }) and element.callback then
										element.callback()
									end
								elseif element.kind == "input" then
									Iris.InputText({ Text = element.name }, element.state)
									local value = element.state:get()
									if value ~= element.last then
										element.last = value
										if element.callback then
											element.callback(value)
										end
									end
								elseif element.kind == "label" then
									Iris.Text({ element.text })
								elseif element.kind == "divider" then
									Iris.Separator()
								elseif element.kind == "dropdown" then
									local previewText = type(element.previewFn) == "function" and element.previewFn() or element.preview
									Iris.Text({ element.name })
									if Iris.Combo({ Text = previewText }, element.openState) then
										for optIndex, option in ipairs(element.options) do
											if Iris.Selectable({ option, optIndex }, element.indexState) then
												element.indexState:set(optIndex)
												if not element.multi then
													element.selectedSingle = option
												end
												if element.callback then
													if element.multi then
														element.callback(element.selected())
													else
														element.callback(option)
													end
												end
											end
										end
										Iris.End()
									end
									Iris.End()
								elseif element.kind == "keybind" then
									if element.listening then
										Iris.Text({ element.name .. ": press a key..." })
									else
										if Iris.Button({ element.name .. ": " .. tostring(element.keyName or "None") }) then
											element.listening = true
										end
									end
								end
							end
						end
						Iris.End()
					end
				end
			end
			Iris.End()
			end
		end
	end)
	irisBooted = true
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not irisBooted then
			return
		end
		for _, win in ipairs(windows) do
			for _, tab in ipairs(win.tabs) do
				for _, section in ipairs(tab.sections) do
					for _, element in ipairs(section.elements) do
						if element.kind == "keybind" and element.listening and input.UserInputType == Enum.UserInputType.Keyboard then
							element.keyName = input.KeyCode.Name
							element.listening = false
							if element.callback then
								element.callback(input.KeyCode)
							end
						end
					end
				end
			end
		end
	end)
	return Iris
end

local function sideOrder(side)
	if side == "Right" then
		return 300
	end
	if side == "Center" then
		return 200
	end
	return 100
end

function MacLib.SetFolder(_self, folder)
	if type(folder) == "string" and folder ~= "" then
		configFolder = folder
	end
end

function MacLib.ApplyEffectsFromEnv(_self, _env)
	return true
end

function MacLib.SetAutoResize(_self, _state)
	return true
end

function MacLib.GetAutoResize(_self)
	return true
end

function MacLib.GetUiScale(_self)
	return 1
end

function MacLib.GetLayoutInfo(_self)
	return { profile = "iris", engine = "Iris", version = IRIS_VERSION, exploitOverlay = true }
end

function MacLib.AttachExploitMirror(_self, onyxWindow)
	if type(onyxWindow) ~= "table" then
		return false
	end
	table.insert(mirrorWindows, onyxWindow)
	return true
end

function MacLib:Window(Settings)
	Settings = Settings or {}
	local ir, err = bootIris()
	if not ir then
		warn("[Alleral Iris] " .. tostring(err))
		return nil
	end

	local WindowFunctions = {
		Settings = Settings,
		_tabs = {},
		_activeTab = nil,
		visible = true,
		title = Settings.Title or "Alleral",
		openState = Iris.State(true),
		activeTab = 1,
		tabs = {},
	}

	if Settings.Keybind then
		menuKey = Settings.Keybind
	end

	table.insert(windows, WindowFunctions)

	function WindowFunctions:TabGroup()
		local TabGroupFunctions = {}
		function TabGroupFunctions:Tab(TabSettings)
			TabSettings = TabSettings or {}
			local TabFunctions = { Settings = TabSettings, _sections = {} }
			local tabData = {
				name = TabSettings.Name or "Tab",
				sections = {},
			}
			TabFunctions._tabData = tabData

			function TabFunctions:Select()
				for index, tab in ipairs(WindowFunctions.tabs) do
					if tab == tabData then
						WindowFunctions.activeTab = index
						break
					end
				end
			end

			function TabFunctions:Section(SectionSettings)
				SectionSettings = SectionSettings or {}
				local SectionFunctions = {}
				local sectionData = {
					name = SectionSettings.Name or SectionSettings.Text or "Section",
					openState = Iris.State(true),
					elements = {},
					order = sideOrder(SectionSettings.Side),
				}

				local function addElement(element)
					element.order = element.order or (#sectionData.elements + 1)
					table.insert(sectionData.elements, element)
					return element
				end

				function SectionFunctions:Header(HS, _flag)
					local text = (HS and (HS.Text or HS.Name)) or ""
					addElement({ kind = "label", text = text, order = 0 })
					return {
						UpdateName = function(_, value)
							text = tostring(value)
						end,
					}
				end

				function SectionFunctions:Label(LS, _flag)
					local text = (LS and (LS.Text or LS.Name)) or ""
					addElement({ kind = "label", text = text })
					return {
						UpdateName = function(_, value)
							text = tostring(value)
						end,
					}
				end

				function SectionFunctions:Divider()
					addElement({ kind = "divider" })
					return {}
				end

				function SectionFunctions:Button(BS, _flag)
					addElement({
						kind = "button",
						name = BS and BS.Name or "Button",
						callback = BS and BS.Callback,
					})
					return {
						UpdateName = function(_, value)
							-- rendered next frame
						end,
					}
				end

				function SectionFunctions:Toggle(TS, _flag)
					local state = Iris.State(TS and TS.Default == true)
					local element = addElement({
						kind = "toggle",
						name = TS and TS.Name or "Toggle",
						state = state,
						last = state:get(),
						callback = TS and TS.Callback,
					})
					return {
						UpdateState = function(_, value)
							state:set(value == true)
							element.last = state:get()
						end,
						GetState = function()
							return state:get()
						end,
					}
				end

				function SectionFunctions:Slider(SS, _flag)
					local minV = tonumber(SS and SS.Minimum) or 0
					local maxV = tonumber(SS and SS.Maximum) or 100
					local default = tonumber(SS and SS.Default) or minV
					local state = Iris.State(default)
					local element = addElement({
						kind = "slider",
						name = SS and SS.Name or "Slider",
						min = minV,
						max = maxV,
						step = tonumber(SS and SS.Increment) or 1,
						state = state,
						last = state:get(),
						callback = SS and SS.Callback,
					})
					return {
						UpdateValue = function(_, value)
							state:set(tonumber(value) or minV)
							element.last = state:get()
						end,
						GetValue = function()
							return state:get()
						end,
					}
				end

				function SectionFunctions:Input(IS, _flag)
					local state = Iris.State(IS and IS.Default or "")
					local element = addElement({
						kind = "input",
						name = IS and IS.Name or "Input",
						state = state,
						last = state:get(),
						callback = IS and IS.Callback,
					})
					return {
						UpdateText = function(_, value)
							state:set(tostring(value))
							element.last = state:get()
						end,
					}
				end

				function SectionFunctions:Dropdown(DS, _flag)
					local options = DS and DS.Options or {}
					local multi = DS and DS.Multi == true
					local indexState = Iris.State(1)
					local openState = Iris.State(false)
					local selected = {}
					if multi and type(DS.Default) == "table" then
						selected = DS.Default
					elseif DS and DS.Default then
						selected = { tostring(DS.Default) }
					elseif options[1] then
						selected = { tostring(options[1]) }
					end
					local function previewText()
						if multi then
							return table.concat(selected, ", ")
						end
						return tostring(selected[1] or options[1] or "Select")
					end
					addElement({
						kind = "dropdown",
						name = DS and DS.Name or "Dropdown",
						options = options,
						multi = multi,
						openState = openState,
						indexState = indexState,
						previewFn = previewText,
						selectedSingle = selected[1],
						selected = function()
							return multi and selected or selected[1]
						end,
						callback = DS and DS.Callback,
					})
					return {
						Refresh = function() end,
						SetValues = function(_, values)
							options = values or options
						end,
					}
				end

				function SectionFunctions:Keybind(KS, _flag)
					addElement({
						kind = "keybind",
						name = KS and KS.Name or "Keybind",
						keyName = tostring(menuKey.Name),
						listening = false,
						callback = KS and KS.Callback,
					})
					return {}
				end

				table.insert(tabData.sections, sectionData)
				table.sort(tabData.sections, function(a, b)
					return (a.order or 0) < (b.order or 0)
				end)
				return SectionFunctions
			end

			table.insert(WindowFunctions.tabs, tabData)
			if #WindowFunctions.tabs == 1 then
				WindowFunctions.activeTab = 1
			end
			table.insert(WindowFunctions._tabs, TabFunctions)
			return TabFunctions
		end
		return TabGroupFunctions
	end

	function WindowFunctions:Notify(payload)
		payload = type(payload) == "table" and payload or {}
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = payload.Title or "Alleral",
				Text = payload.Description or payload.Content or "",
				Duration = payload.Lifetime or payload.Duration or 4,
			})
		end)
	end

	function WindowFunctions:SetState(state)
		WindowFunctions.visible = state ~= false
		WindowFunctions.openState:set(WindowFunctions.visible)
	end

	function WindowFunctions:GetState()
		return WindowFunctions.visible
	end

	function WindowFunctions:Unload()
		WindowFunctions.visible = false
		for index, win in ipairs(windows) do
			if win == WindowFunctions then
				table.remove(windows, index)
				break
			end
		end
	end

	WindowFunctions._macTabGroup = WindowFunctions:TabGroup()
	return WindowFunctions
end

return MacLib
