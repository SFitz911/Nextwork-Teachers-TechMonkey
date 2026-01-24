#!/bin/bash
# Fix Docker iptables permission issue on Vast.ai instances

set -euo pipefail

echo "=========================================="
echo "Fixing Docker iptables Issue"
echo "=========================================="
echo ""

# Create Docker daemon configuration
DAEMON_JSON="/etc/docker/daemon.json"
mkdir -p /etc/docker

echo "Creating Docker daemon configuration..."
cat > "$DAEMON_JSON" << 'EOF'
{
  "iptables": false,
  "ip-forward": false,
  "bridge": "none"
}
EOF

echo "✅ Docker daemon configuration created"
echo ""
echo "Configuration:"
cat "$DAEMON_JSON"
echo ""

# Kill any existing dockerd
pkill -f dockerd 2>/dev/null || true
sleep 2

# Start Docker with the new configuration
echo "Starting Docker daemon with new configuration..."
dockerd > /tmp/dockerd.log 2>&1 &
DOCKERD_PID=$!
sleep 5

# Check if Docker is running
if docker info > /dev/null 2>&1; then
    echo "✅ Docker daemon started successfully (PID: $DOCKERD_PID)"
    docker info | head -10
else
    echo "❌ Docker daemon still not running"
    echo ""
    echo "Checking logs..."
    tail -20 /tmp/dockerd.log
    echo ""
    echo "Alternative: Try starting Docker with explicit config:"
    echo "  dockerd --iptables=false --ip-forward=false > /tmp/dockerd.log 2>&1 &"
fi
