#!/usr/bin/env python3
"""
Add session lookup logic to capture_learning workflow
Enables users to pass human-readable session_id instead of UUID
"""

import json
import sys
from pathlib import Path

# Paths
workflow_path = Path(__file__).parent.parent / 'n8n-workflows/noel_knowledge_repository.json'

# Load workflow
with open(workflow_path, 'r') as f:
    workflow = json.load(f)

# New nodes to add
new_nodes = [
    {
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": True,
                    "leftValue": "",
                    "typeValidation": "strict"
                },
                "conditions": [
                    {
                        "id": "session_id_exists",
                        "leftValue": "={{ $json.payload.session_id }}",
                        "rightValue": "",
                        "operator": {
                            "type": "string",
                            "operation": "exists",
                            "singleValue": True
                        }
                    }
                ],
                "combinator": "and"
            },
            "options": {}
        },
        "name": "Check Session ID",
        "type": "n8n-nodes-base.if",
        "typeVersion": 2,
        "position": [600, -150]
    },
    {
        "parameters": {
            "jsCode": "// Query Sessions database by Title (human-readable session_id)\nconst payload = $input.first().json.payload;\nconst sessionId = payload.session_id;\n\n// Check if it's already a UUID (skip lookup)\nconst uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;\nif (uuidRegex.test(sessionId)) {\n  // Already a UUID, pass through\n  return [{\n    json: {\n      ...payload,\n      session_page_id: sessionId\n    }\n  }];\n}\n\n// Human-readable ID, need to query\nreturn [{\n  json: {\n    payload: payload,\n    query: {\n      endpoint: 'query_data_source',\n      id: '2b43d603-acb6-8064-82f9-000b343a2e1c'\n    },\n    body: {\n      filter: {\n        property: 'Title',\n        title: {\n          equals: sessionId\n        }\n      },\n      page_size: 1\n    }\n  }\n}];"
        },
        "name": "Prepare Session Query",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [800, -50]
    },
    {
        "parameters": {
            "jsCode": "// Extract session page_id from query result\nconst queryResult = $input.first().json;\nconst originalPayload = $('Prepare Session Query').first().json.payload;\n\nif (!queryResult.results || queryResult.results.length === 0) {\n  throw new Error(`Session not found: ${originalPayload.session_id}`);\n}\n\nconst sessionPageId = queryResult.results[0].id;\n\nreturn [{\n  json: {\n    ...originalPayload,\n    session_page_id: sessionPageId\n  }\n}];"
        },
        "name": "Extract Session UUID",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [1200, -50]
    },
    {
        "parameters": {},
        "name": "Merge Session Data",
        "type": "n8n-nodes-base.merge",
        "typeVersion": 3,
        "position": [1400, -150]
    }
]

# Add new nodes
print(f"Adding {len(new_nodes)} new nodes...")
for node in new_nodes:
    # Check if node already exists
    exists = any(n['name'] == node['name'] for n in workflow['nodes'])
    if not exists:
        workflow['nodes'].append(node)
        print(f"  ✓ Added: {node['name']}")
    else:
        print(f"  ⊗ Already exists: {node['name']}")

# Update connections
print("\nUpdating connections...")

# 1. Route Endpoint -> Check Session ID (output 0 for capture_learning)
if 'Route Endpoint' in workflow['connections']:
    # Keep capture_learning routing but point to Check Session ID instead
    old_target = workflow['connections']['Route Endpoint']['main'][0]
    workflow['connections']['Route Endpoint']['main'][0] = [{'node': 'Check Session ID', 'type': 'main', 'index': 0}]
    print("  ✓ Route Endpoint -> Check Session ID")

# 2. Check Session ID -> Prepare Session Query (true branch)
workflow['connections']['Check Session ID'] = {
    'main': [
        [{'node': 'Prepare Session Query', 'type': 'main', 'index': 0}],  # True: has session_id
        [{'node': 'Capture Learning Logic', 'type': 'main', 'index': 0}]  # False: no session_id
    ]
}
print("  ✓ Check Session ID -> Prepare Session Query (true)")
print("  ✓ Check Session ID -> Capture Learning Logic (false)")

# 3. Prepare Session Query -> Call Notion API Wrapper
workflow['connections']['Prepare Session Query'] = {
    'main': [[{'node': 'Call Notion API Wrapper', 'type': 'main', 'index': 0}]]
}
print("  ✓ Prepare Session Query -> Call Notion API Wrapper")

# 4. Call Notion API Wrapper needs to route to Extract Session UUID for session queries
# This is tricky - we need to identify when it's a session query vs other calls
# For now, we'll add a new dedicated Call node for session lookup

# Actually, let's simplify: use the existing Call Notion API Wrapper but route differently
# We need a dedicated Execute Workflow node for session lookup
print("\n⚠️  Note: Need manual adjustment for routing session query results")

# Save modified workflow
with open(workflow_path, 'w') as f:
    json.dump(workflow, f, indent=2)

print(f"\n✓ Workflow saved to {workflow_path}")
print(f"Total nodes: {len(workflow['nodes'])}")
print("\nNext steps:")
print("1. Open workflow in n8n UI")
print("2. Add 'Execute Workflow' node for session lookup (or use HTTP Request)")
print("3. Connect: Prepare Session Query -> Execute Workflow -> Extract Session UUID")
print("4. Connect: Extract Session UUID -> Merge Session Data")
print("5. Connect: Check Session ID (false) -> Merge Session Data")
print("6. Connect: Merge Session Data -> Capture Learning Logic")
print("7. Update Capture Learning Logic to use session_page_id instead of session_id")
