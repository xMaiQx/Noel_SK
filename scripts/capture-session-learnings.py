#!/usr/bin/env python3
"""
Capture Session Learnings Script
Reads SESSION_LEARNINGS_FINAL.md and sends each learning to Noel API
"""

import os
import sys
import json
import urllib.request
import urllib.error
from pathlib import Path

# Load environment
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

NOEL_WEBHOOK_URL = os.getenv('NGROK_URL', 'http://localhost:5678') + '/webhook/noel'
AUTH_TOKEN = os.getenv('AUTH_TOKEN', '')
PROJECT_NAME = "Noel_SK"

def send_learning(learning_data):
    """Send a learning to Noel API"""
    headers = {
        'Content-Type': 'application/json',
        'Authorization': AUTH_TOKEN
    }

    data = json.dumps(learning_data).encode('utf-8')
    req = urllib.request.Request(NOEL_WEBHOOK_URL, data=data, headers=headers, method='POST')

    try:
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8')
        print(f"HTTP Error {e.code}: {error_body}")
        raise

# Session learnings from this session
learnings = [
    {
        "title": "Notion Database Dual ID System",
        "type": "Pattern",
        "content": "Notion databases have TWO types of IDs - Database ID (for schema operations like retrieve_database) and Data Source ID (for querying records via query_data_source). You must use the correct ID type for each operation.",
        "context": "Discovered while setting up automated database verification. The API wrapper requires Data Source IDs for queries but Database IDs are shown in the UI. Both IDs can be extracted from a single retrieve_database API call - Database ID is in the main response, Data Source ID is in `data_sources[0].id`.",
        "dev_stream": ["Notion API", "Data Architecture"],
        "tags": ["notion-api", "ids", "data-sources", "architecture"],
        "confidence": "High",
        "ai_suggested": True
    },
    {
        "title": "Automated Verification vs Manual Checklists",
        "type": "Principle",
        "content": "Always prefer automated verification over manual checklists. Automated scripts catch subtle errors (like trailing spaces in property names) that humans miss, provide repeatable validation, and generate audit trails.",
        "context": "User insisted on automated verification instead of manual checklist after initial suggestion. The automated script immediately found 4 property issues (trailing spaces and plural/singular mismatches) that would have been missed manually. The script became the definitive source of truth for database schema validation.",
        "dev_stream": ["Automation", "Testing", "Quality Assurance"],
        "tags": ["automation", "testing", "quality-assurance", "best-practices"],
        "confidence": "High",
        "ai_suggested": True
    },
    {
        "title": "n8n Webhook Initialization via API",
        "type": "Gotcha",
        "content": "Webhook nodes created via n8n API don't automatically register their webhook paths. You must open the workflow in the n8n UI and click on the Webhook node to initialize the webhook endpoint. The webhookId field remains empty until UI initialization.",
        "context": "Workflow was uploaded successfully via API but webhook requests returned no response. Execution logs showed no webhook triggers. After opening in UI and clicking the Webhook node, the webhookId was generated and the endpoint became active.",
        "dev_stream": ["n8n", "Webhooks"],
        "tags": ["n8n", "webhooks", "api-limitations", "initialization"],
        "confidence": "High",
        "ai_suggested": True
    },
    {
        "title": "n8n Switch Node Routing via API",
        "type": "Gotcha",
        "content": "Switch nodes created/updated via n8n API don't properly initialize their routing logic. Even with correct condition syntax in JSON, the node routes all traffic to output 0 until manually 'touched' in the UI. You must open the Switch node in UI, verify conditions, and re-save to activate proper routing.",
        "context": "All 8 endpoints routed to 'capture_learning' branch despite correct expressions in JSON. Execution logs showed Switch output 0 had items while outputs 1-7 were empty. Fixed by opening Route Endpoint node in UI and clicking outside to force re-initialization.",
        "dev_stream": ["n8n", "Workflow Logic"],
        "tags": ["n8n", "switch-node", "routing", "api-limitations"],
        "confidence": "High",
        "ai_suggested": True
    },
    {
        "title": "n8n Code Node Cannot Use fetch API",
        "type": "Gotcha",
        "content": "n8n Code nodes don't have access to the fetch API. For HTTP requests, you must use n8n's HTTP Request nodes instead. Attempting to use fetch() results in 'fetch is not defined' error.",
        "context": "Initially implemented Query Learnings and Query Feedback endpoints using fetch() in Code nodes. Both failed with 'fetch is not defined'. Had to redesign using HTTP Request nodes with proper credentials (OpenAI and Supabase).",
        "dev_stream": ["n8n", "HTTP"],
        "tags": ["n8n", "fetch", "http-request", "code-nodes"],
        "confidence": "High",
        "ai_suggested": True
    },
    {
        "title": "Notion Title Field as Primary Identifier",
        "type": "Decision",
        "content": "Use Notion's Title field as the primary user-facing identifier instead of creating separate custom ID fields. Title is human-readable, appears in URLs, supports filtering, and avoids the lookup-then-update pattern required for custom text fields.",
        "context": "Initially generated custom Learning IDs as separate rich_text field. This required two-step update: query by Learning ID → extract page_id → update. Realized Notion's Title field serves the same purpose and is directly filterable. Simplified workflow by using Title as identifier, eliminating the lookup step.",
        "dev_stream": ["Notion API", "Data Architecture"],
        "tags": ["notion-api", "data-architecture", "identifiers", "simplification"],
        "confidence": "High",
        "ai_suggested": True
    },
    {
        "title": "Two-Step Update Pattern for Notion",
        "type": "Pattern",
        "content": "Updating Notion pages by user-facing identifier requires two-step pattern: 1) Query with filter on identifier field → extract page_id from results, 2) Update page using page_id. This enables user-friendly APIs while working with Notion's UUID-based update requirements.",
        "context": "Update Learning endpoint needed to accept Title instead of UUID. Implemented: Update Learning Logic queries by Title filter → Call Notion API Wrapper → Prepare Update Page Call extracts page_id from query results and builds update payload → Call Notion API Wrapper again to update.",
        "dev_stream": ["Notion API", "Workflow Design"],
        "tags": ["notion-api", "workflow-patterns", "two-step-operations", "user-experience"],
        "confidence": "High",
        "ai_suggested": True
    },
    {
        "title": "Supabase Native Credentials in n8n",
        "type": "Pattern",
        "content": "When using Supabase in n8n, use native Supabase API credentials instead of HTTP Header Auth. The native credential type handles authentication headers automatically and provides better integration.",
        "context": "Initially tried using HTTP Header Auth with multiple headers for Supabase (apikey and Authorization). This didn't work well. Switched to n8n's native Supabase credential type which only requires Host URL and Service Role Secret, providing cleaner authentication.",
        "dev_stream": ["n8n", "Supabase", "Authentication"],
        "tags": ["n8n", "supabase", "credentials", "authentication"],
        "confidence": "High",
        "ai_suggested": True
    },
    {
        "title": "Python Environment Variable Loading from .env",
        "type": "Pattern",
        "content": "Python scripts can't automatically access .env files loaded by Claude Code. Implement manual .env parsing in Python scripts by reading the file and setting os.environ variables, skipping bash variable expansion patterns like ${VAR}.",
        "context": "n8n_api.py script couldn't access environment variables even though Claude Code loads .env automatically. Had to implement custom load_env() function that reads .env file, parses key=value pairs, strips quotes, and sets os.environ entries. Needed to handle path resolution correctly (5 levels up from script location).",
        "dev_stream": ["Python", "Environment Variables"],
        "tags": ["python", "environment", "dotenv", "configuration"],
        "confidence": "High",
        "ai_suggested": True
    },
    {
        "title": "Supabase Vector Search Function Setup",
        "type": "Pattern",
        "content": "For Supabase vector search, create a PostgreSQL function that performs cosine similarity search using the <=> operator. The function should accept query_embedding vector(1536), match_count int, and optional filters, returning learning_id, content, metadata, and similarity score.",
        "context": "Created match_learnings() function in Supabase that performs vector similarity search on learnings_vectors table. Uses cosine distance operator (<=>) for similarity calculation. Includes optional project filter for scoped searches. Must grant EXECUTE permission to anon and authenticated roles for API access.",
        "dev_stream": ["Supabase", "Vector Search", "PostgreSQL"],
        "tags": ["supabase", "pgvector", "similarity-search", "postgresql", "functions"],
        "confidence": "High",
        "ai_suggested": True
    }
]

def main():
    print(f"Capturing {len(learnings)} learnings to Noel database...")
    print(f"Project: {PROJECT_NAME}")
    print(f"Webhook: {NOEL_WEBHOOK_URL}")
    print()

    success_count = 0
    failed = []

    for i, learning in enumerate(learnings, 1):
        try:
            # Add required fields
            payload = {
                "endpoint": "capture_learning",
                "project": PROJECT_NAME,
                **learning
            }

            print(f"[{i}/{len(learnings)}] Capturing: {learning['title'][:50]}...")
            result = send_learning(payload)

            if isinstance(result, list) and len(result) > 0:
                result = result[0]

            if result.get('success'):
                print(f"  ✓ Success: {result.get('title', 'Created')}")
                success_count += 1
            else:
                print(f"  ✗ Failed: {result.get('error', 'Unknown error')}")
                failed.append((learning['title'], result.get('error', 'Unknown')))
        except Exception as e:
            print(f"  ✗ Error: {str(e)}")
            failed.append((learning['title'], str(e)))

    print()
    print("="*60)
    print(f"Results: {success_count} succeeded, {len(failed)} failed")

    if failed:
        print("\nFailed learnings:")
        for title, error in failed:
            print(f"  - {title[:50]}: {error}")
        sys.exit(1)
    else:
        print("\n✓ All learnings captured successfully!")
        sys.exit(0)

if __name__ == "__main__":
    main()
