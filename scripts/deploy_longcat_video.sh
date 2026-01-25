#!/bin/bash
# Deploy LongCat-Video-Avatar to VAST instance
# This script sets up LongCat-Video-Avatar for integration with n8n workflow

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LONGCAT_DIR="$PROJECT_ROOT/LongCat-Video"

echo "=========================================="
echo "Deploying LongCat-Video-Avatar"
echo "=========================================="

# Check if LongCat-Video directory exists
if [ ! -d "$LONGCAT_DIR" ]; then
    echo "❌ LongCat-Video directory not found at $LONGCAT_DIR"
    echo "Please clone it first:"
    echo "  cd $PROJECT_ROOT"
    echo "  git clone --single-branch --branch main https://github.com/meituan-longcat/LongCat-Video"
    exit 1
fi

cd "$LONGCAT_DIR"

# Check if conda environment exists
if ! conda env list | grep -q "longcat-video"; then
    echo "Creating conda environment 'longcat-video'..."
    conda create -n longcat-video python=3.10 -y
fi

echo "Activating conda environment..."
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate longcat-video

# Install PyTorch FIRST (required for flash-attn)
echo "Installing PyTorch..."
pip install torch==2.6.0+cu124 torchvision==0.21.0+cu124 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124

# Install build dependencies for flash-attn
echo "Installing build dependencies..."
pip install ninja psutil packaging

# Install requirements EXCEPT flash-attn (we'll install it separately)
echo "Installing requirements (excluding flash-attn)..."
pip install -r requirements.txt --no-deps || true
# Reinstall without --no-deps to get dependencies
pip install $(grep -v "flash-attn" requirements.txt | grep -v "^#" | grep -v "^$" | tr '\n' ' ') || true

# Install flash-attn separately (needs PyTorch to be installed first)
echo "Installing Flash Attention..."
pip install flash_attn==2.7.4.post1 || echo "[WARNING] Flash Attention installation may have failed, continuing..."

# Install avatar requirements
echo "Installing avatar requirements..."
pip install -r requirements_avatar.txt

# Install audio processing tools
echo "Installing audio processing tools..."
conda install -c conda-forge librosa ffmpeg -y

# Check if models are downloaded
WEIGHTS_DIR="$LONGCAT_DIR/weights"
AVATAR_MODEL_DIR="$WEIGHTS_DIR/LongCat-Video-Avatar"
BASE_MODEL_DIR="$WEIGHTS_DIR/LongCat-Video"

if [ ! -d "$AVATAR_MODEL_DIR" ] || [ ! -d "$BASE_MODEL_DIR" ]; then
    echo "⚠️  Models not found. Downloading models..."
    echo "This will take a while (~40GB download)..."
    
    mkdir -p "$WEIGHTS_DIR"
    
    # Install huggingface-cli if not present
    pip install "huggingface_hub[cli]"
    
    # Download models
    echo "Downloading LongCat-Video-Avatar..."
    huggingface-cli download meituan-longcat/LongCat-Video-Avatar --local-dir "$AVATAR_MODEL_DIR"
    
    echo "Downloading LongCat-Video base model..."
    huggingface-cli download meituan-longcat/LongCat-Video --local-dir "$BASE_MODEL_DIR"
    
    echo "✅ Models downloaded"
else
    echo "✅ Models already downloaded"
fi

# Create avatar images directory
AVATAR_IMAGES_DIR="$LONGCAT_DIR/assets/avatars"
mkdir -p "$AVATAR_IMAGES_DIR"

# Copy avatar images from Nextwork-Teachers if they exist
echo "Setting up avatar images..."
if [[ -d "$PROJECT_ROOT/Nextwork-Teachers" ]]; then
    echo "Copying teacher images from Nextwork-Teachers..."
    bash "$PROJECT_ROOT/scripts/fix_avatar_images.sh" || echo "⚠️  Avatar image setup had issues, but continuing..."
else
    echo "⚠️  Nextwork-Teachers directory not found. Avatar images will need to be added manually."
    echo "   Expected location: $AVATAR_IMAGES_DIR"
fi

echo "=========================================="
echo "✅ LongCat-Video-Avatar deployment complete!"
echo "=========================================="
echo ""
echo "Avatar images should be in: $AVATAR_IMAGES_DIR"
echo "   - maya.png (teacher_a)"
echo "   - maximus.png (teacher_b)"
echo "   - krishna.png (teacher_c)"
echo "   - techmonkey_steve.png (teacher_d)"
echo "   - pano_bieber.png (teacher_e)"
echo ""
echo "Next steps:"
echo "1. Start the API service:"
echo "   cd $PROJECT_ROOT"
echo "   conda activate longcat-video"
echo "   python services/longcat_video/app.py"
echo ""
echo "2. Update n8n workflow to use LongCat-Video-Avatar service"
echo "   (port 8003 instead of animation service on 8002)"
