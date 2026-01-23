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

# Coordinator API
if pgrep -f "python.*coordinator/app.py" > /dev/null; then
    echo "✅ Coordinator API is running (PID: $(pgrep -f 'python.*coordinator/app.py' | head -1))"
else
    echo "❌ Coordinator API is NOT running"
fi

# Frontend
if pgrep -f streamlit > /dev/null; then
    echo "✅ Frontend (Streamlit) is running (PID: $(pgrep -f streamlit | head -1))"
else
    echo "❌ Frontend (Streamlit) is NOT running"
fi

echo ""
echo "2. Testing if services are accessible via localhost..."
echo ""
echo "⚠️  NOTE: This checks if services are accessible from THIS machine (VAST)."
echo "   To access from your Desktop, you need SSH port forwarding active!"
echo ""

# Test localhost connections
PORT_FORWARDING_NEEDED=false
for port in 11434 5678 8001 8002 8004 8501; do
    case $port in
        11434) name="Ollama" ;;
        5678) name="n8n" ;;
        8001) name="TTS" ;;
        8002) name="Animation" ;;
        8004) name="Coordinator API" ;;
        8501) name="Frontend" ;;
    esac
    
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" > /dev/null 2>&1 || \
       curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port/docs" > /dev/null 2>&1 || \
       curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port/api/tags" > /dev/null 2>&1; then
        echo "✅ $name is accessible on port $port (on VAST instance)"
    else
        echo "❌ $name is NOT accessible on port $port"
        PORT_FORWARDING_NEEDED=true
    fi
done

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""

# Check if we're on VAST (likely) or Desktop (unlikely but possible)
if [[ -n "${SSH_CONNECTION:-}" ]] || hostname | grep -q "vast\|C\."; then
    echo "📍 You are on the VAST instance."
    echo ""
    echo "To access services from your Desktop browser:"
    echo "  1. On Desktop PowerShell: .\connect-vast.ps1"
    echo "  2. Keep that SSH window open"
    echo "  3. Then access: http://localhost:5678 (n8n) or http://localhost:8501 (frontend)"
    echo ""
else
    echo "📍 You may be on your Desktop machine."
    if [[ "$PORT_FORWARDING_NEEDED" == "true" ]]; then
        echo ""
        echo "⚠️  Port forwarding may not be active!"
        echo "   Run: .\connect-vast.ps1 (Desktop PowerShell)"
        echo "   Keep that window open while accessing services."
        echo ""
    fi
fi

echo "For debugging the webhook issue, we need:"
echo "  ✅ n8n (port 5678) - REQUIRED"
echo "  ⚠️  TTS and Animation - Only needed when workflow runs"
echo ""
