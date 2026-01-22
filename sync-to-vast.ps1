# PowerShell script to commit, push, and sync to VAST instance
# Usage: .\sync-to-vast.ps1 [commit-message]

param(
    [string]$CommitMessage = "Update code"
)

$ErrorActionPreference = "Stop"

# Change to script directory (project root)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "Working directory: $ScriptDir" -ForegroundColor Gray
Write-Host ""

# VAST connection details
$VastPort = 41428
$VastHost = "50.217.254.161"
$VastUser = "root"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Syncing Code to VAST Instance" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check git status
Write-Host "Checking git status..." -ForegroundColor Yellow
$status = git status --porcelain

if ($status) {
    Write-Host "Found uncommitted changes:" -ForegroundColor Yellow
    Write-Host $status
    
    # Add all changes
    Write-Host ""
    Write-Host "Staging changes..." -ForegroundColor Yellow
    git add -A
    
    # Commit
    Write-Host "Committing changes..." -ForegroundColor Yellow
    git commit -m $CommitMessage
    
    # Push to GitHub
    Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
    git push origin main
    
    Write-Host "Changes committed and pushed!" -ForegroundColor Green
} else {
    Write-Host "No uncommitted changes" -ForegroundColor Green
}

Write-Host ""
Write-Host "Connecting to VAST instance..." -ForegroundColor Yellow

# Step 2: SSH into VAST and run sync script
$syncCommand = 'cd ~/Nextwork-Teachers-TechMonkey && git pull origin main && bash scripts/sync_and_restart.sh'

try {
    ssh -p $VastPort "${VastUser}@${VastHost}" $syncCommand
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "Sync complete!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Services should now be running with latest code:" -ForegroundColor Cyan
    Write-Host "  n8n:       http://localhost:5678" -ForegroundColor White
    Write-Host "  frontend:  http://localhost:8501" -ForegroundColor White
    Write-Host "  TTS:       http://localhost:8001" -ForegroundColor White
    Write-Host "  animation: http://localhost:8002" -ForegroundColor White
    Write-Host ""
    Write-Host "Make sure your SSH port forwarding is active!" -ForegroundColor Yellow
} catch {
    Write-Host ""
    Write-Host "Error syncing to VAST instance:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "You may need to:" -ForegroundColor Yellow
    Write-Host "  1. Check your SSH connection" -ForegroundColor Yellow
    Write-Host "  2. Manually run: ssh -p $VastPort ${VastUser}@${VastHost}" -ForegroundColor Yellow
    $manualCmd = "cd ~/Nextwork-Teachers-TechMonkey; git pull; bash scripts/sync_and_restart.sh"
    Write-Host "  3. Then run: $manualCmd" -ForegroundColor Yellow
}
