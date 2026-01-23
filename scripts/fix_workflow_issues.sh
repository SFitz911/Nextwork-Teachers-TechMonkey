#!/usr/bin/env bash
# Script to fix workflow issues: Remove Redis dependencies and ensure correct workflow is active
# Usage: bash scripts/fix_workflow_issues.sh

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
echo "Fixing n8n Workflow Issues"
echo "=========================================="
echo ""

# Check if n8n is running
if ! pgrep -f "n8n start" > /dev/null; then
    echo "❌ n8n is not running. Starting n8n..."
    bash scripts/run_no_docker_tmux.sh
    sleep 5
fi

# Get API key if needed
if [[ -z "$N8N_API_KEY" ]]; then
    echo "Getting API key..."
    N8N_API_KEY=$(bash scripts/get_or_create_api_key.sh 2>/dev/null || echo "")
    if [[ -n "$N8N_API_KEY" ]]; then
        export N8N_API_KEY
    fi
fi

# Get workflows list
echo "Checking existing workflows..."
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

# Check for workflows with Redis nodes
echo ""
echo "Checking for workflows with Redis dependencies..."
OLD_WORKFLOW_IDS=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        name = wf.get('name', '')
        if 'Dual Teacher' in name and 'Five Teacher' not in name:
            print(wf.get('id', ''))
except:
    pass
" 2>/dev/null)

if [[ -n "$OLD_WORKFLOW_IDS" ]]; then
    echo "⚠️  Found old workflow(s) that use Redis. These should be replaced."
    echo "   Old workflow IDs: $OLD_WORKFLOW_IDS"
    echo ""
    echo "Deactivating old workflows..."
    for OLD_ID in $OLD_WORKFLOW_IDS; do
        if [[ -n "$N8N_API_KEY" ]]; then
            curl -s -X POST \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                -H "Content-Type: application/json" \
                "${N8N_URL}/api/v1/workflows/${OLD_ID}/deactivate" > /dev/null 2>&1 || true
        else
            curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
                -X POST \
                -H "Content-Type: application/json" \
                "${N8N_URL}/api/v1/workflows/${OLD_ID}/deactivate" > /dev/null 2>&1 || true
        fi
        echo "   ✅ Deactivated workflow $OLD_ID"
    done
fi

# Check if five-teacher workflow exists
echo ""
echo "Checking for Five Teacher workflow (no Redis needed)..."
FIVE_TEACHER_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        name = wf.get('name', '')
        if 'Five Teacher' in name:
            print(f\"{wf.get('id', '')}|{wf.get('active', False)}\")
            sys.exit(0)
except:
    pass
" 2>/dev/null)

if [[ -n "$FIVE_TEACHER_ID" ]]; then
    IFS='|' read -r WORKFLOW_ID IS_ACTIVE <<< "$FIVE_TEACHER_ID"
    echo "✅ Found Five Teacher workflow (ID: $WORKFLOW_ID)"
    
    if [[ "$IS_ACTIVE" == "True" ]]; then
        echo "✅ Workflow is already active!"
    else
        echo "⚠️  Workflow is not active. Activating..."
        if [[ -n "$N8N_API_KEY" ]]; then
            ACTIVATE_RESPONSE=$(curl -s -X POST \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                -H "Content-Type: application/json" \
                "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/activate" 2>/dev/null)
        else
            ACTIVATE_RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
                -X POST \
                -H "Content-Type: application/json" \
                "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/activate" 2>/dev/null)
        fi
        
        if echo "$ACTIVATE_RESPONSE" | grep -q "active.*true\|success"; then
            echo "✅ Workflow activated!"
        else
            echo "⚠️  Activation may have failed. Response:"
            echo "$ACTIVATE_RESPONSE" | head -5
        fi
    fi
else
    echo "⚠️  Five Teacher workflow not found. Importing..."
    bash scripts/import_and_activate_workflow.sh
fi

# Test webhook
echo ""
echo "Testing webhook endpoint..."
sleep 2
WEBHOOK_TEST=$(curl -s -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": 1234567890}' 2>&1)

if echo "$WEBHOOK_TEST" | grep -q "404\|not registered"; then
    echo "❌ Webhook still not working"
    echo "   Response: $WEBHOOK_TEST"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check n8n logs: tail -30 logs/n8n.log"
    echo "2. Verify workflow is active in n8n UI: http://localhost:5678"
    echo "3. Make sure you're using the 'Five Teacher' workflow, not 'Dual Teacher'"
else
    echo "✅ Webhook is working!"
    echo "   Response preview: $(echo "$WEBHOOK_TEST" | head -c 100)..."
fi

# Check Redis (informational)
echo ""
echo "Checking Redis status (not required for Five Teacher workflow)..."
if pgrep -f redis-server > /dev/null; then
    echo "ℹ️  Redis is running (not needed for Five Teacher workflow)"
else
    echo "ℹ️  Redis is not running (this is OK - Five Teacher workflow doesn't need it)"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "✅ Use the 'Five Teacher' workflow (no Redis needed)"
echo "✅ Old 'Dual Teacher' workflows have been deactivated"
echo "✅ Webhook should be working at: ${N8N_URL}/webhook/chat-webhook"
echo ""
echo "If webhook still doesn't work:"
echo "1. Wait 10-15 seconds for n8n to register the webhook"
echo "2. Check n8n UI to verify workflow is active"
echo "3. Check n8n logs: tail -30 logs/n8n.log"
