# Quick Start: New Vast.ai Instance with Storage Volume

This guide helps you set up a fresh Vast.ai instance with a storage volume.

## Prerequisites

1. ✅ **New Vast.ai instance** created and running
2. ✅ **Storage volume** created (200-500 GB recommended)
3. ✅ **Volume attached** to your instance (check Vast.ai dashboard)

## Step 1: Connect to Your Instance

**📍 Terminal: PowerShell Desktop**

Get your SSH connection details from Vast.ai dashboard, then:

```powershell
# Example (replace with your actual details)
ssh -p YOUR_PORT root@ssh1.vast.ai
```

Or use the connection script:
```powershell
.\connect-vast.ps1
```

## Step 2: Run the Setup Script

**📍 Terminal: Vast.ai Instance (SSH terminal)**

Once connected to your instance:

```bash
# Clone the project first
cd ~
git clone https://github.com/SFitz911/Nextwork-Teachers-TechMonkey.git
cd Nextwork-Teachers-TechMonkey

# Make script executable
chmod +x scripts/setup_new_instance_with_storage.sh

# Run the setup script
bash scripts/setup_new_instance_with_storage.sh
```

**What this does:**
- ✅ Detects your Vast.ai storage volume
- ✅ Sets up directories on the volume
- ✅ Installs Ollama, n8n, Node.js, PostgreSQL
- ✅ Pulls Mistral:7b model (~5-10 minutes)
- ✅ Creates Python virtual environment
- ✅ Installs all project dependencies
- ✅ Creates environment configuration file

**Time:** ~15-20 minutes (mostly waiting for model download)

## Step 3: Configure PostgreSQL

**📍 Terminal: Vast.ai Instance**

After setup completes, configure the database:

```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql << EOF
CREATE DATABASE ai_teacher;
CREATE USER ai_teacher WITH PASSWORD 'your_secure_password_here';
GRANT ALL PRIVILEGES ON DATABASE ai_teacher TO ai_teacher;
\q
EOF

# Install pgvector extension
sudo -u postgres psql -d ai_teacher -c "CREATE EXTENSION vector;"
```

**Note:** Replace `'your_secure_password_here'` with a strong password. Save it - you'll need it for the `.env` file.

## Step 4: Update Environment File

**📍 Terminal: Vast.ai Instance**

```bash
cd ~/Nextwork-Teachers-TechMonkey

# Copy the generated environment file
cp .env.storage .env

# Edit and update the PostgreSQL password
nano .env
# Update POSTGRES_PASSWORD with the password you created above
```

## Step 5: Deploy the System

**📍 Terminal: Vast.ai Instance**

```bash
cd ~/Nextwork-Teachers-TechMonkey

# Deploy everything
bash scripts/deploy_2teacher_system.sh
```

This will:
- ✅ Start all services (Ollama, n8n, Coordinator, TTS, Animation, Frontend)
- ✅ Import n8n workflows
- ✅ Verify everything is running

## Step 6: Set Up Port Forwarding

**📍 Terminal: PowerShell Desktop**

Keep this window open while using the system:

```powershell
.\connect-vast.ps1
```

Or manually:
```powershell
ssh -p YOUR_PORT root@ssh1.vast.ai -L 5678:localhost:5678 -L 8501:localhost:8501 -L 8001:localhost:8001 -L 8004:localhost:8004
```

## Step 7: Access the Frontend

**📍 Desktop Browser**

Open: **http://localhost:8501**

You should see the AI Teacher interface!

## Troubleshooting

### Storage Volume Not Detected

If the script can't find your volume:

1. Check Vast.ai dashboard - is volume attached?
2. Check mount point manually:
   ```bash
   df -h | grep -E "(vast|storage|volume)"
   mount | grep -E "(vast|storage|volume)"
   ```
3. If volume is attached but not mounted, mount it:
   ```bash
   # Find the device (check Vast.ai dashboard or lsblk)
   sudo mkdir -p /mnt/vast-storage
   sudo mount /dev/sdX1 /mnt/vast-storage  # Replace sdX1 with your device
   ```

### PostgreSQL Won't Start

```bash
# Check status
sudo systemctl status postgresql

# Check logs
sudo journalctl -u postgresql -n 50

# If data directory is wrong, you may need to reconfigure
sudo -u postgres /usr/lib/postgresql/*/bin/pg_ctl -D /path/to/data start
```

### Services Not Starting

```bash
# Check service status
bash scripts/check_all_services_status.sh

# View logs
tmux attach -t ai-teacher

# Check individual services
ps aux | grep ollama
ps aux | grep n8n
ps aux | grep streamlit
```

## Next Steps

- ✅ System is ready to use!
- ✅ All data persists on your Vast.ai storage volume
- ✅ Database, cache, and logs are on the volume
- ✅ Everything survives instance restarts

## Storage Locations

- **PostgreSQL Data**: `$VAST_STORAGE/postgresql/data`
- **Cached Videos**: `$VAST_STORAGE/cached_sections/`
- **Embeddings**: `$VAST_STORAGE/embeddings/`
- **Logs**: `$VAST_STORAGE/logs/`

Check your `.env` file for the exact `$VAST_STORAGE` path.
