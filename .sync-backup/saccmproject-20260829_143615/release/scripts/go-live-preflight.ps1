param(
  [string]$BackendEnv = "..\..\backend\.env",
  [string]$RegistryEnv = "..\..\registry-backend\.env",
  [switch]$SkipBackendTests,
  [switch]$RunStagingSmoke,
  [string]$StagingBaseUrl = "",
  [string]$StagingDbName = "",
  [switch]$CheckDeployedEndpoints,
  [string]$BackendBase = "",
  [string]$RegistryBase = "",
  [string]$Origin = ""
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..")

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  Write-Host ""
  Write-Host "==> $Name"
  & $Action
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
}

Invoke-Step "Production config preflight" {
  & node (Join-Path $ScriptDir "check-production-config.js") `
    --backend-env $BackendEnv `
    --registry-env $RegistryEnv
}

if (-not $SkipBackendTests) {
  Invoke-Step "Backend guard suite" {
    Push-Location (Join-Path $RepoRoot "backend")
    try {
      & npm test
    } finally {
      Pop-Location
    }
  }
}

if ($RunStagingSmoke) {
  if ([string]::IsNullOrWhiteSpace($StagingBaseUrl) -or [string]::IsNullOrWhiteSpace($StagingDbName)) {
    throw "RunStagingSmoke requires -StagingBaseUrl and -StagingDbName"
  }

  Invoke-Step "Remote staging HTTP smoke" {
    Push-Location (Join-Path $RepoRoot "backend")
    try {
      $previousBaseUrl = $env:E2E_BASE_URL
      $previousDbName = $env:DB_NAME
      $env:E2E_BASE_URL = $StagingBaseUrl
      $env:DB_NAME = $StagingDbName
      & npm run test:e2e:http:staging
    } finally {
      if ($null -eq $previousBaseUrl) {
        Remove-Item Env:E2E_BASE_URL -ErrorAction SilentlyContinue
      } else {
        $env:E2E_BASE_URL = $previousBaseUrl
      }

      if ($null -eq $previousDbName) {
        Remove-Item Env:DB_NAME -ErrorAction SilentlyContinue
      } else {
        $env:DB_NAME = $previousDbName
      }
      Pop-Location
    }
  }
}

if ($CheckDeployedEndpoints) {
  if ([string]::IsNullOrWhiteSpace($BackendBase) -or [string]::IsNullOrWhiteSpace($RegistryBase)) {
    throw "CheckDeployedEndpoints requires -BackendBase and -RegistryBase"
  }

  Invoke-Step "Deployed endpoint verification" {
    $endpointArgs = @(
      "--backend-base", $BackendBase,
      "--registry-base", $RegistryBase
    )
    if (-not [string]::IsNullOrWhiteSpace($Origin)) {
      $endpointArgs += @("--origin", $Origin)
    }
    & node (Join-Path $ScriptDir "check-deployed-endpoints.js") @endpointArgs
  }
}

Write-Host ""
Write-Host "go-live-preflight: PASS"
