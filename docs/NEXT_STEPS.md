# Next Steps - Getting the 2-Teacher System Running

## Immediate Actions (Do These Now)

### 1. On VAST Terminal - Pull Latest Changes

```bash
cd ~/Nextwork-Teachers-TechMonkey
git pull origin main
```

### 2. Install Coordinator API Dependencies

```bash
source ~/ai-teacher-venv/bin/activate
pip install fastapi uvicorn httpx
```

### 3. Import New n8n Workflows

```bash
bash scripts/import_new_workflows.sh
```

This will import:
- Session Start workflow
- Left Worker workflow  
- Right Worker workflow

### 4. Start All Services (Includes Coordinator Now)

```bash
bash scripts/start_all_services.sh
```

This starts:
- Ollama (with mistral:7b)
- Coordinator API (port 8004) ← NEW
- n8n (port 5678)
- TTS (port 8001)
- Animation (port 8002) 
- Frontend (port 8501)

### 5. On Desktop PowerShell - Update Port Forwarding

```bash
# Stop existing port forwarding (close SSH window)
# Then restart with new port 8004
.\connect-vast.ps1
```

Or use the simple version:
```bash
.\connect-vast-simple.ps1
```

### 6. Verify Services Are Running

**On VAST Terminal:**
```bash
bash scripts/check_all_services_status.sh
```

You should see:
- ✅ Coordinator API is running
- ✅ n8n is running
- ✅ TTS is running
- ✅ Frontend is running
- ✅ Ollama is running

**On Desktop (with port forwarding active):**
```bash
# Test Coordinator API
curl http://localhost:8004/

# Test n8n
curl http://localhost:5678

# Test Frontend
# Open browser: http://localhost:8501
```

## Testing the System

### Test 1: Start a Session

**On Desktop Browser (http://localhost:8501):**

1. Open the sidebar
2. Select 2 teachers (e.g., "Maya" and "Maximus")
3. Click "🚀 Start Session"
4. You should see a session ID and status

**Or via curl:**
```bash
curl -X POST http://localhost:8004/session/start \
  -H "Content-Type: application/json" \
  -d '{"selectedTeachers": ["teacher_a", "teacher_b"]}'
```

Expected response:
```json
{
  "sessionId": "abc123...",
  "status": "ok",
  "speaker": "teacher_a",
  "renderer": "teacher_b"
}
```

### Test 2: Check Event Stream

```bash
# Replace {sessionId} with actual session ID from Test 1
curl http://localhost:8004/session/{sessionId}/events
```

You should see SSE events streaming (SESSION_STARTED, etc.)

### Test 3: Send Section Snapshot

```bash
curl -X POST http://localhost:8004/session/{sessionId}/section \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "{sessionId}",
    "sectionId": "sec-001",
    "url": "https://example.com",
    "scrollY": 0,
    "visibleText": "This is a test section",
    "selectedText": "test"
  }'
```

This should trigger the renderer to start generating a clip.

### Test 4: Check n8n Executions

**On Desktop Browser:**
1. Go to http://localhost:5678
2. Login (admin/changeme)
3. Go to "Executions" tab
4. You should see executions for:
   - Session Start
   - Left Worker (or Right Worker)

### Test 5: Full End-to-End Test

**On Desktop Browser (http://localhost:8501):**

1. Start a session with 2 teachers
2. In center panel, enter a website URL
3. Click "📷 Capture Current Section"
4. Paste some visible text
5. Click "Send"
6. Watch for:
   - Left/Right panels showing "Rendering..." status
   - Eventually "Speaking..." when clip is ready
   - Video playing in the speaking teacher's panel

## Troubleshooting

### Coordinator API Not Starting

```bash
# Check if it's running
ps aux | grep coordinator

# Check logs
tail -50 logs/coordinator.log

# Start manually
cd ~/Nextwork-Teachers-TechMonkey
source ~/ai-teacher-venv/bin/activate
python services/coordinator/app.py
```

### Workflows Not Imported

```bash
# Check n8n UI: http://localhost:5678
# Go to Workflows tab
# You should see:
#   - Session Start - Fast Webhook
#   - Left Worker - Teacher Pipeline
#   - Right Worker - Teacher Pipeline

# If missing, import manually:
bash scripts/import_new_workflows.sh
```

### Port Forwarding Issues

```bash
# Check if port 8004 is forwarded
# On Desktop PowerShell:
netstat -an | findstr 8004

# Should show: 127.0.0.1:8004 LISTENING

# If not, restart port forwarding:
.\connect-vast.ps1
```

### Events Not Streaming

```bash
# Test SSE endpoint directly
curl -N http://localhost:8004/session/{sessionId}/events

# Should see events like:
# data: {"type":"SESSION_STARTED",...}
# data: {"type":"CLIP_READY",...}
```

### Clips Not Generating

1. Check n8n executions for errors
2. Check TTS service: `curl http://localhost:8001/docs`
3. Check LongCat-Video: `curl http://localhost:8003/docs`
4. Check Ollama: `curl http://localhost:11434/api/tags`

## What to Watch For

### ✅ Success Indicators

- Session starts successfully
- SSE events are received
- n8n executions show "success"
- Clips appear in frontend
- Teachers alternate turns

### ⚠️ Common Issues

- **Empty response from webhook** → Check n8n workflow is activated
- **No events** → Check Coordinator API is running and SSE connection
- **Clips not ready** → Check TTS/LongCat-Video services
- **Turn not swapping** → Check speech-ended notification is being sent

## Next Enhancements (After Testing)

Once basic flow works:

1. **Bridging Clips** - Generate short filler when renderer is late
2. **Better Error Handling** - Fallback to audio-only if video fails
3. **Browser Extension** - Auto-capture section snapshots
4. **Session Persistence** - Save sessions to database
5. **Analytics** - Track clip generation times, turn swaps, etc.

## Need Help?

- Check logs: `tail -f logs/coordinator.log`
- Check n8n UI: http://localhost:5678
- Check service status: `bash scripts/check_all_services_status.sh`
- Review architecture: `docs/TWO_TEACHER_ARCHITECTURE.md`
