#!/usr/bin/env python3
"""
Record session learnings through Noel API
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

learnings = [
    {
        "project": "Noel_SK",
        "title": "n8n Code Nodes Don't Support fetch()",
        "content": """n8n Code nodes don't have access to browser APIs like fetch(). Use HTTP Request nodes or $http helper instead.

Error encountered: "fetch is not defined"
Location: Query Feedback Logic node

Fix: Replace fetch() calls with either:
1. HTTP Request node (recommended for external API calls)
2. $http.request() helper (for simple requests)
3. Simplified logic that returns success without external calls

This is a common gotcha when migrating browser JavaScript to n8n workflows.""",
        "context": "Debugging query_feedback endpoint that was returning 'fetch is not defined' error. The workflow had a Code node trying to POST to Supabase using fetch(), which doesn't exist in n8n's Node.js runtime.",
        "type": "Error",
        "dev_stream": "n8n",
        "impact": "Critical - fetch() calls will always fail in n8n Code nodes",
        "confidence": "High",
        "tags": ["n8n", "javascript", "fetch", "http-request", "api"]
    },
    {
        "project": "Noel_SK",
        "title": "PostgreSQL Vector Type Requires Plain Array Strings",
        "content": """PostgreSQL vector columns with pgvector extension require plain array strings like [1,2,3], NOT JSON-serialized strings like "[1,2,3]" (with quotes).

The Problem:
- n8n HTTP Request sends: {"embedding": [0.1, 0.2, ...]}
- JSON serialization converts to: {"embedding": "[0.1, 0.2, ...]"} (with outer quotes)
- PostgreSQL stores as TEXT, not vector type
- Vector search fails with "malformed array literal" error

The Fix:
```javascript
const embeddingStr = `[${embedding.join(',')}]`;  // Plain string
return [{ json: { embedding: embeddingStr } }];
```

This ensures the embedding is sent as a plain string "[...]" not a JSON string "\"[...]\"" """,
        "context": "Discovered while debugging why vector similarity search was returning 0 results. SQL error revealed embeddings were stored as '\"[-0.025994465,...]\"' with outer quotes, which PostgreSQL couldn't parse as vector type.",
        "type": "Pattern",
        "dev_stream": "Database",
        "impact": "Critical for vector search functionality",
        "confidence": "High",
        "tags": ["postgresql", "pgvector", "embeddings", "supabase", "vector-search"]
    },
    {
        "project": "Noel_SK",
        "title": "n8n Nodes Stop Executing When Previous Node Returns Empty Array",
        "content": """n8n nodes don't execute if the previous node returns 0 items (empty array []). This causes workflows to stop silently without error.

Execution flow example:
✓ Query → Generate Embedding → Vector Search → STOPPED (0 results)
✗ Format Results (never executed)
✗ Respond to Webhook (never executed)

Client receives: Empty response (timeout)

Solutions:
1. Enable "Always Output Data" on nodes that might return empty:
   - Node → Settings → Node Execution → ✅ Always Output Data

2. Handle empty results explicitly:
```javascript
const results = $input.all();
if (!results || results.length === 0) {
  return [{ json: { success: true, count: 0, results: [] } }];
}
```

This is a fundamental n8n behavior that causes many "silent failures".""",
        "context": "Debugging why query_learnings endpoint was returning empty responses intermittently. Execution logs showed workflow stopped at 'Search Supabase Vectors' when it returned 0 matching results.",
        "type": "Pattern",
        "dev_stream": "n8n",
        "impact": "High - causes silent workflow failures",
        "confidence": "High",
        "tags": ["n8n", "workflow", "execution", "empty-results", "debugging"]
    },
    {
        "project": "Noel_SK",
        "title": "Webhook URL Structure: Endpoint in Body Not Path",
        "content": """For n8n webhooks with multiple operations, use a SINGLE webhook path with endpoint routing in the request body, not multiple URL paths.

Wrong approach:
POST /webhook/noel/capture_learning
POST /webhook/noel/query_learnings

Correct approach:
POST /webhook/noel
Body: {"endpoint": "capture_learning", ...}

POST /webhook/noel
Body: {"endpoint": "query_learnings", ...}

The workflow has ONE webhook path and routes internally using a Switch node based on the 'endpoint' field in the request body.

This pattern:
- Reduces webhook registrations (1 instead of 8)
- Simplifies routing logic
- Makes endpoint management easier""",
        "context": "Testing endpoints and getting 'webhook not registered' errors when appending operation to URL path. User spotted the issue: workflow uses single webhook with body-based routing.",
        "type": "Pattern",
        "dev_stream": "API",
        "impact": "Critical for API consumers",
        "confidence": "High",
        "tags": ["n8n", "webhook", "api-design", "routing"]
    },
    {
        "project": "Noel_SK",
        "title": "Using n8n-management Skill for Workflow Debugging",
        "content": """The n8n-management skill provides powerful CLI access to execution logs for debugging workflow failures.

Commands used:
```bash
# Get latest execution
python3 .claude/skills/n8n-management/scripts/n8n_api.py latest-execution "Workflow"

# Get specific execution details
python3 .claude/skills/n8n-management/scripts/n8n_api.py get-execution <id>

# List recent executions
python3 .claude/skills/n8n-management/scripts/n8n_api.py list-executions

# Find workflow by name
python3 .claude/skills/n8n-management/scripts/n8n_api.py find-workflow "name"
```

What it reveals:
- Exact sequence of nodes executed
- Where execution stopped
- Success/failure status of each node
- Error messages from failed nodes

Benefits over n8n UI:
- Faster access (no browser navigation)
- Scriptable/automatable
- Can be integrated into testing
- Saves 10-15 minutes per debugging cycle""",
        "context": "Used extensively during this debugging session to diagnose endpoint failures. Execution logs revealed exactly where workflows stopped and which nodes failed.",
        "type": "Best Practice",
        "dev_stream": "DevOps",
        "impact": "High for debugging efficiency",
        "confidence": "High",
        "tags": ["n8n", "debugging", "cli", "automation", "skills"]
    },
    {
        "project": "Noel_SK",
        "title": "Full Cycle RAG Workflow Testing Strategy",
        "content": """When testing RAG (Retrieval-Augmented Generation) systems, validate the complete cycle end-to-end:

1. Data cleanup: Delete old/corrupted data
2. Fresh data creation: Create test records through API
3. Verify storage: Check actual stored format in database
4. Test retrieval: Query and verify results
5. Validate semantics: Confirm similarity scores make sense

For Noel workflow:
1. Deleted old learnings with broken embeddings (6 records)
2. Created 3 fresh test learnings via capture_learning
3. Verified embeddings in Supabase (plain strings, not JSON)
4. Tested query_learnings semantic search
5. Confirmed results: 74% and 59% similarity scores

Key insight: Don't assume workflow is correct - verify actual API calls and data storage at each step.

Test query that worked:
"PostgreSQL vectors" → matched "PostgreSQL Vector Types" (74%) and "Testing Vector Storage" (59%)""",
        "context": "After fixing embedding format, performed complete end-to-end test to prove RAG workflow functional. This systematic approach caught the remaining issues.",
        "type": "Best Practice",
        "dev_stream": "Architecture",
        "impact": "Critical for validating RAG systems",
        "confidence": "High",
        "tags": ["rag", "testing", "embeddings", "semantic-search", "validation"]
    }
]

print("="*70)
print("RECORDING SESSION LEARNINGS TO NOEL")
print("="*70)

for i, learning in enumerate(learnings, 1):
    print(f"\n{i}/{len(learnings)}: {learning['title']}")

    payload = {
        "endpoint": "capture_learning",
        **learning
    }

    response = requests.post(WEBHOOK_URL, headers=headers, json=payload)

    if response.status_code == 200:
        try:
            result = response.json()
            if isinstance(result, list):
                result = result[0]

            if result.get("success"):
                learning_id = result.get("learning_id")
                print(f"   ✓ Recorded: {learning_id}")
            else:
                print(f"   ✗ Error: {result}")
        except Exception as e:
            print(f"   ✗ Failed: {str(e)}")
    else:
        print(f"   ✗ HTTP {response.status_code}")

    time.sleep(2)  # Wait for embedding generation

print("\n" + "="*70)
print(f"✓ Recorded {len(learnings)} session learnings to Noel!")
print("="*70)
print("\nThese learnings are now searchable via query_learnings endpoint")
print("and will help future debugging sessions!")
