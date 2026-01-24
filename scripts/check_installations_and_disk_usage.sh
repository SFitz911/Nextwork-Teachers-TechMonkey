#!/bin/bash
# Check all installations and disk usage
# Usage: bash scripts/check_installations_and_disk_usage.sh

set -euo pipefail

echo "=========================================="
echo "Installation & Disk Usage Check"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check and show size
check_component() {
    local name=$1
    local path=$2
    local check_cmd=${3:-""}
    
    echo -n "Checking $name... "
    
    if [ -n "$check_cmd" ]; then
        if eval "$check_cmd" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ INSTALLED${NC}"
        else
            echo -e "${RED}❌ NOT INSTALLED${NC}"
            return 1
        fi
    elif [ -d "$path" ] || [ -f "$path" ]; then
        echo -e "${GREEN}✅ FOUND${NC}"
    else
        echo -e "${RED}❌ NOT FOUND${NC}"
        return 1
    fi
    
    # Show size if path exists
    if [ -e "$path" ]; then
        SIZE=$(du -sh "$path" 2>/dev/null | cut -f1 || echo "0")
        echo "   Location: $path"
        echo "   Size: ${GREEN}$SIZE${NC}"
        
        # Show file count for directories
        if [ -d "$path" ]; then
            FILE_COUNT=$(find "$path" -type f 2>/dev/null | wc -l)
            echo "   Files: $FILE_COUNT"
        fi
    fi
    echo ""
}

# 1. System Disk Usage
echo "=========================================="
echo "1. System Disk Usage"
echo "=========================================="
df -h / | tail -1 | awk '{print "Root filesystem: " $2 " total, " $3 " used, " $4 " available (" $5 " used)"}'
echo ""

# Check storage volume if exists
if [ -d "/root/vast-storage" ] || [ -d "/mnt/vast-storage" ]; then
    STORAGE_PATH=""
    for path in "/root/vast-storage" "/mnt/vast-storage" "/vast-storage"; do
        if [ -d "$path" ]; then
            STORAGE_PATH="$path"
            break
        fi
    done
    
    if [ -n "$STORAGE_PATH" ]; then
        echo "Storage Volume:"
        df -h "$STORAGE_PATH" | tail -1 | awk '{print "  " $2 " total, " $3 " used, " $4 " available (" $5 " used)"}'
        echo ""
    fi
fi

# 2. Ollama
echo "=========================================="
echo "2. Ollama (LLM Service)"
echo "=========================================="
check_component "Ollama" "$(which ollama 2>/dev/null || echo '')" "command -v ollama"

if command -v ollama &> /dev/null; then
    echo "   Version: $(ollama --version 2>/dev/null || echo 'unknown')"
    
    # Check Ollama models directory
    OLLAMA_DIR="${HOME}/.ollama"
    if [ -d "$OLLAMA_DIR" ]; then
        echo "   Models directory: $OLLAMA_DIR"
        OLLAMA_SIZE=$(du -sh "$OLLAMA_DIR" 2>/dev/null | cut -f1 || echo "0")
        echo "   Models size: ${GREEN}$OLLAMA_SIZE${NC}"
        
        # List installed models
        echo "   Installed models:"
        if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
            MODELS=$(curl -s http://localhost:11434/api/tags 2>/dev/null | python3 -c "import json, sys; d=json.load(sys.stdin); models=[m.get('name', 'unknown') for m in d.get('models', [])]; print('\\n'.join(models))" 2>/dev/null || echo "")
            if [ -n "$MODELS" ]; then
                echo "$MODELS" | sed 's/^/      - /'
            else
                echo "      ${YELLOW}(none)${NC}"
            fi
        else
            echo "      ${YELLOW}(Ollama not running - cannot check models)${NC}"
        fi
    fi
fi
echo ""

# 3. LongCat-Video
echo "=========================================="
echo "3. LongCat-Video"
echo "=========================================="
PROJECT_DIR="${PROJECT_DIR:-$HOME/Nextwork-Teachers-TechMonkey}"
LONGCAT_DIR="$PROJECT_DIR/LongCat-Video"

check_component "LongCat-Video" "$LONGCAT_DIR"

if [ -d "$LONGCAT_DIR" ]; then
    echo "   Checking subdirectories:"
    
    # Check weights/models
    if [ -d "$LONGCAT_DIR/weights" ]; then
        WEIGHTS_SIZE=$(du -sh "$LONGCAT_DIR/weights" 2>/dev/null | cut -f1 || echo "0")
        WEIGHTS_COUNT=$(find "$LONGCAT_DIR/weights" -type f 2>/dev/null | wc -l)
        echo "      weights/: ${GREEN}$WEIGHTS_SIZE${NC} ($WEIGHTS_COUNT files)"
    else
        echo "      weights/: ${YELLOW}⚠️  NOT FOUND${NC}"
    fi
    
    # Check assets
    if [ -d "$LONGCAT_DIR/assets" ]; then
        ASSETS_SIZE=$(du -sh "$LONGCAT_DIR/assets" 2>/dev/null | cut -f1 || echo "0")
        ASSETS_COUNT=$(find "$LONGCAT_DIR/assets" -type f 2>/dev/null | wc -l)
        echo "      assets/: ${GREEN}$ASSETS_SIZE${NC} ($ASSETS_COUNT files)"
    fi
fi
echo ""

# 4. Teacher Avatars
echo "=========================================="
echo "4. Teacher Avatars (Images)"
echo "=========================================="
AVATARS_DIR="$PROJECT_DIR/Nextwork-Teachers"

check_component "Teacher Avatars" "$AVATARS_DIR"

if [ -d "$AVATARS_DIR" ]; then
    echo "   Avatar files:"
    find "$AVATARS_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.PNG" -o -name "*.JPG" \) 2>/dev/null | while read -r file; do
        FILE_SIZE=$(du -h "$file" 2>/dev/null | cut -f1 || echo "0")
        FILE_NAME=$(basename "$file")
        echo "      - $FILE_NAME: $FILE_SIZE"
    done
    
    AVATAR_COUNT=$(find "$AVATARS_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.PNG" -o -name "*.JPG" \) 2>/dev/null | wc -l)
    if [ "$AVATAR_COUNT" -eq 0 ]; then
        echo "      ${YELLOW}⚠️  No avatar images found${NC}"
    fi
fi
echo ""

# 5. Python Environment
echo "=========================================="
echo "5. Python Environment"
echo "=========================================="
VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"

if [ -d "$VENV_DIR" ]; then
    echo -e "Virtual Environment: ${GREEN}✅ FOUND${NC}"
    VENV_SIZE=$(du -sh "$VENV_DIR" 2>/dev/null | cut -f1 || echo "0")
    echo "   Location: $VENV_DIR"
    echo "   Size: ${GREEN}$VENV_SIZE${NC}"
    
    # Check key packages
    if [ -f "$VENV_DIR/bin/activate" ]; then
        source "$VENV_DIR/bin/activate"
        echo "   Key packages:"
        for pkg in "torch" "transformers" "diffusers" "streamlit" "fastapi"; do
            if python3 -c "import $pkg" 2>/dev/null; then
                VERSION=$(python3 -c "import $pkg; print(getattr($pkg, '__version__', 'installed'))" 2>/dev/null || echo "installed")
                echo "      - $pkg: ${GREEN}✅${NC} ($VERSION)"
            else
                echo "      - $pkg: ${RED}❌${NC}"
            fi
        done
    fi
else
    echo -e "Virtual Environment: ${RED}❌ NOT FOUND${NC}"
fi
echo ""

# 6. Node.js and n8n
echo "=========================================="
echo "6. Node.js and n8n"
echo "=========================================="
if command -v node &> /dev/null; then
    echo -e "Node.js: ${GREEN}✅ INSTALLED${NC}"
    echo "   Version: $(node --version)"
    NODE_MODULES_SIZE=$(du -sh /usr/lib/node_modules 2>/dev/null | cut -f1 || echo "0")
    echo "   Global modules: $NODE_MODULES_SIZE"
else
    echo -e "Node.js: ${RED}❌ NOT INSTALLED${NC}"
fi

if command -v n8n &> /dev/null; then
    echo -e "n8n: ${GREEN}✅ INSTALLED${NC}"
    echo "   Version: $(n8n --version)"
    N8N_DIR="${HOME}/.n8n"
    if [ -d "$N8N_DIR" ]; then
        N8N_SIZE=$(du -sh "$N8N_DIR" 2>/dev/null | cut -f1 || echo "0")
        echo "   Data directory: $N8N_DIR"
        echo "   Size: ${GREEN}$N8N_SIZE${NC}"
    fi
else
    echo -e "n8n: ${RED}❌ NOT INSTALLED${NC}"
fi
echo ""

# 7. PostgreSQL
echo "=========================================="
echo "7. PostgreSQL"
echo "=========================================="
if command -v psql &> /dev/null; then
    echo -e "PostgreSQL: ${GREEN}✅ INSTALLED${NC}"
    echo "   Version: $(psql --version)"
    
    # Check data directory
    PG_DATA_DIRS=(
        "/root/vast-storage/postgresql/data"
        "/mnt/vast-storage/postgresql/data"
        "/var/lib/postgresql"
    )
    
    for dir in "${PG_DATA_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            PG_SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "0")
            echo "   Data directory: $dir"
            echo "   Size: ${GREEN}$PG_SIZE${NC}"
            break
        fi
    done
else
    echo -e "PostgreSQL: ${RED}❌ NOT INSTALLED${NC}"
fi
echo ""

# 8. Docker (if installed)
echo "=========================================="
echo "8. Docker"
echo "=========================================="
if command -v docker &> /dev/null; then
    echo -e "Docker: ${GREEN}✅ INSTALLED${NC}"
    echo "   Version: $(docker --version)"
    
    # Check Docker data
    DOCKER_DIRS=(
        "/root/docker-data"
        "/var/lib/docker"
    )
    
    for dir in "${DOCKER_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            DOCKER_SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "0")
            echo "   Data directory: $dir"
            echo "   Size: ${GREEN}$DOCKER_SIZE${NC}"
            break
        fi
    done
    
    # Check Docker images
    if docker info > /dev/null 2>&1; then
        IMAGE_SIZE=$(docker system df 2>/dev/null | grep "Images" | awk '{print $3}' || echo "0")
        echo "   Images: ${GREEN}$IMAGE_SIZE${NC}"
    fi
else
    echo -e "Docker: ${YELLOW}⚠️  NOT INSTALLED${NC} (not needed - using no-Docker setup)"
fi
echo ""

# 9. Output/Cache Directories
echo "=========================================="
echo "9. Output & Cache Directories"
echo "=========================================="

# Check for output directories
OUTPUT_DIRS=(
    "$PROJECT_DIR/outputs"
    "$PROJECT_DIR/outputs/longcat"
    "/root/vast-storage/cached_sections"
    "/root/vast-storage/embeddings"
)

for dir in "${OUTPUT_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        DIR_SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "0")
        FILE_COUNT=$(find "$dir" -type f 2>/dev/null | wc -l)
        echo "   $dir: ${GREEN}$DIR_SIZE${NC} ($FILE_COUNT files)"
    fi
done
echo ""

# 10. Total Summary
echo "=========================================="
echo "10. Total Disk Usage Summary"
echo "=========================================="
echo ""

# Calculate total for key directories
TOTAL_SIZE=0
echo "Major components:"

if [ -d "$HOME/.ollama" ]; then
    OLLAMA_SIZE_BYTES=$(du -sb "$HOME/.ollama" 2>/dev/null | cut -f1 || echo "0")
    OLLAMA_SIZE_HUMAN=$(du -sh "$HOME/.ollama" 2>/dev/null | cut -f1 || echo "0")
    echo "   Ollama models: ${GREEN}$OLLAMA_SIZE_HUMAN${NC}"
fi

if [ -d "$LONGCAT_DIR" ]; then
    LONGCAT_SIZE_HUMAN=$(du -sh "$LONGCAT_DIR" 2>/dev/null | cut -f1 || echo "0")
    echo "   LongCat-Video: ${GREEN}$LONGCAT_SIZE_HUMAN${NC}"
fi

if [ -d "$VENV_DIR" ]; then
    VENV_SIZE_HUMAN=$(du -sh "$VENV_DIR" 2>/dev/null | cut -f1 || echo "0")
    echo "   Python venv: ${GREEN}$VENV_SIZE_HUMAN${NC}"
fi

if [ -d "${HOME}/.n8n" ]; then
    N8N_SIZE_HUMAN=$(du -sh "${HOME}/.n8n" 2>/dev/null | cut -f1 || echo "0")
    echo "   n8n data: ${GREEN}$N8N_SIZE_HUMAN${NC}"
fi

# Check storage volume usage
if [ -n "${STORAGE_PATH:-}" ] && [ -d "$STORAGE_PATH" ]; then
    STORAGE_USED=$(du -sh "$STORAGE_PATH" 2>/dev/null | cut -f1 || echo "0")
    echo "   Storage volume: ${GREEN}$STORAGE_USED${NC}"
fi

echo ""
echo "=========================================="
echo "✅ Check Complete!"
echo "=========================================="
echo ""
echo "To see detailed breakdown of any directory:"
echo "   du -sh /path/to/directory"
echo "   du -h --max-depth=1 /path/to/directory | sort -h"
echo ""
