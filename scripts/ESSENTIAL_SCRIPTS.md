# Essential Scripts Reference

After consolidation, these are the **essential scripts** you need to know:

## 🚀 Startup & Management

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `restart_and_setup.sh` | **Complete restart** - starts everything, imports workflow | After VAST restart |
| `start_all_services.sh` | Start all services with health checks | Starting services manually |
| `check_all_services_status.sh` | Check if all services are running | Diagnostic |

## 🔧 Workflow Management

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `clean_and_import_workflow.sh` | Delete old workflows, import correct one | When workflow is missing/corrupted |
| `validate_config.sh` | Validate all required configuration | Before operations, troubleshooting |

## 🔍 Diagnostics

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `diagnose_webhook.sh` | **Comprehensive webhook diagnostics** | When webhook not working |
| `inspect_execution.sh` | Inspect workflow execution details | Debugging execution failures |
| `test_webhook.sh` | Test webhook with message | Quick webhook test |

## 📋 Usage Examples

### After VAST Restart
```bash
bash scripts/restart_and_setup.sh
```

### Debugging Webhook Issues
```bash
# Comprehensive check
bash scripts/diagnose_webhook.sh

# Check latest execution
bash scripts/inspect_execution.sh --latest

# Test webhook
bash scripts/test_webhook.sh "Hello"
```

### Workflow Issues
```bash
# Validate config first
bash scripts/validate_config.sh

# Re-import workflow
bash scripts/clean_and_import_workflow.sh
```

## 📚 Deprecated Scripts

Many scripts have been consolidated. See `scripts/DEPRECATED_SCRIPTS.md` for migration guide.

**Key replacements:**
- `inspect_latest_execution.sh` → `inspect_execution.sh --latest`
- `check_execution_nodes.sh` → `inspect_execution.sh --nodes [id]`
- `test_webhook_with_message.sh` → `test_webhook.sh [message]`
- `diagnose_webhook_issue.sh` → `diagnose_webhook.sh`

## 🆘 Quick Help

**Not sure which script to use?**
```bash
bash scripts/diagnose_webhook.sh
```

This will check everything and tell you what's wrong.
