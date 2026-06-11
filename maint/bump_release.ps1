$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

$releasePath = Join-Path $root "cfg/release.json"
$commit = (git -C $root rev-parse --short HEAD).Trim()
$updatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss'Z'")
$release = Get-Content $releasePath -Raw | ConvertFrom-Json
$release.commit = $commit
$release.updatedAt = $updatedAt
Write-Utf8NoBom $releasePath (($release | ConvertTo-Json -Depth 6) + "`n")
Write-Host "release.json -> commit=$commit updatedAt=$updatedAt"

$manifestSrc = Join-Path $root "cfg/scripts_manifest.json"
$siteSrc = Join-Path $root "cfg/site.json"
$site = Get-Content $siteSrc -Raw | ConvertFrom-Json
$site.loaderVersion = $release.loader
$site.updatedAt = $updatedAt
Write-Utf8NoBom $siteSrc (($site | ConvertTo-Json -Depth 10) + "`n")
Copy-Item $manifestSrc (Join-Path $root "relay/scripts_manifest.json") -Force
Copy-Item $siteSrc (Join-Path $root "relay/site.json") -Force

$relayFiles = @(
    "telemetry_relay.py",
    "script_registry.py",
    "ban_registry.py",
    "site_registry.py",
    "requirements.txt",
    "Dockerfile",
    "railway.toml",
    "scripts_manifest.json",
    "site.json"
)
$backendDir = Join-Path $root "backend"
New-Item -ItemType Directory -Force -Path $backendDir | Out-Null
foreach ($name in $relayFiles) {
    Copy-Item (Join-Path $root "relay/$name") (Join-Path $backendDir $name) -Force
}

function Sync-Tree($src, $dest) {
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Copy-Item $src $dest -Recurse -Force
}
Sync-Tree (Join-Path $root "relay/site") (Join-Path $root "backend/site")

Write-Host "relay + backend deploy bundle synced (site + manifest)"
