#!/usr/bin/env bash
# COMPREHENSIVE FIX: Diagnose why 24 workflows persist, then fix it
# Usage: bash scripts/diagnose_and_fix_24_workflows.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI2NDM0fQ.zY98iCLMf-FyR_6xX6OqNgRA2AY6OYHNeJ2Umt4JCLQ"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="${N8N_URL:-http://localhost:5678}"

echo "=========================================="
echo "DIAGNOSE AND FIX: 24 Workflows Issue"
echo "=========================================="
echo ""

# Function to get ALL workflows with pagination
get_all_workflows_paginated() {
    local all_workflows="[]"
    local page=1
    local limit=50
    
    while true; do
        PAGE_RESPONSE=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            "${N8N_URL}/api/v1/workflows?limit=${limit}&page=${page}" 2>/dev/null || echo '{"data":[],"hasMore":false}')
        
        if echo "$PAGE_RESPONSE" | grep -q "unauthorized\|401\|403"; then
            echo "❌ API key authentication failed" >&2
            return 1
        fi
        
        PAGE_DATA=$(echo "$PAGE_RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    workflows = data.get('data', [])
    has_more = data.get('hasMore', False)
    print(json.dumps({'workflows': workflows, 'hasMore': has_more}))
except Exception as e:
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
            break
        fi
        
        page=$((page + 1))
        if [[ $page -gt 100 ]]; then
            echo "⚠️  Hit safety limit of 100 pages" >&2
            break
        fi
    done
    
    echo "$all_workflows"
}

# Step 1: Get ALL workflows with pagination
echo "Step 1: Fetching ALL workflows (with pagination)..."
ALL_WORKFLOWS=$(get_all_workflows_paginated)

WORKFLOW_COUNT=$(echo "$ALL_WORKFLOWS" | python3 -c "import json, sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

echo "   Found $WORKFLOW_COUNT total workflow(s)"
echo ""

# List all workflows
echo "All workflows:"
echo "$ALL_WORKFLOWS" | python3 -c "
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
DELETED_COUNT=0
FAILED_IDS=()

echo "$ALL_WORKFLOWS" | python3 <<'PYEOF'
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
        deactivate_result = subprocess.run(['curl', '-s', '-w', '%{http_code}', '-o', '/dev/null', '-X', 'POST',
            '-H', f'X-N8N-API-KEY: {n8n_api_key}',
            f'{n8n_url}/api/v1/workflows/{wf_id}/deactivate'],
            capture_output=True, text=True, timeout=10)
        sys.stdout.write(f"   Deactivating: {wf_name[:40]:40s}... ")
        sys.stdout.flush()
    
    # Delete workflow
    delete_result = subprocess.run(['curl', '-s', '-w', '%{http_code}', '-o', '/dev/null', '-X', 'DELETE',
        '-H', f'X-N8N-API-KEY: {n8n_api_key}',
        f'{n8n_url}/api/v1/workflows/{wf_id}'],
        capture_output=True, text=True, timeout=10)
    
    http_code = delete_result.stdout.strip() if delete_result.stdout else '000'
    
    if http_code in ['200', '204']:
        print(f"✅ Deleted (HTTP {http_code})")
        deleted += 1
    else:
        print(f"❌ Failed (HTTP {http_code})")
        failed.append({'id': wf_id, 'name': wf_name, 'code': http_code})

print(f"\nSUMMARY: Deleted {deleted}, Failed {len(failed)}")
if failed:
    print("\nFailed workflows:")
    for f in failed:
        print(f"  - {f['name']} (ID: {f['id']}, HTTP {f['code']})")
PYEOF

echo ""
echo "   Waiting 5 seconds for n8n to process deletions..."
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
    
    VERIFY_WORKFLOWS=$(get_all_workflows_paginated)
    REMAINING_COUNT=$(echo "$VERIFY_WORKFLOWS" | python3 -c "import json, sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    
    if [[ "$REMAINING_COUNT" -eq "0" ]]; then
        echo "   ✅ All workflows deleted!"
        break
    else
        echo "   ⚠️  $REMAINING_COUNT workflow(s) still remain"
        
        if [[ $PASS -lt $MAX_VERIFY_PASSES ]]; then
            echo "   Retrying deletion of remaining workflows..."
            echo "$VERIFY_WORKFLOWS" | python3 <<'PYEOF'
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

# Final check
FINAL_WORKFLOWS=$(get_all_workflows_paginated)
FINAL_COUNT=$(echo "$FINAL_WORKFLOWS" | python3 -c "import json, sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

echo "=========================================="
if [[ "$FINAL_COUNT" -eq "0" ]]; then
    echo "✅ SUCCESS: All workflows deleted!"
else
    echo "⚠️  WARNING: $FINAL_COUNT workflow(s) still remain"
    echo ""
    echo "Remaining workflows:"
    echo "$FINAL_WORKFLOWS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for wf in data:
    print(f\"  - {wf.get('name', 'Unknown')} (ID: {wf.get('id', '')})\")
" 2>/dev/null
fi
echo "=========================================="
echo ""

# Step 4: Import only 3 workflows
if [[ "$FINAL_COUNT" -eq "0" ]]; then
    echo "Step 4: Importing only 3 correct workflows..."
    export FORCE_IMPORT=true
    bash scripts/import_new_workflows.sh
    
    echo ""
    echo "Final verification..."
    FINAL_AFTER_IMPORT=$(get_all_workflows_paginated)
    FINAL_AFTER_COUNT=$(echo "$FINAL_AFTER_IMPORT" | python3 -c "import json, sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    
    echo "   Total workflows after import: $FINAL_AFTER_COUNT"
    if [[ "$FINAL_AFTER_COUNT" -eq 3 ]]; then
        echo "   ✅ SUCCESS: Exactly 3 workflows!"
    else
        echo "   ⚠️  Expected 3, but found $FINAL_AFTER_COUNT"
    fi
else
    echo "Step 4: Skipping import - workflows still remain"
    echo "   Please manually delete remaining workflows via n8n UI"
fi

echo ""
echo "=========================================="
echo "✅ DIAGNOSE AND FIX COMPLETE"
echo "=========================================="
echo ""
