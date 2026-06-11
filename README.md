# Alleral Hub

One loader — detects your game by PlaceId and runs the matching script.

**Supported games:** Kick a Lucky Block · Speed Keyboard Escape · Slime RNG · Build A Ring Farm · Survive a Zombie Arena

## Load

**Local workspace:**

```lua
loadstring(readfile("loader.luau"))()
```

**Remote:**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/loader.luau?t=" .. tick()))()
```

Reload: `getgenv().Alleral_Reload()` · Debug: `getgenv().Alleral_LoaderInfo()`

Dev mode: `getgenv().Alleral_DevMode = true` before running (prefers local files).

## Layout

```
loader.luau          ← only entry point
core/                ← shared UI, helpers, telemetry
games/               ← one script per supported game
config/              ← manifests
```

## Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Games](docs/GAMES.md)
- [Security](docs/SECURITY.md)
