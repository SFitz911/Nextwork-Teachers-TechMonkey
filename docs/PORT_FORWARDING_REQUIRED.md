# Port Forwarding is REQUIRED for Desktop Access

## The Problem

When you run `bash scripts/check_all_services_status.sh` on the VAST instance, it shows:
```
✅ n8n is running (PID: 393)
✅ n8n is accessible on port 5678
```

**BUT** when you try to open `http://localhost:5678` in your Desktop browser, it doesn't work!

## Why This Happens

- ✅ Services ARE running on the VAST instance
- ✅ Services ARE accessible on `localhost` **from the VAST instance**
- ❌ Services are **NOT** accessible on `localhost` **from your Desktop** without SSH port forwarding

## The Solution

**You MUST set up SSH port forwarding on your Desktop before accessing services via localhost URLs.**

### Step 1: Start Port Forwarding (Desktop PowerShell Terminal)

```powershell
.\connect-vast.ps1
```

This opens a new PowerShell window with the SSH connection. **KEEP THAT WINDOW OPEN!**

### Step 2: Verify Port Forwarding (Desktop PowerShell Terminal)

```powershell
.\scripts\check_port_forwarding.ps1
```

You should see:
```
✅ Port 5678 is forwarded and accessible
✅ Port 8501 is forwarded and accessible
✅ Port 8001 is forwarded and accessible
✅ Port 8002 is forwarded and accessible
```

### Step 3: Access Services

Now you can access:
- **n8n**: http://localhost:5678
- **Frontend**: http://localhost:8501
- **TTS**: http://localhost:8001
- **Animation**: http://localhost:8002

## Important Notes

1. **The SSH window must stay open** - Closing it stops port forwarding
2. **Port forwarding is one-way** - It forwards VAST → Desktop, not Desktop → VAST
3. **Services run on VAST** - They're always accessible on VAST's localhost, but Desktop needs the tunnel

## Troubleshooting

### "Port forwarding window closes immediately"

1. Test SSH connection manually:
   ```powershell
   ssh -p 35859 root@ssh7.vast.ai "echo test"
   ```

2. If that fails, check:
   - SSH key is added to VAST instance
   - Instance is running on Vast.ai dashboard
   - Correct port/IP in `connect-vast.ps1`

3. Try the simpler script:
   ```powershell
   .\connect-vast-simple.ps1
   ```

### "Services show as running but localhost doesn't work"

This means port forwarding is not active. Follow Step 1 above.

### "Port forwarding works but services still don't load"

1. Check services are actually running on VAST:
   ```bash
   # On VAST Terminal
   bash scripts/check_all_services_status.sh
   ```

2. Check if services are listening on the correct ports:
   ```bash
   # On VAST Terminal
   netstat -tulpn | grep -E '5678|8501|8001|8002'
   ```

## Quick Reference

| What | Where | Command |
|------|-------|---------|
| Start port forwarding | Desktop PowerShell | `.\connect-vast.ps1` |
| Check port forwarding | Desktop PowerShell | `.\scripts\check_port_forwarding.ps1` |
| Check services running | VAST Terminal | `bash scripts/check_all_services_status.sh` |
| Restart everything | VAST Terminal | `bash scripts/restart_and_setup.sh` |

## Remember

**Services running on VAST ≠ Services accessible from Desktop**

You need the SSH tunnel (port forwarding) to bridge the gap!
