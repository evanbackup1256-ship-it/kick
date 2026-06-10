# Generate a new TELEMETRY_API_KEY. Update backend/.env and private owner_telemetry.luau yourself.
$key = python -c "import secrets; print('aller_' + secrets.token_urlsafe(32))"
Write-Host "New TELEMETRY_API_KEY:"
Write-Host $key
Write-Host ""
Write-Host "1. Set in backend/.env"
Write-Host "2. Set apiKey in ../Alleral-Private/owner_telemetry.luau"
Write-Host "3. Redeploy relay"
Write-Host "4. Regenerate Discord webhook if it was ever shared"
