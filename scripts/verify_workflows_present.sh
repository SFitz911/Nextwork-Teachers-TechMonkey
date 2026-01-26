#!/usr/bin/env bash
# Verify all required n8n workflows are present in the repository
# Usage: bash scripts/verify_workflows_present.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Verifying n8n Workflows in Repository"
echo "=========================================="
echo ""

# Expected workflows (name, file, webhook path)
declare -A EXPECTED_WORKFLOWS=(
    ["Session Start - Fast Webhook"]="session-start-workflow.json|session/start"
    ["Left Worker - Teacher Pipeline"]="left-worker-workflow.json|worker/left/run"
    ["Right Worker - Teacher Pipeline"]="right-worker-workflow.json|worker/right/run"
)

WORKFLOWS_DIR="$PROJECT_DIR/n8n/workflows"
MISSING=0
INVALID=0

echo "Checking workflow files in: $WORKFLOWS_DIR"
echo ""

for workflow_name in "${!EXPECTED_WORKFLOWS[@]}"; do
    IFS='|' read -r filename webhook_path <<< "${EXPECTED_WORKFLOWS[$workflow_name]}"
    filepath="$WORKFLOWS_DIR/$filename"
    
    echo "Checking: $workflow_name"
    echo "  File: $filename"
    echo "  Expected webhook: /webhook/$webhook_path"
    
    # Check if file exists
    if [[ ! -f "$filepath" ]]; then
        echo "  ❌ File NOT FOUND: $filepath"
        MISSING=$((MISSING + 1))
        echo ""
        continue
    fi
    
    # Check if file is valid JSON
    if ! python3 -m json.tool "$filepath" > /dev/null 2>&1; then
        echo "  ❌ Invalid JSON format"
        INVALID=$((INVALID + 1))
        echo ""
        continue
    fi
    
    # Check workflow name matches
    workflow_name_in_file=$(python3 -c "import json, sys; data = json.load(open('$filepath')); print(data.get('name', ''))" 2>/dev/null || echo "")
    if [[ "$workflow_name_in_file" != "$workflow_name" ]]; then
        echo "  ⚠️  Warning: Workflow name mismatch (file: '$workflow_name_in_file', expected: '$workflow_name')"
    fi
    
    # Check webhook path
    webhook_path_in_file=$(python3 -c "
import json, sys
data = json.load(open('$filepath'))
for node in data.get('nodes', []):
    if node.get('type') == 'n8n-nodes-base.webhook':
        path = node.get('parameters', {}).get('path', '')
        if path:
            print(path)
            break
" 2>/dev/null || echo "")
    
    if [[ "$webhook_path_in_file" == "$webhook_path" ]]; then
        echo "  ✅ Webhook path correct: /webhook/$webhook_path_in_file"
    else
        echo "  ⚠️  Warning: Webhook path mismatch (file: '$webhook_path_in_file', expected: '$webhook_path')"
    fi
    
    # Check if workflow has required nodes
    node_count=$(python3 -c "import json, sys; data = json.load(open('$filepath')); print(len(data.get('nodes', [])))" 2>/dev/null || echo "0")
    echo "  ✅ Nodes: $node_count"
    
    # Get file size
    file_size=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null || echo "0")
    echo "  ✅ Size: $file_size bytes"
    
    echo ""
done

echo "=========================================="
if [[ $MISSING -eq 0 && $INVALID -eq 0 ]]; then
    echo "✅ All workflows verified successfully!"
    echo ""
    echo "Summary:"
    echo "  - Total workflows: ${#EXPECTED_WORKFLOWS[@]}"
    echo "  - All files present: ✅"
    echo "  - All files valid JSON: ✅"
    echo ""
    echo "Next steps:"
    echo "  1. Import workflows to n8n: bash scripts/force_reimport_workflows.sh"
    echo "  2. Verify in n8n UI: http://localhost:5678"
    exit 0
else
    echo "❌ Verification failed!"
    echo ""
    echo "Summary:"
    echo "  - Missing files: $MISSING"
    echo "  - Invalid files: $INVALID"
    exit 1
fi
