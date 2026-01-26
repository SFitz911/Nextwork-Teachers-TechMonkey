# n8n Workflows Summary

This document lists all required n8n workflows for the AI Teacher Classroom system.

## Required Workflows

The system requires exactly **3 workflows** as specified in the Master Plan:

### 1. Session Start - Fast Webhook
- **File**: `session-start-workflow.json`
- **Webhook Path**: `/webhook/session/start`
- **Method**: POST
- **Purpose**: 
  - Validates teacher selection (exactly 2 teachers)
  - Creates session in Coordinator API
  - Enqueues first render job
  - Responds immediately (non-blocking)

### 2. Left Worker - Teacher Pipeline
- **File**: `left-worker-workflow.json`
- **Webhook Path**: `/webhook/worker/left/run`
- **Method**: POST
- **Purpose**:
  - Processes render jobs for the left teacher
  - Retrieves session state
  - Validates job is still valid
  - Generates LLM response
  - Converts to speech (TTS)
  - Generates video (LongCat-Video)
  - Posts clip-ready event to Coordinator

### 3. Right Worker - Teacher Pipeline
- **File**: `right-worker-workflow.json`
- **Webhook Path**: `/webhook/worker/right/run`
- **Method**: POST
- **Purpose**:
  - Processes render jobs for the right teacher
  - Same pipeline as Left Worker but for right teacher
  - Enables parallel processing (one teacher speaks while other prepares)

## Workflow Structure

Each worker workflow follows this pipeline:

1. **Webhook Trigger** - Receives job payload
2. **Extract Payload** - Parses sessionId, teacher, role, etc.
3. **Get Session State** - Validates job is still valid
4. **Validate Job** - Checks if teacher is still active
5. **Query RAG** (future) - Retrieves relevant context
6. **Prepare LLM Prompt** - Builds prompt with context
7. **Call Ollama** - Generates text response
8. **Extract Response** - Parses LLM output
9. **Call TTS** - Converts text to speech
10. **Call LongCat-Video** - Generates talking avatar video
11. **Post Clip Ready** - Notifies Coordinator API

## Import Instructions

To import these workflows into n8n:

```bash
# On VAST instance
cd ~/Nextwork-Teachers-TechMonkey
bash scripts/force_reimport_workflows.sh
```

Or manually:
1. Open n8n UI: http://localhost:5678
2. Go to Workflows → Import from File
3. Import each JSON file:
   - `session-start-workflow.json`
   - `left-worker-workflow.json`
   - `right-worker-workflow.json`
4. Activate all workflows

## Verification

To verify workflows are imported and active:

```bash
# Check workflows in n8n
bash scripts/check_n8n_executions.sh

# Or use the API directly
curl -H "X-N8N-API-KEY: $N8N_API_KEY" \
  http://localhost:5678/api/v1/workflows
```

## Expected Workflow Names

When imported, workflows should appear with these exact names:
- `Session Start - Fast Webhook`
- `Left Worker - Teacher Pipeline`
- `Right Worker - Teacher Pipeline`

## Webhook URLs

Once imported, workflows will be accessible at:
- `http://localhost:5678/webhook/session/start`
- `http://localhost:5678/webhook/worker/left/run`
- `http://localhost:5678/webhook/worker/right/run`

## Status

✅ All 3 workflows are present in the repository
✅ Webhook paths match Master Plan specification
✅ Workflow structure follows the 2-teacher architecture

---

**Last Updated**: 2026-01-25  
**Version**: 1.0
