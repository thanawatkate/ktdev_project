# Install SACCM API on Windows Server.
$ErrorActionPreference = "Stop"

$BackendRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\backend")
$EnvExample = Join-Path $PSScriptRoot "..\templates\.env.production.example"
$EnvTarget = Join-Path $BackendRoot ".env"

Write-Host "SACCM Backend Installer" -ForegroundColor Cyan
Write-Host "Path: $BackendRoot"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js 18+ is required"
}

Push-Location $BackendRoot
try {
    Write-Host "npm ci ..."
    npm ci

    $createdEnv = $false
    if (-not (Test-Path $EnvTarget)) {
        Copy-Item $EnvExample $EnvTarget
        $createdEnv = $true
        Write-Host "Created .env from template. Configure DB and secrets before production use." -ForegroundColor Yellow
    }

    if ($createdEnv) {
        Write-Host @"

Stop before migrate because a new .env template was created:
  1. Edit $EnvTarget with real values
  2. Run release\backend\install.ps1 again, or run: cd backend; npm run migrate

"@ -ForegroundColor Yellow
        return
    }

    Write-Host "npm run migrate ..."
    npm run migrate

    Write-Host @"

Install completed. Next steps:
  1. Verify $EnvTarget
  2. Generate a license: cd release\scripts; .\keygen.ps1 -SchoolName "School Name"
  3. Run server: npm start, or use PM2 / Windows Service

"@ -ForegroundColor Green
}
finally {
    Pop-Location
}
