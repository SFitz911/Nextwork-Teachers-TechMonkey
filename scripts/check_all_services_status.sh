#!/usr/bin/env bash
# Check status of all services on VAST instance
# Usage: bash scripts/check_all_services_status.sh

set -euo pipefail

echo "=========================================="
echo "Checking All Services Status"
echo "=========================================="
echo ""

# Check if services are running
echo "1. Checking if processes are running..."
echo ""

# Ollama
if pgrep -f "ollama serve" > /dev/null; then
    echo "✅ Ollama is running (PID: $(pgrep -f 'ollama serve' | head -1))"
else
    echo "❌ Ollama is NOT running"
fi

# n8n
if pgrep -f "n8n start" > /dev/null; then
    echo "✅ n8n is running (PID: $(pgrep -f 'n8n start' | head -1))"
else
    echo "❌ n8n is NOT running"
fi

# TTS
if pgrep -f "python.*tts/app.py" > /dev/null; then
    echo "✅ TTS service is running (PID: $(pgrep -f 'python.*tts/app.py' | head -1))"
else
    echo "❌ TTS service is NOT running"
fi

# Animation
if pgrep -f "python.*animation/app.py" > /dev/null; then
    echo "✅ Animation service is running (PID: $(pgrep -f 'python.*animation/app.py' | head -1))"
else
    echo "❌ Animation service is NOT running"
fi

# Frontend
if pgrep -f streamlit > /dev/null; then
    echo "✅ Frontend (Streamlit) is running (PID: $(pgrep -f streamlit | head -1))"
else
    echo "❌ Frontend (Streamlit) is NOT running"
fi

echo ""
echo "2. Testing if services are accessible locally..."
echo ""

# Test localhost connections
for port in 11434 5678 8001 8002 8501; do
    case $port in
        11434) name="Ollama" ;;
        5678) name="n8n" ;;
        8001) name="TTS" ;;
        8002) name="Animation" ;;
        8501) name="Frontend" ;;
    esac
    
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" > /dev/null 2>&1 || \
       curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port/docs" > /dev/null 2>&1 || \
       curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port/api/tags" > /dev/null 2>&1; then
        echo "✅ $name is accessible on port $port"
    else
        echo "❌ $name is NOT accessible on port $port"
    fi
done

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "For debugging the webhook issue, we need:"
echo "  ✅ n8n (port 5678) - REQUIRED"
echo "  ⚠️  TTS and Animation - Only needed when workflow runs"
echo ""
echo "Since n8n is accessible, you can:"
echo "  1. Open http://localhost:5678 in your browser"
echo "  2. Check workflow executions to see which node is failing"
echo ""
