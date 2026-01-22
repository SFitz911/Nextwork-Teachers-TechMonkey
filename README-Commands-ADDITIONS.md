# Additional Sections to Add to README-Commands.md

## Add after line 25 (after "Restarts all services"):

**With Port Forwarding (Opens SSH in new window):**
```powershell
.\sync-to-vast.ps1 "Your commit message" -PortForward
```

And add to the list:
- ✅ (Optional) Starts SSH port forwarding in new PowerShell window

## Add after line 37 (after "Restart all services with the new code"):

### Verify Services and Activate Workflow

**On your Desktop PowerShell:**
```powershell
cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey
.\verify-and-activate.ps1
```

This will:
- ✅ Test all service endpoints
- ✅ Provide step-by-step instructions for activating n8n workflow
- ✅ Optionally open n8n in your browser
- ✅ Guide you through testing the frontend

## Add after line 144 (after manual SSH command):

**Option 3: Automatic via sync script**
```powershell
.\sync-to-vast.ps1 "Your message" -PortForward
```

## Add after line 183 (after Check Service Logs section):

### Verify Services from Desktop (PowerShell)

```powershell
.\verify-and-activate.ps1
```

This script will:
- Test all service endpoints
- Check if they're accessible via port forwarding
- Provide step-by-step activation instructions

## Update line 201 (Sync to VAST instance section):

Change from:
```powershell
.\sync-to-vast.ps1 "Your commit message"
```

To:
```powershell
# Basic sync
.\sync-to-vast.ps1 "Your commit message"

# Sync with automatic port forwarding
.\sync-to-vast.ps1 "Your commit message" -PortForward
```

## Add after line 208 (after bash scripts/sync_and_restart.sh):

4. **Verify and activate workflow:**
   ```powershell
   .\verify-and-activate.ps1
   ```

## Add after line 251 (after "Click to activate"):

**Or use the verification script:**
```powershell
.\verify-and-activate.ps1
```

## Update Best Practices section (line 290-294):

Add:
3. **Use `-PortForward` flag to automatically start SSH port forwarding**
4. **Use `verify-and-activate.ps1` to check services and get activation instructions**

(Then renumber the rest)

## Add before "Additional Resources" section:

## 🚀 Complete Setup Workflow

### First Time Setup or Full Reset

1. **Sync code and start port forwarding:**
   ```powershell
   .\sync-to-vast.ps1 "Initial setup" -PortForward
   ```

2. **Verify services:**
   ```powershell
   .\verify-and-activate.ps1
   ```

3. **Follow the verification script instructions to:**
   - Log into n8n
   - Activate the workflow
   - Test the frontend

### Daily Development Workflow

1. **Make code changes locally**
2. **Sync with port forwarding:**
   ```powershell
   .\sync-to-vast.ps1 "Your changes" -PortForward
   ```
3. **Test in browser** (port forwarding is already active)
