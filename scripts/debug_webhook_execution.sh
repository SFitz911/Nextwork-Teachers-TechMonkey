#!/usr/bin/env bash
# Debug webhook execution - check where the workflow is failing
# Usage: bash scripts/debug_webhook_execution.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

N8N_URL="http://localhost:5678"
N8N_API_KEY="${N8N_API_KEY:-}"
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"

echo "=========================================="
echo "Debugging Webhook Execution"
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

# Get recent executions
echo "1. Checking recent executions..."
echo ""

if [[ -n "$N8N_API_KEY" ]]; then
    EXECUTIONS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=3")
else
    EXECUTIONS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=3")
fi

echo "$EXECUTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
executions = data.get('data', [])
if not executions:
    print('No executions found')
    sys.exit(0)
    
for i, ex in enumerate(executions[:3], 1):
    print(f'Execution {i}:')
    print(f'  ID: {ex.get(\"id\", \"N/A\")}')
    print(f'  Finished: {ex.get(\"finished\", False)}')
    print(f'  Stopped at: {ex.get(\"stoppedAt\", \"N/A\")}')
    print(f'  Mode: {ex.get(\"mode\", \"N/A\")}')
    print(f'  Status: {ex.get(\"status\", \"N/A\")}')
    print()
" 2>/dev/null || echo "Failed to parse executions"

# Get the most recent execution ID
LATEST_EXEC_ID=$(echo "$EXECUTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
executions = data.get('data', [])
if executions:
    print(executions[0].get('id', ''))
" 2>/dev/null || echo "")

if [[ -n "$LATEST_EXEC_ID" ]]; then
    echo "2. Getting details for latest execution (ID: $LATEST_EXEC_ID)..."
    echo ""
    
    if [[ -n "$N8N_API_KEY" ]]; then
        EXEC_DETAILS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}")
    else
        EXEC_DETAILS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}")
    fi
    
    echo "$EXEC_DETAILS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
exec_data = data.get('data', {})
workflow_data = exec_data.get('workflowData', {})
nodes = workflow_data.get('nodes', [])

print('Execution Status:', exec_data.get('finished', False))
print('Stopped At:', exec_data.get('stoppedAt', 'N/A'))
print()

# Check for errors
execution_data = exec_data.get('data', {})
result_data = execution_data.get('resultData', {})
run_data = result_data.get('runData', {})

print('Node Execution Results:')
print('=' * 50)

for node_name, node_runs in run_data.items():
    if node_runs and len(node_runs) > 0:
        last_run = node_runs[-1]
        error = last_run.get('error', {})
        if error:
            print(f'❌ {node_name}: ERROR')
            print(f'   Error: {error.get(\"message\", \"Unknown error\")}')
        else:
            output = last_run.get('data', {}).get('main', [])
            if output and len(output) > 0:
                output_data = output[0]
                print(f'✅ {node_name}: Success')
                # Show a preview of the output
                json_output = output_data.get('json', {})
                if isinstance(json_output, dict):
                    keys = list(json_output.keys())[:5]
                    print(f'   Output keys: {keys}')
            else:
                print(f'⚠️  {node_name}: No output data')
    else:
        print(f'⚠️  {node_name}: Not executed')
" 2>/dev/null || echo "Failed to parse execution details"
fi

echo ""
echo "3. Testing webhook with verbose output..."
echo ""

# Test webhook and show full response
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME_TOTAL:%{time_total}" -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "Hello, test", "timestamp": '$(date +%s)'}')

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
TIME_TOTAL=$(echo "$RESPONSE" | grep "TIME_TOTAL:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:" | grep -v "TIME_TOTAL:")

echo "HTTP Status: $HTTP_CODE"
echo "Response Time: ${TIME_TOTAL}s"
echo ""

if [[ -z "$BODY" ]]; then
    echo "❌ Response body is EMPTY"
    echo ""
    echo "This means the workflow executed but didn't return a response."
    echo "Check the execution details above to see where it failed."
else
    echo "Response body:"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
fi

echo ""
echo "4. Checking n8n logs for errors..."
echo ""
tail -30 logs/n8n.log 2>/dev/null | grep -i "error\|fail\|exception" || echo "No recent errors in logs"

echo ""
echo "=========================================="
echo "Debug Complete"
echo "=========================================="
