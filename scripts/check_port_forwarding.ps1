# Check if SSH port forwarding is active
# Usage: .\scripts\check_port_forwarding.ps1

Write-Host "=========================================="
Write-Host "Checking SSH Port Forwarding Status"
Write-Host "=========================================="
Write-Host ""

$ports = @(5678, 8501, 8001, 8002)
$allActive = $true

foreach ($port in $ports) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$port" -Method Head -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        Write-Host "✅ Port $port is forwarded and accessible" -ForegroundColor Green
    } catch {
        Write-Host "❌ Port $port is NOT accessible" -ForegroundColor Red
        $allActive = $false
    }
}

Write-Host ""
if ($allActive) {
    Write-Host "✅ All ports are forwarded! You can access:" -ForegroundColor Green
    Write-Host "   - n8n: http://localhost:5678"
    Write-Host "   - Frontend: http://localhost:8501"
    Write-Host "   - TTS: http://localhost:8001"
    Write-Host "   - Animation: http://localhost:8002"
} else {
    Write-Host "❌ Port forwarding is NOT active!" -ForegroundColor Red
    Write-Host ""
    Write-Host "To start port forwarding, run:" -ForegroundColor Yellow
    Write-Host "   .\connect-vast.ps1"
    Write-Host ""
    Write-Host "Keep that PowerShell window open while you work!"
}
