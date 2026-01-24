#!/usr/bin/env bash
# Check LongCat-Video service logs and diagnose 400 errors
# Usage: bash scripts/check_longcat_error.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Diagnosing LongCat-Video 400 Error"
echo "=========================================="
echo ""

# 1. Check LongCat-Video service status
echo "1. Checking LongCat-Video service status..."
if curl -s http://localhost:8003/status > /dev/null 2>&1; then
    STATUS=$(curl -s http://localhost:8003/status | python3 -m json.tool 2>/dev/null || echo "{}")
    echo "✅ LongCat-Video service is running"
    echo "$STATUS" | python3 -m json.tool 2>/dev/null || echo "$STATUS"
else
    echo "❌ LongCat-Video service is NOT accessible on port 8003"
    echo "   Check if service is running: ps aux | grep longcat"
    exit 1
fi
echo ""

# 2. Check avatar images
echo "2. Checking avatar images..."
AVATAR_DIR="$PROJECT_DIR/LongCat-Video/assets/avatars"
if [[ -d "$AVATAR_DIR" ]]; then
    echo "✅ Avatar directory exists: $AVATAR_DIR"
    echo "   Images found:"
    ls -lh "$AVATAR_DIR"/*.png 2>/dev/null | awk '{print "     - " $9}' || echo "     ❌ No PNG images found"
else
    echo "❌ Avatar directory NOT found: $AVATAR_DIR"
    echo "   Run: bash scripts/fix_avatar_images.sh"
fi
echo ""

# 3. Check LongCat-Video logs
echo "3. Checking LongCat-Video service logs..."
if [[ -f "logs/longcat_video.log" ]]; then
    echo "   Last 30 lines of log:"
    tail -30 logs/longcat_video.log | grep -E "(ERROR|400|avatar_id|audio_url|Failed)" || tail -30 logs/longcat_video.log
else
    echo "   ⚠️  No log file found at logs/longcat_video.log"
    echo "   Service might be running in foreground or logs not configured"
fi
echo ""

# 4. Test TTS service to get a valid audio_url
echo "4. Testing TTS service for valid audio_url..."
TTS_RESPONSE=$(curl -s -X POST http://localhost:8001/tts \
    -H "Content-Type: application/json" \
    -d '{"text": "Test audio for LongCat", "voice": "en_US-lessac-medium"}' 2>&1)

AUDIO_URL=$(echo "$TTS_RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); url=d.get('audio_url'); print(url if url and url != 'None' and url != 'null' else '')" 2>/dev/null || echo "")

if [[ -n "$AUDIO_URL" ]]; then
    echo "✅ TTS returned audio_url: $AUDIO_URL"
    
    # Test if audio URL is accessible
    AUDIO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$AUDIO_URL" 2>/dev/null || echo "000")
    if [[ "$AUDIO_STATUS" == "200" ]]; then
        echo "✅ Audio URL is accessible"
    else
        echo "❌ Audio URL is NOT accessible (HTTP $AUDIO_STATUS)"
        echo "   This will cause LongCat-Video to return 400"
    fi
else
    echo "❌ TTS did NOT return audio_url"
    echo "   TTS Response: $TTS_RESPONSE"
fi
echo ""

# 5. Test LongCat-Video with a manual request
echo "5. Testing LongCat-Video /generate endpoint manually..."
if [[ -n "$AUDIO_URL" ]]; then
    TEST_REQUEST=$(cat <<EOF
{
  "avatar_id": "teacher_a",
  "audio_url": "$AUDIO_URL",
  "text_prompt": "A test prompt",
  "resolution": "480p",
  "num_segments": 1
}
EOF
)
    
    TEST_RESPONSE=$(curl -s -X POST http://localhost:8003/generate \
        -H "Content-Type: application/json" \
        -d "$TEST_REQUEST" \
        -w "\nHTTP_CODE:%{http_code}")
    
    HTTP_CODE=$(echo "$TEST_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
    RESPONSE_BODY=$(echo "$TEST_RESPONSE" | grep -v "HTTP_CODE:")
    
    echo "   Request sent:"
    echo "$TEST_REQUEST" | python3 -m json.tool 2>/dev/null || echo "$TEST_REQUEST"
    echo ""
    echo "   HTTP Status: $HTTP_CODE"
    echo "   Response:"
    echo "$RESPONSE_BODY" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE_BODY"
    
    if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "202" ]]; then
        echo "✅ Manual test succeeded - LongCat-Video service is working"
    else
        echo "❌ Manual test failed (HTTP $HTTP_CODE)"
        echo "   Check the error message above"
    fi
else
    echo "⚠️  Skipping manual test - no valid audio_url from TTS"
fi
echo ""

# 6. Check latest n8n execution
echo "6. Checking latest n8n execution for LongCat-Video node..."
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI1MzE3fQ.tU1VEaQCrymcz8MIkAWuWfpBJoT9O7R8olTeBe42JJ0"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="${N8N_URL:-http://localhost:5678}"

LATEST_EXEC=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/executions?limit=1" 2>/dev/null | \
    python3 -c "import sys, json; d=json.load(sys.stdin); execs=d.get('data',[]); print(execs[0].get('id','') if execs else '')" 2>/dev/null || echo "")

if [[ -n "$LATEST_EXEC" ]]; then
    echo "   Latest execution ID: $LATEST_EXEC"
    echo "   Run: bash scripts/inspect_execution.sh $LATEST_EXEC"
    echo "   This will show what data was sent to LongCat-Video"
else
    echo "   No executions found"
fi

echo ""
echo "=========================================="
echo "Diagnosis Complete"
echo "=========================================="
echo ""
echo "Common causes of 400 errors:"
echo "  1. Invalid avatar_id (must be: teacher_a, teacher_b, teacher_c, teacher_d, teacher_e)"
echo "  2. Invalid or inaccessible audio_url"
echo "  3. Missing required fields in request body"
echo "  4. Avatar image file not found"
echo ""
