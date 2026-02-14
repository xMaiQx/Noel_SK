#!/usr/bin/env python3
"""
Direct RAG query to Noel - Bypass n8n entirely
Usage: python3 noel_query.py "your question here"
"""

import sys
import os
import json
import urllib.request
from pathlib import Path

def load_env():
    env_path = Path(__file__).parent.parent / '.env'
    if env_path.exists():
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    value = value.strip('"').strip("'")
                    if not value.startswith('${'):
                        os.environ[key] = value

load_env()

OPENAI_KEY = os.getenv('OPENAI_API_KEY')
SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://sladetzgpogodrqwfamy.supabase.co')
SUPABASE_KEY = os.getenv('SUPABASE_ANON_KEY')  # Add this to .env

def get_embedding(text):
    """Get embedding from OpenAI"""
    url = "https://api.openai.com/v1/embeddings"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {OPENAI_KEY}"
    }
    data = {
        "input": text,
        "model": "text-embedding-3-small"
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(data).encode('utf-8'),
        headers=headers,
        method='POST'
    )

    with urllib.request.urlopen(req) as response:
        result = json.loads(response.read().decode('utf-8'))
        return result['data'][0]['embedding']

def search_learnings(query, limit=5):
    """Search Noel directly via Supabase"""
    print(f"🔍 Searching for: {query}")

    # Get embedding
    print("  → Getting embedding...")
    embedding = get_embedding(query)

    # Search Supabase
    print("  → Searching Supabase...")
    url = f"{SUPABASE_URL}/rest/v1/rpc/match_learnings"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json"
    }
    data = {
        "query_embedding": embedding,
        "match_count": limit,
        "project_filter": None,
        "similarity_threshold": 0.1
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(data).encode('utf-8'),
        headers=headers,
        method='POST'
    )

    with urllib.request.urlopen(req) as response:
        results = json.loads(response.read().decode('utf-8'))
        return results

def display_results(results):
    """Pretty print results"""
    if not results:
        print("\n❌ No results found")
        return

    print(f"\n✅ Found {len(results)} result(s)\n")
    print("=" * 80)

    for i, result in enumerate(results, 1):
        print(f"\n[{i}] {result.get('learning_id', 'Unknown')}")
        print(f"    Project: {result.get('project_name', 'N/A')}")
        print(f"    Similarity: {result.get('similarity', 0):.3f}")
        print(f"\n    Content:")
        content = result.get('content', '')
        # Show first 300 chars
        if len(content) > 300:
            print(f"    {content[:300]}...")
        else:
            print(f"    {content}")
        print("\n" + "-" * 80)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 noel_query.py 'your question'")
        sys.exit(1)

    query = " ".join(sys.argv[1:])

    try:
        results = search_learnings(query)
        display_results(results)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
