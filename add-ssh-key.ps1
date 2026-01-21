# Script to help add SSH key to Vast.ai instance
# This will copy your public key to clipboard for easy pasting

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SSH Key Setup for Vast.ai" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get the public key
$publicKey = ""
if (Test-Path ~/.ssh/id_ed25519.pub) {
    $publicKey = Get-Content ~/.ssh/id_ed25519.pub
} elseif (Test-Path ~/.ssh/id_rsa.pub) {
    $publicKey = Get-Content ~/.ssh/id_rsa.pub
} else {
    Write-Host "❌ No SSH key found!" -ForegroundColor Red
    Write-Host "Generate one with: ssh-keygen -t ed25519 -C 'your-email@example.com'" -ForegroundColor Yellow
    exit 1
}

Write-Host "Your SSH public key:" -ForegroundColor Green
Write-Host $publicKey -ForegroundColor White
Write-Host ""

# Copy to clipboard
$publicKey | Set-Clipboard
Write-Host "✅ Key copied to clipboard!" -ForegroundColor Green
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Connect to your Vast.ai instance with password:" -ForegroundColor White
Write-Host "   ssh -p 35859 root@ssh7.vast.ai" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Once connected, run this command on the instance:" -ForegroundColor White
Write-Host "   echo '$publicKey' >> ~/.ssh/authorized_keys" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Or paste the key (already in clipboard) into:" -ForegroundColor White
Write-Host "   nano ~/.ssh/authorized_keys" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Set correct permissions:" -ForegroundColor White
Write-Host "   chmod 600 ~/.ssh/authorized_keys" -ForegroundColor Cyan
Write-Host "   chmod 700 ~/.ssh" -ForegroundColor Cyan
Write-Host ""
Write-Host "5. Test connection:" -ForegroundColor White
Write-Host "   .\connect-vast.ps1" -ForegroundColor Cyan
