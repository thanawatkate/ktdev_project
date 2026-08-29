<#
.SYNOPSIS
  Build SACCM Windows release และสร้างไฟล์ติดตั้ง .exe (Inno Setup)

.DESCRIPTION
  1) flutter build windows --release (obfuscate + integrity manifest)
  2) คัดลอกไฟล์ไป staging
  3) รัน iscc → release\out\installer\saccm-<version>-setup.exe

  ต้องติดตั้ง Inno Setup 6+ ก่อน:
    winget install JRSoftware.InnoSetup

.EXAMPLE
  # ดับเบิลคลิก build-installer.bat หรือ:
  pwsh release\windows\build-installer.ps1

.EXAMPLE
  pwsh release\windows\build-installer.ps1 `
    -ApiBase "https://api.example.com" `
    -RegistryBase "https://api.example.com"
#>
[CmdletBinding()]
param(
    [string]$ApiBase = "",
    [string]$RegistryBase = "",
    [string]$Version = "",
    [string]$ProjectRoot = "",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

$Frontend = Join-Path $ProjectRoot "forntend"
$PubspecPath = Join-Path $Frontend "pubspec.yaml"
$IssPath = Join-Path $PSScriptRoot "saccm-setup.iss"
$StagingDir = Join-Path $ProjectRoot "release\out\windows-staging"
$InstallerOut = Join-Path $ProjectRoot "release\out\installer"
$AppIcon = Join-Path $Frontend "windows\runner\resources\app_icon.ico"

function Get-PubspecVersion {
    if (-not (Test-Path $PubspecPath)) {
        throw "pubspec.yaml not found: $PubspecPath"
    }
    foreach ($line in Get-Content -LiteralPath $PubspecPath) {
        if ($line -match '^\s*version:\s*(.+)$') {
            return $Matches[1].Trim()
        }
    }
    throw "version not found in pubspec.yaml"
}

function ConvertTo-EndpointBase([string]$Value, [string]$Suffix) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    $v = $Value.Trim().TrimEnd("/")
    if ($v.EndsWith($Suffix)) { return "$v/" }
    return "$v$Suffix/"
}

function Find-InnoSetupCompiler {
    $cmd = Get-Command iscc -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-PubspecVersion
}

$BuildName = $Version.Split('+')[0]
$BuildNumber = if ($Version.Contains("+")) { $Version.Split('+')[1] } else { "1" }

$ApiBase = ConvertTo-EndpointBase $ApiBase "/saccapi"
$RegistryBase = ConvertTo-EndpointBase $RegistryBase "/registryapi"

Write-Host "== SACCM Windows Installer Build ==" -ForegroundColor Cyan
Write-Host "Version : $Version (name=$BuildName, number=$BuildNumber)"
if ($ApiBase) { Write-Host "API     : $ApiBase" }
if ($RegistryBase) { Write-Host "Registry: $RegistryBase" }
Write-Host "Staging : $StagingDir"
Write-Host "Output  : $InstallerOut"
Write-Host ""

Push-Location $Frontend
try {
    if (-not $SkipBuild) {
        Write-Host "-- Flutter Windows release --" -ForegroundColor Yellow
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

        $symbolsDir = Join-Path $Frontend "build\windows-symbols"
        New-Item -ItemType Directory -Force -Path $symbolsDir | Out-Null

        $buildArgs = @(
            "build", "windows",
            "--release",
            "--obfuscate",
            "--split-debug-info=$symbolsDir",
            "--build-name=$BuildName",
            "--build-number=$BuildNumber"
        )
        if ($ApiBase) { $buildArgs += "--dart-define=SACC_API_BASE=$ApiBase" }
        if ($RegistryBase) { $buildArgs += "--dart-define=SACC_REGISTRY_BASE=$RegistryBase" }

        & flutter @buildArgs
        if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }
    }

    $WinBuild = Join-Path $Frontend "build\windows\x64\runner\Release"
    if (-not (Test-Path (Join-Path $WinBuild "saccm.exe"))) {
        throw "saccm.exe not found in $WinBuild - run build first or remove -SkipBuild"
    }

    Write-Host "-- Stage release files --" -ForegroundColor Yellow
    if (Test-Path $StagingDir) {
        Remove-Item -LiteralPath $StagingDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $StagingDir | Out-Null
    Copy-Item -Path (Join-Path $WinBuild "*") -Destination $StagingDir -Recurse -Force

    Write-Host "-- Integrity manifest --" -ForegroundColor Yellow
    & (Join-Path $Frontend "tool\new_integrity_manifest.ps1") -ReleaseDir $StagingDir | Out-Null
}
finally {
    Pop-Location
}

$iscc = Find-InnoSetupCompiler
if (-not $iscc) {
    Write-Host ""
    Write-Host "Inno Setup (iscc) not found." -ForegroundColor Red
    Write-Host "Install: winget install JRSoftware.InnoSetup" -ForegroundColor Yellow
    Write-Host "App bundle ready at: $StagingDir" -ForegroundColor Yellow
    Write-Host "Run saccm.exe from that folder, or install Inno Setup and rerun with -SkipBuild" -ForegroundColor Yellow
    exit 1
}

Write-Host "-- Inno Setup --" -ForegroundColor Yellow
& (Join-Path $ProjectRoot "release\windows\ensure-vcredist.ps1")
New-Item -ItemType Directory -Force -Path $InstallerOut | Out-Null

$isccArgs = @(
    $IssPath,
    "/DMyAppVersion=$BuildName",
    "/DBuildOutput=$StagingDir"
)
if (Test-Path $AppIcon) {
    $isccArgs += "/DMyAppIcon=$AppIcon"
}

& $iscc @isccArgs
if ($LASTEXITCODE -ne 0) { throw "iscc failed (exit $LASTEXITCODE)" }

$setupFile = Join-Path $InstallerOut "saccm-$BuildName-setup.exe"
Write-Host ""
Write-Host "Done" -ForegroundColor Green
Write-Host "  Installer : $setupFile"
Write-Host "  Staging   : $StagingDir"

if (Test-Path $setupFile) {
    $explorerArg = '/select,' + [char]34 + $setupFile + [char]34
    Start-Process explorer.exe $explorerArg
}
