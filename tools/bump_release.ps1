# Refresh release.json commit + updatedAt so live auto-update triggers after push.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$releasePath = Join-Path $root "config/release.json"
$commit = (git -C $root rev-parse --short HEAD).Trim()
$updatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss'Z'")
$release = Get-Content $releasePath -Raw | ConvertFrom-Json
$release.commit = $commit
$release.updatedAt = $updatedAt
$release | ConvertTo-Json -Depth 6 | Set-Content $releasePath -Encoding utf8
Write-Host "release.json -> commit=$commit updatedAt=$updatedAt"
