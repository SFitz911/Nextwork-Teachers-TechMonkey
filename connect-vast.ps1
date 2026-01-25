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
Write-Host "  - 8003  → LongCat-Video" -ForegroundColor White
Write-Host "  - 11434 → Ollama" -ForegroundColor White
Write-Host ""
Write-Host "Opening SSH connection in new window..." -ForegroundColor Green
Write-Host ""

       if ($Method -eq "direct") {
           $sshArgs = "-p 28259 root@24.124.32.70 -L 5678:localhost:5678 -L 8501:localhost:8501 -L 8001:localhost:8001 -L 8002:localhost:8002 -L 8003:localhost:8003 -L 8004:localhost:8004 -L 11434:localhost:11434"
       } else {
           $sshArgs = "-p 24285 root@ssh4.vast.ai -L 5678:localhost:5678 -L 8501:localhost:8501 -L 8001:localhost:8001 -L 8002:localhost:8002 -L 8003:localhost:8003 -L 8004:localhost:8004 -L 11434:localhost:11434"
       }

# Test connection first (but don't fail - just warn)
Write-Host "Testing SSH connection..." -ForegroundColor Yellow
if ($Method -eq "direct") {
    $testCmd = "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p 28259 root@24.124.32.70 'echo test' 2>&1"
} else {
    $testCmd = "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p 24285 root@ssh4.vast.ai 'echo test' 2>&1"
}

$testResult = & powershell -Command $testCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  SSH connection test failed, but will still try to connect..." -ForegroundColor Yellow
    Write-Host "Error: $testResult" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The port forwarding window will open anyway." -ForegroundColor White
    Write-Host "If it fails, check:" -ForegroundColor Yellow
    Write-Host "  1. SSH key is added to VAST instance" -ForegroundColor White
    Write-Host "  2. Instance is running on Vast.ai dashboard" -ForegroundColor White
    Write-Host "  3. Try: ssh -p 24285 root@ssh4.vast.ai" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "✅ SSH connection test successful!" -ForegroundColor Green
    Write-Host ""
}

# Create a temporary script file that will be executed in the new window
$tempScript = Join-Path $env:TEMP "vast-ssh-forward.ps1"
$scriptContent = @"
`$ErrorActionPreference = 'Continue'
`$Host.UI.RawUI.WindowTitle = 'VAST SSH Port Forwarding - DO NOT CLOSE'

Write-Host '==========================================' -ForegroundColor Cyan
Write-Host 'SSH Port Forwarding Window' -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'DO NOT CLOSE THIS WINDOW' -ForegroundColor Red
Write-Host 'Port forwarding will stop if you close this window!' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Ports being forwarded:' -ForegroundColor White
Write-Host '  - 5678  -> n8n (http://localhost:5678)' -ForegroundColor White
Write-Host '  - 8501  -> Frontend (http://localhost:8501)' -ForegroundColor White
Write-Host '  - 8001  -> TTS' -ForegroundColor White
Write-Host '  - 8002  -> Animation' -ForegroundColor White
       Write-Host '  - 8003  -> LongCat-Video' -ForegroundColor White
       Write-Host '  - 8004  -> Coordinator API' -ForegroundColor White
       Write-Host '  - 11434 -> Ollama' -ForegroundColor White
Write-Host ''
Write-Host 'Connecting to VAST.ai...' -ForegroundColor Green
Write-Host ''
Write-Host 'If connection fails, you will see error messages below.' -ForegroundColor Yellow
Write-Host 'Common issues:' -ForegroundColor Yellow
Write-Host '  - SSH key not added to VAST instance' -ForegroundColor White
Write-Host '  - Instance not running' -ForegroundColor White
Write-Host '  - Wrong port/IP address' -ForegroundColor White
Write-Host ''
Write-Host 'Starting SSH connection...' -ForegroundColor Green
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host ''

# Run SSH command
ssh $sshArgs

Write-Host ''
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host 'SSH connection closed or failed.' -ForegroundColor Yellow
Write-Host ''
Write-Host 'This window will stay open for 60 seconds' -ForegroundColor Yellow
Write-Host 'so you can see any error messages above.' -ForegroundColor Yellow
Write-Host ''
Start-Sleep -Seconds 60
Write-Host ''
Write-Host 'Closing window in 5 seconds...' -ForegroundColor Yellow
Start-Sleep -Seconds 5
"@

Set-Content -Path $tempScript -Value $scriptContent -Encoding UTF8

# Start the new PowerShell window with the script
# Use -NoExit to keep window open even if script completes
Write-Host "Opening port forwarding window..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$tempScript`""

Write-Host "✅ SSH port forwarding started in new window!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. A new PowerShell window opened - KEEP IT OPEN" -ForegroundColor White
Write-Host "  2. Wait 3-5 seconds for connection to establish" -ForegroundColor White
Write-Host "  3. Run: .\scripts\check_port_forwarding.ps1 to verify" -ForegroundColor White
Write-Host "  4. If ports 8001/8002 fail, check if services are running on VAST" -ForegroundColor White
Write-Host ""
