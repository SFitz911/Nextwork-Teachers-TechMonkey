#!/usr/bin/env bash
# Verify LongCat-Video service setup
# Usage: bash scripts/verify_longcat_setup.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Verifying LongCat-Video Setup"
echo "=========================================="
echo ""

# Check if LongCat-Video directory exists
LONGCAT_DIR="$PROJECT_DIR/LongCat-Video"
if [[ -d "$LONGCAT_DIR" ]]; then
    echo "✅ LongCat-Video directory exists"
else
    echo "❌ LongCat-Video directory not found at $LONGCAT_DIR"
    echo "   Run: git clone --single-branch --branch main https://github.com/meituan-longcat/LongCat-Video"
fi

# Check if service file exists
SERVICE_FILE="$PROJECT_DIR/services/longcat_video/app.py"
if [[ -f "$SERVICE_FILE" ]]; then
    echo "✅ LongCat-Video service file exists"
else
    echo "❌ Service file not found: $SERVICE_FILE"
fi

# Check if models are downloaded
WEIGHTS_DIR="$LONGCAT_DIR/weights"
AVATAR_MODEL_DIR="$WEIGHTS_DIR/LongCat-Video-Avatar"
if [[ -d "$AVATAR_MODEL_DIR" ]]; then
    echo "✅ LongCat-Video-Avatar models found"
    MODEL_SIZE=$(du -sh "$AVATAR_MODEL_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    echo "   Model size: $MODEL_SIZE"
else
    echo "⚠️  LongCat-Video-Avatar models not found at $AVATAR_MODEL_DIR"
    echo "   Run: bash scripts/deploy_longcat_video.sh"
fi

# Check if avatar images directory exists
AVATAR_IMAGES_DIR="$LONGCAT_DIR/assets/avatars"
if [[ -d "$AVATAR_IMAGES_DIR" ]]; then
    echo "✅ Avatar images directory exists"
    IMAGE_COUNT=$(find "$AVATAR_IMAGES_DIR" -name "*.png" -o -name "*.jpg" 2>/dev/null | wc -l)
    echo "   Found $IMAGE_COUNT image(s)"
    
    # Check for required teacher images
    REQUIRED_IMAGES=("maya.png" "maximus.png" "krishna.png" "techmonkey_steve.png" "pano_bieber.png")
    for img in "${REQUIRED_IMAGES[@]}"; do
        if [[ -f "$AVATAR_IMAGES_DIR/$img" ]]; then
            echo "   ✅ $img found"
        else
            echo "   ⚠️  $img not found"
        fi
    done
else
    echo "⚠️  Avatar images directory not found: $AVATAR_IMAGES_DIR"
    echo "   Create it and add teacher images"
fi

# Check if service is running
echo ""
echo "Checking if LongCat-Video service is running..."
if curl -s http://localhost:8003/status > /dev/null 2>&1; then
    echo "✅ LongCat-Video service is accessible on port 8003"
    STATUS=$(curl -s http://localhost:8003/status | python3 -c "import sys, json; print(json.load(sys.stdin).get('status', 'unknown'))" 2>/dev/null || echo "unknown")
    echo "   Status: $STATUS"
else
    echo "❌ LongCat-Video service is NOT running on port 8003"
    echo "   Start it with:"
    echo "   conda activate longcat-video"
    echo "   python services/longcat_video/app.py"
fi

# Verify teacher ID mapping in service
echo ""
echo "Verifying teacher ID mapping in service..."
if grep -q "teacher_a\|teacher_b\|teacher_c\|teacher_d\|teacher_e" "$SERVICE_FILE"; then
    echo "✅ Service has teacher ID mappings"
else
    echo "⚠️  Teacher ID mappings not found in service file"
fi

echo ""
echo "=========================================="
echo "Verification Complete"
echo "=========================================="
