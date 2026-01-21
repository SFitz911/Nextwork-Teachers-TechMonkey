# Quick Start: Deploying to Vast.ai

This guide walks you through deploying the AI Teacher system to your rented Vast.ai GPU instance.

## Step 1: Rent Your Instance

1. Go to [Vast.ai](https://cloud.vast.ai/create/)
2. Find and rent a **2x A100 PCIE** instance (recommended)
3. Note your SSH connection details:
   - IP address
   - Port
   - Username (usually `root`)
   - Password or SSH key

## Step 2: Connect via SSH

From your local machine:

```bash
# If using password
ssh root@YOUR_VAST_AI_IP -p YOUR_PORT

# If using SSH key (from Notepad++)
ssh -p YOUR_PORT root@YOUR_VAST_AI_IP
```

## Step 3: Upload Project Files

You have several options:

### Option A: Git Clone (Recommended)

If you've pushed to GitHub:
```bash
cd ~
git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
cd Nextwork-Teachers-TechMonkey
```

### Option B: SCP Upload (From Windows)

From your local machine (PowerShell or Git Bash):
```bash
# Upload entire project
scp -P YOUR_PORT -r . root@YOUR_VAST_AI_IP:~/ai-teacher-classroom

# Or just essential files
scp -P YOUR_PORT docker-compose.yml root@YOUR_VAST_AI_IP:~/
scp -P YOUR_PORT -r scripts/ root@YOUR_VAST_AI_IP:~/
scp -P YOUR_PORT -r services/ root@YOUR_VAST_AI_IP:~/
scp -P YOUR_PORT -r configs/ root@YOUR_VAST_AI_IP:~/
scp -P YOUR_PORT -r frontend/ root@YOUR_VAST_AI_IP:~/
scp -P YOUR_PORT -r n8n/ root@YOUR_VAST_AI_IP:~/
```

### Option C: Manual Copy (Using Vast.ai File Manager)

1. Access Vast.ai dashboard
2. Click on your instance
3. Use the file browser/upload feature
4. Upload project files

## Step 4: Run Deployment Script

Once connected to your Vast.ai instance:

```bash
# Make script executable
chmod +x scripts/deploy_vast_ai.sh

# Run the deployment script
bash scripts/deploy_vast_ai.sh
```

The script will:
- ✅ Verify GPU availability
- ✅ Install Docker (if needed)
- ✅ Install NVIDIA Container Toolkit
- ✅ Configure GPU access
- ✅ Install Docker Compose
- ✅ Create necessary directories
- ✅ Set up environment variables

**Note:** This takes 5-10 minutes. The script will prompt for `sudo` password if needed.

## Step 5: Upload Project Files (If Not Done Already)

If you used Option A (Git Clone), skip this. Otherwise:

```bash
cd ~/ai-teacher-classroom

# Make sure all project files are here
ls -la
# You should see: docker-compose.yml, scripts/, services/, etc.
```

## Step 6: Start Services

```bash
cd ~/ai-teacher-classroom
docker compose up -d
```

Wait for all containers to start (30-60 seconds), then check status:

```bash
docker compose ps
```

All services should show "Up" status.

## Step 7: Install LLM Models

```bash
# Install Mistral 7B (recommended)
docker exec ai-teacher-ollama ollama pull mistral:7b

# Or use the helper script
bash scripts/setup_ollama.sh
```

This will take 5-10 minutes depending on your connection speed.

## Step 8: Generate Teacher Avatars

```bash
# Install Python dependencies (if needed)
pip3 install diffusers torch torchvision transformers accelerate

# Generate avatars
python3 scripts/avatar_generation.py
```

## Step 9: Access Your Services

Get your Vast.ai instance IP:
```bash
hostname -I
```

Then access:
- **n8n**: `http://YOUR_IP:5678`
- **Frontend**: `http://YOUR_IP:8501`
- **TTS API**: `http://YOUR_IP:8001`
- **Animation API**: `http://YOUR_IP:8002`

**Important:** You may need to configure firewall rules in Vast.ai dashboard to allow access to these ports.

## Step 10: Import n8n Workflow

1. Open n8n at `http://YOUR_IP:5678`
2. Login with credentials from `.env` file
3. Go to Workflows → Import from File
4. Upload `n8n/workflows/dual-teacher-workflow.json`
5. Configure endpoints in the workflow nodes
6. Activate the workflow

## Troubleshooting

### Services Won't Start
```bash
# Check logs
docker compose logs

# Check specific service
docker compose logs ollama
docker compose logs frontend
```

### GPU Not Detected
```bash
# Verify GPU
nvidia-smi

# Test Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

### Port Already in Use
```bash
# Check what's using the port
sudo netstat -tulpn | grep 5678

# Stop conflicting service or change port in docker-compose.yml
```

### Out of Memory
```bash
# Check GPU memory
nvidia-smi

# Monitor container memory
docker stats
```

## Next Steps

- Run health check: `python3 scripts/health_check.py`
- Test pipeline: `python3 scripts/test_pipeline.py`
- Configure teacher personalities in `configs/teacher_prompts.yaml`
- Set up port forwarding for local access (see SSH commands in Notepad++)

## Port Forwarding (For Local Access)

To access services from your local machine:

```bash
# Option 1: Direct connection with port forwarding
ssh -p 41366 root@50.217.254.161 -L 5678:localhost:5678 -L 8501:localhost:8501 -L 8001:localhost:8001 -L 8002:localhost:8002

# Option 2: Via Vast.ai SSH gateway
ssh -p 11071 root@ssh4.vast.ai -L 5678:localhost:5678 -L 8501:localhost:8501 -L 8001:localhost:8001 -L 8002:localhost:8002

# Then access from your local browser:
# n8n: http://localhost:5678
# Frontend: http://localhost:8501
# TTS API: http://localhost:8001
# Animation API: http://localhost:8002
```

## Stopping Services

```bash
# Stop all services
docker compose down

# Stop and remove volumes (⚠️ deletes data)
docker compose down -v
```

## Monitoring

```bash
# View logs
docker compose logs -f

# Check GPU usage
watch -n 1 nvidia-smi

# Check container stats
docker stats
```
