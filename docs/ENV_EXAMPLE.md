# Environment Configuration Example

Since `.env` files are typically gitignored, create a `.env` file manually by copying this template:

```bash
# Copy this to .env file
cp ENV_EXAMPLE.md .env
# Then edit .env and replace placeholder values
```

## Required Variables

```bash
# n8n Configuration
# Required: Get API key from n8n UI: Settings → API → Create API Key
N8N_USER=your_email@example.com
N8N_PASSWORD=your_password
N8N_API_KEY=your_api_key_here

# n8n URLs (usually don't need to change)
N8N_URL=http://localhost:5678
N8N_WEBHOOK_URL=http://localhost:5678/webhook/chat-webhook

# Service URLs (usually don't need to change)
TTS_API_URL=http://localhost:8001
ANIMATION_API_URL=http://localhost:8002

# Virtual Environment Path
VENV_DIR=$HOME/ai-teacher-venv

# Optional: n8n Host Configuration
# N8N_HOST=0.0.0.0
# N8N_PORT=5678
# N8N_PROTOCOL=http
```

## Setup Instructions

1. Create `.env` file in project root
2. Copy the variables above into `.env`
3. Replace placeholder values with your actual credentials
4. Get API key from n8n UI: http://localhost:5678 → Settings → API
5. Validate configuration: `bash scripts/validate_config.sh`
