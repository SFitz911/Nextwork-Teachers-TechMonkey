#!/usr/bin/env bash
# Complete restart script: Start all services, import workflow, verify everything works
# Usage: bash scripts/restart_and_setup.sh
#
# This script:
# 1. Checks if services are running, starts them if not
# 2. Waits for n8n to be fully ready
# 3. Imports and activates the workflow
# 4. Verifies everything is working
#
# Run this after a VAST instance restart to get everything back up and running.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"
SESSION="ai-teacher"

echo "=========================================="
echo "Complete Restart and Setup"
echo "=========================================="
echo ""

# Step 1: Check if services are running
echo "Step 1: Checking service status..."
bash scripts/check_all_services_status.sh

echo ""
echo "Step 2: Starting services if needed..."

# Check if tmux session exists
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Starting services in tmux..."
    bash scripts/run_no_docker_tmux.sh
    
    # Start Ollama if not running
    if ! pgrep -f "ollama serve" > /dev/null; then
        echo "Starting Ollama..."
        nohup ollama serve > logs/ollama.log 2>&1 &
        sleep 3
    fi
else
    echo "✅ Services already running in tmux session"
fi

echo ""
echo "Step 3: Waiting for n8n to be ready..."

# Wait for n8n to be fully ready (can take 10-20 seconds)
MAX_WAIT=30
WAIT_COUNT=0
N8N_READY=false

while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" | grep -q "200\|404"; then
        # Check if API is responding
        if curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY:-}" "http://localhost:5678/api/v1/workflows" > /dev/null 2>&1 || \
           curl -s -u "${N8N_USER:-admin}:${N8N_PASSWORD:-changeme}" "http://localhost:5678/api/v1/workflows" > /dev/null 2>&1; then
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
    exit 1
fi

echo "✅ n8n is ready"
echo ""

# Step 4: Import and activate workflow
echo "Step 4: Importing and activating workflow..."

# Check if API key is set
if [[ -z "${N8N_API_KEY:-}" ]]; then
    echo "⚠️  N8N_API_KEY not set in .env"
    echo "   The workflow import will try to use basic auth"
    echo "   For better reliability, add N8N_API_KEY to .env"
    echo ""
fi

if bash scripts/clean_and_import_workflow.sh; then
    echo "✅ Workflow imported and activated"
else
    echo "❌ Failed to import workflow"
    echo "   You may need to import it manually through the n8n UI"
    exit 1
fi

echo ""
echo "Step 5: Verifying everything works..."

# Check services again
echo ""
echo "Service Status:"
bash scripts/check_all_services_status.sh

# Test webhook
echo ""
echo "Testing webhook..."
WEBHOOK_TEST=$(curl -s -X POST "http://localhost:5678/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": 1234567890}' \
    -w "\nHTTP_CODE:%{http_code}")

HTTP_CODE=$(echo "$WEBHOOK_TEST" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$WEBHOOK_TEST" | grep -v "HTTP_CODE:")

if [[ "$HTTP_CODE" == "200" ]]; then
    if [[ -n "$BODY" ]]; then
        echo "✅ Webhook is working!"
    else
        echo "⚠️  Webhook responded but returned empty body"
        echo "   This might be normal if the workflow is still processing"
    fi
else
    echo "⚠️  Webhook test returned HTTP $HTTP_CODE"
    echo "   Check workflow activation in n8n UI"
fi

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Services are available at:"
echo "  n8n:       http://localhost:5678"
echo "  frontend:  http://localhost:8501"
echo "  TTS:       http://localhost:8001"
echo "  animation: http://localhost:8002"
echo ""
echo "Next steps:"
echo "  1. Set up SSH port forwarding on your Desktop: .\connect-vast.ps1"
echo "  2. Open http://localhost:8501 to use the frontend"
echo "  3. Check n8n UI at http://localhost:5678 to verify workflow is active"
echo ""
