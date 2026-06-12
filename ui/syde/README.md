# Syde UI (vendored)

Upstream: [essencejs/syde](https://github.com/essencejs/syde) (GPL-3.0)

- `upstream.luau` — unmodified essencejs/syde `main` (reference copy)
- `compat.luau` — Alleral executor/asset compatibility helpers
- `source.luau` — upstream + compat, built by `maint/build_syde_source.py`
- `patches/modal.luau` — modal compat (dropdown patches generated from upstream in build script)
- Docs: https://essencejs.github.io/syde/

## Regenerating `source.luau`

After updating `upstream.luau` or `compat.luau`:

```powershell
python maint/build_syde_source.py
```

The build keeps the **original Syde library body** and applies only Alleral bug fixes:

- Strip embedded asset scripts (Volt `:` vs `.` strictness)
- Normalize Roblox template name casing once at load
- Dropdown `dropholder.drop` proxy for executor compat
- Modal button/title casing via `sydeResolveModal`
- Page template clone aliases (`Button`/`button`, etc.)
- Alleral API: `InitTab("Name")`, `Init({ Keybind })`, `Toggle()` / `GetState()` / `SetState()`, `initelement:Select()`

Patch version: `ALLERAL_SYDE_PATCH` in `compat.luau` (currently **v15**).
