#!/usr/bin/env bash
# Quick check if n8n is running and accessible
# Usage: bash scripts/check_n8n_status.sh

echo "=========================================="
echo "Checking n8n Status"
echo "=========================================="
echo ""

# Check if n8n process is running
if pgrep -f "n8n start" > /dev/null; then
    PID=$(pgrep -f "n8n start" | head -1)
    echo "✅ n8n process is running (PID: $PID)"
else
    echo "❌ n8n process is NOT running"
    echo ""
    echo "To start n8n:"
    echo "  bash scripts/start_all_services.sh"
    echo "  # Or if using tmux:"
    echo "  tmux attach -t ai-teacher"
    exit 1
fi

echo ""

# Check if n8n is accessible locally (on VAST)
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" | grep -q "200\|404"; then
    echo "✅ n8n is accessible on localhost:5678 (on VAST instance)"
else
    echo "❌ n8n is NOT accessible on localhost:5678"
    echo "   n8n may still be starting up, or there's a configuration issue"
fi

echo ""
echo "=========================================="
echo "To access from Desktop:"
echo "=========================================="
echo ""
echo "You need SSH port forwarding active on your Desktop:"
echo ""
echo "1. On Desktop PowerShell Terminal:"
echo "   .\connect-vast.ps1"
echo ""
echo "2. Keep that SSH window open"
echo ""
echo "3. Then access: http://localhost:5678"
echo ""
echo "To check if port forwarding is active (Desktop PowerShell):"
echo "   .\scripts\check_port_forwarding.ps1"
echo ""
