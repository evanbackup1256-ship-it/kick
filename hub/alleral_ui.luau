return function(Core)
	local ALLERAL_UI_LAYER = "Alleral UI layer"
	Core._AlleralUiLayer = ALLERAL_UI_LAYER
	Core.ALLERAL_UI_VERSION = Core.ALLERAL_UI_VERSION or "4.1.0-studio"
	Core.WINDUI_VERSION = Core.ALLERAL_UI_VERSION
	Core.UI_LIBRARY = "Syde"

	local SYDE_SOURCE_PATH = "ui/syde/source.luau"
	local SYDE_SOURCE_PATHS = {
		"ui/syde/source.luau",
		".alleral/cache/ui/syde/source.luau",
		"kick/ui/syde/source.luau",
	}
	local SYDE_PATCH_MARKER = "ALLERAL_SYDE_PATCH"
	local SYDE_PATCH_VERSION = 42
	local SYDE_PATCH_REQUIRED_FN = "sydePrepareDropdownDrop"
	local SYDE_SEARCH_GUARD_FN = "sydeWindowSearch"
	local SYDE_WORKSPACE_ROOTS = { "", "kick/", "workspace/", "scripts/" }
	local SYDE_RAW_URLS = {
			"https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/ui/syde/source.luau",
		}

	local THEME_ACCENTS = {
		Maclib = Color3.fromRGB(83, 252, 18),
		Private = Color3.fromRGB(83, 252, 18),
		Default = Color3.fromRGB(255, 151, 227),
		Dark = Color3.fromRGB(120, 120, 255),
		Light = Color3.fromRGB(0, 122, 255),
		Linoria = Color3.fromRGB(170, 85, 235),
		Obsidian = Color3.fromRGB(255, 120, 80),
	}

	local function genv()
		local ok, env = pcall(function()
			return getgenv and getgenv() or getfenv()
		end)
		return ok and env or {}
	end
	local ENV = genv()

	local DEFAULT_ICON_ID = "18821914323"

	local function extractIconId(icon)
		if icon == nil or icon == "" then
			return nil
		end
		if type(icon) == "number" then
			return tostring(icon)
		end
		local text = tostring(icon)
		local digits = text:match("(%d+)$")
		if digits then
			return digits
		end
		if type(Core.uiIcon) == "function" then
			local numeric = Core.uiIcon(icon)
			if type(numeric) == "string" and numeric ~= "" then
				return numeric
			end
		end
		if type(Core.windUiIcon) == "function" then
			local mapped = Core.windUiIcon(icon)
			if type(mapped) == "string" then
				local fromMapped = mapped:match("(%d+)$")
				if fromMapped then
					return fromMapped
				end
			end
		end
		return nil
	end

	local function iconImage(icon)
		return extractIconId(icon) or DEFAULT_ICON_ID
	end

	local function optionalIconImage(icon)
		if icon == nil or icon == "" then
			return nil
		end
		return iconImage(icon)
	end

	local function requiredSydePatch()
		local expected = ENV._Alleral_ExpectedVersions
		if type(expected) == "table" then
			local patch = tonumber(expected.sydePatch)
			if patch then
				return patch
			end
		end
		return SYDE_PATCH_VERSION
	end

	local function sydePatchFromSource(src)
		if type(src) ~= "string" then
			return nil
		end
		local last
		for patch in src:gmatch("ALLERAL_SYDE_PATCH%s*=%s*(%d+)") do
			last = tonumber(patch)
		end
		return last
	end

	local function sydeSourceValid(src)
		if type(src) ~= "string"
			or #src < 5000
			or src:find("<!DOCTYPE", 1, true)
			or not src:find("sydeFindChild", 1, true)
			or not src:find(SYDE_PATCH_MARKER, 1, true)
			or not src:find("sydePrepareDropdownDrop", 1, true)
			or not src:find(SYDE_PATCH_REQUIRED_FN, 1, true)
			or not src:find(SYDE_SEARCH_GUARD_FN, 1, true) then
			return false
		end
		local patch = sydePatchFromSource(src)
		local need = requiredSydePatch()
		return type(patch) == "number" and patch == need
	end

	local function sydeIoFn(name)
		if type(Core.execFunction) == "function" then
			return Core.execFunction(name)
		end
		return nil
	end

	local function purgeInvalidSydeFile(path)
		local isFile = sydeIoFn("isfile")
		local readFile = sydeIoFn("readfile")
		local deleteFile = sydeIoFn("delfile") or sydeIoFn("deletefile")
		if type(isFile) ~= "function" or type(readFile) ~= "function" or type(deleteFile) ~= "function" then
			return
		end
		local okExists, exists = pcall(isFile, path)
		if not (okExists and exists) then
			return
		end
		local okRead, src = pcall(readFile, path)
		if okRead and sydeSourceValid(src) then
			return
		end
		pcall(deleteFile, path)
	end

	local function readSydeFileAt(path)
		local readFile = sydeIoFn("readfile")
		local isFile = sydeIoFn("isfile")
		if type(readFile) ~= "function" or type(isFile) ~= "function" then
			return Core.readFile and Core.readFile(path)
		end
		local okExists, exists = pcall(isFile, path)
		if not (okExists and exists) then
			return nil
		end
		local okRead, src = pcall(readFile, path)
		return okRead and src or nil
	end

	local function tryReadSydePath(relPath)
		for _, root in ipairs(SYDE_WORKSPACE_ROOTS) do
			local full = root .. relPath
			local src = readSydeFileAt(full)
			if sydeSourceValid(src) then
				return src, "local:" .. full
			end
		end
		return nil
	end

	local function sydeRawUrls()
		local urls = {}
		local seen = {}
		local function add(url)
			if type(url) == "string" and url ~= "" and not seen[url] then
				seen[url] = true
				table.insert(urls, url)
			end
		end
		for _, url in ipairs(SYDE_RAW_URLS) do
			add(url)
		end
		local bases = (type(Core._UiRemoteBases) == "table" and Core._UiRemoteBases)
			or (type(ENV.Alleral_Core) == "table" and ENV.Alleral_Core._UiRemoteBases)
		if type(bases) == "table" then
			for _, base in ipairs(bases) do
				add(tostring(base) .. "/ui/syde/source.luau")
			end
		end
		return urls
	end

	local function readSydeSource()
		local bestSrc, bestLabel, bestPatch = nil, nil, -1

		local function consider(src, label)
			if not sydeSourceValid(src) then
				return
			end
			local patch = sydePatchFromSource(src) or 0
			if patch > bestPatch then
				bestSrc, bestLabel, bestPatch = src, label, patch
			end
		end

		if type(ENV._AlleralSydeSource) == "string" then
			consider(ENV._AlleralSydeSource, ENV._AlleralSydeSourceLabel or "memory:loader")
		end

		for _, path in ipairs(SYDE_SOURCE_PATHS) do
			purgeInvalidSydeFile(path)
			local src, label = tryReadSydePath(path)
			consider(src, label)
		end

		for _, baseUrl in ipairs(sydeRawUrls()) do
			local url = baseUrl .. "?t=" .. tostring(tick())
			local src
			if type(Core.httpGet) == "function" then
				src = Core.httpGet(url)
			end
			if not sydeSourceValid(src) then
				local http = ENV.Alleral_HTTP
				if type(http) == "table" and type(http.get) == "function" then
					src = http.get(url, 8000)
				end
			end
			consider(src, "remote:" .. baseUrl)
		end

		if not bestSrc or bestPatch ~= requiredSydePatch() then
			return nil, nil
		end

		if bestLabel and bestLabel:find("^remote:", 1, false) and type(Core.writeFile) == "function" then
			pcall(Core.writeFile, SYDE_SOURCE_PATH, bestSrc)
			pcall(Core.writeFile, ".alleral/cache/" .. SYDE_SOURCE_PATH, bestSrc)
		end

		return bestSrc, bestLabel
	end

	local function loadSyde()
		if type(ENV._AlleralSyde) == "table" then
			local patch = ENV._AlleralSyde.__AlleralPatch
			local need = requiredSydePatch()
			if type(patch) ~= "number" or patch ~= need then
				ENV._AlleralSyde = nil
				ENV._AlleralSydeSourceKey = nil
			end
		end

		local source, sourceLabel = readSydeSource()
		if not source then
			return nil, "Syde source missing (need patched ui/syde/source.luau v" .. tostring(requiredSydePatch()) .. ")"
		end
		local sourceKey = tostring(#source) .. ":" .. tostring(sourceLabel or "unknown")
		if ENV._AlleralSydeSourceKey == sourceKey and type(ENV._AlleralSyde) == "table" and type(ENV._AlleralSyde.Init) == "function" then
			local patch = ENV._AlleralSyde.__AlleralPatch
			if type(patch) == "number" and patch == requiredSydePatch() then
				return ENV._AlleralSyde
			end
		end
		ENV._AlleralSyde = nil
		local loadFn = Core.loadStringFn()
		if not loadFn then
			return nil, "load unavailable"
		end
		local chunk, err = loadFn(source, "@Syde/source")
		if not chunk then
			return nil, tostring(err or "Syde compile failed")
		end
		local ok, Syde = pcall(chunk)
		if not ok or type(Syde) ~= "table" or type(Syde.Init) ~= "function" then
			return nil, tostring(Syde or "Syde runtime failed")
		end
		if type(Syde.__AlleralPatch) ~= "number" or Syde.__AlleralPatch ~= requiredSydePatch() then
			ENV._AlleralSyde = nil
			ENV._AlleralSydeSourceKey = nil
			return nil, "Syde patch outdated (need v" .. tostring(requiredSydePatch()) .. ")"
		end
		ENV._AlleralSydeSourceKey = sourceKey
		ENV._AlleralSyde = Syde
		if type(Core.say) == "function" then
			Core.say("Syde patch v" .. tostring(Syde.__AlleralPatch) .. " from " .. tostring(sourceLabel or "unknown"))
		end
		return Syde
	end

	local function applyAccent(Syde, themeName)
		local accent = THEME_ACCENTS[themeName] or THEME_ACCENTS.Default
		if type(Syde.UpdateTheme) == "function" then
			pcall(Syde.UpdateTheme, Syde, {
				Accent = accent,
				HitBox = accent,
			})
		end
		return accent
	end

	Core._UiTabRegistry = Core._UiTabRegistry or {}
	local COLUMN_GAP = 16
	local GROUP_GAP = 10
	local STUDIO = {
		topBar = 50,
		segmentBar = 46,
		pad = 16,
		corner = 20,
		segmentGap = 8,
		pillHeight = 34,
		colors = {
			shell = Color3.fromRGB(22, 22, 24),
			shellStroke = Color3.fromRGB(72, 72, 78),
			segmentBg = Color3.fromRGB(36, 36, 40),
			pill = Color3.fromRGB(48, 48, 52),
			pillActive = Color3.fromRGB(72, 72, 78),
			pillText = Color3.fromRGB(174, 174, 178),
			pillTextActive = Color3.fromRGB(255, 255, 255),
			title = Color3.fromRGB(245, 245, 247),
			subtitle = Color3.fromRGB(142, 142, 147),
		},
	}

	local AlleralLayout = {}
	AlleralLayout._resizeToken = 0
	AlleralLayout._activeTweens = {}
	AlleralLayout._suspendUntil = 0

	function AlleralLayout.suspendResize(seconds)
		AlleralLayout._suspendUntil = math.max(AlleralLayout._suspendUntil, tick() + (tonumber(seconds) or 0.6))
	end

	function AlleralLayout.canAutoResize()
		return tick() >= (AlleralLayout._suspendUntil or 0)
	end

	function AlleralLayout.normalizeResizeOpts(opts)
		if type(opts) == "boolean" then
			return opts and { forceSize = true } or {}
		end
		return type(opts) == "table" and opts or {}
	end

	local function findChildLoose(parent, ...)
		if not parent then
			return nil
		end
		local names = { ... }
		for _, child in ipairs(parent:GetChildren()) do
			local lower = child.Name:lower()
			for _, name in ipairs(names) do
				if lower == string.lower(tostring(name)) then
					return child
				end
			end
		end
		for _, name in ipairs(names) do
			local direct = parent:FindFirstChild(name)
			if direct then
				return direct
			end
		end
		return nil
	end

	local function getTabStrip(tabsContainer)
		if not tabsContainer then
			return nil
		end
		return findChildLoose(tabsContainer, "tab", "Tab", "tb", "Tb") or tabsContainer
	end

	local function ensureCorner(instance, radius)
		if not instance or not instance:IsA("GuiObject") then
			return
		end
		local corner = instance:FindFirstChild("AlleralCorner")
		if not corner then
			corner = Instance.new("UICorner")
			corner.Name = "AlleralCorner"
			corner.Parent = instance
		end
		corner.CornerRadius = UDim.new(0, radius)
	end

	local function styleStudioTabPill(tabButton, selected)
		if not tabButton or not tabButton:IsA("GuiObject") then
			return
		end
		local title = tabButton:FindFirstChild("title")
		local indicator = tabButton:FindFirstChild("indicator")
		if indicator and indicator:IsA("GuiObject") then
			indicator.Visible = false
		end
		tabButton.AutomaticSize = Enum.AutomaticSize.X
		tabButton.Size = UDim2.new(0, 0, 0, STUDIO.pillHeight)
		tabButton.BackgroundTransparency = selected and 0.08 or 0.42
		tabButton.BackgroundColor3 = selected and STUDIO.colors.pillActive or STUDIO.colors.pill
		ensureCorner(tabButton, 12)
		local pad = tabButton:FindFirstChild("AlleralPad")
		if not pad then
			pad = Instance.new("UIPadding")
			pad.Name = "AlleralPad"
			pad.PaddingLeft = UDim.new(0, 14)
			pad.PaddingRight = UDim.new(0, 14)
			pad.Parent = tabButton
		end
		if title and title:IsA("TextLabel") then
			if tabButton.Name and tabButton.Name ~= "" then
				title.Text = tabButton.Name
			end
			title.TextSize = 13
			title.Font = selected and Enum.Font.GothamMedium or Enum.Font.Gotham
			title.TextColor3 = selected and STUDIO.colors.pillTextActive or STUDIO.colors.pillText
			title.TextXAlignment = Enum.TextXAlignment.Center
			title.TextTruncate = Enum.TextTruncate.None
			title.TextWrapped = false
			title.BackgroundTransparency = 1
			title.Size = UDim2.new(1, 0, 1, 0)
			title.Position = UDim2.new(0, 0, 0, 0)
		end
	end

	local function refreshStudioTabSelection(tabStrip, activeName)
		if not tabStrip then
			return
		end
		activeName = activeName or tabStrip:GetAttribute("AlleralActiveTab")
		for _, child in ipairs(tabStrip:GetChildren()) do
			if child:IsA("GuiObject") and child:FindFirstChild("title") then
				styleStudioTabPill(child, child.Name == activeName)
			end
		end
	end

	local function styleStudioTabStrip(tabStrip)
		if not tabStrip or not tabStrip:IsA("GuiObject") then
			return
		end
		if not tabStrip:GetAttribute("AlleralStripHooked") then
			tabStrip:SetAttribute("AlleralStripHooked", true)
			tabStrip.ChildAdded:Connect(function(child)
				task.defer(function()
					if child:IsA("GuiObject") and child:FindFirstChild("interact") then
						local interact = child.interact
						if interact:IsA("GuiButton") then
							interact.MouseButton1Click:Connect(function()
								tabStrip:SetAttribute("AlleralActiveTab", child.Name)
								task.defer(function()
									refreshStudioTabSelection(tabStrip, child.Name)
								end)
							end)
						end
					end
					refreshStudioTabSelection(tabStrip)
				end)
			end)
		end
		local layout = tabStrip:FindFirstChildOfClass("UIListLayout")
		if not layout then
			layout = Instance.new("UIListLayout")
			layout.Parent = tabStrip
		end
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, STUDIO.segmentGap)
		for _, child in ipairs(tabStrip:GetChildren()) do
			if child:IsA("GuiObject") and child:FindFirstChild("title") then
				if child:FindFirstChild("interact") and child.interact:IsA("GuiButton") and not child:GetAttribute("AlleralPillHooked") then
					child:SetAttribute("AlleralPillHooked", true)
					child.interact.MouseButton1Click:Connect(function()
						tabStrip:SetAttribute("AlleralActiveTab", child.Name)
						task.defer(function()
							refreshStudioTabSelection(tabStrip, child.Name)
						end)
					end)
				end
			end
		end
		local active = tabStrip:GetAttribute("AlleralActiveTab")
		if not active then
			for _, child in ipairs(tabStrip:GetChildren()) do
				if child:IsA("GuiObject") and child:FindFirstChild("title") and child.Visible then
					active = child.Name
					break
				end
			end
			if active then
				tabStrip:SetAttribute("AlleralActiveTab", active)
			end
		end
		refreshStudioTabSelection(tabStrip, active)
	end

	local function applyAppleChrome(main, nodes)
		if not main or not main:IsA("GuiObject") then
			return
		end
		main.BackgroundColor3 = STUDIO.colors.shell
		main.BackgroundTransparency = 0.06
		ensureCorner(main, STUDIO.corner)
		local stroke = main:FindFirstChild("AlleralStroke")
		if not stroke then
			stroke = Instance.new("UIStroke")
			stroke.Name = "AlleralStroke"
			stroke.Parent = main
		end
		stroke.Color = STUDIO.colors.shellStroke
		stroke.Transparency = 0.35
		stroke.Thickness = 1
		if nodes and nodes.top then
			local title = findChildLoose(nodes.top, "title", "Title")
			if title and title:IsA("TextLabel") then
				title.TextColor3 = STUDIO.colors.title
				title.Font = Enum.Font.GothamMedium
				title.TextSize = 15
				local sub = title:FindFirstChild("sub") or title:FindFirstChild("Sub")
				if sub and sub:IsA("TextLabel") then
					sub.TextColor3 = STUDIO.colors.subtitle
					sub.Font = Enum.Font.Gotham
					sub.TextSize = 12
				end
			end
			local separator = findChildLoose(nodes.top, "separator", "Separator")
			if separator and separator:IsA("GuiObject") then
				separator.BackgroundTransparency = 0.55
				separator.BackgroundColor3 = STUDIO.colors.shellStroke
			end
		end
	end

	local function hidePageChrome(pagesFrame)
		if not pagesFrame then
			return
		end
		local clip = findChildLoose(pagesFrame, "clipframe", "ClipFrame", "clip")
		if clip then
			local clipTitle = findChildLoose(clip, "title", "Title")
			if clipTitle and clipTitle:IsA("GuiObject") then
				clipTitle.Visible = false
			end
			for _, deco in ipairs({ "v0", "v1" }) do
				local node = clip:FindFirstChild(deco)
				if node and node:IsA("GuiObject") then
					node.Visible = false
				end
			end
		end
	end

	local function stretchSydePages(pagesFrame)
		if not pagesFrame or not pagesFrame:IsA("GuiObject") then
			return
		end
		if pagesFrame:GetAttribute("AlleralStretched") then
			return
		end
		pagesFrame:SetAttribute("AlleralStretched", true)
		pagesFrame.ClipsDescendants = true
		local clip = findChildLoose(pagesFrame, "clipframe", "ClipFrame", "clip")
		if clip and clip:IsA("GuiObject") then
			clip.AnchorPoint = Vector2.new(0, 0)
			clip.Position = UDim2.new(0, 0, 0, 0)
			clip.Size = UDim2.new(1, 0, 1, 0)
		end
	end

	local tweenService = game:GetService("TweenService")
	local MOTION_PANEL = TweenInfo.new(0.48, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local MOTION_LAYOUT = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	local function tweenGui(instance, info, props)
		if not instance or not instance:IsA("GuiObject") then
			return
		end
		local prev = AlleralLayout._activeTweens[instance]
		if prev then
			pcall(function()
				prev:Cancel()
			end)
		end
		local tw = tweenService:Create(instance, info, props)
		AlleralLayout._activeTweens[instance] = tw
		tw:Play()
		pcall(function()
			tw.Completed:Once(function()
				if AlleralLayout._activeTweens[instance] == tw then
					AlleralLayout._activeTweens[instance] = nil
				end
			end)
		end)
	end

	function AlleralLayout.getProfile()
		if type(Core.executorProfile) == "function" then
			return Core.executorProfile()
		end
		return {
			ui = { min = Vector2.new(440, 330), max = Vector2.new(860, 640), rail = 60, scale = 0.92, mobile = false },
		}
	end

	function AlleralLayout.viewport()
		local camera = workspace.CurrentCamera
		if camera then
			return camera.ViewportSize
		end
		return Vector2.new(1280, 720)
	end

	function AlleralLayout.computeSize(profile, tabCount, override)
		if override and typeof(override) == "UDim2" then
			return override
		end
		profile = profile or AlleralLayout.getProfile()
		local ui = profile.ui or {}
		local vp = AlleralLayout.viewport()
		local scale = tonumber(ui.scale) or 1
		local mobile = ui.mobile == true or profile.tier == "mobile"
		local minSize = ui.min or Vector2.new(440, 330)
		local maxSize = ui.max or Vector2.new(860, 640)
		local vpX = mobile and 0.88 or 0.92
		local vpY = mobile and 0.84 or 0.88
		local maxW = math.min(maxSize.X, vp.X * vpX)
		local maxH = math.min(maxSize.Y, vp.Y * vpY)
		tabCount = math.max(1, tonumber(tabCount) or 4)
		local heightBoost = math.min(120, tabCount * 8)
		local width = math.clamp(math.floor(820 * scale), minSize.X, maxW)
		local height = math.clamp(math.floor(620 * scale) + heightBoost, minSize.Y, maxH)
		return UDim2.fromOffset(width, height)
	end

	function AlleralLayout.findNodes(rawWindow)
		if type(rawWindow) ~= "table" then
			return nil
		end
		local main = rawWindow.Main
		if not main or not main:IsA("GuiObject") then
			return nil
		end
		return {
			main = main,
			tabs = findChildLoose(main, "tabs", "Tabs"),
			pages = findChildLoose(main, "pages", "Pages"),
			top = findChildLoose(main, "top", "Top"),
			user = findChildLoose(main, "user", "User"),
		}
	end

	function AlleralLayout.applyRailLayout(rawWindow, profile, animated)
		local nodes = AlleralLayout.findNodes(rawWindow)
		if not nodes or not nodes.tabs or not nodes.pages then
			return false
		end
		profile = profile or AlleralLayout.getProfile()
		local pad = STUDIO.pad
		local topHeight = STUDIO.topBar
		local segmentHeight = STUDIO.segmentBar
		if nodes.top and nodes.top:IsA("GuiObject") then
			topHeight = math.max(STUDIO.topBar, math.min(56, nodes.top.AbsoluteSize.Y))
		end

		applyAppleChrome(nodes.main, nodes)

		if nodes.top and nodes.top:IsA("GuiObject") then
			local topSize = UDim2.new(1, -(pad * 2), 0, topHeight)
			local topPos = UDim2.new(0, pad, 0, 8)
			if animated then
				tweenGui(nodes.top, MOTION_LAYOUT, { Size = topSize, Position = topPos })
			else
				nodes.top.Size = topSize
				nodes.top.Position = topPos
			end
		end

		if nodes.user and nodes.user:IsA("GuiObject") then
			nodes.user.AnchorPoint = Vector2.new(1, 0)
			local userPos = UDim2.new(1, -pad, 0, 10)
			if animated then
				tweenGui(nodes.user, MOTION_LAYOUT, { Position = userPos })
			else
				nodes.user.Position = userPos
			end
			ensureCorner(nodes.user, 14)
		end

		local segmentY = topHeight + 6
		nodes.tabs.AnchorPoint = Vector2.new(0, 0)
		local tabsPos = UDim2.new(0, pad, 0, segmentY)
		local tabsSize = UDim2.new(1, -(pad * 2), 0, segmentHeight)
		if animated then
			tweenGui(nodes.tabs, MOTION_LAYOUT, { Position = tabsPos, Size = tabsSize })
		else
			nodes.tabs.Position = tabsPos
			nodes.tabs.Size = tabsSize
		end
		nodes.tabs.BackgroundTransparency = 0.35
		nodes.tabs.BackgroundColor3 = STUDIO.colors.segmentBg
		ensureCorner(nodes.tabs, 14)
		if nodes.tabs:IsA("ScrollingFrame") then
			nodes.tabs.ScrollBarThickness = 0
			nodes.tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
			nodes.tabs.ScrollingDirection = Enum.ScrollingDirection.X
			nodes.tabs.CanvasSize = UDim2.new(0, 0, 0, 0)
			local scrollPad = nodes.tabs:FindFirstChild("AlleralScrollPad")
			if not scrollPad then
				scrollPad = Instance.new("UIPadding")
				scrollPad.Name = "AlleralScrollPad"
				scrollPad.PaddingLeft = UDim.new(0, 8)
				scrollPad.PaddingRight = UDim.new(0, 8)
				scrollPad.Parent = nodes.tabs
			end
		end
		local tabStrip = getTabStrip(nodes.tabs)
		styleStudioTabStrip(tabStrip)

		local contentTop = segmentY + segmentHeight + 10
		nodes.pages.AnchorPoint = Vector2.new(0, 0)
		local pagesPos = UDim2.new(0, pad, 0, contentTop)
		local pagesSize = UDim2.new(1, -(pad * 2), 1, -(contentTop + 10))
		if animated then
			tweenGui(nodes.pages, MOTION_LAYOUT, { Position = pagesPos, Size = pagesSize })
		else
			nodes.pages.Position = pagesPos
			nodes.pages.Size = pagesSize
		end
		stretchSydePages(nodes.pages)
		hidePageChrome(nodes.pages)

		rawWindow._alleralRailLayout = true
		rawWindow._alleralLayoutMode = "studio"
		return true
	end

	function AlleralLayout.relayoutColumns(_animated)
		local halfGap = math.floor(COLUMN_GAP / 2)
		local colSize = UDim2.new(0.5, -halfGap, 0, 0)
		for _, tab in ipairs(Core._UiTabRegistry or {}) do
			local layout = tab._layout
			if layout and layout.row and layout.left and layout.right then
				layout.row.Size = UDim2.new(1, 0, 0, 0)
				layout.row.AutomaticSize = Enum.AutomaticSize.Y
				local width = layout.row.AbsoluteSize.X
				if width <= 0 then
					task.defer(function()
						AlleralLayout.relayoutColumns(false)
					end)
				elseif width > 0 and width < 560 then
					layout.right.Visible = false
					layout.left.Size = UDim2.new(1, 0, 0, 0)
					layout.left.AutomaticSize = Enum.AutomaticSize.Y
				else
					layout.right.Visible = true
					layout.left.Size = colSize
					layout.left.AutomaticSize = Enum.AutomaticSize.Y
					layout.right.Size = colSize
					layout.right.AutomaticSize = Enum.AutomaticSize.Y
				end
				pcall(function()
					local rawTab = tab._rawTab or tab._sydeTab
					if rawTab and rawTab.Page then
						local page = rawTab.Page
						local columns = page:FindFirstChild("AlleralColumns", true)
						if columns then
							local y = columns.AbsoluteSize.Y + 16
							page.CanvasSize = UDim2.new(0, 0, 0, y)
						end
					end
				end)
			end
		end
	end

	function AlleralLayout.applyLayoutOnly(rawWindow, animated)
		if not AlleralLayout.canAutoResize() then
			return
		end
		AlleralLayout.applyRailLayout(rawWindow, AlleralLayout.getProfile(), animated == true)
		AlleralLayout.relayoutColumns(false)
	end

	function AlleralLayout.smartResize(window, rawWindow, settings, opts)
		opts = AlleralLayout.normalizeResizeOpts(opts)
		if type(rawWindow) ~= "table" or not rawWindow.Main then
			return
		end
		if not AlleralLayout.canAutoResize() and not opts.forceSize and not opts.layoutOnly then
			return
		end
		local profile = AlleralLayout.getProfile()
		local tabCount = #(Core._UiTabRegistry or {})
		local target = AlleralLayout.computeSize(profile, tabCount, settings and settings.Size)
		local main = rawWindow.Main
		if main and main:IsA("GuiObject") and opts.forceSize and not opts.layoutOnly then
			if opts.animated then
				tweenGui(main, MOTION_PANEL, { Size = target })
			else
				main.Size = target
			end
			rawWindow._alleralTargetSize = target
		end
		if type(window) == "table" then
			window._alleralLastSize = target
		end
		AlleralLayout.applyRailLayout(rawWindow, profile, opts.animated == true)
		AlleralLayout.relayoutColumns(false)
	end

	function AlleralLayout.wrapSydeWindowLifecycle(rawWindow, window, settings)
		if rawWindow._alleralLifecycleWrapped then
			return
		end
		rawWindow._alleralLifecycleWrapped = true
		local openDelay = 0.62
		local origSetState = rawWindow.SetState
		local origToggle = rawWindow.Toggle

		local function afterOpenMotion()
			task.delay(openDelay, function()
				AlleralLayout.applyLayoutOnly(rawWindow, true)
				if settings and settings.Size and rawWindow.Main then
					local profile = AlleralLayout.getProfile()
					local target = AlleralLayout.computeSize(profile, #(Core._UiTabRegistry or {}), settings.Size)
					if rawWindow._alleralTargetSize ~= target then
						tweenGui(rawWindow.Main, MOTION_PANEL, { Size = target })
						rawWindow._alleralTargetSize = target
					end
				end
			end)
		end

		if type(origSetState) == "function" then
			function rawWindow:SetState(state)
				AlleralLayout.suspendResize(openDelay + 0.12)
				local result = origSetState(self, state)
				if state == true then
					afterOpenMotion()
				end
				return result
			end
		end

		if type(origToggle) == "function" then
			function rawWindow:Toggle()
				local wasOpen = type(rawWindow.GetState) == "function" and rawWindow:GetState() == true
				AlleralLayout.suspendResize(openDelay + 0.12)
				local result = origToggle(self)
				if not wasOpen then
					afterOpenMotion()
				end
				return result
			end
		end
	end

	function AlleralLayout.install(window, rawWindow, settings)
		if type(rawWindow) ~= "table" then
			return
		end
		settings = type(settings) == "table" and settings or {}
		AlleralLayout.wrapSydeWindowLifecycle(rawWindow, window, settings)
		if rawWindow._alleralResizeHooked then
			AlleralLayout.applyLayoutOnly(rawWindow, false)
			return
		end
		rawWindow._alleralResizeHooked = true
		AlleralLayout.applyLayoutOnly(rawWindow, false)

		local layoutDebounce = 0
		local function scheduleLayout()
			layoutDebounce += 1
			local token = layoutDebounce
			task.delay(0.35, function()
				if token ~= layoutDebounce or not AlleralLayout.canAutoResize() then
					return
				end
				AlleralLayout.applyLayoutOnly(rawWindow, true)
			end)
		end

		local camera = workspace.CurrentCamera
		if camera then
			pcall(function()
				camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
					if not AlleralLayout.canAutoResize() then
						return
					end
					AlleralLayout.smartResize(window, rawWindow, settings, { forceSize = true, animated = true })
				end)
			end)
		end
		local nodes = AlleralLayout.findNodes(rawWindow)
		if nodes and nodes.pages then
			pcall(function()
				nodes.pages:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleLayout)
			end)
		end
	end

	local function wrapLibrary(Syde)
		local themes = { "Default", "Maclib", "Private", "Dark", "Light", "Linoria", "Obsidian" }
		local activeTheme = "Default"
		local activeWindow = nil
		local notificationsEnabled = true

		local Library = {
			Syde = Syde,
			Window = nil,
			Version = Core.ALLERAL_UI_VERSION,
			ALLERAL_UI_VERSION = Core.ALLERAL_UI_VERSION,
			_pendingNotifies = {},
			CommandPalette = {
				register = function() end,
				toggle = function() end,
			},
		}

		local function flushPendingNotifies()
			while #Library._pendingNotifies > 0 do
				local payload = table.remove(Library._pendingNotifies, 1)
				pcall(function()
					Syde:Notify({
						Title = payload.Title or "Alleral",
						Content = payload.Description or "",
						Duration = payload.Lifetime or 4,
					})
				end)
			end
		end

		local function pushNotification(info)
			info = type(info) == "table" and info or { Description = tostring(info) }
			local payload = {
				Title = info.Title or "Alleral",
				Description = info.Description or info.Content or info.Text or "",
				Lifetime = info.Lifetime or info.Duration or info.Time or 4,
			}
			if not notificationsEnabled then
				return
			end
			if activeWindow then
				pcall(function()
					Syde:Notify({
						Title = payload.Title,
						Content = payload.Description,
						Duration = payload.Lifetime,
					})
				end)
				return
			end
			table.insert(Library._pendingNotifies, payload)
		end

		function Library:GetAlleralVersion()
			return Core.ALLERAL_UI_VERSION
		end

		function Library:GetArrrelVersion()
			return Core.ALLERAL_UI_VERSION
		end

		function Library:EnsureGuiRoot()
			return true
		end

		function Library:Notification(info)
			pushNotification(info)
		end

		function Library:Notify(info)
			pushNotification(info)
		end

		function Library:ClearNotifications()
			Library._pendingNotifies = {}
			return 0
		end

		function Library:SetNotificationLower(_enabled)
			return true
		end

		function Library:RepairWindow(window)
			window = window or activeWindow or Library.Window
			local rawWindow = type(window) == "table" and (window._rawWindow or window.Main and window) or nil
			if rawWindow and type(rawWindow.SetState) == "function" then
				AlleralLayout.suspendResize(0.72)
				pcall(rawWindow.SetState, rawWindow, true)
			elseif rawWindow and type(rawWindow.Toggle) == "function" then
				AlleralLayout.suspendResize(0.72)
				pcall(rawWindow.Toggle, rawWindow)
			end
			if rawWindow then
				AlleralLayout.applyLayoutOnly(rawWindow, true)
			end
			return true
		end

		function Library:ListThemeNames()
			return themes
		end

		function Library:SetTheme(name)
			activeTheme = tostring(name or activeTheme)
			ENV.Alleral_ActiveTheme = activeTheme
			applyAccent(Syde, activeTheme)
		end

		function Library:CycleTheme(step)
			step = tonumber(step) or 1
			local index = 1
			for i, name in ipairs(themes) do
				if name == activeTheme then
					index = i
					break
				end
			end
			index = ((index - 1 + step) % #themes) + 1
			Library:SetTheme(themes[index])
			return { Name = themes[index] }
		end

		function Library:ListMotionProfiles()
			return { "fluid", "reduced" }
		end

		function Library:GetMotionProfile()
			return "fluid"
		end

		function Library:SetMotionProfile(_name)
			return true
		end

		function Library:SetSpringMotion(_enabled)
			return true
		end

		function Library:SetReducedMotion(_enabled)
			return true
		end

		function Library:GetSpringMotion()
			return true
		end

		function Library:ListProfiles()
			return { "auto", "desktop" }
		end

		function Library:ApplyProfile(_name)
			return true
		end

		function Library:GetGlassIntensity()
			return 0.55
		end

		function Library:SetGlassIntensity(_value)
			return true
		end

		function Library:SetChromeDepth(_value)
			return true
		end

		function Library:GetTooltipStyle()
			return "rich"
		end

		function Library:SetTooltipStyle(_style)
			return true
		end

		function Library:GetNotificationStyle()
			return "glass"
		end

		function Library:SetNotificationStyle(_style)
			return true
		end

		function Library:SetAmbientGlow(_enabled)
			return true
		end

		function Library:SetTabAurora(_enabled)
			return true
		end

		function Library:SetSectionLift(_enabled)
			return true
		end

		function Library:ApplyAccentPreset(name)
			Library:SetTheme(name or activeTheme)
		end

		function Library:FlashAccent()
			return true
		end

		function Library:CreateWindow(settings)
			settings = type(settings) == "table" and settings or {}
			local menuKey = settings.Keybind or ENV.Alleral_UiKeybind or Enum.KeyCode.RightControl
			ENV.Alleral_UiKeybind = menuKey

			local themeName = settings.Theme or activeTheme
			activeTheme = themeName
			applyAccent(Syde, themeName)

			local sydeWindow = Syde:Init({
				Title = settings.Title or settings.Name or "Alleral",
				SubText = settings.Subtitle or settings.SubName or "",
				Home = { Enabled = false },
				Keybind = menuKey,
			})

			if not sydeWindow then
				return nil
			end

			sydeWindow._sydeTabGroup = {
				Tab = function(_, opts)
					opts = type(opts) == "table" and opts or { Name = tostring(opts or "Tab") }
					return sydeWindow:InitTab({
						Title = opts.Name or "Tab",
						Icon = opts.Image and iconImage(opts.Image) or nil,
					})
				end,
			}

			activeWindow = sydeWindow
			Library.Window = sydeWindow
			flushPendingNotifies()
			return sydeWindow
		end

		return Library
	end

	local function uiOk(bundle)
		return type(bundle) == "table"
			and type(bundle.Library) == "table"
			and type(bundle.CreateWindow) == "function"
	end

	local function cacheUi(bundle)
		ENV.Alleral_UI = bundle
		if getgenv then
			getgenv().Alleral_UI = bundle
		end
		return bundle
	end

	function Core.loadUi()
		local cached = ENV.Alleral_UI
		if uiOk(cached) then
			return cacheUi(cached)
		end
		if cached then
			ENV.Alleral_UI = nil
		end

		local Syde, err = loadSyde()
		if not Syde then
			Core.logWarn("Alleral UI load failed: " .. tostring(err or "Syde missing"))
			return nil, err or "Syde missing"
		end

		local Library = wrapLibrary(Syde)
		ENV._AlleralUiLibrary = Library
		Core.clearUiStateBindings()

		local bundle = {
			Library = Library,
			Alleral = Library,
			WindUI = Library,
			Syde = Syde,
			CreateWindow = function(_, settings)
				return Library:CreateWindow(settings)
			end,
			Notify = function(_, info)
				Library:Notification(info)
			end,
		}
		Core.say("Alleral UI " .. tostring(Library:GetAlleralVersion()) .. " (Syde)")
		return cacheUi(bundle)
	end

	function Core.preloadUi()
		return Core.loadUi()
	end

	Core.releaseAlleralRuntime = function()
		ENV._AlleralUiLibrary = nil
		ENV._AlleralSyde = nil
		ENV._AlleralMaclib = nil
	end

	function Core.uiLibrary(bundle)
		if type(bundle) ~= "table" then
			return nil
		end
		return bundle.Alleral or bundle.Library or bundle.Syde
	end

	function Core.createWindUiGroupbox(sydeTab, uiBundle, parent)
		sydeTab = sydeTab or {}
		uiBundle = uiBundle or {}
		local serial = 0

		local function nextFlag(name, explicit)
			serial += 1
			return explicit or Core.uiElementId(name) .. "_" .. serial
		end

		local function wrapElement(applySet, meta)
			meta = type(meta) == "table" and meta or {}
			local wrapper = {
				_raw = meta.raw,
				Set = function(_, settings)
					if type(settings) == "table" then
						applySet(settings)
					else
						applySet({ CurrentValue = settings })
					end
				end,
			}
			if meta.bindKey then
				Core.bindUiState(meta.bindKey, wrapper, meta.kind or "toggle", meta.raw)
			end
			return wrapper
		end

		local function dropdownDefault(values, current, multi)
			values = values or {}
			if multi then
				local selected = Core.normalizeMultiSelection(current)
				if #selected > 0 then
					return selected
				end
				return {}
			end
			if type(current) == "table" then
				return Core.normalizeDropdownValue(current, values[1])
			end
			if current and current ~= "" then
				return tostring(current)
			end
			return values[1]
		end

		local groupbox = {}
		local function selectParent()
			if parent and type(sydeTab.SetParent) == "function" then
				pcall(sydeTab.SetParent, sydeTab, parent)
			end
		end

		function groupbox:CreateToggle(settings, id)
			selectParent()
			local handle = sydeTab:Toggle({
				Title = settings.Name,
				Description = settings.Description or settings.Tooltip or "",
				Value = settings.CurrentValue == true,
				CallBack = settings.Callback or function() end,
			})
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue == nil or not handle then
					return
				end
				local value = nextSettings.CurrentValue == true
				if type(handle.Set) == "function" then
					pcall(handle.Set, handle, value, true)
				end
			end, {
				raw = handle,
				bindKey = settings.BindKey or settings.StateKey,
				kind = "toggle",
			})
		end

		function groupbox:CreateSlider(settings, id)
			selectParent()
			local range = settings.Range or { 0, 100 }
			local minValue, maxValue = range[1], range[2]
			local increment = tonumber(settings.Increment) or Core.sliderIncrement(minValue, maxValue, settings.Increment)
			local handle = sydeTab:Slider({
				Title = settings.Name,
				Description = settings.Description or settings.Tooltip or "",
				Sliders = {
					{
						Title = " ",
						Range = { minValue, maxValue },
						Increment = increment,
						StarterValue = tonumber(settings.CurrentValue) or minValue,
						CallBack = settings.Callback or function() end,
					},
				},
			})
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue == nil then
					return
				end
				-- Syde slider handles are internal; best-effort via stored slider row if present
				if handle and type(handle.Set) == "function" then
					pcall(handle.Set, handle, tonumber(nextSettings.CurrentValue))
				end
			end, {
				raw = handle,
				bindKey = settings.BindKey or settings.StateKey,
				kind = "slider",
			})
		end

		function groupbox:CreateButton(settings, id)
			selectParent()
			local userCallback = settings.Callback or function() end
			local handle = sydeTab:Button({
				Title = settings.Name,
				Description = settings.Description or settings.Tooltip or "",
				CallBack = function()
					userCallback()
				end,
			})
			return wrapElement(function(nextSettings)
				if type(nextSettings) ~= "table" then
					return
				end
				if nextSettings.Callback then
					userCallback = nextSettings.Callback
				end
				if handle and type(handle.Set) == "function" then
					pcall(handle.Set, handle, nextSettings)
				end
			end, {
				raw = handle,
				kind = "button",
			})
		end

		function groupbox:CreateInput(settings, id)
			selectParent()
			local handle = sydeTab:TextInput({
				Title = settings.Name,
				PlaceHolder = settings.PlaceholderText or settings.Placeholder or "",
				NumberOnly = settings.AcceptedCharacters == "Numeric",
				CallBack = settings.Callback or function() end,
			})
			return wrapElement(function(nextSettings)
				if nextSettings.CurrentValue == nil then
					return
				end
				if handle and type(handle.Set) == "function" then
					pcall(handle.Set, handle, tostring(nextSettings.CurrentValue))
				end
			end, {
				raw = handle,
				bindKey = settings.BindKey or settings.StateKey,
				kind = "input",
			})
		end

		function groupbox:CreateDropdown(settings, id)
			selectParent()
			local values = settings.Options or settings.Values or {}
			local multi = settings.MultipleOptions == true or settings.Multi == true
			local current = dropdownDefault(values, settings.CurrentOption, multi)
			local starter = multi and current or tostring(current or values[1] or "")
			local handle = sydeTab:Dropdown({
				Title = settings.Name,
				Options = values,
				StarterOption = starter,
				Multi = multi,
				CallBack = function(selection)
					local userCallback = settings.Callback or function() end
					if multi then
						userCallback(Core.normalizeMultiSelection(selection))
					else
						userCallback(Core.normalizeDropdownValue(selection, values[1]))
					end
				end,
			})
			return wrapElement(function(nextSettings)
				local nextValues = nextSettings.Options or nextSettings.Values
				local pick = nextSettings.CurrentOption or nextSettings.CurrentOptions
				if not handle then
					return
				end
				if type(nextValues) == "table" then
					values = nextValues
					if type(handle.Refresh) == "function" then
						pcall(handle.Refresh, handle, values, pick)
						return
					end
				end
				if pick == nil then return end
				if type(handle.Set) == "function" then
					pcall(handle.Set, handle, pick)
				end
			end, {
				raw = handle,
				bindKey = settings.BindKey or settings.StateKey,
				kind = "dropdown",
			})
		end

		function groupbox:CreateLabel(settings, id)
			local text = type(settings) == "table" and (settings.Name or settings.Text) or tostring(settings or "")
			selectParent()
			local handle = sydeTab:Label(text)
			return {
				_raw = handle,
				Set = function(_, nextSettings)
					local nextText = type(nextSettings) == "table" and (nextSettings.Name or nextSettings.Text)
						or tostring(nextSettings or "")
					if handle and type(handle.Set) == "function" then
						pcall(handle.Set, handle, nextText)
					end
				end,
				SetVisible = function() end,
			}
		end

		function groupbox:CreateStatus(label, fields)
			local status = {
				Labels = {},
				LastValues = {},
				Visible = true,
			}
			for key, value in pairs(fields or {}) do
				status.LastValues[key] = tostring(value)
				status.Labels[key] = groupbox:CreateLabel({
					Name = tostring(key) .. ": " .. tostring(value),
				}, nextFlag(label .. "_" .. tostring(key)))
			end
			status.Labels.Summary = groupbox:CreateLabel({ Name = "" }, nextFlag(label .. "_summary"))
			function status:Update(key, value)
				local rendered = tostring(value)
				if self.LastValues[key] == rendered then
					return
				end
				self.LastValues[key] = rendered
				local row = self.Labels[key]
				if row and row.Set then
					row:Set({ Name = tostring(key) .. ": " .. rendered })
				end
			end
			function status:SetSummary(text)
				local row = self.Labels.Summary
				if row and row.Set then
					row:Set({ Name = tostring(text or "") })
				end
			end
			function status:SetVisible(_visible)
				self.Visible = _visible == true
			end
			return status
		end

		function groupbox:CreateDivider()
			groupbox:CreateLabel({ Name = "────────────" })
			return {}
		end

		return groupbox
	end

	local function ensureSydeColumns(tab)
		if tab._layout then
			return tab._layout
		end
		local rawTab = tab._sydeTab
		local page = rawTab and rawTab.Page
		if not page or not page:IsA("ScrollingFrame") then
			return nil
		end

		-- Let the engine size the scroll canvas to the real content height so
		-- groups can grow (descriptions, expanding sliders) without clipping.
		-- AutomaticCanvasSize takes an Enum.AutomaticSize value; guard the whole
		-- setup so an unsupported property can never break the group build.
		pcall(function()
			page.CanvasSize = UDim2.new(0, 0, 0, 0)
			page.AutomaticCanvasSize = Enum.AutomaticSize.Y
			page.ScrollBarThickness = 4
			local pagePad = page:FindFirstChild("AlleralPagePad")
			if not pagePad then
				pagePad = Instance.new("UIPadding")
				pagePad.Name = "AlleralPagePad"
				pagePad.PaddingTop = UDim.new(0, 4)
				pagePad.PaddingBottom = UDim.new(0, 12)
				pagePad.Parent = page
			end
		end)

		local row = Instance.new("Frame")
		row.Name = "AlleralColumns"
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.LayoutOrder = -1000
		row:SetAttribute("AlleralManaged", true)
		row.Parent = page

		local rowLayout = Instance.new("UIListLayout")
		pcall(function()
			rowLayout.FillDirection = Enum.FillDirection.Horizontal
			rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
			rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
			rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
			rowLayout.Padding = UDim.new(0, COLUMN_GAP)
		end)
		rowLayout.Parent = row

		local function makeColumn(name, order)
			local column = Instance.new("Frame")
			column.Name = name
			column.BackgroundTransparency = 1
			column.Size = UDim2.new(0.5, -math.ceil(COLUMN_GAP / 2), 0, 0)
			column.AutomaticSize = Enum.AutomaticSize.Y
			column.LayoutOrder = order
			column.Parent = row
			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Vertical
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Padding = UDim.new(0, GROUP_GAP)
			layout.Parent = column
			return column
		end

		tab._layout = {
			row = row,
			left = makeColumn("LeftColumn", 1),
			right = makeColumn("RightColumn", 2),
			orders = { 0, 0 },
		}
		task.defer(function()
			AlleralLayout.relayoutColumns(false)
		end)
		return tab._layout
	end

	function Core.wrapUiTab(rawTab, uiBundle, window)
		local tab = {
			_rawTab = rawTab,
			_sydeTab = rawTab,
			_macTab = rawTab,
			_ui = uiBundle,
			_window = window,
			_columnCount = 2,
		}
		table.insert(Core._UiTabRegistry, tab)

		function tab:CreateGroupbox(settings)
			settings = settings or {}
			local name = settings.Name or "Group"
			if not rawTab or type(rawTab.Section) ~= "function" then
				Core.logWarn("CreateGroupbox skipped — tab missing for " .. tostring(name))
				return Core.createStubUiGroup(name)
			end
			local layout = ensureSydeColumns(self)
			local columnIndex = math.clamp(tonumber(settings.Column) or 1, 1, 2)
			local column = layout and (columnIndex == 2 and layout.right or layout.left)
			if not column then
				return Core.createWindUiGroupbox(rawTab, uiBundle)
			end

			layout.orders[columnIndex] += 1
			local group = Instance.new("Frame")
			group.Name = "Group_" .. Core.uiElementId(name)
			group.BackgroundTransparency = 1
			group.Size = UDim2.new(1, 0, 0, 0)
			group.AutomaticSize = Enum.AutomaticSize.Y
			group.LayoutOrder = layout.orders[columnIndex]
			group.Parent = column
			local groupLayout = Instance.new("UIListLayout")
			groupLayout.FillDirection = Enum.FillDirection.Vertical
			groupLayout.SortOrder = Enum.SortOrder.LayoutOrder
			groupLayout.Padding = UDim.new(0, GROUP_GAP)
			groupLayout.Parent = group

			local title = Instance.new("TextLabel")
			title.Name = "GroupTitle"
			title.BackgroundTransparency = 1
			title.Size = UDim2.new(1, 0, 0, 22)
			title.Font = Enum.Font.GothamMedium
			title.TextSize = 12
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextColor3 = STUDIO.colors.subtitle
			title.Text = name
			title.LayoutOrder = 0
			title.Parent = group

			return Core.createWindUiGroupbox(rawTab, uiBundle, group)
		end

		function tab:BuildThemeGroupbox(column)
			local group = Core.buildUiGroup(tab, "Appearance", column or 1)
			local lib = Core.uiLibrary(uiBundle)
			local themes = (lib and type(lib.ListThemeNames) == "function" and lib:ListThemeNames())
				or { "Default", "Maclib", "Linoria", "Obsidian" }
			local current = ENV.Alleral_ActiveTheme or "Default"
			group:CreateDropdown("Theme preset", themes, current, function(selected)
				if lib and type(lib.SetTheme) == "function" then
					pcall(lib.SetTheme, lib, selected)
				end
				ENV.Alleral_ActiveTheme = selected
				Core.notify("Theme", "Applied " .. tostring(selected), 2, "success")
			end, "Syde accent themes.")
			group:CreateButton("Next theme", function()
				if lib and type(lib.CycleTheme) == "function" then
					local ok, nextTheme = pcall(function()
						return lib:CycleTheme(1)
					end)
					if ok and type(nextTheme) == "table" and nextTheme.Name then
						Core.notify("Theme", "Applied " .. tostring(nextTheme.Name), 2, "success")
					end
				end
			end, "Cycle through theme presets.")
			return group
		end

		function tab:Select()
			if rawTab and type(rawTab.Select) == "function" then
				pcall(rawTab.Select, rawTab)
			end
		end

		return tab
	end

	function Core.buildUiWindow(ui, settings)
		settings = settings or {}
		local lib = ui and ui.Library
		if not lib or type(lib.CreateWindow) ~= "function" then
			return nil
		end
		local profile = AlleralLayout.getProfile()
		if not settings.Size then
			settings.Size = AlleralLayout.computeSize(profile, 4, nil)
		end
		local rawWindow = lib:CreateWindow(settings)
		if not rawWindow then
			Core.logWarn("Syde window create failed")
			return nil
		end
		local window = {
			_rawWindow = rawWindow,
			_nlWindow = rawWindow,
			_ui = ui,
			_library = lib,
			_initialized = false,
			_tabGroup = rawWindow._sydeTabGroup or rawWindow._macTabGroup,
			_alleralSettings = settings,
		}
		Core.registerUiWindow(window)
		Core.flushPendingNotifications()

		local initialSize = settings.Size or AlleralLayout.computeSize(profile, 4, nil)
		if rawWindow.Main and rawWindow.Main:IsA("GuiObject") then
			rawWindow.Main.Size = initialSize
			rawWindow._alleralTargetSize = initialSize
		end
		AlleralLayout.install(window, rawWindow, settings)

		function window:AddTab(name, icon)
			local tabGroup = self._tabGroup
			if not tabGroup or type(tabGroup.Tab) ~= "function" then
				return nil
			end
			return tabGroup:Tab({ Name = name, Image = icon and iconImage(icon) or nil })
		end

		function window:Toggle()
			AlleralLayout.suspendResize(0.72)
			if self._rawWindow and type(self._rawWindow.Toggle) == "function" then
				pcall(self._rawWindow.Toggle, self._rawWindow)
			elseif self._rawWindow and type(self._rawWindow.SetState) == "function" then
				pcall(self._rawWindow.SetState, self._rawWindow, not self._rawWindow:GetState())
			end
		end

		if type(rawWindow.SetState) == "function" then
			AlleralLayout.suspendResize(0.72)
			pcall(rawWindow.SetState, rawWindow, true)
		elseif type(rawWindow.GetState) == "function" and rawWindow:GetState() == false and type(rawWindow.Toggle) == "function" then
			AlleralLayout.suspendResize(0.72)
			pcall(rawWindow.Toggle, rawWindow)
		end
		return window
	end

	function Core.buildUiTab(section, name, icon, columns, id)
		local resolve = Core.resolveUiWindow
		local window = type(resolve) == "function" and resolve(section) or nil
		if type(window) ~= "table" or not window._rawWindow then
			Core.logWarn("buildUiTab skipped — window missing")
			return Core.wrapUiTab(nil, type(section) == "table" and section._ui or nil, window)
		end
		local tabGroup = window._tabGroup or window._rawWindow._sydeTabGroup
		if not tabGroup or type(tabGroup.Tab) ~= "function" then
			Core.logWarn("buildUiTab skipped — tab group missing")
			return Core.wrapUiTab(nil, window._ui, window)
		end
		local rawTab = tabGroup:Tab({ Name = name, Image = icon and iconImage(icon) or nil })
		local wrapped = Core.wrapUiTab(rawTab, window._ui or (type(section) == "table" and section._ui) or nil, window)
		wrapped._columnCount = math.max(1, tonumber(columns) or 2)
		if not window._defaultTab then
			window._defaultTab = rawTab
		end
		task.defer(function()
			if window._rawWindow then
				AlleralLayout.applyLayoutOnly(window._rawWindow, false)
			end
		end)
		return wrapped
	end

	function Core.buildUiGroup(tab, name, column, callbackWrapper, icon, id)
		name = tostring(name or "Group")
		if type(tab) ~= "table" or type(tab.CreateGroupbox) ~= "function" then
			return Core.createStubUiGroup(name)
		end
		local groupbox = tab:CreateGroupbox({
			Name = name,
			Column = column or 1,
			Icon = icon,
		})
		if callbackWrapper then
			return Core.wrapUiGroup(groupbox, callbackWrapper)
		end
		return Core.wrapUiGroup(groupbox)
	end

	function Core.finalizeGameUi(window, ui, options)
		options = type(options) == "table" and options or {}
		if type(window) == "table" and window._rawWindow and not window._initialized then
			window._initialized = true
			task.defer(function()
				pcall(function()
					local rawWindow = window._rawWindow
					if rawWindow and type(rawWindow.SetState) == "function" then
						AlleralLayout.suspendResize(0.72)
						rawWindow:SetState(true)
					elseif rawWindow and type(rawWindow.GetState) == "function" and rawWindow:GetState() == false and type(rawWindow.Toggle) == "function" then
						AlleralLayout.suspendResize(0.72)
						rawWindow:Toggle()
					end
					local defaultTab = window._defaultTab
					if defaultTab and type(defaultTab.Select) == "function" then
						defaultTab:Select()
					end
					task.delay(0.75, function()
						AlleralLayout.smartResize(window, rawWindow, options, { forceSize = true, animated = true })
					end)
				end)
			end)
		end
		if type(Core.setupHubKeybinds) == "function" then
			pcall(Core.setupHubKeybinds, {
				window = window,
				ui = ui or window._ui or ENV.Alleral_UI,
				uiKey = ENV.Alleral_UiKeybind,
			})
		end
		if type(Core.registerExploitCommandPalette) == "function" then
			pcall(Core.registerExploitCommandPalette, window, ui)
		end
		if options.notify ~= false then
			Core.notifyBootReady({
				Name = options.Name or "Alleral",
				Subtitle = options.Subtitle,
			})
		end
		return window
	end

	function Core.repairUiWindow(window)
		window = window or ENV.Alleral_UiWindow
		if type(window) ~= "table" or not window._rawWindow then
			return false
		end
		local rawWindow = window._rawWindow
		if type(rawWindow.SetState) == "function" then
			pcall(rawWindow.SetState, rawWindow, true)
		end
		AlleralLayout.applyLayoutOnly(rawWindow, true)
		AlleralLayout.smartResize(window, rawWindow, window._alleralSettings, { forceSize = true, animated = true })
		return true
	end

	function Core.refreshAllTabColumns()
		AlleralLayout.relayoutColumns()
		local window = ENV.Alleral_UiWindow
		if type(window) == "table" and window._rawWindow then
			AlleralLayout.applyLayoutOnly(window._rawWindow, false)
		end
		return true
	end

	Core.notifyWindUi = function(info)
		local ui = ENV.Alleral_UI
		if ui and type(ui.Notify) == "function" then
			pcall(ui.Notify, ui, info)
		end
	end
end
