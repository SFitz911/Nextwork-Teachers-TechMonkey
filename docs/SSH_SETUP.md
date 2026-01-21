# SSH Setup for Vast.ai Deployment

## GitHub Repository
```
https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
```

## SSH Connection Commands

### Direct Connection (If Instance IP Available)
```bash
ssh -p 41366 root@50.217.254.161 -L 8080:localhost:8080
```

### Via Vast.ai SSH Gateway (Recommended)
```bash
ssh -p 11071 root@ssh4.vast.ai -L 8080:localhost:8080
```

## Port Forwarding for All Services

To access all services from your local machine, forward multiple ports:

```bash
# Direct connection with full port forwarding
ssh -p 41366 root@50.217.254.161 \
  -L 5678:localhost:5678 \
  -L 8501:localhost:8501 \
  -L 8001:localhost:8001 \
  -L 8002:localhost:8002 \
  -L 11434:localhost:11434

# Via Vast.ai gateway with full port forwarding
ssh -p 11071 root@ssh4.vast.ai \
  -L 5678:localhost:5678 \
  -L 8501:localhost:8501 \
  -L 8001:localhost:8001 \
  -L 8002:localhost:8002 \
  -L 11434:localhost:11434
```

## Service Ports

- **5678** - n8n orchestration UI
- **8501** - Streamlit frontend
- **8001** - TTS API service
- **8002** - Animation API service
- **11434** - Ollama LLM API
- **6379** - Redis (optional, internal only)

## SSH Key Setup (Optional)

If you want to use SSH key authentication instead of password:

1. **On your local machine**, add your SSH key to the authorized_keys on Vast.ai instance:
   ```bash
   ssh-copy-id -p 41366 root@50.217.254.161
   ```

2. Your SSH public key:
   ```
   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOjUkOMrizf3mTkblsQoLOLTrUBBiy1z46qWgg8WaRp5 sfitz911@gmail.com
   ```

3. You can manually add it to `~/.ssh/authorized_keys` on the Vast.ai instance if needed.

## Quick Connection Script (Windows)

Save this as `connect-vast.ps1`:

```powershell
# Connect to Vast.ai with port forwarding
ssh -p 11071 root@ssh4.vast.ai `
  -L 5678:localhost:5678 `
  -L 8501:localhost:8501 `
  -L 8001:localhost:8001 `
  -L 8002:localhost:8002
```

Or create a `connect-vast.sh` for Git Bash:

```bash
#!/bin/bash
ssh -p 11071 root@ssh4.vast.ai \
  -L 5678:localhost:5678 \
  -L 8501:localhost:8501 \
  -L 8001:localhost:8001 \
  -L 8002:localhost:8002
```

## First-Time Deployment

1. **Connect via SSH:**
   ```bash
   ssh -p 11071 root@ssh4.vast.ai
   ```

2. **Clone the repository:**
   ```bash
   cd ~
   git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git ai-teacher-classroom
   cd ai-teacher-classroom
   ```

3. **Run deployment script:**
   ```bash
   bash scripts/deploy_vast_ai.sh
   ```

4. **After deployment, keep SSH session open for port forwarding in a new terminal:**
   ```bash
   # New terminal window
   ssh -p 11071 root@ssh4.vast.ai -L 5678:localhost:5678 -L 8501:localhost:8501
   ```

5. **Access services locally:**
   - n8n: http://localhost:5678
   - Frontend: http://localhost:8501

## Troubleshooting SSH Connections

### Connection Refused
- Check that the Vast.ai instance is running
- Verify the port number is correct
- Try the Vast.ai SSH gateway instead of direct IP

### Port Already in Use
- Close other SSH sessions using those ports
- Use different local ports: `-L 5679:localhost:5678`

### Timeout Issues
- Vast.ai instances may have connection timeouts
- Keep connection alive: `ssh -o ServerAliveInterval=60 ...`
- Use Vast.ai dashboard to check instance status
