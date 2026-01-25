# Repository Cleanup Plan

## 📋 Current Status

The repository has accumulated many files over time. This document outlines what's essential vs what can be cleaned up.

## ✅ Essential Files (Keep)

### Core Application
- `frontend/` - Streamlit frontend
- `services/` - All service APIs (coordinator, tts, animation, longcat_video)
- `n8n/workflows/` - n8n workflow definitions
- `configs/` - Configuration files
- `LongCat-Video/` - Video generation library
- `Nextwork-Teachers/` - Teacher avatar images
- `scripts/` - Deployment and utility scripts

### Essential Scripts (Root)
- `connect-vast-simple.ps1` - Main port forwarding script
- `connect-vast-terminal.ps1` - Terminal connection script
- `connect-vast.ps1` - Full port forwarding with options
- `add-ssh-key.ps1` - SSH key setup helper
- `sync-to-vast.ps1` - Code sync script
- `docker-compose.yml` - Docker configuration (if using Docker)

### Essential Documentation
- `README.md` - Main project README
- `README-01_relaunch_project.md` - **NEW** - Relaunch guide
- `README-02_shutdown_and_restart.md` - Shutdown/restart guide
- `README-01.1-Master Plan.md` - Master plan document
- `ENV_EXAMPLE.md` - Environment variable template
- `LICENSE` - License file

### Essential Scripts (scripts/)
- `deploy_no_docker.sh` - Main deployment script
- `deploy_longcat_video.sh` - LongCat-Video setup
- `quick_start_all.sh` - Start all services
- `restart_after_shutdown.sh` - Restart after instance restart
- `force_reimport_workflows.sh` - Re-import n8n workflows
- `check_all_services_status.sh` - Service status check
- `install_prerequisites.sh` - Install Ollama, n8n
- `fix_avatar_images.sh` - Setup avatar images

## 🗑️ Files to Archive/Remove

### Redundant Connection Scripts
- `test-connection-simple.ps1` - Redundant (use connect-vast-simple.ps1)
- `test-connection.ps1` - Redundant
- `test-ssh-connection.ps1` - Redundant
- `test-vast-connection.ps1` - Redundant
- `check-vast-ssh.ps1` - Redundant
- `diagnose-vast-connection.ps1` - Redundant
- `find-vast-connection.ps1` - Redundant
- `quick-connect.ps1` - Redundant
- `connect-vast.sh` - Redundant (use .ps1 versions)

### Redundant Upload Scripts
- `upload-teacher-images.ps1` - One-time use, can archive
- `upload-teachers.ps1` - One-time use, can archive

### Outdated Documentation
- `AUDIT_REPORT.md` - Historical, can archive
- `STABILIZATION_COMPLETE.md` - Historical, can archive
- `STABILIZATION_FINAL.md` - Historical, can archive
- `STABILIZATION_PLAN.md` - Historical, can archive
- `IMPLEMENTATION_PLAN.md` - Historical, can archive
- `GITHUB_WORKFLOW.md` - Historical, can archive
- `README-Commands-ADDITIONS.md` - Can consolidate into main README
- `README-Commands.md` - Can consolidate into main README
- `README-AI.md` - Can consolidate into main README

### One-Time Use Scripts
- `convert-krishna-to-png.ps1` - Already converted, can archive
- `verify-and-activate.ps1` - Redundant (use force_reimport_workflows.sh)

### Auto-Start Scripts (Optional)
- `auto-start-port-forwarding.ps1` - Optional, can keep or archive
- `setup-startup-port-forwarding.ps1` - Optional, can keep or archive

## 📁 Recommended Structure

```
Nextwork-Teachers-TechMonkey/
├── README.md                          # Main README
├── README-01_relaunch_project.md      # Relaunch guide
├── README-02_shutdown_and_restart.md  # Shutdown/restart guide
├── README-01.1-Master Plan.md         # Master plan
├── ENV_EXAMPLE.md                      # Environment template
├── LICENSE                             # License
├── docker-compose.yml                  # Docker config
├── requirements.txt                    # Python requirements
│
├── frontend/                           # Frontend app
├── services/                           # Service APIs
├── n8n/                                # n8n workflows
├── configs/                            # Config files
├── scripts/                            # Deployment scripts
├── LongCat-Video/                      # Video library
├── Nextwork-Teachers/                  # Teacher images
│
├── connect-vast-simple.ps1            # Main connection scripts
├── connect-vast-terminal.ps1
├── connect-vast.ps1
├── add-ssh-key.ps1
├── sync-to-vast.ps1
│
├── docs/                               # Additional documentation
└── archive/                            # Archived old files
```

## 🚀 Cleanup Steps

1. **Review and archive redundant files:**
   ```bash
   bash scripts/cleanup_repository.sh
   ```

2. **Manually review archived files:**
   - Check `archive/old_files_YYYYMMDD/`
   - Delete if confident they're not needed
   - Keep for a few weeks as backup

3. **Consolidate documentation:**
   - Merge README-Commands.md into main README.md
   - Keep only essential guides in root
   - Move detailed docs to `docs/` folder

4. **Update .gitignore:**
   - Ensure `archive/` is ignored (or commit if keeping)
   - Ensure `logs/` and `outputs/` are ignored

## 📝 Missing Files to Add

- ✅ `README-01_relaunch_project.md` - Already created, needs to be on VAST instance
- Consider adding `.github/workflows/` for CI/CD (optional)

## ⚠️ Important Notes

- **Don't delete** anything from `scripts/` without checking if it's referenced
- **Don't delete** any service code or configuration files
- **Archive first**, delete later after confirming everything works
- **Keep** all n8n workflow files
- **Keep** all teacher images
