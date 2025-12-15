#!/usr/bin/env python3
import requests
import json

WEBHOOK_URL = "https://272485010cfe.ngrok-free.app/webhook/noel"
AUTH_TOKEN = "1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

headers = {
    "Content-Type": "application/json",
    "Authorization": AUTH_TOKEN
}

# Query for our session learnings
response = requests.post(
    WEBHOOK_URL,
    headers=headers,
    json={
        "endpoint": "query_learnings",
        "query": "n8n debugging embeddings workflow",
        "limit": 10,
        "project": "Noel_SK"
    }
)

if response.status_code == 200:
    result = response.json()
    if isinstance(result, list):
        result = result[0]

    if result.get("success"):
        count = result.get("count", 0)
        print(f"✓ Found {count} session learnings in Noel!")
        print("\nTop matches:")
        for i, r in enumerate(result.get("results", [])[:6], 1):
            title = r.get("metadata", {}).get("title", "N/A")
            similarity = r.get("similarity", 0)
            print(f"{i}. {title} ({similarity:.1%} match)")
    else:
        print("Query failed:", result)
else:
    print(f"HTTP {response.status_code}: {response.text}")
