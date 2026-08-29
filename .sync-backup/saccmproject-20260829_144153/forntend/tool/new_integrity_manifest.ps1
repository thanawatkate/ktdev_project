<#
.SYNOPSIS
  Create + sign the integrity manifest for the code-protection system (shared).

.DESCRIPTION
  Computes SHA-256 of the core binary files, signs them with HMAC-SHA256, and
  writes integrity_manifest.json next to saccm.exe in $ReleaseDir.

  Shared by:
    - forntend\tool\build_windows_protected.ps1
    - release\scripts\build-release.ps1
  so the secret + canonical logic live in one place and never drift.

.NOTES
  The default $SecretHex MUST match GuardSecret.integritySecretHex in
  forntend\lib\core\security\guard_secret.dart.
  If you rotate the key, change it in BOTH places and rebuild.

.EXAMPLE
  pwsh forntend\tool\new_integrity_manifest.ps1 -ReleaseDir "C:\path\to\Release"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ReleaseDir,

  # MUST match GuardSecret.integritySecretHex
  [string]$SecretHex = "7c4e91a2b3d65f08e1c2a4b6d8f0e2c4a6b8d0f2e4c6a8b0d2f4e6c8a0b2d4f6",

  # Binary files to verify (exclude data/assets that can legitimately change)
  [string[]]$ProtectedFiles = @("saccm.exe", "flutter_windows.dll")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
  throw "Release directory not found: $ReleaseDir"
}

$files = [ordered]@{}
foreach ($name in ($ProtectedFiles | Sort-Object)) {
  $full = Join-Path $ReleaseDir $name
  if (-not (Test-Path -LiteralPath $full)) {
    throw "Protected file not found: $full"
  }
  $files[$name] = (Get-FileHash -Algorithm SHA256 -LiteralPath $full).Hash.ToLower()
}

# Canonical string must match _canonicalFiles() on the Dart side:
#   key=hash;  (keys sorted, hash lowercase)
$canonical = ($files.Keys | Sort-Object | ForEach-Object {
  "$_=$($files[$_]);"
}) -join ""

$keyBytes = [byte[]]::new($SecretHex.Length / 2)
for ($i = 0; $i -lt $keyBytes.Length; $i++) {
  $keyBytes[$i] = [Convert]::ToByte($SecretHex.Substring($i * 2, 2), 16)
}
$hmac = [System.Security.Cryptography.HMACSHA256]::new($keyBytes)
$sigBytes = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($canonical))
$signature = ([System.BitConverter]::ToString($sigBytes) -replace '-', '').ToLower()
$hmac.Dispose()

$manifest = [ordered]@{
  version   = 1
  files     = $files
  signature = $signature
}

$manifestPath = Join-Path $ReleaseDir "integrity_manifest.json"
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

return $manifestPath
