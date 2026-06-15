param(
    [switch]$AutoCommit,
    [switch]$Push
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$root = Split-Path -Parent $here

Write-Host "=== bump_release ===" -ForegroundColor Cyan
& (Join-Path $here "bump_release.ps1")
if ($LASTEXITCODE -ne 0)
{ exit $LASTEXITCODE 
}

Write-Host "`n=== verify_versions ===" -ForegroundColor Cyan
& (Join-Path $here "verify_versions.ps1")
if ($LASTEXITCODE -ne 0)
{ exit $LASTEXITCODE 
}

if ($AutoCommit)
{
    $dirty = git -C $root status --porcelain
    if ($dirty)
    {
        $release = Get-Content (Join-Path $root "cfg/release.json") -Raw | ConvertFrom-Json
        $syncPaths = @(
            "cfg/release.json",
            "cfg/site.json",
            "loader.luau",
            "ui/maclib/source.luau",
            "relay/site.json",
            "relay/scripts_manifest.json",
            "backend/GENERATED.txt",
            "backend/site.json",
            "backend/scripts_manifest.json"
        )
        foreach ($rel in $syncPaths)
        {
            $full = Join-Path $root $rel
            if (Test-Path $full)
            {
                git -C $root add $rel
            }
        }
        git -C $root add backend/
        $msg = "Update release commit hash after version sync (v$($release.loader))."
        git -C $root commit -m $msg
        Write-Host "Committed sync changes." -ForegroundColor Green

        if ($Push)
        {
            git -C $root push origin HEAD
            Write-Host "Pushed to origin." -ForegroundColor Green
        }
    } else
    {
        Write-Host "No sync file changes to commit." -ForegroundColor DarkGray
    }
}

Write-Host "`nRepo sync complete." -ForegroundColor Green
