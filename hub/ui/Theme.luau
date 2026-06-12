local Theme = {}
Theme.Version = "2.3.0-vendor"

local function base()
	return {
		Font = Enum.Font.GothamMedium,
		FontBold = Enum.Font.GothamBold,
		FontMono = Enum.Font.Code,
		SidebarWidth = 196,
		TopbarHeight = 42,
		RowHeight = 32,
		Gap = 6,
		Padding = 10,
		Corner = 8,
		CornerSm = 4,
		CornerLg = 10,
		GlassTransparency = 0.14,
		GlowIntensity = 0.72,
		BorderAlpha = 0.92,
	}
end

local presets = {
	Private = {
		Name = "Private",
		Accent = Color3.fromHex("#53fc18"),
		AccentSoft = Color3.fromHex("#9dff6a"),
		AccentGlow = Color3.fromHex("#53fc18"),
		Canvas = Color3.fromHex("#08080a"),
		Surface = Color3.fromHex("#0c0c0f"),
		Card = Color3.fromHex("#111116"),
		CardHover = Color3.fromHex("#16161d"),
		Elevated = Color3.fromHex("#1a1a22"),
		Text = Color3.fromHex("#ececf4"),
		Muted = Color3.fromHex("#8b8b9a"),
		Subtle = Color3.fromHex("#5c5c6a"),
		Border = Color3.fromHex("#ffffff"),
		Divider = Color3.fromHex("#1e1e26"),
		Success = Color3.fromHex("#53fc18"),
		Warning = Color3.fromHex("#ffcc48"),
		Error = Color3.fromHex("#ff5f6d"),
		Info = Color3.fromHex("#5ecbff"),
		TrackOff = Color3.fromHex("#1c1c24"),
		TrackOn = Color3.fromHex("#143a12"),
		Knob = Color3.fromHex("#f8f8fc"),
	},
	Obsidian = {
		Name = "Obsidian",
		Accent = Color3.fromHex("#a855f7"),
		AccentSoft = Color3.fromHex("#c084fc"),
		AccentGlow = Color3.fromHex("#9333ea"),
		Canvas = Color3.fromHex("#070709"),
		Surface = Color3.fromHex("#0b0b0e"),
		Card = Color3.fromHex("#101014"),
		CardHover = Color3.fromHex("#15151b"),
		Elevated = Color3.fromHex("#1b1b22"),
		Text = Color3.fromHex("#f0f0f5"),
		Muted = Color3.fromHex("#9090a0"),
		Subtle = Color3.fromHex("#606070"),
		Border = Color3.fromHex("#ffffff"),
		Divider = Color3.fromHex("#1a1a22"),
		Success = Color3.fromHex("#34d399"),
		Warning = Color3.fromHex("#fbbf24"),
		Error = Color3.fromHex("#f87171"),
		Info = Color3.fromHex("#a855f7"),
		TrackOff = Color3.fromHex("#1a1a22"),
		TrackOn = Color3.fromHex("#2e1065"),
		Knob = Color3.fromHex("#fafafa"),
	},
	Linoria = {
		Name = "Linoria",
		Accent = Color3.fromHex("#4a9eff"),
		AccentSoft = Color3.fromHex("#7ab8ff"),
		AccentGlow = Color3.fromHex("#3b82f6"),
		Canvas = Color3.fromHex("#0a0a0c"),
		Surface = Color3.fromHex("#0f0f12"),
		Card = Color3.fromHex("#141418"),
		CardHover = Color3.fromHex("#19191f"),
		Elevated = Color3.fromHex("#1e1e25"),
		Text = Color3.fromHex("#e8e8ee"),
		Muted = Color3.fromHex("#888894"),
		Subtle = Color3.fromHex("#555560"),
		Border = Color3.fromHex("#ffffff"),
		Divider = Color3.fromHex("#222228"),
		Success = Color3.fromHex("#4ade80"),
		Warning = Color3.fromHex("#facc15"),
		Error = Color3.fromHex("#ef4444"),
		Info = Color3.fromHex("#4a9eff"),
		TrackOff = Color3.fromHex("#1e1e24"),
		TrackOn = Color3.fromHex("#172554"),
		Knob = Color3.fromHex("#ffffff"),
		RowHeight = 30,
		Gap = 5,
	},
	Fluent = {
		Name = "Fluent",
		Accent = Color3.fromHex("#60cdff"),
		AccentSoft = Color3.fromHex("#9fe0ff"),
		AccentGlow = Color3.fromHex("#0ea5e9"),
		Canvas = Color3.fromHex("#0b0b0d"),
		Surface = Color3.fromHex("#101014"),
		Card = Color3.fromHex("#15151a"),
		CardHover = Color3.fromHex("#1b1b21"),
		Elevated = Color3.fromHex("#212128"),
		Text = Color3.fromHex("#f5f5fa"),
		Muted = Color3.fromHex("#9a9aa8"),
		Subtle = Color3.fromHex("#666674"),
		Border = Color3.fromHex("#ffffff"),
		Divider = Color3.fromHex("#24242c"),
		Success = Color3.fromHex("#6ee7b7"),
		Warning = Color3.fromHex("#fcd34d"),
		Error = Color3.fromHex("#fb7185"),
		Info = Color3.fromHex("#60cdff"),
		TrackOff = Color3.fromHex("#222228"),
		TrackOn = Color3.fromHex("#0c4a6e"),
		Knob = Color3.fromHex("#ffffff"),
		GlassTransparency = 0.1,
		Corner = 10,
		CornerLg = 12,
	},
	Graphite = {
		Name = "Graphite",
		Accent = Color3.fromHex("#53fc18"),
		AccentSoft = Color3.fromHex("#8dff52"),
		AccentGlow = Color3.fromHex("#30ff6a"),
		Canvas = Color3.fromHex("#070708"),
		Surface = Color3.fromHex("#0e0e11"),
		Card = Color3.fromHex("#131318"),
		CardHover = Color3.fromHex("#1a1a22"),
		Elevated = Color3.fromHex("#22222c"),
		Text = Color3.fromHex("#f4f4f8"),
		Muted = Color3.fromHex("#9ca3af"),
		Subtle = Color3.fromHex("#6b7280"),
		Border = Color3.fromHex("#ffffff"),
		Divider = Color3.fromHex("#24242e"),
		Success = Color3.fromHex("#53fc18"),
		Warning = Color3.fromHex("#ffd166"),
		Error = Color3.fromHex("#ff5c5c"),
		Info = Color3.fromHex("#22d3ee"),
		TrackOff = Color3.fromHex("#24242e"),
		TrackOn = Color3.fromHex("#163512"),
		Knob = Color3.fromHex("#fafafc"),
	},
	Midnight = {
		Name = "Midnight",
		Accent = Color3.fromHex("#6366f1"),
		AccentSoft = Color3.fromHex("#818cf8"),
		AccentGlow = Color3.fromHex("#4f46e5"),
		Canvas = Color3.fromHex("#09090b"),
		Surface = Color3.fromHex("#111113"),
		Card = Color3.fromHex("#18181b"),
		CardHover = Color3.fromHex("#1f1f23"),
		Elevated = Color3.fromHex("#27272a"),
		Text = Color3.fromHex("#fafafa"),
		Muted = Color3.fromHex("#a1a1aa"),
		Subtle = Color3.fromHex("#71717a"),
		Border = Color3.fromHex("#ffffff"),
		Divider = Color3.fromHex("#27272a"),
		Success = Color3.fromHex("#22c55e"),
		Warning = Color3.fromHex("#f59e0b"),
		Error = Color3.fromHex("#ef4444"),
		Info = Color3.fromHex("#3b82f6"),
		TrackOff = Color3.fromHex("#27272a"),
		TrackOn = Color3.fromHex("#312e81"),
		Knob = Color3.fromHex("#fafafa"),
	},
}

Theme.Presets = presets
Theme.Current = nil

function Theme.get(name)
	local layout = base()
	local preset = presets[name] or presets.Private
	local copy = {}
	for k, v in pairs(layout) do
		copy[k] = v
	end
	for k, v in pairs(preset) do
		copy[k] = v
	end
	Theme.Current = copy
	return copy
end

function Theme.list()
	local names = {}
	for name in pairs(presets) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Theme.applyPreset(target, name)
	if type(target) ~= "table" then
		return Theme.get(name)
	end
	local layout = base()
	local preset = presets[name] or presets.Private
	for k, v in pairs(layout) do
		target[k] = v
	end
	for k, v in pairs(preset) do
		target[k] = v
	end
	Theme.Current = target
	return target
end

local function repaintTrack(track, theme)
	local knob = track:FindFirstChild("Knob")
	local on = knob and knob.Position.X.Offset >= 12
	track.BackgroundColor3 = on and theme.TrackOn or theme.TrackOff
end

function Theme.repaint(root, theme)
	if not root or not theme then
		return
	end
	local nodes = root:GetDescendants()
	table.insert(nodes, root)
	for _, inst in ipairs(nodes) do
		local n = inst.Name
		if inst:IsA("UIGradient") then
			local parent = inst.Parent
			if parent and (parent.Name == "AlleralWindow" or parent.Name == "SectionBody" or parent.Name == "Groupbox") then
				inst.Color = ColorSequence.new({ theme.Canvas, theme.Surface })
			end
		elseif inst:IsA("UIStroke") then
			inst.Color = theme.Border
		elseif inst:IsA("Frame") or inst:IsA("TextButton") or inst:IsA("ScrollingFrame") then
			if n == "AlleralWindow" then
				inst.BackgroundColor3 = theme.Canvas
			elseif n == "Sidebar" then
				inst.BackgroundColor3 = theme.Surface
			elseif n == "SectionBody" or n == "Notification" or n == "CommandPalette" then
				inst.BackgroundColor3 = theme.Card
			elseif n == "Acrylic" then
				inst.BackgroundColor3 = theme.Surface
			elseif n == "NeonGlow" or n == "CursorGlow" then
				inst.BackgroundColor3 = theme.AccentGlow
			elseif n == "AccentEdge" or n == "TabIndicator" or n == "TabIndicatorFill" then
				inst.BackgroundColor3 = theme.Accent
			elseif n == "Track" then
				repaintTrack(inst, theme)
			elseif n == "Knob" then
				inst.BackgroundColor3 = theme.Knob
			elseif n == "Divider" then
				inst.BackgroundColor3 = theme.Divider
			elseif n == "Cmd" then
				inst.BackgroundColor3 = theme.Surface
			end
		elseif inst:IsA("TextLabel") or inst:IsA("TextBox") then
			if n == "Title" or n == "Label" then
				inst.TextColor3 = theme.Text
			elseif n == "Desc" or n == "Body" or n == "Summary" then
				inst.TextColor3 = theme.Muted
			end
		elseif inst:IsA("TextButton") and n:sub(1, 4) == "Nav_" then
			inst.TextColor3 = theme.Muted
		elseif inst:IsA("ImageLabel") and inst.Parent and inst.Parent.Name:sub(1, 4) == "Nav_" then
			inst.ImageColor3 = theme.Muted
		end
	end
end

return Theme
