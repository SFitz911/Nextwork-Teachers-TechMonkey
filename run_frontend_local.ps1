# PowerShell script to run Streamlit frontend locally for development
# Usage: .\run_frontend_local.ps1

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Starting Frontend Locally" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Change to project directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Check if Python is installed
Write-Host "Checking Python..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✅ $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Python not found. Please install Python 3.8+" -ForegroundColor Red
    exit 1
}

# Check if virtual environment exists, create if not
if (-not (Test-Path "venv")) {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
    Write-Host "✅ Virtual environment created" -ForegroundColor Green
}

# Activate virtual environment
Write-Host "Activating virtual environment..." -ForegroundColor Yellow
& .\venv\Scripts\Activate.ps1

# Install/upgrade dependencies
Write-Host "Installing dependencies..." -ForegroundColor Yellow
pip install --upgrade pip
pip install -r frontend/requirements.txt
pip install streamlit

Write-Host "✅ Dependencies installed" -ForegroundColor Green
Write-Host ""

# Set environment variables (pointing to localhost - backend services should be running)
$env:COORDINATOR_API_URL = "http://localhost:8004"
$env:N8N_WEBHOOK_URL = "http://localhost:5678/webhook/session/start"
$env:TTS_API_URL = "http://localhost:8001"
$env:ANIMATION_API_URL = "http://localhost:8002"
$env:LONGCAT_API_URL = "http://localhost:8003"

Write-Host "Environment variables set:" -ForegroundColor Yellow
Write-Host "  COORDINATOR_API_URL: $env:COORDINATOR_API_URL"
Write-Host "  N8N_WEBHOOK_URL: $env:N8N_WEBHOOK_URL"
Write-Host "  TTS_API_URL: $env:TTS_API_URL"
Write-Host "  ANIMATION_API_URL: $env:ANIMATION_API_URL"
Write-Host "  LONGCAT_API_URL: $env:LONGCAT_API_URL"
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Starting Streamlit..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Frontend will be available at: http://localhost:8501" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Backend services need to be running on VAST instance" -ForegroundColor Yellow
Write-Host "      or you'll need to set up port forwarding." -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
Write-Host ""

# Run Streamlit with auto-reload
streamlit run frontend/app.py --server.port 8501 --server.address localhost
