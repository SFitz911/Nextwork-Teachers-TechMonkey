#!/bin/bash
# Comprehensive system check - verifies all components are installed and running
# Usage: bash scripts/check_complete_system.sh

set -euo pipefail

echo "=========================================="
echo "Complete System Check"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check function
check_service() {
    local name=$1
    local check_cmd=$2
    local status_cmd=${3:-""}
    
    echo -n "Checking $name... "
    if eval "$check_cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ INSTALLED${NC}"
        if [ -n "$status_cmd" ]; then
            if eval "$status_cmd" > /dev/null 2>&1; then
                echo "   Status: ${GREEN}✅ RUNNING${NC}"
            else
                echo "   Status: ${YELLOW}⚠️  NOT RUNNING${NC}"
            fi
        fi
        return 0
    else
        echo -e "${RED}❌ NOT INSTALLED${NC}"
        return 1
    fi
}

# 1. System Information
echo "=========================================="
echo "1. System Information"
echo "=========================================="
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo ""

# 2. GPU Information
echo "=========================================="
echo "2. GPU Information"
echo "=========================================="
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
    echo ""
    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader
else
    echo -e "${RED}❌ nvidia-smi not found${NC}"
fi
echo ""

# 3. Docker
echo "=========================================="
echo "3. Docker"
echo "=========================================="
check_service "Docker" "command -v docker"
if command -v docker &> /dev/null; then
    echo "   Version: $(docker --version)"
    
    # Check if Docker daemon is running
    if docker info > /dev/null 2>&1; then
        echo -e "   Daemon: ${GREEN}✅ RUNNING${NC}"
        echo "   Containers: $(docker ps -q | wc -l) running"
        echo ""
        echo "   Running containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "   (none)"
    else
        echo -e "   Daemon: ${RED}❌ NOT RUNNING${NC}"
        echo "   Attempting to start Docker daemon..."
        systemctl start docker 2>/dev/null || service docker start 2>/dev/null || {
            echo "   ⚠️  Could not start Docker. Try: sudo systemctl start docker"
        }
    fi
else
    echo "   ${YELLOW}⚠️  Docker not installed${NC}"
fi
echo ""

check_service "Docker Compose" "command -v docker compose || command -v docker-compose"
if command -v docker compose &> /dev/null || command -v docker-compose &> /dev/null; then
    if command -v docker compose &> /dev/null; then
        echo "   Version: $(docker compose version)"
    else
        echo "   Version: $(docker-compose --version)"
    fi
fi
echo ""

# 4. Node.js and n8n
echo "=========================================="
echo "4. Node.js and n8n"
echo "=========================================="
check_service "Node.js" "command -v node"
if command -v node &> /dev/null; then
    echo "   Version: $(node --version)"
fi
echo ""

check_service "n8n" "command -v n8n"
if command -v n8n &> /dev/null; then
    echo "   Version: $(n8n --version)"
    check_service "n8n (running)" "curl -s http://localhost:5678 > /dev/null" "curl -s http://localhost:5678"
    if curl -s http://localhost:5678 > /dev/null 2>&1; then
        echo "   URL: http://localhost:5678"
    fi
fi
echo ""

# 5. Ollama
echo "=========================================="
echo "5. Ollama (LLM Service)"
echo "=========================================="
check_service "Ollama" "command -v ollama"
if command -v ollama &> /dev/null; then
    # Check if Ollama is running
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "   Status: ${GREEN}✅ RUNNING${NC}"
        echo "   API: http://localhost:11434"
        
        # Check installed models
        echo "   Installed models:"
        MODELS=$(curl -s http://localhost:11434/api/tags 2>/dev/null | python3 -c "import json, sys; d=json.load(sys.stdin); print('\\n'.join([m.get(\"name\", \"unknown\") for m in d.get(\"models\", [])]))" 2>/dev/null || echo "")
        if [ -n "$MODELS" ]; then
            echo "$MODELS" | sed 's/^/      - /'
        else
            echo "      ${YELLOW}(none found)${NC}"
        fi
    else
        echo -e "   Status: ${YELLOW}⚠️  NOT RUNNING${NC}"
        if pgrep -f "ollama serve" > /dev/null; then
            echo "   (Process found but API not responding)"
        fi
    fi
else
    echo "   ${YELLOW}⚠️  Ollama not installed${NC}"
fi
echo ""

# 6. PostgreSQL
echo "=========================================="
echo "6. PostgreSQL"
echo "=========================================="
# Check if running in Docker
if docker ps --format '{{.Names}}' | grep -q "ai-teacher-postgres"; then
    echo -e "PostgreSQL: ${GREEN}✅ RUNNING IN DOCKER${NC}"
    echo "   Container: ai-teacher-postgres"
    echo "   Port: 5432"
    
    # Check if accessible
    if docker exec ai-teacher-postgres pg_isready -U ai_teacher > /dev/null 2>&1; then
        echo -e "   Status: ${GREEN}✅ READY${NC}"
        
        # Check pgvector extension
        if docker exec ai-teacher-postgres psql -U ai_teacher -d ai_teacher -tAc "SELECT 1 FROM pg_extension WHERE extname='vector'" 2>/dev/null | grep -q 1; then
            echo -e "   pgvector: ${GREEN}✅ INSTALLED${NC}"
        else
            echo -e "   pgvector: ${YELLOW}⚠️  NOT INSTALLED${NC}"
            echo "   Run: docker exec -it ai-teacher-postgres psql -U ai_teacher -d ai_teacher -c \"CREATE EXTENSION vector;\""
        fi
    else
        echo -e "   Status: ${YELLOW}⚠️  NOT READY${NC}"
    fi
elif command -v psql &> /dev/null; then
    check_service "PostgreSQL (system)" "command -v psql"
    if systemctl is-active --quiet postgresql || pgrep -f postgres > /dev/null; then
        echo -e "   Status: ${GREEN}✅ RUNNING${NC}"
    else
        echo -e "   Status: ${YELLOW}⚠️  NOT RUNNING${NC}"
    fi
else
    echo -e "PostgreSQL: ${YELLOW}⚠️  NOT FOUND${NC}"
    echo "   (Should be running in Docker container)"
fi
echo ""

# 7. Python Environment
echo "=========================================="
echo "7. Python Environment"
echo "=========================================="
check_service "Python 3" "command -v python3"
if command -v python3 &> /dev/null; then
    echo "   Version: $(python3 --version)"
    
    # Check virtual environment
    if [ -d "$HOME/ai-teacher-venv" ]; then
        echo -e "   Virtual Env: ${GREEN}✅ EXISTS${NC} ($HOME/ai-teacher-venv)"
        if [ -f "$HOME/ai-teacher-venv/bin/activate" ]; then
            source "$HOME/ai-teacher-venv/bin/activate"
            echo "   Active: $(python3 --version) in venv"
        fi
    else
        echo -e "   Virtual Env: ${YELLOW}⚠️  NOT FOUND${NC}"
    fi
    
    # Check key packages
    echo "   Key packages:"
    for pkg in "streamlit" "fastapi" "uvicorn" "httpx" "pydantic"; do
        if python3 -c "import $pkg" 2>/dev/null; then
            VERSION=$(python3 -c "import $pkg; print(getattr($pkg, '__version__', 'unknown'))" 2>/dev/null || echo "installed")
            echo "      - $pkg: ${GREEN}✅${NC} ($VERSION)"
        else
            echo "      - $pkg: ${RED}❌${NC}"
        fi
    done
fi
echo ""

# 8. Docker Services
echo "=========================================="
echo "8. Docker Services Status"
echo "=========================================="
if docker info > /dev/null 2>&1; then
    echo "Docker Compose services:"
    cd "${PROJECT_DIR:-$HOME/Nextwork-Teachers-TechMonkey}" 2>/dev/null || true
    if [ -f "docker-compose.yml" ]; then
        docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null || echo "   (Could not check compose services)"
    else
        echo "   ${YELLOW}⚠️  docker-compose.yml not found${NC}"
    fi
    
    echo ""
    echo "All running containers:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" || echo "   (none)"
else
    echo -e "${RED}❌ Docker daemon not running${NC}"
    echo "   Start with: sudo systemctl start docker"
fi
echo ""

# 9. Storage
echo "=========================================="
echo "9. Storage Configuration"
echo "=========================================="
if [ -n "${VAST_STORAGE:-}" ]; then
    STORAGE="$VAST_STORAGE"
elif [ -f "${PROJECT_DIR:-$HOME/Nextwork-Teachers-TechMonkey}/.env" ]; then
    STORAGE=$(grep "VAST_STORAGE_PATH=" "${PROJECT_DIR:-$HOME/Nextwork-Teachers-TechMonkey}/.env" | cut -d'=' -f2 | tr -d '"' || echo "")
fi

if [ -z "$STORAGE" ]; then
    # Try common locations
    for loc in "/root/vast-storage" "/mnt/vast-storage" "/vast-storage"; do
        if [ -d "$loc" ]; then
            STORAGE="$loc"
            break
        fi
    done
fi

if [ -n "$STORAGE" ] && [ -d "$STORAGE" ]; then
    echo -e "Storage Path: ${GREEN}✅${NC} $STORAGE"
    echo "   Size: $(df -h "$STORAGE" | tail -1 | awk '{print $2 " total, " $4 " available"}')"
    echo ""
    echo "   Directories:"
    for dir in "postgresql" "cached_sections" "embeddings" "logs"; do
        if [ -d "$STORAGE/$dir" ]; then
            SIZE=$(du -sh "$STORAGE/$dir" 2>/dev/null | cut -f1 || echo "0")
            echo "      - $dir: ${GREEN}✅${NC} ($SIZE)"
        else
            echo "      - $dir: ${YELLOW}⚠️  NOT FOUND${NC}"
        fi
    done
else
    echo -e "Storage: ${YELLOW}⚠️  NOT CONFIGURED${NC}"
fi
echo ""

# 10. Service Ports
echo "=========================================="
echo "10. Service Ports (Accessibility)"
echo "=========================================="
PORTS=(
    "5678:n8n"
    "11434:Ollama"
    "8001:TTS"
    "8002:Animation"
    "8003:LongCat-Video"
    "8004:Coordinator API"
    "8501:Frontend"
    "5432:PostgreSQL"
)

for port_info in "${PORTS[@]}"; do
    PORT=$(echo $port_info | cut -d':' -f1)
    NAME=$(echo $port_info | cut -d':' -f2)
    
    if netstat -tuln 2>/dev/null | grep -q ":$PORT " || ss -tuln 2>/dev/null | grep -q ":$PORT "; then
        echo -e "   Port $PORT ($NAME): ${GREEN}✅ LISTENING${NC}"
    else
        echo -e "   Port $PORT ($NAME): ${YELLOW}⚠️  NOT LISTENING${NC}"
    fi
done
echo ""

# 11. Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""

ISSUES=0

# Check critical services
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker daemon not running${NC}"
    echo "   Fix: sudo systemctl start docker"
    ISSUES=$((ISSUES + 1))
fi

if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1 && ! docker ps | grep -q ollama; then
    echo -e "${YELLOW}⚠️  Ollama not running${NC}"
    ISSUES=$((ISSUES + 1))
fi

if ! curl -s http://localhost:5678 > /dev/null 2>&1 && ! docker ps | grep -q n8n; then
    echo -e "${YELLOW}⚠️  n8n not running${NC}"
    ISSUES=$((ISSUES + 1))
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ All critical services appear to be running!${NC}"
else
    echo -e "${YELLOW}⚠️  Found $ISSUES issue(s)${NC}"
fi

echo ""
echo "To start all services:"
echo "   cd ~/Nextwork-Teachers-TechMonkey"
echo "   docker compose up -d"
echo ""
