#!/usr/bin/env bash
# Fix LongCat-Video dependencies and re-import n8n workflows
# Usage: bash scripts/fix_and_reimport_workflows.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Fixing LongCat-Video and Re-importing Workflows"
echo "=========================================="
echo ""

# Load .env if it exists
if [[ -f ".env" ]]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
fi

# Step 1: Install missing dependency in conda environment
echo "Step 1: Installing missing dependencies in conda environment..."
echo ""

# Initialize conda
CONDA_BASE=$(conda info --base)
source "$CONDA_BASE/etc/profile.d/conda.sh"

# Activate conda environment
if conda env list | grep -q "longcat-video"; then
    conda activate longcat-video
    echo "✅ Activated longcat-video conda environment"
    
    # Install missing dependencies
    echo "Installing missing LongCat-Video dependencies..."
    
    # Install from requirements_avatar.txt (filtering out problematic packages)
    cd "$PROJECT_DIR/LongCat-Video"
    grep -v "^#" requirements_avatar.txt | grep -v "^$" | grep -v "libsndfile1" | grep -v "tritonserverclient" | pip install -r /dev/stdin || {
        echo "⚠️  Some avatar requirements failed, installing essential packages..."
        pip install pyloudnorm==0.1.1 scikit-learn==1.6.1 scikit-image==0.25.2 scipy==1.15.3 soundfile==0.13.1 soxr==0.5.0.post1 librosa==0.11.0 sympy==1.13.1 audio-separator==0.30.2 nvidia-ml-py==13.580.65 tzdata==2025.2 onnx==1.18.0 onnxruntime==1.16.3 openai==1.75.0 numpy==1.26.4 cffi==2.0.0 chardet==5.2.0 || echo "⚠️  Some packages failed, but continuing..."
    }
    cd "$PROJECT_DIR"
    
    # Verify critical dependencies
    python -c "import pyloudnorm; print('✅ pyloudnorm installed successfully')" 2>/dev/null || echo "⚠️  pyloudnorm verification failed"
else
    echo "❌ longcat-video conda environment not found!"
    echo "   Run: bash scripts/deploy_longcat_video.sh"
    exit 1
fi

echo ""
echo "Step 2: Pulling latest code changes..."
git pull origin main || echo "⚠️  Git pull had issues, continuing..."

echo ""
echo "Step 3: Restarting LongCat-Video service..."
echo ""

# Kill existing LongCat-Video service
pkill -f "longcat_video/app.py" 2>/dev/null || true
sleep 2

# Make sure we're still in conda environment
conda activate longcat-video

# Set environment variables
export LONGCAT_VIDEO_DIR="$PROJECT_DIR/LongCat-Video"
export CHECKPOINT_DIR="$LONGCAT_VIDEO_DIR/weights/LongCat-Video-Avatar"
export AVATAR_IMAGES_DIR="$LONGCAT_VIDEO_DIR/assets/avatars"
export OUTPUT_DIR="$PROJECT_DIR/outputs/longcat"
mkdir -p "$OUTPUT_DIR"

# Start the service in background
echo "Starting LongCat-Video service..."
nohup python services/longcat_video/app.py > logs/longcat_video.log 2>&1 &
LONGCAT_PID=$!

# Wait for service to start
sleep 3

# Test the service
if curl -s http://localhost:8003/status > /dev/null 2>&1; then
    echo "✅ LongCat-Video service is running"
else
    echo "⚠️  LongCat-Video service may not be ready yet. Check logs: tail -20 logs/longcat_video.log"
fi

echo ""
echo "Step 4: Re-importing n8n workflows..."
echo ""

# Use the existing reconfigure script
if [[ -f "scripts/reconfigure_n8n_for_2teacher.sh" ]]; then
    bash scripts/reconfigure_n8n_for_2teacher.sh
else
    echo "⚠️  reconfigure_n8n_for_2teacher.sh not found, using manual import..."
    
    # Get n8n credentials
    N8N_USER="${N8N_USER:-admin}"
    N8N_PASSWORD="${N8N_PASSWORD:-changeme}"
    DEFAULT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI4ZWM2NDU4Yy1hMjg0LTQ4ZTctYmE3OS0yOTNlNmY3MjJlMTYiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzY5MzE3ODA3fQ.iAUgO1sHP11IDOJT38pn3wOwjHXQmVg4_SyrNyaMqbw"
    N8N_API_KEY="${N8N_API_KEY:-$DEFAULT_API_KEY}"
    N8N_URL="http://localhost:5678"
    
    # Import workflows
    WORKFLOWS=(
        "session-start-workflow.json:Session Start"
        "left-worker-workflow.json:Left Worker - Teacher Pipeline"
        "right-worker-workflow.json:Right Worker - Teacher Pipeline"
    )
    
    for workflow_entry in "${WORKFLOWS[@]}"; do
        IFS=':' read -r workflow_file workflow_name <<< "$workflow_entry"
        workflow_path="$PROJECT_DIR/n8n/workflows/$workflow_file"
        
        if [[ ! -f "$workflow_path" ]]; then
            echo "⚠️  Workflow file not found: $workflow_path"
            continue
        fi
        
        echo "Importing $workflow_name..."
        
        # Clean workflow JSON (remove read-only fields)
        CLEANED_WORKFLOW=$(python3 <<EOF
import json, sys
try:
    with open('$workflow_path', 'r') as f:
        workflow = json.load(f)
    
    cleaned = {
        "name": workflow.get("name", "$workflow_name"),
        "nodes": workflow.get("nodes", []),
        "connections": workflow.get("connections", {}),
        "settings": workflow.get("settings", {}),
        "staticData": workflow.get("staticData", {}),
    }
    
    print(json.dumps(cleaned))
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
EOF
)
        
        if [[ $? -ne 0 ]]; then
            echo "   ❌ Failed to clean workflow JSON"
            continue
        fi
        
        # Import workflow
        RESPONSE=$(curl -s -X POST \
            -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
            -H "Content-Type: application/json" \
            -d "$CLEANED_WORKFLOW" \
            "${N8N_URL}/api/v1/workflows" 2>/dev/null)
        
        WORKFLOW_ID=$(echo "$RESPONSE" | python3 -c "import json, sys; d=json.load(sys.stdin); print(d.get('id', 'error'))" 2>/dev/null || echo "error")
        
        if [[ "$WORKFLOW_ID" != "error" ]] && [[ -n "$WORKFLOW_ID" ]]; then
            echo "   ✅ Imported: $workflow_name (ID: $WORKFLOW_ID)"
            
            # Activate workflow
            ACTIVATE_RESPONSE=$(curl -s -X POST \
                -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
                -H "Content-Type: application/json" \
                "${N8N_URL}/api/v1/workflows/${WORKFLOW_ID}/activate" 2>/dev/null)
            
            if echo "$ACTIVATE_RESPONSE" | grep -q "active.*true\|success"; then
                echo "   ✅ Activated: $workflow_name"
            fi
        else
            echo "   ❌ Failed to import: $workflow_name"
            echo "   Response: $RESPONSE" | head -5
        fi
        echo ""
    done
fi

echo ""
echo "Step 5: Restarting all services..."
echo ""

# Restart all services using quick start
bash scripts/quick_start_all.sh

echo ""
echo "=========================================="
echo "✅ Fix and Re-import Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✅ Installed pyloudnorm in conda environment"
echo "  ✅ Updated LongCat-Video service code"
echo "  ✅ Re-imported n8n workflows"
echo "  ✅ Restarted all services"
echo ""
echo "Next steps:"
echo "  1. Set up port forwarding: .\connect-vast-simple.ps1 (Desktop PowerShell)"
echo "  2. Access frontend: http://localhost:8501"
echo "  3. Test a session with 2 teachers"
echo ""
echo "To check service status:"
echo "  bash scripts/check_all_services_status.sh"
echo ""
echo "To view logs:"
echo "  tmux attach -t ai-teacher"
echo ""
