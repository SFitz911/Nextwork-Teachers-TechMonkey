# System Architecture

## Overview

The AI Virtual Classroom Teacher Agent is a distributed system that orchestrates multiple AI services to create realistic, interactive teacher avatars.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Frontend (Streamlit)                  │
│  - Dual video players                                   │
│  - Chat interface                                       │
│  - WebSocket/SSE for streaming                          │
└────────────────────┬────────────────────────────────────┘
                     │ HTTP/WebSocket
                     ↓
┌─────────────────────────────────────────────────────────┐
│                  n8n Orchestration Layer                 │
│  - Webhook triggers                                     │
│  - Workflow orchestration                               │
│  - State management (Redis)                             │
│  - Teacher switching logic                              │
└─────┬───────────────────────────────────┬───────────────┘
      │                                   │
      ↓                                   ↓
┌──────────────┐                ┌──────────────┐
│  Teacher A   │                │  Teacher B   │
│  Pipeline    │                │  Pipeline    │
└──────┬───────┘                └──────┬───────┘
       │                               │
       ├─→ LLM (Ollama/vLLM)          ├─→ LLM (Ollama/vLLM)
       ├─→ TTS (Piper/Coqui)          ├─→ TTS (Piper/Coqui)
       └─→ Animation (LAM)             └─→ Animation (LAM)
```

## Component Details

### 1. Frontend (Streamlit/Gradio)

**Purpose**: User interface for viewers to interact with teachers

**Responsibilities**:
- Display two side-by-side video players
- Chat input interface
- Real-time video streaming
- Service status monitoring

**Technologies**:
- Streamlit or Gradio
- WebSocket client for real-time updates
- HTML5 video players

### 2. n8n Orchestration

**Purpose**: Central workflow engine that coordinates all services

**Key Workflows**:
- Chat message processing
- Teacher state management
- Response generation pipeline
- Video streaming coordination

**State Management**:
- Uses Redis to track:
  - Current speaking teacher
  - Thinking teacher
  - Conversation history
  - Job status

### 3. LLM Service (Ollama/vLLM)

**Purpose**: Generate intelligent responses to student questions

**Models**:
- Mistral-7B-Instruct
- Llama-3-8B
- Can be swapped easily

**Features**:
- Streaming responses
- Context-aware generation
- Teacher-specific prompting

### 4. TTS Service (Piper/Coqui)

**Purpose**: Convert text responses to natural speech

**Features**:
- Multiple voice options
- Chunked audio generation
- Streaming support
- Adjustable speed and pitch

### 5. Animation Service (LAM/LivePortrait)

**Purpose**: Generate lip-synced video from audio

**Models**:
- Primary: LAM (Large Avatar Model)
- Fallback: LivePortrait, SadTalker, Wav2Lip

**Features**:
- Real-time lip-sync
- Natural head movements
- High-quality output
- Batch processing support

## Data Flow

### Standard Question-Answer Flow

1. **User Input**: Viewer types question in frontend
2. **Webhook**: Frontend sends message to n8n webhook
3. **State Check**: n8n determines which teacher should respond
4. **LLM Request**: n8n calls Ollama/vLLM with question + context
5. **Streaming Response**: LLM streams tokens back to n8n
6. **TTS Generation**: As text arrives, TTS service generates audio chunks
7. **Animation**: Animation service processes audio + avatar image
8. **Video Streaming**: Completed video chunks sent to frontend
9. **Parallel Processing**: Other teacher begins generating next response

### Dual-Teacher Tag-Team Flow

```
Time →
Teacher A: [Generating] ────→ [Speaking] ──────────────→ [Idle]
Teacher B: [Idle] ──────────→ [Preparing] ────→ [Speaking] ────→ [Idle]
```

1. Teacher A receives question and starts generating
2. Teacher B remains in idle/thinking animation
3. Teacher A speaks response
4. While A speaks, Teacher B generates next response
5. Teacher B begins speaking as A finishes
6. Cycle continues

## State Management

### Redis Keys

- `teacher:current_speaker`: "teacher_a" | "teacher_b"
- `teacher:thinking`: "teacher_a" | "teacher_b"
- `teacher:a:status`: "idle" | "generating" | "speaking"
- `teacher:b:status`: "idle" | "generating" | "speaking"
- `chat:history`: JSON array of recent messages
- `job:{teacher_id}:{job_id}`: Job status and metadata

## Latency Optimization

### Target: <3-4 seconds to first words

**Strategies**:
1. **Streaming LLM**: Start TTS as soon as first tokens arrive
2. **Chunked TTS**: Generate audio in small chunks
3. **Parallel Processing**: While one speaks, other prepares
4. **Model Quantization**: Use 4-bit quantized models for speed
5. **Caching**: Cache common responses and animations
6. **GPU Utilization**: Batch process when possible

## Scalability Considerations

### Single Instance (Current Design)
- Suitable for 1-10 concurrent viewers
- All services on one GPU instance

### Multi-Instance (Future)
- Load balancer for frontend
- Multiple n8n workers
- Separate GPU pools for TTS/Animation
- Distributed Redis for state

## Deployment Architecture

### Vast.ai Instance Layout

```
Vast.ai GPU Instance (A100 40GB+)
├── Docker Compose
│   ├── n8n (CPU)
│   ├── Ollama (GPU)
│   ├── TTS Service (GPU)
│   ├── Animation Service (GPU)
│   ├── Frontend (CPU)
│   └── Redis (CPU)
└── Data Volumes
    ├── Models (~10-20GB)
    ├── Avatars (~100MB)
    └── Output (~1GB)
```

## Security Considerations

- n8n authentication enabled
- Webhook URL tokens
- CORS configuration for frontend
- Rate limiting on API endpoints
- Input sanitization for chat messages

## Monitoring & Logging

- n8n execution logs
- Service health endpoints
- GPU utilization monitoring
- Latency metrics per component
- Error tracking and alerting
