# Docker Mount Permission Fix Attempts

## Current Issue
Docker fails with: `operation not permitted: failed to mount` - namespace/mount restrictions

## Attempt 1: VFS Storage Driver

```bash
# Stop Docker
pkill -9 dockerd

# Start with VFS (no overlayfs, avoids mount issues)
dockerd --host=unix:///var/run/docker.sock --iptables=false --bridge=none --storage-driver=vfs > /tmp/dockerd.log 2>&1 &

sleep 10
docker run hello-world
```

## Attempt 2: Check if we can enable namespaces

```bash
# Check current namespace limits
cat /proc/sys/user/max_user_namespaces

# Try to enable (might be read-only)
echo 15000 > /proc/sys/user/max_user_namespaces 2>&1
```

## Attempt 3: Run Docker with different mount options

```bash
# Try with different mount namespace
dockerd --host=unix:///var/run/docker.sock --iptables=false --bridge=none --userns-remap="" > /tmp/dockerd.log 2>&1 &
```

## If All Fail: Run Services Directly

If Docker won't work, we can run services directly without containers (more manual setup required).
