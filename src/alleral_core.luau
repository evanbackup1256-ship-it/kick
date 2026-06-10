--[[ Alleral shared bootstrap — loaded by loader into getgenv().Alleral_Core ]]

local Core = {}
Core.VERSION = "1.1"

local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local STARLIGHT_REMOTE_URLS = {
	"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/vendor/starlight/Source.lua",
	"https://raw.githubusercontent.com/Nebula-Softworks/Starlight-Interface-Suite/master/Source.lua",
}
local STARLIGHT_LOCAL_FILES = {
	"vendor/starlight/Source.lua",
	"starlight/Source.lua",
	"kick/vendor/starlight/Source.lua",
	"kick/kick/vendor/starlight/Source.lua",
}

local function genv()
	local ok, env = pcall(function()
		return getgenv and getgenv() or getfenv()
	end)
	return ok and env or {}
end

local ENV = genv()

function Core.notify(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title or "Alleral",
			Text = text or "",
			Duration = duration or 4,
		})
	end)
end

function Core.requestFunction()
	for _, name in ipairs({ "http_request", "request" }) do
		local fn = ENV[name]
		if type(fn) == "function" then
			return fn
		end
	end
	local syn = ENV.syn
	if type(syn) == "table" and type(syn.request) == "function" then
		return syn.request
	end
	if type(HttpService.RequestAsync) == "function" then
		return function(opts)
			return HttpService:RequestAsync({
				Url = opts.Url,
				Method = opts.Method or "GET",
				Headers = opts.Headers,
				Body = opts.Body,
			})
		end
	end
	return nil
end

function Core.loadStringFn()
	return ENV.loadstring or loadstring
end

function Core.readFile(path)
	local readFile = ENV.readfile
	local isFile = ENV.isfile
	if type(readFile) ~= "function" or type(isFile) ~= "function" or not isFile(path) then
		return nil
	end
	local ok, data = pcall(readFile, path)
	return ok and data or nil
end

function Core.writeFile(path, data)
	local writeFile = ENV.writefile
	local makeFolder = ENV.makefolder
	if type(writeFile) ~= "function" then
		return false
	end
	pcall(function()
		if type(makeFolder) == "function" then
			makeFolder("Alleral_Configs")
		end
	end)
	return pcall(writeFile, path, data)
end

function Core.patchStarlightSource(source)
	if not source or source == "" then
		return source
	end
	source = source:gsub(
		"function Tab:Show%(%)[\r\n]+%s*if Library%.ActiveTab then",
		"function Tab:Show()\n\t\t\tif Library.ActiveTab == Tab then\n\t\t\t\treturn\n\t\t\tend\n\t\t\tif Library.ActiveTab then"
	)
	local inputStart = source:find("function Groupbox:CreateInput", 1, true)
	local labelStart = inputStart and source:find("function Groupbox:CreateLabel", inputStart, true)
	if not inputStart or not labelStart then
		return source
	end
	local before = source:sub(1, inputStart - 1)
	local block = source:sub(inputStart, labelStart - 1)
	local after = source:sub(labelStart)
	block = block:gsub(
		"(Element%.Instance = GroupboxTemplateInstance%.Input_TEMPLATE:Clone%(%)[\r\n]+%s*Element%.Instance%.Visible = true)",
		"%1\n\t\t\t\t\t\tElement.Instance.Parent = Groupbox.ParentingItem",
		1
	)
	block = block:gsub(
		"\n%s*Element%.Instance%.Parent = Groupbox%.ParentingItem\n\n%s*(Starlight%.Window%.TabSections%[Name%]%.Tabs%[TabIndex%]%.Groupboxes%[GroupIndex%]%.Elements%[Index%] = Element)",
		"\n\n\t\t\t\t\t%1",
		1
	)
	return before .. block .. after
end

local function compileStarlightSource(source, label)
	local loadStringFn = Core.loadStringFn()
	if not loadStringFn or not source or source == "" then
		return nil, "Empty Starlight source"
	end
	local compiled, compileErr = loadStringFn(Core.patchStarlightSource(source), label)
	if not compiled then
		return nil, tostring(compileErr)
	end
	local ok, result = pcall(compiled)
	if ok and type(result) == "table" and type(result.CreateWindow) == "function" then
		return result
	end
	return nil, ok and "Invalid Starlight library" or tostring(result)
end

function Core.loadStarlight()
	if ENV.Alleral_Starlight and type(ENV.Alleral_Starlight.CreateWindow) == "function" then
		return ENV.Alleral_Starlight
	end

	local loadStringFn = Core.loadStringFn()
	if not loadStringFn then
		return nil, "loadstring unavailable"
	end

	for _, path in ipairs(STARLIGHT_LOCAL_FILES) do
		local source = Core.readFile(path)
		if source then
			local starlight, err = compileStarlightSource(source, "@Starlight/local")
			if starlight then
				ENV.Alleral_Starlight = starlight
				return starlight
			end
			warn("[Alleral] Local Starlight failed (" .. path .. "): " .. tostring(err))
		end
	end

	local function fetchRemoteSource(url)
		local httpGet = Core.requestFunction()
		if httpGet then
			local ok, response = pcall(httpGet, { Url = url, Method = "GET" })
			if ok and response then
				local body = response.Body or response.body or (type(response) == "string" and response)
				if body and body ~= "" and not body:find("404: Not Found") then
					return body
				end
			end
		end
		if type(game.HttpGet) == "function" then
			local ok, body = pcall(game.HttpGet, game, url, true)
			if ok and body and body ~= "" and not body:find("404: Not Found") then
				return body
			end
		end
		return nil
	end

	local lastErr = "HTTP unavailable and no local Starlight found"
	for _, url in ipairs(STARLIGHT_REMOTE_URLS) do
		local source = fetchRemoteSource(url)
		if source then
			local starlight, err = compileStarlightSource(source, "@Starlight/remote")
			if starlight then
				ENV.Alleral_Starlight = starlight
				return starlight
			end
			lastErr = err or "Invalid Starlight library"
		else
			lastErr = "Starlight download failed: " .. url
		end
	end
	return nil, lastErr
end

function Core.ensureCore()
	if ENV.Alleral_Core then
		return ENV.Alleral_Core
	end
	local loadStringFn = Core.loadStringFn()
	local isFile = ENV.isfile
	local readFile = ENV.readfile
	if type(loadStringFn) ~= "function" or type(isFile) ~= "function" or type(readFile) ~= "function" then
		return nil
	end
	for _, path in ipairs({ "src/alleral_core.luau", "alleral_core.luau" }) do
		if isFile(path) then
			local ok = pcall(loadStringFn(readFile(path), "Alleral/core")())
			if ok and ENV.Alleral_Core then
				return ENV.Alleral_Core
			end
		end
	end
	return nil
end

function Core.prepareGame(state)
	state = state or ENV.Alleral_State
	if not state then
		return nil, nil, "Alleral_State missing"
	end
	local core = Core.ensureCore()
	if not core then
		return nil, nil, "Alleral_Core missing — run loader.luau first"
	end
	state.HubRunning = state.HubRunning ~= false
	core.initAnalytics()
	if state.AntiAFK ~= false then
		core.setupAntiAfk(game:GetService("Players").LocalPlayer)
	end
	local starlight, err = core.loadStarlight()
	if not starlight then
		return nil, nil, err or "Starlight unavailable"
	end
	return core, starlight
end

function Core.stopAutomation(state, connections, loopControllers, loops, onStop)
	state.HubRunning = false
	for name, controller in pairs(loopControllers) do
		if controller then
			controller.enabled = false
		end
		loopControllers[name] = nil
	end
	for _, loopState in pairs(loops) do
		loopState.enabled = false
	end
	for key, connection in pairs(connections) do
		if connection and connection.Disconnect then
			pcall(function()
				connection:Disconnect()
			end)
		end
		connections[key] = nil
	end
	if onStop then
		pcall(onStop)
	end
end

function Core.saveSettings(state, keys, filename)
	local payload = {}
	for _, key in ipairs(keys) do
		payload[key] = state[key]
	end
	Core.writeFile("Alleral_Configs/" .. filename, HttpService:JSONEncode(payload))
end

function Core.loadSettings(state, keys, filename)
	local raw = Core.readFile("Alleral_Configs/" .. filename)
	if not raw then
		return
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		return
	end
	for _, key in ipairs(keys) do
		if decoded[key] ~= nil then
			state[key] = decoded[key]
		end
	end
end

function Core.wrapStarlightGroup(groupbox, loggedCallback)
	local group = {}
	local function nextId(name)
		return name .. "_" .. HttpService:GenerateGUID(false)
	end
	function group:CreateToggle(name, default, tooltip, callback)
		return groupbox:CreateToggle({
			Name = name,
			CurrentValue = default,
			Tooltip = tooltip,
			Callback = loggedCallback(callback),
		}, nextId(name))
	end
	function group:CreateSlider(name, min, max, default, callback, tooltip)
		return groupbox:CreateSlider({
			Name = name,
			Range = { min, max },
			Increment = 1,
			CurrentValue = default,
			Tooltip = tooltip,
			Callback = loggedCallback(callback),
		}, nextId(name))
	end
	function group:CreateButton(name, callback, tooltip)
		return groupbox:CreateButton({
			Name = name,
			Tooltip = tooltip,
			Callback = loggedCallback(callback),
		}, nextId(name))
	end
	function group:CreateInput(name, placeholder, default, callback, tooltip)
		return groupbox:CreateInput({
			Name = name,
			Placeholder = placeholder,
			CurrentValue = default or "",
			Tooltip = tooltip,
			Callback = loggedCallback(callback),
		}, nextId(name))
	end
	function group:CreateDropdown(name, options, default, callback, tooltip)
		return groupbox:CreateDropdown({
			Name = name,
			Options = options,
			CurrentOption = default,
			Tooltip = tooltip,
			Callback = loggedCallback(callback),
		}, nextId(name))
	end
	function group:AddDropdown(name, config)
		config.Name = config.Text or name
		config.Options = config.Values or config.Options or {}
		config.CurrentOptions = config.Default or config.CurrentOptions or {}
		config.Multi = config.Multi == true
		config.Searchable = config.Searchable == true
		config.Callback = loggedCallback(config.Callback or function() end)
		return groupbox:CreateDropdown(config, nextId(name))
	end
	function group:CreateDivider()
		return groupbox:CreateDivider()
	end
	return group
end

function Core.makeSupervisor(state, loops, controllers, name, interval, callback)
	if controllers[name] then
		controllers[name].enabled = false
		controllers[name] = nil
	end
	local loopState = {
		enabled = true,
		token = HttpService:GenerateGUID(false),
	}
	loops[name] = loopState
	controllers[name] = loopState
	task.spawn(function()
		local token = loopState.token
		while state.HubRunning and loopState.enabled and controllers[name] == loopState and loopState.token == token do
			local ok, err = pcall(callback)
			if not ok then
				warn("[Alleral:" .. name .. "] " .. tostring(err))
				task.wait(math.min(5, interval * 2))
			else
				task.wait(interval)
			end
		end
	end)
end

function Core.setupAntiAfk(player)
	local getConnections = ENV.getconnections or ENV.get_signal_cons
	if getConnections then
		for _, connection in ipairs(getConnections(player.Idled)) do
			if connection.Disable then
				connection:Disable()
			elseif connection.Disconnect then
				connection:Disconnect()
			end
		end
		return
	end
	local VirtualUser = game:GetService("VirtualUser")
	player.Idled:Connect(function()
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new(0, 0))
		end)
	end)
end

function Core.initAnalytics()
	local tracker = ENV.Alleral_Analytics
	if tracker and tracker.Track then
		tracker:Track()
	end
	return tracker
end

ENV.Alleral_Core = Core
return Core
