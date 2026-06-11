# Alleral Architecture

## Boot chain

```
loader.luau (CDN HttpGet — only entry point)
    ├── purge legacy workspace files (v3.x launch/load/bootstrap/run)
    ├── detect executor + game by PlaceId
    ├── download core/alleral_core.luau
    ├── load analytics, helpers, telemetry
    ├── preload Rayfield
    └── run games/*.luau
```

## Entry point

| File | Purpose |
|------|---------|
| `loader.luau` | **Only** player entry — fetch from CDN |

There is no `load.luau`, `launch.luau`, `bootstrap.luau`, or `run.luau`. Those were removed in v5.x.

## Version sources

| Component | Version | File |
|-----------|---------|------|
| Loader | 5.4.0 | `loader.luau`, `config/release.json` |
| Core | 1.19 | `core/alleral_core.luau` |
| Analytics | 1.0 | `core/analytics.luau` |
| Telemetry | 2.2 | `core/telemetry.luau` |
| Helpers | 1.0 | `core/game_helpers.luau` |
| Game scripts | per-game | `games/*.luau`, `config/scripts_manifest.json` |

Run `powershell tools/verify_versions.ps1` before pushing.

## Never do

- Add alternate entry scripts (`launch`, `load`, `bootstrap`, `run`)
- Embed core or loader with `[=[` long strings (breaks Volt)
- Commit embedded core/loader bundles (removed `tools/bundle_*.ps1`)
- Ship v3.x loaders — loader purges them from executor workspace on run
