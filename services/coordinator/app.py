"""
Coordinator API - Session State Management and Event Streaming
Handles turn-taking, job routing, and SSE events for 2-teacher live classroom
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional, List, Dict, Literal
from datetime import datetime
import uuid
import json
import asyncio
from collections import defaultdict
import logging
import httpx
import os

app = FastAPI(title="AI Teacher Coordinator API")

# Configure logging to use storage volume if available
VAST_STORAGE = os.getenv("VAST_STORAGE_PATH", os.getenv("VAST_STORAGE", ""))
if VAST_STORAGE and os.path.exists(VAST_STORAGE):
    LOGS_DIR = os.getenv("COORDINATOR_LOGS_DIR", os.path.join(VAST_STORAGE, "logs/coordinator"))
    os.makedirs(LOGS_DIR, exist_ok=True)
    LOG_FILE = os.path.join(LOGS_DIR, "coordinator.log")
else:
    LOGS_DIR = os.getenv("LOGS_DIR", "logs")
    os.makedirs(LOGS_DIR, exist_ok=True)
    LOG_FILE = os.path.join(LOGS_DIR, "coordinator.log")

# In-memory session store (replace with Redis/DB in production)
sessions: Dict[str, Dict] = {}
event_streams: Dict[str, List] = defaultdict(list)  # sessionId -> list of event listeners

# Set up logging with file handler
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)
logger.info(f"Coordinator API starting - Logs: {LOG_FILE}")


# ============================================================================
# Data Models
# ============================================================================

class SessionStartRequest(BaseModel):
    selectedTeachers: List[str]  # Must be exactly 2
    lessonUrl: Optional[str] = None


class SectionUpdateRequest(BaseModel):
    sessionId: str
    sectionId: str
    url: str
    scrollY: Optional[int] = 0
    visibleText: Optional[str] = ""
    selectedText: Optional[str] = ""
    userQuestion: Optional[str] = None
    language: Optional[str] = None  # Language preference (e.g., "English", "Spanish")
    domDigest: Optional[str] = None


class SpeechEndedRequest(BaseModel):
    sessionId: str
    clipId: str


class ClipReadyRequest(BaseModel):
    sessionId: str
    teacher: str
    clip: Dict  # Full clip object with text, audioUrl, videoUrl, etc.


# ============================================================================
# Session State Management
# ============================================================================

def create_session(selected_teachers: List[str], lesson_url: Optional[str] = None) -> Dict:
    """Create a new session with turn-taking state"""
    if len(selected_teachers) != 2:
        raise ValueError("Must select exactly 2 teachers")
    
    session_id = str(uuid.uuid4())
    left_teacher = selected_teachers[0]
    right_teacher = selected_teachers[1]
    
    session = {
        "sessionId": session_id,
        "activeTeachers": selected_teachers,
        "leftTeacher": left_teacher,
        "rightTeacher": right_teacher,
        "turn": 0,
        "speaker": left_teacher,  # Start with left teacher
        "renderer": right_teacher,  # Right teacher renders first
        "currentSectionId": None,
        "currentSnapshot": None,
        "lessonUrl": lesson_url,
        "language": "English",  # Default language
        "queues": {
            left_teacher: {"status": "idle", "nextClipId": None},
            right_teacher: {"status": "idle", "nextClipId": None}
        },
        "createdAt": datetime.utcnow().isoformat(),
        "status": "active"
    }
    
    sessions[session_id] = session
    logger.info(f"Created session {session_id} with teachers {selected_teachers}")
    return session


def swap_speaker_renderer(session_id: str) -> Dict:
    """Swap speaker and renderer roles"""
    if session_id not in sessions:
        raise ValueError(f"Session {session_id} not found")
    
    session = sessions[session_id]
    old_speaker = session["speaker"]
    old_renderer = session["renderer"]
    
    # Swap roles
    session["speaker"] = old_renderer
    session["renderer"] = old_speaker
    session["turn"] += 1
    
    logger.info(f"Session {session_id}: Swapped speaker {old_speaker} <-> {old_renderer}, turn {session['turn']}")
    return session


def emit_event(session_id: str, event_type: str, data: Dict):
    """Emit an event to all listeners for this session"""
    event = {
        "type": event_type,
        "sessionId": session_id,
        "timestamp": datetime.utcnow().isoformat(),
        **data
    }
    
    # Store event for SSE streams
    if session_id in event_streams:
        for listener in event_streams[session_id]:
            try:
                listener.put_nowait(event)
            except:
                pass  # Listener disconnected
    
    logger.info(f"Emitted {event_type} for session {session_id}")


# ============================================================================
# API Endpoints
# ============================================================================

@app.get("/")
async def root():
    return {
        "service": "Coordinator API",
        "status": "ready",
        "activeSessions": len(sessions)
    }


@app.post("/session/start")
async def start_session(request: SessionStartRequest, background_tasks: BackgroundTasks):
    """Start a new session with 2 teachers"""
    try:
        session = create_session(request.selectedTeachers, request.lessonUrl)
        
        # Emit SESSION_STARTED event
        emit_event(session["sessionId"], "SESSION_STARTED", {
            "leftTeacher": session["leftTeacher"],
            "rightTeacher": session["rightTeacher"],
            "speaker": session["speaker"],
            "renderer": session["renderer"]
        })
        
        # Enqueue first render job for renderer (in background)
        background_tasks.add_task(
            enqueue_render_job,
            session["sessionId"],
            session["renderer"],
            session["speaker"]
        )
        
        return {
            "sessionId": session["sessionId"],
            "status": "ok",
            "speaker": session["speaker"],
            "renderer": session["renderer"]
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/session/{session_id}/section")
async def update_section(session_id: str, request: SectionUpdateRequest):
    """Update the current section/snapshot from UI"""
    if session_id not in sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    
    session = sessions[session_id]
    session["currentSectionId"] = request.sectionId
    session["currentSnapshot"] = {
        "url": request.url,
        "scrollY": request.scrollY,
        "visibleText": request.visibleText,
        "selectedText": request.selectedText,
        "userQuestion": request.userQuestion,
        "language": request.language,
        "domDigest": request.domDigest
    }
    # Store language preference in session
    if request.language:
        session["language"] = request.language
    
    # Emit SECTION_UPDATED event
    emit_event(session_id, "SECTION_UPDATED", {
        "sectionId": request.sectionId,
        "url": request.url
    })
    
    # Enqueue render job for current renderer
    await enqueue_render_job(session_id, session["renderer"], session["speaker"])
    
    return {"status": "ok", "sectionId": request.sectionId}


@app.post("/session/{session_id}/speech-ended")
async def speech_ended(session_id: str, request: SpeechEndedRequest):
    """Called when a clip finishes playing - triggers turn swap"""
    if session_id not in sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    
    session = sessions[session_id]
    
    # Check if renderer's clip is ready
    renderer_queue = session["queues"][session["renderer"]]
    
    if renderer_queue["status"] == "ready":
        # Swap roles
        swap_speaker_renderer(session_id)
        updated_session = sessions[session_id]
        
        # Emit SPEAKER_CHANGED event
        emit_event(session_id, "SPEAKER_CHANGED", {
            "speaker": updated_session["speaker"],
            "renderer": updated_session["renderer"],
            "turn": updated_session["turn"]
        })
        
        # Enqueue render job for new renderer
        await enqueue_render_job(
            session_id,
            updated_session["renderer"],
            updated_session["speaker"]
        )
        
        return {
            "status": "ok",
            "speaker": updated_session["speaker"],
            "renderer": updated_session["renderer"],
            "turn": updated_session["turn"]
        }
    else:
        # Renderer not ready - speaker should use bridging clip
        logger.warning(f"Session {session_id}: Renderer {session['renderer']} not ready, need bridging clip")
        return {
            "status": "renderer_not_ready",
            "message": "Renderer clip not ready, use bridging clip"
        }


@app.post("/session/{session_id}/clip-ready")
async def clip_ready(session_id: str, request: ClipReadyRequest):
    """Called by n8n worker when clip is ready"""
    if session_id not in sessions:
        logger.warning(f"Clip ready for unknown session {session_id}")
        return {"status": "ignored", "reason": "session_not_found"}
    
    session = sessions[session_id]
    
    # Validate teacher is still active
    if request.teacher not in session["activeTeachers"]:
        logger.warning(f"Clip ready for inactive teacher {request.teacher} in session {session_id}")
        return {"status": "ignored", "reason": "teacher_not_active"}
    
    # Update queue status
    session["queues"][request.teacher]["status"] = "ready"
    session["queues"][request.teacher]["nextClipId"] = request.clip.get("clipId")
    
    # Emit CLIP_READY event
    emit_event(session_id, "CLIP_READY", {
        "teacher": request.teacher,
        "clip": request.clip
    })
    
    return {"status": "ok"}


@app.get("/session/{session_id}/state")
async def get_session_state(session_id: str):
    """Get current session state"""
    if session_id not in sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    
    return sessions[session_id]


@app.get("/session/{session_id}/events")
async def stream_events(session_id: str):
    """SSE event stream for session"""
    if session_id not in sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    
    async def event_generator():
        # Create a queue for this listener
        queue = asyncio.Queue()
        event_streams[session_id].append(queue)
        
        try:
            # Send initial connection event
            yield f"data: {json.dumps({'type': 'CONNECTED', 'sessionId': session_id})}\n\n"
            
            while True:
                try:
                    # Wait for event with timeout
                    event = await asyncio.wait_for(queue.get(), timeout=30.0)
                    yield f"data: {json.dumps(event)}\n\n"
                except asyncio.TimeoutError:
                    # Send keepalive
                    yield f": keepalive\n\n"
        finally:
            # Remove listener when disconnected
            if session_id in event_streams:
                try:
                    event_streams[session_id].remove(queue)
                except:
                    pass
    
    return StreamingResponse(event_generator(), media_type="text/event-stream")


# ============================================================================
# Helper Functions
# ============================================================================

async def enqueue_render_job(session_id: str, teacher: str, co_teacher: str):
    """Enqueue a render job for n8n worker"""
    if session_id not in sessions:
        return
    
    session = sessions[session_id]
    
    # Determine which worker (left or right)
    worker_side = "left" if teacher == session["leftTeacher"] else "right"
    
    # Prepare job payload
    job_payload = {
        "sessionId": session_id,
        "teacher": teacher,
        "coTeacher": co_teacher,
        "role": "renderer" if teacher == session["renderer"] else "speaker",
        "sectionPayload": session.get("currentSnapshot", {}),
        "language": session.get("language", "English"),  # Include language preference
        "turn": session["turn"]
    }
    
    # Update queue status
    session["queues"][teacher]["status"] = "rendering"
    
    # Call n8n worker webhook
    worker_url = f"http://localhost:5678/webhook/worker/{worker_side}/run"
    
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(worker_url, json=job_payload)
            if response.status_code == 200:
                logger.info(f"Enqueued render job for {teacher} (worker: {worker_side})")
            else:
                logger.error(f"Failed to enqueue render job: {response.status_code}")
                session["queues"][teacher]["status"] = "error"
    except Exception as e:
        logger.error(f"Error enqueueing render job: {e}")
        session["queues"][teacher]["status"] = "error"


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8004)
