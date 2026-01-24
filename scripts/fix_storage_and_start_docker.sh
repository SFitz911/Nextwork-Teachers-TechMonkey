#!/bin/bash
# Quick fix script to set up storage and start Docker services
# Run this if you've already run setup_new_instance_with_storage.sh

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$HOME/Nextwork-Teachers-TechMonkey}"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Fixing Storage Setup and Starting Docker"
echo "=========================================="
echo ""

# Detect or use existing storage
if [ -z "${VAST_STORAGE:-}" ]; then
    # Check common locations
    if [ -d "/root/vast-storage" ]; then
        VAST_STORAGE="/root/vast-storage"
    elif [ -d "/mnt/vast-storage" ]; then
        VAST_STORAGE="/mnt/vast-storage"
    else
        echo "⚠️  Storage directory not found. Please specify:"
        read -p "Enter storage path (or press Enter for /root/vast-storage): " VAST_STORAGE
        VAST_STORAGE="${VAST_STORAGE:-/root/vast-storage}"
    fi
fi

export VAST_STORAGE
echo "Using storage: $VAST_STORAGE"

# Create directories
echo ""
echo "Creating storage directories..."
mkdir -p "$VAST_STORAGE/postgresql"
mkdir -p "$VAST_STORAGE/cached_sections"
mkdir -p "$VAST_STORAGE/embeddings"
mkdir -p "$VAST_STORAGE/logs"
echo "✅ Directories created"

# Check if .env exists, if not create from .env.storage
if [ ! -f "$PROJECT_DIR/.env" ]; then
    if [ -f "$PROJECT_DIR/.env.storage" ]; then
        echo ""
        echo "Copying .env.storage to .env..."
        cp "$PROJECT_DIR/.env.storage" "$PROJECT_DIR/.env"
        
        # Update VAST_STORAGE_PATH in .env
        if grep -q "VAST_STORAGE_PATH=" "$PROJECT_DIR/.env"; then
            sed -i "s|VAST_STORAGE_PATH=.*|VAST_STORAGE_PATH=$VAST_STORAGE|g" "$PROJECT_DIR/.env"
        else
            echo "VAST_STORAGE_PATH=$VAST_STORAGE" >> "$PROJECT_DIR/.env"
        fi
        echo "✅ .env file created/updated"
    else
        echo ""
        echo "⚠️  No .env.storage found. Creating new .env..."
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
fi

# Check Docker
echo ""
echo "Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Installing..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
fi

if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    apt-get update
    apt-get install -y docker-compose-plugin || {
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    }
fi

echo "✅ Docker ready"

# Start services
echo ""
echo "Starting Docker Compose services..."
echo "   (This will start PostgreSQL, n8n, Ollama, and all other services)"
echo ""

cd "$PROJECT_DIR"
export VAST_STORAGE_PATH="$VAST_STORAGE"
docker compose up -d

echo ""
echo "Waiting for services to start..."
sleep 10

# Check service status
echo ""
echo "Service Status:"
docker compose ps

echo ""
echo "Initializing pgvector extension..."
sleep 5
docker exec -it ai-teacher-postgres psql -U ai_teacher -d ai_teacher -c "CREATE EXTENSION IF NOT EXISTS vector;" || {
    echo "⚠️  Could not create extension yet. PostgreSQL may still be starting."
    echo "   Try again in a minute:"
    echo "   docker exec -it ai-teacher-postgres psql -U ai_teacher -d ai_teacher -c \"CREATE EXTENSION IF NOT EXISTS vector;\""
}

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Storage: $VAST_STORAGE"
echo "Services are starting. Check status with:"
echo "   docker compose ps"
echo ""
echo "View logs:"
echo "   docker compose logs -f"
echo ""
echo "Access services (after port forwarding):"
echo "   - Frontend: http://localhost:8501"
echo "   - n8n: http://localhost:5678"
echo "   - Coordinator API: http://localhost:8004"
echo ""
