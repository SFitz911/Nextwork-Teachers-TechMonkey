#!/usr/bin/env bash
# Debug why videos aren't showing in frontend
# Usage: bash scripts/debug_missing_video.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Debugging Missing Video Issue"
echo "=========================================="
echo ""

# 1. Check if videos are being generated
echo "1. Checking for generated videos..."
if [[ -d "outputs/longcat" ]]; then
    VIDEO_FILES=$(find outputs/longcat -name "video_*.mp4" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "   Found $VIDEO_FILES video files"
    if [[ "$VIDEO_FILES" -gt 0 ]]; then
        echo "   Recent videos:"
        find outputs/longcat -name "video_*.mp4" -type f -printf "   %T@ %p\n" 2>/dev/null | sort -rn | head -3 | while read timestamp path; do
            SIZE=$(du -h "$path" 2>/dev/null | cut -f1)
            echo "   - $(basename "$path") (${SIZE})"
        done
    else
        echo "   ⚠️  No video files found - videos may not be generating"
    fi
else
    echo "   ⚠️  Output directory not found: outputs/longcat"
fi
echo ""

# 2. Check LongCat-Video service status
echo "2. Checking LongCat-Video service..."
STATUS=$(curl -s http://localhost:8003/status 2>/dev/null || echo '{"status":"error"}')
ACTIVE_JOBS=$(echo "$STATUS" | python3 -c "import json, sys; d=json.load(sys.stdin); print(d.get('active_jobs', 0))" 2>/dev/null || echo "0")
echo "   Active jobs: $ACTIVE_JOBS"
if [[ "$ACTIVE_JOBS" -gt 0 ]]; then
    echo "   ⚠️  Videos are still processing (this is normal, takes 30-60 seconds)"
fi
echo ""

# 3. Check recent LongCat-Video logs
echo "3. Recent LongCat-Video logs (last 20 lines)..."
if [[ -f "logs/longcat_video.log" ]]; then
    tail -20 logs/longcat_video.log | grep -E "generate|video|job_id|ERROR|completed|status" || echo "   (no relevant entries)"
else
    echo "   ⚠️  Log file not found"
fi
echo ""

# 4. Check Coordinator API for recent clip-ready events
echo "4. Checking Coordinator API logs for CLIP_READY events..."
if [[ -f "logs/coordinator.log" ]]; then
    CLIP_READY_COUNT=$(grep -c "CLIP_READY" logs/coordinator.log 2>/dev/null || echo "0")
    echo "   Found $CLIP_READY_COUNT CLIP_READY events in logs"
    echo "   Recent CLIP_READY events:"
    grep "CLIP_READY" logs/coordinator.log | tail -3 || echo "   (none found)"
else
    echo "   ⚠️  Log file not found"
fi
echo ""

# 5. Check n8n workflow executions
echo "5. Checking n8n workflow status..."
if curl -s http://localhost:5678 > /dev/null 2>&1; then
    echo "   ✅ n8n is accessible"
    echo "   Check recent executions in n8n UI: http://localhost:5678"
    echo "   Look for 'POST Clip Ready' node - check if it succeeded"
else
    echo "   ❌ n8n is NOT accessible"
fi
echo ""

# 6. Test video URL format
echo "6. Testing video URL accessibility..."
if [[ -d "outputs/longcat" ]]; then
    LATEST_VIDEO=$(find outputs/longcat -name "video_*.mp4" -type f -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    if [[ -n "$LATEST_VIDEO" ]]; then
        JOB_ID=$(basename "$LATEST_VIDEO" | sed 's/video_\(.*\)\.mp4/\1/')
        echo "   Latest video job ID: $JOB_ID"
        echo "   Testing URL: http://localhost:8003/video/$JOB_ID"
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8003/video/$JOB_ID" 2>/dev/null || echo "000")
        if [[ "$HTTP_CODE" == "200" ]]; then
            echo "   ✅ Video URL is accessible"
        else
            echo "   ❌ Video URL returned HTTP $HTTP_CODE"
            echo "   This might be why videos aren't showing!"
        fi
    else
        echo "   ⚠️  No videos found to test"
    fi
fi
echo ""

# 7. Check if video status is "processing" vs "completed"
echo "7. Checking video generation status..."
echo "   Videos start with status='processing' and change to 'completed' when ready"
echo "   The frontend should handle both, but check if status is stuck on 'processing'"
echo ""

echo "=========================================="
echo "Common Issues & Solutions"
echo "=========================================="
echo ""
echo "Issue 1: Video URL is 'processing' status"
echo "  → Videos take 30-60 seconds to generate"
echo "  → Check: curl http://localhost:8003/status"
echo "  → Wait for active_jobs to reach 0"
echo ""
echo "Issue 2: Video URL format is wrong"
echo "  → Should be: http://localhost:8003/video/{jobId}"
echo "  → Check n8n workflow 'Format Clip' node output"
echo ""
echo "Issue 3: Port forwarding not active for port 8003"
echo "  → Make sure .\connect-vast-simple.ps1 is running"
echo "  → Check: curl http://localhost:8003/status (from Desktop)"
echo ""
echo "Issue 4: CLIP_READY event not received"
echo "  → Check Coordinator logs: tail -50 logs/coordinator.log"
echo "  → Check n8n 'POST Clip Ready' node execution"
echo ""
echo "Issue 5: Frontend not processing CLIP_READY event"
echo "  → Check browser console for errors"
echo "  → Verify SSE connection: Check Network tab for /session/{id}/events"
echo ""
