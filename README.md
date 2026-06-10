# Alleral

Roblox automation hub built around the Alleral loader and Starlight UI.

Supported games:

- Kick a Lucky Block
- Speed Keyboard Escape
- Slime RNG
- Build A Ring Farm

## Quick start

Copy the whole repo into your executor workspace, then run from the repo root:

```lua
loadstring(readfile("loader.luau"))()
```

Remote loader:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/loader.luau"))()
```

The loader detects the game, preloads `src/alleral_core.luau` and `src/analytics.luau`, then injects the matching script from `src/`.

By default the loader pulls scripts from GitHub (avoids stale local copies). Set `getgenv().Alleral_DevMode = true` before running to prefer local files instead.

Reload after unload: `getgenv().Alleral_Reload()`

Inspect loader state: `getgenv().Alleral_LoaderInfo()`

## Project layout

```
.
├── loader.luau                 # Entry point — run this
├── src/
│   ├── alleral_core.luau       # Shared Starlight/settings bootstrap
│   ├── analytics.luau          # Discord analytics / Tracker
│   ├── kick_a_lucky_block.luau # Kick a Lucky Block (v6.4)
│   ├── speed_keyboard_escape.luau
│   ├── slime_rng.luau
│   └── build_a_ring_farm.luau
├── reference/                  # Deobfuscated sources (not executed by loader)
├── tools/                      # Emit scripts to regenerate game ports
├── vendor/
│   └── starlight/              # Offline Starlight fallback for Alleral_Core
├── archive/                    # Deprecated experiments
└── README.md
```

## What each folder is for

- **`src/`** — Production scripts only. This is what the loader loads locally.
- **`reference/`** — Deobfuscated Luxy dumps used during porting (not loaded at runtime).
- **`tools/`** — `emit_speed_keyboard.py`, `emit_clean_barf.py` to rebuild game scripts.
- **`vendor/starlight/`** — Local Starlight copy used when HTTP is unavailable.
- **`archive/`** — Deprecated experiments.

## Local vs remote

The loader tries local files in this order:

1. `src/alleral_core.luau`, `src/analytics.luau`, then the detected game script
2. Legacy flat filenames at repo root

If none exist, it falls back to the GitHub raw URL in `loader.luau`.

## Config in-game

Runtime settings are saved by the script to `Alleral_Configs/` in the executor filesystem — not in this repo.
