#!/usr/bin/env bash
# Script to check webhook configuration and wait for it to register
# Usage: bash scripts/check_and_fix_webhook.sh

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
# Default API key (hardcoded fallback)
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmNzRkZjc2OC0wZTVhLTQ2OGQtODFiYS1iYTZiMGFiNjAwY2EiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MTQzMDY3fQ.JQU3yyBofIJBX-50Zjdc9GnW7xLMf1QcZrVlgJ-OdbA"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="http://localhost:5678"

echo "=========================================="
echo "Checking Webhook Configuration"
echo "=========================================="
echo ""

# Get the workflow
echo "Finding Five Teacher workflow..."
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

WORKFLOW_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
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

if [[ -z "$WORKFLOW_ID" ]]; then
    echo "❌ Five Teacher workflow not found"
    exit 1
fi

echo "✅ Found workflow (ID: $WORKFLOW_ID)"
echo ""

# Get workflow details
echo "Checking workflow details..."
if [[ -n "$N8N_API_KEY" ]]; then
    WORKFLOW_DETAILS=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}" 2>/dev/null)
else
    WORKFLOW_DETAILS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}" 2>/dev/null)
fi

# Check if workflow is active
IS_ACTIVE=$(echo "$WORKFLOW_DETAILS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print('true' if data.get('active', False) else 'false')
except:
    print('false')
" 2>/dev/null)

if [[ "$IS_ACTIVE" != "true" ]]; then
    echo "⚠️  Workflow is not active. Activating..."
    if [[ -n "$N8N_API_KEY" ]]; then
        curl -s -X POST \
            -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            -H "Content-Type: application/json" \
            "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/activate" > /dev/null 2>&1
    else
        curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
            -X POST \
            -H "Content-Type: application/json" \
            "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/activate" > /dev/null 2>&1
    fi
    sleep 3
    echo "✅ Workflow activated"
else
    echo "✅ Workflow is active"
fi

# Check webhook node configuration
echo ""
echo "Checking webhook node configuration..."
WEBHOOK_NODE=$(echo "$WORKFLOW_DETAILS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for node in data.get('nodes', []):
        if node.get('type') == 'n8n-nodes-base.webhook':
            print(json.dumps(node))
            sys.exit(0)
except:
    pass
" 2>/dev/null)

if [[ -n "$WEBHOOK_NODE" ]]; then
    echo "✅ Webhook node found"
    WEBHOOK_ID=$(echo "$WEBHOOK_NODE" | python3 -c "import json, sys; print(json.load(sys.stdin).get('parameters', {}).get('path', ''))" 2>/dev/null || echo "")
    echo "   Webhook ID: chat-webhook"
else
    echo "⚠️  Webhook node not found in workflow"
fi

# Wait and test webhook multiple times
echo ""
echo "Testing webhook (this may take up to 30 seconds)..."
for i in {1..10}; do
    WEBHOOK_TEST=$(curl -s -X POST "${N8N_URL}/webhook/chat-webhook" \
        -H "Content-Type: application/json" \
        -d '{"message": "test", "timestamp": 1234567890}' 2>&1)
    
    if echo "$WEBHOOK_TEST" | grep -q "404\|not registered"; then
        echo "   Attempt $i/10: Still registering... (waiting 3 seconds)"
        sleep 3
    else
        echo "✅ Webhook is working!"
        echo "   Response: $(echo "$WEBHOOK_TEST" | head -c 200)..."
        exit 0
    fi
done

echo ""
echo "⚠️  Webhook still not responding after 30 seconds"
echo ""
echo "Troubleshooting:"
echo "1. Check n8n logs: tail -50 logs/n8n.log"
echo "2. Verify workflow is active in n8n UI: http://localhost:5678"
echo "3. Check webhook node configuration in the workflow"
echo "4. Try restarting n8n: pkill -f 'n8n start'; sleep 2; bash scripts/run_no_docker_tmux.sh"
echo ""
echo "Final webhook response:"
echo "$WEBHOOK_TEST"
