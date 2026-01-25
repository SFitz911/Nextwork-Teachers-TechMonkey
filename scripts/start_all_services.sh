#!/usr/bin/env bash
# Unified service startup with health checks and dependencies
# Usage: bash scripts/start_all_services.sh
#
# This script:
# 1. Starts Ollama (if not running)
# 2. Waits for Ollama to be ready
# 3. Starts Coordinator API, n8n, TTS, Animation, Frontend in tmux
# 4. Waits for n8n to be fully ready
# 5. Verifies all services are running

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Default API key (hardcoded fallback) - use if not in .env
if [[ -z "${N8N_API_KEY:-}" ]]; then
    export N8N_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI5ODg5NmQwZS00NWFhLTRiNmEtYTkwZi03ZTM0OWY4YjBmZTAiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MzY3MDM4LCJleHAiOjE3NzE5MDkyMDB9.nz4Uao_QXeIlxlC0Mw3rq6nl5MpLyuIL5_WE8YKHBck"
fi

SESSION="ai-teacher"
VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"

echo "=========================================="
echo "Starting All Services"
echo "=========================================="
echo ""

# Step 1: Start Ollama (if not running)
echo "Step 1: Starting Ollama..."
if ! pgrep -f "ollama serve" > /dev/null; then
    echo "   Ollama not running, starting..."
    mkdir -p logs
    nohup ollama serve > logs/ollama.log 2>&1 &
    sleep 5
    echo "✅ Ollama started"
else
    echo "✅ Ollama already running (PID: $(pgrep -f 'ollama serve'))"
fi

# Wait for Ollama to be ready
echo "   Waiting for Ollama to be ready..."
OLLAMA_READY=false
for i in {1..10}; do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        OLLAMA_READY=true
        break
    fi
    echo "   Attempt $i/10..."
    sleep 1
done

if [[ "$OLLAMA_READY" != "true" ]]; then
    echo "❌ Ollama did not become ready within 10 seconds"
    echo "   Check logs: tail -20 logs/ollama.log"
    exit 1
fi
echo "✅ Ollama is ready"

# Check if mistral:7b model is installed
echo "   Checking if mistral:7b model is installed..."
MODEL_INSTALLED=$(curl -s http://localhost:11434/api/tags | python3 -c "import json, sys; d=json.load(sys.stdin); models=[m.get('name') for m in d.get('models', [])]; print('yes' if 'mistral:7b' in models else 'no')" 2>/dev/null || echo "no")

if [[ "$MODEL_INSTALLED" != "yes" ]]; then
    echo "   ⚠️  mistral:7b model not found, installing..."
    echo "   This may take 5-10 minutes (model is ~4GB)..."
    ollama pull mistral:7b
    
    # Verify installation
    sleep 2
    MODEL_INSTALLED=$(curl -s http://localhost:11434/api/tags | python3 -c "import json, sys; d=json.load(sys.stdin); models=[m.get('name') for m in d.get('models', [])]; print('yes' if 'mistral:7b' in models else 'no')" 2>/dev/null || echo "no")
    
    if [[ "$MODEL_INSTALLED" == "yes" ]]; then
        echo "✅ mistral:7b model installed"
    else
        echo "❌ Failed to install mistral:7b model"
        echo "   You can install it manually: ollama pull mistral:7b"
    fi
else
    echo "✅ mistral:7b model is already installed"
fi
echo ""

# Step 2: Start other services in tmux
echo "Step 2: Starting Coordinator API, n8n, TTS, Animation, and Frontend..."
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "   Creating tmux session..."
    bash scripts/run_no_docker_tmux.sh
    echo "✅ Services started in tmux"
else
    echo "✅ Services already running in tmux session '$SESSION'"
fi
echo ""

# Step 3: Wait for n8n to be ready
echo "Step 3: Waiting for n8n to be ready..."
N8N_READY=false
MAX_WAIT=30
WAIT_COUNT=0

while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
    # Check if n8n HTTP server is responding
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" | grep -q "200\|404"; then
        # Check if API is responding (try both API key and basic auth)
        if [[ -n "${N8N_API_KEY:-}" ]]; then
            if curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
               "http://localhost:5678/api/v1/workflows" > /dev/null 2>&1; then
                N8N_READY=true
                break
            fi
        fi
        
        # Fallback to basic auth check
        if curl -s -u "${N8N_USER:-admin}:${N8N_PASSWORD:-changeme}" \
           "http://localhost:5678/api/v1/workflows" > /dev/null 2>&1; then
            N8N_READY=true
            break
        fi
    fi
    
    echo "   Waiting for n8n... ($WAIT_COUNT/$MAX_WAIT seconds)"
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

if [[ "$N8N_READY" != "true" ]]; then
    echo "❌ n8n did not become ready within $MAX_WAIT seconds"
    echo "   Check logs: tail -50 logs/n8n.log"
    echo "   Check tmux: tmux attach -t $SESSION"
    exit 1
fi
echo "✅ n8n is ready"
echo ""

# Step 4: Verify all services
echo "Step 4: Verifying all services..."
echo ""
if bash scripts/check_all_services_status.sh; then
    echo ""
    echo "=========================================="
    echo "✅ All services started and ready"
    echo "=========================================="
    echo ""
    echo "Services are available at:"
    echo "  coordinator: http://localhost:8004"
    echo "  n8n:         http://localhost:5678"
    echo "  frontend:    http://localhost:8501"
    echo "  TTS:         http://localhost:8001"
    echo "  animation:   http://localhost:8002"
    echo "  Ollama:      http://localhost:11434"
    echo ""
    echo "To attach to tmux session: tmux attach -t $SESSION"
    exit 0
else
    echo ""
    echo "❌ Some services are not running correctly"
    echo "   Check logs and tmux session for details"
    exit 1
fi
