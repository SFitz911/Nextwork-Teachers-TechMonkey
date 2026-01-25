# ==========================================
# Relaunch Project - Complete Guide
# ==========================================

## Step 1: Add SSH Key to New VAST Instance

**📍 Desktop PowerShell:**

```powershell
# Get your SSH public key (copies to clipboard automatically)
.\add-ssh-key.ps1
```

This will:
- Display your SSH public key
- Copy it to your clipboard
- Show instructions for adding it

**📍 VAST Dashboard:**
1. Open your instance in the VAST dashboard
2. Open "Manage SSH Keys for Instance" dialog
3. In "Your SSH Keys", click "+ ADD SSH KEY"
4. Paste the key (already in your clipboard)
5. Save

**Note:** The key should appear in both "Your SSH Keys" and "Instance SSH Keys" after adding.

---

## Step 2: Update SSH Connection Details

**📍 Desktop PowerShell:**

After spinning up a new VAST instance, the SSH connection details (port and host) will be different. You need to update the connection scripts:

1. **Get new connection details from VAST dashboard:**
   - Direct: `ssh -p <PORT> root@<IP_ADDRESS>`
   - Proxy: `ssh -p <PORT> root@sshX.vast.ai`

2. **Update connection scripts:**
   - `connect-vast-simple.ps1` - Update the SSH command with new port/host
   - `connect-vast.ps1` - Update both direct and proxy connection details
   - `connect-vast-terminal.ps1` - Update the SSH command

3. **Example of what to update:**
   ```powershell
   # OLD (example):
   ssh -p 11889 root@ssh1.vast.ai ...
   
   # NEW (from your dashboard):
   ssh -p 24285 root@ssh4.vast.ai ...
   ```

4. **Test the connection:**
   ```powershell
   ssh -o ConnectTimeout=10 -p <NEW_PORT> root@<NEW_HOST> "echo 'Connection successful!'"
   ```

5. **Commit and push the updated scripts:**
   ```powershell
   git add connect-vast*.ps1
   git commit -m "Update SSH connection details for new VAST instance"
   git push origin main
   ```

---

## Step 3: Set Up Port Forwarding

**📍 Desktop PowerShell:**

```powershell
# Start port forwarding (keep this window open!)
.\connect-vast-simple.ps1
```

---

## Step 4: Connect to VAST Terminal and Set Up Project

**📍 VAST Terminal** (via SSH or `.\connect-vast-terminal.ps1`):

### For Fresh Instance (First Time Setup):

```bash
# Step 1: Clone the repository
cd ~
git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
cd Nextwork-Teachers-TechMonkey

# Step 2: Verify it cloned correctly
ls -la

# Step 3: Run the complete setup (first time only)
# This will install all dependencies, set up environments, Ollama, n8n, etc.
bash scripts/deploy_no_docker.sh
# Note: This installs Ollama and pulls mistral:7b model (~4GB, 5-10 minutes)

# Step 4: Set up LongCat-Video (this downloads ~40GB of models, takes 30-60 minutes)
bash scripts/deploy_longcat_video.sh

# Step 5: Start all services
bash scripts/quick_start_all.sh

# Step 6: Re-import n8n workflows
bash scripts/force_reimport_workflows.sh
```

### For Existing Instance (After Restart):

```bash
# Navigate to project
cd ~/Nextwork-Teachers-TechMonkey

# Pull latest code
git pull origin main

# Restart all services
bash scripts/restart_after_shutdown.sh
```

---

## Quick Reference

**For future relaunches:**
- Run `bash scripts/deploy_no_docker.sh` (first time setup only)
- Run `bash scripts/deploy_longcat_video.sh` (LongCat-Video setup, first time only)
- Run `bash scripts/quick_start_all.sh` (daily startup)
- Run `bash scripts/force_reimport_workflows.sh` (re-import n8n workflows after restart)

**Port forwarding:**
- Always run `.\connect-vast-simple.ps1` from Desktop PowerShell before accessing services