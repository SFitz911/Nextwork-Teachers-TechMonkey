# Shutdown and Restart Guide

## 🛑 Shutting Down the VAST Instance

### What Persists (Survives Shutdown)
✅ **All data persists** - VAST instances keep all files on disk when stopped:
- ✅ Code repository (`~/Nextwork-Teachers-TechMonkey/`)
- ✅ Python virtual environment (`~/ai-teacher-venv/`)
- ✅ Conda environment (`longcat-video`)
- ✅ Ollama models (`~/.ollama/`)
- ✅ LongCat-Video models (`~/Nextwork-Teachers-TechMonkey/LongCat-Video/weights/`)
- ✅ Avatar images (`~/Nextwork-Teachers-TechMonkey/LongCat-Video/assets/avatars/`)
- ✅ Generated videos (`~/Nextwork-Teachers-TechMonkey/outputs/longcat/`)
- ✅ Logs (`~/Nextwork-Teachers-TechMonkey/logs/`)
- ✅ Configuration files (`.env`, etc.)

### What Needs Re-import (After Restart)
⚠️ **n8n workflows** - Must be re-imported after restart (n8n doesn't auto-persist workflows)

### Shutdown Steps

**📍 VAST Terminal** (Optional - services will stop when instance shuts down):
```bash
# Optional: Stop services cleanly (not required, but clean)
cd ~/Nextwork-Teachers-TechMonkey
tmux kill-session -t ai-teacher 2>/dev/null || true
pkill -f "ollama serve" 2>/dev/null || true
```

**📍 VAST Dashboard** (Web UI):
1. Go to your VAST dashboard
2. Find your instance
3. Click **"Stop"** or **"Shutdown"**
4. Instance will stop (data is preserved)

**📍 Desktop PowerShell**:
- Close the port forwarding window (if running)
- No other action needed

---

## 🚀 Restarting the VAST Instance

### Step 1: Start Instance from VAST Dashboard

1. Go to VAST dashboard
2. Find your stopped instance
3. Click **"Start"** or **"Resume"**
4. Wait for instance to boot (1-2 minutes)
5. Note the new SSH connection details (host/port may change)

### Step 2: Update SSH Connection Details

**📍 Desktop PowerShell**:
```powershell
# Update connect-vast-simple.ps1 and connect-vast-terminal.ps1 with new SSH details
# Get new details from VAST dashboard
```

### Step 3: Connect and Restart Services

**📍 VAST Terminal** (Connect via updated SSH details):
```bash
# Connect to instance
ssh -p <NEW_PORT> root@<NEW_HOST>

# Navigate to project
cd ~/Nextwork-Teachers-TechMonkey

# Pull latest code (if you made changes on Desktop)
git pull origin main

# Restart all services (this handles everything)
bash scripts/quick_start_all.sh
```

### Step 4: Re-import n8n Workflows

**📍 VAST Terminal**:
```bash
# Force re-import workflows (they don't auto-persist)
bash scripts/force_reimport_workflows.sh
```

### Step 5: Set Up Port Forwarding

**📍 Desktop PowerShell**:
```powershell
# Start port forwarding (keep window open)
.\connect-vast-simple.ps1
```

### Step 6: Verify Everything is Running

**📍 VAST Terminal**:
```bash
# Check all services
bash scripts/check_all_services_status.sh

# Or check manually
tmux attach -t ai-teacher
```

---

## ✅ Quick Restart Checklist

After restarting the VAST instance:

- [ ] Instance is running (check VAST dashboard)
- [ ] SSH connection details updated (if changed)
- [ ] Connected to VAST terminal
- [ ] Pulled latest code: `git pull origin main`
- [ ] Started all services: `bash scripts/quick_start_all.sh`
- [ ] Re-imported workflows: `bash scripts/force_reimport_workflows.sh`
- [ ] Port forwarding active: `.\connect-vast-simple.ps1` (Desktop)
- [ ] All services running: `bash scripts/check_all_services_status.sh`
- [ ] Frontend accessible: `http://localhost:8501` (Desktop browser)

---

## 🔧 Troubleshooting

### Services Not Starting
```bash
# Check if services are running
bash scripts/check_all_services_status.sh

# View logs
tmux attach -t ai-teacher

# Check individual service logs
tail -50 logs/coordinator.log
tail -50 logs/longcat_video.log
tail -50 logs/n8n.log
```

### n8n Workflows Missing
```bash
# Re-import workflows
bash scripts/force_reimport_workflows.sh
```

### Ollama Model Missing
```bash
# Check if model exists
ollama list

# If missing, pull it
ollama pull mistral:7b
```

### LongCat-Video Models Missing
```bash
# Check if models exist
ls -lh ~/Nextwork-Teachers-TechMonkey/LongCat-Video/weights/LongCat-Video-Avatar/

# If missing, re-run deployment
bash scripts/deploy_longcat_video.sh
```

### Avatar Images Missing
```bash
# Re-copy avatar images
bash scripts/fix_avatar_images.sh
```

---

## 📝 Notes

- **SSH details may change** when restarting - always check VAST dashboard
- **n8n workflows must be re-imported** after each restart
- **All other data persists** automatically
- **Quick start script handles** most of the setup automatically
- **Port forwarding must be re-established** from Desktop after restart

---

## 🎯 One-Command Restart (After Instance is Running)

Once you're connected to the VAST terminal and instance is running:

```bash
cd ~/Nextwork-Teachers-TechMonkey && git pull origin main && bash scripts/quick_start_all.sh && bash scripts/force_reimport_workflows.sh
```

This single command will:
1. Pull latest code
2. Start all services
3. Re-import n8n workflows

Then just start port forwarding from Desktop and you're ready!
