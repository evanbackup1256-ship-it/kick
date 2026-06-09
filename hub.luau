do
	if not getgenv().Alleral_Tracked then
		getgenv().Alleral_Tracked = true
		pcall(function()
			local req = http_request or request or syn and syn.request
			if req then req({Url = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/hub.luau", Method = "GET"}) end
		end)
	end
end

local HUB_VERSION = "2.0"
local RAW_BASE = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/"
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local gamesList = {
	{
		name = "Kick a Lucky Block",
		file = "kick%20a%20lucky%20block.luau",
		desc = "Automated kicking with filters, training, battles, mastery, weather, and economy management.",
		icon = 10723407389,
		placeIds = { 89469502395769 },
		status = "Ready",
		category = "Farming",
	},
}

local Executor = {}
do
	local env = getgenv()
	local rawName = tostring(identifyexecutor and identifyexecutor() or "")
	Executor.name = rawName:lower()
	Executor.env = env
	Executor.supportsHttp = type(game.HttpGet) == "function"
		or type(syn and syn.request) == "function"
		or type(http_request) == "function"
		or type(request) == "function"
		or type(http and http.request) == "function"
end

local Settings = {}
do
	local env = getgenv()
	env.Alleral_Hub_Settings = env.Alleral_Hub_Settings or {}
	local s = env.Alleral_Hub_Settings
	s.closeOnLaunch = s.closeOnLaunch ~= false
	s.minimizeOnLaunch = s.minimizeOnLaunch or false
	s.favorites = s.favorites or {}
	Settings.data = s
end

local function notify(title, text, duration)
	pcall(function() StarterGui:SetCore("SendNotification", {Title = tostring(title), Text = tostring(text), Duration = duration or 3}) end)
end

local function fetchText(url)
	local cb = "?t=" .. tostring(tick())
	url = url:find("?") and url or (url .. cb)
	local httpReq = syn and syn.request or http_request or request or (http and http.request)
	if httpReq then
		local ok, resp = pcall(httpReq, {Url = url, Method = "GET"})
		if ok and resp and resp.Body and resp.Body ~= "" then
			return resp.Body
		end
	end
	local ok, data = pcall(function()
		if type(game.HttpGet) == "function" then return game:HttpGet(url) end
		return nil
	end)
	if ok and data and data ~= "" and not data:find("404: Not Found") then
		return data
	end
	return nil
end

local function fetchUrl(url)
	return fetchText(url)
end

local function safeCall(scope, cb)
	local ok, r = pcall(cb)
	if not ok then warn("[Hub] " .. tostring(scope) .. ": " .. tostring(r)) end
	return ok, r
end

local function tween(obj, goal, info)
	local tw = TweenService:Create(obj, info or TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function detectCurrentGame()
	for _, info in ipairs(gamesList) do
		if info.placeIds then
			for _, id in ipairs(info.placeIds) do
				if id == game.PlaceId then
					return info
				end
			end
		end
	end
	return nil
end

local function patchStarlightSource(source)
	source = source:gsub("function Tab:Show%(%)[\r\n]+%s*if Library%.ActiveTab then",
		"function Tab:Show()\n\t\t\tif Library.ActiveTab == Tab then\n\t\t\t\treturn\n\t\t\tend\n\t\t\tif Library.ActiveTab then")
	source = source:gsub("local Acrylic = isStudio and require%([^%)]+%)[^\n]+\n[^\n]+AcrylicModule[^\n]+\nAcrylic.Init%(%)\n", "local Acrylic = {Init=function() end}\n")
	source = source:gsub("local function Hide%(Interface, JustHide: boolean%?, Notify: boolean%?, Bind: string%?%)",
		"local function Hide(Interface, JustHide, Notify, Bind)\n\tdo if Interface and Interface.ClassName == \"ScreenGui\" then Interface.Enabled = false Starlight.Minimized = true return end end")
	source = source:gsub("local function Unhide%(Interface%)",
		"local function Unhide(Interface)\n\tdo if Interface and Interface.ClassName == \"ScreenGui\" then Interface.Enabled = true Starlight.Minimized = false return end end")
	local inputStart = source:find("function Groupbox:CreateInput", 1, true)
	local labelStart = inputStart and source:find("function Groupbox:CreateLabel", inputStart, true)
	if not inputStart or not labelStart then return source end
	local before = source:sub(1, inputStart - 1)
	local block = source:sub(inputStart, labelStart - 1)
	local after = source:sub(labelStart)
	block = block:gsub("(Element%.Instance = GroupboxTemplateInstance%.Input_TEMPLATE:Clone%(%)[\r\n]+%s*Element%.Instance%.Visible = true)",
		"%1\n\t\t\t\t\t\tElement.Instance.Parent = Groupbox.ParentingItem", 1)
	block = block:gsub("\n%s*Element%.Instance%.Parent = Groupbox%.ParentingItem\n\n%s*(Starlight%.Window%.TabSections%[Name%]%.Tabs%[TabIndex%]%.Groupboxes%[GroupIndex%]%.Elements%[Index%] = Element)",
		"\n\n\t\t\t\t\t%1", 1)
	return before .. block .. after
end

local STARLIGHT_SRC = "https://raw.githubusercontent.com/Nebula-Softworks/Starlight-Interface-Suite/master/Source.lua"
local STARLIGHT_LOCAL = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/starlight_repo/Source.lua"

local function loadStarlight()
	local src = fetchText(STARLIGHT_SRC)
	if src then
		local ok, r = safeCall("LoadRemote", function()
			return loadstring(patchStarlightSource(src), "@Starlight")()
		end)
		if ok and type(r) == "table" and type(r.CreateWindow) == "function" then return r end
	end
	local src2 = fetchText(STARLIGHT_LOCAL)
	if src2 then
		local ok2, r2 = safeCall("LoadLocal", function()
			return loadstring(patchStarlightSource(src2), "@Starlight")()
		end)
		if ok2 and type(r2) == "table" and type(r2.CreateWindow) == "function" then return r2 end
	end
	return nil
end

local function launchGame(gameInfo)
	if not gameInfo then return end
	local code = fetchUrl(RAW_BASE .. gameInfo.file)
	if not code then notify("Hub Error", "Failed to fetch " .. gameInfo.name, 5) return end
	if starlightWindow then
		local wi = starlightWindow.Instance
		if wi and wi.Parent then
			if Settings.data.minimizeOnLaunch then
				wi.Visible = false
				task.wait(0.1)
			else
				tween(wi, {BackgroundTransparency = 1}, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.In))
				task.wait(0.35)
				wi:Destroy()
			end
		end
	end
	if Settings.data.closeOnLaunch then
		starlight = nil
		starlightWindow = nil
		local env = getgenv()
		env.Starlight = nil
		env.Library = nil
		env.AlleralLib = nil
		task.wait(0.1)
	end
	local fn, err = loadstring(code, "@" .. gameInfo.file)
	if not fn then notify("Hub Error", "Failed to compile: " .. tostring(err), 5) return end
	local ok, e2 = pcall(fn)
	if not ok then notify("Hub Error", tostring(e2), 5) end
end

local starlight = loadStarlight()
if not starlight then warn("[Hub] Failed to load Starlight UI.") return end

local starlightWindow = starlight:CreateWindow({
	Name = "Alleral Hub",
	Subtitle = "Game Launcher v" .. HUB_VERSION,
	Icon = 10723407389,
	LoadingEnabled = false,
	FileSettings = {RootFolder = "Alleral_Configs", ConfigFolder = "Interface"},
})

local starlightSection = starlightWindow:CreateTabSection("Alleral", true)

local hubTab = starlightSection:CreateTab({Name = "Hub", Icon = 10723407389, Columns = 2}, "HubTab")
local settingsTab = starlightSection:CreateTab({Name = "Settings", Icon = 10734950020, Columns = 2}, "SettingsTab")

local execName = Executor.name ~= "" and Executor.name or "Unknown"
local currentGame = detectCurrentGame()

-- ===== HUB TAB (Column 1) =====
local overviewGroup = hubTab:CreateGroupbox({Name = "Overview", Icon = 10723407389, Column = 1}, "OverviewGroup")
overviewGroup:CreateParagraph({Name = "Alleral Hub", Content = "Multi-game script launcher.\nVersion " .. HUB_VERSION .. " | " .. tostring(#gamesList) .. " game(s)"}, "WelcomeText")
overviewGroup:CreateLabel({Name = "Executor: " .. execName}, "ExecLabel")
overviewGroup:CreateLabel({Name = "HTTP: " .. (Executor.supportsHttp and "Yes" or "No")}, "HttpLabel")
overviewGroup:CreateDivider()

local detectedGroup = hubTab:CreateGroupbox({Name = "Detection", Icon = 10734952479, Column = 1}, "DetectedGroup")
if currentGame then
	detectedGroup:CreateParagraph({Name = "Game Detected", Content = "You are in:\n" .. currentGame.name .. "\nPlaceId: " .. tostring(game.PlaceId)}, "DetectedText")
	detectedGroup:CreateDivider()
	detectedGroup:CreateButton({Name = "Launch " .. currentGame.name, Callback = function()
		notify("Hub", "Launching " .. currentGame.name .. "...", 3)
		task.spawn(launchGame, currentGame)
	end}, "DetectedLaunchBtn")
else
	detectedGroup:CreateParagraph({Name = "Not Detected", Content = "PlaceId " .. tostring(game.PlaceId) .. " is not in the hub's game list.\nSelect a game from the list to launch."}, "NoDetectText")
end

local quickGroup = hubTab:CreateGroupbox({Name = "Quick Actions", Icon = 10734950020, Column = 1}, "QuickGroup")
quickGroup:CreateButton({Name = "Copy Support Info", Callback = function()
	local env = getgenv()
	local text = "Alleral Hub v" .. HUB_VERSION .. "\nGame: " .. tostring(game.PlaceId) .. "\nExecutor: " .. execName
	if env.setclipboard then env.setclipboard(text) notify("Hub", "Copied.", 2) else notify("Hub", "Clipboard N/A", 2) end
end}, "CopyBtn")

-- ===== HUB TAB (Column 2): Game Cards =====
local gamesGroup = hubTab:CreateGroupbox({Name = "Available Games", Icon = 10734952479, Column = 2}, "GamesGroup")

for idx, info in ipairs(gamesList) do
	if idx > 1 then gamesGroup:CreateDivider() end

	local isFav = Settings.data.favorites[info.name] == true
	local starPrefix = isFav and "★ " or "☆ "

	gamesGroup:CreateParagraph({Name = starPrefix .. info.name, Content = info.desc .. "\nCategory: " .. (info.category or "General") .. " | PlaceIds: " .. table.concat(info.placeIds or {}, ", ")}, "GameTitle" .. idx)
	gamesGroup:CreateLabel({Name = "Status: " .. info.status}, "GameStatus" .. idx)
	gamesGroup:CreateButton({Name = isFav and "★ Favorited" or "☆ Favorite", Callback = function()
		local current = Settings.data.favorites[info.name] == true
		Settings.data.favorites[info.name] = not current
		notify("Hub", (not current and "Favorited " or "Unfavorited ") .. info.name, 2)
	end}, "GameFavBtn" .. idx)
	gamesGroup:CreateButton({Name = "Launch " .. info.name, Callback = function()
		notify("Hub", "Launching " .. info.name .. "...", 3)
		task.spawn(launchGame, info)
	end}, "LaunchBtn" .. idx)
end

-- ===== SETTINGS TAB =====
local behavGroup = settingsTab:CreateGroupbox({Name = "Launch Behavior", Icon = 10734950020, Column = 1}, "BehavGroup")
local closeToggle = behavGroup:CreateToggle({Name = "Close hub after launch", Value = Settings.data.closeOnLaunch, Callback = function(v)
	Settings.data.closeOnLaunch = v
end}, "CloseToggle")
local minimizeToggle = behavGroup:CreateToggle({Name = "Minimize hub on launch", Value = Settings.data.minimizeOnLaunch, Callback = function(v)
	Settings.data.minimizeOnLaunch = v
end}, "MinimizeToggle")

local dataGroup = settingsTab:CreateGroupbox({Name = "Data", Icon = 10723407389, Column = 1}, "DataGroup")
dataGroup:CreateButton({Name = "Clear All Favorites", Callback = function()
	Settings.data.favorites = {}
	notify("Hub", "Favorites cleared.", 2)
end}, "ClearFavBtn")
dataGroup:CreateButton({Name = "Reset All Settings", Callback = function()
	local env = getgenv()
	env.Alleral_Hub_Settings = { closeOnLaunch = true, minimizeOnLaunch = false, favorites = {} }
	Settings.data = env.Alleral_Hub_Settings
	pcall(function() closeToggle:SetValue(true) end)
	pcall(function() minimizeToggle:SetValue(false) end)
	notify("Hub", "Settings reset.", 2)
end}, "ResetBtn")

local aboutGroup = settingsTab:CreateGroupbox({Name = "About", Icon = 10723407389, Column = 2}, "AboutGroup")
aboutGroup:CreateParagraph({Name = "Alleral Hub", Content = "Version: " .. HUB_VERSION .. "\nGames: " .. tostring(#gamesList) .. "\nHTTP: " .. (Executor.supportsHttp and "Available" or "Unavailable")}, "AboutText")
aboutGroup:CreateDivider()
aboutGroup:CreateParagraph({Name = "Credits", Content = "Alleral Development\nUI: Starlight Interface Suite"}, "CreditsText")

notify("Alleral Hub", "Launcher ready.", 3)

task.spawn(function()
	task.wait(0.1)
	if starlightWindow and starlightWindow.Instance then
		local wi = starlightWindow.Instance
		wi.BackgroundTransparency = 1
		tween(wi, {BackgroundTransparency = 0}, TweenInfo.new(0.6))
	end
end)
