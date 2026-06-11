--[[
	Alleral motion — compact spring engine inspired by fraktality/spr (MIT).
	https://github.com/Fraktality/spr
	Standalone reference module; aller.luau embeds an equivalent engine.
]]

return function(RunService)
	local springStates = setmetatable({}, { __mode = "k" })
	local heartbeatConn = nil

	local EPSILON = 0.0008
	local MAX_DT = 1 / 30

	local PRESETS = {
		instant = { f = math.huge, d = 1 },
		snappy = { f = 7.5, d = 1 },
		soft = { f = 4.8, d = 1.12 },
		bouncy = { f = 5.8, d = 0.72 },
		pop = { f = 6.4, d = 0.82 },
		micro = { f = 9.5, d = 1 },
		open = { f = 5.6, d = 0.88 },
		close = { f = 7.2, d = 1.05 },
		notify = { f = 6.2, d = 0.9 },
		dropdown = { f = 8.5, d = 1 },
		sweep = { f = 4.2, d = 1 },
		tab = { f = 6, d = 0.85 },
		toggle = { f = 7.2, d = 0.78 },
		press = { f = 11, d = 0.68 },
		slider = { f = 12, d = 1 },
	}

	local function resolvePreset(name)
		if type(name) == "table" and name.f then
			return name
		end
		return PRESETS[name] or PRESETS.snappy
	end

	local function stepScalar(pos, vel, goal, dt, freq, damp)
		if freq == math.huge then
			return goal, 0
		end
		local omega = math.pi * 2 * freq
		local zeta = damp
		local offset = pos - goal
		if zeta >= 1 then
			local expTerm = math.exp(-omega * dt)
			local newPos = goal + (offset + (vel + omega * offset) * dt) * expTerm
			local newVel = (vel - omega * (vel + omega * offset) * dt) * expTerm
			return newPos, newVel
		end
		local omegaD = omega * math.sqrt(1 - zeta * zeta)
		if omegaD < 1e-4 then
			omegaD = 1e-4
		end
		local expTerm = math.exp(-zeta * omega * dt)
		local cosTerm = math.cos(omegaD * dt)
		local sinTerm = math.sin(omegaD * dt)
		local newPos = goal
			+ expTerm
				* (offset * (cosTerm + (zeta * omega / omegaD) * sinTerm) + (vel / omegaD) * sinTerm)
		local newVel = expTerm
			* (
				vel * cosTerm
				- ((offset * omega * omega + vel * zeta * omega) / omegaD) * sinTerm
			)
		return newPos, newVel
	end

	local function packValue(value)
		local t = typeof(value)
		if t == "number" then
			return "number", { value }, function(ch)
				return ch[1]
			end
		elseif t == "UDim2" then
			return "udim2", { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }, function(ch)
				return UDim2.new(ch[1], ch[2], ch[3], ch[4])
			end
		elseif t == "UDim" then
			return "udim", { value.Scale, value.Offset }, function(ch)
				return UDim.new(ch[1], ch[2])
			end
		elseif t == "Color3" then
			return "color3", { value.R, value.G, value.B }, function(ch)
				return Color3.new(ch[1], ch[2], ch[3])
			end
		elseif t == "Vector2" then
			return "vector2", { value.X, value.Y }, function(ch)
				return Vector2.new(ch[1], ch[2])
			end
		end
		return nil
	end

	local function readProperty(instance, propName)
		local ok, value = pcall(function()
			return instance[propName]
		end)
		if ok then
			return value
		end
		return nil
	end

	local function writeProperty(instance, propName, value)
		pcall(function()
			instance[propName] = value
		end)
	end

	local function isSettled(channels, goalChannels, velocities)
		for i = 1, #channels do
			if math.abs(channels[i] - goalChannels[i]) > EPSILON then
				return false
			end
			if math.abs(velocities[i]) > EPSILON then
				return false
			end
		end
		return true
	end

	local function stepHeartbeat(dt)
		dt = math.min(dt, MAX_DT)
		for instance, props in pairs(springStates) do
			if not instance or not instance.Parent then
				springStates[instance] = nil
				continue
			end
			for propName, state in pairs(props) do
				local allSettled = true
				for i = 1, #state.pos do
					state.pos[i], state.vel[i] =
						stepScalar(state.pos[i], state.vel[i], state.goal[i], dt, state.f, state.d)
					if math.abs(state.pos[i] - state.goal[i]) > EPSILON or math.abs(state.vel[i]) > EPSILON then
						allSettled = false
					end
				end
				if allSettled then
					writeProperty(instance, propName, state.pack(state.goal))
					props[propName] = nil
				else
					writeProperty(instance, propName, state.pack(state.pos))
				end
			end
			if not next(props) then
				springStates[instance] = nil
			end
		end
		if not next(springStates) and heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
	end

	local function ensureHeartbeat()
		if heartbeatConn then
			return
		end
		heartbeatConn = RunService.RenderStepped:Connect(stepHeartbeat)
	end

	local function target(instance, presetName, props)
		if not instance or type(props) ~= "table" then
			return
		end
		local preset = resolvePreset(presetName)
		if preset.f == math.huge then
			for propName, goal in pairs(props) do
				writeProperty(instance, propName, goal)
			end
			return
		end

		local bag = springStates[instance]
		if not bag then
			bag = {}
			springStates[instance] = bag
		end

		for propName, goal in pairs(props) do
			local kind, goalChannels, pack = packValue(goal)
			if not kind then
				writeProperty(instance, propName, goal)
				continue
			end
			local current = readProperty(instance, propName)
			local _, startChannels = packValue(current)
			if not startChannels then
				writeProperty(instance, propName, goal)
				continue
			end
			local pos, vel = {}, {}
			for i = 1, #goalChannels do
				pos[i] = startChannels[i]
				vel[i] = 0
			end
			bag[propName] = {
				pos = pos,
				vel = vel,
				goal = goalChannels,
				pack = pack,
				f = preset.f,
				d = preset.d,
			}
		end
		ensureHeartbeat()
	end

	local function stop(instance, propName)
		local bag = springStates[instance]
		if not bag then
			return
		end
		if propName then
			bag[propName] = nil
		else
			springStates[instance] = nil
		end
	end

	local function tweenInfoToPreset(info)
		if not info or not info.Time then
			return "snappy"
		end
		local style = info.EasingStyle
		local t = info.Time
		if style == Enum.EasingStyle.Back then
			return "bouncy"
		end
		if style == Enum.EasingStyle.Exponential or style == Enum.EasingStyle.Elastic then
			return "pop"
		end
		if t <= 0.12 then
			return "micro"
		end
		if t >= 0.38 then
			return "soft"
		end
		if style == Enum.EasingStyle.Quint or style == Enum.EasingStyle.Quart then
			return "open"
		end
		return "snappy"
	end

	return {
		Presets = PRESETS,
		target = target,
		stop = stop,
		tweenInfoToPreset = tweenInfoToPreset,
	}
end
