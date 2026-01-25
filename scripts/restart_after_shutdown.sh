#!/usr/bin/env bash
# Complete restart script - use after VAST instance shutdown/restart
# This handles everything needed to get back up and running
# Usage: bash scripts/restart_after_shutdown.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Complete System Restart"
echo "=========================================="
echo ""
echo "This will:"
echo "  1. Pull latest code from GitHub"
echo "  2. Start all services"
echo "  3. Re-import n8n workflows"
echo ""

# Step 1: Pull latest code
echo "Step 1: Pulling latest code..."
git pull origin main || echo "⚠️  Git pull failed (may not be connected to internet or repo)"
echo ""

# Step 2: Start all services
echo "Step 2: Starting all services..."
bash scripts/quick_start_all.sh
echo ""

# Step 3: Wait a moment for services to initialize
echo "Step 3: Waiting for services to initialize..."
sleep 10
echo ""

# Step 4: Re-import n8n workflows
echo "Step 4: Re-importing n8n workflows..."
if [[ -f "scripts/force_reimport_workflows.sh" ]]; then
    bash scripts/force_reimport_workflows.sh
else
    echo "⚠️  force_reimport_workflows.sh not found, skipping workflow import"
    echo "   You may need to manually import workflows in n8n UI"
fi
echo ""

echo "=========================================="
echo "✅ Restart Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Set up port forwarding from Desktop: .\connect-vast-simple.ps1"
echo "  2. Access frontend: http://localhost:8501"
echo "  3. Check service status: bash scripts/check_all_services_status.sh"
echo ""
