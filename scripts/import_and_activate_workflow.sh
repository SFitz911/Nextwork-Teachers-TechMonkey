#!/usr/bin/env bash
# Script to import and activate n8n workflow automatically
# Usage: bash scripts/import_and_activate_workflow.sh [workflow_file]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Get credentials
N8N_USER="${N8N_USER:-sfitz911@gmail.com}"
N8N_PASSWORD="${N8N_PASSWORD:-Delrio77$}"
N8N_API_KEY="${N8N_API_KEY:-}"
N8N_URL="http://localhost:5678"

# Get or create API key if not set
if [[ -z "$N8N_API_KEY" ]]; then
    echo "Getting n8n API key..."
    N8N_API_KEY=$(bash scripts/get_or_create_api_key.sh 2>/dev/null || echo "")
    if [[ -n "$N8N_API_KEY" ]]; then
        export N8N_API_KEY
        echo "✅ Using API key for authentication"
    else
        echo "⚠️  Could not get API key, will try basic auth"
    fi
fi

# Workflow file (default to five-teacher-workflow.json)
WORKFLOW_FILE="${1:-$PROJECT_DIR/n8n/workflows/five-teacher-workflow.json}"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
    echo "❌ Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

echo "=========================================="
echo "Importing and Activating n8n Workflow"
echo "=========================================="
echo ""
echo "Workflow file: $WORKFLOW_FILE"
echo ""

# Test n8n connection
echo "Testing n8n connection..."
if ! curl -s -o /dev/null -w "%{http_code}" "$N8N_URL" | grep -q "200\|404"; then
    echo "❌ n8n is not accessible at $N8N_URL"
    echo "   Make sure n8n is running: ps aux | grep 'n8n start'"
    exit 1
fi
echo "✅ n8n is accessible"
echo ""

# Check if workflow already exists
echo "Checking for existing workflows..."
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

if echo "$WORKFLOWS_JSON" | grep -q "Unauthorized\|401"; then
    echo "❌ Authentication failed. Check credentials in .env file"
    exit 1
fi

# Get workflow name from file
WORKFLOW_NAME=$(python3 -c "
import json, sys
try:
    with open('$WORKFLOW_FILE', 'r') as f:
        data = json.load(f)
        print(data.get('name', ''))
except:
    print('')
" 2>/dev/null)

if [[ -z "$WORKFLOW_NAME" ]]; then
    WORKFLOW_NAME="AI Virtual Classroom - Five Teacher Workflow"
fi

echo "Looking for workflow: $WORKFLOW_NAME"
echo ""

# Check if workflow with this name already exists
EXISTING_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        name = wf.get('name', '')
        if '$WORKFLOW_NAME' in name or 'AI Virtual Classroom' in name:
            print(wf.get('id', ''))
            sys.exit(0)
except:
    pass
" 2>/dev/null)

if [[ -n "$EXISTING_ID" ]]; then
    echo "✅ Workflow already exists (ID: $EXISTING_ID)"
    echo ""
    
    # Check if it's active
    IS_ACTIVE=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if wf.get('id') == '$EXISTING_ID':
            print('true' if wf.get('active', False) else 'false')
            sys.exit(0)
except:
    print('false')
" 2>/dev/null)
    
    if [[ "$IS_ACTIVE" == "true" ]]; then
        echo "✅ Workflow is already active!"
        exit 0
    else
        echo "Workflow exists but is not active. Activating..."
        # Use the activation script
        bash scripts/activate_workflow_api.sh
        exit $?
    fi
fi

# Import the workflow
echo "Importing workflow..."
if [[ -n "$N8N_API_KEY" ]]; then
    IMPORT_RESPONSE=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d @"$WORKFLOW_FILE" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null)
else
    IMPORT_RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d @"$WORKFLOW_FILE" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null)
fi

# Check if import was successful
NEW_WORKFLOW_ID=$(echo "$IMPORT_RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    wf_id = data.get('id') or data.get('data', {}).get('id', '')
    if wf_id:
        print(wf_id)
    else:
        # Try to find it in the response
        print('')
except:
    print('')
" 2>/dev/null)

if [[ -z "$NEW_WORKFLOW_ID" ]]; then
    # Try alternative: check if workflow was created by name
    sleep 2
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
    
    NEW_WORKFLOW_ID=$(echo "$WORKFLOWS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        name = wf.get('name', '')
        if '$WORKFLOW_NAME' in name or 'AI Virtual Classroom' in name:
            print(wf.get('id', ''))
            sys.exit(0)
except:
    pass
" 2>/dev/null)
fi

if [[ -z "$NEW_WORKFLOW_ID" ]]; then
    echo "❌ Failed to import workflow"
    echo "Response:"
    echo "$IMPORT_RESPONSE" | head -20
    echo ""
    echo "Trying manual import method..."
    
    # Alternative: Use n8n's import endpoint
    if [[ -n "$N8N_API_KEY" ]]; then
        IMPORT_RESPONSE2=$(curl -s \
            -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            -X POST \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"$WORKFLOW_NAME\",\"nodes\":$(python3 -c "import json; print(json.dumps(json.load(open('$WORKFLOW_FILE'))['nodes']))" 2>/dev/null),\"connections\":$(python3 -c "import json; print(json.dumps(json.load(open('$WORKFLOW_FILE'))['connections']))" 2>/dev/null)}" \
            "${N8N_URL}/api/v1/workflows" 2>/dev/null)
    else
        IMPORT_RESPONSE2=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
            -X POST \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"$WORKFLOW_NAME\",\"nodes\":$(python3 -c "import json; print(json.dumps(json.load(open('$WORKFLOW_FILE'))['nodes']))" 2>/dev/null),\"connections\":$(python3 -c "import json; print(json.dumps(json.load(open('$WORKFLOW_FILE'))['connections']))" 2>/dev/null)}" \
            "${N8N_URL}/api/v1/workflows" 2>/dev/null)
    fi
    
    echo "$IMPORT_RESPONSE2" | head -10
    exit 1
fi

echo "✅ Workflow imported successfully! (ID: $NEW_WORKFLOW_ID)"
echo ""

# Activate the workflow
echo "Activating workflow..."
if [[ -n "$N8N_API_KEY" ]]; then
    ACTIVATE_RESPONSE=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -X POST \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${NEW_WORKFLOW_ID}/activate" 2>/dev/null)
else
    ACTIVATE_RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        -X POST \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${NEW_WORKFLOW_ID}/activate" 2>/dev/null)
fi

if echo "$ACTIVATE_RESPONSE" | grep -q "active.*true\|success"; then
    echo "✅ Workflow activated successfully!"
elif echo "$ACTIVATE_RESPONSE" | grep -q "already active"; then
    echo "✅ Workflow is already active!"
else
    echo "⚠️  Activation response:"
    echo "$ACTIVATE_RESPONSE" | head -10
fi

# Verify
echo ""
echo "Verifying activation..."
sleep 2
if [[ -n "$N8N_API_KEY" ]]; then
    VERIFY_RESPONSE=$(curl -s \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${NEW_WORKFLOW_ID}" 2>/dev/null)
else
    VERIFY_RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        -H "Content-Type: application/json" \
        "${N8N_URL}/api/v1/workflows/${NEW_WORKFLOW_ID}" 2>/dev/null)
fi

IS_ACTIVE=$(echo "$VERIFY_RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print('true' if data.get('active', False) else 'false')
except:
    print('false')
" 2>/dev/null)

if [[ "$IS_ACTIVE" == "true" ]]; then
    echo "✅ Workflow is confirmed active!"
    echo ""
    echo "Testing webhook..."
    sleep 1
    WEBHOOK_TEST=$(curl -s -X POST "${N8N_URL}/webhook/chat-webhook" \
        -H "Content-Type: application/json" \
        -d '{"message": "test", "timestamp": 1234567890}' 2>&1)
    
    if echo "$WEBHOOK_TEST" | grep -q "404\|not registered"; then
        echo "⚠️  Webhook may need a moment to register. Wait a few seconds and try again."
    else
        echo "✅ Webhook is responding!"
    fi
else
    echo "⚠️  Workflow may not be fully activated. Check n8n logs: tail -20 logs/n8n.log"
fi

echo ""
echo "=========================================="
echo "Done!"
echo "=========================================="
