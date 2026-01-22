#!/usr/bin/env bash
# Validate all required configuration exists
# Usage: bash scripts/validate_config.sh
# Exit code: 0 if valid, 1 if invalid

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

ERRORS=0
WARNINGS=0

echo "=========================================="
echo "Validating Configuration"
echo "=========================================="
echo ""

# Check if .env exists
if [[ ! -f ".env" ]]; then
    echo "❌ .env file not found"
    echo "   Copy .env.example to .env and fill in your values:"
    echo "   cp .env.example .env"
    echo "   # Then edit .env with your actual values"
    ERRORS=$((ERRORS + 1))
    echo ""
else
    echo "✅ .env file exists"
fi

# Check required variables
echo ""
echo "Checking required variables..."

if [[ -z "${N8N_USER:-}" ]]; then
    echo "❌ N8N_USER not set in .env"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ N8N_USER is set"
fi

if [[ -z "${N8N_PASSWORD:-}" ]]; then
    echo "❌ N8N_PASSWORD not set in .env"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ N8N_PASSWORD is set"
fi

if [[ -z "${N8N_API_KEY:-}" ]]; then
    echo "❌ N8N_API_KEY not set in .env"
    echo ""
    echo "   To create an API key:"
    echo "   1. Ensure port forwarding is active: .\connect-vast.ps1 (Desktop PowerShell)"
    echo "   2. Open http://localhost:5678 in your browser"
    echo "   3. Log in with your N8N_USER and N8N_PASSWORD"
    echo "   4. Go to Settings → API"
    echo "   5. Click 'Create API Key'"
    echo "   6. Copy the API key"
    echo "   7. Add to .env: echo 'N8N_API_KEY=your_key_here' >> .env"
    echo ""
    ERRORS=$((ERRORS + 1))
else
    # Validate API key format
    if [[ "$N8N_API_KEY" =~ ^n8n_[A-Za-z0-9]+$ ]] || \
       [[ "$N8N_API_KEY" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]]; then
        echo "✅ N8N_API_KEY is set and format looks valid"
    else
        echo "⚠️  N8N_API_KEY format may be invalid"
        echo "   Expected: 'n8n_...' or JWT token format"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Check optional but recommended variables
echo ""
echo "Checking optional variables..."

if [[ -z "${VENV_DIR:-}" ]]; then
    echo "⚠️  VENV_DIR not set, will use default: \$HOME/ai-teacher-venv"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✅ VENV_DIR is set: $VENV_DIR"
fi

# Summary
echo ""
echo "=========================================="
if [[ $ERRORS -gt 0 ]]; then
    echo "❌ Configuration validation failed ($ERRORS errors)"
    echo ""
    echo "Fix the errors above and run this script again."
    exit 1
elif [[ $WARNINGS -gt 0 ]]; then
    echo "⚠️  Configuration validated with $WARNINGS warnings"
    echo "   System should work, but consider fixing warnings."
    exit 0
else
    echo "✅ Configuration validated successfully"
    exit 0
fi
