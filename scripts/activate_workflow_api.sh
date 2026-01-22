#!/usr/bin/env bash
# Script to activate n8n workflow via API (no UI login needed)
# Usage: bash scripts/activate_workflow_api.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Get credentials
N8N_USER="${N8N_USER:-sfitz911@gmail.com}"
N8N_PASSWORD="${N8N_PASSWORD:-Delrio77$}"
N8N_API_KEY="${N8N_API_KEY:-}"
N8N_URL="http://localhost:5678"

# Get or create API key if not set
if [[ -z "$N8N_API_KEY" ]]; then
    N8N_API_KEY=$(bash scripts/get_or_create_api_key.sh 2>/dev/null || echo "")
    if [[ -n "$N8N_API_KEY" ]]; then
        export N8N_API_KEY
    fi
fi

echo "=========================================="
echo "Activating n8n Workflow via API"
echo "=========================================="
echo ""

# Test n8n connection
echo "Testing n8n connection..."
if ! curl -s -o /dev/null -w "%{http_code}" "$N8N_URL" | grep -q "200\|404"; then
    echo "❌ n8n is not accessible at $N8N_URL"
    echo "   Make sure n8n is running: ps aux | grep 'n8n start'"
    exit 1
fi
echo "✅ n8n is accessible"
echo ""

# Get workflows list
echo "Fetching workflows..."
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

if echo "$WORKFLOWS_JSON" | grep -q "Unauthorized\|401"; then
    echo "❌ Authentication failed. Check credentials in .env file"
    echo "   Expected: N8N_USER=$N8N_USER"
    exit 1
fi

# Check if we got valid JSON
if ! echo "$WORKFLOWS_JSON" | python3 -m json.tool > /dev/null 2>&1; then
    echo "❌ Failed to get workflows. Response:"
    echo "$WORKFLOWS_JSON" | head -5
    exit 1
fi

echo "✅ Successfully authenticated"
echo ""

# Find the workflow (try both names)
WORKFLOW_NAME=""
WORKFLOW_ID=""

# Try "Five Teacher" first
WORKFLOW_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for wf in data.get('data', []):
    if 'Five Teacher' in wf.get('name', ''):
        print(wf.get('id', ''))
        sys.exit(0)
" 2>/dev/null)

if [[ -n "$WORKFLOW_ID" ]]; then
    WORKFLOW_NAME="AI Virtual Classroom - Five Teacher Workflow"
    echo "Found workflow: $WORKFLOW_NAME (ID: $WORKFLOW_ID)"
else
    # Try "Dual Teacher"
    WORKFLOW_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for wf in data.get('data', []):
    if 'Dual Teacher' in wf.get('name', '') or 'AI Virtual Classroom' in wf.get('name', ''):
        print(wf.get('id', ''))
        sys.exit(0)
" 2>/dev/null)
    
    if [[ -n "$WORKFLOW_ID" ]]; then
        WORKFLOW_NAME="AI Virtual Classroom - Dual Teacher Workflow"
        echo "Found workflow: $WORKFLOW_NAME (ID: $WORKFLOW_ID)"
    fi
fi

if [[ -z "$WORKFLOW_ID" ]]; then
    echo "⚠️  No workflow found. Attempting to import automatically..."
    echo ""
    
    # Try to import the workflow automatically
    if bash scripts/import_and_activate_workflow.sh; then
        echo ""
        echo "✅ Workflow imported and activated! Re-running activation check..."
        # Re-fetch workflows to get the new ID
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
data = json.load(sys.stdin)
for wf in data.get('data', []):
    if 'Five Teacher' in wf.get('name', '') or 'AI Virtual Classroom' in wf.get('name', ''):
        print(wf.get('id', ''))
        sys.exit(0)
" 2>/dev/null)
        
        if [[ -n "$WORKFLOW_ID" ]]; then
            echo "✅ Found workflow after import (ID: $WORKFLOW_ID)"
            # Continue with activation below
        else
            echo "❌ Failed to find workflow after import"
            echo "Available workflows:"
            echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        print(f\"  - {wf.get('name', 'Unknown')} (ID: {wf.get('id', 'N/A')}, Active: {wf.get('active', False)})\")
except:
    print('  (Could not parse workflow list)')
" 2>/dev/null || echo "  (Could not list workflows)"
            exit 1
        fi
    else
        echo "❌ Failed to import workflow automatically"
        echo ""
        echo "Manual steps:"
        echo "   1. Go to http://localhost:5678"
        echo "   2. Import: n8n/workflows/five-teacher-workflow.json"
        echo ""
        echo "Available workflows:"
        echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        print(f\"  - {wf.get('name', 'Unknown')} (ID: {wf.get('id', 'N/A')}, Active: {wf.get('active', False)})\")
except:
    print('  (Could not parse workflow list)')
" 2>/dev/null || echo "  (Could not list workflows)"
        exit 1
    fi
fi

# Check if already active
IS_ACTIVE=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for wf in data.get('data', []):
    if wf.get('id') == '$WORKFLOW_ID':
        print('true' if wf.get('active', False) else 'false')
        sys.exit(0)
" 2>/dev/null)

if [[ "$IS_ACTIVE" == "true" ]]; then
    echo "✅ Workflow is already active!"
    exit 0
fi

# Activate the workflow
echo "Activating workflow..."
if [[ -n "$N8N_API_KEY" ]]; then
    ACTIVATE_RESPONSE=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -X POST \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/activate" 2>/dev/null)
else
    ACTIVATE_RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        -X POST \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/activate" 2>/dev/null)
fi

if echo "$ACTIVATE_RESPONSE" | grep -q "active.*true\|success"; then
    echo "✅ Workflow activated successfully!"
elif echo "$ACTIVATE_RESPONSE" | grep -q "already active"; then
    echo "✅ Workflow is already active!"
else
    echo "⚠️  Activation response:"
    echo "$ACTIVATE_RESPONSE" | head -10
    echo ""
    echo "Trying alternative activation method..."
    
    # Alternative: Update workflow with active=true
    if [[ -n "$N8N_API_KEY" ]]; then
        WORKFLOW_DATA=$(curl -s \
            -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            -H "Content-Type: application/json" \
            "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}" 2>/dev/null)
    else
        WORKFLOW_DATA=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
            -H "Content-Type: application/json" \
            "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}" 2>/dev/null)
    fi
    
    if echo "$WORKFLOW_DATA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
data['active'] = True
print(json.dumps(data))
" > /tmp/workflow_update.json 2>/dev/null; then
        if [[ -n "$N8N_API_KEY" ]]; then
            UPDATE_RESPONSE=$(curl -s \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                -X PUT \
                -H "Content-Type: application/json" \
                -d @/tmp/workflow_update.json \
                "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}" 2>/dev/null)
        else
            UPDATE_RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
                -X PUT \
                -H "Content-Type: application/json" \
                -d @/tmp/workflow_update.json \
                "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}" 2>/dev/null)
        fi
        
        if echo "$UPDATE_RESPONSE" | grep -q "\"active\":\s*true"; then
            echo "✅ Workflow activated via update method!"
        else
            echo "❌ Failed to activate workflow"
            echo "Response: $UPDATE_RESPONSE"
            exit 1
        fi
    else
        echo "❌ Failed to prepare workflow update"
        exit 1
    fi
fi

# Verify activation
echo ""
echo "Verifying activation..."
sleep 2
if [[ -n "$N8N_API_KEY" ]]; then
    VERIFY_RESPONSE=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}" 2>/dev/null)
else
    VERIFY_RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}" 2>/dev/null)
fi

IS_ACTIVE_NOW=$(echo "$VERIFY_RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print('true' if data.get('active', False) else 'false')
except:
    print('false')
" 2>/dev/null)

if [[ "$IS_ACTIVE_NOW" == "true" ]]; then
    echo "✅ Workflow is confirmed active!"
    echo ""
    echo "Testing webhook..."
    WEBHOOK_TEST=$(curl -s -X POST "${N8N_URL}/webhook/chat-webhook" \
        -H "Content-Type: application/json" \
        -d '{"message": "test", "timestamp": 1234567890}' 2>&1)
    
    if echo "$WEBHOOK_TEST" | grep -q "404\|not registered"; then
        echo "⚠️  Webhook still returning 404. This might be normal if workflow needs a moment to register."
        echo "   Try again in a few seconds or check n8n logs: tail -20 logs/n8n.log"
    else
        echo "✅ Webhook is responding!"
    fi
else
    echo "⚠️  Workflow activation may have failed. Check n8n logs: tail -20 logs/n8n.log"
fi

echo ""
echo "=========================================="
echo "Done!"
echo "=========================================="
