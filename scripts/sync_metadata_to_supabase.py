#!/usr/bin/env python3
"""
Sync Notion Metadata to Supabase Vectors

The update_learning endpoint updates Notion but doesn't regenerate
Supabase vector metadata. This script syncs metadata from Notion to Supabase.
"""

import json
import requests
from typing import Dict, List

# Configuration
WEBHOOK_URL = "https://18f625ebc1f0.ngrok-free.app/webhook/noel"
AUTH_TOKEN = "1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"
SUPABASE_URL = "https://sladetzgpogodrqwfamy.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsYWRldHpncG9nb2RycXdmYW15Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQyMjk0MjEsImV4cCI6MjA0OTgwNTQyMX0.TYe5B5VH1nzJmBmIztqC6bX8N6BzGf9cMjFlRcRLzWY"


def query_all_learnings(project: str = "Noel") -> List[Dict]:
    """Query all learnings"""
    payload = {
        "endpoint": "query_learnings",
        "query": f"{project} development",
        "filters": {"project": project},
        "limit": 100
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


def get_supabase_vector(learning_id: str) -> Dict:
    """Get vector record from Supabase"""
    response = requests.get(
        f"{SUPABASE_URL}/rest/v1/learnings_vectors",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json"
        },
        params={
            "learning_id": f"eq.{learning_id}",
            "select": "id,learning_id,metadata"
        }
    )

    response.raise_for_status()
    results = response.json()
    return results[0] if results else None


def update_supabase_metadata(vector_id: str, metadata: Dict) -> bool:
    """Update metadata in Supabase vector"""
    response = requests.patch(
        f"{SUPABASE_URL}/rest/v1/learnings_vectors",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal"
        },
        params={"id": f"eq.{vector_id}"},
        json={"metadata": metadata}
    )

    return response.status_code in [200, 204]


def main():
    print("🔍 Fetching all learnings from Noel...")
    learnings = query_all_learnings()
    print(f"Found {len(learnings)} learnings\n")

    updated_count = 0
    failed_count = 0
    skipped_count = 0

    for learning in learnings:
        learning_id = learning.get('learning_id', '')
        current_metadata = learning.get('metadata', {})

        print(f"🔄 Syncing: {learning_id[:60]}...")

        # Get Supabase vector
        vector = get_supabase_vector(learning_id)

        if not vector:
            print(f"   ⚠️  No vector found in Supabase, skipping")
            skipped_count += 1
            continue

        # Compare metadata
        supabase_metadata = vector.get('metadata', {})

        # Check if update needed
        needs_update = (
            current_metadata.get('tags', []) != supabase_metadata.get('tags', []) or
            current_metadata.get('dev_stream', []) != supabase_metadata.get('dev_stream', [])
        )

        if not needs_update:
            print(f"   ✓ Metadata already in sync")
            skipped_count += 1
            continue

        # Update Supabase with current metadata
        success = update_supabase_metadata(vector['id'], current_metadata)

        if success:
            print(f"   ✅ Metadata synced to Supabase")
            print(f"      Tags: {current_metadata.get('tags', [])}")
            print(f"      Dev Stream: {current_metadata.get('dev_stream', [])}")
            updated_count += 1
        else:
            print(f"   ❌ Failed to update Supabase")
            failed_count += 1

        print()

    # Summary
    print("━" * 60)
    print(f"✅ Updated: {updated_count}")
    print(f"❌ Failed: {failed_count}")
    print(f"⏭️  Skipped: {skipped_count}")
    print(f"📊 Total: {len(learnings)}")
    print("━" * 60)


if __name__ == "__main__":
    main()
