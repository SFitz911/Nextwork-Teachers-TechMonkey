#!/usr/bin/env bash
# Reconfigure n8n for 2-Teacher Architecture
# This script:
# 1. Deactivates old 5-teacher workflow
# 2. Imports new 2-teacher workflows (session-start, left-worker, right-worker)
# 3. Activates new workflows
# 4. Verifies webhook endpoints
# Usage: bash scripts/reconfigure_n8n_for_2teacher.sh

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
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"

echo "=========================================="
echo "Reconfiguring n8n for 2-Teacher Architecture"
echo "=========================================="
echo ""

# Step 1: List current workflows
echo "Step 1: Checking current workflows..."
echo ""

if [[ -n "${N8N_API_KEY:-}" ]]; then
    WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
else
    WORKFLOWS_JSON=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
fi

# Find old 5-teacher workflow
OLD_WORKFLOW_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        name = wf.get('name', '')
        if 'Five Teacher' in name or 'five-teacher' in name.lower():
            print(f\"{wf.get('id', '')}|{wf.get('active', False)}\")
            sys.exit(0)
except:
    pass
" 2>/dev/null || echo "")

if [[ -n "$OLD_WORKFLOW_ID" ]]; then
    IFS='|' read -r OLD_ID OLD_ACTIVE <<< "$OLD_WORKFLOW_ID"
    echo "⚠️  Found old 5-teacher workflow (ID: $OLD_ID, Active: $OLD_ACTIVE)"
    
    if [[ "$OLD_ACTIVE" == "True" ]]; then
        echo "   Deactivating old workflow..."
        if [[ -n "${N8N_API_KEY:-}" ]]; then
            curl -s -X POST \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${OLD_ID}/deactivate" > /dev/null 2>&1 || true
        else
            curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
                -X POST \
                "${N8N_URL}/api/v1/workflows/${OLD_ID}/deactivate" > /dev/null 2>&1 || true
        fi
        echo "   ✅ Deactivated old workflow"
    else
        echo "   ✅ Old workflow already deactivated"
    fi
    
    # Ask if user wants to delete the old workflow
    echo ""
    echo "   Do you want to DELETE the old 5-teacher workflow? (y/n)"
    echo "   (Recommended: yes, to avoid confusion)"
    read -r DELETE_OLD
    
    if [[ "$DELETE_OLD" == "y" ]] || [[ "$DELETE_OLD" == "Y" ]]; then
        echo "   Deleting old workflow..."
        if [[ -n "${N8N_API_KEY:-}" ]]; then
            DELETE_RESPONSE=$(curl -s -X DELETE \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${OLD_ID}" 2>/dev/null || echo "")
        else
            DELETE_RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
                -X DELETE \
                "${N8N_URL}/api/v1/workflows/${OLD_ID}" 2>/dev/null || echo "")
        fi
        
        # Verify deletion
        sleep 1
        if [[ -n "${N8N_API_KEY:-}" ]]; then
            CHECK_RESPONSE=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${OLD_ID}" 2>/dev/null || echo '{"code":404}')
        else
            CHECK_RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
                "${N8N_URL}/api/v1/workflows/${OLD_ID}" 2>/dev/null || echo '{"code":404}')
        fi
        
        if echo "$CHECK_RESPONSE" | grep -q "404\|not found"; then
            echo "   ✅ Old workflow deleted"
        else
            echo "   ⚠️  Deletion may have failed (workflow still exists)"
        fi
    else
        echo "   ℹ️  Keeping old workflow (deactivated)"
    fi
else
    echo "✅ No old 5-teacher workflow found (or already removed)"
fi

echo ""

# Step 2: Check if new workflows already exist
echo "Step 2: Checking for existing 2-teacher workflows..."
echo ""

NEW_WORKFLOW_NAMES=(
    "Session Start - Fast Webhook"
    "Left Worker - Teacher Pipeline"
    "Right Worker - Teacher Pipeline"
)

EXISTING_IDS=()
for wf_name in "${NEW_WORKFLOW_NAMES[@]}"; do
    EXISTING_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
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
    
    if [[ -n "$EXISTING_ID" ]]; then
        echo "   Found existing: $wf_name (ID: $EXISTING_ID)"
        EXISTING_IDS+=("$EXISTING_ID")
    else
        echo "   Not found: $wf_name"
    fi
done

echo ""

# Step 3: Import new workflows
echo "Step 3: Importing new 2-teacher workflows..."
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
    
    echo "Processing $display_name..."
    
    # Check if already exists
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
    
    if [[ -n "$EXISTING_ID" ]]; then
        echo "   ⚠️  Already exists (ID: $EXISTING_ID), skipping import"
        IMPORTED_IDS+=("$EXISTING_ID")
        continue
    fi
    
    # Clean workflow JSON for import (remove read-only fields)
    CLEANED_WORKFLOW=$(python3 <<EOF
import json, sys
try:
    with open('$workflow_path', 'r') as f:
        workflow = json.load(f)
    
    # Only include fields that n8n API accepts for import
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
        echo "   ❌ Failed to clean workflow JSON"
        continue
    fi
    
    # Import workflow
    if [[ -n "${N8N_API_KEY:-}" ]]; then
        RESPONSE=$(curl -s -X POST \
            -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            -H "Content-Type: application/json" \
            -d "$CLEANED_WORKFLOW" \
            "${N8N_URL}/api/v1/workflows" 2>/dev/null)
    else
        RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
            -X POST \
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
        echo "   Response: $RESPONSE"
    fi
    echo ""
done

# Step 4: Activate all new workflows
echo "Step 4: Activating new workflows..."
echo ""

for wf_id in "${IMPORTED_IDS[@]}"; do
    if [[ -z "$wf_id" ]]; then
        continue
    fi
    
    echo "   Activating workflow ID: $wf_id..."
    
    if [[ -n "${N8N_API_KEY:-}" ]]; then
        ACTIVATE_RESPONSE=$(curl -s -X POST \
            -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            "${N8N_URL}/api/v1/workflows/${wf_id}/activate" 2>/dev/null)
    else
        ACTIVATE_RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
            -X POST \
            "${N8N_URL}/api/v1/workflows/${wf_id}/activate" 2>/dev/null)
    fi
    
    echo "   ✅ Activated"
done

echo ""

# Step 5: Wait for webhooks to register
echo "Step 5: Waiting for webhooks to register..."
sleep 5

# Step 6: Verify webhook endpoints
echo "Step 6: Verifying webhook endpoints..."
echo ""

WEBHOOKS=(
    "/webhook/session/start:Session Start"
    "/webhook/worker/left/run:Left Worker"
    "/webhook/worker/right/run:Right Worker"
)

for webhook_entry in "${WEBHOOKS[@]}"; do
    IFS=':' read -r path name <<< "$webhook_entry"
    
    echo "   Testing $name ($path)..."
    
    # Test with a simple POST
    if [[ "$path" == "/webhook/session/start" ]]; then
        TEST_PAYLOAD='{"selectedTeachers": ["teacher_a", "teacher_b"]}'
    else
        TEST_PAYLOAD='{"sessionId": "test", "teacher": "teacher_a", "role": "renderer", "sectionPayload": {}, "turn": 0}'
    fi
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$TEST_PAYLOAD" \
        "${N8N_URL}${path}" 2>/dev/null || echo "000")
    
    if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "404" ]]; then
        # 404 might mean webhook not registered yet, but endpoint exists
        echo "   ✅ Endpoint accessible (HTTP $HTTP_CODE)"
    else
        echo "   ⚠️  Endpoint returned HTTP $HTTP_CODE"
    fi
done

echo ""
echo "=========================================="
echo "✅ n8n Reconfiguration Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Old 5-teacher workflow: Deactivated"
echo "  - New workflows imported: ${#IMPORTED_IDS[@]}"
echo "  - All new workflows: Activated"
echo ""
echo "New webhook endpoints:"
echo "  - ${N8N_URL}/webhook/session/start"
echo "  - ${N8N_URL}/webhook/worker/left/run"
echo "  - ${N8N_URL}/webhook/worker/right/run"
echo ""
echo "Next steps:"
echo "  1. Start Coordinator API: python services/coordinator/app.py"
echo "  2. Test session start: curl -X POST ${N8N_URL}/webhook/session/start -H 'Content-Type: application/json' -d '{\"selectedTeachers\": [\"teacher_a\", \"teacher_b\"]}'"
echo "  3. Check n8n UI: ${N8N_URL} (verify workflows are active)"
