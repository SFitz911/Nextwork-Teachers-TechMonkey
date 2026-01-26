# Complete Download & Installation Checklist

This document lists **everything** that needs to be downloaded/installed on a fresh VAST instance to get back to where you were.


cd ~/Nextwork-Teachers-TechMonkey

# Make it executable
chmod +x master_setup-01.sh

# Run it (one click!)
bash master_setup-01.sh


---



## 📦 What Gets Downloaded/Installed

### 1. **System Packages** (via `apt-get`)
- Python 3, pip, venv
- Node.js v20
- FFmpeg, libsndfile1
- tmux, redis-server
- build-essential, gcc, g++ (for compiling Python packages)
- **Size:** ~500MB
- **Time:** 2-5 minutes

### 2. **n8n** (Workflow Automation)
- Installed via: `npm install -g n8n`
- **Size:** ~100MB
- **Time:** 1-2 minutes

### 3. **Ollama** (LLM Service)
- Installed via: `curl -fsSL https://ollama.com/install.sh | sh`
- **Size:** ~50MB (binary)
- **Time:** 1 minute

### 4. **Mistral:7b Model** (for Ollama)
- Installed via: `ollama pull mistral:7b`
- **Size:** ~4GB
- **Time:** 5-10 minutes (depends on internet speed)

### 5. **Python Virtual Environment** (`ai-teacher-venv`)
- Created via: `python3 -m venv ~/ai-teacher-venv`
- **Size:** ~200MB (base)
- **Time:** 30 seconds

### 6. **Python Dependencies** (via `pip install`)
Installed from these requirements files:
- `frontend/requirements.txt` - Streamlit, requests, etc.
- `services/tts/requirements.txt` - TTS libraries
- `services/animation/requirements.txt` - Animation libraries
- `services/coordinator/requirements.txt` - FastAPI, httpx, etc.
- `services/longcat_video/requirements.txt` - FastAPI, psutil, etc.
- **Size:** ~2-3GB
- **Time:** 5-10 minutes

### 7. **LongCat-Video Repository** (Code)
- Cloned via: `git clone https://github.com/meituan-longcat/LongCat-Video`
- **Size:** ~100MB (code only)
- **Time:** 1-2 minutes

### 8. **Conda Environment** (`longcat-video`)
- Created via: `conda create -n longcat-video python=3.10 -y`
- **Size:** ~500MB (base)
- **Time:** 2-3 minutes

### 9. **PyTorch** (for LongCat-Video)
- Installed via: `pip install torch==2.6.0+cu124 ...`
- **Size:** ~3-4GB
- **Time:** 5-10 minutes

### 10. **LongCat-Video Python Dependencies**
- From `LongCat-Video/requirements.txt`
- From `LongCat-Video/requirements_avatar.txt`
- Includes: Flash Attention, transformers, diffusers, librosa, audio-separator, pyloudnorm, etc.
- **Size:** ~5-6GB
- **Time:** 10-20 minutes

### 11. **Hugging Face Models** (THE BIG ONE!)
Downloaded via `huggingface-cli`:
- **LongCat-Video-Avatar:** `meituan-longcat/LongCat-Video-Avatar`
- **LongCat-Video Base:** `meituan-longcat/LongCat-Video`
- **Total Size:** ~40GB
- **Time:** 30-60 minutes (depends on internet speed)

---

## 🚀 Installation Order (What Scripts Do What)

### Script 1: `deploy_no_docker.sh`
**Installs:**
- ✅ System packages (apt-get)
- ✅ Node.js v20
- ✅ n8n (npm)
- ✅ Ollama (curl install script)
- ✅ Mistral:7b model (ollama pull)
- ✅ Python venv (`ai-teacher-venv`)
- ✅ Python dependencies (all service requirements.txt files)
- ✅ Sets up avatar images
- ✅ Starts services in tmux

**Time:** 15-20 minutes total

### Script 2: `deploy_longcat_video.sh`
**Installs:**
- ✅ Conda environment (`longcat-video`)
- ✅ System build tools (gcc, g++, build-essential)
- ✅ PyTorch 2.6.0+cu124
- ✅ Flash Attention
- ✅ LongCat-Video Python dependencies
- ✅ Hugging Face models (~40GB) ← **BIGGEST DOWNLOAD**
- ✅ LongCat-Video API service dependencies
- ✅ Sets up avatar images

**Time:** 45-75 minutes total (mostly model download)

### Script 3: `quick_start_all.sh`
**Does:**
- ✅ Starts Ollama (if not running)
- ✅ Pulls mistral:7b (if missing)
- ✅ Starts all services in tmux
- ✅ Verifies services are running

**Time:** 2-3 minutes

### Script 4: `force_reimport_workflows.sh`
**Does:**
- ✅ Deletes old n8n workflows
- ✅ Imports new workflows from `n8n/workflows/`
- ✅ Activates workflows

**Time:** 30 seconds

---

## 📊 Total Download/Install Summary

| Component | Size | Time |
|-----------|------|------|
| System packages | ~500MB | 2-5 min |
| n8n | ~100MB | 1-2 min |
| Ollama + Mistral:7b | ~4GB | 5-10 min |
| Python dependencies | ~2-3GB | 5-10 min |
| LongCat-Video code | ~100MB | 1-2 min |
| Conda + PyTorch | ~4GB | 5-10 min |
| LongCat-Video deps | ~5-6GB | 10-20 min |
| **Hugging Face models** | **~40GB** | **30-60 min** |
| **TOTAL** | **~56GB** | **60-120 min** |

---

## 🎯 Quick Setup Commands (Fresh Instance)

**📍 On VAST Terminal:**

```bash
# Step 1: Clone repository
cd ~
git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
cd Nextwork-Teachers-TechMonkey

# Step 2: Install everything (Ollama, n8n, Python deps, etc.)
bash scripts/deploy_no_docker.sh
# ⏱️ Takes: 15-20 minutes

# Step 3: Set up LongCat-Video (includes ~40GB model download)
bash scripts/deploy_longcat_video.sh
# ⏱️ Takes: 45-75 minutes (mostly model download)

# Step 4: Start all services
bash scripts/quick_start_all.sh
# ⏱️ Takes: 2-3 minutes

# Step 5: Re-import n8n workflows
bash scripts/force_reimport_workflows.sh
# ⏱️ Takes: 30 seconds
```

**Total time:** ~60-100 minutes (mostly waiting for Hugging Face models)

---

## 🔍 What Each Script Installs (Detailed)

### `deploy_no_docker.sh` installs:

**System:**
- `ca-certificates`, `curl`, `git`
- `python3`, `python3-venv`, `python3-pip`
- `ffmpeg`, `libsndfile1`
- `tmux`, `redis-server`

**Node.js/n8n:**
- Node.js v20 (via nodesource)
- n8n (via npm)

**Ollama:**
- Ollama binary (via install script)
- mistral:7b model (~4GB)

**Python:**
- Virtual environment: `~/ai-teacher-venv`
- Dependencies from:
  - `frontend/requirements.txt`
  - `services/tts/requirements.txt`
  - `services/animation/requirements.txt`
  - `services/coordinator/requirements.txt`
  - `services/longcat_video/requirements.txt`

### `deploy_longcat_video.sh` installs:

**System:**
- `libsndfile1`, `ffmpeg`, `build-essential`, `gcc`, `g++`

**Conda:**
- Conda environment: `longcat-video` (Python 3.10)

**PyTorch:**
- `torch==2.6.0+cu124`
- `torchvision==0.21.0+cu124`
- `torchaudio==2.6.0`

**LongCat-Video Dependencies:**
- From `LongCat-Video/requirements.txt`:
  - `flash-attn==2.7.4.post1`
  - `transformers`, `diffusers`, etc.
- From `LongCat-Video/requirements_avatar.txt`:
  - `pyloudnorm==0.1.1`
  - `audio-separator==0.30.2`
  - `librosa`, `soundfile`, etc.

**Hugging Face Models:**
- `meituan-longcat/LongCat-Video-Avatar` (~20GB)
- `meituan-longcat/LongCat-Video` (~20GB)

**API Service:**
- FastAPI, uvicorn, httpx, pydantic, psutil

---

## ⚠️ Important Notes

1. **Hugging Face models are the biggest download** (~40GB total)
   - This is the longest step (30-60 minutes)
   - Make sure you have good internet connection
   - Models are stored in `LongCat-Video/weights/`

2. **Mistral:7b model** (~4GB)
   - Downloaded automatically by `deploy_no_docker.sh`
   - Takes 5-10 minutes

3. **PyTorch** (~3-4GB)
   - CUDA version (for GPU)
   - Takes 5-10 minutes to download

4. **All Python packages** (~10GB total)
   - Split across venv and conda environments
   - Takes 15-30 minutes total

5. **Total disk space needed:** ~60GB
   - Models: ~40GB
   - Python packages: ~10GB
   - System packages: ~1GB
   - Code: ~1GB
   - Other: ~8GB

---

## ✅ Verification Checklist

After installation, verify everything is installed:

```bash
# Check Ollama
ollama list  # Should show mistral:7b

# Check n8n
n8n --version

# Check Python environments
conda env list  # Should show longcat-video
ls ~/ai-teacher-venv  # Should exist

# Check models
ls -lh LongCat-Video/weights/LongCat-Video-Avatar/  # Should show ~20GB
ls -lh LongCat-Video/weights/LongCat-Video/  # Should show ~20GB

# Check services
bash scripts/check_all_services_status.sh
```

---

## 🎯 Bottom Line

**To get back to where you were, you need:**

1. ✅ Run `deploy_no_docker.sh` (installs Ollama, n8n, Python deps)
2. ✅ Run `deploy_longcat_video.sh` (installs LongCat-Video + downloads ~40GB models)
3. ✅ Run `quick_start_all.sh` (starts all services)
4. ✅ Run `force_reimport_workflows.sh` (imports n8n workflows)

**Total time:** ~60-100 minutes (mostly waiting for Hugging Face models)

**Total disk space:** ~60GB






bash scripts/check_all_services_status.sh