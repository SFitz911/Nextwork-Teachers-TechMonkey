# n8n Workflows

This directory contains n8n workflow definitions for the AI Virtual Classroom system.

## Main Workflow: dual-teacher-workflow.json

The primary workflow that orchestrates the dual-teacher system.

### Workflow Steps:

1. **Webhook Trigger**: Receives chat messages from the frontend
2. **State Management**: Determines which teacher is currently speaking vs thinking
3. **LLM Node**: Generates response using Ollama/vLLM
4. **Teacher Selection**: Alternates between Teacher A and B
5. **TTS Node**: Converts text to speech
6. **Animation Node**: Generates lip-synced video
7. **Response Node**: Sends video back to frontend
8. **Parallel Processing**: While one teacher speaks, the other generates next response

### Import Instructions:

1. Open n8n at http://localhost:5678
2. Go to Workflows → Import from File
3. Select `dual-teacher-workflow.json`
4. Configure the following:
   - Webhook URL
   - Ollama API endpoint
   - TTS service endpoint
   - Animation service endpoint
   - Redis connection (for state management)

## State Management

The workflow uses Redis to track:
- `current_speaker`: "teacher_a" or "teacher_b"
- `thinking_teacher`: Which teacher is generating the next response
- `chat_history`: Recent conversation context

## Custom Nodes

You may need to create custom n8n nodes for:
- Streaming LLM responses
- Video chunk streaming
- WebSocket communication with frontend

## Workflow Variables

- `TEACHER_A_NAME`: Name of Teacher A (default: "Dr. Smith")
- `TEACHER_B_NAME`: Name of Teacher B (default: "Dr. Johnson")
- `LLM_TEMPERATURE`: LLM temperature (default: 0.7)
- `MAX_RESPONSE_LENGTH`: Maximum response length (default: 150 words)
