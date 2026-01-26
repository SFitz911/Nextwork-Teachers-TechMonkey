#!/bin/bash
# Check status of video generation processes
# Usage: bash scripts/check_video_generation_status.sh

set -euo pipefail

echo "=========================================="
echo "Video Generation Status Check"
echo "=========================================="
echo ""

# Check for running video generation processes
echo "Step 1: Checking for running processes..."
echo ""

# Check for torch.distributed.run processes
DIST_PROCESSES=$(ps aux | grep -E "torch.distributed.run.*avatar" | grep -v grep || true)
if [[ -n "$DIST_PROCESSES" ]]; then
    echo "✅ Found torch.distributed.run processes:"
    echo "$DIST_PROCESSES"
else
    echo "❌ No torch.distributed.run processes found"
fi

echo ""

# Check for LongCat-Video script processes
LONGCAT_PROCESSES=$(ps aux | grep -E "run_demo_avatar" | grep -v grep || true)
if [[ -n "$LONGCAT_PROCESSES" ]]; then
    echo "✅ Found LongCat-Video script processes:"
    echo "$LONGCAT_PROCESSES"
else
    echo "❌ No LongCat-Video script processes found"
fi

echo ""

# Check GPU memory and processes
echo "Step 2: GPU Status..."
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>/dev/null || echo "No compute processes found"

echo ""
echo "Step 3: Recent video generation jobs..."
echo ""

# Check for recent job directories
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/Nextwork-Teachers-TechMonkey/outputs/longcat}"
if [[ -d "$OUTPUT_DIR" ]]; then
    echo "Output directory: $OUTPUT_DIR"
    echo ""
    
    # Find recent job directories
    RECENT_JOBS=$(find "$OUTPUT_DIR" -type d -name "job_*" -mmin -10 2>/dev/null | head -5)
    if [[ -n "$RECENT_JOBS" ]]; then
        echo "Recent job directories (last 10 minutes):"
        for job_dir in $RECENT_JOBS; do
            JOB_ID=$(basename "$job_dir" | sed 's/job_//')
            echo "  Job: $JOB_ID"
            
            # Check for video files
            VIDEO_FILES=$(find "$job_dir" -name "*.mp4" -type f 2>/dev/null)
            if [[ -n "$VIDEO_FILES" ]]; then
                echo "    ✅ Video files found:"
                echo "$VIDEO_FILES" | sed 's/^/      /'
            else
                echo "    ⏳ No video files yet (still processing?)"
            fi
            
            # Check for error files
            ERROR_FILES=$(find "$job_dir" -name "*error*" -o -name "*fail*" 2>/dev/null)
            if [[ -n "$ERROR_FILES" ]]; then
                echo "    ⚠️  Error files found:"
                echo "$ERROR_FILES" | sed 's/^/      /'
            fi
        done
    else
        echo "❌ No recent job directories found"
    fi
else
    echo "❌ Output directory not found: $OUTPUT_DIR"
fi

echo ""
echo "Step 4: Check LongCat-Video service logs..."
echo ""

# Check last 20 lines of log
if [[ -f "logs/longcat_video.log" ]]; then
    echo "Last 20 lines of log:"
    tail -20 logs/longcat_video.log
else
    echo "❌ Log file not found"
fi

echo ""
echo "=========================================="
echo "Status Check Complete"
echo "=========================================="
