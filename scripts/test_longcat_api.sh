#!/usr/bin/env bash
# Test LongCat-Video API directly
# Usage: bash scripts/test_longcat_api.sh

set -euo pipefail

echo "=========================================="
echo "Testing LongCat-Video API"
echo "=========================================="
echo ""

# Test 1: Check service status
echo "1. Checking service status..."
STATUS_RESPONSE=$(curl -s http://localhost:8003/status)
echo "$STATUS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$STATUS_RESPONSE"
echo ""

# Test 2: Test with minimal valid request
echo "2. Testing /generate endpoint with minimal request..."
TEST_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:8003/generate \
  -H "Content-Type: application/json" \
  -d '{
    "avatar_id": "teacher_a",
    "audio_url": "http://localhost:8001/test.wav",
    "text_prompt": "A person speaking naturally",
    "resolution": "480p",
    "num_segments": 1
  }')

HTTP_CODE=$(echo "$TEST_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$TEST_RESPONSE" | grep -v "HTTP_CODE:")

echo "HTTP Status: $HTTP_CODE"
echo "Response:"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo ""

if [[ "$HTTP_CODE" == "400" ]]; then
    echo "❌ 400 Bad Request - Check the error message above"
    echo ""
    echo "Common issues:"
    echo "  - avatar_id must be one of: teacher_a, teacher_b, teacher_c, teacher_d, teacher_e"
    echo "  - audio_url must be a valid URL"
    echo "  - Missing required fields"
    echo ""
    echo "Check LongCat-Video service logs for details"
elif [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "202" ]]; then
    echo "✅ Request accepted!"
else
    echo "⚠️  Unexpected status code: $HTTP_CODE"
fi
