#!/usr/bin/env bash
# Common error handling functions for all scripts
# Usage: source scripts/lib/error_handling.sh

# Function to print error with help message
error_with_help() {
    local error_msg="$1"
    local help_msg="$2"
    
    echo "❌ $error_msg" >&2
    if [[ -n "$help_msg" ]]; then
        echo "" >&2
        echo "$help_msg" >&2
    fi
    exit 1
}

# Function to check if command exists
check_prerequisite() {
    local cmd="$1"
    local install_cmd="${2:-}"
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        if [[ -n "$install_cmd" ]]; then
            error_with_help \
                "$cmd is not installed" \
                "Install with: $install_cmd"
        else
            error_with_help "$cmd is not installed"
        fi
    fi
}

# Function to check if service is running
check_service_running() {
    local service_name="$1"
    local check_cmd="$2"
    
    if ! eval "$check_cmd" >/dev/null 2>&1; then
        error_with_help \
            "$service_name is not running" \
            "Start it with the appropriate script or check logs"
    fi
}

# Function to validate API response
validate_api_response() {
    local response="$1"
    local expected_status="${2:-200}"
    
    if echo "$response" | grep -q "unauthorized\|401\|403\|not found\|404"; then
        return 1
    fi
    
    if ! echo "$response" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
        return 1
    fi
    
    return 0
}

# Function to provide next steps on error
provide_next_steps() {
    local error_type="$1"
    
    case "$error_type" in
        "api_key_missing")
            echo "Next steps:" >&2
            echo "  1. Run: bash scripts/validate_config.sh" >&2
            echo "  2. Get API key from n8n UI: http://localhost:5678 → Settings → API" >&2
            echo "  3. Add to .env: echo 'N8N_API_KEY=your_key' >> .env" >&2
            ;;
        "workflow_missing")
            echo "Next steps:" >&2
            echo "  1. Run: bash scripts/clean_and_import_workflow.sh" >&2
            echo "  2. Or import manually through n8n UI" >&2
            ;;
        "service_not_running")
            echo "Next steps:" >&2
            echo "  1. Run: bash scripts/start_all_services.sh" >&2
            echo "  2. Or: bash scripts/restart_and_setup.sh" >&2
            ;;
        "config_invalid")
            echo "Next steps:" >&2
            echo "  1. Run: bash scripts/validate_config.sh" >&2
            echo "  2. Fix any errors shown" >&2
            echo "  3. See ENV_EXAMPLE.md for required variables" >&2
            ;;
    esac
}
