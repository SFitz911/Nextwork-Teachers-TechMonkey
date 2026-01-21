# Terminal Guide: Desktop vs VAST Terminal

This guide clarifies which terminal to use for different tasks.

## Two Types of Terminals

### 1. Desktop PowerShell Terminal
- **Location**: Your local Windows machine
- **Purpose**: Connect TO the VAST instance, manage local files, push to GitHub
- **Prompt looks like**: `PS E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey>`
- **When to use**: 
  - Testing SSH connections
  - Setting up port forwarding
  - Committing and pushing to GitHub
  - Running local scripts

### 2. VAST Terminal
- **Location**: Cloud instance on Vast.ai
- **Purpose**: Deploy services, run commands on the cloud instance
- **Prompt looks like**: `root@C.XXXXX:~/Nextwork-Teachers-TechMonkey#`
- **When to use**:
  - Cloning repository
  - Running deployment scripts
  - Starting/stopping services
  - Installing packages
  - Checking service status

## How to Identify Which Terminal You're In

### Desktop PowerShell Terminal
```powershell
PS E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey> pwd
# Output: E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey

PS E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey> hostname
# Output: Your Windows computer name
```

### VAST Terminal
```bash
root@C.XXXXX:~/Nextwork-Teachers-TechMonkey# pwd
# Output: /root/Nextwork-Teachers-TechMonkey

root@C.XXXXX:~/Nextwork-Teachers-TechMonkey# hostname
# Output: C.XXXXX (Vast.ai instance ID)
```

## Common Workflows

### Connecting to VAST Instance

**Step 1: Desktop PowerShell Terminal**
```powershell
ssh -p 35859 root@ssh7.vast.ai
```

**Step 2: You're now in VAST Terminal**
```bash
# You'll see: root@C.XXXXX:~#
```

### Setting Up Port Forwarding

**Desktop PowerShell Terminal** (keep this open):
```powershell
.\connect-vast.ps1
```

**VAST Terminal** (separate connection for running commands):
```bash
ssh -p 35859 root@ssh7.vast.ai
cd ~/Nextwork-Teachers-TechMonkey
# Run your deployment commands here
```

### Deploying Services

**VAST Terminal:**
```bash
cd ~/Nextwork-Teachers-TechMonkey
git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
bash scripts/deploy_vast_ai.sh
```

### Committing Changes

**If changes were made on Desktop:**
- Use **Desktop PowerShell Terminal** to commit and push

**If changes were made on VAST instance:**
- Use **VAST Terminal** to commit and push
- Or pull changes to Desktop and push from there

## Quick Reference

| Task | Terminal Type |
|------|---------------|
| Connect to VAST | Desktop PowerShell |
| Clone repository | VAST Terminal |
| Deploy services | VAST Terminal |
| Start/stop services | VAST Terminal |
| Port forwarding | Desktop PowerShell |
| Commit to GitHub | Either (where changes were made) |
| Test connection | Desktop PowerShell |
| Check service logs | VAST Terminal |

## Troubleshooting

**"Command not found" errors:**
- Check which terminal you're in
- PowerShell commands won't work in VAST Terminal (bash)
- Bash commands won't work in Desktop PowerShell

**"Connection refused" errors:**
- Make sure you're using Desktop PowerShell Terminal to connect
- Verify you're using the correct port/IP

**"Permission denied" errors:**
- On VAST Terminal: May need `sudo` for some commands
- On Desktop: Check file permissions
