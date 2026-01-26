"""
Streamlit Frontend for 2-Teacher Live Classroom
Landing Page - Welcome screen and session start
"""

import streamlit as st
import threading
from common import (
    TEACHERS, get_css_styles, initialize_session_state,
    start_session, listen_to_events
)

# Page config
st.set_page_config(
    page_title="AI Virtual Classroom",
    page_icon="👨‍🏫",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Initialize session state
initialize_session_state()

# Check for auto-navigation flag BEFORE rendering anything
if st.session_state.get("auto_navigate_to_session", False) and st.session_state.session_id:
    st.session_state.auto_navigate_to_session = False  # Clear flag immediately
    # Force navigation using JavaScript - this is the most reliable method
    st.markdown(
        """
        <script>
            // Navigate to Session page by replacing /app with /Session in the URL
            const currentPath = window.location.pathname;
            const newPath = currentPath.replace('/app', '/Session');
            window.location.href = window.location.origin + newPath;
        </script>
        """,
        unsafe_allow_html=True
    )
    # Also try Streamlit's native navigation
    try:
        st.switch_page("pages/Session")
    except:
        try:
            st.switch_page("Session")
        except:
            pass
    st.stop()  # Stop rendering to allow JavaScript redirect to work

# Apply CSS
st.markdown(get_css_styles(), unsafe_allow_html=True)

# Sidebar - Session controls
with st.sidebar:
    if st.session_state.session_id:
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
                st.session_state.website_url = url_to_use
                
                if st.session_state.sse_thread is None or not st.session_state.sse_thread.is_alive():
                    st.session_state.sse_thread = threading.Thread(
                        target=listen_to_events,
                        args=(session_id, st.session_state.event_queue),
                        daemon=True
                    )
                    st.session_state.sse_thread.start()
                
                # Force immediate navigation using JavaScript
                st.markdown(
                    """
                    <script>
                        window.location.href = window.location.origin + window.location.pathname.replace('/app', '/Session');
                    </script>
                    """,
                    unsafe_allow_html=True
                )
                # Also try Streamlit navigation
                try:
                    st.switch_page("pages/Session")
                except:
                    try:
                        st.switch_page("Session")
                    except:
                        pass
                st.stop()
        
        # Navigation: Go to Session button (if session exists but not auto-navigating)
        if st.session_state.session_id and not st.session_state.get("auto_navigate_to_session", False):
            st.markdown("---")
            st.markdown("### 🧭 Navigation")
            if st.button("▶️ Go to Session", use_container_width=True, type="primary", key="nav_forward_sidebar"):
                try:
                    st.switch_page("Session")
                except:
                    try:
                        st.switch_page("pages/Session")
                    except Exception as e:
                        st.error(f"Could not navigate: {e}")
                        st.rerun()
    else:
        st.info("👋 Welcome! Start a session to begin learning with AI teachers.")

# Landing Page - Welcome screen with teacher showcase
st.markdown("""
    <div style="text-align: center; padding: 40px 20px 20px 20px;">
        <h1 style="color: #f1f5f9; margin-bottom: 10px;">👨‍🏫 AI Virtual Classroom</h1>
        <p style="color: #94a3b8; font-size: 1.2rem; margin-bottom: 40px;">
            Start a session with 2 AI teachers to begin your learning journey
        </p>
    </div>
    """, unsafe_allow_html=True)

# Teacher showcase - Maya and Maximus with images ON the blue boxes
col1, col2 = st.columns(2, gap="large")

with col1:
    # Maya showcase - image on top of blue box
    st.markdown("""
    <div style="background: #1e293b; border-radius: 16px; overflow: hidden; box-shadow: 0 8px 16px rgba(0, 0, 0, 0.4); border: 2px solid #334155; margin: 20px;">
    """, unsafe_allow_html=True)
    # Display Maya's image using Streamlit (works better than HTML img)
    try:
        st.image(TEACHERS['teacher_a']['image'], use_container_width=True)
    except Exception:
        # Fallback if image path doesn't work
        st.markdown(f'<div style="width: 100%; height: 350px; background: #0f172a; display: flex; align-items: center; justify-content: center; color: #64748b;">Image not found</div>', unsafe_allow_html=True)
    st.markdown("""
        <div style="padding: 30px; text-align: center;">
            <h2 style="color: #f1f5f9; font-size: 2rem; margin-bottom: 15px; font-weight: 700;">Maya</h2>
            <p style="color: #cbd5e1; font-size: 1.1rem; line-height: 1.6;">
                Your knowledgeable guide through complex topics, bringing clarity and expertise to every lesson.
            </p>
        </div>
    </div>
    """, unsafe_allow_html=True)

with col2:
    # Maximus showcase - image on top of blue box
    st.markdown("""
    <div style="background: #1e293b; border-radius: 16px; overflow: hidden; box-shadow: 0 8px 16px rgba(0, 0, 0, 0.4); border: 2px solid #334155; margin: 20px;">
    """, unsafe_allow_html=True)
    # Display Maximus's image using Streamlit (works better than HTML img)
    try:
        st.image(TEACHERS['teacher_b']['image'], use_container_width=True)
    except Exception:
        # Fallback if image path doesn't work
        st.markdown(f'<div style="width: 100%; height: 350px; background: #0f172a; display: flex; align-items: center; justify-content: center; color: #64748b;">Image not found</div>', unsafe_allow_html=True)
    st.markdown("""
        <div style="padding: 30px; text-align: center;">
            <h2 style="color: #f1f5f9; font-size: 2rem; margin-bottom: 15px; font-weight: 700;">Maximus</h2>
            <p style="color: #cbd5e1; font-size: 1.1rem; line-height: 1.6;">
                Your engaging companion who makes learning fun and interactive, bringing energy to every session.
            </p>
        </div>
    </div>
    """, unsafe_allow_html=True)

# Session controls at bottom of landing page - centered and narrower
st.markdown("---")

# Create a centered container for the controls
col_left, col_center, col_right = st.columns([1, 2, 1])

with col_center:
    st.markdown("## 🎯 Start Your Session")
    
    # Teacher selection in two columns
    st.markdown("### Select Teachers")
    available_teachers = list(TEACHERS.keys())
    
    col_teacher1, col_teacher2 = st.columns(2, gap="medium")
    
    with col_teacher1:
        teacher_1 = st.selectbox(
            "Teacher 1 (Left)",
            available_teachers,
            format_func=lambda x: TEACHERS[x]["name"],
            key="teacher_1_landing"
        )
    
    with col_teacher2:
        teacher_2_options = [t for t in available_teachers if t != teacher_1]
        teacher_2 = st.selectbox(
            "Teacher 2 (Right)",
            teacher_2_options,
            format_func=lambda x: TEACHERS[x]["name"],
            key="teacher_2_landing"
        )
    
    # URL input for lesson with history dropdown
    st.markdown("---")
    st.markdown("### 📚 Lesson URL")
    
    # URL history dropdown
    if st.session_state.url_history:
        selected_history_url = st.selectbox(
            "Select from history",
            options=st.session_state.url_history,
            key="url_history_select_landing",
            label_visibility="collapsed"
        )
        if selected_history_url:
            st.session_state.selected_url = selected_history_url
    
    # URL input with default value
    lesson_url = st.text_input(
        "Enter or select URL",
        value=st.session_state.selected_url,
        key="lesson_url_landing",
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
        key="language_selectbox_landing",
        label_visibility="collapsed"
    )
    st.session_state.selected_language = selected_language
    
    # Start session button
    if st.button("🚀 Start Session", type="primary", use_container_width=True, key="start_session_landing"):
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
            st.session_state.website_url = url_to_use
            
            if st.session_state.sse_thread is None or not st.session_state.sse_thread.is_alive():
                st.session_state.sse_thread = threading.Thread(
                    target=listen_to_events,
                    args=(session_id, st.session_state.event_queue),
                    daemon=True
                )
                st.session_state.sse_thread.start()
            
            # Force immediate navigation using JavaScript
            st.markdown(
                """
                <script>
                    window.location.href = window.location.origin + window.location.pathname.replace('/app', '/Session');
                </script>
                """,
                unsafe_allow_html=True
            )
            # Also try Streamlit navigation
            try:
                st.switch_page("pages/Session")
            except:
                try:
                    st.switch_page("Session")
                except:
                    pass
            st.stop()
    
    # Navigation: Go to Session button (if session exists but not auto-navigating)
    if st.session_state.session_id and not st.session_state.get("auto_navigate_to_session", False):
        st.markdown("---")
        st.markdown("### 🧭 Navigation")
        if st.button("▶️ Go to Session", use_container_width=True, type="primary", key="nav_forward_landing"):
            try:
                st.switch_page("Session")
            except:
                try:
                    st.switch_page("pages/Session")
                except Exception as e:
                    st.error(f"Could not navigate: {e}")
                    st.rerun()
