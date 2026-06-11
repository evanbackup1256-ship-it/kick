--[[
	Alleral / WindUI unified scale runtime
	Based on Footagesus WindUI AutoScale (MIT) ? 40px viewport margin via SetUIScale
	https://github.com/Footagesus/WindUI
	https://footagesus.github.io/WindUI-Docs/docs/configuration/window
]]

return function(WindUI)
	local Workspace = game:GetService("Workspace")
	local UserInputService = game:GetService("UserInputService")

	local DEFAULTS = {
		margin = 40,
		minScale = 0.3,
		maxScale = 1.0,
		threshold = 0.025,
		profileMin = 0.75,
		profileMax = 1.25,
		referenceWidth = 580,
		referenceHeight = 460,
	}

	local layoutHooks = {}
	local boundWindows = {}

	local function profileMultiplier()
		if type(WindUI) ~= "table" then
			return 1
		end
		return math.clamp(tonumber(WindUI._AlleralUiScale) or 1, DEFAULTS.profileMin, DEFAULTS.profileMax)
	end

	local function viewportSize()
		local camera = Workspace.CurrentCamera
		if camera then
			return camera.ViewportSize
		end
		return Vector2.new(1280, 720)
	end

	local function windowMain(window)
		if type(window) ~= "table" then
			return nil
		end
		local main = window.UIElements and window.UIElements.Main
		if main and main:IsA("GuiObject") then
			return main
		end
		return nil
	end

	local function measureMain(window)
		local main = windowMain(window)
		if not main then
			return nil
		end
		local abs = main.AbsoluteSize
		if abs.X > 1 and abs.Y > 1 then
			return abs
		end
		local size = main.Size
		local vp = viewportSize()
		local width = size.X.Offset
		local height = size.Y.Offset
		if size.X.Scale > 0 then
			width = math.max(width, size.X.Scale * vp.X)
		end
		if size.Y.Scale > 0 then
			height = math.max(height, size.Y.Scale * vp.Y)
		end
		if width <= 1 then
			width = DEFAULTS.referenceWidth
		end
		if height <= 1 then
			height = DEFAULTS.referenceHeight
		end
		return Vector2.new(width, height)
	end

	local function fixTextLayout(root)
		if not root or not root:IsA("GuiObject") then
			return
		end
		for _, desc in ipairs(root:GetDescendants()) do
			if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
				if desc.TextWrapped then
					desc.TextWrapped = false
					desc.TextTruncate = Enum.TextTruncate.AtEnd
				end
				if desc.AutomaticSize == Enum.AutomaticSize.XY then
					desc.AutomaticSize = Enum.AutomaticSize.Y
					if desc.Size.X.Scale == 0 and desc.Size.X.Offset <= 0 then
						desc.Size = UDim2.new(1, 0, 0, 0)
					end
				elseif desc:IsA("TextLabel") and desc.Size.X.Scale == 0 and desc.Size.X.Offset == 0 then
					desc.Size = UDim2.new(1, 0, desc.Size.Y.Scale, desc.Size.Y.Offset)
				end
			end
		end
	end

	local function runLayoutHooks(window)
		for _, hook in pairs(layoutHooks) do
			if type(hook) == "function" then
				pcall(hook, window)
			end
		end
		local mainBar = window and window.UIElements and window.UIElements.MainBar
		if mainBar then
			fixTextLayout(mainBar)
		end
		local dropdownGui = type(WindUI) == "table" and WindUI.DropdownGui
		if dropdownGui then
			fixTextLayout(dropdownGui)
		end
	end

	local function computeScale(window, opts)
		opts = type(opts) == "table" and opts or DEFAULTS
		if type(window) ~= "table" or window.IsFullscreen then
			return nil
		end
		if window.AutoScale == false then
			return profileMultiplier()
		end

		local vp = viewportSize()
		local margin = opts.margin or DEFAULTS.margin
		local availX = vp.X - margin * 2
		local availY = vp.Y - margin * 2
		if availX <= 0 or availY <= 0 then
			return profileMultiplier()
		end

		local measured = measureMain(window)
		if not measured then
			return profileMultiplier()
		end

		local fit = math.min(availX / measured.X, availY / measured.Y)
		local minScale = opts.minScale or DEFAULTS.minScale
		local maxScale = opts.maxScale or DEFAULTS.maxScale
		return math.clamp(fit * profileMultiplier(), minScale, maxScale)
	end

	local function applyScale(window, opts)
		if type(window) ~= "table" or type(window.SetUIScale) ~= "function" then
			return nil
		end

		opts = type(opts) == "table" and opts or DEFAULTS
		local scale = computeScale(window, opts)
		if not scale then
			return nil
		end

		local current = (type(window.GetUIScale) == "function" and window:GetUIScale()) or 1
		local threshold = opts.threshold or DEFAULTS.threshold
		if math.abs(scale - current) > threshold then
			pcall(function()
				window:SetUIScale(scale)
			end)
		end

		if type(WindUI) == "table" then
			WindUI._AlleralAutoScale = scale
		end

		task.defer(function()
			runLayoutHooks(window)
		end)
		return scale
	end

	local function bindViewport(window, opts, onRefresh)
		if type(window) ~= "table" or boundWindows[window] then
			return
		end
		boundWindows[window] = true

		local function refresh()
			local scale = applyScale(window, opts)
			if type(onRefresh) == "function" then
				pcall(onRefresh, window, scale)
			end
		end

		local function hookCamera(camera)
			if not camera then
				return
			end
			pcall(function()
				camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
			end)
			task.defer(refresh)
			task.delay(0.05, refresh)
			task.delay(0.15, refresh)
			task.delay(0.35, refresh)
		end

		hookCamera(Workspace.CurrentCamera)
		pcall(function()
			Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
				hookCamera(Workspace.CurrentCamera)
			end)
		end)

		if UserInputService then
			pcall(function()
				UserInputService:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
			end)
		end
	end

	local function registerLayoutRefresh(name, fn)
		if type(name) ~= "string" or type(fn) ~= "function" then
			return false
		end
		layoutHooks[name] = fn
		return true
	end

	local function detectDeviceProfile()
		local vp = viewportSize()
		local shortSide = math.min(vp.X, vp.Y)
		local touch = UserInputService.TouchEnabled
		local keyboard = UserInputService.KeyboardEnabled
		local mouse = UserInputService.MouseEnabled
		if touch and not keyboard and not mouse then
			return "mobile"
		end
		if touch and shortSide <= 900 then
			return "mobile"
		end
		if shortSide <= 820 then
			return "compact"
		end
		if shortSide >= 1200 and vp.X / math.max(vp.Y, 1) >= 1.8 then
			return "ultrawide"
		end
		return "desktop"
	end

	local api = {
		VERSION = "1.1.0",
		DEFAULTS = DEFAULTS,
		compute = computeScale,
		apply = applyScale,
		bind = bindViewport,
		fixTextLayout = fixTextLayout,
		runLayoutHooks = runLayoutHooks,
		registerLayoutRefresh = registerLayoutRefresh,
		detectDeviceProfile = detectDeviceProfile,
		profileMultiplier = profileMultiplier,
	}

	if type(WindUI) == "table" then
		WindUI._AlleralScaleApi = api
		WindUI.AutoScale = WindUI.AutoScale or {}
		function WindUI.AutoScale.Compute(_self, window, opts)
			return computeScale(window, opts)
		end
		function WindUI.AutoScale.Apply(_self, window, opts)
			return applyScale(window, opts)
		end
		function WindUI.AutoScale.Bind(_self, window, opts, onRefresh)
			bindViewport(window, opts, onRefresh)
		end
		function WindUI.AutoScale.FixTextLayout(_self, root)
			fixTextLayout(root)
		end
		function WindUI.RegisterLayoutRefresh(_self, name, fn)
			return registerLayoutRefresh(name, fn)
		end
		function WindUI.RefreshUiLayout(_self, window)
			window = window or WindUI.Window
			if not window then
				return false
			end
			runLayoutHooks(window)
			return true
		end
	end

	return api
end
