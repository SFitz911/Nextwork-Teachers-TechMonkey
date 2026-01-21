#!/bin/bash

# Quick deployment script - assumes files are already uploaded
# Run this AFTER you've uploaded/cloned the project files

set -e

echo "=========================================="
echo "Quick Deployment - AI Teacher Classroom"
echo "=========================================="

# Navigate to project directory
if [ -f "docker-compose.yml" ]; then
    PROJECT_DIR="$(pwd)"
elif [ -d "$HOME/ai-teacher-classroom" ]; then
    PROJECT_DIR="$HOME/ai-teacher-classroom"
    cd "$PROJECT_DIR"
else
    echo "❌ Error: Project files not found!"
    echo "Please run the full deploy_vast_ai.sh script first, or ensure project files are present."
    exit 1
fi

echo "📍 Project directory: $PROJECT_DIR"

# Verify GPU
echo ""
echo "Checking GPU..."
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
else
    echo "⚠️  Warning: nvidia-smi not found"
fi

# Verify Docker
echo ""
echo "Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please run deploy_vast_ai.sh first."
    exit 1
fi

# Verify NVIDIA Container Toolkit
echo "Checking NVIDIA Container Toolkit..."
if ! docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
    echo "⚠️  Warning: GPU access in Docker not configured"
    echo "   Run: sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker"
fi

# Create directories
echo ""
echo "Creating directories..."
mkdir -p n8n/workflows
mkdir -p services/tts/{models,output}
mkdir -p services/animation/{models,avatars,output}

# Create .env if it doesn't exist
if [ ! -f ".env" ]; then
    echo "Creating .env file..."
    cat > .env << EOF
N8N_USER=admin
N8N_PASSWORD=$(openssl rand -base64 12)
N8N_HOST=localhost
EOF
    echo "✅ .env created - credentials saved!"
fi

# Start services
echo ""
echo "Starting Docker services..."
docker compose up -d

# Wait for services to be ready
echo ""
echo "Waiting for services to start..."
sleep 10

# Check service status
echo ""
echo "Service Status:"
docker compose ps

echo ""
echo "=========================================="
echo "✅ Quick deployment complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Install LLM model:"
echo "   docker exec ai-teacher-ollama ollama pull mistral:7b"
echo ""
echo "2. Access services:"
IP=$(hostname -I | awk '{print $1}')
echo "   n8n: http://$IP:5678"
echo "   Frontend: http://$IP:8501"
echo ""
echo "3. Check logs:"
echo "   docker compose logs -f"
echo ""
echo "4. Run health check:"
echo "   python3 scripts/health_check.py"
echo ""
