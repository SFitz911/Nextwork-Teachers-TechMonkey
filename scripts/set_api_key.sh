#!/usr/bin/env bash
# Set and test n8n API key
# Usage: bash scripts/set_api_key.sh [api_key]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

API_KEY="${1:-}"

if [[ -z "$API_KEY" ]]; then
    echo "Usage: bash scripts/set_api_key.sh <api_key>"
    echo ""
    echo "Example:"
    echo "  bash scripts/set_api_key.sh n8n_abc123..."
    exit 1
fi

echo "=========================================="
echo "Setting and Testing API Key"
echo "=========================================="
echo ""

# Test the API key first
echo "Testing API key..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-N8N-API-KEY: ${API_KEY}" \
    "http://localhost:5678/api/v1/workflows" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" == "200" ]]; then
    echo "✅ API key is valid and working!"
    echo ""
    
    # Update .env
    if [[ -f ".env" ]]; then
        # Remove old API key line if exists
        sed -i '/^N8N_API_KEY=/d' .env 2>/dev/null || true
        
        # Add new API key
        echo "N8N_API_KEY=${API_KEY}" >> .env
        
        echo "✅ API key saved to .env"
        echo ""
        echo "Verifying..."
        bash scripts/validate_config.sh
    else
        echo "⚠️  .env file not found, creating it..."
        echo "N8N_API_KEY=${API_KEY}" > .env
        echo "✅ Created .env with API key"
    fi
elif [[ "$HTTP_CODE" == "401" ]] || [[ "$HTTP_CODE" == "403" ]]; then
    echo "❌ API key is invalid (HTTP $HTTP_CODE)"
    echo ""
    echo "This key doesn't work with n8n API."
    echo ""
    echo "The key you provided looks like a UUID, not an n8n API key."
    echo "n8n API keys usually:"
    echo "  - Start with 'n8n_' followed by alphanumeric characters, OR"
    echo "  - Are JWT tokens (three parts separated by dots)"
    echo ""
    echo "To get the correct API key:"
    echo "  1. Open http://localhost:5678 (with port forwarding active)"
    echo "  2. Go to Settings → API"
    echo "  3. Look for 'API Key' or 'Create API Key'"
    echo "  4. Copy the key (it should start with 'n8n_' or be a JWT token)"
    exit 1
elif [[ "$HTTP_CODE" == "000" ]]; then
    echo "⚠️  Could not test API key (n8n may not be running)"
    echo ""
    echo "Saving key to .env anyway, but you should test it after starting services:"
    echo "  bash scripts/start_all_services.sh"
    echo "  bash scripts/validate_config.sh"
    
    if [[ -f ".env" ]]; then
        sed -i '/^N8N_API_KEY=/d' .env 2>/dev/null || true
        echo "N8N_API_KEY=${API_KEY}" >> .env
    else
        echo "N8N_API_KEY=${API_KEY}" > .env
    fi
    echo "✅ API key saved to .env"
else
    echo "❌ API key test failed (HTTP $HTTP_CODE)"
    echo ""
    echo "This might not be a valid n8n API key."
    echo "Check n8n is running and the key is correct."
    exit 1
fi
