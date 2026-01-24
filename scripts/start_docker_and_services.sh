#!/bin/bash
# Start Docker daemon and all services on Vast.ai instance
# Usage: bash scripts/start_docker_and_services.sh

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$HOME/Nextwork-Teachers-TechMonkey}"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Starting Docker and All Services"
echo "=========================================="
echo ""

# Check if Docker daemon is running
if docker info > /dev/null 2>&1; then
    echo "✅ Docker daemon is already running"
else
    echo "Starting Docker daemon..."
    
    # Try different methods to start Docker
    if command -v dockerd &> /dev/null; then
        # Start dockerd in background
        echo "Starting dockerd..."
        dockerd > /tmp/dockerd.log 2>&1 &
        DOCKERD_PID=$!
        sleep 5
        
        # Check if it started
        if docker info > /dev/null 2>&1; then
            echo "✅ Docker daemon started (PID: $DOCKERD_PID)"
        else
            echo "⚠️  Docker daemon may not have started properly"
            echo "   Check logs: tail -f /tmp/dockerd.log"
        fi
    elif [ -f /etc/init.d/docker ]; then
        # Use init.d script
        /etc/init.d/docker start
        sleep 3
    else
        echo "❌ Could not find Docker daemon binary"
        echo "   Docker may need to be installed differently"
        exit 1
    fi
    
    # Verify Docker is running
    if ! docker info > /dev/null 2>&1; then
        echo ""
        echo "⚠️  Docker daemon still not running. Trying alternative methods..."
        echo ""
        
        # Try starting with nohup
        if command -v dockerd &> /dev/null; then
            nohup dockerd > /tmp/dockerd.log 2>&1 &
            sleep 5
        fi
        
        # Final check
        if docker info > /dev/null 2>&1; then
            echo "✅ Docker daemon started"
        else
            echo "❌ Could not start Docker daemon"
            echo ""
            echo "Troubleshooting:"
            echo "1. Check if Docker is installed: which dockerd"
            echo "2. Check logs: cat /tmp/dockerd.log"
            echo "3. Try manually: dockerd &"
            echo "4. Check permissions: ls -la /var/run/docker.sock"
            exit 1
        fi
    fi
fi

# Set storage path
if [ -z "${VAST_STORAGE_PATH:-}" ]; then
    if [ -f "$PROJECT_DIR/.env" ]; then
        VAST_STORAGE_PATH=$(grep "VAST_STORAGE_PATH=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "")
    fi
    
    if [ -z "$VAST_STORAGE_PATH" ]; then
        # Try common locations
        for loc in "/root/vast-storage" "/mnt/vast-storage" "/vast-storage"; do
            if [ -d "$loc" ]; then
                VAST_STORAGE_PATH="$loc"
                break
            fi
        done
    fi
    
    if [ -z "$VAST_STORAGE_PATH" ]; then
        VAST_STORAGE_PATH="/root/vast-storage"
        mkdir -p "$VAST_STORAGE_PATH"
    fi
fi

export VAST_STORAGE_PATH
echo ""
echo "Using storage: $VAST_STORAGE_PATH"
echo ""

# Create storage directories
mkdir -p "$VAST_STORAGE_PATH/postgresql"
mkdir -p "$VAST_STORAGE_PATH/cached_sections"
mkdir -p "$VAST_STORAGE_PATH/embeddings"
mkdir -p "$VAST_STORAGE_PATH/logs"

# Make sure .env file exists and has VAST_STORAGE_PATH
if [ -f "$PROJECT_DIR/.env" ]; then
    if ! grep -q "VAST_STORAGE_PATH=" "$PROJECT_DIR/.env"; then
        echo "VAST_STORAGE_PATH=$VAST_STORAGE_PATH" >> "$PROJECT_DIR/.env"
    else
        # Update if different
        sed -i "s|VAST_STORAGE_PATH=.*|VAST_STORAGE_PATH=$VAST_STORAGE_PATH|g" "$PROJECT_DIR/.env"
    fi
fi

# Start Docker Compose services
echo ""
echo "Starting Docker Compose services..."
echo ""

cd "$PROJECT_DIR"

# Pull images first
echo "Pulling Docker images (this may take a few minutes)..."
docker compose pull || echo "⚠️  Some images may not have been pulled"

# Start services
echo ""
echo "Starting all services..."
docker compose up -d

echo ""
echo "Waiting for services to initialize..."
sleep 10

# Check service status
echo ""
echo "Service Status:"
docker compose ps

# Initialize pgvector
echo ""
echo "Initializing pgvector extension..."
sleep 5
docker exec ai-teacher-postgres psql -U ai_teacher -d ai_teacher -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || {
    echo "⚠️  PostgreSQL may still be starting. Will retry..."
    sleep 10
    docker exec ai-teacher-postgres psql -U ai_teacher -d ai_teacher -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || {
        echo "⚠️  Could not create extension yet. Try manually:"
        echo "   docker exec -it ai-teacher-postgres psql -U ai_teacher -d ai_teacher -c \"CREATE EXTENSION IF NOT EXISTS vector;\""
    }
}

echo ""
echo "=========================================="
echo "✅ Services Started!"
echo "=========================================="
echo ""
echo "Check status:"
echo "   docker compose ps"
echo ""
echo "View logs:"
echo "   docker compose logs -f"
echo ""
echo "View specific service logs:"
echo "   docker compose logs -f postgres"
echo "   docker compose logs -f coordinator"
echo ""
echo "Access services (after port forwarding):"
echo "   - Frontend: http://localhost:8501"
echo "   - n8n: http://localhost:5678"
echo "   - Coordinator API: http://localhost:8004"
echo ""
