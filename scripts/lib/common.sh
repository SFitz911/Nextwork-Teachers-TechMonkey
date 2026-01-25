#!/usr/bin/env bash
# Common functions and configuration loading for all scripts
# Usage: source scripts/lib/common.sh

# Get project directory
if [[ -z "${PROJECT_DIR:-}" ]]; then
    PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    export PROJECT_DIR
fi

# Change to project directory
cd "$PROJECT_DIR" || exit 1

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Set default values (but prefer .env)
export N8N_USER="${N8N_USER:-admin}"
export N8N_PASSWORD="${N8N_PASSWORD:-changeme}"
# Default API key (JWT token) - will be used if not in .env
export N8N_API_KEY="${N8N_API_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI4ZWM2NDU4Yy1hMjg0LTQ4ZTctYmE3OS0yOTNlNmY3MjJlMTYiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MzE3ODA3fQ.iAUgO1sHP11IDOJT38pn3wOwjHXQmVg4_SyrNyaMqbw}"
export N8N_URL="${N8N_URL:-http://localhost:5678}"
export VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"

# Function to validate API key format
validate_api_key_format() {
    local key="$1"
    # n8n API key format: starts with "n8n_" followed by alphanumeric
    if [[ "$key" =~ ^n8n_[A-Za-z0-9]+$ ]]; then
        return 0
    # JWT token format: three base64 parts separated by dots
    elif [[ "$key" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if n8n is accessible
check_n8n_accessible() {
    if curl -s -o /dev/null -w "%{http_code}" "$N8N_URL" | grep -q "200\|404"; then
        return 0
    else
        return 1
    fi
}

# Function to get workflows using API key or basic auth
get_workflows_json() {
    if [[ -n "$N8N_API_KEY" ]]; then
        curl -s \
            -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            -H "Content-Type: application/json" \
            "${N8N_URL}/api/v1/workflows" 2>/dev/null
    else
        curl -s -u "${N8N_USER}:${N8N_PASSWORD}" \
            -H "Content-Type: application/json" \
            "${N8N_URL}/api/v1/workflows" 2>/dev/null
    fi
}
