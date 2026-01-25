#!/bin/bash
# Test the complete session flow end-to-end
# Usage: bash scripts/test_session_flow.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

COORDINATOR_URL="http://localhost:8004"

echo "=========================================="
echo "Testing Complete Session Flow"
echo "=========================================="
echo ""

# Step 1: Start a session
echo "Step 1: Starting a session..."
SESSION_RESPONSE=$(curl -s -X POST "$COORDINATOR_URL/session/start" \
    -H "Content-Type: application/json" \
    -d '{
        "selectedTeachers": ["teacher_a", "teacher_d"],
        "lessonUrl": "https://example.com/lesson/1"
    }')

SESSION_ID=$(echo "$SESSION_RESPONSE" | python3 -c "import json, sys; d=json.load(sys.stdin); print(d.get('sessionId', ''))" 2>/dev/null || echo "")

if [[ -z "$SESSION_ID" ]]; then
    echo "❌ Failed to create session"
    echo "Response: $SESSION_RESPONSE"
    exit 1
fi

echo "✅ Session created: $SESSION_ID"
echo ""

# Step 2: Check session state
echo "Step 2: Checking session state..."
SESSION_STATE=$(curl -s "$COORDINATOR_URL/session/$SESSION_ID/state")
echo "Session state:"
echo "$SESSION_STATE" | python3 -m json.tool 2>/dev/null || echo "$SESSION_STATE"
echo ""

# Step 3: Update section (triggers render job)
echo "Step 3: Updating section (this should trigger a render job)..."
SECTION_RESPONSE=$(curl -s -X POST "$COORDINATOR_URL/session/$SESSION_ID/section" \
    -H "Content-Type: application/json" \
    -d '{
        "sessionId": "'"$SESSION_ID"'",
        "sectionId": "sec-01",
        "url": "https://example.com/lesson/1",
        "scrollY": 0,
        "visibleText": "This is a test section for the AI teachers to discuss.",
        "selectedText": "",
        "userQuestion": null
    }')

echo "Section update response: $SECTION_RESPONSE"
echo ""

# Step 4: Wait a moment for worker to process
echo "Step 4: Waiting for worker to process (30 seconds)..."
sleep 30

# Step 5: Check session state again (should have clip ready)
echo "Step 5: Checking if clip was generated..."
SESSION_STATE_AFTER=$(curl -s "$COORDINATOR_URL/session/$SESSION_ID/state")
RENDERER_STATUS=$(echo "$SESSION_STATE_AFTER" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    renderer = d.get('renderer', '')
    if renderer:
        queue = d.get('queues', {}).get(renderer, {})
        print(queue.get('status', 'unknown'))
    else:
        print('no_renderer')
except:
    print('error')
" 2>/dev/null || echo "error")

if [[ "$RENDERER_STATUS" == "ready" ]]; then
    echo "✅ Renderer clip is ready!"
elif [[ "$RENDERER_STATUS" == "rendering" ]]; then
    echo "⏳ Renderer is still processing..."
    echo "   Wait a bit longer and check again"
elif [[ "$RENDERER_STATUS" == "idle" ]]; then
    echo "⚠️  Renderer is idle (job may not have been enqueued)"
else
    echo "⚠️  Renderer status: $RENDERER_STATUS"
fi
echo ""

# Step 6: Check active sessions
echo "Step 6: Checking active sessions..."
ACTIVE_SESSIONS=$(curl -s "$COORDINATOR_URL/" | python3 -c "import json, sys; d=json.load(sys.stdin); print(d.get('activeSessions', 0))" 2>/dev/null || echo "0")
echo "Active sessions: $ACTIVE_SESSIONS"
echo ""

echo "=========================================="
echo "Test Complete"
echo "=========================================="
echo ""
echo "Session ID: $SESSION_ID"
echo "To check session state:"
echo "  curl $COORDINATOR_URL/session/$SESSION_ID/state"
echo ""
echo "To view in frontend:"
echo "  Open http://localhost:8501 (with port forwarding)"
echo "  The session should appear in the UI"
echo ""
