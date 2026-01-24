# Quick Start: 2-Teacher Live Classroom

## Overview

This guide will get the 2-teacher live classroom system up and running quickly.

## Prerequisites

- VAST.ai instance running
- SSH access configured
- Port forwarding active (Desktop PowerShell)

## Step 1: Pull Latest Changes (VAST Terminal)

```bash
cd ~/Nextwork-Teachers-TechMonkey
git pull origin main
```

## Step 2: Install Coordinator API Dependencies (VAST Terminal)

```bash
source ~/ai-teacher-venv/bin/activate
pip install fastapi uvicorn httpx
```

## Step 3: Start Coordinator API (VAST Terminal)

```bash
# Option A: Direct run
python services/coordinator/app.py

# Option B: In tmux (recommended)
tmux new-window -t ai-teacher -n coordinator
tmux send-keys -t ai-teacher:coordinator "cd ~/Nextwork-Teachers-TechMonkey && source ~/ai-teacher-venv/bin/activate && python services/coordinator/app.py" Enter
```

## Step 4: Import n8n Workflows (VAST Terminal)

```bash
bash scripts/import_new_workflows.sh
```

This imports:
- Session Start workflow
- Left Worker workflow
- Right Worker workflow

## Step 5: Update Port Forwarding (Desktop PowerShell)

```bash
# Stop existing port forwarding (close the SSH window)
# Then restart with new port 8004
.\connect-vast.ps1
```

Or use the simple version:
```bash
.\connect-vast-simple.ps1
```

## Step 6: Verify Services

**On VAST Terminal**:
```bash
# Check Coordinator API
curl http://localhost:8004/

# Check n8n workflows
curl -H "X-N8N-API-KEY: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmMTQ0MTQ2Ny0zOTdlLTRlNjUtOGZlNi1kZTQwOWIzODljYWQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MjI1MzE3fQ.tU1VEaQCrymcz8MIkAWuWfpBJoT9O7R8olTeBe42JJ0" \
  http://localhost:5678/api/v1/workflows | python3 -m json.tool
```

## Step 7: Test Session Start

**On Desktop** (with port forwarding active):
```bash
curl -X POST http://localhost:8004/session/start \
  -H "Content-Type: application/json" \
  -d '{"selectedTeachers": ["teacher_a", "teacher_d"], "lessonUrl": "https://example.com"}'
```

Expected response:
```json
{
  "sessionId": "abc123...",
  "status": "ok",
  "speaker": "teacher_a",
  "renderer": "teacher_d"
}
```

## Step 8: Test Event Stream

**On Desktop** (with port forwarding active):
```bash
# Replace {sessionId} with the sessionId from Step 7
curl http://localhost:8004/session/{sessionId}/events
```

You should see SSE events streaming.

## Next Steps

1. **Update Frontend UI**: Modify the Streamlit frontend to:
   - Show 2-teacher layout (left avatar, center website, right avatar)
   - Connect to SSE event stream
   - Handle CLIP_READY events
   - Auto-play clips and notify on speech-ended

2. **Add Section Snapshot Extraction**: Extract visible text, scroll position, and selected text from the browser

3. **Test End-to-End**: Start a session, send section updates, verify clips are generated and played

## Troubleshooting

### Coordinator API not accessible
- Check if it's running: `ps aux | grep coordinator`
- Check port 8004: `netstat -tlnp | grep 8004`
- Verify port forwarding includes 8004

### n8n workflows not found
- Run: `bash scripts/import_new_workflows.sh`
- Check n8n UI: http://localhost:5678

### Events not streaming
- Verify SSE endpoint: `curl http://localhost:8004/session/{id}/events`
- Check Coordinator logs for errors

## Architecture Details

See `docs/TWO_TEACHER_ARCHITECTURE.md` for full architecture documentation.
