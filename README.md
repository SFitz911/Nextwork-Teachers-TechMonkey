# AI Virtual Classroom - Dual Teacher System

An intelligent educational platform featuring **two AI teacher avatars** that work together in real-time to teach and explain content from any website. The system uses advanced AI to generate natural speech, lip-synced video animations, and contextual responses based on the content students are viewing.

## 🎯 What This Project Does

**The Problem**: Traditional online learning lacks the personal, interactive experience of a real classroom with multiple teachers.

**The Solution**: Two AI teachers that:
- **Read and understand** any website content the student is viewing
- **Take turns** speaking (one teaches while the other prepares the next response)
- **Generate natural speech** with realistic lip-sync animation
- **Provide contextual explanations** based on the specific content visible on screen
- **Support multiple languages** for global accessibility

**The Experience**: Students browse any website while two AI teachers watch, understand, and explain the content in real-time through natural conversation.

---

## 🏗️ System Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         Student Browser                        │
│  • Views website content                                        │
│  • Sees two AI teachers side-by-side                           │
│  • Receives real-time explanations                             │
└────────────────────┬──────────────────────────────────────────┘
                     │ HTTP/SSE Events
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Frontend (Streamlit)                         │
│  Port: 8501                                                      │
│  • Dual video players (Left & Right teachers)                   │
│  • Website iframe                                                │
│  • Chat interface                                                │
│  • Language selector                                             │
└────────────────────┬──────────────────────────────────────────┘
                     │ HTTP Requests
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│              Coordinator API (FastAPI)                          │
│  Port: 8004                                                      │
│  • Session state management                                     │
│  • Turn-taking logic (who speaks next)                          │
│  • Event streaming (SSE) to frontend                          │
│  • Job queue management                                          │
└─────┬───────────────────────────────────────────┬──────────────┘
      │                                           │
      ↓                                           ↓
┌─────────────────────┐              ┌─────────────────────┐
│   n8n Workflows     │              │   n8n Workflows     │
│   (Orchestration)   │              │   (Orchestration)   │
│   Port: 5678        │              │   Port: 5678        │
└─────┬───────────────┘              └─────┬───────────────┘
      │                                    │
      │ Left Worker Pipeline              │ Right Worker Pipeline
      │                                    │
      ├─→ Get Session State               ├─→ Get Session State
      ├─→ LLM (Ollama)                    ├─→ LLM (Ollama)
      ├─→ Map Language to Voice          ├─→ Map Language to Voice
      ├─→ TTS (Piper)                     ├─→ TTS (Piper)
      ├─→ Video (LongCat-Video)          ├─→ Video (LongCat-Video)
      └─→ Notify Coordinator              └─→ Notify Coordinator
```

### Component Details

| Component | Port | Purpose | Technology |
|-----------|------|---------|------------|
| **Frontend** | 8501 | User interface with dual teachers | Streamlit |
| **Coordinator API** | 8004 | Session state & turn-taking | FastAPI |
| **n8n** | 5678 | Workflow orchestration | n8n (Node.js) |
| **Ollama** | 11434 | LLM inference (Mistral 7B) | Ollama |
| **TTS Service** | 8001 | Text-to-speech generation | Piper TTS |
| **Animation Service** | 8002 | Video animation (placeholder) | - |
| **LongCat-Video** | 8003 | Lip-sync video generation | LongCat-Video |
| **PostgreSQL** | 5432 | Database + vector search | PostgreSQL + pgvector |

---

## 📊 Data Flow Logic Tree

### Complete Request Flow

```
Student Action (Scroll/Click)
    │
    ├─→ Frontend captures: URL + visible text + scroll position
    │
    ├─→ POST /session/{id}/section
    │   └─→ Coordinator stores snapshot
    │
    ├─→ Coordinator determines: Which teacher should respond?
    │   ├─→ Check current turn (left/right)
    │   ├─→ Check if other teacher is ready
    │   └─→ Enqueue render job
    │
    ├─→ n8n Worker receives job
    │   │
    │   ├─→ Step 1: Get Session State
    │   │   └─→ GET /session/{id}/state
    │   │
    │   ├─→ Step 2: Extract Payload
    │   │   └─→ Parse: sectionPayload, language, teacher
    │   │
    │   ├─→ Step 3: LLM Generate
    │   │   ├─→ POST http://localhost:11434/api/generate
    │   │   ├─→ Prompt: "You are {teacher}. Explain {visibleText}..."
    │   │   └─→ Response: Natural language explanation
    │   │
    │   ├─→ Step 4: Map Language to Voice
    │   │   └─→ Select TTS voice based on language
    │   │       (English → en_US-lessac-medium, etc.)
    │   │
    │   ├─→ Step 5: TTS Generate
    │   │   ├─→ POST http://localhost:8001/tts/generate
    │   │   ├─→ Input: text + voice
    │   │   └─→ Output: audio.wav URL
    │   │
    │   ├─→ Step 6: Video Generate
    │   │   ├─→ POST http://localhost:8003/generate
    │   │   ├─→ Input: audio URL + teacher avatar image
    │   │   └─→ Output: video.mp4 URL
    │   │
    │   └─→ Step 7: Notify Coordinator
    │       ├─→ POST /session/{id}/clip-ready
    │       └─→ Coordinator emits CLIP_READY event
    │
    └─→ Frontend receives SSE event
        ├─→ Auto-play video clip
        └─→ Display captions
```

### Turn-Taking Logic

```
Initial State:
    Left Teacher:  IDLE
    Right Teacher: IDLE
    Turn: 0 (Left speaks first)

User Action → Section Update
    │
    ├─→ Coordinator: turn % 2 == 0 → Left speaks
    │   ├─→ Set speaker = "left"
    │   ├─→ Set renderer = "right"
    │   └─→ Enqueue job for RIGHT (prepare next)
    │
    └─→ Coordinator: turn % 2 == 1 → Right speaks
        ├─→ Set speaker = "right"
        ├─→ Set renderer = "left"
        └─→ Enqueue job for LEFT (prepare next)

When Clip Finishes:
    │
    ├─→ Frontend: POST /speech-ended
    │
    ├─→ Coordinator: Increment turn
    │
    ├─→ Coordinator: Swap speaker/renderer
    │
    └─→ Coordinator: If renderer has ready clip → emit CLIP_READY
        └─→ Frontend plays immediately (no delay!)
```

---

## 📁 Project File Structure

```
Nextwork-Teachers-TechMonkey/
│
├── 📄 README.md                    # This file - project overview
├── 📄 README-AI.md                  # AI assistant documentation
├── 📄 IMPLEMENTATION_PLAN.md       # Current implementation roadmap
├── 📄 docker-compose.yml           # Docker orchestration (optional)
├── 📄 requirements.txt             # Python dependencies
│
├── 📂 frontend/                    # Streamlit frontend application
│   ├── app.py                      # Main UI application
│   ├── requirements.txt            # Frontend dependencies
│   ├── Dockerfile                  # Docker image (optional)
│   └── static/
│       └── section_snapshot.js    # Browser extension for content capture
│
├── 📂 services/                     # Microservices (FastAPI)
│   ├── coordinator/                # Session state & turn-taking
│   │   ├── app.py                  # FastAPI application
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   │
│   ├── tts/                        # Text-to-speech service
│   │   ├── app.py                  # Piper TTS API
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   │
│   ├── animation/                  # Animation service (placeholder)
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   │
│   └── longcat_video/              # LongCat-Video service
│       ├── app.py                  # Video generation API
│       ├── requirements.txt
│       └── Dockerfile
│
├── 📂 n8n/                         # n8n workflow definitions
│   └── workflows/
│       ├── session-start-workflow.json    # Fast webhook for session creation
│       ├── left-worker-workflow.json      # Left teacher pipeline
│       ├── right-worker-workflow.json     # Right teacher pipeline
│       ├── dual-teacher-workflow.json     # Legacy (5-teacher)
│       ├── five-teacher-workflow.json     # Legacy (5-teacher)
│       └── README.md                      # Workflow documentation
│
├── 📂 scripts/                      # Deployment & utility scripts
│   ├── deploy_2teacher_system.sh   # Main deployment script
│   ├── start_all_services.sh       # Start all services in tmux
│   ├── install_prerequisites.sh    # Install Ollama, n8n, Mistral
│   ├── setup_new_instance_with_storage.sh  # Complete Vast.ai setup
│   ├── import_new_workflows.sh     # Import n8n workflows
│   ├── check_complete_system.sh    # System health check
│   ├── check_installations_and_disk_usage.sh  # Disk usage report
│   └── lib/
│       └── common.sh                # Shared functions & config
│
├── 📂 configs/                      # Configuration files
│   ├── llm_config.yaml              # LLM model settings
│   ├── tts_config.yaml              # TTS voice settings
│   ├── animation_config.yaml       # Animation quality settings
│   └── teacher_prompts.yaml         # Teacher personalities
│
├── 📂 Nextwork-Teachers/           # Teacher avatar images
│   ├── krishna.png
│   ├── Maximus.png
│   ├── Maya.png
│   ├── Pano Bieber.png
│   └── TechMonkey Steve.png
│
├── 📂 LongCat-Video/                # LongCat-Video submodule/project
│   ├── weights/                     # Model weights
│   ├── assets/                      # Assets
│   └── [LongCat-Video source code]
│
├── 📂 docs/                         # Documentation
│   ├── QUICK_START_NEW_INSTANCE.md  # Setup guide for new Vast.ai instance
│   ├── QUICK_START_2_TEACHER.md     # Quick start for 2-teacher system
│   ├── TWO_TEACHER_ARCHITECTURE.md  # Architecture details
│   ├── ARCHITECTURE.md              # System architecture
│   ├── TERMINAL_GUIDE.md            # Desktop vs VAST terminal guide
│   └── [29 other documentation files]
│
└── 📂 outputs/                      # Generated outputs (created at runtime)
    └── longcat/                     # Generated video clips
```

---

## 🚀 Implementation Plan & Roadmap

### ✅ Phase 1: Core Infrastructure (COMPLETE)
- [x] Project structure
- [x] Coordinator API (session state, turn-taking)
- [x] n8n workflow orchestration
- [x] Frontend UI (Streamlit with dual video players)
- [x] Basic service deployment scripts

### ✅ Phase 2: LLM & TTS Integration (COMPLETE)
- [x] Ollama setup with Mistral 7B
- [x] LLM integration in n8n workflows
- [x] Piper TTS service
- [x] Language-to-voice mapping
- [x] Multi-language support

### ✅ Phase 3: Video Generation (COMPLETE)
- [x] LongCat-Video service integration
- [x] Video generation pipeline
- [x] Avatar image management
- [x] Clip notification system

### 🔄 Phase 4: Database & Caching (IN PROGRESS)
- [x] PostgreSQL + pgvector setup
- [x] Vast.ai storage volume integration
- [ ] Database schema (sessions, sections, embeddings)
- [ ] Content-based caching (reuse videos for same content)
- [ ] RAG system for contextual retrieval

### 📋 Phase 5: Page Segmentation & RAG (PLANNED)
- [ ] Automatic page segmentation service
- [ ] Pre-process all sections on page load
- [ ] Store embeddings in pgvector
- [ ] Retrieve relevant context for LLM prompts
- [ ] Round-robin section assignment to teachers

### 📋 Phase 6: Polish & Optimization (PLANNED)
- [ ] Error handling & retry logic
- [ ] Performance optimization
- [ ] Caching strategy refinement
- [ ] Monitoring & logging
- [ ] Auto-scaling considerations

---

## 🛠️ Tech Stack

### Core Technologies
- **Orchestration**: n8n (workflow automation)
- **LLM**: Ollama + Mistral 7B (local inference)
- **TTS**: Piper TTS (multi-language voices)
- **Video**: LongCat-Video (lip-sync animation)
- **Frontend**: Streamlit (Python web framework)
- **Backend**: FastAPI (Python async API)
- **Database**: PostgreSQL + pgvector (vector search)
- **Storage**: Vast.ai persistent volume

### Deployment
- **Hosting**: Vast.ai (GPU cloud instances)
- **GPUs**: 2x A100 (80GB VRAM total recommended)
- **Storage**: Vast.ai storage volume (200-500 GB)
- **Deployment Mode**: No-Docker (services run directly on host)

---

## 🚀 Quick Start

### Prerequisites
- Vast.ai account
- SSH access to Vast.ai instance
- PowerShell (for port forwarding on Windows)

### 1. Setup New Vast.ai Instance

**📍 VAST Terminal**

```bash
# Clone repository
cd ~
git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
cd Nextwork-Teachers-TechMonkey

# Run complete setup (includes Ollama, n8n, PostgreSQL, etc.)
bash scripts/setup_new_instance_with_storage.sh
```

### 2. Deploy Services

**📍 VAST Terminal**

```bash
cd ~/Nextwork-Teachers-TechMonkey

# Deploy all services (creates venv, installs dependencies, starts services)
bash scripts/deploy_2teacher_system.sh
```

### 3. Import n8n Workflows

**📍 VAST Terminal**

```bash
cd ~/Nextwork-Teachers-TechMonkey

# Import workflows (requires n8n API key in .env)
bash scripts/import_new_workflows.sh
```

### 4. Setup Port Forwarding

**📍 Desktop PowerShell**

```powershell
cd E:\DATA_1TB\Desktop\Nextwork_Teachers_TechMonkey
.\connect-vast.ps1
```

**Keep this window open!** Port forwarding stops if you close it.

### 5. Access Services

**📍 Desktop Browser**

- **Frontend**: http://localhost:8501
- **n8n**: http://localhost:5678
- **Coordinator API**: http://localhost:8004

---

## 📖 Key Concepts

### Session State
Each student session has:
- **Session ID**: Unique identifier
- **Active Teachers**: Which two teachers are active (e.g., `["teacher_a", "teacher_d"]`)
- **Turn Counter**: Tracks whose turn it is to speak
- **Current Section**: What content the student is viewing
- **Queue Status**: Which teacher is rendering the next clip

### Turn-Taking
- **Round-robin**: Teachers alternate turns automatically
- **Parallel Processing**: While one speaks, the other prepares the next response
- **Zero Delay**: Next clip is ready before current one finishes

### Language Support
- **Multi-language**: Select language in UI (English, Spanish, French, etc.)
- **Voice Mapping**: Each language uses appropriate TTS voice
- **LLM Prompts**: LLM responds in selected language

---

## 🔗 Quick Links

- **GitHub**: https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
- **Quick Start Guide**: [docs/QUICK_START_NEW_INSTANCE.md](docs/QUICK_START_NEW_INSTANCE.md)
- **Architecture Details**: [docs/TWO_TEACHER_ARCHITECTURE.md](docs/TWO_TEACHER_ARCHITECTURE.md)
- **Terminal Guide**: [docs/TERMINAL_GUIDE.md](docs/TERMINAL_GUIDE.md) (Desktop vs VAST Terminal)

---

## 📝 Current Status

**✅ Working:**
- Dual teacher system with turn-taking
- LLM generation (Mistral 7B via Ollama)
- TTS generation (Piper TTS, multi-language)
- Video generation (LongCat-Video)
- Frontend UI with real-time updates
- Session state management

**🔄 In Progress:**
- Database integration (PostgreSQL + pgvector)
- Content caching system
- Page segmentation & RAG

**📋 Planned:**
- Automatic page analysis
- Context-aware responses
- Performance optimization

---

## 🤝 Contributing

This project is developed by Sean Fitzgerald. Contributions welcome!

## 📄 License

Open source - see LICENSE file for details.
