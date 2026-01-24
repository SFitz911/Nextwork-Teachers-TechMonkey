#!/bin/bash
# Troubleshoot Docker daemon startup issues

set -euo pipefail

echo "=========================================="
echo "Docker Troubleshooting"
echo "=========================================="
echo ""

# Check if dockerd exists
echo "1. Checking if dockerd exists..."
if command -v dockerd &> /dev/null; then
    echo "✅ dockerd found: $(which dockerd)"
else
    echo "❌ dockerd not found"
    echo "   Docker may not be properly installed"
    exit 1
fi

# Check Docker socket
echo ""
echo "2. Checking Docker socket..."
if [ -S /var/run/docker.sock ]; then
    echo "✅ Docker socket exists"
    ls -la /var/run/docker.sock
else
    echo "⚠️  Docker socket doesn't exist (will be created when daemon starts)"
fi

# Check if Docker is already running
echo ""
echo "3. Checking if Docker is already running..."
if docker info > /dev/null 2>&1; then
    echo "✅ Docker daemon is already running!"
    docker info | head -5
    exit 0
else
    echo "❌ Docker daemon is not running"
fi

# Check logs
echo ""
echo "4. Checking Docker logs..."
if [ -f /tmp/dockerd.log ]; then
    echo "Last 20 lines of dockerd.log:"
    tail -20 /tmp/dockerd.log
else
    echo "No log file found yet"
fi

# Try to start Docker
echo ""
echo "5. Attempting to start Docker daemon..."
echo ""

# Kill any existing dockerd processes
pkill -f dockerd 2>/dev/null || true
sleep 2

# Try starting with different methods
echo "Method 1: Starting dockerd in background..."
dockerd > /tmp/dockerd.log 2>&1 &
DOCKERD_PID=$!
sleep 5

if docker info > /dev/null 2>&1; then
    echo "✅ Docker daemon started successfully (PID: $DOCKERD_PID)"
    docker info | head -5
    exit 0
fi

echo "Method 1 failed, trying Method 2..."
pkill -f dockerd 2>/dev/null || true
sleep 2

echo "Method 2: Starting dockerd with nohup..."
nohup dockerd > /tmp/dockerd.log 2>&1 &
sleep 5

if docker info > /dev/null 2>&1; then
    echo "✅ Docker daemon started successfully"
    docker info | head -5
    exit 0
fi

echo "Method 2 failed, checking logs..."
echo ""
echo "Docker daemon log:"
cat /tmp/dockerd.log

echo ""
echo "=========================================="
echo "❌ Could not start Docker daemon"
echo "=========================================="
echo ""
echo "Common issues:"
echo "1. Docker may need to be installed: curl -fsSL https://get.docker.com | sh"
echo "2. Check if there are permission issues"
echo "3. Try: sudo dockerd (if available)"
echo "4. Check system logs: journalctl -u docker 2>/dev/null || dmesg | tail -20"
echo ""
