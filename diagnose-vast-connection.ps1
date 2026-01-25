# Comprehensive VAST Connection Diagnostic
# This will help identify why the connection is failing

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VAST Connection Diagnostic" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check SSH key
Write-Host "Step 1: Checking SSH Key..." -ForegroundColor Yellow
Write-Host ""

$ed25519Key = "$env:USERPROFILE\.ssh\id_ed25519.pub"
$rsaKey = "$env:USERPROFILE\.ssh\id_rsa.pub"

if (Test-Path $ed25519Key) {
    Write-Host "✅ Found SSH key: $ed25519Key" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your public key:" -ForegroundColor Cyan
    $keyContent = Get-Content $ed25519Key
    Write-Host $keyContent -ForegroundColor White
    Write-Host ""
    Write-Host "⚠️  ACTION REQUIRED:" -ForegroundColor Yellow
    Write-Host "   1. Copy the key above (it's already displayed)" -ForegroundColor White
    Write-Host "   2. Go to VAST.ai dashboard → Your instance → Config → SSH tab" -ForegroundColor White
    Write-Host "   3. Click 'Add SSH Key' and paste the key" -ForegroundColor White
    Write-Host "   4. Save and wait 30 seconds" -ForegroundColor White
} elseif (Test-Path $rsaKey) {
    Write-Host "✅ Found SSH key: $rsaKey" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your public key:" -ForegroundColor Cyan
    $keyContent = Get-Content $rsaKey
    Write-Host $keyContent -ForegroundColor White
    Write-Host ""
    Write-Host "⚠️  ACTION REQUIRED:" -ForegroundColor Yellow
    Write-Host "   1. Copy the key above" -ForegroundColor White
    Write-Host "   2. Go to VAST.ai dashboard → Your instance → Config → SSH tab" -ForegroundColor White
    Write-Host "   3. Click 'Add SSH Key' and paste the key" -ForegroundColor White
    Write-Host "   4. Save and wait 30 seconds" -ForegroundColor White
} else {
    Write-Host "❌ No SSH key found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Generating SSH key..." -ForegroundColor Yellow
    ssh-keygen -t ed25519 -C "vast-ai-key" -f "$env:USERPROFILE\.ssh\id_ed25519" -N '""'
    
    if (Test-Path $ed25519Key) {
        Write-Host "✅ SSH key generated!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Your public key:" -ForegroundColor Cyan
        Get-Content $ed25519Key
        Write-Host ""
        Write-Host "⚠️  ACTION REQUIRED:" -ForegroundColor Yellow
        Write-Host "   1. Copy the key above" -ForegroundColor White
        Write-Host "   2. Go to VAST.ai dashboard → Your instance → Config → SSH tab" -ForegroundColor White
        Write-Host "   3. Click 'Add SSH Key' and paste the key" -ForegroundColor White
        Write-Host "   4. Save and wait 30 seconds" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Step 2: Testing Connection" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$port = "30909"
$hostname = "ssh6.vast.ai"

Write-Host "Testing: ssh -p $port root@$hostname" -ForegroundColor Yellow
Write-Host ""

# Try connection with verbose output
Write-Host "Attempting connection (this may take 10-15 seconds)..." -ForegroundColor Cyan
$result = ssh -v -o ConnectTimeout=15 -o StrictHostKeyChecking=no -p $port root@$hostname "echo 'Connected!'; hostname" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ CONNECTION SUCCESSFUL!" -ForegroundColor Green
    Write-Host $result -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "❌ Connection failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host $result -ForegroundColor Red
    Write-Host ""
    
    # Check for specific error patterns
    if ($result -match "Permission denied") {
        Write-Host "🔍 DIAGNOSIS: Permission denied" -ForegroundColor Yellow
        Write-Host "   → SSH key is NOT added to the instance" -ForegroundColor White
        Write-Host "   → Add your SSH key in VAST dashboard (see Step 1)" -ForegroundColor White
    } elseif ($result -match "Connection timed out") {
        Write-Host "🔍 DIAGNOSIS: Connection timeout" -ForegroundColor Yellow
        Write-Host "   Possible causes:" -ForegroundColor White
        Write-Host "   1. Instance not fully started (wait 2-3 minutes)" -ForegroundColor White
        Write-Host "   2. Firewall blocking connection" -ForegroundColor White
        Write-Host "   3. Wrong port/hostname (check dashboard again)" -ForegroundColor White
        Write-Host "   4. Network/VPN issue" -ForegroundColor White
    } elseif ($result -match "Connection refused") {
        Write-Host "🔍 DIAGNOSIS: Connection refused" -ForegroundColor Yellow
        Write-Host "   → Port might be wrong or instance not ready" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Step 3: Alternative Solutions" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If connection still fails, try these:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Use VAST Web Terminal (if available):" -ForegroundColor Green
Write-Host "   - Go to VAST dashboard → Your instance" -ForegroundColor White
Write-Host "   - Look for 'Web Terminal' or 'Console' button" -ForegroundColor White
Write-Host "   - This bypasses SSH entirely" -ForegroundColor White
Write-Host ""
Write-Host "2. Restart the instance:" -ForegroundColor Green
Write-Host "   - In dashboard, click Restart on your instance" -ForegroundColor White
Write-Host "   - Wait 3-5 minutes for full startup" -ForegroundColor White
Write-Host "   - Check Proxy ssh connect command again (port may change)" -ForegroundColor White
Write-Host ""
Write-Host "3. Check dashboard for updated connection details:" -ForegroundColor Green
Write-Host "   - Instance - Look for Proxy ssh connect or Direct ssh connect" -ForegroundColor White
Write-Host "   - Port numbers can change when instance restarts" -ForegroundColor White
Write-Host ""
Write-Host "4. Try direct IP connection (if shown in dashboard):" -ForegroundColor Green
Write-Host "   - Look for Direct ssh connect in dashboard" -ForegroundColor White
Write-Host "   - It will show: ssh -p PORT root@IP_ADDRESS" -ForegroundColor White
Write-Host "   - Try that command instead" -ForegroundColor White
