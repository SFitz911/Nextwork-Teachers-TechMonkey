#!/usr/bin/env bash
# Helper script to guide user through fixing API key
# Usage: bash scripts/fix_api_key.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_USER="${N8N_USER:-admin}"

echo "=========================================="
echo "Fixing n8n API Key"
echo "=========================================="
echo ""
echo "Your current API key is not working."
echo ""
echo "To get a new API key:"
echo ""
echo "1. Ensure port forwarding is active:"
echo "   On Desktop PowerShell: .\connect-vast.ps1"
echo ""
echo "2. Open n8n in your browser:"
echo "   http://localhost:5678"
echo ""
echo "3. Log in with:"
echo "   Username: ${N8N_USER}"
echo ""
echo "4. Go to: Settings → API"
echo ""
echo "5. Create a new API key (or copy existing one)"
echo ""
echo "6. Once you have the API key, run:"
echo "   echo 'N8N_API_KEY=your_new_key_here' >> .env"
echo "   # Or edit .env manually and replace the old key"
echo ""
echo "7. Then validate:"
echo "   bash scripts/validate_config.sh"
echo ""
echo "=========================================="
echo "Alternative: Test current key"
echo "=========================================="
echo ""
echo "If you want to test if your current key works:"
echo ""

if [[ -n "${N8N_API_KEY:-}" ]]; then
    echo "Current API key (first 20 chars): ${N8N_API_KEY:0:20}..."
    echo ""
    echo "Testing..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo "000")
    
    if [[ "$HTTP_CODE" == "200" ]]; then
        echo "✅ API key is working!"
    else
        echo "❌ API key test failed (HTTP $HTTP_CODE)"
        echo "   You need to get a new API key from n8n UI"
    fi
else
    echo "❌ N8N_API_KEY is not set in .env"
    echo "   You need to add it to .env"
fi
