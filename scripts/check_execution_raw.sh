#!/usr/bin/env bash
# Check raw execution API response
# Usage: bash scripts/check_execution_raw.sh [execution_id]

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

EXEC_ID="${1:-}"

if [[ -z "$EXEC_ID" ]]; then
    # Get latest execution ID
    if [[ -n "$N8N_API_KEY" ]]; then
        EXECUTIONS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions?limit=1")
    else
        EXECUTIONS=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions?limit=1")
    fi
    
    EXEC_ID=$(echo "$EXECUTIONS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    executions = data.get('data', [])
    if executions:
        print(executions[0].get('id', ''))
except:
    pass
" 2>/dev/null || echo "")
    
    if [[ -z "$EXEC_ID" ]]; then
        echo "❌ No executions found"
        exit 1
    fi
fi

echo "Checking execution ID: $EXEC_ID"
echo ""

# Get execution details with verbose output
if [[ -n "$N8N_API_KEY" ]]; then
    echo "Using API key authentication"
    RESPONSE=$(curl -v -s -H "X-N8N-API-KEY: $N8N_API_KEY" "${N8N_URL}/api/v1/executions/${EXEC_ID}" 2>&1)
else
    echo "Using basic auth"
    RESPONSE=$(curl -v -s -u "${N8N_USER}:${N8N_PASSWORD}" "${N8N_URL}/api/v1/executions/${EXEC_ID}" 2>&1)
fi

echo "=== Full Response ==="
echo "$RESPONSE"
echo ""
echo "=== JSON Part Only ==="
echo "$RESPONSE" | grep -A 1000 "^{" | head -100 || echo "No JSON found in response"
