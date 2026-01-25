# Find VAST Connection Details
# This script helps you find the correct SSH connection details from your VAST dashboard

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Find VAST Connection Details" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your connection is timing out. Let's find the correct details!" -ForegroundColor Yellow
Write-Host ""
Write-Host "STEP 1: Open your VAST.ai dashboard" -ForegroundColor Green
Write-Host "  - Go to: https://vast.ai" -ForegroundColor White
Write-Host "  - Find your running instance (should be named 'Juniper' or similar)" -ForegroundColor White
Write-Host ""
Write-Host "STEP 2: Find the SSH connection details" -ForegroundColor Green
Write-Host "  - Click on your instance" -ForegroundColor White
Write-Host "  - Look for 'SSH' or 'Connect' section" -ForegroundColor White
Write-Host "  - You should see something like:" -ForegroundColor White
Write-Host "     'Proxy ssh connect: ssh -p PORT root@sshX.vast.ai'" -ForegroundColor Cyan
Write-Host "     OR" -ForegroundColor White
Write-Host "     'Direct ssh connect: ssh -p PORT root@IP_ADDRESS'" -ForegroundColor Cyan
Write-Host ""
Write-Host "STEP 3: Enter the details below" -ForegroundColor Green
Write-Host ""

# Prompt for connection details
$port = Read-Host "Enter the SSH PORT (from dashboard)"
$hostname = Read-Host "Enter the HOSTNAME (sshX.vast.ai or IP address)"

Write-Host ""
Write-Host "Testing connection to $hostname on port $port..." -ForegroundColor Yellow
Write-Host ""

# Test connection
$testCmd = "ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p $port root@$hostname 'echo Connection successful!; hostname; pwd' 2>&1"
$result = Invoke-Expression $testCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Connection successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now connect with:" -ForegroundColor Green
    Write-Host "  ssh -p $port root@$hostname" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Would you like me to update the connection scripts?" -ForegroundColor Yellow
    $update = Read-Host "Update scripts? (y/n)"
    
    if ($update -eq "y" -or $update -eq "Y") {
        Write-Host ""
        Write-Host "Updating connect-vast-simple.ps1..." -ForegroundColor Yellow
        
        # Update connect-vast-simple.ps1
        $content = Get-Content "connect-vast-simple.ps1" -Raw
        $content = $content -replace 'ssh -p \d+ root@ssh\d+\.vast\.ai', "ssh -p $port root@$hostname"
        Set-Content "connect-vast-simple.ps1" -Value $content
        
        # Update connect-vast-terminal.ps1
        $content = Get-Content "connect-vast-terminal.ps1" -Raw
        $content = $content -replace 'ssh -p \d+ root@ssh\d+\.vast\.ai', "ssh -p $port root@$hostname"
        Set-Content "connect-vast-terminal.ps1" -Value $content
        
        Write-Host "✅ Scripts updated!" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now run:" -ForegroundColor Cyan
        Write-Host "  .\connect-vast-terminal.ps1  (to connect to terminal)" -ForegroundColor White
        Write-Host "  .\connect-vast-simple.ps1     (for port forwarding)" -ForegroundColor White
    }
} else {
    Write-Host ""
    Write-Host "❌ Connection failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host $result -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Double-check the port and hostname from VAST dashboard" -ForegroundColor White
    Write-Host "  2. Make sure your SSH key is added to the instance:" -ForegroundColor White
    Write-Host "     - Go to VAST dashboard → Your instance → SSH Keys" -ForegroundColor Gray
    Write-Host "     - Add your public key if not already added" -ForegroundColor Gray
    Write-Host "  3. Verify the instance is running (not paused/stopped)" -ForegroundColor White
    Write-Host "  4. Try connecting manually:" -ForegroundColor White
    Write-Host "     ssh -p $port root@$hostname" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Your SSH public key:" -ForegroundColor Yellow
    if (Test-Path "$env:USERPROFILE\.ssh\id_ed25519.pub") {
        Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
    } elseif (Test-Path "$env:USERPROFILE\.ssh\id_rsa.pub") {
        Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub"
    } else {
        Write-Host "  No SSH key found. Generate one with: ssh-keygen -t ed25519" -ForegroundColor Yellow
    }
}

Write-Host ""
