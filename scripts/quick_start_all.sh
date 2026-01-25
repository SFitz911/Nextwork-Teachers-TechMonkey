#!/usr/bin/env bash
# Quick Start - Complete System Launch
# Starts ALL services including LongCat-Video
# Usage: bash scripts/quick_start_all.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

SESSION="ai-teacher"
VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"

echo "=========================================="
echo "Quick Start - Complete System Launch"
echo "=========================================="
echo ""
echo "This will start ALL services:"
echo "  ✅ Ollama (Mistral) - port 11434"
echo "  ✅ Coordinator API - port 8004"
echo "  ✅ n8n - port 5678"
echo "  ✅ TTS - port 8001"
echo "  ✅ Animation - port 8002"
echo "  ✅ LongCat-Video - port 8003"
echo "  ✅ Frontend - port 8501"
echo ""

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Step 1: Stop existing services
echo "Step 1: Stopping existing services..."
tmux kill-session -t "$SESSION" 2>/dev/null || true
pkill -f "ollama serve" 2>/dev/null || true
pkill -f "python.*longcat_video/app.py" 2>/dev/null || true
sleep 2
echo "✅ Existing services stopped"
echo ""

# Step 2: Start Ollama
echo "Step 2: Starting Ollama..."
if ! pgrep -f "ollama serve" > /dev/null; then
    mkdir -p logs
    nohup ollama serve > logs/ollama.log 2>&1 &
    sleep 5
    echo "✅ Ollama started"
else
    echo "✅ Ollama already running"
fi

# Wait for Ollama and check mistral:7b
echo "   Checking Ollama..."
for i in {1..10}; do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

MODEL_INSTALLED=$(curl -s http://localhost:11434/api/tags 2>/dev/null | python3 -c "import json, sys; d=json.load(sys.stdin); models=[m.get('name') for m in d.get('models', [])]; print('yes' if 'mistral:7b' in models else 'no')" 2>/dev/null || echo "no")

if [[ "$MODEL_INSTALLED" != "yes" ]]; then
    echo "   Installing mistral:7b model (this may take 5-10 minutes)..."
    ollama pull mistral:7b &
    echo "   ⚠️  Model download started in background"
else
    echo "✅ mistral:7b model is installed"
fi
echo ""

# Step 3: Create tmux session with all services
echo "Step 3: Starting all services in tmux..."
mkdir -p logs

# Check if venv exists
if [[ ! -d "$VENV_DIR" ]]; then
    echo "❌ Virtual environment not found. Run: bash scripts/deploy_no_docker.sh"
    exit 1
fi

# Verify critical dependencies are installed
echo "Verifying dependencies..."
source "$VENV_DIR/bin/activate"
if ! python -c "import httpx" 2>/dev/null; then
    echo "⚠️  Missing httpx dependency. Installing Coordinator API dependencies..."
    pip install -r services/coordinator/requirements.txt
fi
if ! python -c "import fastapi" 2>/dev/null; then
    echo "⚠️  Missing fastapi dependency. Installing service dependencies..."
    pip install -r services/coordinator/requirements.txt
    pip install -r services/longcat_video/requirements.txt
fi
deactivate

# Use environment variables with sensible defaults
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"

tmux new-session -d -s "$SESSION" -n n8n

# Window 0: n8n
tmux send-keys -t "$SESSION":n8n \
  "cd '$PROJECT_DIR' && source '$VENV_DIR/bin/activate' >/dev/null 2>&1 || true && \
   export NODE_ENV=production && \
   export N8N_BASIC_AUTH_ACTIVE=true && \
   export N8N_BASIC_AUTH_USER=\"${N8N_USER}\" && \
   export N8N_BASIC_AUTH_PASSWORD=\"${N8N_PASSWORD}\" && \
   export N8N_HOST=\"${N8N_HOST:-0.0.0.0}\" && \
   export N8N_PORT=5678 && \
   export N8N_PROTOCOL=http && \
   export WEBHOOK_URL=\"http://localhost:5678/\" && \
   n8n start --port 5678 2>&1 | tee logs/n8n.log" C-m

# Window 1: TTS
tmux new-window -t "$SESSION" -n tts
tmux send-keys -t "$SESSION":tts \
  "cd '$PROJECT_DIR' && source '$VENV_DIR/bin/activate' && \
   python services/tts/app.py 2>&1 | tee logs/tts.log" C-m

# Window 2: Animation
tmux new-window -t "$SESSION" -n animation
tmux send-keys -t "$SESSION":animation \
  "cd '$PROJECT_DIR' && source '$VENV_DIR/bin/activate' && \
   export AVATAR_PATH='$PROJECT_DIR/services/animation/avatars' && \
   mkdir -p '$PROJECT_DIR/services/animation/output' && \
   python services/animation/app.py 2>&1 | tee logs/animation.log" C-m

# Window 3: Coordinator API
tmux new-window -t "$SESSION" -n coordinator
tmux send-keys -t "$SESSION":coordinator \
  "cd '$PROJECT_DIR' && source '$VENV_DIR/bin/activate' && \
   python services/coordinator/app.py 2>&1 | tee logs/coordinator.log" C-m

# Window 4: LongCat-Video (NEW)
tmux new-window -t "$SESSION" -n longcat
LONGCAT_DIR="$PROJECT_DIR/LongCat-Video"
if [[ -d "$LONGCAT_DIR" ]] && [[ -f "$PROJECT_DIR/services/longcat_video/app.py" ]]; then
    # Ensure avatar images are set up before starting service
    echo "Setting up LongCat-Video avatar images..."
    mkdir -p "$LONGCAT_DIR/assets/avatars"
    if [[ -d "$PROJECT_DIR/Nextwork-Teachers" ]]; then
        bash "$PROJECT_DIR/scripts/fix_avatar_images.sh" >/dev/null 2>&1 || true
    fi
    
    tmux send-keys -t "$SESSION":longcat \
      "cd '$PROJECT_DIR' && \
       source \"\$(conda info --base)/etc/profile.d/conda.sh\" && \
       conda activate longcat-video && \
       export LONGCAT_VIDEO_DIR=\"$LONGCAT_DIR\" && \
       export CHECKPOINT_DIR=\"$LONGCAT_DIR/weights/LongCat-Video-Avatar\" && \
       export AVATAR_IMAGES_DIR=\"$LONGCAT_DIR/assets/avatars\" && \
       export OUTPUT_DIR=\"$PROJECT_DIR/outputs/longcat\" && \
       export CONDA_PREFIX=\"\$(conda info --base)/envs/longcat-video\" && \
       export CONDA_DEFAULT_ENV=\"longcat-video\" && \
       mkdir -p \"\$OUTPUT_DIR\" && \
       \$(which python) services/longcat_video/app.py 2>&1 | tee logs/longcat_video.log" C-m
    echo "✅ LongCat-Video service added to tmux"
else
    echo "⚠️  LongCat-Video not found - skipping (run: bash scripts/deploy_longcat_video.sh)"
    tmux send-keys -t "$SESSION":longcat "echo 'LongCat-Video not configured. Run: bash scripts/deploy_longcat_video.sh'" C-m
fi

# Window 5: Frontend
tmux new-window -t "$SESSION" -n frontend
tmux send-keys -t "$SESSION":frontend \
  "cd '$PROJECT_DIR' && source '$VENV_DIR/bin/activate' && \
   export COORDINATOR_API_URL='http://localhost:8004' && \
   export N8N_WEBHOOK_URL='http://localhost:5678/webhook/session/start' && \
   export TTS_API_URL='http://localhost:8001' && \
   export ANIMATION_API_URL='http://localhost:8002' && \
   export LONGCAT_API_URL='http://localhost:8003' && \
   streamlit run frontend/app.py --server.address 0.0.0.0 --server.port 8501 2>&1 | tee logs/frontend.log" C-m

echo "✅ All services started in tmux session '$SESSION'"
echo ""

# Step 4: Wait for services to be ready
echo "Step 4: Waiting for services to be ready..."
sleep 5

# Check services
echo ""
echo "Checking service status..."
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

# Check LongCat-Video
if curl -s http://localhost:8003/status > /dev/null 2>&1; then
    echo "✅ LongCat-Video (port 8003) - Running"
else
    echo "⚠️  LongCat-Video (port 8003) - Not accessible (may need setup)"
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
    echo "✅ Quick Start Complete!"
else
    echo "⚠️  Some services may need attention"
fi
echo "=========================================="
echo ""
echo "All services are running in tmux session: $SESSION"
echo ""
echo "Service URLs (on VAST instance):"
echo "  - Ollama:          http://localhost:11434"
echo "  - Coordinator API:  http://localhost:8004"
echo "  - n8n:             http://localhost:5678"
echo "  - TTS:             http://localhost:8001"
echo "  - Animation:       http://localhost:8002"
echo "  - LongCat-Video:   http://localhost:8003"
echo "  - Frontend:        http://localhost:8501"
echo ""
echo "To view logs:"
echo "  tmux attach -t $SESSION"
echo ""
echo "To check status:"
echo "  bash scripts/check_all_services_status.sh"
echo ""
echo "⚠️  IMPORTANT: Set up port forwarding from Desktop:"
echo "  .\connect-vast-simple.ps1"
echo ""
