#!/usr/bin/env bash
# PERMANENT FIX: Stop n8n, clear its database, restart, and import only 3 workflows
# This is the nuclear option that will permanently fix the duplicate workflow issue
# Usage: bash scripts/permanent_fix_workflows.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Default API key (hardcoded fallback)
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI2NDM0fQ.zY98iCLMf-FyR_6xX6OqNgRA2AY6OYHNeJ2Umt4JCLQ"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="${N8N_URL:-http://localhost:5678}"

echo "=========================================="
echo "PERMANENT FIX: Clear n8n Database and Import Only 3 Workflows"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This will DELETE ALL workflows from n8n's database!"
echo "   Press Ctrl+C within 5 seconds to cancel..."
echo ""
sleep 5

# Step 1: Find n8n data directory
echo "Step 1: Finding n8n data directory..."
N8N_DATA_DIR=""

# Check common locations
POSSIBLE_LOCATIONS=(
    "$HOME/.n8n"
    "/root/.n8n"
    "$HOME/n8n"
    "/root/n8n"
)

for loc in "${POSSIBLE_LOCATIONS[@]}"; do
    if [[ -d "$loc" ]]; then
        # Check if it contains database files
        if find "$loc" -name "*.db" -o -name "*.sqlite*" 2>/dev/null | head -n 1 | read -r; then
            N8N_DATA_DIR="$loc"
            echo "   ✅ Found n8n data directory: $N8N_DATA_DIR"
            break
        fi
    fi
done

if [[ -z "$N8N_DATA_DIR" ]]; then
    echo "   ⚠️  Could not find n8n data directory automatically"
    echo "   Will try to delete via API instead"
    N8N_DATA_DIR=""
fi
echo ""

# Step 2: Stop n8n
echo "Step 2: Stopping n8n..."
if pgrep -f "n8n start" > /dev/null; then
    N8N_PID=$(pgrep -f "n8n start" | head -n 1)
    echo "   Stopping n8n (PID: $N8N_PID)..."
    
    # Try graceful shutdown first
    kill "$N8N_PID" 2>/dev/null || true
    sleep 3
    
    # Force kill if still running
    if pgrep -f "n8n start" > /dev/null; then
        echo "   Force killing n8n..."
        pkill -9 -f "n8n start" || true
        sleep 2
    fi
    
    echo "   ✅ n8n stopped"
else
    echo "   ✅ n8n is not running"
fi
echo ""

# Step 3: Clear n8n database (if we found the data directory)
if [[ -n "$N8N_DATA_DIR" ]]; then
    echo "Step 3: Clearing n8n database..."
    
    # Backup database first
    BACKUP_DIR="$PROJECT_DIR/backups/n8n_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    echo "   Creating backup in: $BACKUP_DIR"
    
    # Find and backup database files
    find "$N8N_DATA_DIR" -name "*.db" -o -name "*.sqlite*" 2>/dev/null | while read -r db_file; do
        if [[ -f "$db_file" ]]; then
            cp "$db_file" "$BACKUP_DIR/" 2>/dev/null && echo "   ✅ Backed up: $(basename "$db_file")" || echo "   ⚠️  Could not backup: $db_file"
        fi
    done
    
    # Delete database files
    echo "   Deleting database files..."
    find "$N8N_DATA_DIR" -name "*.db" -o -name "*.sqlite*" 2>/dev/null | while read -r db_file; do
        if [[ -f "$db_file" ]]; then
            rm -f "$db_file" && echo "   ✅ Deleted: $(basename "$db_file")" || echo "   ⚠️  Could not delete: $db_file"
        fi
    done
    
    # Also delete workflow JSON files if they exist
    echo "   Deleting workflow JSON files..."
    find "$N8N_DATA_DIR" -name "*workflow*.json" 2>/dev/null | while read -r wf_file; do
        if [[ -f "$wf_file" ]]; then
            rm -f "$wf_file" && echo "   ✅ Deleted: $(basename "$wf_file")" || echo "   ⚠️  Could not delete: $wf_file"
        fi
    done
    
    echo "   ✅ Database cleared"
else
    echo "Step 3: Skipping database clear (data directory not found)"
    echo "   Will delete workflows via API after restart"
fi
echo ""

# Step 4: Restart n8n
echo "Step 4: Restarting n8n..."
SESSION="ai-teacher"

# Check if tmux session exists
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "   Restarting n8n in existing tmux session..."
    tmux send-keys -t "$SESSION":n8n C-c 2>/dev/null || true
    sleep 2
    
    # Restart n8n in tmux
    VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"
    if [[ -f ".env" ]]; then
        # shellcheck disable=SC2046
        export $(grep -v '^#' .env | xargs)
    fi
    N8N_USER="${N8N_USER:-admin}"
    N8N_PASSWORD="${N8N_PASSWORD:-changeme}"
    
    tmux send-keys -t "$SESSION":n8n \
        "cd '$PROJECT_DIR' && source '$VENV_DIR/bin/activate' >/dev/null 2>&1 || true && \
         export NODE_ENV=production && \
         export N8N_BASIC_AUTH_ACTIVE=true && \
         export N8N_BASIC_AUTH_USER=\"${N8N_USER}\" && \
         export N8N_BASIC_AUTH_PASSWORD=\"${N8N_PASSWORD}\" && \
         export N8N_HOST=\"${N8N_HOST:-0.0.0.0}\" && \
         export N8N_PORT=5678 && \
         export N8N_PROTOCOL=http && \
         export WEBHOOK_URL=\"http://localhost:5678/\" && \
         n8n start --port 5678 2>&1 | tee logs/n8n.log" C-m
else
    echo "   ⚠️  tmux session not found, starting services..."
    bash scripts/run_no_docker_tmux.sh
fi

echo "   Waiting for n8n to start..."
sleep 10

# Wait for n8n to be ready
MAX_WAIT=60
WAIT_COUNT=0
N8N_READY=false

while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" | grep -q "200\|404"; then
        if curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
           "http://localhost:5678/api/v1/workflows" > /dev/null 2>&1; then
            N8N_READY=true
            break
        fi
    fi
    echo "   Waiting... ($WAIT_COUNT/$MAX_WAIT seconds)"
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

if [[ "$N8N_READY" != "true" ]]; then
    echo "   ❌ n8n did not become ready within $MAX_WAIT seconds"
    echo "   Check logs: tail -50 logs/n8n.log"
    exit 1
fi

echo "   ✅ n8n is ready"
echo ""

# Step 5: Delete any remaining workflows via API
echo "Step 5: Deleting any remaining workflows via API..."
WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')

WORKFLOW_COUNT=$(echo "$WORKFLOWS_JSON" | python3 -c "import json, sys; data=json.load(sys.stdin); print(len(data.get('data', [])))" 2>/dev/null || echo "0")

if [[ "$WORKFLOW_COUNT" -gt 0 ]]; then
    echo "   Found $WORKFLOW_COUNT workflow(s) - deleting..."
    
    ALL_WORKFLOW_IDS=$(echo "$WORKFLOWS_JSON" | python3 <<'PYEOF'
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        wf_id = wf.get('id', '')
        if wf_id:
            print(wf_id)
except:
    pass
PYEOF
)
    
    for wf_id in $ALL_WORKFLOW_IDS; do
        if [[ -n "$wf_id" ]]; then
            curl -s -X POST \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${wf_id}/deactivate" > /dev/null 2>&1 || true
            
            curl -s -X DELETE \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                "${N8N_URL}/api/v1/workflows/${wf_id}" > /dev/null 2>&1 || true
        fi
    done
    
    sleep 3
    echo "   ✅ Deleted remaining workflows"
else
    echo "   ✅ No workflows found (database was cleared)"
fi
echo ""

# Step 6: Import only the 3 correct workflows
echo "Step 6: Importing only the 3 correct workflows..."
export FORCE_IMPORT=true
bash scripts/import_new_workflows.sh

echo ""
echo "=========================================="
echo "✅ PERMANENT FIX COMPLETE!"
echo "=========================================="
echo ""
echo "You should now have exactly 3 workflows:"
echo "  1. Session Start - Fast Webhook"
echo "  2. Left Worker - Teacher Pipeline"
echo "  3. Right Worker - Teacher Pipeline"
echo ""
echo "Verify in n8n UI: http://localhost:5678"
echo ""
echo "Database backup saved to: $BACKUP_DIR"
echo ""
