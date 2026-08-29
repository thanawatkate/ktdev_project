param(
    [string]$ProjectPath = "D:\project\saccmproject\forntend",
    [ValidateSet("debug", "release", "profile")]
    [string]$BuildMode = "debug",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

function Run-Step {
    param(
        [string]$Title,
        [scriptblock]$Action
    )

    Write-Host ""
    Write-Host "==> $Title" -ForegroundColor Cyan
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed: $Title (exit code: $LASTEXITCODE)"
    }
}

if (-not (Test-Path -LiteralPath $ProjectPath)) {
    throw "Project path not found: $ProjectPath"
}

Set-Location -LiteralPath $ProjectPath

Write-Host "Flutter Windows recovery started" -ForegroundColor Green
Write-Host "Project: $ProjectPath"
Write-Host "Build mode: $BuildMode"
Write-Host "Skip build: $SkipBuild"

Run-Step -Title "Flutter clean" -Action { flutter clean }
Run-Step -Title "Flutter pub get" -Action { flutter pub get }

if (-not $SkipBuild) {
    Run-Step -Title "Flutter build windows --$BuildMode" -Action { flutter build windows --$BuildMode }
}

Write-Host ""
Write-Host "Recovery completed successfully." -ForegroundColor Green
Write-Host "If crash appears again, close IDE terminals and rerun this script." -ForegroundColor Yellow
