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

# Validate API key format: can be n8n_ format OR JWT token
validate_api_key() {
    local key="$1"
    # n8n API key format: starts with "n8n_" followed by alphanumeric
    if [[ "$key" =~ ^n8n_[A-Za-z0-9]+$ ]]; then
        return 0
    # JWT token format: three base64 parts separated by dots
    elif [[ "$key" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Try to get existing API keys
HTTP_CODE=$(curl -s -o /tmp/api_keys_response.json -w "%{http_code}" -u "${N8N_USER}:${N8N_PASSWORD}" \
    -H "Content-Type: application/json" \
    "${N8N_URL}/api/v1/api-keys" 2>/dev/null)

API_KEYS_JSON=$(cat /tmp/api_keys_response.json 2>/dev/null || echo "")

# Check HTTP status code
if [[ "$HTTP_CODE" != "200" ]]; then
    echo "❌ API returned HTTP $HTTP_CODE" >&2
    if [[ -f /tmp/api_keys_response.json ]]; then
        echo "Response: $(head -c 200 /tmp/api_keys_response.json)" >&2
    fi
    # Try to use basic auth for other endpoints instead
    echo "⚠️  API key endpoint may require different authentication. Trying alternative method..." >&2
    rm -f /tmp/api_keys_response.json
    exit 1
fi

# Check if we got a valid response
if echo "$API_KEYS_JSON" | grep -q "Unauthorized\|401\|Forbidden"; then
    echo "❌ Authentication failed" >&2
    rm -f /tmp/api_keys_response.json
    exit 1
fi

# Check if response is valid JSON
if ! echo "$API_KEYS_JSON" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
    echo "❌ API returned non-JSON response" >&2
    echo "Response preview: $(echo "$API_KEYS_JSON" | head -c 200)" >&2
    rm -f /tmp/api_keys_response.json
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
            # Try 'apiKey' first, then 'id', then 'token'
            key = keys[0].get('apiKey') or keys[0].get('id') or keys[0].get('token') or keys[0].get('key', '')
            if key:
                print(key)
    elif isinstance(data, list) and len(data) > 0:
        key = data[0].get('apiKey') or data[0].get('id') or data[0].get('token') or data[0].get('key', '')
        if key:
            print(key)
    # Also check if the response itself is a key/token
    elif isinstance(data, dict):
        key = data.get('apiKey') or data.get('id') or data.get('token') or data.get('key', '')
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
CREATE_HTTP_CODE=$(curl -s -o /tmp/create_key_response.json -w "%{http_code}" -u "${N8N_USER}:${N8N_PASSWORD}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"name": "Auto-generated API Key"}' \
    "${N8N_URL}/api/v1/api-keys" 2>/dev/null)

CREATE_RESPONSE=$(cat /tmp/create_key_response.json 2>/dev/null || echo "")

# Check HTTP status code
if [[ "$CREATE_HTTP_CODE" != "200" ]] && [[ "$CREATE_HTTP_CODE" != "201" ]]; then
    echo "❌ Failed to create API key (HTTP $CREATE_HTTP_CODE)" >&2
    if [[ -f /tmp/create_key_response.json ]]; then
        echo "Response: $(head -c 200 /tmp/create_key_response.json)" >&2
    fi
    rm -f /tmp/create_key_response.json /tmp/api_keys_response.json
    exit 1
fi

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

# Clean up temp files
rm -f /tmp/api_keys_response.json /tmp/create_key_response.json

# If we get here, we failed to get or create a key
# Print error to stderr, nothing to stdout, exit 1
echo "❌ Failed to get or create API key" >&2
echo "   Tried to get existing keys and create new one, both failed" >&2
echo "   Check n8n is running and credentials are correct" >&2
exit 1
