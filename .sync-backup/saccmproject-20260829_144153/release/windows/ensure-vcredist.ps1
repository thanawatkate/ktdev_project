# Download Microsoft VC++ 2015-2022 x64 redistributable for bundling in SACCM installer.
# Microsoft permits redistribution: https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist

$ErrorActionPreference = "Stop"

$RedistDir = Join-Path $PSScriptRoot "redist"
$RedistFile = Join-Path $RedistDir "vc_redist.x64.exe"
$Url = "https://aka.ms/vs/17/release/vc_redist.x64.exe"

New-Item -ItemType Directory -Force -Path $RedistDir | Out-Null

if (Test-Path $RedistFile) {
    $sizeMb = [math]::Round((Get-Item $RedistFile).Length / 1MB, 1)
    Write-Host "VC++ redist already present ($sizeMb MB): $RedistFile"
    exit 0
}

Write-Host "Downloading VC++ 2015-2022 x64 redistributable..." -ForegroundColor Yellow
Write-Host "  $Url"

Invoke-WebRequest -Uri $Url -OutFile $RedistFile -UseBasicParsing

$sizeMb = [math]::Round((Get-Item $RedistFile).Length / 1MB, 1)
Write-Host "Saved ($sizeMb MB): $RedistFile" -ForegroundColor Green
