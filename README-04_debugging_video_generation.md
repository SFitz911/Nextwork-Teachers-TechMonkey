# Debugging Video Generation - Step-by-Step Guide

## 🎯 Problem: Videos Not Being Produced

If videos aren't appearing in the UI, follow this systematic debugging approach.

---

## Step 1: Run the Diagnostic Script

**On VAST Terminal:**

```bash
cd ~/Nextwork-Teachers-TechMonkey
bash scripts/debug_video_generation.sh
```

This script will check:
- ✅ All services are running (Coordinator, n8n, LongCat-Video, TTS, Ollama)
- ✅ n8n workflows are imported and active
- ✅ Recent error logs
- ✅ Test the complete pipeline end-to-end

---

## Step 2: Verify Service Status

### Check All Services Are Running

```bash
# Check tmux session
tmux attach -t ai-teacher

# Navigate between panes:
# Ctrl+B then arrow keys to switch panes
# Look for errors in each service
```

**Expected Services:**
- ✅ Ollama (port 11434)
- ✅ Coordinator API (port 8004)
- ✅ n8n (port 5678)
- ✅ TTS (port 8001)
- ✅ LongCat-Video (port 8003)
- ✅ Frontend (port 8501)

### Quick Service Check

```bash
# Coordinator API
curl http://localhost:8004/health

# n8n
curl http://localhost:5678/healthz

# LongCat-Video
curl http://localhost:8003/status

# TTS
curl http://localhost:8001/health

# Ollama
curl http://localhost:11434/api/tags
```

---

## Step 3: Verify n8n Workflows

### Check Workflows Are Imported

1. **Open n8n UI:**
   - With port forwarding: http://localhost:5678
   - Or on VAST: http://localhost:5678 (via SSH tunnel)

2. **Check Workflows Tab:**
   - Should see 3 workflows:
     - ✅ "Session Start - Fast Webhook"
     - ✅ "Left Worker - Teacher Pipeline"
     - ✅ "Right Worker - Teacher Pipeline"

3. **Verify They're Active:**
   - Toggle switch should be ON (green) for all 3
   - If not active, click the toggle to activate

### Re-import Workflows (if needed)

```bash
cd ~/Nextwork-Teachers-TechMonkey
bash scripts/force_reimport_workflows.sh
```

---

## Step 4: Test the Pipeline Manually

### Test 1: Create a Session

```bash
curl -X POST http://localhost:8004/session/start \
  -H "Content-Type: application/json" \
  -d '{
    "selectedTeachers": ["teacher_a", "teacher_b"],
    "lessonUrl": "https://www.nextwork.org/projects"
  }'
```

**Expected Response:**
```json
{
  "sessionId": "abc-123-...",
  "speaker": "teacher_a",
  "renderer": "teacher_b"
}
```

### Test 2: Update Section (Triggers Render Job)

```bash
# Replace SESSION_ID with actual session ID from Test 1
curl -X POST http://localhost:8004/session/SESSION_ID/section \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "SESSION_ID",
    "sectionId": "test-1",
    "url": "https://www.nextwork.org/projects",
    "scrollY": 0,
    "visibleText": "Test content for video generation",
    "selectedText": "",
    "userQuestion": "What is this about?",
    "language": "en"
  }'
```

**Expected Response:**
```json
{
  "status": "ok",
  "sectionId": "test-1"
}
```

### Test 3: Check n8n Executions

1. **Open n8n UI:** http://localhost:5678
2. **Go to "Executions" tab**
3. **Look for recent executions:**
   - Should see "Left Worker" or "Right Worker" executions
   - Click on an execution to see details
   - Check for errors (red nodes)

### Test 4: Check Session State

```bash
# Replace SESSION_ID
curl http://localhost:8004/session/SESSION_ID/state
```

**Look for:**
- `"renderer"`: Which teacher is rendering
- `"queues"`: Status of each teacher's queue
  - `"status": "rendering"` = currently processing
  - `"status": "ready"` = clip is ready
  - `"status": "idle"` = no job enqueued (PROBLEM!)

---

## Step 5: Common Issues & Fixes

### Issue 1: "session_not_found" in n8n

**Symptom:** n8n workflow shows `"status": "ignored", "reason": "session_not_found"`

**Cause:** Workflow was triggered manually or session expired

**Fix:** 
- Always create session via frontend or `/session/start` endpoint first
- Don't manually trigger worker workflows

### Issue 2: Render Job Not Enqueued

**Symptom:** `"queues": {"teacher_a": {"status": "idle"}}`

**Check:**
```bash
# Check Coordinator logs
tail -20 logs/coordinator.log | grep -i "enqueue\|render\|job"
```

**Possible Causes:**
- n8n webhook URL incorrect
- n8n not running
- Network connectivity issue

**Fix:**
```bash
# Verify n8n webhook URL in Coordinator
grep -r "webhook" services/coordinator/app.py

# Should be: http://localhost:5678/webhook/...
```

### Issue 3: LLM Generation Fails

**Symptom:** n8n execution stops at "LLM Generate" node

**Check:**
```bash
# Test Ollama directly
curl http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral:7b",
    "prompt": "Hello, this is a test.",
    "stream": false
  }'
```

**Fix:**
- Ensure Ollama is running: `ollama serve`
- Ensure model is pulled: `ollama pull mistral:7b`

### Issue 4: TTS Generation Fails

**Symptom:** n8n execution stops at "TTS Generate" node

**Check:**
```bash
# Test TTS service
curl -X POST http://localhost:8001/tts/generate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello world",
    "voice": "en_US-lessac-medium"
  }'
```

**Fix:**
- Check TTS service is running in tmux
- Check TTS logs: `tail -20 logs/tts.log`

### Issue 5: Video Generation Fails

**Symptom:** n8n execution stops at "Video Generate" node or returns error

**Check:**
```bash
# Check LongCat-Video status
curl http://localhost:8003/status

# Should return:
# {
#   "status": "ready",
#   "model_exists": true,
#   "active_jobs": 0
# }
```

**Common Issues:**
- Models not downloaded: Run `bash scripts/deploy_longcat_video.sh`
- Avatar images missing: Run `bash scripts/fix_avatar_images.sh`
- Service not running: Check tmux pane

**Test Video Generation Directly:**
```bash
curl -X POST http://localhost:8003/generate \
  -H "Content-Type: application/json" \
  -d '{
    "avatar_id": "maya",
    "audio_url": "http://localhost:8001/audio/test.wav",
    "text_prompt": "Hello world",
    "resolution": "480p"
  }'
```

### Issue 6: Clip Ready Not Posted

**Symptom:** Video generates but doesn't appear in UI

**Check:**
```bash
# Check Coordinator logs for clip-ready events
tail -20 logs/coordinator.log | grep -i "clip-ready\|CLIP_READY"
```

**Possible Causes:**
- n8n workflow URL template incorrect
- Coordinator API not receiving POST request
- Session expired

**Fix:**
- Check n8n workflow "POST Clip Ready" node URL:
  - Should be: `http://localhost:8004/session/={{ $json.sessionId }}/clip-ready`
  - Note the `={{` syntax (not `{{`)

---

## Step 6: Check Logs Systematically

### Coordinator API Logs

```bash
tail -50 logs/coordinator.log
```

**Look for:**
- `"Enqueueing render job"` - confirms job was sent
- `"Clip ready"` - confirms clip was received
- `ERROR` or `Exception` - indicates problems

### n8n Logs

```bash
# In tmux, check n8n pane
tmux capture-pane -t ai-teacher:n8n -p | tail -50
```

**Or check n8n execution logs in UI:**
- Open http://localhost:5678
- Go to "Executions" tab
- Click on failed execution
- Check each node for errors

### LongCat-Video Logs

```bash
tail -50 logs/longcat_video.log
```

**Look for:**
- `"Generation failed"` - video generation errors
- `"models_not_found"` - models need to be downloaded
- `"Avatar image not found"` - avatar images missing

---

## Step 7: End-to-End Test

Use the test script:

```bash
bash scripts/test_session_flow.sh
```

This will:
1. Create a session
2. Update a section
3. Wait for processing
4. Check if clip was generated

---

## Step 8: Manual Workflow Testing

If automated tests pass but videos still don't appear:

### Test Each Step Manually

1. **Test LLM:**
   ```bash
   curl http://localhost:11434/api/generate \
     -H "Content-Type: application/json" \
     -d '{"model": "mistral:7b", "prompt": "Explain AI", "stream": false}'
   ```

2. **Test TTS:**
   ```bash
   curl -X POST http://localhost:8001/tts/generate \
     -H "Content-Type: application/json" \
     -d '{"text": "Hello world", "voice": "en_US-lessac-medium"}'
   ```

3. **Test Video:**
   ```bash
   # First get an audio URL from TTS, then:
   curl -X POST http://localhost:8003/generate \
     -H "Content-Type: application/json" \
     -d '{
       "avatar_id": "maya",
       "audio_url": "AUDIO_URL_FROM_TTS",
       "text_prompt": "Hello world",
       "resolution": "480p"
     }'
   ```

---

## Quick Reference: Service URLs

| Service | URL | Health Check |
|---------|-----|--------------|
| Coordinator API | http://localhost:8004 | `/health` |
| n8n | http://localhost:5678 | `/healthz` |
| LongCat-Video | http://localhost:8003 | `/status` |
| TTS | http://localhost:8001 | `/health` |
| Ollama | http://localhost:11434 | `/api/tags` |
| Frontend | http://localhost:8501 | (browser) |

---

## Still Not Working?

If videos still aren't generating after following all steps:

1. **Share the output of:**
   ```bash
   bash scripts/debug_video_generation.sh > debug_output.txt
   ```

2. **Check n8n execution details:**
   - Open http://localhost:5678
   - Go to "Executions" tab
   - Find the most recent execution
   - Screenshot or copy the error messages

3. **Check service logs:**
   ```bash
   # Coordinator
   tail -100 logs/coordinator.log > coordinator_errors.txt
   
   # LongCat-Video
   tail -100 logs/longcat_video.log > longcat_errors.txt
   
   # n8n (from tmux)
   tmux capture-pane -t ai-teacher:n8n -p > n8n_output.txt
   ```

4. **Verify workflow configuration:**
   - Check n8n workflow node settings
   - Verify URLs are correct (localhost, not 127.0.0.1)
   - Check API keys if needed

---

## Next Steps

Once you identify the issue:
1. Fix the specific problem (see fixes above)
2. Re-test with `bash scripts/test_session_flow.sh`
3. Check frontend to see if videos appear
4. If still not working, check the specific error and we'll debug further
