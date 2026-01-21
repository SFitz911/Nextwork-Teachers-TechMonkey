# I'm Already on a Vast.ai Instance - What Do I Do?

If you're already logged into a Vast.ai instance (you see `root@C.XXXXX:/workspace$`), you can skip the SSH step and deploy directly!

## Current Situation

You're on the instance, so you don't need to SSH. Just deploy right here.

## Quick Deployment Steps

### Step 1: Check Your Current Location
```bash
pwd
# Should show: /workspace or /root
```

### Step 2: Check GPU Availability
```bash
nvidia-smi
# Should show your GPU info
```

### Step 3: Clone the Repository
```bash
cd ~
# Or if in /workspace, stay there
git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git ai-teacher-classroom
cd ai-teacher-classroom
```

### Step 4: Run Deployment Script
```bash
bash scripts/deploy_vast_ai.sh
```

This will:
- Install Docker (if needed)
- Install NVIDIA Container Toolkit
- Set up all services
- Create necessary directories

### Step 5: Start Services
```bash
docker compose up -d
```

### Step 6: Install LLM Model
```bash
docker exec ai-teacher-ollama ollama pull mistral:7b
```

### Step 7: Access Services

Get your instance IP:
```bash
hostname -I
```

Or check the Vast.ai dashboard for your instance's public IP.

Then access:
- n8n: `http://YOUR_INSTANCE_IP:5678`
- Frontend: `http://YOUR_INSTANCE_IP:8501`

## Understanding the SSH Commands

The SSH commands (`ssh -p 11071 root@ssh4.vast.ai`) are for when you're on your **local Windows machine** and want to connect **TO** the Vast.ai instance.

Since you're already **ON** the instance, you don't need them!

## If You Need to Access Services from Your Local Machine

**From your Windows machine** (not from the Vast.ai instance), run:

```powershell
ssh -p 11071 root@ssh4.vast.ai -L 5678:localhost:5678 -L 8501:localhost:8501
```

This creates a tunnel so you can access `http://localhost:5678` from your Windows browser.

But first, deploy the services on the Vast.ai instance (the steps above).
