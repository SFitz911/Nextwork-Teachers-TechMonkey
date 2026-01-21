# SSH Setup for Vast.ai Deployment

## Important: Terminal Types

- **Desktop PowerShell Terminal**: Your local Windows machine (where you run commands to connect TO the VAST instance)
- **VAST Terminal**: The cloud instance on Vast.ai (where you deploy and run services)

## GitHub Repository
```
https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
```

## SSH Connection Commands

### Direct Connection (Desktop PowerShell Terminal)
```powershell
ssh -p 41428 root@50.217.254.161 -L 8080:localhost:8080
```

### Via Vast.ai SSH Gateway (Desktop PowerShell Terminal - Recommended)
```powershell
ssh -p 35859 root@ssh7.vast.ai -L 8080:localhost:8080
```

## Port Forwarding for All Services

**Run these commands in your Desktop PowerShell Terminal** to access services from your local machine:

```powershell
# Direct connection with full port forwarding (Desktop PowerShell Terminal)
ssh -p 41428 root@50.217.254.161 `
  -L 5678:localhost:5678 `
  -L 8501:localhost:8501 `
  -L 8001:localhost:8001 `
  -L 8002:localhost:8002 `
  -L 11434:localhost:11434

# Via Vast.ai gateway with full port forwarding (Desktop PowerShell Terminal - Recommended)
ssh -p 35859 root@ssh7.vast.ai `
  -L 5678:localhost:5678 `
  -L 8501:localhost:8501 `
  -L 8001:localhost:8001 `
  -L 8002:localhost:8002 `
  -L 11434:localhost:11434
```

## Service Ports

- **5678** - n8n orchestration UI
- **8501** - Streamlit frontend
- **8001** - TTS API service
- **8002** - Animation API service
- **11434** - Ollama LLM API
- **6379** - Redis (optional, internal only)

## SSH Key Setup

Your SSH public key (already configured on the instance):
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOjUkOMrizf3mTkblsQoLOLTrUBBiy1z46qWgg8WaRp5 sfitz911@gmail.com
```

**To add this key to a new instance (Desktop PowerShell Terminal):**
```powershell
# Copy your public key to clipboard
Get-Content ~/.ssh/id_ed25519.pub | Set-Clipboard

# Then add it via Vast.ai dashboard, or manually on the VAST Terminal:
# ssh -p 35859 root@ssh7.vast.ai
# echo 'YOUR_PUBLIC_KEY' >> ~/.ssh/authorized_keys
# chmod 600 ~/.ssh/authorized_keys
```

## Quick Connection Script (Desktop PowerShell Terminal)

Use the provided `connect-vast.ps1` script:

```powershell
# From Desktop PowerShell Terminal
cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey
.\connect-vast.ps1
```

This will connect via gateway (ssh7.vast.ai:35859) with full port forwarding.

Or use direct connection:
```powershell
.\connect-vast.ps1 direct
```

## First-Time Deployment

1. **Connect via SSH (Desktop PowerShell Terminal):**
   ```powershell
   ssh -p 35859 root@ssh7.vast.ai
   ```
   You're now in the **VAST Terminal** (cloud instance).

2. **Clone the repository (VAST Terminal):**
   ```bash
   cd ~
   git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
   cd Nextwork-Teachers-TechMonkey
   ```

3. **Run deployment script (VAST Terminal):**
   ```bash
   bash scripts/deploy_vast_ai.sh
   ```

4. **After deployment, open a NEW Desktop PowerShell Terminal for port forwarding:**
   ```powershell
   # New Desktop PowerShell Terminal window
   cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey
   .\connect-vast.ps1
   ```
   Keep this terminal open - it maintains the tunnel.

5. **Access services from your Desktop browser:**
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
