#!/usr/bin/env bash
# Wait for execution to complete and check detailed execution data
# Usage: bash scripts/wait_and_check_execution.sh [execution_id]

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
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmNzRkZjc2OC0wZTVhLTQ2OGQtODFiYS1iYTZiMGFiNjAwY2EiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MTQzMDY3fQ.JQU3yyBofIJBX-50Zjdc9GnW7xLMf1QcZrVlgJ-OdbA"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"

EXEC_ID="${1:-}"

if [[ -z "$EXEC_ID" ]]; then
    echo "Usage: bash scripts/wait_and_check_execution.sh <execution_id>"
    echo ""
    echo "First, trigger a webhook to get an execution ID:"
    echo "  curl -X POST http://localhost:5678/webhook/chat-webhook -H 'Content-Type: application/json' -d '{\"message\":\"test\"}'"
    exit 1
fi

echo "Waiting for execution $EXEC_ID to complete..."
echo ""

# Wait and check execution multiple times
for i in {1..10}; do
    if [[ -n "$N8N_API_KEY" ]]; then
        EXEC_DATA=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${EXEC_ID}")
    else
        EXEC_DATA=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions/${EXEC_ID}")
    fi
    
    FINISHED=$(echo "$EXEC_DATA" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('finished', False))" 2>/dev/null || echo "false")
    
    if [[ "$FINISHED" == "True" ]]; then
        echo "✅ Execution finished"
        echo ""
        break
    else
        echo "⏳ Waiting... (attempt $i/10)"
        sleep 1
    fi
done

echo "Execution Details:"
echo "$EXEC_DATA" | python3 -m json.tool 2>/dev/null || echo "$EXEC_DATA"
echo ""

# Check if execution has data field
HAS_DATA=$(echo "$EXEC_DATA" | python3 -c "import sys, json; d=json.load(sys.stdin); print('data' in d)" 2>/dev/null || echo "false")

if [[ "$HAS_DATA" == "True" ]]; then
    echo "✅ Execution has 'data' field"
    echo ""
    echo "Parsing execution data..."
    echo "$EXEC_DATA" | python3 << 'PYTHON'
import sys, json
data = json.load(sys.stdin)
exec_data = data.get('data', {})
result_data = exec_data.get('data', {}).get('resultData', {})
run_data = result_data.get('runData', {})

if run_data:
    print("Nodes executed:")
    for node_name, node_runs in run_data.items():
        if node_runs:
            last_run = node_runs[-1]
            error = last_run.get('error', {})
            if error:
                print(f"  ❌ {node_name}: {error.get('message', 'Error')}")
            else:
                print(f"  ✅ {node_name}: Success")
                # Show output preview
                output = last_run.get('data', {}).get('main', [])
                if output:
                    json_out = output[0].get('json', {})
                    if isinstance(json_out, dict):
                        keys = list(json_out.keys())[:3]
                        print(f"     Output keys: {keys}")
else:
    print("⚠️  No node execution data found")
    print("   This means the workflow didn't execute any nodes")
PYTHON
else
    echo "❌ Execution missing 'data' field"
    echo ""
    echo "This usually means:"
    echo "  1. The workflow failed immediately"
    echo "  2. The execution data was cleaned up"
    echo "  3. The workflow didn't actually run"
    echo ""
    echo "Check n8n logs:"
    echo "  tail -50 logs/n8n.log | grep -i error"
fi
