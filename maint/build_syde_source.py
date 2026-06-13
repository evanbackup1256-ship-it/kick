#!/usr/bin/env python3
"""Merge upstream Syde with Alleral compat fixes into ui/syde/source.luau."""

from __future__ import annotations

import re
import sys
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UPSTREAM = ROOT / "ui" / "syde" / "upstream.luau"
COMPAT = ROOT / "ui" / "syde" / "compat.luau"
PATCHES = ROOT / "ui" / "syde" / "patches"
OUT = ROOT / "ui" / "syde" / "source.luau"
UPSTREAM_SHA256 = "109eb48ed795597161a57a0cb0cf4808532c1d0b2bd2fa420e758e9792f5cedf"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_block(text: str, start: str, end: str) -> str:
    i = text.index(start)
    j = text.index(end, i)
    return text[i:j]


def replace_from(text: str, start: str, new_tail: str) -> str:
    i = text.index(start)
    return text[:i] + new_tail


def replace_between(text: str, start: str, end: str, new_body: str) -> str:
    i = text.index(start)
    j = text.index(end, i)
    return text[:i] + new_body + text[j:]


def convert_dropdown_block(block: str, page_expr: str, return_name: str) -> str:
    block = re.sub(
        r"local dropdown = sydeClonePageTemplate\([^)]+\)",
        f'local dropdown = sydeClonePageTemplate({page_expr}, "Dropdown")',
        block,
        count=1,
    )
    block = re.sub(
        r"local dropdown = .*?:Clone\(\)",
        f'local dropdown = sydeClonePageTemplate({page_expr}, "Dropdown")',
        block,
        count=1,
    )
    insert = (
        f'\t\t\tlocal drop = sydePrepareDropdownDrop(dropdown)\n'
        f'\t\t\tif not drop or not drop.Container then\n'
        f'\t\t\t\twarn("[Syde] Skipping dropdown: " .. tostring(data.Title))\n'
        f"\t\t\t\treturn {return_name}\n"
        f"\t\t\tend\n"
    )
    anchor = "dropdown.Name = data.Title\n"
    if anchor in block and "sydePrepareDropdownDrop(dropdown)" not in block:
        block = block.replace(anchor, anchor + insert, 1)
    block = block.replace("dropdown.dropholder.drop.selected.Text = data.PlaceHolder", "sydeSetDropSelectedText(drop, data.PlaceHolder)")
    block = block.replace("dropdown.dropholder.drop", "drop")
    return block


def adapt_modal(block: str) -> str:
    return block


def patch_ui_setup(text: str) -> str:
    old = """--@UiSetup
local ui = Library
local window = ui.main
local top = window.top
local tabs = window.tabs.tab
local pages = window.pages"""
    new = """--@UiSetup
local ui = sydeBindUi(Library)
local window = ui.main
if not window then
\tsydeWarn("[Syde] Library missing main frame")
end
local top = window and sydeFindChild(window, "top", "Top")
local tabsContainer = window and sydeFindChild(window, "tabs", "Tabs")
local tabs = tabsContainer and sydeFindChild(tabsContainer, "tab", "Tab", "tb", "Tb")
local pages = window and sydeFindChild(window, "pages", "Pages")"""
    if old not in text:
        raise RuntimeError("Syde UI setup anchor missing")
    return text.replace(old, new, 1)


def patch_dropdown_template(text: str) -> str:
    return text.replace(
        "local OptionButton = drop.Container.Option\n",
        "local OptionButton = drop.Container.Option\n\t\t\t\t\tsydeSanitizeUiClone(OptionButton)\n",
    )


def patch_ui_main_access(text: str) -> str:
    text = text.replace("Library.main", "window")
    text = text.replace("ui.main.pages", "pages")
    text = text.replace(
        "tweenservice:Create(logo.Title, TweenInfo.new(2, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play()",
        "do local _logoTitle = sydeTitleLabel(logo); if _logoTitle then tweenservice:Create(_logoTitle, TweenInfo.new(2, Enum.EasingStyle.Exponential), {TextTransparency = 0}):Play() end end",
    )
    return text


def silence_syde_logging(text: str) -> str:
    """Route Syde print/warn through silent Alleral compat stubs."""
    text = re.sub(r"\bprint\s*\(", "sydeLog(", text)
    text = re.sub(r"\bwarn\s*\(", "sydeWarn(", text)
    return text


def patch_slider_labels(text: str) -> str:
    text = text.replace(
        "Slider.Title.Text = Options.Title",
        "do local _sliderTitle = sydeSliderLabel(Slider); if _sliderTitle then _sliderTitle.Text = Options.Title end end",
    )

    def wrap_slider_create(source: str, target: str) -> str:
        prefix = f"tweenservice:Create({target},"
        play_suffix = ":Play()"
        out: list[str] = []
        i = 0
        while i < len(source):
            idx = source.find(prefix, i)
            if idx == -1:
                out.append(source[i:])
                break
            out.append(source[i:idx])
            paren_start = source.find("(", idx)
            if paren_start == -1:
                out.append(source[idx:])
                break
            depth = 0
            j = paren_start
            while j < len(source):
                ch = source[j]
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            if j >= len(source) or source[j + 1 : j + 1 + len(play_suffix)] != play_suffix:
                out.append(source[idx : idx + len(prefix)])
                i = idx + len(prefix)
                continue
            args = source[idx + len(prefix) : j]
            out.append(
                "do local _sliderTitle = sydeSliderLabel(Slider); "
                f"if _sliderTitle then tweenservice:Create(_sliderTitle,{args}):Play() end end"
            )
            i = j + 1 + len(play_suffix)
        return "".join(out)

    for target in ("Slider.Title", "sydeSliderLabel(Slider)"):
        text = wrap_slider_create(text, target)

    return text


def patch_slider_drag(text: str) -> str:
    pattern = re.compile(
        r"^(\t*)Slider\.slide\.Interact\.MouseButton1Down:Connect\(function\(\)\s*\n"
        r"\1\tdragging = true\s*\n"
        r"\1end\)\s*\n\s*\n"
        r"\1Slider\.slide\.Interact\.MouseButton1Up:Connect\(function\(\)\s*\n"
        r"\1\tdragging = false\s*\n"
        r"\1end\)",
        re.MULTILINE,
    )

    def repl(match: re.Match[str]) -> str:
        indent = match.group(1)
        inner = indent + "\t"
        return (
            f"{indent}sydeConnectSliderDrag(Slider.slide, function()\n"
            f"{inner}dragging = true\n"
            f"{indent}end, function()\n"
            f"{inner}dragging = false\n"
            f"{indent}end)"
        )

    return pattern.sub(repl, text)


def wrap_option_tween(source: str, target: str, var_name: str) -> str:
    prefix = f"tweenservice:Create({target},"
    play_suffix = ":Play()"
    out: list[str] = []
    i = 0
    while i < len(source):
        idx = source.find(prefix, i)
        if idx == -1:
            out.append(source[i:])
            break
        out.append(source[i:idx])
        paren_start = source.find("(", idx)
        if paren_start == -1:
            out.append(source[idx:])
            break
        depth = 0
        j = paren_start
        while j < len(source):
            ch = source[j]
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        if j >= len(source) or source[j + 1 : j + 1 + len(play_suffix)] != play_suffix:
            out.append(source[idx : idx + len(prefix)])
            i = idx + len(prefix)
            continue
        args = source[idx + len(prefix) : j]
        out.append(
            f"do local _optionLabel = sydeOptionLabel({var_name}); "
            f"if _optionLabel then tweenservice:Create(_optionLabel,{args}):Play() end end"
        )
        i = j + 1 + len(play_suffix)
    return "".join(out)


def patch_option_labels(text: str) -> str:
    text = re.sub(
        r"(local option = OptionButton:Clone\(\)\n)(\s+)(option\.Title\.Text = OptionText)",
        r"\1\2sydeSanitizeUiClone(option)\n\2local optionLabel = sydeOptionLabel(option)\n\2if optionLabel then\n\2\toptionLabel.Text = OptionText\n\2end",
        text,
    )
    text = re.sub(
        r'(\s+)if option:IsA\("Frame"\) and option:FindFirstChild\("Title"\) then',
        r'\1local optionLabel = sydeOptionLabel(option)\n\1if option:IsA("Frame") and optionLabel then',
        text,
    )
    text = text.replace(
        "local optionText = option.Title.Text:lower()",
        "local optionText = optionLabel.Text:lower()",
    )
    text = text.replace(
        "SelectedOptions[option.Title.Text]",
        "SelectedOptions[optionLabel.Text]",
    )
    for target, var_name in (("option.Title", "option"), ("opt.Title", "opt")):
        text = wrap_option_tween(text, target, var_name)
    text = text.replace(
        "do local _optionLabel = sydeOptionLabel(option); if _optionLabel then tweenservice:Create(_optionLabel,",
        "if optionLabel then tweenservice:Create(optionLabel,",
    )
    text = re.sub(
        r"(if optionLabel then tweenservice:Create\(optionLabel,[^\n]+\):Play\(\)) end end",
        r"\1 end",
        text,
    )
    return text


def patch_option_clicks(text: str) -> str:
    return text.replace(
        "option.Interact.MouseButton1Click:Connect(function()",
        "sydeConnectClick(option, function()",
    )


def patch_normalized_labels(text: str) -> str:
    text = text.replace(
        "LOADER.loader.profile.Title.TextTransparency = 1",
        "do local _profileTitle = sydeLoaderProfileLabel(LOADER); if _profileTitle then _profileTitle.TextTransparency = 1 end end",
    )
    text = text.replace(
        "LOADER.loader.profile.Title.Text = Config.Name",
        "do local _profileTitle = sydeLoaderProfileLabel(LOADER); if _profileTitle then _profileTitle.Text = Config.Name end end",
    )
    text = text.replace(
        "LOADER.loader.profile.Title.Text = LoaderConfig.Name",
        "do local _profileTitle = sydeLoaderProfileLabel(LOADER); if _profileTitle then _profileTitle.Text = LoaderConfig.Name end end",
    )
    text = text.replace(
        'if clone:FindFirstChild("Title") then\n\t\t\t\tclone.Title.Text = value\n\t\t\tend',
        "do local _cloneTitle = sydeTitleLabel(clone); if _cloneTitle then _cloneTitle.Text = value end end",
    )
    notif_anchor = "\t\tlocal Notification = Library.Notification.Default:Clone()\n\t\tNotification.Visible = true"
    notif_insert = notif_anchor + "\n\t\tlocal notificationTitle = sydeTitleLabel(Notification)"
    if notif_anchor in text and "local notificationTitle = sydeTitleLabel(Notification)" not in text:
        text = text.replace(notif_anchor, notif_insert, 1)
    text = text.replace(
        "Notification.Title.Text = NotifData.Title",
        "if notificationTitle then notificationTitle.Text = NotifData.Title end",
    )
    text = text.replace(
        "syde:WiggleText(Notification.Title)",
        "if notificationTitle then syde:WiggleText(notificationTitle) end",
    )
    text = text.replace(
        "tweenservice:Create(Notification.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 40,0, 10)}):Play()",
        "if notificationTitle then tweenservice:Create(notificationTitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 40,0, 10)}):Play() end",
    )
    text = text.replace(
        '\t\t\tlocal Section =  sydeClonePageTemplate(pages.page, "Section")\n\t\t\tSection.Visible = true\n\t\t\tSection.Title.Text = Title',
        '\t\t\tlocal Section =  sydeClonePageTemplate(pages.page, "Section")\n\t\t\tSection.Visible = true\n\t\t\tlocal sectionTitle = sydeTitleLabel(Section)\n\t\t\tif sectionTitle then sectionTitle.Text = Title end',
    )
    text = text.replace(
        "Section.Title.Position = UDim2.new(0, 0,0, 0)",
        "if sectionTitle then sectionTitle.Position = UDim2.new(0, 0,0, 0) end",
    )
    text = text.replace(
        "Section.Title.Position = UDim2.new(0, 25,0, 0)",
        "if sectionTitle then sectionTitle.Position = UDim2.new(0, 25,0, 0) end",
    )
    text = text.replace(
        '\t\t\tlocal EnchancedView = sydeClonePageTemplate(pages.page, "3DView")\n\t\t\tEnchancedView.Visible = true\n\t\t\tEnchancedView.Parent = Page\n\t\t\tEnchancedView.Title.Text = Viewdata.Title',
        '\t\t\tlocal EnchancedView = sydeClonePageTemplate(pages.page, "3DView")\n\t\t\tEnchancedView.Visible = true\n\t\t\tEnchancedView.Parent = Page\n\t\t\tlocal viewTitle = sydeTitleLabel(EnchancedView)\n\t\t\tif viewTitle then viewTitle.Text = Viewdata.Title end',
    )
    text = text.replace(
        "drop.Selected.Text = OptionText",
        "sydeSetDropSelectedText(drop, OptionText)",
    )
    return text


def patch_runtime_safety(text: str) -> str:
    text = text.replace("setclipboard(", "sydeSetClipboard(")
    text = text.replace(
        "local screenSize =      workspace.CurrentCamera.ViewportSize",
        "local screenSize =      sydeGetCurrentCamera().ViewportSize",
    )
    text = text.replace(
        "local camera =          workspace.CurrentCamera",
        "local camera =          sydeGetCurrentCamera()",
    )
    text = text.replace(
        "local camera = workspace.CurrentCamera",
        "local camera = sydeGetCurrentCamera()",
    )
    text = text.replace("RunService.RenderStepped:wait()", "RunService.RenderStepped:Wait()")
    text = text.replace(
        "if dragging and input.UserInputType == Enum.UserInputType.MouseMovement  or input.UserInputType == Enum.UserInputType.Touch  then",
        "if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then",
    )
    text = text.replace(
        "table.remove(notifications, table.find(notifications, Notification))",
        "local notificationIndex = table.find(notifications, Notification)\n\t\t\t\tif notificationIndex then table.remove(notifications, notificationIndex) end",
    )
    text = text.replace(
        "repeat task.wait() until graph.AbsoluteSize.X > 0",
        "local graphDeadline = os.clock() + 5\n\t\trepeat task.wait() until graph.AbsoluteSize.X > 0 or not graph.Parent or os.clock() >= graphDeadline\n\t\tif not graph.Parent or graph.AbsoluteSize.X <= 0 then\n\t\t\twarn(\"[Syde] Latency graph did not become ready\")\n\t\telse",
    )
    text = text.replace(
        "\t\tlocal bh = window.pages.home.general.Quick.QuickSettings.QuickButtons.holder",
        "\t\tend\n\n\t\tlocal bh = window.pages.home.general.Quick.QuickSettings.QuickButtons.holder",
        1,
    )
    text = text.replace(
        "\t\t\twhile true do\n\n\t\t\t\tlocal ping = getPing()",
        "\t\t\twhile Library and Library.Parent and graph.Parent do\n\n\t\t\t\tlocal ping = getPing()",
        1,
    )
    text = text.replace(
        "\t\t\tif not syde.ConfigEnabled then return end\n\n\t\t\tlocal data = {",
        "\t\t\tif not syde.ConfigEnabled or type(writefile) ~= \"function\" then return end\n\n\t\t\tlocal data = {",
        1,
    )
    text = text.replace(
        '''\t\t\t\tif isfolder and not isfolder(folderName) then
\t\t\t\t\tlocal success, err = pcall(function()
\t\t\t\t\t\tmakefolder(folderName)
\t\t\t\t\tend)''',
        '''\t\t\t\tif type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folderName) then
\t\t\t\t\tlocal success, err = pcall(function()
\t\t\t\t\t\tmakefolder(folderName)
\t\t\t\t\tend)''',
        1,
    )
    text = text.replace(
        '''\t\t\t\tlocal success, err = pcall(function()
\t\t\t\t\tif isfile and not isfile(fullPath) then
\t\t\t\t\t\twritefile(fullPath, "-- Protected UI Configuration")
\t\t\t\t\telse
\t\t\t\t\t\tlocal content = readfile(fullPath)
\t\t\t\t\tend
\t\t\t\tend)''',
        '''\t\t\t\tlocal success, err = pcall(function()
\t\t\t\t\tif type(isfile) ~= "function" then return end
\t\t\t\t\tif not isfile(fullPath) then
\t\t\t\t\t\tif type(writefile) == "function" then writefile(fullPath, "-- Protected UI Configuration") end
\t\t\t\t\telseif type(readfile) == "function" then
\t\t\t\t\t\treadfile(fullPath)
\t\t\t\t\tend
\t\t\t\tend)''',
        1,
    )
    text = text.replace(
        "\t\t\tif not syde.ConfigEnabled then return nil end\n\t\t\tif not isfile(FILE) then return nil end",
        "\t\t\tif not syde.ConfigEnabled or type(isfile) ~= \"function\" or type(readfile) ~= \"function\" then return nil end\n\t\t\tif not isfile(FILE) then return nil end",
        1,
    )
    text = text.replace(
        "TeleportService:Teleport(placeId)",
        "TeleportService:Teleport(lastGame.PlaceId)",
        1,
    )
    text = text.replace(
        "\t\t\t\trs:Disconnect()\n\t\t\t\tss:Disconnect()",
        "\t\t\t\tpcall(function() if rs then rs:Disconnect() end end)\n\t\t\t\tpcall(function() if ss then ss:Disconnect() end end)",
        1,
    )
    text = text.replace(
        "\t\t\t\t\t\tOptions:Set(newValue)\n\t\t\t\t\t\tSaveConfig()",
        "\t\t\t\t\t\tOptions.StarterValue = newValue\n\t\t\t\t\t\tSaveConfig()",
        1,
    )
    text = text.replace(
        'string.format("<font size=\'14\'>%d</font><font color=\'#434343\'>/%d</font>", tostring(NewVal), Options.Range[2])',
        'string.format("<font size=\'14\'>%d</font><font color=\'#434343\'>/%d</font>", NewVal, Options.Range[2])',
    )
    text = text.replace(
        "if makefolder and not isfolder(syde.ConfigFolder) then\n\t\tmakefolder(syde.ConfigFolder)\n\tend",
        "if type(isfolder) == \"function\" and type(makefolder) == \"function\" and not isfolder(syde.ConfigFolder) then\n\t\tlocal folderOk, folderErr = pcall(makefolder, syde.ConfigFolder)\n\t\tif not folderOk then sydeWarn(\"Syde | Failed to create config folder:\", folderErr) end\n\tend",
        1,
    )
    text = text.replace(
        "if not syde.ConfigEnabled then return end\n\tif not writefile then return end",
        "if not syde.ConfigEnabled or type(writefile) ~= \"function\" then return end",
        1,
    )
    text = text.replace(
        '''\t\tfunction syde:SaveSettingsConfig()
\t\t\tlocal Data = {}''',
        '''\t\tfunction syde:SaveSettingsConfig()
\t\t\tif type(writefile) ~= "function" then
\t\t\t\tsydeWarn("[SYDE] Settings cannot be saved: writefile is unavailable")
\t\t\t\treturn false
\t\t\tend
\t\t\tlocal Data = {}''',
        1,
    )
    text = text.replace(
        '''\t\t\twritefile(path, encoded)

\t\t\tsyde:Toast({''',
        '''\t\t\tlocal saved, saveErr = pcall(writefile, path, encoded)
\t\t\tif not saved then
\t\t\t\tsydeWarn("[SYDE] Failed to save settings:", saveErr)
\t\t\t\treturn false
\t\t\tend

\t\t\tsyde:Toast({''',
        1,
    )
    text = text.replace(
        '''\t\tfunction syde:LoadSettingsConfig()
\t\t\tlocal path = string.format("%s/SettingsConfig.lua", syde.ConfigFolder)

\t\t\tif not isfile(path) then''',
        '''\t\tfunction syde:LoadSettingsConfig()
\t\t\tlocal path = string.format("%s/SettingsConfig.lua", syde.ConfigFolder)

\t\t\tif type(isfile) ~= "function" or type(readfile) ~= "function" or not isfile(path) then''',
        1,
    )
    text = text.replace(
        "if isfile and isfile(filePath) then\n\t\t\t\t\t\tloaded = LoadConfig(readfile(filePath))",
        "if type(isfile) == \"function\" and type(readfile) == \"function\" and isfile(filePath) then\n\t\t\t\t\t\tloaded = LoadConfig(readfile(filePath))",
        1,
    )
    text = text.replace(
        "\t\t\t\tif success then\n\t\t\t\t\tsyde:Toast({\n\t\t\t\t\t\tContent = 'Loaded Save File';",
        "\t\t\t\tif success and loaded then\n\t\t\t\t\tsyde:Toast({\n\t\t\t\t\t\tContent = 'Loaded Save File';",
        1,
    )
    text = text.replace(
        "\t\t\t\telseif not success then\n\t\t\t\t\tsydeWarn(\"[SYDE] Configurations Error \" .. tostring(result))",
        "\t\t\t\telseif not success then\n\t\t\t\t\tsydeWarn(\"[SYDE] Configurations Error \" .. tostring(result))\n\t\t\t\telse\n\t\t\t\t\tsydeWarn(\"[SYDE] No valid save file was loaded\")",
        1,
    )
    text = text.replace(
        "local bounce = false\n\nfunction ToggleUI()",
        "local bounce = false\nlocal layoutConnectionsBound = false\n\nfunction ToggleUI()",
        1,
    )
    old_layout = '''\t\tworkspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
\t\t\tscreenSize = workspace.CurrentCamera.ViewportSize
\t\t\tisMobile = userinput.TouchEnabled
\t\t\tupdateLayout()
\t\tend)

\t\tupdateLayout()

\t\tcamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
\t\tuserinput:GetPropertyChangedSignal("TouchEnabled"):Connect(updateLayout)'''
    new_layout = '''\t\tif not layoutConnectionsBound then
\t\t\tlayoutConnectionsBound = true
\t\t\tsyde:AddConnection(camera:GetPropertyChangedSignal("ViewportSize"), function()
\t\t\t\tscreenSize = camera.ViewportSize
\t\t\t\tupdateLayout()
\t\t\tend)
\t\t\tsyde:AddConnection(userinput:GetPropertyChangedSignal("TouchEnabled"), updateLayout)
\t\tend
\t\tupdateLayout()'''
    text = text.replace(old_layout, new_layout, 1)
    text = text.replace(
        "\t\t\t--\tif not ui.Parent then return end\n\t\t\ttask.wait(1)\n\t\t\tLibrary:Destroy()",
        "\t\t\t--\tif not ui.Parent then return end\n\t\t\tsyde:DisconnectAll()\n\t\t\ttask.wait(1)\n\t\t\tLibrary:Destroy()",
        1,
    )
    return text


def patch_control_contracts(text: str) -> str:
    text = text.replace("ColorPicker.Linkable = ColorPicker.Linkable or true", "ColorPicker.Linkable = ColorPicker.Linkable ~= false")
    text = text.replace("local success, errorMsg = pcall(c)", "local success, errorMsg = pcall(data.CallBack)")
    text = text.replace(
        "local sliderWidth = Slider.slide.AbsoluteSize.X\n",
        "local sliderWidth = Slider.slide.AbsoluteSize.X\n\t\t\t\t\t\t\tif sliderWidth <= 0 then return end\n",
    )
    text = text.replace(
        "local ColorX = math.clamp(mouse.X - SVPicker.AbsolutePosition.X, 0, SVPicker.AbsoluteSize.X) / SVPicker.AbsoluteSize.X",
        "local pickerWidth = math.max(SVPicker.AbsoluteSize.X, 1)\n\t\t\t\t\t\tlocal pickerHeight = math.max(SVPicker.AbsoluteSize.Y, 1)\n\t\t\t\t\t\tlocal ColorX = math.clamp(mouse.X - SVPicker.AbsolutePosition.X, 0, pickerWidth) / pickerWidth",
    )
    text = text.replace(
        "local ColorY = math.clamp(mouse.Y - SVPicker.AbsolutePosition.Y, 0, SVPicker.AbsoluteSize.Y) / SVPicker.AbsoluteSize.Y",
        "local ColorY = math.clamp(mouse.Y - SVPicker.AbsolutePosition.Y, 0, pickerHeight) / pickerHeight",
    )
    text = text.replace(
        "local ColorX = math.clamp(mouse.X - HUESlider.AbsolutePosition.X, 0, HUESlider.AbsoluteSize.X) / HUESlider.AbsoluteSize.X",
        "local hueWidth = math.max(HUESlider.AbsoluteSize.X, 1)\n\t\t\t\t\t\tlocal ColorX = math.clamp(mouse.X - HUESlider.AbsolutePosition.X, 0, hueWidth) / hueWidth",
    )
    text = text.replace(
        "local relX = (mouse.X - g.AbsolutePosition.X) / g.AbsoluteSize.X",
        "local relX = (mouse.X - g.AbsolutePosition.X) / math.max(g.AbsoluteSize.X, 1)",
    )
    text = text.replace(
        "ExternalGradient.Color = seq",
        "if ExternalGradient then ExternalGradient.Color = seq end",
    )
    text = text.replace(
        "local startCol = data.Color or ExternalGradient.Color.Keypoints[1].Value\n\t\t\t\t\tlocal endCol = data.Color2 or ExternalGradient.Color.Keypoints[#ExternalGradient.Color.Keypoints].Value",
        "local externalKeypoints = ExternalGradient and ExternalGradient.Color.Keypoints\n\t\t\t\t\tlocal startCol = data.Color or (externalKeypoints and externalKeypoints[1].Value) or Color3.new(1, 1, 1)\n\t\t\t\t\tlocal endCol = data.Color2 or (externalKeypoints and externalKeypoints[#externalKeypoints].Value) or startCol",
    )

    text = text.replace(
        "NewVal = math.floor((NewVal - Options.Range[1]) / Options.Increment + 0.5) * Options.Increment + Options.Range[1]",
        "NewVal = math.clamp(tonumber(NewVal) or Options.StarterValue, Options.Range[1], Options.Range[2])\n\t\t\t\t\t\tNewVal = math.floor((NewVal - Options.Range[1]) / Options.Increment + 0.5) * Options.Increment + Options.Range[1]",
    )
    text = re.sub(
        r"(local (\w+) = sydeClonePageTemplate\([^\n]+\)\n)(\s*)\2\.Visible",
        r"\1\3if not \2 then return nil end\n\3\2.Visible",
        text,
    )
    text = text.replace(
        "table.remove(toasts, table.find(toasts, Toast))",
        "local toastIndex = table.find(toasts, Toast)\n\t\t\tif toastIndex then table.remove(toasts, toastIndex) end",
    )
    add_connection_end = "\treturn Connection, Disconnect\nend\n"
    disconnect_all = '''\treturn Connection, Disconnect
end

function syde:DisconnectAll()
\tfor i = #self.Connections, 1, -1 do
\t\tlocal item = self.Connections[i]
\t\tlocal connection = item and (item.Connection or item.conn)
\t\tif connection and connection.Connected then
\t\t\tconnection:Disconnect()
\t\tend
\t\ttable.remove(self.Connections, i)
\tend
end
'''
    text = text.replace(add_connection_end, disconnect_all, 1)
    text = text.replace(
        '''function syde:StopWiggle(label)
\tfor i, data in ipairs(self.Connections) do
\t\tif data.label == label then
\t\t\tdata.conn:Disconnect()
\t\t\ttable.remove(self.Connections, i)
\t\t\tbreak
\t\tend
\tend
end''',
        '''function syde:StopWiggle(label)
\tif not label then return end
\tlocal container = label:FindFirstChild("WiggleContainer")
\tif container then container:Destroy() end
\tlabel.TextTransparency = 0
end''',
        1,
    )
    return text


def add_slider_handles(block: str) -> str:
    block = block.replace(
        "\t\t\t--[SLIDERS INITIALIZE]",
        "\t\t\tlocal sliderHandles = {}\n\n\t\t\t--[SLIDERS INITIALIZE]",
        1,
    )
    block = re.sub(
        r"(\n\s+Options = \{.*?\n\s+\})(\n\s+Slider\.Name = Options\.Title)",
        r"\1\n\t\t\t\tOptions = sydeNormalizeSliderOptions(Options)\2",
        block,
        count=1,
        flags=re.DOTALL,
    )
    block = block.replace(
        "\n\t\t\t\tif syde.ConfigEnabled then",
        "\n\t\t\t\ttable.insert(sliderHandles, Options)\n\n\t\t\t\tif syde.ConfigEnabled then",
        1,
    )
    block = re.sub(
        r"(\n\s+function Options:Set\(.*?\n\s+end)(\n\s+if Options\.(?:SFlag|Flag))",
        r"\1\n\n\t\t\t\ttable.insert(sliderHandles, Options)\2",
        block,
        count=1,
        flags=re.DOTALL,
    )
    final = block.rfind("\n\t\tend")
    if final == -1:
        final = block.rfind("\n\t\t\tend")
    if final == -1:
        raise RuntimeError("Slider function footer missing")
    indent = "\t\t" if block.startswith("\t\tfunction") else "\t\t\t"
    addition = (
        f"\n{indent}\tlocal handle = sliderHandles[1] or {{ Handles = sliderHandles }}\n"
        f"{indent}\thandle.Instance = slider\n"
        f"{indent}\thandle.Handles = sliderHandles\n"
        f"{indent}\treturn handle\n"
    )
    return block[:final] + addition + block[final:]


def add_text_input_handle(block: str) -> str:
    final = block.rfind("\n\t\tend")
    if final == -1:
        final = block.rfind("\n\t\t\tend")
    if final == -1:
        raise RuntimeError("TextInput function footer missing")
    indent = "\t\t" if block.startswith("\t\tfunction") else "\t\t\t"
    addition = f'''\n{indent}\tfunction data:Set(value, skipCallback)
{indent}\t\ttextBox.Text = tostring(value or "")
{indent}\t\tif not skipCallback then sydeCall(data.CallBack, "TextInput " .. tostring(data.Title), textBox.Text) end
{indent}\tend
{indent}\tdata.Instance = textinput
{indent}\treturn data
'''
    return block[:final] + addition + block[final:]


def add_button_handle(block: str) -> str:
    final = block.rfind("\n\t\tend")
    if final == -1:
        final = block.rfind("\n\t\t\tend")
    if final == -1:
        raise RuntimeError("Button function footer missing")
    indent = "\t\t" if block.startswith("\t\tfunction") else "\t\t\t"
    addition = f'''\n{indent}\tfunction data:Set(settings)
{indent}\t\tif type(settings) == "function" then
{indent}\t\t\tdata.CallBack = settings
{indent}\t\telseif type(settings) == "table" then
{indent}\t\t\tif settings.Callback or settings.CallBack then data.CallBack = settings.Callback or settings.CallBack end
{indent}\t\t\tif settings.Name or settings.Title then
{indent}\t\t\t\tdata.Title = settings.Name or settings.Title
{indent}\t\t\t\tbutton.Name = data.Title
{indent}\t\t\t\tbutton.title.Text = data.Title
{indent}\t\t\tend
{indent}\t\t\tif descLabel and (settings.Description or settings.Desc) then descLabel.Text = settings.Description or settings.Desc end
{indent}\t\tend
{indent}\tend
{indent}\tdata.Instance = button
{indent}\treturn data
'''
    return block[:final] + addition + block[final:]


def add_dropdown_handle(block: str) -> str:
    block = block.replace(
        "local function SetDropdownOptions()\n",
        '''local function SetDropdownOptions()
\t\t\t\tfor _, child in ipairs(drop.Container:GetChildren()) do
\t\t\t\t\tif child:IsA("Frame") and child ~= OptionButton then child:Destroy() end
\t\t\t\tend
\t\t\t\tSelectedOptions = {}
\t\t\t\tSelectedOrder = {}
\t\t\t\tlocal selectedContainer = drop.selectContainer and drop.selectContainer:FindFirstChild("ScrollingFrame")
\t\t\t\tif selectedContainer then
\t\t\t\t\tfor _, child in ipairs(selectedContainer:GetChildren()) do
\t\t\t\t\t\tif child:IsA("Frame") and child.Name ~= "result" then child:Destroy() end
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\tlocal starterValues = {}
\t\t\t\tif type(data.StarterOption) == "table" then
\t\t\t\t\tfor _, value in ipairs(data.StarterOption) do starterValues[tostring(value)] = true end
\t\t\t\telseif data.StarterOption ~= nil then
\t\t\t\t\tstarterValues[tostring(data.StarterOption)] = true
\t\t\t\tend
''',
        1,
    )
    block = re.sub(
        r"if OptionText == data\.StarterOption and not starterSet then\s+starterSet = true\s+sydeSetDropSelectedText\(drop, OptionText\)\s+SelectedOptions = \{\[OptionText\] = true\}\s+SelectedOrder = \{OptionText\}",
        "if starterValues[tostring(OptionText)] and (data.Multi or not starterSet) then\n\t\t\t\t\tstarterSet = true\n\t\t\t\t\tAddToSelected(OptionText)\n\t\t\t\t\tsydeSetDropSelectedText(drop, OptionText)",
        block,
    )
    block = block.replace(
        "if OptionText == data.StarterOption and not starterSet then",
        "if starterValues[tostring(OptionText)] and (data.Multi or not starterSet) then",
    )
    block = re.sub(
        r"(?P<indent>[ \t]+)SelectedOptions = \{\[OptionText\] = true\}\n(?P=indent)SelectedOrder = \{OptionText\}",
        lambda match: f"{match.group('indent')}AddToSelected(OptionText)",
        block,
    )
    block = block.replace("\n\t\t\tSetDropdownOptions()\n", "\n\t\t\tSetDropdownOptions()\n\t\t\tUpdateSelectedText()\n", 1)
    final = block.rfind("\n\t\tend")
    if final == -1:
        final = block.rfind("\n\t\t\tend")
    if final == -1:
        raise RuntimeError("Dropdown function footer missing")
    indent = "\t\t" if block.startswith("\t\tfunction") else "\t\t\t"
    addition = f'''\n{indent}\tfunction data:Set(value, skipCallback)
{indent}\t\tdata.StarterOption = value
{indent}\t\tSetDropdownOptions()
{indent}\t\tUpdateSelectedText()
{indent}\t\tif not skipCallback then
{indent}\t\t\tsydeCall(data.CallBack, "Dropdown " .. tostring(data.Title), data.Multi and table.clone(SelectedOrder) or SelectedOrder[1])
{indent}\t\tend
{indent}\tend
{indent}\tfunction data:Refresh(options, value)
{indent}\t\tdata.Options = type(options) == "table" and options or {{}}
{indent}\t\tif value ~= nil then data.StarterOption = value end
{indent}\t\tSetDropdownOptions()
{indent}\t\tUpdateSelectedText()
{indent}\tend
{indent}\tdata.Instance = dropdown
{indent}\treturn data
'''
    return block[:final] + addition + block[final:]


def validate_output(body: str) -> None:
    required_counts = {
        "function syde:DisconnectAll()": 1,
        "function data:Refresh(options, value)": 2,
        "local sliderHandles = {}": 2,
        "data.Instance = textinput": 2,
        "data.Instance = button": 2,
        "data.Instance = dropdown": 2,
        "Options = sydeNormalizeSliderOptions(Options)": 2,
        "TweenInfo.new(1.34, Enum.EasingStyle.Quint)": 2,
        "TweenInfo.new(1.34, Enum.EasingStyle.Exponential)": 4,
        "TweenInfo.new(2, Enum.EasingStyle.Exponential)": 7,
        "TweenInfo.new(0.73, Enum.EasingStyle.Exponential)": 3,
    }
    for fragment, expected in required_counts.items():
        actual = body.count(fragment)
        if actual != expected:
            raise RuntimeError(f"Generated Syde contract mismatch for {fragment!r}: expected {expected}, found {actual}")

    forbidden = (
        "ColorPicker.Linkable = ColorPicker.Linkable or true",
        "table.remove(toasts, table.find(toasts, Toast))",
        "table.remove(notifications, table.find(notifications, Notification))",
        "if dragging and input.UserInputType == Enum.UserInputType.MouseMovement  or",
        "if makefolder and not isfolder(syde.ConfigFolder)",
        "SelectedOptions = {[OptionText] = true}",
    )
    for fragment in forbidden:
        if fragment in body:
            raise RuntimeError(f"Generated Syde still contains unsafe fragment: {fragment!r}")


def main() -> None:
    upstream = read(UPSTREAM)
    upstream_hash = hashlib.sha256(upstream.encode("utf-8")).hexdigest()
    if upstream_hash != UPSTREAM_SHA256:
        raise RuntimeError(
            f"Syde upstream drifted from pinned essencejs/syde main: expected {UPSTREAM_SHA256}, found {upstream_hash}"
        )
    compat = read(COMPAT)
    modal_block = adapt_modal(read(PATCHES / "modal.luau"))

    loader_match = re.search(
        r"(local Loader\s*=.*?110221114597158.*?\[1\]\s*\n)",
        upstream,
        re.DOTALL,
    )
    if not loader_match:
        raise RuntimeError("Could not find Loader assignment in upstream Syde")
    insert_at = loader_match.end()
    body = upstream[:insert_at] + "\n" + compat + "\n" + upstream[insert_at:]

    body = re.sub(
        r"window\.settings\.pages\.page\.(\w+):Clone\(\)",
        r'sydeClonePageTemplate(window.settings.pages.page, "\1")',
        body,
    )
    body = re.sub(
        r'window\.settings\.pages\.page\["3DView"\]:Clone\(\)',
        r'sydeClonePageTemplate(window.settings.pages.page, "3DView")',
        body,
    )
    body = re.sub(
        r"pages\.page\.(\w+):Clone\(\)",
        r'sydeClonePageTemplate(pages.page, "\1")',
        body,
    )
    body = re.sub(
        r'pages\.page\["3DView"\]:Clone\(\)',
        r'sydeClonePageTemplate(pages.page, "3DView")',
        body,
    )

    body = body.replace(
        "function tbdata:InitTab(tab)\n",
        "function tbdata:InitTab(tab)\n\t\tif type(tab) == \"string\" then\n\t\t\ttab = { Title = tab }\n\t\tend\n",
        1,
    )

    keybind_patch = "\n\tif library.Keybind then\n\t\tuitoggle = library.Keybind\n\tend\n"
    anchor = "\tData.Home.profileImage = Data.Home.profileImage or Data.profileImage"
    if anchor in body and keybind_patch.strip() not in body:
        body = body.replace(anchor, anchor + keybind_patch, 1)

    body = replace_between(body, "function syde:Modal(Modal)", "--@@Toast", modal_block)

    settings_dropdown = convert_dropdown_block(
        extract_block(upstream, "function telement:Dropdown(Dropdown)", "\n\t\t\tfunction telement:Slider"),
        "window.settings.pages.page",
        "telement",
    )
    settings_dropdown = add_dropdown_handle(settings_dropdown)
    body = replace_between(
        body,
        "function telement:Dropdown(Dropdown)",
        "\n\t\t\tfunction telement:Slider",
        settings_dropdown,
    )

    page_dropdown = convert_dropdown_block(
        extract_block(upstream, "function initelement:Dropdown(Dropdown)", "\n\t\t--@@Colorpicker"),
        "pages.page",
        "initelement",
    )
    page_dropdown = add_dropdown_handle(page_dropdown)
    body = replace_between(
        body,
        "function initelement:Dropdown(Dropdown)",
        "\n\t\t--@@Colorpicker",
        page_dropdown,
    )

    settings_button = add_button_handle(
        extract_block(body, "function telement:Button(Button)", "\n\t\t\tfunction telement:Toggle")
    )
    body = replace_between(body, "function telement:Button(Button)", "\n\t\t\tfunction telement:Toggle", settings_button)
    page_button = add_button_handle(
        extract_block(body, "function initelement:Button(Button)", "\n\t\t--@@Toggle")
    )
    body = replace_between(body, "function initelement:Button(Button)", "\n\t\t--@@Toggle", page_button)

    settings_slider = add_slider_handles(
        extract_block(body, "function telement:Slider(Slider)", "\n\t\t\tfunction telement:Paragraph")
    )
    body = replace_between(
        body,
        "function telement:Slider(Slider)",
        "\n\t\t\tfunction telement:Paragraph",
        settings_slider,
    )
    page_slider = add_slider_handles(
        extract_block(body, "function initelement:Slider(Slider)", "\n\t\t--@@KeyBind")
    )
    body = replace_between(body, "function initelement:Slider(Slider)", "\n\t\t--@@KeyBind", page_slider)

    settings_input = add_text_input_handle(
        extract_block(body, "function telement:TextInput(TextInput)", "\n\t\t\treturn telement")
    )
    body = replace_between(
        body,
        "function telement:TextInput(TextInput)",
        "\n\t\t\treturn telement",
        settings_input,
    )
    page_input = add_text_input_handle(
        extract_block(body, "function initelement:TextInput(TextInput)", "\n\t\tfunction initelement:EnchancedView")
    )
    body = replace_between(
        body,
        "function initelement:TextInput(TextInput)",
        "\n\t\tfunction initelement:EnchancedView",
        page_input,
    )

    footer_start = "\t\treturn initelement\n\n\n\tend\n\treturn tbdata"
    end_patch = """
\t\tfunction initelement:Select()
\t\t\tSwitchToTab(tdata.Title)
\t\tend

\t\treturn initelement


\tend

\tfunction tbdata:Toggle()
\t\tToggleUI()
\tend

\tfunction tbdata:GetState()
\t\treturn not uiclosed
\tend

\tfunction tbdata:SetState(state)
\t\tlocal want = state == true
\t\tif want and uiclosed then
\t\t\tToggleUI()
\t\telseif not want and not uiclosed then
\t\t\tToggleUI()
\t\tend
\tend

\treturn tbdata


end

syde.__AlleralPatch = ALLERAL_SYDE_PATCH

return syde
"""
    if footer_start not in body:
        raise RuntimeError("Syde Init footer anchor missing — upstream layout changed")
    body = replace_from(body, footer_start, end_patch)

    body = silence_syde_logging(body)
    body = patch_ui_setup(body)
    body = patch_slider_labels(body)
    body = patch_slider_drag(body)
    body = patch_option_labels(body)
    body = patch_option_clicks(body)
    body = patch_normalized_labels(body)
    body = patch_dropdown_template(body)
    body = patch_ui_main_access(body)
    body = patch_runtime_safety(body)
    body = patch_control_contracts(body)
    body = "\n".join(line.rstrip() for line in body.splitlines()) + "\n"
    validate_output(body)

    if "--check" in sys.argv:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != body:
            raise SystemExit(f"{OUT} is stale; run python maint/build_syde_source.py")
        print(f"OK: {OUT} is up to date")
        return

    OUT.write_text(body, encoding="utf-8")
    print(f"Wrote {OUT} ({len(body)} bytes, {body.count(chr(10)) + 1} lines)")


if __name__ == "__main__":
    main()
