# Deployment Guide

## Vast.ai Setup

### 1. Instance Requirements

- **GPU**: A100 40GB+ or H100 (recommended for best performance)
- **CPU**: 8+ cores
- **RAM**: 32GB+
- **Storage**: 100GB+ (for models)
- **CUDA**: 12.1+
- **Docker**: Latest version

### 2. Initial Setup

Run the deployment script on your Vast.ai instance:

```bash
bash scripts/deploy_vast_ai.sh
```

This will:
- Install Docker and NVIDIA Container Toolkit
- Configure GPU access
- Create necessary directories
- Set up environment variables

### 3. Manual Setup (Alternative)

If you prefer manual setup:

#### Install Docker
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

#### Install NVIDIA Container Toolkit
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

#### Verify GPU Access
```bash
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

## Service Deployment

### 1. Clone/Copy Project Files

```bash
cd ~
git clone <your-repo> ai-teacher-classroom
cd ai-teacher-classroom
```

Or upload files via SCP/SFTP.

### 2. Configure Environment

Edit `.env` file:
```bash
N8N_USER=admin
N8N_PASSWORD=your_secure_password
N8N_HOST=your_vast_ai_ip
```

### 3. Start Services

```bash
docker compose up -d
```

### 4. Verify Services

Check all services are running:
```bash
docker compose ps
```

Check logs:
```bash
docker compose logs -f
```

### 5. Download Models

#### Ollama Models
```bash
docker exec ai-teacher-ollama ollama pull mistral:7b
# or
docker exec ai-teacher-ollama ollama pull llama3:8b
```

#### TTS Models (Piper)
Download Piper voices and place in `services/tts/models/`:
```bash
# Example: Download en_US-lessac-medium
wget -O services/tts/models/en_US-lessac-medium.onnx \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx
```

#### Animation Models
Follow LAM or LivePortrait documentation to download models to `services/animation/models/`.

### 6. Generate Avatars

```bash
# Install Python dependencies
pip install diffusers torch torchvision transformers accelerate

# Generate avatars
python scripts/avatar_generation.py
```

This creates `teacher_a.jpg` and `teacher_b.jpg` in `services/animation/avatars/`.

## n8n Workflow Setup

### 1. Access n8n

Navigate to: `http://your_vast_ai_ip:5678`

Login with credentials from `.env`.

### 2. Import Workflow

1. Go to Workflows → Import from File
2. Select `n8n/workflows/dual-teacher-workflow.json`
3. Configure nodes:
   - Set webhook URL
   - Update Ollama endpoint: `http://ollama:11434`
   - Update TTS endpoint: `http://tts-service:8000`
   - Update Animation endpoint: `http://animation-service:8000`
   - Configure Redis connection (if using)

### 3. Activate Workflow

Click "Active" toggle to enable the workflow.

### 4. Test Webhook

```bash
curl -X POST http://your_vast_ai_ip:5678/webhook/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello teachers!"}'
```

## Frontend Access

Navigate to: `http://your_vast_ai_ip:8501`

The Streamlit interface should be accessible.

## Cost Optimization

### 1. Spot Instances

Use Vast.ai spot pricing for ~50% savings:
- Check "Allow Interruption" when renting
- Save work frequently
- Use auto-save scripts

### 2. Auto-Shutdown Script

Create a script to shutdown when idle:

```bash
# scripts/auto_shutdown.sh
#!/bin/bash
THRESHOLD=300  # 5 minutes of no activity
LAST_ACTIVITY=$(redis-cli GET last_activity || echo 0)
NOW=$(date +%s)
IDLE_TIME=$((NOW - LAST_ACTIVITY))

if [ $IDLE_TIME -gt $THRESHOLD ]; then
    echo "No activity for ${IDLE_TIME}s, shutting down..."
    shutdown -h now
fi
```

Add to crontab:
```bash
*/5 * * * * /path/to/scripts/auto_shutdown.sh
```

### 3. Model Quantization

Use 4-bit quantized models to reduce VRAM:
- Ollama supports quantization: `ollama pull mistral:7b-q4_0`
- Reduces VRAM by ~50%

### 4. Monitor Usage

```bash
# GPU usage
watch -n 1 nvidia-smi

# Container stats
docker stats
```

## Troubleshooting

### Service Won't Start

1. Check Docker logs: `docker compose logs [service-name]`
2. Verify GPU access: `nvidia-smi`
3. Check port conflicts: `netstat -tulpn | grep [port]`

### Out of Memory

1. Reduce batch sizes in config files
2. Use quantized models
3. Close unnecessary containers
4. Restart services: `docker compose restart`

### Slow Performance

1. Check GPU utilization: `nvidia-smi`
2. Verify models are using GPU
3. Reduce model quality settings
4. Enable model caching

### Connection Issues

1. Verify firewall allows ports: 5678, 8501, 8001, 8002
2. Check service health: `curl http://localhost:8001/`
3. Verify n8n webhook URL is correct

## Backup & Recovery

### Backup Models
```bash
tar -czf models_backup.tar.gz services/*/models/ services/animation/avatars/
```

### Backup n8n Data
```bash
docker exec ai-teacher-n8n tar -czf /tmp/n8n_backup.tar.gz /home/node/.n8n
docker cp ai-teacher-n8n:/tmp/n8n_backup.tar.gz ./
```

### Restore
```bash
# Restore models
tar -xzf models_backup.tar.gz

# Restore n8n
docker cp n8n_backup.tar.gz ai-teacher-n8n:/tmp/
docker exec ai-teacher-n8n tar -xzf /tmp/n8n_backup.tar.gz -C /
```

## Updates

### Update Services
```bash
docker compose pull
docker compose up -d
```

### Update Models
```bash
# Update Ollama models
docker exec ai-teacher-ollama ollama pull mistral:7b

# Update other models manually
```

## Production Checklist

- [ ] Secure n8n with strong password
- [ ] Configure CORS for frontend
- [ ] Set up monitoring/alerts
- [ ] Configure auto-backups
- [ ] Test failover scenarios
- [ ] Document API endpoints
- [ ] Set up rate limiting
- [ ] Configure logging retention
- [ ] Test load with multiple users
- [ ] Optimize model settings for your GPU
