# LongCat-Video-Avatar Setup Guide - Step by Step

## Overview
This guide walks you through integrating LongCat-Video-Avatar to generate realistic talking videos of your teachers (Maya, Maximus, Krishna, TechMonkey Steve, Pano Bieber).

---

## Step 1: Upload LongCat-Video to VAST Instance

**📍 Terminal: Desktop PowerShell** (Your current window is fine!)

### Option A: Use the Sync Script (Recommended)

1. **Check your SSH environment variables:**
   ```powershell
   # In your PowerShell window, check if these are set:
   $env:VAST_SSH_HOST
   $env:VAST_SSH_USER
   $env:VAST_SSH_PORT
   ```

2. **If not set, set them:**
   ```powershell
   # Replace with your actual VAST instance details
   $env:VAST_SSH_HOST = "your-vast-instance.com"  # e.g., "ssh.vast.ai"
   $env:VAST_SSH_USER = "root"
   $env:VAST_SSH_PORT = "22"
   ```

3. **Run the sync script:**
   ```powershell
   cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey
   .\scripts\sync_longcat_to_vast.ps1
   ```

   This will:
   - Sync the `LongCat-Video` directory to your VAST instance
   - Exclude large files (weights) - we'll download those separately
   - Show progress as it uploads

### Option B: Clone Directly on VAST (Alternative)

If the sync script doesn't work, you can clone directly on VAST:

**📍 Terminal: VAST Terminal** (SSH into your VAST instance)

```bash
cd ~/Nextwork-Teachers-TechMonkey
git clone --single-branch --branch main https://github.com/meituan-longcat/LongCat-Video
```

---

## Step 2: Deploy LongCat-Video on VAST

**📍 Terminal: VAST Terminal** (SSH into your VAST instance)

1. **Navigate to project directory:**
   ```bash
   cd ~/Nextwork-Teachers-TechMonkey
   ```

2. **Pull latest changes:**
   ```bash
   git pull origin main
   ```

3. **Run the deployment script:**
   ```bash
   bash scripts/deploy_longcat_video.sh
   ```

   This script will:
   - ✅ Create conda environment `longcat-video` with Python 3.10
   - ✅ Install PyTorch 2.6.0 with CUDA 12.4 support
   - ✅ Install Flash Attention 2.7.4
   - ✅ Install all Python dependencies
   - ✅ Install audio processing tools (librosa, ffmpeg)
   - ⏳ Download models (~40GB - this takes 30-60 minutes)

   **Note:** The model download is the longest step. You can monitor progress, but it's safe to let it run.

4. **Verify installation:**
   ```bash
   conda activate longcat-video
   python --version  # Should show Python 3.10
   pip list | grep torch  # Should show torch 2.6.0
   ```

---

## Step 3: Prepare Teacher Images

**📍 Terminal: VAST Terminal**

1. **Create avatars directory:**
   ```bash
   mkdir -p ~/Nextwork-Teachers-TechMonkey/LongCat-Video/assets/avatars
   ```

2. **Upload teacher images:**
   
   You need to place images of your teachers in the avatars directory:
   - `maya.png` (for teacher_a)
   - `maximus.png` (for teacher_b)
   - `krishna.png` (for teacher_c)
   - `techmonkey_steve.png` (for teacher_d)
   - `pano_bieber.png` (for teacher_e)

   **Option A: Upload from Desktop PowerShell**
   ```powershell
   # Use SCP to upload images
   scp -P $env:VAST_SSH_PORT "path\to\maya.png" "$($env:VAST_SSH_USER)@$($env:VAST_SSH_HOST):~/Nextwork-Teachers-TechMonkey/LongCat-Video/assets/avatars/maya.png"
   # Repeat for each teacher image
   ```

   **Option B: Use existing images if you have them**
   ```bash
   # On VAST, if you already have teacher images elsewhere:
   cp /path/to/existing/maya.png ~/Nextwork-Teachers-TechMonkey/LongCat-Video/assets/avatars/
   ```

3. **Verify images are in place:**
   ```bash
   ls -la ~/Nextwork-Teachers-TechMonkey/LongCat-Video/assets/avatars/
   # Should show all 5 teacher images
   ```

---

## Step 4: Start the LongCat-Video API Service

**📍 Terminal: VAST Terminal**

1. **Navigate to project:**
   ```bash
   cd ~/Nextwork-Teachers-TechMonkey
   ```

2. **Activate conda environment:**
   ```bash
   conda activate longcat-video
   ```

3. **Set environment variables:**
   ```bash
   export LONGCAT_VIDEO_DIR="$HOME/Nextwork-Teachers-TechMonkey/LongCat-Video"
   export CHECKPOINT_DIR="$LONGCAT_VIDEO_DIR/weights/LongCat-Video-Avatar"
   export AVATAR_IMAGES_DIR="$LONGCAT_VIDEO_DIR/assets/avatars"
   export OUTPUT_DIR="$HOME/Nextwork-Teachers-TechMonkey/outputs/longcat"
   mkdir -p $OUTPUT_DIR
   ```

4. **Start the service:**
   ```bash
   python services/longcat_video/app.py
   ```

   The service will start on port **8003**.

5. **Test the service (in another terminal):**
   ```bash
   curl http://localhost:8003/status
   ```

   Should return:
   ```json
   {
     "status": "ready",
     "model_exists": true,
     ...
   }
   ```

6. **Keep service running:**
   - If using tmux (recommended):
     ```bash
     # Create new tmux session
     tmux new -s longcat-video
     # Inside tmux, run the service
     conda activate longcat-video
     python services/longcat_video/app.py
     # Press Ctrl+B, then D to detach
     ```

---

## Step 5: Update n8n Workflow

**📍 Terminal: Desktop PowerShell** (or use n8n UI directly)

### Option A: Update via n8n UI (Easier)

1. **Open n8n in browser:**
   - Make sure port forwarding is active: `.\connect-vast.ps1`
   - Open: http://localhost:5678

2. **Edit the workflow:**
   - Find the "Animation Generate" node
   - Change the URL from `http://localhost:8002/animate` to `http://localhost:8003/generate`
   - Update the request body to:
     ```json
     {
       "avatar_id": "={{ $json.avatar_id }}",
       "audio_url": "={{ $json.audio_url }}",
       "text_prompt": "={{ $json.text }}"
     }
     ```
   - Save and activate the workflow

### Option B: Update Workflow JSON (Advanced)

If you prefer to update the JSON directly, I can help modify `n8n/workflows/five-teacher-workflow.json`.

---

## Step 6: Test the Integration

**📍 Terminal: Desktop PowerShell**

1. **Ensure port forwarding is active:**
   ```powershell
   .\connect-vast.ps1
   ```

2. **Test the frontend:**
   - Open: http://localhost:8501
   - Send a chat message
   - The workflow should now use LongCat-Video-Avatar instead of the old animation service

3. **Check n8n executions:**
   - Open: http://localhost:5678
   - Go to Executions
   - Verify the "LongCat-Video Generate" node completes successfully

---

## Troubleshooting

### Issue: "Models not found"
**Solution:** Make sure models downloaded successfully:
```bash
ls -la ~/Nextwork-Teachers-TechMonkey/LongCat-Video/weights/
# Should show LongCat-Video-Avatar and LongCat-Video directories
```

### Issue: "CUDA out of memory"
**Solution:** Reduce resolution or use fewer segments:
- In the API request, set `"resolution": "480p"` (instead of 720p)
- Set `"num_segments": 1` (instead of multiple segments)

### Issue: "Avatar image not found"
**Solution:** Verify images are in the correct location:
```bash
ls -la ~/Nextwork-Teachers-TechMonkey/LongCat-Video/assets/avatars/
```

### Issue: Service won't start
**Solution:** Check conda environment is activated:
```bash
conda activate longcat-video
which python  # Should show path with longcat-video
```

---

## Summary Checklist

- [ ] Step 1: Uploaded LongCat-Video to VAST (Desktop PowerShell)
- [ ] Step 2: Deployed LongCat-Video on VAST (VAST Terminal)
- [ ] Step 3: Added teacher images (VAST Terminal)
- [ ] Step 4: Started API service on port 8003 (VAST Terminal)
- [ ] Step 5: Updated n8n workflow (n8n UI or JSON)
- [ ] Step 6: Tested integration (Desktop PowerShell)

---

## Next Steps After Setup

1. **Monitor performance:** Video generation takes 2-5 minutes per request
2. **Optimize settings:** Adjust resolution, segments, and guidance scales
3. **Scale up:** Consider using multiple GPUs for faster generation
4. **Cache models:** Keep models loaded in memory for faster subsequent requests

---

## Need Help?

If you encounter issues:
1. Check the logs: `tail -f ~/Nextwork-Teachers-TechMonkey/outputs/longcat/*.log`
2. Verify service status: `curl http://localhost:8003/status`
3. Check n8n executions for error details
