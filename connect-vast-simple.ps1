# Simple SSH Port Forwarding - Keeps window open
# Usage: .\connect-vast-simple.ps1

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "SSH Port Forwarding" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This window will forward ports from VAST to your local machine." -ForegroundColor Yellow
Write-Host "DO NOT CLOSE THIS WINDOW!" -ForegroundColor Red
Write-Host ""
Write-Host "Ports being forwarded:" -ForegroundColor White
Write-Host "  - 5678  → n8n" -ForegroundColor White
Write-Host "  - 8501  → Frontend" -ForegroundColor White
Write-Host "  - 8001  → TTS" -ForegroundColor White
Write-Host "  - 8002  → Animation" -ForegroundColor White
Write-Host "  - 11434 → Ollama" -ForegroundColor White
Write-Host ""
Write-Host "Connecting..." -ForegroundColor Green
Write-Host ""

# Try gateway connection (most reliable)
ssh -p 35859 root@ssh7.vast.ai -L 5678:localhost:5678 -L 8501:localhost:8501 -L 8001:localhost:8001 -L 8002:localhost:8002 -L 11434:localhost:11434

Write-Host ""
Write-Host "Connection closed. This window will stay open for 60 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 60
