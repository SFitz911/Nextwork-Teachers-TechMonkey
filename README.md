# AI Virtual Classroom Teacher Agent

A realistic AI teacher classroom system featuring two side-by-side teacher avatars that read chat questions, generate smart responses, and speak them with lip-synced animation. Fully open-source and designed to run on rented Vast.ai GPU instances.

## 🎯 Project Overview

This system creates an interactive virtual classroom where two AI teachers work together in a tag-team style:
- One teacher speaks while the other generates the next response
- Teachers play off each other conversationally
- Low latency through streaming and parallel processing
- All orchestrated via n8n workflows

## 🏗️ Architecture

```
Viewer Chat → Webhook → n8n Workflow
                             ↓
        ┌────────────────────┴────────────────────┐
        ↓                                          ↓
   Teacher A (Speaking)                    Teacher B (Thinking)
        ↓                                          ↓
   TTS + Animation                    LLM Generation + Prep
        ↓                                          ↓
   └────────────────────┬────────────────────┘
                        ↓
              Frontend (Streamlit/Gradio)
```

## 🛠️ Tech Stack

- **Orchestration**: n8n (Docker)
- **LLM**: Mistral-7B-Instruct or Llama-3-8B (via Ollama/vLLM)
- **TTS**: Piper TTS or Coqui TTS
- **Animation**: LAM (Large Avatar Model) or LivePortrait
- **Avatar Generation**: Stable Diffusion
- **Frontend**: Streamlit or Gradio
- **GPU Hosting**: Vast.ai (A100 40/80GB recommended)

## 📁 Project Structure

```
.
├── docker-compose.yml          # Main orchestration
├── n8n/
│   └── workflows/              # n8n workflow exports
├── services/
│   ├── llm/                    # LLM service configs
│   ├── tts/                    # TTS service configs
│   └── animation/              # Animation service configs
├── frontend/                   # Streamlit/Gradio app
├── scripts/
│   ├── avatar_generation.py    # Stable Diffusion avatar creation
│   └── deploy_vast_ai.sh       # Vast.ai deployment script
├── configs/                    # Configuration files
└── docs/                       # Additional documentation

```

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- NVIDIA Container Toolkit (for GPU support)
- Vast.ai account (for GPU hosting)

### No-Docker mode (if your Vast.ai host blocks containers)

Some Vast.ai hosts block Docker containers (errors like `unshare: operation not permitted`). In that case, run services directly on the host:

- See: [docs/NO_DOCKER.md](docs/NO_DOCKER.md)
- Run: `bash scripts/deploy_no_docker.sh`

### 1. Vast.ai Setup

**⚠️ Important:** Not all Vast.ai instances support Docker properly. Look for instances that explicitly support Docker/containers. See [docs/VAST_AI_INSTANCE_SELECTION.md](docs/VAST_AI_INSTANCE_SELECTION.md) for details.

1. Rent an A100/H100 instance (≥40GB VRAM, CUDA 12+) that supports Docker
2. SSH into the instance
3. **Test Docker first:** `docker run hello-world` (must work!)
4. Install NVIDIA Container Toolkit:
   ```bash
   curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
   curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
     sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
     sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
   sudo apt-get update
   sudo apt-get install -y nvidia-container-toolkit
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   ```

### 2. Deploy Services

```bash
docker compose up -d
```

This will start:
- n8n on port 5678
- Ollama/vLLM service
- TTS service
- Animation service
- Frontend on port 8501 (Streamlit) or 7860 (Gradio)

### 3. Access Services

- n8n: http://localhost:5678
- Frontend: http://localhost:8501
- TTS API: http://localhost:8001
- Animation API: http://localhost:8002

### 4. Import n8n Workflow

1. Open n8n at http://localhost:5678
2. Import workflow from `n8n/workflows/dual-teacher-workflow.json`
3. Configure webhook URLs and API endpoints

### 5. Generate Teacher Avatars

```bash
python scripts/avatar_generation.py
```

This will generate two teacher avatars using Stable Diffusion.

## 📋 Implementation Steps

### Phase 1: Core Infrastructure (Days 1-2)
- [x] Project structure
- [ ] Vast.ai instance setup
- [ ] Docker services deployment
- [ ] Basic n8n workflow

### Phase 2: LLM Integration (Days 2-3)
- [ ] Ollama/vLLM setup
- [ ] Streaming LLM responses
- [ ] Teacher context management

### Phase 3: TTS & Animation (Days 3-4)
- [ ] TTS service deployment
- [ ] Animation service setup
- [ ] Lip-sync quality testing

### Phase 4: Dual-Teacher Logic (Days 4-6)
- [ ] Tag-team switching logic
- [ ] Conversational prompts
- [ ] Idle animations

### Phase 5: Frontend & Polish (Days 6-7)
- [ ] Streamlit/Gradio UI
- [ ] Video streaming
- [ ] Chat interface
- [ ] Performance optimization

## 🎨 Features

- **Tag-Team Teaching**: Seamless handoff between two AI teachers
- **Low Latency**: Streaming responses with <3-4 second first-word latency
- **Natural Conversations**: Teachers reference each other's responses
- **High Quality Animation**: LAM/LivePortrait for realistic lip-sync
- **Fully Open Source**: No proprietary dependencies

## 💰 Cost Optimization

- Use Vast.ai spot instances (~$0.5-$2/hr)
- Model quantization (4-bit) for VRAM efficiency
- Auto-shutdown script when idle
- Monitor GPU usage via Vast.ai dashboard

## 🔧 Configuration

Edit configuration files in `configs/`:
- `llm_config.yaml`: LLM model selection and parameters
- `tts_config.yaml`: TTS voice and speed settings
- `animation_config.yaml`: Animation quality and model settings
- `teacher_prompts.yaml`: Teacher personality and conversation prompts

## 📝 Notes

- Target latency: <3-4 seconds to first words
- Recommended VRAM: ≥40GB for smooth operation
- Test with multi-user chat simulation
- Monitor GPU usage and adjust quantization as needed

## 🔗 Quick Links

- **GitHub**: https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
- **Quick Start Guide**: [docs/QUICK_START_VAST.md](docs/QUICK_START_VAST.md)
- **Fresh Start Guide**: [docs/FRESH_START.md](docs/FRESH_START.md) (Complete setup from scratch)
- **SSH Setup**: [docs/SSH_SETUP.md](docs/SSH_SETUP.md)
- **Terminal Guide**: [docs/TERMINAL_GUIDE.md](docs/TERMINAL_GUIDE.md) (Desktop vs VAST Terminal)

## 📡 Current Connection Details

- **Direct**: `ssh -p 41428 root@50.217.254.161`
- **Gateway**: `ssh -p 35859 root@ssh7.vast.ai`
- **SSH Key**: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOjUkOMrizf3mTkblsQoLOLTrUBBiy1z46qWgg8WaRp5`

## 🤝 Contributing

This is a project outline by Sean Fitzgerald. Contributions welcome!

## 📄 License

Open source - see LICENSE file for details.
