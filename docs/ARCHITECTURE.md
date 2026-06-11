# Alleral Architecture

## Boot chain

```
load.luau (optional rescue, once)
    └── loader.luau
            ├── bootstrap prefetch (Volt.request → core v1.18+)
            ├── detect game by PlaceId
            ├── load core (local → Volt fetch → mirrors, compile-validated)
            ├── load analytics, helpers, telemetry
            ├── preload Rayfield
            └── run games/*.luau
```

## Entry points

| File | Purpose |
|------|---------|
| `load.luau` | One-time rescue: downloads validated core + loader, saves to workspace |
| `loader.luau` | Main entry — auto-upgrades, loads core and game script |

## Core loading (v4.0.0)

1. Bootstrap block at top prefetches core via `Volt.request` from pinned good commit `d9441a1`
2. `coreBodyValid()` rejects broken cores (missing `AlleralGroupShell` marker, version < 1.18)
3. `coreSourceCompileOk()` runs `loadstring` compile check before executing core
4. Mirror URLs only pin commits with fixed core (`d9441a1`, `414cc8d`)

## Dependencies loaded at runtime

| Module | Source |
|--------|--------|
| Core | `core/alleral_core.luau` (local, CDN, or bootstrap) |
| Rayfield | Sirius GitHub or `vendor/rayfield/source.lua` |
| Game script | `games/<game_id>.luau` |

## Never do

- Embed core in loader with `[=[` long strings (breaks Volt parser)
- Pin CDN commits before `d9441a1` (broken `fakeUiInstance` syntax)
