#!/usr/bin/env bash
# Check workflow structure and node connections
# Usage: bash scripts/check_workflow_structure.sh

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

echo "=========================================="
echo "Checking Workflow Structure"
echo "=========================================="
echo ""

# Get workflow details
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

# Get workflow details
if [[ -n "$N8N_API_KEY" ]]; then
    WORKFLOW_DETAILS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}")
else
    WORKFLOW_DETAILS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}")
fi

# Check if we got a valid response
if [[ -z "$WORKFLOW_DETAILS" ]] || [[ "$WORKFLOW_DETAILS" == *"error"* ]] || [[ "$WORKFLOW_DETAILS" == *"Unauthorized"* ]]; then
    echo "❌ Failed to get workflow details"
    echo "Response: $WORKFLOW_DETAILS"
    echo ""
    echo "Trying with basic auth instead..."
    WORKFLOW_DETAILS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}")
    if [[ -z "$WORKFLOW_DETAILS" ]]; then
        echo "Still failed. Check authentication."
        exit 1
    fi
fi

echo "Analyzing workflow structure..."
echo "$WORKFLOW_DETAILS" | python3 << 'PYTHON'
import sys, json

try:
    data = json.load(sys.stdin)
    workflow = data.get('data', {})
    
    print("Workflow Name:", workflow.get('name', 'N/A'))
    print("Active:", workflow.get('active', False))
    print()
    
    nodes = workflow.get('nodes', [])
    connections = workflow.get('connections', {})
    
    print(f"Total nodes: {len(nodes)}")
    print()
    
    # Check webhook node
    webhook_node = None
    for node in nodes:
        if node.get('type') == 'n8n-nodes-base.webhook':
            webhook_node = node
            print("✅ Webhook node found:")
            print(f"   Name: {node.get('name', 'N/A')}")
            print(f"   Path: {node.get('parameters', {}).get('path', 'N/A')}")
            print(f"   Method: {node.get('parameters', {}).get('httpMethod', 'N/A')}")
            print(f"   Response Mode: {node.get('parameters', {}).get('responseMode', 'N/A')}")
            print()
            break
    
    if not webhook_node:
        print("❌ Webhook node not found!")
        sys.exit(1)
    
    # Check Respond to Webhook node
    respond_node = None
    for node in nodes:
        if node.get('type') == 'n8n-nodes-base.respondToWebhook':
            respond_node = node
            print("✅ Respond to Webhook node found:")
            print(f"   Name: {node.get('name', 'N/A')}")
            print(f"   Response Mode: {node.get('parameters', {}).get('responseMode', 'N/A')}")
            print()
            break
    
    if not respond_node:
        print("❌ Respond to Webhook node not found!")
        sys.exit(1)
    
    # Check node connections
    print("Checking node connections...")
    print()
    
    # Find first node after webhook
    webhook_name = webhook_node.get('name', '')
    webhook_connections = connections.get(webhook_name, {})
    
    if webhook_connections.get('main'):
        next_nodes = webhook_connections['main'][0] if webhook_connections['main'] else []
        if next_nodes:
            print(f"✅ Webhook connects to: {next_nodes[0].get('node', 'N/A')}")
        else:
            print("❌ Webhook has no connections!")
    else:
        print("❌ Webhook has no connections!")
    
    # Check if Respond to Webhook is connected
    respond_name = respond_node.get('name', '')
    # Find what connects to Respond to Webhook
    found_connection = False
    for source_node, conns in connections.items():
        if conns.get('main'):
            for conn_list in conns['main']:
                for conn in conn_list:
                    if conn.get('node') == respond_name:
                        print(f"✅ '{source_node}' connects to 'Respond to Webhook'")
                        found_connection = True
                        break
    
    if not found_connection:
        print("❌ 'Respond to Webhook' node is not connected!")
    
    print()
    print("Node list:")
    for i, node in enumerate(nodes, 1):
        node_type = node.get('type', 'unknown').replace('n8n-nodes-base.', '')
        print(f"  {i}. {node.get('name', 'N/A')} ({node_type})")
    
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON
