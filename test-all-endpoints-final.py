#!/usr/bin/env python3
"""
Final comprehensive test of all 8 endpoints
"""
import requests
import json
import time

WEBHOOK_URL = "https://272485010cfe.ngrok-free.app/webhook/noel"
AUTH_TOKEN = "1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

headers = {
    "Content-Type": "application/json",
    "Authorization": AUTH_TOKEN
}

results = {}

def test(name, payload, description):
    """Test an endpoint"""
    print(f"\n{'='*70}")
    print(f"{name}: {description}")
    print(f"{'='*70}")

    response = requests.post(WEBHOOK_URL, headers=headers, json=payload)

    if response.status_code == 200:
        try:
            result = response.json()
            if isinstance(result, list) and len(result) > 0:
                result = result[0]

            success = result.get("success", False) if isinstance(result, dict) else False

            if success or (isinstance(result, dict) and "count" in result):
                print(f"✅ PASS - {result.get('message', 'Success')}")
                results[name] = "✅ PASS"
                return True, result
            else:
                print(f"⚠️  WARN - {result}")
                results[name] = "⚠️  WARN"
                return False, result
        except:
            print(f"❌ FAIL - Empty response")
            results[name] = "❌ FAIL"
            return False, None
    else:
        print(f"❌ FAIL - HTTP {response.status_code}")
        results[name] = "❌ FAIL"
        return False, None

print("="*70)
print("FINAL COMPREHENSIVE TEST - ALL 8 ENDPOINTS")
print("="*70)

# 1. list_projects
test("list_projects",
     {"endpoint": "list_projects", "limit": 5},
     "List all projects")

time.sleep(0.5)

# 2. start_session
success, session_data = test("start_session",
     {"endpoint": "start_session",
      "projects": ["Noel_Test"],
      "goals": "Final endpoint testing",
      "ai_type": "Claude"},
     "Create new session")

session_id = session_data.get("session_id") if session_data else None

time.sleep(0.5)

# 3. capture_learning
test("capture_learning",
     {"endpoint": "capture_learning",
      "project": "Noel_Test",
      "title": "Final Test Learning",
      "content": "This validates all endpoints are working",
      "dev_stream": "DevOps"},
     "Create new learning")

time.sleep(2)  # Wait for embedding generation

# 4. query_learnings
test("query_learnings",
     {"endpoint": "query_learnings",
      "query": "endpoint testing",
      "limit": 3},
     "Search learnings semantically")

time.sleep(0.5)

# 5. update_learning
test("update_learning",
     {"endpoint": "update_learning",
      "learning_id": "Final Test Learning",
      "confidence": "High",
      "status": "Validated"},
     "Update existing learning")

time.sleep(0.5)

# 6. query_feedback
test("query_feedback",
     {"endpoint": "query_feedback",
      "query": "endpoint testing",
      "relevant_learning_ids": ["Final Test Learning"]},
     "Submit query feedback")

time.sleep(0.5)

# 7. list_sessions
test("list_sessions",
     {"endpoint": "list_sessions"},
     "List all sessions")

time.sleep(0.5)

# 8. end_session
if session_id:
    test("end_session",
         {"endpoint": "end_session",
          "session_id": session_id},
         f"End session {session_id}")
else:
    print("\n⚠️  Skipping end_session (no session_id)")
    results["end_session"] = "⚠️  SKIP"

# Summary
print("\n" + "="*70)
print("FINAL RESULTS")
print("="*70)

pass_count = sum(1 for v in results.values() if "PASS" in v)
warn_count = sum(1 for v in results.values() if "WARN" in v)
fail_count = sum(1 for v in results.values() if "FAIL" in v)
total = len(results)

for endpoint, status in results.items():
    print(f"{status} {endpoint}")

print(f"\n{'='*70}")
print(f"Total: {total} endpoints")
print(f"✅ Passing: {pass_count}/{total} ({pass_count*100//total if total > 0 else 0}%)")
print(f"⚠️  Warnings: {warn_count}/{total}")
print(f"❌ Failures: {fail_count}/{total}")

if pass_count == total:
    print(f"\n🎉 ALL ENDPOINTS WORKING!")
elif pass_count >= 6:
    print(f"\n✨ {pass_count} of {total} endpoints working - Good progress!")
else:
    print(f"\n⚠️  Only {pass_count} of {total} endpoints working")

print("="*70)
