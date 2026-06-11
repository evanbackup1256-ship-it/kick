# Alleral Hub

One loader — detects your game by PlaceId and runs the matching script.

**Supported games:** Kick a Lucky Block · Speed Keyboard Escape · Slime RNG · Build A Ring Farm · Survive a Zombie Arena

## Load

### First time / stuck on old version / core errors

Paste and **Execute** [load.luau](load.luau) once in Volt. It downloads validated core v1.18+ and loader v4.0.0, saves them to your workspace, and runs.

```lua
loadstring(readfile("load.luau"))()
```

Then always use:

```lua
loadstring(readfile("loader.luau"))()
```

### Remote (no local files)

```lua
(function()
	local g = (getgenv and getgenv()) or {}
	local L = g.loadstring or g.LoadString or loadstring or load
	local url = "https://cdn.jsdelivr.net/gh/evanbackup1256-ship-it/kick@main/loader.luau?t=" .. tick()
	local src
	if type(L) ~= "function" then return warn("[Alleral] loadstring missing") end
	if type(g.Volt) == "table" and type(g.Volt.request) == "function" then
		pcall(function()
			local r = g.Volt.request({ Url = url, Method = "GET" })
			src = r and (r.Body or r.body)
		end)
	end
	if type(src) ~= "string" and type(game.HttpGet) == "function" then
		pcall(function() src = game.HttpGet(game, url, true) end)
	end
	if type(src) ~= "string" then return warn("[Alleral] HTTP failed") end
	if src:find("EMBEDDED_CORE = [=", 1, true) then return warn("[Alleral] Corrupted loader cached — use load.luau") end
	local fn, err = L(src, "Alleral/loader")
	if type(fn) ~= "function" then return warn("[Alleral] " .. tostring(err)) end
	fn()
end)()
```

Reload: `getgenv().Alleral_Reload()` · Debug: `getgenv().Alleral_LoaderInfo()`

## Requirements

- Loader **v4.0.0+**
- Core **v1.18+** (fixes broken Rayfield groupbox syntax in older cores)
- Do **not** use loader v3.9.0 (embedded core breaks Volt) or v3.7.x (stale CDN core)

## Layout

```
load.luau            ← one-time rescue (paste once)
loader.luau          ← main entry
core/alleral_core.luau
games/               ← per-game scripts
```

## Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Games](docs/GAMES.md)
