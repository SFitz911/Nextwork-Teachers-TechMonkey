"""
Shared constants, CSS, and helper functions for the AI Virtual Classroom frontend
"""

import os
import streamlit as st
import requests
import json
import time
import threading
import queue
from typing import Optional, List

# Configuration
COORDINATOR_API_URL = os.getenv("COORDINATOR_API_URL", "http://localhost:8004")
N8N_WEBHOOK_URL = os.getenv("N8N_WEBHOOK_URL", "http://localhost:5678/webhook/session/start")

# Teacher mapping
TEACHERS = {
    "teacher_a": {"name": "Maya", "image": "Nextwork-Teachers/Maya.png"},
    "teacher_b": {"name": "Maximus", "image": "Nextwork-Teachers/Maximus.png"},
    "teacher_c": {"name": "Krishna", "image": "Nextwork-Teachers/krishna.png"},
    "teacher_d": {"name": "TechMonkey Steve", "image": "Nextwork-Teachers/TechMonkey Steve.png"},
    "teacher_e": {"name": "Pano Bieber", "image": "Nextwork-Teachers/Pano Bieber.png"}
}


def get_css_styles():
    """Return the CSS styles as a string"""
    return """
    <style>
    /* Hide Streamlit default elements */
    footer {visibility: hidden;}
    header {visibility: hidden;}
    /* Keep MainMenu visible so users can restore sidebar */
    #MainMenu {visibility: visible !important;}
    
    /* Ensure sidebar is always visible */
    [data-testid="stSidebar"] {
        visibility: visible !important;
        display: block !important;
    }
    
    section[data-testid="stSidebar"] {
        visibility: visible !important;
        display: block !important;
    }
    
    /* Hide any default Streamlit containers that might create boxes */
    .stApp > header {display: none;}
    .stAppViewContainer > div:first-child {padding-top: 0 !important;}
    
    /* Remove box styling from Streamlit column containers */
    div[data-testid="column"] {
        border: none !important;
        padding: 0 !important;
        margin: 0 !important;
        background: transparent !important;
        box-shadow: none !important;
    }
    
    /* Remove box styling from column containers */
    .stColumns > div {
        border: none !important;
        padding: 0 !important;
        margin: 0 !important;
        background: transparent !important;
        box-shadow: none !important;
    }
    
    /* Ensure URL input is prominent */
    .stTextInput > div > div > input {
        font-size: 1.1rem !important;
        padding: 12px !important;
        background-color: #0f172a !important;
        color: #f1f5f9 !important;
        border: 2px solid #3b82f6 !important;
        border-radius: 8px !important;
    }
    
    .stTextInput > label {
        font-size: 1.1rem !important;
        font-weight: 600 !important;
        color: #f1f5f9 !important;
        margin-bottom: 8px !important;
    }
    
    /* Main container */
    .main {
        background: #0f172a;
        padding: 0;
    }
    
    /* Teacher panel styling */
    .teacher-panel {
        background: #1e293b;
        border-radius: 12px;
        padding: 16px;
        margin: 8px;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.3);
        height: calc(100vh - 120px);
        min-height: 600px;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        border: 2px solid transparent;
        transition: all 0.3s ease;
    }
    
    .teacher-panel.speaking {
        border-color: #10b981;
        box-shadow: 0 0 20px rgba(16, 185, 129, 0.4);
        background: #1e3a3a;
    }
    
    .teacher-panel.rendering {
        border-color: #f59e0b;
        box-shadow: 0 0 15px rgba(245, 158, 11, 0.3);
        opacity: 0.9;
    }
    
    /* Center panel */
    .center-panel {
        background: #1e293b;
        border-radius: 12px;
        padding: 20px;
        margin: 8px;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.3);
        height: calc(100vh - 120px);
        min-height: 600px;
        overflow-y: auto;
        display: flex;
        flex-direction: column;
    }
    
    /* Status indicators */
    .status-speaking {
        color: #10b981;
        font-weight: 600;
        font-size: 0.9rem;
    }
    
    .status-rendering {
        color: #f59e0b;
        font-weight: 600;
        font-size: 0.9rem;
    }
    
    .status-idle {
        color: #64748b;
        font-weight: 500;
        font-size: 0.85rem;
    }
    
    /* Input styling */
    .stTextInput>div>div>input {
        background-color: #0f172a;
        color: #f1f5f9;
        border: 1px solid #334155;
    }
    
    /* Button styling */
    .stButton>button {
        background-color: #3b82f6;
        color: white;
        font-weight: 600;
        border-radius: 8px;
        border: none;
        transition: all 0.2s;
    }
    
    .stButton>button:hover {
        background-color: #2563eb;
        transform: translateY(-1px);
    }
    
    /* Sidebar styling */
    .css-1d391kg {
        background-color: #0f172a;
    }
    
    /* Video container */
    .video-container {
        width: 100%;
        max-width: 100%;
        border-radius: 8px;
        overflow: hidden;
    }
    
    /* Caption styling */
    .caption-text {
        color: #cbd5e1;
        font-size: 0.9rem;
        margin-top: 8px;
        text-align: center;
        padding: 8px;
        background: rgba(15, 23, 42, 0.5);
        border-radius: 6px;
    }
    
    /* Ensure images display properly in showcase boxes */
    div[data-testid="stImage"] img {
        border-radius: 16px 16px 0 0 !important;
        width: 100% !important;
        height: auto !important;
    }
    </style>
    """


def initialize_session_state():
    """Initialize all session state variables"""
    if "session_id" not in st.session_state:
        st.session_state.session_id = None
    if "selected_teachers" not in st.session_state:
        st.session_state.selected_teachers = []
    if "speaker" not in st.session_state:
        st.session_state.speaker = None
    if "renderer" not in st.session_state:
        st.session_state.renderer = None
    if "clips" not in st.session_state:
        st.session_state.clips = {}
    if "current_clip" not in st.session_state:
        st.session_state.current_clip = None
    if "event_queue" not in st.session_state:
        st.session_state.event_queue = queue.Queue()
    if "sse_thread" not in st.session_state:
        st.session_state.sse_thread = None
    if "selected_language" not in st.session_state:
        st.session_state.selected_language = "English"
    if "chat_message" not in st.session_state:
        st.session_state.chat_message = ""
    if "website_url" not in st.session_state:
        st.session_state.website_url = ""
    if "url_history" not in st.session_state:
        st.session_state.url_history = ["https://www.nextwork.org/projects"]
    if "selected_url" not in st.session_state:
        st.session_state.selected_url = "https://www.nextwork.org/projects"
    if "speech_recognition_active" not in st.session_state:
        st.session_state.speech_recognition_active = False
    if "transcribed_text" not in st.session_state:
        st.session_state.transcribed_text = ""
    if "speech_recognition_id" not in st.session_state:
        st.session_state.speech_recognition_id = 0
    if "last_played_clip" not in st.session_state:
        st.session_state.last_played_clip = None
    if "replay_clip" not in st.session_state:
        st.session_state.replay_clip = False


def start_session(selected_teachers: List[str], lesson_url: Optional[str] = None) -> Optional[str]:
    """Start a new session with 2 teachers"""
    try:
        response = requests.post(
            f"{COORDINATOR_API_URL}/session/start",
            json={
                "selectedTeachers": selected_teachers,
                "lessonUrl": lesson_url
            },
            timeout=5
        )
        response.raise_for_status()
        data = response.json()
        return data.get("sessionId")
    except Exception as e:
        st.error(f"Failed to start session: {e}")
        return None


def update_section(session_id: str, url: str, scroll_y: int = 0, visible_text: str = "", selected_text: str = "", user_question: Optional[str] = None, language: Optional[str] = None):
    """Update current section snapshot"""
    try:
        response = requests.post(
            f"{COORDINATOR_API_URL}/session/{session_id}/section",
            json={
                "sessionId": session_id,
                "sectionId": f"sec-{int(time.time())}",
                "url": url,
                "scrollY": scroll_y,
                "visibleText": visible_text,
                "selectedText": selected_text,
                "userQuestion": user_question,
                "language": language
            },
            timeout=10
        )
        response.raise_for_status()
    except requests.exceptions.Timeout:
        pass  # Timeout is OK - request was sent
    except Exception as e:
        st.warning(f"Failed to update section: {e}")


def notify_speech_ended(session_id: str, clip_id: str):
    """Notify coordinator that clip finished playing"""
    try:
        requests.post(
            f"{COORDINATOR_API_URL}/session/{session_id}/speech-ended",
            json={
                "sessionId": session_id,
                "clipId": clip_id
            },
            timeout=5
        )
    except Exception:
        pass  # Fail silently


def listen_to_events(session_id: str, event_queue: queue.Queue):
    """Listen to SSE events from Coordinator"""
    try:
        response = requests.get(
            f"{COORDINATOR_API_URL}/session/{session_id}/events",
            stream=True,
            timeout=None
        )
        
        for line in response.iter_lines():
            if line:
                line_str = line.decode('utf-8')
                if line_str.startswith('data: '):
                    try:
                        event_data = json.loads(line_str[6:])
                        event_queue.put(event_data)
                    except json.JSONDecodeError:
                        pass
    except Exception as e:
        event_queue.put({"type": "ERROR", "message": str(e)})


def process_events():
    """Process events from the queue"""
    while not st.session_state.event_queue.empty():
        try:
            event = st.session_state.event_queue.get_nowait()
            if not isinstance(event, dict):
                continue
                
            event_type = event.get("type")
            
            if event_type == "SESSION_STARTED":
                session_id = event.get("sessionId")
                if session_id:
                    st.session_state.session_id = session_id
                    st.session_state.speaker = event.get("speaker")
                    st.session_state.renderer = event.get("renderer")
                    st.rerun()
            
            elif event_type == "CLIP_READY":
                teacher = event.get("teacher")
                clip = event.get("clip")
                if teacher and clip and isinstance(clip, dict):
                    st.session_state.clips[teacher] = clip
                    if teacher == st.session_state.speaker:
                        st.session_state.current_clip = clip
                        st.session_state.last_played_clip = clip  # Store for replay
                        st.rerun()
            
            elif event_type == "SPEAKER_CHANGED":
                new_speaker = event.get("speaker")
                new_renderer = event.get("renderer")
                if new_speaker:
                    st.session_state.speaker = new_speaker
                if new_renderer:
                    st.session_state.renderer = new_renderer
                
                if st.session_state.speaker and st.session_state.speaker in st.session_state.clips:
                    clip = st.session_state.clips[st.session_state.speaker]
                    st.session_state.current_clip = clip
                    st.session_state.last_played_clip = clip  # Store for replay
                    st.rerun()
            
            elif event_type == "ERROR":
                error_msg = event.get('message', 'Unknown error')
                st.error(f"Error: {error_msg}")
        
        except queue.Empty:
            break
        except Exception:
            break
