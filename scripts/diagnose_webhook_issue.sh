#!/usr/bin/env bash
# ⚠️  DEPRECATED: Use scripts/diagnose_webhook.sh instead
# Script to diagnose webhook issues - check workflow, test execution, check logs
# Usage: bash scripts/diagnose_webhook_issue.sh

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
echo "Diagnosing Webhook Issue"
echo "=========================================="
echo ""

# Get workflow
echo "1. Checking workflow configuration..."
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
    echo "❌ Five Teacher workflow not found!"
    echo "   Run: bash scripts/clean_and_import_workflow.sh"
    exit 1
fi

echo "✅ Found workflow (ID: $WORKFLOW_ID)"
echo ""

# Get workflow details
echo "2. Checking if workflow has 'Respond to Webhook' node..."
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

HAS_RESPOND_NODE=$(echo "$WORKFLOW_DETAILS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for node in data.get('nodes', []):
        if node.get('type') == 'n8n-nodes-base.respondToWebhook':
            print('true')
            sys.exit(0)
    print('false')
except:
    print('false')
" 2>/dev/null)

if [[ "$HAS_RESPOND_NODE" == "true" ]]; then
    echo "✅ Workflow has 'Respond to Webhook' node"
else
    echo "❌ Workflow is MISSING 'Respond to Webhook' node!"
    echo "   The workflow needs to be re-imported with the latest version"
    echo "   Run: bash scripts/clean_and_import_workflow.sh"
    exit 1
fi

# Check if active
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

echo ""
echo "3. Testing webhook and checking execution..."
echo ""

# Test webhook
WEBHOOK_RESPONSE=$(curl -s -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": 1234567890}' 2>&1)

echo "Webhook response:"
echo "$WEBHOOK_RESPONSE"
echo ""

# Check if it's valid JSON
if echo "$WEBHOOK_RESPONSE" | python3 -m json.tool > /dev/null 2>&1; then
    echo "✅ Response is valid JSON"
else
    echo "❌ Response is NOT valid JSON"
    if [[ -z "$WEBHOOK_RESPONSE" ]]; then
        echo "   Response is EMPTY (this is the problem!)"
    else
        echo "   Response content: $WEBHOOK_RESPONSE"
    fi
fi

echo ""
echo "4. Checking recent n8n execution logs..."
echo ""

# Get recent executions
if [[ -n "$N8N_API_KEY" ]]; then
    EXECUTIONS=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1" 2>/dev/null)
else
    EXECUTIONS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1" 2>/dev/null)
fi

LAST_EXECUTION=$(echo "$EXECUTIONS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if data.get('data') and len(data['data']) > 0:
        exec_data = data['data'][0]
        print(f\"ID: {exec_data.get('id', 'N/A')}\")
        print(f\"Status: {exec_data.get('finished', False)}\")
        print(f\"Mode: {exec_data.get('mode', 'N/A')}\")
        if exec_data.get('finished'):
            print(f\"Success: {exec_data.get('finished', False)}\")
except:
    print('No executions found or error parsing')
" 2>/dev/null)

if [[ -n "$LAST_EXECUTION" ]]; then
    echo "$LAST_EXECUTION"
else
    echo "⚠️  No recent executions found"
    echo "   The workflow might not be triggering"
fi

echo ""
echo "5. Checking n8n logs for errors..."
echo ""
echo "Last 20 lines of n8n.log:"
tail -20 logs/n8n.log 2>/dev/null || echo "   Log file not found"

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "If the workflow is missing 'Respond to Webhook' node:"
echo "  Run: bash scripts/clean_and_import_workflow.sh"
echo ""
echo "If the workflow has the node but still returns empty:"
echo "  1. Check n8n UI: http://localhost:5678"
echo "  2. Open the workflow and check for execution errors"
echo "  3. Test the workflow manually in n8n UI"
echo "  4. Check if Ollama is running: curl http://localhost:11434/api/tags"
