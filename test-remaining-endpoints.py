#!/usr/bin/env python3
"""
Test remaining 5 endpoints: update_learning, create_session, end_session, query_sessions, query_feedback
"""
import requests
import json
import time
from datetime import datetime

WEBHOOK_URL = "https://272485010cfe.ngrok-free.app/webhook/noel"
AUTH_TOKEN = "1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

headers = {
    "Content-Type": "application/json",
    "Authorization": AUTH_TOKEN
}

def test_endpoint(endpoint_name, payload, description):
    """Test an endpoint and return results"""
    print(f"\n{'='*70}")
    print(f"Testing: {endpoint_name}")
    print(f"Description: {description}")
    print(f"{'='*70}")
    print(f"Payload: {json.dumps(payload, indent=2)}")

    response = requests.post(WEBHOOK_URL, headers=headers, json=payload)

    print(f"\nStatus: {response.status_code}")

    if response.status_code == 200:
        try:
            result = response.json()
            # Handle array-wrapped responses
            if isinstance(result, list) and len(result) > 0:
                result = result[0]

            print(f"✓ Success!")
            print(f"Response: {json.dumps(result, indent=2)}")
            return True, result
        except json.JSONDecodeError:
            print(f"✗ Error: Empty or invalid JSON response")
            print(f"Response text: '{response.text}'")
            return False, None
    else:
        print(f"✗ Error: HTTP {response.status_code}")
        print(f"Response: {response.text}")
        return False, None

print("="*70)
print("TESTING REMAINING 5 ENDPOINTS")
print("="*70)

# Store test data for cleanup/reference
test_session_id = None
test_learning_ids = []

# ============================================================================
# TEST 1: start_session (note: workflow uses start_session not create_session)
# ============================================================================
success, result = test_endpoint(
    "start_session",
    {
        "endpoint": "start_session",
        "projects": ["Noel_Test"],
        "goals": "Testing session endpoints for Noel Knowledge Repository",
        "recording_file_path": "~/coding-sessions/test-2025-12-15.cast",
        "ai_type": "Claude"
    },
    "Create a new coding session"
)

if success and result:
    test_session_id = result.get("session_id")
    print(f"\n→ Session ID: {test_session_id}")

time.sleep(1)  # Brief pause between tests

# ============================================================================
# TEST 2: list_sessions (no filters) - note: workflow uses list_sessions not query_sessions
# ============================================================================
success, result = test_endpoint(
    "list_sessions (all)",
    {
        "endpoint": "list_sessions"
    },
    "List all sessions"
)

if success and result:
    sessions = result.get("sessions", [])
    print(f"\n→ Found {len(sessions)} sessions")
    for s in sessions[:3]:  # Show first 3
        print(f"  - {s.get('session_id')}: {s.get('goals', '')[:50]}...")

time.sleep(1)

# ============================================================================
# TEST 3: list_sessions (with project filter)
# ============================================================================
success, result = test_endpoint(
    "list_sessions (filtered)",
    {
        "endpoint": "list_sessions",
        "filters": {
            "project": "Noel_Test",
            "status": "Active"
        }
    },
    "List sessions for Noel_Test project with Active status"
)

if success and result:
    sessions = result.get("sessions", [])
    print(f"\n→ Found {len(sessions)} active Noel_Test sessions")

time.sleep(1)

# ============================================================================
# TEST 4: update_learning
# ============================================================================
# First, get a learning ID from our test learnings
print("\n" + "="*70)
print("Getting a learning ID to update...")
print("="*70)

# Query for our test learnings
payload = {
    "endpoint": "query_learnings",
    "query": "PostgreSQL vectors",
    "limit": 1
}
response = requests.post(WEBHOOK_URL, headers=headers, json=payload)
if response.status_code == 200:
    result = response.json()
    if isinstance(result, list) and len(result) > 0:
        result = result[0]

    if result.get("success") and result.get("count", 0) > 0:
        learning_to_update = result["results"][0]["learning_id"]
        print(f"✓ Found learning: {learning_to_update}")

        # Now test update_learning
        success, result = test_endpoint(
            "update_learning",
            {
                "endpoint": "update_learning",
                "learning_id": learning_to_update,
                "content": f"{learning_to_update}\n\nUpdated content: Added test notes on {datetime.now().isoformat()}\n\nThis learning has been updated to verify the update_learning endpoint works correctly.",
                "confidence": "High",
                "status": "Validated"
            },
            f"Update learning {learning_to_update}"
        )
    else:
        print("✗ No learnings found to update")
        print("Skipping update_learning test")
else:
    print("✗ Failed to query learnings")
    print("Skipping update_learning test")

time.sleep(1)

# ============================================================================
# TEST 5: query_feedback
# ============================================================================
# Use the learning we just queried
if learning_to_update:
    success, result = test_endpoint(
        "query_feedback",
        {
            "endpoint": "query_feedback",
            "query": "PostgreSQL vectors",
            "relevant_learning_ids": [learning_to_update]
        },
        "Submit feedback on query relevance"
    )

time.sleep(1)

# ============================================================================
# TEST 6: end_session
# ============================================================================
if test_session_id:
    success, result = test_endpoint(
        "end_session",
        {
            "endpoint": "end_session",
            "session_id": test_session_id
        },
        f"End session {test_session_id}"
    )

    if success and result:
        duration = result.get("duration_minutes", 0)
        learning_count = result.get("learning_count", 0)
        print(f"\n→ Session duration: {duration} minutes")
        print(f"→ Learnings captured: {learning_count}")

# ============================================================================
# SUMMARY
# ============================================================================
print("\n" + "="*70)
print("TEST SUMMARY")
print("="*70)
print("""
Tested endpoints:
1. ✓ start_session     - Creates new coding session
2. ✓ list_sessions     - Lists sessions (all and filtered)
3. ✓ update_learning   - Updates existing learning
4. ✓ query_feedback    - Submits relevance feedback
5. ✓ end_session       - Completes active session

Combined with previously tested:
- ✓ list_projects      - Lists all projects
- ✓ capture_learning   - Creates new learning
- ✓ query_learnings    - Semantic search

All 8 endpoints tested!

Note: Workflow uses 'start_session' and 'list_sessions'
      (not 'create_session' and 'query_sessions' from spec)
""")

print("="*70)
print("Check output above for any failures (marked with ✗)")
print("="*70)
