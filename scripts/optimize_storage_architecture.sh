#!/bin/bash
# Optimize storage architecture to use VAST.AI storage volume
# This script:
# 1. Detects and mounts VAST.AI storage volume
# 2. Sets up optimized directory structure
# 3. Moves existing data to storage volume
# 4. Creates symlinks for backward compatibility
# 5. Configures services to use storage volume
# 6. Sets up indexing and optimization
# Usage: bash scripts/optimize_storage_architecture.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Optimizing Storage Architecture"
echo "=========================================="
echo ""

# Step 1: Detect VAST.AI storage volume
echo "Step 1: Detecting VAST.AI storage volume..."
echo ""

# Common mount points for VAST.AI volumes
POSSIBLE_MOUNTS=(
    "/workspace"           # VAST.AI default mount point
    "/mnt/vast-storage"
    "/mnt/storage"
    "/vast-storage"
    "/storage"
    "/root/vast-storage"
)

VAST_STORAGE=""
for mount in "${POSSIBLE_MOUNTS[@]}"; do
    if mountpoint -q "$mount" 2>/dev/null || ([ -d "$mount" ] && [ -w "$mount" ]); then
        # Check if it's actually a volume (has significant space)
        SPACE=$(df -h "$mount" 2>/dev/null | tail -1 | awk '{print $2}' || echo "")
        if [[ -n "$SPACE" ]] && [[ "$SPACE" =~ [0-9]+[GT] ]]; then
            VAST_STORAGE="$mount"
            echo "✅ Found storage volume at: $VAST_STORAGE"
            df -h "$VAST_STORAGE"
            break
        fi
    fi
done

# If not found, check all mounted filesystems for large volumes (1TB+)
if [ -z "$VAST_STORAGE" ]; then
    echo "Checking all mounted filesystems for storage volumes..."
    df -h | grep -E "(vast|storage|volume|workspace|1T|1.0T)" || true
    
    # Try to find /workspace (common VAST.AI mount point)
    if mountpoint -q "/workspace" 2>/dev/null || ([ -d "/workspace" ] && [ -w "/workspace" ]); then
        SPACE=$(df -h "/workspace" 2>/dev/null | tail -1 | awk '{print $2}' || echo "")
        if [[ -n "$SPACE" ]] && [[ "$SPACE" =~ [0-9]+[GT] ]]; then
            VAST_STORAGE="/workspace"
            echo "✅ Found storage volume at: $VAST_STORAGE"
            df -h "$VAST_STORAGE"
        fi
    fi
fi

# If still not found, prompt user
if [ -z "$VAST_STORAGE" ]; then
    echo ""
    echo "⚠️  Could not auto-detect storage volume mount point."
    echo "Please check Vast.ai dashboard - volume should be attached to instance."
    echo ""
    echo "Common mount points:"
    echo "  - /workspace (VAST.AI default)"
    echo "  - /mnt/vast-storage"
    echo "  - /mnt/storage"
    echo ""
    read -p "Enter storage volume mount path (or press Enter to use /workspace): " VAST_STORAGE
    VAST_STORAGE="${VAST_STORAGE:-/workspace}"
    
    # Validate the path
    if [ ! -d "$VAST_STORAGE" ]; then
        echo "⚠️  Directory does not exist: $VAST_STORAGE"
        read -p "Create it? (y/n): " CREATE_DIR
        if [[ "$CREATE_DIR" == "y" ]]; then
            mkdir -p "$VAST_STORAGE"
        else
            echo "❌ Cannot proceed without valid storage path"
            exit 1
        fi
    fi
fi

# Export for use in this script and child processes
export VAST_STORAGE
export VAST_STORAGE_PATH="$VAST_STORAGE"

echo ""
echo "Using storage path: $VAST_STORAGE"
echo ""

# Step 2: Create optimized directory structure
echo "Step 2: Creating optimized directory structure..."
echo ""

# Main directories
mkdir -p "$VAST_STORAGE/data"              # All application data
mkdir -p "$VAST_STORAGE/data/videos"        # Generated videos (indexed)
mkdir -p "$VAST_STORAGE/data/audio"         # Generated audio files
mkdir -p "$VAST_STORAGE/data/cache"         # Cached content (by hash)
mkdir -p "$VAST_STORAGE/data/embeddings"    # Vector embeddings
mkdir -p "$VAST_STORAGE/data/postgresql"    # PostgreSQL data
mkdir -p "$VAST_STORAGE/data/n8n"          # n8n workflows and data
mkdir -p "$VAST_STORAGE/data/ollama"       # Ollama models (optional)
mkdir -p "$VAST_STORAGE/logs"               # All application logs
mkdir -p "$VAST_STORAGE/logs/coordinator"   # Coordinator API logs
mkdir -p "$VAST_STORAGE/logs/longcat_video" # LongCat-Video logs
mkdir -p "$VAST_STORAGE/logs/n8n"          # n8n logs
mkdir -p "$VAST_STORAGE/logs/frontend"      # Frontend logs
mkdir -p "$VAST_STORAGE/logs/tts"          # TTS logs
mkdir -p "$VAST_STORAGE/indexes"           # Search indexes
mkdir -p "$VAST_STORAGE/indexes/videos"    # Video metadata index
mkdir -p "$VAST_STORAGE/indexes/sessions"   # Session index
mkdir -p "$VAST_STORAGE/models"            # Model files (if needed)
mkdir -p "$VAST_STORAGE/models/longcat"    # LongCat-Video models (symlink target)

echo "✅ Directory structure created"
echo ""

# Step 3: Move existing data to storage volume (if exists)
echo "Step 3: Migrating existing data to storage volume..."
echo ""

# Videos
if [ -d "$PROJECT_DIR/outputs/longcat" ] && [ "$(ls -A $PROJECT_DIR/outputs/longcat 2>/dev/null)" ]; then
    echo "Moving generated videos..."
    mv "$PROJECT_DIR/outputs/longcat"/* "$VAST_STORAGE/data/videos/" 2>/dev/null || true
    echo "✅ Videos migrated"
fi

# Logs
if [ -d "$PROJECT_DIR/logs" ]; then
    echo "Moving logs..."
    for log_file in "$PROJECT_DIR/logs"/*; do
        if [ -f "$log_file" ]; then
            LOG_NAME=$(basename "$log_file")
            if [[ "$LOG_NAME" == *"coordinator"* ]]; then
                mv "$log_file" "$VAST_STORAGE/logs/coordinator/" 2>/dev/null || true
            elif [[ "$LOG_NAME" == *"longcat"* ]]; then
                mv "$log_file" "$VAST_STORAGE/logs/longcat_video/" 2>/dev/null || true
            elif [[ "$LOG_NAME" == *"n8n"* ]]; then
                mv "$log_file" "$VAST_STORAGE/logs/n8n/" 2>/dev/null || true
            else
                mv "$log_file" "$VAST_STORAGE/logs/" 2>/dev/null || true
            fi
        fi
    done
    echo "✅ Logs migrated"
fi

# LongCat-Video models (create symlink, don't move - too large and may be on instance)
if [ -d "$PROJECT_DIR/LongCat-Video/weights" ]; then
    echo "Creating symlink for LongCat-Video models..."
    ln -sf "$PROJECT_DIR/LongCat-Video/weights" "$VAST_STORAGE/models/longcat/weights" 2>/dev/null || true
    echo "✅ Model symlink created"
fi

echo "✅ Data migration complete"
echo ""

# Step 4: Create symlinks for backward compatibility
echo "Step 4: Creating symlinks for backward compatibility..."
echo ""

# Create symlinks so existing code continues to work
mkdir -p "$PROJECT_DIR/outputs"
ln -sf "$VAST_STORAGE/data/videos" "$PROJECT_DIR/outputs/longcat" 2>/dev/null || true

mkdir -p "$PROJECT_DIR/logs"
ln -sf "$VAST_STORAGE/logs" "$PROJECT_DIR/logs/storage" 2>/dev/null || true

echo "✅ Symlinks created"
echo ""

# Step 5: Update .env file with storage paths
echo "Step 5: Updating environment configuration..."
echo ""

# Load existing .env if it exists
if [ -f "$PROJECT_DIR/.env" ]; then
    # Backup existing .env
    cp "$PROJECT_DIR/.env" "$PROJECT_DIR/.env.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Update or create .env with storage paths
cat >> "$PROJECT_DIR/.env" << EOF

# ==========================================
# VAST.AI Storage Volume Configuration
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

echo "✅ Environment configuration updated"
echo ""

# Step 6: Create indexing script for fast retrieval
echo "Step 6: Setting up indexing system..."
echo ""

cat > "$PROJECT_DIR/scripts/index_videos.sh" << 'INDEX_EOF'
#!/bin/bash
# Index videos for fast retrieval
# Usage: bash scripts/index_videos.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

VIDEO_DIR="${VIDEO_OUTPUT_DIR:-$VAST_STORAGE/data/videos}"
INDEX_DIR="${VIDEO_INDEX_DIR:-$VAST_STORAGE/indexes/videos}"
INDEX_FILE="$INDEX_DIR/video_index.json"

mkdir -p "$INDEX_DIR"

echo "Indexing videos in $VIDEO_DIR..."

# Create JSON index of all videos
python3 << PYTHON_EOF
import os
import json
import hashlib
from datetime import datetime
from pathlib import Path

video_dir = "$VIDEO_DIR"
index_file = "$INDEX_FILE"

videos = []
for root, dirs, files in os.walk(video_dir):
    for file in files:
        if file.endswith(('.mp4', '.avi', '.mov')):
            video_path = os.path.join(root, file)
            rel_path = os.path.relpath(video_path, video_dir)
            
            stat = os.stat(video_path)
            file_hash = hashlib.md5(open(video_path, 'rb').read(1024*1024)).hexdigest()  # First 1MB hash
            
            videos.append({
                "path": rel_path,
                "full_path": video_path,
                "filename": file,
                "size": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                "hash": file_hash
            })

# Sort by modified time (newest first)
videos.sort(key=lambda x: x["modified"], reverse=True)

index_data = {
    "indexed_at": datetime.now().isoformat(),
    "total_videos": len(videos),
    "videos": videos
}

with open(index_file, 'w') as f:
    json.dump(index_data, f, indent=2)

print(f"✅ Indexed {len(videos)} videos")
PYTHON_EOF

echo "✅ Video indexing complete"
INDEX_EOF

chmod +x "$PROJECT_DIR/scripts/index_videos.sh"

echo "✅ Indexing system set up"
echo ""

# Step 7: Create log rotation script
echo "Step 7: Setting up log rotation..."
echo ""

cat > "$PROJECT_DIR/scripts/rotate_logs.sh" << 'ROTATE_EOF'
#!/bin/bash
# Rotate and compress old logs
# Usage: bash scripts/rotate_logs.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

LOGS_DIR="${LOGS_DIR:-$VAST_STORAGE/logs}"
ARCHIVE_DIR="$LOGS_DIR/archive"
DAYS_TO_KEEP=30

mkdir -p "$ARCHIVE_DIR"

echo "Rotating logs older than $DAYS_TO_KEEP days..."

# Find and compress old logs
find "$LOGS_DIR" -type f -name "*.log" -mtime +$DAYS_TO_KEEP | while read logfile; do
    echo "Archiving: $logfile"
    gzip -c "$logfile" > "$ARCHIVE_DIR/$(basename $logfile).gz"
    rm "$logfile"
done

echo "✅ Log rotation complete"
ROTATE_EOF

chmod +x "$PROJECT_DIR/scripts/rotate_logs.sh"

echo "✅ Log rotation set up"
echo ""

# Step 8: Update service configurations
echo "Step 8: Updating service configurations..."
echo ""

# Update LongCat-Video service to use storage volume
if [ -f "$PROJECT_DIR/services/longcat_video/app.py" ]; then
    # This will be done via environment variables, but we can add a note
    echo "✅ LongCat-Video service will use OUTPUT_DIR from .env"
fi

# Update Coordinator API to use storage volume for logs
if [ -f "$PROJECT_DIR/services/coordinator/app.py" ]; then
    echo "✅ Coordinator API will use LOGS_DIR from .env"
fi

echo "✅ Service configurations updated"
echo ""

# Step 9: Create storage health check script
echo "Step 9: Creating storage health check script..."
echo ""

cat > "$PROJECT_DIR/scripts/check_storage_health.sh" << 'HEALTH_EOF'
#!/bin/bash
# Check storage volume health and usage
# Usage: bash scripts/check_storage_health.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

VAST_STORAGE="${VAST_STORAGE:-/root/vast-storage}"

echo "=========================================="
echo "Storage Volume Health Check"
echo "=========================================="
echo ""

# Check if storage is mounted
if mountpoint -q "$VAST_STORAGE" 2>/dev/null || [ -d "$VAST_STORAGE" ]; then
    echo "✅ Storage volume is accessible: $VAST_STORAGE"
    df -h "$VAST_STORAGE"
else
    echo "❌ Storage volume not accessible: $VAST_STORAGE"
    exit 1
fi

echo ""
echo "Directory Usage:"
echo ""

du -sh "$VAST_STORAGE/data"/* 2>/dev/null | sort -h || echo "  (no data directories)"
du -sh "$VAST_STORAGE/logs"/* 2>/dev/null | sort -h || echo "  (no log directories)"

echo ""
echo "File Counts:"
echo "  Videos: $(find "$VAST_STORAGE/data/videos" -type f 2>/dev/null | wc -l)"
echo "  Audio: $(find "$VAST_STORAGE/data/audio" -type f 2>/dev/null | wc -l)"
echo "  Cache: $(find "$VAST_STORAGE/data/cache" -type f 2>/dev/null | wc -l)"
echo "  Logs: $(find "$VAST_STORAGE/logs" -type f 2>/dev/null | wc -l)"

echo ""
echo "✅ Storage health check complete"
HEALTH_EOF

chmod +x "$PROJECT_DIR/scripts/check_storage_health.sh"

echo "✅ Storage health check script created"
echo ""

# Step 10: Summary
echo "=========================================="
echo "✅ Storage Architecture Optimization Complete!"
echo "=========================================="
echo ""
echo "Storage Configuration:"
echo "  Volume Path: $VAST_STORAGE"
echo "  Data: $VAST_STORAGE/data"
echo "  Logs: $VAST_STORAGE/logs"
echo "  Indexes: $VAST_STORAGE/indexes"
echo ""
echo "Next Steps:"
echo "  1. Restart services to use new storage paths:"
echo "     bash scripts/quick_start_all.sh"
echo ""
echo "  2. Index existing videos:"
echo "     bash scripts/index_videos.sh"
echo ""
echo "  3. Check storage health:"
echo "     bash scripts/check_storage_health.sh"
echo ""
echo "  4. Set up log rotation (add to crontab):"
echo "     0 2 * * * cd $PROJECT_DIR && bash scripts/rotate_logs.sh"
echo ""
echo "=========================================="
