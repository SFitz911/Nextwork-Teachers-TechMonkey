#!/bin/bash
# Quick fix - handles git conflicts and sets up Docker

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$HOME/Nextwork-Teachers-TechMonkey}"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Quick Fix: Storage and Docker Setup"
echo "=========================================="
echo ""

# Handle git conflicts
echo "Step 1: Resolving git conflicts..."
if [ -n "$(git status --porcelain scripts/setup_new_instance_with_storage.sh 2>/dev/null)" ]; then
    echo "Stashing local changes to setup script..."
    git stash push -m "Local setup script changes" scripts/setup_new_instance_with_storage.sh || true
fi

# Pull latest
echo "Pulling latest changes..."
git pull origin main || echo "⚠️  Git pull had issues, continuing..."

# Detect storage
echo ""
echo "Step 2: Detecting storage..."
if [ -d "/root/vast-storage" ]; then
    VAST_STORAGE="/root/vast-storage"
elif [ -d "/mnt/vast-storage" ]; then
    VAST_STORAGE="/mnt/vast-storage"
else
    VAST_STORAGE="/root/vast-storage"
    echo "Creating storage directory: $VAST_STORAGE"
    mkdir -p "$VAST_STORAGE"
fi

export VAST_STORAGE
export VAST_STORAGE_PATH="$VAST_STORAGE"

echo "✅ Using storage: $VAST_STORAGE"

# Create directories
echo ""
echo "Step 3: Creating storage directories..."
mkdir -p "$VAST_STORAGE/postgresql"
mkdir -p "$VAST_STORAGE/cached_sections"
mkdir -p "$VAST_STORAGE/embeddings"
mkdir -p "$VAST_STORAGE/logs"
echo "✅ Directories created"

# Create/update .env
echo ""
echo "Step 4: Setting up .env file..."
if [ -f "$PROJECT_DIR/.env.storage" ]; then
    cp "$PROJECT_DIR/.env.storage" "$PROJECT_DIR/.env"
    # Update VAST_STORAGE_PATH
    if grep -q "VAST_STORAGE_PATH=" "$PROJECT_DIR/.env"; then
        sed -i "s|VAST_STORAGE_PATH=.*|VAST_STORAGE_PATH=$VAST_STORAGE|g" "$PROJECT_DIR/.env"
    else
        echo "VAST_STORAGE_PATH=$VAST_STORAGE" >> "$PROJECT_DIR/.env"
    fi
    echo "✅ .env file created from .env.storage"
else
    # Create new .env
    POSTGRES_PASSWORD=$(openssl rand -base64 32)
    cat > "$PROJECT_DIR/.env" << EOF
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
    echo "✅ .env file created"
fi

# Check Docker
echo ""
echo "Step 5: Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
fi

if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    apt-get update -qq
    apt-get install -y docker-compose-plugin 2>/dev/null || {
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    }
fi

echo "✅ Docker ready"

# Start services
echo ""
echo "Step 6: Starting Docker Compose services..."
echo ""

cd "$PROJECT_DIR"
export VAST_STORAGE_PATH="$VAST_STORAGE"
docker compose up -d

echo ""
echo "Waiting for services to initialize..."
sleep 15

# Check status
echo ""
echo "Service Status:"
docker compose ps

# Initialize pgvector
echo ""
echo "Step 7: Initializing pgvector extension..."
sleep 5
docker exec ai-teacher-postgres psql -U ai_teacher -d ai_teacher -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || {
    echo "⚠️  PostgreSQL may still be starting. Try again in a minute:"
    echo "   docker exec -it ai-teacher-postgres psql -U ai_teacher -d ai_teacher -c \"CREATE EXTENSION IF NOT EXISTS vector;\""
}

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Storage: $VAST_STORAGE"
echo ""
echo "Check service status:"
echo "   docker compose ps"
echo ""
echo "View logs:"
echo "   docker compose logs -f"
echo ""
echo "PostgreSQL data location:"
echo "   ls -la $VAST_STORAGE/postgresql/"
echo ""
