# Deprecated Scripts

The following scripts have been **consolidated** into newer, more comprehensive scripts. 
**Please use the replacement scripts instead.**

## Execution Inspection Scripts

### Replaced by: `scripts/inspect_execution.sh`

| Deprecated Script | Replacement Command |
|-------------------|---------------------|
| `inspect_latest_execution.sh` | `bash scripts/inspect_execution.sh --latest` |
| `check_execution_nodes.sh` | `bash scripts/inspect_execution.sh --nodes [id]` |
| `check_execution_raw.sh` | `bash scripts/inspect_execution.sh --raw [id]` |
| `wait_and_check_execution.sh` | `bash scripts/inspect_execution.sh [id]` |
| `trigger_and_inspect.sh` | `bash scripts/test_webhook.sh` then `bash scripts/inspect_execution.sh --latest` |
| `trigger_and_debug.sh` | `bash scripts/test_webhook.sh` then `bash scripts/diagnose_webhook.sh` |

## Webhook Testing Scripts

### Replaced by: `scripts/test_webhook.sh`

| Deprecated Script | Replacement Command |
|-------------------|---------------------|
| `test_webhook_with_message.sh` | `bash scripts/test_webhook.sh "your message"` |
| `simple_webhook_test.sh` | `bash scripts/test_webhook.sh` |
| `test_webhook_full.sh` | `bash scripts/test_webhook.sh --full` |
| `test_webhook_directly.sh` | `bash scripts/test_webhook.sh` |

## Webhook Diagnostic Scripts

### Replaced by: `scripts/diagnose_webhook.sh`

| Deprecated Script | Replacement Command |
|-------------------|---------------------|
| `diagnose_webhook_issue.sh` | `bash scripts/diagnose_webhook.sh` |
| `debug_webhook_execution.sh` | `bash scripts/diagnose_webhook.sh` |
| `check_workflow_execution.sh` | `bash scripts/diagnose_webhook.sh` |
| `check_and_fix_webhook.sh` | `bash scripts/diagnose_webhook.sh` |

## Workflow Management Scripts

### Replaced by: `scripts/clean_and_import_workflow.sh`

| Deprecated Script | Replacement Command |
|-------------------|---------------------|
| `import_and_activate_workflow.sh` | `bash scripts/clean_and_import_workflow.sh` |
| `activate_workflow_api.sh` | `bash scripts/clean_and_import_workflow.sh` (activates automatically) |
| `fix_workflow_issues.sh` | `bash scripts/clean_and_import_workflow.sh` (cleans and re-imports) |
| `fix_workflow_references.sh` | `bash scripts/clean_and_import_workflow.sh` (re-imports fresh) |

## Verification Scripts

### Replaced by: `scripts/diagnose_webhook.sh` or `scripts/check_all_services_status.sh`

| Deprecated Script | Replacement Command |
|-------------------|---------------------|
| `verify_workflow_active.sh` | `bash scripts/diagnose_webhook.sh` (includes workflow check) |
| `verify_webhook_registration.sh` | `bash scripts/test_webhook.sh` |
| `check_workflow_structure.sh` | `bash scripts/diagnose_webhook.sh` (includes structure check) |

## Migration Guide

### Old Way
```bash
# Multiple scripts for similar tasks
bash scripts/inspect_latest_execution.sh
bash scripts/check_execution_nodes.sh
bash scripts/test_webhook_with_message.sh
bash scripts/diagnose_webhook_issue.sh
```

### New Way
```bash
# Consolidated scripts
bash scripts/inspect_execution.sh --latest
bash scripts/inspect_execution.sh --nodes [id]
bash scripts/test_webhook.sh "message"
bash scripts/diagnose_webhook.sh
```

## When Will These Be Removed?

These scripts will be **removed in a future update** after:
1. All documentation is updated
2. All references are migrated
3. Users have had time to adapt

**For now**, they still work but will show deprecation warnings.

## Questions?

If you're not sure which script to use, run:
```bash
bash scripts/diagnose_webhook.sh
```

This comprehensive diagnostic will guide you to the right solution.
