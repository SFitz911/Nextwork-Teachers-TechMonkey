#!/usr/bin/env bash
# Script to test webhook and see full response
# Usage: bash scripts/test_webhook_full.sh

set -euo pipefail

N8N_URL="http://localhost:5678"

echo "=========================================="
echo "Testing Webhook - Full Response"
echo "=========================================="
echo ""

echo "Sending test message to webhook..."
echo "URL: ${N8N_URL}/webhook/chat-webhook"
echo "Body: {\"message\": \"Hello, can you introduce yourself?\", \"timestamp\": $(date +%s)}"
echo ""

# Test with verbose output
RESPONSE=$(curl -v -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "Hello, can you introduce yourself?", "timestamp": 1234567890}' 2>&1)

echo "Full curl output:"
echo "$RESPONSE"
echo ""

# Extract HTTP status
HTTP_STATUS=$(echo "$RESPONSE" | grep -i "< HTTP" | head -1 || echo "")
echo "HTTP Status: $HTTP_STATUS"
echo ""

# Extract response body (everything after the first blank line after headers)
BODY=$(echo "$RESPONSE" | sed -n '/^\r$/,$p' | tail -n +2)

if [[ -z "$BODY" ]]; then
    # Try alternative extraction
    BODY=$(echo "$RESPONSE" | grep -A 100 "^{" | head -20 || echo "$RESPONSE" | tail -20)
fi

echo "Response body:"
echo "$BODY"
echo ""

# Check if it's valid JSON
if echo "$BODY" | python3 -m json.tool > /dev/null 2>&1; then
    echo "✅ Response is valid JSON"
    echo ""
    echo "Parsed JSON:"
    echo "$BODY" | python3 -m json.tool
else
    echo "❌ Response is NOT valid JSON"
    if [[ -z "$BODY" ]]; then
        echo "   Response is EMPTY (this is the problem!)"
    else
        echo "   Response content: $BODY"
    fi
fi

echo ""
echo "Checking if workflow is executing..."
echo "Check n8n logs: tail -30 logs/n8n.log | grep -i error"
