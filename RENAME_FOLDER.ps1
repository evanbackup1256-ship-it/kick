# Close Cursor/terminals using this folder first, then run:
#   powershell -ExecutionPolicy Bypass -File RENAME_FOLDER.ps1

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$parent = Split-Path -Parent $here
$target = Join-Path $parent "Alleral Hub"

if (Test-Path $target) {
    Write-Host "Already exists: $target"
    exit 0
}

Rename-Item -LiteralPath $here -NewName "Alleral Hub"
Write-Host "Renamed to: $target"
