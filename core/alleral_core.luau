local Core = {}
Core.VERSION = "1.4"

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
	local candidates = {
		type(ENV.syn) == "table" and ENV.syn.request or nil,
		type(ENV.fluxus) == "table" and ENV.fluxus.request or nil,
		type(ENV.http) == "table" and ENV.http.request or nil,
		type(ENV.http_service) == "table" and ENV.http_service.request or nil,
		type(ENV.Xeno) == "table" and ENV.Xeno.request or nil,
		type(ENV.Volt) == "table" and ENV.Volt.request or nil,
		type(ENV.Madium) == "table" and ENV.Madium.request or nil,
		type(ENV.Nihon) == "table" and ENV.Nihon.request or nil,
		type(ENV.Cryptic) == "table" and ENV.Cryptic.request or nil,
		type(ENV.Sentinel) == "table" and ENV.Sentinel.request or nil,
		type(ENV.Serenity) == "table" and ENV.Serenity.request or nil,
		type(ENV.Atlantis) == "table" and ENV.Atlantis.request or nil,
		type(ENV.Zorara) == "table" and ENV.Zorara.request or nil,
		type(ENV.Wave) == "table" and ENV.Wave.request or nil,
		type(ENV.Electron) == "table" and ENV.Electron.request or nil,
		type(ENV.Potassium) == "table" and ENV.Potassium.request or nil,
		type(ENV.Velocity) == "table" and ENV.Velocity.request or nil,
		type(ENV.Krnl) == "table" and ENV.Krnl.request or nil,
		type(ENV.jjsploit) == "table" and ENV.jjsploit.request or nil,
		type(ENV.Bunni) == "table" and ENV.Bunni.request or nil,
		type(ENV.Valyse) == "table" and ENV.Valyse.request or nil,
		type(ENV.Krypton) == "table" and ENV.Krypton.request or nil,
		type(ENV.Evon) == "table" and ENV.Evon.request or nil,
		type(ENV.delta) == "table" and ENV.delta.request or nil,
		type(ENV.celery) == "table" and ENV.celery.request or nil,
		ENV.http_request,
		ENV.request,
		ENV.Request,
	}
	for _, name in ipairs({ "http_request", "request", "Request" }) do
		local fn = ENV[name]
		if type(fn) == "function" then
			table.insert(candidates, 1, fn)
		end
	end
	for _, candidate in ipairs(candidates) do
		if type(candidate) == "function" then
			return candidate
		end
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

local function trimText(value)
	return tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
end

function Core.normalizeWebhookUrl(url)
	local text = trimText(url)
	if text == "" then
		return nil, "Webhook URL is empty."
	end
	if not text:find("^https://") and not text:find("^http://") then
		text = "https://" .. text
	end
	if
		not text:find("discord%.com/api/webhooks/")
		and not text:find("discordapp%.com/api/webhooks/")
	then
		return nil, "That doesn't look like a Discord webhook URL."
	end
	return text, nil
end

function Core.postWebhook(url, payload)
	local sender = Core.requestFunction()
	if not sender then
		return false, "HTTP is not available in this executor."
	end
	local postUrl, urlError = Core.normalizeWebhookUrl(url)
	if not postUrl then
		return false, urlError
	end
	local ok, response = pcall(function()
		return sender({
			Url = postUrl,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload),
		})
	end)
	if not ok then
		return false, tostring(response)
	end
	if type(response) == "table" then
		if response.Success == false then
			local code = response.StatusCode or response.Status or response.status_code
			return false, "Webhook failed (HTTP " .. tostring(code or "?") .. ")"
		end
		local code = response.StatusCode or response.Status or response.status_code
		if type(code) == "number" and (code < 200 or code >= 300) then
			return false, "Webhook returned HTTP " .. tostring(code)
		end
	end
	return true, nil
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
		local sep = url:find("?") and "&" or "?"
		local fetchUrl = url .. sep .. "nocache=" .. tostring(math.random(10000, 99999))
		if type(game.HttpGet) == "function" then
			local ok, body = pcall(game.HttpGet, game, fetchUrl, true)
			if ok and body and body ~= "" and not body:find("404: Not Found") then
				return body
			end
		end
		local httpGet = Core.requestFunction()
		if httpGet then
			local ok, response = pcall(httpGet, { Url = fetchUrl, Method = "GET" })
			if ok and response then
				local body = response.Body or response.body or (type(response) == "string" and response)
				if body and body ~= "" and not body:find("404: Not Found") then
					return body
				end
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
	for _, path in ipairs({ "core/alleral_core.luau", "src/alleral_core.luau", "alleral_core.luau" }) do
		if isFile(path) then
			local ok = pcall(loadStringFn(readFile(path), "Alleral/core")())
			if ok and ENV.Alleral_Core then
				return ENV.Alleral_Core
			end
		end
	end
	return nil
end

local function signalBootFailure(message)
	ENV.Alleral_StartupFailed = message
	if ENV.Alleral_State then
		ENV.Alleral_State.StartupFailed = message
	end
	pcall(function()
		if shared then
			shared.Alleral_StartupFailed = message
		end
	end)
	local report = ENV.Alleral_ReportError
	if type(report) == "function" then
		pcall(report, "boot", message)
	end
end

function Core.prepareGame(state)
	state = state or ENV.Alleral_State
	if not state then
		local msg = "Alleral_State missing"
		signalBootFailure(msg)
		return nil, nil, msg
	end
	local core = Core.ensureCore()
	if not core then
		local msg = "Alleral_Core missing, run loader.luau first"
		signalBootFailure(msg)
		return nil, nil, msg
	end
	state.HubRunning = state.HubRunning ~= false
	core.initAnalytics()
	if state.AntiAFK ~= false then
		core.setupAntiAfk(game:GetService("Players").LocalPlayer)
	end
	local starlight, err = core.loadStarlight()
	if not starlight then
		local msg = err or "Starlight unavailable"
		signalBootFailure(msg)
		return nil, nil, msg
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
				Core.reportError("Loop:" .. name, err)
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
	else
		local VirtualUser = game:GetService("VirtualUser")
		player.Idled:Connect(function()
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new(0, 0))
			end)
		end)
	end
	task.spawn(function()
		local VirtualUser = game:GetService("VirtualUser")
		while player.Parent do
			task.wait(120)
			pcall(function()
				local camera = workspace.CurrentCamera
				if not camera then
					return
				end
				VirtualUser:Button2Down(Vector2.new(100, 100), camera.CFrame)
				task.wait(0.2)
				VirtualUser:Button2Up(Vector2.new(100, 100), camera.CFrame)
			end)
		end
	end)
end

function Core.initAnalytics()
	local tracker = ENV.Alleral_Analytics
	if tracker and tracker.Track then
		tracker:Track()
	end
	return tracker
end

function Core.reportError(scope, err, details)
	local reporter = ENV.Alleral_ReportError
	if type(reporter) == "function" then
		pcall(reporter, scope, err, details)
	end
end

function Core.logEvent(category, message, data)
	local logger = ENV.Alleral_LogEvent
	if type(logger) == "function" then
		pcall(logger, category, message, data)
	end
end

ENV.Alleral_Core = Core
return Core
