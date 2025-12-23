# Noel API Contracts - Quick Reference

Concise reference for all 8 Noel Knowledge Repository API endpoints.

**Webhook Base URL:** `$NOEL_WEBHOOK_URL` (from environment)

**All endpoints:** POST to `$NOEL_WEBHOOK_URL/{endpoint_name}`

---

## Learning Management

### 1. capture_learning

**Purpose:** Store new learning with AI enrichment

**Endpoint:** POST `/capture_learning`

**Required Fields:**
- `project` (string): Project name
- `title` (string): Learning title
- `content` (string): Learning description

**Optional Fields:**
- `type` (string): Learning type (Pattern, Solution, Error, Decision, Insight, etc.)
- `dev_stream` (string): Development stream (Back-end, Front-end, n8n, Database, API, etc.)
- `tags` (array): Tags for categorization
- `confidence` (string): High, Medium, Low
- `session_id` (string): Link to session
- `context` (string): Additional context
- `related_files` (array): Related file paths

**Response:**
```json
{
  "success": true,
  "learning_id": "PROJECT-###",
  "ai_enriched": {
    "suggested_dev_streams": ["Back-end", "API"],
    "suggested_type": "Pattern",
    "suggested_tags": ["api-design", "webhook"]
  },
  "message": "Learning captured successfully"
}
```

**Performance:** <3 seconds

### 2. query_learnings

**Purpose:** Semantic search for relevant learnings

**Endpoint:** POST `/query_learnings`

**Required Fields:**
- `query` (string): Natural language search query

**Optional Fields:**
- `filters` (object): Filter by project, dev_stream, type, tags, confidence, status
- `limit` (number): Max results (default 10)

**Response:**
```json
{
  "success": true,
  "count": 5,
  "results": [
    {
      "learning_id": "NOEL-012",
      "title": "Webhook routing pattern",
      "project": "Noel",
      "type": "Pattern",
      "dev_stream": "n8n",
      "confidence": "High",
      "status": "Validated",
      "content": "Single webhook path, route via...",
      "similarity_score": 0.87,
      "tags": ["webhook", "n8n", "routing"]
    }
  ]
}
```

**Performance:** <1 second

**Notes:**
- Excludes deprecated learnings by default
- Uses cosine similarity on 1536-dim embeddings
- Returns top 10 by similarity score

### 3. update_learning

**Purpose:** Modify existing learning

**Endpoint:** POST `/update_learning`

**Required Fields:**
- `learning_id` (string): ID of learning to update

**Optional Fields (at least one):**
- `title` (string): New title
- `content` (string): New content
- `type` (string): New type
- `dev_stream` (string): New dev stream
- `tags` (array): New tags
- `confidence` (string): New confidence
- `status` (string): New status (Hypothesis → Validated → Deprecated)
- `ai_accepted` (boolean): Whether AI suggestions were accepted

**Response:**
```json
{
  "success": true,
  "learning_id": "NOEL-012",
  "updated_fields": ["content", "confidence"],
  "message": "Learning updated successfully"
}
```

**Notes:**
- Status transitions are one-way: Hypothesis → Validated → Deprecated
- Updating content regenerates vector embedding

### 4. query_feedback

**Purpose:** Track search quality metrics

**Endpoint:** POST `/query_feedback`

**Required Fields:**
- `query_text` (string): Original search query
- `relevant_learning_ids` (array): IDs that were useful

**Response:**
```json
{
  "success": true,
  "feedback_id": "FB-###",
  "message": "Feedback recorded"
}
```

**Usage:**
```bash
# After finding useful learnings
noel-feedback "vector search debugging" "NOEL-034,NOEL-041"
```

---

## Session Management

### 5. create_session

**Purpose:** Start development session with recording

**Endpoint:** POST `/create_session`

**Required Fields:**
- `projects` (array): Project names (can be multiple)
- `goals` (string): Session goals

**Optional Fields:**
- `recording_file_path` (string): Path to asciinema .cast file
- `ai_type` (string): Claude, Gemini, Other

**Response:**
```json
{
  "success": true,
  "session_id": "SESSION-YYYYMMDD-###",
  "start_time": "2025-12-18T00:30:00Z",
  "status": "Active",
  "message": "Session created"
}
```

**Performance:** <2 seconds

**Notes:**
- Session IDs auto-generated per day (SESSION-YYYYMMDD-###)
- Can link to multiple projects
- Auto-closes to "Abandoned" after 24h inactivity

### 6. end_session

**Purpose:** Complete active session

**Endpoint:** POST `/end_session`

**Required Fields:**
- `session_id` (string): Session to end

**Response:**
```json
{
  "success": true,
  "session_id": "SESSION-20251218-001",
  "end_time": "2025-12-18T02:37:00Z",
  "duration_minutes": 127,
  "learning_count": 5,
  "status": "Completed",
  "message": "Session ended"
}
```

**Notes:**
- Cannot reactivate completed sessions
- Returns summary stats (duration, learnings)

### 7. query_sessions

**Purpose:** Browse session history

**Endpoint:** POST `/query_sessions`

**Optional Fields:**
- `filters` (object): Filter by project, date range, status, ai_type

**Response:**
```json
{
  "success": true,
  "count": 3,
  "sessions": [
    {
      "session_id": "SESSION-20251218-001",
      "projects": ["Noel"],
      "goals": "Implement domain memory skill",
      "start_time": "2025-12-18T00:30:00Z",
      "end_time": "2025-12-18T02:37:00Z",
      "duration_minutes": 127,
      "status": "Completed",
      "ai_type": "Claude",
      "recording_file_path": "/path/to/recording.cast",
      "learning_count": 5
    }
  ]
}
```

---

## Project Management

### 8. list_projects

**Purpose:** Browse project catalog

**Endpoint:** POST `/list_projects`

**Optional Fields:**
- `filters` (object): Filter by status, priority, tech_stack

**Response:**
```json
{
  "success": true,
  "count": 1,
  "projects": [
    {
      "name": "Noel",
      "status": "Active",
      "priority": "P0-Critical",
      "tech_stack": ["n8n", "Notion", "Supabase", "OpenAI"],
      "description": "Workflow-based knowledge management system",
      "start_date": "2025-11-20",
      "last_activity": "2025-12-18",
      "learning_count": 45,
      "session_count": 12,
      "total_session_hours": 87.5
    }
  ]
}
```

**Notes:**
- Learning count excludes deprecated learnings
- Supports status: Active, On Hold, Planning, Completed, Archived
- Supports priority: P0-Critical, P1-High, P2-Medium, P3-Low

---

## Common Usage Patterns

### Using Bash Helpers

All endpoints accessible via bash helpers in `scripts/noel-helpers.sh`:

```bash
# Source helpers
source /Users/murodos/Documents/_Mad_Panda_/Proyectos/Noel_SK/scripts/noel-helpers.sh

# Capture learning
noel-capture "Noel" "Pattern name" "Pattern description" "Pattern" "High"

# Query learnings
noel-query "search query" "Noel"

# Update learning
noel-update "NOEL-012" --status "Validated"

# Start session
noel-start-session "Noel" "Session goals"

# End session
noel-end-session

# List projects
noel-projects "Active"

# Query sessions
noel-sessions "Noel"

# Submit feedback
noel-feedback "query text" "NOEL-012,NOEL-034"
```

### Using curl Directly

```bash
# Set webhook URL
export NOEL_WEBHOOK_URL="https://xxxxx.ngrok-free.app/webhook"

# Capture learning
curl -s -X POST "$NOEL_WEBHOOK_URL/capture_learning" \
  -H "Content-Type: application/json" \
  -d '{
    "project": "Noel",
    "title": "Learning title",
    "content": "Learning description",
    "type": "Pattern",
    "confidence": "High"
  }' | jq '.'

# Query learnings
curl -s -X POST "$NOEL_WEBHOOK_URL/query_learnings" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "search query",
    "filters": {"project": "Noel"},
    "limit": 5
  }' | jq '.'
```

### From Python

```python
import os
import requests

webhook_url = os.getenv('NOEL_WEBHOOK_URL')

# Capture learning
response = requests.post(
    f"{webhook_url}/capture_learning",
    json={
        "project": "Noel",
        "title": "Learning title",
        "content": "Learning description",
        "type": "Pattern",
        "confidence": "High"
    }
)

data = response.json()
if data['success']:
    print(f"Captured: {data['learning_id']}")
```

---

## Error Responses

All endpoints return consistent error format:

```json
{
  "success": false,
  "error": "Error description",
  "details": {
    "field": "Validation details"
  }
}
```

**Common errors:**
- `400`: Invalid request (missing required fields, invalid values)
- `404`: Resource not found (learning_id, session_id, project doesn't exist)
- `500`: Server error (n8n workflow issue, Notion/Supabase connectivity)

---

## Full Specifications

For complete OpenAPI specifications, see:
`/Users/murodos/Documents/_Mad_Panda_/Proyectos/Noel_SK/specs/001-knowledge-repository/contracts/`

Files:
- `capture-learning.json`
- `query-learnings.json`
- `update-learning.json`
- `query-feedback.json`
- `create-session.json`
- `end-session.json`
- `query-sessions.json`
- `list-projects.json`

---

**Last updated:** 2025-12-18 (Skill v1.0.0 initialization)
