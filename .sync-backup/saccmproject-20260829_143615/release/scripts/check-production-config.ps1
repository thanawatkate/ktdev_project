param(
  [string]$BackendEnv = "..\..\backend\.env",
  [string]$RegistryEnv = "..\..\registry-backend\.env"
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Checker = Join-Path $ScriptDir "check-production-config.js"

node $Checker --backend-env $BackendEnv --registry-env $RegistryEnv
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
