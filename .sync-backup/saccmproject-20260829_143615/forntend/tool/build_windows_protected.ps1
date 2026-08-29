<#
.SYNOPSIS
  Build the SACCM Windows release in "protected" mode (anti-tamper).

.DESCRIPTION
  Steps:
    1) flutter build windows --release with Dart obfuscation
       (--obfuscate + --split-debug-info) to make decompiling / reading
       symbol names hard.
    2) Create the integrity manifest (SHA-256 of the core binary files) and
       sign it with HMAC-SHA256 next to saccm.exe -- used for runtime
       anti-tamper checks.

  Resulting bundle:
    forntend\build\windows\x64\runner\Release\

.NOTES
  IMPORTANT -- the key must match in two places or integrity always fails:
    - $SecretHex (default) in forntend\tool\new_integrity_manifest.ps1
    - GuardSecret.integritySecretHex in
      forntend\lib\core\security\guard_secret.dart
  If you rotate the key, change BOTH and rebuild.

.EXAMPLE
  pwsh forntend\tool\build_windows_protected.ps1
  pwsh forntend\tool\build_windows_protected.ps1 -ApiBase "https://host/saccapi/"
#>
[CmdletBinding()]
param(
  [string]$ApiBase = "",
  [string]$RegistryBase = "",
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$FrontendRoot = Split-Path -Parent $PSScriptRoot
$ReleaseDir = Join-Path $FrontendRoot "build\windows\x64\runner\Release"

function Write-Step($msg) {
  Write-Host "==> $msg" -ForegroundColor Cyan
}

# -- 1) Build with obfuscation ----------------------------------------
if (-not $SkipBuild) {
  $symbolsDir = Join-Path $FrontendRoot "build\windows-symbols"
  New-Item -ItemType Directory -Force -Path $symbolsDir | Out-Null

  $buildArgs = @(
    "build", "windows",
    "--release",
    "--obfuscate",
    "--split-debug-info=$symbolsDir"
  )
  if ($ApiBase) { $buildArgs += "--dart-define=SACC_API_BASE=$ApiBase" }
  if ($RegistryBase) { $buildArgs += "--dart-define=SACC_REGISTRY_BASE=$RegistryBase" }

  Write-Step "flutter $($buildArgs -join ' ')"
  Push-Location $FrontendRoot
  try {
    & flutter @buildArgs
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed (exit $LASTEXITCODE)" }
  } finally {
    Pop-Location
  }
  Write-Host "debug symbols: $symbolsDir (keep for crash symbolize -- do NOT ship with the app)" -ForegroundColor DarkYellow
}

if (-not (Test-Path $ReleaseDir)) {
  throw "Release directory not found: $ReleaseDir"
}

# -- 2) Create + sign integrity manifest ------------------------------
Write-Step "Create integrity manifest"

$manifestPath = & (Join-Path $PSScriptRoot "new_integrity_manifest.ps1") -ReleaseDir $ReleaseDir

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

Write-Host ""
Write-Host "Done" -ForegroundColor Green
Write-Host "  bundle   : $ReleaseDir"
Write-Host "  manifest : $manifestPath"
foreach ($name in $manifest.files.PSObject.Properties.Name) {
  $hash = $manifest.files.$name
  Write-Host ("    {0}  {1}" -f $hash.Substring(0, 16), $name)
}
