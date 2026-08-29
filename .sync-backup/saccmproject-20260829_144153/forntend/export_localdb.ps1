param(
    [string]$DbName = "saccm.db",
    [string]$SourcePath = "",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

function Resolve-DbPath {
    param(
        [string]$DbName,
        [string]$SourcePath
    )

    if (-not [string]::IsNullOrWhiteSpace($SourcePath)) {
        if (Test-Path -LiteralPath $SourcePath) {
            return (Resolve-Path -LiteralPath $SourcePath).Path
        }
        throw "Database file not found at SourcePath: $SourcePath"
    }

    $projectRoot = $PSScriptRoot
    $candidatePaths = @(
        (Join-Path $projectRoot ".dart_tool\sqflite_common_ffi\databases\$DbName"),
        (Join-Path $projectRoot "build\windows\x64\runner\Debug\data\flutter_assets\$DbName")
    )

    foreach ($candidate in $candidatePaths) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $found = Get-ChildItem -Path $projectRoot -Recurse -File -Filter $DbName -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -ne $found) {
        return $found.FullName
    }

    throw "Database file $DbName not found in project."
}

try {
    $dbPath = Resolve-DbPath -DbName $DbName -SourcePath $SourcePath

    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        $OutputDir = Join-Path $PSScriptRoot "db-backups"
    }

    if (-not (Test-Path -LiteralPath $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($DbName)
    if ([string]::IsNullOrWhiteSpace($baseName)) {
        $baseName = "localdb"
    }
    $targetFile = Join-Path $OutputDir "${baseName}_$timestamp.db"

    Copy-Item -LiteralPath $dbPath -Destination $targetFile -Force

    Write-Host "Local DB export completed." -ForegroundColor Green
    Write-Host "Source : $dbPath"
    Write-Host "Backup : $targetFile"
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
