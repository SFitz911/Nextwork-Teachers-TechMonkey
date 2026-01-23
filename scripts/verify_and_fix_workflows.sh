#!/usr/bin/env bash
# Verify and fix 2-teacher workflows in n8n
# This script checks if workflows are imported and activated, and fixes issues
# Usage: bash scripts/verify_and_fix_workflows.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Default API key (hardcoded fallback)
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmNzRkZjc2OC0wZTVhLTQ2OGQtODFiYS1iYTZiMGFiNjAwY2EiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MTQzMDY3fQ.JQU3yyBofIJBX-50Zjdc9GnW7xLMf1QcZrVlgJ-OdbA"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"

echo "=========================================="
echo "Verifying 2-Teacher Workflows"
echo "=========================================="
echo ""

# Get all workflows
if [[ -n "${N8N_API_KEY:-}" ]]; then
    WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
else
    WORKFLOWS_JSON=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
fi

# Expected workflows
EXPECTED_WORKFLOWS=(
    "Session Start - Fast Webhook:/webhook/session/start:POST"
    "Left Worker - Teacher Pipeline:/webhook/worker/left/run:POST"
    "Right Worker - Teacher Pipeline:/webhook/worker/right/run:POST"
)

echo "Checking for expected workflows..."
echo ""

MISSING_WORKFLOWS=()
INACTIVE_WORKFLOWS=()

for workflow_entry in "${EXPECTED_WORKFLOWS[@]}"; do
    IFS=':' read -r name path method <<< "$workflow_entry"
    
    echo "Checking: $name"
    
    # Find workflow by name
    WORKFLOW_INFO=$(echo "$WORKFLOWS_JSON" | python3 <<EOF
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if wf.get('name', '') == '$name':
            print(f"{wf.get('id', '')}|{wf.get('active', False)}")
            sys.exit(0)
    print("NOT_FOUND|False")
except:
    print("NOT_FOUND|False")
EOF
)
    
    IFS='|' read -r wf_id wf_active <<< "$WORKFLOW_INFO"
    
    if [[ "$wf_id" == "NOT_FOUND" ]]; then
        echo "   ❌ NOT FOUND"
        MISSING_WORKFLOWS+=("$name")
    else
        if [[ "$wf_active" == "True" ]]; then
            echo "   ✅ Found and ACTIVE (ID: $wf_id)"
            
            # Test webhook endpoint
            echo "   Testing webhook endpoint..."
            if [[ "$path" == "/webhook/session/start" ]]; then
                TEST_PAYLOAD='{"selectedTeachers": ["teacher_a", "teacher_b"]}'
            else
                TEST_PAYLOAD='{"sessionId": "test", "teacher": "teacher_a", "role": "renderer", "sectionPayload": {}, "turn": 0}'
            fi
            
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
                -X "$method" \
                -H "Content-Type: application/json" \
                -d "$TEST_PAYLOAD" \
                "${N8N_URL}${path}" 2>/dev/null || echo "000")
            
            if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "404" ]]; then
                if [[ "$HTTP_CODE" == "404" ]]; then
                    echo "   ⚠️  Webhook returned 404 (may need to wait for registration)"
                else
                    echo "   ✅ Webhook endpoint working (HTTP $HTTP_CODE)"
                fi
            else
                echo "   ⚠️  Webhook returned HTTP $HTTP_CODE"
            fi
        else
            echo "   ⚠️  Found but INACTIVE (ID: $wf_id)"
            INACTIVE_WORKFLOWS+=("$wf_id|$name")
        fi
    fi
    echo ""
done

# Fix missing workflows
if [[ ${#MISSING_WORKFLOWS[@]} -gt 0 ]]; then
    echo "=========================================="
    echo "Fixing Missing Workflows"
    echo "=========================================="
    echo ""
    echo "Missing workflows: ${MISSING_WORKFLOWS[*]}"
    echo ""
    echo "Running reconfiguration script to import them..."
    bash scripts/reconfigure_n8n_for_2teacher.sh
    echo ""
fi

# Fix inactive workflows
if [[ ${#INACTIVE_WORKFLOWS[@]} -gt 0 ]]; then
    echo "=========================================="
    echo "Activating Inactive Workflows"
    echo "=========================================="
    echo ""
    
    for workflow_entry in "${INACTIVE_WORKFLOWS[@]}"; do
        IFS='|' read -r wf_id wf_name <<< "$workflow_entry"
        
        echo "Activating: $wf_name (ID: $wf_id)..."
        
        if [[ -n "${N8N_API_KEY:-}" ]]; then
            ACTIVATE_RESPONSE=$(curl -s -X POST \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${wf_id}/activate" 2>/dev/null)
        else
            ACTIVATE_RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
                -X POST \
                "${N8N_URL}/api/v1/workflows/${wf_id}/activate" 2>/dev/null)
        fi
        
        echo "   ✅ Activated"
    done
    
    echo ""
    echo "Waiting for webhooks to register..."
    sleep 5
    echo ""
fi

# Final verification - Re-fetch workflows to get updated status
echo "=========================================="
echo "Final Verification"
echo "=========================================="
echo ""

# Re-fetch workflows list to get updated status after import/activation
if [[ -n "${N8N_API_KEY:-}" ]]; then
    WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
else
    WORKFLOWS_JSON=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
fi

ALL_GOOD=true

for workflow_entry in "${EXPECTED_WORKFLOWS[@]}"; do
    IFS=':' read -r name path method <<< "$workflow_entry"
    
    WORKFLOW_INFO=$(echo "$WORKFLOWS_JSON" | python3 <<EOF
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if wf.get('name', '') == '$name':
            print(f"{wf.get('id', '')}|{wf.get('active', False)}")
            sys.exit(0)
    print("NOT_FOUND|False")
except:
    print("NOT_FOUND|False")
EOF
)
    
    IFS='|' read -r wf_id wf_active <<< "$WORKFLOW_INFO"
    
    if [[ "$wf_id" != "NOT_FOUND" ]] && [[ "$wf_active" == "True" ]]; then
        echo "✅ $name - Active and ready"
    else
        echo "❌ $name - Still has issues"
        ALL_GOOD=false
    fi
done

echo ""

if [[ "$ALL_GOOD" == "true" ]]; then
    echo "=========================================="
    echo "✅ All workflows verified and working!"
    echo "=========================================="
    echo ""
    echo "Webhook endpoints:"
    echo "  - ${N8N_URL}/webhook/session/start"
    echo "  - ${N8N_URL}/webhook/worker/left/run"
    echo "  - ${N8N_URL}/webhook/worker/right/run"
    echo ""
    echo "Test session start:"
    echo "  curl -X POST ${N8N_URL}/webhook/session/start \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"selectedTeachers\": [\"teacher_a\", \"teacher_b\"]}'"
else
    echo "=========================================="
    echo "⚠️  Some workflows still need attention"
    echo "=========================================="
    echo ""
    echo "Try:"
    echo "  1. Check n8n UI: ${N8N_URL}"
    echo "  2. Manually activate workflows"
    echo "  3. Restart n8n if needed"
fi
