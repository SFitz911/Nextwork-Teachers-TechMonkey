# Storage Architecture Optimization Guide

## Overview

This project uses the VAST.AI storage volume (1TB) for persistent, fast, and indexed storage of all application data.

## Storage Structure

```
/mnt/vast-storage/ (or /root/vast-storage/)
├── data/                    # All application data
│   ├── videos/             # Generated video files (indexed)
│   ├── audio/              # Generated audio files
│   ├── cache/              # Cached content (by hash)
│   ├── embeddings/         # Vector embeddings
│   ├── postgresql/         # PostgreSQL data directory
│   ├── n8n/                # n8n workflows and data
│   └── ollama/             # Ollama models (optional)
├── logs/                   # All application logs
│   ├── coordinator/        # Coordinator API logs
│   ├── longcat_video/      # LongCat-Video logs
│   ├── n8n/                # n8n logs
│   ├── frontend/           # Frontend logs
│   └── tts/                # TTS logs
├── indexes/                # Search indexes
│   ├── videos/             # Video metadata index
│   └── sessions/           # Session index
└── models/                 # Model files
    └── longcat/            # LongCat-Video models (symlink)
```

## Quick Setup

**📍 VAST Terminal:**

```bash
cd ~/Nextwork-Teachers-TechMonkey

# Run the optimization script
bash scripts/optimize_storage_architecture.sh
```

This script will:
1. ✅ Detect and mount the VAST.AI storage volume
2. ✅ Create optimized directory structure
3. ✅ Migrate existing data to storage volume
4. ✅ Create symlinks for backward compatibility
5. ✅ Update environment configuration
6. ✅ Set up indexing and log rotation

## Benefits

### 🚀 Fast Retrieval
- **Indexed video metadata**: Fast lookup by hash, session, or timestamp
- **Organized structure**: Logical directory layout for quick access
- **Symlinks**: Backward compatibility with existing code

### 📊 Indexing
- **Video index**: JSON index of all videos with metadata
- **Session index**: Fast session lookup
- **Automatic indexing**: Run `bash scripts/index_videos.sh` to index videos

### 📝 Logging
- **Centralized logs**: All logs in one place
- **Organized by service**: Easy to find specific service logs
- **Log rotation**: Automatic compression of old logs
- **Persistent**: Logs survive instance restarts

### 💾 Persistence
- **All data on volume**: Videos, audio, cache, embeddings, database
- **Survives restarts**: Data persists when instance stops/starts
- **Detachable**: Can detach and reattach volume to different instances

## Usage

### Index Videos

```bash
# Index all videos for fast retrieval
bash scripts/index_videos.sh
```

Creates `$VAST_STORAGE/indexes/videos/video_index.json` with:
- Video paths
- File sizes
- Modification dates
- Content hashes

### Check Storage Health

```bash
# Check storage volume health and usage
bash scripts/check_storage_health.sh
```

Shows:
- Storage volume status
- Directory usage
- File counts
- Available space

### Rotate Logs

```bash
# Compress and archive old logs
bash scripts/rotate_logs.sh
```

Automatically:
- Compresses logs older than 30 days
- Archives to `$VAST_STORAGE/logs/archive/`
- Removes original log files

### Set Up Automatic Log Rotation

Add to crontab:

```bash
# Edit crontab
crontab -e

# Add this line (runs daily at 2 AM)
0 2 * * * cd ~/Nextwork-Teachers-TechMonkey && bash scripts/rotate_logs.sh
```

## Environment Variables

The optimization script updates `.env` with:

```bash
VAST_STORAGE_PATH=/mnt/vast-storage
VIDEO_OUTPUT_DIR=$VAST_STORAGE/data/videos
AUDIO_OUTPUT_DIR=$VAST_STORAGE/data/audio
CACHE_DIR=$VAST_STORAGE/data/cache
EMBEDDINGS_DIR=$VAST_STORAGE/data/embeddings
LOGS_DIR=$VAST_STORAGE/logs
COORDINATOR_LOGS_DIR=$VAST_STORAGE/logs/coordinator
LONGCAT_LOGS_DIR=$VAST_STORAGE/logs/longcat_video
```

## Service Configuration

All services automatically use storage volume paths from `.env`:

- **LongCat-Video**: Outputs to `$VIDEO_OUTPUT_DIR`
- **Coordinator API**: Logs to `$COORDINATOR_LOGS_DIR`
- **TTS Service**: Can use `$AUDIO_OUTPUT_DIR`
- **Frontend**: Can access cached content from `$CACHE_DIR`

## Troubleshooting

### Storage Volume Not Detected

```bash
# Check all mounted filesystems
df -h | grep -E "(vast|storage|volume)"

# Check mount points
mount | grep -E "(vast|storage|volume)"

# Manually specify path in .env
echo "VAST_STORAGE_PATH=/your/custom/path" >> .env
```

### Services Not Using Storage

1. Check `.env` has correct paths:
   ```bash
   grep VAST_STORAGE .env
   ```

2. Restart services:
   ```bash
   bash scripts/quick_start_all.sh
   ```

3. Verify services are using storage:
   ```bash
   # Check if videos are being written to storage
   ls -lh $VAST_STORAGE/data/videos/
   
   # Check if logs are being written to storage
   ls -lh $VAST_STORAGE/logs/coordinator/
   ```

## Best Practices

1. **Regular Indexing**: Run `index_videos.sh` after generating many videos
2. **Log Rotation**: Set up cron job for automatic log rotation
3. **Health Checks**: Run `check_storage_health.sh` regularly
4. **Backup**: Consider backing up critical data from storage volume
5. **Monitoring**: Monitor storage usage to avoid filling up

## Next Steps

After running the optimization script:

1. ✅ Restart services:
   ```bash
   bash scripts/quick_start_all.sh
   ```

2. ✅ Index existing videos:
   ```bash
   bash scripts/index_videos.sh
   ```

3. ✅ Set up log rotation:
   ```bash
   crontab -e  # Add log rotation cron job
   ```

4. ✅ Verify everything works:
   ```bash
   bash scripts/check_storage_health.sh
   ```
