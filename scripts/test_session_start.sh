#!/usr/bin/env bash
# Test session start webhook with detailed output
# Usage: bash scripts/test_session_start.sh

set -euo pipefail

N8N_URL="${N8N_URL:-http://localhost:5678}"
COORDINATOR_URL="${COORDINATOR_URL:-http://localhost:8004}"

echo "=========================================="
echo "Testing Session Start Webhook"
echo "=========================================="
echo ""

# Step 1: Check if Coordinator API is running
echo "Step 1: Checking Coordinator API..."
if curl -s "$COORDINATOR_URL/" > /dev/null 2>&1; then
    echo "✅ Coordinator API is running"
else
    echo "❌ Coordinator API is NOT running!"
    echo "   Start it with: python services/coordinator/app.py"
    echo "   Or: bash scripts/start_all_services.sh"
    exit 1
fi
echo ""

# Step 2: Test webhook with verbose output
echo "Step 2: Testing webhook endpoint..."
echo ""

RESPONSE=$(curl -v -X POST \
    -H "Content-Type: application/json" \
    -d '{"selectedTeachers": ["teacher_a", "teacher_b"]}' \
    "${N8N_URL}/webhook/session/start" 2>&1)

HTTP_CODE=$(echo "$RESPONSE" | grep -i "< HTTP" | tail -1 | awk '{print $3}' || echo "unknown")
BODY=$(echo "$RESPONSE" | grep -v "^<" | grep -v "^*" | grep -v "^}" | tail -1)

echo "HTTP Status: $HTTP_CODE"
echo "Response Body: $BODY"
echo ""

# Step 3: Check n8n executions
echo "Step 3: Checking latest n8n execution..."
echo ""

# Get API key
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmNzRkZjc2OC0wZTVhLTQ2OGQtODFiYS1iYTZiMGFiNjAwY2EiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MTQzMDY3fQ.JQU3yyBofIJBX-50Zjdc9GnW7xLMf1QcZrVlgJ-OdbA"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"

if [[ -n "${N8N_API_KEY:-}" ]]; then
    LATEST_EXEC=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/executions?limit=1" 2>/dev/null)
    
    EXEC_STATUS=$(echo "$LATEST_EXEC" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    execs = data.get('data', [])
    if execs:
        exec_data = execs[0]
        print(f\"Status: {exec_data.get('status', 'unknown')}\")
        print(f\"Finished: {exec_data.get('finished', False)}\")
        print(f\"Workflow: {exec_data.get('workflowId', 'unknown')}\")
        
        # Check for errors
        error = exec_data.get('data', {}).get('resultData', {}).get('error', {})
        if error:
            print(f\"Error: {error.get('message', 'Unknown error')}\")
    else:
        print('No executions found')
except:
    print('Failed to parse execution data')
" 2>/dev/null || echo "Failed to get execution data")
    
    echo "$EXEC_STATUS"
else
    echo "⚠️  No API key found, skipping execution check"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
if [[ "$HTTP_CODE" == "200" ]]; then
    echo "✅ Webhook is working!"
    if [[ -n "$BODY" ]]; then
        echo "   Response: $BODY"
    fi
else
    echo "❌ Webhook returned HTTP $HTTP_CODE"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check Coordinator API is running: curl $COORDINATOR_URL/"
    echo "  2. Check n8n UI: $N8N_URL"
    echo "  3. Check workflow is activated (green toggle)"
    echo "  4. Check n8n executions for errors"
fi
