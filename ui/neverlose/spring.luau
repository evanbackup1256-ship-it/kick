--[[
	Critical-damping spring animator for Neverlose UI instances.
	Animates numbers, UDim2 (scale + offset), and Vector2 on one Heartbeat loop.
]]

return function()
	local RunService = game:GetService("RunService")

	local motors = {}
	local conn

	local function applyUdim(instance, key, states)
		local current = instance[key]
		local xs, xo, ys, yo = current.X.Scale, current.X.Offset, current.Y.Scale, current.Y.Offset
		for _, state in pairs(states) do
			if state.udimKey == key then
				if state.udimAxis == "X" and state.udimKind == "Scale" then
					xs = state.position
				elseif state.udimAxis == "X" and state.udimKind == "Offset" then
					xo = state.position
				elseif state.udimAxis == "Y" and state.udimKind == "Scale" then
					ys = state.position
				elseif state.udimAxis == "Y" and state.udimKind == "Offset" then
					yo = state.position
				end
			end
		end
		instance[key] = UDim2.new(xs, xo, ys, yo)
	end

	local function stopMotor(id)
		motors[id] = nil
		if not next(motors) and conn then
			conn:Disconnect()
			conn = nil
		end
	end

	local function ensureLoop()
		if conn then
			return
		end
		conn = RunService.Heartbeat:Connect(function(dt)
			dt = math.clamp(dt, 1 / 240, 1 / 20)
			for id, motor in pairs(motors) do
				local done = true
				for key, state in pairs(motor.states) do
					local omega = state.frequency * math.pi * 2
					local c = 2 * omega * state.damping
					local accel = -c * state.velocity - (omega * omega) * (state.position - state.target)
					state.velocity += accel * dt
					state.position += state.velocity * dt
					if motor.instance and motor.instance.Parent then
						if state.udimKey then
							applyUdim(motor.instance, state.udimKey, motor.states)
						elseif state.vectorKey then
							local current = motor.instance[state.vectorKey]
							if state.vectorAxis == "X" then
								motor.instance[state.vectorKey] = Vector2.new(state.position, current.Y)
							else
								motor.instance[state.vectorKey] = Vector2.new(current.X, state.position)
							end
						else
							motor.instance[key] = state.position
						end
					end
					if math.abs(state.position - state.target) > 0.0005 or math.abs(state.velocity) > 0.0005 then
						done = false
					else
						state.position = state.target
						state.velocity = 0
					end
				end
				if done then
					if motor.instance and motor.instance.Parent then
						for key, state in pairs(motor.states) do
							if state.udimKey then
								state.position = state.target
								applyUdim(motor.instance, state.udimKey, motor.states)
							elseif state.vectorKey then
								local current = motor.instance[state.vectorKey]
								if state.vectorAxis == "X" then
									motor.instance[state.vectorKey] = Vector2.new(state.target, current.Y)
								else
									motor.instance[state.vectorKey] = Vector2.new(current.X, state.target)
								end
							else
								motor.instance[key] = state.target
							end
						end
					end
					stopMotor(id)
					if motor.onComplete then
						pcall(motor.onComplete)
					end
				end
			end
		end)
	end

	local function addUdimStates(states, instance, key, target, frequency, damping)
		local current = instance[key]
		local specs = {
			{ axis = "X", kind = "Scale", pos = current.X.Scale, tgt = target.X.Scale },
			{ axis = "X", kind = "Offset", pos = current.X.Offset, tgt = target.X.Offset },
			{ axis = "Y", kind = "Scale", pos = current.Y.Scale, tgt = target.Y.Scale },
			{ axis = "Y", kind = "Offset", pos = current.Y.Offset, tgt = target.Y.Offset },
		}
		for _, spec in ipairs(specs) do
			local id = key .. "_" .. spec.axis .. spec.kind
			states[id] = {
				position = spec.pos,
				target = spec.tgt,
				velocity = 0,
				frequency = frequency,
				damping = damping,
				udimKey = key,
				udimAxis = spec.axis,
				udimKind = spec.kind,
			}
		end
	end

	local function spring(instance, goal, opts)
		if not instance or type(goal) ~= "table" then
			return
		end
		opts = type(opts) == "table" and opts or {}
		local frequency = opts.frequency or 7
		local damping = opts.damping or 0.78
		local states = {}
		for key, target in pairs(goal) do
			local targetType = typeof(target)
			if targetType == "number" then
				states[key] = {
					position = instance[key],
					target = target,
					velocity = 0,
					frequency = frequency,
					damping = damping,
				}
			elseif targetType == "UDim2" then
				addUdimStates(states, instance, key, target, frequency, damping)
			elseif targetType == "Vector2" then
				states[key .. "_X"] = {
					position = instance[key].X,
					target = target.X,
					velocity = 0,
					frequency = frequency,
					damping = damping,
					vectorKey = key,
					vectorAxis = "X",
				}
				states[key .. "_Y"] = {
					position = instance[key].Y,
					target = target.Y,
					velocity = 0,
					frequency = frequency,
					damping = damping,
					vectorKey = key,
					vectorAxis = "Y",
				}
			end
		end
		if not next(states) then
			return
		end
		motors[instance] = {
			instance = instance,
			states = states,
			onComplete = opts.onComplete,
		}
		ensureLoop()
	end

	return {
		target = spring,
		cancel = function(instance)
			stopMotor(instance)
		end,
	}
end
