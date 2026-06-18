getgenv().Alleral_State = getgenv().Alleral_State or {}

local Core = getgenv().Alleral_Core
if not Core or not Core.assertLoader or not Core.assertLoader() then
	return
end

local VERSION = "0.1.1"
local PLACE_ID = 2753915549
local SCRIPT_STATUS = "broken"
local state = getgenv().Alleral_State
local connections = {}
local loops = {}
local loopControllers = {}

local ui
local bootErr
Core, ui, bootErr = Core.boot(state)
if not Core or not ui then
	local msg = bootErr or "boot failed"
	getgenv().Alleral_StartupFailed = msg
	local coreRef = Core or getgenv().Alleral_Core
	if coreRef and type(coreRef.logWarn) == "function" then
		coreRef.logWarn(msg)
	else
		warn("[Alleral] " .. tostring(msg))
	end
	return
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local SETTINGS_FILE = "blox_fruit.json"
local SETTINGS_EXCLUDE = {
	HubRunning = true,
}
local defaults = {
	HubRunning = true,
	AntiAFK = true,
	MaintenanceAcknowledged = false,
}

local savedKeys
local saveSettings
saveSettings, savedKeys = Core.initSettings(state, defaults, SETTINGS_FILE, SETTINGS_EXCLUDE)

local function notify(title, text, duration, notifyType)
	Core.notify(title, text, duration, notifyType)
end

local function leaderstat(name)
	local folder = LocalPlayer:FindFirstChild("leaderstats")
	local value = folder and folder:FindFirstChild(name)
	if value and (value:IsA("IntValue") or value:IsA("NumberValue") or value:IsA("StringValue")) then
		return tostring(value.Value)
	end
	return "?"
end

local MAINTENANCE_REASONS = {
	"Combat remotes were renamed after the latest Blox Fruit patch.",
	"Quest NPC paths changed and old tween routes no longer resolve.",
	"Fruit detection hooks need to be rebuilt for the new inventory UI.",
	"Sea event timers and raid join flows are not mapped yet.",
}

local PLANNED_FEATURES = {
	"Auto farm selected mob levels",
	"Auto quest progression and boss raids",
	"Fruit ESP and rarity alerts",
	"Auto buy fighting styles and upgrades",
	"Safe teleport helpers between seas",
}

local VERSION_HISTORY = {
	{ version = "0.1.1", note = "Performance toggles (FPS/RTX/black screen) via shared Core helpers." },
	{ version = "0.1.0", note = "Maintenance shell only. Automation disabled after game update." },
	{ version = "0.0.1", note = "Internal prototype — never shipped publicly." },
}

local function formatBulletList(items)
	local lines = {}
	for index, item in ipairs(items) do
		table.insert(lines, tostring(index) .. ". " .. item)
	end
	return table.concat(lines, "\n")
end

local function validatePlace()
	if game.PlaceId ~= PLACE_ID then
		Core.logWarn("Blox Fruit script loaded on unexpected place: " .. tostring(game.PlaceId))
	end
end

validatePlace()

notify(
	"Alleral",
	"Blox Fruit is under maintenance. Automation is disabled until the script is updated.",
	8,
	"warning"
)

local window = Core.buildUiWindow(ui, Core.uiWindowSettings({
	Subtitle = "Blox Fruit · v" .. VERSION .. " · Maintenance",
	Icon = "anchor",
	Theme = "Default",
}))
if not window or not window._rawWindow then
	getgenv().Alleral_StartupFailed = "UI window failed"
	Core.logWarn("UI window failed — aborting")
	return
end
local section = Core.buildUiSection(window)
Core.buildExploitHub(section, {
	window = window,
	ui = ui,
	state = state,
	loops = loopControllers,
	version = VERSION,
	scriptId = "blox_fruit",
	gameName = "Blox Fruit",
	gameStats = { Status = "Maintenance", Level = "?", Beli = "?" },
	statsTick = function(status)
		status:Update("Status", "Maintenance")
		status:Update("Level", leaderstat("Level") or leaderstat("Lvl") or "?")
		status:Update("Beli", leaderstat("Beli") or leaderstat("Money") or "?")
	end,
	automationFlags = {},
	saveFn = saveSettings,
})
local statusTab = Core.buildUiTab(section, "Status", 10734950309, 1, "status")

local saveWrap = Core.onUiSave(saveSettings)
local notice = Core.buildUiGroup(statusTab, "Script status", 1, saveWrap, nil, "notice")
local info = Core.buildUiGroup(statusTab, "Details", 2, saveWrap, nil, "info")
local roadmap = Core.buildUiGroup(statusTab, "Restore roadmap", 1, saveWrap, nil, "roadmap")
local history = Core.buildUiGroup(statusTab, "Version history", 2, saveWrap, nil, "history")

notice:CreateLabel("This game script is temporarily broken.")
notice:CreateLabel("Blox Fruit received a major update and the automation layer needs to be rebuilt.")
notice:CreateLabel("You can keep the hub open, but no farm/combat features will run in this build.")
notice:CreateButton("Acknowledge maintenance notice", function()
	state.MaintenanceAcknowledged = true
	saveSettings()
	notify("Alleral", "Maintenance notice acknowledged.", 3)
end, "Dismisses the startup warning for this session.")
notice:CreateButton("Copy maintenance summary", function()
	local summary = table.concat({
		"Blox Fruit script status: " .. SCRIPT_STATUS,
		"Version: v" .. VERSION,
		"Place ID: " .. tostring(PLACE_ID),
		"",
		"Known blockers:",
		formatBulletList(MAINTENANCE_REASONS),
		"",
		"Planned restore list:",
		formatBulletList(PLANNED_FEATURES),
	}, "\n")
	if setclipboard then
		pcall(setclipboard, summary)
		notify("Alleral", "Maintenance summary copied.", 3)
	else
		notify("Alleral", "Clipboard unavailable on this executor.", 4, "warning")
	end
end, "Copies a short report you can paste into support tickets.")

info:CreateLabel("Script version: v" .. VERSION)
info:CreateLabel("Place ID: " .. tostring(PLACE_ID))
info:CreateLabel("Status flag: " .. SCRIPT_STATUS)
info:CreateLabel("Automation loops: disabled")
info:CreateLabel("Hub shell: active")
info:CreateLabel("Why it is broken:")
for _, reason in ipairs(MAINTENANCE_REASONS) do
	info:CreateLabel("• " .. reason)
end
info:CreateLabel("Planned when restored:")
for _, feature in ipairs(PLANNED_FEATURES) do
	info:CreateLabel("• " .. feature)
end

roadmap:CreateLabel("Restore order once the game API is mapped again:")
roadmap:CreateLabel("1. Remote scan + combat hooks")
roadmap:CreateLabel("2. Mob farm loops and quest routing")
roadmap:CreateLabel("3. Fruit ESP and inventory helpers")
roadmap:CreateLabel("4. Sea travel and raid automation")
roadmap:CreateButton("Notify when I open the script", function()
	if state.MaintenanceAcknowledged then
		notify("Alleral", "You already acknowledged the maintenance notice.", 3)
		return
	end
	state.MaintenanceAcknowledged = true
	saveSettings()
	notify("Alleral", "Startup notice recorded for this session.", 3)
end, "Marks the maintenance banner as seen.")

history:CreateLabel("Recent script builds:")
for _, entry in ipairs(VERSION_HISTORY) do
	history:CreateLabel("v" .. entry.version .. " — " .. entry.note)
end
history:CreateLabel("Next target build: v0.2.0 (farm + quest restore)")
history:CreateButton("Open support hint", function()
	notify(
		"Alleral",
		"Report Blox Fruit issues with your executor name, sea, and level. Automation is intentionally off in v" .. VERSION .. ".",
		6
	)
end, "Shows what to include if you report this script.")

info:CreateToggle("Anti AFK", state.AntiAFK ~= false, "Still keeps you from idling out while waiting for fixes.", function(enabled)
	state.AntiAFK = enabled
	if enabled then
		Core.setupAntiAfk(LocalPlayer)
	end
end)
info:CreateButton("Save now", saveSettings)

local config = Core.buildUiGroup(statusTab, "Save / reset", 1, nil, nil, "config")
config:CreateButton("Reset settings", function()
	local env = getgenv and getgenv() or {}
	if type(env.delfile) == "function" then
		pcall(env.delfile, "Alleral_Configs/" .. SETTINGS_FILE)
	end
	Core.mergeDefaults(state, defaults)
	for key in pairs(SETTINGS_EXCLUDE) do
		if key ~= "HubRunning" then
			state[key] = defaults[key]
		end
	end
	saveSettings()
	notify("Alleral", "Settings reset.", 4)
end, "Clears saved config and restores defaults.")

statusTab:BuildThemeGroupbox(2)
Core.buildConfigProfileGroup(statusTab, {
	state = state,
	savedKeys = savedKeys,
	saveFn = saveSettings,
	version = VERSION,
	column = 1,
})
Core.buildStandardSettingsExtras(statusTab, Core.settingsExtrasOptions(window, ui, state, savedKeys, saveSettings, SETTINGS_FILE, VERSION, {
	gameId = "blox_fruit",
	placeId = PLACE_ID,
}))

Core.finalizeGameUi(window, ui, {
	Subtitle = "Blox Fruit · v" .. VERSION .. " · Maintenance",
})

if state.AntiAFK ~= false then
	Core.setupAntiAfk(LocalPlayer)
end

saveSettings()

state.Alleral_Unload = function()
	state.HubRunning = false
	Core.stopAutomation(state, connections, loopControllers, loops)
end
