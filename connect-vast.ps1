# PowerShell script to connect to Vast.ai with port forwarding
# Usage: .\connect-vast.ps1 [direct|gateway]

param(
    [string]$Method = "gateway"
)

if ($Method -eq "direct") {
    Write-Host "Connecting via direct IP with port forwarding..." -ForegroundColor Green
    ssh -p 41428 root@50.217.254.161 `
        -L 5678:localhost:5678 `
        -L 8501:localhost:8501 `
        -L 8001:localhost:8001 `
        -L 8002:localhost:8002 `
        -L 11434:localhost:11434
} else {
    Write-Host "Connecting via Vast.ai SSH gateway with port forwarding..." -ForegroundColor Green
    ssh -p 35859 root@ssh7.vast.ai `
        -L 5678:localhost:5678 `
        -L 8501:localhost:8501 `
        -L 8001:localhost:8001 `
        -L 8002:localhost:8002 `
        -L 11434:localhost:11434
}
