-- NEVERLOSE_UI_VERSION = "1.3.0-kick"
-- Ripple-style easing + instance tweens (MIT) https://github.com/littensy/ripple

return function()
	local RunService = game:GetService("RunService")

	local PI = math.pi
	local c1 = 1.70158
	local c2 = c1 * 1.525
	local c3 = c1 + 1
	local c4 = (2 * PI) / 3
	local c5 = (2 * PI) / 4.5

	local easing = {
		linear = function(x)
			return x
		end,
		quadOut = function(x)
			return 1 - (1 - x) * (1 - x)
		end,
		quadInOut = function(x)
			if x < 0.5 then
				return 2 * x * x
			end
			return 1 - ((-2 * x + 2) ^ 2) / 2
		end,
		quartOut = function(x)
			return 1 - (1 - x) ^ 4
		end,
		cubicOut = function(x)
			return 1 - (1 - x) ^ 3
		end,
		sineOut = function(x)
			return math.sin((x * PI) / 2)
		end,
		expoOut = function(x)
			if x == 1 then
				return 1
			end
			return 1 - 2 ^ (-10 * x)
		end,
	}

	local motors = {}
	local conn

	local function stopMotor(instance)
		motors[instance] = nil
		if not next(motors) and conn then
			conn:Disconnect()
			conn = nil
		end
	end

	local function lerpNumber(a, b, t)
		return a + (b - a) * t
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

	local function ensureLoop()
		if conn then
			return
		end
		conn = RunService.Heartbeat:Connect(function(dt)
			dt = math.clamp(dt, 1 / 240, 1 / 15)
			for instance, motor in pairs(motors) do
				if not instance or not instance.Parent then
					stopMotor(instance)
					if motor.onComplete then
						pcall(motor.onComplete)
					end
				else
				motor.elapsed += dt
				local alpha = math.clamp(motor.elapsed / motor.duration, 0, 1)
				local eased = motor.ease(alpha)
				for key, startValue in pairs(motor.starts) do
					local targetValue = motor.goals[key]
					local valueType = typeof(startValue)
					if valueType == "number" then
						instance[key] = lerpNumber(startValue, targetValue, eased)
					elseif valueType == "UDim2" then
						instance[key] = lerpUdim2(startValue, targetValue, eased)
					elseif valueType == "Vector2" then
						instance[key] = lerpVector2(startValue, targetValue, eased)
					end
				end
				if alpha >= 1 then
					stopMotor(instance)
					if motor.onComplete then
						pcall(motor.onComplete)
					end
				end
				end
			end
		end)
	end

	local function tween(instance, goals, opts)
		if not instance or type(goals) ~= "table" then
			return
		end
		opts = type(opts) == "table" and opts or {}
		local starts = {}
		for key, target in pairs(goals) do
			local valueType = typeof(target)
			if valueType == "number" or valueType == "UDim2" or valueType == "Vector2" then
				starts[key] = instance[key]
			end
		end
		if not next(starts) then
			return
		end
		local easeName = tostring(opts.easing or "quartOut")
		motors[instance] = {
			starts = starts,
			goals = goals,
			duration = math.max(opts.duration or 0.26, 0.01),
			ease = easing[easeName] or easing.quartOut,
			elapsed = 0,
			onComplete = opts.onComplete,
		}
		ensureLoop()
	end

	return {
		easing = easing,
		tween = tween,
		createTween = function(_, opts)
			opts = type(opts) == "table" and opts or {}
			return {
				setGoal = function() end,
				onComplete = function(callback)
					opts.onComplete = callback
				end,
			}
		end,
		stop = stopMotor,
	}
end
