<#
.SYNOPSIS
  Build signed SACCM Android release APK for school distribution.

.DESCRIPTION
  1) frontend-release-preflight (signing key, pubspec.lock, generated files)
  2) flutter build apk --release --obfuscate
  3) manifest.json + SHA256SUMS.txt + distribution ZIP

  Requires forntend\android\key.properties (copy from key.properties.example).

.EXAMPLE
  .\build-android-release.ps1 -SchoolSlug "pilot" -Version "1.0.0+1"

.EXAMPLE
  .\build-android-release.ps1 -SchoolSlug "school-a" -SplitPerAbi

.EXAMPLE
  .\build-android-release.ps1 -SchoolSlug "school-a" -BuildAppBundle
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SchoolSlug,

    [string]$ApiBase = "",
    [string]$RegistryBase = "",
    [string]$Version = "1.0.0+1",
    [string]$ProjectRoot = "",
    [switch]$BuildAppBundle,
    [switch]$SplitPerAbi
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$CoreScript = Join-Path $ScriptDir "..\scripts\build-android-release.ps1"

& $CoreScript @PSBoundParameters
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
