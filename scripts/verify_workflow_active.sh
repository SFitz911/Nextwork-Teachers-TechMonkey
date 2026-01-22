#!/usr/bin/env bash
# Verify which workflow is actually active
# Usage: bash scripts/verify_workflow_active.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

N8N_USER="${N8N_USER:-sfitz911@gmail.com}"
N8N_PASSWORD="${N8N_PASSWORD:-Delrio77$}"
N8N_API_KEY="${N8N_API_KEY:-}"
N8N_URL="http://localhost:5678"

# Get API key if needed
if [[ -z "$N8N_API_KEY" ]]; then
    N8N_API_KEY=$(bash scripts/get_or_create_api_key.sh 2>/dev/null || echo "")
    if [[ -n "$N8N_API_KEY" ]]; then
        export N8N_API_KEY
    fi
fi

echo "=========================================="
echo "Verifying Active Workflow"
echo "=========================================="
echo ""

# Get all workflows
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

echo "$WORKFLOWS_JSON" | python3 << 'PYTHON'
import json
import sys

try:
    data = json.load(sys.stdin)
    workflows = data.get('data', [])
    
    print("All workflows:")
    print("=" * 60)
    
    for wf in workflows:
        wf_id = wf.get('id', 'N/A')
        wf_name = wf.get('name', 'N/A')
        wf_active = wf.get('active', False)
        
        status = "✅ ACTIVE" if wf_active else "❌ INACTIVE"
        print(f"{status} - {wf_name}")
        print(f"   ID: {wf_id}")
        print()
    
    # Find Five Teacher workflow
    five_teacher = None
    for wf in workflows:
        if 'Five Teacher' in wf.get('name', ''):
            five_teacher = wf
            break
    
    if five_teacher:
        print("=" * 60)
        print(f"Five Teacher Workflow:")
        print(f"  ID: {five_teacher.get('id')}")
        print(f"  Active: {five_teacher.get('active', False)}")
        print(f"  Name: {five_teacher.get('name')}")
        
        if not five_teacher.get('active', False):
            print()
            print("⚠️  Workflow is NOT active! This is the problem.")
            print("   Activate it in n8n UI or run: bash scripts/clean_and_import_workflow.sh")
    else:
        print("❌ Five Teacher workflow not found!")
        
except Exception as e:
    print(f"Error: {e}")
    print("Raw response:")
    sys.stdin.seek(0)
    print(sys.stdin.read()[:500])
PYTHON

echo ""
echo "Checking webhook registration..."
WEBHOOK_TEST=$(curl -s -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": 1234567890}' 2>&1)

if echo "$WEBHOOK_TEST" | grep -q "404\|not registered"; then
    echo "❌ Webhook not registered"
else
    if [[ -n "$WEBHOOK_TEST" ]]; then
        echo "✅ Webhook is registered and responding"
    else
        echo "⚠️  Webhook responds but with empty body"
    fi
fi
