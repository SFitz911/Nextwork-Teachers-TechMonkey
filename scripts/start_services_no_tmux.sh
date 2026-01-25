#!/usr/bin/env bash
# Start all services WITHOUT tmux (using nohup/background processes)
# Usage: bash scripts/start_services_no_tmux.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"
LOGS_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOGS_DIR"

echo "=========================================="
echo "Starting Services (No tmux)"
echo "=========================================="
echo ""

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Step 1: Install missing dependencies
echo "Step 1: Installing dependencies..."
if [[ -d "$VENV_DIR" ]]; then
    source "$VENV_DIR/bin/activate"
    echo "Installing Coordinator API dependencies..."
    pip install -q -r services/coordinator/requirements.txt || true
    echo "✅ Dependencies installed"
else
    echo "❌ Virtual environment not found: $VENV_DIR"
    echo "   Run: bash scripts/deploy_no_docker.sh"
    exit 1
fi
echo ""

# Step 2: Stop existing services
echo "Step 2: Stopping existing services..."
pkill -f "ollama serve" 2>/dev/null || true
pkill -f "python.*coordinator/app.py" 2>/dev/null || true
pkill -f "python.*tts/app.py" 2>/dev/null || true
pkill -f "python.*animation/app.py" 2>/dev/null || true
pkill -f "python.*longcat_video/app.py" 2>/dev/null || true
pkill -f "n8n start" 2>/dev/null || true
pkill -f "streamlit run" 2>/dev/null || true
sleep 2
echo "✅ Existing services stopped"
echo ""

# Step 3: Start Ollama
echo "Step 3: Starting Ollama..."
if ! pgrep -f "ollama serve" > /dev/null; then
    nohup ollama serve > "$LOGS_DIR/ollama.log" 2>&1 &
    sleep 5
    echo "✅ Ollama started (PID: $(pgrep -f 'ollama serve'))"
else
    echo "✅ Ollama already running"
fi

# Wait for Ollama
for i in {1..10}; do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        break
    fi
    sleep 1
done
echo ""

# Step 4: Start Coordinator API
echo "Step 4: Starting Coordinator API..."
source "$VENV_DIR/bin/activate"
cd "$PROJECT_DIR"
nohup python services/coordinator/app.py > "$LOGS_DIR/coordinator.log" 2>&1 &
COORDINATOR_PID=$!
sleep 3
if ps -p $COORDINATOR_PID > /dev/null; then
    echo "✅ Coordinator API started (PID: $COORDINATOR_PID)"
else
    echo "❌ Coordinator API failed to start. Check logs: tail -20 $LOGS_DIR/coordinator.log"
fi
echo ""

# Step 5: Start n8n
echo "Step 5: Starting n8n..."
source "$VENV_DIR/bin/activate" >/dev/null 2>&1 || true
export NODE_ENV=production
export N8N_BASIC_AUTH_ACTIVE=true
export N8N_BASIC_AUTH_USER="${N8N_USER:-admin}"
export N8N_BASIC_AUTH_PASSWORD="${N8N_PASSWORD:-changeme}"
export N8N_HOST="${N8N_HOST:-0.0.0.0}"
export N8N_PORT=5678
export N8N_PROTOCOL=http
export WEBHOOK_URL="http://localhost:5678/"
cd "$PROJECT_DIR"
nohup n8n start --port 5678 > "$LOGS_DIR/n8n.log" 2>&1 &
N8N_PID=$!
sleep 5
if ps -p $N8N_PID > /dev/null; then
    echo "✅ n8n started (PID: $N8N_PID)"
else
    echo "❌ n8n failed to start. Check logs: tail -20 $LOGS_DIR/n8n.log"
fi
echo ""

# Step 6: Start TTS
echo "Step 6: Starting TTS..."
source "$VENV_DIR/bin/activate"
cd "$PROJECT_DIR"
nohup python services/tts/app.py > "$LOGS_DIR/tts.log" 2>&1 &
TTS_PID=$!
sleep 2
if ps -p $TTS_PID > /dev/null; then
    echo "✅ TTS started (PID: $TTS_PID)"
else
    echo "❌ TTS failed to start. Check logs: tail -20 $LOGS_DIR/tts.log"
fi
echo ""

# Step 7: Start Animation
echo "Step 7: Starting Animation..."
source "$VENV_DIR/bin/activate"
export AVATAR_PATH="$PROJECT_DIR/services/animation/avatars"
mkdir -p "$PROJECT_DIR/services/animation/output"
cd "$PROJECT_DIR"
nohup python services/animation/app.py > "$LOGS_DIR/animation.log" 2>&1 &
ANIMATION_PID=$!
sleep 2
if ps -p $ANIMATION_PID > /dev/null; then
    echo "✅ Animation started (PID: $ANIMATION_PID)"
else
    echo "❌ Animation failed to start. Check logs: tail -20 $LOGS_DIR/animation.log"
fi
echo ""

# Step 8: Start Frontend
echo "Step 8: Starting Frontend..."
source "$VENV_DIR/bin/activate"
export COORDINATOR_API_URL='http://localhost:8004'
export N8N_WEBHOOK_URL='http://localhost:5678/webhook/session/start'
export TTS_API_URL='http://localhost:8001'
export ANIMATION_API_URL='http://localhost:8002'
export LONGCAT_API_URL='http://localhost:8003'
cd "$PROJECT_DIR"
nohup streamlit run frontend/app.py --server.address 0.0.0.0 --server.port 8501 > "$LOGS_DIR/frontend.log" 2>&1 &
FRONTEND_PID=$!
sleep 3
if ps -p $FRONTEND_PID > /dev/null; then
    echo "✅ Frontend started (PID: $FRONTEND_PID)"
else
    echo "❌ Frontend failed to start. Check logs: tail -20 $LOGS_DIR/frontend.log"
fi
echo ""

# Step 9: Wait and check services
echo "Step 9: Checking service status..."
sleep 5
echo ""

services_ok=true

# Check Ollama
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "✅ Ollama (port 11434) - Running"
else
    echo "❌ Ollama (port 11434) - Not accessible"
    services_ok=false
fi

# Check Coordinator
if curl -s http://localhost:8004/ > /dev/null 2>&1; then
    echo "✅ Coordinator API (port 8004) - Running"
else
    echo "❌ Coordinator API (port 8004) - Not accessible"
    services_ok=false
fi

# Check n8n
if curl -s http://localhost:5678 > /dev/null 2>&1; then
    echo "✅ n8n (port 5678) - Running"
else
    echo "❌ n8n (port 5678) - Not accessible"
    services_ok=false
fi

# Check TTS
if curl -s http://localhost:8001/docs > /dev/null 2>&1; then
    echo "✅ TTS (port 8001) - Running"
else
    echo "❌ TTS (port 8001) - Not accessible"
    services_ok=false
fi

# Check Animation
if curl -s http://localhost:8002/docs > /dev/null 2>&1; then
    echo "✅ Animation (port 8002) - Running"
else
    echo "❌ Animation (port 8002) - Not accessible"
    services_ok=false
fi

# Check Frontend
if curl -s http://localhost:8501 > /dev/null 2>&1; then
    echo "✅ Frontend (port 8501) - Running"
else
    echo "❌ Frontend (port 8501) - Not accessible"
    services_ok=false
fi

echo ""
echo "=========================================="
if [[ "$services_ok" == "true" ]]; then
    echo "✅ All Services Started!"
else
    echo "⚠️  Some services may need attention"
fi
echo "=========================================="
echo ""
echo "Service PIDs:"
echo "  - Ollama:          $(pgrep -f 'ollama serve' || echo 'not running')"
echo "  - Coordinator API:  $COORDINATOR_PID"
echo "  - n8n:             $N8N_PID"
echo "  - TTS:             $TTS_PID"
echo "  - Animation:       $ANIMATION_PID"
echo "  - Frontend:        $FRONTEND_PID"
echo ""
echo "To view logs:"
echo "  tail -f $LOGS_DIR/coordinator.log"
echo "  tail -f $LOGS_DIR/n8n.log"
echo "  tail -f $LOGS_DIR/tts.log"
echo "  tail -f $LOGS_DIR/animation.log"
echo "  tail -f $LOGS_DIR/frontend.log"
echo ""
echo "To stop all services:"
echo "  pkill -f 'ollama serve'"
echo "  pkill -f 'python.*coordinator/app.py'"
echo "  pkill -f 'n8n start'"
echo "  pkill -f 'python.*tts/app.py'"
echo "  pkill -f 'python.*animation/app.py'"
echo "  pkill -f 'streamlit run'"
echo ""
