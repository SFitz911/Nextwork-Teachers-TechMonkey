# Sync LongCat-Video directory to VAST instance
# Usage: .\scripts\sync_longcat_to_vast.ps1

$ErrorActionPreference = "Stop"

# Load SSH config
$SSH_CONFIG = @{
    Host = $env:VAST_SSH_HOST
    User = $env:VAST_SSH_USER
    Port = $env:VAST_SSH_PORT
}

if (-not $SSH_CONFIG.Host) {
    Write-Host "❌ VAST_SSH_HOST not set. Please set environment variables:" -ForegroundColor Red
    Write-Host "   `$env:VAST_SSH_HOST = 'your-vast-instance.com'" -ForegroundColor Yellow
    Write-Host "   `$env:VAST_SSH_USER = 'root'" -ForegroundColor Yellow
    Write-Host "   `$env:VAST_SSH_PORT = '22'" -ForegroundColor Yellow
    exit 1
}

$LOCAL_LONGCAT_DIR = "LongCat-Video"
$REMOTE_PROJECT_DIR = "~/Nextwork-Teachers-TechMonkey"
$REMOTE_LONGCAT_DIR = "$REMOTE_PROJECT_DIR/LongCat-Video"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Syncing LongCat-Video to VAST Instance" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if local directory exists
if (-not (Test-Path $LOCAL_LONGCAT_DIR)) {
    Write-Host "❌ LongCat-Video directory not found locally" -ForegroundColor Red
    Write-Host "   Please clone it first:" -ForegroundColor Yellow
    Write-Host "   git clone --single-branch --branch main https://github.com/meituan-longcat/LongCat-Video" -ForegroundColor Yellow
    exit 1
}

Write-Host "📦 Syncing LongCat-Video directory..." -ForegroundColor Yellow
Write-Host "   From: $LOCAL_LONGCAT_DIR" -ForegroundColor Gray
Write-Host "   To: $SSH_CONFIG.User@$SSH_CONFIG.Host:$REMOTE_LONGCAT_DIR" -ForegroundColor Gray
Write-Host ""

# Use rsync via SSH
$rsyncArgs = @(
    "-avz",
    "--progress",
    "--exclude", ".git",
    "--exclude", "__pycache__",
    "--exclude", "*.pyc",
    "--exclude", "weights/",  # Exclude weights (too large, download separately)
    "--exclude", "outputs*/",
    "-e", "ssh -p $($SSH_CONFIG.Port)",
    "$LOCAL_LONGCAT_DIR/",
    "$($SSH_CONFIG.User)@$($SSH_CONFIG.Host):$REMOTE_LONGCAT_DIR/"
)

try {
    & rsync @rsyncArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Sync complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps on VAST:" -ForegroundColor Cyan
        Write-Host "  1. cd $REMOTE_PROJECT_DIR" -ForegroundColor Yellow
        Write-Host "  2. bash scripts/deploy_longcat_video.sh" -ForegroundColor Yellow
    } else {
        Write-Host "❌ Sync failed (exit code: $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Error during sync: $_" -ForegroundColor Red
    exit 1
}
