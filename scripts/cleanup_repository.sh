#!/usr/bin/env bash
# Repository Cleanup Script
# This organizes and removes redundant/unnecessary files
# Usage: bash scripts/cleanup_repository.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Repository Cleanup"
echo "=========================================="
echo ""

# Create archive directory for old files
ARCHIVE_DIR="archive/old_files_$(date +%Y%m%d)"
mkdir -p "$ARCHIVE_DIR"

echo "Files will be moved to: $ARCHIVE_DIR"
echo ""

# Files to archive (redundant/test scripts)
REDUNDANT_FILES=(
    # Redundant connection scripts (keep only the main ones)
    "test-connection-simple.ps1"
    "test-connection.ps1"
    "test-ssh-connection.ps1"
    "test-vast-connection.ps1"
    "check-vast-ssh.ps1"
    "diagnose-vast-connection.ps1"
    "find-vast-connection.ps1"
    "quick-connect.ps1"
    
    # Redundant upload scripts
    "upload-teacher-images.ps1"
    "upload-teachers.ps1"
    
    # Old/outdated documentation
    "AUDIT_REPORT.md"
    "STABILIZATION_COMPLETE.md"
    "STABILIZATION_FINAL.md"
    "STABILIZATION_PLAN.md"
    "IMPLEMENTATION_PLAN.md"
    "GITHUB_WORKFLOW.md"
    
    # Convert script (one-time use)
    "convert-krishna-to-png.ps1"
    
    # Verify script (redundant with force_reimport_workflows.sh)
    "verify-and-activate.ps1"
)

echo "Archiving redundant files..."
for file in "${REDUNDANT_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  Moving $file to archive..."
        mv "$file" "$ARCHIVE_DIR/" 2>/dev/null || echo "    ⚠️  Could not move $file"
    fi
done

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Archived files are in: $ARCHIVE_DIR"
echo "You can review them and delete if not needed."
echo ""
