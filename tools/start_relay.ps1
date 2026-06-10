# Start the telemetry relay locally
Set-Location $PSScriptRoot\..\backend
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created backend/.env — edit DISCORD_WEBHOOK_URL and TELEMETRY_API_KEY first."
    exit 1
}
pip install -r requirements.txt -q
Write-Host "Relay starting on http://127.0.0.1:8787 (health: /health)"
python telemetry_relay.py
