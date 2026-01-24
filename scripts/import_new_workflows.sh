#!/usr/bin/env bash
# Import the new 2-teacher architecture workflows into n8n
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
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI1MzE3fQ.tU1VEaQCrymcz8MIkAWuWfpBJoT9O7R8olTeBe42JJ0"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="${N8N_URL:-http://localhost:5678}"

echo "=========================================="
echo "Importing New 2-Teacher Architecture Workflows"
echo "=========================================="
echo ""

WORKFLOWS=(
    "session-start-workflow.json:Session Start - Fast Webhook"
    "left-worker-workflow.json:Left Worker - Teacher Pipeline"
    "right-worker-workflow.json:Right Worker - Teacher Pipeline"
)

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
    
    HTTP_CODE=$(echo "$RESPONSE" | python3 -c "import json, sys; d=json.load(sys.stdin); print(d.get('id', 'error'))" 2>/dev/null || echo "error")
    
    if [[ "$HTTP_CODE" != "error" ]] && [[ -n "$HTTP_CODE" ]]; then
        echo "✅ Imported: $display_name (ID: $HTTP_CODE)"
        
        # Activate workflow
        ACTIVATE_RESPONSE=$(curl -s -X POST \
            -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            "${N8N_URL}/api/v1/workflows/${HTTP_CODE}/activate")
        
        echo "   Activated: $display_name"
    else
        echo "❌ Failed to import: $display_name"
        echo "   Response: $RESPONSE"
    fi
    echo ""
done

echo "=========================================="
echo "✅ Workflow import complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Start Coordinator API: python services/coordinator/app.py"
echo "2. Test session start: curl -X POST http://localhost:8004/session/start -H 'Content-Type: application/json' -d '{\"selectedTeachers\": [\"teacher_a\", \"teacher_d\"]}'"
echo "3. Update frontend UI for 2-teacher layout and SSE event handling"
