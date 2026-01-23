#!/usr/bin/env bash
# Test LongCat-Video request format to diagnose 400 errors
# Usage: bash scripts/test_longcat_request_format.sh

set -euo pipefail

echo "=========================================="
echo "Testing LongCat-Video Request Format"
echo "=========================================="
echo ""

# Test 1: Minimal valid request
echo "1. Testing with valid request format..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:8003/generate \
  -H "Content-Type: application/json" \
  -d '{
    "avatar_id": "teacher_a",
    "audio_url": "http://localhost:8001/audio/test.wav",
    "text_prompt": "A person speaking naturally",
    "resolution": "480p",
    "num_segments": 1
  }' 2>&1)

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

echo "HTTP Status: $HTTP_CODE"
if [[ "$HTTP_CODE" == "400" ]]; then
    echo "❌ 400 Bad Request - Error details:"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
    echo ""
    echo "Common causes:"
    echo "  - Invalid avatar_id (must be: teacher_a, teacher_b, teacher_c, teacher_d, teacher_e)"
    echo "  - Avatar image file not found"
    echo "  - Invalid audio_url (can't download)"
    echo "  - Missing required fields"
elif [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "202" ]]; then
    echo "✅ Request accepted!"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
else
    echo "⚠️  Status: $HTTP_CODE"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
fi

echo ""

# Test 2: Check what n8n is actually sending
echo "2. To see what n8n is sending, check the latest execution:"
echo "   bash scripts/inspect_execution.sh --latest"
echo ""

# Test 3: Verify avatar images exist
echo "3. Verifying avatar images..."
AVATAR_DIR="$HOME/Nextwork-Teachers-TechMonkey/LongCat-Video/assets/avatars"
REQUIRED=("maya.png" "maximus.png" "krishna.png" "techmonkey_steve.png" "pano_bieber.png")

for img in "${REQUIRED[@]}"; do
    if [[ -f "$AVATAR_DIR/$img" ]]; then
        echo "✅ $img exists"
    else
        echo "❌ $img MISSING at $AVATAR_DIR/$img"
    fi
done
