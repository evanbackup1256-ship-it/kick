# Alleral Hub

Roblox automation hub — one loader, five games, private owner telemetry.

**Supported games:** Kick a Lucky Block · Speed Keyboard Escape · Slime RNG · Build A Ring Farm · Survive a Zombie Arena

## Quick start

Copy **Alleral Hub** into your executor workspace, then from the repo root:

```lua
loadstring(readfile("loader.luau"))()
```

Remote (recommended — use `bootstrap.luau`, not `launch.luau`):

```lua
(getgenv().loadstring or loadstring or load)(game.HttpGet(game, "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/bootstrap.luau?t=" .. tick(), true))()
```

Or save `bootstrap.luau` from the repo into your executor autoexec folder (no one-liner needed).

Reload: `getgenv().Alleral_Reload()` · Debug: `getgenv().Alleral_LoaderInfo()`

Dev mode (prefer local files): `getgenv().Alleral_DevMode = true` before running.

## Project layout

```
Alleral Hub/
├── loader.luau                 # Entry point (v3.3)
├── core/
│   ├── alleral_core.luau       # Rayfield UI, RoScripts, supervisors
│   ├── game_helpers.luau       # Shared combat/movement/remote helpers
│   ├── internal/               # Readable telemetry/analytics sources
│   ├── analytics.luau          # Protected (obfuscated) — do not edit
│   └── telemetry.luau          # Protected (obfuscated) — do not edit
├── config/
│   └── scripts_manifest.json   # Script status source (also served by relay /scripts)
├── games/
│   ├── kick_a_lucky_block.luau
│   ├── speed_keyboard_escape.luau
│   ├── slime_rng.luau
│   ├── build_a_ring_farm.luau
│   ├── survive_a_zombie_arena.luau
│   └── data/
│       └── kickblox.luau       # Kick brainrot name list
├── docs/
│   ├── ARCHITECTURE.md
│   ├── GAMES.md
│   ├── SECURITY.md
│   └── WEBHOOK_SETUP.md
├── config/
│   ├── owner_telemetry.example.luau
│   └── SECURITY.md             # Pointer → docs/
├── backend/
│   └── telemetry_relay.py      # Private Discord relay (host this)
├── tools/
```

## Owner webhook (secure)

**If others can read this folder**, read [docs/SECURITY.md](docs/SECURITY.md) first.

- Discord webhook → `backend/.env` on **your server only**
- Relay API key → `../Alleral-Private/owner_telemetry.luau` (**outside** shared hub)
- Before sharing: `powershell tools/prepare_distribution.ps1`

Setup: [docs/WEBHOOK_SETUP.md](docs/WEBHOOK_SETUP.md)

## Luxy sync (dev)

```bash
python tools/luxy_sync.py
python tools/luxy_sync.py --check
```

## Docs

- [Architecture](docs/ARCHITECTURE.md) — loader boot chain and path resolution
- [Games](docs/GAMES.md) — per-game feature summary
