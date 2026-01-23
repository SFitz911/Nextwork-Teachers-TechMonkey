#!/usr/bin/env bash
# Fix avatar image filenames to match expected format
# Usage: bash scripts/fix_avatar_images.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

SOURCE_DIR="$PROJECT_DIR/Nextwork-Teachers"
TARGET_DIR="$PROJECT_DIR/LongCat-Video/assets/avatars"

echo "=========================================="
echo "Fixing Avatar Image Filenames"
echo "=========================================="
echo ""

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Copy and rename images to match expected format
echo "Copying and renaming images..."

# teacher_a -> maya.png
if [[ -f "$SOURCE_DIR/Maya.png" ]]; then
    cp "$SOURCE_DIR/Maya.png" "$TARGET_DIR/maya.png"
    echo "✅ Copied Maya.png → maya.png"
elif [[ -f "$SOURCE_DIR/maya.png" ]]; then
    cp "$SOURCE_DIR/maya.png" "$TARGET_DIR/maya.png"
    echo "✅ Copied maya.png → maya.png"
else
    echo "⚠️  Maya.png not found in $SOURCE_DIR"
fi

# teacher_b -> maximus.png
if [[ -f "$SOURCE_DIR/Maximus.png" ]]; then
    cp "$SOURCE_DIR/Maximus.png" "$TARGET_DIR/maximus.png"
    echo "✅ Copied Maximus.png → maximus.png"
elif [[ -f "$SOURCE_DIR/maximus.png" ]]; then
    cp "$SOURCE_DIR/maximus.png" "$TARGET_DIR/maximus.png"
    echo "✅ Copied maximus.png → maximus.png"
else
    echo "⚠️  Maximus.png not found in $SOURCE_DIR"
fi

# teacher_c -> krishna.png
if [[ -f "$SOURCE_DIR/krishna.png" ]]; then
    cp "$SOURCE_DIR/krishna.png" "$TARGET_DIR/krishna.png"
    echo "✅ Copied krishna.png → krishna.png"
elif [[ -f "$SOURCE_DIR/Krishna.png" ]]; then
    cp "$SOURCE_DIR/Krishna.png" "$TARGET_DIR/krishna.png"
    echo "✅ Copied Krishna.png → krishna.png"
else
    echo "⚠️  krishna.png not found in $SOURCE_DIR"
fi

# teacher_d -> techmonkey_steve.png
if [[ -f "$SOURCE_DIR/TechMonkey Steve.png" ]]; then
    cp "$SOURCE_DIR/TechMonkey Steve.png" "$TARGET_DIR/techmonkey_steve.png"
    echo "✅ Copied TechMonkey Steve.png → techmonkey_steve.png"
elif [[ -f "$SOURCE_DIR/techmonkey_steve.png" ]]; then
    cp "$SOURCE_DIR/techmonkey_steve.png" "$TARGET_DIR/techmonkey_steve.png"
    echo "✅ Copied techmonkey_steve.png → techmonkey_steve.png"
else
    echo "⚠️  TechMonkey Steve.png not found in $SOURCE_DIR"
fi

# teacher_e -> pano_bieber.png
if [[ -f "$SOURCE_DIR/Pano Bieber.png" ]]; then
    cp "$SOURCE_DIR/Pano Bieber.png" "$TARGET_DIR/pano_bieber.png"
    echo "✅ Copied Pano Bieber.png → pano_bieber.png"
elif [[ -f "$SOURCE_DIR/pano_bieber.png" ]]; then
    cp "$SOURCE_DIR/pano_bieber.png" "$TARGET_DIR/pano_bieber.png"
    echo "✅ Copied pano_bieber.png → pano_bieber.png"
else
    echo "⚠️  Pano Bieber.png not found in $SOURCE_DIR"
fi

echo ""
echo "Verifying all images are in place..."
REQUIRED_IMAGES=("maya.png" "maximus.png" "krishna.png" "techmonkey_steve.png" "pano_bieber.png")
ALL_PRESENT=true

for img in "${REQUIRED_IMAGES[@]}"; do
    if [[ -f "$TARGET_DIR/$img" ]]; then
        echo "✅ $img exists"
    else
        echo "❌ $img MISSING"
        ALL_PRESENT=false
    fi
done

echo ""
if [[ "$ALL_PRESENT" == true ]]; then
    echo "=========================================="
    echo "✅ All avatar images are in place!"
    echo "=========================================="
else
    echo "=========================================="
    echo "⚠️  Some images are missing"
    echo "=========================================="
    exit 1
fi
