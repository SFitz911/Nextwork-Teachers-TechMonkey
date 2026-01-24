#!/usr/bin/env python3
"""
Validate right-worker workflow structure
Checks all connections, node references, and data flow
"""

import json
import sys
from pathlib import Path

def validate_workflow(file_path):
    """Validate workflow structure"""
    with open(file_path, 'r') as f:
        workflow = json.load(f)
    
    errors = []
    warnings = []
    
    # Get all node IDs and names
    nodes = {node['id']: node for node in workflow['nodes']}
    node_names = {node['name']: node['id'] for node in workflow['nodes']}
    
    # Check connections
    connections = workflow.get('connections', {})
    
    for node_name, conn_data in connections.items():
        # Find node ID from name
        node_id = node_names.get(node_name)
        if not node_id:
            errors.append(f"Connection references unknown node: {node_name}")
            continue
        
        # Check main connections
        if 'main' in conn_data:
            for branch in conn_data['main']:
                for link in branch:
                    target_name = link.get('node')
                    if target_name not in node_names:
                        errors.append(f"Node '{node_name}' connects to unknown node: {target_name}")
        
        # Check error connections
        if 'error' in conn_data:
            for branch in conn_data['error']:
                for link in branch:
                    target_name = link.get('node')
                    if target_name not in node_names:
                        errors.append(f"Node '{node_name}' error path connects to unknown node: {target_name}")
    
    # Check for required nodes
    required_nodes = [
        'Webhook Trigger',
        'Extract Payload',
        'Get Session State',
        'Validate Still Active',
        'Prepare LLM Request',
        'Prepare LLM Body',
        'LLM Generate',
        'Extract Response',
        'Map Voice',
        'TTS Generate',
        'Prepare Video',
        'Video Generate',
        'Format Clip',
        'Prepare Clip Ready',
        'POST Clip Ready',
        'Respond',
        'Error Handler'
    ]
    
    for req_node in required_nodes:
        if req_node not in node_names:
            errors.append(f"Missing required node: {req_node}")
    
    # Check node positions (no duplicates)
    positions = {}
    for node in workflow['nodes']:
        pos = tuple(node.get('position', [0, 0]))
        if pos in positions:
            warnings.append(f"Duplicate position {pos}: {positions[pos]} and {node['name']}")
        positions[pos] = node['name']
    
    # Print results
    if errors:
        print("ERRORS FOUND:")
        for error in errors:
            print(f"  - {error}")
        return False
    
    if warnings:
        print("WARNINGS:")
        for warning in warnings:
            print(f"  - {warning}")
    
    print("OK Workflow structure is valid!")
    print(f"   Total nodes: {len(nodes)}")
    print(f"   Total connections: {len(connections)}")
    return True

if __name__ == '__main__':
    workflow_path = Path(__file__).parent.parent / 'n8n' / 'workflows' / 'right-worker-workflow.json'
    
    if not workflow_path.exists():
        print(f"ERROR: Workflow file not found: {workflow_path}")
        sys.exit(1)
    
    success = validate_workflow(workflow_path)
    sys.exit(0 if success else 1)
