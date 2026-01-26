#!/bin/bash
# Check if Hugging Face models are downloaded
# Usage: bash scripts/check_models_downloaded.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Checking Hugging Face Models"
echo "=========================================="
echo ""

AVATAR_MODEL_DIR="$PROJECT_DIR/LongCat-Video/weights/LongCat-Video-Avatar"
BASE_MODEL_DIR="$PROJECT_DIR/LongCat-Video/weights/LongCat-Video"

# Check Avatar model
if [[ -d "$AVATAR_MODEL_DIR" ]]; then
    AVATAR_SIZE=$(du -sh "$AVATAR_MODEL_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    AVATAR_FILES=$(find "$AVATAR_MODEL_DIR" -type f 2>/dev/null | wc -l)
    
    if [[ $AVATAR_FILES -gt 5 ]]; then
        echo "✅ LongCat-Video-Avatar model found"
        echo "   Location: $AVATAR_MODEL_DIR"
        echo "   Size: $AVATAR_SIZE"
        echo "   Files: $AVATAR_FILES"
    else
        echo "⚠️  LongCat-Video-Avatar model directory exists but seems incomplete"
        echo "   Location: $AVATAR_MODEL_DIR"
        echo "   Files: $AVATAR_FILES (expected: 20+)"
        echo "   Size: $AVATAR_SIZE"
    fi
else
    echo "❌ LongCat-Video-Avatar model NOT found"
    echo "   Expected: $AVATAR_MODEL_DIR"
fi

echo ""

# Check Base model
if [[ -d "$BASE_MODEL_DIR" ]]; then
    BASE_SIZE=$(du -sh "$BASE_MODEL_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    BASE_FILES=$(find "$BASE_MODEL_DIR" -type f 2>/dev/null | wc -l)
    
    if [[ $BASE_FILES -gt 5 ]]; then
        echo "✅ LongCat-Video base model found"
        echo "   Location: $BASE_MODEL_DIR"
        echo "   Size: $BASE_SIZE"
        echo "   Files: $BASE_FILES"
    else
        echo "⚠️  LongCat-Video base model directory exists but seems incomplete"
        echo "   Location: $BASE_MODEL_DIR"
        echo "   Files: $BASE_FILES (expected: 20+)"
        echo "   Size: $BASE_SIZE"
    fi
else
    echo "❌ LongCat-Video base model NOT found"
    echo "   Expected: $BASE_MODEL_DIR"
fi

echo ""
echo "=========================================="

# If models are missing, provide download command
if [[ ! -d "$AVATAR_MODEL_DIR" ]] || [[ ! -d "$BASE_MODEL_DIR" ]]; then
    echo ""
    echo "To download models, run:"
    echo "  source \"\$(conda info --base)/etc/profile.d/conda.sh\""
    echo "  conda activate longcat-video"
    echo "  pip install 'huggingface_hub[cli]'"
    echo "  huggingface-cli download meituan-longcat/LongCat-Video-Avatar --local-dir $AVATAR_MODEL_DIR"
    echo "  huggingface-cli download meituan-longcat/LongCat-Video --local-dir $BASE_MODEL_DIR"
fi
