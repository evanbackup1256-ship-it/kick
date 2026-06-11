local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.theme)

local Tween = {}

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

	local tween
	local ok = pcall(function()
		tween = TweenService:Create(instance, info or Theme.tweenInfo(), goal)
	end)
	if ok and tween then
		if callback then
			tween.Completed:Once(callback)
		end
		tween:Play()
	end
	return tween
end

function Tween.fade(instance, visible, callback)
	local props = {}
	if instance:IsA("GuiObject") then
		props.BackgroundTransparency = visible and (instance:GetAttribute("TargetTransparency") or 0) or 1
	end
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		props.TextTransparency = visible and 0 or 1
	end
	if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		props.ImageTransparency = visible and 0 or 1
	end
	return Tween.play(instance, props, callback, Theme.tweenInfo(0.2))
end

return Tween
