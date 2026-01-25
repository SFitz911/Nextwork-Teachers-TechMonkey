# Connect to VAST instance terminal (no port forwarding)
# Usage: .\connect-vast-terminal.ps1
#
# This connects you directly to the VAST terminal so you can run commands.
# For port forwarding (to access services from browser), use connect-vast.ps1 instead.

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Connecting to VAST Terminal" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will connect you to the VAST instance terminal." -ForegroundColor Yellow
Write-Host "Once connected, you can run commands like:" -ForegroundColor White
Write-Host "  cd ~/Nextwork-Teachers-TechMonkey" -ForegroundColor Gray
Write-Host "  bash scripts/start_all_services.sh" -ForegroundColor Gray
Write-Host ""
Write-Host "Connecting..." -ForegroundColor Green
Write-Host ""

# Connect via gateway (most reliable)
# Direct: ssh -p 28259 root@24.124.32.70
# Proxy: ssh -p 24285 root@ssh4.vast.ai
ssh -p 24285 root@ssh4.vast.ai

Write-Host ""
Write-Host "Connection closed." -ForegroundColor Yellow
