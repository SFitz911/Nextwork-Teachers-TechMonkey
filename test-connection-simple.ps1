# Simple connection test - just try to connect
# Usage: .\test-connection-simple.ps1

param(
    [string]$Port = "41428",
    [string]$IP = "50.217.254.161"
)

Write-Host "Testing connection to ${IP}:${Port}..." -ForegroundColor Yellow
Write-Host ""

# Try direct connection
ssh -o ConnectTimeout=15 -p $Port root@$IP "echo '✅ Connected!'; hostname; pwd"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Connection successful!" -ForegroundColor Green
    Write-Host "You can now run: ssh -p $Port root@$IP" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "❌ Connection failed. Possible reasons:" -ForegroundColor Red
    Write-Host "  1. SSH key not added to instance yet" -ForegroundColor Yellow
    Write-Host "  2. Instance still initializing (wait 1-2 minutes)" -ForegroundColor Yellow
    Write-Host "  3. Firewall blocking connection" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Try again in a minute, or check Vast.ai dashboard for SSH key settings" -ForegroundColor Cyan
}
