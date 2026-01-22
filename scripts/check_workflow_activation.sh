#!/usr/bin/env bash
# Check if the n8n workflow is activated
# Usage: bash scripts/check_workflow_activation.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load environment variables
if [[ -f .env ]]; then
    source .env
fi

N8N_URL="http://localhost:5678"
# Default API key (hardcoded fallback)
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhNDE1ODkzYS1hY2Q2LTQ2NWYtODcyNS02NDQzZTRkNTkyZTkiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MDYxNjMwfQ.faRO3CRuldcSQd0-g9sJORo8tUq_vfMMDpOmXQTPH0I"
API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"

echo "=========================================="
echo "Checking Workflow Activation Status"
echo "=========================================="
echo ""

# Get workflows
if [[ -n "$API_KEY" ]]; then
    WORKFLOWS=$(curl -s -H "X-N8N-API-KEY: $API_KEY" "${N8N_URL}/api/v1/workflows")
else
    WORKFLOWS=$(curl -s -u "${N8N_USER:-admin}:${N8N_PASSWORD:-changeme}" "${N8N_URL}/api/v1/workflows")
fi

# Find the Five Teacher workflow
WORKFLOW_ID=$(echo "$WORKFLOWS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for wf in data.get('data', []):
    if 'Five Teacher' in wf.get('name', ''):
        print(wf['id'])
        print(wf.get('active', False))
        break
" 2>/dev/null || echo "")

if [[ -z "$WORKFLOW_ID" ]]; then
    echo "❌ Five Teacher workflow not found"
    echo ""
    echo "Import it first:"
    echo "  bash scripts/clean_and_import_workflow.sh"
    exit 1
fi

ACTIVE=$(echo "$WORKFLOW_ID" | tail -1)
WORKFLOW_ID=$(echo "$WORKFLOW_ID" | head -1)

echo "Workflow ID: $WORKFLOW_ID"
echo ""

if [[ "$ACTIVE" == "True" ]]; then
    echo "✅ Workflow is ACTIVATED"
    echo ""
    echo "The workflow will automatically respond to webhook requests."
    echo "You do NOT need to click 'Execute Workflow' button."
    echo ""
    echo "Test it:"
    echo "  bash scripts/simple_webhook_test.sh"
else
    echo "❌ Workflow is NOT activated"
    echo ""
    echo "Activate it:"
    echo "  bash scripts/activate_workflow_api.sh"
    echo ""
    echo "Or manually:"
    echo "  1. Open http://localhost:5678"
    echo "  2. Open the 'Five Teacher' workflow"
    echo "  3. Toggle the 'Active/Inactive' switch in the top-right"
fi
