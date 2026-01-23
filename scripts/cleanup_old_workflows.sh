#!/usr/bin/env bash
# Clean up old workflows from n8n
# This script finds and optionally deletes old 5-teacher workflows
# Usage: bash scripts/cleanup_old_workflows.sh [--delete]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Default API key (hardcoded fallback)
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmNzRkZjc2OC0wZTVhLTQ2OGQtODFiYS1iYTZiMGFiNjAwY2EiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MTQzMDY3fQ.JQU3yyBofIJBX-50Zjdc9GnW7xLMf1QcZrVlgJ-OdbA"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"

DELETE_MODE=false
if [[ "${1:-}" == "--delete" ]]; then
    DELETE_MODE=true
fi

echo "=========================================="
echo "Cleaning Up Old Workflows"
echo "=========================================="
echo ""

# Get all workflows
if [[ -n "${N8N_API_KEY:-}" ]]; then
    WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
else
    WORKFLOWS_JSON=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
fi

# Find old workflows
OLD_WORKFLOWS=$(echo "$WORKFLOWS_JSON" | python3 <<EOF
import json, sys
try:
    data = json.load(sys.stdin)
    old_workflows = []
    for wf in data.get('data', []):
        name = wf.get('name', '')
        wf_id = wf.get('id', '')
        active = wf.get('active', False)
        
        # Look for old workflow patterns
        if 'Five Teacher' in name or 'five-teacher' in name.lower() or \
           'Dual Teacher' in name or 'chat-webhook' in name.lower():
            old_workflows.append({
                'id': wf_id,
                'name': name,
                'active': active
            })
    
    print(json.dumps(old_workflows))
except Exception as e:
    print('[]')
EOF
)

OLD_COUNT=$(echo "$OLD_WORKFLOWS" | python3 -c "import json, sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$OLD_COUNT" == "0" ]]; then
    echo "✅ No old workflows found"
    exit 0
fi

echo "Found $OLD_COUNT old workflow(s):"
echo ""

echo "$OLD_WORKFLOWS" | python3 <<EOF
import json, sys
workflows = json.load(sys.stdin)
for wf in workflows:
    status = "🟢 Active" if wf['active'] else "⚪ Inactive"
    print(f"  - {wf['name']} (ID: {wf['id']}) - {status}")
EOF

echo ""

if [[ "$DELETE_MODE" == "true" ]]; then
    echo "Deleting old workflows..."
    echo ""
    
    echo "$OLD_WORKFLOWS" | python3 <<EOF
import json, sys
import subprocess
import os

workflows = json.load(sys.stdin)
n8n_url = os.environ.get('N8N_URL', 'http://localhost:5678')
n8n_api_key = os.environ.get('N8N_API_KEY', '')
n8n_user = os.environ.get('N8N_USER', 'admin')
n8n_password = os.environ.get('N8N_PASSWORD', 'changeme')

for wf in workflows:
    wf_id = wf['id']
    wf_name = wf['name']
    
    # Deactivate first if active
    if wf['active']:
        if n8n_api_key:
            subprocess.run(['curl', '-s', '-X', 'POST',
                '-H', f'X-N8N-API-KEY: {n8n_api_key}',
                f'{n8n_url}/api/v1/workflows/{wf_id}/deactivate'],
                capture_output=True)
        else:
            subprocess.run(['curl', '-s', '-u', f'{n8n_user}:{n8n_password}',
                '-X', 'POST',
                f'{n8n_url}/api/v1/workflows/{wf_id}/deactivate'],
                capture_output=True)
    
    # Delete workflow
    if n8n_api_key:
        result = subprocess.run(['curl', '-s', '-X', 'DELETE',
            '-H', f'X-N8N-API-KEY: {n8n_api_key}',
            f'{n8n_url}/api/v1/workflows/{wf_id}'],
            capture_output=True, text=True)
    else:
        result = subprocess.run(['curl', '-s', '-u', f'{n8n_user}:{n8n_password}',
            '-X', 'DELETE',
            f'{n8n_url}/api/v1/workflows/{wf_id}'],
            capture_output=True, text=True)
    
    print(f"  ✅ Deleted: {wf_name}")
EOF

    echo ""
    echo "✅ Cleanup complete!"
else
    echo "To delete these workflows, run:"
    echo "  bash scripts/cleanup_old_workflows.sh --delete"
    echo ""
    echo "Or manually delete them in n8n UI: ${N8N_URL}"
fi
