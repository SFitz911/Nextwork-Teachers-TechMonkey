#!/usr/bin/env bash
# Script to convert Krishna's image from JPG to PNG on VAST instance
# Usage: bash scripts/convert_krishna_png.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

AVATAR_DIR="$PROJECT_DIR/services/animation/avatars"

echo "=========================================="
echo "Converting Krishna's Image to PNG"
echo "=========================================="
echo ""

# Check if teacher_c files exist
if [ ! -f "$AVATAR_DIR/teacher_c.jpg" ] && [ ! -f "$AVATAR_DIR/teacher_c.png" ]; then
    echo "Error: teacher_c image not found in $AVATAR_DIR"
    exit 1
fi

# Check if Python PIL/Pillow is available
if ! python3 -c "from PIL import Image" 2>/dev/null; then
    echo "Installing Pillow for image conversion..."
    pip install Pillow
fi

# Convert JPG to PNG if JPG exists
if [ -f "$AVATAR_DIR/teacher_c.jpg" ]; then
    echo "Converting teacher_c.jpg to PNG..."
    python3 << 'PYTHON'
from PIL import Image
import os

avatar_dir = "services/animation/avatars"
jpg_path = os.path.join(avatar_dir, "teacher_c.jpg")
png_path = os.path.join(avatar_dir, "teacher_c.png")

if os.path.exists(jpg_path):
    img = Image.open(jpg_path)
    img.save(png_path, "PNG")
    print(f"Converted {jpg_path} to {png_path}")
    
    # Remove old JPG file
    os.remove(jpg_path)
    print(f"Removed {jpg_path}")
else:
    print(f"{jpg_path} not found")
PYTHON
    
    echo "Conversion complete!"
elif [ -f "$AVATAR_DIR/teacher_c.png" ]; then
    echo "teacher_c.png already exists - no conversion needed"
else
    echo "Error: Could not find teacher_c image"
    exit 1
fi

# Verify the PNG file exists
if [ -f "$AVATAR_DIR/teacher_c.png" ]; then
    echo ""
    echo "Verifying PNG file..."
    file "$AVATAR_DIR/teacher_c.png"
    ls -lh "$AVATAR_DIR/teacher_c.png"
    echo ""
    echo "Krishna's image is now in PNG format!"
    echo "You may need to refresh the frontend to see the update."
else
    echo "Error: PNG file was not created"
    exit 1
fi
