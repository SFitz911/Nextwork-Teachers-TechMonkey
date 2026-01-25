#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "AI Teacher Classroom - NO DOCKER deploy"
echo "=========================================="

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if [[ ! -f "frontend/app.py" || ! -f "services/tts/app.py" || ! -f "services/animation/app.py" ]]; then
  echo "❌ This doesn't look like the repo root: $PROJECT_DIR"
  exit 1
fi

echo "📍 Repo: $PROJECT_DIR"

export DEBIAN_FRONTEND=noninteractive

echo ""
echo "Installing OS dependencies..."
apt-get update -y
apt-get install -y \
  ca-certificates curl git \
  python3 python3-venv python3-pip \
  ffmpeg libsndfile1 \
  tmux redis-server

echo ""
echo "Installing Node.js (v20) + n8n..."
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v || true)" != v20* ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

if ! command -v n8n >/dev/null 2>&1; then
  npm install -g n8n
fi

echo ""
echo "Setting up Python virtualenv..."
VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"
python3 -m venv "$VENV_DIR"
# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip

echo ""
echo "Installing Python deps (frontend + services)..."
pip install -r frontend/requirements.txt
pip install -r services/tts/requirements.txt
pip install -r services/animation/requirements.txt
pip install -r services/coordinator/requirements.txt
pip install -r services/longcat_video/requirements.txt

echo ""
echo "Creating local .env (for n8n auth) if missing..."
if [[ ! -f ".env" ]]; then
  N8N_PASSWORD="$(python - <<'PY'
import secrets
print(secrets.token_urlsafe(12))
PY
)"
  cat > .env <<EOF
N8N_USER=admin
N8N_PASSWORD=$N8N_PASSWORD
N8N_HOST=localhost
EOF
  echo "✅ Wrote .env"
fi

echo ""
echo "Setting up LongCat-Video avatar images (if LongCat-Video exists)..."
if [[ -d "LongCat-Video" ]] && [[ -d "Nextwork-Teachers" ]]; then
    mkdir -p "LongCat-Video/assets/avatars"
    bash scripts/fix_avatar_images.sh >/dev/null 2>&1 || echo "⚠️  Avatar image setup skipped (images may need manual setup)"
else
    echo "⚠️  LongCat-Video or Nextwork-Teachers not found - skipping avatar setup"
fi

echo ""
echo "Starting Redis (best-effort)..."
redis-server --daemonize yes >/dev/null 2>&1 || true

echo ""
echo "Starting all services in tmux..."
bash scripts/run_no_docker_tmux.sh

echo ""
echo "Waiting for services to start..."
sleep 5

echo ""
echo "🔄 Importing and activating n8n workflow..."
if bash scripts/import_and_activate_workflow.sh 2>&1; then
    echo "✅ Workflow imported and activated!"
else
    echo "⚠️  Workflow import/activation had issues"
    echo "   You can manually import: n8n/workflows/five-teacher-workflow.json"
fi

echo ""
echo "=========================================="
echo "✅ No-Docker deploy complete"
echo "=========================================="
echo ""
echo "Ports:"
echo "  n8n:       http://<host>:5678"
echo "  frontend:  http://<host>:8501"
echo "  TTS:       http://<host>:8001"
echo "  animation: http://<host>:8002"
echo ""
echo "To view logs: tmux attach -t ai-teacher"
echo "To stop:      tmux kill-session -t ai-teacher"

