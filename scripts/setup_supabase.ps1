# Alleral - complete Supabase setup for management backend
# Usage:
#   .\scripts\setup_supabase.ps1
#   .\scripts\setup_supabase.ps1 -ProjectName "alleral-hub" -Region "us-east-1"
#
# Requires one-time: npx supabase login

param(
  [string]$ProjectName = "alleral-hub",
  [string]$Region = "us-east-1",
  [string]$DbPassword = "",
  [switch]$SkipCreate
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    !! $msg" -ForegroundColor Yellow }

Write-Step "Checking Supabase CLI"
$npx = Get-Command npx -ErrorAction SilentlyContinue
if (-not $npx) { throw "Node/npx required. Install Node.js first." }
$ver = npx supabase --version 2>&1
Write-Ok "Supabase CLI $ver"

Write-Step "Verify supabase/ migrations exist"
if (-not (Test-Path "supabase\migrations\20250610000000_alleral_management.sql")) {
  throw "Missing supabase/migrations - run from repo root."
}
Write-Ok "Migration ready"

Write-Step "Check Supabase login"
if ($env:SUPABASE_ACCESS_TOKEN) {
  $ErrorActionPreference = "Continue"
  npx supabase login --token $env:SUPABASE_ACCESS_TOKEN --no-browser 2>&1 | Out-Null
  $ErrorActionPreference = "Stop"
}
$ErrorActionPreference = "Continue"
$listOut = npx supabase projects list 2>&1
$listExit = $LASTEXITCODE
$ErrorActionPreference = "Stop"
if ($listExit -ne 0) {
  Write-Warn "Not logged in."
  Write-Host @'
  Option A - browser login (recommended):
    npx supabase login

  Option B - personal access token:
    1. Create token at supabase.com/dashboard/account/tokens
    2. $env:SUPABASE_ACCESS_TOKEN = "sbp_..."
    3. Re-run: .\scripts\setup_supabase.ps1

  Then re-run this script.
'@ -ForegroundColor Yellow
  exit 1
}
Write-Ok "Authenticated"

$projectRef = $null
if (-not $SkipCreate) {
  Write-Step "Looking for existing project '$ProjectName'"
  $ErrorActionPreference = "Continue"
  $listJson = npx supabase projects list -o json 2>&1 | Out-String
  $ErrorActionPreference = "Stop"
  try {
    $jsonStart = $listJson.IndexOf('[')
    if ($jsonStart -ge 0) { $listJson = $listJson.Substring($jsonStart) }
    $projects = $listJson | ConvertFrom-Json
    $existing = $projects | Where-Object { $_.name -eq $ProjectName } | Select-Object -First 1
    if ($existing) {
      $projectRef = $existing.ref
      if (-not $projectRef) { $projectRef = $existing.id }
      Write-Ok "Using existing project ref: $projectRef"
    } elseif ($projects.Count -eq 1) {
      $projectRef = $projects[0].ref
      if (-not $projectRef) { $projectRef = $projects[0].id }
      Write-Ok "Using only account project: $($projects[0].name) ($projectRef)"
    }
  } catch {
    Write-Warn "Could not parse project list JSON"
  }

  if (-not $projectRef) {
    Write-Step "Creating Supabase project '$ProjectName' in $Region"
    if (-not $DbPassword) {
      $DbPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
      Write-Ok "Generated DB password (save this): $DbPassword"
    }
    $createOut = npx supabase projects create $ProjectName --db-password $DbPassword --region $Region -o json 2>&1 | Out-String
    try {
      $created = $createOut | ConvertFrom-Json
      $projectRef = $created.id
      Write-Ok "Created project ref: $projectRef"
    } catch {
      Write-Warn "Create output: $createOut"
      throw "Project creation failed. Create manually at supabase.com/dashboard then run with -SkipCreate"
    }
    Write-Host "    Waiting 45s for project provisioning..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 45
  }
} else {
  Write-Step "Enter project ref (Dashboard -> Project Settings -> General -> Reference ID)"
  $projectRef = Read-Host "Project ref"
}

if (-not $projectRef) { throw "No project ref" }

Write-Step "Linking local repo to Supabase project $projectRef"
npx supabase link --project-ref $projectRef --yes 2>&1 | ForEach-Object { Write-Host "    $_" }
if ($LASTEXITCODE -ne 0) { throw "supabase link failed" }
Write-Ok "Linked"

Write-Step "Pushing database schema (migrations)"
npx supabase db push --yes 2>&1 | ForEach-Object { Write-Host "    $_" }
if ($LASTEXITCODE -ne 0) {
  Write-Warn "db push failed - paste supabase/migrations/*.sql into Supabase SQL Editor manually"
}

Write-Step "Fetching API keys"
$keysJson = npx supabase projects api-keys --project-ref $projectRef -o json 2>&1 | Out-String
$url = "https://$projectRef.supabase.co"
$serviceKey = ""
$anonKey = ""
try {
  $keys = $keysJson | ConvertFrom-Json
  foreach ($k in $keys) {
    if ($k.name -eq "service_role") { $serviceKey = $k.api_key }
    if ($k.name -eq "anon") { $anonKey = $k.api_key }
  }
} catch {
  Write-Warn "Could not parse API keys - copy from Dashboard -> Settings -> API"
}

Write-Step "Writing relay/.env Supabase variables"
$envPath = Join-Path $Root "relay\.env"
$lines = @()
if (Test-Path $envPath) {
  $lines = Get-Content $envPath | Where-Object {
    $_ -notmatch '^(SUPABASE_URL|SUPABASE_SERVICE_KEY|SUPABASE_ANON_KEY|SUPABASE_AUDIT_TABLE)='
  }
}
$lines += "SUPABASE_URL=$url"
if ($serviceKey) { $lines += "SUPABASE_SERVICE_KEY=$serviceKey" }
if ($anonKey) { $lines += "SUPABASE_ANON_KEY=$anonKey" }
$lines += "SUPABASE_AUDIT_TABLE=alleral_audit"
Set-Content -Path $envPath -Value ($lines -join "`n") -Encoding UTF8
Write-Ok "Updated relay/.env (gitignored)"

Write-Step "Railway variables - add these in Dashboard -> Variables"
$maskedKey = if ($serviceKey) { ($serviceKey.Substring(0, [Math]::Min(8, $serviceKey.Length)) + "...") } else { "(service_role key from Supabase Dashboard)" }
Write-Host ""
Write-Host "  SUPABASE_URL=$url"
Write-Host "  SUPABASE_SERVICE_KEY=$maskedKey"
Write-Host "  SUPABASE_ANON_KEY=(anon key, optional)"
Write-Host "  SUPABASE_AUDIT_TABLE=alleral_audit"
Write-Host ""

if ($serviceKey) {
  $railway = Get-Command railway -ErrorAction SilentlyContinue
  if ($railway) {
    Write-Step "Optional: push vars to Railway (requires 'railway link' in this folder)"
    Write-Host "  railway variables set SUPABASE_URL=`"$url`""
    Write-Host "  railway variables set SUPABASE_SERVICE_KEY=`"$serviceKey`""
    Write-Host "  railway variables set SUPABASE_AUDIT_TABLE=alleral_audit"
    Write-Host ""
  }
}

Write-Step "Verify after deploy"
Write-Host @'
  1. Redeploy Railway
  2. Open https://alleral-telemetry-production.up.railway.app/manage
  3. Sign in with ADMIN_API_KEY
  4. Click Test Supabase - should show Connected
  5. Click Sync to Supabase to push pending audit rows
'@ -ForegroundColor White

Write-Ok "Supabase setup complete for project $projectRef"
