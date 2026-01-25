#!/usr/bin/env bash
# Check for duplicate processes to ensure we're not running unnecessary duplicates
# Usage: bash scripts/check_duplicate_processes.sh

set -euo pipefail

echo "=========================================="
echo "Checking for Duplicate Processes"
echo "=========================================="
echo ""

# Check Ollama processes
echo "1. Ollama processes:"
OLLAMA_PIDS=$(pgrep -f "ollama serve" || echo "")
if [[ -z "$OLLAMA_PIDS" ]]; then
    echo "   ❌ No Ollama processes found"
else
    OLLAMA_COUNT=$(echo "$OLLAMA_PIDS" | wc -l)
    if [[ $OLLAMA_COUNT -eq 1 ]]; then
        echo "   ✅ Only 1 Ollama process (correct): PID $OLLAMA_PIDS"
    else
        echo "   ⚠️  WARNING: Found $OLLAMA_COUNT Ollama processes!"
        echo "   PIDs: $OLLAMA_PIDS"
        echo "   You should kill duplicates: pkill -f 'ollama serve'"
    fi
fi
echo ""

# Check n8n processes
echo "2. n8n processes:"
N8N_PIDS=$(pgrep -f "n8n start" || echo "")
if [[ -z "$N8N_PIDS" ]]; then
    echo "   ❌ No n8n processes found"
else
    N8N_COUNT=$(echo "$N8N_PIDS" | wc -l)
    if [[ $N8N_COUNT -eq 1 ]]; then
        echo "   ✅ Only 1 n8n process (correct): PID $N8N_PIDS"
    else
        echo "   ⚠️  WARNING: Found $N8N_COUNT n8n processes!"
        echo "   PIDs: $N8N_PIDS"
        echo "   You should kill duplicates: pkill -f 'n8n start'"
    fi
fi
echo ""

# Check Python services
echo "3. Python service processes:"
echo "   Coordinator API:"
COORD_PIDS=$(pgrep -f "python.*coordinator/app.py" || echo "")
if [[ -z "$COORD_PIDS" ]]; then
    echo "      ❌ Not running"
else
    COORD_COUNT=$(echo "$COORD_PIDS" | wc -l)
    if [[ $COORD_COUNT -eq 1 ]]; then
        echo "      ✅ 1 process: PID $COORD_PIDS"
    else
        echo "      ⚠️  $COORD_COUNT processes: $COORD_PIDS"
    fi
fi

echo "   TTS:"
TTS_PIDS=$(pgrep -f "python.*tts/app.py" || echo "")
if [[ -z "$TTS_PIDS" ]]; then
    echo "      ❌ Not running"
else
    TTS_COUNT=$(echo "$TTS_PIDS" | wc -l)
    if [[ $TTS_COUNT -eq 1 ]]; then
        echo "      ✅ 1 process: PID $TTS_PIDS"
    else
        echo "      ⚠️  $TTS_COUNT processes: $TTS_PIDS"
    fi
fi

echo "   Animation:"
ANIM_PIDS=$(pgrep -f "python.*animation/app.py" || echo "")
if [[ -z "$ANIM_PIDS" ]]; then
    echo "      ❌ Not running"
else
    ANIM_COUNT=$(echo "$ANIM_PIDS" | wc -l)
    if [[ $ANIM_COUNT -eq 1 ]]; then
        echo "      ✅ 1 process: PID $ANIM_PIDS"
    else
        echo "      ⚠️  $ANIM_COUNT processes: $ANIM_PIDS"
    fi
fi

echo "   LongCat-Video:"
LONGCAT_PIDS=$(pgrep -f "python.*longcat_video/app.py" || echo "")
if [[ -z "$LONGCAT_PIDS" ]]; then
    echo "      ❌ Not running"
else
    LONGCAT_COUNT=$(echo "$LONGCAT_PIDS" | wc -l)
    if [[ $LONGCAT_COUNT -eq 1 ]]; then
        echo "      ✅ 1 process: PID $LONGCAT_PIDS"
    else
        echo "      ⚠️  $LONGCAT_COUNT processes: $LONGCAT_PIDS"
    fi
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "The scripts check BEFORE installing/starting to avoid duplicates."
echo "'Already installed/running' means: 'I checked, it exists, so I'm skipping to avoid duplication.'"
echo ""
echo "If you see duplicate processes above, run:"
echo "  bash scripts/quick_start_all.sh"
echo ""
echo "This will stop all services and restart them cleanly."
