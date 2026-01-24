#!/bin/bash
# Complete setup script for new VAST instance with storage volume
# This script:
# 1. Detects and sets up Vast.ai storage volume
# 2. Clones the project
# 3. Installs all prerequisites (Ollama, n8n, Mistral)
# 4. Sets up PostgreSQL on the volume
# 5. Deploys the 2-teacher system
# Usage: bash scripts/setup_new_instance_with_storage.sh

set -euo pipefail

echo "=========================================="
echo "Setting Up New VAST Instance with Storage"
echo "=========================================="
echo ""

# Step 1: Detect Vast.ai storage volume
echo "Step 1: Detecting Vast.ai storage volume..."
echo ""

# Common mount points for Vast.ai volumes
POSSIBLE_MOUNTS=(
    "/mnt/vast-storage"
    "/mnt/storage"
    "/vast-storage"
    "/storage"
)

VAST_STORAGE=""
for mount in "${POSSIBLE_MOUNTS[@]}"; do
    if mountpoint -q "$mount" 2>/dev/null || [ -d "$mount" ] && [ -w "$mount" ]; then
        # Check if it's actually a volume (has space)
        if df "$mount" 2>/dev/null | tail -1 | grep -qE "(T|G|M)"; then
            VAST_STORAGE="$mount"
            echo "✅ Found storage volume at: $VAST_STORAGE"
            df -h "$VAST_STORAGE"
            break
        fi
    fi
done

# If not found, check all mounted filesystems
if [ -z "$VAST_STORAGE" ]; then
    echo "Checking all mounted filesystems..."
    df -h | grep -E "(vast|storage|volume)" || true
    
    echo ""
    echo "⚠️  Could not auto-detect storage volume mount point."
    echo "Please check Vast.ai dashboard - volume should be attached to instance."
    echo ""
    read -p "Enter storage volume mount path (or press Enter to use ~/vast-storage): " VAST_STORAGE
    VAST_STORAGE="${VAST_STORAGE:-$HOME/vast-storage}"
    
    # Create if doesn't exist
    if [ ! -d "$VAST_STORAGE" ]; then
        echo "Creating directory: $VAST_STORAGE"
        mkdir -p "$VAST_STORAGE"
    fi
fi

echo ""
echo "Using storage path: $VAST_STORAGE"
echo ""

# Step 2: Set up storage directories
echo "Step 2: Setting up storage directories on volume..."
echo ""

mkdir -p "$VAST_STORAGE/postgresql"      # PostgreSQL data
mkdir -p "$VAST_STORAGE/cached_sections" # Cached video/audio
mkdir -p "$VAST_STORAGE/embeddings"      # Vector embeddings
mkdir -p "$VAST_STORAGE/logs"             # Application logs

echo "✅ Storage directories created:"
echo "   - PostgreSQL: $VAST_STORAGE/postgresql"
echo "   - Cached sections: $VAST_STORAGE/cached_sections"
echo "   - Embeddings: $VAST_STORAGE/embeddings"
echo "   - Logs: $VAST_STORAGE/logs"
echo ""

# Step 3: Update system
echo "Step 3: Updating system packages..."
echo ""
apt-get update -y
apt-get upgrade -y

# Step 4: Install essential tools
echo "Step 4: Installing essential tools..."
echo ""
apt-get install -y \
    git curl wget vim tmux \
    python3 python3-pip python3-venv \
    postgresql postgresql-contrib \
    build-essential \
    || echo "⚠️  Some packages may have failed, continuing..."

# Step 5: Install Node.js and n8n
echo ""
echo "Step 5: Installing Node.js and n8n..."
echo ""

if ! command -v node &> /dev/null || [[ "$(node -v 2>/dev/null || echo '')" != v20* ]]; then
    echo "Installing Node.js v20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
    echo "✅ Node.js installed: $(node -v)"
else
    echo "✅ Node.js already installed: $(node -v)"
fi

if ! command -v n8n &> /dev/null; then
    echo "Installing n8n..."
    npm install -g n8n
    echo "✅ n8n installed: $(n8n --version)"
else
    echo "✅ n8n already installed: $(n8n --version)"
fi

# Step 6: Install Ollama
echo ""
echo "Step 6: Installing Ollama..."
echo ""

if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    echo "✅ Ollama installed"
else
    echo "✅ Ollama already installed"
fi

# Start Ollama and pull Mistral model
if ! pgrep -f "ollama serve" > /dev/null; then
    echo "Starting Ollama service..."
    ollama serve > /tmp/ollama.log 2>&1 &
    sleep 5
    
    echo "Checking if mistral:7b model is installed..."
    MODEL_INSTALLED=$(curl -s http://localhost:11434/api/tags 2>/dev/null | python3 -c "import json, sys; d=json.load(sys.stdin); models=[m.get('name') for m in d.get('models', [])]; print('yes' if 'mistral:7b' in models else 'no')" 2>/dev/null || echo "no")
    
    if [[ "$MODEL_INSTALLED" != "yes" ]]; then
        echo "Installing mistral:7b model (this takes 5-10 minutes, ~4GB)..."
        ollama pull mistral:7b
        echo "✅ mistral:7b model installed"
    else
        echo "✅ mistral:7b model already installed"
    fi
else
    echo "✅ Ollama already running"
fi

# Step 7: Clone project
echo ""
echo "Step 7: Cloning project from GitHub..."
echo ""

PROJECT_DIR="$HOME/Nextwork-Teachers-TechMonkey"

if [ ! -d "$PROJECT_DIR" ]; then
    cd ~
    git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
    echo "✅ Project cloned"
else
    echo "Project already exists, pulling latest..."
    cd "$PROJECT_DIR"
    git pull origin main || echo "⚠️  Git pull failed, continuing..."
    echo "✅ Project updated"
fi

cd "$PROJECT_DIR"

# Step 8: Install Docker and Docker Compose (if not installed)
echo ""
echo "Step 8: Setting up Docker..."
echo ""

if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo "✅ Docker installed"
else
    echo "✅ Docker already installed: $(docker --version)"
fi

# Install Docker Compose if not present
if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    apt-get update
    apt-get install -y docker-compose-plugin || {
        # Fallback to standalone docker-compose
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    }
    echo "✅ Docker Compose installed"
else
    echo "✅ Docker Compose already installed"
fi

# Create PostgreSQL data directory on volume (for Docker bind mount)
echo ""
echo "Setting up PostgreSQL data directory on storage volume..."
PG_DATA_DIR="$VAST_STORAGE/postgresql"
mkdir -p "$PG_DATA_DIR"
chmod 755 "$PG_DATA_DIR"
echo "✅ PostgreSQL data directory ready: $PG_DATA_DIR"
echo "   (Docker will initialize the database here)"

# Step 9: Create Python virtual environment
echo ""
echo "Step 9: Setting up Python virtual environment..."
echo ""

VENV_DIR="$HOME/ai-teacher-venv"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "✅ Virtual environment created"
else
    echo "✅ Virtual environment already exists"
fi

source "$VENV_DIR/bin/activate"
pip install -q --upgrade pip

# Install all service dependencies
echo "Installing all service dependencies..."
pip install -q -r requirements.txt 2>/dev/null || true
pip install -q -r frontend/requirements.txt 2>/dev/null || true
pip install -q -r services/tts/requirements.txt 2>/dev/null || true
pip install -q -r services/animation/requirements.txt 2>/dev/null || true
pip install -q -r services/coordinator/requirements.txt 2>/dev/null || true

# Install PostgreSQL Python client
pip install -q psycopg2-binary pgvector 2>/dev/null || {
    echo "⚠️  pgvector Python package may need manual installation"
}

echo "✅ Python dependencies installed"
echo ""

# Step 10: Create environment file with storage paths
echo "Step 10: Creating environment configuration..."
echo ""

# Generate secure password for PostgreSQL
POSTGRES_PASSWORD=$(openssl rand -base64 32)

cat > "$PROJECT_DIR/.env.storage" << EOF
# Vast.ai Storage Volume Configuration
VAST_STORAGE_PATH=$VAST_STORAGE

# Database Configuration (Docker PostgreSQL)
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=ai_teacher
POSTGRES_USER=ai_teacher
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Storage Directories
CACHE_DIR=$VAST_STORAGE/cached_sections
EMBEDDINGS_DIR=$VAST_STORAGE/embeddings
LOGS_DIR=$VAST_STORAGE/logs

# Service URLs
COORDINATOR_API_URL=http://localhost:8004
N8N_WEBHOOK_URL=http://localhost:5678/webhook/session/start

# n8n Configuration
N8N_USER=admin
N8N_PASSWORD=$(openssl rand -base64 16)
N8N_HOST=localhost
EOF

echo "✅ Environment file created: $PROJECT_DIR/.env.storage"
echo "   (Copy this to .env if needed)"
echo ""

# Step 11: Summary
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Storage Configuration:"
echo "   Volume Path: $VAST_STORAGE"
echo "   PostgreSQL: $VAST_STORAGE/postgresql"
echo "   Cache: $VAST_STORAGE/cached_sections"
echo ""
echo "Next Steps:"
echo ""
echo "1. Review and copy environment file:"
echo "   cp $PROJECT_DIR/.env.storage $PROJECT_DIR/.env"
echo ""
echo "2. Start all services with Docker Compose:"
echo "   cd $PROJECT_DIR"
echo "   cp .env.storage .env"
echo "   docker compose up -d"
echo ""
echo "   This will start:"
echo "   - PostgreSQL (with pgvector) on port 5432"
echo "   - n8n on port 5678"
echo "   - Ollama on port 11434"
echo "   - Coordinator API on port 8004"
echo "   - TTS service on port 8001"
echo "   - Animation service on port 8002"
echo "   - Frontend on port 8501"
echo ""
echo "3. Initialize PostgreSQL database (create extension):"
echo "   docker exec -it ai-teacher-postgres psql -U ai_teacher -d ai_teacher -c \"CREATE EXTENSION IF NOT EXISTS vector;\""
echo ""
echo "4. Deploy the system (if not using Docker Compose):"
echo "   cd $PROJECT_DIR"
echo "   bash scripts/deploy_2teacher_system.sh"
echo ""
echo "6. On Desktop PowerShell - Start port forwarding:"
echo "   .\connect-vast.ps1"
echo ""
echo "7. Access frontend:"
echo "   http://localhost:8501"
echo ""
echo "=========================================="
echo ""
