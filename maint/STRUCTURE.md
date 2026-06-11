# Alleral repo layout

Edit sources live in **`cfg/`**, **`relay/`**, **`hub/`**, **`games/`**, **`loader.luau`**, and **`ui/`**.

## Source of truth

| What | Edit here |
|------|-----------|
| Loader / hub module versions | `cfg/release.json` + matching `VERSION` in `loader.luau` / `hub/*.luau` |
| Game script versions | `cfg/scripts_manifest.json` + `local VERSION` in each `games/*.luau` + `loader.luau` `GAMES` table |
| Public site copy | `cfg/site.json` |
| Backend Python + static site | **`relay/`** (never edit `backend/` by hand) |
| Hub site frontend (main page) | `relay/site/src/site.ts` → run `npm run build` in `relay/site` |

## Sync before push

```powershell
./maint/sync_repo.ps1
```

This runs `bump_release.ps1` (updates commit stamp, syncs `cfg/` → `relay/` → `backend/`) and `verify_versions.ps1`.

## Deploy

| Target | Config |
|--------|--------|
| Railway API | Root `Dockerfile` + `railway.toml` (builds from `backend/`) |
| GitHub Pages | `.github/workflows/deploy-site.yml` publishes `relay/site` |

## Do not add

- Extra `.luau` files at repo root (only `loader.luau` is allowed)
- Root `README.md` (blocked by verify script)
