#!/usr/bin/env python3
"""
Test full cycle: Delete old data, create new learnings, test retrieval
"""
import os
import requests
import json
from datetime import datetime

# Configuration
WEBHOOK_URL = "https://272485010cfe.ngrok-free.app/webhook/noel"
AUTH_TOKEN = "1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"
SUPABASE_URL = "https://sladetzgpogodrqwfamy.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsYWRldHpncG9nb2RycXdmYW15Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU0NjEwNDcsImV4cCI6MjA2MTAzNzA0N30.0lgfAKOCwRHSKI5NjhIQz-nAh0ej44N6AZbHlo8WzAE"

headers = {
    "Content-Type": "application/json",
    "Authorization": AUTH_TOKEN
}

supabase_headers = {
    "apikey": SUPABASE_KEY,
    "Content-Type": "application/json"
}

print("=" * 60)
print("STEP 1: Check current learnings_vectors data")
print("=" * 60)

# Check current data
response = requests.get(
    f"{SUPABASE_URL}/rest/v1/learnings_vectors",
    headers=supabase_headers,
    params={"select": "learning_id,content,created_at", "order": "created_at.desc", "limit": 10}
)
print(f"Status: {response.status_code}")
current_data = response.json()
print(f"Current records: {len(current_data)}")
for record in current_data:
    print(f"  - {record['learning_id']}: {record['content'][:50]}...")

print("\n" + "=" * 60)
print("STEP 2: Delete ALL existing learnings_vectors")
print("=" * 60)

# Delete all records
response = requests.delete(
    f"{SUPABASE_URL}/rest/v1/learnings_vectors",
    headers={**supabase_headers, "Prefer": "return=representation"},
    params={"learning_id": "neq.XXXXX"}  # This will match all records
)
print(f"Status: {response.status_code}")
if response.status_code == 200:
    deleted = response.json()
    print(f"✓ Deleted {len(deleted)} records")
else:
    print(f"Error: {response.text}")

print("\n" + "=" * 60)
print("STEP 3: Create fresh learnings through API")
print("=" * 60)

test_learnings = [
    {
        "project": "Noel_Test",
        "title": "Testing Vector Storage",
        "content": "This learning tests how vector embeddings are stored in Supabase using the pgvector extension.",
        "dev_stream": "Backend",
        "impact": "Enables semantic search for learnings"
    },
    {
        "project": "Noel_Test",
        "title": "n8n Workflow Debugging",
        "content": "When debugging n8n workflows, use execution logs to see exactly where nodes stop executing.",
        "dev_stream": "DevOps",
        "impact": "Faster debugging of workflow issues"
    },
    {
        "project": "Noel_Test",
        "title": "PostgreSQL Vector Types",
        "content": "PostgreSQL vector columns require plain array strings [1,2,3] not JSON-quoted strings.",
        "dev_stream": "Database",
        "impact": "Critical for vector similarity search to work"
    }
]

created_ids = []
for i, learning in enumerate(test_learnings, 1):
    print(f"\n{i}. Creating: {learning['title']}")

    payload = {
        "endpoint": "capture_learning",
        **learning
    }

    response = requests.post(WEBHOOK_URL, headers=headers, json=payload)
    print(f"   Status: {response.status_code}")

    if response.status_code == 200:
        result = response.json()
        # Handle both list and dict responses
        if isinstance(result, list) and len(result) > 0:
            result = result[0]

        if isinstance(result, dict) and result.get("success"):
            learning_id = result.get("learning_id")
            created_ids.append(learning_id)
            print(f"   ✓ Created: {learning_id}")
        else:
            print(f"   Response: {result}")
    else:
        print(f"   Error: {response.text}")

print("\n" + "=" * 60)
print("STEP 4: Verify embeddings were created")
print("=" * 60)

# Wait a moment for embeddings to be processed
import time
time.sleep(2)

response = requests.get(
    f"{SUPABASE_URL}/rest/v1/learnings_vectors",
    headers=supabase_headers,
    params={"select": "learning_id,content", "order": "created_at.desc"}
)
embeddings_data = response.json()
print(f"Embeddings count: {len(embeddings_data)}")
for record in embeddings_data:
    print(f"  - {record['learning_id']}: {record['content'][:50]}...")

print("\n" + "=" * 60)
print("STEP 5: Test query_learnings (semantic search)")
print("=" * 60)

test_queries = [
    "How do I store vectors in PostgreSQL?",
    "Debugging n8n workflows",
    "Vector embeddings"
]

for query in test_queries:
    print(f"\nQuery: '{query}'")

    payload = {
        "endpoint": "query_learnings",
        "query": query,
        "limit": 3
    }

    response = requests.post(WEBHOOK_URL, headers=headers, json=payload)
    print(f"Status: {response.status_code}")

    if response.status_code == 200:
        result = response.json()
        # Handle both list and dict responses
        if isinstance(result, list) and len(result) > 0:
            result = result[0]

        if isinstance(result, dict) and result.get("success"):
            results = result.get("results", [])
            print(f"✓ Found {len(results)} results")
            for r in results:
                print(f"  - {r.get('learning_id')}: {r.get('title')} (similarity: {r.get('similarity', 'N/A')})")
        else:
            print(f"Response: {result}")
    else:
        print(f"Error: {response.text}")

print("\n" + "=" * 60)
print("FULL CYCLE TEST COMPLETE")
print("=" * 60)
