do
	if not getgenv().Alleral_Tracked then
		getgenv().Alleral_Tracked = true
		pcall(function()
			local req = http_request or request or syn and syn.request
			if req then req({Url = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/hub.luau", Method = "GET"}) end
		end)
	end
end

local HUB_VERSION = "1.0"
local RAW_BASE = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/"
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local gamesList = {
	{
		name = "Kick a Lucky Block",
		file = "kick%20a%20lucky%20block.luau",
		desc = "Automated kicking with filters, training, battles, mastery, weather, and economy management.",
		icon = 10723407389,
		placeIds = { 89469502395769 },
		status = "Ready",
	},
}

local Executor = {}
do
	local env = getgenv()
	local rawName = tostring(identifyexecutor and identifyexecutor() or "")
	Executor.name = rawName:lower()
	Executor.hasHttp = type(HttpService.HttpGet) == "function" or type(HttpService.RequestAsync) == "function"
	Executor.env = env
end

local function notify(title, text, duration)
	pcall(function() StarterGui:SetCore("SendNotification", {Title = tostring(title), Text = tostring(text), Duration = duration or 3}) end)
end

local function fetchUrl(url)
	local ok, data = pcall(function() return game:HttpGet(url) end)
	if not ok or not data or data == "" or data:find("404: Not Found") then return nil end
	return data
end

local function safeCall(scope, cb)
	local ok, r = pcall(cb)
	if not ok then warn("[Hub] " .. tostring(scope) .. ": " .. tostring(r)) end
	return ok, r
end

local starlight
local starlightWindow
local starlightSection
local hubTab

local function patchStarlightSource(source)
	source = source:gsub("function Tab:Show%(%)[\r\n]+%s*if Library%.ActiveTab then",
		"function Tab:Show()\n\t\t\tif Library.ActiveTab == Tab then\n\t\t\t\treturn\n\t\t\tend\n\t\t\tif Library.ActiveTab then")
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
	local ok, r = safeCall("LoadRemote", function()
		return loadstring(patchStarlightSource(game:HttpGet(STARLIGHT_SRC)), "@Starlight")()
	end)
	if ok and type(r) == "table" and type(r.CreateWindow) == "function" then return r end
	local ok2, r2 = safeCall("LoadLocal", function()
		return loadstring(patchStarlightSource(game:HttpGet(STARLIGHT_LOCAL)), "@Starlight")()
	end)
	if ok2 and type(r2) == "table" and type(r2.CreateWindow) == "function" then return r2 end
	return nil
end

local function tween(obj, goal, info)
	local tw = TweenService:Create(obj, info or TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function launchGame(gameInfo)
	if not gameInfo then return end
	local code = fetchUrl(RAW_BASE .. gameInfo.file)
	if not code then notify("Hub Error", "Failed to fetch " .. gameInfo.name, 5) return end
	if starlightWindow then
		local wi = starlightWindow.Instance
		if wi and wi.Parent then
			tween(wi, {BackgroundTransparency = 1}, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.In))
			task.wait(0.35)
			wi:Destroy()
		end
	end
	starlight = nil
	starlightWindow = nil
	local env = getgenv()
	env.Starlight = nil
	env.Library = nil
	env.AlleralLib = nil
	task.wait(0.1)
	local fn, err = loadstring(code, "@" .. gameInfo.file)
	if not fn then notify("Hub Error", "Failed to compile: " .. tostring(err), 5) return end
	local ok, e2 = pcall(fn)
	if not ok then notify("Hub Error", tostring(e2), 5) end
end

local function autoDetectAndLaunch()
	for _, info in ipairs(gamesList) do
		if info.placeIds then
			for _, id in ipairs(info.placeIds) do
				if id == game.PlaceId then
					task.wait(0.5)
					notify("Alleral Hub", "Detected " .. info.name .. "!", 3)
					task.spawn(launchGame, info)
					return true
				end
			end
		end
	end
	return false
end

starlight = loadStarlight()
if not starlight then warn("[Hub] Failed to load Starlight UI.") return end

starlightWindow = starlight:CreateWindow({
	Name = "Alleral Hub",
	Subtitle = "Game Launcher",
	Icon = 10723407389,
	LoadingEnabled = false,
	FileSettings = {RootFolder = "Alleral_Configs", ConfigFolder = "Interface"},
})

starlightSection = starlightWindow:CreateTabSection("Alleral", true)
hubTab = starlightSection:CreateTab({Name = "Hub", Icon = 10723407389, Columns = 2}, "HubTab")

local execName = Executor.name ~= "" and Executor.name or "Unknown"

local welcomeGroup = hubTab:CreateGroupbox({Name = "Welcome", Icon = 10723407389, Column = 1}, "WelcomeGroup")
welcomeGroup:CreateParagraph({Name = "Alleral Hub", Content = "Select a game to launch.\nVersion " .. HUB_VERSION .. " | Multi-game hub"}, "WelcomeText")
welcomeGroup:CreateLabel({Name = "Executor: " .. execName}, "ExecLabel")
welcomeGroup:CreateDivider()

local statsGroup = hubTab:CreateGroupbox({Name = "Session", Icon = 10734950020, Column = 1}, "StatsGroup")
statsGroup:CreateParagraph({Name = "Info", Content = "Hub v" .. HUB_VERSION .. "\nPlaceId: " .. tostring(game.PlaceId) .. "\nGames: " .. tostring(#gamesList)}, "StatsText")
statsGroup:CreateDivider()
statsGroup:CreateButton({Name = "Copy Support Info", Callback = function()
	local env = getgenv()
	local text = "Alleral Hub v" .. HUB_VERSION .. "\nGame: " .. tostring(game.PlaceId) .. "\nExecutor: " .. execName
	if env.setclipboard then env.setclipboard(text) notify("Hub", "Copied.", 2) else notify("Hub", "Clipboard N/A", 2) end
end}, "CopyBtn")

local gamesGroup = hubTab:CreateGroupbox({Name = "Available Games", Icon = 10734952479, Column = 2}, "GamesGroup")

for idx, gameInfo in ipairs(gamesList) do
	if idx > 1 then gamesGroup:CreateDivider() end
	gamesGroup:CreateParagraph({Name = gameInfo.name, Content = gameInfo.desc}, "GameTitle" .. idx)
	gamesGroup:CreateLabel({Name = "Status: " .. gameInfo.status}, "GameStatus" .. idx)
	gamesGroup:CreateDivider()
	gamesGroup:CreateButton({Name = "Launch " .. gameInfo.name, Callback = function()
		notify("Hub", "Launching " .. gameInfo.name .. "...", 3)
		task.spawn(launchGame, gameInfo)
	end}, "LaunchBtn" .. idx)

	task.spawn(function()
		local thumbUrl = "https://thumbnails.roblox.com/v1/places/gameicons?placeIds=" .. tostring((gameInfo.placeIds or {})[1] or "") .. "&size=512x512&format=Png"
		local ok, json = pcall(function() return game:HttpGet(thumbUrl) end)
		if ok and json and not json:find("404") then
			local ok2, decoded = pcall(function() return HttpService:JSONDecode(json) end)
			if ok2 and decoded and decoded.data and decoded.data[1] and decoded.data[1].imageUrl then
				local imgUrl = decoded.data[1].imageUrl
				task.wait(0.5)
				if gamesGroup and gamesGroup.Instance then
					local img = Instance.new("ImageLabel")
					img.Size = UDim2.new(0, 48, 0, 48)
					img.Position = UDim2.new(0, 10, 0, 10)
					img.BackgroundTransparency = 1
					img.Image = imgUrl
					img.ScaleType = Enum.ScaleType.Fit
					img.BorderSizePixel = 0
					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(0, 6)
					corner.Parent = img
					local container = gamesGroup.Instance:FindFirstChild("ScrollingFrame", true) or gamesGroup.Instance
					img.Parent = container
				end
			end
		end
	end)
end

notify("Alleral Hub", "Launcher ready.", 3)

task.spawn(function()
	task.wait(0.1)
	if starlightWindow and starlightWindow.Instance then
		local wi = starlightWindow.Instance
		wi.BackgroundTransparency = 1
		tween(wi, {BackgroundTransparency = 0}, TweenInfo.new(0.6))
	end
end)

task.spawn(autoDetectAndLaunch)