#!/usr/bin/env bash
# Check which nodes actually executed in the latest execution
# Usage: bash scripts/check_execution_nodes.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

N8N_URL="http://localhost:5678"
N8N_USER="${N8N_USER:-sfitz911@gmail.com}"
N8N_PASSWORD="${N8N_PASSWORD:-Delrio77$}"
N8N_API_KEY="${N8N_API_KEY:-}"

# Get API key if needed
if [[ -z "$N8N_API_KEY" ]]; then
    N8N_API_KEY=$(bash scripts/get_or_create_api_key.sh 2>/dev/null || echo "")
    if [[ -z "$N8N_API_KEY" ]]; then
        echo "❌ Missing N8N_API_KEY environment variable" >&2
        echo "   Run: export N8N_API_KEY=\$(bash scripts/get_or_create_api_key.sh)" >&2
        exit 1
    fi
    # Validate API key format
    if [[ ! "$N8N_API_KEY" =~ ^n8n_[A-Za-z0-9]+$ ]]; then
        echo "❌ Invalid N8N_API_KEY format (must start with 'n8n_')" >&2
        echo "   Got: ${N8N_API_KEY:0:20}..." >&2
        exit 1
    fi
    export N8N_API_KEY
fi

# Get latest execution ID - try with workflow ID first
if [[ -n "$N8N_API_KEY" ]]; then
    WORKFLOW_ID=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/workflows" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if 'Five Teacher' in wf.get('name', ''):
            print(wf.get('id', ''))
            break
except:
    pass
" 2>/dev/null)
else
    WORKFLOW_ID=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/workflows" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if 'Five Teacher' in wf.get('name', ''):
            print(wf.get('id', ''))
            break
except:
    pass
" 2>/dev/null)
fi

if [[ -n "$WORKFLOW_ID" ]]; then
    echo "Workflow ID: $WORKFLOW_ID"
    if [[ -n "$N8N_API_KEY" ]]; then
        EXECUTIONS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1" 2>/dev/null)
    else
        EXECUTIONS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1" 2>/dev/null)
    fi
else
    if [[ -n "$N8N_API_KEY" ]]; then
        EXECUTIONS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions?limit=1" 2>/dev/null)
    else
        EXECUTIONS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions?limit=1" 2>/dev/null)
    fi
fi

# Debug: show what we got
echo "Executions API response (first 500 chars):"
echo "$EXECUTIONS" | head -c 500
echo ""
echo ""

# Check if response is valid JSON
if ! echo "$EXECUTIONS" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
    echo "⚠️  API response is not valid JSON"
    echo "Full response:"
    echo "$EXECUTIONS"
    echo ""
    echo "This might mean:"
    echo "  1. API key is invalid or missing"
    echo "  2. n8n API endpoint changed"
    echo "  3. No executions exist yet"
    exit 1
fi

LATEST_EXEC_ID=$(echo "$EXECUTIONS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    executions = data.get('data', [])
    if executions:
        print(executions[0].get('id', ''))
    else:
        print('')
except Exception as e:
    print('')
    sys.stderr.write(f'Error: {e}\\n')
" 2>&1)

if [[ -z "$LATEST_EXEC_ID" ]]; then
    echo "❌ No executions found"
    exit 1
fi

echo "Latest Execution ID: $LATEST_EXEC_ID"
echo ""

# Get execution data - save to file first
if [[ -n "$N8N_API_KEY" ]]; then
    EXEC_DATA=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}?includeData=true" 2>/dev/null)
else
    EXEC_DATA=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}?includeData=true" 2>/dev/null)
fi

# Save to file for inspection
echo "$EXEC_DATA" > /tmp/exec_full.json

# Parse and show nodes
echo "$EXEC_DATA" | python3 << 'PYTHON'
import json
import sys

try:
    data = json.load(sys.stdin)
    exec_data = data.get('data', {})
    
    print(f"Status: {exec_data.get('status', 'unknown')}")
    print(f"Finished: {exec_data.get('finished', False)}")
    print(f"Started: {exec_data.get('startedAt', 'N/A')}")
    print(f"Stopped: {exec_data.get('stoppedAt', 'N/A')}")
    print()
    
    result_data = exec_data.get('data', {}).get('resultData', {})
    run_data = result_data.get('runData', {})
    
    if not run_data:
        print("❌ No node execution data found")
        print("This means the workflow stopped immediately after webhook trigger")
        sys.exit(0)
    
    print("Nodes that executed:")
    print("=" * 60)
    
    for node_name, node_runs in run_data.items():
        if node_runs and len(node_runs) > 0:
            last_run = node_runs[-1]
            error = last_run.get('error', {})
            status = last_run.get('executionStatus', 'unknown')
            
            if error:
                print(f"❌ {node_name}: ERROR")
                print(f"   {error.get('message', 'Unknown error')}")
            elif status == 'success':
                print(f"✅ {node_name}: Success")
            else:
                print(f"⚠️  {node_name}: {status}")
        else:
            print(f"⚪ {node_name}: Not executed")
    
    print()
    print("=" * 60)
    
    # Check if Respond to Webhook executed
    respond_found = False
    for node_name in run_data.keys():
        if 'respond' in node_name.lower() or 'webhook' in node_name.lower():
            if node_name != 'Webhook Trigger':
                respond_found = True
                print(f"\n✅ 'Respond to Webhook' node found: {node_name}")
                break
    
    if not respond_found:
        print("\n❌ 'Respond to Webhook' node did NOT execute!")
        print("   The workflow is stopping before reaching the response node.")
        
except Exception as e:
    print(f"Error: {e}")
    print("\nRaw data saved to /tmp/exec_full.json")
    print("First 500 chars:")
    sys.stdin.seek(0)
    print(sys.stdin.read()[:500])
PYTHON
