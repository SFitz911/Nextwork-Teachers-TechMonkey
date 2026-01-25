#!/usr/bin/env bash
# Update n8n API key in all scripts
# Usage: bash scripts/update_api_key.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

NEW_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI5ODg5NmQwZS00NWFhLTRiNmEtYTkwZi03ZTM0OWY4YjBmZTAiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MzY3MDM4LCJleHAiOjE3NzE5MDkyMDB9.nz4Uao_QXeIlxlC0Mw3rq6nl5MpLyuIL5_WE8YKHBck"

echo "=========================================="
echo "Updating n8n API Key in All Scripts"
echo "=========================================="
echo ""

# Old API keys to replace (multiple variations found)
OLD_KEYS=(
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI4ZWM2NDU4Yy1hMjg0LTQ4ZTctYmE3OS0yOTNlNmY3MjJlMTYiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MzE3ODA3fQ.iAUgO1sHP11IDOJT38pn3wOwjHXQmVg4_SyrNyaMqbw"
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI1MzE3fQ.tU1VEaQCrymcz8MIkAWuWfpBJoT9O7R8olTeBe42JJ0"
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI2NDM0fQ.zY98iCLMf-FyR_6xX6OqNgRA2AY6OYHNeJ2Umt4JCLQ"
)

UPDATED_COUNT=0

# Find all shell scripts in scripts directory
for script in scripts/**/*.sh scripts/*.sh; do
    if [[ -f "$script" ]]; then
        UPDATED=false
        for old_key in "${OLD_KEYS[@]}"; do
            if grep -q "$old_key" "$script" 2>/dev/null; then
                # Use sed to replace the old key with new key
                sed -i "s|$old_key|$NEW_API_KEY|g" "$script"
                UPDATED=true
                UPDATED_COUNT=$((UPDATED_COUNT + 1))
            fi
        done
        if [[ "$UPDATED" == "true" ]]; then
            echo "✅ Updated: $script"
        fi
    fi
done

# Also update .env file if it exists
if [[ -f ".env" ]]; then
    for old_key in "${OLD_KEYS[@]}"; do
        if grep -q "N8N_API_KEY.*$old_key" ".env" 2>/dev/null; then
            sed -i "s|N8N_API_KEY=.*|N8N_API_KEY=$NEW_API_KEY|g" ".env"
            echo "✅ Updated: .env"
            break
        fi
    fi
fi

echo ""
echo "=========================================="
echo "✅ Update Complete!"
echo "=========================================="
echo "Updated $UPDATED_COUNT files"
echo ""
echo "New API key: $NEW_API_KEY"
echo ""
echo "⚠️  Remember to also update .env file on VAST instance:"
echo "   echo 'N8N_API_KEY=$NEW_API_KEY' >> ~/Nextwork-Teachers-TechMonkey/.env"
