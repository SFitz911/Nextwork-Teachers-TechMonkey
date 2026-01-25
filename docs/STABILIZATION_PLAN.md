# Stabilization Implementation Plan
**Based on Audit Report**  
**Priority: Fix Critical Issues First**

---

## Phase 1: Critical Fixes (Days 1-2)

### Fix 1.1: API Key Management

#### Problem
- API key endpoint returns 404
- Cannot create API keys programmatically
- Workflow import fails without valid API key

#### Solution Options

**Option A: Use n8n UI Automation (Recommended)**
- Create script that opens n8n UI and guides user
- Or use n8n's internal API if available
- Fallback to manual instructions

**Option B: Fix API Endpoint**
- Check n8n version: `n8n --version`
- Verify correct API endpoint path
- May need n8n configuration change

**Option C: Manual Setup with Validation**
- Require API key in `.env` before operations
- Validate API key on startup
- Provide clear setup instructions

#### Implementation Steps

1. **Create `.env.example`**:
```bash
# n8n Configuration
N8N_USER=your_email@example.com
N8N_PASSWORD=your_password
N8N_API_KEY=your_api_key_here  # Get from n8n UI: Settings → API

# Service URLs (usually don't need to change)
N8N_URL=http://localhost:5678
N8N_WEBHOOK_URL=http://localhost:5678/webhook/chat-webhook
TTS_API_URL=http://localhost:8001
ANIMATION_API_URL=http://localhost:8002

# Virtual Environment
VENV_DIR=$HOME/ai-teacher-venv
```

2. **Create `scripts/validate_config.sh`**:
```bash
#!/usr/bin/env bash
# Validate all required configuration exists

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env if it exists
if [[ -f ".env" ]]; then
    export $(grep -v '^#' .env | xargs)
fi

ERRORS=0

# Check required variables
if [[ -z "${N8N_USER:-}" ]]; then
    echo "❌ N8N_USER not set in .env"
    ERRORS=$((ERRORS + 1))
fi

if [[ -z "${N8N_PASSWORD:-}" ]]; then
    echo "❌ N8N_PASSWORD not set in .env"
    ERRORS=$((ERRORS + 1))
fi

if [[ -z "${N8N_API_KEY:-}" ]]; then
    echo "❌ N8N_API_KEY not set in .env"
    echo "   To create an API key:"
    echo "   1. Open http://localhost:5678 (with port forwarding active)"
    echo "   2. Go to Settings → API"
    echo "   3. Create a new API key"
    echo "   4. Add to .env: echo 'N8N_API_KEY=your_key_here' >> .env"
    ERRORS=$((ERRORS + 1))
fi

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "❌ Configuration validation failed ($ERRORS errors)"
    echo "   Copy .env.example to .env and fill in values"
    exit 1
fi

echo "✅ Configuration validated"
exit 0
```

3. **Update `scripts/get_or_create_api_key.sh`**:
- Remove automatic creation attempts (they fail)
- Focus on validation and clear error messages
- Provide manual setup instructions

4. **Update `scripts/clean_and_import_workflow.sh`**:
- Call `validate_config.sh` first
- Fail fast if API key missing
- Provide clear error messages

---

### Fix 1.2: Unify Service Startup

#### Problem
- Ollama not started by `run_no_docker_tmux.sh`
- Services start without health checks
- No dependency management

#### Solution

**Create `scripts/start_all_services.sh`**:
```bash
#!/usr/bin/env bash
# Unified service startup with health checks and dependencies

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load .env
if [[ -f ".env" ]]; then
    export $(grep -v '^#' .env | xargs)
fi

SESSION="ai-teacher"
VENV_DIR="${VENV_DIR:-$HOME/ai-teacher-venv}"

echo "=========================================="
echo "Starting All Services"
echo "=========================================="
echo ""

# Step 1: Start Ollama (if not running)
echo "1. Starting Ollama..."
if ! pgrep -f "ollama serve" > /dev/null; then
    nohup ollama serve > logs/ollama.log 2>&1 &
    sleep 5
    echo "✅ Ollama started"
else
    echo "✅ Ollama already running"
fi

# Wait for Ollama to be ready
echo "   Waiting for Ollama to be ready..."
for i in {1..10}; do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "✅ Ollama is ready"
        break
    fi
    sleep 1
done

# Step 2: Start other services in tmux
echo ""
echo "2. Starting n8n, TTS, Animation, and Frontend..."
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    bash scripts/run_no_docker_tmux.sh
    echo "✅ Services started in tmux"
else
    echo "✅ Services already running in tmux"
fi

# Step 3: Wait for n8n to be ready
echo ""
echo "3. Waiting for n8n to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:5678 > /dev/null 2>&1; then
        # Test API
        if curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY:-}" \
           "http://localhost:5678/api/v1/workflows" > /dev/null 2>&1 || \
           curl -s -u "${N8N_USER:-admin}:${N8N_PASSWORD:-changeme}" \
           "http://localhost:5678/api/v1/workflows" > /dev/null 2>&1; then
            echo "✅ n8n is ready"
            break
        fi
    fi
    sleep 2
done

# Step 4: Verify all services
echo ""
echo "4. Verifying all services..."
bash scripts/check_all_services_status.sh

echo ""
echo "=========================================="
echo "✅ All services started and ready"
echo "=========================================="
```

**Update `scripts/run_no_docker_tmux.sh`**:
- Add comment: "Ollama started separately by start_all_services.sh"
- Or add Ollama as optional window

**Update `scripts/restart_and_setup.sh`**:
- Use `start_all_services.sh` instead of separate commands
- Remove duplicate Ollama startup logic

---

### Fix 1.3: Workflow Import Reliability

#### Problem
- Workflow import fails when API key invalid
- No validation after import
- No backup/restore mechanism

#### Solution

**Update `scripts/clean_and_import_workflow.sh`**:
1. Call `validate_config.sh` first
2. Add workflow backup before deletion
3. Add validation after import
4. Add retry logic

**Add workflow backup**:
```bash
# Before deleting workflows, backup them
BACKUP_DIR="$PROJECT_DIR/backups/workflows"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/workflow_backup_$(date +%Y%m%d_%H%M%S).json"

# Backup existing workflows
echo "Backing up existing workflows..."
curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" > "$BACKUP_FILE" 2>/dev/null || true
```

**Add import validation**:
```bash
# After import, verify workflow exists and is active
sleep 3
VERIFY_WORKFLOW=$(curl -s -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    "${N8N_URL}/api/v1/workflows" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for wf in data.get('data', []):
        if 'Five Teacher' in wf.get('name', ''):
            print(wf.get('id', ''))
            print('active' if wf.get('active', False) else 'inactive')
except:
    pass
")

if [[ -z "$VERIFY_WORKFLOW" ]]; then
    echo "❌ Workflow import verification failed"
    exit 1
fi
```

---

## Phase 2: Script Consolidation (Days 3-5)

### Consolidation Plan

#### Group 1: Webhook Diagnostics → `scripts/diagnose_webhook.sh`
**Merge**:
- `diagnose_webhook_issue.sh`
- `debug_webhook_execution.sh`
- `check_workflow_execution.sh`
- `check_and_fix_webhook.sh`

**New script structure**:
```bash
#!/usr/bin/env bash
# Comprehensive webhook diagnostics

# 1. Check services
# 2. Check workflow exists and is active
# 3. Check recent executions
# 4. Test webhook
# 5. Provide recommendations
```

#### Group 2: Execution Inspection → `scripts/inspect_execution.sh`
**Merge**:
- `inspect_latest_execution.sh`
- `check_execution_nodes.sh`
- `check_execution_raw.sh`
- `wait_and_check_execution.sh`

**New script**: Single script with flags for different detail levels

#### Group 3: Workflow Management → Keep `clean_and_import_workflow.sh`
**Remove**:
- `import_and_activate_workflow.sh` (duplicate)
- `activate_workflow_api.sh` (functionality in clean_and_import)

#### Group 4: Test Scripts → `scripts/test_webhook.sh`
**Merge**:
- All `test_webhook_*.sh` scripts
- `simple_webhook_test.sh`

**New script**: Single test script with options

---

## Phase 3: Configuration Management (Days 6-8)

### Create Configuration System

1. **`.env.example`** (already planned in Phase 1)
2. **`scripts/setup_environment.sh`**:
```bash
#!/usr/bin/env bash
# Interactive environment setup

if [[ ! -f ".env" ]]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "Please edit .env and fill in your values"
    echo "Then run: bash scripts/validate_config.sh"
else
    echo ".env already exists"
fi
```

3. **Update all scripts** to:
   - Load `.env` consistently
   - Call `validate_config.sh` if needed
   - Remove hardcoded credentials

---

## Phase 4: Error Handling (Days 9-11)

### Improve Error Messages

**Create `scripts/lib/error_handling.sh`**:
```bash
#!/usr/bin/env bash
# Common error handling functions

error_with_help() {
    local error_msg="$1"
    local help_msg="$2"
    
    echo "❌ $error_msg" >&2
    echo "" >&2
    echo "$help_msg" >&2
    exit 1
}

check_prerequisite() {
    local cmd="$1"
    local install_cmd="$2"
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error_with_help \
            "$cmd is not installed" \
            "Install with: $install_cmd"
    fi
}
```

**Update scripts** to use error handling library

---

## Phase 5: Persistence (Days 12-14)

### Workflow Backup/Restore

**Create `scripts/backup_workflow.sh`**:
```bash
#!/usr/bin/env bash
# Backup current workflow

# Backup to file
# Version control backup
# Restore from backup on startup
```

**Update `restart_and_setup.sh`**:
- Restore workflow from backup if import fails
- Fallback chain: Import → Restore backup → Manual instructions

---

## Testing Plan

### After Each Phase

1. **Test restart scenario**:
   ```bash
   # On VAST Terminal
   # 1. Kill all services
   tmux kill-session -t ai-teacher
   pkill -f ollama
   
   # 2. Run restart script
   bash scripts/restart_and_setup.sh
   
   # 3. Verify everything works
   bash scripts/check_all_services_status.sh
   curl -X POST http://localhost:5678/webhook/chat-webhook \
       -H "Content-Type: application/json" \
       -d '{"message": "test"}'
   ```

2. **Test error scenarios**:
   - Missing API key
   - Invalid API key
   - Services not running
   - Workflow missing

3. **Test recovery**:
   - Partial service failure
   - Workflow import failure
   - Configuration errors

---

## Rollout Plan

### Week 1: Critical Fixes
- Day 1-2: Fix API key, service startup, workflow import
- Day 3: Test and validate
- Day 4-5: Script consolidation (if time)

### Week 2: Quality Improvements
- Day 6-8: Configuration management
- Day 9-11: Error handling
- Day 12-14: Persistence (if needed)

### Week 3: Documentation and Polish
- Update all documentation
- Create user guides
- Final testing

---

## Success Criteria

### Phase 1 Success
- [ ] `bash scripts/restart_and_setup.sh` works after fresh restart
- [ ] No manual API key creation needed (or clear instructions)
- [ ] All services start in correct order
- [ ] Workflow imports automatically

### Phase 2 Success
- [ ] Script count reduced to ~15
- [ ] Clear documentation on which script to use
- [ ] No duplicate functionality

### Phase 3 Success
- [ ] `.env.example` exists
- [ ] Configuration validated on startup
- [ ] No hardcoded credentials

### Phase 4 Success
- [ ] All error messages provide next steps
- [ ] Prerequisites checked before operations
- [ ] Clear recovery instructions

### Phase 5 Success
- [ ] Workflow persists across restarts
- [ ] Backup/restore works
- [ ] System recovers automatically

---

## Risk Mitigation

### Backup Before Changes
```bash
# Before making changes, backup current state
git commit -a -m "Backup before stabilization changes"
git push origin main
```

### Incremental Changes
- Make one fix at a time
- Test after each change
- Revert if issues found

### Documentation
- Document all changes
- Update README-AI.md
- Create migration guides

---

## Next Steps

1. **Review this plan** with stakeholders
2. **Prioritize fixes** based on impact
3. **Start Phase 1** immediately
4. **Test thoroughly** after each phase
5. **Document changes** as you go

---

**Ready to begin? Start with Phase 1, Fix 1.1: Create `.env.example` and `validate_config.sh`**
