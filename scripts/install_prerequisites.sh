#!/bin/bash
# Quick script to install missing prerequisites (Ollama and n8n)
# Run this before deploy_2teacher_system.sh if they're not installed

set -e

echo "=========================================="
echo "Installing Prerequisites"
echo "=========================================="
echo ""

# Install Ollama
if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    echo "✅ Ollama installed"
else
    echo "✅ Ollama already installed"
fi

# Install n8n
if ! command -v n8n &> /dev/null; then
    echo "Installing n8n..."
    if ! command -v node &> /dev/null; then
        echo "   Installing Node.js first..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
    fi
    npm install -g n8n
    echo "✅ n8n installed"
else
    echo "✅ n8n already installed"
fi

# Start Ollama and pull model
if ! pgrep -f "ollama serve" > /dev/null; then
    echo ""
    echo "Starting Ollama service..."
    ollama serve > /tmp/ollama.log 2>&1 &
    sleep 5
    
    echo "Checking if mistral:7b model is installed..."
    MODEL_INSTALLED=$(curl -s http://localhost:11434/api/tags 2>/dev/null | python3 -c "import json, sys; d=json.load(sys.stdin); models=[m.get('name') for m in d.get('models', [])]; print('yes' if 'mistral:7b' in models else 'no')" 2>/dev/null || echo "no")
    
    if [[ "$MODEL_INSTALLED" != "yes" ]]; then
        echo "   Installing mistral:7b model (this takes 5-10 minutes, ~4GB)..."
        ollama pull mistral:7b
        echo "✅ mistral:7b model installed"
    else
        echo "✅ mistral:7b model already installed"
    fi
else
    echo "✅ Ollama already running"
fi

echo ""
echo "=========================================="
echo "✅ Prerequisites installed!"
echo "=========================================="
echo ""
echo "You can now run: bash scripts/deploy_2teacher_system.sh"
