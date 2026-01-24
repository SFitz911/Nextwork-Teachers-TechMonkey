#!/usr/bin/env bash
# Find where n8n stores its data and workflows
# Usage: bash scripts/find_n8n_data_location.sh

set -euo pipefail

echo "=========================================="
echo "Finding n8n Data Storage Location"
echo "=========================================="
echo ""

# Check if n8n is running
if pgrep -f "n8n start" > /dev/null; then
    N8N_PID=$(pgrep -f "n8n start" | head -n 1)
    echo "✅ n8n is running (PID: $N8N_PID)"
    echo ""
    
    # Get n8n process environment variables
    echo "Step 1: Checking n8n environment variables..."
    if [[ -f "/proc/$N8N_PID/environ" ]]; then
        ENV_VARS=$(cat /proc/$N8N_PID/environ 2>/dev/null | tr '\0' '\n' | grep -iE "N8N|DATA|HOME|USER" || echo "")
        echo "$ENV_VARS" | while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                echo "   $line"
            fi
        done
    fi
    echo ""
    
    # Check common n8n data locations
    echo "Step 2: Checking common n8n data locations..."
    
    POSSIBLE_LOCATIONS=(
        "$HOME/.n8n"
        "/root/.n8n"
        "$HOME/n8n"
        "/root/n8n"
        "/var/lib/n8n"
        "/opt/n8n"
        "$(pwd)/.n8n"
        "$(pwd)/n8n"
    )
    
    for loc in "${POSSIBLE_LOCATIONS[@]}"; do
        if [[ -d "$loc" ]]; then
            echo "   ✅ Found: $loc"
            echo "      Contents:"
            ls -la "$loc" 2>/dev/null | head -n 10 | sed 's/^/         /' || echo "         (cannot list)"
            
            # Check for database files
            if find "$loc" -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" 2>/dev/null | head -n 5 | while read -r db_file; do
                echo "      📁 Database file: $db_file"
                echo "         Size: $(du -h "$db_file" 2>/dev/null | cut -f1)"
            done; then
                true
            fi
            
            # Check for workflow files
            if find "$loc" -name "*.json" -path "*/workflow*" 2>/dev/null | head -n 10 | while read -r wf_file; do
                echo "      📄 Workflow file: $wf_file"
            done; then
                true
            fi
            echo ""
        fi
    done
    
    # Check n8n config
    echo "Step 3: Checking n8n configuration..."
    if command -v n8n > /dev/null 2>&1; then
        N8N_CONFIG=$(n8n --help 2>&1 | grep -i "data\|config" || echo "")
        if [[ -n "$N8N_CONFIG" ]]; then
            echo "   $N8N_CONFIG"
        fi
    fi
    echo ""
    
    # Check for SQLite database
    echo "Step 4: Searching for n8n database files..."
    find /root /home -name "*.db" -o -name "*.sqlite*" 2>/dev/null | grep -i n8n | head -n 5 | while read -r db; do
        echo "   📁 Found: $db"
        echo "      Size: $(du -h "$db" 2>/dev/null | cut -f1)"
    done
    echo ""
    
else
    echo "❌ n8n is not running"
    echo "   Start n8n first to check its data location"
fi

echo "=========================================="
echo "✅ Data location check complete"
echo "=========================================="
echo ""
