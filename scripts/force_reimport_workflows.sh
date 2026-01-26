#!/usr/bin/env bash
# Force delete and re-import n8n workflows (to pick up fixes)
# Usage: bash scripts/force_reimport_workflows.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Get n8n credentials
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI2ODU4OGE3Mi0xN2YyLTQ1NzUtYTZmNi1jOTc5OGU2YjZhNGIiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5NDAzNzE3fQ.Q2S2ioWmVFx55zSJoqQaUcKhpl-Bo22Vyv-1bdVVNV0"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="http://localhost:5678"

echo "=========================================="
echo "Force Re-importing n8n Workflows"
echo "=========================================="
echo ""

# Function to make authenticated request
make_auth_request() {
    local method="$1"
    local url="$2"
    local data="${3:-}"
    
    # Try API key first
    if [[ -n "$N8N_API_KEY" ]]; then
        if [[ -n "$data" ]]; then
            curl -s -X "$method" \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                -H "Content-Type: application/json" \
                -d "$data" \
                "$url" 2>/dev/null
        else
            curl -s -X "$method" \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "$url" 2>/dev/null
        fi
    else
        # Fall back to basic auth
        if [[ -n "$data" ]]; then
            curl -s -X "$method" \
                -u "${N8N_USER}:${N8N_PASSWORD}" \
                -H "Content-Type: application/json" \
                -d "$data" \
                "$url" 2>/dev/null
        else
            curl -s -X "$method" \
                -u "${N8N_USER}:${N8N_PASSWORD}" \
                "$url" 2>/dev/null
        fi
    fi
}

# Test authentication
echo "Testing n8n authentication..."
TEST_RESPONSE=$(make_auth_request "GET" "${N8N_URL}/api/v1/workflows")
if echo "$TEST_RESPONSE" | grep -q "unauthorized\|Unauthorized\|401"; then
    echo "   ⚠️  API key authentication failed, trying basic auth..."
    # Try basic auth
    TEST_RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo "")
    if echo "$TEST_RESPONSE" | grep -q "unauthorized\|Unauthorized\|401"; then
        echo "   ❌ Both API key and basic auth failed!"
        echo "   Please check:"
        echo "     1. n8n is running: ps aux | grep n8n"
        echo "     2. N8N_USER and N8N_PASSWORD in .env"
        echo "     3. API key is valid (get from n8n UI: Settings → API)"
        exit 1
    else
        echo "   ✅ Basic auth works, using it for all requests"
        USE_BASIC_AUTH=true
    fi
else
    echo "   ✅ API key authentication works"
    USE_BASIC_AUTH=false
fi
echo ""

# Get all workflows
if [[ "$USE_BASIC_AUTH" == "true" ]]; then
    WORKFLOWS_JSON=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
else
    WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
fi

# Workflows to delete and re-import
WORKFLOW_NAMES=(
    "Session Start - Fast Webhook"
    "Left Worker - Teacher Pipeline"
    "Right Worker - Teacher Pipeline"
)

echo "Step 1: Deleting existing workflows..."
echo ""

for wf_name in "${WORKFLOW_NAMES[@]}"; do
    WF_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if wf.get('name', '') == '$wf_name':
            print(wf.get('id', ''))
            sys.exit(0)
except:
    pass
" 2>/dev/null || echo "")
    
    if [[ -n "$WF_ID" ]]; then
        echo "   Deleting: $wf_name (ID: $WF_ID)..."
        
        # Deactivate first
        if [[ "$USE_BASIC_AUTH" == "true" ]]; then
            curl -s -X POST -u "${N8N_USER}:${N8N_PASSWORD}" \
                "${N8N_URL}/api/v1/workflows/${WF_ID}/deactivate" > /dev/null 2>&1 || true
        else
            curl -s -X POST -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${WF_ID}/deactivate" > /dev/null 2>&1 || true
        fi
        
        # Delete
        if [[ "$USE_BASIC_AUTH" == "true" ]]; then
            DELETE_RESPONSE=$(curl -s -X DELETE -u "${N8N_USER}:${N8N_PASSWORD}" \
                "${N8N_URL}/api/v1/workflows/${WF_ID}" 2>/dev/null || echo "")
        else
            DELETE_RESPONSE=$(curl -s -X DELETE -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${WF_ID}" 2>/dev/null || echo "")
        fi
        
        sleep 1
        echo "   ✅ Deleted: $wf_name"
    else
        echo "   ℹ️  Not found: $wf_name (may already be deleted)"
    fi
done

echo ""
echo "Step 2: Re-importing workflows..."
echo ""

# Wait a moment for deletion to complete
sleep 2

# Get fresh workflow list
if [[ "$USE_BASIC_AUTH" == "true" ]]; then
    WORKFLOWS_JSON=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
else
    WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
fi

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
    
    # Clean workflow JSON (remove read-only fields)
    CLEANED_WORKFLOW=$(python3 <<EOF
import json, sys
try:
    with open('$workflow_path', 'r') as f:
        workflow = json.load(f)
    
    cleaned = {
        "name": workflow.get("name", "$display_name"),
        "nodes": workflow.get("nodes", []),
        "connections": workflow.get("connections", {}),
        "settings": workflow.get("settings", {}),
        "staticData": workflow.get("staticData", {}),
    }
    
    print(json.dumps(cleaned))
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
EOF
)
    
    if [[ $? -ne 0 ]]; then
        echo "   ❌ Failed to clean workflow JSON"
        continue
    fi
    
    # Import workflow
    if [[ "$USE_BASIC_AUTH" == "true" ]]; then
        RESPONSE=$(curl -s -X POST \
            -u "${N8N_USER}:${N8N_PASSWORD}" \
            -H "Content-Type: application/json" \
            -d "$CLEANED_WORKFLOW" \
            "${N8N_URL}/api/v1/workflows" 2>/dev/null)
    else
        RESPONSE=$(curl -s -X POST \
            -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            -H "Content-Type: application/json" \
            -d "$CLEANED_WORKFLOW" \
            "${N8N_URL}/api/v1/workflows" 2>/dev/null)
    fi
    
    WORKFLOW_ID=$(echo "$RESPONSE" | python3 -c "import json, sys; d=json.load(sys.stdin); print(d.get('id', 'error'))" 2>/dev/null || echo "error")
    
    if [[ "$WORKFLOW_ID" != "error" ]] && [[ -n "$WORKFLOW_ID" ]]; then
        echo "   ✅ Imported: $display_name (ID: $WORKFLOW_ID)"
        IMPORTED_IDS+=("$WORKFLOW_ID")
    else
        echo "   ❌ Failed to import: $display_name"
        echo "   Response: $RESPONSE" | head -5
        continue
    fi
    
    # Activate workflow
    sleep 1
    if [[ "$USE_BASIC_AUTH" == "true" ]]; then
        ACTIVATE_RESPONSE=$(curl -s -X POST \
            -u "${N8N_USER}:${N8N_PASSWORD}" \
            -H "Content-Type: application/json" \
            "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/activate" 2>/dev/null)
    else
        ACTIVATE_RESPONSE=$(curl -s -X POST \
            -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            -H "Content-Type: application/json" \
            "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/activate" 2>/dev/null)
    fi
    
    if echo "$ACTIVATE_RESPONSE" | grep -q "active.*true\|success"; then
        echo "   ✅ Activated: $display_name"
    else
        echo "   ⚠️  Activation may have failed for: $display_name"
    fi
    echo ""
done

echo "=========================================="
echo "✅ Force Re-import Complete!"
echo "=========================================="
echo ""
echo "Imported and activated ${#IMPORTED_IDS[@]} workflows"
echo ""
echo "Next steps:"
echo "  1. Test a session in the frontend"
echo "  2. Check n8n UI to verify workflows are active: http://localhost:5678"
echo ""
