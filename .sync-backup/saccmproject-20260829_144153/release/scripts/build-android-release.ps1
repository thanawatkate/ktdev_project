# Build signed Android production APK (optional AAB) for school distribution.
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

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

$Frontend = Join-Path $ProjectRoot "forntend"
$OutRoot = Join-Path $ProjectRoot "release\out\$SchoolSlug"
$SymbolsRoot = Join-Path $ProjectRoot "release\symbols\$SchoolSlug\$Version"
$AndroidSymbols = Join-Path $SymbolsRoot "android"
New-Item -ItemType Directory -Force -Path $AndroidSymbols, (Join-Path $OutRoot "android") | Out-Null

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

function New-ReleaseManifest {
    param(
        [string]$RootPath,
        [string]$SchoolSlugValue,
        [string]$VersionValue,
        [string]$ApiBaseValue,
        [string]$RegistryBaseValue
    )

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
        platform = "android"
        api_base = $ApiBaseValue
        registry_base = $RegistryBaseValue
        files = $files
    }

    $manifestPath = Join-Path $RootPath "manifest.json"
    $sumsPath = Join-Path $RootPath "SHA256SUMS.txt"
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8
    $files | ForEach-Object { "$($_.sha256)  $($_.path)" } | Set-Content -Path $sumsPath -Encoding ASCII
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

function Copy-AndroidArtifact {
    param(
        [string]$SourcePath,
        [string]$DestPath
    )

    if (-not (Test-Path $SourcePath)) {
        throw "Build output not found: $SourcePath"
    }
    Copy-Item -LiteralPath $SourcePath -Destination $DestPath -Force
    return (Get-Item $DestPath).Length
}

$ConfigDart = Join-Path $Frontend "lib\config.dart"
if (-not [string]::IsNullOrWhiteSpace($ApiBase)) {
    $ApiBase = ConvertTo-EndpointBase $ApiBase "/saccapi"
}
if (-not [string]::IsNullOrWhiteSpace($RegistryBase)) {
    $RegistryBase = ConvertTo-EndpointBase $RegistryBase "/registryapi"
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
& (Join-Path $PSScriptRoot "frontend-release-preflight.ps1") @preflightArgs

$dartDefines = Get-FlutterDartDefines -ApiBaseValue $ApiBase -RegistryBaseValue $RegistryBase
$ApkOut = Join-Path $OutRoot "android"
$apkFileName = "saccm-$SchoolSlug-release.apk"

Write-Host "== SACCM Android Release Build ==" -ForegroundColor Cyan
Write-Host "School  : $SchoolSlug"
Write-Host "Version : $Version"
if ($ApiBase) {
    Write-Host "API     : $ApiBase (build override)"
} else {
    Write-Host "API     : (app default - offline-first)"
}
if ($RegistryBase) {
    Write-Host "Registry: $RegistryBase (build override)"
} else {
    Write-Host "Registry: (app default from config.dart)"
}
Write-Host "Out     : $ApkOut"

Push-Location $Frontend
try {
    flutter pub get

    $commonBuildArgs = @(
        "--release",
        "--obfuscate",
        "--split-debug-info=$AndroidSymbols",
        "--build-name=$BuildName",
        "--build-number=$BuildNumber"
    ) + $dartDefines

    Write-Host "`n-- Android APK --" -ForegroundColor Yellow
    $apkBuildArgs = @("build", "apk") + $commonBuildArgs
    if ($SplitPerAbi) {
        $apkBuildArgs += "--split-per-abi"
    }
    & flutter @apkBuildArgs
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed" }

    $builtApks = @()
    if ($SplitPerAbi) {
        $abiOutputs = Get-ChildItem -Path (Join-Path $Frontend "build\app\outputs\flutter-apk") -Filter "app-*-release.apk"
        foreach ($apk in $abiOutputs) {
            $abi = $apk.BaseName -replace '^app-', '' -replace '-release$', ''
            $destName = "saccm-$SchoolSlug-$abi-release.apk"
            $bytes = Copy-AndroidArtifact -SourcePath $apk.FullName -DestPath (Join-Path $ApkOut $destName)
            $builtApks += [PSCustomObject]@{ name = $destName; bytes = $bytes }
            Write-Host "APK -> $destName ($([math]::Round($bytes / 1MB, 1)) MB)" -ForegroundColor Green
        }
    }
    else {
        $apkSrc = Join-Path $Frontend "build\app\outputs\flutter-apk\app-release.apk"
        $bytes = Copy-AndroidArtifact -SourcePath $apkSrc -DestPath (Join-Path $ApkOut $apkFileName)
        $builtApks += [PSCustomObject]@{ name = $apkFileName; bytes = $bytes }
        Write-Host "APK -> $apkFileName ($([math]::Round($bytes / 1MB, 1)) MB)" -ForegroundColor Green
    }

    if ($BuildAppBundle) {
        Write-Host "`n-- Android App Bundle (AAB) --" -ForegroundColor Yellow
        $aabBuildArgs = @("build", "appbundle") + $commonBuildArgs
        & flutter @aabBuildArgs
        if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle failed" }

        $aabSrc = Join-Path $Frontend "build\app\outputs\bundle\release\app-release.aab"
        $aabName = "saccm-$SchoolSlug-release.aab"
        $aabBytes = Copy-AndroidArtifact -SourcePath $aabSrc -DestPath (Join-Path $ApkOut $aabName)
        Write-Host "AAB -> $aabName ($([math]::Round($aabBytes / 1MB, 1)) MB)" -ForegroundColor Green
    }

    $installHint = if ($SplitPerAbi) {
        "Install the APK matching the device CPU (arm64-v8a for most phones)."
    } else {
        "Install android\$apkFileName and allow trusted sideloading."
    }

    $readmeLines = @(
        "SACCM Android distribution ($SchoolSlug)",
        "======================================",
        "",
        "Install",
        "-------",
        "1. $installHint",
        "2. Works offline immediately (90-day embedded trial).",
        "3. For online activation/sync: SACC-.... license + API URL in app settings.",
        "4. Default API: $ManifestApiBase",
        ""
    )
    if ($BuildAppBundle) {
        $readmeLines += "App Bundle (AAB) is for Play Console upload only, not sideload install."
        $readmeLines += ""
    }
    Set-Content -Path (Join-Path $OutRoot "README.txt") -Value ($readmeLines -join "`n") -Encoding UTF8

    New-ReleaseManifest `
        -RootPath $OutRoot `
        -SchoolSlugValue $SchoolSlug `
        -VersionValue $Version `
        -ApiBaseValue $ManifestApiBase `
        -RegistryBaseValue $ManifestRegistryBase

    $zipPath = Join-Path $ProjectRoot "release\out\saccm-$SchoolSlug-$BuildName-android.zip"
    Write-Host "`n-- Distribution ZIP --" -ForegroundColor Yellow
    New-DistributionZip -SourceDir $OutRoot -ZipPath $zipPath
    $zipSizeMb = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
    Write-Host "ZIP -> $zipPath ($zipSizeMb MB)" -ForegroundColor Green
    Write-Host "Symbols -> $AndroidSymbols (do not distribute)" -ForegroundColor Yellow
    Write-Host "`nDone -> $OutRoot" -ForegroundColor Green
}
finally {
    Pop-Location
}
