#!/bin/bash
# Fix storage path in .env file after incorrect setup
# Usage: bash scripts/fix_storage_path.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Fixing Storage Path Configuration"
echo "=========================================="
echo ""

# Detect the correct storage path (/workspace)
VAST_STORAGE="/workspace"

if [ ! -d "$VAST_STORAGE" ]; then
    echo "❌ Storage volume not found at /workspace"
    echo "Checking other locations..."
    
    # Check for other possible locations
    for loc in "/mnt/vast-storage" "/mnt/storage" "/vast-storage"; do
        if [ -d "$loc" ] && mountpoint -q "$loc" 2>/dev/null; then
            VAST_STORAGE="$loc"
            echo "✅ Found storage at: $VAST_STORAGE"
            break
        fi
    done
    
    if [ ! -d "$VAST_STORAGE" ]; then
        echo "⚠️  Please enter the correct storage volume path:"
        read -p "Storage path: " VAST_STORAGE
    fi
fi

echo ""
echo "Using storage path: $VAST_STORAGE"
df -h "$VAST_STORAGE" || echo "⚠️  Could not get disk usage"
echo ""

# Backup existing .env
if [ -f ".env" ]; then
    cp ".env" ".env.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✅ Backed up existing .env"
fi

# Remove incorrect storage paths from .env
if [ -f ".env" ]; then
    # Remove lines with invalid paths
    sed -i '/^VAST_STORAGE_PATH=.*paths/d' .env
    sed -i '/^VIDEO_OUTPUT_DIR=.*paths/d' .env
    sed -i '/^AUDIO_OUTPUT_DIR=.*paths/d' .env
    sed -i '/^CACHE_DIR=.*paths/d' .env
    sed -i '/^EMBEDDINGS_DIR=.*paths/d' .env
    sed -i '/^POSTGRES_DATA_DIR=.*paths/d' .env
    sed -i '/^N8N_DATA_DIR=.*paths/d' .env
    sed -i '/^OLLAMA_DATA_DIR=.*paths/d' .env
    sed -i '/^LOGS_DIR=.*paths/d' .env
    sed -i '/^COORDINATOR_LOGS_DIR=.*paths/d' .env
    sed -i '/^LONGCAT_LOGS_DIR=.*paths/d' .env
    sed -i '/^N8N_LOGS_DIR=.*paths/d' .env
    sed -i '/^FRONTEND_LOGS_DIR=.*paths/d' .env
    sed -i '/^TTS_LOGS_DIR=.*paths/d' .env
    sed -i '/^INDEXES_DIR=.*paths/d' .env
    sed -i '/^VIDEO_INDEX_DIR=.*paths/d' .env
    sed -i '/^SESSION_INDEX_DIR=.*paths/d' .env
    sed -i '/^MODELS_DIR=.*paths/d' .env
    sed -i '/^LONGCAT_MODELS_DIR=.*paths/d' .env
fi

# Add correct storage paths
cat >> ".env" << EOF

# ==========================================
# VAST.AI Storage Volume Configuration (FIXED)
# ==========================================
VAST_STORAGE_PATH=$VAST_STORAGE
VAST_STORAGE=$VAST_STORAGE

# Data Directories (on storage volume)
VIDEO_OUTPUT_DIR=$VAST_STORAGE/data/videos
AUDIO_OUTPUT_DIR=$VAST_STORAGE/data/audio
CACHE_DIR=$VAST_STORAGE/data/cache
EMBEDDINGS_DIR=$VAST_STORAGE/data/embeddings
POSTGRES_DATA_DIR=$VAST_STORAGE/data/postgresql
N8N_DATA_DIR=$VAST_STORAGE/data/n8n
OLLAMA_DATA_DIR=$VAST_STORAGE/data/ollama

# Log Directories (on storage volume)
LOGS_DIR=$VAST_STORAGE/logs
COORDINATOR_LOGS_DIR=$VAST_STORAGE/logs/coordinator
LONGCAT_LOGS_DIR=$VAST_STORAGE/logs/longcat_video
N8N_LOGS_DIR=$VAST_STORAGE/logs/n8n
FRONTEND_LOGS_DIR=$VAST_STORAGE/logs/frontend
TTS_LOGS_DIR=$VAST_STORAGE/logs/tts

# Index Directories (on storage volume)
INDEXES_DIR=$VAST_STORAGE/indexes
VIDEO_INDEX_DIR=$VAST_STORAGE/indexes/videos
SESSION_INDEX_DIR=$VAST_STORAGE/indexes/sessions

# Model Directories
MODELS_DIR=$VAST_STORAGE/models
LONGCAT_MODELS_DIR=$VAST_STORAGE/models/longcat
EOF

echo "✅ Storage paths fixed in .env"
echo ""

# Verify the paths
echo "Verifying storage paths..."
grep "VAST_STORAGE_PATH" .env | tail -1
grep "VIDEO_OUTPUT_DIR" .env | tail -1
echo ""

echo "=========================================="
echo "✅ Storage Path Fixed!"
echo "=========================================="
echo ""
echo "Storage Configuration:"
echo "  Volume Path: $VAST_STORAGE"
echo "  Data: $VAST_STORAGE/data"
echo "  Logs: $VAST_STORAGE/logs"
echo ""
echo "Next: Restart services:"
echo "  bash scripts/quick_start_all.sh"
echo ""
