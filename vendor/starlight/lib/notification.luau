local Util = require(script.Parent.util)
local Theme = require(script.Parent.theme)
local Tween = require(script.Parent.tween)

local Notification = {}
Notification._container = nil
Notification._library = nil

function Notification.init(gui, library)
	Notification._library = library
	Notification._container = Util.new("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 300, 1, -40),
		Position = UDim2.new(1, -320, 0, 20),
		ZIndex = 500,
	}, { gui })
	Util.list(8, false, Notification._container)
end

function Notification.show(data)
	if not Notification._container then
		return
	end
	local theme = Theme.current()
	data = data or {}
	local layoutOrder = 0
	for _, child in ipairs(Notification._container:GetChildren()) do
		if child:IsA("GuiObject") then
			layoutOrder += 1
		end
	end

	local card = Util.new("Frame", {
		Name = "Notification",
		BackgroundColor3 = theme.Backgrounds.Elevated,
		BackgroundTransparency = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = layoutOrder,
		ZIndex = 500,
	}, { Notification._container })
	Util.corner(Theme.Visual.CornerRadius, card)
	Util.stroke(theme.Miscellaneous.Divider, 1, 0.5, card)

	local accent = Util.new("Frame", {
		BackgroundColor3 = theme.Accent,
		Size = UDim2.new(0, 3, 1, -12),
		Position = UDim2.fromOffset(0, 6),
	}, { card })
	Util.corner(999, accent)

	Util.padding(12, 14, 12, 18, card)
	Util.list(4, false, card)

	local headerRow = Util.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
	}, { card })
	Util.list(8, true, headerRow)

	if not Util.isEmpty(data.Icon) then
		Util.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Util.iconAsset(data.Icon),
			Size = UDim2.fromOffset(16, 16),
			ImageColor3 = theme.Accent,
			ImageTransparency = 0,
		}, { headerRow })
	end

	Util.text({
		Parent = headerRow,
		Text = data.Title or "Notification",
		Font = Enum.Font.GothamBold,
		TextSize = 14 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		Size = UDim2.new(1, -22, 1, 0),
	})

	local body = Util.text({
		Parent = card,
		Text = data.Content or "",
		TextWrapped = true,
		TextSize = 13 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Medium,
		Size = UDim2.new(1, 0, 0, 0),
	})
	body.AutomaticSize = Enum.AutomaticSize.Y

	local duration = data.Duration or math.clamp((#tostring(data.Content or "") * 0.08) + 3, 3, 12)
	task.delay(duration, function()
		if card.Parent then
			card:Destroy()
		end
	end)
	return card
end

return Notification
