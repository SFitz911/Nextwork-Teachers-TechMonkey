#!/usr/bin/env bash
# Script to verify Krishna's image and restart animation service
# Usage: bash scripts/verify_and_fix_krishna.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

AVATAR_DIR="$PROJECT_DIR/services/animation/avatars"

echo "=========================================="
echo "Verifying Krishna's Image"
echo "=========================================="
echo ""

# Check what files exist
echo "Checking avatar files..."
ls -lh "$AVATAR_DIR"/teacher_*.{jpg,png} 2>/dev/null || echo "No teacher files found"

echo ""
echo "Checking specifically for teacher_c..."
if [ -f "$AVATAR_DIR/teacher_c.png" ]; then
    echo "✅ teacher_c.png exists"
    ls -lh "$AVATAR_DIR/teacher_c.png"
    
    # Check file size (should be > 0)
    SIZE=$(stat -f%z "$AVATAR_DIR/teacher_c.png" 2>/dev/null || stat -c%s "$AVATAR_DIR/teacher_c.png" 2>/dev/null || echo "0")
    if [ "$SIZE" -gt 0 ]; then
        echo "✅ File size: $SIZE bytes (valid)"
    else
        echo "❌ File size is 0 - file may be corrupted"
    fi
elif [ -f "$AVATAR_DIR/teacher_c.jpg" ]; then
    echo "⚠️  teacher_c.jpg exists (should be PNG)"
    echo "Converting to PNG..."
    
    # Install Pillow if needed
    if ! python3 -c "from PIL import Image" 2>/dev/null; then
        echo "Installing Pillow..."
        pip install Pillow
    fi
    
    # Convert
    python3 << 'PYTHON'
from PIL import Image
import os

avatar_dir = "services/animation/avatars"
jpg_path = os.path.join(avatar_dir, "teacher_c.jpg")
png_path = os.path.join(avatar_dir, "teacher_c.png")

if os.path.exists(jpg_path):
    img = Image.open(jpg_path)
    img.save(png_path, "PNG")
    print(f"✅ Converted {jpg_path} to {png_path}")
    os.remove(jpg_path)
    print(f"✅ Removed {jpg_path}")
else:
    print(f"❌ {jpg_path} not found")
PYTHON
else
    echo "❌ Neither teacher_c.png nor teacher_c.jpg found!"
    exit 1
fi

echo ""
echo "Testing animation service endpoint..."
echo "Testing: http://localhost:8002/avatar/teacher_c"

# Test if animation service is running
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8002/avatar/teacher_c | grep -q "200"; then
    echo "✅ Animation service is serving the image"
else
    echo "⚠️  Animation service may not be running or image not accessible"
    echo "Restarting animation service..."
    
    # Kill existing animation service
    pkill -f "python.*animation/app.py" || true
    sleep 2
    
    # Start animation service
    source /root/ai-teacher-venv/bin/activate
    export AVATAR_PATH="$PROJECT_DIR/services/animation/avatars"
    mkdir -p "$PROJECT_DIR/services/animation/output"
    
    cd "$PROJECT_DIR"
    nohup python services/animation/app.py > logs/animation.log 2>&1 &
    
    echo "Waiting for service to start..."
    sleep 3
    
    # Test again
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8002/avatar/teacher_c | grep -q "200"; then
        echo "✅ Animation service is now serving the image"
    else
        echo "❌ Still having issues. Check logs: tail -20 logs/animation.log"
    fi
fi

echo ""
echo "=========================================="
echo "Verification complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Refresh your browser at http://localhost:8501"
echo "2. Clear browser cache if image still doesn't show (Ctrl+Shift+R)"
echo "3. Check frontend logs: tail -20 logs/frontend.log"
