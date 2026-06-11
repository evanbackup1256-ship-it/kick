local Util = require(script.Parent.util)
local Theme = require(script.Parent.theme)
local Tween = require(script.Parent.tween)

local Notification = {}
Notification._container = nil

function Notification.init(gui, library)
	Notification._library = library
	Notification._container = Util.new("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 500,
	}, { gui })

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = Notification._container

	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 10)
	pad.Parent = Notification._container
end

function Notification.show(data)
	if not Notification._container then
		return
	end
	local theme = Theme.current()
	local transp = theme.Transparency or Theme.Palettes.Alleral.Transparency
	data = data or {}

	local card = Util.new("Frame", {
		Name = "Notification",
		BackgroundColor3 = theme.Backgrounds.Dark,
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 500,
	}, { Notification._container })
	Util.corner(Theme.Visual.CornerRadius, card)
	Util.stroke(Color3.fromRGB(255, 255, 255), 1, transp.Stroke, card)
	Util.padding(14, 14, 14, 14, card)
	Util.list(4, false, card)

	Util.text({
		Parent = card,
		Text = data.Title or "Notification",
		FontWeight = Enum.FontWeight.SemiBold,
		TextSize = 14 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Title,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	Util.text({
		Parent = card,
		Text = data.Content or "",
		TextWrapped = true,
		TextSize = 13 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		TextTransparency = transp.Subtitle,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	local duration = data.Duration or math.clamp((#tostring(data.Content or "") * 0.08) + 3, 3, 12)
	task.delay(duration, function()
		if card.Parent then
			card:Destroy()
		end
	end)
	return card
end

return Notification
