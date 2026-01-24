# Quick SSH connection test script
# This helps you find the right connection details

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "SSH Connection Test" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will help you test SSH connections." -ForegroundColor Yellow
Write-Host ""
Write-Host "STEP 1: Get connection details from Vast.ai dashboard" -ForegroundColor Green
Write-Host "  - Go to your instance in Vast.ai dashboard" -ForegroundColor White
Write-Host "  - Look for 'Direct ssh connect' or 'Proxy ssh connect'" -ForegroundColor White
Write-Host "  - Copy the SSH command shown there" -ForegroundColor White
Write-Host ""
Write-Host "STEP 2: Test connection manually" -ForegroundColor Green
Write-Host ""
Write-Host "Common connection formats:" -ForegroundColor Yellow
Write-Host "  Direct: ssh -p PORT root@IP_ADDRESS" -ForegroundColor White
Write-Host "  Gateway: ssh -p PORT root@sshX.vast.ai" -ForegroundColor White
Write-Host ""
Write-Host "Example commands to try:" -ForegroundColor Yellow
Write-Host "  ssh -p 28008 root@24.124.32.70" -ForegroundColor Cyan
Write-Host "  ssh -p 28008 root@ssh1.vast.ai" -ForegroundColor Cyan
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Prompt for connection details
$port = Read-Host "Enter SSH port (from Vast.ai dashboard)"
$hostname = Read-Host "Enter hostname (IP or sshX.vast.ai)"

Write-Host ""
Write-Host "Testing connection to $hostname on port $port..." -ForegroundColor Yellow
Write-Host ""

# Test connection
$testCmd = "ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p $port root@$hostname 'echo Connection successful!' 2>&1"
$result = & powershell -Command $testCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Connection successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now connect with:" -ForegroundColor Green
    Write-Host "  ssh -p $port root@$hostname" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or update connect-vast.ps1 with:" -ForegroundColor Yellow
    Write-Host "  Port: $port" -ForegroundColor White
    Write-Host "  Host: $hostname" -ForegroundColor White
} else {
    Write-Host "❌ Connection failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host $result -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Make sure SSH key is added to instance (via Vast.ai dashboard)" -ForegroundColor White
    Write-Host "  2. Check that instance is running" -ForegroundColor White
    Write-Host "  3. Verify port and hostname are correct" -ForegroundColor White
    Write-Host "  4. Try connecting with password first:" -ForegroundColor White
    Write-Host "     ssh -p $port root@$hostname" -ForegroundColor Cyan
}

Write-Host ""
