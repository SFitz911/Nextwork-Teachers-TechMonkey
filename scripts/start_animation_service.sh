#!/usr/bin/env bash
# Script to start the Animation service
# Usage: bash scripts/start_animation_service.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Starting Animation Service"
echo "=========================================="
echo ""

# Check if already running
if pgrep -f "python.*animation/app.py" > /dev/null; then
    echo "⚠️  Animation service is already running"
    echo "   PID: $(pgrep -f 'python.*animation/app.py')"
    exit 0
fi

# Activate virtual environment
source /root/ai-teacher-venv/bin/activate

# Set environment variables
export AVATAR_PATH="$PROJECT_DIR/services/animation/avatars"
mkdir -p "$PROJECT_DIR/services/animation/output"
mkdir -p logs

# Start animation service
echo "Starting animation service..."
nohup python services/animation/app.py > logs/animation.log 2>&1 &

sleep 2

# Verify it's running
if pgrep -f "python.*animation/app.py" > /dev/null; then
    echo "✅ Animation service started"
    echo "   PID: $(pgrep -f 'python.*animation/app.py')"
    echo "   Logs: tail -f logs/animation.log"
    echo ""
    
    # Test if it's accessible
    sleep 1
    if curl -s http://localhost:8002/docs > /dev/null 2>&1; then
        echo "✅ Animation service is accessible at http://localhost:8002"
    else
        echo "⚠️  Animation service started but not yet accessible"
        echo "   Wait a few seconds and check: curl http://localhost:8002/docs"
    fi
else
    echo "❌ Failed to start animation service"
    echo "   Check logs: tail -20 logs/animation.log"
    exit 1
fi
