# Alleral Hub

Roblox automation hub — one loader, four games, private owner telemetry.

**Supported games:** Kick a Lucky Block · Speed Keyboard Escape · Slime RNG · Build A Ring Farm

## Quick start

Copy **Alleral Hub** into your executor workspace, then from the repo root:

```lua
loadstring(readfile("loader.luau"))()
```

Remote (after pushing this layout to GitHub):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/loader.luau"))()
```

Reload: `getgenv().Alleral_Reload()` · Debug: `getgenv().Alleral_LoaderInfo()`

Dev mode (prefer local files): `getgenv().Alleral_DevMode = true` before running.

## Project layout

```
Alleral Hub/
├── loader.luau                 # Entry point
├── core/
│   ├── alleral_core.luau       # Starlight, supervisors, HTTP
│   ├── analytics.luau          # In-game user webhooks (Kick)
│   └── telemetry.luau          # Owner telemetry client (relay only)
├── games/
│   ├── kick_a_lucky_block.luau
│   ├── kickblox.luau
│   ├── speed_keyboard_escape.luau
│   ├── slime_rng.luau
│   └── build_a_ring_farm.luau
├── config/
│   ├── owner_telemetry.example.luau
│   └── WEBHOOK_SETUP.md        # Full webhook deploy guide
├── backend/
│   └── telemetry_relay.py      # Private Discord relay (host this)
├── tools/
└── vendor/starlight/
```

## Owner webhook (secure)

**If others can read this folder**, read [config/SECURITY.md](config/SECURITY.md) first.

- Discord webhook → `backend/.env` on **your server only**
- Relay API key → `../Alleral-Private/owner_telemetry.luau` (**outside** shared hub)
- Before sharing: `powershell tools/prepare_distribution.ps1`

Setup: [config/WEBHOOK_SETUP.md](config/WEBHOOK_SETUP.md)

## Luxy sync (dev)

```bash
python tools/luxy_sync.py
python tools/luxy_sync.py --check
```
