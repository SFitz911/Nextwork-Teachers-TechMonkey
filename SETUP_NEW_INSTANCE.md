# Setup New VAST Instance - Quick Guide

## Step 1: Get Your SSH Key

**📍 Desktop PowerShell:**

```powershell
.\add-ssh-key.ps1
```

This will:
- Display your SSH public key
- Copy it to your clipboard automatically
- Show instructions

## Step 2: Add SSH Key to VAST Instance

**📍 VAST Dashboard:**

1. Open your instance in the VAST dashboard
2. Click on "Manage SSH Keys for Instance" (or similar button)
3. In "Your SSH Keys" section, click "+ ADD SSH KEY"
4. Paste the key (already in your clipboard from Step 1)
5. Click "Save" or "Add"

**Note:** The key should appear in both "Your SSH Keys" and "Instance SSH Keys" after adding.

## Step 3: Get New Connection Details

**📍 VAST Dashboard:**

Look for the SSH connection information. You'll see two options:

1. **Direct Connection:**
   ```
   ssh -p <PORT> root@<IP_ADDRESS>
   ```
   Example: `ssh -p 28259 root@24.124.32.70`

2. **Proxy/Gateway Connection:**
   ```
   ssh -p <PORT> root@sshX.vast.ai
   ```
   Example: `ssh -p 24285 root@ssh4.vast.ai`

**Write down:**
- Direct port: `________`
- Direct IP: `________`
- Proxy port: `________`
- Proxy host: `________`

## Step 4: Update Connection Scripts

**📍 Desktop PowerShell:**

```powershell
.\update-vast-connection.ps1
```

This script will:
- Ask you for the new connection details
- Update all connection scripts automatically
- Show you what was changed

**Or manually update:**

If you prefer to update manually, edit these files:
- `connect-vast-simple.ps1` - Update proxy connection
- `connect-vast.ps1` - Update both direct and proxy
- `connect-vast-terminal.ps1` - Update proxy connection

## Step 5: Test Connection

**📍 Desktop PowerShell:**

```powershell
# Test proxy connection (recommended)
ssh -p <PROXY_PORT> root@<PROXY_HOST> "echo 'Connection successful!'"

# Or test direct connection
ssh -p <DIRECT_PORT> root@<DIRECT_IP> "echo 'Connection successful!'"
```

If successful, you'll see "Connection successful!"

## Step 6: Start Port Forwarding

**📍 Desktop PowerShell:**

```powershell
.\connect-vast-simple.ps1
```

**IMPORTANT:** Keep this window open! Port forwarding stops if you close it.

## Step 7: Connect to VAST Terminal

**📍 Desktop PowerShell (new window):**

```powershell
.\connect-vast-terminal.ps1
```

This opens a terminal session on the VAST instance.

## Step 8: Set Up Project on VAST

**📍 VAST Terminal:**

```bash
# Clone the repository (if not already cloned)
cd ~
git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
cd Nextwork-Teachers-TechMonkey

# Follow the setup guide
cat README-01_relaunch_project.md
```

## Troubleshooting

### SSH Key Not Working

1. Make sure you added the key in "Your SSH Keys" section
2. The key should appear in "Instance SSH Keys" after adding
3. Try connecting with password first to verify instance is accessible

### Connection Refused

1. Check that the instance is running in VAST dashboard
2. Verify the port and host are correct
3. Try the direct connection if proxy fails (or vice versa)

### Port Forwarding Not Working

1. Make sure the port forwarding window is still open
2. Check that services are running on VAST:
   ```bash
   # On VAST terminal
   tmux list-sessions
   curl http://localhost:8004/status
   ```

## Quick Reference

After setup, you can use:

- **Port Forwarding:** `.\connect-vast-simple.ps1`
- **Terminal Access:** `.\connect-vast-terminal.ps1`
- **Full Connection:** `.\connect-vast.ps1`

All services will be accessible at:
- Frontend: http://localhost:8501
- n8n: http://localhost:5678
- Coordinator API: http://localhost:8004
- TTS: http://localhost:8001
- LongCat-Video: http://localhost:8003
- Ollama: http://localhost:11434
