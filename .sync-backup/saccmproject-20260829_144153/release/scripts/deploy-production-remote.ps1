# Sync repo to a Linux VPS and run deploy-production-server.sh over SSH.
param(
    [Parameter(Mandatory = $true)]
    [string]$SshTarget,

    [string]$RemoteRepoPath = "/var/www/saccm",
    [string]$PublicHost = "ktdevelop.com",
    [string]$SshKeyPath = "",
    [switch]$SkipRsync,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$DeployScript = "release/scripts/deploy-production-server.sh"

function Get-SshArgs {
    $args = @("-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new")
    if (-not [string]::IsNullOrWhiteSpace($SshKeyPath)) {
        $args += @("-i", $SshKeyPath)
    }
    return $args
}

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    throw "OpenSSH client required"
}

$sshBase = Get-SshArgs

if (-not $SkipRsync) {
    if (-not (Get-Command rsync -ErrorAction SilentlyContinue)) {
        Write-Warning "rsync not found; use -SkipRsync and deploy from git pull on server"
    }
    else {
        $excludes = @(
            "--exclude", ".git",
            "--exclude", "node_modules",
            "--exclude", "forntend/build",
            "--exclude", "forntend/.dart_tool",
            "--exclude", "release/out",
            "--exclude", "release/local-production",
            "--exclude", "release/backups",
            "--exclude", "backend/.env",
            "--exclude", "registry-backend/.env"
        )
        $rsyncArgs = @("-avz", "--delete") + $excludes + @(
            "$ProjectRoot/",
            "${SshTarget}:${RemoteRepoPath}/"
        )
        if ($DryRun) { $rsyncArgs = @("-avzn") + $excludes + @("$ProjectRoot/", "${SshTarget}:${RemoteRepoPath}/") }
        Write-Host "rsync -> $RemoteRepoPath" -ForegroundColor Cyan
        & rsync @rsyncArgs
        if ($LASTEXITCODE -ne 0) { throw "rsync failed" }
    }
}

$remoteCmd = "cd '$RemoteRepoPath' && chmod +x $DeployScript && PUBLIC_HOST='$PublicHost' bash $DeployScript"
if ($DryRun) {
    Write-Host "DRY RUN remote: $remoteCmd"
    exit 0
}

Write-Host "SSH deploy on $SshTarget" -ForegroundColor Cyan
& ssh @sshBase $SshTarget $remoteCmd
if ($LASTEXITCODE -ne 0) { throw "remote deploy failed" }

Write-Host "`nVerify HTTPS endpoints:" -ForegroundColor Green
& node (Join-Path $ScriptDir "check-deployed-endpoints.js") `
    --backend-base "https://$PublicHost/saccapi" `
    --registry-base "https://$PublicHost/registryapi" `
    --origin "https://$PublicHost"
