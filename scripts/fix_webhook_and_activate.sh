#!/usr/bin/env bash
# Script to fix webhook issues and activate n8n workflow
# Usage: bash scripts/fix_webhook_and_activate.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Fixing Webhook and Activating n8n Workflow"
echo "=========================================="
echo ""

# Check if n8n is running
if ! pgrep -f "n8n start" > /dev/null; then
    echo "❌ n8n is not running. Starting n8n..."
    bash scripts/run_no_docker_tmux.sh
    sleep 5
fi

# Check if n8n is accessible
echo "Testing n8n connection..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 | grep -q "200\|404"; then
    echo "✅ n8n is accessible"
else
    echo "❌ n8n is not accessible. Check if it's running."
    exit 1
fi

# Test webhook endpoint
echo ""
echo "Testing webhook endpoint..."
WEBHOOK_RESPONSE=$(curl -s -X POST http://localhost:5678/webhook/chat-webhook \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": 1234567890}' 2>&1)

if echo "$WEBHOOK_RESPONSE" | grep -q "404\|not registered"; then
    echo "⚠️  Webhook not registered - workflow needs to be activated"
    echo ""
    echo "To activate the workflow:"
    echo "1. Open http://localhost:5678 in your browser"
    echo "2. Log in with your credentials"
    echo "3. Open the workflow: 'AI Virtual Classroom - Five Teacher Workflow'"
    echo "   (or import n8n/workflows/five-teacher-workflow.json if needed)"
    echo "4. Click the 'Active/Inactive' toggle in the top-right to activate it"
    echo ""
    echo "If you don't see the toggle, n8n might be in dev mode."
    echo "Check n8n logs: tail -20 logs/n8n.log"
else
    echo "✅ Webhook is working!"
    echo "Response: $WEBHOOK_RESPONSE"
fi

# Check if services are running
echo ""
echo "Checking service status..."
echo ""

SERVICES=(
    "n8n:http://localhost:5678"
    "TTS:http://localhost:8001/docs"
    "Animation:http://localhost:8002/docs"
    "Ollama:http://localhost:11434"
)

for service in "${SERVICES[@]}"; do
    IFS=':' read -r name url <<< "$service"
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|404"; then
        echo "✅ $name is accessible"
    else
        echo "❌ $name is not accessible"
    fi
done

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Ensure n8n workflow is activated (see above)"
echo "2. Import the updated workflow if needed:"
echo "   - Go to n8n UI → Workflows → Import from File"
echo "   - Select: n8n/workflows/five-teacher-workflow.json"
echo "3. Test the frontend at http://localhost:8501"
echo "4. Send a message and watch the teachers animate!"
echo ""
