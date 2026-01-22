#!/usr/bin/env bash
# Inspect the latest workflow execution in detail
# Usage: bash scripts/inspect_latest_execution.sh

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
N8N_USER="${N8N_USER:-sfitz911@gmail.com}"
N8N_PASSWORD="${N8N_PASSWORD:-Delrio77$}"

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

# Get latest execution
if [[ -n "$N8N_API_KEY" ]]; then
    EXECUTIONS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1")
else
    EXECUTIONS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1")
fi

LATEST_EXEC_ID=$(echo "$EXECUTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
executions = data.get('data', [])
if executions:
    print(executions[0].get('id', ''))
else:
    print('')
" 2>/dev/null || echo "")

if [[ -z "$LATEST_EXEC_ID" ]]; then
    echo "❌ No executions found. Trigger the webhook first."
    exit 1
fi

echo "Latest Execution ID: $LATEST_EXEC_ID"
echo ""

# Get execution details with verbose error checking
echo "Fetching execution details for ID: $LATEST_EXEC_ID..."

# Make sure we have an API key
if [[ -z "$N8N_API_KEY" ]]; then
    echo "Getting API key..."
    N8N_API_KEY=$(bash scripts/get_or_create_api_key.sh 2>/dev/null || echo "")
    if [[ -z "$N8N_API_KEY" ]]; then
        echo "❌ Could not get API key. Trying basic auth..."
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}?includeData=true")
        echo "HTTP Status: $HTTP_CODE"
        EXEC_DETAILS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}?includeData=true")
    else
        export N8N_API_KEY
    fi
fi

if [[ -n "$N8N_API_KEY" ]]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}?includeData=true")
    echo "HTTP Status: $HTTP_CODE"
    EXEC_DETAILS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}?includeData=true")
else
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}?includeData=true")
    echo "HTTP Status: $HTTP_CODE"
    EXEC_DETAILS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}?includeData=true")
fi

echo "Response length: ${#EXEC_DETAILS} characters"
if [[ ${#EXEC_DETAILS} -lt 10 ]]; then
    echo "⚠️  Response is very short, trying without includeData..."
    if [[ -n "$N8N_API_KEY" ]]; then
        EXEC_DETAILS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}")
    else
        EXEC_DETAILS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}")
    fi
    echo "Response length (without includeData): ${#EXEC_DETAILS} characters"
fi

# Check if we got a valid response
if [[ -z "$EXEC_DETAILS" ]] || [[ "$EXEC_DETAILS" == *"error"* ]] || [[ "$EXEC_DETAILS" == *"Unauthorized"* ]]; then
    echo "❌ Failed to get execution details"
    echo "Response: $EXEC_DETAILS"
    echo ""
    echo "Trying without includeData parameter..."
    if [[ -n "$N8N_API_KEY" ]]; then
        EXEC_DETAILS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}")
    else
        EXEC_DETAILS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}")
    fi
    if [[ -z "$EXEC_DETAILS" ]]; then
        echo "Still empty. Checking API response..."
        echo "HTTP Status:"
        if [[ -n "$N8N_API_KEY" ]]; then
            curl -s -o /dev/null -w "%{http_code}" -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}"
        else
            curl -s -o /dev/null -w "%{http_code}" -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}"
        fi
        echo ""
        exit 1
    fi
fi

# Debug: Save response to file to inspect
echo "$EXEC_DETAILS" > /tmp/exec_response.json 2>/dev/null || true

# Check if response is valid JSON
if ! echo "$EXEC_DETAILS" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
    echo "⚠️  Response is not valid JSON"
    echo "First 500 characters of response:"
    echo "$EXEC_DETAILS" | head -c 500
    echo ""
    echo ""
    echo "Full response saved to /tmp/exec_response.json for inspection"
    echo "Checking response type..."
    echo "$EXEC_DETAILS" | head -c 100
    echo ""
    echo ""
    echo "This might be HTML or an error page. Checking if n8n is accessible..."
    curl -s http://localhost:5678 > /dev/null && echo "✅ n8n is accessible" || echo "❌ n8n is not accessible"
    exit 1
fi

# Parse and display execution details
echo "$EXEC_DETAILS" | python3 << 'PYTHON_SCRIPT'
import sys
import json

try:
    data = json.load(sys.stdin)
    exec_data = data.get('data', {})
    
    print("Execution Status:")
    print(f"  Finished: {exec_data.get('finished', False)}")
    print(f"  Stopped At: {exec_data.get('stoppedAt', 'N/A')}")
    print(f"  Started At: {exec_data.get('startedAt', 'N/A')}")
    print()
    
    # Get workflow data
    workflow_data = exec_data.get('workflowData', {})
    result_data = exec_data.get('data', {}).get('resultData', {})
    run_data = result_data.get('runData', {})
    
    # Expected node order
    expected_nodes = [
        "Webhook Trigger",
        "Select Teacher (Round-Robin)",
        "Switch Teacher",
        "LLM Generate",
        "Extract LLM Response",
        "TTS Generate",
        "Prepare Animation",
        "Animation Generate",
        "Format Response",
        "Respond to Webhook"
    ]
    
    print("Node Execution Status:")
    print("=" * 60)
    
    for node_name in expected_nodes:
        # Find node in run_data (node names might be slightly different)
        node_found = False
        for actual_node_name, node_runs in run_data.items():
            if node_name.lower().replace(' ', '-') in actual_node_name.lower().replace(' ', '-') or \
               actual_node_name.lower().replace(' ', '-') in node_name.lower().replace(' ', '-'):
                node_found = True
                if node_runs and len(node_runs) > 0:
                    last_run = node_runs[-1]
                    error = last_run.get('error', {})
                    if error:
                        print(f"❌ {node_name}: ERROR")
                        print(f"   Message: {error.get('message', 'Unknown error')}")
                    else:
                        output = last_run.get('data', {}).get('main', [])
                        if output and len(output) > 0:
                            output_data = output[0]
                            json_output = output_data.get('json', {})
                            print(f"✅ {node_name}: Success")
                            if isinstance(json_output, dict):
                                # Show key fields
                                if 'response' in json_output or 'text' in json_output:
                                    text = json_output.get('response') or json_output.get('text', '')[:50]
                                    print(f"   Output preview: {text}...")
                                elif 'selectedTeacher' in json_output:
                                    print(f"   Selected: {json_output.get('selectedTeacher')}")
                                elif 'audio_url' in json_output or 'audio_base64' in json_output:
                                    print(f"   Audio: {'URL' if 'audio_url' in json_output else 'Base64'}")
                                elif 'video_url' in json_output or 'video_path' in json_output:
                                    print(f"   Video: {json_output.get('video_url') or json_output.get('video_path', 'N/A')}")
                                else:
                                    keys = list(json_output.keys())[:3]
                                    print(f"   Keys: {keys}")
                        else:
                            print(f"⚠️  {node_name}: Executed but no output")
                else:
                    print(f"⚠️  {node_name}: Not executed")
                break
        
        if not node_found:
            print(f"❓ {node_name}: Not found in execution")
    
    print()
    print("=" * 60)
    
    # Check if Respond to Webhook was reached
    respond_found = False
    for node_name, node_runs in run_data.items():
        if 'respond' in node_name.lower() or 'webhook' in node_name.lower():
            respond_found = True
            if node_runs and len(node_runs) > 0:
                last_run = node_runs[-1]
                error = last_run.get('error', {})
                if error:
                    print(f"\n❌ Respond to Webhook node has ERROR:")
                    print(f"   {error.get('message', 'Unknown error')}")
                else:
                    print(f"\n✅ Respond to Webhook node executed successfully")
                    output = last_run.get('data', {}).get('main', [])
                    if output:
                        print(f"   Response data: {json.dumps(output[0].get('json', {}), indent=2)}")
            break
    
    if not respond_found:
        print("\n❌ Respond to Webhook node was NOT executed!")
        print("   The workflow is failing before reaching the response node.")

except Exception as e:
    print(f"Error parsing execution: {e}")
    print("\nRaw execution data (first 1000 chars):")
    import sys
    raw_data = sys.stdin.read() if hasattr(sys.stdin, 'read') else ""
    if raw_data:
        print(raw_data[:1000])
    else:
        print("(No data available)")
PYTHON_SCRIPT
