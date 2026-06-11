local UserInputService = game:GetService("UserInputService")
local Util = require(script.Parent.util)
local Theme = require(script.Parent.theme)
local Tween = require(script.Parent.tween)

local Elements = {}

function Elements.runCallback(windowSettings, label, callback, library)
	local ok, err = pcall(callback)
	if not ok and windowSettings.NotifyOnCallbackError ~= false then
		warn("[Starlight] Callback error:", err)
		if library and library.Notification then
			library:Notification({
				Title = label .. " Error",
				Content = tostring(err),
				Icon = 6031075938,
			})
		end
	end
	return ok, err
end

function Elements.createRow(parent, settings, theme)
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local height = Theme.Visual.CompactMode and 34 or 38
	local row = Util.new("Frame", {
		Name = settings.Name or "Row",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = settings.LayoutOrder or 0,
	}, { parent })

	local label = Util.text({
		Parent = row,
		Text = settings.Name or "",
		FontWeight = Enum.FontWeight.Medium,
		TextSize = 13 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Label,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, -120, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	label.Name = "Header"

	if not Util.isEmpty(settings.Icon) then
		Util.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Util.iconAsset(settings.Icon),
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromOffset(0, 12),
			ImageColor3 = theme.Foregrounds.Light,
			ImageTransparency = transp.Label,
		}, { row })
		label.Position = UDim2.fromOffset(20, 0.5)
		label.Size = UDim2.new(1, -140, 0, 0)
	end

	local slot = Util.new("Frame", {
		Name = "ElementContainer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(120, 26),
	}, { row })

	local dropdownHolder = Util.new("Frame", {
		Name = "DropdownHolder",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 1, 4),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = true,
	}, { row })
	Util.list(6, false, dropdownHolder)

	return row, label, slot, dropdownHolder
end

function Elements.animateRowEntrance(label, index)
	if label then
		Tween.entrance(label, (index or 0) * 0.028)
	end
end

function Elements.glassBox(parent, theme, size)
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local box = Util.new("Frame", {
		BackgroundColor3 = theme.Backgrounds.Light,
		BackgroundTransparency = transp.Input,
		Size = size or UDim2.fromScale(1, 1),
	}, { parent })
	Util.corner(4, box)
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, box)
	return box
end

function Elements.createToggle(groupbox, settings, index, windowSettings, library)
	local theme = Theme.current()
	local element = { Class = "Toggle", Values = settings, NestedElements = {} }
	settings.CurrentValue = settings.CurrentValue == true
	settings.Callback = settings.Callback or function() end
	settings.LayoutOrder = settings.LayoutOrder or index

	local row, label, slot = Elements.createRow(groupbox.ParentingItem, settings, theme)
	element.Instance = row
	Elements.animateRowEntrance(label, index)

	local toggleBtn = Util.new("ImageButton", {
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(41, 21),
		BackgroundTransparency = 1,
		Image = Theme.Assets.ToggleBackground,
		ImageColor3 = theme.Miscellaneous.ToggleOff,
	}, { slot })

	local toggleScale = Instance.new("UIScale")
	toggleScale.Scale = 1
	toggleScale.Parent = toggleBtn

	local head = Util.new("ImageLabel", {
		Name = "TogglerHead",
		BackgroundTransparency = 1,
		Image = Theme.Assets.ToggleHead,
		ImageColor3 = theme.Miscellaneous.ToggleHeadOff,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(15, 15),
		ZIndex = 2,
	}, { toggleBtn })

	local function paint(on, instant)
		local trackColor = on and theme.Miscellaneous.ToggleOn or theme.Miscellaneous.ToggleOff
		local headColor = on and theme.Miscellaneous.ToggleHeadOn or theme.Miscellaneous.ToggleHeadOff
		local headPos = on and UDim2.new(1, -10, 0.5, 0) or UDim2.new(0, 10, 0.5, 0)
		if instant then
			toggleBtn.ImageColor3 = trackColor
			head.ImageColor3 = headColor
			head.Position = headPos
			return
		end
		Tween.play(toggleBtn, { ImageColor3 = trackColor }, nil, Theme.motion(0.22))
		Tween.play(head, {
			ImageColor3 = headColor,
			Position = headPos,
		}, nil, Theme.motionSpring(0.28))
		Tween.play(toggleScale, { Scale = 1.06 }, function()
			Tween.play(toggleScale, { Scale = 1 }, nil, Theme.motionSnap(0.14))
		end, Theme.motionSnap(0.1))
	end
	paint(settings.CurrentValue, true)

	toggleBtn.MouseEnter:Connect(function()
		Tween.play(toggleScale, { Scale = 1.04 }, nil, Theme.motionSnap(0.12))
	end)
	toggleBtn.MouseLeave:Connect(function()
		Tween.play(toggleScale, { Scale = 1 }, nil, Theme.motionSnap(0.12))
	end)
	toggleBtn.MouseButton1Click:Connect(function()
		settings.CurrentValue = not settings.CurrentValue
		paint(settings.CurrentValue, false)
		Elements.runCallback(windowSettings, settings.Name or "Toggle", function()
			settings.Callback(settings.CurrentValue)
		end, library)
	end)

	function element:Set(newSettings)
		for key, value in pairs(element.Values) do
			newSettings[key] = newSettings[key] ~= nil and newSettings[key] or value
		end
		element.Values = newSettings
		settings = newSettings
		label.Text = settings.Name or label.Text
		paint(settings.CurrentValue == true, false)
	end
	function element:Destroy()
		row:Destroy()
	end

	groupbox.Elements[index] = element
	return element
end

function Elements.createSlider(groupbox, settings, index, windowSettings, library)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local element = { Class = "Slider", Values = settings, NestedElements = {} }
	local minValue = settings.Range and settings.Range[1] or 0
	local maxValue = settings.Range and settings.Range[2] or 100
	local increment = settings.Increment or 1
	settings.CurrentValue = Util.clamp(settings.CurrentValue or minValue, minValue, maxValue)
	settings.LayoutOrder = settings.LayoutOrder or index

	local function snapValue(raw)
		local steps = math.floor((raw - minValue) / increment + 0.5)
		return Util.clamp(minValue + steps * increment, minValue, maxValue)
	end

	local row, label, slot = Elements.createRow(groupbox.ParentingItem, settings, theme)
	element.Instance = row
	slot.Size = UDim2.fromOffset(150, 26)
	Elements.animateRowEntrance(label, index)

	local valueScale = Instance.new("UIScale")
	valueScale.Scale = 1

	local valueBox = Util.new("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(41, 21),
		BackgroundColor3 = theme.Backgrounds.Light,
		BackgroundTransparency = transp.Input,
		BorderSizePixel = 0,
		FontFace = Util.fontFace(Enum.FontWeight.Medium),
		Text = tostring(settings.CurrentValue),
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = 0.4,
		TextSize = 12 * Theme.Visual.FontScale,
		ClearTextOnFocus = false,
	}, { slot })
	valueScale.Parent = valueBox
	Util.corner(4, valueBox)
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, valueBox)

	local bar = Util.new("Frame", {
		BackgroundColor3 = theme.Miscellaneous.ToggleOff,
		Size = UDim2.new(1, -48, 0, 4),
		Position = UDim2.new(0, 0, 0.5, -2),
	}, { slot })
	Util.corner(999, bar)

	local fill = Util.new("Frame", {
		BackgroundColor3 = theme.Miscellaneous.ToggleOn,
		BackgroundTransparency = 0.15,
		Size = UDim2.new(0, 0, 1, 0),
	}, { bar })
	Util.corner(999, fill)

	local thumb = Util.new("Frame", {
		Name = "Thumb",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Foregrounds.Light,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		ZIndex = 4,
	}, { bar })
	Util.corner(999, thumb)
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, 0.35, thumb)

	local thumbScale = Instance.new("UIScale")
	thumbScale.Scale = 1
	thumbScale.Parent = thumb

	local dragging = false
	local function applyVisuals(alpha, animate)
		local fillGoal = UDim2.new(alpha, 0, 1, 0)
		local thumbGoal = UDim2.new(alpha, 0, 0.5, 0)
		if dragging or not animate then
			fill.Size = fillGoal
			thumb.Position = thumbGoal
		else
			Tween.play(fill, { Size = fillGoal }, nil, Theme.motion(0.2))
			Tween.play(thumb, { Position = thumbGoal }, nil, Theme.motionSpring(0.24))
		end
	end

	local function pulseValue()
		Tween.play(valueScale, { Scale = 1.08 }, function()
			Tween.play(valueScale, { Scale = 1 }, nil, Theme.motionSnap(0.12))
		end, Theme.motionSnap(0.08))
	end

	local function setValue(raw, fire, animate)
		local previous = settings.CurrentValue
		settings.CurrentValue = snapValue(raw)
		local alpha = (settings.CurrentValue - minValue) / math.max(maxValue - minValue, increment)
		applyVisuals(alpha, animate ~= false and not dragging)
		valueBox.Text = tostring(settings.CurrentValue)
		if previous ~= settings.CurrentValue then
			pulseValue()
		end
		if fire and settings.Callback then
			Elements.runCallback(windowSettings, settings.Name or "Slider", function()
				settings.Callback(settings.CurrentValue)
			end, library)
		end
	end
	setValue(settings.CurrentValue, false, false)

	local hit = Util.button({
		Parent = bar,
		Size = UDim2.new(1, 0, 12, 0),
		Position = UDim2.new(0, 0, 0.5, -6),
		BackgroundTransparency = 1,
		Radius = 999,
	})
	hit.ZIndex = 3
	hit.MouseEnter:Connect(function()
		if not dragging then
			Tween.play(bar, { Size = UDim2.new(1, -48, 0, 5) }, nil, Theme.motionSnap(0.12))
		end
	end)
	hit.MouseLeave:Connect(function()
		if not dragging then
			Tween.play(bar, { Size = UDim2.new(1, -48, 0, 4) }, nil, Theme.motionSnap(0.12))
			Tween.play(thumbScale, { Scale = 1 }, nil, Theme.motionSnap(0.12))
		end
	end)
	hit.MouseButton1Down:Connect(function()
		dragging = true
		Tween.play(thumbScale, { Scale = 1.35 }, nil, Theme.motionSnap(0.1))
		Tween.play(fill, { BackgroundTransparency = 0 }, nil, Theme.motionSnap(0.12))
		local mouse = UserInputService:GetMouseLocation()
		local rel = Util.clamp((mouse.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		setValue(minValue + (maxValue - minValue) * rel, true, false)
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			setValue(settings.CurrentValue, true, true)
			dragging = false
			Tween.play(thumbScale, { Scale = 1 }, nil, Theme.motionSpring(0.18))
			Tween.play(fill, { BackgroundTransparency = 0.15 }, nil, Theme.motion(0.16))
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local rel = Util.clamp((input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
			setValue(minValue + (maxValue - minValue) * rel, false, false)
		end
	end)

	function element:Set(newSettings)
		for key, value in pairs(element.Values) do
			newSettings[key] = newSettings[key] ~= nil and newSettings[key] or value
		end
		element.Values = newSettings
		settings = newSettings
		if newSettings.Range then
			minValue = settings.Range[1] or minValue
			maxValue = settings.Range[2] or maxValue
		end
		if newSettings.Increment then
			increment = newSettings.Increment
		end
		label.Text = settings.Name or label.Text
		setValue(settings.CurrentValue, false, true)
	end
	function element:Destroy()
		row:Destroy()
	end

	groupbox.Elements[index] = element
	return element
end

function Elements.createButton(groupbox, settings, index, windowSettings, library)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local element = { Class = "Button", Values = settings, NestedElements = {} }

	local row = Util.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Theme.Visual.CompactMode and 34 or 38),
		LayoutOrder = settings.LayoutOrder or index,
	}, { groupbox.ParentingItem })
	element.Instance = row

	local btn = Util.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = theme.Backgrounds.Light,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	}, { row })
	Util.corner(6, btn)

	local label = Util.text({
		Parent = btn,
		Text = settings.Name or "Button",
		FontWeight = Enum.FontWeight.Medium,
		TextSize = 13 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Label,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -20, 1, 0),
	})

	Util.new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Theme.Assets.ButtonArrow,
		ImageTransparency = transp.Label,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(15, 15),
	}, { btn })
	Elements.animateRowEntrance(label, index)

	btn.MouseEnter:Connect(function()
		Tween.play(btn, { BackgroundTransparency = transp.Input }, nil, Theme.motionSnap(0.14))
		Tween.play(label, { TextTransparency = transp.LabelHover }, nil, Theme.motionSnap(0.14))
	end)
	btn.MouseLeave:Connect(function()
		Tween.play(btn, { BackgroundTransparency = 1 }, nil, Theme.motionSnap(0.14))
		Tween.play(label, { TextTransparency = transp.Label }, nil, Theme.motionSnap(0.14))
	end)
	btn.MouseButton1Down:Connect(function()
		Tween.play(btn, { Size = UDim2.new(1, -4, 1, -2) }, nil, Theme.motionSnap(0.08))
	end)
	btn.MouseButton1Up:Connect(function()
		Tween.play(btn, { Size = UDim2.fromScale(1, 1) }, nil, Theme.motionSpring(0.14))
	end)
	btn.MouseButton1Click:Connect(function()
		Elements.runCallback(windowSettings, settings.Name or "Button", settings.Callback or function() end, library)
	end)

	function element:Set(newSettings)
		element.Values = Util.merge(element.Values, newSettings)
		label.Text = element.Values.Name or "Button"
	end
	function element:Destroy()
		row:Destroy()
	end
	groupbox.Elements[index] = element
	return element
end

function Elements.createInput(groupbox, settings, index, windowSettings, library)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local element = { Class = "Input", Values = settings, NestedElements = {} }
	settings.CurrentValue = settings.CurrentValue or settings.Placeholder or ""
	settings.LayoutOrder = settings.LayoutOrder or index

	local row, label, slot = Elements.createRow(groupbox.ParentingItem, settings, theme)
	element.Instance = row
	slot.Size = UDim2.fromOffset(160, 26)
	Elements.animateRowEntrance(label, index)

	local box = Util.inputBox({
		Parent = slot,
		BackgroundColor3 = theme.Backgrounds.Light,
		BackgroundTransparency = transp.Input,
		PlaceholderText = settings.PlaceholderText or settings.Placeholder or "",
		Text = settings.CurrentValue,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = 0.4,
		TextSize = 13 * Theme.Visual.FontScale,
		ClearTextOnFocus = settings.RemoveTextOnFocus == true,
		Radius = 4,
	})
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, box)
	Util.padding(0, 8, 0, 8, box)
	local inputStroke = box:FindFirstChildOfClass("UIStroke")

	box.Focused:Connect(function()
		Tween.play(box, { BackgroundTransparency = math.max(0, transp.Input - 0.06) }, nil, Theme.motionSnap(0.14))
		if inputStroke then
			Tween.play(inputStroke, { Transparency = math.max(0, transp.Stroke - 0.25) }, nil, Theme.motionSnap(0.14))
		end
	end)
	box.FocusLost:Connect(function()
		Tween.play(box, { BackgroundTransparency = transp.Input }, nil, Theme.motion(0.16))
		if inputStroke then
			Tween.play(inputStroke, { Transparency = transp.Stroke }, nil, Theme.motion(0.16))
		end
		settings.CurrentValue = box.Text
		Elements.runCallback(windowSettings, settings.Name or "Input", function()
			settings.Callback(settings.CurrentValue)
		end, library)
	end)

	function element:Set(newSettings)
		element.Values = Util.merge(element.Values, newSettings)
		label.Text = element.Values.Name or label.Text
		if newSettings.CurrentValue ~= nil then
			box.Text = newSettings.CurrentValue
		end
	end
	function element:Destroy()
		row:Destroy()
	end
	groupbox.Elements[index] = element
	return element
end

function Elements.createLabel(groupbox, settings, index, windowSettings, library)
	local theme = Theme.current()
	local element = { Class = "Label", Values = settings, NestedElements = {} }
	settings.LayoutOrder = settings.LayoutOrder or index
	local row, label, slot, dropdownHolder = Elements.createRow(groupbox.ParentingItem, settings, theme)
	element.Instance = row
	slot.Visible = false
	slot.Size = UDim2.fromOffset(0, 0)

	function element:Set(newSettings)
		element.Values = Util.merge(element.Values, newSettings)
		label.Text = element.Values.Name or ""
	end
	function element:Destroy()
		row:Destroy()
	end
	function element:Lock(reason)
		label.Text = reason or element.Values.Name or ""
	end
	function element:Unlock()
		label.Text = element.Values.Name or ""
	end
	function element:AddDropdown(nestedSettings, nestedIndex)
		return Elements.createDropdown(groupbox, nestedSettings, nestedIndex or #element.NestedElements + 1, windowSettings, element, dropdownHolder, library)
	end
	function element:AddBind(nestedSettings, nestedIndex)
		slot.Visible = true
		slot.Size = UDim2.fromOffset(80, 24)
		return Elements.createBind(groupbox, nestedSettings, nestedIndex or #element.NestedElements + 1, windowSettings, element, slot, library)
	end
	function element:AddColorPicker(nestedSettings, nestedIndex)
		slot.Visible = true
		slot.Size = UDim2.fromOffset(24, 24)
		return Elements.createColorPicker(groupbox, nestedSettings, nestedIndex or #element.NestedElements + 1, windowSettings, element, slot, library)
	end

	groupbox.Elements[index] = element
	return element
end

function Elements.createDivider(groupbox)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local line = Util.new("Frame", {
		BackgroundColor3 = theme.Miscellaneous.Divider,
		BackgroundTransparency = transp.Divider,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
	}, { groupbox.ParentingItem })
	return {
		Class = "Divider",
		Instance = line,
		Destroy = function()
			line:Destroy()
		end,
	}
end

function Elements.createParagraph(groupbox, settings, index)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local element = { Class = "Paragraph", Values = settings, NestedElements = {} }
	local frame = Util.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, { groupbox.ParentingItem })
	Util.list(4, false, frame)
	Util.text({
		Parent = frame,
		Text = settings.Name or settings.Title or "",
		FontWeight = Enum.FontWeight.SemiBold,
		TextSize = 16 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Tab,
	})
	Util.text({
		Parent = frame,
		Text = settings.Content or settings.Description or "",
		TextWrapped = true,
		TextSize = 13 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Subtitle,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	element.Instance = frame
	function element:Set(newSettings)
		element.Values = Util.merge(element.Values, newSettings)
	end
	function element:Destroy()
		frame:Destroy()
	end
	groupbox.Elements[index] = element
	return element
end

function Elements.createDropdown(groupbox, settings, index, windowSettings, parentElement, holderOverride, library)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local element = { Class = "Dropdown", Values = settings, NestedElements = {} }
	settings.Options = settings.Options or settings.Values or {}
	settings.Callback = settings.Callback or function() end
	settings.Multi = settings.Multi == true or settings.MultiSelection == true or settings.MultipleOptions == true
	settings.LayoutOrder = settings.LayoutOrder or index
	settings.Placeholder = settings.Placeholder or "--"
	if settings.Multi then
		settings.CurrentOptions = settings.CurrentOptions or settings.CurrentOption or settings.Default or {}
		if type(settings.CurrentOptions) ~= "table" then
			settings.CurrentOptions = { settings.CurrentOptions }
		end
		if type(settings.CurrentOption) == "table" and settings.CurrentOptions ~= settings.CurrentOption then
			settings.CurrentOptions = settings.CurrentOption
		end
	else
		settings.CurrentOption = settings.CurrentOption or settings.Default or settings.Options[1] or ""
	end

	local parentFrame
	local rowLabel
	if not holderOverride then
		local row, label, slot = Elements.createRow(groupbox.ParentingItem, settings, theme)
		rowLabel = label
		element.Instance = row
		parentFrame = slot
		parentFrame.Size = UDim2.fromOffset(160, 26)
	else
		local wrapper = Util.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 32),
		}, { holderOverride })
		parentFrame = wrapper
		element.Instance = wrapper
	end

	local closed = Util.button({
		Parent = parentFrame,
		BackgroundColor3 = theme.Backgrounds.Light,
		BackgroundTransparency = transp.Input,
		Size = UDim2.fromScale(1, 1),
		Radius = 4,
	})
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, closed)

	local chevron = Util.new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Theme.Assets.ButtonArrow,
		ImageTransparency = 0.45,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Rotation = 90,
		Size = UDim2.fromOffset(12, 12),
	}, { closed })

	local valueText = Util.text({
		Parent = closed,
		Text = "",
		TextSize = 12 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = 0.4,
		Size = UDim2.new(1, -24, 1, 0),
	})
	Util.padding(0, 8, 0, 8, closed)

	local popupRoot = library and (library._screenGui or library._popupRoot) or parentFrame
	local popup = Util.new("ScrollingFrame", {
		Name = "DropdownPopup",
		BackgroundColor3 = theme.Backgrounds.Dark,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(200, 180),
		Position = UDim2.fromOffset(0, 0),
		Visible = false,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 1,
		ScrollBarImageTransparency = 0.5,
		ZIndex = 300,
		ClipsDescendants = true,
	}, { popupRoot })
	Util.corner(6, popup)
	local popupLayout = Util.list(2, false, popup)
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, popup)
	Util.padding(4, 4, 4, 4, popup)

	local popupScale = Instance.new("UIScale")
	popupScale.Scale = 0.94
	popupScale.Parent = popup

	local openDropdowns = library and library._openDropdowns
	if not openDropdowns and library then
		openDropdowns = {}
		library._openDropdowns = openDropdowns
	end

	local function positionPopup()
		local anchor = closed.AbsolutePosition
		local size = closed.AbsoluteSize
		popup.Size = UDim2.fromOffset(math.max(size.X, 200), 180)
		popup.Position = UDim2.fromOffset(anchor.X, anchor.Y + size.Y + 4)
	end

	local function closePopup(instant)
		if instant then
			popup.Visible = false
			popupScale.Scale = 0.94
			chevron.Rotation = 90
		else
			Tween.play(popupScale, { Scale = 0.94 }, nil, Theme.motionSnap(0.1))
			Tween.play(chevron, { Rotation = 90 }, nil, Theme.motionSnap(0.14))
			Tween.play(popup, { BackgroundTransparency = 1 }, function()
				popup.Visible = false
			end, Theme.motionSnap(0.12))
		end
		if openDropdowns then
			openDropdowns[popup] = nil
		end
	end

	local function openPopup()
		if openDropdowns then
			for other in pairs(openDropdowns) do
				if other ~= popup and other.Parent then
					other.Visible = false
				end
			end
			for key in pairs(openDropdowns) do
				openDropdowns[key] = nil
			end
			openDropdowns[popup] = true
		end
		positionPopup()
		popup.BackgroundTransparency = 1
		popup.Visible = true
		popupScale.Scale = 0.92
		Tween.play(popupScale, { Scale = 1 }, nil, Theme.motionSpring(0.22))
		Tween.play(popup, { BackgroundTransparency = 0 }, nil, Theme.motion(0.18))
		Tween.play(chevron, { Rotation = -90 }, nil, Theme.motionSpring(0.2))
	end

	local function displayValue()
		if settings.Multi then
			valueText.Text = #settings.CurrentOptions == 0 and settings.Placeholder
				or table.concat(settings.CurrentOptions, ", ")
		else
			local text = tostring(settings.CurrentOption or "")
			valueText.Text = (text == "" and settings.Placeholder) or text
		end
	end

	local function rebuildOptions(filtered)
		for _, child in ipairs(popup:GetChildren()) do
			if child:IsA("GuiObject") and child.Name == "Option" then
				child:Destroy()
			end
		end
		local options = filtered or settings.Options
		for i, option in ipairs(options) do
			local selected = settings.Multi
				and table.find(settings.CurrentOptions, option) ~= nil
				or settings.CurrentOption == option
			local opt = Util.button({
				Name = "Option",
				Parent = popup,
				BackgroundColor3 = theme.Backgrounds.Light,
				BackgroundTransparency = selected and 0.9 or 0.98,
				Size = UDim2.new(1, -4, 0, 28),
				Radius = 4,
			})
			opt.ZIndex = popup.ZIndex + 1
			opt.LayoutOrder = i
			Util.text({
				Parent = opt,
				Text = tostring(option),
				TextSize = 12 * Theme.Visual.FontScale,
				TextColor3 = theme.Foregrounds.Light,
				TextTransparency = selected and 0.2 or 0.5,
				Size = UDim2.fromScale(1, 1),
			})
			opt.MouseEnter:Connect(function()
				Tween.play(opt, { BackgroundTransparency = selected and 0.82 or 0.9 }, nil, Theme.motionSnap(0.1))
			end)
			opt.MouseLeave:Connect(function()
				Tween.play(opt, { BackgroundTransparency = selected and 0.9 or 0.98 }, nil, Theme.motionSnap(0.1))
			end)
			opt.MouseButton1Click:Connect(function()
				if settings.Multi then
					local found = table.find(settings.CurrentOptions, option)
					if found then
						table.remove(settings.CurrentOptions, found)
					else
						table.insert(settings.CurrentOptions, option)
					end
					Elements.runCallback(windowSettings, settings.Name or "Dropdown", function()
						settings.Callback(settings.CurrentOptions)
					end, library)
					displayValue()
					rebuildOptions(filtered)
				else
					settings.CurrentOption = option
					closePopup()
					Elements.runCallback(windowSettings, settings.Name or "Dropdown", function()
						settings.Callback(option)
					end, library)
					displayValue()
				end
			end)
		end
		task.defer(function()
			popup.CanvasSize = UDim2.new(0, 0, 0, popupLayout.AbsoluteContentSize.Y + 8)
		end)
	end

	displayValue()
	rebuildOptions()
	if rowLabel then
		Elements.animateRowEntrance(rowLabel, index)
	end

	closed.MouseEnter:Connect(function()
		Tween.play(closed, { BackgroundTransparency = math.max(0, transp.Input - 0.04) }, nil, Theme.motionSnap(0.12))
	end)
	closed.MouseLeave:Connect(function()
		if not popup.Visible then
			Tween.play(closed, { BackgroundTransparency = transp.Input }, nil, Theme.motionSnap(0.12))
		end
	end)
	closed.MouseButton1Click:Connect(function()
		if popup.Visible then
			closePopup()
		else
			openPopup()
		end
	end)

	if library and library._screenGui then
		library._screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if popup.Visible then
				positionPopup()
			end
		end)
	end

	local dismissConnection
	dismissConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if not popup.Visible or processed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local pos = input.Position
		local function inside(gui)
			if not gui or not gui.Visible then
				return false
			end
			local ap, sz = gui.AbsolutePosition, gui.AbsoluteSize
			return pos.X >= ap.X and pos.X <= ap.X + sz.X and pos.Y >= ap.Y and pos.Y <= ap.Y + sz.Y
		end
		if not inside(closed) and not inside(popup) then
			closePopup()
		end
	end)
	element._dismissConnection = dismissConnection

	function element:Set(newSettings)
		element.Values = Util.merge(element.Values, newSettings)
		settings = element.Values
		if newSettings.Options or newSettings.Values then
			settings.Options = newSettings.Options or newSettings.Values
		end
		if newSettings.MultipleOptions ~= nil then
			settings.Multi = newSettings.MultipleOptions == true
		end
		if newSettings.CurrentOption ~= nil then
			if settings.Multi and type(newSettings.CurrentOption) == "table" then
				settings.CurrentOptions = newSettings.CurrentOption
			else
				settings.CurrentOption = newSettings.CurrentOption
			end
		end
		if newSettings.CurrentOptions ~= nil then
			settings.CurrentOptions = newSettings.CurrentOptions
		end
		if newSettings.Callback then
			settings.Callback = newSettings.Callback
		end
		if rowLabel then
			rowLabel.Text = settings.Name or rowLabel.Text
		end
		displayValue()
		rebuildOptions(newSettings.Options or newSettings.Values)
	end
	function element:SetValues(newValues, newDefault)
		settings.Options = newValues or settings.Options
		if settings.Multi then
			settings.CurrentOptions = type(newDefault) == "table" and newDefault or settings.CurrentOptions
		else
			settings.CurrentOption = newDefault or settings.CurrentOption
		end
		element:Set({
			Options = settings.Options,
			CurrentOption = settings.CurrentOption,
			CurrentOptions = settings.CurrentOptions,
		})
	end
	function element:Refresh(newValues, newDefault)
		self:SetValues(newValues, newDefault)
	end
	function element:Search(query)
		local needle = tostring(query or ""):lower()
		if needle == "" then
			rebuildOptions()
			return
		end
		local filtered = {}
		for _, option in ipairs(settings.Options) do
			if tostring(option):lower():find(needle, 1, true) then
				table.insert(filtered, option)
			end
		end
		rebuildOptions(filtered)
	end
	function element:Destroy()
		if element._dismissConnection then
			element._dismissConnection:Disconnect()
		end
		if popup and popup.Parent then
			popup:Destroy()
		end
		if element.Instance then
			element.Instance:Destroy()
		end
	end

	if parentElement then
		parentElement.NestedElements[index] = element
	else
		groupbox.Elements[index] = element
	end
	return element
end

function Elements.createBind(groupbox, settings, index, windowSettings, parentElement, slot)
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	local element = { Class = "Bind", Values = settings, NestedElements = {} }
	settings.CurrentValue = settings.CurrentValue or "None"
	local bindButton = Util.button({
		Parent = slot or groupbox.ParentingItem,
		BackgroundColor3 = theme.Backgrounds.Light,
		BackgroundTransparency = transp.Input,
		Size = UDim2.fromOffset(80, 24),
		Radius = 4,
	})
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, bindButton)
	element.Instance = bindButton
	Util.text({
		Parent = bindButton,
		Text = tostring(settings.CurrentValue),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
	})
	local listening = false
	bindButton.MouseButton1Click:Connect(function()
		listening = true
		bindButton:FindFirstChildOfClass("TextLabel").Text = "..."
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not listening or processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			settings.CurrentValue = input.KeyCode.Name
			listening = false
			bindButton:FindFirstChildOfClass("TextLabel").Text = settings.CurrentValue
			if settings.OnChangedCallback then
				settings.OnChangedCallback(settings.CurrentValue)
			end
		end
	end)
	parentElement.NestedElements[index] = element
	return element
end

function Elements.createColorPicker(groupbox, settings, index, windowSettings, parentElement, slot)
	local theme = Theme.current()
	local element = { Class = "ColorPicker", Values = settings, NestedElements = {} }
	settings.CurrentValue = settings.CurrentValue or Color3.fromRGB(255, 255, 255)
	settings.Transparency = settings.Transparency or 0
	local swatch = Util.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = settings.CurrentValue,
		BackgroundTransparency = settings.Transparency,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(24, 24),
		Text = "",
	}, { slot or groupbox.ParentingItem })
	Util.corner(6, swatch)
	element.Instance = swatch
	swatch.MouseButton1Click:Connect(function()
		local presets = {
			Color3.fromRGB(76, 110, 245),
			Color3.fromRGB(72, 199, 142),
			Color3.fromRGB(255, 184, 77),
			Color3.fromRGB(255, 96, 112),
			Color3.fromRGB(168, 85, 247),
		}
		local nextIndex = (table.find(presets, settings.CurrentValue) or 0) % #presets + 1
		settings.CurrentValue = presets[nextIndex]
		swatch.BackgroundColor3 = settings.CurrentValue
		if settings.Callback then
			settings.Callback(settings.CurrentValue, settings.Transparency)
		end
	end)
	parentElement.NestedElements[index] = element
	return element
end

return Elements
