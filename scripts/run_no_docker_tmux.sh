#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

SESSION="ai-teacher"
VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"

if [[ ! -d "$VENV_DIR" ]]; then
  echo "❌ venv not found at $VENV_DIR. Run: bash scripts/deploy_no_docker.sh"
  exit 1
fi

if command -v tmux >/dev/null 2>&1; then
  true
else
  echo "❌ tmux not installed"
  exit 1
fi

# Load .env for n8n basic auth if present
if [[ -f ".env" ]]; then
  # shellcheck disable=SC2046
  export $(grep -v '^#' .env | xargs)
fi

# Use environment variables with sensible defaults (but prefer .env)
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"

mkdir -p logs

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "ℹ️ tmux session '$SESSION' already exists"
  exit 0
fi

echo "Creating tmux session '$SESSION'..."
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

# Window 3: Frontend
tmux new-window -t "$SESSION" -n frontend
tmux send-keys -t "$SESSION":frontend \
  "cd '$PROJECT_DIR' && source '$VENV_DIR/bin/activate' && \
   export N8N_WEBHOOK_URL='http://localhost:5678/webhook/chat-webhook' && \
   export TTS_API_URL='http://localhost:8001' && \
   export ANIMATION_API_URL='http://localhost:8002' && \
   streamlit run frontend/app.py --server.address 0.0.0.0 --server.port 8501 2>&1 | tee logs/frontend.log" C-m

echo "✅ Started. Attach with: tmux attach -t $SESSION"

