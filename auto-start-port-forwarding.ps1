# Auto-start SSH Port Forwarding
# This script automatically starts port forwarding and keeps it running
# Usage: .\auto-start-port-forwarding.ps1
# 
# To run at Windows startup:
# 1. Press Win+R, type: shell:startup
# 2. Create a shortcut to this script
# 3. Or add this script to Task Scheduler

param(
    [switch]$Background = $false,
    [switch]$CheckFirst = $true
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Auto-Start Port Forwarding" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if port forwarding is already active
if ($CheckFirst) {
    Write-Host "Checking if port forwarding is already active..." -ForegroundColor Yellow
    
    $portsActive = 0
    $ports = @(5678, 8501, 8001, 8002)
    
    foreach ($port in $ports) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$port" -Method Head -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            $portsActive++
            Write-Host "  ✅ Port $port is already forwarded" -ForegroundColor Green
        } catch {
            Write-Host "  ❌ Port $port is not forwarded" -ForegroundColor Red
        }
    }
    
    if ($portsActive -eq $ports.Count) {
        Write-Host ""
        Write-Host "✅ All ports are already forwarded!" -ForegroundColor Green
        Write-Host "Port forwarding is active. No need to start again." -ForegroundColor White
        Write-Host ""
        Write-Host "To check status: .\scripts\check_port_forwarding.ps1" -ForegroundColor Cyan
        exit 0
    } elseif ($portsActive -gt 0) {
        Write-Host ""
        Write-Host "⚠️  Some ports are forwarded but not all." -ForegroundColor Yellow
        Write-Host "Starting fresh port forwarding session..." -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "No port forwarding detected. Starting..." -ForegroundColor Yellow
        Write-Host ""
    }
}

# Check if SSH process is already running
$existingSSH = Get-Process -Name ssh -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*ssh7.vast.ai*" -or $_.CommandLine -like "*50.217.254.161*"
}

if ($existingSSH) {
    Write-Host "⚠️  Found existing SSH port forwarding process(es):" -ForegroundColor Yellow
    foreach ($proc in $existingSSH) {
        Write-Host "  PID: $($proc.Id) - $($proc.CommandLine)" -ForegroundColor White
    }
    Write-Host ""
    $response = Read-Host "Kill existing processes and start fresh? (Y/N)"
    if ($response -eq "Y" -or $response -eq "y") {
        foreach ($proc in $existingSSH) {
            Write-Host "Stopping process PID: $($proc.Id)..." -ForegroundColor Yellow
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
    } else {
        Write-Host "Keeping existing processes. Exiting." -ForegroundColor Yellow
        exit 0
    }
}

# Determine connection method (default to gateway)
# You can change this to "direct" if needed
$Method = "gateway"

# Load connection details from connect-vast.ps1 if it exists
$connectVastScript = Join-Path $PSScriptRoot "connect-vast.ps1"
if (Test-Path $connectVastScript) {
    # Try to extract connection details (simple approach)
    $connectContent = Get-Content $connectVastScript -Raw
    if ($connectContent -match 'ssh7\.vast\.ai.*35859') {
        $Method = "gateway"
    } elseif ($connectContent -match '50\.217\.254\.161.*41428') {
        $Method = "direct"
    }
}

if ($Method -eq "direct") {
    $sshArgs = "-p 41428 root@50.217.254.161 -L 5678:localhost:5678 -L 8501:localhost:8501 -L 8001:localhost:8001 -L 8002:localhost:8002 -L 11434:localhost:11434"
} else {
    $sshArgs = "-p 35859 root@ssh7.vast.ai -L 5678:localhost:5678 -L 8501:localhost:8501 -L 8001:localhost:8001 -L 8002:localhost:8002 -L 11434:localhost:11434"
}

if ($Background) {
    Write-Host "Starting port forwarding in background..." -ForegroundColor Green
    Write-Host ""
    
    # Create a script that will run in background
    $tempScript = Join-Path $env:TEMP "vast-ssh-auto.ps1"
    $scriptContent = @"
`$Host.UI.RawUI.WindowTitle = 'VAST Port Forwarding (Auto-Started)'
Write-Host 'Auto-started SSH Port Forwarding' -ForegroundColor Cyan
Write-Host 'DO NOT CLOSE THIS WINDOW' -ForegroundColor Red
Write-Host ''
ssh $sshArgs
Write-Host ''
Write-Host 'Connection closed. Window will stay open for 30 seconds...' -ForegroundColor Yellow
Start-Sleep -Seconds 30
"@
    
    Set-Content -Path $tempScript -Value $scriptContent -Encoding UTF8
    
    # Start in minimized window
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoExit -WindowStyle Minimized -ExecutionPolicy Bypass -File `"$tempScript`""
    $psi.UseShellExecute = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    
    Write-Host "✅ Port forwarding started in background (minimized window)" -ForegroundColor Green
    Write-Host ""
    Write-Host "The SSH window is minimized. Check your taskbar for it." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To verify ports are forwarded:" -ForegroundColor Cyan
    Write-Host "  .\scripts\check_port_forwarding.ps1" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "Starting port forwarding in new window..." -ForegroundColor Green
    Write-Host ""
    
    # Use the existing connect-vast.ps1 logic
    $tempScript = Join-Path $env:TEMP "vast-ssh-forward.ps1"
    $scriptContent = @"
`$ErrorActionPreference = 'Continue'
`$Host.UI.RawUI.WindowTitle = 'VAST SSH Port Forwarding - DO NOT CLOSE'

Write-Host '==========================================' -ForegroundColor Cyan
Write-Host 'SSH Port Forwarding Window' -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host '⚠️  DO NOT CLOSE THIS WINDOW ⚠️' -ForegroundColor Red
Write-Host 'Port forwarding will stop if you close this window!' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Ports being forwarded:' -ForegroundColor White
Write-Host '  - 5678  → n8n (http://localhost:5678)' -ForegroundColor White
Write-Host '  - 8501  → Frontend (http://localhost:8501)' -ForegroundColor White
Write-Host '  - 8001  → TTS' -ForegroundColor White
Write-Host '  - 8002  → Animation' -ForegroundColor White
Write-Host '  - 11434 → Ollama' -ForegroundColor White
Write-Host ''
Write-Host 'Connecting to VAST.ai...' -ForegroundColor Green
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
    
    # Start the new PowerShell window
    Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$tempScript`""
    
    Write-Host "✅ Port forwarding started in new window!" -ForegroundColor Green
    Write-Host ""
    Write-Host "A new PowerShell window opened - KEEP IT OPEN" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Wait 3-5 seconds, then verify:" -ForegroundColor Cyan
    Write-Host "  .\scripts\check_port_forwarding.ps1" -ForegroundColor White
    Write-Host ""
}
