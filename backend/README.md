# Alleral Telemetry Relay v3

Server-side Discord webhook proxy. Clients never see your webhook URL.

## Run locally

```bash
cp .env.example .env   # fill DISCORD_WEBHOOK_URL + TELEMETRY_API_KEY
pip install -r requirements.txt
python telemetry_relay.py
```

## Deploy (Railway)

1. New project → deploy from `backend/` (uses `Dockerfile` + `railway.toml`)
2. Set env vars from `.env.example`
3. Use `https://YOUR-APP.up.railway.app/ingest` in `config/owner_telemetry.luau`

## Endpoints

| Method | Path | Auth |
|--------|------|------|
| GET | `/health` | None |
| POST | `/ingest` | Header `X-Alleral-Key` |

Returns `202 Accepted` — work is queued so bursts don't drop events.

## Scale defaults

- Queue: 5000 events
- Discord: ~1 post / 0.55s with retry on 429
- Heartbeats: batched every 90s into one embed
- Per-IP: 120 requests/min

See [../config/WEBHOOK_SETUP.md](../config/WEBHOOK_SETUP.md) for the full guide.
