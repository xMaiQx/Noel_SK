# Quick Start Guide: Noel Knowledge Repository

**Feature**: 001-knowledge-repository
**Date**: 2025-11-20
**Phase**: 1 - Setup and Testing Guide

## Overview

This guide walks through setting up the Noel knowledge repository system from scratch. By the end, you'll have a fully functional system capturing and querying learnings with AI enrichment and session replay.

**Estimated Setup Time**: 30-45 minutes

## Prerequisites

- [ ] Notion account (free plan sufficient)
- [ ] Supabase account (free plan sufficient)
- [ ] OpenAI API key with credits
- [ ] n8n installed (Community Edition via Docker or npm)
- [ ] ngrok account and installed (for webhook tunnel)
- [ ] asciinema installed (for session recording)

---

## Step 1: Create Notion Databases (10 minutes)

### 1.1 Create Projects Database

1. Open Notion workspace
2. Create new database (full page): "Noel - Projects"
3. Add properties following this schema:

| Property Name | Type | Configuration |
|--------------|------|---------------|
| Name | Title | (default) |
| Status | Select | Options: Active, On Hold, Planning, Completed, Archived |
| Priority | Select | Options: P0-Critical, P1-High, P2-Medium, P3-Low |
| Tech Stack | Multi-select | Tags: n8n, Notion, React, Node.js, Python, Supabase, etc. |
| Description | Rich Text | (default) |
| Started | Date | (default) |
| Last Activity | Date | (default) |

4. Copy database ID from URL:
   ```
   https://notion.so/[workspace]/[DATABASE_ID]?v=...
   ```
5. Save database ID for later

### 1.2 Create Learnings Database

1. Create new database: "Noel - Learnings"
2. Add properties:

| Property Name | Type | Configuration |
|--------------|------|---------------|
| Title | Title | (default) |
| Learning ID | Rich Text | (default) |
| Project | Relation | To: Projects database, Show: Name |
| Type | Select | Options: Pattern, Solution, Error, Decision, Insight, Anti-Pattern, Best Practice |
| Dev Stream | Multi-select | Options: Back-end, Front-end, UI/UX, n8n, Database, API, DevOps, Architecture, Performance, Security |
| Content | Rich Text | (default) |
| Context | Rich Text | (default) |
| Tags | Multi-select | (dynamic) |
| Related Files | Rich Text | (default) |
| Confidence | Select | Options: High, Medium, Low |
| Status | Select | Options: Validated, Hypothesis, Deprecated |
| Timestamp | Date | Include time: Yes |
| Last Modified | Date | Include time: Yes |
| Session | Relation | To: Sessions database (create in step 1.3), Show: Session ID |
| AI Suggested | Checkbox | (default) |

3. Save database ID

### 1.3 Create Sessions Database

1. Create new database: "Noel - Sessions"
2. Add properties:

| Property Name | Type | Configuration |
|--------------|------|---------------|
| Session ID | Title | (default) |
| Projects | Relation | To: Projects database, Show: Name, Allow multiple |
| Goals | Rich Text | (default) |
| Start Time | Date | Include time: Yes |
| End Time | Date | Include time: Yes, Allow empty: Yes |
| Status | Select | Options: Active, Completed, Abandoned |
| AI Type | Select | Options: Claude, Gemini, Other |
| Recording File Path | Rich Text | (default) |
| Recording Format | Select | Options: asciinema, other |

3. Add computed properties:
   - **Learning Count**: Rollup on Learnings relation, Count all
   - **Duration**: Formula: `if(empty(prop("End Time")), dateBetween(now(), prop("Start Time"), "minutes"), dateBetween(prop("End Time"), prop("Start Time"), "minutes"))`

4. Save database ID

### 1.4 Update Rollup Properties

1. In Projects database, add:
   - **Learning Count**: Rollup on reverse Learnings relation, Count all
   - **Session Count**: Rollup on reverse Sessions relation, Count all

### 1.5 Get Notion Integration Token

1. Go to https://www.notion.so/my-integrations
2. Create new integration: "Noel Knowledge Repository"
3. Copy Internal Integration Token
4. Share all three databases with the integration:
   - Open each database
   - Click "..." → "Connections" → Add your integration

---

## Step 2: Set Up Supabase (5 minutes)

### 2.1 Create Project

1. Go to https://supabase.com
2. Create new project: "noel-knowledge-repo"
3. Choose region (closest to you)
4. Wait for provisioning (~2 minutes)

### 2.2 Enable pgvector Extension

1. Go to Database → Extensions
2. Search for "vector"
3. Enable "vector" extension

### 2.3 Create Table and Indexes

1. Go to SQL Editor
2. Run this script:

```sql
-- Create learnings_vectors table
CREATE TABLE learnings_vectors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  learning_id text UNIQUE NOT NULL,
  content text NOT NULL,
  embedding vector(1536) NOT NULL,
  metadata jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Indexes
CREATE INDEX idx_learnings_vectors_learning_id
  ON learnings_vectors(learning_id);

CREATE INDEX idx_learnings_vectors_embedding
  ON learnings_vectors
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

CREATE INDEX idx_learnings_vectors_metadata
  ON learnings_vectors
  USING gin (metadata);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_learnings_vectors_updated_at
  BEFORE UPDATE ON learnings_vectors
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

3. Verify table created: Go to Table Editor, see "learnings_vectors"

### 2.4 Get API Credentials

1. Go to Settings → API
2. Copy:
   - **Project URL**: `https://[project-ref].supabase.co`
   - **Anon public** key (for client access)
3. Save for n8n configuration

---

## Step 3: Configure n8n (15 minutes)

### 3.1 Install n8n (if not already)

**Option A: Docker**
```bash
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  n8nio/n8n
```

**Option B: npm**
```bash
npm install -g n8n
n8n start
```

Access n8n at http://localhost:5678

### 3.2 Add Credentials

1. **Notion API**
   - Go to Credentials → Add Credential
   - Type: Notion API
   - API Key: [Your Notion Integration Token]
   - Test connection
   - Save as "Noel Notion API"

2. **OpenAI**
   - Add Credential → OpenAI API
   - API Key: [Your OpenAI API Key]
   - Save as "Noel OpenAI"

3. **Supabase**
   - Add Credential → HTTP Header Auth
   - Name: Authorization
   - Value: `Bearer [Your Supabase Anon Key]`
   - Save as "Noel Supabase"

### 3.3 Import Workflow

1. Create new workflow: "Knowledge_Repository"
2. Copy workflow JSON from `n8n-workflows/Knowledge_Repository.json` (to be created in implementation phase)
3. Import via "Import from File" or paste JSON
4. Update database IDs in Notion nodes:
   - Projects database ID
   - Learnings database ID
   - Sessions database ID
5. Update Supabase URL in HTTP nodes: `https://[your-project-ref].supabase.co`
6. Save workflow

### 3.4 Activate Webhook Triggers

1. Click each Webhook node
2. Copy webhook URL (format: `http://localhost:5678/webhook/[path]`)
3. Note down all 6 URLs:
   - `/capture_learning`
   - `/query_learnings`
   - `/list_projects`
   - `/create_session`
   - `/end_session`
   - `/query_sessions`

### 3.5 Start ngrok Tunnel

```bash
ngrok http 5678
```

Copy the HTTPS URL (e.g., `https://abc123.ngrok.io`)

Update webhook URLs to use ngrok URL:
- From: `http://localhost:5678/webhook/capture_learning`
- To: `https://abc123.ngrok.io/webhook/capture_learning`

**Important**: ngrok URL changes on restart. Save in environment variable for convenience:
```bash
export NOEL_WEBHOOK_URL="https://abc123.ngrok.io/webhook"
```

---

## Step 4: Test the System (10 minutes)

### 4.1 Create Initial Projects

```bash
curl -X POST $NOEL_WEBHOOK_URL/capture_learning \
  -H 'Content-Type: application/json' \
  -d '{
    "project": "Noel",
    "title": "System setup complete",
    "content": "Successfully set up Noel knowledge repository with Notion, Supabase, and n8n integration. All databases created and connected.",
    "type": "Milestone",
    "confidence": "High"
  }'
```

Expected response:
```json
{
  "success": true,
  "learning_id": "NOEL-001",
  "message": "Learning captured successfully"
}
```

### 4.2 Verify in Notion

1. Open Learnings database
2. See new entry: "System setup complete"
3. Open Projects database
4. See new project: "Noel" with learning count: 1

### 4.3 Test Query

```bash
curl -X POST $NOEL_WEBHOOK_URL/query_learnings \
  -H 'Content-Type: application/json' \
  -d '{
    "query": "setup and configuration"
  }'
```

Expected response:
```json
{
  "success": true,
  "results": [
    {
      "learning_id": "NOEL-001",
      "title": "System setup complete",
      "similarity_score": 0.85,
      ...
    }
  ],
  "count": 1
}
```

### 4.4 Test Session Creation

```bash
curl -X POST $NOEL_WEBHOOK_URL/create_session \
  -H 'Content-Type: application/json' \
  -d '{
    "projects": ["Noel"],
    "goals": "Testing session tracking functionality",
    "recording_file_path": "~/coding-sessions/test-session.cast",
    "ai_type": "Claude"
  }'
```

Expected response:
```json
{
  "success": true,
  "session_id": "SESSION-20251120-001",
  "status": "Active"
}
```

### 4.5 Capture Learning with Session

```bash
curl -X POST $NOEL_WEBHOOK_URL/capture_learning \
  -H 'Content-Type: application/json' \
  -d '{
    "project": "Noel",
    "title": "Session tracking working correctly",
    "content": "Verified that learnings can be associated with active sessions",
    "session_id": "SESSION-20251120-001"
  }'
```

### 4.6 End Session

```bash
curl -X POST $NOEL_WEBHOOK_URL/end_session \
  -H 'Content-Type: application/json' \
  -d '{
    "session_id": "SESSION-20251120-001"
  }'
```

Expected response:
```json
{
  "success": true,
  "session_id": "SESSION-20251120-001",
  "status": "Completed",
  "duration_minutes": 5,
  "learning_count": 1
}
```

---

## Step 5: Integration with Claude Code (5 minutes)

### 5.1 Create Helper Script

Create `~/.config/claude-code/noel-helpers.sh`:

```bash
#!/bin/bash

# Environment variables
export NOEL_WEBHOOK_URL="https://your-ngrok-url.ngrok.io/webhook"
export CURRENT_SESSION_ID=""

# Function: Capture learning
noel-capture() {
  local project="${1:-Noel}"
  local title="${2}"
  local content="${3}"

  curl -X POST $NOEL_WEBHOOK_URL/capture_learning \
    -H 'Content-Type: application/json' \
    -d "{
      \"project\": \"$project\",
      \"title\": \"$title\",
      \"content\": \"$content\",
      \"session_id\": \"$CURRENT_SESSION_ID\"
    }"
}

# Function: Query learnings
noel-query() {
  local query="$1"

  curl -X POST $NOEL_WEBHOOK_URL/query_learnings \
    -H 'Content-Type: application/json' \
    -d "{\"query\": \"$query\"}" | jq
}

# Function: Start session
noel-start-session() {
  local project="${1:-Noel}"
  local goals="${2}"

  local timestamp=$(date +%Y-%m-%d-%H%M%S)
  local recording_path="$HOME/coding-sessions/${timestamp}-claude-${project}.cast"

  # Start asciinema recording
  export NOEL_RECORDING_PATH="$recording_path"

  # Create session
  local response=$(curl -s -X POST $NOEL_WEBHOOK_URL/create_session \
    -H 'Content-Type: application/json' \
    -d "{
      \"projects\": [\"$project\"],
      \"goals\": \"$goals\",
      \"recording_file_path\": \"$recording_path\",
      \"ai_type\": \"Claude\"
    }")

  export CURRENT_SESSION_ID=$(echo $response | jq -r '.session_id')
  echo "Session started: $CURRENT_SESSION_ID"
  echo "Recording to: $recording_path"

  # Start recording
  asciinema rec "$recording_path"
}

# Function: End session
noel-end-session() {
  if [ -z "$CURRENT_SESSION_ID" ]; then
    echo "No active session"
    return
  fi

  curl -X POST $NOEL_WEBHOOK_URL/end_session \
    -H 'Content-Type: application/json' \
    -d "{\"session_id\": \"$CURRENT_SESSION_ID\"}" | jq

  unset CURRENT_SESSION_ID
}
```

### 5.2 Add to Shell Profile

```bash
# Add to ~/.bashrc or ~/.zshrc
source ~/.config/claude-code/noel-helpers.sh
```

### 5.3 Test Integration

```bash
# Start session
noel-start-session "Noel" "Testing integration"

# During session, capture learning
noel-capture "Noel" "Test learning" "This is a test"

# Query learnings
noel-query "setup"

# End session
noel-end-session
```

---

## Step 6: Session Replay Setup (Optional)

### 6.1 Install asciinema Player

**For local playback:**
```bash
# Install asciinema
brew install asciinema  # macOS
# or
apt install asciinema    # Linux
```

**For web playback:**
1. Use https://asciinema.org/
2. Upload .cast files for sharing
3. Or self-host asciinema-player: https://github.com/asciinema/asciinema-player

### 6.2 Test Replay

```bash
# Play back a session
asciinema play ~/coding-sessions/2025-11-20-claude-noel-001.cast
```

---

## Troubleshooting

### Issue: "Database not found" error

**Solution**: Verify database IDs in n8n Notion nodes match actual database IDs from Notion URLs.

### Issue: "pgvector not available"

**Solution**: Enable vector extension in Supabase → Database → Extensions.

### Issue: "OpenAI API rate limit"

**Solution**: Add delay between requests or upgrade OpenAI plan.

### Issue: "ngrok URL changed"

**Solution**: Update `NOEL_WEBHOOK_URL` environment variable and restart n8n workflow to re-register webhooks.

### Issue: "Learnings not appearing in search"

**Solution**: Check Supabase vector table has entries. Verify embedding generation didn't fail (check n8n execution logs).

---

## Next Steps

- [ ] Populate with existing learnings from other projects (Briseno, etc.)
- [ ] Create Claude Code skill for easier capture
- [ ] Set up automatic daily backup of Notion databases
- [ ] Configure Dropbox/Google Drive sync for recording files
- [ ] Customize AI enrichment prompts in n8n workflow

---

## Quick Reference

### Environment Variables
```bash
export NOEL_WEBHOOK_URL="https://your-ngrok-url.ngrok.io/webhook"
export CURRENT_SESSION_ID="SESSION-20251120-001"
```

### Common Commands
```bash
# Capture learning
noel-capture "ProjectName" "Title" "Content"

# Query learnings
noel-query "search query"

# Start session with recording
noel-start-session "ProjectName" "Session goals"

# End session
noel-end-session
```

### API Endpoints
- **Capture Learning**: `POST /capture_learning`
- **Query Learnings**: `POST /query_learnings`
- **List Projects**: `POST /list_projects`
- **Create Session**: `POST /create_session`
- **End Session**: `POST /end_session`
- **Query Sessions**: `POST /query_sessions`

Full API specs: See `/contracts/` directory

---

## Support

For issues or questions:
1. Check n8n execution logs for errors
2. Verify Notion database permissions
3. Test Supabase connection with SQL Editor
4. Review API contract specs in `/contracts/`

**System is now ready for production use!**
