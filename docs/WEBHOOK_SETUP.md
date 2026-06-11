# Telemetry — complete setup guide

Full guide moved to `docs/`. Quick start:

```powershell
cd "Alleral Hub"
powershell -ExecutionPolicy Bypass -File tools/setup_telemetry.ps1
```

```
Roblox loader  →  HTTPS relay /ingest  →  Discord webhook
                 (API key only)          (hidden in backend/.env)
```

## Layout

```
kick/
├── loader.luau
├── core/                   Shared modules
├── games/                  Game scripts
├── games/data/             Game data (KickBlox)
├── config/                 Owner telemetry template
├── backend/                Python relay (Railway/local)
├── docs/                   Architecture + setup docs
├── tools/                  Dev + ops scripts
└── core/                     Shared runtime modules
```

## Relay URL

Production: `https://alleral-telemetry-production.up.railway.app`

See the original step-by-step in git history at `config/WEBHOOK_SETUP.md` or run `tools/setup_telemetry.ps1` for interactive setup.
