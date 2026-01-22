#!/usr/bin/env bash
# Script to restart frontend with correct environment variables
# Usage: bash scripts/restart_frontend.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Restarting Frontend"
echo "=========================================="
echo ""

# Kill existing frontend (including in tmux)
echo "Stopping existing frontend..."
pkill -f streamlit || true
# Also kill any streamlit in tmux sessions
tmux list-sessions 2>/dev/null | grep -q ai-teacher && tmux kill-window -t ai-teacher:frontend 2>/dev/null || true
sleep 2

# Activate virtual environment
source /root/ai-teacher-venv/bin/activate

# Set environment variables
export N8N_WEBHOOK_URL='http://localhost:5678/webhook/chat-webhook'
export TTS_API_URL='http://localhost:8001'
export ANIMATION_API_URL='http://localhost:8002'

# Start frontend
echo "Starting frontend with updated code..."
mkdir -p logs
nohup streamlit run frontend/app.py --server.address 0.0.0.0 --server.port 8501 > logs/frontend.log 2>&1 &

sleep 3

# Verify it's running
if pgrep -f streamlit > /dev/null; then
    echo "✅ Frontend is running"
    echo ""
    echo "Frontend URL: http://localhost:8501"
    echo "Check logs: tail -f logs/frontend.log"
else
    echo "❌ Frontend failed to start"
    echo "Check logs: tail -20 logs/frontend.log"
    exit 1
fi
