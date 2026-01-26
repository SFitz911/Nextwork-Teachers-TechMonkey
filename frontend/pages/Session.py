"""
Session Page - Active learning session with dual teachers
"""

import streamlit as st
import time
from common import (
    TEACHERS, get_css_styles, initialize_session_state,
    process_events, update_section, COORDINATOR_API_URL
)

# Initialize session state
initialize_session_state()

# Apply CSS
st.markdown(get_css_styles(), unsafe_allow_html=True)

# Check if we have a valid session
if not st.session_state.session_id or not st.session_state.selected_teachers or len(st.session_state.selected_teachers) != 2:
    st.warning("⚠️ No active session. Please start a session from the landing page.")
    st.info("💡 Use the sidebar menu to navigate back to the landing page.")
    st.stop()

# Process events
if st.session_state.session_id:
    process_events()

# Get teachers
left_teacher = st.session_state.selected_teachers[0]
right_teacher = st.session_state.selected_teachers[1]

# Sidebar - Session controls
with st.sidebar:
    st.markdown("### 📊 Session Active")
    st.success(f"**Session:** `{st.session_state.session_id[:12]}...`")
    
    if st.session_state.speaker:
        st.markdown(f"**Speaking:** {TEACHERS[st.session_state.speaker]['name']}")
    if st.session_state.renderer:
        st.markdown(f"**Rendering:** {TEACHERS[st.session_state.renderer]['name']}")
    
    st.markdown("---")
    
    # Replay button - show if there's a last played clip
    if st.session_state.last_played_clip:
        if st.button("🔄 Replay Last Video", use_container_width=True, key="replay_button"):
            st.session_state.current_clip = st.session_state.last_played_clip
            # Determine which teacher to show as speaking for replay
            for teacher_id, clip in st.session_state.clips.items():
                if clip == st.session_state.last_played_clip:
                    st.session_state.speaker = teacher_id
                    break
            st.rerun()
    
    if st.button("🛑 End Session", use_container_width=True):
        st.session_state.session_id = None
        st.session_state.selected_teachers = []
        st.session_state.speaker = None
        st.session_state.renderer = None
        st.session_state.clips = {}
        st.session_state.current_clip = None
        st.rerun()

# Clean three-column layout: Teacher Left | URL Box Center | Teacher Right
col_left, col_center, col_right = st.columns([1, 2, 1], gap="medium")

# ===== LEFT COLUMN: Teacher =====
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
    showing_video = (left_speaking and st.session_state.current_clip) or (
        st.session_state.current_clip and 
        st.session_state.current_clip == st.session_state.last_played_clip and
        st.session_state.current_clip in st.session_state.clips.values() and
        st.session_state.clips.get(left_teacher) == st.session_state.current_clip
    )
    
    if showing_video:
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
    
    # Chat input with speech-to-text - using text_area for bigger box
    chat_col1, chat_col2, chat_col3 = st.columns([3, 1, 1])
    
    with chat_col1:
        # Dynamic placeholder based on speech recognition state
        if st.session_state.speech_recognition_active:
            placeholder_text = "🎤 Listening... Speak your question"
        else:
            placeholder_text = "Type your question or click 🎤 Talk for speech-to-text"
        
        # Use text_area instead of text_input for bigger box
        chat_message = st.text_area(
            "Type your question",
            value=st.session_state.chat_message,
            key="chat_input",
            placeholder=placeholder_text,
            label_visibility="collapsed",
            height=100
        )
        st.session_state.chat_message = chat_message
    
    # Speech recognition component with proper stop functionality
    rec_id = st.session_state.speech_recognition_id
    if st.session_state.speech_recognition_active:
        speech_html = f"""
        <div id="speech-rec-{rec_id}"></div>
        <script>
        (function() {{
            const recId = '{rec_id}';
            let recognition = null;
            let transcriptText = '';
            let isActive = true;
            
            // Store recognition instance globally with ID
            if (!window.speechRecognitionInstances) {{
                window.speechRecognitionInstances = {{}};
            }}
            
            function findTextArea() {{
                // Try multiple methods to find the textarea
                const selectors = [
                    'textarea[data-testid="stTextArea"]',
                    'textarea[placeholder*="question"]',
                    'textarea[placeholder*="Talk"]',
                    'textarea[placeholder*="Listening"]',
                    'textarea'
                ];
                
                for (let selector of selectors) {{
                    const textarea = document.querySelector(selector);
                    if (textarea) return textarea;
                }}
                return null;
            }}
            
            function updateTextArea(text) {{
                const textarea = findTextArea();
                if (textarea) {{
                    textarea.value = text;
                    textarea.focus();
                    // Trigger multiple events to ensure Streamlit captures it
                    const events = ['input', 'change', 'keyup', 'keydown'];
                    events.forEach(eventType => {{
                        textarea.dispatchEvent(new Event(eventType, {{ bubbles: true }}));
                    }});
                    // Also try setting value directly
                    Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set.call(textarea, text);
                    textarea.dispatchEvent(new Event('input', {{ bubbles: true }}));
                }}
            }}
            
            function initSpeechRecognition() {{
                if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {{
                    alert('Speech recognition not supported. Please use Chrome, Edge, or Safari.');
                    return;
                }}
                
                const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
                recognition = new SpeechRecognition();
                recognition.continuous = true;
                recognition.interimResults = true;
                recognition.lang = 'en-US';
                
                recognition.onresult = function(event) {{
                    if (!isActive) return;
                    
                    transcriptText = '';
                    for (let i = event.resultIndex; i < event.results.length; i++) {{
                        transcriptText += event.results[i][0].transcript;
                    }}
                    
                    if (transcriptText) {{
                        updateTextArea(transcriptText);
                    }}
                }};
                
                recognition.onerror = function(event) {{
                    console.error('Speech recognition error:', event.error);
                    if (event.error === 'not-allowed') {{
                        alert('Microphone permission denied. Please allow access.');
                        isActive = false;
                    }}
                }};
                
                recognition.onend = function() {{
                    // Only restart if still active
                    if (isActive && document.getElementById('speech-rec-' + recId)) {{
                        setTimeout(() => {{
                            if (isActive && recognition) {{
                                try {{
                                    recognition.start();
                                }} catch (e) {{
                                    // Ignore
                                }}
                            }}
                        }}, 100);
                    }}
                }};
                
                // Store stop function
                window.speechRecognitionInstances[recId] = {{
                    stop: function() {{
                        isActive = false;
                        if (recognition) {{
                            recognition.stop();
                            recognition = null;
                        }}
                        delete window.speechRecognitionInstances[recId];
                    }}
                }};
                
                try {{
                    recognition.start();
                    console.log('Speech recognition started:', recId);
                }} catch (e) {{
                    console.error('Error starting recognition:', e);
                }}
            }}
            
            // Initialize
            if (document.readyState === 'loading') {{
                document.addEventListener('DOMContentLoaded', initSpeechRecognition);
            }} else {{
                setTimeout(initSpeechRecognition, 300);
            }}
        }})();
        </script>
        """
        st.components.v1.html(speech_html, height=0)
    
    # Stop recognition when button is clicked to stop
    if not st.session_state.speech_recognition_active and rec_id > 0:
        stop_script = f"""
        <script>
        if (window.speechRecognitionInstances && window.speechRecognitionInstances['{rec_id}']) {{
            window.speechRecognitionInstances['{rec_id}'].stop();
        }}
        </script>
        """
        st.components.v1.html(stop_script, height=0)
    
    with chat_col2:
        # Push-to-talk button
        button_label = "🎤 Stop" if st.session_state.speech_recognition_active else "🎤 Talk"
        button_type = "secondary" if st.session_state.speech_recognition_active else "primary"
        if st.button(button_label, type=button_type, use_container_width=True, key="speech_button"):
            if st.session_state.speech_recognition_active:
                # Stopping - increment ID to create new instance next time
                st.session_state.speech_recognition_id += 1
            else:
                # Starting - increment ID for new instance
                st.session_state.speech_recognition_id += 1
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

# ===== RIGHT COLUMN: Teacher =====
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
    showing_video_right = (right_speaking and st.session_state.current_clip) or (
        st.session_state.current_clip and 
        st.session_state.current_clip == st.session_state.last_played_clip and
        st.session_state.current_clip in st.session_state.clips.values() and
        st.session_state.clips.get(right_teacher) == st.session_state.current_clip
    )
    
    if showing_video_right:
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

# Auto-refresh for event processing
if st.session_state.session_id:
    time.sleep(0.5)
    st.rerun()
