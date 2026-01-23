#!/usr/bin/env bash
# Restart TTS service properly
# Usage: bash scripts/restart_tts_service.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Restarting TTS Service"
echo "=========================================="
echo ""

# Step 1: Kill ALL TTS processes
echo "Step 1: Killing all TTS processes..."
pkill -9 -f "python.*tts/app.py" 2>/dev/null || true
pkill -9 -f "services/tts/app.py" 2>/dev/null || true

# Also kill via tmux if it's running there
if tmux has-session -t ai-teacher 2>/dev/null; then
    echo "   Stopping TTS in tmux session..."
    tmux send-keys -t ai-teacher:tts C-c 2>/dev/null || true
    sleep 2
fi

# Kill any process on port 8001
if command -v fuser >/dev/null 2>&1; then
    fuser -k 8001/tcp 2>/dev/null || true
fi

sleep 2

# Step 2: Verify it's stopped
if pgrep -f "python.*tts/app.py" > /dev/null; then
    echo "❌ TTS is still running! Force killing..."
    pkill -9 -f "python.*tts" || true
    sleep 2
else
    echo "✅ TTS is stopped"
fi
echo ""

# Step 3: Verify code is updated
echo "Step 2: Verifying code is updated..."
if grep -q "ALWAYS return a valid audio_url" services/tts/app.py; then
    echo "✅ Code is updated (has audio_url fix)"
else
    echo "❌ Code is NOT updated! Pulling latest..."
    git pull origin main
fi
echo ""

# Step 4: Start TTS service
echo "Step 3: Starting TTS service..."

# Activate venv
if [[ -f "$HOME/ai-teacher-venv/bin/activate" ]]; then
    source "$HOME/ai-teacher-venv/bin/activate"
else
    echo "❌ Virtual environment not found at $HOME/ai-teacher-venv"
    exit 1
fi

# Create logs directory
mkdir -p logs

# Start TTS
cd "$PROJECT_DIR"
python services/tts/app.py > logs/tts.log 2>&1 &
TTS_PID=$!

sleep 3

# Step 5: Verify it's running
if pgrep -f "python.*tts/app.py" > /dev/null; then
    echo "✅ TTS is running (PID: $(pgrep -f 'python.*tts/app.py'))"
else
    echo "❌ TTS failed to start!"
    echo "   Check logs: tail -30 logs/tts.log"
    exit 1
fi
echo ""

# Step 6: Test TTS service
echo "Step 4: Testing TTS service..."
TEST_RESPONSE=$(curl -s -X POST http://localhost:8001/tts \
    -H "Content-Type: application/json" \
    -d '{"text": "test", "voice": "en_US-lessac-medium"}' 2>&1)

AUDIO_URL=$(echo "$TEST_RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('audio_url', 'NOT_FOUND'))" 2>/dev/null || echo "PARSE_ERROR")

echo "   Response:"
echo "$TEST_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$TEST_RESPONSE"
echo ""

if [[ "$AUDIO_URL" != "null" ]] && [[ "$AUDIO_URL" != "None" ]] && [[ "$AUDIO_URL" != "NOT_FOUND" ]] && [[ "$AUDIO_URL" != "PARSE_ERROR" ]]; then
    echo "✅ TTS is working! audio_url: $AUDIO_URL"
    echo ""
    echo "=========================================="
    echo "✅ TTS Service Restarted Successfully"
    echo "=========================================="
else
    echo "❌ TTS is NOT working correctly (audio_url is null or missing)"
    echo ""
    echo "Checking logs for errors..."
    tail -20 logs/tts.log
    echo ""
    echo "=========================================="
    echo "❌ TTS Service Restart Failed"
    echo "=========================================="
    exit 1
fi
