"""
Streamlit Frontend for AI Virtual Classroom
Dual teacher video display with chat interface
"""

import streamlit as st
import requests
import os
import json
from typing import Optional
import time

# Configuration
N8N_WEBHOOK_URL = os.getenv("N8N_WEBHOOK_URL", "http://localhost:5678/webhook/chat")
TTS_API_URL = os.getenv("TTS_API_URL", "http://localhost:8001")
ANIMATION_API_URL = os.getenv("ANIMATION_API_URL", "http://localhost:8002")

# Page config
st.set_page_config(
    page_title="AI Virtual Classroom",
    page_icon="👨‍🏫",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# Custom CSS for classroom theme
st.markdown("""
    <style>
    .main {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        padding: 1rem;
    }
    .teacher-container {
        background: white;
        border-radius: 10px;
        padding: 20px;
        margin: 10px 0;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    .chat-message {
        padding: 10px;
        margin: 5px 0;
        border-radius: 5px;
        background: #f0f0f0;
    }
    .stButton>button {
        width: 100%;
        background-color: #667eea;
        color: white;
        font-weight: bold;
    }
    </style>
    """, unsafe_allow_html=True)


def send_chat_message(message: str) -> dict:
    """
    Send chat message to n8n webhook
    """
    try:
        response = requests.post(
            N8N_WEBHOOK_URL,
            json={"message": message, "timestamp": time.time()},
            timeout=30
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        st.error(f"Error sending message: {str(e)}")
        return {}


def get_video_stream(teacher_id: str) -> Optional[str]:
    """
    Get video stream URL for teacher
    TODO: Implement WebSocket or SSE for real-time streaming
    """
    # Placeholder - implement actual video streaming
    return None


# Main UI
st.title("👨‍🏫 AI Virtual Classroom")
st.markdown("Ask questions in the chat below, and our AI teachers will respond!")

# Sidebar for settings
with st.sidebar:
    st.header("⚙️ Settings")
    teacher_a_name = st.text_input("Teacher A Name", value="Krishna")
    teacher_b_name = st.text_input("Teacher B Name", value="Maya")
    teacher_c_name = st.text_input("Teacher C Name", value="Maximus")
    teacher_d_name = st.text_input("Teacher D Name", value="Tech Monkey Steve")
    
    st.header("📊 Status")
    if st.button("Check Services"):
        # Check service health
        services = {
            "n8n": N8N_WEBHOOK_URL,
            "TTS": TTS_API_URL,
            "Animation": ANIMATION_API_URL
        }
        for name, url in services.items():
            try:
                response = requests.get(url.replace("/webhook/chat", ""), timeout=2)
                st.success(f"✅ {name}: Online")
            except:
                st.error(f"❌ {name}: Offline")

# Four-column layout for teachers (2x2 grid)
col1, col2 = st.columns(2)
col3, col4 = st.columns(2)

with col1:
    st.markdown(f'<div class="teacher-container">', unsafe_allow_html=True)
    st.header(f"👨‍🏫 {teacher_a_name}")
    
    # Video player for Teacher A
    video_a = get_video_stream("teacher_a")
    if video_a:
        st.video(video_a)
    else:
        st.image("https://via.placeholder.com/640x360?text=Teacher+A+Video", use_container_width=True)
        st.info("Waiting for Teacher A to speak...")
    
    # Status indicator
    status_a = st.empty()
    status_a.info("🟢 Ready")
    
    st.markdown('</div>', unsafe_allow_html=True)

with col2:
    st.markdown(f'<div class="teacher-container">', unsafe_allow_html=True)
    st.header(f"👨‍🏫 {teacher_b_name}")
    
    # Video player for Teacher B
    video_b = get_video_stream("teacher_b")
    if video_b:
        st.video(video_b)
    else:
        st.image("https://via.placeholder.com/640x360?text=Teacher+B+Video", use_container_width=True)
        st.info("Waiting for Teacher B to speak...")
    
    # Status indicator
    status_b = st.empty()
    status_b.info("🟢 Ready")
    
    st.markdown('</div>', unsafe_allow_html=True)

with col3:
    st.markdown(f'<div class="teacher-container">', unsafe_allow_html=True)
    st.header(f"👨‍🏫 {teacher_c_name}")
    
    # Video player for Teacher C
    video_c = get_video_stream("teacher_c")
    if video_c:
        st.video(video_c)
    else:
        st.image("https://via.placeholder.com/640x360?text=Teacher+C+Video", use_container_width=True)
        st.info("Waiting for Teacher C to speak...")
    
    # Status indicator
    status_c = st.empty()
    status_c.info("🟢 Ready")
    
    st.markdown('</div>', unsafe_allow_html=True)

with col4:
    st.markdown(f'<div class="teacher-container">', unsafe_allow_html=True)
    st.header(f"👨‍🏫 {teacher_d_name}")
    
    # Video player for Teacher D
    video_d = get_video_stream("teacher_d")
    if video_d:
        st.video(video_d)
    else:
        st.image("https://via.placeholder.com/640x360?text=Teacher+D+Video", use_container_width=True)
        st.info("Waiting for Teacher D to speak...")
    
    # Status indicator
    status_d = st.empty()
    status_d.info("🟢 Ready")
    
    st.markdown('</div>', unsafe_allow_html=True)

# Chat interface
st.markdown("---")
st.header("💬 Ask a Question")

# Chat history
if "chat_history" not in st.session_state:
    st.session_state.chat_history = []

# Display chat history
with st.expander("📜 Chat History", expanded=False):
    for msg in st.session_state.chat_history:
        st.markdown(f'<div class="chat-message"><strong>You:</strong> {msg["question"]}</div>', 
                   unsafe_allow_html=True)
        if "response" in msg:
            st.markdown(f'<div class="chat-message"><strong>Teachers:</strong> {msg["response"]}</div>', 
                       unsafe_allow_html=True)

# Chat input
user_input = st.text_input(
    "Type your question here:",
    placeholder="e.g., What is the theory of relativity?",
    key="chat_input"
)

col_send, col_clear = st.columns([4, 1])

with col_send:
    if st.button("🚀 Send Question", type="primary"):
        if user_input:
            # Add to chat history
            st.session_state.chat_history.append({"question": user_input})
            
            # Show loading
            with st.spinner("Teachers are thinking..."):
                # Send to n8n webhook
                result = send_chat_message(user_input)
                
                if result:
                    st.session_state.chat_history[-1]["response"] = result.get("response", "Processing...")
                    st.rerun()
                else:
                    st.error("Failed to get response. Please check service status.")

with col_clear:
    if st.button("🗑️ Clear"):
        st.session_state.chat_history = []
        st.rerun()

# Footer
st.markdown("---")
st.markdown(
    """
    <div style='text-align: center; color: #666; padding: 20px;'>
        <p>AI Virtual Classroom Teacher Agent | Built with ❤️ using n8n, Ollama, and open-source AI</p>
    </div>
    """,
    unsafe_allow_html=True
)
