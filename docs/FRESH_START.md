# Fresh Start: Complete VAST Instance Setup

This guide walks you through setting up a brand new VAST instance from scratch, including proper GitHub workflow.

## Important: Terminal Types

Throughout this guide, we'll refer to two different terminals:

- **Desktop PowerShell Terminal**: Your local Windows machine (where you run commands to connect TO the VAST instance)
- **VAST Terminal**: The cloud instance on Vast.ai (where you deploy and run services)

Each step will clearly indicate which terminal to use.

## Prerequisites

- Vast.ai account
- GitHub account with repository access
- SSH key generated on your local machine

## Step 1: Generate/Verify SSH Key (Desktop PowerShell Terminal)

On your **Desktop PowerShell Terminal**, ensure you have an SSH key:

```powershell
# Check if key exists
ls ~/.ssh/id_ed25519.pub

# If not, generate one
ssh-keygen -t ed25519 -C "your-email@example.com"
# Press Enter to accept defaults, optionally set a passphrase
```

**Copy your public key:**
```powershell
Get-Content ~/.ssh/id_ed25519.pub | Set-Clipboard
# Or manually copy the output
cat ~/.ssh/id_ed25519.pub
```

## Step 2: Rent New VAST Instance

1. Go to [Vast.ai](https://cloud.vast.ai/create/)
2. Search for **2x A100 PCIE** or similar GPU instance
3. **Important:** Look for instances that support Docker (check description/comments)
4. Rent the instance
5. **Note the connection details** from the dashboard:
   - IP address
   - SSH port
   - Gateway connection details (if available)

## Step 3: Add SSH Key to VAST Instance

**Option A: Via Vast.ai Dashboard (Recommended)**
1. Open your instance in the Vast.ai dashboard
2. Look for "SSH Keys", "Access", or "Security" section
3. Click "Add SSH Key"
4. Paste your public key (from Step 1)
5. Save

**Option B: Via Instance Settings**
- Some instances allow adding keys during setup
- Check instance configuration/access settings

## Step 4: Test Connection (Desktop PowerShell Terminal)

From your **Desktop PowerShell Terminal**, test the connection:

```powershell
# Navigate to project directory
cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey

# Test connection (will use correct IP/port from your dashboard)
.\quick-connect.ps1
```

Or manually test:
```powershell
# Replace with your actual IP and port from dashboard
ssh -p YOUR_PORT root@YOUR_IP
```

**If connection works**, you should see a shell prompt like `root@C.XXXXX:~#` - you're now in the **VAST Terminal**.

## Step 5: Clone Repository (VAST Terminal)

Once connected, you're in the **VAST Terminal**. Clone the repository:

```bash
# Navigate to home directory
cd ~

# Clone the repository
git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git

# Navigate into project
cd Nextwork-Teachers-TechMonkey

# Verify files are there
ls -la
```

## Step 6: Update Connection Scripts (If Needed)

If your new instance has different IP/port, update the connection scripts:

**On your Desktop PowerShell Terminal:**
```powershell
cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey

# Edit connect-vast.ps1 with new IP/port
# Then commit and push:
git add connect-vast.ps1 connect-vast.sh
git commit -m "Update connection details for new instance"
git push origin main
```

## Step 7: Deploy Services (VAST Terminal)

**In the VAST Terminal**, choose your deployment method:

### Option A: Docker Deployment (If Instance Supports It)

```bash
cd ~/Nextwork-Teachers-TechMonkey

# Test Docker first
docker run hello-world

# If Docker works, deploy with Docker
bash scripts/deploy_vast_ai.sh
docker compose up -d
```

### Option B: No-Docker Deployment (If Docker Fails)

```bash
cd ~/Nextwork-Teachers-TechMonkey

# Deploy without Docker
bash scripts/deploy_no_docker.sh

# Start services
bash scripts/run_no_docker_tmux.sh
```

## Step 8: Verify Services Are Running (VAST Terminal)

**In the VAST Terminal:**

```bash
# Check Docker containers (if using Docker)
docker compose ps

# Or check processes (if using no-docker)
ps aux | grep python
ps aux | grep streamlit

# Check GPU
nvidia-smi

# Check service health
python3 scripts/health_check.py
```

## Step 9: Set Up Port Forwarding (Desktop PowerShell Terminal)

**Open a NEW Desktop PowerShell Terminal** (keep the VAST Terminal open), create an SSH tunnel:

```powershell
cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey

# Use the connection script with port forwarding
.\connect-vast.ps1

# Or manually (replace with your IP/port):
ssh -p YOUR_PORT root@YOUR_IP `
  -L 5678:localhost:5678 `
  -L 8501:localhost:8501 `
  -L 8001:localhost:8001 `
  -L 8002:localhost:8002 `
  -L 11434:localhost:11434
```

**Keep this terminal open** - it maintains the tunnel.

## Step 10: Access Services

With port forwarding active, access services from your local browser:

- **n8n**: http://localhost:5678
- **Frontend**: http://localhost:8501
- **TTS API**: http://localhost:8001
- **Animation API**: http://localhost:8002
- **Ollama**: http://localhost:11434

## Step 11: Import n8n Workflow

1. Open n8n at http://localhost:5678
2. Login (credentials from `.env` file or default)
3. Go to **Workflows** → **Import from File**
4. Upload `n8n/workflows/dual-teacher-workflow.json`
5. Configure endpoints if needed
6. Activate the workflow

## Step 12: Install LLM Models (VAST Terminal)

**In the VAST Terminal:**

```bash
# If using Docker
docker exec ai-teacher-ollama ollama pull mistral:7b

# Or if using no-docker
ollama pull mistral:7b
```

## Step 13: Generate Teacher Avatars (VAST Terminal)

**In the VAST Terminal:**

```bash
cd ~/Nextwork-Teachers-TechMonkey

# Install dependencies if needed
pip3 install diffusers torch torchvision transformers accelerate

# Generate avatars
python3 scripts/avatar_generation.py
```

## GitHub Workflow: Keeping Changes Synced

**Always commit and push changes as you make them!**

### On Desktop PowerShell Terminal (After Making Changes)

```powershell
cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey

# Check what changed
git status

# Add changes
git add .

# Commit with descriptive message
git commit -m "Description of what changed"

# Push to GitHub
git push origin main
```

### On VAST Terminal (After Making Changes)

```bash
cd ~/Nextwork-Teachers-TechMonkey

# Check what changed
git status

# Add changes
git add .

# Commit
git commit -m "Description of what changed"

# Push to GitHub
git push origin main
```

**Note:** Make sure you've configured git on the VAST Terminal:
```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

## Troubleshooting

### Connection Issues
- See `docs/TROUBLESHOOT_SSH.md` for detailed SSH troubleshooting
- Verify instance is running in Vast.ai dashboard
- Check IP/port match dashboard exactly
- Try gateway connection: `ssh -p PORT root@ssh1.vast.ai`

### Docker Issues
- See `docs/TROUBLESHOOT_DOCKER.md` for Docker troubleshooting
- Test with `docker run hello-world` first
- If Docker fails, use no-docker deployment (see `docs/NO_DOCKER.md`)

### Service Issues
- Check logs: `docker compose logs` or `journalctl -u service-name`
- Verify GPU: `nvidia-smi`
- Check ports: `netstat -tulpn | grep PORT`
- Run health check: `python3 scripts/health_check.py`

## Quick Reference Commands

### Desktop PowerShell Terminal
```powershell
# Test connection
.\quick-connect.ps1

# Connect with port forwarding
.\connect-vast.ps1

# Add SSH key helper
.\add-ssh-key.ps1
```

### VAST Terminal
```bash
# Check services
docker compose ps  # or ps aux | grep python

# View logs
docker compose logs -f  # or tail -f /path/to/log

# Restart services
docker compose restart  # or restart tmux session

# Update from GitHub
git pull origin main
```

## Next Steps

- Configure teacher personalities in `configs/teacher_prompts.yaml`
- Set up custom workflows in n8n
- Test the full pipeline with `python3 scripts/test_pipeline.py`
- Monitor GPU usage and optimize as needed

## Important Reminders

1. **Always commit and push changes** - Don't lose work!
2. **Keep connection details updated** - Update scripts when instance changes
3. **Test Docker first** - Before deploying, verify Docker works
4. **Keep port forwarding active** - Leave SSH tunnel open while working
5. **Monitor costs** - Vast.ai charges per hour, stop instance when not in use
