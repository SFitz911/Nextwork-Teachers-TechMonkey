"""
Streamlit Frontend for 2-Teacher Live Classroom
Main entrypoint with st.navigation
"""

import streamlit as st

# Page config MUST be first
st.set_page_config(
    page_title="AI Virtual Classroom",
    page_icon="👨‍🏫",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Define pages using st.Page
landing_page = st.Page("pages/Landing.py", title="Home", icon="🏠", default=True)
session_page = st.Page("pages/Session.py", title="Session", icon="🎓")

# Create navigation
pg = st.navigation([landing_page, session_page])

# Run the selected page
pg.run()
