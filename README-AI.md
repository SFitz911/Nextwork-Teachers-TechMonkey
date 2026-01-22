# README-AI.md - AI Virtual Classroom Project Documentation

**Purpose**: This document is designed to be read by AI assistants to quickly understand the current state of the project, problems encountered, solutions implemented, and development patterns. It should be updated whenever significant changes are made.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Key Problems and Solutions](#key-problems-and-solutions)
4. [Development Workflow](#development-workflow)
5. [Common Issues and Fixes](#common-issues-and-fixes)
6. [Scripts Reference](#scripts-reference)
7. [Current State](#current-state)

---

## Project Overview

**AI Virtual Classroom** - A multi-teacher AI educational platform that uses:
- **n8n** for workflow orchestration
- **Ollama** (mistral:7b) for LLM responses
- **TTS Service** for text-to-speech
- **Animation Service** for video generation
- **Streamlit** for the frontend UI

**Deployment**: VAST.ai cloud instance (2x A100 GPUs, 80GB VRAM total)

---

## Architecture

### Services and Ports

| Service | Port | Purpose | Location |
|---------|------|---------|----------|
| n8n | 5678 | Workflow orchestration | VAST |
| Frontend (Streamlit) | 8501 | User interface | VAST |
| TTS API | 8001 | Text-to-speech generation | VAST |
| Animation API | 8002 | Video animation generation | VAST |
| Ollama | 11434 | LLM inference | VAST |

### Data Flow

```
User Input (Frontend)
    ↓
Webhook → n8n Workflow
    ↓
Select Teacher (Round-Robin)
    ↓
LLM Generate (Ollama)
    ↓
TTS Generate
    ↓
Animation Generate
    ↓
Format Response
    ↓
Respond to Webhook
    ↓
Frontend displays response
```

### n8n Workflow Structure

**Workflow Name**: "AI Virtual Classroom - Five Teacher Workflow"

**Key Nodes**:
1. **Webhook Trigger** - Receives POST requests at `/webhook/chat-webhook`
2. **Select Teacher (Round-Robin)** - JavaScript code node that selects teacher
3. **Switch Teacher** - Routes to appropriate teacher configuration
4. **LLM Generate** - Calls Ollama API
5. **Extract LLM Response** - Parses Ollama response
6. **TTS Generate** - Calls TTS service
7. **Prepare Animation** - Prepares data for animation
8. **Animation Generate** - Calls animation service
9. **Format Response** - Formats final response
10. **Respond to Webhook** - Returns response to frontend

**Critical**: The "Respond to Webhook" node MUST exist or the frontend will receive empty responses.

---

## Key Problems and Solutions

### Problem 1: Empty Response from Webhook

**Symptoms**:
- Frontend shows "Empty response from webhook"
- Workflow executes but returns no data

**Root Causes Found**:
1. Missing "Respond to Webhook" node in workflow
2. Workflow not activated
3. Ollama service not running
4. Workflow failing at a node before reaching "Respond to Webhook"

**Solutions**:
- Always verify workflow has "Respond to Webhook" node
- Use `bash scripts/clean_and_import_workflow.sh` to ensure correct workflow
- Check Ollama is running: `pgrep -f "ollama serve"`
- Use `bash scripts/inspect_latest_execution.sh` to see which node failed

---

### Problem 2: Workflow Not Found After Restart

**Symptoms**:
- Scripts can't find workflow
- "Five Teacher workflow not found" error

**Root Cause**:
- n8n workflows are stored in n8n's database
- After VAST instance restart, workflows are not automatically restored
- Workflow must be re-imported after each restart

**Solution**:
- Always run `bash scripts/restart_and_setup.sh` after restart
- Or manually: `bash scripts/clean_and_import_workflow.sh`
- Scripts now check if workflow exists and provide clear error messages

---

### Problem 3: API Key Authentication Issues

**Symptoms**:
- `'X-N8N-API-KEY' header required` errors
- Scripts failing to authenticate
- Empty responses from API calls

**Root Cause**:
- n8n API requires `X-N8N-API-KEY` header for most endpoints
- Basic auth doesn't work for all endpoints (especially `includeData=true`)
- API key format can be JWT token OR `n8n_` prefixed key

**Solution**:
- **API key is now hardcoded as a default fallback** in all scripts
- If `N8N_API_KEY` is set in `.env`, it will be used instead
- Scripts automatically use the hardcoded default if `.env` doesn't have it
- This prevents "API key missing" errors from recurring

**Current API Key Format**: JWT token (hardcoded in scripts, can be overridden via `.env`)

---

### Problem 4: Port Forwarding Not Working

**Symptoms**:
- Can't access services at `localhost:5678`, `localhost:8501`, etc.
- Port forwarding check shows all ports as "NOT accessible"

**Root Cause**:
- SSH port forwarding window was closing immediately
- PowerShell script wasn't keeping SSH session alive

**Solution**:
- Updated `connect-vast.ps1` to open SSH in a new persistent window
- Window stays open and maintains port forwarding
- User must keep that window open while working

**Port Forwarding Setup**:
```powershell
# Desktop PowerShell
.\connect-vast.ps1
# Keep the new window that opens - DO NOT CLOSE IT
```

---

### Problem 5: Ollama Not Running

**Symptoms**:
- Workflow executes but fails at LLM node
- "Ollama is NOT running" in service status

**Root Cause**:
- `run_no_docker_tmux.sh` doesn't start Ollama
- Ollama must be started separately

**Solution**:
- Start Ollama manually: `nohup ollama serve > logs/ollama.log 2>&1 &`
- Or use `bash scripts/restart_and_setup.sh` which starts it automatically
- Verify: `pgrep -f "ollama serve"`

---

### Problem 6: Workflow Missing audio_base64 Parameter

**Symptoms**:
- Animation node failing
- "Piper placeholder" errors in workflow

**Root Cause**:
- Workflow had `audio_base64` parameter that shouldn't be there
- This was a leftover from previous workflow versions

**Solution**:
- Removed `audio_base64` from "Animation Generate" node's `bodyParameters`
- Removed `audio_base64` from "Prepare Animation" node's JavaScript code
- Workflow JSON updated in `n8n/workflows/five-teacher-workflow.json`

---

### Problem 7: Scripts Polluting stdout with Logging

**Symptoms**:
- `export N8N_API_KEY=$(bash scripts/get_or_create_api_key.sh)` captures log messages instead of key
- API key becomes "Getting n8n API key..." instead of actual key

**Root Cause**:
- Scripts printing informational messages to stdout
- Command substitution captures everything printed to stdout

**Solution**:
- All logging/messages redirected to stderr (`>&2`)
- Only the actual API key printed to stdout
- Strict validation: key must match `^n8n_[A-Za-z0-9]+$` OR JWT format
- Script exits with code 1 and no stdout if key can't be obtained

---

## Development Workflow

### After VAST Instance Restart

**Single Command Solution**:
```bash
# On VAST Terminal
bash scripts/restart_and_setup.sh
```

This script:
1. Checks service status
2. Starts services if needed (including Ollama)
3. Waits for n8n to be ready
4. Imports and activates workflow
5. Verifies everything works

**Manual Steps** (if needed):
```bash
# 1. Check services
bash scripts/check_all_services_status.sh

# 2. Start services if not running
bash scripts/run_no_docker_tmux.sh

# 3. Start Ollama if not running
nohup ollama serve > logs/ollama.log 2>&1 &

# 4. Wait for n8n (15-20 seconds)
sleep 15

# 5. Import workflow
bash scripts/clean_and_import_workflow.sh
```

### Desktop Setup (Port Forwarding)

```powershell
# Desktop PowerShell
cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey

# Start port forwarding (opens new window)
.\connect-vast.ps1

# Verify ports are forwarded
.\scripts\check_port_forwarding.ps1
```

**Important**: Keep the SSH port forwarding window open!

### Making Code Changes

1. **Make changes locally**
2. **Test on VAST**:
   ```bash
   # On VAST Terminal
   git pull origin main
   bash scripts/restart_frontend.sh  # If frontend changed
   # Or restart specific service
   ```
3. **Commit and push**:
   ```powershell
   # Desktop PowerShell
   git add .
   git commit -m "Description of changes"
   git push origin main
   ```

---

## Common Issues and Fixes

### Issue: "Empty response from webhook"

**Checklist**:
1. ✅ All services running? `bash scripts/check_all_services_status.sh`
2. ✅ Workflow imported and activated? Check n8n UI or run `bash scripts/clean_and_import_workflow.sh`
3. ✅ Ollama running? `pgrep -f "ollama serve"`
4. ✅ Port forwarding active? `.\scripts\check_port_forwarding.ps1`
5. ✅ Check execution details: `bash scripts/inspect_latest_execution.sh`

### Issue: "Workflow not found"

**Fix**:
```bash
bash scripts/clean_and_import_workflow.sh
```

### Issue: "N8N_API_KEY is not set"

**Note**: This should no longer occur! The API key is now hardcoded as a default fallback in all scripts.

**If you still see this error**:
1. The hardcoded default should work automatically
2. If you want to use a different key, add to `.env`:
   ```bash
   echo "N8N_API_KEY=your_key_here" >> .env
   ```
3. The `.env` value will override the hardcoded default

### Issue: Port forwarding not working

**Fix**:
1. Close any existing SSH windows
2. Run `.\connect-vast.ps1` again
3. Keep the new window open
4. Wait 3-5 seconds, then verify: `.\scripts\check_port_forwarding.ps1`

### Issue: Services not starting

**Check**:
1. Check logs: `tail -50 logs/n8n.log`
2. Check if tmux session exists: `tmux list-sessions`
3. Kill and restart: `tmux kill-session -t ai-teacher && bash scripts/run_no_docker_tmux.sh`

---

## Scripts Reference

### Essential Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `restart_and_setup.sh` | Complete restart: services + workflow | After VAST restart |
| `check_all_services_status.sh` | Check if all services are running | Diagnostic |
| `clean_and_import_workflow.sh` | Delete old workflows, import correct one | When workflow is missing/corrupted |
| `inspect_latest_execution.sh` | Show detailed execution info | Debugging webhook issues |
| `check_execution_nodes.sh` | Show which nodes executed | Debugging workflow flow |
| `run_no_docker_tmux.sh` | Start all services in tmux | Starting services |
| `restart_frontend.sh` | Restart just the frontend | After frontend code changes |

### Desktop Scripts (PowerShell)

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `connect-vast.ps1` | Start SSH port forwarding | Before accessing services |
| `check_port_forwarding.ps1` | Verify ports are forwarded | Diagnostic |
| `sync-to-vast.ps1` | Sync code to VAST and restart | After code changes |

### Script Execution Context

**VAST Terminal**: All bash scripts in `scripts/` directory
**Desktop PowerShell**: PowerShell scripts in root directory

**Important**: Always specify which terminal to use when instructing users!

---

## Current State

### Working Configuration

- ✅ All services running in tmux session `ai-teacher`
- ✅ Ollama running separately (not in tmux)
- ✅ API key stored in `.env` file (JWT token format)
- ✅ Workflow: "AI Virtual Classroom - Five Teacher Workflow"
- ✅ Workflow file: `n8n/workflows/five-teacher-workflow.json`
- ✅ No `audio_base64` parameter in workflow (removed)

### Known Limitations

1. **Workflow must be re-imported after each restart** - n8n doesn't persist workflows automatically
2. **Ollama must be started separately** - not included in `run_no_docker_tmux.sh`
3. **Port forwarding requires persistent window** - can't run in background easily
4. **API key required for most operations** - basic auth doesn't work for all endpoints

### Environment Variables

**Required in `.env`** (optional - defaults are hardcoded):
- `N8N_API_KEY` - API key for n8n (JWT token or `n8n_` prefixed) - **Hardcoded default available**
- `N8N_USER` - n8n username (default: `admin`)
- `N8N_PASSWORD` - n8n password (default: `changeme`)

**Optional**:
- `VENV_DIR` - Virtual environment directory (default: `$HOME/ai-teacher-venv`)

### File Locations

- **Workflow**: `n8n/workflows/five-teacher-workflow.json`
- **Logs**: `logs/` directory (n8n.log, frontend.log, tts.log, animation.log, ollama.log)
- **Scripts**: `scripts/` directory
- **Services**: `services/tts/`, `services/animation/`
- **Frontend**: `frontend/app.py`

---

## Important Notes for AI Assistants

### When Helping Users

1. **Always specify terminal type**: "On VAST Terminal" or "On Desktop PowerShell Terminal"
2. **Check service status first**: Before debugging, verify services are running
3. **Workflow import is common**: After restart, workflow needs to be imported
4. **API key is hardcoded**: Default API key is built into all scripts (can override via `.env`)
5. **Port forwarding is critical**: Services won't be accessible without it

### Common Patterns

- **After restart**: `bash scripts/restart_and_setup.sh`
- **Debugging webhook**: `bash scripts/inspect_latest_execution.sh`
- **Workflow issues**: `bash scripts/clean_and_import_workflow.sh`
- **Service issues**: `bash scripts/check_all_services_status.sh`

### Don't Do

- ❌ Don't try to create API keys automatically (unreliable)
- ❌ Don't assume workflow exists after restart
- ❌ Don't modify workflow logic without understanding the full flow
- ❌ Don't print to stdout in scripts that output values (use stderr for logs)

### Do

- ✅ Always check if workflow exists before trying to use it
- ✅ Load `.env` file in scripts that need credentials (with hardcoded fallbacks)
- ✅ Use API key from `.env` if available, otherwise use hardcoded default
- ✅ Provide clear error messages with next steps
- ✅ Verify services are running before debugging
- ✅ Always specify terminal type in instructions ("VAST Terminal" vs "Desktop PowerShell Terminal")

---

## Update History

**2026-01-22 (Evening)**: 
- **Phase 1 Stabilization Complete**
- Created `validate_config.sh` for configuration validation
- Created `start_all_services.sh` for unified service startup
- Added workflow backup/restore mechanism
- Removed hardcoded credentials from critical scripts
- Created `diagnose_webhook.sh` (consolidated diagnostic script)
- Created `ENV_EXAMPLE.md` for environment setup
- Updated `restart_and_setup.sh` to use new unified scripts
- All scripts now validate configuration before operations

**2026-01-22 (Morning)**: 
- Created comprehensive documentation
- Documented all major problems and solutions
- Created `restart_and_setup.sh` for easy recovery after restart
- Simplified inspection scripts to fail fast with clear messages
- Fixed API key handling to use `.env` file

---

**Last Updated**: 2026-01-22 (Evening)  
**Maintainer**: Update this file whenever significant changes are made to the project
