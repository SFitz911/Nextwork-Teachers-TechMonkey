#!/usr/bin/env bash
# Consolidated webhook testing - replaces multiple test scripts
# Usage:
#   bash scripts/test_webhook.sh [message]
#   bash scripts/test_webhook.sh --full [message]
#   bash scripts/test_webhook.sh --verbose [message]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

N8N_URL="${N8N_URL:-http://localhost:5678}"
WEBHOOK_URL="${N8N_URL}/webhook/chat-webhook"

# Parse arguments
MODE="simple"
MESSAGE="Hello, can you introduce yourself?"

if [[ "${1:-}" == "--full" ]] || [[ "${1:-}" == "--verbose" ]]; then
    MODE="${1}"
    MESSAGE="${2:-Hello, can you introduce yourself?}"
elif [[ -n "${1:-}" ]]; then
    MESSAGE="${1}"
fi

echo "=========================================="
echo "Testing Webhook"
echo "=========================================="
echo ""
echo "Webhook URL: $WEBHOOK_URL"
echo "Message: $MESSAGE"
echo ""

# Test webhook
TIMESTAMP=$(date +%s)
START_TIME=$(date +%s.%N)

RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"message\": \"$MESSAGE\", \"timestamp\": $TIMESTAMP}" \
    -w "\nHTTP_CODE:%{http_code}\nTIME_TOTAL:%{time_total}")

END_TIME=$(date +%s.%N)
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
TIME_TOTAL=$(echo "$RESPONSE" | grep "TIME_TOTAL:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:" | grep -v "TIME_TOTAL:")

# Calculate elapsed time
ELAPSED=$(echo "$END_TIME - $START_TIME" | bc 2>/dev/null || echo "$TIME_TOTAL")

echo "HTTP Status: $HTTP_CODE"
echo "Response Time: ${ELAPSED}s"
echo ""

if [[ "$HTTP_CODE" != "200" ]]; then
    echo "❌ Webhook test failed (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
    exit 1
fi

if [[ -z "$BODY" ]]; then
    echo "⚠️  Webhook returned empty response"
    echo ""
    echo "This usually means:"
    echo "  1. Workflow is not activated"
    echo "  2. Workflow failed before 'Respond to Webhook' node"
    echo "  3. Service timeout"
    echo ""
    echo "To diagnose:"
    echo "  bash scripts/diagnose_webhook.sh"
    echo "  bash scripts/inspect_execution.sh --latest"
    exit 1
fi

# Try to parse JSON
if echo "$BODY" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
    echo "✅ Webhook returned valid JSON"
    
    if [[ "$MODE" == "--full" ]] || [[ "$MODE" == "--verbose" ]]; then
        echo ""
        echo "=== Full Response ==="
        echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
    else
        echo "Response preview: $(echo "$BODY" | head -c 200)..."
    fi
else
    echo "⚠️  Webhook returned non-JSON response"
    echo "Response: $BODY"
fi

echo ""
echo "✅ Webhook test complete"
