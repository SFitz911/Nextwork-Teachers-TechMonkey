#!/bin/bash
# ==========================================
# AI Teacher Classroom - One-Click Master Setup
# ==========================================
# This script installs EVERYTHING needed to run the AI Teacher system:
# - Ollama + Mistral:7b model
# - n8n workflow automation
# - Python dependencies
# - LongCat-Video + Hugging Face models (~40GB)
# - All services and configurations
#
# Usage: bash master_setup-01.sh
# Time: ~60-100 minutes (mostly model downloads)
# Disk Space: ~60GB required
# ==========================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR" && pwd)"
cd "$PROJECT_DIR"

# Log file
LOG_FILE="$PROJECT_DIR/logs/master_setup.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to print section header
print_section() {
    echo ""
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo ""
    log "=== $1 ==="
}

# Function to print step
print_step() {
    echo -e "${BLUE}▶ $1${NC}"
    log "STEP: $1"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    log "SUCCESS: $1"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log "WARNING: $1"
}

# Function to print error
print_error() {
    echo -e "${RED}❌ $1${NC}"
    log "ERROR: $1"
}

# Function to check disk space
check_disk_space() {
    local required_gb=60
    local available_gb=$(df -BG "$PROJECT_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
    
    if [[ $available_gb -lt $required_gb ]]; then
        print_error "Insufficient disk space!"
        echo "  Required: ${required_gb}GB"
        echo "  Available: ${available_gb}GB"
        echo ""
        echo "Please free up space or use a larger instance."
        exit 1
    else
        print_success "Disk space check passed (${available_gb}GB available)"
    fi
}

# Function to check internet connection
check_internet() {
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        print_success "Internet connection verified"
    else
        print_error "No internet connection!"
        echo "  This setup requires internet to download models and dependencies."
        exit 1
    fi
}

# Main setup function
main() {
    print_section "AI Teacher Classroom - One-Click Master Setup"
    
    echo -e "${YELLOW}This will install:${NC}"
    echo "  ✅ Ollama + Mistral:7b model (~4GB, 5-10 min)"
    echo "  ✅ n8n workflow automation (~100MB, 1-2 min)"
    echo "  ✅ Python dependencies (~10GB, 15-30 min)"
    echo "  ✅ LongCat-Video code (~100MB, 1-2 min)"
    echo "  ✅ LongCat-Video dependencies (~10GB, 15-30 min)"
    echo "  ✅ Hugging Face models (~40GB, 30-60 min) ← BIGGEST DOWNLOAD"
    echo ""
    echo -e "${YELLOW}Total time: ~60-100 minutes${NC}"
    echo -e "${YELLOW}Total disk space: ~60GB${NC}"
    echo ""
    
    read -p "Continue with setup? (y/N): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    # Pre-flight checks
    print_section "Pre-Flight Checks"
    check_disk_space
    check_internet
    
    # Verify we're in the right directory
    if [[ ! -f "frontend/app.py" || ! -d "services" || ! -d "scripts" ]]; then
        print_error "This doesn't look like the project root!"
        echo "  Expected files: frontend/app.py, services/, scripts/"
        echo "  Current directory: $PROJECT_DIR"
        exit 1
    fi
    print_success "Project structure verified"
    
    # Check if LongCat-Video needs to be cloned
    if [[ ! -d "LongCat-Video" ]]; then
        print_step "LongCat-Video repository not found"
        read -p "Clone LongCat-Video repository now? (y/N): " clone_confirm
        if [[ $clone_confirm == "y" || $clone_confirm == "Y" ]]; then
            print_step "Cloning LongCat-Video repository..."
            git clone --single-branch --branch main https://github.com/meituan-longcat/LongCat-Video || {
                print_error "Failed to clone LongCat-Video repository"
                exit 1
            }
            print_success "LongCat-Video repository cloned"
        else
            print_warning "LongCat-Video will be cloned by deploy_longcat_video.sh"
        fi
    else
        print_success "LongCat-Video repository found"
    fi
    
    # Step 1: Deploy base system (Ollama, n8n, Python deps)
    print_section "Step 1: Installing Base System"
    print_step "This installs: Ollama, n8n, Python dependencies"
    print_step "Estimated time: 15-20 minutes"
    echo ""
    
    if [[ -f "scripts/deploy_no_docker.sh" ]]; then
        if bash scripts/deploy_no_docker.sh 2>&1 | tee -a "$LOG_FILE"; then
            print_success "Base system installation complete!"
        else
            print_error "Base system installation failed!"
            echo "  Check logs: $LOG_FILE"
            exit 1
        fi
    else
        print_error "scripts/deploy_no_docker.sh not found!"
        exit 1
    fi
    
    # Step 2: Deploy LongCat-Video (models, dependencies)
    print_section "Step 2: Installing LongCat-Video"
    print_step "This installs: LongCat-Video + Hugging Face models (~40GB)"
    print_step "Estimated time: 45-75 minutes (mostly model download)"
    echo ""
    print_warning "This is the longest step - models are ~40GB"
    echo ""
    
    if [[ -f "scripts/deploy_longcat_video.sh" ]]; then
        if bash scripts/deploy_longcat_video.sh 2>&1 | tee -a "$LOG_FILE"; then
            print_success "LongCat-Video installation complete!"
        else
            print_error "LongCat-Video installation failed!"
            echo "  Check logs: $LOG_FILE"
            echo "  You can retry this step later with: bash scripts/deploy_longcat_video.sh"
            exit 1
        fi
    else
        print_error "scripts/deploy_longcat_video.sh not found!"
        exit 1
    fi
    
    # Step 3: Start all services
    print_section "Step 3: Starting All Services"
    print_step "Starting Ollama, n8n, Coordinator, TTS, LongCat-Video, Frontend"
    print_step "Estimated time: 2-3 minutes"
    echo ""
    
    if [[ -f "scripts/quick_start_all.sh" ]]; then
        if bash scripts/quick_start_all.sh 2>&1 | tee -a "$LOG_FILE"; then
            print_success "All services started!"
        else
            print_error "Service startup had issues!"
            echo "  Check logs: $LOG_FILE"
            echo "  You can manually start services with: bash scripts/quick_start_all.sh"
        fi
    else
        print_error "scripts/quick_start_all.sh not found!"
        exit 1
    fi
    
    # Step 4: Import n8n workflows
    print_section "Step 4: Importing n8n Workflows"
    print_step "Importing and activating n8n workflows"
    print_step "Estimated time: 30 seconds"
    echo ""
    
    if [[ -f "scripts/force_reimport_workflows.sh" ]]; then
        if bash scripts/force_reimport_workflows.sh 2>&1 | tee -a "$LOG_FILE"; then
            print_success "n8n workflows imported and activated!"
        else
            print_warning "Workflow import had issues"
            echo "  You can manually import workflows with: bash scripts/force_reimport_workflows.sh"
        fi
    else
        print_warning "scripts/force_reimport_workflows.sh not found - skipping workflow import"
    fi
    
    # Final verification
    print_section "Final Verification"
    
    print_step "Checking service status..."
    sleep 5  # Give services time to start
    
    if [[ -f "scripts/check_all_services_status.sh" ]]; then
        bash scripts/check_all_services_status.sh || print_warning "Some services may need attention"
    fi
    
    # Summary
    print_section "Setup Complete!"
    
    echo -e "${GREEN}✅ AI Teacher Classroom setup is complete!${NC}"
    echo ""
    echo "Service URLs (with port forwarding):"
    echo "  - Frontend:      http://localhost:8501"
    echo "  - n8n:           http://localhost:5678"
    echo "  - Coordinator:    http://localhost:8004"
    echo "  - TTS:           http://localhost:8001"
    echo "  - LongCat-Video: http://localhost:8003"
    echo "  - Ollama:        http://localhost:11434"
    echo ""
    echo "Next steps:"
    echo "  1. Set up port forwarding from Desktop:"
    echo "     .\connect-vast-simple.ps1"
    echo ""
    echo "  2. Access the frontend:"
    echo "     http://localhost:8501"
    echo ""
    echo "  3. View service logs:"
    echo "     tmux attach -t ai-teacher"
    echo ""
    echo "  4. Check service status:"
    echo "     bash scripts/check_all_services_status.sh"
    echo ""
    echo "Setup log saved to: $LOG_FILE"
    echo ""
    
    log "=== Setup Complete ==="
}

# Run main function
main "$@"
