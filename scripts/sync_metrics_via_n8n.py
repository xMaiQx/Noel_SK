#!/usr/bin/env python3
"""
Sync Learning Metrics via n8n Webhook

Fetches usage metrics from Supabase and updates Notion via n8n webhook.
This approach uses n8n's stored Notion credentials, no separate NOTION_TOKEN needed.

Usage:
    python3 scripts/sync_metrics_via_n8n.py [learning_id]
"""

import os
import sys
import requests
from typing import Optional, Dict, List

# Configuration
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://sladetzgpogodrqwfamy.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY")
NGROK_URL = os.getenv("NGROK_URL", "https://18f625ebc1f0.ngrok-free.app")
AUTH_TOKEN = os.getenv("AUTH_TOKEN", "1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6")

# Colors
GREEN = '\033[0;32m'
BLUE = '\033[0;34m'
YELLOW = '\033[1;33m'
RED = '\033[0;31m'
NC = '\033[0m'

def fetch_learning_metrics(learning_id: Optional[str] = None) -> List[Dict]:
    """Fetch metrics from Supabase"""
    print(f"{BLUE}Fetching metrics from Supabase...{NC}")

    url = f"{SUPABASE_URL}/rest/v1/rpc/get_learning_metrics"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "p_learning_id": learning_id,
        "p_min_usage_count": 1,
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

def update_notion_via_n8n(learning_id: str, metrics: Dict) -> bool:
    """Update Notion learning via n8n webhook"""

    url = f"{NGROK_URL}/webhook/noel"
    headers = {
        "Content-Type": "application/json",
        "Authorization": AUTH_TOKEN
    }

    # Prepare update payload
    payload = {
        "endpoint": "update_learning",
        "learning_id": learning_id,
        "Usage Count": int(metrics["total_uses"]),
        "Helpful Rate": float(metrics["helpful_rate"]),
        "Success Rate": float(metrics["success_rate"]),
        "Effectiveness Score": float(metrics["effectiveness_score"])
    }

    # Add Last Used if available
    if metrics.get("last_used"):
        payload["Last Used"] = metrics["last_used"]

    response = requests.post(url, headers=headers, json=payload)

    if response.status_code != 200:
        print(f"{RED}Error updating via n8n: {response.text}{NC}")
        return False

    return True

def sync_learning(learning_id: str, metrics: Dict) -> bool:
    """Sync a single learning's metrics"""
    print(f"\n{BLUE}Syncing {learning_id}...{NC}")

    if update_notion_via_n8n(learning_id, metrics):
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
    print(f"{BLUE}Sync Learning Metrics: Supabase → n8n → Notion{NC}")
    print(f"{BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{NC}")

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
