# Noel Knowledge Repository - Implementation Guide

**Status**: Ready for implementation
**Branch**: 001-knowledge-repository
**Date**: 2025-11-20

---

## Overview

This guide provides step-by-step instructions for implementing the Noel Knowledge Repository system. This is a **workflow-based integration project** using n8n, Notion, Supabase, and OpenAI - not a traditional code repository.

**Important**: Most implementation is done through UIs and visual workflow editors, not code. This guide walks you through each manual step.

---

## Implementation Phases

### ✅ Phase 0: Project Setup (COMPLETED)

- [x] .gitignore created with patterns for Node.js, n8n, environment files
- [x] Directory structure created (n8n-workflows/, scripts/, specs/)
- [x] All design documentation complete (spec.md, plan.md, data-model.md, contracts/, research.md, quickstart.md)
- [x] Checklists validated and complete

---

### 📋 Phase 1: Setup Infrastructure (MANUAL STEPS REQUIRED)

**Estimated Time**: 30-45 minutes

This phase provisions all external services. Follow quickstart.md for detailed instructions.

#### Task T001-T002: Create Notion Databases

**Action Required**: Manual creation via Notion UI

1. Open your Notion workspace
2. Create three databases following schemas in `specs/001-knowledge-repository/data-model.md`:
   - **Projects** database with properties: Name, Status, Priority, Tech Stack, Description, Started, Last Activity
   - **Learnings** database with properties: Title, Learning ID, Project (relation), Type, Dev Stream, Content, Context, Tags, Related Files, Confidence, Status, Timestamp, Last Modified, Session (relation), AI Suggested, AI Accepted
   - **Sessions** database with properties: Session ID, Projects (relation), Goals, Start Time, End Time, Status, AI Type, Recording File Path, Recording Format, Learning Count (rollup), Duration (formula)

3. Add rollup properties:
   - Projects: Learning Count, Session Count, Total Session Hours
   - Sessions: Learning Count
   - Use formulas as specified in data-model.md

4. **Save database IDs** from URLs (format: `https://notion.so/[workspace]/[DATABASE_ID]?v=...`)

**Validation**: All three databases visible in Notion workspace with correct properties

---

#### Task T003: Configure Notion Integration

**Action Required**: Create integration and share databases

1. Go to https://www.notion.so/my-integrations
2. Create new integration: "Noel Knowledge Repository"
3. Copy **Internal Integration Token** (save securely)
4. Share all three databases with the integration:
   - Open each database → Click "..." → "Connections" → Add your integration

**Validation**: Integration appears in Connections for all three databases

---

#### Task T004-T006: Set Up Supabase

**Action Required**: Create project and run SQL scripts

1. Go to https://supabase.com → Create new project: "noel-knowledge-repo"
2. Choose region (closest to you) → Wait for provisioning (~2 minutes)
3. Enable pgvector: Database → Extensions → Search "vector" → Enable
4. Run SQL script from `specs/001-knowledge-repository/data-model.md` (lines 196-259):
   - Go to SQL Editor → New query
   - Paste entire schema script (includes learnings_vectors, query_feedback, indexes, triggers)
   - Execute
5. Verify table created: Table Editor → See "learnings_vectors" and "query_feedback"
6. Get API credentials: Settings → API → Copy:
   - **Project URL**: `https://[project-ref].supabase.co`
   - **Anon public key**

**Validation**: Tables visible in Supabase Table Editor, pgvector extension enabled

---

#### Task T007-T009: Install Tools

**Action Required**: Install n8n, ngrok, and asciinema

**n8n Installation** (choose one):

Option A - Docker:
```bash
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  n8nio/n8n
```

Option B - npm:
```bash
npm install -g n8n
n8n start
```

Access n8n at http://localhost:5678

**ngrok Installation**:
```bash
# macOS
brew install ngrok

# Or download from https://ngrok.com/download

# Start tunnel (keep running)
ngrok http 5678
```

Copy the HTTPS URL (e.g., `https://abc123.ngrok.io`) and save as environment variable:
```bash
export NOEL_WEBHOOK_URL="https://abc123.ngrok.io/webhook"
```

**asciinema Installation**:
```bash
# macOS
brew install asciinema

# Linux
apt install asciinema

# Verify
asciinema --version
```

**Validation**:
- n8n accessible at http://localhost:5678
- ngrok tunnel running with HTTPS URL
- asciinema installed and verified

---

### 📋 Phase 2: Foundational Workflow (REQUIRES N8N VISUAL EDITING)

**Estimated Time**: 1-2 hours

This phase creates the core n8n workflow structure that all user stories depend on.

#### Task T010: Create n8n Credentials

**Action Required**: Add credentials via n8n UI

1. Open n8n at http://localhost:5678
2. Go to Credentials → Add Credential
3. Create three credentials:

   **Notion API**:
   - Type: Notion API
   - API Key: [Your Notion Integration Token]
   - Test connection → Save as "Noel Notion API"

   **OpenAI**:
   - Type: OpenAI API
   - API Key: [Your OpenAI API Key]
   - Save as "Noel OpenAI"

   **Supabase** (HTTP Header Auth):
   - Type: HTTP Header Auth
   - Name: Authorization
   - Value: `Bearer [Your Supabase Anon Key]`
   - Save as "Noel Supabase"

**Validation**: All three credentials saved and testable

---

#### Task T011: Create Main n8n Workflow

**Action Required**: Visual workflow creation in n8n

1. Create new workflow: "Knowledge_Repository"
2. Add 8 Webhook Trigger nodes with paths:
   - `/capture_learning` (POST)
   - `/update_learning` (POST)
   - `/query_learnings` (POST)
   - `/query_feedback` (POST)
   - `/list_projects` (POST)
   - `/create_session` (POST)
   - `/end_session` (POST)
   - `/query_sessions` (POST)

3. For each webhook:
   - Set HTTP Method: POST
   - Set Path: [endpoint name]
   - Enable "Respond" mode
   - Save webhook URL

4. Update webhook URLs to use ngrok:
   - Replace `http://localhost:5678` with your ngrok HTTPS URL

**Validation**: All 8 webhook triggers created and accessible via ngrok URLs

---

#### Tasks T012-T017: Implement Core Functions

**Action Required**: Create JavaScript function nodes in n8n

These are complex n8n workflow implementations. I'll create helper JavaScript files that you can paste into n8n Function nodes:

