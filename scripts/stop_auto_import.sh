#!/usr/bin/env bash
# Stop any auto-import mechanisms that might be running
# Usage: bash scripts/stop_auto_import.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Stopping Auto-Import Mechanisms"
echo "=========================================="
echo ""

# Check for cron jobs
echo "Step 1: Checking for cron jobs..."
CRON_JOBS=$(crontab -l 2>/dev/null | grep -i "import.*workflow\|workflow.*import" || echo "")
if [[ -n "$CRON_JOBS" ]]; then
    echo "⚠️  Found cron jobs that might import workflows:"
    echo "$CRON_JOBS"
    echo ""
    echo "   To remove, run: crontab -e"
else
    echo "✅ No cron jobs found"
fi
echo ""

# Check for running processes that might import
echo "Step 2: Checking for processes that might auto-import..."
IMPORT_PROCESSES=$(ps aux | grep -E "import.*workflow|workflow.*import|sync_and_restart" | grep -v grep || echo "")
if [[ -n "$IMPORT_PROCESSES" ]]; then
    echo "⚠️  Found processes that might import workflows:"
    echo "$IMPORT_PROCESSES"
    echo ""
    echo "   Consider killing these processes"
else
    echo "✅ No suspicious processes found"
fi
echo ""

# Check n8n environment variables
echo "Step 3: Checking n8n environment variables..."
if pgrep -f "n8n start" > /dev/null; then
    N8N_PID=$(pgrep -f "n8n start" | head -n 1)
    echo "   n8n is running (PID: $N8N_PID)"
    echo "   Checking environment variables..."
    
    # Check for auto-import related env vars
    ENV_VARS=$(cat /proc/$N8N_PID/environ 2>/dev/null | tr '\0' '\n' | grep -iE "IMPORT|WORKFLOW|AUTO" || echo "")
    if [[ -n "$ENV_VARS" ]]; then
        echo "   Found potentially relevant environment variables:"
        echo "$ENV_VARS"
    else
        echo "   ✅ No auto-import environment variables found"
    fi
else
    echo "   ⚠️  n8n is not running"
fi
echo ""

# Check for file watchers
echo "Step 4: Checking for file watchers..."
if command -v inotifywait > /dev/null 2>&1; then
    INOTIFY_PROCESSES=$(ps aux | grep inotifywait | grep -v grep || echo "")
    if [[ -n "$INOTIFY_PROCESSES" ]]; then
        echo "⚠️  Found inotifywait processes:"
        echo "$INOTIFY_PROCESSES"
    else
        echo "✅ No inotifywait processes found"
    fi
else
    echo "✅ inotifywait not installed (no file watchers)"
fi
echo ""

echo "=========================================="
echo "✅ Auto-import check complete"
echo "=========================================="
echo ""
echo "If workflows are still duplicating, the issue might be:"
echo "  1. n8n's internal database/caching"
echo "  2. A webhook or external trigger"
echo "  3. n8n's workflow backup/restore feature"
echo ""
echo "Next steps:"
echo "  1. Run: bash scripts/nuclear_delete_all_workflows.sh"
echo "  2. Check n8n UI for any scheduled workflows"
echo "  3. Check n8n logs: tail -50 logs/n8n.log"
echo ""
