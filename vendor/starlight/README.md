# Starlight — Alleral UI

Programmatic UI library for Alleral game scripts. Inspired by Linoria, Rayfield, and Fluent — dark sidebar layout, solid panels, executor-safe rendering.

## Layout

```
vendor/starlight/
  lib/           Source modules (edit these)
  init.luau      Studio require entry
  Source.lua     Bundled output for executors
  bundle.py      Rebuild Source.lua after lib changes
```

## Rebuild

```bash
python vendor/starlight/bundle.py
```

Writes `Source.plain.lua` and `Source.lua` (plain readable bundle).

## Usage

Loaded via `Alleral_Core.loadStarlight()` → `vendor/starlight/Source.lua`.

```lua
local window = Starlight:CreateWindow({
    Name = "Alleral",
    Subtitle = "My Game",
    Icon = 10723407389,
    LoadingEnabled = false,
    NotifyOnCallbackError = true,
})

local section = window:CreateTabSection("Main", true)
local tab = section:CreateTab({ Name = "Farm", Columns = 2 }, "farm")
local group = tab:CreateGroupbox({ Name = "Auto", Column = 1 }, "auto")

group:CreateToggle({
    Name = "Auto farm",
    CurrentValue = false,
    Callback = function(on) end,
}, "AutoFarm")
```

Use `Core.wrapStarlightGroup(groupbox, callbackWrapper)` in game scripts for shorthand helpers.

Press **K** to toggle the window.
