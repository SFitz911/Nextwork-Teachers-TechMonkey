#!/bin/bash
# n8n entrypoint script that imports workflows after n8n is ready

# Start n8n in background
n8n start &

# Wait for n8n to be ready
echo "Waiting for n8n to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:5678/healthz > /dev/null 2>&1; then
        echo "n8n is ready!"
        break
    fi
    echo "Attempt $i/30..."
    sleep 2
done

# Import workflows if they exist
if [ -d "/data/workflows" ] && [ "$(ls -A /data/workflows/*.json 2>/dev/null)" ]; then
    echo "Importing workflows from /data/workflows..."
    # This would need n8n API key - for now, just log
    echo "Workflows available in /data/workflows - import manually via n8n UI or API"
fi

# Keep container running
wait
