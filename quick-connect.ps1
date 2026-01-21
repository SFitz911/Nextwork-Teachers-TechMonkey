# Quick connection test - can be run from any directory
# Tests connection to VAST instance with correct IP and port

Write-Host "Testing VAST connection..." -ForegroundColor Yellow
Write-Host ""

# Try direct connection first (using correct IP from dashboard)
Write-Host "Attempting direct connection to 60.217.254.161:40257..." -ForegroundColor Cyan
ssh -o ConnectTimeout=10 -p 40257 root@60.217.254.161 "echo 'Connection successful!'; hostname; pwd" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Connection successful!" -ForegroundColor Green
    Write-Host "You can now use: ssh -p 40257 root@60.217.254.161" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "❌ Direct connection failed. Trying gateway..." -ForegroundColor Yellow
    Write-Host ""
    
    # Try gateway connection
    Write-Host "Attempting gateway connection to ssh1.vast.ai:29889..." -ForegroundColor Cyan
    ssh -o ConnectTimeout=10 -p 29889 root@ssh1.vast.ai "echo 'Connection successful!'; hostname; pwd" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Gateway connection successful!" -ForegroundColor Green
        Write-Host "You can now use: ssh -p 29889 root@ssh1.vast.ai" -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "❌ Both connection methods failed." -ForegroundColor Red
        Write-Host ""
        Write-Host "Make sure you've added your SSH key to the Vast.ai instance:" -ForegroundColor Yellow
        Write-Host "1. Go to Vast.ai dashboard" -ForegroundColor White
        Write-Host "2. Open your instance" -ForegroundColor White
        Write-Host "3. Find 'SSH Keys' section" -ForegroundColor White
        Write-Host "4. Add your public key" -ForegroundColor White
        Write-Host ""
        Write-Host "Your public key (already in clipboard):" -ForegroundColor Cyan
        if (Test-Path ~/.ssh/id_ed25519.pub) {
            Get-Content ~/.ssh/id_ed25519.pub
        } elseif (Test-Path ~/.ssh/id_rsa.pub) {
            Get-Content ~/.ssh/id_rsa.pub
        }
    }
}
