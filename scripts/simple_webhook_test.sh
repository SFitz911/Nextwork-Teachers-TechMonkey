#!/usr/bin/env bash
# Simple webhook test - just get the response
# Usage: bash scripts/simple_webhook_test.sh

N8N_URL="http://localhost:5678"

echo "Testing webhook..."
echo ""

# Get response body only
RESPONSE=$(curl -s -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": 1234567890}')

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": 1234567890}')

echo "HTTP Status: $HTTP_CODE"
echo ""

if [[ -z "$RESPONSE" ]]; then
    echo "❌ Response is EMPTY"
    echo ""
    echo "The workflow is executing but not returning a response."
    echo "This means it's likely failing before reaching the 'Respond to Webhook' node."
    echo ""
    echo "Check n8n execution logs:"
    echo "  tail -50 logs/n8n.log | grep -i error"
else
    echo "Response body:"
    echo "$RESPONSE"
    echo ""
    
    if echo "$RESPONSE" | python3 -m json.tool > /dev/null 2>&1; then
        echo "✅ Valid JSON response"
    else
        echo "❌ Not valid JSON"
    fi
fi
