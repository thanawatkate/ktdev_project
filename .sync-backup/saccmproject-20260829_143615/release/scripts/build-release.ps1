# Build Windows and Android distribution artifacts.
param(
    [Parameter(Mandatory = $true)]
    [string]$SchoolSlug,

    [string]$ApiBase = "",
    [string]$RegistryBase = "",
    [string]$Version = "1.0.0+1",

    [string]$ProjectRoot = "",

    [switch]$BuildInstaller,
    [switch]$WindowsOnly
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

$Frontend = Join-Path $ProjectRoot "forntend"
$OutRoot = Join-Path $ProjectRoot "release\out\$SchoolSlug"
# Obfuscation symbol maps ต้องเก็บไว้ debug crash แต่ "ห้าม" แจกไปกับชุดติดตั้ง
# จึงวางไว้นอก $OutRoot (ใต้ release\symbols\<school>\<version>)
$SymbolsRoot = Join-Path $ProjectRoot "release\symbols\$SchoolSlug\$Version"
$WinSymbols = Join-Path $SymbolsRoot "windows"
$AndroidSymbols = Join-Path $SymbolsRoot "android"
New-Item -ItemType Directory -Force -Path $WinSymbols, $AndroidSymbols | Out-Null

function ConvertTo-EndpointBase([string]$Value, [string]$Suffix) {
    $v = $Value.Trim().TrimEnd("/")
    if ($v.EndsWith($Suffix)) { return "$v/" }
    return "$v$Suffix/"
}

function Get-AppDefaultEndpoint {
    param(
        [string]$EnvName,
        [string]$ConfigDartPath
    )

    $content = Get-Content -LiteralPath $ConfigDartPath -Raw
    $pattern = "'$EnvName',\s*defaultValue:\s*'([^']+)'"
    if ($content -match $pattern) {
        return $Matches[1]
    }
    throw "defaultValue for $EnvName not found in config.dart"
}

function Get-FlutterDartDefines {
    param([string]$ApiBaseValue, [string]$RegistryBaseValue)

    $defines = @()
    if (-not [string]::IsNullOrWhiteSpace($ApiBaseValue)) {
        $defines += "--dart-define=SACC_API_BASE=$ApiBaseValue"
    }
    if (-not [string]::IsNullOrWhiteSpace($RegistryBaseValue)) {
        $defines += "--dart-define=SACC_REGISTRY_BASE=$RegistryBaseValue"
    }
    return $defines
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

function New-DistributionZip {
    param(
        [string]$SourceDir,
        [string]$ZipPath
    )

    if (Test-Path $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }
    $parent = Split-Path $ZipPath -Parent
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Compress-Archive -Path (Join-Path $SourceDir "*") -DestinationPath $ZipPath -CompressionLevel Optimal
}

function Get-RelativePathCompat([string]$From, [string]$To) {
    $fromFull = [System.IO.Path]::GetFullPath($From.TrimEnd('\', '/'))
    $toFull = [System.IO.Path]::GetFullPath($To)
    if (-not $fromFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $fromFull += [System.IO.Path]::DirectorySeparatorChar
    }
    if ($toFull.StartsWith($fromFull, [StringComparison]::OrdinalIgnoreCase)) {
        return $toFull.Substring($fromFull.Length)
    }
    throw "Cannot make path relative: $To from $From"
}

function New-ReleaseManifest([string]$RootPath, [string]$SchoolSlugValue, [string]$VersionValue, [string]$ApiBaseValue, [string]$RegistryBaseValue) {
    $files = Get-ChildItem -Path $RootPath -File -Recurse |
        Where-Object { $_.Name -ne "manifest.json" -and $_.Name -ne "SHA256SUMS.txt" } |
        Sort-Object FullName |
        ForEach-Object {
            $relative = (Get-RelativePathCompat -From $RootPath -To $_.FullName).Replace("\", "/")
            $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256
            [PSCustomObject]@{
                path = $relative
                bytes = $_.Length
                sha256 = $hash.Hash.ToLowerInvariant()
            }
        }

    $manifest = [PSCustomObject]@{
        generated_at = (Get-Date).ToUniversalTime().ToString("o")
        school_slug = $SchoolSlugValue
        version = $VersionValue
        api_base = $ApiBaseValue
        registry_base = $RegistryBaseValue
        files = $files
    }

    $manifestPath = Join-Path $RootPath "manifest.json"
    $sumsPath = Join-Path $RootPath "SHA256SUMS.txt"
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8
    $files | ForEach-Object { "$($_.sha256)  $($_.path)" } | Set-Content -Path $sumsPath -Encoding ASCII
}

$ConfigDart = Join-Path $Frontend "lib\config.dart"
if (-not [string]::IsNullOrWhiteSpace($ApiBase)) {
    $ApiBase = ConvertTo-EndpointBase $ApiBase "/saccapi"
} else {
    $ApiBase = ""
}
if (-not [string]::IsNullOrWhiteSpace($RegistryBase)) {
    $RegistryBase = ConvertTo-EndpointBase $RegistryBase "/registryapi"
} else {
    $RegistryBase = ""
}

$ManifestApiBase = if ($ApiBase) { $ApiBase } else { Get-AppDefaultEndpoint "SACC_API_BASE" $ConfigDart }
$ManifestRegistryBase = if ($RegistryBase) { $RegistryBase } else { Get-AppDefaultEndpoint "SACC_REGISTRY_BASE" $ConfigDart }
$BuildName = $Version.Split('+')[0]
$BuildNumber = if ($Version.Contains("+")) { $Version.Split('+')[1] } else { "1" }

$preflightArgs = @{
    ProjectRoot = $ProjectRoot
}
if ($ApiBase) { $preflightArgs.ApiBase = $ApiBase }
if ($RegistryBase) { $preflightArgs.RegistryBase = $RegistryBase }
if ($WindowsOnly) { $preflightArgs.WindowsOnly = $true }
& (Join-Path $PSScriptRoot "frontend-release-preflight.ps1") @preflightArgs

$dartDefines = Get-FlutterDartDefines -ApiBaseValue $ApiBase -RegistryBaseValue $RegistryBase

Write-Host "== SACCM Release Build ==" -ForegroundColor Cyan
Write-Host "School : $SchoolSlug"
if ($ApiBase) {
    Write-Host "API    : $ApiBase (build override)"
} else {
    Write-Host "API    : (app default - offline-first, configurable in app settings later)"
}
if ($RegistryBase) {
    Write-Host "Registry: $RegistryBase (build override)"
} else {
    Write-Host "Registry: (app default from config.dart)"
}
Write-Host "Out    : $OutRoot"

Push-Location $Frontend
try {
    flutter pub get

    Write-Host "`n-- Windows --" -ForegroundColor Yellow
    $winBuildArgs = @(
        "build", "windows",
        "--release",
        "--obfuscate",
        "--split-debug-info=$WinSymbols",
        "--build-name=$BuildName",
        "--build-number=$BuildNumber"
    ) + $dartDefines
    & flutter @winBuildArgs
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }

    $WinBuild = Join-Path $Frontend "build\windows\x64\runner\Release"
    $WinOut = Join-Path $OutRoot "windows"
    New-Item -ItemType Directory -Force -Path $WinOut | Out-Null
    Copy-Item -Path (Join-Path $WinBuild "*") -Destination $WinOut -Recurse -Force

    # Code protection: create the signed (HMAC) integrity manifest next to
    # saccm.exe in $WinOut so it ships in the installer and AppGuard verifies
    # it at runtime.
    Write-Host "-- Integrity manifest --" -ForegroundColor Yellow
    & (Join-Path $Frontend "tool\new_integrity_manifest.ps1") -ReleaseDir $WinOut | Out-Null

    if (-not $WindowsOnly) {
        Write-Host "`n-- Android APK --" -ForegroundColor Yellow
        $apkBuildArgs = @(
            "build", "apk",
            "--release",
            "--obfuscate",
            "--split-debug-info=$AndroidSymbols",
            "--build-name=$BuildName",
            "--build-number=$BuildNumber"
        ) + $dartDefines
        & flutter @apkBuildArgs
        if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed" }

        $ApkSrc = Join-Path $Frontend "build\app\outputs\flutter-apk\app-release.apk"
        $ApkOut = Join-Path $OutRoot "android"
        New-Item -ItemType Directory -Force -Path $ApkOut | Out-Null
        Copy-Item $ApkSrc (Join-Path $ApkOut "saccm-$SchoolSlug-release.apk") -Force
    }

    # README for school operators.
    $readmeLines = @(
        "SACCM distribution ($SchoolSlug)",
        "================================",
        "",
        "Windows installer (recommended)",
        "-------------------------------",
        "1. Run installer\saccm-$BuildName-setup.exe",
        "2. Follow the setup wizard (Thai). Optional Desktop shortcut.",
        "3. Launch SACCM from Start Menu.",
        "",
        "Portable (no install)",
        "---------------------",
        "1. Open windows\ and run saccm.exe directly."
    )
    if (-not $WindowsOnly) {
        $readmeLines += ""
        $readmeLines += "Android"
        $readmeLines += "-------"
        $readmeLines += "1. Install android\saccm-$SchoolSlug-release.apk and allow trusted sideloading."
    }
    $readmeLines += ""
    $readmeLines += "License / sync"
    $readmeLines += "--------------"
    $readmeLines += "- Works offline immediately (90-day embedded trial)."
    $readmeLines += "- For online activation/sync: SACC-.... license code + API URL in app settings."
    $readmeLines += "- Default API: $ManifestApiBase"
    $readmeLines += ""
    Set-Content -Path (Join-Path $OutRoot "README.txt") -Value ($readmeLines -join "`n") -Encoding UTF8

    if ($BuildInstaller) {
        $iscc = Find-InnoSetupCompiler
        if (-not $iscc) {
            Write-Host "Inno Setup (iscc) not found. Skipping installer." -ForegroundColor Yellow
            Write-Host "Install: winget install JRSoftware.InnoSetup" -ForegroundColor Yellow
        } else {
            Write-Host "`n-- Inno Setup --" -ForegroundColor Yellow
            & (Join-Path $ProjectRoot "release\windows\ensure-vcredist.ps1")
            $iss = Join-Path $ProjectRoot "release\windows\saccm-setup.iss"
            $ver = $Version.Split('+')[0]
            $appIcon = Join-Path $Frontend "windows\runner\resources\app_icon.ico"
            $isccArgs = @($iss, "/DMyAppVersion=$ver", "/DBuildOutput=$WinOut")
            if (Test-Path $appIcon) { $isccArgs += "/DMyAppIcon=$appIcon" }
            & $iscc @isccArgs
            if ($LASTEXITCODE -ne 0) { throw "iscc failed (exit $LASTEXITCODE)" }

            $setupBuilt = Join-Path $ProjectRoot "release\out\installer\saccm-$ver-setup.exe"
            $setupOutDir = Join-Path $OutRoot "installer"
            New-Item -ItemType Directory -Force -Path $setupOutDir | Out-Null
            if (Test-Path $setupBuilt) {
                Copy-Item -LiteralPath $setupBuilt -Destination (Join-Path $setupOutDir "saccm-$ver-setup.exe") -Force
                Write-Host "Installer -> $setupOutDir" -ForegroundColor Green
            } else {
                throw "Installer not found after iscc: $setupBuilt"
            }
        }
    }

    # Regenerate manifest after installer copy (includes setup.exe checksums).
    New-ReleaseManifest `
        -RootPath $OutRoot `
        -SchoolSlugValue $SchoolSlug `
        -VersionValue $Version `
        -ApiBaseValue $ManifestApiBase `
        -RegistryBaseValue $ManifestRegistryBase

    if ($WindowsOnly) {
        $zipName = "saccm-$SchoolSlug-$BuildName-windows.zip"
        if ($BuildInstaller -and (Test-Path (Join-Path $OutRoot "installer"))) {
            $zipName = "saccm-$SchoolSlug-$BuildName-windows-setup.zip"
        }
        $zipPath = Join-Path $ProjectRoot "release\out\$zipName"
        Write-Host "`n-- Distribution ZIP --" -ForegroundColor Yellow
        New-DistributionZip -SourceDir $OutRoot -ZipPath $zipPath
        $zipSizeMb = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
        Write-Host "ZIP -> $zipPath ($zipSizeMb MB)" -ForegroundColor Green
    }

    Write-Host "`nDone -> $OutRoot" -ForegroundColor Green
}
finally {
    Pop-Location
}
