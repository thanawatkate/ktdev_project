param(
  [string]$ApiBase = "",
  [string]$RegistryBase = "",
  [string]$ProjectRoot = "",
  [switch]$AllowLocalhost,
  [switch]$WindowsOnly
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

$Frontend = Join-Path $ProjectRoot "forntend"
$KeyProperties = Join-Path $Frontend "android\key.properties"
$PubspecLock = Join-Path $Frontend "pubspec.lock"

function Test-ReleaseUrl {
  param(
    [string]$Value,
    [string]$Name
  )

  try {
    $uri = [System.Uri]$Value
  } catch {
    throw "$Name must be a valid URL"
  }

  if ($uri.Scheme -eq "https") {
    return
  }

  $isLocalhost = $uri.Scheme -eq "http" -and @("localhost", "127.0.0.1", "::1") -contains $uri.Host
  if ($AllowLocalhost -and $isLocalhost) {
    return
  }

  throw "$Name must use https for release builds"
}

function Read-PropertiesFile {
  param([string]$PathValue)

  $props = @{}
  foreach ($rawLine in Get-Content $PathValue) {
    $line = $rawLine.Trim()
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
      continue
    }

    $eq = $line.IndexOf("=")
    if ($eq -lt 1) {
      continue
    }

    $key = $line.Substring(0, $eq).Trim()
    $value = $line.Substring($eq + 1).Trim()
    $props[$key] = $value
  }
  return $props
}

function Assert-KeyProperties {
  if (-not (Test-Path $KeyProperties)) {
    throw "Missing forntend\android\key.properties. Copy key.properties.example and set real signing values."
  }

  $props = Read-PropertiesFile -PathValue $KeyProperties
  foreach ($key in @("storeFile", "storePassword", "keyAlias", "keyPassword")) {
    $value = [string]$props[$key]
    if ([string]::IsNullOrWhiteSpace($value) -or $value.ToUpperInvariant().Contains("CHANGE_ME")) {
      throw "Android signing $key must be configured with a real value"
    }
  }
}

function Assert-GeneratedFilesClean {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) {
    Write-Host "git not found; skipping generated-file diff check" -ForegroundColor Yellow
    return
  }

  Push-Location $ProjectRoot
  try {
    & git diff --exit-code -- `
      "forntend/pubspec.lock" `
      "forntend/linux/flutter/generated_plugin_registrant.cc" `
      "forntend/linux/flutter/generated_plugins.cmake" `
      "forntend/macos/Flutter/GeneratedPluginRegistrant.swift" `
      "forntend/windows/flutter/generated_plugin_registrant.cc" `
      "forntend/windows/flutter/generated_plugins.cmake"
    if ($LASTEXITCODE -ne 0) {
      throw "Generated Flutter files or pubspec.lock have uncommitted changes. Run flutter pub get and commit generated files before release."
    }
  } finally {
    Pop-Location
  }
}

if (-not [string]::IsNullOrWhiteSpace($ApiBase)) {
  Test-ReleaseUrl -Value $ApiBase -Name "ApiBase"
}
if (-not [string]::IsNullOrWhiteSpace($RegistryBase)) {
  Test-ReleaseUrl -Value $RegistryBase -Name "RegistryBase"
}

if (-not (Test-Path $PubspecLock)) {
  throw "Missing forntend\pubspec.lock. Run flutter pub get before release."
}

if (-not $WindowsOnly) {
  Assert-KeyProperties
}
Assert-GeneratedFilesClean

Write-Host "frontend-release-preflight: PASS"
