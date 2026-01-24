#!/usr/bin/env bash
# Delete all workflows and restore only the 3 required workflows:
# - Session Start - Fast Webhook
# - Left Worker - Teacher Pipeline
# - Right Worker - Teacher Pipeline
# Usage: bash scripts/clean_and_restore_3_workflows.sh

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

echo "=========================================="
echo "Clean and Restore 3 Workflows"
echo "=========================================="
echo ""
echo "This will:"
echo "  1. Delete ALL existing workflows"
echo "  2. Restore only the 3 required workflows:"
echo "     - Session Start - Fast Webhook"
echo "     - Left Worker - Teacher Pipeline"
echo "     - Right Worker - Teacher Pipeline"
echo ""

# Check if n8n is accessible
if ! curl -s -o /dev/null -w "%{http_code}" "$N8N_URL" | grep -q "200\|404"; then
    echo "❌ n8n is not accessible at $N8N_URL"
    echo "   Make sure n8n is running and port forwarding is active"
    exit 1
fi

# Step 1: Delete all existing workflows
echo "Step 1: Deleting all existing workflows..."
echo ""

WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')

# Extract all workflow IDs
ALL_WORKFLOW_IDS=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    ids = []
    for wf in data.get('data', []):
        wf_id = wf.get('id', '')
        if wf_id:
            ids.append(wf_id)
    print(' '.join(ids))
except:
    pass
" 2>/dev/null || echo "")

WORKFLOW_COUNT=$(echo "$ALL_WORKFLOW_IDS" | python3 -c "
import sys
ids = sys.stdin.read().strip().split()
print(len(ids) if ids[0] else 0)
" 2>/dev/null || echo "0")

if [[ "$WORKFLOW_COUNT" -gt "0" ]]; then
    echo "Found $WORKFLOW_COUNT workflow(s) to delete..."
    
    for wf_id in $ALL_WORKFLOW_IDS; do
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
    
    echo ""
    echo "Waiting 2 seconds for n8n to process deletions..."
    sleep 2
else
    echo "   No workflows found to delete"
fi

# Step 2: Import the 3 required workflows
echo ""
echo "Step 2: Importing the 3 required workflows..."
echo ""

WORKFLOWS=(
    "session-start-workflow.json:Session Start - Fast Webhook"
    "left-worker-workflow.json:Left Worker - Teacher Pipeline"
    "right-worker-workflow.json:Right Worker - Teacher Pipeline"
)

IMPORTED_IDS=()

for workflow_entry in "${WORKFLOWS[@]}"; do
    IFS=':' read -r filename display_name <<< "$workflow_entry"
    workflow_path="$PROJECT_DIR/n8n/workflows/$filename"
    
    if [[ ! -f "$workflow_path" ]]; then
        echo "❌ Workflow file not found: $workflow_path"
        continue
    fi
    
    echo "Importing $display_name..."
    
    # Clean workflow JSON for import (remove read-only fields)
    CLEANED_WORKFLOW=$(python3 <<EOF
import json, sys
try:
    with open('$workflow_path', 'r') as f:
        workflow = json.load(f)
    
    # Only include fields that n8n API accepts for import
    cleaned = {
        "name": workflow.get("name", "$display_name"),
        "nodes": workflow.get("nodes", []),
        "connections": workflow.get("connections", {}),
        "settings": workflow.get("settings", {}),
        "staticData": workflow.get("staticData", {}),
    }
    
    # Remove node IDs
    for node in cleaned.get("nodes", []):
        node.pop("id", None)
        node.pop("webhookId", None)
    
    print(json.dumps(cleaned))
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
EOF
)
    
    if [[ $? -ne 0 ]] || [[ "$CLEANED_WORKFLOW" == *"ERROR"* ]]; then
        echo "   ❌ Failed to clean workflow JSON"
        continue
    fi
    
    # Import workflow
    CLEANED_FILE="/tmp/import_workflow_$$_${filename}.json"
    echo "$CLEANED_WORKFLOW" > "$CLEANED_FILE"
    
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
        echo "   ❌ Failed to import workflow (HTTP $HTTP_CODE)"
        echo "   Response: $IMPORT_BODY" | head -5
        continue
    fi
    
    WORKFLOW_ID=$(echo "$IMPORT_BODY" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    wf_id = data.get('id') or data.get('data', {}).get('id', '')
    if wf_id:
        print(wf_id)
except:
    pass
" 2>/dev/null || echo "")
    
    if [[ -n "$WORKFLOW_ID" ]]; then
        echo "   ✅ Imported successfully (ID: $WORKFLOW_ID)"
        IMPORTED_IDS+=("$WORKFLOW_ID")
    else
        echo "   ⚠️  Imported but couldn't get workflow ID"
    fi
    echo ""
done

# Step 3: Activate all imported workflows
echo "Step 3: Activating workflows..."
echo ""

for wf_id in "${IMPORTED_IDS[@]}"; do
    if [[ -z "$wf_id" ]]; then
        continue
    fi
    
    echo "   Activating workflow ID: $wf_id..."
    
    ACTIVATE_RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"active": true}' \
        "${N8N_URL}/api/v1/workflows/${wf_id}/activate" 2>/dev/null)
    
    ACTIVATE_CODE=$(echo "$ACTIVATE_RESPONSE" | tail -1)
    
    if [[ "$ACTIVATE_CODE" == "200" ]]; then
        echo "   ✅ Activated"
    else
        echo "   ⚠️  Could not activate (HTTP $ACTIVATE_CODE)"
    fi
    echo ""
done

# Step 4: Verify final state
echo "Step 4: Verifying final state..."
echo ""

FINAL_WORKFLOWS=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')

FINAL_COUNT=$(echo "$FINAL_WORKFLOWS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(len(data.get('data', [])))
except:
    print(0)
" 2>/dev/null || echo "0")

echo "=========================================="
if [[ "$FINAL_COUNT" -eq "3" ]]; then
    echo "✅ Success! Exactly 3 workflows restored:"
    echo ""
    echo "$FINAL_WORKFLOWS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        name = wf.get('name', 'Unknown')
        active = '✅ Active' if wf.get('active', False) else '❌ Inactive'
        print(f\"  - {name} ({active})\")
except:
    pass
" 2>/dev/null
else
    echo "⚠️  Warning: Expected 3 workflows, but found $FINAL_COUNT"
    echo ""
    echo "Current workflows:"
    echo "$FINAL_WORKFLOWS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        print(f\"  - {wf.get('name', 'Unknown')} (ID: {wf.get('id', '')})\")
except:
    pass
" 2>/dev/null
fi
echo "=========================================="
echo ""
echo "Workflows are now available in n8n:"
echo "  $N8N_URL"
echo ""
