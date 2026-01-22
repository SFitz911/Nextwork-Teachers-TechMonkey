#!/usr/bin/env bash
# Comprehensive webhook diagnostics - consolidated from multiple scripts
# Usage: bash scripts/diagnose_webhook.sh

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
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhNDE1ODkzYS1hY2Q2LTQ2NWYtODcyNS02NDQzZTRkNTkyZTkiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MDYxNjMwfQ.faRO3CRuldcSQd0-g9sJORo8tUq_vfMMDpOmXQTPH0I"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="${N8N_URL:-http://localhost:5678}"

echo "=========================================="
echo "Comprehensive Webhook Diagnostics"
echo "=========================================="
echo ""

# 1. Check services
echo "1. Checking services..."
bash scripts/check_all_services_status.sh
echo ""

# 2. Check workflow exists and is active
echo "2. Checking workflow..."
if [[ -n "$N8N_API_KEY" ]]; then
    WORKFLOWS_JSON=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null)
else
    WORKFLOWS_JSON=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null)
fi

WORKFLOW_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if 'Five Teacher' in wf.get('name', ''):
            print(wf.get('id', ''))
            print('active' if wf.get('active', False) else 'inactive')
            break
except:
    pass
" 2>/dev/null)

if [[ -z "$WORKFLOW_ID" ]]; then
    echo "❌ Workflow not found"
    echo "   Run: bash scripts/clean_and_import_workflow.sh"
else
    WORKFLOW_STATUS=$(echo "$WORKFLOW_ID" | tail -1)
    WORKFLOW_ID=$(echo "$WORKFLOW_ID" | head -1)
    echo "✅ Workflow found (ID: $WORKFLOW_ID, Status: $WORKFLOW_STATUS)"
    if [[ "$WORKFLOW_STATUS" != "active" ]]; then
        echo "   ⚠️  Workflow is not active"
    fi
fi
echo ""

# 3. Check recent executions
echo "3. Checking recent executions..."
if [[ -n "$N8N_API_KEY" ]]; then
    EXECUTIONS=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/executions?limit=5" 2>/dev/null)
else
    EXECUTIONS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        "${N8N_URL}/api/v1/executions?limit=5" 2>/dev/null)
fi

echo "$EXECUTIONS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    execs = data.get('data', [])[:5]
    if execs:
        print('Recent executions:')
        for e in execs:
            print(f\"  ID: {e.get('id', 'N/A')}, Status: {e.get('status', 'N/A')}, Finished: {e.get('finished', False)}\")
    else:
        print('No executions found')
except:
    print('Could not parse executions')
" 2>/dev/null
echo ""

# 4. Test webhook
echo "4. Testing webhook..."
WEBHOOK_TEST=$(curl -s -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": 1234567890}' \
    -w "\nHTTP_CODE:%{http_code}")

HTTP_CODE=$(echo "$WEBHOOK_TEST" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$WEBHOOK_TEST" | grep -v "HTTP_CODE:")

if [[ "$HTTP_CODE" == "200" ]]; then
    if [[ -n "$BODY" ]]; then
        echo "✅ Webhook is working"
        echo "   Response: $(echo "$BODY" | head -c 200)"
    else
        echo "⚠️  Webhook returned empty response"
        echo "   Check workflow execution in n8n UI"
    fi
else
    echo "❌ Webhook test failed (HTTP $HTTP_CODE)"
    echo "   Response: $BODY"
fi
echo ""

# 5. Recommendations
echo "5. Recommendations:"
if [[ -z "$WORKFLOW_ID" ]]; then
    echo "   → Import workflow: bash scripts/clean_and_import_workflow.sh"
elif [[ "$WORKFLOW_STATUS" != "active" ]]; then
    echo "   → Activate workflow in n8n UI or re-import"
fi

if [[ "$HTTP_CODE" != "200" ]] || [[ -z "$BODY" ]]; then
    echo "   → Check n8n UI: http://localhost:5678"
    echo "   → Check execution details: bash scripts/inspect_latest_execution.sh"
fi

echo ""
echo "=========================================="
echo "Diagnostics Complete"
echo "=========================================="
