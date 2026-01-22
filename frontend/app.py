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
N8N_WEBHOOK_URL = os.getenv("N8N_WEBHOOK_URL", "http://localhost:5678/webhook/chat-webhook")
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
        
        # Check if response has content
        if not response.text:
            st.error("❌ Error: Empty response from webhook")
            st.warning("""
            **The workflow executed but didn't return a response.**
            
            This usually means the workflow is failing before reaching the 'Respond to Webhook' node.
            
            **To diagnose:**
            1. Open n8n UI: http://localhost:5678
            2. Go to 'Workflows' → 'AI Virtual Classroom - Five Teacher Workflow'
            3. Click the 'Executions' tab
            4. Check the latest execution to see which node failed
            
            **Common issues:**
            - Workflow not activated (check green toggle in n8n)
            - Ollama service not running
            - Code node syntax error
            - Service timeout
            """)
            return {}
        
        # Try to parse JSON
        try:
            return response.json()
        except ValueError as e:
            st.error(f"Error parsing response: {str(e)}")
            st.error(f"Response was: {response.text[:200]}")
            return {}
    except requests.exceptions.Timeout:
        st.error("❌ Request timed out after 30 seconds")
        st.warning("The workflow may be taking too long. Check if Ollama and other services are running.")
        return {}
    except requests.exceptions.ConnectionError:
        st.error("❌ Cannot connect to webhook")
        st.warning(f"""
        **Connection failed to:** {N8N_WEBHOOK_URL}
        
        **Possible causes:**
        1. Port forwarding not active - Run: `.\connect-vast.ps1`
        2. n8n service not running
        3. Wrong webhook URL
        
        **Check port forwarding:** Run `.\scripts\check_port_forwarding.ps1`
        """)
        return {}
    except requests.exceptions.RequestException as e:
        st.error(f"Error sending message: {str(e)}")
        if hasattr(e, 'response') and e.response is not None:
            st.error(f"HTTP Status: {e.response.status_code}")
        return {}
    except Exception as e:
        st.error(f"Unexpected error: {str(e)}")
        return {}


def get_video_stream(teacher_id: str) -> Optional[str]:
    """
    Get video stream URL for teacher
    TODO: Implement WebSocket or SSE for real-time streaming
    """
    # Placeholder - implement actual video streaming
    return None


def get_avatar_image(teacher_id: str) -> Optional[str]:
    """
    Get avatar image URL for teacher from animation API
    """
    try:
        # Get from animation API
        return f"{ANIMATION_API_URL}/avatar/{teacher_id}"
    except:
        return None


# Main UI
st.title("👨‍🏫 AI Virtual Classroom")
st.markdown("Ask questions in the chat below, and our AI teachers will respond!")

# Sidebar for settings
with st.sidebar:
    st.header("⚙️ Settings")
    teacher_a_name = st.text_input("Teacher A Name", value="Maya")
    teacher_b_name = st.text_input("Teacher B Name", value="Maximus")
    teacher_c_name = st.text_input("Teacher C Name", value="Krishna")
    teacher_d_name = st.text_input("Teacher D Name", value="TechMonkey Steve")
    teacher_e_name = st.text_input("Teacher E Name", value="Pano Bieber")
    
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

# Five-teacher layout (3 on top, 2 on bottom)
col1, col2, col3 = st.columns(3)
col4, col5 = st.columns(2)

with col1:
    st.markdown(f'<div class="teacher-container">', unsafe_allow_html=True)
    st.header(f"👨‍🏫 {teacher_a_name}")
    
    # Video player for Teacher A
    video_a = get_video_stream("teacher_a")
    if video_a:
        st.video(video_a)
    else:
        # Show avatar image if available
        avatar_a = get_avatar_image("teacher_a")
        if avatar_a:
            try:
                st.image(avatar_a, use_container_width=True)
            except:
                st.image("https://via.placeholder.com/640x360?text=Maya", use_container_width=True)
        else:
            st.image("https://via.placeholder.com/640x360?text=Maya", use_container_width=True)
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
        # Show avatar image if available
        avatar_b = get_avatar_image("teacher_b")
        if avatar_b:
            try:
                st.image(avatar_b, use_container_width=True)
            except:
                st.image("https://via.placeholder.com/640x360?text=Maximus", use_container_width=True)
        else:
            st.image("https://via.placeholder.com/640x360?text=Maximus", use_container_width=True)
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
        # Show avatar image if available
        avatar_c = get_avatar_image("teacher_c")
        if avatar_c:
            try:
                st.image(avatar_c, use_container_width=True)
            except:
                st.image("https://via.placeholder.com/640x360?text=Krishna", use_container_width=True)
        else:
            st.image("https://via.placeholder.com/640x360?text=Krishna", use_container_width=True)
        st.info("Waiting for Teacher C to speak...")
    
    # Status indicator
    status_c = st.empty()
    status_c.info("🟢 Ready")
    
    st.markdown('</div>', unsafe_allow_html=True)

# Second row: Teachers D and E
with col4:
    st.markdown(f'<div class="teacher-container">', unsafe_allow_html=True)
    st.header(f"👨‍🏫 {teacher_d_name}")
    
    # Video player for Teacher D
    video_d = get_video_stream("teacher_d")
    if video_d:
        st.video(video_d)
    else:
        # Show avatar image if available
        avatar_d = get_avatar_image("teacher_d")
        if avatar_d:
            try:
                st.image(avatar_d, use_container_width=True)
            except:
                st.image("https://via.placeholder.com/640x360?text=TechMonkey+Steve", use_container_width=True)
        else:
            st.image("https://via.placeholder.com/640x360?text=TechMonkey+Steve", use_container_width=True)
        st.info("Waiting for Teacher D to speak...")
    
    # Status indicator
    status_d = st.empty()
    status_d.info("🟢 Ready")
    
    st.markdown('</div>', unsafe_allow_html=True)

with col5:
    st.markdown(f'<div class="teacher-container">', unsafe_allow_html=True)
    st.header(f"👨‍🏫 {teacher_e_name}")
    
    # Video player for Teacher E
    video_e = get_video_stream("teacher_e")
    if video_e:
        st.video(video_e)
    else:
        # Show avatar image if available
        avatar_e = get_avatar_image("teacher_e")
        if avatar_e:
            try:
                st.image(avatar_e, use_container_width=True)
            except:
                st.image("https://via.placeholder.com/640x360?text=Pano+Bieber", use_container_width=True)
        else:
            st.image("https://via.placeholder.com/640x360?text=Pano+Bieber", use_container_width=True)
        st.info("Waiting for Teacher E to speak...")
    
    # Status indicator
    status_e = st.empty()
    status_e.info("🟢 Ready")
    
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
                    st.error("❌ Failed to get response. Please check service status.")
                    st.info("""
                    💡 **To diagnose:**
                    
                    **1. Check port forwarding** (Desktop PowerShell):
                       `.\scripts\check_port_forwarding.ps1`
                    
                    **2. Run diagnostic** (VAST Terminal):
                       `bash scripts/diagnose_webhook_issue.sh`
                    
                    **3. Check which node failed** (VAST Terminal):
                       `bash scripts/debug_webhook_execution.sh`
                    """)

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
