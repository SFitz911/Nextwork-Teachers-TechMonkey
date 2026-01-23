# LongCat-Video-Avatar Integration Guide

## Overview

LongCat-Video-Avatar is a unified model that delivers expressive and highly dynamic audio-driven character animation. It supports:
- **Audio-Image-to-Video (ai2v)**: Generate video from an image + audio + text prompt
- **Audio-Text-to-Video (at2v)**: Generate video from text prompt + audio
- **Video Continuation**: Extend videos seamlessly

This is perfect for creating realistic talking avatars like Maya, Maximus, Krishna, TechMonkey Steve, and Pano Bieber.

## Repository Structure

```
LongCat-Video/
├── longcat_video/
│   ├── pipeline_longcat_video_avatar.py  # Main pipeline
│   └── ...
├── run_demo_avatar_single_audio_to_video.py  # Single character demo
├── run_demo_avatar_multi_audio_to_video.py    # Multi character demo
├── requirements.txt
├── requirements_avatar.txt
└── assets/avatar/
    └── single_example_1.json  # Example input format
```

## Requirements

### System Requirements
- **GPU**: CUDA-capable GPU (recommended: 2+ GPUs for best performance)
- **CUDA**: Version 12.4+
- **Python**: 3.10
- **RAM**: 32GB+ recommended
- **Storage**: ~50GB for models

### Dependencies
- PyTorch 2.6.0+cu124
- Flash Attention 2.7.4
- Transformers 4.41.0
- Diffusers 0.35.1
- Librosa, FFmpeg (for audio processing)
- Audio Separator (for vocal extraction)

## Model Download

Download the LongCat-Video-Avatar model from HuggingFace:

```bash
pip install "huggingface_hub[cli]"
huggingface-cli download meituan-longcat/LongCat-Video-Avatar --local-dir ./weights/LongCat-Video-Avatar
huggingface-cli download meituan-longcat/LongCat-Video --local-dir ./weights/LongCat-Video
```

## Integration Architecture

### Current Flow (n8n Workflow)
```
Webhook → Select Teacher → LLM Generate (parallel) → 
Merge → Select Response → TTS → Animation → Response
```

### New Flow (with LongCat-Video-Avatar)
```
Webhook → Select Teacher → LLM Generate (parallel) → 
Merge → Select Response → TTS → LongCat-Video-Avatar → Response
```

### API Service Wrapper

We'll create a FastAPI service wrapper (`services/longcat_video/app.py`) that:
1. Receives: `avatar_id`, `audio_url`, `text_prompt`
2. Maps `avatar_id` to teacher image (e.g., `teacher_a` → `maya.png`)
3. Calls LongCat-Video-Avatar pipeline
4. Returns: `video_url`, `job_id`

## Implementation Steps

### Step 1: Upload LongCat-Video to VAST Instance

**On Desktop PowerShell:**
```powershell
# Use the sync script to upload LongCat-Video directory
.\sync-to-vast.ps1
```

Or manually:
```bash
# On VAST Terminal
cd ~/Nextwork-Teachers-TechMonkey
git clone --single-branch --branch main https://github.com/meituan-longcat/LongCat-Video
```

### Step 2: Install Dependencies

**On VAST Terminal:**
```bash
cd ~/Nextwork-Teachers-TechMonkey/LongCat-Video

# Create conda environment
conda create -n longcat-video python=3.10 -y
conda activate longcat-video

# Install PyTorch (adjust CUDA version if needed)
pip install torch==2.6.0+cu124 torchvision==0.21.0+cu124 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124

# Install flash-attn-2
pip install ninja psutil packaging
pip install flash_attn==2.7.4.post1

# Install other requirements
pip install -r requirements.txt
pip install -r requirements_avatar.txt

# Install audio processing tools
conda install -c conda-forge librosa ffmpeg -y
```

### Step 3: Download Models

**On VAST Terminal:**
```bash
cd ~/Nextwork-Teachers-TechMonkey/LongCat-Video

# Install huggingface-cli
pip install "huggingface_hub[cli]"

# Download models (this will take time, ~40GB)
mkdir -p weights
huggingface-cli download meituan-longcat/LongCat-Video-Avatar --local-dir ./weights/LongCat-Video-Avatar
huggingface-cli download meituan-longcat/LongCat-Video --local-dir ./weights/LongCat-Video
```

### Step 4: Create API Service Wrapper

The service wrapper (`services/longcat_video/app.py`) will:
- Accept HTTP POST requests with `avatar_id`, `audio_url`, `text_prompt`
- Map avatar_id to image path
- Call LongCat-Video-Avatar pipeline
- Return video URL

### Step 5: Update n8n Workflow

Replace the "Animation Generate" node with a "LongCat-Video Generate" node that:
- Calls `http://localhost:8003/generate` (new service port)
- Passes: `avatar_id`, `audio_url`, `text_prompt`
- Receives: `video_url`, `job_id`

### Step 6: Teacher Image Setup

Place teacher images in `LongCat-Video/assets/avatars/`:
- `teacher_a.png` → Maya
- `teacher_b.png` → Maximus
- `teacher_c.png` → Krishna
- `teacher_d.png` → TechMonkey Steve
- `teacher_e.png` → Pano Bieber

## API Endpoints

### POST `/generate`
Generate video from image + audio + prompt

**Request:**
```json
{
  "avatar_id": "teacher_a",
  "audio_url": "http://localhost:8001/tts/audio.mp3",
  "text_prompt": "A warm and approachable educator speaking naturally",
  "resolution": "480p",
  "num_segments": 1
}
```

**Response:**
```json
{
  "video_url": "http://localhost:8003/video/abc123",
  "video_path": "/app/output/video_abc123.mp4",
  "job_id": "abc123",
  "status": "completed"
}
```

### GET `/video/{job_id}`
Stream generated video

### GET `/status`
Check service status and model availability

## Performance Considerations

### Generation Time
- **480p, 1 segment**: ~2-5 minutes (single GPU)
- **720p, 1 segment**: ~5-10 minutes (single GPU)
- **Multi-segment (long video)**: ~2-5 minutes per segment

### Optimization Tips
1. Use `--enable_compile` for faster inference
2. Use multi-GPU with `--context_parallel_size=2`
3. Use 480p for faster generation (720p for higher quality)
4. Cache model in memory for repeated requests

### Resource Usage
- **VRAM**: ~20-30GB per GPU
- **RAM**: ~10-15GB
- **Disk**: ~50GB for models

## Troubleshooting

### Common Issues

1. **CUDA Out of Memory**
   - Reduce resolution to 480p
   - Use fewer segments
   - Enable model offloading

2. **Audio Processing Errors**
   - Ensure FFmpeg is installed: `conda install -c conda-forge ffmpeg`
   - Check audio format (WAV, MP3 supported)

3. **Model Download Fails**
   - Check HuggingFace authentication: `huggingface-cli login`
   - Verify disk space: `df -h`

4. **Import Errors**
   - Ensure all requirements installed: `pip install -r requirements_avatar.txt`
   - Check Python version: `python --version` (should be 3.10)

## Next Steps

1. ✅ Clone repository
2. ✅ Install dependencies
3. ✅ Download models
4. ⏳ Create API service wrapper
5. ⏳ Update n8n workflow
6. ⏳ Test integration
7. ⏳ Deploy to production

## References

- [LongCat-Video-Avatar Project Page](https://meigen-ai.github.io/LongCat-Video-Avatar/)
- [LongCat-Video-Avatar HuggingFace](https://huggingface.co/meituan-longcat/LongCat-Video-Avatar)
- [Technical Report](https://github.com/meituan-longcat/LongCat-Video/blob/main/assets/LongCat-Video-Avatar-Tech-Report.pdf)
