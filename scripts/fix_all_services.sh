#!/bin/bash
# Fix all service issues and start everything properly
# Usage: bash scripts/fix_all_services.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Fixing All Services"
echo "=========================================="
echo ""

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Load common functions
if [[ -f "scripts/lib/common.sh" ]]; then
    source "scripts/lib/common.sh"
fi

# Step 1: Pull Ollama model
echo "Step 1: Ensuring Ollama model is installed..."
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    MODEL_INSTALLED=$(curl -s http://localhost:11434/api/tags | python3 -c "import json, sys; d=json.load(sys.stdin); models=[m.get('name') for m in d.get('models', [])]; print('yes' if 'mistral:7b' in models else 'no')" 2>/dev/null || echo "no")
    
    if [[ "$MODEL_INSTALLED" != "yes" ]]; then
        echo "   Pulling mistral:7b model (this may take 5-10 minutes)..."
        ollama pull mistral:7b
        echo "✅ Model installed"
    else
        echo "✅ mistral:7b model already installed"
    fi
else
    echo "   ⚠️  Ollama not responding, will start it in next step"
fi
echo ""

# Step 2: Start all services
echo "Step 2: Starting all services..."
bash scripts/quick_start_all.sh
echo ""

# Step 3: Wait for services to be ready
echo "Step 3: Waiting for services to be ready..."
sleep 10

# Check Coordinator API
echo "   Checking Coordinator API..."
for i in {1..10}; do
    if curl -s http://localhost:8004/health > /dev/null 2>&1; then
        echo "   ✅ Coordinator API is ready"
        break
    fi
    if [[ $i -eq 10 ]]; then
        echo "   ⚠️  Coordinator API not ready after 10 attempts"
    else
        sleep 2
    fi
done

# Check n8n
echo "   Checking n8n..."
for i in {1..15}; do
    if curl -s http://localhost:5678/healthz > /dev/null 2>&1; then
        echo "   ✅ n8n is ready"
        break
    fi
    if [[ $i -eq 15 ]]; then
        echo "   ⚠️  n8n not ready after 15 attempts"
    else
        sleep 2
    fi
done
echo ""

# Step 4: Re-import n8n workflows
echo "Step 4: Re-importing n8n workflows..."
if [[ -n "${N8N_API_KEY:-}" ]]; then
    bash scripts/force_reimport_workflows.sh
else
    echo "   ⚠️  N8N_API_KEY not set, skipping workflow import"
    echo "   Set it in .env file or scripts/lib/common.sh"
fi
echo ""

# Step 5: Check LongCat-Video distributed error
echo "Step 5: Checking LongCat-Video service..."
if curl -s http://localhost:8003/status > /dev/null 2>&1; then
    STATUS=$(curl -s http://localhost:8003/status)
    echo "   Status: $STATUS"
    
    # Check for distributed error in logs
    if [[ -f "logs/longcat_video.log" ]]; then
        if grep -q "torch.distributed" logs/longcat_video.log; then
            echo "   ⚠️  Found torch.distributed errors in logs"
            echo "   This may be a configuration issue with LongCat-Video"
            echo "   Check: tail -50 logs/longcat_video.log"
        fi
    fi
else
    echo "   ⚠️  LongCat-Video service not accessible"
fi
echo ""

# Step 6: Final status check
echo "Step 6: Final service status..."
echo ""
bash scripts/check_all_services_status.sh || true
echo ""

echo "=========================================="
echo "Fix Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Check service status above"
echo "2. If Coordinator API or n8n still not running, check tmux:"
echo "   tmux attach -t ai-teacher"
echo "3. Test video generation:"
echo "   bash scripts/test_session_flow.sh"
echo ""
