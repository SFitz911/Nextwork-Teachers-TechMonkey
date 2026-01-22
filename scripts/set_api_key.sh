#!/usr/bin/env bash
# Script to set n8n API key in .env file
# Usage: bash scripts/set_api_key.sh [api_key]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

API_KEY="${1:-}"

if [[ -z "$API_KEY" ]]; then
    echo "Usage: bash scripts/set_api_key.sh <api_key>"
    exit 1
fi

# Create .env if it doesn't exist
if [[ ! -f ".env" ]]; then
    touch .env
fi

# Remove existing N8N_API_KEY line if present
sed -i '/^N8N_API_KEY=/d' .env 2>/dev/null || sed -i.bak '/^N8N_API_KEY=/d' .env

# Add the API key
echo "N8N_API_KEY=$API_KEY" >> .env

echo "✅ API key added to .env file"
echo ""
echo "You can now run: bash scripts/import_and_activate_workflow.sh"
