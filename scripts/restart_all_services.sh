#!/usr/bin/env bash
# Restart all services on VAST instance
# Usage: bash scripts/restart_all_services.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Restarting All Services"
echo "=========================================="
echo ""

# Activate virtual environment
source /root/ai-teacher-venv/bin/activate

# Kill existing services
echo "Stopping existing services..."
pkill -f "n8n start" || true
pkill -f streamlit || true
pkill -f "python.*tts/app.py" || true
pkill -f "python.*animation/app.py" || true
pkill -f "ollama serve" || true
tmux kill-session -t ai-teacher 2>/dev/null || true

sleep 3

echo "✅ Services stopped"
echo ""

# Start Ollama if not running
if ! pgrep -f "ollama serve" > /dev/null; then
    echo "Starting Ollama..."
    nohup ollama serve > logs/ollama.log 2>&1 &
    sleep 2
    echo "✅ Ollama started"
else
    echo "✅ Ollama already running"
fi

# Start all services in tmux
echo ""
echo "Starting all services in tmux..."
bash scripts/run_no_docker_tmux.sh

sleep 5

echo ""
echo "Verifying services are running..."
echo ""

# Check services
services_ok=true

if pgrep -f "n8n start" > /dev/null; then
    echo "✅ n8n is running"
else
    echo "❌ n8n is NOT running"
    services_ok=false
fi

if pgrep -f streamlit > /dev/null; then
    echo "✅ Frontend (Streamlit) is running"
else
    echo "❌ Frontend is NOT running"
    services_ok=false
fi

if pgrep -f "python.*tts/app.py" > /dev/null; then
    echo "✅ TTS service is running"
else
    echo "❌ TTS service is NOT running"
    services_ok=false
fi

if pgrep -f "python.*animation/app.py" > /dev/null; then
    echo "✅ Animation service is running"
else
    echo "❌ Animation service is NOT running"
    services_ok=false
fi

if pgrep -f "ollama serve" > /dev/null; then
    echo "✅ Ollama is running"
else
    echo "❌ Ollama is NOT running"
    services_ok=false
fi

echo ""
if $services_ok; then
    echo "=========================================="
    echo "✅ All services are running!"
    echo "=========================================="
    echo ""
    echo "Services are available at:"
    echo "  n8n:       http://localhost:5678"
    echo "  frontend:  http://localhost:8501"
    echo "  TTS:       http://localhost:8001"
    echo "  animation: http://localhost:8002"
    echo ""
    echo "Next steps:"
    echo "  1. Make sure SSH port forwarding is active on your Desktop"
    echo "  2. Open http://localhost:5678 in your browser"
    echo "  3. Activate the workflow if needed"
else
    echo "=========================================="
    echo "❌ Some services failed to start"
    echo "=========================================="
    echo ""
    echo "Check logs:"
    echo "  tail -50 logs/n8n.log"
    echo "  tail -50 logs/frontend.log"
    echo "  tail -50 logs/tts.log"
    echo "  tail -50 logs/animation.log"
fi
