#!/usr/bin/env python3
"""
Sync Learning Metrics from Supabase to Notion

Fetches usage metrics from Supabase learning_metrics view and updates
corresponding Notion learnings with:
- Usage Count
- Helpful Rate
- Success Rate
- Last Used
- Effectiveness Score

Usage:
    python3 scripts/sync_learning_metrics.py [learning_id]

    If learning_id is provided, syncs only that learning.
    Otherwise, syncs all learnings with usage data.
"""

import os
import sys
import json
import requests
from datetime import datetime
from typing import Optional, Dict, List

# Configuration from environment
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://sladetzgpogodrqwfamy.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY")
NOTION_TOKEN = os.getenv("NOTION_TOKEN")
NOTION_LEARNINGS_DB = os.getenv("NOTION_LEARNINGS_DB")

# Colors for output
GREEN = '\033[0;32m'
BLUE = '\033[0;34m'
YELLOW = '\033[1;33m'
RED = '\033[0;31m'
NC = '\033[0m'

def fetch_learning_metrics(learning_id: Optional[str] = None) -> List[Dict]:
    """
    Fetch metrics from Supabase learning_metrics view.

    Args:
        learning_id: Optional specific learning ID to fetch

    Returns:
        List of metric dictionaries
    """
    print(f"{BLUE}Fetching metrics from Supabase...{NC}")

    # Use the get_learning_metrics RPC function
    url = f"{SUPABASE_URL}/rest/v1/rpc/get_learning_metrics"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "p_learning_id": learning_id,
        "p_min_usage_count": 1,  # Only fetch learnings that have been used
        "p_sort_by": "effectiveness_score",
        "p_limit": 1000
    }

    response = requests.post(url, headers=headers, json=payload)

    if response.status_code != 200:
        print(f"{RED}Error fetching metrics: {response.text}{NC}")
        return []

    metrics = response.json()
    print(f"{GREEN}✓{NC} Found {len(metrics)} learnings with usage data")
    return metrics

def get_notion_page_id(learning_id: str) -> Optional[str]:
    """
    Find the Notion page ID for a given learning ID.

    Args:
        learning_id: The learning ID to search for

    Returns:
        Notion page ID or None if not found
    """
    url = f"https://api.notion.com/v1/databases/{NOTION_LEARNINGS_DB}/query"
    headers = {
        "Authorization": f"Bearer {NOTION_TOKEN}",
        "Notion-Version": "2022-06-28",
        "Content-Type": "application/json"
    }

    # Search for learning by Learning ID property
    payload = {
        "filter": {
            "property": "Learning ID",
            "rich_text": {
                "equals": learning_id
            }
        }
    }

    response = requests.post(url, headers=headers, json=payload)

    if response.status_code != 200:
        print(f"{RED}Error querying Notion: {response.text}{NC}")
        return None

    results = response.json().get("results", [])
    if not results:
        return None

    return results[0]["id"]

def update_notion_learning(page_id: str, metrics: Dict) -> bool:
    """
    Update Notion learning with usage metrics.

    Args:
        page_id: Notion page ID
        metrics: Dictionary with metrics data

    Returns:
        True if successful, False otherwise
    """
    url = f"https://api.notion.com/v1/pages/{page_id}"
    headers = {
        "Authorization": f"Bearer {NOTION_TOKEN}",
        "Notion-Version": "2022-06-28",
        "Content-Type": "application/json"
    }

    # Prepare properties update
    properties = {
        "Usage Count": {
            "number": int(metrics["total_uses"])
        },
        "Helpful Rate": {
            "number": float(metrics["helpful_rate"])
        },
        "Success Rate": {
            "number": float(metrics["success_rate"])
        },
        "Effectiveness Score": {
            "number": float(metrics["effectiveness_score"])
        }
    }

    # Add Last Used date if available
    if metrics.get("last_used"):
        # Convert timestamp to ISO format
        last_used = metrics["last_used"]
        if isinstance(last_used, str):
            # Parse and convert to ISO format
            dt = datetime.fromisoformat(last_used.replace('Z', '+00:00'))
            properties["Last Used"] = {
                "date": {
                    "start": dt.isoformat()
                }
            }

    payload = {"properties": properties}

    response = requests.patch(url, headers=headers, json=payload)

    if response.status_code != 200:
        print(f"{RED}Error updating Notion: {response.text}{NC}")
        return False

    return True

def sync_learning(learning_id: str, metrics: Dict) -> bool:
    """
    Sync a single learning's metrics to Notion.

    Args:
        learning_id: The learning ID
        metrics: Metrics dictionary from Supabase

    Returns:
        True if successful, False otherwise
    """
    print(f"\n{BLUE}Syncing {learning_id}...{NC}")

    # Get Notion page ID
    page_id = get_notion_page_id(learning_id)
    if not page_id:
        print(f"{YELLOW}⚠ Learning not found in Notion{NC}")
        return False

    # Update Notion
    if update_notion_learning(page_id, metrics):
        print(f"{GREEN}✓{NC} Synced metrics:")
        print(f"  Usage Count: {metrics['total_uses']}")
        print(f"  Helpful Rate: {metrics['helpful_rate']}%")
        print(f"  Success Rate: {metrics['success_rate']}%")
        print(f"  Effectiveness Score: {metrics['effectiveness_score']}")
        print(f"  Last Used: {metrics.get('last_used', 'N/A')}")
        return True

    return False

def main():
    """Main sync process"""
    print(f"{BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{NC}")
    print(f"{BLUE}Sync Learning Metrics: Supabase → Notion{NC}")
    print(f"{BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{NC}")

    # Check required environment variables
    if not all([SUPABASE_KEY, NOTION_TOKEN, NOTION_LEARNINGS_DB]):
        print(f"{RED}Error: Missing required environment variables{NC}")
        print("Required: SUPABASE_ANON_KEY, NOTION_TOKEN, NOTION_LEARNINGS_DB")
        print("Load them with: source .env")
        sys.exit(1)

    # Get optional learning ID from command line
    learning_id = sys.argv[1] if len(sys.argv) > 1 else None

    if learning_id:
        print(f"Syncing single learning: {learning_id}\n")
    else:
        print("Syncing all learnings with usage data\n")

    # Fetch metrics from Supabase
    metrics_list = fetch_learning_metrics(learning_id)

    if not metrics_list:
        print(f"\n{YELLOW}No learnings with usage data found{NC}")
        sys.exit(0)

    # Sync each learning
    success_count = 0
    fail_count = 0

    for metrics in metrics_list:
        lid = metrics["learning_id"]
        if sync_learning(lid, metrics):
            success_count += 1
        else:
            fail_count += 1

    # Summary
    print(f"\n{BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{NC}")
    if fail_count == 0:
        print(f"{GREEN}✅ All learnings synced successfully!{NC}")
    else:
        print(f"{YELLOW}⚠ Completed with some errors{NC}")

    print(f"\nResults:")
    print(f"  {GREEN}✓{NC} Synced: {success_count}")
    print(f"  {RED}✗{NC} Failed: {fail_count}")
    print(f"{BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{NC}\n")

if __name__ == "__main__":
    main()
