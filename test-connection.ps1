# Test VAST Connection
# Usage: .\test-connection.ps1 [-Port PORT] [-IP IP_ADDRESS]

param(
    [string]$Port = "40257",
    [string]$IP = "60.217.254.161"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  VAST Instance Connection Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Testing connection to VAST instance..." -ForegroundColor Yellow
Write-Host "IP: $IP" -ForegroundColor White
Write-Host "Port: $Port" -ForegroundColor White
Write-Host ""

# Test 1: Direct connection
Write-Host "Test 1: Direct connection to ${IP}:${Port}..." -ForegroundColor Yellow
$result1 = ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p $Port root@$IP "echo 'Connection successful!'" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Direct connection works!" -ForegroundColor Green
    Write-Host "You can connect using: ssh -p $Port root@$IP" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "❌ Direct connection failed" -ForegroundColor Red
    Write-Host "Error: $result1" -ForegroundColor Red
    Write-Host ""
}

# Test 2: SSH Gateway connection
Write-Host "Test 2: SSH Gateway connection (ssh1.vast.ai:29889)..." -ForegroundColor Yellow
$result2 = ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p 29889 root@ssh1.vast.ai "echo 'Connection successful!'" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Gateway connection works!" -ForegroundColor Green
    Write-Host "You can connect using: ssh -p 29889 root@ssh1.vast.ai" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Note: Update connect-vast.ps1 to use gateway method" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "❌ Gateway connection also failed" -ForegroundColor Red
    Write-Host "Error: $result2" -ForegroundColor Red
    Write-Host ""
}

# If both failed
Write-Host "========================================" -ForegroundColor Red
Write-Host "  Both connection methods failed!" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""
Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
Write-Host "1. Check Vast.ai dashboard to verify instance is running" -ForegroundColor White
Write-Host "2. Verify the IP address and port in the dashboard" -ForegroundColor White
Write-Host "3. Check if you need to add your SSH key to the instance" -ForegroundColor White
Write-Host "4. Try connecting with password first:" -ForegroundColor White
Write-Host "   ssh -p $Port root@$IP" -ForegroundColor Cyan
Write-Host ""
Write-Host "See docs/TROUBLESHOOT_SSH.md for detailed help" -ForegroundColor Yellow
