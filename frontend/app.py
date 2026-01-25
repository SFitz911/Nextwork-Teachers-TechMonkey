"""
Streamlit Frontend for 2-Teacher Live Classroom
Left Avatar + Center Website + Right Avatar layout with SSE event streaming
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
    page_title="AI Virtual Classroom - 2 Teacher Live",
    page_icon="👨‍🏫",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for 2-teacher layout
st.markdown("""
    <style>
    .main {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        padding: 1rem;
    }
    .teacher-panel {
        background: white;
        border-radius: 10px;
        padding: 20px;
        margin: 10px;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        height: 600px;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
    }
    .center-panel {
        background: white;
        border-radius: 10px;
        padding: 20px;
        margin: 10px;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        height: 600px;
        overflow-y: auto;
    }
    .speaking {
        border: 3px solid #4CAF50;
        box-shadow: 0 0 20px rgba(76, 175, 80, 0.5);
    }
    .rendering {
        border: 3px solid #FF9800;
        opacity: 0.8;
    }
    .stButton>button {
        width: 100%;
        background-color: #667eea;
        color: white;
        font-weight: bold;
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
    st.session_state.clips = {}  # teacher_id -> clip data
if "current_clip" not in st.session_state:
    st.session_state.current_clip = None  # Currently playing clip
if "event_queue" not in st.session_state:
    st.session_state.event_queue = queue.Queue()
if "sse_thread" not in st.session_state:
    st.session_state.sse_thread = None
if "selected_language" not in st.session_state:
    st.session_state.selected_language = "English"
if "chat_message" not in st.session_state:
    st.session_state.chat_message = ""
if "push_to_talk_active" not in st.session_state:
    st.session_state.push_to_talk_active = False


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
        # Use longer timeout since Coordinator may trigger n8n workflows
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
            timeout=10  # Increased from 2 to 10 seconds to allow for n8n workflow triggering
        )
        response.raise_for_status()
    except requests.exceptions.Timeout:
        # Timeout is OK - the request was sent, Coordinator will process it
        st.info("⏳ Section update sent (processing in background)")
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
            timeout=5  # Increased from 2 to 5 seconds
        )
    except Exception as e:
        st.warning(f"Failed to notify speech ended: {e}")


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
                        event_data = json.loads(line_str[6:])  # Remove 'data: ' prefix
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
            event_type = event.get("type")
            
            if event_type == "SESSION_STARTED":
                st.session_state.session_id = event.get("sessionId")
                st.session_state.speaker = event.get("speaker")
                st.session_state.renderer = event.get("renderer")
                st.rerun()
            
            elif event_type == "CLIP_READY":
                teacher = event.get("teacher")
                clip = event.get("clip")
                st.session_state.clips[teacher] = clip
                
                # If this is the speaker's clip, start playing it
                if teacher == st.session_state.speaker:
                    st.session_state.current_clip = clip
                    st.rerun()
            
            elif event_type == "SPEAKER_CHANGED":
                st.session_state.speaker = event.get("speaker")
                st.session_state.renderer = event.get("renderer")
                
                # Check if new speaker has a ready clip
                if st.session_state.speaker in st.session_state.clips:
                    st.session_state.current_clip = st.session_state.clips[st.session_state.speaker]
                    st.rerun()
            
            elif event_type == "ERROR":
                st.error(f"Error: {event.get('message', 'Unknown error')}")
        
        except queue.Empty:
            break


# Main UI
st.title("👨‍🏫 AI Virtual Classroom - 2 Teacher Live")

# Sidebar for session management
with st.sidebar:
    st.header("🎯 Session Control")
    
    # Teacher selection (must choose exactly 2)
    st.subheader("Select 2 Teachers")
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
    
    lesson_url = st.text_input("Lesson URL (optional)", value="")
    
    # Language selection
    st.markdown("---")
    st.subheader("🌐 Language")
    languages = {
        "English": "en",
        "Spanish": "es",
        "French": "fr",
        "German": "de",
        "Chinese (Simplified)": "zh-CN",
        "Japanese": "ja",
        "Korean": "ko",
        "Portuguese": "pt",
        "Italian": "it",
        "Russian": "ru"
    }
    selected_language = st.selectbox(
        "Select Language",
        options=list(languages.keys()),
        index=0,
        key="language_selectbox"
    )
    st.session_state.selected_language = selected_language
    
    if st.button("🚀 Start Session", type="primary"):
        selected = [teacher_1, teacher_2]
        session_id = start_session(selected, lesson_url if lesson_url else None)
        
        if session_id:
            st.session_state.session_id = session_id
            st.session_state.selected_teachers = selected
            
            # Start SSE listener thread
            if st.session_state.sse_thread is None or not st.session_state.sse_thread.is_alive():
                st.session_state.sse_thread = threading.Thread(
                    target=listen_to_events,
                    args=(session_id, st.session_state.event_queue),
                    daemon=True
                )
                st.session_state.sse_thread.start()
            
            st.success(f"✅ Session started: {session_id[:8]}...")
            st.rerun()
    
    if st.session_state.session_id:
        st.markdown("---")
        st.subheader("📊 Session Status")
        st.info(f"**Session ID:** {st.session_state.session_id[:16]}...")
        if st.session_state.speaker:
            st.success(f"**Speaking:** {TEACHERS[st.session_state.speaker]['name']}")
        if st.session_state.renderer:
            st.info(f"**Rendering:** {TEACHERS[st.session_state.renderer]['name']}")
        
        if st.button("🛑 End Session"):
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

# Main layout: Left Avatar | Center Website | Right Avatar
if st.session_state.session_id and len(st.session_state.selected_teachers) == 2:
    col_left, col_center, col_right = st.columns([1, 2, 1])
    
    left_teacher = st.session_state.selected_teachers[0]
    right_teacher = st.session_state.selected_teachers[1]
    
    # Left Teacher Panel
    with col_left:
        left_speaking = (st.session_state.speaker == left_teacher)
        left_rendering = (st.session_state.renderer == left_teacher)
        
        panel_class = "teacher-panel"
        if left_speaking:
            panel_class += " speaking"
        elif left_rendering:
            panel_class += " rendering"
        
        st.markdown(f'<div class="{panel_class}">', unsafe_allow_html=True)
        st.header(f"👨‍🏫 {TEACHERS[left_teacher]['name']}")
        
        # Show video if clip is ready and this is the speaker
        if left_speaking and st.session_state.current_clip:
            clip = st.session_state.current_clip
            if clip.get("videoUrl"):
                st.video(clip["videoUrl"])
                st.caption(clip.get("text", ""))
            elif clip.get("audioUrl"):
                st.audio(clip["audioUrl"])
                st.caption(clip.get("text", ""))
        else:
            # Show avatar image
            try:
                st.image(TEACHERS[left_teacher]["image"], use_container_width=True)
            except:
                st.image("https://via.placeholder.com/400x300", use_container_width=True)
            
            if left_speaking:
                st.info("🎤 Speaking...")
            elif left_rendering:
                st.info("⏳ Rendering next clip...")
            else:
                st.info("💤 Idle")
        
        st.markdown('</div>', unsafe_allow_html=True)
    
    # Center Panel (Website/Learning Project)
    with col_center:
        st.markdown('<div class="center-panel">', unsafe_allow_html=True)
        st.header("📚 Learning Content")
        
        # URL input for website
        website_url = st.text_input("Website URL", value=lesson_url or "https://example.com", key="website_url")
        
        # Embed website (using iframe)
        if website_url:
            st.components.v1.iframe(website_url, height=400, scrolling=True)
        
        # Chat box with push-to-talk, send, and clear
        st.markdown("---")
        st.subheader("💬 Chat with Teachers")
        
        # Chat input area
        chat_col1, chat_col2, chat_col3, chat_col4 = st.columns([3, 1, 1, 1])
        
        with chat_col1:
            chat_message = st.text_input(
                "Type your question or message",
                value=st.session_state.chat_message,
                key="chat_input",
                placeholder="Ask the teachers a question or provide feedback..."
            )
            st.session_state.chat_message = chat_message
        
        with chat_col2:
            # Push-to-talk button
            push_to_talk = st.button("🎤 Push to Talk", key="push_to_talk", use_container_width=True)
            if push_to_talk:
                st.session_state.push_to_talk_active = not st.session_state.push_to_talk_active
                if st.session_state.push_to_talk_active:
                    st.info("🎤 Recording... (Release to stop)")
                else:
                    st.info("⏹️ Recording stopped")
        
        with chat_col3:
            # Send button
            send_chat = st.button("📤 Send", key="send_chat", type="primary", use_container_width=True)
            if send_chat and chat_message and st.session_state.session_id:
                # Send chat message as user question with section update
                update_section(
                    st.session_state.session_id,
                    website_url,
                    0,
                    "",  # visible_text - can be empty for chat-only
                    "",  # selected_text
                    chat_message,  # user_question
                    st.session_state.selected_language
                )
                st.success(f"✅ Message sent: {chat_message[:50]}...")
                st.session_state.chat_message = ""  # Clear after sending
                st.rerun()
        
        with chat_col4:
            # Clear button
            clear_chat = st.button("🗑️ Clear", key="clear_chat", use_container_width=True)
            if clear_chat:
                st.session_state.chat_message = ""
                st.rerun()
        
        # Show push-to-talk status
        if st.session_state.push_to_talk_active:
            st.warning("🎤 Push-to-talk is active - This feature requires browser microphone access (coming soon)")
        
        # Section snapshot controls
        st.markdown("---")
        st.subheader("📸 Section Snapshot")
        if st.button("📷 Capture Current Section"):
            # Extract visible text (simplified - in production, use browser extension)
            visible_text = st.text_area("Visible Text (paste from browser)", height=100)
            selected_text = st.text_input("Selected Text (if any)", "")
            scroll_y = st.number_input("Scroll Position", value=0, min_value=0)
            
            if st.session_state.session_id:
                update_section(
                    st.session_state.session_id,
                    website_url,
                    int(scroll_y),
                    visible_text,
                    selected_text,
                    None,  # user_question - can add separate field if needed
                    st.session_state.selected_language
                )
                st.success("✅ Section snapshot sent to teachers!")
        
        st.markdown('</div>', unsafe_allow_html=True)
    
    # Right Teacher Panel
    with col_right:
        right_speaking = (st.session_state.speaker == right_teacher)
        right_rendering = (st.session_state.renderer == right_teacher)
        
        panel_class = "teacher-panel"
        if right_speaking:
            panel_class += " speaking"
        elif right_rendering:
            panel_class += " rendering"
        
        st.markdown(f'<div class="{panel_class}">', unsafe_allow_html=True)
        st.header(f"👨‍🏫 {TEACHERS[right_teacher]['name']}")
        
        # Show video if clip is ready and this is the speaker
        if right_speaking and st.session_state.current_clip:
            clip = st.session_state.current_clip
            if clip.get("videoUrl"):
                st.video(clip["videoUrl"])
                st.caption(clip.get("text", ""))
            elif clip.get("audioUrl"):
                st.audio(clip["audioUrl"])
                st.caption(clip.get("text", ""))
        else:
            # Show avatar image
            try:
                st.image(TEACHERS[right_teacher]["image"], use_container_width=True)
            except:
                st.image("https://via.placeholder.com/400x300", use_container_width=True)
            
            if right_speaking:
                st.info("🎤 Speaking...")
            elif right_rendering:
                st.info("⏳ Rendering next clip...")
            else:
                st.info("💤 Idle")
        
        st.markdown('</div>', unsafe_allow_html=True)
    
    # Bottom controls
    st.markdown("---")
    col_controls = st.columns(4)
    
    with col_controls[0]:
        if st.button("⏸️ Pause"):
            st.info("Pause functionality - coming soon")
    
    with col_controls[1]:
        if st.button("⏭️ Next Section"):
            st.info("Next section - coming soon")
    
    with col_controls[2]:
        if st.button("🔄 Swap Teachers"):
            st.info("Swap teachers - coming soon")
    
    with col_controls[3]:
        if st.button("⚙️ Settings"):
            st.info("Settings - coming soon")

else:
    # Welcome screen - no session active
    st.info("👆 **Start a session** using the sidebar to begin the 2-teacher live classroom!")
    st.markdown("""
    ### How it works:
    1. **Select 2 teachers** from the sidebar
    2. **Click "Start Session"** to begin
    3. **Load a website** in the center panel
    4. **Capture section snapshots** to send context to teachers
    5. Teachers will **alternate turns** automatically, with one speaking while the other renders
    
    ### Features:
    - 🎥 **Live video** from LongCat-Video-Avatar
    - 🔄 **Automatic turn-taking** (no waiting)
    - 📚 **Website context** awareness
    - 🎯 **Real-time events** via SSE
    """)

# Auto-refresh for event processing
if st.session_state.session_id:
    time.sleep(0.5)  # Small delay to allow events to process
    st.rerun()
