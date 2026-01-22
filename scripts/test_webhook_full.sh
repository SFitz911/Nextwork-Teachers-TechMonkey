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

# Test with separate verbose and body capture
echo "Testing webhook (verbose output to stderr, body to stdout)..."
echo ""

# Get just the response body
BODY=$(curl -s -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "Hello, can you introduce yourself?", "timestamp": 1234567890}')

# Get HTTP status separately
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "Hello, can you introduce yourself?", "timestamp": 1234567890}')

echo "HTTP Status Code: $HTTP_CODE"
echo ""

echo "Response body (raw):"
if [[ -z "$BODY" ]]; then
    echo "   [EMPTY - No response body received]"
    echo ""
    echo "❌ Response is EMPTY (this is the problem!)"
    echo ""
    echo "This means the workflow is executing but not returning a response."
    echo "Possible causes:"
    echo "  1. Workflow is failing before reaching 'Respond to Webhook' node"
    echo "  2. 'Respond to Webhook' node is not properly configured"
    echo "  3. Workflow execution is timing out"
else
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
        echo "   Response content: $BODY"
        echo "   Length: ${#BODY} characters"
    fi
fi

echo ""
echo "Checking if workflow is executing..."
echo "Check n8n logs: tail -30 logs/n8n.log | grep -i error"
