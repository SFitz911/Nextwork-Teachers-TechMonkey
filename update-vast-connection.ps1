# Script to update VAST connection details for new instance
# Usage: .\update-vast-connection.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Update VAST Connection Details" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will update all connection scripts with your new VAST instance details." -ForegroundColor Yellow
Write-Host ""

# Get connection details from user
Write-Host "Enter your new VAST instance connection details:" -ForegroundColor White
Write-Host ""

# Direct connection
Write-Host "DIRECT CONNECTION:" -ForegroundColor Cyan
$directPort = Read-Host "  SSH Port (e.g., 28259)"
$directIP = Read-Host "  IP Address (e.g., 24.124.32.70)"

Write-Host ""
Write-Host "PROXY/GATEWAY CONNECTION:" -ForegroundColor Cyan
$proxyPort = Read-Host "  SSH Port (e.g., 24285)"
$proxyHost = Read-Host "  Host (e.g., ssh4.vast.ai)"

Write-Host ""
Write-Host "Your connection details:" -ForegroundColor Green
Write-Host "  Direct:  ssh -p $directPort root@$directIP" -ForegroundColor White
Write-Host "  Proxy:   ssh -p $proxyPort root@$proxyHost" -ForegroundColor White
Write-Host ""

$confirm = Read-Host "Is this correct? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "Updating connection scripts..." -ForegroundColor Green

# Update connect-vast-simple.ps1
$simpleScript = "connect-vast-simple.ps1"
if (Test-Path $simpleScript) {
    $content = Get-Content $simpleScript -Raw
    $content = $content -replace "ssh -p \d+ root@[^\s]+", "ssh -p $proxyPort root@$proxyHost"
    Set-Content $simpleScript -Value $content -Encoding UTF8
    Write-Host "  ✅ Updated $simpleScript" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  $simpleScript not found" -ForegroundColor Yellow
}

# Update connect-vast.ps1
$vastScript = "connect-vast.ps1"
if (Test-Path $vastScript) {
    $content = Get-Content $vastScript -Raw
    # Update direct connection
    $content = $content -replace "-p \d+ root@[\d\.]+", "-p $directPort root@$directIP"
    # Update proxy connection
    $content = $content -replace "-p \d+ root@ssh\d+\.vast\.ai", "-p $proxyPort root@$proxyHost"
    # Update test commands
    $content = $content -replace "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p \d+ root@[\d\.]+", "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p $directPort root@$directIP"
    $content = $content -replace "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p \d+ root@ssh\d+\.vast\.ai", "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p $proxyPort root@$proxyHost"
    Set-Content $vastScript -Value $content -Encoding UTF8
    Write-Host "  ✅ Updated $vastScript" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  $vastScript not found" -ForegroundColor Yellow
}

# Update connect-vast-terminal.ps1
$terminalScript = "connect-vast-terminal.ps1"
if (Test-Path $terminalScript) {
    $content = Get-Content $terminalScript -Raw
    $content = $content -replace "ssh -p \d+ root@[^\s]+", "ssh -p $proxyPort root@$proxyHost"
    Set-Content $terminalScript -Value $content -Encoding UTF8
    Write-Host "  ✅ Updated $terminalScript" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  $terminalScript not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ Connection scripts updated!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Add SSH key to VAST instance:" -ForegroundColor White
Write-Host "   .\add-ssh-key.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Test connection:" -ForegroundColor White
Write-Host "   ssh -p $proxyPort root@$proxyHost 'echo test'" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Start port forwarding:" -ForegroundColor White
Write-Host "   .\connect-vast-simple.ps1" -ForegroundColor Cyan
Write-Host ""
