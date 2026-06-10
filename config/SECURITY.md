# Security — sharing Alleral Hub

If other people can read this folder, assume **every gitignored file on disk can be read too**.

## Never put in a shared / public copy

| File / folder | Why |
|---------------|-----|
| `backend/.env` | Discord webhook URL |
| `config/owner_telemetry.luau` | Relay API key |
| `../Alleral-Private/` | Owner-only overlay (recommended) |

Before sharing, run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/prepare_distribution.ps1
```

## Where owner secrets should live

**Recommended:** sibling folder the hub does not ship:

```
Desktop/
├── Alleral Hub/          ← share this
└── Alleral-Private/
    └── owner_telemetry.luau   ← only you keep this
```

Loader checks `../Alleral-Private/owner_telemetry.luau` first.

## If secrets were exposed

1. **Regenerate** the Discord webhook in Discord channel settings.
2. **Rotate** `TELEMETRY_API_KEY` (`tools/rotate_secrets.ps1`).
3. Update `backend/.env` and your private `owner_telemetry.luau`.
4. Redeploy the relay.

## What users cannot get (if configured correctly)

- Discord webhook URL (stays in `backend/.env` on your server only)
- Direct webhook mode is disabled in client code

## What users CAN extract (inherent limit)

- Relay `apiKey` if it exists in any file they can read or in a Roblox script
- Mitigation: rate limits on relay, rotate key, use private folder outside shared hub

## Kick in-game webhooks

Those are **per-user** URLs they paste in the UI — separate from owner telemetry.
