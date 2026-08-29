# Install SACCM Registry for keygen and activation logs.
param(
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

$Registry = Join-Path $ProjectRoot "registry-backend"
$EnvExample = Join-Path $Registry ".env.example"
$EnvFile = Join-Path $Registry ".env"

Write-Host "== SACCM Registry Install ==" -ForegroundColor Cyan
Write-Host "Path: $Registry"

if (-not (Test-Path $Registry)) {
    throw "registry-backend not found"
}

Push-Location $Registry
try {
    if (-not (Test-Path "node_modules")) {
        Write-Host "npm install..." -ForegroundColor Yellow
        npm install
    }

    $createdEnv = $false
    if (-not (Test-Path $EnvFile)) {
        Copy-Item $EnvExample $EnvFile
        $createdEnv = $true
        Write-Host "Created .env. Configure DB / ONLINE_API_BASE / secrets before migrate." -ForegroundColor Yellow
    }

    if ($createdEnv) {
        Write-Host @"

Stop before migrate because a new .env template was created:
  1. Edit $EnvFile with real values
  2. Run release\registry\install.ps1 again, or run: cd registry-backend; npm run migrate

"@ -ForegroundColor Yellow
        return
    }

    npm run migrate
    Write-Host "`nRegistry is ready: npm start (port 3802)" -ForegroundColor Green
    Write-Host "Online keygen smoke: npm run keygen:online -- --name `"Test School`"" -ForegroundColor Green
}
finally {
    Pop-Location
}
