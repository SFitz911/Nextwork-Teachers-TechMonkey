#!/usr/bin/env bash
# Restore n8n workflow from backup or original file
# Usage: bash scripts/restore_workflow.sh [backup_file|latest|original]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Default API key (hardcoded fallback)
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhNDE1ODkzYS1hY2Q2LTQ2NWYtODcyNS02NDQzZTRkNTkyZTkiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MDYxNjMwfQ.faRO3CRuldcSQd0-g9sJORo8tUq_vfMMDpOmXQTPH0I"
N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
N8N_URL="${N8N_URL:-http://localhost:5678}"

WORKFLOW_FILE="$PROJECT_DIR/n8n/workflows/five-teacher-workflow.json"
BACKUP_DIR="$PROJECT_DIR/backups/workflows"

echo "=========================================="
echo "Restore n8n Workflow"
echo "=========================================="
echo ""

# Check if n8n is accessible
if ! curl -s -o /dev/null -w "%{http_code}" "$N8N_URL" | grep -q "200\|404"; then
    echo "❌ n8n is not accessible at $N8N_URL"
    echo "   Make sure n8n is running and port forwarding is active"
    exit 1
fi

RESTORE_SOURCE="${1:-latest}"

# Determine which file to restore from
RESTORE_FILE=""

if [[ "$RESTORE_SOURCE" == "original" ]]; then
    if [[ -f "$WORKFLOW_FILE" ]]; then
        RESTORE_FILE="$WORKFLOW_FILE"
        echo "Using original workflow file: $WORKFLOW_FILE"
    else
        echo "❌ Original workflow file not found: $WORKFLOW_FILE"
        exit 1
    fi
elif [[ "$RESTORE_SOURCE" == "latest" ]]; then
    # Find latest backup
    if [[ -d "$BACKUP_DIR" ]]; then
        LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.json 2>/dev/null | head -1)
        if [[ -n "$LATEST_BACKUP" ]] && [[ -f "$LATEST_BACKUP" ]]; then
            RESTORE_FILE="$LATEST_BACKUP"
            echo "Using latest backup: $LATEST_BACKUP"
        else
            echo "⚠️  No backups found, using original workflow file"
            if [[ -f "$WORKFLOW_FILE" ]]; then
                RESTORE_FILE="$WORKFLOW_FILE"
            else
                echo "❌ No backups and original file not found!"
                exit 1
            fi
        fi
    else
        echo "⚠️  Backup directory not found, using original workflow file"
        if [[ -f "$WORKFLOW_FILE" ]]; then
            RESTORE_FILE="$WORKFLOW_FILE"
        else
            echo "❌ Original workflow file not found!"
            exit 1
        fi
    fi
elif [[ -f "$RESTORE_SOURCE" ]]; then
    RESTORE_FILE="$RESTORE_SOURCE"
    echo "Using specified file: $RESTORE_FILE"
else
    echo "❌ File not found: $RESTORE_SOURCE"
    echo ""
    echo "Available options:"
    echo "  - latest (default) - Use most recent backup"
    echo "  - original - Use original workflow file"
    echo "  - <path> - Use specific backup file"
    echo ""
    echo "Available backups:"
    if [[ -d "$BACKUP_DIR" ]]; then
        ls -lt "$BACKUP_DIR"/*.json 2>/dev/null | head -5 | awk '{print "  - " $9}'
    else
        echo "  (no backups directory)"
    fi
    exit 1
fi

echo ""

# Check if restore file is a backup (contains multiple workflows) or single workflow
if python3 -c "import json, sys; data=json.load(open('$RESTORE_FILE')); print('backup' if isinstance(data, dict) and 'data' in data else 'single')" 2>/dev/null; then
    FILE_TYPE=$(python3 -c "import json, sys; data=json.load(open('$RESTORE_FILE')); print('backup' if isinstance(data, dict) and 'data' in data else 'single')" 2>/dev/null)
else
    FILE_TYPE="single"
fi

if [[ "$FILE_TYPE" == "backup" ]]; then
    echo "Detected backup file (multiple workflows). Extracting Five Teacher workflow..."
    
    # Extract the Five Teacher workflow from backup
    EXTRACTED_WORKFLOW=$(python3 <<EOF
import json, sys
try:
    with open('$RESTORE_FILE', 'r') as f:
        backup_data = json.load(f)
    
    # Backup format: {"data": [workflows...]}
    workflows = backup_data.get('data', [])
    
    # Find Five Teacher workflow
    for wf in workflows:
        if 'Five Teacher' in wf.get('name', ''):
            # Remove ID so n8n creates a new one
            wf.pop('id', None)
            wf.pop('updatedAt', None)
            wf.pop('createdAt', None)
            print(json.dumps(wf))
            sys.exit(0)
    
    print("NOT_FOUND", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
EOF
)
    
    if [[ "$EXTRACTED_WORKFLOW" == *"NOT_FOUND"* ]] || [[ -z "$EXTRACTED_WORKFLOW" ]]; then
        echo "❌ Five Teacher workflow not found in backup file"
        echo "   The backup may not contain the workflow you're looking for"
        exit 1
    fi
    
    # Save extracted workflow to temp file
    TEMP_WORKFLOW="/tmp/restore_workflow_$$.json"
    echo "$EXTRACTED_WORKFLOW" > "$TEMP_WORKFLOW"
    RESTORE_FILE="$TEMP_WORKFLOW"
    echo "✅ Extracted workflow from backup"
    echo ""
fi

# Clean workflow JSON for import (remove n8n-specific fields)
echo "Cleaning workflow JSON for import..."
CLEANED_WORKFLOW=$(python3 <<EOF
import json, sys
try:
    with open('$RESTORE_FILE', 'r') as f:
        workflow = json.load(f)
    
    # Remove fields that n8n doesn't want in import
    fields_to_remove = ['id', 'updatedAt', 'createdAt', 'staticData', 'settings']
    for field in fields_to_remove:
        workflow.pop(field, None)
    
    # Ensure name is set
    if 'name' not in workflow:
        workflow['name'] = 'AI Virtual Classroom - Five Teacher Workflow'
    
    print(json.dumps(workflow))
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
EOF
)

if [[ "$CLEANED_WORKFLOW" == *"ERROR"* ]]; then
    echo "❌ Failed to clean workflow JSON"
    echo "$CLEANED_WORKFLOW"
    exit 1
fi

CLEANED_FILE="/tmp/cleaned_workflow_$$.json"
echo "$CLEANED_WORKFLOW" > "$CLEANED_FILE"
echo "✅ Workflow cleaned"

# Import workflow
echo ""
echo "Importing workflow..."
IMPORT_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    -H "Content-Type: application/json" \
    -d @"$CLEANED_FILE" \
    "${N8N_URL}/api/v1/workflows" 2>/dev/null)

HTTP_CODE=$(echo "$IMPORT_RESPONSE" | tail -1)
IMPORT_BODY=$(echo "$IMPORT_RESPONSE" | head -n -1)

if [[ "$HTTP_CODE" != "200" ]] && [[ "$HTTP_CODE" != "201" ]]; then
    echo "❌ Failed to import workflow (HTTP $HTTP_CODE)"
    echo "Response:"
    echo "$IMPORT_BODY" | head -20
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check API key: bash scripts/validate_config.sh"
    echo "  2. Check n8n is running: curl http://localhost:5678"
    echo "  3. Try manual import: Open http://localhost:5678 → Import workflow"
    rm -f "$CLEANED_FILE" "$TEMP_WORKFLOW" 2>/dev/null
    exit 1
fi

# Get workflow ID
NEW_WORKFLOW_ID=$(echo "$IMPORT_BODY" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    wf_id = data.get('id') or data.get('data', {}).get('id', '')
    if wf_id:
        print(wf_id)
except:
    pass
" 2>/dev/null)

if [[ -z "$NEW_WORKFLOW_ID" ]]; then
    echo "⚠️  Workflow imported but couldn't get ID"
    echo "Response:"
    echo "$IMPORT_BODY" | head -10
else
    echo "✅ Workflow imported successfully (ID: $NEW_WORKFLOW_ID)"
fi

# Activate workflow
echo ""
echo "Activating workflow..."
ACTIVATE_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"active": true}' \
    "${N8N_URL}/api/v1/workflows/${NEW_WORKFLOW_ID}/activate" 2>/dev/null)

ACTIVATE_CODE=$(echo "$ACTIVATE_RESPONSE" | tail -1)

if [[ "$ACTIVATE_CODE" == "200" ]]; then
    echo "✅ Workflow activated!"
else
    echo "⚠️  Could not activate workflow (HTTP $ACTIVATE_CODE)"
    echo "   You may need to activate it manually in n8n UI"
fi

# Cleanup
rm -f "$CLEANED_FILE" "$TEMP_WORKFLOW" 2>/dev/null

echo ""
echo "=========================================="
echo "✅ Workflow Restored!"
echo "=========================================="
echo ""
echo "Workflow is now available in n8n:"
echo "  http://localhost:5678"
echo ""
echo "To verify:"
echo "  1. Open http://localhost:5678 in your browser"
echo "  2. Check that 'AI Virtual Classroom - Five Teacher Workflow' exists"
echo "  3. Verify it's activated (green toggle)"
echo ""
