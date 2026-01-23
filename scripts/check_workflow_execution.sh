#!/usr/bin/env bash
# Script to check why workflow is returning empty responses
# Usage: bash scripts/check_workflow_execution.sh

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
N8N_URL="http://localhost:5678"

echo "=========================================="
echo "Checking Workflow Execution"
echo "=========================================="
echo ""

# 1. Check if services are running
echo "1. Checking if services are running..."
echo ""

SERVICES_OK=true

# Check Ollama
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "✅ Ollama is running"
else
    echo "❌ Ollama is NOT running or not accessible"
    SERVICES_OK=false
fi

# Check TTS
if curl -s http://localhost:8001/docs > /dev/null 2>&1; then
    echo "✅ TTS service is running"
else
    echo "❌ TTS service is NOT running or not accessible"
    SERVICES_OK=false
fi

# Check Animation
if curl -s http://localhost:8002/docs > /dev/null 2>&1; then
    echo "✅ Animation service is running"
else
    echo "❌ Animation service is NOT running or not accessible"
    SERVICES_OK=false
fi

# Check n8n
if curl -s http://localhost:5678 > /dev/null 2>&1; then
    echo "✅ n8n is running"
else
    echo "❌ n8n is NOT running"
    SERVICES_OK=false
fi

echo ""

if [[ "$SERVICES_OK" != "true" ]]; then
    echo "⚠️  Some services are not running. This will cause workflow failures."
    echo ""
fi

# 2. Get workflow ID
echo "2. Getting workflow details..."
if [[ -n "$N8N_API_KEY" ]]; then
    WORKFLOWS_JSON=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null)
else
    WORKFLOWS_JSON=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null)
fi

WORKFLOW_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if 'Five Teacher' in wf.get('name', ''):
            print(wf.get('id', ''))
            sys.exit(0)
except:
    pass
" 2>/dev/null)

if [[ -z "$WORKFLOW_ID" ]]; then
    echo "❌ Five Teacher workflow not found"
    exit 1
fi

echo "✅ Found workflow (ID: $WORKFLOW_ID)"
echo ""

# 3. Get recent executions
echo "3. Checking recent workflow executions..."
if [[ -n "$N8N_API_KEY" ]]; then
    EXECUTIONS=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=3" 2>/dev/null)
else
    EXECUTIONS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/executions?workflowId=${WORKFLOW_ID}&limit=3" 2>/dev/null)
fi

echo "$EXECUTIONS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    executions = data.get('data', [])
    if executions:
        print(f'Found {len(executions)} recent execution(s):')
        for i, exec_data in enumerate(executions[:3], 1):
            exec_id = exec_data.get('id', 'N/A')
            finished = exec_data.get('finished', False)
            stopped_at = exec_data.get('stoppedAt', 'N/A')
            mode = exec_data.get('mode', 'N/A')
            print(f'  {i}. ID: {exec_id}')
            print(f'     Finished: {finished}')
            print(f'     Stopped at: {stopped_at}')
            print(f'     Mode: {mode}')
            
            # Get execution details
            if exec_id != 'N/A':
                print(f'     (Check details: curl -H \"X-N8N-API-KEY: ...\" {sys.argv[1]}/api/v1/executions/{exec_id})')
    else:
        print('No executions found')
except Exception as e:
    print(f'Error parsing executions: {e}')
" "$N8N_URL" 2>/dev/null || echo "Could not parse executions"

echo ""

# 4. Check n8n logs for errors
echo "4. Checking n8n logs for errors..."
echo ""

ERRORS=$(tail -100 logs/n8n.log 2>/dev/null | grep -i -E "error|fail|exception" | tail -10 || echo "No errors found in recent logs")

if [[ "$ERRORS" != "No errors found in recent logs" ]]; then
    echo "Recent errors in n8n.log:"
    echo "$ERRORS"
else
    echo "✅ No recent errors in n8n.log"
fi

echo ""

# 5. Test Ollama directly
echo "5. Testing Ollama API..."
echo ""

OLLAMA_TEST=$(curl -s -X POST http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d '{"model": "mistral:7b", "prompt": "Say hello", "stream": false}' 2>&1 | head -c 200)

if [[ -n "$OLLAMA_TEST" ]]; then
    echo "✅ Ollama is responding"
    echo "   Response preview: ${OLLAMA_TEST:0:100}..."
else
    echo "❌ Ollama is not responding"
fi

echo ""

# 6. Summary and recommendations
echo "=========================================="
echo "Summary and Recommendations"
echo "=========================================="
echo ""

if [[ "$SERVICES_OK" != "true" ]]; then
    echo "❌ Some services are not running. Start them:"
    echo "   bash scripts/run_no_docker_tmux.sh"
    echo ""
fi

echo "To debug the workflow execution:"
echo "1. Open n8n UI: http://localhost:5678"
echo "2. Open the 'Five Teacher' workflow"
echo "3. Check the 'Executions' tab to see failed executions"
echo "4. Click on a failed execution to see where it failed"
echo ""
echo "Common issues:"
echo "- Ollama not responding: Check if 'ollama serve' is running"
echo "- TTS/Animation services not running: Check if they're in tmux session"
echo "- Workflow timeout: The workflow might be taking too long"
