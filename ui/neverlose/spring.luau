-- NEVERLOSE_UI_VERSION = "1.3.0-kick"
--[[
	Unified motion adapter for Neverlose UI.
	Uses spr (springs), ripple (easing tweens), fusion (reactive state bridge).
]]

return function(deps)
	deps = type(deps) == "table" and deps or {}
	local Spr = deps.spr
	local Ripple = deps.ripple
	local Fusion = deps.fusion

	local function mapMotion(opts)
		opts = type(opts) == "table" and opts or {}
		local frequency = opts.frequency or 5.5
		local damping = opts.damping or 1
		return damping, frequency
	end

	local function springTarget(instance, goal, opts)
		if not instance or type(goal) ~= "table" then
			return
		end
		opts = type(opts) == "table" and opts or {}
		if Spr and type(Spr.target) == "function" then
			local damping, frequency = mapMotion(opts)
			Spr.target(instance, damping, frequency, goal)
			if opts.onComplete and type(Spr.completed) == "function" then
				Spr.completed(instance, opts.onComplete)
			end
			return
		end
		if Ripple and type(Ripple.tween) == "function" then
			Ripple.tween(instance, goal, {
				easing = opts.easing or "quartOut",
				duration = opts.duration or 0.26,
				onComplete = opts.onComplete,
			})
		end
	end

	local function springCancel(instance)
		if Spr and type(Spr.stop) == "function" then
			Spr.stop(instance)
		elseif Ripple and type(Ripple.stop) == "function" then
			Ripple.stop(instance)
		end
	end

	return {
		target = springTarget,
		cancel = springCancel,
		spr = Spr,
		ripple = Ripple,
		fusion = Fusion,
		tween = Ripple and Ripple.tween or nil,
	}
end
