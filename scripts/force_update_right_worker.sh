#!/usr/bin/env bash
# Force update Right Worker workflow by deleting old and importing new
# Usage: bash scripts/force_update_right_worker.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Default API key (hardcoded fallback)
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI1MzE3fQ.tU1VEaQCrymcz8MIkAWuWfpBJoT9O7R8olTeBe42JJ0"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="${N8N_URL:-http://localhost:5678}"

WORKFLOW_FILE="$PROJECT_DIR/n8n/workflows/right-worker-workflow.json"
WORKFLOW_NAME="Right Worker - Teacher Pipeline"

echo "=========================================="
echo "Force Update Right Worker Workflow"
echo "=========================================="
echo ""

# Check if n8n is accessible
if ! curl -s -o /dev/null -w "%{http_code}" "$N8N_URL" | grep -q "200\|404"; then
    echo "❌ n8n is not accessible at $N8N_URL"
    echo "   Make sure n8n is running"
    exit 1
fi

# Check if workflow file exists
if [[ ! -f "$WORKFLOW_FILE" ]]; then
    echo "❌ Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

echo "Step 1: Finding existing 'Right Worker' workflows..."
WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')

# Find all workflows with the name
EXISTING_IDS=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    ids = []
    for wf in data.get('data', []):
        if '$WORKFLOW_NAME' in wf.get('name', ''):
            ids.append(wf.get('id', ''))
    print(' '.join(ids))
except:
    print('')
" 2>/dev/null || echo "")

if [[ -n "$EXISTING_IDS" ]]; then
    echo "   Found existing workflow(s), deleting..."
    for wf_id in $EXISTING_IDS; do
        if [[ -n "$wf_id" ]]; then
            # Deactivate first
            curl -s -X POST \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${wf_id}/deactivate" > /dev/null 2>&1 || true
            
            # Delete workflow
            DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" \
                -X DELETE \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${wf_id}" 2>/dev/null)
            
            HTTP_CODE=$(echo "$DELETE_RESPONSE" | tail -1)
            if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "204" ]]; then
                echo "   ✅ Deleted workflow ID: $wf_id"
            else
                echo "   ⚠️  Failed to delete workflow ID: $wf_id (HTTP $HTTP_CODE)"
            fi
        fi
    done
    echo "   Waiting 2 seconds..."
    sleep 2
else
    echo "   No existing workflows found"
fi

echo ""
echo "Step 2: Importing new workflow..."

# Clean workflow JSON for import (remove n8n-specific fields)
CLEANED_WORKFLOW=$(python3 <<EOF
import json, sys
try:
    with open('$WORKFLOW_FILE', 'r') as f:
        workflow = json.load(f)
    
    # Only include fields that n8n API accepts for import
    cleaned = {
        "name": workflow.get("name", "$WORKFLOW_NAME"),
        "nodes": workflow.get("nodes", []),
        "connections": workflow.get("connections", {}),
        "settings": workflow.get("settings", {}),
        "staticData": workflow.get("staticData", {}),
    }
    
    # Remove node IDs and other fields that might cause issues
    for node in cleaned.get("nodes", []):
        node.pop("id", None)
        node.pop("webhookId", None)
    
    print(json.dumps(cleaned))
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
EOF
)

if [[ "$CLEANED_WORKFLOW" == *"ERROR"* ]]; then
    echo "❌ Failed to clean workflow JSON"
    echo "$CLEANED_WORKFLOW"
    exit 1
fi

CLEANED_FILE="/tmp/right_worker_import_$$.json"
echo "$CLEANED_WORKFLOW" > "$CLEANED_FILE"

# Import workflow
IMPORT_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    -H "Content-Type: application/json" \
    -d @"$CLEANED_FILE" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null)

HTTP_CODE=$(echo "$IMPORT_RESPONSE" | tail -1)
IMPORT_BODY=$(echo "$IMPORT_RESPONSE" | head -n -1)

rm -f "$CLEANED_FILE" 2>/dev/null

if [[ "$HTTP_CODE" != "200" ]] && [[ "$HTTP_CODE" != "201" ]]; then
    echo "❌ Failed to import workflow (HTTP $HTTP_CODE)"
    echo "Response:"
    echo "$IMPORT_BODY" | head -20
    exit 1
fi

# Get workflow ID
NEW_WORKFLOW_ID=$(echo "$IMPORT_BODY" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    wf_id = data.get('id') or data.get('data', {}).get('id', '')
    if wf_id:
        print(wf_id)
except:
    pass
" 2>/dev/null || echo "")

if [[ -z "$NEW_WORKFLOW_ID" ]]; then
    echo "⚠️  Workflow imported but couldn't get ID"
    echo "Response:"
    echo "$IMPORT_BODY" | head -10
else
    echo "✅ Workflow imported successfully (ID: $NEW_WORKFLOW_ID)"
fi

echo ""
echo "Step 3: Activating workflow..."
ACTIVATE_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"active": true}' \
    "${N8N_URL}/api/v1/workflows/${NEW_WORKFLOW_ID}/activate" 2>/dev/null)

ACTIVATE_CODE=$(echo "$ACTIVATE_RESPONSE" | tail -1)

if [[ "$ACTIVATE_CODE" == "200" ]]; then
    echo "✅ Workflow activated!"
else
    echo "⚠️  Could not activate workflow (HTTP $ACTIVATE_CODE)"
    echo "   You may need to activate it manually in n8n UI"
fi

echo ""
echo "=========================================="
echo "✅ Right Worker Workflow Updated!"
echo "=========================================="
echo ""
echo "Workflow is now available in n8n:"
echo "  $N8N_URL"
echo ""
echo "Workflow ID: $NEW_WORKFLOW_ID"
echo ""
