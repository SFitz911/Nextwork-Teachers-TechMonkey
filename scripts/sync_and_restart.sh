#!/usr/bin/env bash
# Script to run on VAST instance: Pull latest code and restart services
# Usage: bash scripts/sync_and_restart.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Syncing with GitHub and Restarting Services"
echo "=========================================="

# Pull latest code
echo ""
echo "📥 Pulling latest code from GitHub..."
git pull origin main

echo ""
echo "✅ Code updated!"

# Check if services need restart
echo ""
echo "🔄 Restarting services..."

# Kill existing services
echo "Stopping existing services..."
pkill -f "n8n start" || true
pkill -f streamlit || true
pkill -f "python.*tts/app.py" || true
pkill -f "python.*animation/app.py" || true
tmux kill-session -t ai-teacher 2>/dev/null || true

sleep 2

# Restart services using the deployment script
echo "Starting services with latest code..."
source /root/ai-teacher-venv/bin/activate
bash scripts/run_no_docker_tmux.sh

sleep 5

# Verify services are running
echo ""
echo "✅ Verifying services..."
ps aux | grep -E "n8n|streamlit|python.*tts|python.*animation" | grep -v grep || echo "⚠️  Some services may not be running"

echo ""
echo "=========================================="
echo "✅ Sync and restart complete!"
echo "=========================================="
echo ""
echo "Services should be running on:"
echo "  n8n:       http://localhost:5678"
echo "  frontend:  http://localhost:8501"
echo "  TTS:       http://localhost:8001"
echo "  animation: http://localhost:8002"
