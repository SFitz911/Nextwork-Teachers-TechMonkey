# PowerShell script to connect to Vast.ai with port forwarding
# Usage: .\connect-vast.ps1 [direct|gateway]
#
# IMPORTANT: This opens SSH in a NEW PowerShell window.
# Keep that window open for port forwarding to work!
# DO NOT close the SSH window while using services.

param(
    [string]$Method = "gateway"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Starting SSH Port Forwarding" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will open a NEW PowerShell window with SSH connection." -ForegroundColor Yellow
Write-Host "KEEP THAT WINDOW OPEN for port forwarding to work!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Ports being forwarded:" -ForegroundColor White
Write-Host "  - 5678  → n8n" -ForegroundColor White
Write-Host "  - 8501  → Frontend" -ForegroundColor White
Write-Host "  - 8001  → TTS" -ForegroundColor White
Write-Host "  - 8002  → Animation" -ForegroundColor White
Write-Host "  - 11434 → Ollama" -ForegroundColor White
Write-Host ""
Write-Host "Opening SSH connection in new window..." -ForegroundColor Green
Write-Host ""

if ($Method -eq "direct") {
    $sshArgs = "-p 41428 root@50.217.254.161 -L 5678:localhost:5678 -L 8501:localhost:8501 -L 8001:localhost:8001 -L 8002:localhost:8002 -L 11434:localhost:11434"
} else {
    $sshArgs = "-p 35859 root@ssh7.vast.ai -L 5678:localhost:5678 -L 8501:localhost:8501 -L 8001:localhost:8001 -L 8002:localhost:8002 -L 11434:localhost:11434"
}

# Create a temporary script file that will be executed in the new window
$tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
$scriptContent = @"
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host 'SSH Port Forwarding Window' -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'DO NOT CLOSE THIS WINDOW' -ForegroundColor Yellow
Write-Host 'Port forwarding will stop if you close this window!' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Connecting to VAST.ai...' -ForegroundColor Green
Write-Host ''
Write-Host 'If connection fails, check:' -ForegroundColor Yellow
Write-Host '  1. SSH key is added to VAST instance' -ForegroundColor White
Write-Host '  2. Instance is running on Vast.ai dashboard' -ForegroundColor White
Write-Host '  3. IP/port are correct in connect-vast.ps1' -ForegroundColor White
Write-Host ''
try {
    ssh $sshArgs
} catch {
    Write-Host ''
    Write-Host 'SSH connection error!' -ForegroundColor Red
    Write-Host `$_.Exception.Message -ForegroundColor Red
}
Write-Host ''
Write-Host 'SSH connection closed or failed.' -ForegroundColor Yellow
Write-Host 'This window will stay open for 30 seconds so you can see any errors.' -ForegroundColor Yellow
Write-Host ''
Start-Sleep -Seconds 30
"@

Set-Content -Path $tempScript -Value $scriptContent

# Start the new PowerShell window with the script
# Use -NoExit to keep window open even if script completes
Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $tempScript

Write-Host "✅ SSH port forwarding started in new window!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. A new PowerShell window opened - KEEP IT OPEN" -ForegroundColor White
Write-Host "  2. Wait 3-5 seconds for connection to establish" -ForegroundColor White
Write-Host "  3. Run: .\scripts\check_port_forwarding.ps1 to verify" -ForegroundColor White
Write-Host "  4. If ports 8001/8002 fail, check if services are running on VAST" -ForegroundColor White
Write-Host ""
