#!/usr/bin/env bash
# Verify webhook is properly registered and activated
# Usage: bash scripts/verify_webhook_registration.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

N8N_URL="http://localhost:5678"
# Default API key (hardcoded fallback)
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI1MzE3fQ.tU1VEaQCrymcz8MIkAWuWfpBJoT9O7R8olTeBe42JJ0"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"

echo "=========================================="
echo "Verifying Webhook Registration"
echo "=========================================="
echo ""

# Get workflow ID
if [[ -n "$N8N_API_KEY" ]]; then
    WORKFLOWS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/workflows")
else
    WORKFLOWS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/workflows")
fi

WORKFLOW_ID=$(echo "$WORKFLOWS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for wf in data.get('data', []):
    if 'Five Teacher' in wf.get('name', ''):
        print(wf['id'])
        print(wf.get('active', False))
        break
" 2>/dev/null || echo "")

if [[ -z "$WORKFLOW_ID" ]]; then
    echo "❌ Five Teacher workflow not found"
    exit 1
fi

ACTIVE=$(echo "$WORKFLOW_ID" | tail -1)
WORKFLOW_ID=$(echo "$WORKFLOW_ID" | head -1)

echo "Workflow ID: $WORKFLOW_ID"
echo "Active: $ACTIVE"
echo ""

if [[ "$ACTIVE" != "True" ]]; then
    echo "❌ Workflow is NOT active!"
    echo "Activating workflow..."
    if [[ -n "$N8N_API_KEY" ]]; then
        curl -s -X POST -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/activate" > /dev/null
    else
        curl -s -X POST -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/activate" > /dev/null
    fi
    sleep 3
    echo "✅ Workflow activated"
    echo ""
fi

# Get workflow details to check webhook configuration
if [[ -n "$N8N_API_KEY" ]]; then
    WORKFLOW_DETAILS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}")
else
    WORKFLOW_DETAILS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}")
fi

echo "Checking webhook node configuration..."
echo "$WORKFLOW_DETAILS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
workflow = data.get('data', {})
nodes = workflow.get('nodes', [])

for node in nodes:
    if node.get('type') == 'n8n-nodes-base.webhook':
        params = node.get('parameters', {})
        print(f\"Webhook Node: {node.get('name', 'N/A')}\")
        print(f\"  Path: {params.get('path', 'N/A')}\")
        print(f\"  Method: {params.get('httpMethod', 'N/A')}\")
        print(f\"  Response Mode: {params.get('responseMode', 'N/A')}\")
        print(f\"  Webhook ID: {node.get('webhookId', 'N/A')}\")
        break
" 2>/dev/null || echo "Could not parse webhook configuration"

echo ""
echo "Testing webhook..."
echo ""

# Test with GET first (to see what error we get)
echo "Testing GET request (should fail):"
GET_RESPONSE=$(curl -s -X GET "${N8N_URL}/webhook/chat-webhook" 2>&1)
echo "$GET_RESPONSE" | head -5
echo ""

# Test with POST
echo "Testing POST request:"
POST_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": 1234567890}')

HTTP_CODE=$(echo "$POST_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$POST_RESPONSE" | grep -v "HTTP_CODE:")

echo "HTTP Status: $HTTP_CODE"
if [[ -n "$BODY" ]]; then
    echo "Response: $BODY"
else
    echo "Response: [EMPTY]"
fi

echo ""
if [[ "$HTTP_CODE" == "200" ]] && [[ -n "$BODY" ]]; then
    echo "✅ Webhook is working!"
elif [[ "$HTTP_CODE" == "404" ]] || [[ "$BODY" == *"not registered"* ]]; then
    echo "❌ Webhook is NOT registered for POST requests"
    echo ""
    echo "This usually means:"
    echo "  1. The workflow needs to be re-activated"
    echo "  2. The webhook node configuration is incorrect"
    echo "  3. n8n needs to be restarted to register the webhook"
    echo ""
    echo "Try:"
    echo "  1. Deactivate and reactivate the workflow in n8n UI"
    echo "  2. Or restart n8n: pkill -f 'n8n start' && bash scripts/run_no_docker_tmux.sh"
else
    echo "⚠️  Unexpected response"
fi
