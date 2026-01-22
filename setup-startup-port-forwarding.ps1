# Setup Port Forwarding to Run at Windows Startup
# This script helps you configure port forwarding to start automatically
# Usage: .\setup-startup-port-forwarding.ps1

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Setup Auto-Start Port Forwarding" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$scriptPath = Join-Path $PSScriptRoot "auto-start-port-forwarding.ps1"
$startupFolder = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startupFolder "VAST Port Forwarding.lnk"

Write-Host "This will create a shortcut in your Windows Startup folder." -ForegroundColor Yellow
Write-Host "Port forwarding will start automatically when Windows boots." -ForegroundColor Yellow
Write-Host ""
Write-Host "Startup folder: $startupFolder" -ForegroundColor White
Write-Host "Script: $scriptPath" -ForegroundColor White
Write-Host ""

$response = Read-Host "Create startup shortcut? (Y/N)"

if ($response -ne "Y" -and $response -ne "y") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

# Create shortcut using WScript
$WScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $WScriptShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$scriptPath`" -Background -CheckFirst"
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.Description = "Auto-start VAST.ai SSH Port Forwarding"
$shortcut.IconLocation = "powershell.exe,0"
$shortcut.Save()

Write-Host ""
Write-Host "✅ Startup shortcut created!" -ForegroundColor Green
Write-Host ""
Write-Host "Shortcut location: $shortcutPath" -ForegroundColor White
Write-Host ""
Write-Host "Port forwarding will now start automatically when Windows boots." -ForegroundColor Cyan
Write-Host ""
Write-Host "To test it now, run:" -ForegroundColor Yellow
Write-Host "  .\auto-start-port-forwarding.ps1 -Background" -ForegroundColor White
Write-Host ""
Write-Host "To remove auto-start later:" -ForegroundColor Yellow
Write-Host "  1. Press Win+R, type: shell:startup" -ForegroundColor White
Write-Host "  2. Delete 'VAST Port Forwarding.lnk'" -ForegroundColor White
Write-Host ""
