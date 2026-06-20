-- Alleral_Animations
local Animations = { VERSION = "1.0.0" }
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

function Animations.create(instance, properties, style, direction, duration)
	style = style or Enum.EasingStyle.Quad
	direction = direction or Enum.EasingDirection.Out
	duration = duration or 0.3
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style, direction), properties)
	tween:Play()
	return tween
end

function Animations.spring(target, current, goal, speed)
	speed = speed or 8
	local diff = goal - current
	local step = diff * (1 - math.exp(-speed * (tick() - (target._lastTick or tick()))))
	target._lastTick = tick()
	local value = current + step
	if math.abs(value - goal) < 0.001 then
		return goal, true
	end
	return value, false
end

function Animations.buttonHover(button)
	local ts = TweenService
	local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local hoverIn = ts:Create(button, info, {
		Scale = UDim2.new(1.025, 0, 1.025, 0),
	})
	local hoverOut = ts:Create(button, info, {
		Scale = UDim2.new(1, 0, 1, 0),
	})
	local clickIn = ts:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = UDim2.new(0.98, 0, 0.98, 0),
	})
	local clickOut = ts:Create(button, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = UDim2.new(1.025, 0, 1.025, 0),
	})
	local function onHover()
		hoverOut:Cancel()
		hoverIn:Play()
	end
	local function onHoverEnd()
		hoverIn:Cancel()
		hoverOut:Play()
	end
	local function onPress()
		hoverIn:Cancel()
		clickIn:Play()
	end
	local function onRelease()
		clickIn:Cancel()
		clickOut:Play()
	end
	return onHover, onHoverEnd, onPress, onRelease
end

function Animations.dropdown(frame, content, open, duration)
	duration = duration or 0.25
	local ts = TweenService
	if open then
		frame.Visible = true
		local targetHeight = content.AbsoluteContentSize.Y
		local expand = ts:Create(frame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 0, targetHeight + 12),
		})
		expand:Play()
		if content:FindFirstChildOfClass("UIListLayout") then
			local children = content:GetChildren()
			for i, child in ipairs(children) do
				if child:IsA("GuiObject") then
					child.Visible = true
					local fade = ts:Create(child, TweenInfo.new(duration * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Position = UDim2.new(0, 0, 0, (i - 1) * 28),
					})
					fade:Play()
				end
			end
		end
		return expand
	else
		local collapse = ts:Create(frame, TweenInfo.new(duration * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(1, 0, 0, 0),
		})
		collapse:Play()
		collapse.Completed:Connect(function()
			frame.Visible = false
		end)
		return collapse
	end
end

function Animations.fadeIn(guiObject, duration)
	duration = duration or 0.2
	guiObject.Visible = true
	return Animations.create(guiObject, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, duration)
end

function Animations.fadeOut(guiObject, duration)
	duration = duration or 0.15
	local tween = Animations.create(guiObject, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, duration)
	tween.Completed:Connect(function()
		guiObject.Visible = false
	end)
	return tween
end

function Animations.slideIn(guiObject, offset, duration)
	duration = duration or 0.3
	local startPos = guiObject.Position
	local goal = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale, startPos.Y.Offset + offset)
	guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale, startPos.Y.Offset - offset)
	guiObject.Visible = true
	return Animations.create(guiObject, { Position = goal }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, duration)
end

function Animations.scaleIn(guiObject, duration)
	duration = duration or 0.2
	guiObject.Visible = true
	local startScale = guiObject.Scale
	guiObject.Scale = UDim2.new(0.95, 0, 0.95, 0)
	local tween = Animations.create(guiObject, { Scale = startScale }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, duration)
	return tween
end

function Animations.slideToggle(thumb, on, duration)
	duration = duration or 0.2
	local goalX = on and 18 or 2
	return Animations.create(thumb, { Position = UDim2.new(0, goalX, 0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, duration)
end

function Animations.sliderThumb(thumb, position, duration)
	duration = duration or 0.15
	return Animations.create(thumb, { Position = UDim2.new(position, 0, 0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, duration)
end

function Animations.sliderFill(fill, size, duration)
	duration = duration or 0.15
	return Animations.create(fill, { Size = UDim2.new(size, 0, 1, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, duration)
end

function Animations.tabSwitch(content, direction)
	direction = direction or 1
	local duration = 0.2
	local offset = 30 * direction
	local startPos = content.Position
	content.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + offset, startPos.Y.Scale, startPos.Y.Offset)
	local tween = Animations.create(content, { Position = startPos }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, duration)
	return tween
end

function Animations.notificationSlide(guiObject, from, to, duration)
	duration = duration or 0.3
	guiObject.Position = from
	guiObject.Visible = true
	return Animations.create(guiObject, { Position = to }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, duration)
end

if getgenv then getgenv().Alleral_Animations = Animations end
return Animations
