# Setup New VAST Instance - Complete Guide

## Step 1: Connect to New Instance

**On Desktop PowerShell or Terminal:**

```bash
# Use direct connection
ssh -p 41085 root@50.217.254.161

# Or use proxy if direct doesn't work
ssh -p 29105 root@ssh5.vast.ai
```

## Step 2: Initial Setup on New Instance

**On VAST Terminal (after SSH connection):**

```bash
# Update system
apt-get update && apt-get upgrade -y

# Install git if not present
apt-get install -y git

# Clone your project
cd ~
git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
cd Nextwork-Teachers-TechMonkey

# Pull latest changes
git pull origin main
```

## Step 3: Clone LongCat-Video

```bash
cd ~/Nextwork-Teachers-TechMonkey
git clone --single-branch --branch main https://github.com/meituan-longcat/LongCat-Video
```

## Step 4: Deploy LongCat-Video

```bash
cd ~/Nextwork-Teachers-TechMonkey
bash scripts/deploy_longcat_video.sh
```

This will:
- Create conda environment
- Install PyTorch, dependencies
- Download models (~40GB, takes 30-60 minutes)

## Step 5: Set Up Project Environment

```bash
cd ~/Nextwork-Teachers-TechMonkey

# Create .env file if needed
# Copy from ENV_EXAMPLE.md or create manually

# Install project dependencies (if any)
pip install -r requirements.txt
```

## Step 6: Verify Setup

```bash
# Check disk space
df -h

# Check models downloaded
ls -lh ~/Nextwork-Teachers-TechMonkey/LongCat-Video/weights/

# Check conda environment
conda activate longcat-video
python --version
python -c "import torch; print(f'PyTorch: {torch.__version__}')"
```

## Step 7: Update SSH Connection Scripts

**On Desktop PowerShell**, update your connection scripts with new ports:

- Direct: Port `41085`, IP `50.217.254.161`
- Proxy: Port `29105`, Host `ssh5.vast.ai`

## Next Steps

After setup is complete:
1. Add teacher images to `LongCat-Video/assets/avatars/`
2. Start LongCat-Video API service
3. Update n8n workflow
4. Test the integration
