#!/usr/bin/env bash
# FORCE delete ALL workflows and import only the 3 correct ones
# This script will NOT skip deletion even if workflows exist
# Usage: bash scripts/force_clean_workflows.sh

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
echo "FORCE CLEAN: Delete ALL and Import 3 Correct Workflows"
echo "=========================================="
echo ""

# Step 1: Delete ALL workflows (loop until none remain)
echo "Step 1: Deleting ALL workflows (will retry until none remain)..."
echo ""

MAX_DELETE_ATTEMPTS=5
ATTEMPT=0

while [[ $ATTEMPT -lt $MAX_DELETE_ATTEMPTS ]]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "Delete attempt $ATTEMPT/$MAX_DELETE_ATTEMPTS..."
    
    # Get all workflows
    WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
    
    # Check if API key works
    if echo "$WORKFLOWS_JSON" | grep -q "unauthorized\|401\|403"; then
        echo "❌ API key authentication failed"
        echo "   Please check your N8N_API_KEY in .env"
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
    
    if [[ "$WORKFLOW_COUNT" -eq "0" ]]; then
        echo "✅ All workflows deleted!"
        break
    fi
    
    echo "   Found $WORKFLOW_COUNT workflow(s) - deleting..."
    
    # Delete each workflow
    DELETED_THIS_ROUND=0
    for wf_id in $ALL_WORKFLOW_IDS; do
        if [[ -n "$wf_id" ]]; then
            # Deactivate first
            curl -s -X POST \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${wf_id}/deactivate" > /dev/null 2>&1 || true
            
            # Delete workflow
            HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${wf_id}" 2>/dev/null || echo "000")
            
            if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "204" ]]; then
                DELETED_THIS_ROUND=$((DELETED_THIS_ROUND + 1))
            fi
        fi
    done
    
    echo "   Deleted $DELETED_THIS_ROUND workflow(s) this round"
    
    # Wait for n8n to process deletions
    sleep 3
    
    # Verify
    VERIFY_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
    
    REMAINING_COUNT=$(echo "$VERIFY_JSON" | python3 -c "import json, sys; data=json.load(sys.stdin); print(len(data.get('data', [])))" 2>/dev/null || echo "0")
    
    if [[ "$REMAINING_COUNT" -eq "0" ]]; then
        echo "✅ All workflows deleted!"
        break
    else
        echo "   ⚠️  $REMAINING_COUNT workflow(s) still remain - will retry..."
    fi
    
    echo ""
done

# Final verification
FINAL_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')

FINAL_COUNT=$(echo "$FINAL_JSON" | python3 -c "import json, sys; data=json.load(sys.stdin); print(len(data.get('data', [])))" 2>/dev/null || echo "0")

if [[ "$FINAL_COUNT" -gt 0 ]]; then
    echo "⚠️  WARNING: $FINAL_COUNT workflow(s) still remain after $MAX_DELETE_ATTEMPTS attempts"
    echo "   Remaining workflows:"
    echo "$FINAL_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for wf in data.get('data', []):
    print(f\"  - {wf.get('name', 'Unknown')} (ID: {wf.get('id', '')})\")
" 2>/dev/null
    echo ""
    echo "   You may need to delete them manually via n8n UI"
    echo ""
else
    echo "✅ All workflows successfully deleted!"
    echo ""
fi

# Step 2: Final verification before import
echo "Step 2: Final verification..."
FINAL_CHECK=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')

FINAL_COUNT=$(echo "$FINAL_CHECK" | python3 -c "import json, sys; data=json.load(sys.stdin); print(len(data.get('data', [])))" 2>/dev/null || echo "0")

if [[ "$FINAL_COUNT" -gt 0 ]]; then
    echo "⚠️  WARNING: $FINAL_COUNT workflow(s) still remain!"
    echo "   Running nuclear delete to remove them..."
    bash scripts/nuclear_delete_all_workflows.sh
    sleep 2
fi

# Step 3: Import the 3 correct workflows
echo ""
echo "Step 3: Importing 3 correct workflows..."
echo ""

# Force import by setting FORCE_IMPORT
export FORCE_IMPORT=true
bash scripts/import_new_workflows.sh

echo ""
echo "=========================================="
echo "✅ Force clean complete!"
echo "=========================================="
echo ""
echo "You should now have exactly 3 workflows:"
echo "  1. Session Start - Fast Webhook"
echo "  2. Left Worker - Teacher Pipeline"
echo "  3. Right Worker - Teacher Pipeline"
echo ""
echo "Verify in n8n UI: http://localhost:5678"
echo ""
