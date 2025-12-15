#!/usr/bin/env python3
"""
Fix embedding format in Noel workflow
Updates the Prepare Supabase Insert node to convert embeddings properly
"""

import json
from pathlib import Path

# Load workflow
workflow_path = Path(__file__).parent / 'n8n-workflows/noel_knowledge_repository.json'
with open(workflow_path, 'r') as f:
    workflow = json.load(f)

# Find and update the "Prepare Supabase Insert" node
for node in workflow['nodes']:
    if node['name'] == 'Prepare Supabase Insert':
        print(f"Found node: {node['name']}")

        # Update the jsCode to fix embedding format
        node['parameters']['jsCode'] = '''// Prepare Supabase insert
const embeddingData = $('Prepare Embedding Data').first().json;
const embeddingResponse = $input.first().json;

const embedding = embeddingResponse.data[0].embedding;

// Convert embedding array to proper format for Supabase vector type
const embeddingStr = `[${embedding.join(',')}]`;

return [{
    json: {
        learning_id: embeddingData.learning_id,
        content: embeddingData.content,
        embedding: embeddingStr,
        metadata: embeddingData.metadata,
        notion_response: embeddingData.notion_response
    }
}];'''

        print("✓ Updated Prepare Supabase Insert node")
        break

# Save updated workflow
with open(workflow_path, 'w') as f:
    json.dump(workflow, f, indent=2)

print(f"✓ Workflow saved to {workflow_path}")
print("\nNext step: Upload to n8n using:")
print("python3 .claude/skills/n8n-management/scripts/n8n_api.py update-workflow vZSgaLE6I6VK4K6N n8n-workflows/noel_knowledge_repository.json")
