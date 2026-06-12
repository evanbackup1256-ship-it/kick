-- NEVERLOSE_UI_VERSION = "1.3.0-kick"
-- Fusion-inspired reactive helpers (MIT) https://github.com/dphfox/Fusion

return function()
	local function peek(state)
		if type(state) == "table" and type(state.get) == "function" then
			return state:get()
		end
		return state
	end

	local function Value(initial)
		local self = {
			_value = initial,
			_observers = {},
		}
		function self:get()
			return self._value
		end
		function self:set(nextValue)
			if self._value == nextValue then
				return
			end
			self._value = nextValue
			for _, callback in ipairs(self._observers) do
				pcall(callback, nextValue)
			end
		end
		function self:observe(callback)
			if type(callback) == "function" then
				table.insert(self._observers, callback)
			end
			return self
		end
		return self
	end

	local function Computed(producer)
		local source = Value(nil)
		local function refresh()
			local ok, result = pcall(producer)
			if ok then
				source:set(result)
			end
		end
		refresh()
		return {
			get = function()
				return source:get()
			end,
			refresh = refresh,
		}
	end

	local function Observer(state, callback)
		if type(state) == "table" and type(state.observe) == "function" then
			state:observe(callback)
			pcall(callback, state:get())
		end
	end

	return {
		version = { major = 0, minor = 4, bridge = true },
		Value = Value,
		Computed = Computed,
		Observer = Observer,
		peek = peek,
	}
end
