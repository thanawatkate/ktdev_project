# Generate a Registry license code, offline by default or online when requested.
param(
    [Parameter(Mandatory = $true)]
    [string]$SchoolName,

    [ValidateSet('offline', 'online')]
    [string]$Tier = 'offline',

    [int]$Devices = 3,
    [int]$Days = 365,
    [string]$Note = "",
    [string]$By = ""
)

$ErrorActionPreference = "Stop"
$Registry = Resolve-Path (Join-Path $PSScriptRoot "..\..\registry-backend")

Push-Location $Registry
try {
    $args = @("scripts/keygen.js", "--name", $SchoolName, "--devices", "$Devices", "--days", "$Days")
    if ($Tier -eq 'online') { $args += "--online" }
    if ($Note) { $args += @("--note", $Note) }
    if ($By) { $args += @("--by", $By) }
    node @args
}
finally {
    Pop-Location
}
