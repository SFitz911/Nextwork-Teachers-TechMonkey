#!/usr/bin/env bash
# Consolidated execution inspection - replaces multiple execution check scripts
# Usage: 
#   bash scripts/inspect_execution.sh [execution_id]
#   bash scripts/inspect_execution.sh --latest
#   bash scripts/inspect_execution.sh --nodes [execution_id]
#   bash scripts/inspect_execution.sh --raw [execution_id]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"
# Default API key (hardcoded fallback)
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmNzRkZjc2OC0wZTVhLTQ2OGQtODFiYS1iYTZiMGFiNjAwY2EiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MTQzMDY3fQ.JQU3yyBofIJBX-50Zjdc9GnW7xLMf1QcZrVlgJ-OdbA"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="${N8N_URL:-http://localhost:5678}"

# Get workflow ID
WORKFLOWS_JSON=$(curl -s \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null)

WORKFLOW_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if 'Five Teacher' in wf.get('name', '') or 'AI Virtual Classroom' in wf.get('name', ''):
            print(wf.get('id', ''))
            break
except:
    pass
" 2>/dev/null)

if [[ -z "$WORKFLOW_ID" ]]; then
    echo "❌ Workflow not found"
    echo "   Run: bash scripts/clean_and_import_workflow.sh"
    exit 1
fi

# Parse arguments
MODE="${1:-latest}"
EXECUTION_ID="${2:-}"

if [[ "$MODE" == "--latest" ]] || [[ "$MODE" == "latest" ]]; then
    # Get latest execution
    EXECUTIONS=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1" 2>/dev/null)
    
    EXECUTION_ID=$(echo "$EXECUTIONS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    execs = data.get('data', [])
    if execs:
        print(execs[0].get('id', ''))
except:
    pass
" 2>/dev/null)
    
    if [[ -z "$EXECUTION_ID" ]]; then
        echo "❌ No executions found"
        exit 1
    fi
    MODE="full"
elif [[ "$MODE" == "--nodes" ]]; then
    if [[ -z "$EXECUTION_ID" ]]; then
        echo "❌ Execution ID required for --nodes mode"
        exit 1
    fi
    MODE="nodes"
elif [[ "$MODE" == "--raw" ]]; then
    if [[ -z "$EXECUTION_ID" ]]; then
        echo "❌ Execution ID required for --raw mode"
        exit 1
    fi
    MODE="raw"
elif [[ "$MODE" =~ ^[0-9]+$ ]]; then
    # Numeric execution ID provided
    EXECUTION_ID="$MODE"
    MODE="full"
else
    EXECUTION_ID="$MODE"
    MODE="full"
fi

# Fetch execution details
EXECUTION_JSON=$(curl -s \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/executions/${EXECUTION_ID}?includeData=true" 2>/dev/null)

if echo "$EXECUTION_JSON" | grep -q "unauthorized\|401\|not found"; then
    echo "❌ Failed to fetch execution"
    echo "Response: $(echo "$EXECUTION_JSON" | head -c 200)"
    exit 1
fi

# Process based on mode
case "$MODE" in
    "raw")
        echo "=== Raw Execution Data ==="
        echo "$EXECUTION_JSON" | python3 -m json.tool 2>/dev/null || echo "$EXECUTION_JSON"
        ;;
    "nodes")
        echo "=== Execution Nodes ==="
        echo "$EXECUTION_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    result_data = data.get('data', {}).get('data', {}).get('resultData', {})
    run_data = result_data.get('runData', {})
    
    if run_data:
        print('Nodes executed:')
        for node_name, node_data in run_data.items():
            executions = node_data.get('executions', [])
            if executions:
                status = executions[0].get('executionStatus', 'unknown')
                print(f'  {node_name}: {status}')
    else:
        print('No node execution data found')
except Exception as e:
    print(f'Error parsing: {e}')
" 2>/dev/null
        ;;
    "full"|*)
        echo "=========================================="
        echo "Execution Details: $EXECUTION_ID"
        echo "=========================================="
        echo ""
        
        # Basic info
        echo "$EXECUTION_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    exec_data = data.get('data', {})
    
    print(f\"Execution ID: {exec_data.get('id', 'N/A')}\")
    print(f\"Status: {exec_data.get('status', 'N/A')}\")
    print(f\"Finished: {exec_data.get('finished', False)}\")
    print(f\"Started: {exec_data.get('startedAt', 'N/A')}\")
    print(f\"Stopped: {exec_data.get('stoppedAt', 'N/A')}\")
    print()
    
    # Node execution summary
    result_data = exec_data.get('data', {}).get('resultData', {})
    run_data = result_data.get('runData', {})
    
    if run_data:
        print('Nodes executed:')
        for node_name, node_data in run_data.items():
            executions = node_data.get('executions', [])
            if executions:
                status = executions[0].get('executionStatus', 'unknown')
                print(f'  ✅ {node_name}: {status}')
    else:
        print('⚠️  No node execution data found')
except Exception as e:
    print(f'Error: {e}')
" 2>/dev/null
        ;;
esac
