# Troubleshooting Docker on Vast.ai

If Docker won't start, try these solutions:

## Check Docker Status
```bash
# Check if Docker daemon is running
ps aux | grep dockerd

# Check Docker socket
ls -la /var/run/docker.sock
```

## Solution 1: Start Docker with explicit socket
```bash
# Kill any existing dockerd processes
pkill dockerd

# Start Docker daemon with explicit socket path
dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2376 > /tmp/dockerd.log 2>&1 &

# Wait a few seconds
sleep 5

# Test
docker ps
```

## Solution 2: Use Docker rootless mode
```bash
# Install rootless Docker
dockerd-rootless-setuptool.sh install

# Start rootless Docker
dockerd-rootless-setuptool.sh start
```

## Solution 3: Check if Docker is already running via Vast.ai
Some Vast.ai instances have Docker pre-installed and running. Check:
```bash
# Try docker info
docker info

# If that works, Docker is already running!
```

## Solution 4: Use Vast.ai's Docker setup
Some instances have Docker configured differently. Check:
```bash
# Check for Docker in PATH
which docker

# Check Docker version
docker --version

# Try running a simple container
docker run hello-world
```
