# Nextwork Teachers TechMonkey — Master Plan
## Dual Teacher Live AI Classroom System

---

## 📋 Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Overview](#system-overview)
3. [Core Architecture](#core-architecture)
4. [Session State Machine](#session-state-machine)
5. [Event-Driven Communication](#event-driven-communication)
6. [Teacher Pipeline Architecture](#teacher-pipeline-architecture)
7. [RAG Integration](#rag-integration)
8. [Turn-Taking Logic](#turn-taking-logic)
9. [Latency Masking Strategies](#latency-masking-strategies)
10. [Failure Handling & Resilience](#failure-handling--resilience)
11. [Implementation Checklist](#implementation-checklist)
12. [Tech Stack & Infrastructure](#tech-stack--infrastructure)
13. [Future Roadmap](#future-roadmap)

---

## Executive Summary

### TL;DR

You're building a **2-teacher "live classroom"** system where:
- **Teacher A speaks on-camera** while **Teacher B silently prepares** the next clip (RAG → LLM → TTS → Avatar Video)
- Teachers **alternate turns continuously** with zero visible lag
- **Exactly two teachers** are active per session (user-selected)
- Each teacher runs in a **fully independent pipeline**, coordinated by a **session state machine**
- **No merge nodes, no blocking webhooks** — synchronize by state + events

### Key Principles

1. **Never block** — all operations are asynchronous
2. **Hide latency** — renderer always stays one clip ahead
3. **State-driven** — synchronize by state + events, never by merging data
4. **Resilient** — graceful degradation at every layer
5. **Scalable** — independent pipelines enable true concurrency

---

## System Overview

### End Goal: What "Done" Looks Like

#### User Interface Layout

```
┌─────────────────────────────────────────────────────────────┐
│                    AI Virtual Classroom                     │
├──────────────┬──────────────────────────┬──────────────────┤
│              │                          │                  │
│  Left Panel  │    Center Panel         │   Right Panel    │
│              │                          │                  │
│  Teacher A   │   Website / Lesson       │   Teacher B      │
│  Avatar      │   View (scrollable,      │   Avatar         │
│  (Video)     │   highlightable)         │   (Video)        │
│              │                          │                  │
│  🎤 Speaking │   [Content Area]        │   ⏳ Rendering   │
│              │                          │                  │
├──────────────┴──────────────────────────┴──────────────────┤
│  Captions + Controls (pause, next, swap, speed)            │
└─────────────────────────────────────────────────────────────┘
```

#### Behavioral Requirements

- **Exactly two teachers** active per session (user selects from available pool)
- **Continuous alternation**: While Teacher A is speaking, Teacher B is rendering
- **Zero visible lag**: When A finishes, B's clip is already ready to play
- **Seamless handoffs**: Teachers naturally pass control to each other
- **Context-aware**: Teachers reference visible content, user selections, and RAG-retrieved knowledge

---

## Core Architecture

### Fundamental Rule

> **Never synchronize by merging data. Synchronize by state + events.**

This is the most important architectural decision. It enables:
- True concurrency (both teachers can render simultaneously)
- Clear isolation (each pipeline is independent)
- Predictable behavior (state machine is the single source of truth)
- Easy debugging (events are traceable)

### Three-Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Frontend UI                          │
│  • Teacher pair selector                                   │
│  • Website container with DOM extraction                    │
│  • Video/audio playback                                    │
│  • Event listener (SSE/WebSocket)                          │
│  • Clip queue management                                   │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ HTTP/SSE/WebSocket
                        │ • Start session
                        │ • Send section snapshots
                        │ • Receive events
                        │ • Notify speech-ended
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                    Coordinator API                          │
│  • Session state machine (authoritative)                    │
│  • Turn-taking engine                                      │
│  • Job routing (enqueue render jobs)                        │
│  • Event emission (SSE/WebSocket)                          │
│  • RAG query service                                        │
└───────┬───────────────────────────────────────┬─────────────┘
        │                                       │
        │ enqueue job                           │ enqueue job
        │ (renderer = left)                     │ (renderer = right)
        ▼                                       ▼
┌──────────────────────┐              ┌──────────────────────┐
│   LEFT_WORKER         │              │   RIGHT_WORKER        │
│   (n8n Pipeline)     │              │   (n8n Pipeline)     │
│                      │              │                      │
│ 1. Fetch session     │              │ 1. Fetch session     │
│ 2. Query RAG         │              │ 2. Query RAG         │
│ 3. LLM Generate      │              │ 3. LLM Generate      │
│ 4. TTS Generate      │              │ 4. TTS Generate      │
│ 5. Video Generate    │              │ 5. Video Generate    │
│ 6. POST CLIP_READY   │              │ 6. POST CLIP_READY   │
└──────────┬────────────┘              └──────────┬────────────┘
           │                                      │
           └──────────────┬───────────────────────┘
                          │ POST /session/:id/clip-ready
                          ▼
              ┌───────────────────────────┐
              │   Coordinator API          │
              │   • Updates session state   │
              │   • Emits CLIP_READY event │
              └───────────────────────────┘
```

### Component Responsibilities

#### Frontend UI
- **Display**: Render teacher avatars, website content, captions
- **Input**: Capture user interactions (scroll, selection, questions)
- **Communication**: Send snapshots, receive events, notify speech-ended
- **Playback**: Queue and play clips, handle transitions

#### Coordinator API
- **State Management**: Maintain authoritative session state
- **Turn Engine**: Decide who speaks next, swap roles
- **Job Routing**: Enqueue render jobs for the renderer
- **Event Broadcasting**: Emit events to all connected UIs
- **RAG Service**: Query knowledge base, return relevant context

#### n8n Workers (LEFT + RIGHT)
- **Pipeline Execution**: Run complete teacher pipeline independently
- **Validation**: Check if job is still valid before processing
- **Asset Generation**: Create audio, video, captions
- **Notification**: Post CLIP_READY when complete

---

## Session State Machine

### Authoritative Session Object

The Coordinator API maintains the single source of truth for each session:

```json
{
  "sessionId": "abc123",
  "createdAt": "2026-01-25T19:30:00Z",
  "status": "active",
  
  "activeTeachers": ["teacher_a", "teacher_d"],
  "leftTeacher": "teacher_a",
  "rightTeacher": "teacher_d",
  
  "turn": 0,
  "speaker": "teacher_a",
  "renderer": "teacher_d",
  
  "currentSectionId": "sec-05",
  "currentSnapshot": {
    "url": "https://yourproject.com/lesson/5",
    "scrollY": 1280,
    "visibleText": "Step 5: Build the API route...\n\nWe will create...",
    "selectedText": "server-side validation",
    "userQuestion": "Why do we validate on the server?",
    "domDigest": "sha256:abc123...",
    "timestamp": "2026-01-25T19:30:15Z"
  },
  
  "queues": {
    "teacher_a": {
      "status": "speaking",
      "currentClipId": "clip-990",
      "nextClipId": null,
      "lastUpdated": "2026-01-25T19:30:10Z"
    },
    "teacher_d": {
      "status": "ready",
      "currentClipId": null,
      "nextClipId": "clip-991",
      "lastUpdated": "2026-01-25T19:30:20Z"
    }
  },
  
  "history": [
    {
      "turn": 0,
      "speaker": "teacher_a",
      "clipId": "clip-990",
      "timestamp": "2026-01-25T19:30:10Z"
    }
  ]
}
```

### Teacher Status States

Each teacher can be in exactly one of these states:

```
┌─────────┐
│  idle   │  ← Initial state, no active job
└────┬────┘
     │ enqueue render job
     ▼
┌────────────┐
│ rendering  │  ← Worker is generating clip
└────┬───────┘
     │ POST CLIP_READY
     ▼
┌─────────┐
│  ready  │  ← Clip complete, waiting to play
└────┬────┘
     │ swap roles (speaker finishes)
     ▼
┌──────────┐
│ speaking │  ← Currently playing on UI
└────┬─────┘
     │ POST speech-ended
     ▼
┌─────────┐
│  idle   │  ← Ready for next render job
└─────────┘

Error path:
Any state → error (on failure)
error → idle (after recovery/retry)
```

### Turn-Taking Rules (Invariants)

These rules must **always** be true:

1. **Exactly one speaker**: `speaker ∈ activeTeachers`
2. **Exactly one renderer**: `renderer ∈ activeTeachers`
3. **Speaker ≠ Renderer**: `speaker !== renderer`
4. **Speaker status**: `queues[speaker].status ∈ {speaking, ready}`
5. **Renderer status**: `queues[renderer].status ∈ {rendering, ready}`
6. **Swap on completion**: When `speech-ended` received → swap `speaker` and `renderer`

### State Transition Logic Tree

```
┌─────────────────────────────────────┐
│   Session State Machine              │
└─────────────────────────────────────┘

Event: POST /session/start
├─ Validate: selectedTeachers.length === 2
├─ Create session object
├─ Set speaker = leftTeacher (or random)
├─ Set renderer = rightTeacher
├─ Set queues[speaker].status = "idle"
├─ Set queues[renderer].status = "idle"
└─ Enqueue render job for renderer
   └─ POST /worker/{renderer_side}/run

Event: POST /session/:id/section
├─ Validate: session exists
├─ Update currentSnapshot
├─ IF renderer.status === "idle"
│  └─ Enqueue render job for renderer
└─ Emit SECTION_UPDATED event

Event: POST /session/:id/clip-ready
├─ Validate: session exists
├─ Validate: teacher ∈ activeTeachers
├─ Validate: teacher === renderer (or allow if ready)
├─ Update queues[teacher].status = "ready"
├─ Update queues[teacher].nextClipId = clipId
└─ Emit CLIP_READY event
   └─ IF teacher === speaker AND speaker clip not ready
      └─ Use this clip immediately

Event: POST /session/:id/speech-ended
├─ Validate: session exists
├─ Validate: clipId matches current speaker clip
├─ IF renderer.status === "ready"
│  ├─ Swap: speaker ↔ renderer
│  ├─ Increment turn
│  ├─ Update queues[new_speaker].status = "speaking"
│  ├─ Update queues[new_renderer].status = "idle"
│  ├─ Emit SPEAKER_CHANGED event
│  └─ Enqueue render job for new renderer
│     └─ POST /worker/{new_renderer_side}/run
└─ ELSE (renderer not ready)
   ├─ Emit WARNING event
   └─ Generate bridging clip for current speaker
      └─ Short filler clip (2-4 seconds)
```

---

## Event-Driven Communication

### Event Stream Protocol

The Coordinator API emits events via **Server-Sent Events (SSE)** or **WebSocket**:

**Connection**: `GET /session/:id/events` (SSE) or `WS /session/:id/events` (WebSocket)

### Event Types

#### 1. SESSION_STARTED

Emitted immediately after session creation.

```json
{
  "type": "SESSION_STARTED",
  "sessionId": "abc123",
  "timestamp": "2026-01-25T19:30:00Z",
  "leftTeacher": "teacher_a",
  "rightTeacher": "teacher_d",
  "speaker": "teacher_a",
  "renderer": "teacher_d",
  "turn": 0
}
```

**UI Action**: Initialize session state, display teacher avatars, start listening for clips.

#### 2. CLIP_READY

Emitted when a worker completes clip generation.

```json
{
  "type": "CLIP_READY",
  "sessionId": "abc123",
  "timestamp": "2026-01-25T19:30:20Z",
  "teacher": "teacher_d",
  "clip": {
    "clipId": "clip-991",
    "text": "Alright, now look at the function on line 42. Notice how we're using server-side validation here...",
    "audioUrl": "http://localhost:8001/audio/clip-991.wav",
    "videoUrl": "http://localhost:8003/video/clip-991.mp4",
    "durationMs": 8200,
    "status": "completed",
    "sectionId": "sec-05",
    "turn": 0,
    "metadata": {
      "onScreenAction": "highlight",
      "targetSelector": "#code-block-3",
      "handoff": "ask_other_teacher"
    }
  }
}
```

**UI Action**: 
- Store clip in teacher's queue
- If teacher === speaker AND no current clip playing → start playing immediately
- If teacher === renderer → wait for speaker to finish

#### 3. SPEAKER_CHANGED

Emitted when roles swap after speech-ended.

```json
{
  "type": "SPEAKER_CHANGED",
  "sessionId": "abc123",
  "timestamp": "2026-01-25T19:30:28Z",
  "speaker": "teacher_d",
  "renderer": "teacher_a",
  "turn": 1,
  "previousSpeaker": "teacher_a",
  "previousRenderer": "teacher_d"
}
```

**UI Action**:
- Stop current speaker's video
- Check if new speaker has ready clip
- If yes → start playing new speaker's clip
- If no → show "Rendering..." message, wait for CLIP_READY

#### 4. SECTION_UPDATED

Emitted when UI sends a new section snapshot.

```json
{
  "type": "SECTION_UPDATED",
  "sessionId": "abc123",
  "timestamp": "2026-01-25T19:30:15Z",
  "sectionId": "sec-05",
  "url": "https://yourproject.com/lesson/5",
  "scrollY": 1280,
  "visibleText": "Step 5: Build the API route...",
  "selectedText": "server-side validation"
}
```

**UI Action**: Update UI to reflect current section (optional visual feedback).

#### 5. ERROR

Emitted when an error occurs.

```json
{
  "type": "ERROR",
  "sessionId": "abc123",
  "timestamp": "2026-01-25T19:30:25Z",
  "teacher": "teacher_d",
  "error": {
    "code": "VIDEO_GENERATION_FAILED",
    "message": "Video generation service unavailable",
    "fallback": "audio_only",
    "clipId": "clip-991-fallback"
  }
}
```

**UI Action**: 
- Show error message to user
- If fallback available → use audio-only clip with idle animation
- Retry or skip based on error type

### Event Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Event Flow                               │
└─────────────────────────────────────────────────────────────┘

UI Action: Start Session
  │
  ▼
POST /session/start
  │
  ▼
Coordinator: Create session
  │
  ├─► Emit SESSION_STARTED ──► UI receives ──► Initialize UI
  │
  └─► Enqueue render job for renderer
      │
      ▼
Worker: Generate clip
  │
  ├─► Query RAG
  ├─► LLM Generate
  ├─► TTS Generate
  ├─► Video Generate
  │
  ▼
POST /session/:id/clip-ready
  │
  ▼
Coordinator: Update state
  │
  ├─► Emit CLIP_READY ──► UI receives ──► Store in queue
  │
  └─► IF speaker clip ready ──► UI plays clip

UI Action: Clip finishes playing
  │
  ▼
POST /session/:id/speech-ended
  │
  ▼
Coordinator: Swap roles
  │
  ├─► Emit SPEAKER_CHANGED ──► UI receives ──► Switch to new speaker
  │
  └─► Enqueue render job for new renderer
      │
      └─► (Loop continues)
```

---

## Teacher Pipeline Architecture

### Pipeline Overview

Each worker (LEFT and RIGHT) runs an identical pipeline template. The only difference is the webhook route and which teacher they're assigned to.

### Complete Pipeline Flow

```
┌─────────────────────────────────────────────────────────────┐
│              LEFT_WORKER / RIGHT_WORKER Pipeline            │
└─────────────────────────────────────────────────────────────┘

1. Webhook Trigger
   ├─ Route: /worker/left/run OR /worker/right/run
   └─ Payload:
      {
        "sessionId": "abc123",
        "teacher": "teacher_a",
        "role": "renderer",
        "sectionPayload": {...},
        "turn": 0
      }

2. HTTP Request: Get Session State
   ├─ GET /session/:id/state
   └─ Response: Full session object

3. IF Node: Validate Job Still Valid
   ├─ Condition: teacher ∈ session.activeTeachers
   ├─ Condition: role === session.renderer (or allow if ready)
   ├─ Condition: turn matches (avoid stale jobs)
   └─ IF invalid → Respond 200 (discard silently)
      IF valid → Continue

4. HTTP Request: Query RAG
   ├─ POST /rag/query
   ├─ Payload:
      {
        "sessionId": "abc123",
        "visibleText": "...",
        "selectedText": "...",
        "userQuestion": "...",
        "teacher": "teacher_a"
      }
   └─ Response: Top K relevant chunks with embeddings

5. Code Node: Prepare LLM Prompt
   ├─ Input: RAG context + sectionPayload + teacher persona
   ├─ Build prompt:
      {
        "system": "You are Teacher A, co-teaching with Teacher D...",
        "context": "[RAG chunks]",
        "visibleContent": sectionPayload.visibleText,
        "selectedText": sectionPayload.selectedText,
        "userQuestion": sectionPayload.userQuestion,
        "instructions": "Speak in 8-12 second segments, reference on-screen content..."
      }
   └─ Output: Formatted prompt

6. LLM Generate (Ollama/OpenAI)
   ├─ Model: mistral:7b (or configured model)
   ├─ Temperature: 0.7
   ├─ Max tokens: 200
   └─ Response: Raw LLM output

7. Code Node: Extract & Normalize Response
   ├─ Parse JSON response (if structured)
   ├─ Extract spoken_text
   ├─ Validate length (target: 8-12 seconds spoken)
   ├─ Apply safety filters
   ├─ Extract metadata (onScreenAction, handoff, etc.)
   └─ Output:
      {
        "text": "Alright, now look at...",
        "durationEstimate": 8500,
        "metadata": {...}
      }

8. HTTP Request: Generate TTS
   ├─ POST /tts/generate
   ├─ Payload:
      {
        "text": "...",
        "voice": "teacher_a_voice",
        "language": "en"
      }
   └─ Response:
      {
        "audioUrl": "http://localhost:8001/audio/clip-991.wav",
        "durationMs": 8200
      }

9. HTTP Request: Generate Avatar Video
   ├─ POST /video/generate
   ├─ Payload:
      {
        "avatar_id": "teacher_a",
        "audio_url": "http://localhost:8001/audio/clip-991.wav",
        "text_prompt": "A warm educator speaking naturally...",
        "resolution": "480p",
        "num_segments": 1
      }
   ├─ Timeout: 300000 (5 minutes)
   ├─ Retries: 2
   └─ Response:
      {
        "job_id": "job-991",
        "status": "processing",
        "video_url": "http://localhost:8003/video/job-991"
      }
   └─ IF error → Continue with audio-only fallback

10. Code Node: Format Clip Object
    ├─ Input: TTS audioUrl, video job_id, text, metadata
    ├─ Generate clipId: `clip-{sessionId}-{teacher}-{turn}-{timestamp}`
    └─ Output:
       {
         "clipId": "clip-991",
         "text": "...",
         "audioUrl": "...",
         "videoUrl": "...",
         "jobId": "job-991",
         "durationMs": 8200,
         "status": "processing" | "completed" | "audio_only",
         "sectionId": "sec-05",
         "turn": 0,
         "metadata": {...}
       }

11. HTTP Request: POST Clip Ready
    ├─ POST /session/:id/clip-ready
    ├─ Payload:
       {
         "sessionId": "abc123",
         "teacher": "teacher_a",
         "clip": {...}
       }
    └─ Response: {"status": "ok"}

12. Respond to Webhook
    └─ Return 200 OK (job complete)
```

### Pipeline Decision Tree

```
┌─────────────────────────────────────┐
│   Worker Pipeline Decision Tree      │
└─────────────────────────────────────┘

Receive job
  │
  ▼
Fetch session state
  │
  ▼
Is job still valid?
  ├─ NO → Discard silently (return 200)
  └─ YES → Continue
      │
      ▼
Query RAG
  │
  ├─ Success → Use RAG context
  └─ Failure → Continue without RAG (log warning)
      │
      ▼
Generate LLM response
  │
  ├─ Success → Extract text
  └─ Failure → Retry once, then use fallback text
      │
      ▼
Generate TTS
  │
  ├─ Success → Get audioUrl
  └─ Failure → Abort job, send ERROR event
      │
      ▼
Generate video
  │
  ├─ Success → Get videoUrl
  ├─ Timeout → Use audio-only fallback
  └─ Failure → Use audio-only fallback
      │
      ▼
POST CLIP_READY
  │
  ├─ Success → Job complete
  └─ Failure → Retry 2x, then log error
```

### No Merge Nodes Policy

**Critical**: The pipeline must never use merge nodes or wait for other pipelines. Each worker is completely independent.

**Why?**
- Enables true concurrency (both teachers can render simultaneously)
- Prevents deadlocks (no waiting on other workers)
- Simplifies debugging (each pipeline is self-contained)
- Allows independent scaling (can run workers on different machines)

---

## RAG Integration

### RAG Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    RAG System                               │
└─────────────────────────────────────────────────────────────┘

Knowledge Sources
  │
  ├─► Lesson content (markdown, HTML)
  ├─► Code examples
  ├─► Documentation
  └─► Previous session transcripts
      │
      ▼
Chunking Service
  │
  ├─► Split by semantic boundaries
  ├─► Preserve context (overlap chunks)
  └─► Extract metadata (section, lesson, topic)
      │
      ▼
Embedding Service
  │
  ├─► Generate embeddings (OpenAI/text-embedding-3-small)
  └─► Store with metadata
      │
      ▼
Vector Database (PostgreSQL + pgvector)
  │
  ├─► Store: (embedding, text, metadata, section_id)
  └─► Index: HNSW index for fast similarity search
      │
      ▼
RAG Query Service (Coordinator API)
  │
  ├─► POST /rag/query
  ├─► Input: visibleText, selectedText, userQuestion
  ├─► Generate query embedding
  ├─► Vector similarity search (top K=5)
  └─► Return: Relevant chunks with scores
      │
      ▼
Worker Pipeline
  │
  └─► Inject RAG context into LLM prompt
```

### RAG Query Flow

```json
// Request
POST /rag/query
{
  "sessionId": "abc123",
  "visibleText": "Step 5: Build the API route...",
  "selectedText": "server-side validation",
  "userQuestion": "Why do we validate on the server?",
  "teacher": "teacher_a",
  "maxResults": 5
}

// Response
{
  "chunks": [
    {
      "text": "Server-side validation is critical because...",
      "score": 0.92,
      "metadata": {
        "sectionId": "sec-03",
        "lessonId": "lesson-1",
        "topic": "validation"
      }
    },
    {
      "text": "Always validate user input on the server...",
      "score": 0.87,
      "metadata": {...}
    }
  ],
  "queryEmbedding": [0.123, ...],
  "totalResults": 5
}
```

### RAG Prompt Injection

The RAG chunks are injected into the LLM prompt like this:

```
System: You are Teacher A, co-teaching with Teacher D. You are an expert educator
who makes complex topics relatable. Speak in 8-12 second segments.

Context from knowledge base:
1. "Server-side validation is critical because client-side validation can be bypassed..."
2. "Always validate user input on the server to prevent security vulnerabilities..."

Current screen content:
- URL: https://yourproject.com/lesson/5
- Visible text: "Step 5: Build the API route..."
- Selected text: "server-side validation"
- User question: "Why do we validate on the server?"

Instructions:
- Reference the context above when relevant
- Point to specific on-screen elements
- Keep responses to 8-12 seconds when spoken
- End with a handoff cue for Teacher D

Generate your response in JSON format:
{
  "spoken_text": "...",
  "on_screen_action": "highlight|scroll|point|none",
  "target_selector": "#code-block-3",
  "handoff": "ask_other_teacher|continue_self"
}
```

### Pre-Generation & Caching Strategy (Zero-Lag Architecture)

#### Core Concept

To achieve **zero-lag, natural conversation flow**, the system uses a **pre-generation + RAG caching** strategy:

1. **Pre-read lesson** → Parse and split content into logical sections
2. **Pre-assign sections** → Teacher A gets sections 1, 3, 5... Teacher B gets sections 2, 4, 6...
3. **Pre-generate videos** → Each teacher generates video/audio responses for their assigned sections in background
4. **Store in RAG** → Videos, audio, transcripts, and metadata indexed for instant retrieval
5. **Progressive improvement** → More usage = more cached content = faster responses

#### Architecture Flow

```
User selects lesson URL
    ↓
Read & parse lesson content
    ↓
Split into sections (semantic boundaries, not just length)
    ├─► Tag with keywords, concepts, topics
    └─► Assign to Teacher A (odd) / Teacher B (even)
    ↓
Pre-generate videos (background, parallel processing)
    ├─► Generate: Video URL, Audio URL, Transcript
    ├─► Extract: Keywords, Concepts, Topics
    └─► Store metadata: Section ID, Lesson ID, Teacher, Turn
    ↓
Store in RAG with rich metadata:
    ├─► Video URL (pre-generated)
    ├─► Audio URL (pre-generated)
    ├─► Transcript (full text)
    ├─► Keywords (extracted)
    ├─► Concepts (extracted)
    ├─► Section metadata (ID, lesson, topic)
    └─► Embeddings (for similarity search)
    ↓
User asks question
    ↓
RAG searches:
    ├─► Transcript text (semantic similarity)
    ├─► Keywords (exact match)
    ├─► Concepts (conceptual match)
    └─► Metadata (section, lesson, topic)
    ↓
Retrieve best match(es) with scores
    ↓
Return pre-generated video/audio (INSTANT - zero lag!)
    ↓
If no match → Fallback to real-time generation
```

#### Two-Tier RAG System

**Tier 1: Pre-Generated Content (Instant)**
- Pre-generated videos/audio for lesson sections
- Common Q&A pairs (pre-answered)
- Frequently accessed content
- **Result**: Zero lag for cached content

**Tier 2: Real-Time Generation (Fallback)**
- For unexpected questions
- Edge cases not covered by pre-generation
- Follow-up questions requiring synthesis
- **Result**: Handles all cases, with slight delay

#### Smart Sectioning Strategy

**Don't just split by length - split by meaning:**

- **Semantic boundaries**: Split at topic changes, concept transitions
- **Natural breaks**: Paragraphs, code blocks, examples
- **Context preservation**: Overlap chunks to maintain context
- **Tagging**: Extract keywords, concepts, topics for each section
- **Result**: Better RAG retrieval, more relevant answers

#### Metadata Indexing Schema

Each pre-generated clip stored in RAG includes:

```json
{
  "clip_id": "clip-{sessionId}-{teacher}-{turn}-{timestamp}",
  "video_url": "http://localhost:8003/video/{jobId}",
  "audio_url": "http://localhost:8001/audio/{audioId}.wav",
  "transcript": "Full spoken text of the clip",
  "section_id": "sec-03",
  "lesson_id": "lesson-1",
  "lesson_url": "https://example.com/lesson/1",
  "teacher": "teacher_a",
  "turn": 2,
  "keywords": ["validation", "server-side", "security"],
  "concepts": ["input validation", "security best practices"],
  "topics": ["backend", "api", "validation"],
  "duration_ms": 8500,
  "created_at": "2026-01-26T00:00:00Z",
  "embedding": [0.123, 0.456, ...],
  "access_count": 0,
  "last_accessed": null
}
```

#### Progressive Pre-Generation

**Don't wait for everything - start fast, expand in background:**

1. **Immediate**: Generate first 3-5 sections (instant start)
2. **Background**: Continue generating remaining sections while user watches
3. **On-demand**: Generate sections as user progresses through lesson
4. **Result**: Feels instant, but covers full content

#### Question Prediction & Pre-Answering

**Track and pre-answer common questions:**

1. **Track questions**: Log all user questions per lesson
2. **Identify patterns**: Find frequently asked questions
3. **Pre-generate answers**: Create video/audio responses for common questions
4. **Store in RAG**: Index with high priority for instant retrieval
5. **Result**: Instant answers to frequent questions

#### Edge Cases & Fallbacks

**Handle scenarios not covered by pre-generation:**

1. **Unexpected questions** → Real-time generation fallback
2. **Follow-up questions** → RAG finds related sections, chain them together
3. **Skip ahead requests** → RAG finds relevant section, jump to it
4. **Content updates** → Version RAG entries, invalidate old ones
5. **Cross-lesson questions** → Search across all lessons in RAG

#### Performance Benefits

**This approach provides:**

- ✅ **Zero lag** for pre-generated content (instant retrieval)
- ✅ **Natural flow** (A/B alternation with seamless handoffs)
- ✅ **Contextual answers** (RAG finds relevant sections)
- ✅ **Progressive improvement** (more usage = more cached content = faster)
- ✅ **Handles common questions instantly** (pre-answered Q&A)
- ✅ **Graceful degradation** (real-time fallback for edge cases)

#### Implementation Priority

1. **Phase 1**: Basic pre-generation (sections A/B, store in RAG)
2. **Phase 2**: Metadata enrichment (keywords, concepts, topics)
3. **Phase 3**: Question prediction (track, pre-answer common questions)
4. **Phase 4**: Progressive generation (start fast, expand background)
5. **Phase 5**: Cross-lesson search (search across all lessons)

---

## Turn-Taking Logic

### Turn Engine Flow

```
┌─────────────────────────────────────────────────────────────┐
│              Turn-Taking Engine Flow                        │
└─────────────────────────────────────────────────────────────┘

Initial State:
  speaker = leftTeacher
  renderer = rightTeacher
  queues[speaker].status = "idle"
  queues[renderer].status = "idle"

Step 1: Enqueue First Render Job
  │
  ├─► POST /worker/{renderer_side}/run
  └─► queues[renderer].status = "rendering"

Step 2: Worker Generates Clip
  │
  ├─► Worker: RAG → LLM → TTS → Video
  └─► Worker: POST /session/:id/clip-ready
      │
      ▼
Step 3: Coordinator Receives CLIP_READY
  │
  ├─► queues[renderer].status = "ready"
  ├─► queues[renderer].nextClipId = clipId
  └─► Emit CLIP_READY event
      │
      ▼
Step 4: UI Plays Speaker Clip
  │
  ├─► IF speaker has ready clip → Play it
  └─► ELSE → Show "Rendering..." (shouldn't happen if timing is right)
      │
      ▼
Step 5: Clip Finishes Playing
  │
  ├─► UI: POST /session/:id/speech-ended
  └─► Payload: {sessionId, clipId}
      │
      ▼
Step 6: Coordinator Swaps Roles
  │
  ├─► Validate: clipId matches current speaker clip
  ├─► IF renderer.status === "ready"
  │  ├─► Swap: speaker ↔ renderer
  │  ├─► Increment turn
  │  ├─► queues[new_speaker].status = "speaking"
  │  ├─► queues[new_renderer].status = "idle"
  │  ├─► Emit SPEAKER_CHANGED event
  │  └─► Enqueue render job for new renderer
  │      └─► POST /worker/{new_renderer_side}/run
  └─► ELSE (renderer not ready)
     ├─► Emit WARNING event
     └─► Generate bridging clip for current speaker
         └─► Short filler (2-4 seconds): "Let me scroll to the next part..."

Step 7: Loop Continues
  │
  └─► Repeat from Step 2 with swapped roles
```

### Turn-Taking State Diagram

```
┌─────────────────────────────────────────────────────────────┐
│         Turn-Taking State Diagram                          │
└─────────────────────────────────────────────────────────────┘

[Session Start]
      │
      ▼
┌─────────────────┐
│  Speaker: A      │
│  Renderer: B     │
│  B: rendering    │
└────────┬─────────┘
         │
         │ B completes clip
         ▼
┌─────────────────┐
│  Speaker: A      │
│  Renderer: B     │
│  B: ready        │
│  A: speaking     │
└────────┬─────────┘
         │
         │ A finishes speaking
         │ POST speech-ended
         ▼
┌─────────────────┐
│  Speaker: B      │ ◄─── SWAP
│  Renderer: A     │
│  B: speaking     │
│  A: rendering    │
└────────┬─────────┘
         │
         │ A completes clip
         ▼
┌─────────────────┐
│  Speaker: B      │
│  Renderer: A     │
│  A: ready        │
│  B: speaking     │
└────────┬─────────┘
         │
         │ B finishes speaking
         │ POST speech-ended
         ▼
┌─────────────────┐
│  Speaker: A      │ ◄─── SWAP
│  Renderer: B     │
│  A: speaking     │
│  B: rendering    │
└────────┬─────────┘
         │
         └─► (Loop continues)
```

---

## Latency Masking Strategies

### Core Strategy: Always Stay One Clip Ahead

The renderer must **always** complete their clip before the speaker finishes. This creates the illusion of zero lag.

### Clip Length Targets

```
Speaker Clips:  5-12 seconds (optimal: 8-10s)
Renderer Clips: 8-20 seconds (optimal: 10-15s)
Bridging Clips: 2-4 seconds (emergency filler)
```

**Why different lengths?**
- Speaker clips are shorter for faster turn-taking
- Renderer clips can be longer since they're generated in parallel
- Longer renderer clips give more buffer time

### Timing Calculation

```
Expected speaker clip duration: 8 seconds
Expected renderer generation time: 12 seconds

Timeline:
T=0s:  Speaker starts playing clip (8s)
       Renderer starts generating (12s)
T=8s:  Speaker finishes
       Renderer should be ready (ideally completed at T=7s)
T=8s:  Swap roles, new speaker starts immediately
```

### Bridging Clip Strategy

If the renderer is not ready when the speaker finishes:

```
┌─────────────────────────────────────┐
│   Bridging Clip Decision Tree        │
└─────────────────────────────────────┘

Speaker finishes (POST speech-ended)
  │
  ▼
Is renderer.status === "ready"?
  ├─ YES → Swap roles, play renderer clip
  └─ NO → Generate bridging clip
      │
      ├─► Enqueue urgent render job for current speaker
      ├─► Generate short filler clip (2-4 seconds)
      │   Examples:
      │   - "Let me scroll to the next part..."
      │   - "Okay, now watch this next section..."
      │   - "Give me a moment to find that..."
      ├─► Play bridging clip
      └─► Check renderer status again
          │
          ├─► If ready → Swap after bridging clip
          └─► If still not ready → Generate another bridging clip
```

### Adaptive Clip Length

The system can dynamically adjust clip length targets based on performance:

```
IF average_render_time > speaker_clip_duration:
  ├─► Reduce speaker clip target (5-8s instead of 8-12s)
  ├─► Increase renderer clip target (15-20s instead of 10-15s)
  └─► Log performance warning

IF average_render_time < speaker_clip_duration * 0.7:
  ├─► Increase speaker clip target (10-15s instead of 8-12s)
  └─► This allows more detailed explanations
```

---

## Failure Handling & Resilience

### Failure Mode Decision Tree

```
┌─────────────────────────────────────────────────────────────┐
│              Failure Handling Strategy                     │
└─────────────────────────────────────────────────────────────┘

1. Video Generation Fails
   │
   ├─► Retry: 2 attempts with exponential backoff
   ├─► IF still fails:
   │  ├─► Send CLIP_READY with status="audio_only"
   │  ├─► videoUrl = null or placeholder
   │  └─► UI shows avatar with idle animation + audio playback
   └─► Log error for monitoring

2. TTS Generation Fails
   │
   ├─► Retry: 2 attempts
   ├─► IF still fails:
   │  ├─► Send ERROR event
   │  ├─► Abort clip generation
   │  └─► Coordinator enqueues new render job
   └─► Log critical error

3. LLM Generation Fails
   │
   ├─► Retry: 1 attempt
   ├─► IF still fails:
   │  ├─► Use fallback template response
   │  │   "Let me continue with the next section..."
   │  └─► Continue pipeline with fallback text
   └─► Log warning

4. RAG Query Fails
   │
   ├─► Continue without RAG context
   ├─► Log warning
   └─► Teacher still generates response (may be less accurate)

5. Renderer Late (Not Ready When Speaker Finishes)
   │
   ├─► Generate bridging clip for current speaker
   ├─► Play bridging clip (2-4 seconds)
   ├─► Check renderer status again
   └─► IF still not ready → Generate another bridging clip

6. Session State Stale (Job Invalid)
   │
   ├─► Worker validates job before processing
   ├─► IF invalid:
   │  ├─► Discard job silently
   │  ├─► Return 200 OK (don't confuse UI)
   │  └─► Log debug message
   └─► Coordinator enqueues fresh job

7. Network Failure (Worker Can't POST CLIP_READY)
   │
   ├─► Retry: 3 attempts with exponential backoff
   ├─► IF still fails:
   │  ├─► Store clip locally (if possible)
   │  ├─► Log critical error
   │  └─► Coordinator will timeout and enqueue new job
   └─► Monitoring system alerts on repeated failures

8. Coordinator API Down
   │
   ├─► Workers queue jobs locally (if implemented)
   ├─► UI shows "Reconnecting..." message
   ├─► Retry connection with exponential backoff
   └─► Restore session state when reconnected
```

### Graceful Degradation Levels

```
Level 1: Full Experience
  ├─► Video + Audio + Captions
  └─► All features working

Level 2: Audio-Only Fallback
  ├─► Audio + Captions + Idle Animation
  └─► Video generation failed

Level 3: Text-Only Fallback
  ├─► Captions only
  └─► TTS failed (shouldn't happen, but possible)

Level 4: Bridging Mode
  ├─► Short filler clips
  └─► Renderer consistently late

Level 5: Error State
  ├─► Show error message
  ├─► Allow user to retry or skip
  └─► Log for debugging
```

---

## Implementation Checklist

### Phase 1: Core Infrastructure

- [ ] **Session State Schema**
  - [ ] Define session object structure
  - [ ] Implement state validation functions
  - [ ] Add state persistence (in-memory for now, DB later)

- [ ] **Coordinator API Endpoints**
  - [ ] `POST /session/start` - Create session, validate teachers
  - [ ] `GET /session/:id/state` - Get current session state
  - [ ] `POST /session/:id/section` - Update section snapshot
  - [ ] `POST /session/:id/speech-ended` - Notify clip finished
  - [ ] `POST /session/:id/clip-ready` - Worker posts completed clip
  - [ ] `GET /session/:id/events` - SSE event stream
  - [ ] `POST /rag/query` - RAG query endpoint

- [ ] **Event System**
  - [ ] Implement SSE server
  - [ ] Event emission functions
  - [ ] Event queue per session
  - [ ] Client connection management

### Phase 2: Frontend UI

- [ ] **Teacher Selection**
  - [ ] Multi-select component (exactly 2)
  - [ ] Validation (must select 2)
  - [ ] Teacher preview/description

- [ ] **Layout Components**
  - [ ] Left panel (Teacher A avatar)
  - [ ] Center panel (Website container)
  - [ ] Right panel (Teacher B avatar)
  - [ ] Bottom controls (captions, pause, speed, etc.)

- [ ] **Event Handling**
  - [ ] SSE client connection
  - [ ] Event listener/dispatcher
  - [ ] State management (session state, clip queues)
  - [ ] Auto-play logic (play speaker clip when ready)

- [ ] **Website Integration**
  - [ ] Iframe or embedded website
  - [ ] DOM extraction (visible text, selected text)
  - [ ] Scroll position tracking
  - [ ] Section change detection

- [ ] **Video/Audio Playback**
  - [ ] Video player component
  - [ ] Audio fallback (idle animation)
  - [ ] Caption display
  - [ ] Playback event handling (ended, error)

### Phase 3: n8n Workflows

- [ ] **SESSION_START Workflow**
  - [ ] Webhook trigger
  - [ ] Validate payload (2 teachers)
  - [ ] HTTP: Create session in Coordinator
  - [ ] HTTP: Enqueue first render job
  - [ ] Respond immediately (don't wait)

- [ ] **LEFT_WORKER Workflow**
  - [ ] Webhook trigger
  - [ ] HTTP: Get session state
  - [ ] IF: Validate job still valid
  - [ ] HTTP: Query RAG
  - [ ] Code: Prepare LLM prompt
  - [ ] HTTP: LLM Generate (Ollama)
  - [ ] Code: Extract & normalize response
  - [ ] HTTP: TTS Generate
  - [ ] HTTP: Video Generate (with retries)
  - [ ] Code: Format clip object
  - [ ] HTTP: POST CLIP_READY
  - [ ] Respond 200

- [ ] **RIGHT_WORKER Workflow**
  - [ ] Same as LEFT_WORKER (different route)

### Phase 4: Turn-Taking Engine

- [ ] **Swap Logic**
  - [ ] On speech-ended: validate renderer ready
  - [ ] Swap speaker/renderer
  - [ ] Update queue statuses
  - [ ] Emit SPEAKER_CHANGED event
  - [ ] Enqueue render job for new renderer

- [ ] **Bridging Clip Logic**
  - [ ] Detect renderer not ready
  - [ ] Generate short filler clip
  - [ ] Play bridging clip
  - [ ] Re-check renderer status

### Phase 5: RAG System

- [ ] **Knowledge Base Setup**
  - [ ] Chunking service
  - [ ] Embedding generation
  - [ ] Vector database (PostgreSQL + pgvector)
  - [ ] Index creation

- [ ] **RAG Query Service**
  - [ ] Query embedding generation
  - [ ] Vector similarity search
  - [ ] Result ranking and filtering
  - [ ] Context formatting for LLM

### Phase 6: Error Handling

- [ ] **Retry Logic**
  - [ ] Exponential backoff
  - [ ] Max retry limits
  - [ ] Retry on specific error types only

- [ ] **Fallback Mechanisms**
  - [ ] Audio-only fallback
  - [ ] Bridging clip generation
  - [ ] Error event emission

- [ ] **Monitoring**
  - [ ] Error logging
  - [ ] Performance metrics
  - [ ] Alerting on critical failures

---

## Tech Stack & Infrastructure

### Frontend
- **Framework**: Streamlit (Python) or React/Next.js
- **Video Playback**: HTML5 video element
- **Event Streaming**: Server-Sent Events (SSE) or WebSocket
- **DOM Extraction**: Browser APIs or headless browser

### Coordinator API
- **Framework**: FastAPI (Python) or Express.js (Node.js)
- **State Storage**: In-memory (development) → PostgreSQL (production)
- **Event Streaming**: SSE (simpler) or WebSocket (more features)
- **RAG Service**: FastAPI endpoint with pgvector

### Automation
- **Platform**: n8n
- **Workflows**: 3 workflows (SESSION_START, LEFT_WORKER, RIGHT_WORKER)
- **Triggers**: Webhooks
- **HTTP Client**: Built-in HTTP Request nodes

### AI Services
- **LLM**: Ollama (mistral:7b) or OpenAI API
- **TTS**: Piper TTS or Coqui TTS (multi-language)
- **Avatar Video**: LongCat-Video-Avatar (talking head generation)
- **Embeddings**: OpenAI text-embedding-3-small or local model

### RAG System
- **Vector Database**: PostgreSQL + pgvector extension
- **Embedding Model**: OpenAI or local (sentence-transformers)
- **Chunking**: Semantic chunking with overlap
- **Index**: HNSW index for fast similarity search

### Storage
- **Instance Storage**: 500GB (code, environments, temporary files)
- **Storage Volume**: 1TB at `/workspace` (videos, logs, cache, database)
- **Video Storage**: `/workspace/data/videos/`
- **Audio Storage**: `/workspace/data/audio/`
- **Cache**: `/workspace/data/cache/` (content-based caching)
- **Logs**: `/workspace/logs/` (organized by service)
- **Database**: `/workspace/data/postgresql/` (PostgreSQL data directory)

### Deployment
- **Hosting**: VAST.AI GPU instances
- **GPUs**: 2x A100 (80GB VRAM total recommended)
- **Services**: All services run directly on host (no Docker for simplicity)
- **Process Management**: tmux sessions
- **Port Forwarding**: SSH tunnels from desktop to VAST instance

---

## Future Roadmap

### Short-Term (Next 3 Months)
- [ ] **Persistent RAG Memory**
  - [ ] Store session transcripts in RAG
  - [ ] Teachers can reference previous conversations
  - [ ] Cross-session learning

- [ ] **Semantic Section Detection**
  - [ ] Auto-detect section boundaries
  - [ ] Smart section transitions
  - [ ] Context-aware section assignment

- [ ] **Adaptive Clip Length**
  - [ ] Dynamic adjustment based on performance
  - [ ] Content-aware length optimization
  - [ ] User preference settings

### Medium-Term (3-6 Months)
- [ ] **Student Profiles**
  - [ ] Track student progress
  - [ ] Personalized teaching style
  - [ ] Learning path recommendations

- [ ] **Teacher Specialization**
  - [ ] Domain-specific teachers (math, coding, etc.)
  - [ ] Teaching style preferences
  - [ ] Teacher personality customization

- [ ] **Observability Dashboard**
  - [ ] Real-time system metrics
  - [ ] Performance monitoring
  - [ ] Error tracking and alerts

### Long-Term (6+ Months)
- [ ] **Teaching Presets**
  - [ ] Pre-configured teacher pairs
  - [ ] Lesson templates
  - [ ] Teaching mode presets (beginner, advanced, etc.)

- [ ] **Citation Mode**
  - [ ] Teachers cite sources from RAG
  - [ ] Show references on screen
  - [ ] Link to original content

- [ ] **Multi-Language Support**
  - [ ] Automatic language detection
  - [ ] Teacher language preferences
  - [ ] Real-time translation

- [ ] **Advanced RAG Features**
  - [ ] Multi-modal RAG (images, code, diagrams)
  - [ ] Temporal RAG (time-aware context)
  - [ ] Hierarchical RAG (lesson → section → concept)

---

## Project Philosophy

### Core Principles

1. **Never Block**
   - All operations are asynchronous
   - No waiting on other pipelines
   - Immediate responses to user actions

2. **Hide Latency**
   - Renderer always stays one clip ahead
   - Bridging clips mask any delays
   - Smooth transitions between teachers

3. **State-Driven**
   - Single source of truth (Coordinator)
   - Events communicate changes
   - No data merging or synchronization

4. **Resilient**
   - Graceful degradation at every layer
   - Multiple fallback mechanisms
   - Error recovery without user intervention

5. **Scalable**
   - Independent pipelines enable concurrency
   - Stateless workers (except session context)
   - Horizontal scaling possible

### Vision

This is not just avatars. This is a **distributed AI classroom** with:
- **Co-teaching**: Two teachers working together seamlessly
- **Memory**: RAG provides persistent knowledge
- **Grounding**: Teachers reference real content
- **Human Flow**: Natural turn-taking and handoffs

A system that **feels alive**.

---

## Appendix: Quick Reference

### Session State Schema
See [Session State Machine](#session-state-machine) section.

### Event Types
See [Event-Driven Communication](#event-driven-communication) section.

### API Endpoints
- `POST /session/start` - Create session
- `GET /session/:id/state` - Get session state
- `POST /session/:id/section` - Update section
- `POST /session/:id/speech-ended` - Notify clip finished
- `POST /session/:id/clip-ready` - Worker posts clip
- `GET /session/:id/events` - SSE event stream
- `POST /rag/query` - Query RAG system

### n8n Workflow Routes
- `/webhook/session/start` - SESSION_START workflow
- `/webhook/worker/left/run` - LEFT_WORKER workflow
- `/webhook/worker/right/run` - RIGHT_WORKER workflow

### Storage Paths
- Videos: `/workspace/data/videos/`
- Audio: `/workspace/data/audio/`
- Cache: `/workspace/data/cache/`
- Logs: `/workspace/logs/{service}/`
- Database: `/workspace/data/postgresql/`

---

**Document Version**: 2.0  
**Last Updated**: 2026-01-25  
**Status**: Active Development
