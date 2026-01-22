#!/usr/bin/env bash
# ⚠️  DEPRECATED: Use scripts/test_webhook.sh [message] instead
# Test webhook with a message and show full execution details
# Usage: bash scripts/test_webhook_with_message.sh

set -euo pipefail

N8N_URL="http://localhost:5678"

echo "=========================================="
echo "Testing Webhook with Message"
echo "=========================================="
echo ""

# Test webhook
echo "Sending test message..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${N8N_URL}/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "Hello, test message", "timestamp": '$(date +%s)'}')

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

echo "HTTP Status: $HTTP_CODE"
echo ""
echo "Response:"
if [[ -z "$BODY" ]]; then
    echo "  [EMPTY]"
else
    echo "$BODY" | head -20
fi

echo ""
echo "Checking execution in n8n..."
echo "Go to: http://localhost:5678/workflow/UktEICXRKntzx4GD"
echo "Click 'Executions' tab to see the latest execution"
