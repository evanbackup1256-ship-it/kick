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
		Size = UDim2.new(0, 320, 1, -40),
		Position = UDim2.new(1, -340, 0, 20),
	}, { gui })
	Util.list(10, false, Notification._container)
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
		BackgroundTransparency = 0.05,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = layoutOrder,
	}, { Notification._container })
	Util.corner(Theme.Visual.CornerRadius, card)
	if Theme.Visual.ShowShadows then
		Util.stroke(theme.Miscellaneous.Divider, 1, 0.35, card)
	end
	Util.padding(12, 14, 12, 14, card)
	Util.list(6, false, card)

	local headerRow = Util.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
	}, { card })
	Util.list(8, true, headerRow)

	if not Util.isEmpty(data.Icon) then
		local icon = Util.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Util.iconAsset(data.Icon),
			Size = UDim2.fromOffset(18, 18),
			ImageColor3 = theme.Accent,
		}, { headerRow })
	end

	Util.text({
		Parent = headerRow,
		Text = data.Title or "Notification",
		Font = Enum.Font.GothamBold,
		TextSize = 15 * Theme.Visual.FontScale,
		TextColor3 = theme.Foregrounds.Light,
		Size = UDim2.new(1, -26, 1, 0),
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
			Tween.play(card, { BackgroundTransparency = 1 }, function()
				card:Destroy()
			end, Theme.tweenInfo(0.2))
		end
	end)
	return card
end

return Notification
