# Alleral Hub

Roblox automation hub — one loader, five games, private owner telemetry.

**Supported games:** Kick a Lucky Block · Speed Keyboard Escape · Slime RNG · Build A Ring Farm · Survive a Zombie Arena

## Load Alleral (works on Volt — no one-liner)

One-liners like `loadstring(game:HttpGet(...))()` **will not work** on Volt. Do this instead:

1. Open **[paste.luau on GitHub](https://github.com/evanbackup1256-ship-it/kick/blob/main/paste.luau)** (or [raw link](https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/paste.luau))
2. **Select All** (Ctrl+A) → **Copy** (Ctrl+C)
3. Paste into your executor script editor
4. Click **Execute**

No HttpGet one-liner. No autoexec. The pasted file includes the full loader built in.

**Same session reload:** `Alleral_Load()` or `getgenv().Alleral_Reload()`

**Dev / local workspace:**

```lua
loadstring(readfile("loader.luau"))()
```

## If paste is too large for your executor

Use [`fetch.luau`](fetch.luau) instead — copy the entire file the same way. It downloads `load.luau` using Volt.request and other HTTP APIs.

## Project layout

```
Alleral Hub/
├── paste.luau                  # Copy ALL of this into executor (recommended)
├── fetch.luau                  # Smaller fallback if paste is too big
├── load.luau                   # Full bootstrap + embedded loader
├── loader.luau                 # Dev entry point
```

See repo for full layout, docs, and games.

## Owner webhook (secure)

**If others can read this folder**, read [docs/SECURITY.md](docs/SECURITY.md) first.

Setup: [docs/WEBHOOK_SETUP.md](docs/WEBHOOK_SETUP.md)

## Docs

- [Architecture](docs/ARCHITECTURE.md) — loader boot chain and path resolution
- [Games](docs/GAMES.md) — per-game feature summary
