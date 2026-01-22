# Script Audit and Usage Guide

## Where to Run Scripts

### Desktop PowerShell Terminal
- **Location**: Your Windows Desktop PowerShell
- **Scripts**: All `.ps1` files
- **Purpose**: Local checks, port forwarding, syncing to VAST

### VAST Terminal (SSH)
- **Location**: SSH session to your VAST AI instance
- **Scripts**: All `.sh` (bash) files
- **Purpose**: Running on the actual server where services are running

---

## Webhook Diagnostic Scripts (VAST Terminal)

You have **multiple scripts** that diagnose webhook issues. Here's when to use each:

### 1. `diagnose_webhook_issue.sh` ⭐ **RECOMMENDED FIRST**
**Run on**: VAST Terminal
```bash
bash scripts/diagnose_webhook_issue.sh
```
**What it does**:
- Checks workflow configuration
- Verifies "Respond to Webhook" node exists
- Activates workflow if needed
- Tests webhook
- Checks recent executions
- Shows n8n logs

**Use when**: You're getting empty responses and want a comprehensive check.

---

### 2. `debug_webhook_execution.sh`
**Run on**: VAST Terminal
```bash
bash scripts/debug_webhook_execution.sh
```
**What it does**:
- Gets workflow ID
- Shows recent executions with detailed status
- Shows which nodes executed/failed
- Tests webhook with timing info
- Checks n8n logs for errors

**Use when**: You want to see exactly which node in the workflow is failing.

---

### 3. `check_workflow_execution.sh`
**Run on**: VAST Terminal
```bash
bash scripts/check_workflow_execution.sh
```
**What it does**:
- Checks if services are running (Ollama, TTS, Animation, n8n)
- Gets workflow details
- Shows recent executions
- Tests Ollama directly
- Provides summary and recommendations

**Use when**: You want to check service status AND workflow execution together.

---

### 4. `inspect_latest_execution.sh`
**Run on**: VAST Terminal
```bash
bash scripts/inspect_latest_execution.sh
```
**What it does**:
- Gets the latest execution ID
- Shows detailed execution data
- Shows which nodes ran and their outputs
- Checks if "Respond to Webhook" node executed

**Use when**: You want to see the detailed output of the most recent execution.

---

### 5. `check_and_fix_webhook.sh`
**Run on**: VAST Terminal
```bash
bash scripts/check_and_fix_webhook.sh
```
**What it does**:
- Checks workflow is active
- Activates workflow if needed
- Tests webhook multiple times (waits up to 30 seconds)
- Helps with webhook registration timing issues

**Use when**: Webhook returns 404 or "not registered" errors.

---

### 6. `simple_webhook_test.sh`
**Run on**: VAST Terminal
```bash
bash scripts/simple_webhook_test.sh
```
**What it does**:
- Simple webhook test
- Shows HTTP status and response body
- Validates JSON

**Use when**: You just want a quick webhook test without all the diagnostics.

---

### 7. `test_webhook_full.sh`
**Run on**: VAST Terminal
```bash
bash scripts/test_webhook_full.sh
```
**What it does**:
- Tests webhook with a full message
- Shows HTTP status and full response
- Validates and pretty-prints JSON
- Explains possible causes if empty

**Use when**: You want a detailed webhook test with better output formatting.

---

## Port Forwarding Scripts (Desktop PowerShell)

### `check_port_forwarding.ps1`
**Run on**: Desktop PowerShell Terminal
```powershell
.\scripts\check_port_forwarding.ps1
```
**What it does**:
- Checks if ports 5678, 8501, 8001, 8002 are forwarded
- Tells you if port forwarding is active

**Use when**: You can't access services at localhost and need to verify port forwarding.

---

## Quick Decision Tree

**Getting "Empty response from webhook" error?**

1. **First**: Check port forwarding (Desktop PowerShell)
   ```powershell
   .\scripts\check_port_forwarding.ps1
   ```
   If ports aren't forwarded, run `.\connect-vast.ps1`

2. **Then**: Run comprehensive diagnostic (VAST Terminal)
   ```bash
   bash scripts/diagnose_webhook_issue.sh
   ```

3. **If workflow is failing**: See which node failed (VAST Terminal)
   ```bash
   bash scripts/debug_webhook_execution.sh
   ```

4. **If services are down**: Check service status (VAST Terminal)
   ```bash
   bash scripts/check_workflow_execution.sh
   ```

---

## Script Consolidation Recommendations

You have significant overlap. Consider:

1. **Keep**: `diagnose_webhook_issue.sh` (most comprehensive)
2. **Keep**: `debug_webhook_execution.sh` (detailed node-level debugging)
3. **Keep**: `check_workflow_execution.sh` (service + workflow check)
4. **Consider removing**: `simple_webhook_test.sh` (use `test_webhook_full.sh` instead)
5. **Consider merging**: `check_and_fix_webhook.sh` into `diagnose_webhook_issue.sh`

---

## Common Issues and Which Script to Use

| Issue | Script to Run | Where |
|-------|---------------|-------|
| Empty webhook response | `diagnose_webhook_issue.sh` | VAST Terminal |
| Can't connect to services | `check_port_forwarding.ps1` | Desktop PowerShell |
| Workflow node failing | `debug_webhook_execution.sh` | VAST Terminal |
| Services not running | `check_workflow_execution.sh` | VAST Terminal |
| Webhook 404 error | `check_and_fix_webhook.sh` | VAST Terminal |
| Quick webhook test | `test_webhook_full.sh` | VAST Terminal |
