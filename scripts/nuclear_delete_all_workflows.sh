#!/usr/bin/env bash
# NUCLEAR OPTION: Delete ALL workflows using pagination and multiple verification passes
# This script handles n8n's pagination and ensures ALL workflows are deleted
# Usage: bash scripts/nuclear_delete_all_workflows.sh

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
echo "NUCLEAR DELETE: Delete ALL Workflows (with pagination)"
echo "=========================================="
echo ""

# Function to get ALL workflows (handling pagination)
get_all_workflows() {
    local all_workflows="[]"
    local page=1
    local limit=50
    local has_more=true
    
    while [[ "$has_more" == "true" ]]; do
        WORKFLOWS_PAGE=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            "${N8N_URL}/api/v1/workflows?limit=${limit}&page=${page}" 2>/dev/null || echo '{"data":[],"hasMore":false}')
        
        # Check if API key works
        if echo "$WORKFLOWS_PAGE" | grep -q "unauthorized\|401\|403"; then
            echo "❌ API key authentication failed"
            exit 1
        fi
        
        PAGE_DATA=$(echo "$WORKFLOWS_PAGE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    workflows = data.get('data', [])
    has_more = data.get('hasMore', False)
    print(json.dumps({'workflows': workflows, 'hasMore': has_more}))
except:
    print(json.dumps({'workflows': [], 'hasMore': False}))
" 2>/dev/null || echo '{"workflows":[],"hasMore":false}')
        
        PAGE_WORKFLOWS=$(echo "$PAGE_DATA" | python3 -c "import json, sys; d=json.load(sys.stdin); print(json.dumps(d['workflows']))" 2>/dev/null || echo "[]")
        HAS_MORE=$(echo "$PAGE_DATA" | python3 -c "import json, sys; d=json.load(sys.stdin); print('true' if d.get('hasMore') else 'false')" 2>/dev/null || echo "false")
        
        # Merge workflows
        all_workflows=$(echo "$all_workflows" "$PAGE_WORKFLOWS" | python3 -c "
import json, sys
all = []
for line in sys.stdin:
    if line.strip():
        try:
            workflows = json.loads(line)
            if isinstance(workflows, list):
                all.extend(workflows)
        except:
            pass
print(json.dumps(all))
" 2>/dev/null || echo "[]")
        
        if [[ "$HAS_MORE" != "true" ]]; then
            has_more=false
        else
            page=$((page + 1))
        fi
        
        # Safety limit
        if [[ $page -gt 100 ]]; then
            echo "⚠️  Hit safety limit of 100 pages"
            break
        fi
    done
    
    echo "$all_workflows"
}

# Step 1: Get ALL workflows (with pagination)
echo "Step 1: Fetching ALL workflows (handling pagination)..."
ALL_WORKFLOWS_JSON=$(get_all_workflows)

WORKFLOW_COUNT=$(echo "$ALL_WORKFLOWS_JSON" | python3 -c "import json, sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$WORKFLOW_COUNT" -eq "0" ]]; then
    echo "✅ No workflows found - nothing to delete"
    exit 0
fi

echo "   Found $WORKFLOW_COUNT total workflow(s)"
echo ""

# List all workflows
echo "Workflows to delete:"
echo "$ALL_WORKFLOWS_JSON" | python3 -c "
import json, sys
workflows = json.load(sys.stdin)
for i, wf in enumerate(workflows, 1):
    name = wf.get('name', 'Unknown')
    wf_id = wf.get('id', '')
    active = '🟢 ACTIVE' if wf.get('active', False) else '⚪ inactive'
    print(f\"  {i:3d}. {name:50s} {active} (ID: {wf_id})\")
" 2>/dev/null

echo ""
echo "Step 2: Deleting ALL workflows..."
echo ""

# Delete all workflows
DELETED_TOTAL=0
FAILED_IDS=()

echo "$ALL_WORKFLOWS_JSON" | python3 <<'PYEOF'
import json, sys
import subprocess
import os

workflows = json.load(sys.stdin)
n8n_url = os.environ.get('N8N_URL', 'http://localhost:5678')
n8n_api_key = os.environ.get('N8N_API_KEY', '')

deleted = 0
failed = []

for wf in workflows:
    wf_id = wf.get('id', '')
    wf_name = wf.get('name', 'Unknown')
    is_active = wf.get('active', False)
    
    if not wf_id:
        continue
    
    # Deactivate first if active
    if is_active:
        subprocess.run(['curl', '-s', '-X', 'POST',
            '-H', f'X-N8N-API-KEY: {n8n_api_key}',
            f'{n8n_url}/api/v1/workflows/{wf_id}/deactivate'],
            capture_output=True, timeout=5)
        sys.stdout.write(f"   Deactivating: {wf_name}... ")
        sys.stdout.flush()
    
    # Delete workflow
    result = subprocess.run(['curl', '-s', '-w', '%{http_code}', '-o', '/dev/null', '-X', 'DELETE',
        '-H', f'X-N8N-API-KEY: {n8n_api_key}',
        f'{n8n_url}/api/v1/workflows/{wf_id}'],
        capture_output=True, text=True, timeout=10)
    
    http_code = result.stdout.strip() if result.stdout else '000'
    
    if http_code in ['200', '204']:
        print(f"✅ Deleted")
        deleted += 1
    else:
        print(f"❌ Failed (HTTP {http_code})")
        failed.append({'id': wf_id, 'name': wf_name})

print(f"\nDELETED:{deleted}")
print(f"FAILED:{len(failed)}")
for f in failed:
    print(f"FAILED_ID:{f['id']}|{f['name']}")
PYEOF

# Parse results
DELETED_COUNT=$(echo "$ALL_WORKFLOWS_JSON" | python3 <<'PYEOF'
import json, sys
import subprocess
import os

workflows = json.load(sys.stdin)
n8n_url = os.environ.get('N8N_URL', 'http://localhost:5678')
n8n_api_key = os.environ.get('N8N_API_KEY', '')

deleted = 0
for wf in workflows:
    wf_id = wf.get('id', '')
    if not wf_id:
        continue
    
    # Deactivate first
    if wf.get('active', False):
        subprocess.run(['curl', '-s', '-X', 'POST',
            '-H', f'X-N8N-API-KEY: {n8n_api_key}',
            f'{n8n_url}/api/v1/workflows/{wf_id}/deactivate'],
            capture_output=True, timeout=5)
    
    # Delete
    result = subprocess.run(['curl', '-s', '-w', '%{http_code}', '-o', '/dev/null', '-X', 'DELETE',
        '-H', f'X-N8N-API-KEY: {n8n_api_key}',
        f'{n8n_url}/api/v1/workflows/{wf_id}'],
        capture_output=True, text=True, timeout=10)
    
    if result.stdout.strip() in ['200', '204']:
        deleted += 1

print(deleted)
PYEOF
)

echo ""
echo "   Deleted $DELETED_COUNT out of $WORKFLOW_COUNT workflow(s)"
echo "   Waiting 5 seconds for n8n to process..."
sleep 5

# Step 3: Verify deletion (multiple passes)
echo ""
echo "Step 3: Verifying deletion (multiple passes)..."
echo ""

MAX_VERIFY_PASSES=5
PASS=0
REMAINING_COUNT=$WORKFLOW_COUNT

while [[ $PASS -lt $MAX_VERIFY_PASSES ]] && [[ $REMAINING_COUNT -gt 0 ]]; do
    PASS=$((PASS + 1))
    echo "   Verification pass $PASS/$MAX_VERIFY_PASSES..."
    
    VERIFY_JSON=$(get_all_workflows)
    REMAINING_COUNT=$(echo "$VERIFY_JSON" | python3 -c "import json, sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    
    if [[ "$REMAINING_COUNT" -eq "0" ]]; then
        echo "   ✅ All workflows deleted!"
        break
    else
        echo "   ⚠️  $REMAINING_COUNT workflow(s) still remain"
        
        # Try to delete remaining ones again
        if [[ $PASS -lt $MAX_VERIFY_PASSES ]]; then
            echo "   Retrying deletion of remaining workflows..."
            echo "$VERIFY_JSON" | python3 <<'PYEOF'
import json, sys
import subprocess
import os

workflows = json.load(sys.stdin)
n8n_url = os.environ.get('N8N_URL', 'http://localhost:5678')
n8n_api_key = os.environ.get('N8N_API_KEY', '')

for wf in workflows:
    wf_id = wf.get('id', '')
    if not wf_id:
        continue
    
    # Deactivate first
    subprocess.run(['curl', '-s', '-X', 'POST',
        '-H', f'X-N8N-API-KEY: {n8n_api_key}',
        f'{n8n_url}/api/v1/workflows/{wf_id}/deactivate'],
        capture_output=True, timeout=5)
    
    # Delete
    subprocess.run(['curl', '-s', '-X', 'DELETE',
        '-H', f'X-N8N-API-KEY: {n8n_api_key}',
        f'{n8n_url}/api/v1/workflows/{wf_id}'],
        capture_output=True, timeout=10)

PYEOF
            sleep 3
        fi
    fi
    echo ""
done

# Final verification
FINAL_JSON=$(get_all_workflows)
FINAL_COUNT=$(echo "$FINAL_JSON" | python3 -c "import json, sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

echo "=========================================="
if [[ "$FINAL_COUNT" -eq "0" ]]; then
    echo "✅ SUCCESS: All workflows deleted!"
else
    echo "⚠️  WARNING: $FINAL_COUNT workflow(s) still remain"
    echo ""
    echo "Remaining workflows:"
    echo "$FINAL_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for wf in data:
    print(f\"  - {wf.get('name', 'Unknown')} (ID: {wf.get('id', '')})\")
" 2>/dev/null
fi
echo "=========================================="
echo ""
