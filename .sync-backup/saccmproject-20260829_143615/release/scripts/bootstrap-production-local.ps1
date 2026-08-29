# Bootstrap local production stack: MariaDB (Docker) + backend/registry .env + migrate
param(
    [string]$ProjectRoot = "",
    [string]$CorsOrigin = "http://localhost",
    [switch]$SkipDocker,
    [switch]$SkipMigrate,
    [switch]$StartServers
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

$BackendRoot = Join-Path $ProjectRoot "backend"
$RegistryRoot = Join-Path $ProjectRoot "registry-backend"
$DockerDir = Join-Path $ProjectRoot "release\docker"
$SecretsDir = Join-Path $ProjectRoot "release\local-production"
$SecretsFile = Join-Path $SecretsDir "secrets.json"
$BackendEnv = Join-Path $BackendRoot ".env"
$RegistryEnv = Join-Path $RegistryRoot ".env"
$BackendTemplate = Join-Path $ProjectRoot "release\templates\.env.production.example"
$RegistryTemplate = Join-Path $RegistryRoot ".env.example"

function New-RandomSecret {
    param([int]$Length = 48)
    $bytes = New-Object byte[] ([math]::Ceiling($Length * 0.75))
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $raw = [Convert]::ToBase64String($bytes) -replace '\+', 'A' -replace '/', 'B' -replace '=', ''
    if ($raw.Length -ge $Length) { return $raw.Substring(0, $Length) }
    return $raw.PadRight($Length, 'x')
}

function Get-OrCreateSecrets {
    if (Test-Path $SecretsFile) {
        return Get-Content $SecretsFile -Raw | ConvertFrom-Json
    }

    $internal = New-RandomSecret -Length 48
    $secrets = [PSCustomObject]@{
        generated_at = (Get-Date).ToUniversalTime().ToString("o")
        mariadb_root_password = New-RandomSecret -Length 32
        db_app_password = New-RandomSecret -Length 24
        db_registry_password = New-RandomSecret -Length 24
        secretkey = New-RandomSecret -Length 48
        internal_api_secret = $internal
        license_admin_secret = New-RandomSecret -Length 48
        trial_signing_secret = New-RandomSecret -Length 48
    }

    New-Item -ItemType Directory -Force -Path $SecretsDir | Out-Null
    $secrets | ConvertTo-Json | Set-Content -Path $SecretsFile -Encoding UTF8
    Write-Host "Created secrets -> $SecretsFile (keep private, not in git)" -ForegroundColor Yellow
    return $secrets
}

function Write-EnvFile {
    param(
        [string]$TemplatePath,
        [string]$TargetPath,
        [hashtable]$Replacements
    )

    $content = Get-Content -LiteralPath $TemplatePath -Raw
    foreach ($key in $Replacements.Keys) {
        $content = $content -replace [regex]::Escape($key), [string]$Replacements[$key]
    }
    Set-Content -LiteralPath $TargetPath -Value $content -Encoding UTF8
    Write-Host "Wrote $TargetPath"
}

function Write-DockerInitSql {
    param($Secrets)

    $initDir = Join-Path $DockerDir "init"
    New-Item -ItemType Directory -Force -Path $initDir | Out-Null
    $sqlPath = Join-Path $initDir "01-init.generated.sql"

    $appPwd = $Secrets.db_app_password
    $regPwd = $Secrets.db_registry_password
    $sql = @"
CREATE DATABASE IF NOT EXISTS saccm_master CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS saccm_registry CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'saccm_app'@'%' IDENTIFIED BY '$appPwd';
GRANT ALL PRIVILEGES ON saccm_master.* TO 'saccm_app'@'%';

CREATE USER IF NOT EXISTS 'saccm_registry'@'%' IDENTIFIED BY '$regPwd';
GRANT ALL PRIVILEGES ON saccm_registry.* TO 'saccm_registry'@'%';

FLUSH PRIVILEGES;
"@
    Set-Content -LiteralPath $sqlPath -Value $sql -Encoding ASCII
}

Write-Host "== SACCM local production bootstrap ==" -ForegroundColor Cyan

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js is required"
}

$secrets = Get-OrCreateSecrets

Write-DockerInitSql -Secrets $secrets

$backendReplacements = [ordered]@{
    "CHANGE_ME_LONG_RANDOM" = $secrets.secretkey
    "CHANGE_ME_INTERNAL_SECRET" = $secrets.internal_api_secret
    "CHANGE_ME_ONLY_IF_SETUP_ENABLED" = (New-RandomSecret -Length 32)
    "https://your-app-host.example.com" = $CorsOrigin
    "CHANGE_ME" = $secrets.db_app_password
}
Write-EnvFile -TemplatePath $BackendTemplate -TargetPath $BackendEnv -Replacements $backendReplacements

$registryReplacements = [ordered]@{
    "CHANGE_ME_SAME_AS_ONLINE_BACKEND" = $secrets.internal_api_secret
    "CHANGE_ME_ADMIN_SECRET" = $secrets.license_admin_secret
    "CHANGE_ME_TRIAL_SIGNING_SECRET" = $secrets.trial_signing_secret
    "https://your-app-host.example.com" = $CorsOrigin
    "CHANGE_ME" = $secrets.db_registry_password
}
Write-EnvFile -TemplatePath $RegistryTemplate -TargetPath $RegistryEnv -Replacements $registryReplacements

if (-not $SkipDocker) {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Docker is required (or pass -SkipDocker if MariaDB is already running)"
    }

    $dockerEnvPath = Join-Path $DockerDir ".env"
    @(
        "MARIADB_ROOT_PASSWORD=$($secrets.mariadb_root_password)"
        "SACCM_DB_PORT=3306"
    ) | Set-Content -Path $dockerEnvPath -Encoding ASCII

    Write-Host "`n-- Docker MariaDB --" -ForegroundColor Yellow
    Push-Location $DockerDir
    try {
        docker compose up -d
        if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

        Write-Host "Waiting for MariaDB..."
        $healthy = $false
        for ($i = 0; $i -lt 60; $i++) {
            $status = docker inspect -f '{{.State.Health.Status}}' saccm-mariadb 2>$null
            if ($status -eq 'healthy') { $healthy = $true; break }
            Start-Sleep -Seconds 2
        }
        if (-not $healthy) { throw "MariaDB did not become healthy in time" }
        Write-Host "MariaDB healthy" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

if (-not $SkipMigrate) {
    Write-Host "`n-- Backend install/migrate --" -ForegroundColor Yellow
    & (Join-Path $ProjectRoot "release\backend\install.ps1")

    Write-Host "`n-- Registry install/migrate --" -ForegroundColor Yellow
    & (Join-Path $ProjectRoot "release\registry\install.ps1")
}

Write-Host "`n-- Production config check --" -ForegroundColor Yellow
& node (Join-Path $PSScriptRoot "check-production-config.js") `
    --backend-env $BackendEnv `
    --registry-env $RegistryEnv
if ($LASTEXITCODE -ne 0) {
    throw "check-production-config failed"
}

if ($StartServers) {
    Write-Host "`n-- Starting API servers (background) --" -ForegroundColor Yellow
    $backendCmd = "Set-Location '$BackendRoot'; npm start"
    $registryCmd = "Set-Location '$RegistryRoot'; npm start"
    Start-Process powershell -ArgumentList @('-NoProfile', '-Command', $backendCmd) -WindowStyle Minimized
    Start-Process powershell -ArgumentList @('-NoProfile', '-Command', $registryCmd) -WindowStyle Minimized
    Start-Sleep -Seconds 5
    Write-Host "Backend  -> http://127.0.0.1:3801/saccapi"
    Write-Host "Registry -> http://127.0.0.1:3802/registryapi"
}

Write-Host "`nBootstrap complete." -ForegroundColor Green
Write-Host "Secrets: $SecretsFile"
Write-Host "Next: cd release\scripts; .\keygen.ps1 -SchoolName `"Pilot School`""
