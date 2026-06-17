# Migration script: update REPO references from private repo to public loader repo
# Run this when you create the public repo and are ready to switch over.
#
# Usage: pwsh -File maint/migrate_public_repo.ps1 -TargetRepo "evanbackup1256-ship-it/kick-loader"

param(
  [Parameter(Mandatory = $true)]
  [string]$TargetRepo
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

$SourceRepo = "evanbackup1256-ship-it/kick"
$files = @(
  "bootstrap.luau",
  "loader.luau",
  "hub/bootstrap.luau",
  "kick/bootstrap.luau",
  "kick/loader.luau"
)

foreach ($relative in $files) {
  $path = Join-Path $root $relative
  if (-not (Test-Path $path)) {
    Write-Host "Skipping $relative (not found)"
    continue
  }

  $content = Get-Content $path -Raw -Encoding UTF8
  if ($content -match [regex]::Escape($SourceRepo)) {
    $content = $content -replace [regex]::Escape($SourceRepo), $TargetRepo
    Write-Utf8NoBom $path $content
    Write-Host "Updated ${relative}: $SourceRepo → $TargetRepo"
  } else {
    Write-Host "No changes needed in ${relative}"
  }
}

Write-Host "`nMigration complete. Commit and push these changes before making the repo private."
Write-Host "Then go to GitHub → Settings → Danger Zone → Make private"
