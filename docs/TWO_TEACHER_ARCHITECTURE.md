# 2-Teacher Live Classroom Architecture

## Overview

This document describes the **2-teacher live classroom** system where two teachers alternate turns, with one speaking while the other renders the next clip in the background. This architecture eliminates blocking and provides a seamless, "live" experience.

## Key Principles

1. **No blocking, no merging**: Never synchronize by merging data. Synchronize by state + events.
2. **Two independent pipelines**: Left and Right workers run completely independently.
3. **State machine coordination**: A tiny Coordinator API manages session state and turn-taking.
4. **Event-driven**: UI receives events via SSE/WebSocket, not polling.

## Architecture Components

### 1. Coordinator API (Port 8004)

**Purpose**: Session state management, turn-taking logic, event streaming

**Key Endpoints**:
- `POST /session/start` - Create new session with 2 teachers
- `POST /session/{id}/section` - Update current section/snapshot from UI
- `POST /session/{id}/speech-ended` - Called when clip finishes, triggers turn swap
- `POST /session/{id}/clip-ready` - Called by n8n workers when clip is ready
- `GET /session/{id}/state` - Get current session state
- `GET /session/{id}/events` - SSE event stream for UI

**Session State Schema**:
```json
{
  "sessionId": "abc123",
  "activeTeachers": ["teacher_a", "teacher_d"],
  "leftTeacher": "teacher_a",
  "rightTeacher": "teacher_d",
  "turn": 0,
  "speaker": "teacher_a",
  "renderer": "teacher_d",
  "currentSectionId": "sec-05",
  "currentSnapshot": {
    "url": "https://...",
    "scrollY": 1280,
    "visibleText": "...",
    "selectedText": "..."
  },
  "queues": {
    "teacher_a": {"status": "idle", "nextClipId": null},
    "teacher_d": {"status": "rendering", "nextClipId": "clip-991"}
  }
}
```

### 2. n8n Workflows

#### Session Start Workflow
- **Path**: `/webhook/session/start`
- **Purpose**: Fast webhook that validates and creates session
- **Returns**: `{sessionId, status}` immediately (does NOT wait)

#### Left Worker Workflow
- **Path**: `/webhook/worker/left/run`
- **Purpose**: Complete teacher pipeline for left side
- **Flow**: Extract Payload → Get Session State → Validate Active → LLM → TTS → Video → POST Clip Ready

#### Right Worker Workflow
- **Path**: `/webhook/worker/right/run`
- **Purpose**: Complete teacher pipeline for right side
- **Flow**: Same as Left Worker (identical pipeline)

### 3. Frontend UI

**Layout**:
- Left panel: Teacher A avatar (video)
- Center panel: Website / learning project view
- Right panel: Teacher B avatar (video)
- Bottom: Captions + controls

**Event Handling**:
- Connects to Coordinator SSE stream: `GET /session/{id}/events`
- Listens for: `SESSION_STARTED`, `CLIP_READY`, `SPEAKER_CHANGED`, `SECTION_UPDATED`, `ERROR`
- Auto-plays speaker's clip when ready
- Notifies Coordinator when clip ends: `POST /session/{id}/speech-ended`

## Turn-Taking Flow

```
1. UI starts session → POST /session/start
   ↓
2. Coordinator creates session, sets speaker=left, renderer=right
   ↓
3. Coordinator enqueues render job for renderer (right)
   ↓
4. Right worker renders clip (LLM → TTS → Video)
   ↓
5. Right worker POSTs /clip-ready to Coordinator
   ↓
6. Coordinator emits CLIP_READY event to UI
   ↓
7. UI plays speaker's (left) clip (if ready) or bridging clip
   ↓
8. When clip ends → UI POSTs /speech-ended
   ↓
9. Coordinator swaps: speaker=right, renderer=left
   ↓
10. Coordinator enqueues render job for new renderer (left)
   ↓
11. Repeat from step 4
```

## Event Types

### SESSION_STARTED
```json
{
  "type": "SESSION_STARTED",
  "sessionId": "abc123",
  "leftTeacher": "teacher_a",
  "rightTeacher": "teacher_d",
  "speaker": "teacher_a",
  "renderer": "teacher_d"
}
```

### CLIP_READY
```json
{
  "type": "CLIP_READY",
  "sessionId": "abc123",
  "teacher": "teacher_d",
  "clip": {
    "clipId": "clip-991",
    "text": "Alright, now look at the function...",
    "audioUrl": "http://...",
    "videoUrl": "http://...",
    "durationMs": 8200,
    "status": "completed"
  }
}
```

### SPEAKER_CHANGED
```json
{
  "type": "SPEAKER_CHANGED",
  "sessionId": "abc123",
  "speaker": "teacher_d",
  "renderer": "teacher_a",
  "turn": 1
}
```

## Section Snapshot Format

The UI sends section updates to Coordinator:

```json
{
  "sessionId": "abc123",
  "sectionId": "sec-05",
  "url": "https://yourproject.com/lesson/5",
  "scrollY": 1280,
  "visibleText": "Step 5: Build the API route...",
  "selectedText": "server-side validation",
  "userQuestion": "Why do we validate on the server?"
}
```

## Latency Masking

### Bridging Clips
If renderer is not ready when speaker finishes:
- Speaker generates a short bridging clip (2-4 seconds)
- Examples: "Let me scroll to the next part...", "Okay, now watch this..."

### Clip Length Targets
- Speaker clips: 5-12 seconds
- Renderer clips: 8-20 seconds (can be longer since it's background)

## Failure Handling

### Video Render Fails
- Send `ERROR` event with fallback audio-only
- UI shows avatar with looping idle animation + captions

### Renderer Late
- Speaker uses bridging clip
- Coordinator can dynamically lower clip length target

### Stale Session State
- Workers check "role still valid" before posting results
- If invalid: discard clip (don't confuse UI)

## Setup Instructions

### 1. Start Coordinator API

**On VAST Terminal**:
```bash
cd ~/Nextwork-Teachers-TechMonkey
source ~/ai-teacher-venv/bin/activate
pip install fastapi uvicorn httpx
python services/coordinator/app.py
```

Or add to tmux:
```bash
tmux new-window -t ai-teacher -n coordinator
tmux send-keys -t ai-teacher:coordinator "cd ~/Nextwork-Teachers-TechMonkey && source ~/ai-teacher-venv/bin/activate && python services/coordinator/app.py" Enter
```

### 2. Import n8n Workflows

**On VAST Terminal**:
```bash
cd ~/Nextwork-Teachers-TechMonkey
bash scripts/import_new_workflows.sh
```

### 3. Update Port Forwarding

**On Desktop PowerShell**:
```bash
.\connect-vast.ps1
```

This now includes port 8004 for Coordinator API.

### 4. Test Session Start

```bash
curl -X POST http://localhost:8004/session/start \
  -H "Content-Type: application/json" \
  -d '{"selectedTeachers": ["teacher_a", "teacher_d"], "lessonUrl": "https://example.com"}'
```

## Migration from 5-Teacher System

The old `five-teacher-workflow.json` is kept for reference but is **deprecated**. The new system uses:
- `session-start-workflow.json`
- `left-worker-workflow.json`
- `right-worker-workflow.json`

## Next Steps

1. ✅ Coordinator API implemented
2. ✅ n8n workflows created
3. ⏳ Frontend UI updates (2-teacher layout, SSE event handling)
4. ⏳ Section snapshot extraction from browser
5. ⏳ Bridging clip logic
6. ⏳ Testing end-to-end
