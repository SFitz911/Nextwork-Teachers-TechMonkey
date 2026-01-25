#!/bin/bash
# Comprehensive video generation debugging script

set -e

echo "=========================================="
echo "Video Generation Debugging Tool"
echo "=========================================="
echo ""

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    echo "⚠️  Warning: common.sh not found, using defaults"
    COORDINATOR_API_URL="http://localhost:8004"
    N8N_API_URL="http://localhost:5678"
fi

echo "Step 1: Checking Service Status"
echo "--------------------------------"
echo ""

# Check Coordinator API
echo "📡 Coordinator API (port 8004):"
if curl -s -f "$COORDINATOR_API_URL/health" > /dev/null 2>&1; then
    echo "  ✅ Running"
    COORD_STATUS=$(curl -s "$COORDINATOR_API_URL/health" | jq -r '.status' 2>/dev/null || echo "unknown")
    echo "  Status: $COORD_STATUS"
else
    echo "  ❌ NOT RUNNING or not accessible"
    echo "  Run: source ~/ai-teacher-venv/bin/activate && python services/coordinator/app.py"
fi
echo ""

# Check n8n
echo "🔄 n8n (port 5678):"
if curl -s -f "$N8N_API_URL/healthz" > /dev/null 2>&1; then
    echo "  ✅ Running"
else
    echo "  ❌ NOT RUNNING or not accessible"
    echo "  Check: tmux attach -t ai-teacher (look for n8n pane)"
fi
echo ""

# Check LongCat-Video service
echo "🎥 LongCat-Video Service (port 8003):"
if curl -s -f "http://localhost:8003/status" > /dev/null 2>&1; then
    echo "  ✅ Running"
    LONGCAT_STATUS=$(curl -s "http://localhost:8003/status" | jq -r '.status' 2>/dev/null || echo "unknown")
    echo "  Status: $LONGCAT_STATUS"
    
    # Check if models are available
    if echo "$LONGCAT_STATUS" | grep -q "models_not_found"; then
        echo "  ⚠️  WARNING: Models not found!"
        echo "  Run: bash scripts/deploy_longcat_video.sh"
    fi
else
    echo "  ❌ NOT RUNNING or not accessible"
    echo "  Check: tmux attach -t ai-teacher (look for longcat-video pane)"
fi
echo ""

# Check TTS service
echo "🔊 TTS Service (port 8001):"
if curl -s -f "http://localhost:8001/health" > /dev/null 2>&1; then
    echo "  ✅ Running"
else
    echo "  ❌ NOT RUNNING or not accessible"
fi
echo ""

# Check Ollama
echo "🤖 Ollama (port 11434):"
if curl -s -f "http://localhost:11434/api/tags" > /dev/null 2>&1; then
    echo "  ✅ Running"
    MODELS=$(curl -s "http://localhost:11434/api/tags" | jq -r '.models[].name' 2>/dev/null | head -3)
    if [ -n "$MODELS" ]; then
        echo "  Models: $MODELS"
    else
        echo "  ⚠️  WARNING: No models found!"
        echo "  Run: ollama pull mistral:7b"
    fi
else
    echo "  ❌ NOT RUNNING or not accessible"
    echo "  Run: ollama serve"
fi
echo ""

echo "Step 2: Checking n8n Workflows"
echo "--------------------------------"
echo ""

# Check if workflows are imported
if [ -n "$N8N_API_KEY" ]; then
    WORKFLOWS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_API_URL/api/v1/workflows" 2>/dev/null | jq -r '.[] | "\(.name) (ID: \(.id), Active: \(.active))"' 2>/dev/null || echo "")
    
    if [ -n "$WORKFLOWS" ]; then
        echo "📋 Imported Workflows:"
        echo "$WORKFLOWS" | while read -r line; do
            if echo "$line" | grep -q "Session Start\|Left Worker\|Right Worker"; then
                if echo "$line" | grep -q "Active: true"; then
                    echo "  ✅ $line"
                else
                    echo "  ⚠️  $line (INACTIVE - needs activation)"
                fi
            fi
        done
    else
        echo "  ❌ No workflows found or API key invalid"
        echo "  Run: bash scripts/force_reimport_workflows.sh"
    fi
else
    echo "  ⚠️  N8N_API_KEY not set in environment"
    echo "  Set it in .env file or scripts/lib/common.sh"
fi
echo ""

echo "Step 3: Checking Recent Logs"
echo "--------------------------------"
echo ""

# Check Coordinator logs
if [ -f "logs/coordinator.log" ]; then
    echo "📝 Last 5 Coordinator API errors:"
    grep -i "error\|exception\|failed" logs/coordinator.log | tail -5 || echo "  No errors found"
else
    echo "  ⚠️  logs/coordinator.log not found"
fi
echo ""

# Check LongCat-Video logs
if [ -f "logs/longcat_video.log" ]; then
    echo "📝 Last 5 LongCat-Video errors:"
    grep -i "error\|exception\|failed" logs/longcat_video.log | tail -5 || echo "  No errors found"
else
    echo "  ⚠️  logs/longcat_video.log not found"
fi
echo ""

echo "Step 4: Testing Video Generation Pipeline"
echo "--------------------------------"
echo ""

# Test 1: Create a test session
echo "🧪 Test 1: Creating test session..."
SESSION_RESPONSE=$(curl -s -X POST "$COORDINATOR_API_URL/session/start" \
    -H "Content-Type: application/json" \
    -d '{"selectedTeachers": ["teacher_a", "teacher_b"], "lessonUrl": "https://www.nextwork.org/projects"}' 2>/dev/null)

if [ $? -eq 0 ] && echo "$SESSION_RESPONSE" | jq -e '.sessionId' > /dev/null 2>&1; then
    SESSION_ID=$(echo "$SESSION_RESPONSE" | jq -r '.sessionId')
    echo "  ✅ Session created: $SESSION_ID"
    
    # Test 2: Update section to trigger render job
    echo ""
    echo "🧪 Test 2: Updating section to trigger render job..."
    SECTION_RESPONSE=$(curl -s -X POST "$COORDINATOR_API_URL/session/$SESSION_ID/section" \
        -H "Content-Type: application/json" \
        -d '{
            "sessionId": "'$SESSION_ID'",
            "sectionId": "test-sec-1",
            "url": "https://www.nextwork.org/projects",
            "scrollY": 0,
            "visibleText": "Test content for video generation",
            "selectedText": "",
            "userQuestion": "What is this about?",
            "language": "en"
        }' 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "  ✅ Section update sent"
        echo "  ⏳ Waiting 5 seconds for workflow to process..."
        sleep 5
        
        # Test 3: Check session state
        echo ""
        echo "🧪 Test 3: Checking session state..."
        STATE_RESPONSE=$(curl -s "$COORDINATOR_API_URL/session/$SESSION_ID/state" 2>/dev/null)
        if [ $? -eq 0 ]; then
            SPEAKER=$(echo "$STATE_RESPONSE" | jq -r '.speaker' 2>/dev/null || echo "none")
            RENDERER=$(echo "$STATE_RESPONSE" | jq -r '.renderer' 2>/dev/null || echo "none")
            echo "  Speaker: $SPEAKER"
            echo "  Renderer: $RENDERER"
            
            # Check if clips exist
            CLIPS=$(echo "$STATE_RESPONSE" | jq -r '.clips | keys[]' 2>/dev/null || echo "")
            if [ -n "$CLIPS" ]; then
                echo "  ✅ Clips found for teachers: $CLIPS"
            else
                echo "  ⚠️  No clips generated yet"
            fi
        fi
        
        # Test 4: Check n8n workflow executions
        echo ""
        echo "🧪 Test 4: Checking n8n workflow executions..."
        if [ -n "$N8N_API_KEY" ]; then
            EXECUTIONS=$(curl -s -H "X-N8N-API-KEY: $N8N_API_KEY" \
                "$N8N_API_URL/api/v1/executions?limit=5" 2>/dev/null | \
                jq -r '.data[] | "\(.workflowId) - \(.finished) - \(.mode)"' 2>/dev/null || echo "")
            
            if [ -n "$EXECUTIONS" ]; then
                echo "  Recent executions:"
                echo "$EXECUTIONS" | head -3
            else
                echo "  ⚠️  No recent executions found"
            fi
        fi
    else
        echo "  ❌ Failed to update section"
    fi
else
    echo "  ❌ Failed to create session"
    echo "  Response: $SESSION_RESPONSE"
fi

echo ""
echo "Step 5: Manual Testing Steps"
echo "--------------------------------"
echo ""
echo "If videos still aren't generating, try these steps:"
echo ""
echo "1. Check n8n workflow execution logs:"
echo "   - Open http://localhost:5678 in browser"
echo "   - Go to 'Executions' tab"
echo "   - Look for failed executions and error messages"
echo ""
echo "2. Test LongCat-Video service directly:"
echo "   curl -X POST http://localhost:8003/generate \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"avatar_id\": \"maya\", \"audio_url\": \"http://localhost:8001/audio/test.wav\", \"text_prompt\": \"Hello world\"}'"
echo ""
echo "3. Check tmux session for service errors:"
echo "   tmux attach -t ai-teacher"
echo "   - Navigate between panes with Ctrl+B then arrow keys"
echo "   - Look for error messages in each service pane"
echo ""
echo "4. Verify all services are using correct ports:"
echo "   netstat -tuln | grep -E '8001|8003|8004|5678|11434'"
echo ""
echo "=========================================="
echo "Debugging complete!"
echo "=========================================="
