# No-Docker Deployment (Vast.ai / restricted hosts)

Use this when Docker can’t run on the GPU host (errors like `unshare: operation not permitted` or mount/overlayfs failures).

## What you’ll run (no containers)

- `redis-server` (optional state store)
- `n8n` (installed via `npm`, runs on port `5678`)
- `services/tts` (FastAPI on port `8001`)
- `services/animation` (FastAPI on port `8002`)
- `frontend` (Streamlit on port `8501`)

## One-command setup (recommended)

From the GPU host:

```bash
cd ~/Nextwork-Teachers-TechMonkey
bash scripts/deploy_no_docker.sh
```

This installs OS packages + Node + n8n, creates a Python venv, installs Python deps, and starts everything in a `tmux` session.

## Start/Stop after install

```bash
# Start all services in tmux
bash scripts/run_no_docker_tmux.sh

# Attach to logs
tmux attach -t ai-teacher

# Stop the tmux session (stops all services started inside it)
tmux kill-session -t ai-teacher
```

## Ports

- n8n: `5678`
- Streamlit UI: `8501`
- TTS API: `8001`
- Animation API: `8002`

If you can’t access ports publicly, use SSH port-forwarding from your desktop:

```bash
ssh -p YOUR_PORT root@YOUR_HOST \
  -L 5678:localhost:5678 \
  -L 8501:localhost:8501 \
  -L 8001:localhost:8001 \
  -L 8002:localhost:8002
```

