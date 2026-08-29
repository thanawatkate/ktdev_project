param(
  [Parameter(Mandatory = $true)]
  [string]$Database,

  [string]$HostName = "127.0.0.1",
  [int]$Port = 3306,
  [string]$User = "saccm_app",
  [string]$OutDir = "..\backups",
  [switch]$NoData
)

$ErrorActionPreference = 'Stop'

function Resolve-OutputDirectory {
  param([string]$PathValue)
  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return $PathValue
  }
  $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
  return Join-Path $scriptDir $PathValue
}

$dumpTool = Get-Command mysqldump -ErrorAction SilentlyContinue
if (-not $dumpTool) {
  throw "mysqldump not found in PATH. Install MySQL/MariaDB client tools before running backup."
}

$resolvedOutDir = Resolve-OutputDirectory -PathValue $OutDir
New-Item -ItemType Directory -Force -Path $resolvedOutDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$safeDbName = $Database -replace '[^A-Za-z0-9_.-]', '_'
$backupFile = Join-Path $resolvedOutDir "$safeDbName-$timestamp.sql"

$password = Read-Host "MySQL password for $User@$HostName" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)

try {
  $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  $env:MYSQL_PWD = $plainPassword

  $dumpArgs = @(
    "--host=$HostName",
    "--port=$Port",
    "--user=$User",
    "--single-transaction",
    "--routines",
    "--triggers",
    "--events",
    "--default-character-set=utf8mb4"
  )
  if ($NoData) {
    $dumpArgs += "--no-data"
  }
  $dumpArgs += $Database

  & $dumpTool.Source @dumpArgs | Out-File -FilePath $backupFile -Encoding utf8
  if ($LASTEXITCODE -ne 0) {
    throw "mysqldump failed with exit code $LASTEXITCODE"
  }

  Write-Host "Backup written to $backupFile"
} finally {
  Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
  if ($bstr -ne [IntPtr]::Zero) {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}
