#!/usr/bin/env bash
# Script to completely clean old workflows and import the correct Five Teacher workflow
# Usage: bash scripts/clean_and_import_workflow.sh

set -euo pipefail

# Source error handling if available
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/lib/error_handling.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/lib/error_handling.sh"
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Validate configuration first
if ! bash scripts/validate_config.sh 2>/dev/null; then
    echo ""
    echo "❌ Configuration validation failed"
    echo "   Run: bash scripts/validate_config.sh"
    echo ""
    provide_next_steps "config_invalid" || true
    exit 1
fi

# Use defaults from common.sh or .env
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"
N8N_API_KEY="${N8N_API_KEY:-}"
N8N_URL="${N8N_URL:-http://localhost:5678}"

# API key is required - validate_config.sh should have caught this, but double-check
if [[ -z "$N8N_API_KEY" ]]; then
    echo "❌ N8N_API_KEY is required but not set"
    echo "   Run: bash scripts/validate_config.sh"
    exit 1
fi

echo "=========================================="
echo "Cleaning and Importing Correct Workflow"
echo "=========================================="
echo ""

# Get all workflows - API key is required
echo "Fetching all workflows..."
WORKFLOWS_JSON=$(curl -s \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    -H "Content-Type: application/json" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null)

# Check if API key works
if echo "$WORKFLOWS_JSON" | grep -q "unauthorized\|401\|'X-N8N-API-KEY' header required"; then
    echo "❌ API key authentication failed"
    echo "Response: $(echo "$WORKFLOWS_JSON" | head -c 200)"
    echo ""
    echo "The API key in .env may be invalid or expired."
    echo "To fix:"
    echo "  1. Open http://localhost:5678 in your browser"
    echo "  2. Go to Settings → API"
    echo "  3. Create a new API key"
    echo "  4. Update .env: echo 'N8N_API_KEY=your_new_key_here' >> .env"
    exit 1
fi

echo "✅ API key authentication working"

# Backup existing workflows before deletion
BACKUP_DIR="$PROJECT_DIR/backups/workflows"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/workflow_backup_$(date +%Y%m%d_%H%M%S).json"

echo "Backing up existing workflows..."
if echo "$WORKFLOWS_JSON" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
    echo "$WORKFLOWS_JSON" > "$BACKUP_FILE"
    echo "✅ Workflows backed up to: $BACKUP_FILE"
else
    echo "⚠️  Could not backup workflows (invalid JSON response)"
fi
echo ""

# Delete all old workflows
echo "Deleting old workflows..."
ALL_WORKFLOW_IDS=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        print(wf.get('id', ''))
except:
    pass
" 2>/dev/null)

for WF_ID in $ALL_WORKFLOW_IDS; do
    if [[ -n "$WF_ID" ]]; then
        echo "   Deleting workflow $WF_ID..."
        curl -s -X DELETE \
            -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            -H "Content-Type: application/json" \
            "${N8N_URL}/api/v1/workflows/${WF_ID}" > /dev/null 2>&1 || true
    fi
done

echo "✅ All old workflows deleted"
echo ""

# Wait a moment
sleep 2

# Import the correct workflow
echo "Importing Five Teacher workflow..."
WORKFLOW_FILE="$PROJECT_DIR/n8n/workflows/five-teacher-workflow.json"
CLEANED_WORKFLOW="/tmp/five-teacher-workflow-cleaned.json"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
    echo "❌ Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

# Clean the workflow JSON (remove fields n8n API doesn't accept)
echo "Cleaning workflow JSON for API import..."
python3 << PYTHON
import json
import sys

with open('$WORKFLOW_FILE', 'r') as f:
    workflow = json.load(f)

# Keep only fields that n8n API accepts (tags is read-only, so exclude it)
cleaned = {
    "name": workflow.get("name", ""),
    "nodes": workflow.get("nodes", []),
    "connections": workflow.get("connections", {}),
    "settings": workflow.get("settings", {}),
    "staticData": workflow.get("staticData", {}),
}

with open('$CLEANED_WORKFLOW', 'w') as f:
    json.dump(cleaned, f, indent=2)

print("✅ Workflow cleaned")
PYTHON

# Import workflow - API key is required
echo "Importing workflow using API key..."
IMPORT_RESPONSE=$(curl -s \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d @"$CLEANED_WORKFLOW" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null)

# Get the new workflow ID
NEW_WORKFLOW_ID=$(echo "$IMPORT_RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    wf_id = data.get('id') or data.get('data', {}).get('id', '')
    if wf_id:
        print(wf_id)
except:
    pass
" 2>/dev/null)

if [[ -z "$NEW_WORKFLOW_ID" ]]; then
    # Try to find it by name
    sleep 2
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
    
    WORKFLOWS_JSON=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null)
    
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
fi

if [[ -z "$NEW_WORKFLOW_ID" ]]; then
    echo "❌ Failed to import workflow"
    echo "Response:"
    echo "$IMPORT_RESPONSE" | head -20
    echo ""
    echo "Attempting to restore from backup..."
    
    # Try to restore from most recent backup
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.json 2>/dev/null | head -1)
    if [[ -n "$LATEST_BACKUP" ]] && [[ -f "$LATEST_BACKUP" ]]; then
        echo "   Found backup: $LATEST_BACKUP"
        echo "   You may need to import workflow manually through n8n UI"
        echo "   Or check the backup file for workflow details"
    fi
    
    exit 1
fi

echo "✅ Workflow imported (ID: $NEW_WORKFLOW_ID)"

# Verify workflow was imported correctly
echo "Verifying workflow import..."
sleep 2
VERIFY_WORKFLOW=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if wf.get('id') == '$NEW_WORKFLOW_ID':
            name = wf.get('name', 'Unknown')
            active = wf.get('active', False)
            print(f'{name}|{active}')
            break
except:
    pass
" 2>/dev/null)

if [[ -n "$VERIFY_WORKFLOW" ]]; then
    WORKFLOW_NAME=$(echo "$VERIFY_WORKFLOW" | cut -d'|' -f1)
    WORKFLOW_ACTIVE=$(echo "$VERIFY_WORKFLOW" | cut -d'|' -f2)
    echo "✅ Workflow verified: $WORKFLOW_NAME (active: $WORKFLOW_ACTIVE)"
else
    echo "⚠️  Could not verify workflow import"
fi
echo ""

# Activate the workflow
echo "Activating workflow..."
sleep 2

ACTIVATE_RESPONSE=$(curl -s -X POST \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    -H "Content-Type: application/json" \
    "${N8N_URL}/api/v1/workflows/${NEW_WORKFLOW_ID}/activate" 2>/dev/null)

if echo "$ACTIVATE_RESPONSE" | grep -q "active.*true\|success"; then
    echo "✅ Workflow activated!"
else
    echo "⚠️  Activation response:"
    echo "$ACTIVATE_RESPONSE" | head -10
fi

# Wait for webhook to register
echo ""
echo "Waiting for webhook to register..."
sleep 5

# Test webhook multiple times
echo "Testing webhook..."
for i in {1..3}; do
    WEBHOOK_TEST=$(curl -s -X POST "${N8N_URL}/webhook/chat-webhook" \
        -H "Content-Type: application/json" \
        -d '{"message": "test", "timestamp": 1234567890}' 2>&1)
    
    if echo "$WEBHOOK_TEST" | grep -q "404\|not registered"; then
        echo "   Attempt $i: Still registering... (waiting 3 more seconds)"
        sleep 3
    else
        echo "✅ Webhook is working!"
        echo "   Response: $(echo "$WEBHOOK_TEST" | head -c 200)..."
        exit 0
    fi
done

echo "⚠️  Webhook may need more time to register"
echo "   Final response: $WEBHOOK_TEST"
echo ""
echo "Try testing again in 10-15 seconds, or check n8n UI: http://localhost:5678"
