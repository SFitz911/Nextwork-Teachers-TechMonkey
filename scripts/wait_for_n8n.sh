#!/bin/bash
# Wait for n8n to be fully ready
# Usage: bash scripts/wait_for_n8n.sh

set -euo pipefail

echo "Waiting for n8n to be ready..."
MAX_WAIT=30
WAIT_COUNT=0

while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
    # Check if n8n HTTP server is responding
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" 2>/dev/null || echo "000")
    
    if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "404" ]]; then
        # Check if API is responding
        if curl -s "http://localhost:5678/api/v1/workflows" > /dev/null 2>&1; then
            echo "✅ n8n is ready! (HTTP $HTTP_CODE)"
            exit 0
        fi
    fi
    
    echo "   Waiting... ($WAIT_COUNT/$MAX_WAIT seconds)"
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

echo "⚠️  n8n did not become ready within $MAX_WAIT seconds"
echo "   Check logs: tmux capture-pane -t ai-teacher:n8n -p | tail -30"
exit 1
