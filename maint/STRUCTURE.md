# Repo layout

| Path | What it is |
|------|------------|
| `loader.luau` | Entry point — boot, updates, game routing |
| `bootstrap.luau` | Stable loadstring entry (pulls `loader.luau` from GitHub) |
| `hub/` | Core runtime (`core_base`, `core_ui`, `alleral_ui`, telemetry, security, …) |
| `games/` | Per-game scripts (public, no obfuscation) |
| `cfg/` | Versions, manifests, site copy, telemetry/security JSON |
| `relay/` | Railway API + Next.js site (single source of truth) |
| `maint/` | Release and verify scripts |

## Before you push

```powershell
./maint/bump_release.ps1
./maint/verify_versions.ps1
./maint/verify_ui_compat.ps1
```

Bumps the release stamp, builds the Next.js site, then verifies the loader/site copies.

## Deploy

- **Railway** — root `Dockerfile` + `railway.toml`
- **GitHub Pages** — `.github/workflows/deploy-site.yml` publishes the `-kick-loader` site mirror

## Rules

- Single public repo — no dual-repo sync, no obfuscation
- Only one root `.luau` file: `loader.luau`
