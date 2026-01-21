#!/bin/bash

# Smart Deployment Script for Vast.ai
# Automatically detects Docker availability and chooses the best deployment method

set -e

echo "=========================================="
echo "AI Virtual Classroom - Smart Deployment"
echo "=========================================="

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Check if we're in the right directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo "❌ Error: docker-compose.yml not found. Are you in the project root?"
    exit 1
fi

# Check for NVIDIA GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo "⚠️  Warning: nvidia-smi not found. GPU features may not work."
else
    echo "✅ NVIDIA GPU detected:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
fi

# Function to check if Docker works
check_docker() {
    if ! command -v docker &> /dev/null; then
        return 1
    fi
    
    # Try to run a simple Docker command
    if docker ps &> /dev/null; then
        # Test if we can actually run containers
        if docker run --rm hello-world &> /dev/null 2>&1; then
            return 0
        fi
    fi
    
    return 1
}

# Function to install Docker
install_docker() {
    echo ""
    echo "=========================================="
    echo "Installing Docker..."
    echo "=========================================="
    
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # Start Docker service
    if command -v systemctl &> /dev/null; then
        sudo systemctl start docker || true
        sudo systemctl enable docker || true
    fi
    
    # Wait a moment for Docker to start
    sleep 3
    
    # Test Docker
    if docker run --rm hello-world &> /dev/null 2>&1; then
        echo "✅ Docker installed and working!"
        return 0
    else
        echo "⚠️  Docker installed but may not be fully functional"
        return 1
    fi
}

# Main deployment logic
echo ""
echo "Checking Docker availability..."

if check_docker; then
    echo "✅ Docker is available and working"
    echo ""
    echo "Deploying with Docker..."
    bash scripts/deploy_vast_ai.sh
    
elif ! command -v docker &> /dev/null; then
    echo "⚠️  Docker not installed. Attempting to install..."
    
    if install_docker && check_docker; then
        echo "✅ Docker installed successfully!"
        echo ""
        echo "Deploying with Docker..."
        bash scripts/deploy_vast_ai.sh
    else
        echo "⚠️  Docker installation failed or Docker doesn't work on this instance"
        echo "Falling back to no-docker deployment..."
        bash scripts/deploy_no_docker.sh
    fi
    
else
    echo "⚠️  Docker is installed but not working (common on restricted Vast.ai instances)"
    echo "Falling back to no-docker deployment..."
    bash scripts/deploy_no_docker.sh
fi

echo ""
echo "=========================================="
echo "✅ Deployment complete!"
echo "=========================================="
