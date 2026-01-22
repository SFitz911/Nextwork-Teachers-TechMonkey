# Commands and Workflow Guide

## 🔄 Automated Sync Workflow

### Overview
This project uses a **GitHub → VAST Instance** workflow:
1. Make changes locally (on your Desktop)
2. Commit and push to GitHub
3. Pull latest code on VAST instance
4. Restart services with new code

### Quick Sync (Recommended)

**On your Desktop PowerShell:**
```powershell
cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey
.\sync-to-vast.ps1 "Your commit message here"
```

This automatically:
- ✅ Commits any uncommitted changes
- ✅ Pushes to GitHub
- ✅ SSHs into VAST instance
- ✅ Pulls latest code
- ✅ Restarts all services

### Manual Sync on VAST Instance

**On your VAST Terminal:**
```bash
cd ~/Nextwork-Teachers-TechMonkey
bash scripts/sync_and_restart.sh
```

This will:
- Pull latest code from GitHub
- Restart all services with the new code

---

## 🚀 Manual Service Management

### Start All Services (VAST Terminal)

```bash
cd ~/Nextwork-Teachers-TechMonkey

# Kill everything completely
echo "=== Stopping all services ==="
pkill -f "n8n start" || true
pkill -f streamlit || true
pkill -f "python.*tts" || true
pkill -f "python.*animation" || true
pkill -f "python.*frontend" || true
tmux kill-session -t ai-teacher 2>/dev/null || true

# Wait for everything to stop
sleep 3

# Verify everything is stopped
ps aux | grep -E "n8n|streamlit|python.*tts|python.*animation" | grep -v grep || echo "All stopped"

# Activate virtual environment
source /root/ai-teacher-venv/bin/activate

# Load environment variables from .env if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Set required environment variables
export N8N_BASIC_AUTH_ACTIVE=true
export N8N_BASIC_AUTH_USER="${N8N_USER:-sfitz911@gmail.com}"
export N8N_BASIC_AUTH_PASSWORD="${N8N_PASSWORD:-Delrio77$}"
export N8N_HOST="0.0.0.0"
export N8N_PORT=5678
export N8N_PROTOCOL=http
export WEBHOOK_URL="http://localhost:5678/"
export NODE_ENV=production

# Create logs directory
mkdir -p logs

# Start n8n
echo "=== Starting n8n ==="
nohup env NODE_ENV=production N8N_BASIC_AUTH_ACTIVE=true N8N_BASIC_AUTH_USER="sfitz911@gmail.com" N8N_BASIC_AUTH_PASSWORD="Delrio77$" N8N_HOST="0.0.0.0" N8N_PORT=5678 N8N_PROTOCOL=http WEBHOOK_URL="http://localhost:5678/" n8n start --port 5678 > logs/n8n.log 2>&1 &

# Start TTS service
echo "=== Starting TTS ==="
nohup python services/tts/app.py > logs/tts.log 2>&1 &

# Start Animation service
echo "=== Starting Animation ==="
export AVATAR_PATH="$PWD/services/animation/avatars"
mkdir -p services/animation/output
nohup python services/animation/app.py > logs/animation.log 2>&1 &

# Start Frontend
echo "=== Starting Frontend ==="
export N8N_WEBHOOK_URL='http://localhost:5678/webhook/chat-webhook'
export TTS_API_URL='http://localhost:8001'
export ANIMATION_API_URL='http://localhost:8002'
nohup streamlit run frontend/app.py --server.address 0.0.0.0 --server.port 8501 > logs/frontend.log 2>&1 &

# Wait for services to start
echo "=== Waiting for services to start ==="
sleep 8

# Check all services are running
echo "=== Service Status ==="
ps aux | grep -E "n8n|streamlit|python.*tts|python.*animation" | grep -v grep

# Test each service
echo "=== Testing Services ==="
curl -I http://localhost:5678 2>/dev/null | head -1 || echo "n8n: Not responding"
curl -I http://localhost:8501 2>/dev/null | head -1 || echo "Frontend: Not responding"
curl -I http://localhost:8001 2>/dev/null | head -1 || echo "TTS: Not responding"
curl -I http://localhost:8002 2>/dev/null | head -1 || echo "Animation: Not responding"
```

### Using tmux Script (Alternative)

```bash
cd ~/Nextwork-Teachers-TechMonkey
source /root/ai-teacher-venv/bin/activate
bash scripts/run_no_docker_tmux.sh
```

---

## 🔌 SSH Port Forwarding

### Connect from Desktop PowerShell

**Option 1: Using connect script**
```powershell
cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey
.\connect-vast.ps1
```

**Option 2: Manual SSH with port forwarding**
```powershell
ssh -p 41428 root@50.217.254.161 -L 5678:localhost:5678 -L 8501:localhost:8501 -L 8001:localhost:8001 -L 8002:localhost:8002
```

**Important:** Keep this PowerShell window open while using the services!

### Access Services After Port Forwarding

Once SSH port forwarding is active, access services in your browser:
- **n8n:** `http://localhost:5678`
- **Frontend:** `http://localhost:8501`
- **TTS API:** `http://localhost:8001/docs`
- **Animation API:** `http://localhost:8002/docs`

---

## 📊 Service Status Checks

### Check if Services are Running (VAST Terminal)

```bash
ps aux | grep -E "n8n|streamlit|python.*tts|python.*animation" | grep -v grep
```

### Test Service Endpoints (VAST Terminal)

```bash
curl -I http://localhost:5678 2>/dev/null | head -1
curl -I http://localhost:8501 2>/dev/null | head -1
curl -I http://localhost:8001 2>/dev/null | head -1
curl -I http://localhost:8002 2>/dev/null | head -1
```

### Check Service Logs (VAST Terminal)

```bash
cd ~/Nextwork-Teachers-TechMonkey
tail -50 logs/n8n.log
tail -50 logs/frontend.log
tail -50 logs/tts.log
tail -50 logs/animation.log
```

---

## 🔄 Git Workflow

### Standard Workflow

1. **Make changes locally** (on Desktop)
2. **Commit and push:**
   ```powershell
   cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey
   git add .
   git commit -m "Your commit message"
   git push origin main
   ```
3. **Sync to VAST instance:**
   ```powershell
   .\sync-to-vast.ps1 "Your commit message"
   ```
   OR manually on VAST:
   ```bash
   cd ~/Nextwork-Teachers-TechMonkey
   git pull origin main
   bash scripts/sync_and_restart.sh
   ```

### Pull Latest Code on VAST (Manual)

```bash
cd ~/Nextwork-Teachers-TechMonkey
git pull origin main
```

---

## 🐛 Troubleshooting

### Services Not Starting

```bash
# Check if ports are in use
netstat -tlnp | grep -E "5678|8501|8001|8002" || ss -tlnp | grep -E "5678|8501|8001|8002"

# Kill processes on specific ports
fuser -k 5678/tcp
fuser -k 8501/tcp
fuser -k 8001/tcp
fuser -k 8002/tcp
```

### n8n Not in Production Mode

```bash
# Check if NODE_ENV is set
cat /proc/$(pgrep -f "n8n start" | head -1)/environ | tr '\0' '\n' | grep NODE_ENV

# Restart n8n with NODE_ENV=production
pkill -f "n8n start"
NODE_ENV=production nohup n8n start --port 5678 > logs/n8n.log 2>&1 &
```

### Workflow Not Activated

1. Go to `http://localhost:5678` in browser
2. Log in with: `sfitz911@gmail.com` / `Delrio77$`
3. Open workflow "AI Virtual Classroom - Dual Teacher Workflow"
4. Look for "Active/Inactive" toggle in top-right corner
5. Click to activate

### SSH Connection Issues

```powershell
# Kill existing SSH connections
Get-Process ssh -ErrorAction SilentlyContinue | Stop-Process -Force

# Reconnect
ssh -p 41428 root@50.217.254.161 -L 5678:localhost:5678 -L 8501:localhost:8501 -L 8001:localhost:8001 -L 8002:localhost:8002
```

---

## 📝 Quick Reference

### Service Ports
- **n8n:** 5678
- **Frontend (Streamlit):** 8501
- **TTS Service:** 8001
- **Animation Service:** 8002
- **Ollama (LLM):** 11434

### Credentials
- **n8n Username:** `sfitz911@gmail.com`
- **n8n Password:** `Delrio77$`

### SSH Connection
- **Direct:** `ssh -p 41428 root@50.217.254.161`
- **Gateway:** `ssh -p 35859 root@ssh7.vast.ai`

### Project Directories
- **Local:** `E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey`
- **VAST:** `~/Nextwork-Teachers-TechMonkey`

---

## 🎯 Best Practices

1. **Always commit and push before restarting services**
2. **Use `sync-to-vast.ps1` for automated workflow**
3. **Keep SSH port forwarding active while using services**
4. **Check service logs if something isn't working**
5. **Verify services are running before testing frontend**

---

## 📚 Additional Resources

- **Quick Start:** `docs/QUICK_START_VAST.md`
- **Fresh Start Guide:** `docs/FRESH_START.md`
- **SSH Setup:** `docs/SSH_SETUP.md`
- **Terminal Guide:** `docs/TERMINAL_GUIDE.md`