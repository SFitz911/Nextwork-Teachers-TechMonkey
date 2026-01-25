#!/bin/bash
# Quick diagnostic after port forwarding crash
# Usage: bash scripts/quick_diagnose.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Quick Diagnostic After Port Forwarding Crash"
echo "=========================================="
echo ""

# 1. Check tmux session
echo "1. Checking tmux session..."
if tmux has-session -t ai-teacher 2>/dev/null; then
    echo "   ✅ tmux session 'ai-teacher' exists"
    echo "   Windows:"
    tmux list-windows -t ai-teacher | sed 's/^/      /'
else
    echo "   ❌ tmux session 'ai-teacher' NOT found"
    echo "   Run: bash scripts/quick_start_all.sh"
fi
echo ""

# 2. Check services
echo "2. Checking services..."
SERVICES=(
    "Ollama:ollama serve:11434"
    "n8n:n8n start:5678"
    "Coordinator:python.*coordinator/app.py:8004"
    "TTS:python.*tts/app.py:8001"
    "Animation:python.*animation/app.py:8002"
    "LongCat-Video:python.*longcat_video/app.py:8003"
    "Frontend:streamlit.*app.py:8501"
)

for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r name pattern port <<< "$service_info"
    if pgrep -f "$pattern" > /dev/null; then
        PID=$(pgrep -f "$pattern" | head -1)
        if curl -s "http://localhost:$port" > /dev/null 2>&1; then
            echo "   ✅ $name (PID: $PID, port $port) - Running and accessible"
        else
            echo "   ⚠️  $name (PID: $PID, port $port) - Running but not accessible"
        fi
    else
        echo "   ❌ $name - NOT running"
    fi
done
echo ""

# 3. Check port forwarding
echo "3. Port forwarding status..."
echo "   ⚠️  Port forwarding must be set up from Desktop PowerShell"
echo "   Run: .\connect-vast-simple.ps1"
echo ""

# 4. Quick fix option
echo "4. Quick fix options:"
echo ""
echo "   If services are not running:"
echo "     bash scripts/quick_start_all.sh"
echo ""
echo "   If services are running but not accessible:"
echo "     Check logs: tmux attach -t ai-teacher"
echo "     Check specific service: tail -50 logs/{service}.log"
echo ""
echo "   If port forwarding is not working:"
echo "     From Desktop PowerShell: .\connect-vast-simple.ps1"
echo ""
