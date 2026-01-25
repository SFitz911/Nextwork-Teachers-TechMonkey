"""
Streamlit Frontend for 2-Teacher Live Classroom
Professional, clean UI with Left Avatar + Center Website + Right Avatar layout
"""

import streamlit as st
import requests
import os
import json
from typing import Optional, Dict, List
import time
import threading
import queue
from datetime import datetime

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

# Page config
st.set_page_config(
    page_title="AI Virtual Classroom",
    page_icon="👨‍🏫",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Professional CSS styling
st.markdown("""
    <style>
    /* Hide Streamlit default elements */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    header {visibility: hidden;}
    
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
    </style>
    """, unsafe_allow_html=True)


# Session state management
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
                        st.rerun()
            
            elif event_type == "SPEAKER_CHANGED":
                new_speaker = event.get("speaker")
                new_renderer = event.get("renderer")
                if new_speaker:
                    st.session_state.speaker = new_speaker
                if new_renderer:
                    st.session_state.renderer = new_renderer
                
                if st.session_state.speaker and st.session_state.speaker in st.session_state.clips:
                    st.session_state.current_clip = st.session_state.clips[st.session_state.speaker]
                    st.rerun()
            
            elif event_type == "ERROR":
                error_msg = event.get('message', 'Unknown error')
                st.error(f"Error: {error_msg}")
        
        except queue.Empty:
            break
        except Exception:
            break


# Sidebar - Session Management
with st.sidebar:
    st.markdown("## 🎯 Session Control")
    
    if not st.session_state.session_id:
        # Teacher selection
        st.markdown("### Select Teachers")
        available_teachers = list(TEACHERS.keys())
        
        teacher_1 = st.selectbox(
            "Teacher 1 (Left)",
            available_teachers,
            format_func=lambda x: TEACHERS[x]["name"],
            key="teacher_1"
        )
        
        teacher_2_options = [t for t in available_teachers if t != teacher_1]
        teacher_2 = st.selectbox(
            "Teacher 2 (Right)",
            teacher_2_options,
            format_func=lambda x: TEACHERS[x]["name"],
            key="teacher_2"
        )
        
        # URL input for lesson with history dropdown
        st.markdown("---")
        st.markdown("### 📚 Lesson URL")
        
        # URL history dropdown
        if st.session_state.url_history:
            selected_history_url = st.selectbox(
                "Select from history",
                options=st.session_state.url_history,
                key="url_history_select",
                label_visibility="collapsed"
            )
            if selected_history_url:
                st.session_state.selected_url = selected_history_url
        
        # URL input with default value
        lesson_url = st.text_input(
            "Enter or select URL",
            value=st.session_state.selected_url,
            key="lesson_url_sidebar",
            placeholder="https://www.nextwork.org/projects"
        )
        
        # Update selected URL when user types
        if lesson_url:
            st.session_state.selected_url = lesson_url
        
        # Language selection
        st.markdown("---")
        st.markdown("### 🌐 Language")
        languages = ["English", "Spanish", "French", "German", "Chinese (Simplified)", "Japanese", "Korean"]
        selected_language = st.selectbox(
            "Select Language",
            options=languages,
            index=0,
            key="language_selectbox",
            label_visibility="collapsed"
        )
        st.session_state.selected_language = selected_language
        
        # Start session button
        if st.button("🚀 Start Session", type="primary", use_container_width=True):
            selected = [teacher_1, teacher_2]
            url_to_use = lesson_url if lesson_url else st.session_state.selected_url
            
            # Add URL to history if it's not already there
            if url_to_use and url_to_use not in st.session_state.url_history:
                st.session_state.url_history.insert(0, url_to_use)
                # Keep only last 10 URLs in history
                if len(st.session_state.url_history) > 10:
                    st.session_state.url_history = st.session_state.url_history[:10]
            
            session_id = start_session(selected, url_to_use if url_to_use else None)
            
            if session_id:
                st.session_state.session_id = session_id
                st.session_state.selected_teachers = selected
                st.session_state.website_url = url_to_use  # Set website URL for session page
                
                if st.session_state.sse_thread is None or not st.session_state.sse_thread.is_alive():
                    st.session_state.sse_thread = threading.Thread(
                        target=listen_to_events,
                        args=(session_id, st.session_state.event_queue),
                        daemon=True
                    )
                    st.session_state.sse_thread.start()
                
                st.success("✅ Session started!")
                st.rerun()
    else:
        # Session active - show status and controls
        st.markdown("### 📊 Session Active")
        st.success(f"**Session:** `{st.session_state.session_id[:12]}...`")
        
        if st.session_state.speaker:
            st.markdown(f"**Speaking:** {TEACHERS[st.session_state.speaker]['name']}")
        if st.session_state.renderer:
            st.markdown(f"**Rendering:** {TEACHERS[st.session_state.renderer]['name']}")
        
        st.markdown("---")
        if st.button("🛑 End Session", use_container_width=True):
            st.session_state.session_id = None
            st.session_state.selected_teachers = []
            st.session_state.speaker = None
            st.session_state.renderer = None
            st.session_state.clips = {}
            st.session_state.current_clip = None
            st.rerun()


# Process events
if st.session_state.session_id:
    process_events()


# Main Content Area - Session Active Page
if st.session_state.session_id and st.session_state.selected_teachers and len(st.session_state.selected_teachers) == 2:
    left_teacher = st.session_state.selected_teachers[0]
    right_teacher = st.session_state.selected_teachers[1]
    
    # Clean three-column layout: Teacher Left | URL Box Center | Teacher Right
    col_left, col_center, col_right = st.columns([1, 2, 1], gap="medium")
    
    # ===== LEFT COLUMN: Teacher (Maya) =====
    with col_left:
        left_speaking = (st.session_state.speaker == left_teacher)
        left_rendering = (st.session_state.renderer == left_teacher)
        
        # Teacher name
        st.markdown(f"### {TEACHERS[left_teacher]['name']}")
        
        # Status indicator
        if left_speaking:
            st.success("🎤 Speaking")
        elif left_rendering:
            st.info("⏳ Rendering")
        else:
            st.caption("💤 Idle")
        
        # Show video/audio or avatar
        if left_speaking and st.session_state.current_clip:
            clip = st.session_state.current_clip
            try:
                if clip.get("videoUrl") and clip.get("videoUrl") != "empty":
                    st.video(clip["videoUrl"])
                    if clip.get("text"):
                        st.caption(clip.get("text", ""))
                elif clip.get("audioUrl"):
                    st.audio(clip["audioUrl"])
                    if clip.get("text"):
                        st.caption(clip.get("text", ""))
            except Exception:
                if clip.get("audioUrl"):
                    try:
                        st.audio(clip["audioUrl"])
                        if clip.get("text"):
                            st.caption(clip.get("text", ""))
                    except Exception:
                        pass
        else:
            # Show avatar image
            try:
                st.image(TEACHERS[left_teacher]["image"], use_container_width=True)
            except Exception:
                st.image("https://via.placeholder.com/400x300?text=Avatar", use_container_width=True)
    
    # ===== CENTER COLUMN: URL Lesson Box =====
    with col_center:
        # Large, prominent URL input box
        website_url = st.text_input(
            "Enter URL to load learning content",
            value=st.session_state.website_url or "",
            key="website_url_input",
            placeholder="https://example.com/lesson",
            label_visibility="visible"
        )
        st.session_state.website_url = website_url
        
        # Embed website if URL provided
        if website_url:
            try:
                st.components.v1.iframe(website_url, height=500, scrolling=True)
            except Exception:
                st.warning("Could not load website. Please check the URL.")
        
        # Chat interface
        st.markdown("---")
        st.markdown("### 💬 Ask a Question")
        
        # Speech recognition component that stores transcript in a hidden input
        if st.session_state.speech_recognition_active:
            speech_html = f"""
            <div id="speech-recognition-wrapper">
                <input type="hidden" id="speech-transcript" value="">
                <input type="hidden" id="should-listen" value="true">
                <script>
                (function() {{
                    let recognition = null;
                    let transcriptText = '';
                    let shouldListen = true;
                    
                    function stopRecognition() {{
                        shouldListen = false;
                        if (recognition) {{
                            recognition.stop();
                            recognition = null;
                        }}
                    }}
                    
                    // Listen for stop signal
                    window.addEventListener('message', function(event) {{
                        if (event.data === 'stop-speech-recognition') {{
                            stopRecognition();
                        }}
                    }});
                    
                    function initSpeechRecognition() {{
                        if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {{
                            alert('Speech recognition not supported in this browser. Please use Chrome, Edge, or Safari.');
                            return;
                        }}
                        
                        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
                        recognition = new SpeechRecognition();
                        recognition.continuous = true;
                        recognition.interimResults = true;
                        recognition.lang = 'en-US';
                        
                        recognition.onresult = function(event) {{
                            if (!shouldListen) return;
                            
                            transcriptText = '';
                            for (let i = event.resultIndex; i < event.results.length; i++) {{
                                transcriptText += event.results[i][0].transcript;
                            }}
                            
                            // Store in hidden input
                            const hiddenInput = document.getElementById('speech-transcript');
                            if (hiddenInput) {{
                                hiddenInput.value = transcriptText;
                            }}
                            
                            // Update visible text input
                            const textInputs = window.parent.document.querySelectorAll('input[type="text"]');
                            for (let input of textInputs) {{
                                if (input.placeholder && (input.placeholder.includes('Type your question') || input.placeholder.includes('Talk to text'))) {{
                                    input.value = transcriptText;
                                    // Trigger input event
                                    input.dispatchEvent(new Event('input', {{ bubbles: true }}));
                                    input.dispatchEvent(new Event('change', {{ bubbles: true }}));
                                    break;
                                }}
                            }}
                        }};
                        
                        recognition.onerror = function(event) {{
                            console.error('Speech recognition error:', event.error);
                            if (event.error === 'not-allowed') {{
                                alert('Microphone permission denied. Please allow microphone access and try again.');
                                shouldListen = false;
                            }}
                        }};
                        
                        recognition.onend = function() {{
                            // Only auto-restart if we should still be listening
                            if (shouldListen && document.getElementById('speech-transcript')) {{
                                try {{
                                    recognition.start();
                                }} catch (e) {{
                                    // Already started or error
                                }}
                            }}
                        }};
                        
                        try {{
                            recognition.start();
                        }} catch (e) {{
                            console.error('Error starting recognition:', e);
                        }}
                    }}
                    
                    // Initialize when page loads
                    if (document.readyState === 'loading') {{
                        document.addEventListener('DOMContentLoaded', initSpeechRecognition);
                    }} else {{
                        setTimeout(initSpeechRecognition, 100);
                    }}
                }})();
                </script>
            </div>
            """
            st.components.v1.html(speech_html, height=0)
        
        # Stop recognition when button is clicked to stop
        if not st.session_state.speech_recognition_active:
            stop_script = """
            <script>
            window.postMessage('stop-speech-recognition', '*');
            </script>
            """
            st.components.v1.html(stop_script, height=0)
        
        # Chat input with speech-to-text
        chat_col1, chat_col2, chat_col3 = st.columns([3, 1, 1])
        
        with chat_col1:
            # Dynamic placeholder based on speech recognition state
            if st.session_state.speech_recognition_active:
                placeholder_text = "🎤 Listening... Speak your question"
            else:
                placeholder_text = "Type your question or click 🎤 Talk for speech-to-text"
            
            chat_message = st.text_input(
                "Type your question",
                value=st.session_state.chat_message,
                key="chat_input",
                placeholder=placeholder_text,
                label_visibility="collapsed"
            )
            st.session_state.chat_message = chat_message
        
        with chat_col2:
            # Push-to-talk button
            button_label = "🎤 Stop" if st.session_state.speech_recognition_active else "🎤 Talk"
            button_type = "secondary" if st.session_state.speech_recognition_active else "primary"
            if st.button(button_label, type=button_type, use_container_width=True, key="speech_button"):
                st.session_state.speech_recognition_active = not st.session_state.speech_recognition_active
                st.rerun()
        
        with chat_col3:
            if st.button("📤 Send", type="primary", use_container_width=True):
                if chat_message and st.session_state.session_id:
                    update_section(
                        st.session_state.session_id,
                        website_url,
                        0,
                        "",
                        "",
                        chat_message,
                        st.session_state.selected_language
                    )
                    st.success("✅ Question sent!")
                    st.session_state.chat_message = ""
                    st.rerun()
        
        # Show speech recognition status
        if st.session_state.speech_recognition_active:
            st.info("🎤 Listening... Speak now! (Click Stop when done)")
            # Auto-refresh to capture transcript updates
            time.sleep(0.5)
            st.rerun()
    
    # ===== RIGHT COLUMN: Teacher (Maximus) =====
    with col_right:
        right_speaking = (st.session_state.speaker == right_teacher)
        right_rendering = (st.session_state.renderer == right_teacher)
        
        # Teacher name
        st.markdown(f"### {TEACHERS[right_teacher]['name']}")
        
        # Status indicator
        if right_speaking:
            st.success("🎤 Speaking")
        elif right_rendering:
            st.info("⏳ Rendering")
        else:
            st.caption("💤 Idle")
        
        # Show video/audio or avatar
        if right_speaking and st.session_state.current_clip:
            clip = st.session_state.current_clip
            try:
                if clip.get("videoUrl") and clip.get("videoUrl") != "empty":
                    st.video(clip["videoUrl"])
                    if clip.get("text"):
                        st.caption(clip.get("text", ""))
                elif clip.get("audioUrl"):
                    st.audio(clip["audioUrl"])
                    if clip.get("text"):
                        st.caption(clip.get("text", ""))
            except Exception:
                if clip.get("audioUrl"):
                    try:
                        st.audio(clip["audioUrl"])
                        if clip.get("text"):
                            st.caption(clip.get("text", ""))
                    except Exception:
                        pass
        else:
            # Show avatar image
            try:
                st.image(TEACHERS[right_teacher]["image"], use_container_width=True)
            except Exception:
                st.image("https://via.placeholder.com/400x300?text=Avatar", use_container_width=True)

else:
    # Welcome screen - no session active
    st.markdown("""
    <div style="text-align: center; padding: 40px 20px;">
        <h1 style="color: #f1f5f9; margin-bottom: 20px;">👨‍🏫 AI Virtual Classroom</h1>
        <p style="color: #94a3b8; font-size: 1.2rem;">
            Start a session with 2 AI teachers to begin your learning journey
        </p>
    </div>
    """, unsafe_allow_html=True)

# Auto-refresh for event processing
if st.session_state.session_id:
    time.sleep(0.5)
    st.rerun()
