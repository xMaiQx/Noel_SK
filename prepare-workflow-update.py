#!/usr/bin/env python3
"""
Prepare workflow for n8n API update (extract only updatable fields)
"""
import json

with open('n8n-workflows/noel_knowledge_repository.json') as f:
    workflow = json.load(f)

# Extract only updatable fields
updatable = {
    "name": workflow["name"],
    "nodes": workflow["nodes"],
    "connections": workflow["connections"],
    "settings": workflow.get("settings", {})
}

# Save to temporary file
with open('/tmp/noel_workflow_update.json', 'w') as f:
    json.dump(updatable, f, indent=2)

print(f"Prepared workflow update:")
print(f"  Name: {updatable['name']}")
print(f"  Nodes: {len(updatable['nodes'])}")
print(f"  Saved to: /tmp/noel_workflow_update.json")
print("\nReady to upload!")
