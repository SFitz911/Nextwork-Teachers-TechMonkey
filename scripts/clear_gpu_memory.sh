#!/bin/bash
# Clear GPU memory by killing processes using CUDA
# Usage: bash scripts/clear_gpu_memory.sh

set -euo pipefail

echo "=========================================="
echo "Clearing GPU Memory"
echo "=========================================="
echo ""

# Check current GPU usage
echo "Current GPU memory usage:"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || echo "nvidia-smi not available"

echo ""
echo "Finding processes using CUDA..."

# Find processes using CUDA (Python processes that might be using GPU)
PYTHON_PIDS=$(ps aux | grep -E "python.*(longcat|torch|distributed)" | grep -v grep | awk '{print $2}' | sort -u)

if [[ -z "$PYTHON_PIDS" ]]; then
    echo "✅ No Python processes found using CUDA"
else
    echo "Found Python processes:"
    for pid in $PYTHON_PIDS; do
        CMD=$(ps -p $pid -o cmd= 2>/dev/null || echo "process not found")
        echo "  PID $pid: $CMD"
    done
    
    echo ""
    read -p "Kill these processes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for pid in $PYTHON_PIDS; do
            echo "Killing PID $pid..."
            kill -9 $pid 2>/dev/null || echo "  Failed to kill $pid (may already be dead)"
        done
        sleep 2
        echo "✅ Processes killed"
    else
        echo "Skipped killing processes"
    fi
fi

# Clear PyTorch cache if possible
echo ""
echo "Attempting to clear PyTorch CUDA cache..."
python3 <<EOF
import torch
if torch.cuda.is_available():
    torch.cuda.empty_cache()
    torch.cuda.ipc_collect()
    print("✅ PyTorch CUDA cache cleared")
else:
    print("⚠️  CUDA not available")
EOF

# Check GPU usage after cleanup
echo ""
echo "GPU memory usage after cleanup:"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || echo "nvidia-smi not available"

echo ""
echo "=========================================="
echo "Cleanup Complete"
echo "=========================================="
echo ""
echo "If GPU memory is still high, you may need to:"
echo "  1. Restart the VAST instance"
echo "  2. Reduce model size or use CPU offloading"
echo "  3. Check for other services using GPU"
echo ""
