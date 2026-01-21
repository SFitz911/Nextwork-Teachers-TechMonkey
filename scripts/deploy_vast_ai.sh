#!/bin/bash

# Vast.ai Deployment Script
# Run this script on your Vast.ai GPU instance to set up the AI Teacher system

set -e

echo "=========================================="
echo "AI Virtual Classroom - Vast.ai Setup"
echo "=========================================="

# Check for NVIDIA GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo "Error: nvidia-smi not found. This script requires a GPU instance."
    exit 1
fi

echo "✅ NVIDIA GPU detected:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # Start Docker service
    if command -v systemctl &> /dev/null; then
        sudo systemctl start docker || true
        sudo systemctl enable docker || true
    fi
    
    # Wait for Docker to be ready
    echo "Waiting for Docker to start..."
    sleep 5
    
    # Test Docker
    if docker run --rm hello-world &> /dev/null 2>&1; then
        echo "✅ Docker installed and working!"
    else
        echo "⚠️  Docker installed but may not be fully functional"
        echo "You may need to restart or check Docker permissions"
    fi
fi

# Install NVIDIA Container Toolkit
echo "Installing NVIDIA Container Toolkit..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker to use NVIDIA runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Verify Docker GPU access
echo "Verifying Docker GPU access..."
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi

# Install Docker Compose if not present
if ! command -v docker compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
fi

# Setup project directory
echo "Setting up project..."
PROJECT_DIR="$HOME/ai-teacher-classroom"

# Check if we're already in the project directory or if it exists
if [ -f "docker-compose.yml" ]; then
    # Already in project directory or files are here
    echo "✅ Project files found in current directory"
    PROJECT_DIR="$(pwd)"
elif [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
    # Project directory exists with files
    echo "✅ Project directory exists at $PROJECT_DIR"
    cd "$PROJECT_DIR"
else
    # Create project directory
    echo "📁 Creating project directory at $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    echo ""
    echo "⚠️  Project files not found!"
    echo "Please do one of the following:"
    echo ""
    echo "Option 1 - Git Clone:"
    echo "  cd ~"
    echo "  git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git ai-teacher-classroom"
    echo "  cd ai-teacher-classroom"
    echo "  bash scripts/deploy_vast_ai.sh"
    echo ""
    echo "Option 2 - Upload via SCP (from your local machine):"
    echo "  scp -P YOUR_PORT -r . root@YOUR_IP:~/ai-teacher-classroom"
    echo ""
    echo "Then re-run this script."
    exit 1
fi

# Create necessary directories
mkdir -p n8n/workflows
mkdir -p services/tts/models
mkdir -p services/tts/output
mkdir -p services/animation/models
mkdir -p services/animation/avatars
mkdir -p services/animation/output

# Set environment variables
cat > .env << EOF
N8N_USER=admin
N8N_PASSWORD=$(openssl rand -base64 12)
N8N_HOST=localhost
EOF

echo "✅ Environment variables set in .env"
echo "   n8n credentials saved to .env (keep this secure!)"

# Download Ollama models (optional - can be done after startup)
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Start services: docker compose up -d"
echo "2. Access n8n: http://$(hostname -I | awk '{print $1}'):5678"
echo "3. Load Ollama model: docker exec ai-teacher-ollama ollama pull mistral:7b"
echo "4. Generate avatars: python scripts/avatar_generation.py"
echo ""
echo "To view logs: docker compose logs -f"
echo "To stop: docker compose down"
echo ""
echo "=========================================="
