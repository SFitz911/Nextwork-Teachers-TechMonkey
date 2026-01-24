#!/usr/bin/env bash
# Diagnose TTS and LongCat-Video issues
# Usage: bash scripts/diagnose_tts_and_longcat.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Diagnosing TTS and LongCat-Video Issues"
echo "=========================================="
echo ""

# Check TTS service
echo "1. Checking TTS service..."
if pgrep -f "python.*tts/app.py" > /dev/null; then
    echo "✅ TTS service is running (PID: $(pgrep -f 'python.*tts/app.py' | head -1))"
else
    echo "❌ TTS service is NOT running"
    echo ""
    echo "Checking TTS logs..."
    if [[ -f "logs/tts.log" ]]; then
        echo "Last 20 lines of TTS log:"
        tail -20 logs/tts.log
    else
        echo "No TTS log file found"
    fi
    echo ""
    echo "Try starting TTS service:"
    echo "  source ~/ai-teacher-venv/bin/activate"
    echo "  python services/tts/app.py > logs/tts.log 2>&1 &"
fi

echo ""

# Test TTS service
echo "2. Testing TTS service..."
TTS_RESPONSE=$(curl -s -X POST http://localhost:8001/tts \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello test", "voice": "en_US-lessac-medium"}' 2>&1 || echo "ERROR")

if echo "$TTS_RESPONSE" | grep -q "audio_url"; then
    echo "✅ TTS service returned audio_url"
    echo "$TTS_RESPONSE" | python3 -m json.tool 2>/dev/null | head -10 || echo "$TTS_RESPONSE"
else
    echo "❌ TTS service error:"
    echo "$TTS_RESPONSE"
fi

echo ""

# Check LongCat-Video service
echo "3. Checking LongCat-Video service..."
if curl -s http://localhost:8003/status > /dev/null 2>&1; then
    echo "✅ LongCat-Video service is accessible"
    STATUS=$(curl -s http://localhost:8003/status | python3 -c "import sys, json; d=json.load(sys.stdin); print(f\"Status: {d.get('status')}, Model exists: {d.get('model_exists')}\")" 2>/dev/null || echo "unknown")
    echo "   $STATUS"
else
    echo "❌ LongCat-Video service is NOT accessible on port 8003"
fi

echo ""

# Check latest execution
echo "4. Checking latest n8n execution..."
if command -v python3 > /dev/null; then
    LATEST_EXEC=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI1MzE3fQ.tU1VEaQCrymcz8MIkAWuWfpBJoT9O7R8olTeBe42JJ0}" \
        "http://localhost:5678/api/v1/executions?limit=1" 2>/dev/null | \
        python3 -c "import sys, json; d=json.load(sys.stdin); execs=d.get('data',[]); print(execs[0].get('id','') if execs else '')" 2>/dev/null || echo "")
    
    if [[ -n "$LATEST_EXEC" ]]; then
        echo "Latest execution ID: $LATEST_EXEC"
        echo "Run: bash scripts/inspect_execution.sh $LATEST_EXEC"
    else
        echo "No executions found"
    fi
fi

echo ""
echo "=========================================="
echo "Diagnosis Complete"
echo "=========================================="
