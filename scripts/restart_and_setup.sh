#!/usr/bin/env bash
# Complete restart script: Start all services, import workflow, verify everything works
# Usage: bash scripts/restart_and_setup.sh
#
# This script:
# 1. Checks if services are running, starts them if not
# 2. Waits for n8n to be fully ready
# 3. Imports and activates the workflow
# 4. Verifies everything is working
#
# Run this after a VAST instance restart to get everything back up and running.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Default API key (hardcoded fallback) - use if not in .env
if [[ -z "${N8N_API_KEY:-}" ]]; then
    export N8N_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmNzRkZjc2OC0wZTVhLTQ2OGQtODFiYS1iYTZiMGFiNjAwY2EiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MTQzMDY3fQ.JQU3yyBofIJBX-50Zjdc9GnW7xLMf1QcZrVlgJ-OdbA"
fi

VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"
SESSION="ai-teacher"

echo "=========================================="
echo "Complete Restart and Setup"
echo "=========================================="
echo ""

# Step 1: Check if services are running
echo "Step 1: Checking service status..."
bash scripts/check_all_services_status.sh

echo ""
echo "Step 2: Starting services if needed..."

# Use unified service startup script
if ! tmux has-session -t "$SESSION" 2>/dev/null || ! pgrep -f "ollama serve" > /dev/null; then
    echo "Starting all services..."
    bash scripts/start_all_services.sh
else
    echo "✅ Services already running"
fi

echo ""
echo "Step 3: Validating configuration..."

# Validate configuration before proceeding
if ! bash scripts/validate_config.sh; then
    echo ""
    echo "❌ Configuration validation failed"
    echo "   Fix configuration issues and run this script again"
    exit 1
fi

# n8n should already be ready from start_all_services.sh, but verify
if ! curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" | grep -q "200\|404"; then
    echo "❌ n8n is not accessible"
    echo "   Check logs: tail -50 logs/n8n.log"
    exit 1
fi

echo "✅ n8n is ready"
echo ""

# Step 4: Import and activate workflow
echo "Step 4: Importing and activating workflow..."

if bash scripts/clean_and_import_workflow.sh; then
    echo "✅ Workflow imported and activated"
else
    echo "❌ Failed to import workflow"
    echo ""
    echo "   Troubleshooting steps:"
    echo "   1. Verify API key is valid: bash scripts/validate_config.sh"
    echo "   2. Check n8n is accessible: curl http://localhost:5678"
    echo "   3. Try manual import: Open http://localhost:5678 → Import workflow"
    echo "   4. Check backup: ls -lt backups/workflows/"
    exit 1
fi

echo ""
echo "Step 5: Verifying everything works..."

# Check services again
echo ""
echo "Service Status:"
bash scripts/check_all_services_status.sh

# Test webhook
echo ""
echo "Testing webhook..."
WEBHOOK_TEST=$(curl -s -X POST "http://localhost:5678/webhook/chat-webhook" \
    -H "Content-Type: application/json" \
    -d '{"message": "test", "timestamp": 1234567890}' \
    -w "\nHTTP_CODE:%{http_code}")

HTTP_CODE=$(echo "$WEBHOOK_TEST" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$WEBHOOK_TEST" | grep -v "HTTP_CODE:")

if [[ "$HTTP_CODE" == "200" ]]; then
    if [[ -n "$BODY" ]]; then
        echo "✅ Webhook is working!"
    else
        echo "⚠️  Webhook responded but returned empty body"
        echo "   This might be normal if the workflow is still processing"
    fi
else
    echo "⚠️  Webhook test returned HTTP $HTTP_CODE"
    echo "   Check workflow activation in n8n UI"
fi

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""

# Check if we're on VAST instance
if [[ -n "${SSH_CONNECTION:-}" ]] || hostname | grep -q "vast\|C\."; then
    echo "📍 You are on the VAST instance."
    echo ""
    echo "⚠️  IMPORTANT: To access services from your Desktop browser,"
    echo "   you MUST set up SSH port forwarding!"
    echo ""
    echo "On your Desktop PowerShell Terminal, run:"
    echo "   .\connect-vast.ps1"
    echo ""
    echo "Keep that SSH window open, then access:"
    echo "  - n8n:       http://localhost:5678"
    echo "  - frontend:  http://localhost:8501"
    echo "  - TTS:       http://localhost:8001"
    echo "  - animation: http://localhost:8002"
    echo ""
    echo "Without port forwarding, localhost URLs won't work from Desktop!"
    echo ""
else
    echo "Services should be available at:"
    echo "  n8n:       http://localhost:5678"
    echo "  frontend:  http://localhost:8501"
    echo "  TTS:       http://localhost:8001"
    echo "  animation: http://localhost:8002"
    echo ""
    echo "⚠️  If these don't work, check port forwarding:"
    echo "   .\scripts\check_port_forwarding.ps1"
    echo ""
fi
echo ""
