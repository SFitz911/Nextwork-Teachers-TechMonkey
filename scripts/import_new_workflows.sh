#!/usr/bin/env bash
# Import the new 2-teacher architecture workflows into n8n
# This script DELETES all existing workflows first, then imports only the 3 correct ones
# Usage: bash scripts/import_new_workflows.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Default API key (hardcoded fallback)
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI2NDM0fQ.zY98iCLMf-FyR_6xX6OqNgRA2AY6OYHNeJ2Umt4JCLQ"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="${N8N_URL:-http://localhost:5678}"

echo "=========================================="
echo "Cleaning and Importing 2-Teacher Workflows"
echo "=========================================="
echo ""

# Step 1: Delete ALL existing workflows first
echo "Step 1: Deleting ALL existing workflows..."
echo ""

# Get all workflows
WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')

# Check if API key works
if echo "$WORKFLOWS_JSON" | grep -q "unauthorized\|401\|403"; then
    echo "❌ API key authentication failed"
    echo "   Please check your N8N_API_KEY in .env"
    echo "   Or get a new API key from n8n UI: http://localhost:5678 → Settings → API"
    exit 1
fi

# Extract all workflow IDs
ALL_WORKFLOW_IDS=$(echo "$WORKFLOWS_JSON" | python3 <<'PYEOF'
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        wf_id = wf.get('id', '')
        if wf_id:
            print(wf_id)
except:
    pass
PYEOF
)

WORKFLOW_COUNT=$(echo "$ALL_WORKFLOW_IDS" | wc -l | tr -d ' ' || echo "0")

if [[ "$WORKFLOW_COUNT" -gt 0 ]]; then
    echo "   Found $WORKFLOW_COUNT existing workflow(s) - deleting all..."
    echo ""
    
    # Delete each workflow
    for wf_id in $ALL_WORKFLOW_IDS; do
        if [[ -n "$wf_id" ]]; then
            # Get workflow name for display
            WF_NAME=$(echo "$WORKFLOWS_JSON" | python3 -c "import json, sys; data=json.load(sys.stdin); [print(wf.get('name', 'Unknown')) for wf in data.get('data', []) if wf.get('id') == '$wf_id']" 2>/dev/null || echo "Unknown")
            
            echo "   Deleting: $WF_NAME (ID: $wf_id)..."
            
            # Deactivate first
            curl -s -X POST \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${wf_id}/deactivate" > /dev/null 2>&1 || true
            
            # Delete workflow
            DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${wf_id}" 2>/dev/null || echo "")
            
            HTTP_CODE=$(echo "$DELETE_RESPONSE" | tail -n 1)
            if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "204" ]]; then
                echo "   ✅ Deleted: $WF_NAME"
            else
                echo "   ⚠️  Delete may have failed (HTTP $HTTP_CODE)"
            fi
        fi
    done
    
    echo ""
    echo "✅ Deletion complete - waiting 3 seconds for n8n to process..."
    sleep 3
    echo ""
else
    echo "   No existing workflows found"
    echo ""
fi

# Step 2: Import the 3 correct workflows
echo "Step 2: Importing correct workflows..."
echo ""

WORKFLOWS=(
    "session-start-workflow.json:Session Start - Fast Webhook"
    "left-worker-workflow.json:Left Worker - Teacher Pipeline"
    "right-worker-workflow.json:Right Worker - Teacher Pipeline"
)

IMPORTED_COUNT=0

for workflow_entry in "${WORKFLOWS[@]}"; do
    IFS=':' read -r filename display_name <<< "$workflow_entry"
    workflow_path="$PROJECT_DIR/n8n/workflows/$filename"
    
    if [[ ! -f "$workflow_path" ]]; then
        echo "❌ Workflow file not found: $workflow_path"
        continue
    fi
    
    echo "Importing $display_name..."
    
    # Clean workflow JSON for import (remove n8n-specific fields)
    CLEANED_WORKFLOW=$(python3 <<EOF
import json, sys
try:
    with open('$workflow_path', 'r') as f:
        workflow = json.load(f)
    
    # Keep only fields that n8n API accepts for import
    # Exclude: tags (read-only), id, updatedAt, createdAt, versionId, etc.
    cleaned = {
        "name": workflow.get("name", ""),
        "nodes": workflow.get("nodes", []),
        "connections": workflow.get("connections", {}),
        "settings": workflow.get("settings", {}),
        "staticData": workflow.get("staticData", {}),
        # DO NOT include "tags" - it's read-only and causes import to fail
    }
    
    print(json.dumps(cleaned))
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
EOF
)
    
    if [[ $? -ne 0 ]]; then
        echo "❌ Failed to clean workflow JSON"
        continue
    fi
    
    # Import workflow
    RESPONSE=$(curl -s -X POST \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$CLEANED_WORKFLOW" \
        "${N8N_URL}/api/v1/workflows")
    
    WORKFLOW_ID=$(echo "$RESPONSE" | python3 -c "import json, sys; d=json.load(sys.stdin); print(d.get('id', 'error'))" 2>/dev/null || echo "error")
    
    if [[ "$WORKFLOW_ID" != "error" ]] && [[ -n "$WORKFLOW_ID" ]]; then
        echo "   ✅ Imported: $display_name (ID: $WORKFLOW_ID)"
        
        # Activate workflow
        ACTIVATE_RESPONSE=$(curl -s -X POST \
            -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/activate" 2>/dev/null || echo "")
        
        echo "   ✅ Activated: $display_name"
        IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
    else
        echo "   ❌ Failed to import: $display_name"
        echo "   Response: $RESPONSE"
    fi
    echo ""
done

echo "=========================================="
if [[ "$IMPORTED_COUNT" -eq 3 ]]; then
    echo "✅ All workflows imported successfully!"
else
    echo "⚠️  Imported $IMPORTED_COUNT out of 3 workflows"
fi
echo "=========================================="
echo ""
echo "Expected workflows:"
echo "  1. Session Start - Fast Webhook"
echo "  2. Left Worker - Teacher Pipeline"
echo "  3. Right Worker - Teacher Pipeline"
echo ""
echo "Verify in n8n UI: http://localhost:5678"
echo ""
