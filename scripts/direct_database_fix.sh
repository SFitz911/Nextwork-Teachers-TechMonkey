#!/usr/bin/env bash
# DIRECT FIX: Find n8n database, stop n8n, delete database, restart, import 3 workflows
# Usage: bash scripts/direct_database_fix.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI2NDM0fQ.zY98iCLMf-FyR_6xX6OqNgRA2AY6OYHNeJ2Umt4JCLQ"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="${N8N_URL:-http://localhost:5678}"

echo "=========================================="
echo "DIRECT DATABASE FIX: Clear n8n Database"
echo "=========================================="
echo ""

# Step 1: Find n8n process and data directory
echo "Step 1: Finding n8n process and data directory..."
N8N_PID=""
N8N_DATA_DIR=""

if pgrep -f "n8n start" > /dev/null; then
    N8N_PID=$(pgrep -f "n8n start" | head -n 1)
    echo "   ✅ Found n8n process (PID: $N8N_PID)"
    
    # Get the user running n8n
    N8N_USER=$(ps -o user= -p "$N8N_PID" 2>/dev/null | tr -d ' ' || echo "root")
    echo "   Running as user: $N8N_USER"
    
    # Check environment variables from process
    if [[ -f "/proc/$N8N_PID/environ" ]]; then
        N8N_HOME=$(cat /proc/$N8N_PID/environ 2>/dev/null | tr '\0' '\n' | grep "^HOME=" | cut -d= -f2 || echo "")
        if [[ -z "$N8N_HOME" ]]; then
            N8N_HOME="/root"
        fi
        echo "   Home directory: $N8N_HOME"
        
        # Check common n8n data locations
        POSSIBLE_DIRS=(
            "$N8N_HOME/.n8n"
            "/root/.n8n"
            "$HOME/.n8n"
            "/home/$N8N_USER/.n8n"
        )
        
        for dir in "${POSSIBLE_DIRS[@]}"; do
            if [[ -d "$dir" ]]; then
                # Check if it has database files
                DB_FILES=$(find "$dir" -name "*.db" -o -name "*.sqlite*" 2>/dev/null | head -n 1)
                if [[ -n "$DB_FILES" ]]; then
                    N8N_DATA_DIR="$dir"
                    echo "   ✅ Found n8n data directory: $N8N_DATA_DIR"
                    break
                fi
            fi
        done
    fi
else
    echo "   ⚠️  n8n is not running"
    # Try to find data directory anyway
    POSSIBLE_DIRS=(
        "$HOME/.n8n"
        "/root/.n8n"
    )
    
    for dir in "${POSSIBLE_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            DB_FILES=$(find "$dir" -name "*.db" -o -name "*.sqlite*" 2>/dev/null | head -n 1)
            if [[ -n "$DB_FILES" ]]; then
                N8N_DATA_DIR="$dir"
                echo "   ✅ Found n8n data directory: $N8N_DATA_DIR"
                break
            fi
        fi
    done
fi

if [[ -z "$N8N_DATA_DIR" ]]; then
    echo "   ❌ Could not find n8n data directory"
    echo "   Searching entire system..."
    
    # Search for n8n database files
    DB_FILES=$(find /root /home -name "database.sqlite" -o -name "*.db" 2>/dev/null | grep -i n8n | head -n 5 || echo "")
    
    if [[ -n "$DB_FILES" ]]; then
        FIRST_DB=$(echo "$DB_FILES" | head -n 1)
        N8N_DATA_DIR=$(dirname "$FIRST_DB")
        echo "   ✅ Found database at: $FIRST_DB"
        echo "   Data directory: $N8N_DATA_DIR"
    else
        echo "   ❌ Could not find n8n database files"
        echo "   Will try API deletion only"
    fi
fi
echo ""

# Step 2: Stop n8n
echo "Step 2: Stopping n8n..."
if [[ -n "$N8N_PID" ]]; then
    echo "   Stopping n8n (PID: $N8N_PID)..."
    kill "$N8N_PID" 2>/dev/null || true
    sleep 3
    
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

# Step 3: Delete database files
if [[ -n "$N8N_DATA_DIR" ]] && [[ -d "$N8N_DATA_DIR" ]]; then
    echo "Step 3: Deleting n8n database files..."
    
    # Backup first
    BACKUP_DIR="$PROJECT_DIR/backups/n8n_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    echo "   Creating backup in: $BACKUP_DIR"
    
    # Find and backup all database files
    find "$N8N_DATA_DIR" -type f \( -name "*.db" -o -name "*.sqlite*" \) 2>/dev/null | while read -r db_file; do
        if [[ -f "$db_file" ]]; then
            cp "$db_file" "$BACKUP_DIR/" 2>/dev/null && echo "   ✅ Backed up: $(basename "$db_file")" || echo "   ⚠️  Could not backup: $db_file"
        fi
    done
    
    # Delete all database files
    echo "   Deleting database files..."
    DELETED_COUNT=0
    find "$N8N_DATA_DIR" -type f \( -name "*.db" -o -name "*.sqlite*" \) 2>/dev/null | while read -r db_file; do
        if [[ -f "$db_file" ]]; then
            rm -f "$db_file" && echo "   ✅ Deleted: $(basename "$db_file")" && DELETED_COUNT=$((DELETED_COUNT + 1)) || echo "   ⚠️  Could not delete: $db_file"
        fi
    done
    
    # Also delete workflow JSON files
    echo "   Deleting workflow JSON files..."
    find "$N8N_DATA_DIR" -type f -name "*workflow*.json" 2>/dev/null | while read -r wf_file; do
        if [[ -f "$wf_file" ]]; then
            rm -f "$wf_file" && echo "   ✅ Deleted: $(basename "$wf_file")" || true
        fi
    done
    
    echo "   ✅ Database cleared"
else
    echo "Step 3: Skipping database deletion (data directory not found)"
    echo "   Will delete workflows via API after restart"
fi
echo ""

# Step 4: Restart n8n
echo "Step 4: Restarting n8n..."
SESSION="ai-teacher"
VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"

if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "   Restarting n8n in tmux session..."
    
    # Load environment
    if [[ -f ".env" ]]; then
        # shellcheck disable=SC2046
        export $(grep -v '^#' .env | xargs)
    fi
    N8N_USER="${N8N_USER:-admin}"
    N8N_PASSWORD="${N8N_PASSWORD:-changeme}"
    
    # Kill existing n8n in tmux
    tmux send-keys -t "$SESSION":n8n C-c 2>/dev/null || true
    sleep 2
    
    # Start n8n
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
    echo "   Starting services in new tmux session..."
    bash scripts/run_no_docker_tmux.sh
fi

echo "   Waiting for n8n to start..."
sleep 15

# Wait for n8n to be ready
MAX_WAIT=90
WAIT_COUNT=0
N8N_READY=false

echo "   Checking if n8n is ready..."
while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" 2>/dev/null | grep -q "200\|404"; then
        # Try API call
        API_TEST=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
           "http://localhost:5678/api/v1/workflows" 2>/dev/null || echo "")
        
        if [[ -n "$API_TEST" ]] && ! echo "$API_TEST" | grep -q "unauthorized\|401\|403"; then
            N8N_READY=true
            break
        fi
    fi
    if [[ $((WAIT_COUNT % 10)) -eq 0 ]]; then
        echo "   Still waiting... ($WAIT_COUNT/$MAX_WAIT seconds)"
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

if [[ "$N8N_READY" != "true" ]]; then
    echo "   ❌ n8n did not become ready within $MAX_WAIT seconds"
    echo "   Check logs: tail -50 logs/n8n.log"
    echo "   Or check tmux: tmux attach -t $SESSION"
    exit 1
fi

echo "   ✅ n8n is ready"
echo ""

# Step 5: Verify no workflows exist, then import
echo "Step 5: Checking workflows and importing..."
WORKFLOWS_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')

WORKFLOW_COUNT=$(echo "$WORKFLOWS_JSON" | python3 -c "import json, sys; data=json.load(sys.stdin); print(len(data.get('data', [])))" 2>/dev/null || echo "0")

echo "   Found $WORKFLOW_COUNT workflow(s)"

if [[ "$WORKFLOW_COUNT" -gt 0 ]]; then
    echo "   ⚠️  Workflows still exist - deleting via API..."
    
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
    
    sleep 5
    
    # Verify deletion
    VERIFY_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')
    
    VERIFY_COUNT=$(echo "$VERIFY_JSON" | python3 -c "import json, sys; data=json.load(sys.stdin); print(len(data.get('data', [])))" 2>/dev/null || echo "0")
    
    if [[ "$VERIFY_COUNT" -gt 0 ]]; then
        echo "   ⚠️  $VERIFY_COUNT workflow(s) still remain after API deletion"
        echo "   This suggests the database was not fully cleared"
    else
        echo "   ✅ All workflows deleted via API"
    fi
else
    echo "   ✅ No workflows found (database was cleared)"
fi
echo ""

# Step 6: Import only 3 workflows
echo "Step 6: Importing only 3 correct workflows..."
export FORCE_IMPORT=true
bash scripts/import_new_workflows.sh

echo ""
echo "=========================================="
echo "✅ DIRECT FIX COMPLETE!"
echo "=========================================="
echo ""
echo "Final workflow count check..."
FINAL_JSON=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null || echo '{"data":[]}')

FINAL_COUNT=$(echo "$FINAL_JSON" | python3 -c "import json, sys; data=json.load(sys.stdin); print(len(data.get('data', [])))" 2>/dev/null || echo "0")

echo "   Total workflows: $FINAL_COUNT"
if [[ "$FINAL_COUNT" -eq 3 ]]; then
    echo "   ✅ SUCCESS: Exactly 3 workflows!"
else
    echo "   ⚠️  Expected 3, but found $FINAL_COUNT"
    echo ""
    echo "   Workflows:"
    echo "$FINAL_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for wf in data.get('data', []):
    print(f\"     - {wf.get('name', 'Unknown')}\")
" 2>/dev/null
fi
echo ""
echo "Verify in n8n UI: http://localhost:5678"
if [[ -n "$BACKUP_DIR" ]]; then
    echo "Database backup: $BACKUP_DIR"
fi
echo ""
