#!/usr/bin/env bash
# Fix workflow references after deleting and re-importing
# Usage: bash scripts/fix_workflow_references.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"
N8N_API_KEY="${N8N_API_KEY:-}"
N8N_URL="http://localhost:5678"

# Get API key if needed
if [[ -z "$N8N_API_KEY" ]]; then
    N8N_API_KEY=$(bash scripts/get_or_create_api_key.sh 2>/dev/null || echo "")
    if [[ -n "$N8N_API_KEY" ]]; then
        export N8N_API_KEY
    fi
fi

echo "=========================================="
echo "Fixing Workflow References"
echo "=========================================="
echo ""

# Get current workflow
if [[ -n "$N8N_API_KEY" ]]; then
    WORKFLOWS_JSON=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null)
else
    WORKFLOWS_JSON=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null)
fi

NEW_WORKFLOW_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if 'Five Teacher' in wf.get('name', ''):
            print(wf.get('id', ''))
            sys.exit(0)
except:
    pass
" 2>/dev/null)

if [[ -z "$NEW_WORKFLOW_ID" ]]; then
    echo "❌ Five Teacher workflow not found"
    exit 1
fi

echo "✅ Found workflow (ID: $NEW_WORKFLOW_ID)"
echo ""

# Deactivate and reactivate to refresh webhook registration
echo "Refreshing workflow activation..."
if [[ -n "$N8N_API_KEY" ]]; then
    curl -s -X POST \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${NEW_WORKFLOW_ID}/deactivate" > /dev/null 2>&1 || true
    sleep 2
    curl -s -X POST \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${NEW_WORKFLOW_ID}/activate" > /dev/null 2>&1
else
    curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        -X POST \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${NEW_WORKFLOW_ID}/deactivate" > /dev/null 2>&1 || true
    sleep 2
    curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        -X POST \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${NEW_WORKFLOW_ID}/activate" > /dev/null 2>&1
fi

echo "✅ Workflow reactivated"
echo ""

# Wait for webhook to re-register
echo "Waiting for webhook to re-register..."
sleep 5

# Test webhook
echo "Testing webhook..."
WEBHOOK_TEST=$(curl -s -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": 1234567890}' 2>&1)

if echo "$WEBHOOK_TEST" | grep -q "404\|not registered\|error"; then
    echo "⚠️  Webhook still has issues"
    echo "   Response: $WEBHOOK_TEST"
    echo ""
    echo "Try restarting n8n to clear cached references:"
    echo "   pkill -f 'n8n start'"
    echo "   # Then restart with: bash scripts/run_no_docker_tmux.sh"
else
    if [[ -n "$WEBHOOK_TEST" ]]; then
        echo "✅ Webhook is working!"
        echo "   Response preview: $(echo "$WEBHOOK_TEST" | head -c 100)..."
    else
        echo "⚠️  Webhook responded but with empty body"
        echo "   This means the workflow is executing but not returning data"
    fi
fi

echo ""
echo "If issues persist, restart n8n to clear all cached references."
