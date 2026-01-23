#!/usr/bin/env bash
# Verify teacher IDs are strings in the workflow
# Usage: bash scripts/verify_workflow_teacher_ids.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

WORKFLOW_FILE="n8n/workflows/five-teacher-workflow.json"

echo "=========================================="
echo "Verifying Teacher IDs in Workflow"
echo "=========================================="
echo ""

# Check if workflow file exists
if [[ ! -f "$WORKFLOW_FILE" ]]; then
    echo "❌ Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

echo "Checking teacher ID usage..."
echo ""

# Extract all teacher ID references
echo "1. Teacher IDs in JavaScript code:"
grep -o "'teacher_[a-e]'" "$WORKFLOW_FILE" | sort -u || echo "   No matches found"
echo ""

echo "2. Teacher IDs in strings:"
grep -o "teacher_[a-e]" "$WORKFLOW_FILE" | sort -u || echo "   No matches found"
echo ""

echo "3. Checking for numeric teacher IDs (should be none):"
if grep -E "teacher_[0-9]|teacher_[1-5]" "$WORKFLOW_FILE"; then
    echo "   ⚠️  Found numeric teacher IDs!"
else
    echo "   ✅ No numeric teacher IDs found"
fi
echo ""

echo "4. Verifying teacher IDs are strings (not numbers):"
python3 <<EOF
import json
import sys

with open('$WORKFLOW_FILE', 'r') as f:
    workflow = json.load(f)

errors = []
for node in workflow.get('nodes', []):
    if 'jsCode' in node.get('parameters', {}):
        code = node['parameters']['jsCode']
        # Check for teacher array
        if 'teacher_' in code:
            # Should be strings like 'teacher_a', not numbers
            if 'teacher_0' in code or 'teacher_1' in code:
                errors.append(f"Node {node.get('name', 'unknown')} has numeric teacher IDs")
    
    # Check parameters for teacher references
    params = node.get('parameters', {})
    for key, value in params.items():
        if isinstance(value, str) and 'teacher_' in value:
            if 'teacher_0' in value or 'teacher_1' in value:
                errors.append(f"Node {node.get('name', 'unknown')} parameter {key} has numeric teacher IDs")

if errors:
    print("   ❌ Found issues:")
    for error in errors:
        print(f"      - {error}")
    sys.exit(1)
else:
    print("   ✅ All teacher IDs are strings (teacher_a, teacher_b, etc.)")
EOF

echo ""
echo "5. Checking LongCat-Video service teacher mapping:"
if grep -q "teacher_a\|teacher_b\|teacher_c\|teacher_d\|teacher_e" services/longcat_video/app.py; then
    echo "   ✅ LongCat-Video service has teacher mappings"
else
    echo "   ⚠️  LongCat-Video service teacher mappings not found"
fi

echo ""
echo "=========================================="
echo "Verification Complete"
echo "=========================================="
