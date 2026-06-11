# Alleral Hub

One script. Detects your game and runs it.

**Games:** Kick a Lucky Block · Speed Keyboard Escape · Slime RNG · Build A Ring Farm · Survive a Zombie Arena

## Load

Paste this in Volt and Execute:

```lua
loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/evanbackup1256-ship-it/kick@main/loader.luau", true))()
```

If HttpGet doesn't work on your executor, use this instead:

```lua
(function()
	local g = getgenv and getgenv() or {}
	local url = "https://cdn.jsdelivr.net/gh/evanbackup1256-ship-it/kick@main/loader.luau?t=" .. tick()
	local src
	if g.Volt and g.Volt.request then
		local r = g.Volt.request({ Url = url, Method = "GET" })
		src = r and (r.Body or r.body)
	end
	if not src and g.request then
		local r = g.request({ Url = url, Method = "GET" })
		src = r and (r.Body or r.body)
	end
	loadstring(src)()
end)()
```

**Local files:** save `loader.luau` to your workspace, then:

```lua
loadstring(readfile("loader.luau"))()
```

Reload: `getgenv().Alleral_Reload()`
