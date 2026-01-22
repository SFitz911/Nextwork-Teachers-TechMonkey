#!/usr/bin/env bash
# Script to get or create n8n API key
# Usage: bash scripts/get_or_create_api_key.sh

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
N8N_URL="http://localhost:5678"

echo "Getting n8n API key..." >&2

# Try to get existing API keys
API_KEYS_JSON=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
    -H "Content-Type: application/json" \
    "${N8N_URL}/api/v1/api-keys" 2>/dev/null)

# Check if we got a valid response
if echo "$API_KEYS_JSON" | grep -q "Unauthorized\|401"; then
    echo "❌ Authentication failed" >&2
    exit 1
fi

# Extract API key if it exists
EXISTING_KEY=$(echo "$API_KEYS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, dict) and 'data' in data:
        keys = data['data']
        if keys and len(keys) > 0:
            print(keys[0].get('apiKey', ''))
    elif isinstance(data, list) and len(data) > 0:
        print(data[0].get('apiKey', ''))
except:
    pass
" 2>/dev/null)

if [[ -n "$EXISTING_KEY" ]]; then
    echo "$EXISTING_KEY"
    exit 0
fi

# Try to create a new API key
echo "No existing API key found. Creating new one..." >&2
CREATE_RESPONSE=$(curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"name": "Auto-generated API Key"}' \
    "${N8N_URL}/api/v1/api-keys" 2>/dev/null)

NEW_KEY=$(echo "$CREATE_RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'apiKey' in data:
        print(data['apiKey'])
    elif 'data' in data and 'apiKey' in data['data']:
        print(data['data']['apiKey'])
except:
    pass
" 2>/dev/null)

if [[ -n "$NEW_KEY" ]]; then
    echo "$NEW_KEY"
    # Save to .env for future use
    if ! grep -q "N8N_API_KEY" .env 2>/dev/null; then
        echo "N8N_API_KEY=$NEW_KEY" >> .env
        echo "✅ Saved API key to .env" >&2
    fi
    exit 0
fi

echo "❌ Failed to get or create API key" >&2
exit 1
