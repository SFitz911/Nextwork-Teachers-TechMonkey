# Troubleshooting SSH Connection to VAST Instance

## Quick Diagnosis Steps

### Step 1: Verify Instance is Running
1. Go to [Vast.ai Dashboard](https://cloud.vast.ai/instances/)
2. Check if your instance shows as "Running" (green status)
3. Note the exact IP address and port number shown in the dashboard
4. **Important:** Port numbers can change if the instance was restarted!

### Step 2: Check Your Connection Details
Your connection details should match what's shown in the Vast.ai dashboard:
- **IP Address**: Usually `50.217.254.161` (but verify in dashboard)
- **Port**: Could be `41366`, `48257`, or another number (check dashboard!)
- **Username**: Usually `root`
- **SSH Method**: Either direct IP or via gateway

### Step 3: Test Basic Connection

#### Option A: Direct Connection (Try First)
```powershell
# Replace PORT with the port from your Vast.ai dashboard
ssh -p PORT root@50.217.254.161
```

#### Option B: Via SSH Gateway (More Reliable)
```powershell
# This uses Vast.ai's SSH gateway (usually more stable)
ssh -p 11071 root@ssh4.vast.ai
```

### Step 4: If Getting "Permission Denied"

#### Check 1: Are you using password or SSH key?
- **Password**: Vast.ai provides a password in the dashboard
- **SSH Key**: You need to add your public key to the instance

#### Check 2: Add SSH Key to Instance
If you want to use SSH key authentication:

1. **On your Windows machine**, check if you have an SSH key:
   ```powershell
   # Check if key exists
   ls ~/.ssh/id_ed25519.pub
   # Or
   ls ~/.ssh/id_rsa.pub
   ```

2. **If no key exists, generate one:**
   ```powershell
   ssh-keygen -t ed25519 -C "sfitz911@gmail.com"
   # Press Enter to accept default location
   # Press Enter twice for no passphrase (or set one)
   ```

3. **Copy your public key:**
   ```powershell
   # Display your public key
   cat ~/.ssh/id_ed25519.pub
   ```

4. **Add key to Vast.ai instance:**
   - **Method 1**: Use Vast.ai dashboard
     - Go to your instance
     - Click "SSH Keys" or "Access" tab
     - Add your public key there
   
   - **Method 2**: Use password first, then add key
     ```powershell
     # Connect with password
     ssh -p PORT root@50.217.254.161
     # Once connected, add your key:
     echo "YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
     ```

### Step 5: Test Connection with Verbose Output
If still having issues, use verbose mode to see what's happening:

```powershell
ssh -v -p PORT root@50.217.254.161
```

This will show detailed connection information and help identify the problem.

### Step 6: Common Issues and Solutions

#### Issue: "Connection refused"
- **Cause**: Instance might be down or port changed
- **Solution**: Check Vast.ai dashboard, restart instance if needed

#### Issue: "Permission denied (publickey)"
- **Cause**: SSH key not added or wrong key
- **Solution**: Add your public key to the instance (see Step 4)

#### Issue: "Connection timed out"
- **Cause**: Firewall or network issue
- **Solution**: Try SSH gateway method instead:
  ```powershell
  ssh -p 11071 root@ssh4.vast.ai
  ```

#### Issue: "Host key verification failed"
- **Cause**: SSH thinks the host key changed (common with Vast.ai)
- **Solution**: Remove old host key:
  ```powershell
  ssh-keygen -R [50.217.254.161]:PORT
  # Or remove all Vast.ai keys:
  ssh-keygen -R ssh4.vast.ai
  ```

### Step 7: Update Connection Script
Once you have the correct port, update `connect-vast.ps1`:

```powershell
# Edit connect-vast.ps1 and update the port number
# Replace 41366 with your actual port from dashboard
```

## Quick Connection Test Script

Save this as `test-connection.ps1`:

```powershell
# Test VAST Connection
param(
    [string]$Port = "41366",
    [string]$IP = "50.217.254.161"
)

Write-Host "Testing connection to VAST instance..." -ForegroundColor Yellow
Write-Host "IP: $IP" -ForegroundColor Cyan
Write-Host "Port: $Port" -ForegroundColor Cyan
Write-Host ""

# Test 1: Direct connection
Write-Host "Test 1: Direct connection..." -ForegroundColor Yellow
ssh -o ConnectTimeout=10 -p $Port root@$IP "echo 'Connection successful!'"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Direct connection works!" -ForegroundColor Green
} else {
    Write-Host "❌ Direct connection failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Test 2: SSH Gateway connection..." -ForegroundColor Yellow
    ssh -o ConnectTimeout=10 -p 11071 root@ssh4.vast.ai "echo 'Connection successful!'"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Gateway connection works!" -ForegroundColor Green
        Write-Host "Use: ssh -p 11071 root@ssh4.vast.ai" -ForegroundColor Cyan
    } else {
        Write-Host "❌ Both connection methods failed" -ForegroundColor Red
        Write-Host "Check Vast.ai dashboard to verify instance is running" -ForegroundColor Yellow
    }
}
```

## Next Steps After Successful Connection

Once you can connect:

1. **Check if services are running:**
   ```bash
   # On the VAST instance
   docker ps
   # Or if using no-docker mode:
   ps aux | grep python
   ```

2. **Check service status:**
   ```bash
   cd ~/Nextwork-Teachers-TechMonkey
   docker compose ps
   # Or
   bash scripts/health_check.py
   ```

3. **Restart services if needed:**
   ```bash
   cd ~/Nextwork-Teachers-TechMonkey
   docker compose restart
   # Or if using no-docker:
   bash scripts/run_no_docker_tmux.sh
   ```
