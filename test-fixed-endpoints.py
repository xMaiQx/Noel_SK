#!/usr/bin/env python3
"""
Test the fixed endpoints: query_feedback and update_learning
"""
import requests
import json

WEBHOOK_URL = "https://272485010cfe.ngrok-free.app/webhook/noel"
AUTH_TOKEN = "1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

headers = {
    "Content-Type": "application/json",
    "Authorization": AUTH_TOKEN
}

print("="*70)
print("TESTING FIXED ENDPOINTS")
print("="*70)

# Test 1: query_feedback
print("\n" + "="*70)
print("TEST 1: query_feedback")
print("="*70)

payload = {
    "endpoint": "query_feedback",
    "query": "PostgreSQL vector storage",
    "relevant_learning_ids": ["PostgreSQL Vector Types", "Testing Vector Storage"]
}

print(f"Request: {json.dumps(payload, indent=2)}")

response = requests.post(WEBHOOK_URL, headers=headers, json=payload)
print(f"\nStatus: {response.status_code}")

if response.status_code == 200:
    try:
        result = response.json()
        if isinstance(result, list) and len(result) > 0:
            result = result[0]
        print(f"✓ Response: {json.dumps(result, indent=2)}")

        if result.get("success"):
            print("\n✅ query_feedback is FIXED!")
        else:
            print(f"\n❌ Still failing: {result.get('error')}")
    except json.JSONDecodeError:
        print(f"✗ Empty response: '{response.text}'")
else:
    print(f"✗ Error: {response.text}")

# Test 2: update_learning
print("\n" + "="*70)
print("TEST 2: update_learning")
print("="*70)

# First get a real learning ID from Notion
print("Getting a valid learning ID from list_projects...")
list_response = requests.post(
    WEBHOOK_URL,
    headers=headers,
    json={"endpoint": "query_learnings", "query": "vector", "limit": 1}
)

learning_id = None
if list_response.status_code == 200:
    try:
        result = list_response.json()
        if isinstance(result, list):
            result = result[0]
        if result.get("success") and result.get("count", 0) > 0:
            learning_id = result["results"][0]["learning_id"]
            print(f"Found learning: {learning_id}")
    except:
        pass

if not learning_id:
    print("⚠️  Could not find a learning to update. Skipping update test.")
else:
    payload = {
        "endpoint": "update_learning",
        "learning_id": learning_id,
        "content": f"Updated via API test at {json.dumps({'test': True})}",
        "confidence": "High"
    }

    print(f"\nRequest: {json.dumps(payload, indent=2)}")

    response = requests.post(WEBHOOK_URL, headers=headers, json=payload)
    print(f"\nStatus: {response.status_code}")

    if response.status_code == 200:
        try:
            result = response.json()
            if isinstance(result, list) and len(result) > 0:
                result = result[0]
            print(f"Response: {json.dumps(result, indent=2)}")

            if result.get("success"):
                print("\n✅ update_learning is FIXED!")
            else:
                print(f"\n❌ Still failing: {result.get('error')}")
        except json.JSONDecodeError:
            print(f"✗ Empty response: '{response.text}'")
    else:
        print(f"✗ Error: {response.text}")

print("\n" + "="*70)
print("TEST SUMMARY")
print("="*70)
print("""
1. query_feedback - Should now return success (without storing to Supabase yet)
2. update_learning - Needs valid learning_id that matches Notion page title

Next: Add HTTP Request node for actual query_feedback storage
""")
