#!/usr/bin/env bash
# Force delete and re-import n8n workflows (to pick up fixes)
# Usage: bash scripts/force_reimport_workflows.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Get n8n credentials
N8N_USER="${N8N_USER:-admin}"
N8N_PASSWORD="${N8N_PASSWORD:-changeme}"
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzMThlZDVhMy04ZDdlLTQ0NTEtYTc2ZS0wZjEyMTRlYjYwMGYiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5NDcwMzEyfQ.o1CNGPHMt8JbqFrSkbZo9o5Q4tjhptdjb-lKPSKK2oc"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="http://localhost:5678"

echo "=========================================="
echo "Force Re-importing n8n Workflows"
echo "=========================================="
echo ""

# Test authentication to determine which method works
echo "Testing n8n authentication..."

# Try API key first
API_TEST=$(curl -s -w "\n%{http_code}" -X GET "${N8N_URL}/api/v1/workflows" \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" 2>/dev/null || echo -e "\n000")
API_CODE=$(echo "$API_TEST" | tail -1)

if [[ "$API_CODE" == "200" ]]; then
    echo "   âœ… API key authentication works"
    AUTH_METHOD="api_key"
else
    echo "   âš ï¸  API key authentication failed, trying basic auth..."
    # Try basic auth
    BASIC_TEST=$(curl -s -w "\n%{http_code}" -X GET "${N8N_URL}/api/v1/workflows" \
        -u "${N8N_USER}:${N8N_PASSWORD}" 2>/dev/null || echo -e "\n000")
    BASIC_CODE=$(echo "$BASIC_TEST" | tail -1)
    
    if [[ "$BASIC_CODE" == "200" ]]; then
        echo "   âœ… Basic auth works, using it for all requests"
        AUTH_METHOD="basic"
    else
        echo "   âŒ Both API key and basic auth failed!"
        echo "   Please check:"
        echo "     1. n8n is running: ps aux | grep n8n"
        echo "     2. N8N_USER and N8N_PASSWORD in .env"
        echo "     3. API key is valid (get from n8n UI: Settings â†’ API)"
        exit 1
    fi
fi
echo ""

# Function to make authenticated request using the determined auth method
make_auth_request() {
    local method="$1"
    local url="$2"
    local data="${3:-}"
    
    if [[ "$AUTH_METHOD" == "basic" ]]; then
        # Use basic auth
        if [[ -n "$data" ]]; then
            curl -s -X "$method" \
                -u "${N8N_USER}:${N8N_PASSWORD}" \
                -H "Content-Type: application/json" \
                -d "$data" \
                "$url" 2>/dev/null
        else
            curl -s -X "$method" \
                -u "${N8N_USER}:${N8N_PASSWORD}" \
                "$url" 2>/dev/null
        fi
    else
        # Use API key
        if [[ -n "$data" ]]; then
            curl -s -X "$method" \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                -H "Content-Type: application/json" \
                -d "$data" \
                "$url" 2>/dev/null
        else
            curl -s -X "$method" \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "$url" 2>/dev/null
        fi
    fi
}

# Get all workflows using the authenticated request
WORKFLOWS_JSON=$(make_auth_request "GET" "${N8N_URL}/api/v1/workflows")