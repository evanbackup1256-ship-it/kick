-- NEVERLOSE_UI_VERSION = "1.5.2-kick"
--[[
	Lightweight Lottie-inspired timeline director for Neverlose UI.
	Integrates with Library:Motion / AnimateFluid — one shared Heartbeat loop.
]]

return function(Library)
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")

	local MathClamp = math.clamp
	local TableInsert = table.insert
	local TableRemove = table.remove
	local TableClone = table.clone or function(t)
		local c = {}
		for k, v in pairs(t) do
			c[k] = v
		end
		return c
	end

	local Easing = {
		Linear = function(t)
			return t
		end,
		InQuad = function(t)
			return t * t
		end,
		OutQuad = function(t)
			return 1 - (1 - t) * (1 - t)
		end,
		InOutQuad = function(t)
			if t < 0.5 then
				return 2 * t * t
			end
			return 1 - ((-2 * t + 2) ^ 2) / 2
		end,
		OutQuart = function(t)
			return 1 - (1 - t) ^ 4
		end,
		OutBack = function(t)
			local c1 = 1.70158
			local c3 = c1 + 1
			return 1 + c3 * ((t - 1) ^ 3) + c1 * ((t - 1) ^ 2)
		end,
		OutElastic = function(t)
			if t == 0 or t == 1 then
				return t
			end
			return (2 ^ (-10 * t)) * math.sin((t * 10 - 0.75) * ((2 * math.pi) / 3)) + 1
		end,
		OutExpo = function(t)
			if t == 1 then
				return 1
			end
			return 1 - 2 ^ (-10 * t)
		end,
	}

	local function lerpNumber(a, b, t)
		return a + (b - a) * t
	end

	local function lerpColor(a, b, t)
		return Color3.new(
			lerpNumber(a.R, b.R, t),
			lerpNumber(a.G, b.G, t),
			lerpNumber(a.B, b.B, t)
		)
	end

	local function lerpUdim2(a, b, t)
		return UDim2.new(
			lerpNumber(a.X.Scale, b.X.Scale, t),
			lerpNumber(a.X.Offset, b.X.Offset, t),
			lerpNumber(a.Y.Scale, b.Y.Scale, t),
			lerpNumber(a.Y.Offset, b.Y.Offset, t)
		)
	end

	local function lerpVector2(a, b, t)
		return Vector2.new(lerpNumber(a.X, b.X, t), lerpNumber(a.Y, b.Y, t))
	end

	local function lerpValue(a, b, t)
		local ta, tb = typeof(a), typeof(b)
		if ta ~= tb then
			return b
		end
		if ta == "number" then
			return lerpNumber(a, b, t)
		elseif ta == "Color3" then
			return lerpColor(a, b, t)
		elseif ta == "UDim2" then
			return lerpUdim2(a, b, t)
		elseif ta == "Vector2" then
			return lerpVector2(a, b, t)
		end
		return b
	end

	local Lottie = {
		Debug = false,
		_registry = {},
		_active = {},
		_players = {},
		_conn = nil,
		_id = 0,
	}

	local function debugLog(...)
		if Lottie.Debug then
			print("[Lottie]", ...)
		end
	end

	local function debugWarn(...)
		if Lottie.Debug then
			warn("[Lottie]", ...)
		end
	end

	local function getTargetKey(target)
		if typeof(target) == "Instance" then
			return "inst:" .. tostring(target)
		end
		if type(target) == "table" then
			if not target._lottieId then
				Lottie._id += 1
				target._lottieId = "ctx:" .. tostring(Lottie._id)
			end
			return target._lottieId
		end
		return "unknown"
	end

	local function buildContext(target, options)
		if type(options.context) == "table" then
			return options.context
		end
		if type(target) == "table" and (target.root or target.targets or target.items) then
			return target
		end
		if typeof(target) == "Instance" then
			return { root = target, items = {}, targets = { Self = target } }
		end
		if type(target) == "table" and target.Instance then
			return {
				root = target.Instance,
				items = { Self = target },
				targets = { Self = target.Instance },
			}
		end
		return { root = nil, items = {}, targets = {} }
	end

	local function resolveTarget(context, path)
		if not context or not path then
			return nil
		end
		if path == "Self" then
			return context.root
		end
		if type(context.targets) == "table" and context.targets[path] then
			local hit = context.targets[path]
			if typeof(hit) == "Instance" then
				return hit
			end
			if type(hit) == "table" and hit.Instance then
				return hit.Instance
			end
		end
		if type(context.items) == "table" and context.items[path] then
			local item = context.items[path]
			if typeof(item) == "Instance" then
				return item
			end
			if type(item) == "table" and item.Instance then
				return item.Instance
			end
		end
		if context.root and typeof(context.root) == "Instance" then
			local named = context.root:FindFirstChild(path, true)
			if named then
				return named
			end
		end
		return nil
	end

	local function findScaleObject(root)
		if not root or typeof(root) ~= "Instance" then
			return nil
		end
		return root:FindFirstChild("_WindowScale")
			or root:FindFirstChild("_PremiumScale")
			or root:FindFirstChild("_TooltipScale")
			or root:FindFirstChild("_LogoScale")
			or root:FindFirstChild("_PopoverScale")
			or root:FindFirstChild("_PremiumScale", true)
	end

	local function applyProperty(instance, property, value)
		if not instance or typeof(instance) ~= "Instance" then
			return
		end
		local ok = pcall(function()
			if property == "Scale" then
				local scale = findScaleObject(instance) or (instance:IsA("UIScale") and instance)
				if scale then
					scale.Scale = value
				end
				return
			end
			if property:sub(1, 9) == "UIStroke." then
				local stroke = instance:IsA("UIStroke") and instance or instance:FindFirstChildWhichIsA("UIStroke", true)
				if stroke then
					stroke[property:sub(10)] = value
				end
				return
			end
			if property:sub(1, 11) == "UIGradient." then
				local gradient = instance:IsA("UIGradient") and instance or instance:FindFirstChildWhichIsA("UIGradient", true)
				if gradient then
					gradient[property:sub(12)] = value
				end
				return
			end
			instance[property] = value
		end)
		if not ok then
			debugWarn("apply failed", property, instance:GetFullName())
		end
	end

	local function evalTrack(track, progress)
		local kfs = track.Keyframes
		if type(kfs) ~= "table" or #kfs == 0 then
			return nil
		end
		if progress <= kfs[1].Time then
			return kfs[1].Value
		end
		if progress >= kfs[#kfs].Time then
			return kfs[#kfs].Value
		end
		for index = 1, #kfs - 1 do
			local a, b = kfs[index], kfs[index + 1]
			if progress >= a.Time and progress <= b.Time then
				local span = b.Time - a.Time
				local localT = span > 0 and (progress - a.Time) / span or 1
				local easeFn = Easing[track.Easing or "Linear"] or Easing.Linear
				localT = easeFn(localT)
				return lerpValue(a.Value, b.Value, localT)
			end
		end
		return kfs[#kfs].Value
	end

	local function applyState(state, progress)
		for _, track in ipairs(state.data.Tracks or {}) do
			local inst = resolveTarget(state.context, track.Target)
			if inst then
				local value = evalTrack(track, progress)
				if value ~= nil then
					applyProperty(inst, track.Property, value)
				end
			end
		end
		if type(state.hooks) == "table" and type(state.hooks.onUpdate) == "function" then
			pcall(state.hooks.onUpdate, progress, state)
		end
	end

	local function removeState(index)
		local state = Lottie._active[index]
		if state then
			Lottie._players[state.key] = nil
		end
		TableRemove(Lottie._active, index)
	end

	local function ensureLoop()
		if Lottie._conn then
			return
		end
		Lottie._conn = RunService.Heartbeat:Connect(function(dt)
			dt = MathClamp(dt, 1 / 240, 1 / 20)
			local index = 1
			while index <= #Lottie._active do
				local state = Lottie._active[index]
				if state.paused then
					index += 1
				else
					state.elapsed += dt * (state.speed or 1)
					local duration = math.max(state.data.Duration or 0.3, 0.01)
					local progress = MathClamp(state.elapsed / duration, 0, 1)
					if state.data.Direction == "Reverse" then
						progress = 1 - progress
					end
					if state.elapsed >= duration then
						if state.data.Loop then
							applyState(state, state.data.Direction == "Reverse" and 0 or 1)
							state.elapsed = 0
							index += 1
						else
							applyState(state, state.data.Direction == "Reverse" and 0 or 1)
							removeState(index)
							if state.onComplete then
								pcall(state.onComplete, state)
							end
						end
					else
						applyState(state, progress)
						index += 1
					end
				end
			end
			if #Lottie._active == 0 and Lottie._conn then
				Lottie._conn:Disconnect()
				Lottie._conn = nil
			end
		end)
	end

	function Lottie:Register(name, animationData)
		if type(name) ~= "string" or type(animationData) ~= "table" then
			return false
		end
		self._registry[name] = animationData
		return true
	end

	function Lottie:GetPreset(name, params)
		local base = self._registry[name]
		if not base then
			return nil
		end
		local copy = TableClone(base)
		params = type(params) == "table" and params or {}
		if params.Loop ~= nil then
			copy.Loop = params.Loop
		end
		if params.Duration then
			copy.Duration = params.Duration
		end
		if params.direction and type(copy.Tracks) == "table" then
			local dir = params.direction
			local slide = params.slide or 26
			for _, track in ipairs(copy.Tracks) do
				if track.Property == "Position" and type(track.Keyframes) == "table" then
					for _, kf in ipairs(track.Keyframes) do
						if typeof(kf.Value) == "UDim2" then
							if params.mode == "In" and kf.Time == 0 then
								kf.Value = UDim2.new(kf.Value.X.Scale, dir * slide, kf.Value.Y.Scale, 10)
							elseif params.mode == "In" and kf.Time == 1 then
								kf.Value = UDim2.new(0, 0, 0, 0)
							elseif params.mode == "Out" and kf.Time == 0 then
								kf.Value = UDim2.new(0, 0, 0, 0)
							elseif params.mode == "Out" and kf.Time == 1 then
								kf.Value = UDim2.new(0, dir * -slide, 0, slide)
							end
						end
					end
				end
			end
		end
		return copy
	end

	function Lottie:IsPlaying(target)
		local key = getTargetKey(target)
		return self._players[key] ~= nil
	end

	function Lottie:Stop(target)
		local key = getTargetKey(target)
		local index = 1
		while index <= #self._active do
			if self._active[index].key == key then
				debugLog("stop", key)
				removeState(index)
			else
				index += 1
			end
		end
	end

	function Lottie:Pause(target)
		local state = self._players[getTargetKey(target)]
		if state then
			state.paused = true
		end
	end

	function Lottie:Resume(target)
		local state = self._players[getTargetKey(target)]
		if state then
			state.paused = false
		end
	end

	function Lottie:StopAll()
		table.clear(self._active)
		self._players = {}
		if self._conn then
			self._conn:Disconnect()
			self._conn = nil
		end
	end

	function Lottie:Play(target, name, options)
		options = type(options) == "table" and options or {}
		local data = options.data
		if not data then
			if options.mode or options.direction then
				data = self:GetPreset(name, options)
			else
				data = self._registry[name]
			end
		end
		if type(data) ~= "table" then
			debugWarn("missing animation", name)
			return false
		end
		data = TableClone(data)
		if options.Loop ~= nil then
			data.Loop = options.Loop
		end
		if options.Direction then
			data.Direction = options.Direction
		end

		local key = getTargetKey(target)
		self:Stop(target)

		local state = {
			key = key,
			context = buildContext(target, options),
			data = data,
			elapsed = 0,
			paused = false,
			speed = options.speed or 1,
			onComplete = options.onComplete,
			hooks = options.hooks,
			name = name,
		}

		TableInsert(self._active, state)
		self._players[key] = state
		applyState(state, data.Direction == "Reverse" and 1 or 0)
		ensureLoop()
		debugLog("play", name, key)
		return true
	end

	local function registerBuiltins()
		Lottie:Register("PremiumWindowOpen", {
			Duration = 0.55,
			Loop = false,
			Direction = "Forward",
			Tracks = {
				{ Target = "Self", Property = "Scale", Keyframes = { { Time = 0, Value = 0.94 }, { Time = 1, Value = 1 } }, Easing = "OutBack" },
				{ Target = "Shadow", Property = "BackgroundTransparency", Keyframes = { { Time = 0, Value = 1 }, { Time = 1, Value = 0.62 } }, Easing = "OutQuart" },
				{ Target = "Glow", Property = "UIStroke.Transparency", Keyframes = { { Time = 0, Value = 1 }, { Time = 0.5, Value = 0.35 }, { Time = 1, Value = 0.72 } }, Easing = "OutQuart" },
				{ Target = "Gradient", Property = "UIGradient.Rotation", Keyframes = { { Time = 0, Value = 70 }, { Time = 1, Value = 90 } }, Easing = "OutExpo" },
			},
		})

		Lottie:Register("PremiumWindowClose", {
			Duration = 0.28,
			Loop = false,
			Direction = "Forward",
			Tracks = {
				{ Target = "Self", Property = "Scale", Keyframes = { { Time = 0, Value = 1 }, { Time = 1, Value = 0.97 } }, Easing = "OutQuart" },
				{ Target = "Shadow", Property = "BackgroundTransparency", Keyframes = { { Time = 0, Value = 0.62 }, { Time = 1, Value = 1 } }, Easing = "InQuad" },
				{ Target = "Glow", Property = "UIStroke.Transparency", Keyframes = { { Time = 0, Value = 0.72 }, { Time = 1, Value = 1 } }, Easing = "InQuad" },
			},
		})

		Lottie:Register("NotificationPop", {
			Duration = 0.62,
			Loop = false,
			Direction = "Forward",
			Tracks = {
				{ Target = "Self", Property = "Position", Keyframes = { { Time = 0, Value = UDim2.new(1, 48, 0, 0) }, { Time = 1, Value = UDim2.new(1, 0, 0, 0) } }, Easing = "OutBack" },
				{ Target = "Icon", Property = "Rotation", Keyframes = { { Time = 0, Value = -12 }, { Time = 0.55, Value = 8 }, { Time = 1, Value = 0 } }, Easing = "OutElastic" },
				{ Target = "Content", Property = "BackgroundTransparency", Keyframes = { { Time = 0, Value = 1 }, { Time = 1, Value = 0.12 } }, Easing = "OutQuart" },
			},
		})

		Lottie:Register("DropdownBloom", {
			Duration = 0.32,
			Loop = false,
			Direction = "Forward",
			Tracks = {
				{ Target = "Self", Property = "BackgroundTransparency", Keyframes = { { Time = 0, Value = 1 }, { Time = 1, Value = 0.08 } }, Easing = "OutQuart" },
				{ Target = "Icon", Property = "Rotation", Keyframes = { { Time = 0, Value = 0 }, { Time = 1, Value = 180 } }, Easing = "OutBack" },
				{ Target = "Glow", Property = "ImageColor3", Keyframes = { { Time = 0, Value = Color3.fromRGB(141, 141, 150) }, { Time = 1, Value = Color3.fromRGB(255, 255, 255) } }, Easing = "OutQuart" },
			},
		})

		Lottie:Register("ToggleSpark", {
			Duration = 0.42,
			Loop = false,
			Direction = "Forward",
			Tracks = {
				{ Target = "Self", Property = "Scale", Keyframes = { { Time = 0, Value = 1 }, { Time = 0.35, Value = 1.08 }, { Time = 1, Value = 1 } }, Easing = "OutElastic" },
				{ Target = "Glow", Property = "BackgroundTransparency", Keyframes = { { Time = 0, Value = 1 }, { Time = 0.2, Value = 0.2 }, { Time = 1, Value = 1 } }, Easing = "OutQuart" },
				{ Target = "Icon", Property = "ImageTransparency", Keyframes = { { Time = 0, Value = 1 }, { Time = 0.25, Value = 0 }, { Time = 1, Value = 0 } }, Easing = "OutQuart" },
			},
		})

		Lottie:Register("TabLiquidSwitch", {
			Duration = 0.38,
			Loop = false,
			Direction = "Forward",
			Tracks = {
				{ Target = "Self", Property = "Position", Keyframes = { { Time = 0, Value = UDim2.new(0, 26, 0, 10) }, { Time = 1, Value = UDim2.new(0, 0, 0, 0) } }, Easing = "OutQuart" },
				{ Target = "Icon", Property = "Size", Keyframes = { { Time = 0, Value = UDim2.new(0, 16, 0, 16) }, { Time = 1, Value = UDim2.new(0, 20, 0, 20) } }, Easing = "OutBack" },
				{ Target = "Stroke", Property = "Position", Keyframes = { { Time = 0, Value = UDim2.new(0, 0, 0, 0) }, { Time = 1, Value = UDim2.new(0, 0, 0, 0) } }, Easing = "OutExpo" },
			},
		})

		Lottie:Register("ButtonPulse", {
			Duration = 0.24,
			Loop = false,
			Direction = "Forward",
			Tracks = {
				{ Target = "Self", Property = "Scale", Keyframes = { { Time = 0, Value = 1 }, { Time = 0.4, Value = 0.97 }, { Time = 1, Value = 1.015 } }, Easing = "OutBack" },
				{ Target = "Glow", Property = "UIStroke.Transparency", Keyframes = { { Time = 0, Value = 1 }, { Time = 0.35, Value = 0.45 }, { Time = 1, Value = 1 } }, Easing = "OutQuart" },
			},
		})

		Lottie:Register("IconBreathe", {
			Duration = 2.4,
			Loop = true,
			Direction = "Forward",
			Tracks = {
				{ Target = "Icon", Property = "Rotation", Keyframes = { { Time = 0, Value = -2 }, { Time = 0.5, Value = 2 }, { Time = 1, Value = -2 } }, Easing = "InOutQuad" },
				{ Target = "Self", Property = "Scale", Keyframes = { { Time = 0, Value = 1 }, { Time = 0.5, Value = 1.03 }, { Time = 1, Value = 1 } }, Easing = "InOutQuad" },
			},
		})

		Lottie:Register("TooltipPop", {
			Duration = 0.24,
			Loop = false,
			Direction = "Forward",
			Tracks = {
				{ Target = "Self", Property = "Scale", Keyframes = { { Time = 0, Value = 0.9 }, { Time = 1, Value = 1 } }, Easing = "OutBack" },
				{ Target = "Self", Property = "BackgroundTransparency", Keyframes = { { Time = 0, Value = 1 }, { Time = 1, Value = 0.05 } }, Easing = "OutQuart" },
				{ Target = "Stroke", Property = "UIStroke.Transparency", Keyframes = { { Time = 0, Value = 1 }, { Time = 1, Value = 0.2 } }, Easing = "OutQuart" },
				{ Target = "Content", Property = "TextTransparency", Keyframes = { { Time = 0, Value = 0.4 }, { Time = 1, Value = 0 } }, Easing = "OutQuart" },
				{ Target = "Icon", Property = "Size", Keyframes = { { Time = 0, Value = UDim2.new(1, 0, 0, 0) }, { Time = 0.45, Value = UDim2.new(1, 0, 0, 2) }, { Time = 1, Value = UDim2.new(1, 0, 0, 2) } }, Easing = "OutExpo" },
			},
		})
	end

	registerBuiltins()

	Library.Lottie = Lottie
	return Lottie
end
