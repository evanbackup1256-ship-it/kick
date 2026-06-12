# Repo layout

| Path | What it is |
|------|------------|
| `loader.luau` | Entry point — boot, updates, game routing |
| `hub/` | Core runtime (`core_base`, `core_ui`, `alleral_ui`, telemetry, security, …) |
| `games/` | Per-game scripts |
| `cfg/` | Versions, manifests, site copy, telemetry/security JSON |
| `relay/` | Source for the Railway API + public site (edit here, not `backend/`) |
| `maint/` | Sync and verify scripts |

## Before you push

```powershell
./maint/sync_repo.ps1
```

That bumps the release stamp, copies `cfg/` → `relay/` → `backend/`, and runs version checks.

## Deploy

- **Railway** — root `Dockerfile` + `railway.toml` (builds from synced `backend/`)
- **GitHub Pages** — `.github/workflows/deploy-site.yml` publishes `relay/site`

## Rules

- Only one root `.luau` file: `loader.luau`
- Don't hand-edit `backend/` — change `relay/` and sync
