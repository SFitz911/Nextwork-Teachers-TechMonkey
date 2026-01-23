# Sync LongCat-Video directory to VAST instance
# Usage: .\scripts\sync_longcat_to_vast.ps1 [direct|gateway]

param(
    [string]$Method = "gateway"
)

$ErrorActionPreference = "Stop"

# Use same SSH config as connect-vast.ps1
if ($Method -eq "direct") {
    $SSH_CONFIG = @{
        Host = "50.217.254.161"
        User = "root"
        Port = "41428"
    }
} else {
    $SSH_CONFIG = @{
        Host = "ssh7.vast.ai"
        User = "root"
        Port = "35859"
    }
}

# Allow override via environment variables
if ($env:VAST_SSH_HOST) {
    $SSH_CONFIG.Host = $env:VAST_SSH_HOST
}
if ($env:VAST_SSH_USER) {
    $SSH_CONFIG.User = $env:VAST_SSH_USER
}
if ($env:VAST_SSH_PORT) {
    $SSH_CONFIG.Port = $env:VAST_SSH_PORT
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
Write-Host "   Method: $Method" -ForegroundColor Gray
Write-Host "   From: $LOCAL_LONGCAT_DIR" -ForegroundColor Gray
Write-Host "   To: $($SSH_CONFIG.User)@$($SSH_CONFIG.Host):$REMOTE_LONGCAT_DIR" -ForegroundColor Gray
Write-Host ""

# Check if rsync is available (Windows may not have it)
$rsyncAvailable = Get-Command rsync -ErrorAction SilentlyContinue

if (-not $rsyncAvailable) {
    Write-Host "⚠️  rsync not found. Using SCP instead (slower but works)..." -ForegroundColor Yellow
    Write-Host ""
    
    # Use SCP instead
    $scpCmd = "scp -r -P $($SSH_CONFIG.Port) `"$LOCAL_LONGCAT_DIR\*`" $($SSH_CONFIG.User)@$($SSH_CONFIG.Host):$REMOTE_LONGCAT_DIR/"
    Write-Host "Running: $scpCmd" -ForegroundColor Gray
    & powershell -Command $scpCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Sync complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps on VAST:" -ForegroundColor Cyan
        Write-Host "  1. cd $REMOTE_PROJECT_DIR" -ForegroundColor Yellow
        Write-Host "  2. bash scripts/deploy_longcat_video.sh" -ForegroundColor Yellow
    } else {
        Write-Host "❌ Sync failed (exit code: $LASTEXITCODE)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Alternative: Clone directly on VAST:" -ForegroundColor Yellow
        Write-Host "  ssh -p $($SSH_CONFIG.Port) $($SSH_CONFIG.User)@$($SSH_CONFIG.Host)" -ForegroundColor White
        Write-Host "  cd ~/Nextwork-Teachers-TechMonkey" -ForegroundColor White
        Write-Host "  git clone --single-branch --branch main https://github.com/meituan-longcat/LongCat-Video" -ForegroundColor White
        exit 1
    }
    exit 0
}

# Use rsync via SSH
$rsyncArgs = @(
    "-avz",
    "--progress",
    "--exclude", ".git",
    "--exclude", "__pycache__",
    "--exclude", "*.pyc",
    "--exclude", "weights/",  # Exclude weights (too large, download separately)
    "--exclude", "outputs*/",
    "-e", "ssh -p $($SSH_CONFIG.Port) -o StrictHostKeyChecking=no",
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
