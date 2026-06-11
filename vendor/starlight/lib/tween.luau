local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.theme)

local Tween = {}
local active = {}

local function trackKey(instance, prop)
	return tostring(instance) .. ":" .. tostring(prop)
end

function Tween.cancel(instance, prop)
	if prop then
		local key = trackKey(instance, prop)
		if active[key] then
			active[key]:Cancel()
			active[key] = nil
		end
		return
	end
	local prefix = tostring(instance) .. ":"
	for key, tween in pairs(active) do
		if key:sub(1, #prefix) == prefix then
			tween:Cancel()
			active[key] = nil
		end
	end
end

function Tween.set(instance, props)
	if not instance or type(props) ~= "table" then
		return
	end
	for key, value in pairs(props) do
		pcall(function()
			instance[key] = value
		end)
	end
end

function Tween.play(instance, goal, callback, info)
	if not instance or type(goal) ~= "table" then
		if callback then
			callback()
		end
		return nil
	end

	for prop in pairs(goal) do
		Tween.cancel(instance, prop)
	end

	local tween
	local ok = pcall(function()
		tween = TweenService:Create(instance, info or Theme.tweenInfo(), goal)
	end)
	if ok and tween then
		for prop in pairs(goal) do
			active[trackKey(instance, prop)] = tween
		end
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				for prop in pairs(goal) do
					active[trackKey(instance, prop)] = nil
				end
				if callback then
					callback()
				end
			end
		end)
		tween:Play()
	end
	return tween
end

function Tween.sequence(steps)
	task.spawn(function()
		for _, step in ipairs(steps or {}) do
			local done = false
			Tween.play(step.instance, step.goal, function()
				done = true
			end, step.info or Theme.tweenInfo())
			while not done do
				task.wait()
			end
		end
	end)
end

function Tween.number(fromValue, toValue, callback, info)
	local driver = Instance.new("NumberValue")
	driver.Value = fromValue
	local connection = driver.Changed:Connect(function(value)
		callback(value)
	end)
	Tween.play(driver, { Value = toValue }, function()
		connection:Disconnect()
		driver:Destroy()
	end, info)
end

function Tween.fade(instance, visible, callback)
	local props = {}
	if instance:IsA("GuiObject") then
		local target = instance:GetAttribute("TargetTransparency")
		if target == nil then
			target = instance.BackgroundTransparency
			instance:SetAttribute("TargetTransparency", target)
		end
		props.BackgroundTransparency = visible and target or 1
	end
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		props.TextTransparency = visible and (instance:GetAttribute("TargetTextTransparency") or 0.4) or 1
	end
	if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		props.ImageTransparency = visible and (instance:GetAttribute("TargetImageTransparency") or 0) or 1
	end
	return Tween.play(instance, props, callback, Theme.tweenInfo(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
end

function Tween.entrance(instance, delaySeconds)
	if not instance then
		return
	end
	delaySeconds = delaySeconds or 0
	local props = {}
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		local target = instance.TextTransparency
		instance:SetAttribute("TargetTextTransparency", target)
		instance.TextTransparency = 1
		props.TextTransparency = target
	end
	if instance:IsA("GuiObject") and not next(props) then
		local target = instance.BackgroundTransparency
		instance:SetAttribute("TargetTransparency", target)
		instance.BackgroundTransparency = 1
		props.BackgroundTransparency = target
	end
	task.delay(delaySeconds, function()
		if instance and instance.Parent then
			Tween.play(instance, props, nil, Theme.tweenInfo(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
		end
	end)
end

return Tween
