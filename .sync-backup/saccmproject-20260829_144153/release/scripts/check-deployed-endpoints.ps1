param(
  [Parameter(Mandatory = $true)]
  [string]$BackendBase,

  [Parameter(Mandatory = $true)]
  [string]$RegistryBase,

  [string]$Origin = "",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Checker = Join-Path $ScriptDir "check-deployed-endpoints.js"

$argsList = @(
  "--backend-base", $BackendBase,
  "--registry-base", $RegistryBase
)

if (-not [string]::IsNullOrWhiteSpace($Origin)) {
  $argsList += @("--origin", $Origin)
}

if ($AllowLocalhost) {
  $argsList += "--allow-localhost"
}

node $Checker @argsList
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
