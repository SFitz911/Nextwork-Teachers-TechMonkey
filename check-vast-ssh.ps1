# Simple VAST SSH Connection Check
Write-Host "VAST Connection Diagnostic" -ForegroundColor Cyan
Write-Host ""

# Check SSH key
$keyPath = "$env:USERPROFILE\.ssh\id_ed25519.pub"
if (-not (Test-Path $keyPath)) {
    $keyPath = "$env:USERPROFILE\.ssh\id_rsa.pub"
}

if (Test-Path $keyPath) {
    Write-Host "SSH Key Found: $keyPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your public key:" -ForegroundColor Yellow
    Get-Content $keyPath
    Write-Host ""
    Write-Host "IMPORTANT: Make sure this key is added in VAST dashboard:" -ForegroundColor Yellow
    Write-Host "1. Go to VAST.ai dashboard" -ForegroundColor White
    Write-Host "2. Open your instance" -ForegroundColor White
    Write-Host "3. Go to Config tab, then SSH tab" -ForegroundColor White
    Write-Host "4. Add this key if not already there" -ForegroundColor White
} else {
    Write-Host "No SSH key found. Generating one..." -ForegroundColor Yellow
    ssh-keygen -t ed25519 -C "vast-ai" -f "$env:USERPROFILE\.ssh\id_ed25519" -N '""'
    if (Test-Path "$env:USERPROFILE\.ssh\id_ed25519.pub") {
        Write-Host "SSH key generated!" -ForegroundColor Green
        Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
    }
}

Write-Host ""
Write-Host "Testing connection..." -ForegroundColor Cyan
$result = ssh -o ConnectTimeout=15 -p 30909 root@ssh6.vast.ai "echo Connected; hostname" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "SUCCESS! Connection works." -ForegroundColor Green
    Write-Host $result -ForegroundColor White
} else {
    Write-Host "Connection failed." -ForegroundColor Red
    Write-Host $result -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Check VAST dashboard - is instance Running?" -ForegroundColor White
    Write-Host "2. Verify SSH key is added in dashboard" -ForegroundColor White
    Write-Host "3. Check if port/hostname changed in dashboard" -ForegroundColor White
    Write-Host "4. Try using Web Terminal in VAST dashboard instead" -ForegroundColor White
}
