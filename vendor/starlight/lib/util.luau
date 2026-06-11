local Util = {}

function Util.deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = Util.deepCopy(child)
	end
	return copy
end

function Util.clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

function Util.isEmpty(text)
	return text == nil or tostring(text) == ""
end

function Util.trim(text)
	return tostring(text or ""):gsub("^%s*(.-)%s*$", "%1")
end

function Util.iconAsset(icon)
	if Util.isEmpty(icon) then
		return ""
	end
	local text = tostring(icon)
	if text:find("rbxassetid://") then
		return text
	end
	local digits = text:match("%d+$")
	return digits and ("rbxassetid://" .. digits) or text
end

function Util.safeCall(label, callback, onError)
	local ok, result = pcall(callback)
	if not ok and onError then
		onError(label, result)
	end
	return ok, result
end

function Util.merge(base, overrides)
	local merged = Util.deepCopy(base)
	for key, value in pairs(overrides or {}) do
		merged[key] = value
	end
	return merged
end

function Util.new(className, props, children)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		if typeof(child) == "Instance" then
			child.Parent = instance
		end
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Util.corner(radius, parent)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function Util.padding(top, right, bottom, left, parent)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, top)
	pad.PaddingRight = UDim.new(0, right or top)
	pad.PaddingBottom = UDim.new(0, bottom or top)
	pad.PaddingLeft = UDim.new(0, left or right or top)
	pad.Parent = parent
	return pad
end

function Util.stroke(color, thickness, transparency, parent)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Util.gradient(colorSequence, rotation, parent)
	local gradient = Instance.new("UIGradient")
	gradient.Color = colorSequence
	gradient.Rotation = rotation or 0
	gradient.Parent = parent
	return gradient
end

function Util.list(padding, horizontal, parent)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding or 6)
	layout.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function Util.fontFace(weight)
	weight = weight or Enum.FontWeight.Medium
	local ok, font = pcall(function()
		return Font.new("rbxassetid://12187365364", weight)
	end)
	if ok and font then
		return font
	end
	if weight == Enum.FontWeight.SemiBold or weight == Enum.FontWeight.Bold then
		return Enum.Font.GothamBold
	end
	return Enum.Font.GothamMedium
end

function Util.divider(parent, theme, layoutOrder)
	local t = theme and theme.Transparency
	return Util.new("Frame", {
		BackgroundColor3 = (theme and theme.Miscellaneous.Divider) or Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = (t and t.Divider) or 0.9,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = layoutOrder,
	}, { parent })
end

function Util.text(props)
	local label = Util.new("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = props.FontFace or Util.fontFace(props.FontWeight or Enum.FontWeight.Medium),
		Font = props.Font,
		Text = props.Text or "",
		TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255),
		TextTransparency = props.TextTransparency or 0,
		TextSize = props.TextSize or 14,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		TextWrapped = props.TextWrapped == true,
		TextTruncate = props.TextTruncate,
		RichText = props.RichText == true,
		Size = props.Size or UDim2.new(1, 0, 0, 20),
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = props.AutomaticSize,
	})
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

function Util.button(props)
	local frame = Util.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(42, 44, 52),
		BackgroundTransparency = props.BackgroundTransparency or 0,
		BorderSizePixel = 0,
		Text = "",
		Size = props.Size or UDim2.new(1, 0, 0, 34),
		LayoutOrder = props.LayoutOrder,
	})
	Util.corner(props.Radius or 8, frame)
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

function Util.inputBox(props)
	local box = Util.new("TextBox", {
		AutoButtonColor = false,
		BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(38, 38, 48),
		BackgroundTransparency = props.BackgroundTransparency or 0,
		BorderSizePixel = 0,
		ClearTextOnFocus = props.ClearTextOnFocus == true,
		Font = props.Font or Enum.Font.Gotham,
		PlaceholderText = props.PlaceholderText or "",
		Text = props.Text or "",
		TextColor3 = props.TextColor3 or Color3.fromRGB(240, 240, 245),
		TextTransparency = 0,
		PlaceholderColor3 = props.PlaceholderColor3 or Color3.fromRGB(120, 120, 135),
		TextSize = props.TextSize or 13,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		Size = props.Size or UDim2.fromScale(1, 1),
	})
	Util.corner(props.Radius or 6, box)
	if props.Parent then
		box.Parent = props.Parent
	end
	return box
end

return Util
