return function(Core)
	local HttpService = game:GetService("HttpService")
	local StarterGui = game:GetService("StarterGui")
	local WINDUI_MIRROR_URLS = {
		"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/ui/windui/",
		"https://github.com/evanbackup1256-ship-it/kick/raw/main/ui/windui/",
		"https://github.com/Footagesus/WindUI/releases/download/1.6.64-fix/",
		"https://raw.githubusercontent.com/Footagesus/WindUI/1.6.64-fix/dist/",
	}
	local WINDUI_LOCAL_ROOTS = {
		"ui/windui/",
		"kick/ui/windui/",
		"kick/kick/ui/windui/",
		"windui/",
	}
	local WINDUI_FILE = "main.lua"
	local WINDUI_PATCH_FILE = "arrrel.luau"
	local WINDUI_PATCH_FALLBACK = "aller.luau"
	local WINDUI_MIN_BYTES = 50000
	local ALLERAL_ACCENT = Color3.fromHex("#53fc18")
	local ALLERAL_ACCENT_ALT = Color3.fromHex("#30ff6a")
	local function genv()
		local ok, env = pcall(function()
			return getgenv and getgenv() or getfenv()
		end)
		return ok and env or {}
	end
	local ENV = genv()

local function uiOk(bundle)
	return type(bundle) == "table"
		and type(bundle.Library) == "table"
		and type(bundle.CreateWindow) == "function"
end

local function stampUi(bundle)
	if type(bundle) ~= "table" then
		return bundle
	end
	bundle.InterfaceBuild = Core.UI_LIBRARY
	bundle.UI_LIBRARY = Core.UI_LIBRARY
	return bundle
end

local function windUiSourceValid(body)
	if type(body) ~= "string" or body == "" then
		return false
	end
	if #body < WINDUI_MIN_BYTES then
		return false
	end
	return body:find("CreateWindow", 1, true) ~= nil or body:find("WindUI", 1, true) ~= nil
end

local function compileWindUiModule(source, label)
	local loadStringFn = Core.loadStringFn()
	if not loadStringFn or not source or source == "" then
		return nil, "Empty WindUI source"
	end
	local cacheKey = tostring(#source) .. ":" .. tostring(label)
	local cache = ENV._AlleralWindUiCompileCache
	if cache and cache.key == cacheKey and type(cache.module) == "table" then
		return cache.module
	end
	if not windUiSourceValid(source) then
		return nil, "WindUI source invalid (" .. tostring(#source) .. " bytes)"
	end
	local compiled, compileErr = loadStringFn(source, label)
	if not compiled and type(load) == "function" and load ~= loadStringFn then
		compiled, compileErr = load(source, label)
	end
	if not compiled then
		return nil, tostring(compileErr)
	end
	local ok, result = pcall(compiled)
	if ok and type(result) == "table" and type(result.CreateWindow) == "function" then
		ENV.Alleral_WindUiLastGood = result
		ENV._AlleralWindUiCompileCache = {
			key = tostring(#source) .. ":" .. tostring(label),
			module = result,
		}
		return result
	end
	if not ok then
		Core.logWarn("Alleral UI compile error: " .. tostring(result))
	end
	if ENV.Alleral_WindUiLastGood and type(ENV.Alleral_WindUiLastGood.CreateWindow) == "function" then
		Core.logWarn("Alleral UI compile failed, using last good copy")
		return ENV.Alleral_WindUiLastGood
	end
	return nil, ok and "Invalid WindUI module" or tostring(result)
end

local function readWindUiLocal(relativePath)
	local cacheKey = "_AlleralWindPath_" .. tostring(relativePath):gsub("[^%w]", "_")
	local cachedPath = ENV[cacheKey]
	if type(cachedPath) == "string" then
		local cachedSource = Core.readFile(cachedPath)
		if cachedSource then
			return cachedSource, cachedPath
		end
	end

	local roots = { "", "kick/", "kick/kick/", "workspace/", "scripts/" }
	for _, vendorRoot in ipairs(WINDUI_LOCAL_ROOTS) do
		for _, root in ipairs(roots) do
			local fullPath = root .. vendorRoot .. relativePath
			local source = Core.readFile(fullPath)
			if source then
				ENV[cacheKey] = fullPath
				return source, fullPath
			end
		end
	end
	return nil
end

local function fetchWindUiRemote(relativePath)
	for _, base in ipairs(WINDUI_MIRROR_URLS) do
		local url = base .. relativePath
		local body = Core.httpGet(url)
		if windUiSourceValid(body) then
			return body, url
		end
	end
	return nil
end

local function patchSourceValid(body)
	return type(body) == "string"
		and #body > 400
		and (body:find("ARRREL_UI_VERSION", 1, true) ~= nil or body:find("ALLERAL_UI_VERSION", 1, true) ~= nil)
		and body:find("return function", 1, true) ~= nil
end

local function extractPatchVersion(body)
	if type(body) ~= "string" then
		return nil
	end
	return body:match('ARRREL_UI_VERSION%s*=%s*"([^"]+)"')
		or body:match('ALLERAL_UI_VERSION%s*=%s*"([^"]+)"')
end

local function expectedPatchVersion()
	return Core.ALLERAL_UI_VERSION or "2.0.4-alleral-v2"
end

local function patchVersionCurrent(body)
	local version = extractPatchVersion(body)
	return version ~= nil and version == expectedPatchVersion()
end

local function patchApplied(windUi)
	return type(windUi) == "table" and windUi._AlleralPatchComplete == true
end

local function bootstrapSourceValid(body)
	return type(body) == "string"
		and #body > 200
		and body:find("return function", 1, true) ~= nil
end

local function applyAlleralWindUiPatch(windUi)
	if type(windUi) ~= "table" or patchApplied(windUi) then
		return windUi
	end

	local loadStringFn = Core.loadStringFn()
	if type(loadStringFn) ~= "function" then
		return windUi
	end

	local function runPatchLoader(source, label)
		if not source then
			return false
		end
		local chunk, compileErr = loadStringFn(source, label)
		if not chunk then
			Core.logWarn("UI loader compile: " .. tostring(compileErr))
			return false
		end
		local ok, loader = pcall(chunk)
		if not ok or type(loader) ~= "function" then
			Core.logWarn("UI loader: " .. tostring(loader))
			return false
		end
		local applied, applyErr = pcall(loader, windUi)
		if not applied then
			Core.logWarn("UI patch: " .. tostring(applyErr))
			return false
		end
		return patchApplied(windUi)
	end

	local bootstrapSource, bootstrapPath

	for _, base in ipairs(WINDUI_MIRROR_URLS) do
		local body = Core.httpGet(base .. "bootstrap.lua")
		if bootstrapSourceValid(body) and runPatchLoader(body, "@Arrrel/bootstrap:remote") then
			return windUi
		end
	end

	bootstrapSource, bootstrapPath = readWindUiLocal("bootstrap.lua")
	if bootstrapSource and patchVersionCurrent(bootstrapSource) then
		if runPatchLoader(bootstrapSource, "@Arrrel/bootstrap:" .. tostring(bootstrapPath or "local")) then
			return windUi
		end
	end

	for _, patchName in ipairs({ WINDUI_PATCH_FILE, WINDUI_PATCH_FALLBACK }) do
		for _, base in ipairs(WINDUI_MIRROR_URLS) do
			local body = Core.httpGet(base .. patchName)
			if patchSourceValid(body) then
				local chunk, compileErr = loadStringFn(body, "@Arrrel/patch:remote:" .. patchName)
				if chunk then
					local ok, patchFn = pcall(chunk)
					if ok and type(patchFn) == "function" then
						pcall(patchFn, windUi)
						if patchApplied(windUi) then
							return windUi
						end
					end
				else
					Core.logWarn("UI patch compile: " .. tostring(compileErr))
				end
			end
		end
	end

	local patchSource, patchPath = readWindUiLocal(WINDUI_PATCH_FILE)
	if not patchSource then
		patchSource, patchPath = readWindUiLocal(WINDUI_PATCH_FALLBACK)
	end
	if patchSource and patchSourceValid(patchSource) and patchVersionCurrent(patchSource) then
		local chunk, compileErr = loadStringFn(patchSource, "@Arrrel/patch:" .. tostring(patchPath))
		if chunk then
			local ok, patchFn = pcall(chunk)
			if ok and type(patchFn) == "function" then
				pcall(patchFn, windUi)
				if patchApplied(windUi) then
					return windUi
				end
			end
		else
			Core.logWarn("UI patch compile: " .. tostring(compileErr))
		end
	end

	return windUi
end

local function loadWindUiModule()
	if ENV.Alleral_WindUiLastGood and type(ENV.Alleral_WindUiLastGood.CreateWindow) == "function" then
		local cache = ENV._AlleralWindUiCompileCache
		if cache and type(cache.module) == "table" then
			return applyAlleralWindUiPatch(cache.module)
		end
	end

	local localSource, localPath = readWindUiLocal(WINDUI_FILE)
	if localSource then
		local module, err = compileWindUiModule(localSource, "@WindUI/local:" .. localPath)
		if module then
			return applyAlleralWindUiPatch(module)
		end
		Core.logWarn("local Alleral UI failed (" .. tostring(localPath) .. "): " .. tostring(err))
	end
	local remoteSource, remoteUrl = fetchWindUiRemote(WINDUI_FILE)
	if remoteSource then
		local module, err = compileWindUiModule(remoteSource, "@WindUI/remote:" .. tostring(remoteUrl))
		if module then
			Core.say("Alleral UI pulled from " .. tostring(remoteUrl))
			return applyAlleralWindUiPatch(module)
		end
		Core.logWarn("remote WindUI failed: " .. tostring(err))
	end
	localSource = readWindUiLocal(WINDUI_FILE)
	if localSource then
		return applyAlleralWindUiPatch(compileWindUiModule(localSource, "@WindUI/local"))
	end
	return nil, "WindUI download failed for " .. WINDUI_FILE
end

local function listUiThemes(windUi)
	local names = {}
	if type(windUi) == "table" and type(windUi.GetThemes) == "function" then
		local ok, themes = pcall(function()
			return windUi:GetThemes()
		end)
		if ok and type(themes) == "table" then
			for name in pairs(themes) do
				table.insert(names, name)
			end
			table.sort(names)
		end
	end
	if #names == 0 then
		return {
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
			"Dark",
			"Light",
		}
	end
	return names
end

local function applyAlleralTheme(bundle)
	if type(bundle) ~= "table" then
		return
	end
	local windUi = bundle.WindUI or bundle.Library
	if type(windUi) ~= "table" or type(windUi.SetTheme) ~= "function" then
		return
	end
	pcall(function()
		windUi:SetTheme("Arrrel")
	end)
end

local function cacheUi(bundle)
	stampUi(bundle)
	ENV.Alleral_UI = bundle
	if getgenv then
		local g = getgenv()
		if type(g) == "table" then
			g.Alleral_UI = bundle
		end
	end
	return bundle
end

function Core.loadUi()
	local cached = ENV.Alleral_UI
	if uiOk(cached) then
		return cacheUi(cached)
	end
	ENV.Alleral_UI = nil

	local loadStringFn = Core.loadStringFn()
	if not loadStringFn then
		return nil, "loadstring unavailable"
	end

	local WindUI, libErr = loadWindUiModule()
	if not WindUI and ENV.Alleral_WindUiLastGood then
		WindUI = ENV.Alleral_WindUiLastGood
		libErr = nil
		Core.say("using cached Alleral UI")
	end
	if not WindUI then
		return nil, libErr or "Alleral UI missing"
	end

	ENV.Alleral_WindUiLastGood = WindUI

	Core.clearUiStateBindings()

	local bundle = {
		Alleral = WindUI,
		Library = WindUI,
		WindUI = WindUI,
		CreateWindow = function(_, settings)
			return Core.safeCall("UI:CreateWindow", function()
				return WindUI:CreateWindow(settings)
			end)
		end,
		Notify = function(_, info)
			Core.safeCall("UI:Notify", function()
				if type(info) == "table" then
					WindUI:Notify({
						Title = info.Title,
						Content = info.Content or info.Description or info.Text or "",
						Duration = info.Duration or info.Time or 4,
						Type = info.Type or info.Level,
						Icon = info.Icon,
					})
				else
					WindUI:Notify({
						Title = "Alleral",
						Content = tostring(info or ""),
						Duration = 4,
						Type = "info",
					})
				end
			end)
		end,
	}
	applyAlleralTheme(bundle)
	bundle.ThemeNames = listUiThemes(WindUI)
	if ENV.Alleral_UiReducedMotion == true and type(WindUI.SetReducedMotion) == "function" then
		WindUI:SetReducedMotion(true)
	end
	if ENV.Alleral_UiSpringMotion == false and type(WindUI.SetSpringMotion) == "function" then
		pcall(function()
			WindUI:SetSpringMotion(false)
		end)
	end
	if ENV.Alleral_UiStartup == false and type(WindUI.SetStartupEffect) == "function" then
		pcall(function()
			WindUI:SetStartupEffect(false)
		end)
	elseif ENV.Alleral_UiStartup == true and type(WindUI.SetStartupEffect) == "function" then
		pcall(function()
			WindUI:SetStartupEffect(true)
		end)
	end
	if ENV.Alleral_UiTouchFeedback == false and type(WindUI.SetTouchFeedback) == "function" then
		pcall(function()
			WindUI:SetTouchFeedback(false)
		end)
	end
	if ENV.Alleral_NotifyDedupe == false and type(WindUI.SetNotifyDedupe) == "function" then
		pcall(function()
			WindUI:SetNotifyDedupe(false)
		end)
	end
	if ENV.Alleral_NotifyLower == true and type(WindUI.SetNotificationLower) == "function" then
		pcall(function()
			WindUI:SetNotificationLower(true)
		end)
	end
	if ENV.Alleral_NotifyCompact == true and type(WindUI.SetNotificationCompact) == "function" then
		pcall(function()
			WindUI:SetNotificationCompact(true)
		end)
	end
	if type(WindUI.ApplyProfile) == "function" then
		pcall(function()
			WindUI:ApplyProfile(ENV.Alleral_UiProfile or "auto")
		end)
	end
	registerUiScaleHooks(WindUI)
	if ENV.Alleral_UiScale and type(WindUI.SetUiScale) == "function" then
		pcall(function()
			WindUI:SetUiScale(ENV.Alleral_UiScale)
		end)
	end
	if ENV.Alleral_UiHaptics == true and type(WindUI.SetHaptics) == "function" then
		pcall(function()
			WindUI:SetHaptics(true)
		end)
	end
	Core.say("Alleral " .. tostring(WindUI.GetArrrelVersion and WindUI:GetArrrelVersion() or WindUI.GetAlleralVersion and WindUI:GetAlleralVersion() or Core.ALLERAL_UI_VERSION) .. " loaded")
	task.defer(function()
		if type(WindUI.Preload) == "function" then
			pcall(function()
				WindUI:Preload()
			end)
		end
	end)
	return cacheUi(bundle)
end

function Core.preloadUi()
	local cached = ENV.Alleral_UI
	if uiOk(cached) then
		return cacheUi(cached)
	end
	if ENV._AlleralUiPreloadRunning == true then
		local started = tick()
		while ENV._AlleralUiPreloadRunning == true and tick() - started < 15 do
			task.wait()
		end
		cached = ENV.Alleral_UI
		if uiOk(cached) then
			return cacheUi(cached)
		end
	end
	ENV._AlleralUiPreloadRunning = true
	local bundle, err = Core.loadUi()
	ENV._AlleralUiPreloadRunning = false
	return bundle, err
end

function Core.httpGet(url)
	if type(url) ~= "string" or url == "" then
		return nil
	end

	local plain = url:gsub("%?.*$", "")
	local urls = {
		plain .. "?t=" .. tostring(tick()),
		plain,
		url,
	}

	local function accept(body)
		if type(body) ~= "string" or body == "" then
			return false
		end
		if #body <= 8192 and body:find("404: Not Found", 1, true) then
			return false
		end
		if body:find("<!DOCTYPE html>", 1, true) or body:find("<html", 1, true) then
			return body:find("function", 1, true) ~= nil or body:find("local ", 1, true) ~= nil
		end
		return true
	end

	local function extractBody(response)
		if type(response) == "string" then
			return response
		end
		if type(response) == "table" then
			return response.Body or response.body or response.Data or response.data
		end
		return nil
	end

	local function tryRequest(fn, fetchUrl)
		if type(fn) ~= "function" then
			return nil
		end
		local ok, direct = pcall(fn, fetchUrl)
		if ok and accept(direct) then
			return direct
		end
		if ok and type(direct) == "table" then
			local body = extractBody(direct)
			if accept(body) then
				return body
			end
		end
		for _, spec in ipairs({
			{
				Url = fetchUrl,
				Method = "GET",
				Headers = { ["Cache-Control"] = "no-cache" },
			},
			{
				url = fetchUrl,
				method = "GET",
				headers = { ["Cache-Control"] = "no-cache" },
			},
		}) do
			local rok, response = pcall(fn, spec)
			if rok then
				local body = extractBody(response)
				local status = type(response) == "table" and (response.StatusCode or response.status or response.Status or 200) or 200
				if accept(body) and (status == 0 or (status >= 200 and status < 300)) then
					return body
				end
			end
		end
		return nil
	end

	local bestBody, bestLen = nil, 0
	local function consider(body)
		if type(body) == "string" and accept(body) and #body > bestLen then
			bestBody, bestLen = body, #body
		end
	end

	for _, fetchUrl in ipairs(urls) do
		if type(game.HttpGet) == "function" then
			local ok, body = pcall(game.HttpGet, game, fetchUrl, true)
			consider(body)
			ok, body = pcall(game.HttpGet, game, fetchUrl)
			consider(body)
		end
		local ok, body = pcall(function()
			return game:HttpGet(fetchUrl, true)
		end)
		if ok then
			consider(body)
		end
		ok, body = pcall(function()
			return game:HttpGet(fetchUrl)
		end)
		if ok then
			consider(body)
		end
		if type(HttpService.GetAsync) == "function" then
			ok, body = pcall(function()
				return HttpService:GetAsync(fetchUrl, true)
			end)
			if ok then
				consider(body)
			end
		end
		consider(tryRequest(Core.requestFunction(), fetchUrl))
	end

	return bestBody
end

function Core.httpGetJson(url)
	local body = Core.httpGet(url)
	if not body then
		return nil, "HTTP unavailable"
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok or type(decoded) ~= "table" then
		return nil, "Invalid JSON response"
	end
	return decoded
end

function Core.httpPostJson(url, payload, headers)
	local sender = Core.requestFunction()
	if not sender then
		return nil, "HTTP unavailable"
	end
	local encoded = HttpService:JSONEncode(payload or {})
	local ok, response = pcall(function()
		return sender({
			Url = url,
			Method = "POST",
			Headers = headers or { ["Content-Type"] = "application/json" },
			Body = encoded,
		})
	end)
	if not ok then
		return nil, tostring(response)
	end
	local body = type(response) == "table" and (response.Body or response.body) or (type(response) == "string" and response)
	if type(body) == "string" and body ~= "" then
		local decodedOk, decoded = pcall(function()
			return HttpService:JSONDecode(body)
		end)
		if decodedOk and type(decoded) == "table" then
			return decoded
		end
	end
	local code = type(response) == "table" and (response.StatusCode or response.Status or response.status_code) or nil
	if type(code) == "number" and (code < 200 or code >= 300) then
		return nil, "HTTP " .. tostring(code)
	end
	return { ok = true }, nil
end

function Core.resolveRelayBase()
	local telemetry = ENV.Alleral_Telemetry
	if type(telemetry) == "table" and type(telemetry.GetConfig) == "function" then
		local ok, cfg = pcall(function()
			return telemetry:GetConfig()
		end)
		if ok and type(cfg) == "table" and cfg.relayUrl and cfg.relayUrl ~= "" then
			local base = tostring(cfg.relayUrl):gsub("/+$", ""):gsub("/ingest$", "")
			return base
		end
	end
	if ENV.Alleral_RelayUrl and tostring(ENV.Alleral_RelayUrl) ~= "" then
		return tostring(ENV.Alleral_RelayUrl):gsub("/+$", ""):gsub("/ingest$", "")
	end
	return "https://alleral-telemetry-production.up.railway.app"
end

function Core.uiLibrary(bundle)
	if type(bundle) ~= "table" then
		return nil
	end
	return bundle.Alleral or bundle.Library or bundle.WindUI
end

function Core.setClipboard(text)
	local clip = Core.execFunction("setclipboard") or Core.execFunction("toclipboard")
	if clip then
		pcall(clip, tostring(text or ""))
		return true
	end
	return false
end

function Core.windUiIcon(icon)
	if type(icon) == "number" then
		return "rbxassetid://" .. tostring(icon)
	end
	local numeric = Core.uiIcon(icon)
	if numeric ~= "" then
		return "rbxassetid://" .. numeric
	end
	if type(icon) == "string" and icon ~= "" and not icon:find("rbxassetid", 1, true) then
		return icon
	end
	return "circle"
end

local function windUiVisibilityTarget(label)
	if type(label) ~= "table" then
		return nil
	end
	local frame = label.ParagraphFrame or label
	if type(frame.UIElements) == "table" and frame.UIElements.Main then
		return frame.UIElements.Main
	end
	if label.Instance then
		return label.Instance
	end
	return nil
end

function Core.createWindUiGroupbox(rawGroup, uiBundle)
	rawGroup = rawGroup or {}
	uiBundle = uiBundle or {}
	local serial = 0
	local windUi = Core.uiLibrary(uiBundle)

	local function attachTooltip(handle, tooltip)
		if type(handle) ~= "table" or not tooltip or tostring(tooltip) == "" then
			return
		end
		if not handle.Desc and not handle.Description then
			handle.Desc = tostring(tooltip)
		end
		if not handle.Tooltip then
			handle.Tooltip = tostring(tooltip)
		end
		local function tryHook()
			if windUi and type(windUi.HookElementTooltip) == "function" then
				pcall(windUi.HookElementTooltip, windUi, handle)
			end
		end
		tryHook()
		task.spawn(function()
			for _ = 1, 20 do
				if handle._ArrrelTipHooked then
					return
				end
				tryHook()
				task.wait(0.05)
			end
		end)
	end

	local function nextFlag(name, explicit)
		serial += 1
		return explicit or Core.uiElementId(name) .. "_" .. serial
	end

	local function wrapElement(applySet, meta)
		meta = type(meta) == "table" and meta or {}
		local wrapper = {
			_raw = meta.raw,
			Set = function(_, settings)
				if type(settings) == "table" then
					applySet(settings)
				else
					applySet({ CurrentValue = settings })
				end
			end,
		}
		if meta.bindKey then
			Core.bindUiState(meta.bindKey, wrapper, meta.kind or "toggle", meta.raw)
		end
		return wrapper
	end

	local function dropdownDefault(values, current, multi)
		values = values or {}
		if multi then
			local selected = Core.normalizeMultiSelection(current)
			if #selected > 0 then
				return selected
			end
			return {}
		end
		if type(current) == "table" then
			return Core.normalizeDropdownValue(current, values[1])
		end
		if current and current ~= "" then
			return tostring(current)
		end
		return values[1]
	end

	local function labelVisibilityTarget(label)
		return windUiVisibilityTarget(label)
	end

	local function setElementValue(element, value)
		if not element then
			return
		end
		if element.Select then
			element:Select(value)
		elseif element.Set then
			element:Set(value)
		elseif element.SetValue then
			element:SetValue(value)
		end
	end

	local groupbox = {}

	function groupbox:CreateToggle(settings, id)
		if type(rawGroup.Toggle) ~= "function" then
			return wrapElement(function() end, { kind = "toggle" })
		end
		local handle
		handle = rawGroup:Toggle({
			Title = settings.Name,
			Value = settings.CurrentValue == true,
			Desc = settings.Tooltip,
			Callback = settings.Callback or function() end,
		})
		attachTooltip(handle, settings.Tooltip)
		task.defer(function()
			if handle and handle.ToggleFrame and handle.ToggleFrame.UIElements and handle.ToggleFrame.UIElements.Main then
				fixWrappedLabels(handle.ToggleFrame.UIElements.Main)
			end
		end)
		return wrapElement(function(nextSettings)
			if nextSettings.CurrentValue ~= nil then
				setElementValue(handle, nextSettings.CurrentValue == true)
			end
		end, {
			raw = handle,
			bindKey = settings.BindKey or settings.StateKey,
			kind = "toggle",
		})
	end

	function groupbox:CreateSlider(settings, id)
		if type(rawGroup.Slider) ~= "function" then
			return wrapElement(function() end, { kind = "slider" })
		end
		local range = settings.Range or { 0, 100 }
		local minValue, maxValue = range[1], range[2]
		local defaultValue = tonumber(settings.CurrentValue) or minValue
		local handle = rawGroup:Slider({
			Title = settings.Name,
			Desc = settings.Tooltip,
			Step = Core.sliderIncrement(minValue, maxValue, settings.Increment),
			Value = {
				Min = minValue,
				Max = maxValue,
				Default = defaultValue,
			},
			Callback = settings.Callback or function() end,
		})
		attachTooltip(handle, settings.Tooltip)
		return wrapElement(function(nextSettings)
			if nextSettings.CurrentValue ~= nil then
				setElementValue(handle, tonumber(nextSettings.CurrentValue) or minValue)
			end
		end, {
			raw = handle,
			bindKey = settings.BindKey or settings.StateKey,
			kind = "slider",
		})
	end

	function groupbox:CreateButton(settings, id)
		local handle = rawGroup:Button({
			Title = settings.Name,
			Desc = settings.Tooltip,
			Callback = settings.Callback or function() end,
		})
		attachTooltip(handle, settings.Tooltip)
		return { Set = function() end }
	end

	function groupbox:CreateInput(settings, id)
		local initialValue = tostring(settings.CurrentValue or settings.Default or "")
		local userCallback = settings.Callback or function() end
		local acceptInput = false
		local handle = rawGroup:Input({
			Title = settings.Name,
			Value = initialValue,
			Placeholder = settings.PlaceholderText or settings.Placeholder or "",
			Desc = settings.Tooltip,
			Callback = function(value)
				if not acceptInput then
					return
				end
				userCallback(value)
			end,
		})
		acceptInput = true
		attachTooltip(handle, settings.Tooltip)
		return wrapElement(function(nextSettings)
			if nextSettings.CurrentValue ~= nil then
				setElementValue(handle, tostring(nextSettings.CurrentValue))
			end
		end)
	end

	function groupbox:CreateDropdown(settings, id)
		local values = settings.Options or settings.Values or {}
		local multi = settings.MultipleOptions == true or settings.Multi == true
		local current = dropdownDefault(values, settings.CurrentOption, multi)
		local userCallback = settings.Callback or function() end
		local handle = rawGroup:Dropdown({
			Title = settings.Name,
			Values = values,
			Value = multi and current or current,
			Multi = multi,
			Desc = settings.Tooltip,
			Callback = function(selection)
				if multi then
					userCallback(Core.normalizeMultiSelection(selection))
				else
					userCallback(Core.normalizeDropdownValue(selection, current))
				end
			end,
		})
		attachTooltip(handle, settings.Tooltip)
		return wrapElement(function(nextSettings)
			if not handle then
				return
			end
			local nextValues = nextSettings.Options or nextSettings.Values
			if nextValues and handle.Refresh then
				handle:Refresh(nextValues)
			elseif nextValues and handle.SetValues then
				handle:SetValues(nextValues)
			end
			local pick = nextSettings.CurrentOption or nextSettings.CurrentOptions
			if pick == nil then
				return
			end
			if multi and type(pick) == "table" then
				local selected = {}
				for index, value in ipairs(pick) do
					table.insert(selected, tostring(value))
				end
				for key, value in pairs(pick) do
					if type(key) ~= "number" and value == true then
						table.insert(selected, tostring(key))
					end
				end
				setElementValue(handle, selected)
			else
				setElementValue(handle, type(pick) == "table" and pick[1] or pick)
			end
		end, {
			raw = handle,
			bindKey = settings.BindKey or settings.StateKey,
			kind = "dropdown",
		})
	end

	function groupbox:CreateLabel(settings, id)
		local text = type(settings) == "table" and (settings.Name or settings.Text) or tostring(settings or "")
		local label = rawGroup:Paragraph({
			Title = text,
		})
		local visibleTarget = labelVisibilityTarget(label)
		return {
			Set = function(_, nextSettings)
				local nextText = type(nextSettings) == "table" and (nextSettings.Name or nextSettings.Text)
					or tostring(nextSettings or "")
				if label and label.SetTitle then
					label:SetTitle(nextText)
				elseif label and label.Set then
					label:Set(nextText)
				end
			end,
			_windLabel = label,
			_visibleTarget = visibleTarget,
			TextLabel = visibleTarget,
		}
	end

	function groupbox:CreateDivider()
		if rawGroup.Space then
			rawGroup:Space()
		end
		return {}
	end

	return groupbox
end

function Core.createStubUiGroup(label)
	label = tostring(label or "Group")
	local stub = {
		_stub = true,
		_label = label,
	}
	local function noop()
		return stub
	end
	stub.CreateToggle = noop
	stub.CreateSlider = noop
	stub.CreateButton = noop
	stub.CreateDropdown = noop
	stub.CreateInput = noop
	stub.CreateLabel = noop
	stub.AddDropdown = noop
	stub.CreateStatus = function(_, fields)
		local status = { Labels = {}, LastValues = {}, Visible = true }
		for key, value in pairs(fields or {}) do
			status.LastValues[key] = tostring(value)
		end
		status.Update = function() end
		status.SetVisible = function() end
		return status
	end
	return stub
end

local function measureTabContentWidth(rawTab, window)
	if rawTab and rawTab.UIElements and rawTab.UIElements.ContainerFrame then
		local scroll = rawTab.UIElements.ContainerFrame
		local width = scroll.AbsoluteSize.X
		if width >= 64 then
			local pad = scroll:FindFirstChildOfClass("UIPadding")
			if pad then
				width = width - pad.PaddingLeft.Offset - pad.PaddingRight.Offset
			end
			return math.max(width, 64)
		end
	end
	local rawWindow = window and window._rawWindow
	if rawWindow and rawWindow.UIElements then
		local mainBar = rawWindow.UIElements.MainBar
		if mainBar and mainBar.AbsoluteSize.X >= 64 then
			local width = mainBar.AbsoluteSize.X
			local pad = mainBar:FindFirstChildOfClass("UIPadding")
			if pad then
				width = width - pad.PaddingLeft.Offset - pad.PaddingRight.Offset
			end
			return math.max(width - 8, 64)
		end
	end
	return 0
end

local function fixWrappedLabels(root)
	if not root then
		return
	end
	for _, desc in ipairs(root:GetDescendants()) do
		if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.TextWrapped then
			desc.TextWrapped = false
			desc.TextTruncate = Enum.TextTruncate.None
			if desc.AutomaticSize == Enum.AutomaticSize.XY then
				desc.AutomaticSize = Enum.AutomaticSize.Y
				desc.Size = UDim2.new(1, 0, 0, 0)
			elseif desc.Size.X.Scale == 0 and desc.Size.X.Offset == 0 then
				desc.Size = UDim2.new(1, 0, desc.Size.Y.Scale, desc.Size.Y.Offset)
			end
		end
	end
end

local COLUMN_GAP = 8
Core._UiTabRegistry = Core._UiTabRegistry or {}

local function relayoutTwoColumnFrames(tab)
	local layout = tab._layout
	if not layout or not layout.ready or not layout.row or not layout.left or not layout.right then
		return false
	end

	local width = layout.row.AbsoluteSize.X
	if width < 64 then
		width = measureTabContentWidth(tab._rawTab, tab._window)
	end
	if width < 64 then
		return false
	end

	layout.row.Size = UDim2.new(1, 0, 0, 0)
	layout.row.AutomaticSize = Enum.AutomaticSize.Y

	local colWidth = math.max(160, math.floor((width - COLUMN_GAP) / 2))
	local colSize = UDim2.new(0, colWidth, 0, 0)

	layout.left.Size = colSize
	layout.left.AutomaticSize = Enum.AutomaticSize.Y
	layout.right.Size = colSize
	layout.right.AutomaticSize = Enum.AutomaticSize.Y

	fixWrappedLabels(layout.row)
	fixWrappedLabels(layout.left)
	fixWrappedLabels(layout.right)
	return true
end

local function ensureTwoColumnLayout(tab, rawTab)
	if not rawTab or tab._columnCount < 2 then
		return false
	end

	tab._layout = tab._layout or {}
	local layout = tab._layout
	if layout.ready then
		return true
	end

	local container = rawTab.UIElements and rawTab.UIElements.ContainerFrame
	if not container then
		return false
	end

	local row = Instance.new("Frame")
	row.Name = "AlleralColumns"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.LayoutOrder = -1000
	row.Parent = container

	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Padding = UDim.new(0, COLUMN_GAP)
	rowList.Parent = row

	local function makeColumn(name, order)
		local col = Instance.new("Frame")
		col.Name = name
		col.BackgroundTransparency = 1
		col.Size = UDim2.new(0, 160, 0, 0)
		col.AutomaticSize = Enum.AutomaticSize.Y
		col.LayoutOrder = order
		col.Parent = row

		local vlist = Instance.new("UIListLayout")
		vlist.FillDirection = Enum.FillDirection.Vertical
		vlist.SortOrder = Enum.SortOrder.LayoutOrder
		vlist.Padding = UDim.new(0, 8)
		vlist.Parent = col
		return col
	end

	layout.row = row
	layout.left = makeColumn("LeftColumn", 1)
	layout.right = makeColumn("RightColumn", 2)
	layout.leftOrder = 0
	layout.rightOrder = 0
	layout.ready = true

	if not tab._columnRelayoutHooked then
		tab._columnRelayoutHooked = true
		pcall(function()
			row:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				if row.AbsoluteSize.X >= 64 then
					relayoutTwoColumnFrames(tab)
				end
			end)
		end)
		pcall(function()
			container:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				if container.AbsoluteSize.X >= 64 then
					relayoutTwoColumnFrames(tab)
				end
			end)
		end)
	end

	relayoutTwoColumnFrames(tab)
	return true
end

local function getColumnFrame(tab, column)
	local layout = tab._layout
	if not layout or not layout.ready then
		return nil
	end
	return (column == 2) and layout.right or layout.left
end

local function scheduleTwoColumnRelayout(tab)
	if type(tab) ~= "table" then
		return
	end

	local function tryRelayout()
		relayoutTwoColumnFrames(tab)
	end

	task.defer(tryRelayout)
	task.delay(0.05, tryRelayout)
	task.delay(0.15, tryRelayout)
	task.delay(0.35, tryRelayout)
end

function Core.refreshAllTabColumns()
	for _, tab in ipairs(Core._UiTabRegistry) do
		if type(tab) == "table" then
			relayoutTwoColumnFrames(tab)
		end
	end
	return true
end

local function registerUiScaleHooks(windUi)
	if type(windUi) ~= "table" or Core._UiScaleHooksRegistered then
		return
	end
	Core._UiScaleHooksRegistered = true
	if type(windUi.RegisterLayoutRefresh) == "function" then
		pcall(function()
			windUi:RegisterLayoutRefresh("core_columns", function()
				Core.refreshAllTabColumns()
			end)
		end)
	elseif windUi._AlleralScaleApi and type(windUi._AlleralScaleApi.registerLayoutRefresh) == "function" then
		pcall(function()
			windUi._AlleralScaleApi.registerLayoutRefresh("core_columns", function()
				Core.refreshAllTabColumns()
			end)
		end)
	end
end

function Core.wrapUiTab(rawTab, uiBundle, window)
	local tab = {
		_rawTab = rawTab,
		_ui = uiBundle,
		_window = window,
		_columnCount = 1,
	}
	table.insert(Core._UiTabRegistry, tab)

	local function resolveColumn(column)
		column = math.clamp(tonumber(column) or 1, 1, 2)
		if tab._columnCount >= 2 and rawTab then
			ensureTwoColumnLayout(tab, rawTab)
		end
		return column
	end

	function tab:CreateGroupbox(settings)
		settings = settings or {}
		local name = settings.Name or "Group"
		if not rawTab then
			Core.logWarn("CreateGroupbox skipped — tab missing for " .. tostring(name))
			return Core.createWindUiGroupbox({}, uiBundle)
		end
		if type(rawTab.Section) ~= "function" then
			Core.logWarn("CreateGroupbox skipped — Section unavailable for " .. tostring(name))
			return Core.createWindUiGroupbox({}, uiBundle)
		end

		local column = resolveColumn(settings.Column or 1)
		local ok, rawGroup = pcall(function()
			return rawTab:Section({
				Title = name,
				Box = true,
				BoxBorder = true,
				Opened = true,
			})
		end)
		if not ok or not rawGroup then
			Core.logWarn("CreateGroupbox Section failed for " .. tostring(name) .. ": " .. tostring(rawGroup))
			return Core.createWindUiGroupbox({}, uiBundle)
		end

		if tab._columnCount >= 2 then
			local colFrame = getColumnFrame(tab, column)
			local sectionFrame = rawGroup.ElementFrame
			if colFrame and sectionFrame and sectionFrame:IsA("GuiObject") then
				local layout = tab._layout
				if column == 2 then
					layout.rightOrder = (layout.rightOrder or 0) + 1
					sectionFrame.LayoutOrder = layout.rightOrder
				else
					layout.leftOrder = (layout.leftOrder or 0) + 1
					sectionFrame.LayoutOrder = layout.leftOrder
				end
				sectionFrame.Parent = colFrame
				sectionFrame.Size = UDim2.new(1, 0, 0, 0)
				if sectionFrame:IsA("Frame") then
					sectionFrame.AutomaticSize = Enum.AutomaticSize.Y
				end
				fixWrappedLabels(sectionFrame)
			end
		end

		task.defer(function()
			scheduleTwoColumnRelayout(tab)
			if rawGroup.UIElements and rawGroup.UIElements.Main then
				fixWrappedLabels(rawGroup.UIElements.Main)
			end
		end)
		return Core.createWindUiGroupbox(rawGroup, uiBundle)
	end

	function tab:BuildThemeGroupbox(column)
		local group = Core.buildUiGroup(tab, "Appearance", column or 1)
		local windUi = uiBundle and (uiBundle.WindUI or uiBundle.Library)
		local themes = (uiBundle and uiBundle.ThemeNames) or {
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
			"Dark",
			"Light",
		}
		if windUi and type(windUi.ListThemeNames) == "function" then
			local ok, listed = pcall(function()
				return windUi:ListThemeNames()
			end)
			if ok and type(listed) == "table" and #listed > 0 then
				themes = listed
			end
		end
		local current = "Arrrel"
		if windUi and type(windUi.GetCurrentTheme) == "function" then
			local ok, theme = pcall(function()
				return windUi:GetCurrentTheme()
			end)
			if ok and theme then
				current = theme
			end
		end
		group:CreateDropdown("Theme preset", themes, current, function(selected)
			if windUi and type(windUi.SetTheme) == "function" then
				pcall(function()
					windUi:SetTheme(selected)
					if type(windUi.FlashAccent) == "function" then
						windUi:FlashAccent()
					end
				end)
			end
			Core.notify("Theme", "theme: " .. tostring(selected), 2, "success")
		end, "Choose a color preset.")
		group:CreateButton("Next theme", function()
			if windUi and type(windUi.CycleTheme) == "function" then
				local ok, nextTheme = pcall(function()
					return windUi:CycleTheme(1)
				end)
				if ok and nextTheme and nextTheme.Name then
					Core.notify("Theme", "Applied " .. tostring(nextTheme.Name), 2, "success")
				end
			end
		end, "Cycles through available presets.")

		local accentPresets = { "Mint", "Cyan", "Violet", "Rose", "Amber", "Ice", "Aurora", "Crimson", "Lime", "Sky", "Gold", "Plum", "Teal", "Blaze", "Mono" }
		group:CreateDropdown("Accent color", accentPresets, "Mint", function(selected)
			if windUi and type(windUi.ApplyAccentPreset) == "function" then
				pcall(function()
					windUi:ApplyAccentPreset(selected)
					if type(windUi.FlashAccent) == "function" then
						windUi:FlashAccent()
					end
				end)
			elseif windUi and type(windUi.SetAccentColor) == "function" then
				local hex = ({
					Mint = "#53fc18",
					Cyan = "#22d3ee",
					Violet = "#a78bfa",
					Rose = "#fb7185",
					Amber = "#fbbf24",
					Ice = "#93c5fd",
					Aurora = "#7cf7ff",
				})[selected] or "#53fc18"
				pcall(function()
					windUi:SetAccentColor(Color3.fromHex(hex))
					if type(windUi.FlashAccent) == "function" then
						windUi:FlashAccent()
					end
				end)
			end
		end, "Accent for toggles and highlights.")

		local profileNames = { "auto", "desktop", "mobile", "compact", "performance" }
		local profileLabels = {
			auto = "Auto",
			desktop = "Desktop",
			mobile = "Mobile",
			compact = "Compact",
			performance = "Performance",
		}
		local currentProfile = ENV.Alleral_UiProfile or "auto"
		group:CreateDropdown("Layout profile", profileNames, currentProfile, function(selected)
			ENV.Alleral_UiProfile = selected
			if windUi and type(windUi.ApplyProfile) == "function" then
				pcall(function()
					windUi:ApplyProfile(selected)
				end)
			end
			Core.notify("UI", "Profile: " .. tostring(profileLabels[selected] or selected), 2, "info")
		end, "Auto picks mobile or desktop from your device.")

		group:CreateSlider("UI scale", 0.85, 1.1, tonumber(ENV.Alleral_UiScale) or 1, function(value)
			ENV.Alleral_UiScale = value
			if windUi and type(windUi.SetUiScale) == "function" then
				pcall(function()
					windUi:SetUiScale(value)
				end)
			end
		end, "Shrink or enlarge the whole menu.")

		group:CreateToggle("Reduced motion", ENV.Alleral_UiReducedMotion == true, "Disables animations.", function(value)
			ENV.Alleral_UiReducedMotion = value == true
			if windUi and type(windUi.SetReducedMotion) == "function" then
				pcall(function()
					windUi:SetReducedMotion(value == true)
				end)
			end
		end)

		group:CreateToggle("Spring motion", ENV.Alleral_UiSpringMotion ~= false, "Springs on menus and controls.", function(value)
			ENV.Alleral_UiSpringMotion = value ~= false
			if windUi and type(windUi.SetSpringMotion) == "function" then
				pcall(function()
					windUi:SetSpringMotion(value ~= false)
				end)
			end
		end)

		group:CreateToggle("Startup animation", ENV.Alleral_UiStartup ~= false, "Opening sweep when the menu loads.", function(value)
			ENV.Alleral_UiStartup = value ~= false
			if windUi and type(windUi.SetStartupEffect) == "function" then
				pcall(function()
					windUi:SetStartupEffect(value ~= false)
				end)
			end
		end)

		group:CreateToggle("Compact notifications", ENV.Alleral_NotifyCompact == true, "Tighter toast stack.", function(value)
			ENV.Alleral_NotifyCompact = value == true
			if windUi and type(windUi.SetNotificationCompact) == "function" then
				pcall(function()
					windUi:SetNotificationCompact(value == true)
				end)
			end
		end)

		group:CreateToggle("Touch feedback", ENV.Alleral_UiTouchFeedback ~= false, "Button press scale on click.", function(value)
			ENV.Alleral_UiTouchFeedback = value ~= false
			if windUi and type(windUi.SetTouchFeedback) == "function" then
				pcall(function()
					windUi:SetTouchFeedback(value ~= false)
				end)
			end
		end)

		group:CreateToggle("Haptics", ENV.Alleral_UiHaptics == true, "Light vibration on toggles (mobile).", function(value)
			ENV.Alleral_UiHaptics = value == true
			if windUi and type(windUi.SetHaptics) == "function" then
				pcall(function()
					windUi:SetHaptics(value == true)
				end)
			end
		end)

		group:CreateToggle("Dedupe notifications", ENV.Alleral_NotifyDedupe ~= false, "Skip identical toasts within 2s.", function(value)
			ENV.Alleral_NotifyDedupe = value ~= false
			if windUi and type(windUi.SetNotifyDedupe) == "function" then
				pcall(function()
					windUi:SetNotifyDedupe(value ~= false)
				end)
			end
		end)

		return group
	end

	return tab
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
	for _, path in ipairs({ "hub/core_base.luau", "hub/core.luau", "core/alleral_core.luau", "src/alleral_core.luau", "alleral_core.luau" }) do
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
	local security = ENV.Alleral_Security
	if type(security) == "table" and type(security.enforce) == "function" then
		local ok, reason = security.enforce({ stage = "prepareGame" })
		if not ok then
			local msg = tostring(reason or "Access denied")
			signalBootFailure(msg)
			return nil, nil, msg
		end
	end
	local core = Core.ensureCore()
	if not core then
		local msg = "Core not loaded"
		signalBootFailure(msg)
		return nil, nil, msg
	end
	for _, fnName in ipairs({ "buildUiWindow", "buildUiTab", "buildUiGroup", "wrapUiGroup", "createWindUiGroupbox" }) do
		if type(core[fnName]) ~= "function" then
			local msg = "Core outdated — missing " .. fnName
			signalBootFailure(msg)
			return nil, nil, msg
		end
	end
	state.HubRunning = true
	core.initAnalytics()
	core.installErrorLogHook()
	if state.AntiAFK ~= false then
		core.setupAntiAfk(game:GetService("Players").LocalPlayer)
	end
	local cachedUi = ENV.Alleral_UI
	local uiLibrary = type(cachedUi) == "table" and type(cachedUi.Library) == "table" and cachedUi or nil
	local err
	if not uiLibrary then
		uiLibrary, err = core.loadUi()
	end
	if not uiLibrary then
		task.wait(0.2)
		uiLibrary, err = core.loadUi()
	end
	if not uiLibrary then
		local msg = err or "UI unavailable"
		signalBootFailure(msg)
		return nil, nil, msg
	end
	pcall(function()
		if core.refreshLoaderCapabilities then
			core.refreshLoaderCapabilities()
		end
		if core.fetchScriptManifest then
			core.fetchScriptManifest(false)
		end
		if core.fetchWeaoExploits then
			task.spawn(function()
				core.fetchWeaoExploits(false)
				if core.refreshLoaderCapabilities then
					core.refreshLoaderCapabilities()
				end
			end)
		end
		if core.notifyExecutorCompat then
			core.notifyExecutorCompat()
		end
	end)
	if type(ENV._Alleral_EnsureTeleportWatch) == "function" then
		pcall(ENV._Alleral_EnsureTeleportWatch)
	end
	return core, uiLibrary
end

function Core.wireTeleportRelaunch(state)
	state = state or ENV.Alleral_State
	if state then
		state.HubRunning = true
	end
	if type(ENV._Alleral_EnsureTeleportWatch) == "function" then
		pcall(ENV._Alleral_EnsureTeleportWatch)
	end
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

function Core.copyValue(value)
	if type(value) ~= "table" then
		return value
	end
	local output = {}
	for key, item in pairs(value) do
		output[key] = Core.copyValue(item)
	end
	return output
end

function Core.mergeDefaults(state, defaults)
	for key, value in pairs(defaults or {}) do
		if state[key] == nil then
			state[key] = Core.copyValue(value)
		end
	end
end

function Core.buildSavedKeys(defaults, exclude)
	exclude = exclude or { HubRunning = true }
	local keys = {}
	for key in pairs(defaults or {}) do
		if not exclude[key] then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

function Core.initSettings(state, defaults, filename, exclude)
	Core.mergeDefaults(state, defaults)
	local savedKeys = Core.buildSavedKeys(defaults, exclude)
	Core.loadSettings(state, savedKeys, filename, defaults)
	local function saveSettings()
		return Core.saveSettings(state, savedKeys, filename)
	end
	return saveSettings, savedKeys
end

function Core.saveSettings(state, keys, filename)
	local payload = {}
	for _, key in ipairs(keys) do
		payload[key] = state[key]
	end
	local encodeOk, json = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if not encodeOk or type(json) ~= "string" or json == "" then
		Core.notify("Alleral", "Couldn't encode settings — nothing saved.", 5)
		return false
	end
	Core.backupSettings(filename, json)
	local target = "Alleral_Configs/" .. filename
	local previous = Core.readFile(target)
	local ok = Core.writeFile(target, json)
	if not ok and previous then
		pcall(function()
			Core.writeFile(target, previous)
		end)
		Core.notify("Alleral", "Save failed — restored previous settings file.", 5)
		return false
	end
	if not ok then
		Core.notify("Alleral", "Couldn't save settings. Your executor may not support writefile.", 5)
	end
	return ok
end

function Core.loadSettings(state, keys, filename, defaults)
	local target = "Alleral_Configs/" .. filename
	local raw = Core.readFile(target)
	if not raw then
		return false
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(decoded) ~= "table" then
		if Core.restoreSettingsFromBackup(filename, state, keys, defaults) then
			Core.notify("Alleral", "settings were busted — loaded a backup", 5)
			return true
		end
		return false
	end
	for _, key in ipairs(keys) do
		if decoded[key] ~= nil then
			state[key] = Core.copyValue(decoded[key])
		end
	end
	return true
end

function Core.wrapUiGroup(groupbox, callbackWrapper)
	local group = {}
	local serial = 0
	local MAX_RENDERED_DROPDOWN_OPTIONS = 50

	local function nextId(name)
		serial += 1
		return tostring(name) .. "_" .. HttpService:GenerateGUID(false):sub(1, 8) .. "_" .. serial
	end

	local function wrap(label, callback)
		callback = callback or function() end
		local function guarded(...)
			local ok, err = pcall(callback, ...)
			if not ok then
				Core.pushErrorLog("UI:" .. tostring(label), err)
				Core.reportError("UI:" .. tostring(label), err)
				warn("[Alleral UI:" .. tostring(label) .. "] " .. tostring(err))
			end
		end
		if not callbackWrapper then
			return guarded
		end
		for _, args in ipairs({ { label, guarded }, { guarded } }) do
			local ok, wrapped = pcall(callbackWrapper, table.unpack(args))
			if ok and type(wrapped) == "function" then
				return function(...)
					local innerOk, innerErr = pcall(wrapped, ...)
					if not innerOk then
						Core.pushErrorLog("UI:" .. tostring(label), innerErr)
						Core.reportError("UI:" .. tostring(label), innerErr)
					end
				end
			end
		end
		return guarded
	end

	local function normalizeOptions(values)
		local output = {}
		local seen = {}
		for _, value in ipairs(values or {}) do
			local text = tostring(value)
			if text ~= "" and not seen[text] then
				seen[text] = true
				table.insert(output, text)
			end
		end
		return output
	end

	local function currentSelection(default, multi)
		if type(default) == "table" then
			local copy = {}
			for i, v in ipairs(default) do
				copy[i] = v
			end
			for k, v in pairs(default) do
				if type(k) ~= "number" then
					copy[k] = v
				end
			end
			return copy
		end
		if multi then
			return default and { tostring(default) } or {}
		end
		return tostring(default or "")
	end

	local function compactOptions(values, selected, limit)
		values = normalizeOptions(values)
		limit = limit or MAX_RENDERED_DROPDOWN_OPTIONS
		if #values <= limit then
			return values
		end
		local output = {}
		local seen = {}
		local selectedList = type(selected) == "table" and selected or { selected }
		for _, value in ipairs(selectedList) do
			local text = tostring(value)
			if text ~= "" and not seen[text] then
				seen[text] = true
				table.insert(output, text)
			end
		end
		for _, value in ipairs(values) do
			if #output >= limit then
				break
			end
			if not seen[value] then
				table.insert(output, value)
			end
		end
		return output
	end

	local function instanceHasChild(parent, childName)
		if type(parent) ~= "table" or type(parent.FindFirstChild) ~= "function" then
			return false
		end
		return parent:FindFirstChild(childName) ~= nil
	end

	local function waitForElement(element, timeout)
		local started = tick()
		repeat
			if element and (element._visibleTarget or element.TextLabel or element._windLabel) then
				return true
			end
			task.wait()
		until tick() - started >= (timeout or 3)
		return element and (element._visibleTarget or element.TextLabel or element._windLabel) ~= nil
	end

	local function setVisible(element, visible)
		if not element then
			return
		end
		local target = element._visibleTarget or element.TextLabel
		if target and target.Visible ~= nil then
			target.Visible = visible
			return
		end
		if element._windLabel then
			local fallback = windUiVisibilityTarget(element._windLabel)
			if fallback and fallback.Visible ~= nil then
				fallback.Visible = visible
			end
		end
	end

	function group:CreateToggle(name, default, tooltip, callback, bindKey)
		return groupbox:CreateToggle({
			Name = name,
			CurrentValue = default == true,
			Tooltip = tooltip,
			Callback = wrap(name, callback),
			BindKey = bindKey,
		}, nextId(name))
	end

	function group:CreateSlider(name, min, max, default, callback, tooltip, increment, bindKey)
		return groupbox:CreateSlider({
			Name = name,
			Range = { min, max },
			Increment = increment,
			CurrentValue = tonumber(default) or min,
			Tooltip = tooltip,
			Callback = wrap(name, callback),
			BindKey = bindKey,
		}, nextId(name))
	end

	function group:CreateButton(name, callback, tooltip)
		return groupbox:CreateButton({
			Name = name,
			Tooltip = tooltip,
			Callback = wrap(name, callback),
		}, nextId(name))
	end

	function group:CreateInput(name, placeholder, arg3, arg4, arg5)
		local icon, default, callback, tip
		local function isIcon(value)
			local text = tostring(value or "")
			return text:find("rbxassetid") ~= nil or text:match("^%d+$") ~= nil
		end
		if type(arg3) == "function" then
			callback = arg3
			tip = arg4
		elseif type(arg4) == "function" and isIcon(arg3) then
			icon = Core.uiIcon(arg3)
			callback = arg4
			tip = arg5
		elseif type(arg4) == "function" then
			default = tostring(arg3 or "")
			callback = arg4
			tip = arg5
		else
			icon = Core.uiIcon(arg3)
			callback = arg4
			tip = arg5
		end
		return groupbox:CreateInput({
			Name = name,
			Icon = icon,
			Placeholder = placeholder,
			PlaceholderText = placeholder,
			CurrentValue = default or "",
			RemoveTextOnFocus = false,
			Tooltip = tip,
			Callback = wrap(name, callback),
		}, nextId(name))
	end

	function group:CreateDropdown(name, options, default, callback, tooltip, bindKey)
		return groupbox:CreateDropdown({
			Name = name,
			Options = normalizeOptions(options),
			CurrentOption = default,
			Tooltip = tooltip,
			Callback = wrap(name, callback),
			BindKey = bindKey,
		}, nextId(name))
	end

	function group:AddDropdown(id, config)
		config = config or {}
		local multi = config.Multi == true or config.MultiSelection == true
		local values = normalizeOptions(config.Values or config.Options)
		local current = currentSelection(config.Default or config.CurrentValue or config.CurrentOption, multi)
		local handle = {
			Values = values,
			Selection = current,
			Dropdown = nil,
			LastSearch = "",
		}
		local function safeCallback(selection)
			local normalized = multi and Core.normalizeMultiSelection(selection)
				or Core.normalizeDropdownValue(selection, current)
			handle.Selection = multi and normalized or currentSelection(normalized, false)
			wrap(config.Text or config.Name or id, config.Callback or function() end)(normalized)
		end
		local function rebuild(currentValues)
			local nextValues = currentValues or handle.Values
			if config.Searchable then
				nextValues = compactOptions(nextValues, handle.Selection)
			end
			if handle.Dropdown and handle.Dropdown.Set then
				handle.Dropdown:Set({
					Options = nextValues,
					Values = nextValues,
					CurrentOption = handle.Selection,
					CurrentOptions = type(handle.Selection) == "table" and handle.Selection or nil,
					MultipleOptions = multi,
					Placeholder = config.Placeholder or "--",
					Callback = safeCallback,
				})
			end
		end
		local renderedValues = config.Searchable and compactOptions(values, current) or values
		local dropdown = groupbox:CreateDropdown({
			Name = config.Text or config.Name or id,
			Options = renderedValues,
			Values = renderedValues,
			CurrentOption = current,
			MultipleOptions = multi,
			Callback = safeCallback,
		}, nextId(id .. "_dd"))
		handle.Dropdown = dropdown
		function handle:SetValues(newValues, newDefault)
			self.Values = normalizeOptions(newValues)
			self.Selection = currentSelection(newDefault or self.Selection, multi)
			rebuild(self.Values)
		end
		function handle:Refresh(newValues, newDefault)
			self:SetValues(newValues, newDefault)
		end
		function handle:Search(query)
			self.LastSearch = tostring(query or "")
			local filtered = self.LastSearch == "" and self.Values
				or compactOptions(Core.filterDropdownOptions(self.Values, self.LastSearch), self.Selection)
			rebuild(filtered)
		end
		if config.Searchable then
			groupbox:CreateInput({
				Name = (config.Text or config.Name or id) .. " filter",
				PlaceholderText = "search...",
				RemoveTextOnFocus = false,
				Callback = wrap((config.Text or config.Name or id) .. " Search", function(text)
					handle:Search(text)
				end),
			}, nextId(id .. "_search"))
		end
		return handle
	end

	function group:CreateLabel(text)
		return groupbox:CreateLabel({
			Name = text,
		}, nextId("label"))
	end

	function group:CreateStatus(label, fields)
		local status = {
			Labels = {},
			LastValues = {},
			Visible = true,
		}
		for key, value in pairs(fields or {}) do
			local rendered = tostring(value)
			status.LastValues[key] = rendered
			status.Labels[key] = groupbox:CreateLabel({
				Name = tostring(key) .. ": " .. rendered,
			}, nextId(label .. "_" .. tostring(key)))
		end
		status.Labels.Summary = groupbox:CreateLabel({
			Name = "",
		}, nextId(label .. "_summary"))
		function status:Update(key, value)
			local rendered = tostring(value)
			if self.LastValues[key] == rendered then
				return
			end
			self.LastValues[key] = rendered
			local row = self.Labels[key]
			if row and row.Set then
				row:Set({ Name = tostring(key) .. ": " .. rendered })
			end
		end
		function status:SetSummary(text)
			local row = self.Labels.Summary
			if row and row.Set then
				row:Set({ Name = tostring(text or "") })
			end
		end
		function status:SetVisible(visible)
			self.Visible = visible
			for _, row in pairs(self.Labels) do
				setVisible(row, visible)
			end
		end
		return status
	end

	function group:CreateDivider()
		return groupbox:CreateDivider()
	end

	return group
end

function Core.dropdownEntryText(value)
	if type(value) == "table" then
		return tostring(value.Title or value.Name or value.Text or value[1] or "")
	end
	return tostring(value or "")
end

function Core.normalizeMultiSelection(selection)
	local picked = {}
	if type(selection) == "string" then
		if selection ~= "" then
			table.insert(picked, selection)
		end
		return picked
	end
	if type(selection) ~= "table" then
		return picked
	end
	local hasBooleanMap = false
	for key, value in pairs(selection) do
		if type(key) ~= "number" and type(value) == "boolean" then
			hasBooleanMap = true
			break
		end
	end
	if hasBooleanMap then
		for item, enabled in pairs(selection) do
			if type(item) == "number" then
				if enabled ~= nil and enabled ~= false then
					local text = Core.dropdownEntryText(enabled)
					if text ~= "" then
						table.insert(picked, text)
					end
				end
			elseif enabled then
				local text = Core.dropdownEntryText(item)
				if text ~= "" then
					table.insert(picked, text)
				end
			end
		end
		return picked
	end
	for _, value in ipairs(selection) do
		local text = Core.dropdownEntryText(value)
		if text ~= "" then
			table.insert(picked, text)
		end
	end
	if #picked == 0 then
		for key, value in pairs(selection) do
			if type(key) ~= "number" and value == true then
				local text = Core.dropdownEntryText(key)
				if text ~= "" then
					table.insert(picked, text)
				end
			end
		end
	end
	return picked
end

function Core.normalizeDropdownValue(selection, fallback)
	if type(selection) == "table" then
		local text = Core.dropdownEntryText(selection)
		if text ~= "" then
			return text
		end
		if selection[1] ~= nil then
			return Core.normalizeDropdownValue(selection[1], fallback)
		end
	elseif type(selection) == "string" or type(selection) == "number" or type(selection) == "boolean" then
		return tostring(selection)
	end
	return fallback
end

function Core.selectionFirst(selection, fallback)
	local items = Core.normalizeMultiSelection(selection)
	if items[1] and items[1] ~= "" then
		return items[1]
	end
	return fallback or ""
end

function Core.listContains(selection, value)
	local list = Core.normalizeMultiSelection(selection)
	if #list == 0 then
		return false
	end
	return table.find(list, value) ~= nil
end

function Core.listMatches(selection, value)
	local list = Core.normalizeMultiSelection(selection)
	if #list == 0 then
		return true
	end
	if Core.listContains(list, "Any") or Core.listContains(list, "All") or Core.listContains(list, "any") then
		return true
	end
	return Core.listContains(list, value)
end

function Core.uiIcon(icon)
	return tostring(icon or ""):match("%d+$") or ""
end

function Core.uiElementId(text)
	return (tostring(text or "Element"):gsub("[^%w_]", "_"))
end

function Core.hasPremiumAccess()
	if getgenv().JD_IS_PREMIUM == true then
		return true
	end
	local access = ENV.Alleral_Access
	if type(access) == "table" and type(access.isPremium) == "function" then
		return access.isPremium() == true
	end
	return true
end

function Core.accessMode()
	local access = ENV.Alleral_Access
	if type(access) == "table" and type(access.mode) == "function" then
		return access.mode()
	end
	return "public"
end

function Core.gameUiSettings(options)
	options = type(options) == "table" and options or {}
	local fileSettings = type(options.FileSettings) == "table" and options.FileSettings or {}
	return {
		Name = options.Name or "Alleral",
		Subtitle = options.Subtitle,
		Icon = options.Icon or "sparkles",
		FileSettings = {
			RootFolder = fileSettings.RootFolder or "Alleral_Configs",
			ConfigFolder = fileSettings.ConfigFolder or options.configFolder or "Interface",
		},
	}
end

function Core.settingsExtrasOptions(window, ui, state, savedKeys, saveFn, settingsFile, version, extra)
	extra = type(extra) == "table" and extra or {}
	return {
		state = state,
		savedKeys = savedKeys,
		saveFn = saveFn,
		settingsFile = settingsFile,
		settingsPath = extra.settingsPath,
		version = version,
		window = window,
		uiBundle = ui,
		gameId = extra.gameId,
		scriptId = extra.scriptId,
		onApply = extra.onApply,
		cloudOnlyTab = extra.cloudOnlyTab,
		skipCloudConfig = extra.skipCloudConfig,
		skipHubActions = extra.skipHubActions,
		skipScriptStatus = extra.skipScriptStatus,
	}
end

function Core.finalizeGameUi(window, ui, options)
	options = type(options) == "table" and options or {}
	if type(window) == "table" and window._rawWindow then
		Core.registerUiWindow(window)
		task.defer(function()
			Core.repairUiWindow(window)
			local windUi = ui and (ui.WindUI or ui.Library)
			if type(ENV.Alleral_UiCustomization) == "table" and windUi and type(windUi.ImportCustomization) == "function" then
				pcall(function()
					windUi:ImportCustomization(ENV.Alleral_UiCustomization)
				end)
			end
		end)
	end
	if options.notify ~= false then
		Core.notifyBootReady({
			Name = options.Name or "Alleral",
			Subtitle = options.Subtitle,
		})
	end
	return window
end

function Core.buildUiWindow(ui, settings)
	settings = settings or {}
	local lib = ui and (ui.WindUI or ui.Library)
	if not lib then
		return nil
	end
	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer
	local playerLabel = lp and ((lp.DisplayName ~= "" and lp.DisplayName) or lp.Name) or ""
	local windowSettings = {
		Title = settings.Name or "Alleral",
		Author = settings.Subtitle or playerLabel,
		Folder = (settings.FileSettings or {}).RootFolder or (settings.FileSettings or {}).ConfigFolder or "Alleral_Configs",
		Icon = Core.windUiIcon(settings.Icon or "sparkles"),
		Theme = "Arrrel",
		NewElements = true,
		HideSearchBar = false,
		AutoScale = true,
		UICorner = 12,
		UIPadding = 24,
		SideBarWidth = 280,
		ElementPadding = 16,
		Resizable = true,
		OpenButton = {
			Title = "Alleral",
			Enabled = true,
			Draggable = true,
			OnlyMobile = false,
			Color = ColorSequence.new(ALLERAL_ACCENT, ALLERAL_ACCENT_ALT),
		},
	}
	local rawWindow = lib:CreateWindow(windowSettings)
	if not rawWindow and type(lib.ReleaseWindow) == "function" then
		pcall(function()
			lib:ReleaseWindow(lib.Window)
		end)
		task.wait(0.05)
		rawWindow = lib:CreateWindow(windowSettings)
	end
	if not rawWindow then
		Core.logWarn("Alleral window create failed")
		return nil
	end
	applyAlleralTheme(ui)
	local window = {
		_rawWindow = rawWindow,
		_ui = ui,
		_library = lib,
		_windSection = nil,
	}
	Core.registerUiWindow(window)
	Core.flushPendingNotifications()
	registerUiScaleHooks(lib)
	task.defer(function()
		Core.repairUiWindow(window)
		if type(lib.RefreshViewportScale) == "function" then
			pcall(function()
				lib:RefreshViewportScale(window._rawWindow)
			end)
		end
	end)
	function window:AddTab(name, icon)
		if not self._rawWindow or type(self._rawWindow.Tab) ~= "function" then
			Core.logWarn("AddTab skipped — window missing")
			return nil
		end
		return self._rawWindow:Tab({
			Title = name,
			Icon = Core.windUiIcon(icon),
			Border = true,
		})
	end
	window._ui = ui
	window._library = lib
	return window
end

function Core.buildUiSection(window)
	return {
		_window = window,
		_ui = window._ui,
	}
end

function Core.buildUiTab(section, name, icon, columns, id)
	local window = section._window or section
	if not window or not window._rawWindow then
		Core.logWarn("buildUiTab skipped — window missing")
		return Core.wrapUiTab(nil, section._ui, window)
	end
	local iconArg = nil
	if icon then
		local numeric = tonumber(Core.uiIcon(icon))
		if numeric then
			iconArg = numeric
		elseif type(icon) == "string" and icon ~= "" and not icon:find("rbxassetid", 1, true) then
			iconArg = icon
		end
	end
	local rawTab
	if iconArg then
		rawTab = window:AddTab(name, iconArg)
	else
		rawTab = window:AddTab(name)
	end
	if not rawTab then
		Core.logWarn("buildUiTab AddTab failed for " .. tostring(name))
	end
	local wrapped = Core.wrapUiTab(rawTab, window._ui or section._ui, window)
	local requested = math.max(1, tonumber(columns) or 1)
	if requested >= 2 then
		local camera = workspace.CurrentCamera
		if camera then
			local shortSide = math.min(camera.ViewportSize.X, camera.ViewportSize.Y)
			if shortSide <= 900 then
				requested = 1
			end
		end
	end
	wrapped._columnCount = requested
	return wrapped
end

function Core.onUiSave(saveFn)
	return function(_, callback)
		return function(...)
			local result = callback(...)
			if type(saveFn) == "function" then
				saveFn()
			end
			return result
		end
	end
end

function Core.buildUiGroup(tab, name, column, callbackWrapper, icon, id)
	name = tostring(name or "Group")
	if type(tab) ~= "table" or type(tab.CreateGroupbox) ~= "function" then
		Core.logWarn("buildUiGroup skipped — tab missing for " .. name)
		return Core.createStubUiGroup(name)
	end
	local ok, groupbox = pcall(function()
		return tab:CreateGroupbox({
			Name = name,
			Column = column or 1,
			Icon = icon and Core.uiIcon(icon) or nil,
		}, id or Core.uiElementId(name))
	end)
	if not ok or not groupbox then
		Core.logWarn("buildUiGroup CreateGroupbox failed for " .. name .. ": " .. tostring(groupbox))
		return Core.createStubUiGroup(name)
	end
	if type(Core.wrapUiGroup) ~= "function" then
		Core.logWarn("wrapUiGroup missing — returning stub for " .. name)
		return Core.createStubUiGroup(name)
	end
	if callbackWrapper then
		return Core.wrapUiGroup(groupbox, callbackWrapper)
	end
	return Core.wrapUiGroup(groupbox)
end

function Core.filterDropdownOptions(values, query)
	query = tostring(query or ""):lower()
	if query == "" then
		return values
	end
	local filtered = {}
	for _, value in ipairs(values or {}) do
		if tostring(value):lower():find(query, 1, true) then
			table.insert(filtered, value)
		end
	end
	return filtered
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

end
