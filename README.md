# Alleral Hub

Roblox automation hub — one loader, five games, private owner telemetry.

**Supported games:** Kick a Lucky Block · Speed Keyboard Escape · Slime RNG · Build A Ring Farm · Survive a Zombie Arena

## Load Alleral

Join a supported game and paste this into your executor, then click **Execute**:

```lua
(getgenv().loadstring or loadstring or load)(game.HttpGet(game, "https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/load.luau?t=" .. tick(), true))()
```

**If that still fails:** open [`paste.luau`](paste.luau), copy the **entire file**, paste into your executor, and Execute. It tries every HttpGet style automatically.

**Same session reload:** `Alleral_Load()` or `getgenv().Alleral_Reload()`

**Dev / local workspace:**

```lua
loadstring(readfile("loader.luau"))()
```

## How it stays reliable

- **One download** — `load.luau` includes the full loader embedded (no second HTTP hop)
- **Bundled fallback** — if CDN serves stale files, the embedded copy still runs
- **Universal HttpGet** — works on Volt, Synapse, Krnl, Solara, Wave, and others

## Project layout

```
Alleral Hub/
├── paste.luau                  # Copy/paste loader (start here)
├── load.luau                   # Full bootstrap + embedded loader
├── loader.luau                 # Dev entry point
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
