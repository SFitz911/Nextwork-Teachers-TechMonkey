#!/usr/bin/env bash
# Trigger webhook and immediately inspect the execution
# Usage: bash scripts/trigger_and_inspect.sh

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
echo "Triggering Webhook and Inspecting Execution"
echo "=========================================="
echo ""

# Get workflow ID
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
if [[ -n "$N8N_API_KEY" ]]; then
    BEFORE_EXEC=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('data', [{}])[0].get('id', '0'))" 2>/dev/null || echo "0")
else
    BEFORE_EXEC=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('data', [{}])[0].get('id', '0'))" 2>/dev/null || echo "0")
fi

echo "Current latest execution ID: $BEFORE_EXEC"
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

# Wait for execution to complete
echo "Waiting for execution to complete..."
sleep 3

# Get new execution
if [[ -n "$N8N_API_KEY" ]]; then
    EXECUTIONS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1")
else
    EXECUTIONS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1")
fi

NEW_EXEC_ID=$(echo "$EXECUTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
executions = data.get('data', [])
if executions:
    print(executions[0].get('id', ''))
" 2>/dev/null || echo "")

if [[ -z "$NEW_EXEC_ID" ]] || [[ "$NEW_EXEC_ID" == "$BEFORE_EXEC" ]]; then
    echo "⚠️  No new execution found (or same as before)"
    echo "   This might mean the webhook didn't trigger the workflow"
    exit 1
fi

echo "New execution ID: $NEW_EXEC_ID"
echo ""

# Get full execution details
echo "Fetching execution details..."
if [[ -n "$N8N_API_KEY" ]]; then
    EXEC_DETAILS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${NEW_EXEC_ID}")
else
    EXEC_DETAILS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions/${NEW_EXEC_ID}")
fi

# Check if we got data
if echo "$EXEC_DETAILS" | python3 -c "import sys, json; d=json.load(sys.stdin); print('data' in d)" 2>/dev/null | grep -q "True"; then
    echo "✅ Execution has data field"
    echo ""
    
    # Show execution summary
    echo "$EXEC_DETAILS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
exec_data = data.get('data', {})
print('Execution Summary:')
print(f'  Status: {exec_data.get(\"status\", \"N/A\")}')
print(f'  Finished: {exec_data.get(\"finished\", False)}')
print(f'  Started: {exec_data.get(\"startedAt\", \"N/A\")}')
print(f'  Stopped: {exec_data.get(\"stoppedAt\", \"N/A\")}')
print()

# Check result data
result_data = exec_data.get('data', {}).get('resultData', {})
run_data = result_data.get('runData', {})

if run_data:
    print(f'Nodes executed: {len(run_data)}')
    for node_name, node_runs in run_data.items():
        if node_runs:
            last_run = node_runs[-1]
            error = last_run.get('error', {})
            if error:
                print(f'  ❌ {node_name}: {error.get(\"message\", \"Error\")}')
            else:
                print(f'  ✅ {node_name}: Success')
else:
    print('⚠️  No node execution data found')
    print('   This means the workflow might have failed immediately')
" 2>/dev/null || echo "Failed to parse execution details"
else
    echo "❌ Execution response missing 'data' field"
    echo ""
    echo "Raw response:"
    echo "$EXEC_DETAILS" | python3 -m json.tool 2>/dev/null || echo "$EXEC_DETAILS"
fi
