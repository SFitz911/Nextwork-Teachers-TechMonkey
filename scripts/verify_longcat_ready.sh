#!/bin/bash
# Verify LongCat-Video is ready for use
# Usage: bash scripts/verify_longcat_ready.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Verifying LongCat-Video Setup"
echo "=========================================="
echo ""

# Check if models are downloaded
LONGCAT_DIR="$PROJECT_DIR/LongCat-Video"
AVATAR_MODEL_DIR="$LONGCAT_DIR/weights/LongCat-Video-Avatar"
BASE_MODEL_DIR="$LONGCAT_DIR/weights/LongCat-Video"

echo "Step 1: Checking model directories..."
if [[ -d "$AVATAR_MODEL_DIR" ]]; then
    MODEL_SIZE=$(du -sh "$AVATAR_MODEL_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    FILE_COUNT=$(find "$AVATAR_MODEL_DIR" -type f 2>/dev/null | wc -l)
    echo "✅ Avatar models found: $AVATAR_MODEL_DIR"
    echo "   Size: $MODEL_SIZE"
    echo "   Files: $FILE_COUNT"
    
    # Check for key model files
    if [[ -f "$AVATAR_MODEL_DIR/config.json" ]]; then
        echo "   ✅ config.json found"
    else
        echo "   ⚠️  config.json missing"
    fi
else
    echo "❌ Avatar models NOT found: $AVATAR_MODEL_DIR"
    echo "   Run: bash scripts/deploy_longcat_video.sh"
fi

if [[ -d "$BASE_MODEL_DIR" ]]; then
    BASE_SIZE=$(du -sh "$BASE_MODEL_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    echo "✅ Base models found: $BASE_MODEL_DIR"
    echo "   Size: $BASE_SIZE"
else
    echo "⚠️  Base models not found: $BASE_MODEL_DIR"
fi

echo ""
echo "Step 2: Checking avatar images..."
AVATAR_DIR="$LONGCAT_DIR/assets/avatars"
if [[ -d "$AVATAR_DIR" ]]; then
    echo "✅ Avatar directory exists: $AVATAR_DIR"
    for teacher in maya maximus krishna techmonkey_steve pano_bieber; do
        if [[ -f "$AVATAR_DIR/${teacher}.png" ]]; then
            echo "   ✅ ${teacher}.png"
        else
            echo "   ❌ ${teacher}.png MISSING"
        fi
    done
else
    echo "❌ Avatar directory not found: $AVATAR_DIR"
    echo "   Run: bash scripts/fix_avatar_images.sh"
fi

echo ""
echo "Step 3: Checking LongCat-Video service status..."
if curl -s http://localhost:8003/status > /dev/null 2>&1; then
    echo "✅ LongCat-Video service is running (port 8003)"
    STATUS=$(curl -s http://localhost:8003/status)
    echo "   Status: $STATUS"
else
    echo "❌ LongCat-Video service NOT running (port 8003)"
    echo "   Start it with: bash scripts/quick_start_all.sh"
fi

echo ""
echo "Step 4: Checking conda environment..."
if conda env list | grep -q "longcat-video"; then
    echo "✅ Conda environment 'longcat-video' exists"
    
    # Check if we can activate it
    source "$(conda info --base)/etc/profile.d/conda.sh"
    if conda activate longcat-video 2>/dev/null; then
        PYTHON_PATH=$(which python)
        PYTHON_VERSION=$(python --version 2>&1)
        echo "   Python: $PYTHON_PATH"
        echo "   Version: $PYTHON_VERSION"
        
        # Check critical packages
        echo ""
        echo "   Checking critical packages..."
        for pkg in torch fastapi uvicorn; do
            if python -c "import $pkg" 2>/dev/null; then
                echo "   ✅ $pkg installed"
            else
                echo "   ❌ $pkg NOT installed"
            fi
        done
    fi
else
    echo "❌ Conda environment 'longcat-video' not found"
    echo "   Run: bash scripts/deploy_longcat_video.sh"
fi

echo ""
echo "=========================================="
echo "Verification Complete"
echo "=========================================="
echo ""
echo "If everything is ✅, you can test video generation:"
echo "  bash scripts/test_session_flow.sh"
echo ""
