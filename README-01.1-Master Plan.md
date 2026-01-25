## TL;DR

You’re building a **2-teacher “live classroom”** system where **Teacher A is speaking on-camera** while **Teacher B is silently preparing the next on-camera clip** (LLM → TTS → avatar video). You should implement this as **two independent pipelines** coordinated by a tiny **session state machine** (no merge nodes, no waiting on the webhook). The UI shows **Left Avatar + Center Website + Right Avatar**, and plays whichever teacher is currently “speaking,” while the other is “rendering.”

Also—quick heads up since you’re on your desktop: if you still want to set up the **AI agent rules/triggers** workflow (the “advanced agent” setup), this is a perfect project to wire those in.

---

# 1) The End Goal (what “done” looks like)

**User UI**

* Left panel: Teacher A avatar (video)
* Center panel: Website / learning project view (scrollable, highlightable)
* Right panel: Teacher B avatar (video)
* Bottom: captions + controls (pause, next section, swap teachers, change pair, speed)

**Behavior**

* Exactly **two teachers active** per session (user selects which two)
* Teachers **alternate turns** continuously:

  * While Teacher A is **speaking** (video playing),
  * Teacher B is **rendering** the next response/video in the background.
* When A finishes speaking, UI immediately switches to B (already rendered), and A starts rendering next.

This hides lag and feels “alive.”

---

# 2) Core Architecture (no blocking, no merging)

### Key rule

**Never try to synchronize by merging data.**
Synchronize by **state + events**.

### Three moving parts

1. **Frontend UI** (plays clips, shows website, sends “section/snapshot” inputs)
2. **Coordinator API** (tiny backend that stores session state and routes jobs)
3. **n8n Worker(s)** (two pipelines that generate teacher clips and post results back)

---

# 3) System Diagram (high-level)

```text
┌──────────────────────────────┐
│           Frontend           │
│  (Website + 2 Avatars + UI)  │
└──────────────┬───────────────┘
               │ start session, send snapshots, receive events
               ▼
┌──────────────────────────────┐
│        Coordinator API        │
│  session state + job routing  │
│  SSE/WebSocket event stream   │
└───────┬───────────────┬──────┘
        │ enqueue job A  │ enqueue job B
        ▼                ▼
┌──────────────┐   ┌──────────────┐
│ n8n Pipeline  │   │ n8n Pipeline  │
│ Teacher Left  │   │ Teacher Right │
│ LLM→TTS→Video  │   │ LLM→TTS→Video │
└───────┬───────┘   └───────┬───────┘
        │ POST clip-ready        │ POST clip-ready
        └──────────────┬─────────┘
                       ▼
              ┌──────────────────┐
              │ Coordinator API   │
              │ emits UI events   │
              └──────────────────┘
```

---

# 4) Session State Machine (the “synchronization” you actually need)

You only need a few state fields:

### Session object (authoritative)

```json
{
  "sessionId": "abc123",
  "activeTeachers": ["teacher_a", "teacher_d"],
  "leftTeacher": "teacher_a",
  "rightTeacher": "teacher_d",

  "turn": 0,
  "speaker": "teacher_a",
  "renderer": "teacher_d",

  "currentSectionId": "sec-05",
  "currentSnapshot": {
    "url": "https://yourproject.com/lesson/...",
    "scrollY": 1280,
    "selectedText": "…",
    "domDigest": "sha256:…"
  },

  "queues": {
    "teacher_a": { "status": "idle", "nextClipId": null },
    "teacher_d": { "status": "rendering", "nextClipId": "clip-991" }
  }
}
```

### Allowed teacher statuses

* `idle`
* `rendering`
* `ready` (clip finished, ready to play)
* `speaking` (currently playing on UI)
* `error` (failed clip)

### Turn-taking rule (always true)

* Exactly one teacher is **speaker**
* The other teacher is **renderer**
* When speaker finishes, you **swap roles**

---

# 5) UI Event Contract (how the UI stays live)

You need an event stream from Coordinator → Frontend:

* **SSE** (simplest) or **WebSocket**

### Event types

1. `SESSION_STARTED`
2. `CLIP_READY`
3. `SPEAKER_CHANGED`
4. `SECTION_UPDATED`
5. `ERROR`

### Example events

**SESSION_STARTED**

```json
{
  "type": "SESSION_STARTED",
  "sessionId": "abc123",
  "leftTeacher": "teacher_a",
  "rightTeacher": "teacher_d",
  "speaker": "teacher_a",
  "renderer": "teacher_d"
}
```

**CLIP_READY**

```json
{
  "type": "CLIP_READY",
  "sessionId": "abc123",
  "teacher": "teacher_d",
  "clip": {
    "clipId": "clip-991",
    "text": "Alright, now look at the function on line 42…",
    "audioUrl": "https://cdn/.../clip-991.mp3",
    "videoUrl": "https://cdn/.../clip-991.mp4",
    "durationMs": 8200,
    "captionsUrl": "https://cdn/.../clip-991.vtt",
    "sectionId": "sec-05"
  }
}
```

**SPEAKER_CHANGED**

```json
{
  "type": "SPEAKER_CHANGED",
  "sessionId": "abc123",
  "speaker": "teacher_d",
  "renderer": "teacher_a",
  "turn": 1
}
```

---

# 6) How “Website Reading” Works (the part that makes it feel real)

You have 3 practical options. Pick one now, you can upgrade later.

## Option A (fastest): “UI snapshot packet”

The UI sends the teachers:

* URL
* scroll position
* selected text
* visible text dump (center column)
* optional screenshot (base64) if you want

**Pros:** easy, works everywhere
**Cons:** limited “vision” unless you send screenshot

Payload example from UI → Coordinator:

```json
{
  "sessionId": "abc123",
  "sectionId": "sec-05",
  "url": "https://yourproject.com/lesson/5",
  "scrollY": 1280,
  "visibleText": "Step 5: Build the API route...\n\nWe will create...",
  "selectedText": "server-side validation",
  "userQuestion": "Why do we validate on the server?"
}
```

## Option B (better): DOM extraction in browser

UI sends a structured DOM excerpt:

* headings
* code blocks
* current element under cursor
* “active section boundaries”

**Pros:** best reasoning fidelity
**Cons:** a bit more frontend work

## Option C (advanced): live browser agent

Teacher pipeline controls a headless browser to “look”
**Pros:** maximum realism
**Cons:** highest complexity + latency

For your current build, **Option A or B** is perfect.

---

# 7) The Two n8n Pipelines (full pipelines, independently running)

You want **two separate pipelines**, not 5.

* Pipeline “LEFT_WORKER”
* Pipeline “RIGHT_WORKER”

Each is the *same template* but with `workerSide = left/right`.

### Why two pipelines are good

* True concurrency: both can render at once
* Clear isolation: each teacher pipeline can have its own retries/timeouts
* UI mapping stays stable: left avatar always fed by left worker (even if teacher identity changes)

---

## 7.1 n8n Workflow: `SESSION_START` (fast webhook)

**Goal:** validate teacher pair, create session, kick off first render job, respond immediately.

**Nodes**

1. Webhook Trigger: `/session/start`
2. Function/Code: validate payload (`selectedTeachers.length === 2`)
3. HTTP Request / DB: create session in Coordinator store
4. HTTP Request: enqueue first render for `renderer`
5. Respond to Webhook: return `{sessionId}` immediately (do NOT wait)

**Webhook response**

```json
{ "sessionId": "abc123", "status": "ok" }
```

---

## 7.2 n8n Workflow: `LEFT_WORKER` (complete teacher pipeline)

**Trigger:** Webhook `/worker/left/run` or Queue trigger.

**Input payload**

```json
{
  "sessionId": "abc123",
  "teacher": "teacher_a",
  "role": "speaker|renderer",
  "sectionPayload": { ...UI snapshot packet... },
  "turn": 0
}
```

**Nodes (in order)**

1. Webhook Trigger (or Queue)
2. HTTP Request: fetch session state (Coordinator)
3. IF: confirm `teacher` is still active + role still valid (avoid stale work)
4. LLM Generate (Teacher persona prompt + sectionPayload)
5. Extract Response (text normalization + safety filters + length target)
6. TTS Generate (voice per teacher)
7. Avatar Video Generate (your talking-head model)
8. Upload/Store assets (S3/CDN/local path)
9. HTTP Request: POST `CLIP_READY` to Coordinator
10. (Optional) If `role === renderer`: Coordinator may immediately mark it “ready”
11. Respond (200 ok)

**Important settings**

* Timeouts high on video node
* Retries on video node (2 max)
* On failure: send ERROR event with fallback text/audio-only

---

## 7.3 n8n Workflow: `RIGHT_WORKER`

Same as left worker, just different route: `/worker/right/run`

---

# 8) The Coordinator “Turn Engine” (the brain that swaps roles)

This is the logic that keeps the show moving.

### Coordinator responsibilities

* Store session state
* Accept UI “section updates”
* Enqueue jobs for renderer
* Decide who speaks next
* Emit events to UI

### Turn loop (activity diagram)

```text
[UI updates section] ──► Coordinator stores snapshot
                          │
                          ▼
                 Enqueue render job for renderer
                          │
                          ▼
        n8n worker renders clip and POSTS CLIP_READY
                          │
                          ▼
           UI plays current speaker clip (already ready)
                          │
                          ▼
      When speaker clip ends ─► UI notifies Coordinator: SPEECH_ENDED
                          │
                          ▼
       Coordinator swaps speaker/renderer and emits SPEAKER_CHANGED
                          │
                          ▼
            Coordinator enqueues next render for new renderer
```

### Key UI → Coordinator callback

When a clip finishes playing:
`POST /session/:id/speech-ended { clipId }`

That triggers swap.

---

# 9) How to Keep It Feeling Real (latency masking tactics)

### Hard rules

* Speaker clips should be **short and frequent** (5–12 seconds)
* Renderer can produce a slightly longer clip (8–20 seconds) but try not to exceed
* Always keep **one clip queued** for the next speaker before switching

### Practical cadence

* Teacher A speaks 8s (clip ready)
* Teacher B renders 10–15s while A speaks
* Switch to B only if B’s clip is ready
* If not ready: A does a “bridging line” (tiny filler clip: 2–4 seconds)

### Bridging line strategy (must have)

If rendering is late, speaker generates:

* “Let me scroll to the next part…”
* “Okay, now watch this next section…”

These are tiny clips you can generate quickly and keep the illusion alive.

---

# 10) Teacher Selection (exactly 2, user-chosen)

UI enforces:

* user selects two from five
* cannot start session without exactly two

Coordinator enforces again server-side:

* reject sessions with != 2 teachers

### Payload from UI on session start

```json
{
  "selectedTeachers": ["teacher_b", "teacher_e"],
  "lessonUrl": "https://yourproject.com/lesson/1"
}
```

Coordinator sets:

* leftTeacher = first selection
* rightTeacher = second selection
* speaker = leftTeacher (or random)
* renderer = other

---

# 11) Prompt Design (how teachers “read the website” like humans)

Each teacher prompt should include:

* Teacher identity + voice style
* The sectionPayload (visible text + selected text + url + scroll)
* A strict output format

**System prompt skeleton**

* “You are Teacher X”
* “You are co-teaching with Teacher Y”
* “Speak in short segments suited for 8–12 second spoken clips”
* “Reference what’s visible on screen”
* “Do not mention you are an AI”
* “Do not narrate internal steps”
* “End with a handoff cue for the other teacher”

**Output format (important)**

```json
{
  "spoken_text": "...",
  "on_screen_action": "highlight|scroll|point|none",
  "target_selector": "#code-block-3",
  "handoff": "ask_other_teacher|continue_self"
}
```

That lets UI do “point at code” effects.

---

# 12) Failure Modes (so it doesn’t fall apart live)

### If video render fails

* Send `ERROR` with fallback audio-only
* UI can show avatar “talking” with a looping idle animation + captions

### If renderer is late

* Speaker uses a bridging clip
* Coordinator can lower clip length target dynamically

### If session state gets stale

* Workers check “role still valid” before posting results
* If invalid: discard clip (don’t confuse UI)

---

# 13) What to Copy/Paste Into Cursor (implementation checklist)

Use this as your Cursor “task list”:

1. **Define session state schema** (as shown above)
2. Build Coordinator API endpoints:

   * `POST /session/start`
   * `POST /session/:id/section`
   * `POST /session/:id/speech-ended`
   * `POST /session/:id/clip-ready` (from n8n)
   * `GET /session/:id/events` (SSE) or WebSocket
3. UI:

   * Teacher pair selector (must choose 2)
   * Center website container + “visibleText extractor”
   * Event listener (SSE/WS)
   * Clip queue per teacher
   * Auto-play speaker clip, notify `speech-ended`
4. n8n:

   * `SESSION_START` workflow (fast ACK)
   * `LEFT_WORKER` full pipeline
   * `RIGHT_WORKER` full pipeline
5. Add bridging behavior:

   * If renderer clip not ready within X seconds → speaker generates filler
6. Add swapping logic in Coordinator:

   * On `speech-ended` → swap speaker/renderer and enqueue render for new renderer

---

# 14) Minimal n8n Node Layout (so you can rebuild fast)

### `LEFT_WORKER` / `RIGHT_WORKER` (identical)

* Webhook Trigger
* HTTP: Get Session State
* IF: Still active + role valid
* LLM Generate
* Code: Extract + clip-length trimming
* TTS Generate
* Avatar Video Generate
* HTTP: POST Clip Ready (Coordinator)
* Respond 200

**No merge nodes anywhere.**

---

If you paste this into Cursor, tell it:

* “Implement the Coordinator API (Express or Next.js API routes) using this exact event contract and session schema.”
* “Implement SSE events and the clip queue logic in the frontend.”

And if you want, I can also give you a **ready-to-paste Cursor prompt** that instructs Cursor *exactly* how to implement these endpoints + UI wiring in your existing project structure.





🧠 Nextwork Teachers TechMonkey — Dual Teacher Live Classroom (Master Plan v2 + RAG)
TL;DR (RAG Edition)

You’re building a 2-teacher live AI classroom where Teacher A is speaking on-camera while Teacher B silently prepares the next clip (RAG → LLM → TTS → Avatar Video).

They swap continuously.

Exactly two teachers are active per session.

Each teacher runs in a fully independent pipeline, coordinated by a tiny session state machine (no merge nodes, no blocking webhooks).

Teachers reason over:

Live UI snapshots (visible text, scroll position, selected text)

User questions

Retrieval-Augmented Generation (RAG) from your lesson knowledge base

Pipeline:

UI Snapshot → RAG Retrieval → LLM → TTS → Avatar Video

This hides latency and creates a continuous co-teaching experience.

1) End Goal

User Interface:

Left panel: Teacher A avatar (video)
Center panel: Website / lesson view
Right panel: Teacher B avatar (video)
Bottom: captions + controls

Behavior:

Exactly two teachers active

One speaks

One renders

Roles swap continuously

Renderer always stays one clip ahead

Feels alive.

2) Core Architecture

Never synchronize by merging.

Synchronize by state + events.

Three components:

Frontend UI

Coordinator API

Two n8n workers

3) System Diagram

Frontend
Avatars + Website + Controls
↓ snapshots + events

Coordinator API
session state + turn engine
SSE / WebSocket

enqueue left → LEFT_WORKER
enqueue right → RIGHT_WORKER

LEFT_WORKER: RAG → LLM → TTS → Avatar
RIGHT_WORKER: RAG → LLM → TTS → Avatar

Both POST CLIP_READY back to Coordinator
Coordinator emits UI events

4) Session State Machine

Authoritative session object:

sessionId
activeTeachers
speaker
renderer
turn
snapshot
queues

Teacher statuses:

idle
rendering
ready
speaking
error

Rules:

Exactly one speaker

Exactly one renderer

Swap roles on speech-ended

5) UI Event Contract

Events:

SESSION_STARTED
CLIP_READY
SPEAKER_CHANGED
SECTION_UPDATED
ERROR

UI subscribes via SSE or WebSocket.

6) Website Reading

Option A (fast):

UI sends:

url
scrollY
visibleText
selectedText
userQuestion

Option B:

Structured DOM blocks:

headings
code blocks
active section

7) RAG Integration

Before LLM generation, each worker calls:

POST /rag/query

Payload includes:

sessionId
visibleText
selectedText
userQuestion

Coordinator returns top K semantic matches.

These are injected directly into the teacher prompt.

8) RAG Architecture

Knowledge Sources
↓ chunk + embed
Vector Database (Chroma / Qdrant / Pinecone)
↑
Coordinator
↓
Workers

RAG provides:

Curriculum grounding

Cross-lesson recall

Reduced hallucination

Persistent knowledge

9) Worker Pipelines (LEFT + RIGHT)

Both pipelines are identical templates.

Steps:

Trigger

Fetch session state

Query RAG

Generate text (LLM)

Normalize output

Generate speech (TTS)

Render avatar video

Upload assets

POST CLIP_READY

Respond 200

No merge nodes anywhere.

10) Coordinator Turn Engine

Flow:

UI sends section update
Coordinator stores snapshot
Coordinator enqueues renderer
Worker renders clip
Worker posts CLIP_READY
UI plays current speaker
UI sends speech-ended
Coordinator swaps roles
Coordinator enqueues next render

Loop forever.

11) Latency Masking

Speaker clips: 5–12 seconds
Renderer clips: 8–20 seconds

If renderer is late:

Speaker generates a short bridging clip:

“Let’s scroll to the next part…”

Keeps illusion alive.

12) Teacher Selection

User must choose exactly two teachers.

Coordinator enforces this server-side.

Session rejected otherwise.

13) Prompt Design

Each prompt includes:

Teacher identity
Co-teacher identity
RAG context
Visible screen content
Selected text

Output schema:

spoken_text
on_screen_action
handoff

Teachers end every clip with a handoff cue.

14) Failure Modes

If avatar render fails:

Fallback to audio + idle animation.

If renderer late:

Speaker bridges.

If job stale:

Discard result.

15) Cursor Implementation Checklist

Define session schema
Build Coordinator API endpoints
Implement SSE
Create UI clip queues
Build LEFT_WORKER
Build RIGHT_WORKER
Add RAG service
Implement swap logic
Add bridging behavior

16) Tech Stack

Frontend:

React / Next.js
SSE or WebSocket
Video + audio playback
DOM extraction

Coordinator:

Node.js
Session state machine
Turn engine

Automation:

n8n

AI:

LLM (OpenAI / Ollama / local)
TTS
Avatar renderer

RAG:

Chroma / Qdrant / Pinecone
Embeddings
Chunked lessons

Storage:

Vast.ai storage on cloud with instances (or whatever you think is best)
Video
Audio
Captions

17) Future Roadmap

Persistent RAG memory
Student profiles
Teacher specialization
Semantic section detection
Adaptive clip length
Observability dashboard
Teaching presets
Citation mode

18) Project Philosophy

Never block.
Hide latency.
Teachers behave like instructors — not chatbots.

19) Vision

Not avatars.

A distributed AI classroom with:

co-teaching
memory
grounding
human flow

A system that feels alive.