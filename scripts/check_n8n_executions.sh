#!/bin/bash
# Check recent n8n workflow executions
# Usage: bash scripts/check_n8n_executions.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Get n8n API key
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI2ODU4OGE3Mi0xN2YyLTQ1NzUtYTZmNi1jOTc5OGU2YjZhNGIiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5NDAzNzE3fQ.Q2S2ioWmVFx55zSJoqQaUcKhpl-Bo22Vyv-1bdVVNV0"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="http://localhost:5678"

echo "=========================================="
echo "Checking n8n Workflow Executions"
echo "=========================================="
echo ""

# Get recent executions
EXECUTIONS=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/executions?limit=5" 2>/dev/null)

if [[ -z "$EXECUTIONS" ]] || echo "$EXECUTIONS" | grep -q "error\|unauthorized"; then
    echo "❌ Failed to get executions (check API key)"
    exit 1
fi

# Parse and display executions
echo "$EXECUTIONS" | python3 <<EOF
import json, sys
from datetime import datetime

try:
    data = json.load(sys.stdin)
    executions = data.get('data', [])
    
    if not executions:
        print("No recent executions found")
        sys.exit(0)
    
    print(f"Found {len(executions)} recent execution(s):\n")
    
    for i, exec in enumerate(executions, 1):
        workflow_id = exec.get('workflowId', 'unknown')
        workflow_name = exec.get('workflow', {}).get('name', 'Unknown Workflow')
        status = exec.get('finished', False)
        mode = exec.get('mode', 'unknown')
        started_at = exec.get('startedAt', '')
        stopped_at = exec.get('stoppedAt', '')
        
        # Get workflow name from workflow data
        if 'workflow' in exec and 'name' in exec['workflow']:
            workflow_name = exec['workflow']['name']
        
        status_icon = "✅" if status else "⏳"
        status_text = "Finished" if status else "Running"
        
        print(f"{i}. {workflow_name}")
        print(f"   Status: {status_icon} {status_text}")
        print(f"   Mode: {mode}")
        print(f"   Started: {started_at}")
        if stopped_at:
            print(f"   Stopped: {stopped_at}")
        
        # Check for errors
        if exec.get('data', {}).get('resultData', {}).get('error'):
            error = exec['data']['resultData']['error']
            print(f"   ❌ ERROR: {error.get('message', 'Unknown error')}")
        
        # Show node execution status if available
        if 'data' in exec and 'resultData' in exec['data']:
            result_data = exec['data']['resultData']
            if 'runData' in result_data:
                print(f"   Nodes executed:")
                for node_name, node_data in result_data['runData'].items():
                    if isinstance(node_data, dict) and 'main' in node_data:
                        main_data = node_data['main']
                        if isinstance(main_data, list) and len(main_data) > 0:
                            exec_count = len(main_data[0]) if isinstance(main_data[0], list) else 0
                            if exec_count > 0:
                                print(f"      - {node_name}: ✅ Executed")
                            else:
                                print(f"      - {node_name}: ⏳ Pending")
        
        print()
        
except Exception as e:
    print(f"Error parsing executions: {e}")
    print("\nRaw response:")
    print(sys.stdin.read())
EOF

echo ""
echo "To see detailed execution:"
echo "  1. Open http://localhost:5678 (with port forwarding)"
echo "  2. Go to 'Executions' tab"
echo "  3. Click on an execution to see node-by-node details"
echo ""
