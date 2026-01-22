#!/usr/bin/env bash
# Script to test webhook directly and see what it returns
# Usage: bash scripts/test_webhook_directly.sh

set -euo pipefail

N8N_URL="http://localhost:5678"

echo "=========================================="
echo "Testing Webhook Directly"
echo "=========================================="
echo ""

echo "Sending POST request to webhook..."
echo "URL: ${N8N_URL}/webhook/chat-webhook"
echo "Body: {\"message\": \"test\", \"timestamp\": 1234567890}"
echo ""

RESPONSE=$(curl -v -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": 1234567890}' 2>&1)

echo "Full response:"
echo "$RESPONSE"
echo ""

# Extract just the body
BODY=$(echo "$RESPONSE" | grep -A 100 "^{" | head -20 || echo "$RESPONSE")

echo "Response body:"
echo "$BODY"
echo ""

# Check if it's valid JSON
if echo "$BODY" | python3 -m json.tool > /dev/null 2>&1; then
    echo "✅ Response is valid JSON"
else
    echo "❌ Response is NOT valid JSON (this is the problem!)"
    echo ""
    echo "The webhook might be returning HTML or an error page instead of JSON"
fi
