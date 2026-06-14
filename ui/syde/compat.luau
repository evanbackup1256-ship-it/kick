-- Alleral compatibility layer for upstream Syde (essencejs/syde).
-- Applied before the original library body; keeps upstream logic intact.

local ALLERAL_SYDE_PATCH = 34

local function sydeLog(...) end
local function sydeWarn(...) end

local function sydeGetCurrentCamera()
	local current = workspace.CurrentCamera
	while not current do
		workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
		current = workspace.CurrentCamera
	end
	return current
end

local function sydeSetClipboard(value)
	if type(setclipboard) == "function" then
		local ok = pcall(setclipboard, tostring(value or ""))
		return ok
	end
	return false
end

local function sydeCall(callback, context, ...)
	if type(callback) ~= "function" then
		return true
	end
	local ok, result = pcall(callback, ...)
	if not ok then
		sydeWarn("[Syde] " .. tostring(context or "callback") .. " failed: " .. tostring(result))
	end
	return ok, result
end

local function sydeNormalizeSliderOptions(options)
	options = type(options) == "table" and options or {}
	local range = type(options.Range) == "table" and options.Range or { 0, 100 }
	local minimum = tonumber(range[1]) or 0
	local maximum = tonumber(range[2]) or 100
	if maximum < minimum then
		minimum, maximum = maximum, minimum
	end
	if maximum == minimum then
		maximum = minimum + 1
	end
	local increment = math.abs(tonumber(options.Increment) or 1)
	if increment == 0 then increment = 1 end
	local starter = math.clamp(tonumber(options.StarterValue) or minimum, minimum, maximum)
	options.Range = { minimum, maximum }
	options.Increment = increment
	options.StarterValue = starter
	options.Value = starter
	return options
end

local SYDE_CANONICAL_NAMES = {
	Main = "main",
	Top = "top",
	Tabs = "tabs",
	Pages = "pages",
	Settings = "settings",
	Dim = "dim",
	Modal = "modal",
	User = "user",
	Search = "search",
	-- Render: keep PascalCase — upstream uses ui.Render.ToggleConfiguration
	Minihome = "minihome",
	Toastholder = "toastholder",
	ToastHolder = "toastholder",
	Toast = "toast",
	Title = "title",
	Sub = "sub",
	Subtitle = "sub",
	Tog = "tog",
	Check = "check",
	Gradfr = "gradfr",
	GradFr = "gradfr",
	Glow = "glow",
	Interact = "interact",
	Configure = "configure",
	ClipFrame = "clipframe",
	Clipframe = "clipframe",
	Separator = "separator",
	Desc = "desc",
	Icon = "icon",
	Timer = "timer",
	Slide = "slide",
	SlideFrame = "slideframe",
	Slideframe = "slideframe",
	DropHolder = "dropholder",
	Dropholder = "dropholder",
	Drop = "drop",
	Selected = "selected",
	Down = "down",
	Shadow = "shadow",
	Functions = "functions",
	Resize = "resize",
	Wallpaper = "wallpaper",
	Homeicon = "homeicon",
	HomeIcon = "homeicon",
	Tb = "tb",
	Btn = "btn",
	Tab = "tab",
	Page = "page",
	Indicator = "indicator",
	Buttons = "buttons",
	Confirm = "confirm",
	Cancel = "cancel",
	Option = "Option",
}

local function sydeFindChild(parent, ...)
	if not parent then
		return nil
	end
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		local child = parent:FindFirstChild(name)
		if child then
			return child
		end
	end
	return nil
end

local function sydeFindDescendant(parent, ...)
	local direct = sydeFindChild(parent, ...)
	if direct then
		return direct
	end
	if not parent then
		return nil
	end
	for i = 1, select("#", ...) do
		local child = parent:FindFirstChild(select(i, ...), true)
		if child then
			return child
		end
	end
	return nil
end

local function sydeButtonLabel(button)
	if not button then
		return nil
	end
	return sydeFindChild(button, "TextLabel", "text", "title")
end

local function sydeSliderLabel(slider)
	if not slider then
		return nil
	end
	return sydeFindChild(slider, "title", "Title")
end

local function sydeOptionLabel(option)
	if not option then
		return nil
	end
	return sydeFindChild(option, "title", "Title", "TextLabel", "text")
end

local function sydeTitleLabel(instance)
	return sydeOptionLabel(instance)
end

local function sydeParagraphParts(paragraph)
	local frame = sydeFindChild(paragraph, "Frame", "frame")
	local title = sydeTitleLabel(paragraph) or (frame and sydeTitleLabel(frame))
	local content = sydeFindDescendant(paragraph, "Content", "content", "Description", "description", "desc")
	local function isTextObject(instance)
		return instance and (instance:IsA("TextLabel") or instance:IsA("TextBox") or instance:IsA("TextButton"))
	end
	if not isTextObject(title) or not isTextObject(content) then
		for _, descendant in ipairs(paragraph:GetDescendants()) do
			if isTextObject(descendant) then
				local name = string.lower(descendant.Name)
				if not isTextObject(title) and (name == "title" or name == "textlabel") then
					title = descendant
				elseif not isTextObject(content) and (name == "content" or name == "description" or name == "desc") then
					content = descendant
				end
			end
		end
	end
	if not isTextObject(title) then title = nil end
	if not isTextObject(content) then content = nil end
	return title, content
end

local function sydeOptionText(option)
	local label = sydeOptionLabel(option)
	return label and label.Text or ""
end

local function sydeLoaderProfileLabel(loaderGui)
	local root = loaderGui or Loader
	if not root then
		return nil
	end
	local loaderFrame = sydeFindChild(root, "loader")
	local profile = loaderFrame and sydeFindChild(loaderFrame, "profile")
	return profile and sydeTitleLabel(profile)
end

local function sydeBindUi(root)
	root = root or Library
	local main = sydeFindChild(root, "main", "Main")
	local render = sydeFindChild(root, "Render", "render")
	local toastholder = sydeFindChild(root, "toastholder", "Toastholder", "ToastHolder")
	local bound = {
		_root = root,
		main = main,
		Main = main,
		Render = render,
		render = render,
		toastholder = toastholder,
		Toastholder = toastholder,
	}
	return setmetatable(bound, {
		__index = function(_, key)
			local value = rawget(bound, key)
			if value ~= nil then
				return value
			end
			if key == "main" or key == "Main" then
				return main
			end
			if key == "Enabled" or key == "DisplayOrder" or key == "IgnoreGuiInset" or key == "ResetOnSpawn" then
				return root[key]
			end
			return sydeFindChild(root, tostring(key))
		end,
		__newindex = function(_, key, value)
			if key == "Enabled" or key == "DisplayOrder" or key == "IgnoreGuiInset" or key == "ResetOnSpawn" then
				root[key] = value
			else
				rawset(bound, key, value)
			end
		end,
	})
end

local function sydeButtonStroke(button)
	if not button then
		return nil
	end
	return button:FindFirstChildOfClass("UIStroke") or sydeFindChild(button, "UIStroke")
end

local function sydeResolveModal(instance)
	local buttonsFrame = sydeFindChild(instance, "Buttons", "buttons")
	local confirm = buttonsFrame and sydeFindChild(buttonsFrame, "Confirm", "confirm")
		or sydeFindChild(instance, "Confirm", "confirm")
	local cancel = buttonsFrame and sydeFindChild(buttonsFrame, "Cancel", "cancel")
		or sydeFindChild(instance, "Cancel", "cancel")
	return {
		Instance = instance,
		Title = sydeFindChild(instance, "Title", "title"),
		Content = sydeFindChild(instance, "Content", "content"),
		UIStroke = instance:FindFirstChildOfClass("UIStroke"),
		Confirm = confirm,
		Cancel = cancel,
		ConfirmLabel = sydeButtonLabel(confirm),
		CancelLabel = sydeButtonLabel(cancel),
		ConfirmStroke = sydeButtonStroke(confirm),
		CancelStroke = sydeButtonStroke(cancel),
	}
end

local function sydeSetInteractable(button, enabled)
	if not button then
		return
	end
	if typeof(button.Interactable) == "boolean" then
		button.Interactable = enabled
	end
	local interact = sydeFindChild(button, "interact", "Interact")
	if interact and typeof(interact.Interactable) == "boolean" then
		interact.Interactable = enabled
	end
end

local function sydeConnectClick(button, callback)
	if not button or type(callback) ~= "function" then
		return
	end
	if button:IsA("GuiButton") then
		button.MouseButton1Click:Connect(callback)
		return
	end
	local interact = sydeFindChild(button, "interact", "Interact")
	if interact and interact:IsA("GuiButton") then
		interact.MouseButton1Click:Connect(callback)
	end
end

local function sydeConnectSliderDrag(slideFrame, onDown, onUp)
	if not slideFrame or type(onDown) ~= "function" or type(onUp) ~= "function" then
		return
	end
	local handle = sydeFindChild(slideFrame, "interact", "Interact")
	if not handle and slideFrame:IsA("GuiButton") then
		handle = slideFrame
	end
	if handle and handle:IsA("GuiButton") then
		handle.MouseButton1Down:Connect(onDown)
		handle.MouseButton1Up:Connect(onUp)
		return
	end
	slideFrame.Active = true
	slideFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			onDown()
		end
	end)
	slideFrame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			onUp()
		end
	end)
end

local function sydeDropSelectedLabel(drop)
	if not drop then
		return nil
	end
	local label = sydeFindChild(
		drop,
		"selected",
		"Selected",
		"select",
		"Select",
		"value",
		"Value",
		"placeholder",
		"Placeholder"
	)
	if label then
		return label
	end
	for _, child in ipairs(drop:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			return child
		end
	end
	return nil
end

local function sydeBindDropFrame(drop)
	if not drop then
		return nil
	end
	local selectedLabel = sydeDropSelectedLabel(drop)
	local selectContainer = sydeFindChild(drop, "selectContainer", "SelectContainer", "selectedContainer", "SelectedContainer")
	local container = sydeFindChild(drop, "Container", "container")
	local search = sydeFindChild(drop, "search", "Search")
	local down = sydeFindChild(drop, "down", "Down")
	local v0 = sydeFindChild(drop, "v0", "V0")
	local bound = {
		_drop = drop,
		selected = selectedLabel,
		Selected = selectedLabel,
		selectContainer = selectContainer,
		SelectContainer = selectContainer,
		Container = container,
		container = container,
		search = search,
		Search = search,
		down = down,
		Down = down,
		v0 = v0,
		V0 = v0,
	}
	return setmetatable(bound, {
		__index = function(_, key)
			if key == "_drop" then
				return drop
			end
			local value = rawget(bound, key)
			if value ~= nil then
				return value
			end
			local instValue = drop[key]
			if type(instValue) == "function" then
				return function(first, ...)
					if first == drop or first == bound then
						return instValue(drop, ...)
					end
					return instValue(drop, first, ...)
				end
			end
			return instValue
		end,
		__newindex = function(_, key, value)
			drop[key] = value
		end,
	})
end

local function sydeUnwrapDropFrame(drop)
	if type(drop) == "table" and drop._drop then
		return drop._drop
	end
	return drop
end

local function sydeSetDropSelectedText(drop, text)
	local frame = sydeUnwrapDropFrame(drop)
	local label = drop and (drop.selected or sydeDropSelectedLabel(frame))
	if label then
		label.Text = tostring(text or "")
	end
end

local function sydeSanitizeAssetRoot(root)
	if not root then
		return
	end
	for _, desc in ipairs(root:GetDescendants()) do
		if desc:IsA("LocalScript") or desc:IsA("Script") or desc:IsA("ModuleScript") then
			pcall(function()
				desc:Destroy()
			end)
		end
	end
end

local function sydeShouldSkipNormalize(instance)
	local current = instance
	while current do
		if current.Name == "Render" then
			return true
		end
		current = current.Parent
	end
	return false
end

local function sydeNormalizeTemplateNames(root)
	if not root then
		return
	end
	for _, desc in ipairs(root:GetDescendants()) do
		if sydeShouldSkipNormalize(desc) then
			continue
		end
		local canonical = SYDE_CANONICAL_NAMES[desc.Name]
		if canonical and canonical ~= desc.Name then
			pcall(function()
				desc.Name = canonical
			end)
		end
	end
end

local function sydePrepareAssetRoot(root)
	sydeSanitizeAssetRoot(root)
	sydeNormalizeTemplateNames(root)
end

local function sydeSanitizeUiClone(root)
	sydePrepareAssetRoot(root)
end

sydePrepareAssetRoot(Library)
sydePrepareAssetRoot(Loader)

local function sydeEnsureDropholderDropFrame(dropholder)
	if not dropholder then
		return nil
	end
	local drop = sydeFindChild(dropholder, "drop", "Drop")
	if drop then
		return drop
	end
	drop = Instance.new("Frame")
	drop.Name = "drop"
	drop.BackgroundTransparency = 1
	drop.BorderSizePixel = 0
	drop.Size = UDim2.new(1, 0, 1, 0)
	drop.Position = UDim2.new(0, 0, 0, 0)
	drop.ZIndex = dropholder.ZIndex
	local children = dropholder:GetChildren()
	drop.Parent = dropholder
	for _, child in ipairs(children) do
		if child ~= drop then
			child.Parent = drop
		end
	end
	return drop
end

local function sydeResolveDropFrame(dropholder)
	if not dropholder then
		return nil
	end
	local drop = sydeFindChild(dropholder, "drop", "Drop")
	if drop then
		return drop
	end
	if sydeFindChild(dropholder, "Container", "container") or sydeDropSelectedLabel(dropholder) then
		return dropholder
	end
	for _, child in ipairs(dropholder:GetChildren()) do
		if child:IsA("GuiObject") then
			if sydeFindChild(child, "Container", "container") or sydeDropSelectedLabel(child) then
				return child
			end
		end
	end
	return nil
end

local function sydeDropHasContainer(dropFrame)
	return dropFrame ~= nil and sydeFindChild(dropFrame, "Container", "container") ~= nil
end

local function sydePrepareDropdownDrop(dropdown)
	if not dropdown then
		return nil
	end
	sydeSanitizeUiClone(dropdown)
	local holder = sydeFindChild(dropdown, "dropholder", "DropHolder", "Dropholder", "dropHolder")
	if not holder then
		for _, child in ipairs(dropdown:GetChildren()) do
			if sydeResolveDropFrame(child) then
				holder = child
				break
			end
		end
	end
	local dropFrame = nil
	if holder then
		dropFrame = sydeEnsureDropholderDropFrame(holder) or sydeResolveDropFrame(holder)
	end
	if not sydeDropHasContainer(dropFrame) then
		local altDrop = sydeFindChild(dropdown, "drop", "Drop")
		if sydeDropHasContainer(altDrop) then
			dropFrame = altDrop
		else
			for _, child in ipairs(dropdown:GetChildren()) do
				if child ~= holder then
					local resolved = sydeResolveDropFrame(child)
					if sydeDropHasContainer(resolved) then
						dropFrame = resolved
						break
					end
				end
			end
		end
	end
	if not dropFrame then
		return nil
	end
	return sydeBindDropFrame(dropFrame) or dropFrame
end

local PAGE_TEMPLATE_ALIASES = {
	Button = { "Button", "button" },
	Toggle = { "Toggle", "toggle" },
	KeyBind = { "KeyBind", "keybind", "Keybind" },
	ColorPicker = { "ColorPicker", "colorpicker", "Colorpicker" },
	Dropdown = { "Dropdown", "dropdown" },
	Slider = { "Slider", "slider" },
	Paragraph = { "Paragraph", "paragraph", "Para", "para" },
	Input = { "Input", "input", "TextInput", "textinput" },
	Label = { "Label", "label" },
	Section = { "Section", "section" },
	["3DView"] = { "3DView", "3dview", "View3D", "view3d" },
}

local function sydePageTemplate(pageContainer, templateName)
	if not pageContainer then
		return nil
	end
	local aliases = PAGE_TEMPLATE_ALIASES[templateName]
	if aliases then
		return sydeFindChild(pageContainer, table.unpack(aliases))
	end
	local lower = templateName:sub(1, 1):lower() .. templateName:sub(2)
	return sydeFindChild(pageContainer, templateName, lower)
end

local function sydeClonePageTemplate(pageContainer, templateName)
	local template = sydePageTemplate(pageContainer, templateName)
	if not template then
		sydeWarn("[Syde] Missing page template: " .. tostring(templateName))
		return nil
	end
	local clone = template:Clone()
	sydeSanitizeUiClone(clone)
	return clone
end
