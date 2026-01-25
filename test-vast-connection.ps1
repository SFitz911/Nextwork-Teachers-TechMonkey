# Test VAST Connection with Detailed Diagnostics
# Usage: .\test-vast-connection.ps1

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VAST Connection Diagnostic Test" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$port = "30909"
$hostname = "ssh6.vast.ai"

Write-Host "Testing connection to: $hostname on port $port" -ForegroundColor Yellow
Write-Host ""

# Test 1: Basic connectivity
Write-Host "Test 1: Basic connectivity test..." -ForegroundColor Cyan
$test1 = ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p $port root@$hostname "echo 'Success'; hostname; pwd" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Connection successful!" -ForegroundColor Green
    Write-Host $test1 -ForegroundColor White
    Write-Host ""
    Write-Host "You can now connect with:" -ForegroundColor Green
    Write-Host "  ssh -p $port root@$hostname" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "❌ Connection failed" -ForegroundColor Red
    Write-Host "Error: $test1" -ForegroundColor Red
    Write-Host ""
}

# Test 2: Check if port is reachable (using Test-NetConnection if available)
Write-Host "Test 2: Checking if port is reachable..." -ForegroundColor Cyan
try {
    $tcpTest = Test-NetConnection -ComputerName $hostname -Port $port -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($tcpTest) {
        Write-Host "✅ Port $port is reachable on $hostname" -ForegroundColor Green
    } else {
        Write-Host "❌ Port $port is NOT reachable on $hostname" -ForegroundColor Red
        Write-Host "   This could mean:" -ForegroundColor Yellow
        Write-Host "   - Instance is not running" -ForegroundColor White
        Write-Host "   - Firewall is blocking the connection" -ForegroundColor White
        Write-Host "   - Port number is incorrect" -ForegroundColor White
    }
} catch {
    Write-Host "⚠️  Could not test port (Test-NetConnection not available)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Troubleshooting Steps" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Check VAST.ai Dashboard:" -ForegroundColor Yellow
Write-Host "   - Is the instance status 'Running'?" -ForegroundColor White
Write-Host "   - Has it been running for at least 1-2 minutes?" -ForegroundColor White
Write-Host "   - Try clicking 'Restart' if it just started" -ForegroundColor White
Write-Host ""
Write-Host "2. Verify SSH Key:" -ForegroundColor Yellow
Write-Host "   - Go to instance → Config → SSH tab" -ForegroundColor White
Write-Host "   - Make sure your SSH public key is added" -ForegroundColor White
Write-Host ""
Write-Host "3. Check Connection Details:" -ForegroundColor Yellow
Write-Host "   - In dashboard, look for 'Proxy ssh connect:'" -ForegroundColor White
Write-Host "   - Verify the port and hostname match:" -ForegroundColor White
Write-Host "     Port: $port" -ForegroundColor Cyan
Write-Host "     Host: $hostname" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Your SSH Public Key:" -ForegroundColor Yellow
$sshKeyPath = "$env:USERPROFILE\.ssh\id_ed25519.pub"
if (Test-Path $sshKeyPath) {
    Write-Host "   Found: $sshKeyPath" -ForegroundColor Green
    Write-Host "   Key:" -ForegroundColor White
    Get-Content $sshKeyPath | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
} else {
    $rsaKeyPath = "$env:USERPROFILE\.ssh\id_rsa.pub"
    if (Test-Path $rsaKeyPath) {
        Write-Host "   Found: $rsaKeyPath" -ForegroundColor Green
        Write-Host "   Key:" -ForegroundColor White
        Get-Content $rsaKeyPath | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    } else {
        Write-Host "   ⚠️  No SSH key found!" -ForegroundColor Red
        Write-Host "   Generate one with: ssh-keygen -t ed25519" -ForegroundColor Yellow
    }
}
Write-Host ""
Write-Host "5. Try Manual Connection:" -ForegroundColor Yellow
Write-Host "   ssh -p $port root@$hostname" -ForegroundColor Cyan
Write-Host ""
