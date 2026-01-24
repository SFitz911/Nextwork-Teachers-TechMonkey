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

# Step 1: Delete ALL existing workflows first (ALWAYS delete, even if FORCE_IMPORT is not set)
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

WORKFLOW_COUNT=$(echo "$ALL_WORKFLOW_IDS" | grep -v '^$' | wc -l | tr -d ' ' || echo "0")

if [[ "$WORKFLOW_COUNT" -gt 0 ]]; then
    echo "   Found $WORKFLOW_COUNT existing workflow(s) - deleting ALL..."
    echo ""
    
    # Delete each workflow (loop to ensure all are deleted)
    DELETED_COUNT=0
    for wf_id in $ALL_WORKFLOW_IDS; do
        if [[ -n "$wf_id" ]]; then
            # Get workflow name for display
            WF_NAME=$(echo "$WORKFLOWS_JSON" | python3 -c "import json, sys; data=json.load(sys.stdin); [print(wf.get('name', 'Unknown')) for wf in data.get('data', []) if wf.get('id') == '$wf_id']" 2>/dev/null || echo "Unknown")
            
            # Deactivate first
            curl -s -X POST \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${wf_id}/deactivate" > /dev/null 2>&1 || true
            
            # Delete workflow
            HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${wf_id}" 2>/dev/null || echo "000")
            
            if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "204" ]]; then
                echo "   ✅ Deleted: $WF_NAME"
                DELETED_COUNT=$((DELETED_COUNT + 1))
            else
                echo "   ⚠️  Failed to delete: $WF_NAME (HTTP $HTTP_CODE)"
            fi
        fi
    done
    
    echo ""
    echo "   Deleted $DELETED_COUNT out of $WORKFLOW_COUNT workflow(s)"
    echo "   Waiting 5 seconds for n8n to process deletions..."
    sleep 5
    
    # Verify deletion - retry if needed
    VERIFY_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
    
    REMAINING_COUNT=$(echo "$VERIFY_JSON" | python3 -c "import json, sys; data=json.load(sys.stdin); print(len(data.get('data', [])))" 2>/dev/null || echo "0")
    
    if [[ "$REMAINING_COUNT" -gt 0 ]]; then
        echo "   ⚠️  $REMAINING_COUNT workflow(s) still remain - retrying deletion..."
        
        # Retry deletion for remaining workflows
        REMAINING_IDS=$(echo "$VERIFY_JSON" | python3 <<'PYEOF'
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
        
        for wf_id in $REMAINING_IDS; do
            if [[ -n "$wf_id" ]]; then
                curl -s -X POST \
                    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                    "${N8N_URL}/api/v1/workflows/${wf_id}/deactivate" > /dev/null 2>&1 || true
                
                curl -s -X DELETE \
                    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                    "${N8N_URL}/api/v1/workflows/${wf_id}" > /dev/null 2>&1 || true
            fi
        done
        
        sleep 3
    fi
    
    echo ""
    echo "✅ Deletion complete"
    echo ""
else
    echo "   No existing workflows found"
    echo ""
fi

# Refresh workflows JSON after deletion
WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')

# Step 2: Check if correct workflows already exist
echo "Step 2: Checking if correct workflows already exist..."
echo ""

EXPECTED_WORKFLOWS=(
    "Session Start - Fast Webhook"
    "Left Worker - Teacher Pipeline"
    "Right Worker - Teacher Pipeline"
)

EXISTING_COUNT=0
for wf_name in "${EXPECTED_WORKFLOWS[@]}"; do
    EXISTS=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if wf.get('name', '') == '$wf_name':
            print('yes')
            sys.exit(0)
except:
    pass
print('no')
" 2>/dev/null || echo "no")
    
    if [[ "$EXISTS" == "yes" ]]; then
        echo "   ✅ Found: $wf_name"
        EXISTING_COUNT=$((EXISTING_COUNT + 1))
    else
        echo "   ❌ Missing: $wf_name"
    fi
done

echo ""

# Note: We already deleted all workflows in Step 1, so we should always import
# But check anyway in case deletion failed
if [[ "$EXISTING_COUNT" -eq 3 ]] && [[ "${FORCE_IMPORT:-}" != "true" ]]; then
    echo "⚠️  All 3 correct workflows already exist (deletion may have failed)"
    echo ""
    echo "   To force re-import, run:"
    echo "   bash scripts/force_clean_workflows.sh"
    echo ""
    echo "   Or continue with import anyway..."
    echo ""
fi

# Step 3: Import the 3 correct workflows
echo "Step 3: Importing correct workflows..."
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
    
    # Check if this specific workflow already exists
    EXISTING_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if wf.get('name', '') == '$display_name':
            print(wf.get('id', ''))
            sys.exit(0)
except:
    pass
" 2>/dev/null || echo "")
    
    if [[ -n "$EXISTING_ID" ]] && [[ "${FORCE_IMPORT:-}" != "true" ]]; then
        echo "   ⚠️  Already exists: $display_name (ID: $EXISTING_ID) - skipping"
        echo "   (Use FORCE_IMPORT=true to replace)"
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
