#!/usr/bin/env bash
# Debug script to check why videos aren't appearing
# Usage: bash scripts/debug_video_generation.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Debugging Video Generation"
echo "=========================================="
echo ""

# Check LongCat-Video service
echo "1. Checking LongCat-Video service..."
echo ""
if curl -s http://localhost:8003/status > /dev/null 2>&1; then
    STATUS=$(curl -s http://localhost:8003/status)
    echo "✅ LongCat-Video service is running"
    echo "   Status: $STATUS"
    
    # Check if models exist
    MODEL_EXISTS=$(echo "$STATUS" | python3 -c "import json, sys; d=json.load(sys.stdin); print(d.get('model_exists', False))" 2>/dev/null || echo "unknown")
    if [[ "$MODEL_EXISTS" != "true" ]]; then
        echo "   ⚠️  WARNING: Models may not be found!"
    fi
else
    echo "❌ LongCat-Video service is NOT accessible"
fi
echo ""

# Check recent LongCat-Video logs
echo "2. Recent LongCat-Video logs (last 30 lines)..."
echo ""
if [[ -f "logs/longcat_video.log" ]]; then
    tail -30 logs/longcat_video.log | grep -E "ERROR|INFO|Generation|pyloudnorm|ModuleNotFound" || echo "   (no relevant log entries)"
else
    echo "   ⚠️  Log file not found"
fi
echo ""

# Check if videos were generated
echo "3. Checking for generated videos..."
echo ""
if [[ -d "outputs/longcat" ]]; then
    VIDEO_COUNT=$(find outputs/longcat -name "*.mp4" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "   Found $VIDEO_COUNT video files in outputs/longcat/"
    if [[ "$VIDEO_COUNT" -gt 0 ]]; then
        echo "   Recent videos:"
        find outputs/longcat -name "*.mp4" -type f -printf "   %T@ %p\n" 2>/dev/null | sort -rn | head -5 | while read timestamp path; do
            echo "   - $(basename "$path") ($(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown time'))"
        done
    fi
else
    echo "   ⚠️  Output directory not found"
fi
echo ""

# Check Coordinator API logs
echo "4. Recent Coordinator API logs (last 30 lines)..."
echo ""
if [[ -f "logs/coordinator.log" ]]; then
    tail -30 logs/coordinator.log | grep -E "CLIP_READY|clip-ready|ERROR|session" || echo "   (no relevant log entries)"
else
    echo "   ⚠️  Log file not found"
fi
echo ""

# Check n8n workflow executions
echo "5. Checking n8n workflow status..."
echo ""
if curl -s http://localhost:5678 > /dev/null 2>&1; then
    echo "   ✅ n8n is accessible"
    echo "   Check workflow executions in n8n UI: http://localhost:5678"
else
    echo "   ❌ n8n is NOT accessible"
fi
echo ""

# Check active jobs in LongCat-Video
echo "6. Checking active video generation jobs..."
echo ""
# Try to get job status (this requires a job ID, but we can check the service)
ACTIVE_JOBS=$(curl -s http://localhost:8003/status 2>/dev/null | python3 -c "import json, sys; d=json.load(sys.stdin); print(d.get('active_jobs', 0))" 2>/dev/null || echo "0")
echo "   Active jobs: $ACTIVE_JOBS"
echo ""

# Check conda environment for pyloudnorm
echo "7. Checking LongCat-Video dependencies..."
echo ""
CONDA_BASE=$(conda info --base 2>/dev/null || echo "")
if [[ -n "$CONDA_BASE" ]]; then
    source "$CONDA_BASE/etc/profile.d/conda.sh" 2>/dev/null || true
    if conda env list | grep -q "longcat-video"; then
        conda activate longcat-video 2>/dev/null || true
        if python -c "import pyloudnorm" 2>/dev/null; then
            echo "   ✅ pyloudnorm is installed in conda environment"
        else
            echo "   ❌ pyloudnorm is NOT installed in conda environment"
            echo "   Run: conda activate longcat-video && pip install pyloudnorm==0.1.1"
        fi
    else
        echo "   ⚠️  longcat-video conda environment not found"
    fi
else
    echo "   ⚠️  Conda not found"
fi
echo ""

# Check if Coordinator is receiving clip-ready requests
echo "8. Testing Coordinator API clip-ready endpoint..."
echo ""
# This would require a session ID, so we'll just check if the endpoint exists
if curl -s -X POST http://localhost:8004/session/test-session-id/clip-ready \
    -H "Content-Type: application/json" \
    -d '{"sessionId":"test","teacher":"teacher_a","clip":{}}' 2>&1 | grep -q "not found\|404"; then
    echo "   ⚠️  Endpoint exists but session not found (expected for test)"
else
    echo "   ✅ Coordinator API is responding"
fi
echo ""

echo "=========================================="
echo "Debug Summary"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Check LongCat-Video logs for errors: tail -50 logs/longcat_video.log"
echo "  2. Check Coordinator logs for CLIP_READY events: tail -50 logs/coordinator.log"
echo "  3. Check n8n workflow executions in UI: http://localhost:5678"
echo "  4. Verify video generation is working:"
echo "     curl -X POST http://localhost:8003/generate \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"avatar_id\":\"teacher_a\",\"audio_url\":\"http://localhost:8001/audio/test.wav\"}'"
echo ""
