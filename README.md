# Alleral Hub

One script. Detects your game and runs it.

**Games:** Kick a Lucky Block · Speed Keyboard Escape · Slime RNG · Build A Ring Farm · Survive a Zombie Arena

## Load

There is **only one entry point:** `loader.luau`. Paste this in Volt and click **Execute**:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/evanbackup1256-ship-it/kick/main/loader.luau?t=" .. tick()))()
```

You must see this line in the console:

```
=== Alleral loader 5.4.x active ===
```

If you see `[Alleral Loader v3.x]` instead, you are running an **old saved script inside Volt** — not this repo. Delete every Alleral script from Volt's **Scripts / Saved** tab and use the line above.

Reload in the same session: `getgenv().Alleral_Reload()`

Scan executor workspace for stale files: `getgenv().Alleral_ScanLegacy()`
