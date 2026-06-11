# Alleral Hub — architecture

## Overview

Alleral Hub is a multi-game Roblox executor loader. One `loader.luau` detects the current place, loads shared core modules, then injects the matching game script.

```
loader.luau
  ├── core/alleral_core.luau      Rayfield UI, RoScripts browser, supervisors
  ├── core/game_helpers.luau      Shared combat/movement/remote helpers
  ├── core/analytics.luau         Kick in-game user webhooks
  ├── core/telemetry.luau         Owner relay client
  └── games/<detected>.luau       Game-specific automation
```

## Runtime bridge

State flows through `getgenv().Alleral_State`. The loader injects an ENV bridge so game scripts can read executor globals safely.

Boot order:

1. `detectGame()` — PlaceId + in-game markers
2. `preloadCore()` → `preloadAnalytics()` → `preloadHelpers()` → `preloadTelemetry()`
3. Rayfield preload
4. `runGameScript(profile)` — compile game source into getgenv

## Path resolution

| Canonical | Fallbacks (local dev) |
|-----------|----------------------|
| `core/*.luau` | `src/*.luau`, flat name |
| `games/*.luau` | `src/*.luau`, flat name |
| `games/data/*.luau` | Game data modules (KickBlox brainrot list) |
| Rayfield (remote) | UI library loaded from Sirius GitHub at runtime |
| `core/telemetry.luau` | Obfuscated owner telemetry (edit `core/internal/`) |
| `core/analytics.luau` | Obfuscated user analytics (edit `core/internal/`) |

Remote base: `https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main`

## Game scripts

| ID | Place ID | Version |
|----|----------|---------|
| kick_a_lucky_block | 89469502395769 | 6.5 |
| speed_keyboard_escape | 95082159892680 | 1.1 |
| slime_rng | 92416421522960 | 1.1 |
| build_a_ring_farm | 107646426076756 | 1.1 |
| survive_a_zombie_arena | 114204398207377 | 2.0 |

## Backend

`backend/telemetry_relay.py` — Python Discord relay. Clients POST to `/ingest`; webhook URL stays server-side in `backend/.env`.

## Tools

| Script | Purpose |
|--------|---------|
| `tools/luxy_sync.py` | Pull Luxy upstream → cache → `games/` |
| `tools/prepare_distribution.ps1` | Scrub secrets before sharing |
| `tools/setup_telemetry.ps1` | One-shot telemetry stack setup |

## Adding a new game

1. Create `games/your_game.luau` using `Core.prepareGame(state)` boot pattern
2. Register in `loader.luau` `GAMES` table with `placeIds`, `validate`, `preload`
3. Document in `docs/GAMES.md`
