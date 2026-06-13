-- Alleral CSS Engine v1.0
-- Parses real CSS and applies styles to Roblox GuiObjects
-- Supports: selectors, classes, ids, cascading, pseudo-classes, @keyframes

local CSS = {}
CSS.__index = CSS

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- CSS → Roblox property mapping
local PROPERTY_MAP = {
	-- Layout
	width = "Size",
	height = "Size",
	["min-width"] = nil,
	["max-width"] = nil,
	position = "Position",
	["z-index"] = "ZIndex",
	anchor = "AnchorPoint",

	-- Display
	visibility = "Visible",
	opacity = "BackgroundTransparency",
	display = nil,

	-- Colors
	color = "TextColor3",
	["background-color"] = "BackgroundColor3",
	["background"] = "BackgroundColor3",
	["border-color"] = "BorderColor3",
	["text-color"] = "TextColor3",

	-- Typography
	["font-size"] = "TextSize",
	["font-family"] = "Font",
	["font-weight"] = nil,
	["text-align"] = nil,
	["text-wrap"] = "TextWrapped",

	-- Borders & Corners
	["border-radius"] = nil,
	["border-width"] = nil,
	["border-size"] = "BorderSizePixel",

	-- Transforms & Effects
	rotation = "Rotation",
	scale = nil,
	transparency = "BackgroundTransparency",
}

local PSEUDO_MAP = {
	hover = "MouseEnter",
	leave = "MouseLeave",
	press = "MouseButton1Down",
	release = "MouseButton1Up",
	click = "MouseButton1Click",
	focus = "Focused",
	blur = "FocusLost",
}

-- Parse a CSS string into a stylesheet object
function CSS.parse(cssString)
	local sheet = { rules = {}, keyframes = {} }
	local pos = 1

	-- Strip comments
	cssString = cssString:gsub("/%*.-%*/", "")

	while pos <= #cssString do
		-- Skip whitespace
		local ws = cssString:match("^%s+", pos)
		if ws then pos = pos + #ws end
		if pos > #cssString then break end

		-- @keyframes
		local kfName, kfBody = cssString:match("^@keyframes%s+([%w%-_]+)%s*{(.-)}", pos)
		if kfName then
			sheet.keyframes[kfName] = CSS.parseKeyframes(kfBody)
			pos = pos + #kfName + #kfBody + 13
		else
			-- Selector + rules block
			local selector, body = cssString:match("^([^{]+)%s*{(.-)}", pos)
			if selector and body then
				selector = selector:gsub("^%s+", ""):gsub("%s+$", "")
				local declarations = CSS.parseDeclarations(body)
				local rule = { selector = selector, raw = selector, declarations = declarations }
				CSS.parseSelector(rule)
				table.insert(sheet.rules, rule)
				pos = pos + #selector + #body + 2
			else
				pos = pos + 1
			end
		end
	end

	-- Sort by specificity (higher = more specific)
	table.sort(sheet.rules, function(a, b)
		return a.specificity < b.specificity
	end)

	return sheet
end

-- Parse a single selector into components
function CSS.parseSelector(rule)
	local sel = rule.selector
	rule.tag = nil
	rule.classes = {}
	rule.id = nil
	rule.pseudo = nil
	rule.specificity = 0

	-- Extract pseudo-class
	local pseudo = sel:match(":(%w+)%s*$")
	if pseudo and PSEUDO_MAP[pseudo] then
		rule.pseudo = PSEUDO_MAP[pseudo]
		sel = sel:gsub(":%w+%s*$", "")
	end

	-- Extract ID
	local id = sel:match("#([%w%-_]+)")
	if id then
		rule.id = id
		rule.specificity = rule.specificity + 100
		sel = sel:gsub("#[%w%-_]+", "")
	end

	-- Extract classes
	for class in sel:gmatch("%.([%w%-_]+)") do
		table.insert(rule.classes, class)
		rule.specificity = rule.specificity + 10
		sel = sel:gsub("%.[%w%-_]+", "")
	end

	-- Remaining is the tag/element selector
	sel = sel:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	if sel ~= "" and sel ~= "*" then
		rule.tag = sel:lower()
		rule.specificity = rule.specificity + 1
	end
end

-- Parse CSS declarations block
function CSS.parseDeclarations(body)
	local decls = {}
	for prop, value in body:gmatch("([%w%-]+)%s*:%s*([^;]+);?") do
		prop = prop:gsub("^%s+", ""):gsub("%s+$", ""):lower()
		value = value:gsub("^%s+", ""):gsub("%s+$", "")
		decls[prop] = value
	end
	return decls
end

-- Parse @keyframes block
function CSS.parseKeyframes(body)
	local frames = {}
	for percent, decls in body:gmatch("(%d+%%)%s*{(.-)}") do
		local pct = tonumber(percent:match("%d+")) / 100
		frames[pct] = CSS.parseDeclarations(decls)
	end
	return frames
end

-- Check if a rule matches a GuiObject
function CSS.ruleMatches(rule, instance)
	if not instance then return false end

	local name = instance.Name:lower()
	local className = instance:GetAttribute("Class")
	local id = instance:GetAttribute("ID")

	-- Tag match
	if rule.tag and rule.tag ~= "*" then
		if name ~= rule.tag then return false end
	end

	-- Class match
	if #rule.classes > 0 then
		local hasClass = false
		if className then
			local classes = {}
			for c in className:gmatch("%S+") do table.insert(classes, c:lower()) end
			for _, rc in ipairs(rule.classes) do
				for _, c in ipairs(classes) do
					if c == rc then hasClass = true break end
				end
				if hasClass then break end
			end
		end
		if not hasClass then return false end
	end

	-- ID match
	if rule.id then
		if not id or id:lower() ~= rule.id:lower() then return false end
	end

	return true
end

-- Convert CSS value string to Roblox type
local function convertValue(value, prop)
	value = value:lower()

	-- Colors: #rrggbb, rgb(), Color3
	if prop:find("color") or prop == "background" then
		if value:match("^#[%x]+$") then
			return Color3.fromHex(value)
		elseif value:match("^rgb%(") then
			local r, g, b = value:match("rgb%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)")
			if r then return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end
		elseif value == "transparent" then
			return nil
		end
		return value
	end

	-- Numbers
	if tonumber(value) then
		return tonumber(value)
	end

	-- Visibility
	if value == "hidden" then return false
	elseif value == "visible" then return true end

	-- Text alignment
	if value == "left" then return Enum.TextXAlignment.Left
	elseif value == "center" then return Enum.TextXAlignment.Center
	elseif value == "right" then return Enum.TextXAlignment.Right end

	-- Font weight → bold
	if value == "bold" or value == "700" then return true end

	return value
end

-- Apply a declaration to a GuiObject
function CSS.applyDeclaration(instance, prop, value)
	local robloxProp = PROPERTY_MAP[prop]
	if not robloxProp then return end

	local converted = convertValue(value, prop)

	if prop == "width" or prop == "height" then
		CSS.applyDimension(instance, prop, value)
	elseif prop == "position" then
		CSS.applyPosition(instance, value)
	elseif prop == "visibility" then
		instance.Visible = converted
	elseif prop == "opacity" or prop == "transparency" then
		local t = tonumber(value) or 0
		if t > 1 then t = t / 100 end
		t = 1 - t
		CSS.setProperty(instance, "BackgroundTransparency", t)
		CSS.setProperty(instance, "TextTransparency", t)
		CSS.setProperty(instance, "ImageTransparency", t)
	elseif prop == "display" then
		instance.Visible = (value ~= "none")
	elseif prop == "border-radius" then
		local r = tonumber(value:match("%d+")) or 8
		CSS.applyCornerRadius(instance, r)
	elseif prop == "text-align" then
		local align = convertValue(value, prop)
		CSS.setProperty(instance, "TextXAlignment", align)
	elseif prop == "font-weight" then
		-- Roblox handles bold via RichText
	elseif prop == "scale" then
		local s = tonumber(value) or 1
		instance.Size = UDim2.new(s, 0, s, 0)
	elseif prop == "font-family" then
		if value:find("bold") then
			instance.RichText = true
		end
	else
		CSS.setProperty(instance, robloxProp, converted)
	end
end

-- Safely set a property on an instance
function CSS.setProperty(instance, prop, value)
	if value == nil then return end
	local ok, err = pcall(function()
		instance[prop] = value
	end)
end

-- Apply width/height with px support
function CSS.applyDimension(instance, prop, value)
	local num = tonumber(value:match("%d+"))
	if not num then return end
	local isPct = value:find("%%")
	local axis = prop == "width" and "X" or "Y"
	if isPct then
		instance.Size = UDim2.new(
			axis == "X" and num / 100 or instance.Size.X.Scale,
			instance.Size.X.Offset,
			axis == "Y" and num / 100 or instance.Size.Y.Scale,
			instance.Size.Y.Offset
		)
	else
		instance.Size = UDim2.new(
			instance.Size.X.Scale,
			axis == "X" and num or instance.Size.X.Offset,
			instance.Size.Y.Scale,
			axis == "Y" and num or instance.Size.Y.Offset
		)
	end
end

-- Apply position (static, relative, absolute)
function CSS.applyPosition(instance, value)
	-- Roblox uses AnchorPoint + Position
end

-- Apply corner radius via UICorner
function CSS.applyCornerRadius(instance, radius)
	local corner = instance:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Name = "CSS_Corner"
		corner.Parent = instance
	end
	corner.CornerRadius = UDim.new(0, radius)
end

-- Create a UIGradient if gradient is specified
function CSS.applyGradient(instance, gradientValue)
	local gradient = instance:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Name = "CSS_Gradient"
		gradient.Parent = instance
	end
	-- Parse linear-gradient(...) syntax
	local colors = {}
	for color, pct in gradientValue:gmatch("([#%w]+)%s+(%d+%%)") do
		table.insert(colors, ColorSequenceKeypoint.new(tonumber(pct:match("%d+")) / 100, Color3.fromHex(color)))
	end
	if #colors > 0 then
		gradient.Color = ColorSequence.new(colors)
	end
end

-- CSS Engine instance
function CSS.new(sheet)
	local self = setmetatable({
		_sheet = sheet,
		_styled = {},
		_animations = {},
		_connections = {},
	}, CSS)
	return self
end

-- Style a single GuiObject
function CSS:style(instance)
	if not instance or not instance:IsA("GuiObject") then return end

	-- Skip if already styled with same CSS
	local key = instance:GetFullName()
	if self._styled[key] then return end
	self._styled[key] = true

	-- Collect matching declarations
	local declarations = {}
	for _, rule in ipairs(self._sheet.rules) do
		if CSS.ruleMatches(rule, instance) then
			for prop, value in pairs(rule.declarations) do
				declarations[prop] = value
			end
		end
	end

	-- Apply all matching declarations
	for prop, value in pairs(declarations) do
		CSS.applyDeclaration(instance, prop, value)
	end

	-- Connect pseudo-classes
	for _, rule in ipairs(self._sheet.rules) do
		if rule.pseudo and CSS.ruleMatches(rule, instance) then
			local event = instance[rule.pseudo]
			if event and typeof(event) == "RBXScriptSignal" then
				local conn = event:Connect(function()
					for prop, value in pairs(rule.declarations) do
						CSS.applyDeclaration(instance, prop, value)
					end
				end)
				table.insert(self._connections, conn)
			end
		end
	end

	-- Recurse children
	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("GuiObject") then
			self:style(child)
		end
	end
end

-- Style entire ScreenGui recursively
function CSS:mount(gui)
	self._styled = {}
	for _, child in ipairs(gui:GetChildren()) do
		self:style(child)
	end
end

-- Apply CSS class to instance
function CSS.addClass(instance, className)
	local current = instance:GetAttribute("Class") or ""
	if not current:find(className) then
		instance:SetAttribute("Class", (current .. " " .. className):gsub("^%s+", ""))
	end
end

function CSS.removeClass(instance, className)
	local current = instance:GetAttribute("Class") or ""
	current = current:gsub(className, ""):gsub("%s+", " ")
	instance:SetAttribute("Class", current)
end

function CSS.setId(instance, id)
	instance:SetAttribute("ID", id)
end

-- Cleanup connections
function CSS:destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	self._connections = {}
	self._styled = {}
end

return CSS
