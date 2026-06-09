do
	if not getgenv().Alleral_Tracked then
		getgenv().Alleral_Tracked = true
		pcall(function()
			local req = http_request or request or syn and syn.request
			if req then req({Url = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/hub.luau", Method = "GET"}) end
		end)
	end
end

local HUB_VER = "3.0"
local RAW = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/"
local Ts = game:GetService("TweenService")
local Hs = game:GetService("HttpService")
local Ps = game:GetService("Players")
local Sg = game:GetService("StarterGui")
local Me = Ps.LocalPlayer

local games = {
	{
		name = "Kick a Lucky Block",
		file = "kick%20a%20lucky%20block.luau",
		desc = "Auto kick, filters, training, battles, mastery, weather, economy management. Everything in one box.",
		icon = 10723407389,
		placeIds = { 89469502395769 },
		status = "Ready",
		tag = "Farming",
	},
}

local Ex = {}
do
	local e = getgenv()
	local r = tostring(identifyexecutor and identifyexecutor() or "")
	Ex.name = r:lower()
	Ex.env = e
	Ex.http = type(game.HttpGet) == "function" or type(syn and syn.request) == "function" or type(http_request) == "function" or type(request) == "function" or type(http and http.request) == "function"
end

local Cfg = {}
do
	local e = getgenv()
	e.Alleral_Hub_Settings = e.Alleral_Hub_Settings or {}
	local s = e.Alleral_Hub_Settings
	s.closeOnLaunch = s.closeOnLaunch ~= false
	s.minimizeOnLaunch = s.minimizeOnLaunch or false
	s.favorites = s.favorites or {}
	Cfg.data = s
end

local function pop(t, d)
	pcall(function() Sg:SetCore("SendNotification", {Title = tostring(t), Text = tostring(d or ""), Duration = 3}) end)
end

local function grab(url)
	local cb = "?ck=" .. tostring(tick())
	url = url:find("?") and url or (url .. cb)
	local r = syn and syn.request or http_request or request or (http and http.request)
	if r then
		local ok, resp = pcall(r, {Url = url, Method = "GET"})
		if ok and resp and resp.Body and resp.Body ~= "" then return resp.Body end
	end
	local ok, d = pcall(function()
		if type(game.HttpGet) == "function" then return game:HttpGet(url) end
		return nil
	end)
	if ok and d and d ~= "" and not d:find("404: Not Found") then return d end
	return nil
end

local function soft(scope, cb)
	local ok, r = pcall(cb)
	if not ok then warn("[Hub] " .. tostring(scope) .. ": " .. tostring(r)) end
	return ok, r
end

local function tween(o, g, info)
	local tw = Ts:Create(o, info or TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), g)
	tw:Play()
	return tw
end

local function detect()
	for _, info in ipairs(games) do
		if info.placeIds then
			for _, id in ipairs(info.placeIds) do
				if id == game.PlaceId then return info end
			end
		end
	end
	return nil
end

local function patchStar(src)
	src = src:gsub("function Tab:Show%(%)[\r\n]+%s*if Library%.ActiveTab then",
		"function Tab:Show()\n\t\t\tif Library.ActiveTab == Tab then\n\t\t\t\treturn\n\t\t\tend\n\t\t\tif Library.ActiveTab then")
	src = src:gsub("local Acrylic = isStudio and require%([^%)]+%)[^\n]+\n[^\n]+AcrylicModule[^\n]+\nAcrylic.Init%(%)\n", "local Acrylic = {Init=function() end}\n")
	src = src:gsub("local function Hide%(Interface, JustHide: boolean%?, Notify: boolean%?, Bind: string%?%)",
		"local function Hide(Interface, JustHide, Notify, Bind)\n\tdo if Interface and Interface.ClassName == \"ScreenGui\" then Interface.Enabled = false Starlight.Minimized = true return end end")
	src = src:gsub("local function Unhide%(Interface%)",
		"local function Unhide(Interface)\n\tdo if Interface and Interface.ClassName == \"ScreenGui\" then Interface.Enabled = true Starlight.Minimized = false return end end")
	local inp = src:find("function Groupbox:CreateInput", 1, true)
	local lbl = inp and src:find("function Groupbox:CreateLabel", inp, true)
	if not inp or not lbl then return src end
	local b4 = src:sub(1, inp - 1)
	local blk = src:sub(inp, lbl - 1)
	local aft = src:sub(lbl)
	blk = blk:gsub("(Element%.Instance = GroupboxTemplateInstance%.Input_TEMPLATE:Clone%(%)[\r\n]+%s*Element%.Instance%.Visible = true)",
		"%1\n\t\t\t\t\t\tElement.Instance.Parent = Groupbox.ParentingItem", 1)
	blk = blk:gsub("\n%s*Element%.Instance%.Parent = Groupbox%.ParentingItem\n\n%s*(Starlight%.Window%.TabSections%[Name%]%.Tabs%[TabIndex%]%.Groupboxes%[GroupIndex%]%.Elements%[Index%] = Element)",
		"\n\n\t\t\t\t\t%1", 1)
	return b4 .. blk .. aft
end

local STAR_URL = "https://raw.githubusercontent.com/Nebula-Softworks/Starlight-Interface-Suite/master/Source.lua"
local STAR_LOCAL = "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/starlight_repo/Source.lua"

local function loadStar()
	local src = grab(STAR_URL)
	if src then
		local ok, r = soft("LoadRemote", function() return loadstring(patchStar(src), "@Starlight")() end)
		if ok and type(r) == "table" and type(r.CreateWindow) == "function" then return r end
	end
	local src2 = grab(STAR_LOCAL)
	if src2 then
		local ok2, r2 = soft("LoadLocal", function() return loadstring(patchStar(src2), "@Starlight")() end)
		if ok2 and type(r2) == "table" and type(r2.CreateWindow) == "function" then return r2 end
	end
	return nil
end

local function launch(info)
	if not info then return end
	local code = grab(RAW .. info.file)
	if not code then pop("Hub Error", "Failed to fetch " .. info.name) return end
	if starWin then
		local wi = starWin.Instance
		if wi and wi.Parent then
			if Cfg.data.minimizeOnLaunch then
				wi.Visible = false
				task.wait(0.1)
			else
				tween(wi, {BackgroundTransparency = 1}, TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.In))
				task.wait(0.35)
				wi:Destroy()
			end
		end
	end
	if Cfg.data.closeOnLaunch then
		starlightLib = nil
		starWin = nil
		local e = getgenv()
		e.Starlight = nil
		e.Library = nil
		e.AlleralLib = nil
		task.wait(0.1)
	end
	local fn, err = loadstring(code, "@" .. info.file)
	if not fn then pop("Hub Error", "Failed to compile: " .. tostring(err)) return end
	local ok, e2 = pcall(fn)
	if not ok then pop("Hub Error", tostring(e2)) end
end

-- real-time auto-update for hub itself
local HUB_SRC = RAW .. "hub.luau"
local function contentHash(text)
	if not text then return "" end
	local a, b = 0, 0
	for i = 1, #text do
		local byte = string.byte(text, i)
		a = (a + byte) % 65521
		b = (b + a) % 65521
	end
	return tostring((b * 65536 + a) % 2147483647)
end

local env = getgenv()
env._HubStamp = env._HubStamp or ""

if env._HubStamp == "" then
	local raw = grab(HUB_SRC)
	if raw then env._HubStamp = contentHash(raw) end
end

task.spawn(function()
	while task.wait(25 + math.random(0, 10)) do
		if not starWin then break end
		local raw = grab(HUB_SRC)
		if raw then
			local h = contentHash(raw)
			if h ~= env._HubStamp and env._HubStamp ~= "" then
				env._HubStamp = h
				if starWin and starWin.Instance then
					pcall(starWin.Instance.Destroy, starWin.Instance)
				end
				local fn, err = loadstring(raw, "@HubLive")
				if fn then pcall(fn) end
				break
			end
			env._HubStamp = h
		end
	end
end)

local starlightLib = loadStar()
if not starlightLib then warn("[Hub] Starlight UI failed to load.") return end

local starWin = starlightLib:CreateWindow({
	Name = "alleral hub",
	Subtitle = "game launcher v" .. HUB_VER,
	Icon = 10723407389,
	LoadingEnabled = false,
	FileSettings = {RootFolder = "Alleral_Configs", ConfigFolder = "Interface"},
})

local starSec = starWin:CreateTabSection("alleral", true)

local hubTab = starSec:CreateTab({Name = "hub", Icon = 10723407389, Columns = 2}, "HubTab")
local setTab = starSec:CreateTab({Name = "settings", Icon = 10734950020, Columns = 2}, "SettingsTab")

local execName = Ex.name ~= "" and Ex.name or "Unknown"
local current = detect()

-- col 1: overview
local ovGroup = hubTab:CreateGroupbox({Name = "overview", Icon = 10723407389, Column = 1}, "OvGroup")
ovGroup:CreateParagraph({Name = "alleral hub", Content = "multi-game launcher\nv" .. HUB_VER .. " | " .. tostring(#games) .. " games loaded"}, "Welcome")
ovGroup:CreateLabel({Name = "executor: " .. execName}, "ExecLabel")
ovGroup:CreateLabel({Name = "http: " .. (Ex.http and "yes" or "no")}, "HttpLabel")
ovGroup:CreateDivider()
ovGroup:CreateParagraph({Name = "what's new", Content = "• auto-update polls repo every ~30s\n• better game detection\n• profiles and favorites\n• smoother UI"}, "WhatsNew")
ovGroup:CreateDivider()

local detGroup = hubTab:CreateGroupbox({Name = "game detection", Icon = 10734952479, Column = 1}, "DetGroup")
if current then
	detGroup:CreateParagraph({Name = "game found", Content = current.name .. "\nplaceId: " .. tostring(game.PlaceId)}, "DetText")
	detGroup:CreateDivider()
	detGroup:CreateButton({Name = "launch " .. current.name, Callback = function()
		pop("hub", "firing up " .. current.name .. "...")
		task.spawn(launch, current)
	end}, "DetBtn")
else
	detGroup:CreateParagraph({Name = "nothing detected", Content = "placeId " .. tostring(game.PlaceId) .. " isnt in the list.\npick a game from the right panel."}, "NoDet")
end

local actGroup = hubTab:CreateGroupbox({Name = "quick actions", Icon = 10734950020, Column = 1}, "ActGroup")
actGroup:CreateButton({Name = "copy debug info", Callback = function()
	local t = "alleral hub v" .. HUB_VER .. "\ngame: " .. tostring(game.PlaceId) .. "\nexecutor: " .. execName
	if getgenv().setclipboard then getgenv().setclipboard(t) pop("hub", "copied.") else pop("hub", "clipboard n/a") end
end}, "CopyBtn")
actGroup:CreateDivider()
actGroup:CreateButton({Name = "reload hub", Callback = function()
	local raw = grab(HUB_SRC)
	if raw then
		if starWin and starWin.Instance then pcall(starWin.Instance.Destroy, starWin.Instance) end
		local fn, err = loadstring(raw, "@HubReload")
		if fn then pcall(fn) else pop("hub", "reload failed: " .. tostring(err)) end
	else
		pop("hub", "couldnt fetch hub source")
	end
end}, "ReloadBtn")

-- col 2: game cards
local gmGroup = hubTab:CreateGroupbox({Name = "game library", Icon = 10734952479, Column = 2}, "GmGroup")

for i, info in ipairs(games) do
	if i > 1 then gmGroup:CreateDivider() end
	local fav = Cfg.data.favorites[info.name] == true
	local star = fav and "★ " or "☆ "

	gmGroup:CreateParagraph({Name = star .. info.name, Content = info.desc .. "\ntype: " .. (info.tag or "general") .. " | IDs: " .. table.concat(info.placeIds or {}, ", ")}, "GameT" .. i)
	gmGroup:CreateLabel({Name = "status: " .. info.status}, "GameS" .. i)
	gmGroup:CreateButton({Name = fav and "★ favorited" or "☆ favorite", Callback = function()
		local c = Cfg.data.favorites[info.name] == true
		Cfg.data.favorites[info.name] = not c
		pop("hub", (not c and "favorited " or "unfavorited ") .. info.name)
	end}, "FavBtn" .. i)
	gmGroup:CreateButton({Name = "launch " .. info.name, Callback = function()
		pop("hub", "starting " .. info.name .. "...")
		task.spawn(launch, info)
	end}, "LchBtn" .. i)
end

-- settings tab
local behGroup = setTab:CreateGroupbox({Name = "launch behavior", Icon = 10734950020, Column = 1}, "BehGroup")
local closeToggle = behGroup:CreateToggle({Name = "close hub after launch", Value = Cfg.data.closeOnLaunch, Callback = function(v)
	Cfg.data.closeOnLaunch = v
end}, "CloseTog")
local minToggle = behGroup:CreateToggle({Name = "minimize on launch", Value = Cfg.data.minimizeOnLaunch, Callback = function(v)
	Cfg.data.minimizeOnLaunch = v
end}, "MinTog")

local datGroup = setTab:CreateGroupbox({Name = "data", Icon = 10723407389, Column = 1}, "DatGroup")
datGroup:CreateButton({Name = "clear favorites", Callback = function()
	Cfg.data.favorites = {}
	pop("hub", "favorites cleared.")
end}, "ClrFav")
datGroup:CreateButton({Name = "reset everything", Callback = function()
	local e = getgenv()
	e.Alleral_Hub_Settings = { closeOnLaunch = true, minimizeOnLaunch = false, favorites = {} }
	Cfg.data = e.Alleral_Hub_Settings
	pcall(function() closeToggle:SetValue(true) end)
	pcall(function() minToggle:SetValue(false) end)
	pop("hub", "all settings back to default.")
end}, "ResetBtn")

local abtGroup = setTab:CreateGroupbox({Name = "about", Icon = 10723407389, Column = 2}, "AbtGroup")
abtGroup:CreateParagraph({Name = "alleral hub", Content = "version: " .. HUB_VER .. "\ngames: " .. tostring(#games) .. "\nhttp: " .. (Ex.http and "available" or "unavailable")}, "AbtText")
abtGroup:CreateDivider()
abtGroup:CreateParagraph({Name = "credits", Content = "alleral development\nui: starlight suite\nlive-reload enabled"}, "Credits")

pop("alleral hub", "launcher ready.", 3)

task.spawn(function()
	task.wait(0.1)
	if starWin and starWin.Instance then
		local wi = starWin.Instance
		wi.BackgroundTransparency = 1
		tween(wi, {BackgroundTransparency = 0}, TweenInfo.new(0.6))
	end
end)
