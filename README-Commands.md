
<!-- Commands to connect the vast instance to cursor local host -->

cd ~/Nextwork-Teachers-TechMonkey

# Kill everything completely
echo "=== Stopping all services ==="
pkill -f "n8n start" || true
pkill -f streamlit || true
pkill -f "python.*tts" || true
pkill -f "python.*animation" || true
pkill -f "python.*frontend" || true
tmux kill-session -t ai-teacher 2>/dev/null || true

# Wait for everything to stop
sleep 3

# Verify everything is stopped
ps aux | grep -E "n8n|streamlit|python.*tts|python.*animation" | grep -v grep || echo "All stopped"

# Activate virtual environment
source /root/ai-teacher-venv/bin/activate

# Load environment variables from .env if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Set required environment variables
export N8N_BASIC_AUTH_ACTIVE=true
export N8N_BASIC_AUTH_USER="${N8N_USER:-sfitz911@gmail.com}"
export N8N_BASIC_AUTH_PASSWORD="${N8N_PASSWORD:-Delrio77$}"
export N8N_HOST="0.0.0.0"
export N8N_PORT=5678
export N8N_PROTOCOL=http
export WEBHOOK_URL="http://localhost:5678/"
export NODE_ENV=production

# Create logs directory
mkdir -p logs

# Start n8n
echo "=== Starting n8n ==="
nohup env NODE_ENV=production N8N_BASIC_AUTH_ACTIVE=true N8N_BASIC_AUTH_USER="sfitz911@gmail.com" N8N_BASIC_AUTH_PASSWORD="Delrio77$" N8N_HOST="0.0.0.0" N8N_PORT=5678 N8N_PROTOCOL=http WEBHOOK_URL="http://localhost:5678/" n8n start --port 5678 > logs/n8n.log 2>&1 &

# Start TTS service
echo "=== Starting TTS ==="
nohup python services/tts/app.py > logs/tts.log 2>&1 &

# Start Animation service
echo "=== Starting Animation ==="
export AVATAR_PATH="$PWD/services/animation/avatars"
mkdir -p services/animation/output
nohup python services/animation/app.py > logs/animation.log 2>&1 &

# Start Frontend
echo "=== Starting Frontend ==="
export N8N_WEBHOOK_URL='http://localhost:5678/webhook/chat-webhook'
export TTS_API_URL='http://localhost:8001'
export ANIMATION_API_URL='http://localhost:8002'
nohup streamlit run frontend/app.py --server.address 0.0.0.0 --server.port 8501 > logs/frontend.log 2>&1 &

# Wait for services to start
echo "=== Waiting for services to start ==="
sleep 8

# Check all services are running
echo "=== Service Status ==="
ps aux | grep -E "n8n|streamlit|python.*tts|python.*animation" | grep -v grep

# Test each service
echo "=== Testing Services ==="
curl -I http://localhost:5678 2>/dev/null | head -1 || echo "n8n: Not responding"
curl -I http://localhost:8501 2>/dev/null | head -1 || echo "Frontend: Not responding"
curl -I http://localhost:8001 2>/dev/null | head -1 || echo "TTS: Not responding"
curl -I http://localhost:8002 2>/dev/null | head -1 || echo "Animation: Not responding"

<!-- End of command -->


