#!/usr/bin/env python3
"""
Clean workflow JSON for n8n API import
Removes fields that n8n API doesn't accept
"""
import json
import sys

if len(sys.argv) < 3:
    print("Usage: python3 prepare_workflow_for_import.py <input_file> <output_file>")
    sys.exit(1)

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'r') as f:
    workflow = json.load(f)

# Keep only fields that n8n API accepts for import
cleaned = {
    "name": workflow.get("name", ""),
    "nodes": workflow.get("nodes", []),
    "connections": workflow.get("connections", {}),
    "settings": workflow.get("settings", {}),
    "staticData": workflow.get("staticData", {}),
    "tags": workflow.get("tags", []),
}

# Remove fields that cause API errors
# n8n API doesn't accept: id, updatedAt, createdAt, versionId, triggerCount, pinData

with open(output_file, 'w') as f:
    json.dump(cleaned, f, indent=2)

print(f"✅ Cleaned workflow saved to {output_file}")
