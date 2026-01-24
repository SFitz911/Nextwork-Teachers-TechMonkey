#!/usr/bin/env bash
# Check if n8n is running, start it if not
# Usage: bash scripts/check_and_start_n8n.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

SESSION="ai-teacher"
VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"

echo "=========================================="
echo "Check and Start n8n"
echo "=========================================="
echo ""

# Check if n8n is already running
if pgrep -f "n8n start" > /dev/null; then
    PID=$(pgrep -f "n8n start" | head -1)
    echo "✅ n8n process is running (PID: $PID)"
    
    # Check if it's accessible
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" 2>/dev/null | grep -q "200\|404"; then
        echo "✅ n8n is accessible on localhost:5678"
        exit 0
    else
        echo "⚠️  n8n process is running but not accessible"
        echo "   It may still be starting up..."
        echo "   Waiting 10 seconds..."
        sleep 10
        
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" 2>/dev/null | grep -q "200\|404"; then
            echo "✅ n8n is now accessible"
            exit 0
        else
            echo "❌ n8n is still not accessible"
            echo "   Check logs: tail -50 logs/n8n.log"
            exit 1
        fi
    fi
fi

echo "❌ n8n is NOT running"
echo ""
echo "Starting n8n..."

# Check if tmux session exists
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "   Using existing tmux session: $SESSION"
    
    # Check if n8n window exists
    if tmux list-windows -t "$SESSION" | grep -q "n8n"; then
        echo "   n8n window exists, checking if n8n is running in it..."
        # Try to start n8n in the existing window
    else
        echo "   Creating n8n window..."
        tmux new-window -t "$SESSION" -n n8n
    fi
else
    echo "   Creating new tmux session: $SESSION"
    tmux new-session -d -s "$SESSION" -n n8n
fi

# Load environment variables
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"

# Start n8n in tmux
echo "   Starting n8n in tmux..."
tmux send-keys -t "$SESSION":n8n C-c 2>/dev/null || true
sleep 2

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

echo "   Waiting for n8n to start..."
sleep 10

# Wait for n8n to be ready
MAX_WAIT=60
WAIT_COUNT=0
N8N_READY=false

while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" 2>/dev/null | grep -q "200\|404"; then
        N8N_READY=true
        break
    fi
    if [[ $((WAIT_COUNT % 10)) -eq 0 ]]; then
        echo "   Still waiting... ($WAIT_COUNT/$MAX_WAIT seconds)"
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

if [[ "$N8N_READY" == "true" ]]; then
    echo "✅ n8n is now running and accessible!"
    echo ""
    echo "To view n8n logs:"
    echo "  tmux attach -t $SESSION"
    echo "  (Press Ctrl+B, then 0 to go to n8n window)"
    echo ""
    echo "To detach from tmux: Press Ctrl+B, then D"
    exit 0
else
    echo "❌ n8n did not become ready within $MAX_WAIT seconds"
    echo ""
    echo "Check logs:"
    echo "  tail -50 logs/n8n.log"
    echo "  tmux attach -t $SESSION"
    exit 1
fi
