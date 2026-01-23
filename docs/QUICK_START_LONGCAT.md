# Quick Start: LongCat-Video-Avatar Setup

## Step 1: Get LongCat-Video on VAST

**📍 Terminal: VAST Terminal** (where you are now)

```bash
cd ~/Nextwork-Teachers-TechMonkey
git pull origin main
git clone --single-branch --branch main https://github.com/meituan-longcat/LongCat-Video
```

## Step 2: Deploy LongCat-Video

**📍 Terminal: VAST Terminal** (same session)

```bash
bash scripts/deploy_longcat_video.sh
```

This will:
- Create conda environment
- Install all dependencies
- Download models (~40GB, takes 30-60 minutes)

## Step 3: Add Teacher Images

**📍 Terminal: VAST Terminal**

```bash
mkdir -p ~/Nextwork-Teachers-TechMonkey/LongCat-Video/assets/avatars
# Then upload your teacher images here:
# - maya.png (teacher_a)
# - maximus.png (teacher_b)
# - krishna.png (teacher_c)
# - techmonkey_steve.png (teacher_d)
# - pano_bieber.png (teacher_e)
```

## Step 4: Start Service

**📍 Terminal: VAST Terminal** (in tmux)

```bash
tmux new -s longcat-video
conda activate longcat-video
cd ~/Nextwork-Teachers-TechMonkey
export LONGCAT_VIDEO_DIR="$HOME/Nextwork-Teachers-TechMonkey/LongCat-Video"
export CHECKPOINT_DIR="$LONGCAT_VIDEO_DIR/weights/LongCat-Video-Avatar"
export AVATAR_IMAGES_DIR="$LONGCAT_VIDEO_DIR/assets/avatars"
export OUTPUT_DIR="$HOME/Nextwork-Teachers-TechMonkey/outputs/longcat"
mkdir -p $OUTPUT_DIR
python services/longcat_video/app.py
# Press Ctrl+B, then D to detach
```

## Step 5: Update n8n Workflow

**📍 Browser: http://localhost:5678** (with port forwarding active)

1. Open n8n workflow
2. Find "Animation Generate" node
3. Change URL to: `http://localhost:8003/generate`
4. Update body to:
   ```json
   {
     "avatar_id": "={{ $json.avatar_id }}",
     "audio_url": "={{ $json.audio_url }}",
     "text_prompt": "={{ $json.text }}"
   }
   ```

## That's it!

Your workflow will now use LongCat-Video-Avatar for realistic talking videos.
