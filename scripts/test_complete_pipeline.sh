#!/usr/bin/env bash
# Test the complete pipeline - all services and webhook
# Usage: bash scripts/test_complete_pipeline.sh

set -euo pipefail

echo "=========================================="
echo "Testing Complete Pipeline"
echo "=========================================="
echo ""

# Check all services
echo "1. Checking services..."
echo ""

# Ollama
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "✅ Ollama is running"
else
    echo "❌ Ollama is NOT running"
fi

# TTS
if curl -s http://localhost:8001/docs > /dev/null 2>&1; then
    echo "✅ TTS service is running"
else
    echo "❌ TTS service is NOT running"
fi

# Animation
if curl -s http://localhost:8002/docs > /dev/null 2>&1; then
    echo "✅ Animation service is running"
else
    echo "❌ Animation service is NOT running"
fi

# n8n
if curl -s http://localhost:5678 > /dev/null 2>&1; then
    echo "✅ n8n is running"
else
    echo "❌ n8n is NOT running"
fi

echo ""
echo "2. Testing webhook..."
echo ""

# Test webhook
RESPONSE=$(curl -s -X POST "http://localhost:5678/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "Hello, can you introduce yourself?", "timestamp": '$(date +%s)'}')

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:5678/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "Hello, can you introduce yourself?", "timestamp": '$(date +%s)'}')

echo "HTTP Status: $HTTP_CODE"
echo ""

if [[ -z "$RESPONSE" ]]; then
    echo "❌ Response is EMPTY"
    echo ""
    echo "The workflow executed but returned no response."
    echo "Check n8n execution logs:"
    echo "  tail -50 logs/n8n.log | grep -i error"
    echo ""
    echo "Or check recent executions in n8n UI:"
    echo "  http://localhost:5678"
else
    echo "Response body:"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
    echo ""
    
    if echo "$RESPONSE" | python3 -m json.tool > /dev/null 2>&1; then
        echo "✅ Valid JSON response!"
        echo ""
        
        # Check if response has expected fields
        if echo "$RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); print('response' in d and 'teacher' in d)" 2>/dev/null; then
            echo "✅ Response contains expected fields (response, teacher)"
        else
            echo "⚠️  Response may be missing expected fields"
        fi
    else
        echo "❌ Not valid JSON"
        echo ""
        echo "The response should be JSON. Check n8n workflow execution."
    fi
fi

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
