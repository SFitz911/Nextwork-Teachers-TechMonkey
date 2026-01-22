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
    # Test API key by making actual API call
    echo "   Testing API key..."
    TEST_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "http://localhost:5678/api/v1/workflows" 2>/dev/null || echo "000")
    
    if [[ "$TEST_RESPONSE" == "200" ]]; then
        echo "✅ N8N_API_KEY is set and working"
    elif [[ "$TEST_RESPONSE" == "401" ]] || [[ "$TEST_RESPONSE" == "403" ]]; then
        echo "❌ N8N_API_KEY is invalid or expired (HTTP $TEST_RESPONSE)"
        echo ""
        echo "   The API key in .env is not working. To fix:"
        echo "   1. Ensure port forwarding is active: .\connect-vast.ps1 (Desktop PowerShell)"
        echo "   2. Open http://localhost:5678 in your browser"
        echo "   3. Log in with your N8N_USER and N8N_PASSWORD"
        echo "   4. Go to Settings → API"
        echo "   5. Create a NEW API key"
        echo "   6. Update .env:"
        echo "      sed -i 's/^N8N_API_KEY=.*/N8N_API_KEY=your_new_key_here/' .env"
        echo "      # Or manually edit .env and replace the old key"
        echo ""
        ERRORS=$((ERRORS + 1))
    elif [[ "$TEST_RESPONSE" == "000" ]] || [[ "$TEST_RESPONSE" == "" ]]; then
        echo "⚠️  Could not test API key (n8n may not be running)"
        echo "   API key is set, but cannot verify it works"
        echo "   Format looks OK, but test it after starting services"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "⚠️  API key test returned HTTP $TEST_RESPONSE"
        echo "   API key is set, but may not be working correctly"
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
