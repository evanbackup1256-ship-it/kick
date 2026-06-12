return function(Core)
	local HttpService = game:GetService("HttpService")
	local function genv()
		local ok, env = pcall(function()
			return getgenv and getgenv() or getfenv()
		end)
		return ok and env or {}
	end
	local ENV = genv()
function Core.buildScriptStatusGroupbox(tab, column, scriptId, profileVersion)
	scriptId = scriptId or ENV.Alleral_ActiveScriptId
	local evaluation = Core.evaluateScriptStatus(scriptId, profileVersion)
	local status = evaluation.status
	local groupbox = tab:CreateGroupbox({
		Name = "Script status",
		Column = column or 1,
		Icon = 6031075938,
	}, "ScriptStatus")

	local labels = {}
	local function addRow(key, value)
		labels[key] = groupbox:CreateLabel({
			Name = tostring(key) .. ": " .. tostring(value),
		}, "Status_" .. tostring(key))
	end

	addRow("Status", status.icon .. " " .. status.label)
	addRow("Script", status.name)
	addRow("Version", status.version)
	addRow("Executor", (Core.executorProfile().displayName))
	addRow("Access", "Public · no key required")
	local weao = Core.fetchWeaoExecutorStatus()
	if weao then
		addRow("WEAO", Core.weaoStatusLabel(weao))
		if weao.version then
			addRow("Exec version", tostring(weao.version))
		end
	end
	if status.message ~= "" then
		addRow("Notice", status.message)
	end
	if evaluation.force then
		addRow("Force load", "Enabled")
	end

	if not evaluation.allowed then
		groupbox:CreateToggle({
			Name = "Force load anyway",
			Value = ENV.Alleral_ForceLoad == true,
			Tooltip = "Skip maintenance gate this session.",
			Callback = function(value)
				ENV.Alleral_ForceLoad = value == true
				getgenv().Alleral_ForceLoad = value == true
				Core.notify("Alleral", value and "force load on — reload to use it" or "force load off", 4)
			end,
		}, "ForceLoadToggle")
	end

	groupbox:CreateButton({
		Name = "Refresh status",
		Callback = function()
			Core.fetchScriptManifest(true)
			Core.fetchWeaoExploits(true)
			local nextEval = Core.evaluateScriptStatus(scriptId, profileVersion)
			local nextStatus = nextEval.status
			if labels.Status and labels.Status.Set then
				labels.Status:Set({ Name = "Status: " .. nextStatus.icon .. " " .. nextStatus.label })
			end
			if labels.Notice and nextStatus.message ~= "" then
				labels.Notice:Set({ Name = "Notice: " .. nextStatus.message })
			end
			local refreshedWeao = Core.fetchWeaoExecutorStatus()
			if refreshedWeao and labels.WEAO and labels.WEAO.Set then
				labels.WEAO:Set({ Name = "WEAO: " .. Core.weaoStatusLabel(refreshedWeao) })
			end
			Core.notify("Alleral", "status: " .. nextStatus.label, 3)
		end,
	}, "RefreshStatus")

	Core._scriptStatusUI = {
		groupbox = groupbox,
		labels = labels,
		scriptId = scriptId,
		profileVersion = profileVersion,
	}
	return groupbox, evaluation
end

function Core.buildHubActionsGroup(tab, column)
	local groupbox = tab:CreateGroupbox({
		Name = "Hub controls",
		Column = column or 2,
		Icon = 6031075938,
	}, "HubActions")
	local group = Core.wrapUiGroup(groupbox)

	group:CreateButton("Reload script", function()
		local reload = getgenv().Alleral_Reload
		if type(reload) == "function" then
			Core.notify("Alleral", "reloading...", 3)
			task.defer(reload)
		else
			Core.notify("Alleral", "can't reload here — run the loadstring again", 5)
		end
	end, "Runs getgenv().Alleral_Reload().")

	group:CreateButton("Check for update", function()
		local check = getgenv().Alleral_CheckUpdate
		if type(check) == "function" then
			check()
		else
			Core.notify("Alleral", "Update check unavailable.", 4)
		end
	end, "Pulls the latest loader/core from GitHub.")

	group:CreateButton("Stop automation", function()
		stateHubStop()
	end, "Stops loops without closing the UI.")

	group:CreateButton("Purge cache", function()
		local purge = getgenv().Alleral_PurgeCache
		if type(purge) == "function" then
			purge()
			Core.notify("Alleral", "cache cleared", 4)
		else
			Core.notify("Alleral", "Purge unavailable.", 4)
		end
	end, "Clears cached hub files and reloads fresh.")

	group:CreateButton("Sync WEAO config", function()
		Core.syncWeaoConfigNow()
	end, "Pulls the latest WEAO API endpoints without reloading.")

	group:CreateButton("Copy JobId", function()
		Core.copyJobId()
	end, "Copies this server's JobId to clipboard.")

	group:CreateButton("Copy join link", function()
		Core.copyPlaceJoinLink()
	end, "Copies a roblox:// link for this server.")

	group:CreateButton("Copy web join link", function()
		Core.copyWebJoinLink()
	end, "Copies the https:// join link for this server.")

	group:CreateButton("Rejoin server", function()
		Core.rejoinServer()
	end, "Teleports you back into this same server instance.")

	Core.buildJoinServerControls(group, { dividerFirst = true })

	return group
end

local ERROR_LOG_MAX = 40
ENV.Alleral_ErrorLog = ENV.Alleral_ErrorLog or {}

function Core.pushErrorLog(scope, err, details)
	local entry = {
		at = os.date("%H:%M:%S"),
		scope = tostring(scope or "Runtime"),
		message = tostring(err or "?"),
		details = details and tostring(details) or nil,
	}
	local log = ENV.Alleral_ErrorLog
	table.insert(log, 1, entry)
	while #log > ERROR_LOG_MAX do
		table.remove(log)
	end
	local statuses = Core._errorLogStatuses or {}
	if Core._errorLogStatus then
		local seen = false
		for _, entry in ipairs(statuses) do
			if entry == Core._errorLogStatus then
				seen = true
				break
			end
		end
		if not seen then
			table.insert(statuses, Core._errorLogStatus)
		end
	end
	for _, status in ipairs(statuses) do
		pcall(function()
			status:Update("Latest", entry.scope .. ": " .. entry.message:sub(1, 80))
			status:Update("Count", tostring(#log))
		end)
	end
end

function Core.installErrorLogHook()
	if ENV._Alleral_ErrorLogHooked then
		return
	end
	ENV._Alleral_ErrorLogHooked = true
	local previous = ENV.Alleral_ReportError
	ENV.Alleral_ReportError = function(scope, err, details)
		Core.pushErrorLog(scope, err, details)
		if type(previous) == "function" then
			pcall(previous, scope, err, details)
		end
	end
	getgenv().Alleral_ReportError = ENV.Alleral_ReportError
end

function Core.getErrorLogText(limit)
	limit = limit or 20
	local lines = {}
	for index, entry in ipairs(ENV.Alleral_ErrorLog or {}) do
		if index > limit then
			break
		end
		table.insert(lines, string.format("[%s] %s: %s", entry.at, entry.scope, entry.message))
	end
	return #lines > 0 and table.concat(lines, "\n") or "No errors logged this session."
end

function Core.registerUiWindow(window)
	if type(window) == "table" and window._rawWindow then
		ENV.Alleral_UiWindow = window
		getgenv().Alleral_UiWindow = window
	end
	return window
end

function Core.repairUiWindow(window)
	window = window or ENV.Alleral_UiWindow
	if type(window) ~= "table" or not window._rawWindow then
		return false
	end
	local lib = window._library or Core.getWindUi()
	if not lib or type(lib.RepairWindow) ~= "function" then
		return false
	end
	local ok = pcall(function()
		lib:RepairWindow(window._rawWindow)
	end)
	return ok == true
end

Core._UiStateBindings = Core._UiStateBindings or {}

function Core.clearUiStateBindings()
	Core._UiStateBindings = {}
	Core._errorLogStatuses = {}
	ENV._AlleralStatsTickGen = (ENV._AlleralStatsTickGen or 0) + 1
	ENV._AlleralCommandPaletteReady = false
	if ENV._Alleral_KeybindConn then
		pcall(function()
			ENV._Alleral_KeybindConn:Disconnect()
		end)
		ENV._Alleral_KeybindConn = nil
	end
	ENV._AlleralMenuKeyBound = false
end

function Core.bindUiState(stateKey, widget, kind, rawHandle)
	if type(stateKey) ~= "string" or stateKey == "" then
		return widget
	end
	Core._UiStateBindings[stateKey] = {
		widget = widget,
		kind = kind or "toggle",
		raw = rawHandle,
	}
	return widget
end

function Core.sliderIncrement(minValue, maxValue, explicit)
	if explicit ~= nil then
		return explicit
	end
	minValue = tonumber(minValue) or 0
	maxValue = tonumber(maxValue) or 100
	local range = maxValue - minValue
	if range <= 0 then
		return 1
	end
	if range <= 1 then
		return 0.01
	end
	if range <= 5 then
		return 0.05
	end
	if range <= 10 then
		return 0.1
	end
	if range <= 50 then
		return 0.5
	end
	if range <= 200 then
		return 1
	end
	return math.max(1, math.floor(range / 80))
end

function Core.syncUiState(state, options)
	if type(state) ~= "table" then
		return 0
	end
	options = type(options) == "table" and options or {}
	local synced = 0
	for key, entry in pairs(Core._UiStateBindings or {}) do
		local value = state[key]
		if value ~= nil then
			local raw = entry.raw
			if not raw and type(entry.widget) == "table" then
				raw = entry.widget._raw
			end
			if entry.kind == "toggle" and raw then
				pcall(function()
					if type(raw.UpdateState) == "function" then
						raw:UpdateState(value == true)
					elseif type(raw.Set) == "function" then
						local prev = raw.Callback
						raw.Callback = function() end
						raw:Set(value == true, nil, false)
						raw.Callback = prev
					elseif entry.widget and entry.widget.Set then
						entry.widget:Set({ CurrentValue = value == true })
					end
				end)
				synced += 1
			elseif entry.kind == "slider" and raw then
				pcall(function()
					local num = tonumber(value) or 0
					if type(raw.UpdateValue) == "function" then
						raw:UpdateValue(num)
					elseif type(raw.Set) == "function" then
						local prev = raw.Callback
						raw.Callback = function() end
						raw:Set(num)
						raw.Callback = prev
					elseif entry.widget and entry.widget.Set then
						entry.widget:Set({ CurrentValue = num })
					end
				end)
				synced += 1
			elseif entry.kind == "input" and raw then
				pcall(function()
					if type(raw.UpdateText) == "function" then
						raw:UpdateText(tostring(value))
					elseif entry.widget and entry.widget.Set then
						entry.widget:Set({ CurrentValue = tostring(value) })
					end
				end)
				synced += 1
			elseif entry.kind == "dropdown" and raw then
				pcall(function()
					if type(raw.UpdateSelection) == "function" then
						raw:UpdateSelection(value)
					elseif raw.Select then
						raw:Select(value)
					elseif raw.Set then
						raw:Set(value)
					elseif entry.widget and entry.widget.Set then
						entry.widget:Set({ CurrentOption = value })
					end
				end)
				synced += 1
			elseif entry.widget and type(entry.widget.Set) == "function" then
				pcall(function()
					if entry.kind == "toggle" then
						entry.widget:Set({ CurrentValue = value == true })
					elseif entry.kind == "slider" then
						entry.widget:Set({ CurrentValue = tonumber(value) or 0 })
					else
						entry.widget:Set({ CurrentOption = value })
					end
				end)
				synced += 1
			end
		end
	end
	if options.notify == true and synced > 0 then
		Core.notify("UI", "Synced " .. tostring(synced) .. " controls.", 2, "info")
	end
	return synced
end

function Core.releaseUiWindow()
	local window = ENV.Alleral_UiWindow
	if type(window) == "table" and window._nlWindow and type(window._nlWindow.SetOpen) == "function" then
		pcall(function()
			window._nlWindow:SetOpen(false)
		end)
	end
	local ui = ENV.Alleral_UI
	local lib = ui and (ui.Library or ui.Alleral or ui.WindUI)
	if type(lib) == "table" and type(lib.ReleaseWindow) == "function" then
		pcall(function()
			lib:ReleaseWindow(lib.Window)
		end)
	end
	if type(lib) == "table" and type(lib.Unload) == "function" then
		pcall(lib.Unload, lib)
	end
	ENV.Alleral_UiWindow = nil
	getgenv().Alleral_UiWindow = nil
end

function Core.toggleUiVisibility()
	local window = ENV.Alleral_UiWindow
	if not window or not window._rawWindow then
		return false
	end
	local raw = window._rawWindow
	if type(raw.Toggle) == "function" then
		pcall(raw.Toggle, raw)
		return true
	end
	if type(raw.SetState) == "function" and type(raw.GetState) == "function" then
		pcall(raw.SetState, raw, not raw:GetState())
		return true
	end
	if type(raw.SetOpen) == "function" then
		pcall(function()
			raw:SetOpen(not raw.IsOpen)
		end)
		return true
	end
	return false
end

function Core.setGlobalMusicMuted(muted)
	muted = muted == true
	local SoundService = game:GetService("SoundService")
	ENV._AlleralMutedSounds = ENV._AlleralMutedSounds or {}

	local function muteSound(sound)
		if not sound or not sound:IsA("Sound") then
			return
		end
		if ENV._AlleralMutedSounds[sound] == nil then
			ENV._AlleralMutedSounds[sound] = sound.Volume
		end
		pcall(function()
			sound.Volume = 0
		end)
	end

	local function restoreSound(sound, volume)
		if not sound or not sound:IsA("Sound") then
			return
		end
		pcall(function()
			sound.Volume = tonumber(volume) or 0.5
		end)
	end

	if muted then
		for _, desc in ipairs(game:GetDescendants()) do
			if desc:IsA("Sound") then
				muteSound(desc)
			end
		end
		if not ENV._AlleralSoundMuteConn then
			ENV._AlleralSoundMuteConn = game.DescendantAdded:Connect(function(desc)
				if ENV.Alleral_MusicMuted == true and desc:IsA("Sound") then
					muteSound(desc)
				end
			end)
		end
	else
		for sound, volume in pairs(ENV._AlleralMutedSounds) do
			if typeof(sound) == "Instance" and sound.Parent then
				restoreSound(sound, volume)
			end
		end
		table.clear(ENV._AlleralMutedSounds)
		if ENV._AlleralSoundMuteConn then
			pcall(function()
				ENV._AlleralSoundMuteConn:Disconnect()
			end)
			ENV._AlleralSoundMuteConn = nil
		end
	end

	-- Legacy path: some executors expose a master SoundGroup or deprecated Volume.
	pcall(function()
		local master = SoundService:FindFirstChild("AlleralMaster")
		if not master then
			master = Instance.new("SoundGroup")
			master.Name = "AlleralMaster"
			master.Volume = 1
			master.Parent = SoundService
		end
		if muted then
			if ENV._Alleral_PrevMasterVolume == nil then
				ENV._Alleral_PrevMasterVolume = master.Volume
			end
			master.Volume = 0
		else
			master.Volume = ENV._Alleral_PrevMasterVolume or 1
		end
	end)

	ENV.Alleral_MusicMuted = muted
end

function Core.setLowGraphics(enabled)
	enabled = enabled == true
	local Lighting = game:GetService("Lighting")
	local Terrain = workspace:FindFirstChildOfClass("Terrain")
	ENV._AlleralDisabledEffects = ENV._AlleralDisabledEffects or {}

	local function setQuality(enabledNow)
		pcall(function()
			local gameSettings = UserSettings():GetService("UserGameSettings")
			if enabledNow then
				if ENV._Alleral_PrevQuality == nil then
					ENV._Alleral_PrevQuality = gameSettings.SavedQualityLevel
				end
				gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
			elseif ENV._Alleral_PrevQuality ~= nil then
				gameSettings.SavedQualityLevel = ENV._Alleral_PrevQuality
			end
		end)
		pcall(function()
			if enabledNow then
				settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
				settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
			end
		end)
	end

	if enabled then
		ENV._Alleral_PrevShadows = Lighting.GlobalShadows
		Lighting.GlobalShadows = false
		pcall(function()
			if ENV._Alleral_PrevTechnology == nil then
				ENV._Alleral_PrevTechnology = Lighting.Technology
			end
			Lighting.Technology = Enum.Technology.Compatibility
		end)
		pcall(function()
			if Terrain and ENV._Alleral_PrevDecoration == nil then
				ENV._Alleral_PrevDecoration = Terrain.Decoration
				Terrain.Decoration = false
			end
		end)
		for _, effect in ipairs(Lighting:GetDescendants()) do
			if effect:IsA("PostEffect") and effect.Enabled then
				ENV._AlleralDisabledEffects[effect] = true
				effect.Enabled = false
			end
		end
		setQuality(true)
	else
		if ENV._Alleral_PrevShadows ~= nil then
			Lighting.GlobalShadows = ENV._Alleral_PrevShadows
		else
			Lighting.GlobalShadows = true
		end
		pcall(function()
			if ENV._Alleral_PrevTechnology ~= nil then
				Lighting.Technology = ENV._Alleral_PrevTechnology
			end
		end)
		pcall(function()
			if Terrain and ENV._Alleral_PrevDecoration ~= nil then
				Terrain.Decoration = ENV._Alleral_PrevDecoration
			end
		end)
		for effect in pairs(ENV._AlleralDisabledEffects) do
			if typeof(effect) == "Instance" and effect.Parent then
				pcall(function()
					effect.Enabled = true
				end)
			end
		end
		table.clear(ENV._AlleralDisabledEffects)
		setQuality(false)
	end

	ENV.Alleral_LowGraphics = enabled
end

function Core.buildWebJoinUrl(placeId, jobId)
	placeId = tonumber(placeId) or game.PlaceId
	jobId = tostring(jobId or game.JobId or "")
	return string.format(
		"https://www.roblox.com/games/start?placeId=%s&gameInstanceId=%s",
		tostring(placeId),
		jobId
	)
end

function Core.buildRobloxJoinUrl(placeId, jobId)
	placeId = tonumber(placeId) or game.PlaceId
	jobId = tostring(jobId or game.JobId or "")
	return string.format(
		"roblox://experiences/start?placeId=%s&gameInstanceId=%s",
		tostring(placeId),
		jobId
	)
end

function Core.currentWebJoinUrl()
	return Core.buildWebJoinUrl(game.PlaceId, game.JobId)
end

local function decodeLuxyJoinPayload(raw)
	local luxyPayload = tostring(raw or ""):match("LUXY:<([^>]+)>")
	if not luxyPayload then
		return nil
	end
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local cleaned = luxyPayload:gsub("[^" .. alphabet .. "=]", "")
	local bits = cleaned:gsub(".", function(char)
		if char == "=" then
			return ""
		end
		local index = alphabet:find(char, 1, true)
		if not index then
			return ""
		end
		local output = ""
		for bitIndex = 6, 1, -1 do
			output = output .. (((index % (2 ^ bitIndex)) - (index % (2 ^ (bitIndex - 1))) > 0) and "1" or "0")
		end
		return output
	end)
	local decoded = bits:gsub("%d%d%d?%d?%d?%d?%d?%d?", function(chunk)
		if #chunk ~= 8 then
			return ""
		end
		local value = 0
		for bitIndex = 1, 8 do
			if chunk:sub(bitIndex, bitIndex) == "1" then
				value = value + (2 ^ (8 - bitIndex))
			end
		end
		return string.char(value)
	end)
	if decoded == "" then
		return nil
	end
	return decoded
end

function Core.parseJoinJobId(raw, defaultPlaceId)
	raw = tostring(raw or ""):gsub("^%s*(.-)%s*$", "%1")
	local placeId = tonumber(defaultPlaceId) or game.PlaceId
	if raw == "" then
		return nil, placeId
	end
	local luxyDecoded = decodeLuxyJoinPayload(raw)
	if luxyDecoded then
		raw = luxyDecoded
	end
	placeId = tonumber(raw:match("placeId=(%d+)")) or placeId
	local jobId = raw:match("gameInstanceId=([%w%-]+)")
		or raw:match("instanceId=([^&%s]+)")
		or raw:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)")
		or raw:match("([%w]+%-[%w]+%-[%w]+%-[%w]+%-[%w]+)")
		or raw
	jobId = tostring(jobId or ""):gsub("^%s*(.-)%s*$", "%1")
	if jobId == "" then
		return nil, placeId
	end
	return jobId, placeId
end

function Core.teleportToJoinInput(raw, defaultPlaceId)
	local jobId, placeId = Core.parseJoinJobId(raw, defaultPlaceId)
	if not jobId or jobId == "" then
		return false, "invalid_join_input"
	end
	local TeleportService = game:GetService("TeleportService")
	local Players = game:GetService("Players")
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(placeId or game.PlaceId, jobId, Players.LocalPlayer)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true
end

function Core.buildJoinServerControls(group, options)
	options = options or {}
	local key = options.key or "JoinJobId"
	local state = type(options.state) == "table" and options.state or getgenv().Alleral_State
	local saveSettings = options.saveSettings
	local inputLabel = options.inputLabel or "Server link or job id"
	local inputPlaceholder = options.inputPlaceholder or "paste invite link"
	local buttonLabel = options.buttonLabel or "Hop to server"
	local buttonTooltip = options.buttonTooltip or "Full roblox share link or raw job id both work."

	local function readJoinInput()
		if type(state) == "table" and state[key] ~= nil then
			return tostring(state[key])
		end
		local g = getgenv()
		g.Alleral_JoinJobId = g.Alleral_JoinJobId or ""
		return g.Alleral_JoinJobId
	end

	local function writeJoinInput(value)
		value = tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
		if type(state) == "table" then
			state[key] = value
		end
		getgenv().Alleral_JoinJobId = value
		if type(saveSettings) == "function" then
			saveSettings()
		end
	end

	if options.dividerFirst == true then
		group:CreateDivider()
	end
	group:CreateInput(
		inputLabel,
		inputPlaceholder,
		readJoinInput(),
		function(value)
			writeJoinInput(value)
		end,
		buttonTooltip
	)
	group:CreateButton(buttonLabel, function()
		local ok, err = Core.teleportToJoinInput(readJoinInput())
		if not ok then
			Core.notify("Alleral", "That doesn't look like a valid link or job id.", 3, "warn")
			if err and err ~= "invalid_join_input" and ENV.Alleral_TelemetryDebug == true then
				warn("[Alleral] Join hop failed: " .. tostring(err))
			end
		end
	end, buttonTooltip)
end

function Core.copyJobId()
	local clip = Core.execFunction("setclipboard") or Core.execFunction("setclipboard", true)
	if type(clip) == "function" then
		pcall(clip, game.JobId)
		Core.notify("Alleral", "JobId copied.", 3)
		return true
	end
	Core.notify("Alleral", game.JobId, 8)
	return false
end

function Core.copyPlaceJoinLink()
	local link = Core.buildRobloxJoinUrl(game.PlaceId, game.JobId)
	local clip = Core.execFunction("setclipboard") or Core.execFunction("setclipboard", true)
	if type(clip) == "function" then
		pcall(clip, link)
		Core.notify("Alleral", "Join link copied.", 3)
		return true
	end
	Core.notify("Alleral", link, 8)
	return false
end

function Core.copyWebJoinLink()
	local link = Core.currentWebJoinUrl()
	local clip = Core.execFunction("setclipboard") or Core.execFunction("setclipboard", true)
	if type(clip) == "function" then
		pcall(clip, link)
		Core.notify("Alleral", "Web join link copied.", 3)
		return true
	end
	Core.notify("Alleral", link, 8)
	return false
end

function Core.rejoinServer()
	local TeleportService = game:GetService("TeleportService")
	local Players = game:GetService("Players")
	pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Players.LocalPlayer)
	end)
end

function Core.syncWeaoConfigNow()
	local sync = getgenv().Alleral_SyncWeao
	if type(sync) == "function" then
		local ok = sync(false)
		Core.notify(
			"Alleral",
			ok and "WEAO config updated" or "WEAO config unchanged (or offline)",
			4
		)
		return ok
	end
	Core.notify("Alleral", "WEAO sync unavailable — reload the loader.", 5)
	return false
end

function Core.backupSettings(filename, jsonBody)
	local writeFile = Core.execFunction("writefile")
	local makeFolder = Core.execFunction("makefolder")
	local listFiles = Core.execFunction("listfiles")
	local deleteFile = Core.execFunction("delfile")
	if type(writeFile) ~= "function" then
		return false
	end
	pcall(makeFolder, "Alleral_Configs")
	pcall(makeFolder, "Alleral_Configs/backups")
	local base = tostring(filename or "settings.json"):gsub("%.json$", ""):gsub("[^%w%-_]", "_")
	local stamp = os.date("!%Y%m%d-%H%M%S")
	local path = "Alleral_Configs/backups/" .. base .. "_" .. stamp .. ".json"
	pcall(writeFile, path, jsonBody)
	if type(listFiles) == "function" and type(deleteFile) == "function" then
		local matches = {}
		for _, filePath in ipairs(listFiles("Alleral_Configs/backups")) do
			if tostring(filePath):find(base .. "_", 1, true) then
				table.insert(matches, tostring(filePath))
			end
		end
		table.sort(matches)
		while #matches > 8 do
			pcall(deleteFile, matches[1])
			table.remove(matches, 1)
		end
	end
	return true
end

function Core.settingsFilePath(options)
	options = type(options) == "table" and options or {}
	if type(options.settingsPath) == "string" and options.settingsPath ~= "" then
		return options.settingsPath
	end
	local file = options.settingsFile or "settings.json"
	if file:find("/", 1, true) or file:find("\\", 1, true) then
		return file
	end
	return "Alleral_Configs/" .. file
end

function Core.buildSessionStatsGroup(tab, column)
	local RunService = game:GetService("RunService")
	local Stats = game:GetService("Stats")
	local Players = game:GetService("Players")
	local startedAt = tick()
	local frameCount = 0
	local frameConn = RunService.RenderStepped:Connect(function()
		frameCount += 1
	end)
	local group = Core.buildUiGroup(tab, "Session stats", column or 1, nil, nil, "SessionStats")
	local status = group:CreateStatus("Live", {
		FPS = "--",
		Ping = "--",
		Players = "--",
		Uptime = "0s",
		Memory = "--",
	})
	task.spawn(function()
		local lastTick = tick()
		while ENV.Alleral_State and ENV.Alleral_State.HubRunning ~= false do
			local now = tick()
			local elapsed = math.max(now - lastTick, 0.001)
			local fps = math.floor(frameCount / elapsed)
			frameCount = 0
			lastTick = now
			local ping = "--"
			pcall(function()
				local item = Stats.Network.ServerStatsItem["Data Ping"]
				if item then
					ping = item:GetValueString()
				end
			end)
			local memory = "--"
			pcall(function()
				memory = string.format("%.0f MB", Stats:GetTotalMemoryUsageMb())
			end)
			local uptime = math.floor(tick() - startedAt)
			status:Update("FPS", tostring(fps))
			status:Update("Ping", ping)
			status:Update("Players", tostring(#Players:GetPlayers()))
			status:Update("Uptime", uptime .. "s")
			status:Update("Memory", memory)
			task.wait(2)
		end
		if frameConn then
			frameConn:Disconnect()
		end
	end)
	return group, status
end

function Core.buildQuickTogglesGroup(tab, options)
	options = type(options) == "table" and options or {}
	local state = options.state or ENV.Alleral_State or {}
	local saveFn = options.saveFn
	local column = options.column or 2
	local group = Core.buildUiGroup(tab, "Quick toggles", column, nil, nil, "QuickToggles")

	group:CreateToggle("Mute all audio", ENV.Alleral_MusicMuted == true, "Mutes in-game Sound instances.", function(value)
		Core.setGlobalMusicMuted(value)
		if type(saveFn) == "function" then
			saveFn()
		end
	end)

	group:CreateToggle("Low graphics", ENV.Alleral_LowGraphics == true, "Lowest quality, no shadows, fewer effects.", function(value)
		Core.setLowGraphics(value)
		if type(saveFn) == "function" then
			saveFn()
		end
	end)

	if ENV.Alleral_MusicMuted == true then
		pcall(Core.setGlobalMusicMuted, true)
	end
	if ENV.Alleral_LowGraphics == true then
		pcall(Core.setLowGraphics, true)
	end

	group:CreateToggle(
		"Auto relaunch on teleport",
		getgenv().Alleral_AutoRelaunch ~= false,
		"Reload the hub after server hops (loader setting).",
		function(value)
			getgenv().Alleral_AutoRelaunch = value == true
			ENV.Alleral_AutoRelaunch = value == true
		end
	)

	if state.AntiAFK ~= nil then
		group:CreateToggle("Anti AFK", state.AntiAFK ~= false, "Prevents idle kick.", function(value)
			state.AntiAFK = value
			if value then
				Core.setupAntiAfk(game:GetService("Players").LocalPlayer)
			end
			if type(saveFn) == "function" then
				saveFn()
			end
		end)
	end

	return group
end

function Core.buildServerToolsGroup(tab, column)
	local group = Core.buildUiGroup(tab, "Server tools", column or 1, nil, nil, "ServerTools")
	group:CreateButton("Copy JobId", Core.copyJobId, "Copy this server's instance id.")
	group:CreateButton("Copy join link", Core.copyPlaceJoinLink, "Share a direct join link.")
	group:CreateButton("Rejoin server", Core.rejoinServer, "Reconnect to this exact server.")
	group:CreateButton("Copy PlaceId", function()
		local clip = Core.execFunction("setclipboard") or Core.execFunction("setclipboard", true)
		if type(clip) == "function" then
			pcall(clip, tostring(game.PlaceId))
			Core.notify("Alleral", "PlaceId copied.", 3)
		else
			Core.notify("Alleral", tostring(game.PlaceId), 5)
		end
	end, "Copy the experience PlaceId.")
	return group
end

function Core.buildErrorLogGroup(tab, column)
	local group = Core.buildUiGroup(tab, "Error log", column or 2, nil, nil, "ErrorLog")
	Core.installErrorLogHook()
	local status = group:CreateStatus("Errors", {
		Count = tostring(#(ENV.Alleral_ErrorLog or {})),
		Latest = "None",
	})
	Core._errorLogStatuses = Core._errorLogStatuses or {}
	table.insert(Core._errorLogStatuses, status)
	Core._errorLogStatus = status
	if #(ENV.Alleral_ErrorLog or {}) > 0 then
		local latest = ENV.Alleral_ErrorLog[1]
		status:Update("Latest", latest.scope .. ": " .. latest.message:sub(1, 80))
	end
	group:CreateButton("Copy log", function()
		local clip = Core.execFunction("setclipboard") or Core.execFunction("setclipboard", true)
		if type(clip) ~= "function" then
			Core.notify("Alleral", "Clipboard not supported.", 4)
			return
		end
		pcall(clip, Core.getErrorLogText(25))
		Core.notify("Alleral", "Error log copied.", 3)
	end, "Copy the last 25 errors.")
	group:CreateButton("Clear log", function()
		table.clear(ENV.Alleral_ErrorLog)
		status:Update("Count", "0")
		status:Update("Latest", "None")
		Core.notify("Alleral", "Error log cleared.", 3)
	end)
	return group, status
end

function Core.buildSettingsBackupGroup(tab, options)
	options = type(options) == "table" and options or {}
	local column = options.column or 2
	local settingsPath = Core.settingsFilePath(options)
	local readFile = Core.execFunction("readfile")
	local writeFile = Core.execFunction("writefile")
	local isFile = Core.execFunction("isfile")
	local listFiles = Core.execFunction("listfiles")
	local group = Core.buildUiGroup(tab, "Settings backup", column, nil, nil, "SettingsBackup")

	local function listBackups()
		local names = {}
		if type(listFiles) == "function" then
			local base = (options.settingsFile or "settings"):gsub("%.json$", ""):gsub("[^%w%-_]", "_")
			for _, path in ipairs(listFiles("Alleral_Configs/backups")) do
				local name = tostring(path):match("([^/\\]+)$")
				if name and name:find("^" .. base .. "_", 1, true) then
					table.insert(names, name)
				end
			end
		end
		table.sort(names, function(a, b)
			return a > b
		end)
		if #names == 0 then
			table.insert(names, "(none yet)")
		end
		return names
	end

	local selected = listBackups()[1]
	group:CreateDropdown("Backups", listBackups(), selected, function(value)
		selected = value
	end, "Rolling backups created whenever settings save.")

	group:CreateButton("Restore backup", function()
		if selected == "(none yet)" then
			Core.notify("Alleral", "No backups found yet.", 4)
			return
		end
		if type(readFile) ~= "function" or type(writeFile) ~= "function" or type(isFile) ~= "function" then
			Core.notify("Alleral", "Filesystem not supported.", 5)
			return
		end
		local backupPath = "Alleral_Configs/backups/" .. selected
		if not isFile(backupPath) then
			Core.notify("Alleral", "Backup missing.", 4)
			return
		end
		local raw = readFile(backupPath)
		pcall(writeFile, settingsPath, raw)
		Core.notify("Alleral", "Backup restored — reload the script.", 5)
	end, "Overwrites your current settings file.")

	group:CreateButton("Backup now", function()
		if type(readFile) ~= "function" or not isFile or not isFile(settingsPath) then
			Core.notify("Alleral", "Nothing to backup yet.", 4)
			return
		end
		local raw = readFile(settingsPath)
		Core.backupSettings(options.settingsFile or settingsPath, raw)
		Core.notify("Alleral", "Manual backup saved.", 3)
	end)

	return group
end

function Core.setupHubKeybinds(options)
	options = type(options) == "table" and options or {}
	if ENV._Alleral_KeybindConn then
		pcall(function()
			ENV._Alleral_KeybindConn:Disconnect()
		end)
		ENV._Alleral_KeybindConn = nil
	end
	local UserInputService = game:GetService("UserInputService")
	local panicKey = options.panicKey or Enum.KeyCode.Delete
	local uiKey = options.uiKey or Enum.KeyCode.RightControl
	local insertKey = options.insertKey or Enum.KeyCode.Insert
	local maclibUi = Core.UI_LIBRARY == "Maclib"
	ENV._Alleral_KeybindConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == panicKey then
			Core.stateHubStop()
			Core.notify("Alleral", "everything stopped", 4)
		elseif input.KeyCode == insertKey or (not maclibUi and input.KeyCode == uiKey) then
			if Core.toggleUiVisibility() then
				Core.notify("Alleral", "UI toggled.", 2)
			end
		elseif input.KeyCode == Enum.KeyCode.K and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			local ui = options.ui or options.uiBundle or ENV.Alleral_UI
			local lib = ui and (ui.Library or ui.Alleral)
			if lib and lib.CommandPalette and type(lib.CommandPalette.toggle) == "function" then
				local root = lib.Holder
				if not root and type(lib.EnsureGuiRoot) == "function" then
					root = lib:EnsureGuiRoot()
				end
				if root then
					lib.CommandPalette.toggle(root)
				end
			end
		end
	end)
	ENV._AlleralMenuKeyBound = true
end

function Core.buildUiPreferencesGroup(tab, options)
	options = type(options) == "table" and options or {}
	local column = options.column or 2
	local uiBundle = options.uiBundle
	if not uiBundle and type(options.window) == "table" then
		uiBundle = options.window._ui
	end
	local windUi = uiBundle and (uiBundle.WindUI or uiBundle.Library)
	local group = Core.buildUiGroup(tab, "UI tools", column, nil, nil, "UiPreferences")

	group:CreateButton("Test success toast", function()
		Core.notify("Alleral", "Success toast.", 4, "success")
	end, "Fire a success toast.")

	group:CreateButton("Test warning toast", function()
		Core.notify("Alleral", "Warning toast.", 4, "warn")
	end, "Fire a warning toast.")

	group:CreateButton("Clear all toasts", function()
		if windUi and type(windUi.ClearNotifications) == "function" then
			local cleared = windUi:ClearNotifications()
			Core.notify("Alleral", "cleared " .. tostring(cleared or 0), 2, "info")
		else
			Core.notify("Alleral", "Clear unavailable.", 3, "warn")
		end
	end, "Dismiss visible toasts.")

	group:CreateButton("Repair UI chrome", function()
		if windUi and type(windUi.RepairWindow) == "function" then
			local ok = windUi:RepairWindow()
			Core.notify("Alleral", ok and "UI repaired." or "Repair failed.", 3, ok and "success" or "error")
		else
			Core.notify("Alleral", "Repair unavailable.", 3, "warn")
		end
	end, "Re-apply theme rails and polish.")

	group:CreateToggle(
		"Bottom notifications",
		ENV.Alleral_NotifyLower == true,
		"Move toasts to the bottom-right.",
		function(value)
			ENV.Alleral_NotifyLower = value == true
			if windUi and type(windUi.SetNotificationLower) == "function" then
				pcall(function()
					windUi:SetNotificationLower(value)
				end)
			end
		end
	)

	return group
end

function Core.buildAutomationStatusGroup(tab, options)
	options = type(options) == "table" and options or {}
	local state = options.state or ENV.Alleral_State or {}
	local loops = options.loops or {}
	local column = options.column or 1
	local flags = options.flags or {
		{ key = "AFarm", label = "Auto kick" },
		{ key = "APlaceBest", label = "Auto place" },
		{ key = "AAutoUpgrade", label = "Auto upgrade" },
		{ key = "AAutoFav", label = "Auto favorite" },
		{ key = "ATrain", label = "Auto train" },
		{ key = "ACollect", label = "Auto collect" },
		{ key = "AAutoBattle", label = "Auto battle" },
		{ key = "AAutoMastery", label = "Auto mastery" },
	}

	local group = Core.buildUiGroup(tab, "Automation", column, nil, nil, "AutomationStatus")
	local status = group:CreateStatus("Live loops", {
		Active = "0",
		Total = tostring(#flags),
		Hub = state.HubRunning ~= false and "running" or "stopped",
	})

	local function refresh()
		local active = 0
		local lines = {}
		for _, entry in ipairs(flags) do
			local on = state[entry.key] == true
			if on then
				active += 1
			end
			local loopState = loops[entry.key] or loops[entry.label]
			local pulse = on and (loopState and loopState.enabled ~= false and "●" or "○") or "·"
			table.insert(lines, pulse .. " " .. entry.label)
		end
		status:Update("Active", tostring(active))
		status:Update("Hub", state.HubRunning ~= false and "running" or "stopped")
		if status.SetSummary and type(status.SetSummary) == "function" then
			status:SetSummary(table.concat(lines, "  "))
		end
	end

	group:CreateButton("Refresh status", refresh, "Update loop indicators.")
	task.spawn(function()
		while state.HubRunning ~= false do
			refresh()
			task.wait(2)
		end
	end)

	return group, status, refresh
end

function Core.hsvToColor(h, s, v)
	h = (tonumber(h) or 0) % 360
	s = math.clamp(tonumber(s) or 0, 0, 1)
	v = math.clamp(tonumber(v) or 0, 0, 1)
	local c = v * s
	local x = c * (1 - math.abs((h / 60) % 2 - 1))
	local m = v - c
	local r, g, b = 0, 0, 0
	if h < 60 then
		r, g, b = c, x, 0
	elseif h < 120 then
		r, g, b = x, c, 0
	elseif h < 180 then
		r, g, b = 0, c, x
	elseif h < 240 then
		r, g, b = 0, x, c
	elseif h < 300 then
		r, g, b = x, 0, c
	else
		r, g, b = c, 0, x
	end
	return Color3.new(r + m, g + m, b + m)
end

function Core.applyThemeAccent(windUi, color)
	if type(windUi) ~= "table" or typeof(color) ~= "Color3" then
		return false
	end
	if type(windUi.SetAccentColor) == "function" then
		pcall(function()
			windUi:SetAccentColor(color)
			if type(windUi.FlashAccent) == "function" then
				windUi:FlashAccent()
			end
		end)
		return true
	end
	return false
end

function Core.buildThemeStudioGroup(tab, options)
	options = type(options) == "table" and options or {}
	local column = options.column or 1
	local uiBundle = options.uiBundle
	if not uiBundle and type(options.window) == "table" then
		uiBundle = options.window._ui
	end
	local windUi = uiBundle and (uiBundle.WindUI or uiBundle.Library)
	local group = Core.buildUiGroup(tab, "Theme studio", column, nil, nil, "ThemeStudio")

	ENV.Alleral_AccentHue = tonumber(ENV.Alleral_AccentHue) or 108
	ENV.Alleral_AccentSat = tonumber(ENV.Alleral_AccentSat) or 0.92
	ENV.Alleral_AccentVal = tonumber(ENV.Alleral_AccentVal) or 0.96
	ENV.Alleral_UiRgbLive = ENV.Alleral_UiRgbLive ~= false

	local function pushAccent()
		local color = Core.hsvToColor(ENV.Alleral_AccentHue, ENV.Alleral_AccentSat, ENV.Alleral_AccentVal)
		Core.applyThemeAccent(windUi, color)
	end

	group:CreateToggle("Live preview", ENV.Alleral_UiRgbLive ~= false, "Update accent while dragging sliders.", function(value)
		ENV.Alleral_UiRgbLive = value ~= false
	end)

	group:CreateSlider("Hue", 0, 360, ENV.Alleral_AccentHue, function(value)
		ENV.Alleral_AccentHue = value
		if ENV.Alleral_UiRgbLive ~= false then
			pushAccent()
		end
	end, "Accent hue on the color wheel.", 1)

	group:CreateSlider("Saturation", 0, 100, math.floor(ENV.Alleral_AccentSat * 100), function(value)
		ENV.Alleral_AccentSat = value / 100
		if ENV.Alleral_UiRgbLive ~= false then
			pushAccent()
		end
	end, "Color intensity.", 1)

	group:CreateSlider("Brightness", 0, 100, math.floor(ENV.Alleral_AccentVal * 100), function(value)
		ENV.Alleral_AccentVal = value / 100
		if ENV.Alleral_UiRgbLive ~= false then
			pushAccent()
		end
	end, "How bright the accent reads.", 1)

	local themeNames = { "Private", "Obsidian", "Linoria", "Fluent", "Graphite", "Midnight" }
	group:CreateDropdown("Hub theme", themeNames, ENV.Alleral_UiThemePreset or "Private", function(value)
		ENV.Alleral_UiThemePreset = value
		local win = options.window
		if type(win) == "table" and win._rawWindow and type(win._rawWindow.SetTheme) == "function" then
			win._rawWindow:SetTheme(value)
		elseif windUi and type(windUi.SetTheme) == "function" then
			pcall(function()
				windUi:SetTheme(value)
			end)
		end
		Core.notify("Alleral", "Theme: " .. tostring(value), 2)
	end)

	group:CreateButton("Apply accent", pushAccent, "Commit the wheel color to the UI.")
	group:CreateButton("Reset to mint", function()
		ENV.Alleral_AccentHue = 108
		ENV.Alleral_AccentSat = 0.92
		ENV.Alleral_AccentVal = 0.96
		if windUi and type(windUi.ApplyAccentPreset) == "function" then
			pcall(function()
				windUi:ApplyAccentPreset("Mint")
				if type(windUi.FlashAccent) == "function" then
					windUi:FlashAccent()
				end
			end)
		else
			pushAccent()
		end
	end, "Restore the default Arrrel mint accent.")

	return group
end

function Core.buildCustomizationStudioGroup(tab, options)
	options = type(options) == "table" and options or {}
	local column = options.customizationColumn or options.column or 2
	local uiBundle = options.uiBundle
	if not uiBundle and type(options.window) == "table" then
		uiBundle = options.window._ui
	end
	local windUi = uiBundle and (uiBundle.WindUI or uiBundle.Library)
	local group = Core.buildUiGroup(tab, "Customization V2", column, nil, nil, "CustomizationV2")

	if not windUi or type(windUi.SetMotionProfile) ~= "function" then
		group:CreateLabel("Maclib UI layer unavailable — re-run the loader.")
		return group
	end

	local motionProfiles = { "fluid", "snappy", "bouncy", "cinematic", "reduced" }
	if type(windUi.ListMotionProfiles) == "function" then
		local ok, listed = pcall(function()
			return windUi:ListMotionProfiles()
		end)
		if ok and type(listed) == "table" and #listed > 0 then
			motionProfiles = listed
		end
	end

	local layoutProfiles = { "auto", "desktop", "mobile", "compact", "cinema", "ultrawide", "minimal", "accessibility", "performance" }
	if type(windUi.ListProfiles) == "function" then
		local ok, listed = pcall(function()
			return windUi:ListProfiles()
		end)
		if ok and type(listed) == "table" and #listed > 0 then
			layoutProfiles = { "auto" }
			for _, entry in ipairs(listed) do
				if type(entry) == "table" and entry.id then
					table.insert(layoutProfiles, entry.id)
				elseif type(entry) == "string" then
					table.insert(layoutProfiles, entry)
				end
			end
		end
	end

	local v2Themes = {
		"Arrrel",
		"ArrrelNeon",
		"ArrrelMidnight",
		"ArrrelAurora",
		"ArrrelObsidian",
		"ArrrelSynth",
		"ArrrelOcean",
		"ArrrelEmber",
		"ArrrelStealth",
		"ArrrelPaper",
		"ArrrelVoid",
	}
	if type(windUi.ListThemeNames) == "function" then
		local ok, listed = pcall(function()
			return windUi:ListThemeNames()
		end)
		if ok and type(listed) == "table" and #listed > 0 then
			v2Themes = listed
		end
	end

	group:CreateDropdown("Layout profile", layoutProfiles, ENV.Alleral_UiProfile or "auto", function(selected)
		ENV.Alleral_UiProfile = tostring(selected or "auto")
		if type(windUi.ApplyProfile) == "function" then
			pcall(function()
				windUi:ApplyProfile(ENV.Alleral_UiProfile)
			end)
		end
		Core.notify("Alleral V2", "Layout: " .. tostring(selected), 2, "success")
	end, "Device-aware spacing and scale presets.")

	group:CreateDropdown("Motion feel", motionProfiles, (type(windUi.GetMotionProfile) == "function" and windUi:GetMotionProfile()) or "fluid", function(selected)
		if type(windUi.SetMotionProfile) == "function" then
			windUi:SetMotionProfile(selected)
		end
		Core.notify("Alleral V2", "Motion: " .. tostring(selected), 2, "info")
	end, "Spring personality for tabs, toggles, and panels.")

	group:CreateSlider("Glass intensity", 0, 100, math.floor(((type(windUi.GetGlassIntensity) == "function" and windUi:GetGlassIntensity()) or 0.55) * 100), function(value)
		if type(windUi.SetGlassIntensity) == "function" then
			windUi:SetGlassIntensity(value / 100)
		end
	end, "Sidebar veil and ambient glass strength.", 1)

	group:CreateSlider("Chrome depth", 0, 100, math.floor((tonumber(ENV.Alleral_ChromeDepth) or 0.65) * 100), function(value)
		ENV.Alleral_ChromeDepth = value / 100
		if type(windUi.SetChromeDepth) == "function" then
			windUi:SetChromeDepth(value / 100)
		end
	end, "Glow spread and section elevation.", 1)

	group:CreateDropdown("Tooltip style", { "minimal", "card", "rich" }, (type(windUi.GetTooltipStyle) == "function" and windUi:GetTooltipStyle()) or "rich", function(selected)
		if type(windUi.SetTooltipStyle) == "function" then
			windUi:SetTooltipStyle(selected)
		end
	end, "Hover hint presentation.")

	group:CreateDropdown("Toast style", { "glass", "rail", "banner", "pill" }, (type(windUi.GetNotificationStyle) == "function" and windUi:GetNotificationStyle()) or "glass", function(selected)
		if type(windUi.SetNotificationStyle) == "function" then
			windUi:SetNotificationStyle(selected)
		end
	end, "Notification chrome variant.")

	group:CreateToggle("Ambient window glow", ENV.Alleral_AmbientGlow ~= false, "Soft accent halo behind the window.", function(value)
		ENV.Alleral_AmbientGlow = value ~= false
		if type(windUi.SetAmbientGlow) == "function" then
			windUi:SetAmbientGlow(value)
		end
	end)

	group:CreateToggle("Tab aurora rail", ENV.Alleral_TabAurora ~= false, "Accent pulse on sidebar tabs.", function(value)
		ENV.Alleral_TabAurora = value ~= false
		if type(windUi.SetTabAurora) == "function" then
			windUi:SetTabAurora(value)
		end
	end)

	group:CreateToggle("Section lift", ENV.Alleral_SectionLift ~= false, "Elevated cards with accent edge glow.", function(value)
		ENV.Alleral_SectionLift = value ~= false
		if type(windUi.SetSectionLift) == "function" then
			windUi:SetSectionLift(value)
		end
	end)

	group:CreateDropdown("V2 theme", v2Themes, ENV.Alleral_ActiveTheme or "Arrrel", function(selected)
		if type(windUi.SetTheme) == "function" then
			pcall(function()
				windUi:SetTheme(selected)
				if type(windUi.FlashAccent) == "function" then
					windUi:FlashAccent()
				end
			end)
		end
	end, "Full V2 theme presets including Synth, Ocean, and Void.")

	group:CreateButton("Cycle V2 themes", function()
		if type(windUi.CycleV2Theme) == "function" then
			local ok, nextTheme = pcall(function()
				return windUi:CycleV2Theme(1)
			end)
			if ok and nextTheme then
				Core.notify("Alleral V2", "Theme: " .. tostring(nextTheme), 2, "success")
			end
		end
	end, "Step through the expanded V2 palette.")

	group:CreateButton("Export look", function()
		if type(windUi.ExportCustomization) == "function" then
			local ok, payload = pcall(function()
				return windUi:ExportCustomization()
			end)
			if ok and type(payload) == "table" and Core.setClipboard then
				local encoded = game:GetService("HttpService"):JSONEncode(payload)
				pcall(Core.setClipboard, encoded)
				Core.notify("Alleral V2", "Customization copied to clipboard.", 3, "success")
			end
		end
	end, "Copy your current UI settings as JSON.")

	return group
end

function Core.buildSystemPanelGroup(tab, options)
	options = type(options) == "table" and options or {}
	local column = options.column or 2
	local group = Core.buildUiGroup(tab, "System", column, nil, nil, "SystemPanel")
	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer
	local stats = {
		Hub = Core.UI_LIBRARY or "Alleral",
		UI = Core.ALLERAL_UI_VERSION or "--",
		Core = Core.VERSION or "--",
		Loader = tostring(ENV.Alleral_LoaderVersion or "--"),
		Player = lp and lp.Name or "--",
		Display = lp and lp.DisplayName or "--",
	}
	local status = group:CreateStatus("Runtime", stats)
	group:CreateButton("Refresh system info", function()
		status:Update("Hub", Core.UI_LIBRARY or "Arrrel")
		status:Update("UI", Core.ALLERAL_UI_VERSION or "--")
		status:Update("Core", Core.VERSION or "--")
		status:Update("Loader", tostring(ENV.Alleral_LoaderVersion or "--"))
		status:Update("Player", lp and lp.Name or "--")
		status:Update("Display", lp and lp.DisplayName or "--")
	end, "Refresh version and player labels.")
	return group, status
end

function Core.buildAdvancedHubGroup(tab, options)
	options = type(options) == "table" and options or {}
	local column = options.column or 1
	local group = Core.buildUiGroup(tab, "Advanced", column, nil, nil, "AdvancedHub")
	group:CreateToggle(
		"Force script load",
		ENV.Alleral_ForceLoad == true,
		"Skip manifest version checks on next reload.",
		function(value)
			ENV.Alleral_ForceLoad = value == true
			getgenv().Alleral_ForceLoad = value == true
		end
	)
	group:CreateButton("Repair UI", function()
		local ui = ENV.Alleral_UI
		local windUi = ui and (ui.WindUI or ui.Library)
		if windUi and type(windUi.RepairWindow) == "function" then
			local ok = windUi:RepairWindow()
			Core.notify("Arrrel", ok and "UI repaired." or "Repair failed.", 3, ok and "success" or "error")
		else
			Core.notify("Arrrel", "Repair unavailable.", 3, "warn")
		end
	end, "Re-apply Arrrel chrome and polish.")
	group:CreateButton("Stop hub loops", Core.stateHubStop, "Stop automation loops tied to this session.")
	return group
end

function Core.getExecutorDisplayName()
	local name = "Unknown"
	pcall(function()
		if type(identifyexecutor) == "function" then
			local a, b = identifyexecutor()
			name = tostring(b or a or name)
		elseif type(getexecutorname) == "function" then
			name = tostring(getexecutorname())
		end
	end)
	return name
end

function Core.buildExecutorIntelGroup(tab, column)
	local group = Core.buildUiGroup(tab, "Executor intel", column or 1, nil, nil, "ExecutorIntel")
	local execName = Core.getExecutorDisplayName()
	group:CreateLabel("Executor · " .. execName)
	group:CreateLabel("PlaceId · " .. tostring(game.PlaceId))
	group:CreateLabel("JobId · " .. tostring(game.JobId):sub(1, 20) .. "...")
	group:CreateLabel("UserId · " .. tostring(game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer.UserId or "?"))
	local caps = {}
	for _, cap in ipairs({ "clipboard", "filesystem", "http", "hookmetamethod", "decompile", "getconnections" }) do
		local ok = false
		if cap == "clipboard" then
			ok = type(Core.execFunction("setclipboard")) == "function" or type(setclipboard) == "function"
		elseif cap == "filesystem" then
			ok = type(writefile) == "function"
		elseif cap == "http" then
			ok = type(request) == "function" or type(http_request) == "function"
		else
			ok = type(_G[cap]) == "function" or type(getfenv()[cap]) == "function"
			pcall(function()
				ok = ok or type(loadstring("return " .. cap)()) == "function"
			end)
		end
		if ok then
			table.insert(caps, cap)
		end
	end
	group:CreateLabel("Caps · " .. (#caps > 0 and table.concat(caps, ", ") or "sandboxed"))
	group:CreateButton("Copy JobId", Core.copyJobId, "Copy this server's JobId.")
	group:CreateButton("Copy join link", Core.copyPlaceJoinLink, "Roblox app join link.")
	return group
end

function Core.buildPlayerOpsGroup(tab, column)
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer
	local group = Core.buildUiGroup(tab, "Player ops", column or 2, nil, nil, "PlayerOps")

	local function playerNames()
		local names = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				table.insert(names, plr.Name)
			end
		end
		if #names == 0 then
			table.insert(names, "(no other players)")
		end
		return names
	end

	local names = playerNames()
	local selectedName = names[1]

	local function getTarget()
		if selectedName and selectedName ~= "(no other players)" then
			return Players:FindFirstChild(selectedName)
		end
		return nil
	end

	local dropdown = group:CreateDropdown("Target player", names, selectedName, function(value)
		selectedName = value
	end, "Select a player for exploit actions.")

	local function refreshPlayers()
		local nextNames = playerNames()
		local stillHere = false
		for _, name in ipairs(nextNames) do
			if name == selectedName then
				stillHere = true
				break
			end
		end
		if selectedName and not stillHere then
			selectedName = nextNames[1]
		end
		if dropdown and dropdown.Set then
			dropdown:Set({ Options = nextNames, CurrentOption = selectedName })
		end
	end

	Players.PlayerAdded:Connect(refreshPlayers)
	Players.PlayerRemoving:Connect(refreshPlayers)

	group:CreateButton("Teleport to player", function()
		local target = getTarget()
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local tRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if root and tRoot then
			root.CFrame = tRoot.CFrame * CFrame.new(0, 0, 3)
			Core.notify("Alleral", "Teleported to " .. target.Name, 3, "success")
		else
			Core.notify("Alleral", "Target not available.", 3, "warn")
		end
	end, "Client-side teleport to target HRP.")

	group:CreateButton("Spectate player", function()
		local target = getTarget()
		local hum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		local cam = workspace.CurrentCamera
		if hum and cam then
			cam.CameraSubject = hum
			Core.notify("Alleral", "Spectating " .. target.Name, 3)
		end
	end, "Camera follows target humanoid.")

	group:CreateButton("Reset camera", function()
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum and workspace.CurrentCamera then
			workspace.CurrentCamera.CameraSubject = hum
			Core.notify("Alleral", "Camera reset.", 2)
		end
	end, "Return camera to your character.")

	group:CreateButton("Fling target", function()
		local target = getTarget()
		local tRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if not tRoot then
			Core.notify("Alleral", "Target not available.", 3, "warn")
			return
		end
		local vel = Instance.new("BodyVelocity")
		vel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		vel.Velocity = Vector3.new(0, 500, 0)
		vel.Parent = tRoot
		task.delay(0.15, function()
			if vel and vel.Parent then
				vel:Destroy()
			end
		end)
		Core.notify("Alleral", "Fling applied to " .. target.Name, 3)
	end, "Classic client fling (visual/local).")

	group:CreateButton("Copy username", function()
		local target = getTarget()
		if not target then
			return
		end
		local clip = Core.execFunction("setclipboard")
		if type(clip) == "function" then
			pcall(clip, target.Name)
			Core.notify("Alleral", "Copied " .. target.Name, 3)
		end
	end, "Copy target username to clipboard.")

	return group
end

function Core.buildRemoteToolsGroup(tab, column, options)
	options = type(options) == "table" and options or {}
	local group = Core.buildUiGroup(tab, "Remote tools", column or 2, nil, nil, "RemoteTools")
	local indexed = 0
	local status = group:CreateStatus("Remotes", {
		Indexed = "0",
		LastScan = "never",
	})

	local scanToken = 0

	local function isRemote(inst)
		return inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent")
	end

	local function scanRemotesAsync(done)
		scanToken += 1
		local token = scanToken
		status:Update("LastScan", "scanning")
		task.spawn(function()
			local count = 0
			local descendants = game:GetDescendants()
			for i, inst in ipairs(descendants) do
				if token ~= scanToken then
					return
				end
				if isRemote(inst) then
					count += 1
				end
				if i % 2500 == 0 then
					status:Update("Indexed", tostring(count))
					task.wait()
				end
			end
			if token ~= scanToken then
				return
			end
			indexed = count
			status:Update("Indexed", tostring(count))
			status:Update("LastScan", os.date("%H:%M:%S"))
			if type(done) == "function" then
				done(count)
			end
		end)
	end

	local function scanRemotes()
		scanRemotesAsync()
		return indexed
	end

	group:CreateButton("Scan remotes", function()
		scanRemotesAsync(function(count)
			Core.notify("Alleral", "Indexed " .. tostring(count) .. " remotes.", 3)
			if type(options.onScan) == "function" then
				options.onScan(count)
			end
		end)
	end, "Count RemoteEvent/RemoteFunction instances.")

	group:CreateButton("Copy remote list", function()
		scanRemotesAsync(function()
			scanToken += 1
			local token = scanToken
			task.spawn(function()
				local lines = {}
				local descendants = game:GetDescendants()
				for i, inst in ipairs(descendants) do
					if token ~= scanToken then
						return
					end
					if isRemote(inst) then
						table.insert(lines, inst:GetFullName())
					end
					if i % 2500 == 0 then
						task.wait()
					end
				end
				if token ~= scanToken then
					return
				end
				local clip = Core.execFunction("setclipboard")
				if type(clip) == "function" then
					pcall(clip, table.concat(lines, "\n"))
					Core.notify("Alleral", "Remote list copied (" .. #lines .. ").", 3)
				end
			end)
		end)
	end, "Copy full remote paths to clipboard.")

	return group, status, scanRemotes
end

function Core.buildMovementExploitGroup(tab, options)
	options = type(options) == "table" and options or {}
	local state = options.state or ENV.Alleral_State or {}
	local saveFn = options.saveFn
	local column = options.column or 1
	local group = Core.buildUiGroup(tab, "Movement exploits", column, nil, nil, "MovementExploit")

	if state.Noclip ~= nil or state.ANoclip ~= nil then
		local key = state.Noclip ~= nil and "Noclip" or "ANoclip"
		group:CreateToggle("Noclip", state[key] == true, "Walk through walls.", function(value)
			state[key] = value
			if type(saveFn) == "function" then
				saveFn()
			end
		end)
	end

	if state.Freecam ~= nil then
		group:CreateToggle("Freecam", state.Freecam == true, "Detach camera for scouting.", function(value)
			state.Freecam = value
			if type(saveFn) == "function" then
				saveFn()
			end
		end)
	end

	if state.AFly ~= nil or state.EnableFly ~= nil then
		local key = state.AFly ~= nil and "AFly" or "EnableFly"
		group:CreateToggle("Fly", state[key] == true, "Toggle fly mode if script supports it.", function(value)
			state[key] = value
			if type(saveFn) == "function" then
				saveFn()
			end
		end)
	end

	if state.RunSpeed ~= nil then
		group:CreateSlider("Walk speed", 16, 500, state.RunSpeed, function(value)
			state.RunSpeed = value
			local hum = game:GetService("Players").LocalPlayer.Character
				and game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = value
			end
			if type(saveFn) == "function" then
				saveFn()
			end
		end, "Local walkspeed override.")
	end

	group:CreateButton("Reset character", function()
		local lp = game:GetService("Players").LocalPlayer
		if lp and lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") then
			lp.Character:FindFirstChildOfClass("Humanoid").Health = 0
		end
	end, "Kill character to respawn.")

	return group
end

function Core.registerExploitCommandPalette(window, ui)
	if ENV._AlleralCommandPaletteReady then
		return
	end
	if type(window) ~= "table" or type(ui) ~= "table" then
		return
	end
	local lib = ui.Library or ui.Alleral
	if not lib or not lib.CommandPalette or type(lib.CommandPalette.register) ~= "function" then
		return
	end
	local cmds = {
		{ Name = "Toggle UI", Callback = function()
			if window.Toggle then
				window:Toggle()
			end
		end },
		{ Name = "Copy JobId", Callback = Core.copyJobId },
		{ Name = "Copy join link", Callback = Core.copyPlaceJoinLink },
		{ Name = "Rejoin server", Callback = Core.rejoinServer },
		{ Name = "Server hop (low pop)", Callback = function()
			Core.notify("Alleral", "Use Settings → Server tools for hop controls.", 4)
		end },
	}
	for _, cmd in ipairs(cmds) do
		lib.CommandPalette.register(cmd)
	end
	ENV._AlleralCommandPaletteReady = true
end

function Core.bindExploitMenuKey(window)
	Core.setupHubKeybinds({
		window = window,
		ui = type(window) == "table" and window._ui or ENV.Alleral_UI,
	})
end

function Core.premiumUiSettings(options)
	options = type(options) == "table" and options or {}
	local base = Core.gameUiSettings(options)
	base.Theme = options.Theme or "Private"
	base.Size = options.Size or UDim2.fromOffset(860, 580)
	base.Acrylic = options.Acrylic ~= false
	base.Subtitle = options.Subtitle
	return base
end

function Core.buildPremiumExploitHub(section, options)
	options = type(options) == "table" and options or {}
	local state = options.state or ENV.Alleral_State or {}

	local hub = {}
	hub.dashboardTab = Core.buildUiTab(section, "Dashboard", "layout-dashboard", 2, "dashboard")
	hub.exploitTab = Core.buildUiTab(section, "Exploit", "terminal", 2, "exploit")

	Core.buildSessionStatsGroup(hub.dashboardTab, 1)

	if options.automationFlags then
		Core.buildAutomationStatusGroup(hub.dashboardTab, {
			state = state,
			loops = options.loops,
			flags = options.automationFlags,
			column = 2,
		})
	end

	if type(options.gameStats) == "table" then
		local telemetry = Core.buildUiGroup(hub.dashboardTab, "Game telemetry", 1, nil, nil, "GameTelemetry")
		hub.gameStatus = telemetry:CreateStatus(options.gameName or "Script", options.gameStats)
		if type(options.statsTick) == "function" then
			local tickGen = ENV._AlleralStatsTickGen or 0
			task.spawn(function()
				while ENV._AlleralStatsTickGen == tickGen do
					local liveState = ENV.Alleral_State or state
					if liveState.HubRunning == false then
						break
					end
					pcall(options.statsTick, hub.gameStatus)
					task.wait(options.statsInterval or 2)
				end
			end)
		end
	end

	if options.scriptId then
		Core.buildScriptStatusGroupbox(hub.dashboardTab, 2, options.scriptId, options.version)
	end

	Core.buildExecutorIntelGroup(hub.exploitTab, 1)
	local hopGroup = Core.buildUiGroup(hub.exploitTab, "Server hop", 1, nil, nil, "ServerHop")
	Core.buildJoinServerControls(hopGroup, {
		state = state,
		saveSettings = options.saveFn,
	})
	Core.buildServerToolsGroup(hub.exploitTab, 1)
	Core.buildPlayerOpsGroup(hub.exploitTab, 2)
	Core.buildRemoteToolsGroup(hub.exploitTab, 2, { onScan = options.onRemoteScan })
	Core.buildMovementExploitGroup(hub.exploitTab, {
		state = state,
		saveFn = options.saveFn,
		column = 2,
	})
	Core.buildQuickTogglesGroup(hub.exploitTab, {
		state = state,
		saveFn = options.saveFn,
		column = 1,
	})
	Core.buildErrorLogGroup(hub.exploitTab, 2)

	Core.registerExploitCommandPalette(options.window, options.ui)

	return hub
end

function Core.buildStandardSettingsExtras(tab, options)
	options = type(options) == "table" and options or {}
	Core.installErrorLogHook()
	if type(options.window) == "table" then
		Core.registerUiWindow(options.window)
	end
	local scriptId = Core.resolveActiveGameId(options)
	local profileVersion = options.version or options.profileVersion
	if scriptId and options.skipScriptStatus ~= true then
		Core.buildScriptStatusGroupbox(tab, options.scriptStatusColumn or 1, scriptId, profileVersion)
	end
	if options.skipHubActions ~= true then
		Core.buildHubActionsGroup(tab, options.hubActionsColumn or 2)
	end
	if options.skipCloudConfig ~= true and type(options.savedKeys) == "table" and #options.savedKeys > 0 then
		if type(options.window) == "table" then
			Core.buildCloudConfigTab(options.window, options)
			if options.cloudOnlyTab ~= true then
				Core.buildCloudConfigStudio(tab, options)
			end
		else
			Core.buildCloudConfigStudio(tab, options)
		end
	end
	Core.buildSessionStatsGroup(tab, options.sessionColumn or 1)
	Core.buildServerToolsGroup(tab, options.serverColumn or 1)
	Core.buildThemeStudioGroup(tab, options)
	Core.buildCustomizationStudioGroup(tab, options)
	Core.buildSystemPanelGroup(tab, options)
	Core.buildAdvancedHubGroup(tab, options)
	Core.buildQuickTogglesGroup(tab, options)
	Core.buildUiPreferencesGroup(tab, options)
	Core.buildErrorLogGroup(tab, options.errorColumn or 2)
	Core.buildSettingsBackupGroup(tab, options)
	if options.setupKeybinds ~= false then
		Core.setupHubKeybinds({
			window = options.window,
			ui = options.ui or options.uiBundle,
			uiBundle = options.uiBundle,
			panicKey = options.panicKey,
			uiKey = options.uiKey,
			insertKey = options.insertKey,
		})
	end
	if type(options.window) == "table" then
		task.defer(function()
			Core.repairUiWindow(options.window)
		end)
	end
end

function stateHubStop()
	local state = ENV.Alleral_State
	if type(state) == "table" then
		state.HubRunning = false
		if type(state.Alleral_Unload) == "function" then
			pcall(state.Alleral_Unload)
		end
	end
	local telemetry = ENV.Alleral_Telemetry
	if type(telemetry) == "table" and type(telemetry.ReportSessionEnd) == "function" then
		telemetry:ReportSessionEnd("stopped")
	end
	Core.notify("Alleral", "loops stopped", 3)
end

Core.stateHubStop = stateHubStop

local function trimText(value)
	return tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
end

function Core.sanitizeProfileName(name)
	name = trimText(name):gsub("[^%w%-_%s]", ""):gsub("%s+", "_")
	if name == "" then
		return "Default"
	end
	return name:sub(1, 32)
end

function Core.buildConfigProfileGroup(tab, options)
	options = type(options) == "table" and options or {}
	local state = options.state or ENV.Alleral_State or {}
	local savedKeys = options.savedKeys or {}
	local profileFolder = options.profileFolder or "Alleral_Configs/Profiles"
	local saveFn = options.saveFn or function() end
	local onApply = options.onApply
	local scriptVersion = options.version or "1.0"
	local column = options.column or 2

	local writeFile = Core.execFunction("writefile")
	local readFile = Core.execFunction("readfile")
	local isFile = Core.execFunction("isfile")
	local isFolder = Core.execFunction("isfolder")
	local makeFolder = Core.execFunction("makefolder")
	local listFiles = Core.execFunction("listfiles")
	local deleteFile = Core.execFunction("delfile")
	local setClipboard = Core.execFunction("setclipboard") or Core.execFunction("setclipboard", true)

	local function ensureFolder()
		if type(makeFolder) ~= "function" then
			return false
		end
		pcall(makeFolder, "Alleral_Configs")
		pcall(makeFolder, profileFolder)
		return true
	end

	local function profilePath(name)
		return profileFolder .. "/" .. Core.sanitizeProfileName(name) .. ".json"
	end

	local function collectSnapshot()
		local snapshot = {}
		for _, key in ipairs(savedKeys) do
			snapshot[key] = Core.copyValue(state[key])
		end
		snapshot.__meta = {
			version = scriptVersion,
			createdAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		}
		return snapshot
	end

	local function applySnapshot(snapshot)
		if type(snapshot) ~= "table" then
			return false, "Invalid profile file."
		end
		for _, key in ipairs(savedKeys) do
			if snapshot[key] ~= nil then
				state[key] = Core.copyValue(snapshot[key])
			end
		end
		if type(onApply) == "function" then
			pcall(onApply, snapshot)
		end
		saveFn()
		return true, nil
	end

	local function listProfiles()
		local names = {}
		if type(listFiles) == "function" and type(isFolder) == "function" and isFolder(profileFolder) then
			for _, path in ipairs(listFiles(profileFolder)) do
				local name = tostring(path):match("([^/\\]+)%.json$")
				if name then
					table.insert(names, name)
				end
			end
		end
		table.sort(names)
		if #names == 0 then
			table.insert(names, "Default")
		end
		return names
	end

	local profileName = Core.sanitizeProfileName(state.ActiveProfileName or "Default")
	local groupbox = tab:CreateGroupbox({
		Name = "Config profiles",
		Column = column,
		Icon = 6031075938,
	}, "ConfigProfiles")
	local group = Core.wrapUiGroup(groupbox)

	group:CreateInput("Profile name", "my setup", profileName, function(value)
		profileName = Core.sanitizeProfileName(value)
		state.ActiveProfileName = profileName
		saveFn()
	end, "Name used when saving or loading.")

	group:CreateButton("Save profile", function()
		if type(writeFile) ~= "function" then
			Core.notify("Alleral", "Your executor can't save files.", 5)
			return
		end
		ensureFolder()
		local ok = Core.writeFile(profilePath(profileName), HttpService:JSONEncode(collectSnapshot()))
		if ok then
			state.ActiveProfileName = profileName
			saveFn()
			Core.notify("Alleral", "Saved '" .. profileName .. "'.", 4)
		end
	end, "Writes all settings to disk under this name.")

	group:CreateButton("Load profile", function()
		if type(readFile) ~= "function" or type(isFile) ~= "function" then
			Core.notify("Alleral", "Your executor can't read files.", 5)
			return
		end
		local path = profilePath(profileName)
		if not isFile(path) then
			Core.notify("Alleral", "No profile named '" .. profileName .. "'.", 5)
			return
		end
		local raw = readFile(path)
		local decodedOk, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if not decodedOk then
			Core.notify("Alleral", "Profile JSON is corrupt.", 5)
			return
		end
		local applied, err = applySnapshot(decoded)
		if applied then
			Core.notify("Alleral", "Loaded '" .. profileName .. "'. Reload to refresh UI.", 5)
		else
			Core.notify("Alleral", tostring(err), 5)
		end
	end, "Applies a saved profile to this session.")

	group:CreateButton("Delete profile", function()
		if type(deleteFile) ~= "function" then
			Core.notify("Alleral", "Your executor can't delete files.", 5)
			return
		end
		local path = profilePath(profileName)
		if type(isFile) == "function" and not isFile(path) then
			Core.notify("Alleral", "Nothing to delete.", 4)
			return
		end
		pcall(deleteFile, path)
		Core.notify("Alleral", "Deleted '" .. profileName .. "'.", 4)
	end)

	group:CreateButton("Copy to clipboard", function()
		if type(setClipboard) ~= "function" then
			Core.notify("Alleral", "Clipboard not supported.", 4)
			return
		end
		pcall(setClipboard, HttpService:JSONEncode(collectSnapshot()))
		Core.notify("Alleral", "Profile copied — paste to share.", 4)
	end)

	group:CreateButton("Paste from clipboard", function()
		local clip = Core.execFunction("getclipboard") or Core.execFunction("getclipboard", true)
		if type(clip) ~= "function" then
			Core.notify("Alleral", "Clipboard not supported.", 4)
			return
		end
		local ok, raw = pcall(clip)
		if not ok or type(raw) ~= "string" or raw == "" then
			Core.notify("Alleral", "Clipboard is empty.", 4)
			return
		end
		local decodedOk, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if not decodedOk then
			Core.notify("Alleral", "Clipboard doesn't contain valid JSON.", 5)
			return
		end
		local applied, err = applySnapshot(decoded)
		if applied then
			Core.notify("Alleral", "Imported profile from clipboard.", 4)
		else
			Core.notify("Alleral", tostring(err), 5)
		end
	end)

	local names = listProfiles()
	group:CreateDropdown("Saved profiles", names, profileName, function(value)
		profileName = Core.sanitizeProfileName(value)
		state.ActiveProfileName = profileName
		saveFn()
	end, "Quick-pick a profile you've saved before.")

	return group
end

function Core.buildCloudConfigStudio(tab, options)
	options = type(options) == "table" and options or {}
	local state = options.state or ENV.Alleral_State or {}
	local savedKeys = options.savedKeys or {}
	local saveFn = options.saveFn or function() end
	local onApply = options.onApply
	local scriptVersion = options.version or options.profileVersion or "1.0"
	local gameId = Core.resolveActiveGameId(options) or options.gameId or "unknown"
	local libraryColumn = options.cloudLibraryColumn or 1
	local communityColumn = options.cloudCommunityColumn or 2
	local shareCode = tostring(state.Alleral_CloudConfigCode or "")
	local sharePublic = state.Alleral_CloudConfigPublic ~= false
	local browseEntries = {}
	local browseLabels = { "Refresh community list" }
	local selectedBrowseCode = shareCode
	local previewCache = nil

	local function collectSnapshot()
		local snapshot = {}
		for _, key in ipairs(savedKeys) do
			snapshot[key] = Core.copyValue(state[key])
		end
		snapshot.__meta = {
			version = scriptVersion,
			gameId = gameId,
			createdAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			brand = "Alleral",
		}
		return snapshot
	end

	local function applySnapshot(snapshot)
		if type(snapshot) ~= "table" then
			return false, "Invalid cloud config."
		end
		for _, key in ipairs(savedKeys) do
			if snapshot[key] ~= nil then
				state[key] = Core.copyValue(snapshot[key])
			end
		end
		if type(onApply) == "function" then
			pcall(onApply, snapshot)
		end
		saveFn()
		return true, nil
	end

	local function countDiff(remote)
		if type(remote) ~= "table" then
			return 0
		end
		local changed = 0
		for _, key in ipairs(savedKeys) do
			local localValue = state[key]
			local remoteValue = remote[key]
			if remoteValue ~= nil and HttpService:JSONEncode(localValue) ~= HttpService:JSONEncode(remoteValue) then
				changed += 1
			end
		end
		return changed
	end

	local function formatBrowseLabel(entry)
		return string.format(
			"[%s] %s · %s · %s dl",
			tostring(entry.code or "??????"),
			tostring(entry.name or "Untitled"),
			tostring(entry.author or "?"),
			tostring(entry.downloads or 0)
		)
	end

	local library = Core.buildUiGroup(tab, "Cloud library", libraryColumn, nil, nil, "CloudLibrary")
	local community = Core.buildUiGroup(tab, "Community browser", communityColumn, nil, nil, "CloudCommunity")

	local cloudStatus = library:CreateStatus("Cloud", {
		Code = shareCode ~= "" and shareCode or "--",
		Setup = state.Alleral_CloudConfigName or "My setup",
		DNA = "--",
		Diff = "--",
		Downloads = "--",
		Status = "Ready",
	})
	cloudStatus:SetSummary("Upload, preview DNA, then import when you're happy.")

	local function setStatus(message, tone)
		cloudStatus:Update("Status", message or "Ready")
		if tone then
			Core.notify("Alleral Cloud", tostring(message or ""), 5, tone)
		end
	end

	local function updatePreviewStatus(decoded)
		previewCache = decoded
		if type(decoded) ~= "table" then
			cloudStatus:Update("DNA", "--")
			cloudStatus:Update("Diff", "--")
			cloudStatus:Update("Downloads", "--")
			return
		end
		local diff = countDiff(decoded.data)
		cloudStatus:Update("Code", tostring(decoded.code or shareCode or "--"))
		cloudStatus:Update("Setup", tostring(decoded.name or state.Alleral_CloudConfigName or "My setup"))
		cloudStatus:Update("DNA", tostring(decoded.dna or "?"))
		cloudStatus:Update("Diff", tostring(diff) .. " keys")
		cloudStatus:Update("Downloads", tostring(decoded.downloads or 0))
		cloudStatus:SetSummary(
			string.format(
				"%s by %s · v%s · DNA %s · %s keys would change",
				tostring(decoded.name or "Untitled"),
				tostring(decoded.author or "?"),
				tostring(decoded.scriptVersion or "?"),
				tostring(decoded.dna or "?"),
				tostring(diff)
			)
		)
	end

	local function fetchRemote(code)
		code = trimText(code):upper()
		if code == "" then
			return nil, "Enter a share code."
		end
		local base = Core.resolveRelayBase()
		local decoded = Core.httpGetJson(base .. "/api/configs/" .. code)
		if not decoded or decoded.ok ~= true or type(decoded.data) ~= "table" then
			return nil, decoded and decoded.error or "Config not found."
		end
		return decoded, nil
	end

	library:CreateLabel("Publish your current setup to the Alleral cloud. Each upload gets a DNA fingerprint so you can preview before importing.")
	library:CreateInput("Setup name", "my public build", state.Alleral_CloudConfigName or "My setup", function(value)
		state.Alleral_CloudConfigName = trimText(value)
		cloudStatus:Update("Setup", state.Alleral_CloudConfigName)
		saveFn()
	end, "Shown in the community browser when public.")
	library:CreateToggle(
		"List publicly",
		sharePublic,
		"Public configs appear in the community browser for this game.",
		function(value)
			sharePublic = value ~= false
			state.Alleral_CloudConfigPublic = sharePublic
			saveFn()
		end
	)
	library:CreateButton("Upload current setup", function()
		setStatus("Uploading...", nil)
		local base = Core.resolveRelayBase()
		local payload = {
			gameId = gameId,
			name = state.Alleral_CloudConfigName or "My setup",
			author = (game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer.DisplayName) or "Player",
			scriptVersion = scriptVersion,
			public = sharePublic,
			tags = { "alleral", gameId },
			data = collectSnapshot(),
		}
		local decoded, err = Core.httpPostJson(base .. "/api/configs/publish", payload)
		if not decoded or decoded.ok ~= true or not decoded.code then
			setStatus("Upload failed", "error")
			return
		end
		shareCode = tostring(decoded.code)
		state.Alleral_CloudConfigCode = shareCode
		saveFn()
		cloudStatus:Update("Code", shareCode)
		cloudStatus:Update("DNA", tostring(decoded.dna or "?"))
		cloudStatus:Update("Diff", "0 keys")
		cloudStatus:SetSummary("Uploaded " .. shareCode .. " · DNA " .. tostring(decoded.dna or "?"))
		setStatus("Uploaded " .. shareCode, "success")
		if Core.setClipboard then
			pcall(Core.setClipboard, shareCode)
		end
		task.defer(refreshBrowse)
	end, "Uploads this session and copies the share code.")
	library:CreateDivider()
	library:CreateInput("Share code", "ABC123", shareCode, function(value)
		shareCode = trimText(value):upper()
		state.Alleral_CloudConfigCode = shareCode
		cloudStatus:Update("Code", shareCode ~= "" and shareCode or "--")
		saveFn()
	end, "Paste a friend's 6-character code.")
	library:CreateButton("Preview DNA", function()
		if shareCode == "" then
			setStatus("Enter a share code first.", "warn")
			return
		end
		setStatus("Fetching preview...", nil)
		local decoded, err = fetchRemote(shareCode)
		if not decoded then
			setStatus(tostring(err or "Preview failed."), "error")
			return
		end
		updatePreviewStatus(decoded)
		setStatus("Preview ready", "info")
	end, "Loads remote DNA and shows how many keys would change.")
	library:CreateButton("Import selected setup", function()
		if shareCode == "" then
			setStatus("Enter a share code first.", "warn")
			return
		end
		setStatus("Importing...", nil)
		local decoded = previewCache
		if not decoded or tostring(decoded.code or ""):upper() ~= shareCode then
			local remote, err = fetchRemote(shareCode)
			if not remote then
				setStatus(tostring(err or "Import failed."), "error")
				return
			end
			decoded = remote
		end
		local applied, err = applySnapshot(decoded.data)
		if applied then
			updatePreviewStatus(decoded)
			setStatus("Imported " .. tostring(decoded.name or shareCode), "success")
		else
			setStatus(tostring(err or "Import failed."), "error")
		end
	end, "Applies the previewed cloud config to this session.")

	local communityStatus = community:CreateStatus("Browse", {
		Game = gameId,
		Listed = "0",
		Selected = shareCode ~= "" and shareCode or "--",
	})
	communityStatus:SetSummary("Pick a public setup, preview it, then import from the library panel.")

	local browseDropdown
	local function refreshBrowse()
		local base = Core.resolveRelayBase()
		local decoded = Core.httpGetJson(base .. "/api/configs/browse?game=" .. HttpService:UrlEncode(gameId) .. "&limit=20")
		browseEntries = {}
		browseLabels = {}
		if decoded and decoded.ok == true and type(decoded.configs) == "table" then
			for _, entry in ipairs(decoded.configs) do
				if type(entry) == "table" and entry.code then
					table.insert(browseEntries, entry)
					table.insert(browseLabels, formatBrowseLabel(entry))
				end
			end
		end
		if #browseLabels == 0 then
			table.insert(browseLabels, "No public configs yet")
		end
		communityStatus:Update("Listed", tostring(#browseEntries))
		if browseDropdown and browseDropdown.Refresh then
			browseDropdown:Refresh(browseLabels, browseLabels[1])
		end
		if #browseEntries > 0 then
			selectedBrowseCode = tostring(browseEntries[1].code or "")
			communityStatus:Update("Selected", selectedBrowseCode)
		end
	end

	community:CreateLabel("Browse player-uploaded setups for this game. Select one to load its share code into the library panel.")
	browseDropdown = community:AddDropdown("CloudBrowse", {
		Text = "Public setups",
		Values = browseLabels,
		Default = browseLabels[1],
		Tooltip = "Sorted by downloads.",
		Callback = function(selected)
			local label = type(selected) == "table" and selected[1] or selected
			for index, entry in ipairs(browseEntries) do
				if browseLabels[index] == label then
					selectedBrowseCode = tostring(entry.code or "")
					shareCode = selectedBrowseCode
					state.Alleral_CloudConfigCode = shareCode
					cloudStatus:Update("Code", shareCode)
					communityStatus:Update("Selected", shareCode)
					saveFn()
					task.defer(function()
						local decoded, err = fetchRemote(shareCode)
						if decoded then
							updatePreviewStatus(decoded)
							communityStatus:SetSummary(formatBrowseLabel(entry))
						else
							communityStatus:SetSummary(tostring(err or "Preview failed."))
						end
					end)
					return
				end
			end
		end,
	})
	community:CreateButton("Refresh community list", refreshBrowse, "Pull the latest public configs from the relay.")
	community:CreateButton("Load into library", function()
		if selectedBrowseCode == "" or selectedBrowseCode == "No public configs yet" then
			setStatus("Pick a public setup first.", "warn")
			return
		end
		shareCode = selectedBrowseCode
		state.Alleral_CloudConfigCode = shareCode
		cloudStatus:Update("Code", shareCode)
		saveFn()
		task.defer(function()
			local decoded, err = fetchRemote(shareCode)
			if decoded then
				updatePreviewStatus(decoded)
				setStatus("Loaded " .. shareCode .. " into library.", "success")
			else
				setStatus(tostring(err or "Load failed."), "error")
			end
		end)
	end, "Copies the selected community code into the library panel.")
	community:CreateButton("Import selected setup", function()
		if selectedBrowseCode == "" then
			setStatus("Pick a public setup first.", "warn")
			return
		end
		shareCode = selectedBrowseCode
		state.Alleral_CloudConfigCode = shareCode
		local decoded, err = fetchRemote(shareCode)
		if not decoded then
			setStatus(tostring(err or "Import failed."), "error")
			return
		end
		local applied, applyErr = applySnapshot(decoded.data)
		if applied then
			updatePreviewStatus(decoded)
			setStatus("Imported " .. tostring(decoded.name or shareCode), "success")
		else
			setStatus(tostring(applyErr or "Import failed."), "error")
		end
	end, "Imports the highlighted community setup immediately.")

	task.defer(refreshBrowse)

	return library, community, cloudStatus, communityStatus
end

Core.buildCloudConfigGroup = Core.buildCloudConfigStudio

function Core.buildCloudConfigTab(window, options)
	options = type(options) == "table" and options or {}
	window = window or options.window
	if not window then
		return nil
	end
	local tab = Core.buildUiTab(
		{ _window = window, _ui = options.uiBundle or window._ui },
		options.cloudTabName or "Configs",
		options.cloudTabIcon or "cloud",
		2
	)
	Core.buildCloudConfigStudio(tab, options)
	return tab
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

function Core.buildDiscordEmbed(opts)
	opts = type(opts) == "table" and opts or {}
	local embed = {
		title = opts.title,
		description = opts.description,
		color = opts.color or 5489688,
		fields = opts.fields,
		footer = opts.footer or { text = opts.brand or "Alleral" },
		timestamp = opts.timestamp,
		thumbnail = opts.thumbnail,
		image = opts.image,
		author = opts.author,
	}
	if embed.fields == nil then
		embed.fields = {}
	end
	return embed
end

function Core.buildDiscordPayload(opts)
	opts = type(opts) == "table" and opts or {}
	local embeds = opts.embeds
	if type(embeds) ~= "table" or #embeds == 0 then
		embeds = { Core.buildDiscordEmbed(opts) }
	end
	return {
		username = opts.username or opts.brand or "Alleral",
		avatar_url = opts.avatarUrl,
		content = opts.content,
		embeds = embeds,
	}
end

function Core.discordField(name, value, inline)
	local text = trimText(value)
	if text == "" then
		text = "—"
	end
	if #text > 1024 then
		text = text:sub(1, 1021) .. "..."
	end
	return {
		name = tostring(name or "Field"),
		value = "```" .. text .. "```",
		inline = inline == true,
	}
end

function Core.discordLinkField(name, label, url, inline)
	url = trimText(url)
	if url == "" then
		return Core.discordField(name, "—", inline)
	end
	return {
		name = tostring(name or "Link"),
		value = string.format("[%s](%s)", label or "Open", url),
		inline = inline == true,
	}
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
end
