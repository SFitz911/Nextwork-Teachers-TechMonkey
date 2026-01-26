#!/bin/bash
# Kill stuck GPU processes that are holding memory
# Usage: bash scripts/kill_stuck_gpu_processes.sh

set -euo pipefail

echo "=========================================="
echo "Killing Stuck GPU Processes"
echo "=========================================="
echo ""

# Check current GPU usage
echo "Current GPU memory usage:"
nvidia-smi --query-gpu=index,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || echo "nvidia-smi not available"

echo ""
echo "Finding processes using GPU memory..."

# Get processes from nvidia-smi
GPU_PIDS=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | sort -u || echo "")

if [[ -z "$GPU_PIDS" ]]; then
    echo "⚠️  No processes found via nvidia-smi, but GPU memory is still allocated"
    echo "   This means processes died but didn't release memory"
    echo ""
    echo "Attempting to find Python processes that might be holding memory..."
    
    # Find any Python processes that might be related
    PYTHON_PIDS=$(ps aux | grep -E "python.*(longcat|torch|distributed|run_demo)" | grep -v grep | awk '{print $2}' | sort -u || echo "")
    
    if [[ -n "$PYTHON_PIDS" ]]; then
        echo "Found Python processes:"
        for pid in $PYTHON_PIDS; do
            CMD=$(ps -p $pid -o cmd= 2>/dev/null || echo "process not found")
            echo "  PID $pid: $CMD"
        done
        
        echo ""
        echo "Killing these processes..."
        for pid in $PYTHON_PIDS; do
            kill -9 $pid 2>/dev/null && echo "  ✅ Killed PID $pid" || echo "  ⚠️  Failed to kill PID $pid"
        done
    else
        echo "❌ No Python processes found"
    fi
else
    echo "Found GPU processes:"
    for pid in $GPU_PIDS; do
        CMD=$(ps -p $pid -o cmd= 2>/dev/null || echo "process not found")
        MEM=$(nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader 2>/dev/null | grep "^$pid," | cut -d',' -f2 || echo "unknown")
        echo "  PID $pid: $MEM - $CMD"
    done
    
    echo ""
    echo "Killing these processes..."
    for pid in $GPU_PIDS; do
        kill -9 $pid 2>/dev/null && echo "  ✅ Killed PID $pid" || echo "  ⚠️  Failed to kill PID $pid"
    done
fi

# Wait a moment
sleep 3

# Clear PyTorch cache
echo ""
echo "Clearing PyTorch CUDA cache..."
python3 <<EOF
import torch
if torch.cuda.is_available():
    torch.cuda.empty_cache()
    torch.cuda.ipc_collect()
    print("✅ PyTorch CUDA cache cleared")
    print(f"   Free memory: {torch.cuda.get_device_properties(0).total_memory - torch.cuda.memory_allocated(0)} bytes")
else:
    print("⚠️  CUDA not available")
EOF

# Check GPU usage after cleanup
echo ""
echo "GPU memory usage after cleanup:"
nvidia-smi --query-gpu=index,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || echo "nvidia-smi not available"

echo ""
echo "=========================================="
echo "Cleanup Complete"
echo "=========================================="
echo ""
echo "If GPU memory is still high, you may need to:"
echo "  1. Restart the VAST instance (most reliable)"
echo "  2. Wait a few minutes for memory to be released"
echo ""
