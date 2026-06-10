# Telemetry — complete setup guide

## Current layout (after setup)

```
kick/
├── Alleral Hub/              ← scripts (shareable)
│   ├── backend/.env          ← Discord webhook + API key (SERVER, gitignored)
│   └── tools/setup_telemetry.ps1
└── Alleral-Private/          ← owner_telemetry.luau (NEVER share)
```

```
Roblox loader  →  HTTPS relay /ingest  →  Discord webhook
                 (API key only)          (hidden in backend/.env)
```

## Quick setup (one command)

```powershell
cd "Alleral Hub"
powershell -ExecutionPolicy Bypass -File tools/setup_telemetry.ps1
```

Or with your webhook already known:

```powershell
$env:DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/..."
$env:TELEMETRY_PUBLIC_URL = "https://alleral-telemetry-production.up.railway.app"
powershell -ExecutionPolicy Bypass -File tools/setup_telemetry.ps1
```

## What's running locally

| Service | URL |
|---------|-----|
| Relay | http://127.0.0.1:8787 |
| Health | http://127.0.0.1:8787/health |
| Ingest | POST http://127.0.0.1:8787/ingest |

| Offline stack | `powershell tools/start_telemetry_stack.ps1` (local relay + status) |
| Offline test | `powershell tools/test_offline_ingest.ps1` |

Start relay only: `powershell tools/start_relay.ps1`

## Two relays (both work together)

| Mode | URL | Used for |
|------|-----|----------|
| **Offline** | `http://127.0.0.1:8787/ingest` | Local testing, PowerShell scripts, dev |
| **Railway** | `https://alleral-telemetry-production.up.railway.app/ingest` | Roblox in-game (loader) |

Roblox cannot reach `localhost` — `owner_telemetry.luau` must use the Railway URL for in-game telemetry.

### Railway (production — already deployed)

1. [railway.app](https://railway.app) project `alleral-telemetry`
2. Env vars from `backend/.env` (DISCORD_WEBHOOK_URL + TELEMETRY_API_KEY)
3. `../Alleral-Private/owner_telemetry.luau` → `relayUrl` = Railway `/ingest` URL

Do **not** use localtunnel — Railway replaces it.

## Verify it works

1. **Offline:** `powershell tools/test_offline_ingest.ps1` → Discord gets test event
2. **Railway:** `https://alleral-telemetry-production.up.railway.app/health` → `{"ok":true}`
3. **Roblox:** run loader — Discord gets "Session started" + "Inject succeeded"
4. Loader log: `Owner telemetry active via alleral-telemetry-production.up.railway.app`

## Rotate secrets

```powershell
powershell tools/rotate_secrets.ps1
```

Update `backend/.env`, redeploy relay, update `Alleral-Private/owner_telemetry.luau`.

## Security

See [SECURITY.md](SECURITY.md). Never put API keys in `Alleral Hub/config/` if others read that folder.
