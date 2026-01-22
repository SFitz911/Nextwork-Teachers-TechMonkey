# Port Forwarding Guide

## The Problem You Encountered

When you ran `.\connect-vast.ps1`, the SSH connection closed immediately, which stopped port forwarding. **Port forwarding only works while the SSH session is active.**

## Solution: Updated Script

The `connect-vast.ps1` script now opens SSH in a **NEW PowerShell window** that stays open. This is the correct way to do port forwarding.

## How to Use Port Forwarding

### Step 1: Start Port Forwarding (Desktop PowerShell)

```powershell
cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey
.\connect-vast.ps1
```

**What happens:**
- Opens a NEW PowerShell window
- That window shows "SSH Port Forwarding Active - DO NOT CLOSE THIS WINDOW"
- The SSH connection stays active in that window
- **Keep that window open!**

### Step 2: Verify Port Forwarding (Desktop PowerShell)

In your **original** PowerShell window (not the SSH one):

```powershell
.\scripts\check_port_forwarding.ps1
```

**Expected output:**
```
✅ Port 5678 is forwarded and accessible
✅ Port 8501 is forwarded and accessible
✅ Port 8001 is forwarded and accessible
✅ Port 8002 is forwarded and accessible
```

### Step 3: If Some Ports Fail

If ports 8001 or 8002 show as "NOT accessible", it could mean:

1. **Services aren't running on VAST** (most likely)
2. **Port forwarding window closed** (check if SSH window is still open)

**To check if services are running on VAST:**

SSH into VAST (in a separate terminal, or use the port forwarding window):

```bash
# On VAST Terminal
cd ~/Nextwork-Teachers-TechMonkey
bash scripts/check_all_services_status.sh
```

**If services aren't running, start them:**

```bash
# On VAST Terminal
bash scripts/run_no_docker_tmux.sh
```

## Understanding Port Forwarding

Port forwarding creates a "tunnel" from your local machine to the VAST instance:

```
Your Desktop          SSH Tunnel          VAST Instance
localhost:5678  ────────►  localhost:5678  (n8n)
localhost:8501  ────────►  localhost:8501  (Frontend)
localhost:8001  ────────►  localhost:8001  (TTS)
localhost:8002  ────────►  localhost:8002  (Animation)
```

**Important:** The tunnel only exists while the SSH connection is active. If you close the SSH window, the tunnel closes and ports become inaccessible.

## Troubleshooting

### "Port forwarding is NOT active!"

**Cause:** SSH connection closed or never established

**Fix:**
1. Run `.\connect-vast.ps1` again
2. Make sure the NEW window stays open
3. Wait 3-5 seconds for connection
4. Run `.\scripts\check_port_forwarding.ps1` again

### "Port 8001/8002 NOT accessible" but 5678/8501 work

**Cause:** TTS/Animation services not running on VAST

**Fix:**
1. SSH into VAST (use the port forwarding window or new terminal)
2. Run: `bash scripts/check_all_services_status.sh`
3. If services are down, run: `bash scripts/run_no_docker_tmux.sh`

### "Connection refused" errors

**Cause:** Services not running on VAST

**Fix:** Start services on VAST instance (see above)

## Quick Reference

| Task | Command | Where |
|------|---------|-------|
| Start port forwarding | `.\connect-vast.ps1` | Desktop PowerShell |
| Check port forwarding | `.\scripts\check_port_forwarding.ps1` | Desktop PowerShell |
| Check services on VAST | `bash scripts/check_all_services_status.sh` | VAST Terminal |
| Start services on VAST | `bash scripts/run_no_docker_tmux.sh` | VAST Terminal |

## Best Practice

1. **Always start port forwarding first** before using services
2. **Keep the SSH window open** - minimize it, don't close it
3. **Check port forwarding** after starting to verify it's working
4. **Check services on VAST** if some ports fail
