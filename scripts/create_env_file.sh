#!/usr/bin/env bash
# Create .env file with required values
# Usage: bash scripts/create_env_file.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Creating .env File"
echo "=========================================="
echo ""

# Default API key (hardcoded fallback)
DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI1MzE3fQ.tU1VEaQCrymcz8MIkAWuWfpBJoT9O7R8olTeBe42JJ0"

# Check if .env already exists
if [[ -f ".env" ]]; then
    echo "⚠️  .env file already exists"
    read -p "Overwrite? (y/N): " overwrite
    if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
        echo "Keeping existing .env file"
        exit 0
    fi
    echo "Backing up existing .env to .env.backup"
    cp .env .env.backup
fi

# Create .env file with defaults
cat > .env <<EOF
# n8n Configuration
# These are defaults - update if your n8n uses different credentials
N8N_USER=admin
N8N_PASSWORD=changeme
N8N_API_KEY=${DEFAULT_API_KEY}

# n8n URLs
N8N_URL=http://localhost:5678
N8N_WEBHOOK_URL=http://localhost:5678/webhook/chat-webhook

# Service URLs
TTS_API_URL=http://localhost:8001
ANIMATION_API_URL=http://localhost:8002

# Virtual Environment Path
VENV_DIR=\$HOME/ai-teacher-venv
EOF

echo "✅ .env file created"
echo ""
echo "Current values:"
echo "  N8N_USER=admin"
echo "  N8N_PASSWORD=changeme"
echo "  N8N_API_KEY=<set with hardcoded default>"
echo ""
echo "⚠️  If your n8n dev mode uses different credentials, edit .env:"
echo "   nano .env"
echo ""
echo "Validating configuration..."
bash scripts/validate_config.sh
