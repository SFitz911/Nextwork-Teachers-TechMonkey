#!/usr/bin/env bash
# Simple debug - test each component individually
# Usage: bash scripts/debug_webhook_simple.sh

set -euo pipefail

echo "=========================================="
echo "Simple Component Test"
echo "=========================================="
echo ""

# 1. Test Ollama directly
echo "1. Testing Ollama..."
OLLAMA_TEST=$(curl -s -X POST http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d '{"model": "mistral:7b", "prompt": "Say hello", "stream": false}' 2>&1)

if echo "$OLLAMA_TEST" | grep -q "response\|error"; then
    echo "✅ Ollama is responding"
    echo "   Response preview: $(echo "$OLLAMA_TEST" | head -c 100)..."
else
    echo "❌ Ollama is NOT responding"
    echo "   Response: $OLLAMA_TEST"
fi
echo ""

# 2. Test webhook and see raw response
echo "2. Testing webhook (showing first 500 chars of response)..."
WEBHOOK_RESPONSE=$(curl -s -X POST "http://localhost:5678/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": 1234567890}')

if [[ -z "$WEBHOOK_RESPONSE" ]]; then
    echo "❌ Webhook returned EMPTY response"
else
    echo "✅ Webhook returned response (${#WEBHOOK_RESPONSE} chars):"
    echo "$WEBHOOK_RESPONSE" | head -c 500
    echo ""
fi
echo ""

# 3. Check if services are running
echo "3. Checking services..."
for service in "n8n" "ollama" "tts" "animation"; do
    case $service in
        n8n) port=5678 ;;
        ollama) port=11434 ;;
        tts) port=8001 ;;
        animation) port=8002 ;;
    esac
    
    if curl -s "http://localhost:$port" > /dev/null 2>&1 || \
       curl -s "http://localhost:$port/api/tags" > /dev/null 2>&1 || \
       curl -s "http://localhost:$port/docs" > /dev/null 2>&1; then
        echo "✅ $service is running on port $port"
    else
        echo "❌ $service is NOT accessible on port $port"
    fi
done
echo ""

# 4. Check latest n8n execution - simple way
echo "4. Checking n8n logs for latest execution error..."
tail -100 logs/n8n.log | grep -i "error\|fail" | tail -5 || echo "No recent errors in logs"
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo "If Ollama is not responding, the workflow will fail at 'LLM Generate' node"
echo "If webhook returns empty, check n8n UI execution to see which node failed"
