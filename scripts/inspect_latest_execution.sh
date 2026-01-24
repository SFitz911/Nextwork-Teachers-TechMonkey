#!/usr/bin/env bash
# ⚠️  DEPRECATED: Use scripts/inspect_execution.sh --latest instead
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

N8N_URL="${N8N_URL:-http://localhost:5678}"
# Default API key (hardcoded fallback)
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI1MzE3fQ.tU1VEaQCrymcz8MIkAWuWfpBJoT9O7R8olTeBe42JJ0"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"
    echo "   2. Go to Settings → API" >&2
    echo "   3. Create or copy your API key" >&2
    exit 1
fi

# Get workflow ID using API key
WORKFLOWS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/workflows")

# Try multiple name patterns
WORKFLOW_ID=$(echo "$WORKFLOWS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        name = wf.get('name', '')
        # Try multiple patterns
        if 'Five Teacher' in name or 'AI Virtual Classroom' in name or 'Virtual Classroom' in name:
            print(wf.get('id', ''))
            sys.exit(0)
except:
    pass
" 2>/dev/null || echo "")

if [[ -z "$WORKFLOW_ID" ]]; then
    echo "❌ Workflow not found!" >&2
    echo "" >&2
    echo "Available workflows:" >&2
    echo "$WORKFLOWS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    workflows = data.get('data', [])
    if workflows:
        for wf in workflows:
            print(f\"  - {wf.get('name', 'Unknown')} (ID: {wf.get('id', 'N/A')}, Active: {wf.get('active', False)})\")
    else:
        print('  (No workflows found)')
except Exception as e:
    print(f'  (Error parsing workflows: {e})')
" 2>&1
    echo "" >&2
    echo "To import the workflow, run:" >&2
    echo "  bash scripts/clean_and_import_workflow.sh" >&2
    exit 1
fi

echo "Workflow ID: $WORKFLOW_ID"
echo ""

# Get latest execution using API key
EXECUTIONS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=1")

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

# API key is required and should already be set from .env
# No need to try to create one - just use what's in .env

# Use API key (required for includeData=true)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}?includeData=true" 2>/dev/null)
echo "HTTP Status: $HTTP_CODE"
EXEC_DETAILS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}?includeData=true" 2>/dev/null)

if [[ "$HTTP_CODE" != "200" ]]; then
    echo "❌ API request failed with HTTP $HTTP_CODE" >&2
    echo "Response: $(echo "$EXEC_DETAILS" | head -c 200)" >&2
    exit 1
fi

echo "Response length: ${#EXEC_DETAILS} characters"
if [[ ${#EXEC_DETAILS} -lt 10 ]]; then
    echo "⚠️  Response is very short, trying without includeData..."
    EXEC_DETAILS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}")
    echo "Response length (without includeData): ${#EXEC_DETAILS} characters"
fi

# Check if we got a valid response
if [[ -z "$EXEC_DETAILS" ]] || [[ "$EXEC_DETAILS" == *"error"* ]] || [[ "$EXEC_DETAILS" == *"Unauthorized"* ]]; then
    echo "❌ Failed to get execution details"
    echo "Response: $EXEC_DETAILS"
    echo ""
    echo "Trying without includeData parameter..."
    EXEC_DETAILS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}")
    if [[ -z "$EXEC_DETAILS" ]]; then
        echo "Still empty. Checking API response..."
        echo "HTTP Status:"
        curl -s -o /dev/null -w "%{http_code}" -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${LATEST_EXEC_ID}"
        echo ""
        exit 1
    fi
fi

# Debug: Save response to file to inspect
echo "$EXEC_DETAILS" > /tmp/exec_response.json 2>/dev/null || true

# Check if response is valid JSON - try to parse it
if ! echo "$EXEC_DETAILS" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
    echo "⚠️  Response is not valid JSON"
    echo ""
    echo "First 200 characters of response:"
    echo "$EXEC_DETAILS" | head -c 200
    echo ""
    echo ""
    
    # Try to extract JSON from response (might be embedded in HTML or have prefix)
    JSON_PART=$(echo "$EXEC_DETAILS" | python3 -c "
import sys
text = sys.stdin.read()
# Try to find JSON object
start = text.find('{')
if start != -1:
    # Try to find matching closing brace
    brace_count = 0
    for i in range(start, len(text)):
        if text[i] == '{':
            brace_count += 1
        elif text[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                print(text[start:i+1])
                break
" 2>/dev/null || echo "")
    
    if [[ -n "$JSON_PART" ]]; then
        echo "Found JSON in response, extracting..."
        EXEC_DETAILS="$JSON_PART"
        # Try parsing again
        if echo "$EXEC_DETAILS" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
            echo "✅ Successfully extracted valid JSON"
        else
            echo "❌ Extracted JSON is still invalid"
            echo "Full response saved to /tmp/exec_response.json for inspection"
            exit 1
        fi
    else
        echo "❌ Could not extract JSON from response"
        echo "Full response saved to /tmp/exec_response.json for inspection"
        echo ""
        echo "This might be HTML or an error page. Checking if n8n is accessible..."
        curl -s http://localhost:5678 > /dev/null && echo "✅ n8n is accessible" || echo "❌ n8n is not accessible"
        exit 1
    fi
fi

# Save valid JSON for inspection
echo "$EXEC_DETAILS" > /tmp/exec_response.json

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
