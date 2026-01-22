#!/usr/bin/env bash
# Check n8n logs in detail for workflow execution errors
# Usage: bash scripts/check_n8n_logs_detailed.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Checking n8n Logs for Errors"
echo "=========================================="
echo ""

if [[ ! -f "logs/n8n.log" ]]; then
    echo "❌ n8n.log not found at logs/n8n.log"
    echo "   Check if n8n is logging to a different location"
    exit 1
fi

echo "Recent n8n log entries (last 100 lines):"
echo "----------------------------------------"
tail -100 logs/n8n.log
echo ""
echo "----------------------------------------"
echo ""
echo "Errors and warnings:"
echo "----------------------------------------"
tail -200 logs/n8n.log | grep -i "error\|warn\|fail\|exception" | tail -30 || echo "No errors found"
echo ""
echo "----------------------------------------"
echo ""
echo "Workflow execution related entries:"
echo "----------------------------------------"
tail -200 logs/n8n.log | grep -i "workflow\|execution\|webhook" | tail -20 || echo "No workflow entries found"
