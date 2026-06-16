-- Alleral loader relaunch module (loaded at runtime by loader.luau)
local ENV = getgenv()
local deps = ENV._Alleral_LoaderInternals or {}
local GAMES = ENV._Alleral_GAMES or {}

local log = deps.log or function() end
local notify = deps.notify or function() end
local httpGet = deps.httpGet or (ENV.Alleral_HTTP and ENV.Alleral_HTTP.get)
local compileAndRun = deps.compileAndRun
local loaderRunEnv = deps.loaderRunEnv
local stopAutoUpdater = deps.stopAutoUpdater
local GITHUB_RAW = deps.GITHUB_RAW or ""
local BOOTSTRAP_REMOTE_PATH = deps.BOOTSTRAP_REMOTE_PATH or "bootstrap.luau"
local BOOTSTRAP_LOADSTRING = deps.BOOTSTRAP_LOADSTRING or ""
local writeFileFn = deps.writeFileFn
local makeFolderFn = deps.makeFolderFn
local isFolderFn = deps.isFolderFn
local gameInstance = deps.game
if typeof(gameInstance) ~= "Instance" and typeof(ENV.game) == "Instance" then
	gameInstance = ENV.game
end
if typeof(gameInstance) ~= "Instance" and typeof(game) == "Instance" then
	gameInstance = game
end

if type(compileAndRun) ~= "function" or typeof(gameInstance) ~= "Instance" then
	return
end

local TELEPORT_RELAUNCH_COOLDOWN = 5
local LOADER_MIN_BYTES = 50000

local function installAutoexecRedirect()
	if type(writeFileFn) ~= "function" then
		return
	end
	local stub = table.concat({
		"local g = getgenv()",
		"if g.Alleral_AutoRelaunch == false then return end",
		"if not g._Alleral_SessionWasActive and not g._Alleral_PendingRelaunch then return end",
		"local placeOk = g._Alleral_LastPlaceId == game.PlaceId",
		"if type(g._Alleral_SupportedPlaces) == 'table' and g._Alleral_SupportedPlaces[game.PlaceId] then placeOk = true end",
		"if not placeOk and not g._Alleral_PendingRelaunch then return end",
		BOOTSTRAP_LOADSTRING,
		"",
	}, "\n")
	local targetDir = "autoexec"
	if type(isFolderFn) == "function" then
		for _, candidate in ipairs({ "autoexec", "Autoexec" }) do
			local okFolder, exists = pcall(isFolderFn, candidate)
			if okFolder and exists == true then
				targetDir = candidate
				break
			end
		end
	end
	if type(isFolderFn) == "function" then
		local okFolder, exists = pcall(isFolderFn, targetDir)
		if (not okFolder or exists ~= true) and type(makeFolderFn) == "function" then
			pcall(makeFolderFn, targetDir)
		end
	end
	local okWrite, writeErr = pcall(writeFileFn, targetDir .. "/alleral.luau", stub)
	if okWrite then
		log("Wrote " .. targetDir .. "/alleral.luau (local-first relaunch)")
	else
		log("Autoexec install failed at " .. targetDir .. "/alleral.luau: " .. tostring(writeErr), true)
	end
	return okWrite, writeErr
end

local function markSupportedPlaces()
	local places = {}
	for _, profile in ipairs(GAMES) do
		for _, placeId in ipairs(profile.placeIds or {}) do
			places[placeId] = true
		end
	end
	ENV._Alleral_SupportedPlaces = places
end

local function relaunchViaBootstrap(reason)
	reason = reason or "relaunch"
	if ENV._Alleral_BootstrapRunning then
		return false, "bootstrap already running"
	end
	if type(stopAutoUpdater) == "function" then
		stopAutoUpdater()
	end

	local src, via = httpGet(GITHUB_RAW .. "/bootstrap.luau?t=" .. tostring(tick()), 200)
	if type(src) ~= "string" or #src < 200 then
		src, via = httpGet(GITHUB_RAW .. "/loader.luau?t=" .. tostring(tick()), LOADER_MIN_BYTES)
	end
	if type(src) ~= "string" or #src < 200 then
		return false, "bootstrap fetch failed (" .. tostring(via) .. ")"
	end
	ENV._Alleral_BootstrapSkipAutoRun = true
	local ok, err = compileAndRun(src, "Alleral/bootstrap", loaderRunEnv())
	ENV._Alleral_BootstrapSkipAutoRun = nil
	return ok == true, err
end

local function installGlobalBootstrap()
	if ENV._Alleral_BootstrapInstalled then
		return
	end
	ENV._Alleral_BootstrapInstalled = true

	ENV._Alleral_RunLoader = function(reason)
		local g = getgenv()
		if g.Alleral_AutoRelaunch == false then
			return
		end
		g._Alleral_RunLoaderToken = (g._Alleral_RunLoaderToken or 0) + 1
		local token = g._Alleral_RunLoaderToken
		task.delay(0.75, function()
			if g._Alleral_RunLoaderToken ~= token then
				return
			end
			if g.Alleral_LoaderRunning then
				return
			end

			if g.Alleral_State and type(g.Alleral_State.Alleral_Unload) == "function" then
				pcall(g.Alleral_State.Alleral_Unload)
			end
			local prevCore = g.Alleral_Core
			if type(prevCore) == "table" and type(prevCore.releaseUiWindow) == "function" then
				pcall(prevCore.releaseUiWindow)
			end
			g.Alleral_LoaderRunning = false
			g._Alleral_TeleportWatchConnected = nil
			g._Alleral_RelaunchScheduledAt = nil
			g._Alleral_AutoUpdateRunning = false
			g._Alleral_AutoUpdateToken = nil
			if reason then
				g._Alleral_PendingRelaunch = true
			end

			local ok, err = relaunchViaBootstrap(reason or "relaunch")
			if not ok then
				warn("[Alleral] Bootstrap relaunch failed: " .. tostring(err))
			end
		end)
	end

	pcall(function()
		local TeleportService = gameInstance:GetService("TeleportService")
		TeleportService.LocalPlayerArrivedFromTeleport:Connect(function()
			local g = getgenv()
			g._Alleral_PendingRelaunch = true
			task.delay(2.5, function()
				if type(g._Alleral_RunLoader) == "function" then
					g._Alleral_RunLoader("arrived-from-teleport")
				end
			end)
		end)
	end)
end

local function scheduleHubRelaunch(reason, delaySeconds)
	if ENV.Alleral_AutoRelaunch == false then
		return
	end
	delaySeconds = delaySeconds or 2
	local now = tick()
	if ENV._Alleral_RelaunchScheduledAt and (now - ENV._Alleral_RelaunchScheduledAt) < 1 then
		return
	end
	if ENV._Alleral_LastLoadAt and (now - ENV._Alleral_LastLoadAt) < TELEPORT_RELAUNCH_COOLDOWN then
		if ENV._Alleral_LastJobId and tostring(ENV._Alleral_LastJobId) == tostring(gameInstance.JobId) then
			return
		end
	end
	ENV._Alleral_RelaunchScheduledAt = now
	task.delay(delaySeconds, function()
		ENV._Alleral_RelaunchScheduledAt = nil
		if type(ENV._Alleral_RunLoader) == "function" then
			log("Teleport relaunch: " .. tostring(reason))
			notify("Alleral", "new server — reloading hub", 3)
			ENV._Alleral_RunLoader(reason)
		elseif type(ENV.Alleral_Reload) == "function" then
			ENV.Alleral_Reload()
		else
			log("Relaunch unavailable after teleport — re-run the loader", true)
		end
	end)
end

local function ensureAutoexecLoader()
	if ENV.Alleral_AutoRelaunch == false then
		return
	end
	if type(writeFileFn) ~= "function" then
		log("Teleport auto-relaunch works best with writefile (autoexec stub skipped)", true)
		return
	end
	installAutoexecRedirect()
end

local function wireTeleportRelaunch()
	if ENV.Alleral_AutoRelaunch == nil then
		ENV.Alleral_AutoRelaunch = true
	end
	installGlobalBootstrap()
	if ENV._Alleral_TeleportWatchConnected then
		return
	end
	ENV._Alleral_TeleportWatchConnected = true
	ENV._Alleral_SessionWasActive = true
	ENV._Alleral_LastPlaceId = gameInstance.PlaceId
	ENV._Alleral_LastJobId = gameInstance.JobId
	markSupportedPlaces()

	pcall(function()
		local Players = gameInstance:GetService("Players")
		local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

		LocalPlayer.OnTeleport:Connect(function(_teleportState, placeId)
			ENV._Alleral_PendingRelaunch = true
			ENV._Alleral_PendingPlaceId = placeId
			ENV._Alleral_TeleportAt = tick()
			log("Teleport detected — hub will reload when you arrive")
		end)

		LocalPlayer.CharacterAdded:Connect(function()
			local teleAt = ENV._Alleral_TeleportAt
			if type(teleAt) ~= "number" or (tick() - teleAt) > 60 then
				return
			end
			ENV._Alleral_TeleportAt = nil
			scheduleHubRelaunch("spawn-after-teleport", 2)
		end)
	end)
end

ENV._Alleral_InstallAutoexecRedirect = installAutoexecRedirect
ENV._Alleral_MarkSupportedPlaces = markSupportedPlaces
ENV._Alleral_RelaunchViaBootstrap = relaunchViaBootstrap
ENV._Alleral_InstallGlobalBootstrap = installGlobalBootstrap
ENV._Alleral_EnsureAutoexec = ensureAutoexecLoader
ENV._Alleral_EnsureTeleportWatch = wireTeleportRelaunch
ENV._Alleral_ScheduleRelaunch = scheduleHubRelaunch
