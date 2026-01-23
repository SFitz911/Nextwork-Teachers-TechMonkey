#!/bin/bash
# Complete setup script for new VAST instance
# Run this after SSH'ing into your new instance

set -e

echo "=========================================="
echo "Setting Up New VAST Instance"
echo "=========================================="
echo ""

# Step 1: Update system
echo "Step 1: Updating system..."
apt-get update -y
apt-get upgrade -y

# Step 2: Install essential tools
echo "Step 2: Installing essential tools..."
apt-get install -y git curl wget vim tmux python3 python3-pip python3-venv

# Step 2a: Install Node.js and n8n
echo "Step 2a: Installing Node.js and n8n..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi
if ! command -v n8n &> /dev/null; then
    npm install -g n8n
fi

# Step 2b: Install Ollama
echo "Step 2b: Installing Ollama..."
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
fi

# Start Ollama service
echo "   Starting Ollama service..."
ollama serve > /tmp/ollama.log 2>&1 &
sleep 5

# Install mistral:7b model
echo "   Installing mistral:7b model (this may take 5-10 minutes)..."
ollama pull mistral:7b
echo "✅ mistral:7b model installed"

# Step 3: Install conda if not present
if ! command -v conda &> /dev/null; then
    echo "Step 3: Installing Miniconda..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p $HOME/miniconda3
    export PATH="$HOME/miniconda3/bin:$PATH"
    conda init bash
    source ~/.bashrc
else
    echo "Step 3: Conda already installed"
fi

# Step 4: Clone project
echo "Step 4: Cloning project..."
if [ ! -d "$HOME/Nextwork-Teachers-TechMonkey" ]; then
    cd ~
    git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
else
    echo "Project already exists, pulling latest..."
    cd ~/Nextwork-Teachers-TechMonkey
    git pull origin main
fi

# Step 5: Clone LongCat-Video
echo "Step 5: Cloning LongCat-Video..."
cd ~/Nextwork-Teachers-TechMonkey
if [ ! -d "LongCat-Video" ]; then
    git clone --single-branch --branch main https://github.com/meituan-longcat/LongCat-Video
else
    echo "LongCat-Video already exists"
fi

# Step 6: Check disk space
echo ""
echo "Step 6: Checking disk space..."
df -h
echo ""
echo "Available space check complete."
echo "You need at least 100GB free for models (40GB) + system + headroom"
echo ""

# Step 7: Deploy LongCat-Video
echo "Step 7: Deploying LongCat-Video..."
echo "This will take 30-60 minutes for model downloads..."
cd ~/Nextwork-Teachers-TechMonkey
bash scripts/deploy_longcat_video.sh

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Add teacher images to: ~/Nextwork-Teachers-TechMonkey/LongCat-Video/assets/avatars/"
echo "2. Start LongCat-Video service: python services/longcat_video/app.py"
echo "3. Update n8n workflow to use new instance"
echo ""
