#!/usr/bin/env bash
# Trigger webhook and debug execution
# Usage: bash scripts/trigger_and_debug.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

N8N_URL="http://localhost:5678"
# Default API key (hardcoded fallback)
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhNDE1ODkzYS1hY2Q2LTQ2NWYtODcyNS02NDQzZTRkNTkyZTkiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MDYxNjMwfQ.faRO3CRuldcSQd0-g9sJORo8tUq_vfMMDpOmXQTPH0I"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"

echo "=========================================="
echo "Triggering Webhook and Debugging"
echo "=========================================="
echo ""

# Get workflow ID first
if [[ -n "$N8N_API_KEY" ]]; then
    WORKFLOWS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/workflows")
else
    WORKFLOWS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/workflows")
fi

WORKFLOW_ID=$(echo "$WORKFLOWS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for wf in data.get('data', []):
    if 'Five Teacher' in wf.get('name', ''):
        print(wf['id'])
        break
" 2>/dev/null || echo "")

if [[ -z "$WORKFLOW_ID" ]]; then
    echo "❌ Five Teacher workflow not found"
    exit 1
fi

echo "Workflow ID: $WORKFLOW_ID"
echo ""

# Get current execution count
echo "Getting current execution count..."
if [[ -n "$N8N_API_KEY" ]]; then
    BEFORE_EXEC=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1")
else
    BEFORE_EXEC=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1")
fi

BEFORE_ID=$(echo "$BEFORE_EXEC" | python3 -c "import sys, json; d=json.load(sys.stdin); execs=d.get('data',[]); print(execs[0].get('id','0') if execs else '0')" 2>/dev/null || echo "0")
echo "Current latest execution ID: $BEFORE_ID"
echo ""

# Trigger webhook
echo "Triggering webhook..."
WEBHOOK_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "Hello, test message", "timestamp": '$(date +%s)'}')

HTTP_CODE=$(echo "$WEBHOOK_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$WEBHOOK_RESPONSE" | grep -v "HTTP_CODE:")

echo "Webhook HTTP Status: $HTTP_CODE"
if [[ -n "$BODY" ]]; then
    echo "Webhook Response: $BODY"
else
    echo "Webhook Response: [EMPTY]"
fi
echo ""

# Wait a bit
echo "Waiting 5 seconds for execution to complete..."
sleep 5

# Get new execution
echo "Checking for new execution..."
if [[ -n "$N8N_API_KEY" ]]; then
    EXECUTIONS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=5")
else
    EXECUTIONS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=5")
fi

echo "Raw executions response (first 500 chars):"
echo "$EXECUTIONS" | head -c 500
echo ""
echo ""

NEW_EXEC_ID=$(echo "$EXECUTIONS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    executions = data.get('data', [])
    if executions:
        print(executions[0].get('id', ''))
    else:
        print('')
except Exception as e:
    print(f'ERROR: {e}')
" 2>/dev/null || echo "")

if [[ -z "$NEW_EXEC_ID" ]] || [[ "$NEW_EXEC_ID" == "$BEFORE_ID" ]]; then
    echo "⚠️  No new execution found or same as before"
    echo "   This might mean the webhook didn't trigger the workflow"
    echo ""
    echo "Checking if webhook is registered..."
    curl -s -X POST "${N8N_URL}/webhook/chat-webhook" \
        -H "Content-Type: application/json" \
        -d '{"test": "test"}' 2>&1 | head -20
    exit 1
fi

echo "New execution ID: $NEW_EXEC_ID"
echo ""

# Get execution details
echo "Fetching execution details..."
if [[ -n "$N8N_API_KEY" ]]; then
    EXEC_DETAILS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${NEW_EXEC_ID}")
else
    EXEC_DETAILS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions/${NEW_EXEC_ID}")
fi

echo "Execution summary:"
echo "$EXEC_DETAILS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    exec_data = data.get('data', {})
    print(f'  Status: {exec_data.get(\"status\", \"N/A\")}')
    print(f'  Finished: {exec_data.get(\"finished\", False)}')
    print(f'  Started: {exec_data.get(\"startedAt\", \"N/A\")}')
    print(f'  Stopped: {exec_data.get(\"stoppedAt\", \"N/A\")}')
    print()
    
    # Check for data field
    if 'data' in exec_data:
        print('✅ Execution has data field')
        result_data = exec_data.get('data', {}).get('resultData', {})
        run_data = result_data.get('runData', {})
        
        if run_data:
            print(f'  Nodes executed: {len(run_data)}')
            for node_name, node_runs in list(run_data.items())[:5]:
                if node_runs:
                    last_run = node_runs[-1]
                    error = last_run.get('error', {})
                    if error:
                        print(f'    ❌ {node_name}: {error.get(\"message\", \"Error\")}')
                    else:
                        print(f'    ✅ {node_name}: Success')
        else:
            print('  ⚠️  No node execution data')
    else:
        print('❌ Execution missing data field')
        print('   Full response:')
        print(json.dumps(data, indent=2))
except Exception as e:
    print(f'Error: {e}')
    print('Raw response:')
    sys.stdin.seek(0)
    print(sys.stdin.read()[:1000])
" 2>/dev/null || echo "Failed to parse execution"
