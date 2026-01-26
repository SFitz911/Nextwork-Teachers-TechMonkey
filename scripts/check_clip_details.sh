#!/bin/bash
# Check details of the latest clip to see if video was generated
# Usage: bash scripts/check_clip_details.sh [session_id]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

SESSION_ID="${1:-}"

if [[ -z "$SESSION_ID" ]]; then
    echo "Usage: bash scripts/check_clip_details.sh <session_id>"
    echo ""
    echo "Getting latest session..."
    SESSION_ID=$(curl -s http://localhost:8004/sessions | python3 -c "import json, sys; sessions = json.load(sys.stdin); print(sessions[0]['sessionId'] if sessions else '')" 2>/dev/null || echo "")
    
    if [[ -z "$SESSION_ID" ]]; then
        echo "❌ No active sessions found"
        exit 1
    fi
    echo "Using session: $SESSION_ID"
    echo ""
fi

echo "=========================================="
echo "Checking Clip Details"
echo "=========================================="
echo ""

# Get session state
SESSION_STATE=$(curl -s "http://localhost:8004/session/${SESSION_ID}/state")

# Extract clip information
echo "Session State:"
echo "$SESSION_STATE" | python3 <<EOF
import json, sys

try:
    state = json.load(sys.stdin)
    
    print(f"Session ID: {state.get('sessionId', 'N/A')}")
    print(f"Status: {state.get('status', 'N/A')}")
    print(f"Speaker: {state.get('speaker', 'N/A')}")
    print(f"Renderer: {state.get('renderer', 'N/A')}")
    print(f"Turn: {state.get('turn', 'N/A')}")
    print("")
    
    # Check queues
    queues = state.get('queues', {})
    for teacher, queue in queues.items():
        print(f"Teacher {teacher}:")
        print(f"  Status: {queue.get('status', 'N/A')}")
        print(f"  Next Clip ID: {queue.get('nextClipId', 'N/A')}")
        print("")
    
    # Check if there are any clips in the session
    # (This would require checking the Coordinator API for clip history)
    print("To see clip details, check the Coordinator API logs or frontend")
    
except Exception as e:
    print(f"Error parsing session state: {e}")
    print("\nRaw response:")
    sys.stdin.seek(0)
    print(sys.stdin.read())
EOF

echo ""
echo "Checking LongCat-Video logs for recent generation attempts..."
echo ""

# Check recent LongCat-Video logs
if [[ -f "logs/longcat_video.log" ]]; then
    echo "Last 20 lines of LongCat-Video log:"
    tail -20 logs/longcat_video.log | grep -E "(Starting video generation|Generation failed|Video generation completed|STDOUT|STDERR|ERROR)" || echo "No recent video generation activity"
else
    echo "⚠️  LongCat-Video log file not found"
fi

echo ""
echo "Checking for generated video files..."
echo ""

# Check output directory
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/Nextwork-Teachers-TechMonkey/outputs/longcat}"
if [[ -d "$OUTPUT_DIR" ]]; then
    echo "Output directory: $OUTPUT_DIR"
    VIDEO_COUNT=$(find "$OUTPUT_DIR" -name "*.mp4" -type f 2>/dev/null | wc -l)
    echo "Found $VIDEO_COUNT video file(s)"
    
    if [[ $VIDEO_COUNT -gt 0 ]]; then
        echo ""
        echo "Recent video files:"
        find "$OUTPUT_DIR" -name "*.mp4" -type f -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -5 | while read timestamp path; do
            size=$(du -h "$path" 2>/dev/null | cut -f1)
            date=$(date -d "@${timestamp%.*}" 2>/dev/null || echo "unknown")
            echo "  - $path ($size, $date)"
        done
    fi
else
    echo "⚠️  Output directory not found: $OUTPUT_DIR"
fi

echo ""
echo "=========================================="
echo "To check clip status in Coordinator API:"
echo "  curl http://localhost:8004/session/${SESSION_ID}/state"
echo ""
echo "To view in frontend:"
echo "  Open http://localhost:8501 (with port forwarding)"
echo "=========================================="
