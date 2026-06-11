#!/usr/bin/env python3
"""Bundle modular Starlight sources into a single plain Source.lua for executors."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LIB = ROOT / "lib"
PLAIN_OUTPUT = ROOT / "Source.plain.lua"
OUTPUT = ROOT / "Source.lua"

MODULE_ORDER = [
    "util.luau",
    "theme.luau",
    "tween.luau",
    "filesystem.luau",
    "notification.luau",
    "elements.luau",
    "window.luau",
]

HEADER = """--[[ Starlight bundle — edit vendor/starlight/lib/ then run bundle.py ]]

"""


def transform_module(source: str) -> str:
    source = re.sub(
        r"local (\w+) = require\(script\.Parent\.(\w+)\)",
        r"local \1 = requireModule('\2')",
        source,
    )
    return source


def module_name(filename: str) -> str:
    return Path(filename).stem


def bundle() -> str:
    chunks = [
        HEADER,
        "local modules = {}\n"
        "local function requireModule(name)\n"
        "\treturn modules[name]\n"
        "end\n",
    ]

    for filename in MODULE_ORDER:
        path = LIB / filename
        name = module_name(filename)
        body = transform_module(path.read_text(encoding="utf-8"))
        chunks.append(f"do\n\tmodules['{name}'] = (function()\n{body}\n\tend)()\nend\n")

    chunks.append(
        """
local FileSystem = requireModule('filesystem')
local Theme = requireModule('theme')
local Notification = requireModule('notification')
local WindowBuilder = requireModule('window')
local Util = requireModule('util')

local Starlight = {
\tInterfaceBuild = "Alleral-6",
\tWindowKeybind = "K",
\tMinimized = false,
\tMaximized = false,
\tNotificationsOpen = false,
\tDialogOpen = false,
\tWindow = nil,
\tNotifications = nil,
\tInstance = nil,
\tOnDestroy = nil,
\tFileSystem = FileSystem,
\tThemes = Theme.Palettes,
\tCurrentTheme = Theme.current(),
}

function Starlight:Notification(data)
\treturn Notification.show(data)
end

function Starlight:CreateWindow(windowSettings)
\tlocal window = WindowBuilder.create(self, windowSettings)
\tself.Window = window
\tself.CurrentTheme = Theme.current()
\treturn window
end

function Starlight:SetTheme(themeName)
\tTheme.setTheme(themeName)
\tself.CurrentTheme = Theme.current()
\tif self.Window and self.Window.Instance then
\t\tWindowBuilder.refreshTheme(self.Window.Instance)
\tend
end

function Starlight:SetAccent(color)
\tTheme.applyAccent(color)
\tself.CurrentTheme = Theme.current()
end

function Starlight:GetVisualSettings()
\treturn Util.deepCopy(Theme.Visual)
end

function Starlight:SetVisualSettings(settings)
\tfor key, value in pairs(settings or {}) do
\t\tif Theme.Visual[key] ~= nil then
\t\t\tTheme.Visual[key] = value
\t\tend
\tend
\tself.CurrentTheme = Theme.current()
end

return Starlight
"""
    )
    return "\n".join(chunks)


def main() -> None:
    bundled = bundle()
    PLAIN_OUTPUT.write_text(bundled, encoding="utf-8")
    OUTPUT.write_text(bundled, encoding="utf-8")
    print(f"Wrote {PLAIN_OUTPUT} ({len(bundled.splitlines())} lines, plain)")
    print(f"Wrote {OUTPUT} ({len(bundled.splitlines())} lines, plain)")


if __name__ == "__main__":
    main()
