#!/usr/bin/env python3
"""
Enrich Existing Learnings with Missing Metadata

This script:
1. Queries all existing learnings from Noel
2. Analyzes content to suggest dev_stream, tags, and context
3. Updates learnings via the update_learning endpoint
"""

import json
import requests
import re
from typing import Dict, List, Set

# Configuration
WEBHOOK_URL = "https://18f625ebc1f0.ngrok-free.app/webhook/noel"
AUTH_TOKEN = "1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

# Development streams mapping (keywords -> dev_stream)
DEV_STREAM_KEYWORDS = {
    'n8n': ['n8n', 'workflow', 'node', 'execution'],
    'API': ['api', 'endpoint', 'webhook', 'http', 'rest', 'request', 'response'],
    'Database': ['database', 'supabase', 'postgres', 'sql', 'vector', 'pgvector', 'table', 'query'],
    'Backend': ['backend', 'server', 'function', 'rpc'],
    'Frontend': ['frontend', 'ui', 'interface', 'component', 'react'],
    'DevOps': ['ngrok', 'deployment', 'docker', 'environment', 'tunnel'],
    'Architecture': ['architecture', 'pattern', 'design', 'system', 'structure'],
    'Performance': ['performance', 'optimization', 'speed', 'latency'],
    'Security': ['security', 'authentication', 'authorization', 'token', 'auth'],
}

# Common tags mapping
TAG_KEYWORDS = {
    'notion': ['notion', 'database id', 'data source'],
    'supabase': ['supabase', 'pgvector'],
    'openai': ['openai', 'embedding', 'gpt'],
    'vector-search': ['vector', 'embedding', 'similarity', 'semantic'],
    'bash': ['bash', 'shell', 'script'],
    'python': ['python', 'script'],
    'javascript': ['javascript', 'node', 'js'],
    'debugging': ['debug', 'fix', 'error', 'issue', 'problem'],
    'validation': ['validate', 'verification', 'check'],
    'metadata': ['metadata', 'enrichment', 'ai-suggested'],
    'automation': ['automation', 'automatic', 'auto'],
    'patterns': ['pattern', 'best practice', 'anti-pattern'],
}


def query_all_learnings(project: str = "Noel", limit: int = 100) -> List[Dict]:
    """Query all learnings for a project"""
    payload = {
        "endpoint": "query_learnings",
        "query": f"{project} development",
        "filters": {"project": project},
        "limit": limit
    }

    response = requests.post(
        WEBHOOK_URL,
        headers={
            "Content-Type": "application/json",
            "Authorization": AUTH_TOKEN
        },
        json=payload
    )

    response.raise_for_status()
    data = response.json()
    return data[0].get('results', [])


def analyze_content(content: str, title: str) -> Dict[str, any]:
    """Analyze content and suggest metadata"""
    text = (title + " " + content).lower()

    # Suggest dev_stream
    dev_streams = set()
    for stream, keywords in DEV_STREAM_KEYWORDS.items():
        if any(keyword in text for keyword in keywords):
            dev_streams.add(stream)

    # Suggest tags
    tags = set()
    for tag, keywords in TAG_KEYWORDS.items():
        if any(keyword in text for keyword in keywords):
            tags.add(tag)

    # Extract context if present
    context_match = re.search(r'Context:\s*(.+?)(?:\n\n|$)', content, re.DOTALL)
    if context_match:
        context = context_match.group(1).strip()
    else:
        context = ""

    # Try to find file references
    file_refs = re.findall(r'[\w/\-\.]+\.(sh|py|js|json|md|sql|ts|tsx)(?::\d+(?:-\d+)?)?', content)
    related_files = ", ".join(set(file_refs[:5])) if file_refs else ""

    return {
        'dev_stream': sorted(list(dev_streams)),
        'tags': sorted(list(tags)),
        'context': context,
        'related_files': related_files
    }


def update_learning(learning_id: str, updates: Dict) -> bool:
    """Update a learning via the update_learning endpoint"""
    payload = {
        "endpoint": "update_learning",
        "learning_id": learning_id,
        **updates
    }

    # Only include non-empty updates
    payload = {k: v for k, v in payload.items() if v}

    response = requests.post(
        WEBHOOK_URL,
        headers={
            "Content-Type": "application/json",
            "Authorization": AUTH_TOKEN
        },
        json=payload
    )

    try:
        response.raise_for_status()
        data = response.json()
        return data[0].get('success', False)
    except Exception as e:
        print(f"Error updating {learning_id}: {e}")
        return False


def main():
    print("🔍 Fetching all learnings from Noel...")
    learnings = query_all_learnings()
    print(f"Found {len(learnings)} learnings\n")

    needs_update = []

    # Analyze which learnings need updates
    for learning in learnings:
        learning_id = learning.get('learning_id', '')
        content = learning.get('content', '')
        metadata = learning.get('metadata', {})

        tags = metadata.get('tags', [])
        dev_stream = metadata.get('dev_stream', [])

        # Check if fields are empty
        if not tags or not dev_stream:
            needs_update.append({
                'learning_id': learning_id,
                'content': content,
                'current_tags': tags,
                'current_dev_stream': dev_stream
            })

    print(f"📊 Analysis: {len(needs_update)}/{len(learnings)} learnings need metadata enrichment\n")

    if not needs_update:
        print("✅ All learnings already have complete metadata!")
        return

    # Process updates
    updated_count = 0
    failed_count = 0

    for item in needs_update:
        learning_id = item['learning_id']

        # Analyze content to suggest metadata
        suggestions = analyze_content(item['content'], learning_id)

        # Only update empty fields
        updates = {}

        if not item['current_dev_stream'] and suggestions['dev_stream']:
            updates['dev_stream'] = suggestions['dev_stream']

        if not item['current_tags'] and suggestions['tags']:
            updates['tags'] = suggestions['tags']

        # Always try to add context and related_files if found
        if suggestions['context']:
            updates['context'] = suggestions['context']

        if suggestions['related_files']:
            updates['related_files'] = suggestions['related_files']

        if not updates:
            print(f"⏭️  Skipping {learning_id[:50]}... (no new metadata)")
            continue

        # Update the learning
        print(f"🔄 Updating: {learning_id[:60]}...")
        print(f"   + Dev Stream: {updates.get('dev_stream', [])}")
        print(f"   + Tags: {updates.get('tags', [])}")
        if updates.get('context'):
            print(f"   + Context: {updates['context'][:60]}...")
        if updates.get('related_files'):
            print(f"   + Files: {updates['related_files'][:60]}...")

        success = update_learning(learning_id, updates)

        if success:
            print(f"   ✅ Updated successfully\n")
            updated_count += 1
        else:
            print(f"   ❌ Failed to update\n")
            failed_count += 1

    # Summary
    print("━" * 60)
    print(f"✅ Updated: {updated_count}")
    print(f"❌ Failed: {failed_count}")
    print(f"⏭️  Skipped: {len(needs_update) - updated_count - failed_count}")
    print(f"📊 Total processed: {len(needs_update)}")
    print("━" * 60)


if __name__ == "__main__":
    main()
