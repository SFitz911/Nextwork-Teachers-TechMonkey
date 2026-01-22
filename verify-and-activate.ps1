# PowerShell script to verify services and help activate n8n workflow
# Usage: .\verify-and-activate.ps1

$ErrorActionPreference = "Continue"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Verifying Services and n8n Status" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if services are accessible
Write-Host "Testing service endpoints..." -ForegroundColor Yellow

$services = @{
    "n8n" = "http://localhost:5678"
    "Frontend" = "http://localhost:8501"
    "TTS" = "http://localhost:8001"
    "Animation" = "http://localhost:8002"
}

$allGood = $true

foreach ($service in $services.GetEnumerator()) {
    try {
        $response = Invoke-WebRequest -Uri $service.Value -Method Head -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        Write-Host "  $($service.Key): OK (Status: $($response.StatusCode))" -ForegroundColor Green
    } catch {
        Write-Host "  $($service.Key): NOT ACCESSIBLE" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        $allGood = $false
    }
}

Write-Host ""

if (-not $allGood) {
    Write-Host "Some services are not accessible!" -ForegroundColor Red
    Write-Host "Make sure SSH port forwarding is active:" -ForegroundColor Yellow
    Write-Host "  .\connect-vast.ps1" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "All services are accessible!" -ForegroundColor Green
Write-Host ""

# Instructions for n8n
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "n8n Workflow Activation Steps" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Open n8n in your browser:" -ForegroundColor Yellow
Write-Host "   http://localhost:5678" -ForegroundColor White
Write-Host ""
Write-Host "2. Log in with credentials:" -ForegroundColor Yellow
Write-Host "   Username: sfitz911@gmail.com" -ForegroundColor White
Write-Host "   Password: Delrio77$" -ForegroundColor White
Write-Host ""
Write-Host "3. Check the browser tab title:" -ForegroundColor Yellow
Write-Host "   - If it shows 'n8n [DEV]' -> n8n is in dev mode" -ForegroundColor White
Write-Host "   - If it shows just 'n8n' -> n8n is in production mode" -ForegroundColor White
Write-Host ""
Write-Host "4. Open your workflow:" -ForegroundColor Yellow
Write-Host "   'AI Virtual Classroom - Dual Teacher Workflow'" -ForegroundColor White
Write-Host ""
Write-Host "5. Look for activation toggle:" -ForegroundColor Yellow
Write-Host "   - Top-right corner of workflow editor" -ForegroundColor White
Write-Host "   - Should say 'Active' or 'Inactive'" -ForegroundColor White
Write-Host "   - Click it to activate the workflow" -ForegroundColor White
Write-Host ""
Write-Host "6. Test the frontend:" -ForegroundColor Yellow
Write-Host "   http://localhost:8501" -ForegroundColor White
Write-Host "   Try sending a message!" -ForegroundColor White
Write-Host ""

# Open browser to n8n
$openN8n = Read-Host "Open n8n in browser now? (Y/N)"
if ($openN8n -eq "Y" -or $openN8n -eq "y") {
    Start-Process "http://localhost:5678"
    Write-Host "Browser opened to n8n" -ForegroundColor Green
}

Write-Host ""
Write-Host "Verification complete!" -ForegroundColor Green
