#!/bin/bash
# Clone LongCat-Video repository if it doesn't exist
# Usage: bash scripts/clone_longcat_video.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

LONGCAT_DIR="$PROJECT_DIR/LongCat-Video"

echo "=========================================="
echo "Cloning LongCat-Video Repository"
echo "=========================================="
echo ""

if [[ -d "$LONGCAT_DIR" ]]; then
    echo "✅ LongCat-Video directory already exists"
    echo "   Location: $LONGCAT_DIR"
    
    # Check if it's a git repository
    if [[ -d "$LONGCAT_DIR/.git" ]]; then
        echo "✅ It's a git repository"
        echo ""
        echo "To update it, run:"
        echo "  cd $LONGCAT_DIR"
        echo "  git pull origin main"
    else
        echo "⚠️  Directory exists but is not a git repository"
        echo "   Removing and re-cloning..."
        rm -rf "$LONGCAT_DIR"
    fi
fi

if [[ ! -d "$LONGCAT_DIR" ]]; then
    echo "Cloning LongCat-Video repository..."
    echo "   This may take a few minutes..."
    echo ""
    
    git clone --single-branch --branch main https://github.com/meituan-longcat/LongCat-Video "$LONGCAT_DIR"
    
    if [[ $? -eq 0 ]]; then
        echo ""
        echo "✅ Successfully cloned LongCat-Video repository"
        echo "   Location: $LONGCAT_DIR"
    else
        echo ""
        echo "❌ Failed to clone repository"
        exit 1
    fi
fi

# Verify the script file exists
SCRIPT_FILE="$LONGCAT_DIR/run_demo_avatar_single_audio_to_video.py"
if [[ -f "$SCRIPT_FILE" ]]; then
    echo "✅ Avatar script found: $SCRIPT_FILE"
else
    echo "❌ Avatar script not found: $SCRIPT_FILE"
    echo "   The repository may be incomplete"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ LongCat-Video repository ready!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Run: bash scripts/deploy_longcat_video.sh"
echo "  2. This will install dependencies and download models (~40GB)"
