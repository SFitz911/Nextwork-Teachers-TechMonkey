#!/usr/bin/env bash
# Fix n8n worker workflows to use async job pattern
# This prevents HTTP timeouts during GPU video generation

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

N8N_API_KEY="${N8N_API_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzMThlZDVhMy04ZDdlLTQ0NTEtYTc2ZS0wZjEyMTRlYjYwMGYiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5NDcwMzEyfQ.o1CNGPHMt8JbqFrSkbZo9o5Q4tjhptdjb-lKPSKK2oc}"
N8N_URL="http://localhost:5678/api/v1"

echo "=========================================="
echo "Fix n8n Async Job Pattern"
echo "=========================================="
echo ""
echo "This will update worker workflows to respond immediately"
echo "instead of waiting for GPU video generation to complete."
echo ""

# Get all workflows
WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" "${N8N_URL}/workflows")

# Find Left Worker workflow ID
LEFT_WORKER_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for wf in data.get('data', []):
    if 'Left Worker' in wf.get('name', ''):
        print(wf.get('id', ''))
        sys.exit(0)
")

# Find Right Worker workflow ID
RIGHT_WORKER_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for wf in data.get('data', []):
    if 'Right Worker' in wf.get('name', ''):
        print(wf.get('id', ''))
        sys.exit(0)
")

if [[ -z "$LEFT_WORKER_ID" ]] || [[ -z "$RIGHT_WORKER_ID" ]]; then
    echo "❌ Could not find worker workflows!"
    echo "   Left Worker ID: ${LEFT_WORKER_ID:-NOT FOUND}"
    echo "   Right Worker ID: ${RIGHT_WORKER_ID:-NOT FOUND}"
    exit 1
fi

echo "Found workflows:"
echo "  Left Worker: $LEFT_WORKER_ID"
echo "  Right Worker: $RIGHT_WORKER_ID"
echo ""

# Function to fix a workflow
fix_workflow() {
    local workflow_id="$1"
    local workflow_name="$2"
    
    echo "Fixing $workflow_name..."
    
    # Get current workflow
    WORKFLOW=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" "${N8N_URL}/workflows/${workflow_id}")
    
    # Update responseMode to "onReceived" using Python
    UPDATED_WORKFLOW=$(echo "$WORKFLOW" | python3 <<'EOF'
import json, sys

workflow = json.load(sys.stdin)

# Find webhook trigger node and update responseMode
for node in workflow.get('nodes', []):
    if node.get('type') == 'n8n-nodes-base.webhook':
        if 'parameters' in node:
            node['parameters']['responseMode'] = 'onReceived'
            print(f"  ✅ Updated webhook trigger to respond immediately", file=sys.stderr)

# Remove read-only fields for update
cleaned = {
    "name": workflow.get("name"),
    "nodes": workflow.get("nodes", []),
    "connections": workflow.get("connections", {}),
    "settings": workflow.get("settings", {}),
    "staticData": workflow.get("staticData", {}),
}

print(json.dumps(cleaned))
EOF
)
    
    # Update workflow via API
    UPDATE_RESPONSE=$(curl -s -X PUT \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$UPDATED_WORKFLOW" \
        "${N8N_URL}/workflows/${workflow_id}")
    
    # Check if update succeeded
    if echo "$UPDATE_RESPONSE" | grep -q '"id"'; then
        echo "  ✅ $workflow_name updated successfully"
        
        # Deactivate and reactivate to apply changes
        curl -s -X POST -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            "${N8N_URL}/workflows/${workflow_id}/deactivate" > /dev/null
        sleep 1
        curl -s -X POST -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            "${N8N_URL}/workflows/${workflow_id}/activate" > /dev/null
        echo "  ✅ $workflow_name reactivated"
    else
        echo "  ❌ Failed to update $workflow_name"
        echo "  Response: $UPDATE_RESPONSE" | head -5
    fi
    
    echo ""
}

# Fix both workflows
fix_workflow "$LEFT_WORKER_ID" "Left Worker"
fix_workflow "$RIGHT_WORKER_ID" "Right Worker"

echo "=========================================="
echo "✅ Async Job Pattern Applied!"
echo "=========================================="
echo ""
echo "Worker workflows now respond immediately."
echo "GPU video generation runs in background."
echo "No more HTTP timeouts!"
echo ""
echo "Test by starting a session in the frontend."
echo ""
