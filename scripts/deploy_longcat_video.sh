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
# Initialize conda for bash
CONDA_BASE=$(conda info --base)
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate longcat-video

# CRITICAL: Verify we're in the right environment
PYTHON_PATH=$(which python)
PYTHON_VERSION=$(python --version 2>&1)
echo "Python location: $PYTHON_PATH"
echo "Python version: $PYTHON_VERSION"

# Check if we're actually in conda environment
if [[ ! "$PYTHON_PATH" == *"longcat-video"* ]] && [[ ! "$PYTHON_PATH" == *"conda"* ]]; then
    echo "❌ ERROR: Not in conda longcat-video environment!"
    echo "   Python path: $PYTHON_PATH"
    echo "   Expected: .../conda/envs/longcat-video/..."
    echo ""
    echo "Please run:"
    echo "  source $(conda info --base)/etc/profile.d/conda.sh"
    echo "  conda activate longcat-video"
    echo "  bash scripts/deploy_longcat_video.sh"
    exit 1
fi

# Verify Python version is 3.10
if [[ ! "$PYTHON_VERSION" == *"3.10"* ]]; then
    echo "❌ ERROR: Wrong Python version! Need Python 3.10, got: $PYTHON_VERSION"
    echo "   Please recreate conda environment:"
    echo "   conda create -n longcat-video python=3.10 -y"
    exit 1
fi

# Install system dependencies first
echo "Installing system dependencies..."
apt-get update -qq
apt-get install -y libsndfile1 ffmpeg build-essential gcc g++ >/dev/null 2>&1 || echo "⚠️  System package installation had issues, continuing..."

# Install PyTorch FIRST (required for flash-attn)
echo "Installing PyTorch..."
pip install torch==2.6.0+cu124 torchvision==0.21.0+cu124 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124

# Verify PyTorch installation
echo "Verifying PyTorch installation..."
python -c "import torch; print(f'PyTorch version: {torch.__version__}')" || echo "⚠️  PyTorch verification failed"

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

# Install avatar requirements (skip libsndfile1 - it's a system package)
echo "Installing avatar requirements..."
# Filter out problematic packages: libsndfile1 (system package), tritonserverclient (not available)
grep -v "^#" requirements_avatar.txt | grep -v "^$" | grep -v "libsndfile1" | grep -v "tritonserverclient" | pip install -r /dev/stdin || {
    echo "⚠️  Some avatar requirements failed, trying essential packages only..."
    pip install scikit-learn==1.6.1 scikit-image==0.25.2 scipy==1.15.3 soundfile==0.13.1 soxr==0.5.0.post1 librosa==0.11.0 sympy==1.13.1 audio-separator==0.30.2 pyloudnorm==0.1.1 nvidia-ml-py==13.580.65 tzdata==2025.2 onnx==1.18.0 onnxruntime==1.16.3 openai==1.75.0 numpy==1.26.4 cffi==2.0.0 chardet==5.2.0 || echo "⚠️  Some packages failed, but continuing..."
}

# Verify critical dependencies are installed
echo "Verifying critical dependencies..."
CRITICAL_DEPS=("pyloudnorm" "audio_separator" "librosa" "soundfile")
MISSING_DEPS=()
for dep in "${CRITICAL_DEPS[@]}"; do
    if ! python -c "import ${dep//-/_}" 2>/dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo "⚠️  Missing critical dependencies: ${MISSING_DEPS[*]}"
    echo "   Installing missing dependencies..."
    for dep in "${MISSING_DEPS[@]}"; do
        case "$dep" in
            "audio_separator")
                pip install audio-separator==0.30.2 || echo "⚠️  Failed to install audio-separator"
                ;;
            "pyloudnorm")
                pip install pyloudnorm==0.1.1 || echo "⚠️  Failed to install pyloudnorm"
                ;;
            "librosa")
                pip install librosa==0.11.0 || conda install -c conda-forge librosa -y || echo "⚠️  Failed to install librosa"
                ;;
            "soundfile")
                pip install soundfile==0.13.1 || echo "⚠️  Failed to install soundfile"
                ;;
        esac
    done
    
    # Verify again
    echo "Re-verifying dependencies..."
    for dep in "${MISSING_DEPS[@]}"; do
        if python -c "import ${dep//-/_}" 2>/dev/null; then
            echo "   ✅ $dep installed successfully"
        else
            echo "   ❌ $dep still missing!"
        fi
    done
else
    echo "✅ All critical dependencies verified"
fi

# Install audio processing tools via conda (librosa, ffmpeg)
echo "Installing audio processing tools via conda..."
conda install -c conda-forge librosa ffmpeg -y >/dev/null 2>&1 || echo "⚠️  Conda audio tools installation had issues, continuing..."

# Check if models are downloaded
WEIGHTS_DIR="$LONGCAT_DIR/weights"
AVATAR_MODEL_DIR="$WEIGHTS_DIR/LongCat-Video-Avatar"
BASE_MODEL_DIR="$WEIGHTS_DIR/LongCat-Video"

if [ ! -d "$AVATAR_MODEL_DIR" ] || [ ! -d "$BASE_MODEL_DIR" ]; then
    echo "⚠️  Models not found. Downloading models..."
    echo "This will take a while (~40GB download)..."
    
    mkdir -p "$WEIGHTS_DIR"
    
    # Install huggingface-cli if not present (in conda environment)
    echo "Installing huggingface-cli..."
    pip install "huggingface_hub[cli]" || {
        echo "⚠️  Failed to install huggingface-cli, trying alternative method..."
        pip install huggingface_hub
    }
    
    # Verify huggingface-cli is available
    if ! command -v huggingface-cli >/dev/null 2>&1; then
        echo "⚠️  huggingface-cli not in PATH, using python -m huggingface_hub.cli instead"
        HF_CLI="python -m huggingface_hub.cli"
    else
        HF_CLI="huggingface-cli"
    fi
    
    # Download models
    echo "Downloading LongCat-Video-Avatar..."
    $HF_CLI download meituan-longcat/LongCat-Video-Avatar --local-dir "$AVATAR_MODEL_DIR"
    
    echo "Downloading LongCat-Video base model..."
    $HF_CLI download meituan-longcat/LongCat-Video --local-dir "$BASE_MODEL_DIR"
    
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

# Install LongCat-Video API service dependencies
echo "Installing LongCat-Video API service dependencies..."
if [[ -f "$PROJECT_ROOT/services/longcat_video/requirements.txt" ]]; then
    pip install -r "$PROJECT_ROOT/services/longcat_video/requirements.txt" || echo "⚠️  Some API service dependencies failed, but continuing..."
    
    # Verify critical API dependencies
    if python -c "import fastapi" 2>/dev/null; then
        echo "✅ FastAPI installed"
    else
        echo "⚠️  FastAPI not found, installing..."
        pip install fastapi==0.104.1 "uvicorn[standard]==0.24.0" httpx==0.25.2 pydantic==2.5.0 || echo "⚠️  Failed to install API dependencies"
    fi
else
    echo "⚠️  API service requirements.txt not found, installing minimal dependencies..."
    pip install fastapi==0.104.1 "uvicorn[standard]==0.24.0" httpx==0.25.2 pydantic==2.5.0 || echo "⚠️  Failed to install API dependencies"
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
