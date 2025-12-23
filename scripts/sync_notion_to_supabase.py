#!/usr/bin/env python3
"""
Sync Notion Metadata to Supabase Vectors

After enriching learnings in Notion, this script updates the corresponding
Supabase vector records with the current Notion metadata.
"""

import json
import os
import requests
from typing import Dict, List

# Load from .env
WEBHOOK_URL = "https://18f625ebc1f0.ngrok-free.app/webhook/noel"
AUTH_TOKEN = "1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"
SUPABASE_URL = "https://sladetzgpogodrqwfamy.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsYWRldHpncG9nb2RycXdmYW15Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU0NjEwNDcsImV4cCI6MjA2MTAzNzA0N30.0lgfAKOCwRHSKI5NjhIQz-nAh0ej44N6AZbHlo8WzAE"

def get_notion_learning_metadata(learning_id: str) -> Dict:
    """Get full metadata from Notion for a learning"""
    # Use Noel API to query the specific learning
    payload = {
        "endpoint": "query_learnings",
        "query": learning_id,
        "limit": 1
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
    results = data[0].get('results', [])

    if not results:
        return None

    # The metadata from query comes from Supabase, so we need to get it from Notion directly
    # For now, just trigger re-enrichment via the enrichment script
    return results[0].get('metadata', {})


def update_supabase_metadata_direct(learning_id: str, new_metadata: Dict) -> bool:
    """Update Supabase vector metadata directly"""
    # First, get the vector ID
    get_response = requests.get(
        f"{SUPABASE_URL}/rest/v1/learnings_vectors",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}"
        },
        params={
            "learning_id": f"eq.{learning_id}",
            "select": "id"
        }
    )

    if get_response.status_code != 200:
        return False

    records = get_response.json()
    if not records:
        return False

    # Update the metadata
    update_response = requests.patch(
        f"{SUPABASE_URL}/rest/v1/learnings_vectors",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal"
        },
        params={"id": f"eq.{records[0]['id']}"},
        json={"metadata": new_metadata}
    )

    return update_response.status_code in [200, 204]


def main():
    print("🔄 Syncing enriched metadata from Notion to Supabase...")
    print()

    # This is a temporary solution
    # The proper fix is to enhance the n8n update_learning workflow
    # to also update Supabase when metadata changes

    print("⚠️  Note: This is a workaround. The proper solution is to enhance")
    print("   the n8n workflow to update Supabase when update_learning is called.")
    print()

    # For now, just run the enrichment script again
    # which will update Notion (already done) but won't update Supabase automatically

    print("✅ Current status:")
    print("   - Notion learnings: Updated with dev_stream, tags, context, files")
    print("   - Supabase vectors: Still have old metadata (empty arrays)")
    print()
    print("📋 Next steps:")
    print("   1. Enhance n8n update_learning workflow to update Supabase metadata")
    print("   2. OR: Regenerate all embeddings (will update metadata)")
    print("   3. OR: Run direct Supabase UPDATE queries")
    print()


if __name__ == "__main__":
    main()
