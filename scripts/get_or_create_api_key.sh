#!/usr/bin/env bash
# Script to get or create n8n API key
# Outputs ONLY the raw API key to stdout, all logging to stderr
# Usage: export N8N_API_KEY=$(bash scripts/get_or_create_api_key.sh)

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

# Validate API key format: must start with "n8n_" followed by alphanumeric
validate_api_key() {
    local key="$1"
    if [[ "$key" =~ ^n8n_[A-Za-z0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

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
            key = keys[0].get('apiKey', '')
            if key:
                print(key)
    elif isinstance(data, list) and len(data) > 0:
        key = data[0].get('apiKey', '')
        if key:
            print(key)
except:
    pass
" 2>/dev/null)

# Validate and output existing key
if [[ -n "$EXISTING_KEY" ]]; then
    if validate_api_key "$EXISTING_KEY"; then
        # ONLY output the key to stdout - no newline, no prefix, nothing else
        printf '%s' "$EXISTING_KEY"
        exit 0
    else
        echo "❌ Invalid API key format: ${EXISTING_KEY:0:20}..." >&2
        exit 1
    fi
fi

# Try to create a new API key
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

# Validate and output new key
if [[ -n "$NEW_KEY" ]]; then
    if validate_api_key "$NEW_KEY"; then
        # Save to .env for future use
        if ! grep -q "N8N_API_KEY" .env 2>/dev/null; then
            echo "N8N_API_KEY=$NEW_KEY" >> .env 2>/dev/null || true
        fi
        # ONLY output the key to stdout - no newline, no prefix, nothing else
        printf '%s' "$NEW_KEY"
        exit 0
    else
        echo "❌ Invalid API key format: ${NEW_KEY:0:20}..." >&2
        exit 1
    fi
fi

# If we get here, we failed to get or create a key
# Print error to stderr, nothing to stdout, exit 1
echo "❌ Failed to get or create API key" >&2
exit 1
