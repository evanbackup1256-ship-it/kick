# Alleral Architecture

## Boot chain

```
loader.luau (GitHub HttpGet — only entry point)
    ├── load config/weao.json + core/weao.luau (WEAO client)
    ├── purge legacy workspace files
    ├── detect executor locally, enrich via WEAO API
    ├── detect game by PlaceId
    ├── download core/alleral_core.luau
    ├── load analytics, helpers, telemetry
    ├── preload Obsidian UI
    ├── run games/*.luau
    └── auto-update poll → reload on GitHub changes
```

## WEAO integration

Per [WEAO API docs](https://docs.weao.xyz):

- Required header: `User-Agent: WEAO-3PService`
- Exploits endpoint: `GET /api/status/exploits` (all) or `/api/status/exploits/[name]` (single)
- Config: `config/weao.json` (GitHub + local fallback)
- Client: `core/weao.luau` (shared by loader + core)
- Proxy (primary): [goodcurry/weao-proxy-api](https://github.com/goodcurry/weao-proxy-api) → `http://farts.fadedis.xyz:25551`
- Fallback domains: weao.xyz, whatexpsare.online, whatexploitsaretra.sh, api.weao.xyz

The WEAO client tries every base × transport × cache-busted URL, validates JSON (rejects rate-limit payloads), filters hidden exploits, and caches for 5 minutes in `getgenv().Alleral_WeaoCache`.

## Entry point

| File | Purpose |
|------|---------|
| `loader.luau` | **Only** player entry — fetch from GitHub |

## Version sources

| Component | Version | File |
|-----------|---------|------|
| Loader | 7.2.0 | `loader.luau`, `config/release.json` |
| Core | 2.1 | `core/alleral_core.luau` |
| UI | Obsidian | `vendor/obsidian/` |
| Telemetry | 3.0 | `core/telemetry.luau`, `config/telemetry.json` |
| WEAO | 1.0 | `core/weao.luau`, `config/weao.json` |
| Analytics | 1.0 | `core/analytics.luau` |
| Helpers | 1.0 | `core/game_helpers.luau` |
| Game scripts | per-game | `games/*.luau`, `config/scripts_manifest.json` |

Run `powershell tools/verify_versions.ps1` before pushing.

## Never do

- Add alternate entry scripts (`launch`, `load`, `bootstrap`, `run`)
- Call WEAO without `WEAO-3PService` user-agent
- Embed core or loader with `[=[` long strings (breaks Volt)
- Ship v3.x loaders — loader purges them from executor workspace on run
- Push without updating `config/release.json` (`commit`, `updatedAt`, or versions) when you expect live auto-update

## Auto-update

Loader polls GitHub every `updatePollSeconds` (default 45) using `config/release.json` + `config/scripts_manifest.json`. When the release fingerprint changes, the hub purges stale workspace files and calls `Alleral_Reload()`.

Player commands: `Alleral_CheckUpdate()` · `Alleral_PurgeCache()` · `Alleral_Reload()`

Maintainer: run `powershell tools/bump_release.ps1` before push to refresh `commit` and `updatedAt`.
