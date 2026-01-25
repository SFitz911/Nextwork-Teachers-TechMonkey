#!/usr/bin/env bash
# Check video generation status and debug why videos aren't showing
# Usage: bash scripts/check_video_status.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Checking Video Generation Status"
echo "=========================================="
echo ""

# Check if videos were generated
echo "1. Checking for generated video files..."
if [[ -d "outputs/longcat" ]]; then
    VIDEO_FILES=$(find outputs/longcat -name "*.mp4" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "   Found $VIDEO_FILES video files"
    
    if [[ "$VIDEO_FILES" -gt 0 ]]; then
        echo "   Recent videos:"
        find outputs/longcat -name "*.mp4" -type f -printf "   %T@ %p\n" 2>/dev/null | sort -rn | head -5 | while read timestamp path; do
            size=$(du -h "$path" 2>/dev/null | cut -f1)
            echo "   - $(basename "$path") ($size) - $(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown time')"
        done
    else
        echo "   ⚠️  No video files found"
    fi
else
    echo "   ⚠️  Output directory not found"
fi
echo ""

# Check LongCat-Video service status
echo "2. Checking LongCat-Video service..."
STATUS=$(curl -s http://localhost:8003/status 2>/dev/null || echo "{}")
ACTIVE_JOBS=$(echo "$STATUS" | python3 -c "import json, sys; d=json.load(sys.stdin); print(d.get('active_jobs', 0))" 2>/dev/null || echo "0")
echo "   Active jobs: $ACTIVE_JOBS"
echo ""

# Check recent LongCat-Video logs for completed videos
echo "3. Checking for completed video generations..."
tail -200 logs/longcat_video.log | strings | grep -E "Video generation completed|status.*completed" | tail -5 || echo "   No completed videos found in recent logs"
echo ""

# Check Coordinator logs for CLIP_READY events
echo "4. Checking for CLIP_READY events in Coordinator..."
tail -100 logs/coordinator.log | strings | grep -E "CLIP_READY|clip-ready" | tail -5 || echo "   No CLIP_READY events found in recent logs"
echo ""

# Check if port forwarding is needed
echo "5. Video URL accessibility..."
echo "   Video URLs use: http://localhost:8003/video/{jobId}"
echo "   ⚠️  IMPORTANT: These URLs will only work if:"
echo "      1. Port forwarding is active: .\connect-vast-simple.ps1 (Desktop PowerShell)"
echo "      2. The video generation is complete (status: 'completed')"
echo "      3. The frontend receives CLIP_READY events"
echo ""

# Check recent job IDs
echo "6. Recent job IDs from logs..."
tail -100 logs/longcat_video.log | strings | grep -E "job_id|jobId|Starting video generation for job" | tail -5 || echo "   No job IDs found"
echo ""

echo "=========================================="
echo "Debugging Tips"
echo "=========================================="
echo ""
echo "If videos are generated but not showing:"
echo "  1. Check if port forwarding is active (port 8003)"
echo "  2. Check if video status is 'completed' (not 'processing')"
echo "  3. Check browser console for video loading errors"
echo "  4. Try accessing video URL directly: http://localhost:8003/video/{jobId}"
echo ""
echo "To test a specific job:"
echo "  curl http://localhost:8003/job/{jobId}"
echo ""
