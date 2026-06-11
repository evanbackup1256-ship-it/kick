# Alleral Hub

One script. Detects your game and runs it.

**Games:** Kick a Lucky Block · Speed Keyboard Escape · Slime RNG · Build A Ring Farm · Survive a Zombie Arena

## Load

Paste in Volt and execute:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/loader.luau?t=" .. tick()))()
```

You should see:

```
=== Alleral 7.2.0 active ===
Auto-update polling every 45s
```

If you see an old version, delete saved Alleral scripts in Volt and run the line above again.

## Live updates

After the hub loads, it polls GitHub every **45 seconds** (configurable in `config/release.json`). When you push a new commit or bump a version, players get **Update detected. Reloading...** automatically.

Manual controls:

- Reload now: `getgenv().Alleral_Reload()`
- Check for updates: `getgenv().Alleral_CheckUpdate()`
- Clear cached files: `getgenv().Alleral_PurgeCache()`

## Bump a release on GitHub

When you ship changes, update `config/release.json`:

1. Bump `loader`, `core`, or game versions in `config/scripts_manifest.json`
2. Set `commit` to the new git short hash
3. Set `updatedAt` to the current UTC time

Push to `main` — connected clients pick it up within one poll cycle.
