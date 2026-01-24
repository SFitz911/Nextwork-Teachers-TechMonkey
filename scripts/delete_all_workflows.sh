#!/usr/bin/env bash
# Delete ALL workflows from n8n
# Usage: bash scripts/delete_all_workflows.sh

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
echo "Deleting ALL Workflows from n8n"
echo "=========================================="
echo ""

# Get all workflows
echo "Fetching all workflows..."
WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')

# Check if API key works
if echo "$WORKFLOWS_JSON" | grep -q "unauthorized\|401\|403"; then
    echo "❌ API key authentication failed"
    echo "   Please check your N8N_API_KEY in .env"
    exit 1
fi

# Extract all workflow IDs and names
ALL_WORKFLOWS=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    workflows = []
    for wf in data.get('data', []):
        wf_id = wf.get('id', '')
        wf_name = wf.get('name', 'Unknown')
        if wf_id:
            workflows.append({'id': wf_id, 'name': wf_name})
    print(json.dumps(workflows))
except Exception as e:
    print('[]', file=sys.stderr)
" 2>/dev/null || echo "[]")

WORKFLOW_COUNT=$(echo "$ALL_WORKFLOWS" | python3 -c "import json, sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$WORKFLOW_COUNT" -eq "0" ]]; then
    echo "✅ No workflows found - nothing to delete"
    exit 0
fi

echo "Found $WORKFLOW_COUNT workflow(s) to delete:"
echo ""

# List all workflows
echo "$ALL_WORKFLOWS" | python3 -c "
import json, sys
workflows = json.load(sys.stdin)
for i, wf in enumerate(workflows, 1):
    print(f\"  {i}. {wf['name']} (ID: {wf['id']})\")
" 2>/dev/null

echo ""
echo "Deleting all workflows..."
echo ""

# Delete each workflow
DELETED_COUNT=0
echo "$ALL_WORKFLOWS" | python3 -c "
import json, sys
import subprocess
import os

workflows = json.load(sys.stdin)
n8n_url = os.environ.get('N8N_URL', 'http://localhost:5678')
n8n_api_key = os.environ.get('N8N_API_KEY', '')

for wf in workflows:
    wf_id = wf['id']
    wf_name = wf['name']
    
    # Deactivate first if active
    subprocess.run(['curl', '-s', '-X', 'POST',
        '-H', f'X-N8N-API-KEY: {n8n_api_key}',
        f'{n8n_url}/api/v1/workflows/{wf_id}/deactivate'],
        capture_output=True, timeout=5)
    
    # Delete workflow
    result = subprocess.run(['curl', '-s', '-X', 'DELETE',
        '-H', f'X-N8N-API-KEY: {n8n_api_key}',
        f'{n8n_url}/api/v1/workflows/{wf_id}'],
        capture_output=True, text=True, timeout=5)
    
    if result.returncode == 0:
        print(f\"✅ Deleted: {wf_name}\")
    else:
        print(f\"❌ Failed to delete: {wf_name}\")
" 2>/dev/null

echo ""
echo "Waiting 3 seconds for n8n to process deletions..."
sleep 3

# Verify deletion
echo ""
echo "Verifying deletion..."
VERIFY_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')

REMAINING_COUNT=$(echo "$VERIFY_JSON" | python3 -c "import json, sys; data=json.load(sys.stdin); print(len(data.get('data', [])))" 2>/dev/null || echo "0")

echo "=========================================="
if [[ "$REMAINING_COUNT" -eq "0" ]]; then
    echo "✅ All workflows deleted successfully!"
else
    echo "⚠️  Warning: $REMAINING_COUNT workflow(s) still remain"
    echo ""
    echo "Remaining workflows:"
    echo "$VERIFY_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for wf in data.get('data', []):
    print(f\"  - {wf.get('name', 'Unknown')} (ID: {wf.get('id', '')})\")
" 2>/dev/null
fi
echo "=========================================="
echo ""
