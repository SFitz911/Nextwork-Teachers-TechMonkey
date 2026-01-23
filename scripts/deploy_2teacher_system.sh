#!/usr/bin/env bash
# Complete deployment script for 2-Teacher Architecture
# This script does everything needed to deploy the new system:
# 1. Pulls latest changes
# 2. Installs dependencies
# 3. Reconfigures n8n
# 4. Starts all services
# 5. Verifies everything is working
# Usage: bash scripts/deploy_2teacher_system.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"
SESSION="ai-teacher"

echo "=========================================="
echo "Deploying 2-Teacher Architecture"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Pull latest changes from Git"
echo "  2. Install Coordinator API dependencies"
echo "  3. Reconfigure n8n (deactivate old, import new workflows)"
echo "  4. Start all services (Ollama, Coordinator, n8n, TTS, Animation, Frontend)"
echo "  5. Verify all services are running"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Step 1: Pull latest changes
echo "=========================================="
echo "Step 1: Pulling Latest Changes"
echo "=========================================="
echo ""

if [[ -d ".git" ]]; then
    echo "Pulling from Git..."
    git pull origin main || {
        echo "⚠️  Git pull failed (maybe no remote or network issue)"
        echo "   Continuing anyway..."
    }
    echo "✅ Git pull complete"
else
    echo "⚠️  Not a git repository, skipping pull"
fi

echo ""

# Step 2: Check/create virtual environment
echo "=========================================="
echo "Step 2: Setting Up Python Environment"
echo "=========================================="
echo ""

if [[ ! -d "$VENV_DIR" ]]; then
    echo "⚠️  Virtual environment not found at $VENV_DIR"
    echo "   Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
    echo "✅ Virtual environment created"
else
    echo "✅ Virtual environment exists"
fi

echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

echo "Installing/updating Coordinator API dependencies..."
pip install -q --upgrade pip
pip install -q fastapi uvicorn httpx pydantic

echo "✅ Python environment ready"
echo ""

# Step 3: Reconfigure n8n
echo "=========================================="
echo "Step 3: Reconfiguring n8n"
echo "=========================================="
echo ""

if bash scripts/reconfigure_n8n_for_2teacher.sh; then
    echo "✅ n8n reconfiguration complete"
else
    echo "❌ n8n reconfiguration failed"
    echo "   You may need to manually configure n8n workflows"
    echo "   Continue anyway? (y/n)"
    read -r response
    if [[ "$response" != "y" ]] && [[ "$response" != "Y" ]]; then
        exit 1
    fi
fi

echo ""

# Step 4: Check if services are already running
echo "=========================================="
echo "Step 4: Checking Existing Services"
echo "=========================================="
echo ""

SERVICES_RUNNING=false
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "⚠️  tmux session '$SESSION' already exists"
    echo "   Services may already be running"
    echo ""
    echo "Options:"
    echo "  1. Stop existing services and restart (recommended)"
    echo "  2. Skip service startup (use existing)"
    echo "  3. Cancel"
    echo ""
    read -p "Choose option (1/2/3): " choice
    
    case $choice in
        1)
            echo "Stopping existing services..."
            tmux kill-session -t "$SESSION" 2>/dev/null || true
            pkill -f "ollama serve" 2>/dev/null || true
            sleep 2
            echo "✅ Existing services stopped"
            ;;
        2)
            echo "Skipping service startup..."
            SERVICES_RUNNING=true
            ;;
        3)
            echo "Cancelled"
            exit 0
            ;;
        *)
            echo "Invalid choice, stopping existing services..."
            tmux kill-session -t "$SESSION" 2>/dev/null || true
            pkill -f "ollama serve" 2>/dev/null || true
            sleep 2
            ;;
    esac
else
    echo "✅ No existing services found"
fi

echo ""

# Step 5: Start all services
if [[ "$SERVICES_RUNNING" != "true" ]]; then
    echo "=========================================="
    echo "Step 5: Starting All Services"
    echo "=========================================="
    echo ""
    
    if bash scripts/start_all_services.sh; then
        echo "✅ All services started"
    else
        echo "❌ Service startup had issues"
        echo "   Check logs and tmux session for details"
        echo "   Attach to tmux: tmux attach -t $SESSION"
    fi
else
    echo "=========================================="
    echo "Step 5: Verifying Existing Services"
    echo "=========================================="
    echo ""
    
    if bash scripts/check_all_services_status.sh; then
        echo "✅ All services are running"
    else
        echo "⚠️  Some services may not be running correctly"
        echo "   Check: bash scripts/check_all_services_status.sh"
    fi
fi

echo ""

# Step 6: Final verification
echo "=========================================="
echo "Step 6: Final Verification"
echo "=========================================="
echo ""

echo "Checking service endpoints..."
echo ""

# Check Coordinator API
if curl -s http://localhost:8004/ > /dev/null 2>&1; then
    echo "✅ Coordinator API (port 8004) - Accessible"
else
    echo "❌ Coordinator API (port 8004) - Not accessible"
fi

# Check n8n
if curl -s http://localhost:5678 > /dev/null 2>&1; then
    echo "✅ n8n (port 5678) - Accessible"
else
    echo "❌ n8n (port 5678) - Not accessible"
fi

# Check TTS
if curl -s http://localhost:8001/docs > /dev/null 2>&1; then
    echo "✅ TTS Service (port 8001) - Accessible"
else
    echo "❌ TTS Service (port 8001) - Not accessible"
fi

# Check Frontend
if curl -s http://localhost:8501 > /dev/null 2>&1; then
    echo "✅ Frontend (port 8501) - Accessible"
else
    echo "❌ Frontend (port 8501) - Not accessible"
fi

# Check Ollama
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "✅ Ollama (port 11434) - Accessible"
else
    echo "❌ Ollama (port 11434) - Not accessible"
fi

echo ""

# Step 7: Summary and next steps
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "Services are running. Next steps:"
echo ""
echo "1. On Desktop PowerShell - Start port forwarding:"
echo "   .\connect-vast.ps1"
echo ""
echo "2. On Desktop Browser - Access frontend:"
echo "   http://localhost:8501"
echo ""
echo "3. Test the system:"
echo "   - Select 2 teachers in the sidebar"
echo "   - Click 'Start Session'"
echo "   - Load a website in center panel"
echo "   - Capture section snapshot"
echo ""
echo "Service URLs (on VAST instance):"
echo "  - Coordinator API: http://localhost:8004"
echo "  - n8n UI:          http://localhost:5678"
echo "  - Frontend:        http://localhost:8501"
echo "  - TTS:             http://localhost:8001"
echo "  - Ollama:          http://localhost:11434"
echo ""
echo "To view service logs:"
echo "  tmux attach -t $SESSION"
echo ""
echo "To check service status:"
echo "  bash scripts/check_all_services_status.sh"
echo ""
echo "Troubleshooting:"
echo "  - If services aren't accessible, check port forwarding"
echo "  - If workflows aren't working, check n8n UI: http://localhost:5678"
echo "  - Check logs: tail -f logs/*.log"
echo ""
