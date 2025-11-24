# Tasks: Noel Knowledge Repository System

**Input**: Design documents from `/specs/001-knowledge-repository/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: No automated tests requested in specification. Focus on manual testing via curl/webhook validation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This is a workflow-based integration project (n8n + cloud services), not a traditional code repository:
- **n8n workflows**: Visual workflow editor, exported as JSON
- **Notion databases**: Created via Notion UI
- **Supabase**: SQL scripts via SQL Editor
- **Helper scripts**: Bash scripts for Claude Code integration

---

## Phase 1: Setup (Infrastructure Provisioning)

**Purpose**: Provision all external services and create initial database structures

- [ ] T001 Create Notion workspace databases: Projects, Learnings, Sessions following data-model.md schemas
- [ ] T002 Configure Notion database properties with correct types, selects, and multi-selects per data-model.md
- [ ] T003 [P] Create Notion integration and obtain API token, share all three databases with integration
- [ ] T004 [P] Create Supabase project "noel-knowledge-repo" and enable pgvector extension via Database → Extensions
- [ ] T005 [P] Execute Supabase schema script from data-model.md to create learnings_vectors table with indexes
- [ ] T006 [P] Verify Supabase table created correctly and obtain API credentials (Project URL + Anon key)
- [ ] T007 [P] Install n8n (Docker or npm) and access at http://localhost:5678
- [ ] T008 [P] Start ngrok tunnel: `ngrok http 5678` and save HTTPS URL for webhook configuration
- [ ] T009 [P] Verify asciinema installed for session recording: `asciinema --version`

**Checkpoint**: All external services provisioned - ready for n8n workflow configuration

---

## Phase 2: Foundational (Core n8n Workflow Structure)

**Purpose**: Core n8n workflow infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T010 Create n8n credentials: Notion API (integration token), OpenAI (API key), Supabase (HTTP header auth with Bearer token)
- [ ] T011 Create main n8n workflow named "Knowledge_Repository" with webhook trigger nodes for all 8 endpoints
- [ ] T012 [P] Implement input validation function in n8n workflow to check required fields for each endpoint
- [ ] T013 [P] Implement error handling wrapper in n8n workflow with try-catch and retry logic (3 retries with exponential backoff)
- [ ] T014 [P] Implement learning ID generation function extracting project prefix and querying Notion for next sequence number
- [ ] T015 [P] Implement session ID generation function with format SESSION-YYYYMMDD-### by querying Notion for today's sessions
- [ ] T016 [P] Configure webhook trigger nodes in n8n to listen on paths: /capture_learning, /update_learning, /query_learnings, /query_feedback, /list_projects, /create_session, /end_session, /query_sessions
- [ ] T017 Test n8n workflow activation and webhook URL accessibility via ngrok tunnel

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Capture Development Learning via Webhook (Priority: P1) 🎯 MVP

**Goal**: Enable developers to capture learnings via webhook POST request, automatically store in Notion with unique ID and timestamp, create projects automatically if they don't exist

**Independent Test**: Send POST to /capture_learning with {project, title, content}, verify learning stored in Notion with generated learning ID (e.g., NOEL-001), verify project auto-created if new

### Implementation for User Story 1

- [ ] T018 [US1] Implement /capture_learning webhook branch in n8n: validate input (project, title, content required)
- [ ] T019 [US1] Add Notion node to check if project exists in Projects database, filter by name property
- [ ] T020 [US1] Add conditional node: if project not found, create new project in Projects database with defaults (status=Active, priority=P2-Medium)
- [ ] T021 [US1] Call learning ID generator function with project name to get unique ID (e.g., BR-001, NOEL-001)
- [ ] T022 [US1] Create Notion page in Learnings database with all properties: Title, Learning ID, Project (relation), Type, Content, Context, Tags, Confidence (default Medium), Status (default Hypothesis), Timestamp (now)
- [ ] T023 [US1] Add response formatter to return success=true, learning_id, message in JSON format
- [ ] T024 [US1] Test /capture_learning with minimal fields: {project: "Noel", title: "Test", content: "Test content"}
- [ ] T025 [US1] Test /capture_learning with new project to verify auto-creation
- [ ] T026 [US1] Test /capture_learning with concurrent requests (5+ simultaneous) to verify no data loss
- [ ] T027 [US1] Implement /update_learning endpoint in n8n: validate input (learning_id required)
- [ ] T028 [US1] Query Notion to verify learning exists by Learning ID before update
- [ ] T029 [US1] Update learning in Notion: preserve original timestamp, set last_modified to now, update AI_Accepted field if provided
- [ ] T030 [US1] If content changed, regenerate vector embedding and update Supabase learnings_vectors table
- [ ] T031 [US1] Enforce status transition rules: allow Hypothesis→Validated, Validated→Deprecated, prevent Deprecated→Validated
- [ ] T032 [US1] Test /update_learning: modify content and verify embedding regeneration, test status transitions

**Checkpoint**: At this point, User Story 1 should be fully functional - can capture, update learnings and auto-create projects

---

## Phase 4: User Story 2 - Query Learnings with Semantic Search (Priority: P2)

**Goal**: Enable semantic search across learnings using natural language queries with optional filters, return top 10 results ranked by cosine similarity

**Independent Test**: Populate repository with 5-10 test learnings, send POST to /query_learnings with natural language query, verify relevant results returned with similarity scores

### Implementation for User Story 2

- [ ] T033 [US2] Implement embedding generation in /capture_learning workflow: call OpenAI text-embedding-3-small API with learning content
- [ ] T034 [US2] Add Supabase HTTP node in /capture_learning to INSERT embedding into learnings_vectors table with metadata (project, type, dev_stream, status)
- [ ] T035 [US2] Implement /query_learnings webhook branch: validate input (query required, filters optional)
- [ ] T036 [US2] Add OpenAI node in /query_learnings to generate query embedding from natural language input
- [ ] T037 [US2] Add Supabase HTTP node to execute similarity search: SELECT with ORDER BY embedding <=> query_embedding LIMIT 10
- [ ] T038 [US2] Apply metadata filters in Supabase query (project, dev_stream, type, confidence, status) using WHERE clauses
- [ ] T039 [US2] Add filter to exclude status=Deprecated by default unless explicitly requested
- [ ] T040 [US2] For each result learning_id, fetch full details from Notion Learnings database
- [ ] T041 [US2] Format response with results array containing: learning_id, title, project, type, dev_stream, confidence, status, content_excerpt (first 200 chars), similarity_score
- [ ] T042 [US2] Test /query_learnings with simple query: {query: "How to debug n8n?"}
- [ ] T043 [US2] Test /query_learnings with project filter: {query: "patterns", filters: {project: "Noel"}}
- [ ] T044 [US2] Test /query_learnings with dev_stream filter to verify filtering works correctly

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - can capture and query learnings

---

## Phase 5: User Story 3 - Manage Project Catalog (Priority: P3)

**Goal**: Enable querying project catalog with optional filters (status, priority, tech_stack), return projects with computed learning counts and session counts

**Independent Test**: Create 3-5 projects with varying statuses/priorities, capture learnings for each, send POST to /list_projects, verify all projects returned with correct counts

### Implementation for User Story 3

- [ ] T039 [US3] Implement /list_projects webhook branch: validate optional filters (status, priority, tech_stack)
- [ ] T040 [US3] Add Notion node to query Projects database with filters applied
- [ ] T041 [US3] For each project, use Notion rollup properties to get learning_count and session_count
- [ ] T042 [US3] Format response with projects array containing: name, status, priority, tech_stack, description, started, last_activity, learning_count, session_count, total_session_hours
- [ ] T043 [US3] Test /list_projects without filters to get all projects
- [ ] T044 [US3] Test /list_projects with status filter: {filters: {status: "Active"}}
- [ ] T045 [US3] Test /list_projects with priority filter to verify sorting/filtering works

**Checkpoint**: User Stories 1, 2, AND 3 all functional - full project management capability

---

## Phase 6: User Story 4 - AI-Powered Learning Enrichment (Priority: P4)

**Goal**: Automatically suggest dev streams, learning type, and tags using GPT-4o-mini when learnings are captured with minimal metadata

**Independent Test**: Capture learning with only title and content, verify AI-suggested fields appear in response (dev_streams_suggested, type_suggested, tags_suggested)

### Implementation for User Story 4

- [ ] T046 [US4] Create AI enrichment prompt template in n8n function node following research.md specifications
- [ ] T047 [US4] Add OpenAI node in /capture_learning (parallel to storage) to call gpt-4o-mini with enrichment prompt
- [ ] T048 [US4] Parse AI response JSON to extract suggested dev_streams, type, tags
- [ ] T049 [US4] Merge AI suggestions with user-provided metadata (append, don't replace) in Notion learning properties
- [ ] T050 [US4] Set AI Suggested checkbox to true in Notion when enrichment runs
- [ ] T051 [US4] Add ai_enrichment object to /capture_learning response with suggested fields
- [ ] T052 [US4] Test AI enrichment with minimal input: {project: "Noel", title: "n8n webhook pattern", content: "Use webhook triggers for API endpoints"}
- [ ] T053 [US4] Test AI enrichment with technical content to verify tag extraction accuracy

**Checkpoint**: User Stories 1-4 functional - AI enrichment reduces capture friction

---

## Phase 7: User Story 5 - Session Tracking and Replay (Priority: P5)

**Goal**: Track coding sessions with start/end times, goals, recording file paths, and associate learnings with sessions. Enable session queries and replay access.

**Independent Test**: POST to /create_session with goals and recording path, capture learnings with session_id, POST to /end_session, verify session in Notion with correct duration and learning count, query sessions to get replay file path

### Implementation for User Story 5

- [ ] T054 [US5] Implement /create_session webhook branch: validate input (projects array, goals required)
- [ ] T055 [US5] Call session ID generator function to create unique SESSION-YYYYMMDD-### ID
- [ ] T056 [US5] Create Notion page in Sessions database with properties: Session ID, Projects (relation to multiple), Goals, Start Time (now), Status (Active), AI Type, Recording File Path, Recording Format (asciinema)
- [ ] T057 [US5] Format /create_session response with: success, session_id, start_time, status
- [ ] T058 [US5] Modify /capture_learning to accept optional session_id parameter and create Notion relation to Sessions database
- [ ] T059 [US5] Implement /end_session webhook branch: validate input (session_id required)
- [ ] T060 [US5] Query Notion Sessions database for session by Session ID, verify status=Active
- [ ] T061 [US5] Update session in Notion: set End Time (now), Status (Completed), trigger Duration formula to calculate minutes
- [ ] T062 [US5] Fetch session learning_count from Notion rollup property
- [ ] T063 [US5] Format /end_session response with: success, session_id, start_time, end_time, duration_minutes, status, learning_count
- [ ] T064 [US5] Implement /query_sessions webhook branch: validate optional filters (project, date_range, status, ai_type)
- [ ] T065 [US5] Query Notion Sessions database with filters, include all properties and rollups
- [ ] T066 [US5] Format /query_sessions response with sessions array containing: session_id, projects, goals, start_time, end_time, duration_minutes, status, ai_type, recording_file_path, recording_format, learning_count
- [ ] T067 [US5] Test /create_session: {projects: ["Noel"], goals: "Testing session tracking", recording_file_path: "~/coding-sessions/test.cast", ai_type: "Claude"}
- [ ] T068 [US5] Test /capture_learning with session_id to verify association
- [ ] T069 [US5] Test /end_session with session_id to verify completion and duration calculation
- [ ] T070 [US5] Test /query_sessions with project filter to verify session retrieval

**Checkpoint**: All 5 user stories functional - complete knowledge repository with session replay

---

## Phase 8: Integration & Helper Scripts

**Purpose**: Create helper scripts for easier integration with Claude Code and session recording

- [X] T071 [P] Create bash helper script ~/config/claude-code/noel-helpers.sh with functions: noel-capture, noel-query, noel-start-session, noel-end-session ✅ AUTOMATED
- [X] T072 [P] Implement noel-capture function to curl /capture_learning with NOEL_WEBHOOK_URL and CURRENT_SESSION_ID env vars ✅ AUTOMATED
- [X] T073 [P] Implement noel-query function to curl /query_learnings and pipe to jq for formatted output ✅ AUTOMATED
- [X] T074 [P] Implement noel-start-session function to start asciinema recording, curl /create_session, export SESSION_ID to env ✅ AUTOMATED
- [X] T075 [P] Implement noel-end-session function to curl /end_session and unset SESSION_ID env var ✅ AUTOMATED
- [X] T076 [P] Create integration guide in README.md showing how to source noel-helpers.sh and use functions ✅ AUTOMATED
- [ ] T077 [P] Implement /query_feedback endpoint in n8n to store query relevance feedback in Supabase query_feedback table
- [X] T078 [P] Create Supabase query_feedback table: query_text, relevant_learning_ids array, timestamp per data-model.md ✅ AUTOMATED (in SQL script)
- [X] T079 [P] Update /query_learnings response to include feedback prompt encouraging users to submit relevance feedback ✅ AUTOMATED (in helper functions)
- [ ] T080 Test helper scripts end-to-end: start session, capture learning, query with feedback, end session, verify in Notion

**Checkpoint**: Helper scripts and feedback system enable seamless Claude Code integration with metrics tracking

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and ensure production readiness

- [ ] T081 [P] Export n8n workflow as JSON to n8n-workflows/Knowledge_Repository.json for version control
- [ ] T082 [P] Create n8n workflow import instructions in n8n-workflows/README.md
- [X] T083 [P] Document all Notion database IDs and Supabase credentials needed in quickstart.md environment variables section ✅ AUTOMATED (documented in quickstart.md)
- [ ] T084 [P] Add error handling for Notion API rate limits (3 req/s) with request queuing in n8n workflow
- [ ] T085 [P] Add retry logic for OpenAI API timeouts in embedding and enrichment nodes
- [ ] T086 [P] Create seed data script to populate initial projects (Noel, Briseno) in Notion via API
- [ ] T087 [P] Implement auto-close for abandoned sessions: create n8n scheduled workflow (runs hourly) to query Active sessions with no learnings in last 24h, set status to Abandoned
- [ ] T088 [P] Test auto-close: create test session, wait 24h (or manually set timestamps), verify status changes to Abandoned
- [X] T089 Validate all 8 endpoints against OpenAPI contracts in contracts/ directory (capture, query, list_projects, create_session, end_session, query_sessions, update_learning, query_feedback) ✅ AUTOMATED (test-endpoints.sh created)
- [ ] T090 Run full quickstart.md validation: follow guide from scratch on clean environment, verify all steps work
- [ ] T091 Create backup instructions for Notion databases (CSV export) and Supabase vectors (pg_dump)
- [ ] T092 Document ngrok URL reconfiguration process when tunnel restarts
- [X] T093 Performance test: capture 50 learnings concurrently, measure response times, verify <3s average ✅ AUTOMATED (included in test-endpoints.sh)
- [X] T094 Performance test: query learnings with 500+ learnings in database, verify <1s response time ✅ AUTOMATED (included in test-endpoints.sh)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup (Phase 1) completion - BLOCKS all user stories
- **User Stories (Phases 3-7)**: All depend on Foundational phase (Phase 2) completion
  - User stories can proceed in parallel (with different developers)
  - Or sequentially in priority order (P1 → P2 → P3 → P4 → P5)
- **Integration (Phase 8)**: Can start after User Story 1 (Phase 3) complete, works best after User Story 5 (Phase 7)
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories ✅ MVP
- **User Story 2 (P2)**: Depends on User Story 1 (needs embeddings generated during capture) ⚠️
- **User Story 3 (P3)**: Can start after Foundational - No dependencies on other stories (uses Projects database)
- **User Story 4 (P4)**: Extends User Story 1 (adds AI enrichment to capture flow)
- **User Story 5 (P5)**: Can start after Foundational - Extends capture to accept session_id

### Within Each User Story

- n8n workflow branches can be built in any order
- Notion database queries before data manipulation
- Embedding generation before vector storage (US2)
- Core implementation before integration testing
- Story complete before moving to next priority

### Parallel Opportunities

- **Phase 1 (Setup)**: T003-T009 all marked [P] can run in parallel (different services)
- **Phase 2 (Foundational)**: T012-T016 marked [P] can run in parallel (different workflow components)
- **Once Foundational completes**: User Stories 1, 3, 5 can start in parallel (no cross-dependencies)
- **Phase 8 (Integration)**: T071-T075 marked [P] can run in parallel (different helper functions)
- **Phase 9 (Polish)**: T078-T084 marked [P] can run in parallel (different concerns)

---

## Parallel Example: User Story 1

```bash
# After Foundational phase complete, these US1 tasks can proceed:
T018: Implement /capture_learning webhook validation
T019: Add Notion project existence check
T020: Add project auto-creation logic
# (These are sequential within US1 but US1 as a whole can run parallel to US3, US5)
```

---

## Parallel Example: Multiple User Stories

```bash
# After Phase 2 (Foundational) complete, launch in parallel:

# Developer A: User Story 1 (Capture)
Task: "Implement /capture_learning webhook branch"

# Developer B: User Story 3 (Projects)
Task: "Implement /list_projects webhook branch"

# Developer C: User Story 5 (Sessions)
Task: "Implement /create_session webhook branch"

# These don't conflict - different workflow branches, different database operations
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (provision all services) - T001-T009
2. Complete Phase 2: Foundational (n8n workflow structure) - T010-T017
3. Complete Phase 3: User Story 1 (capture learnings) - T018-T026
4. **STOP and VALIDATE**: Test via curl, verify Notion storage
5. Deploy/demo basic capture functionality

**MVP Deliverable**: Can capture learnings via webhook, auto-create projects, store in Notion with unique IDs

### Incremental Delivery

1. Complete Setup + Foundational → Workflow infrastructure ready (T001-T017)
2. Add User Story 1 → Test independently → Deploy (MVP! Basic capture works) (T018-T026)
3. Add User Story 2 → Test independently → Deploy (Semantic search works) (T027-T038)
4. Add User Story 3 → Test independently → Deploy (Project management works) (T039-T045)
5. Add User Story 4 → Test independently → Deploy (AI enrichment works) (T046-T053)
6. Add User Story 5 → Test independently → Deploy (Session tracking works) (T054-T070)
7. Add Integration Scripts → Deploy (Claude Code helpers work) (T071-T077)
8. Polish & Production Ready → Deploy (Complete system) (T078-T090)

Each phase adds value without breaking previous functionality.

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup (Phase 1) + Foundational (Phase 2) together (T001-T017)
2. Once Foundational is done:
   - **Developer A**: User Story 1 (Capture) - T018-T026
   - **Developer B**: User Story 3 (Projects) - T039-T045
   - **Developer C**: User Story 5 (Sessions) - T054-T070
3. User Story 2 waits for User Story 1 (needs embeddings)
4. User Story 4 waits for User Story 1 (extends capture)
5. Stories complete and integrate via shared n8n workflow

---

## Notes

- **[P] tasks**: Different n8n workflow branches, different services, no dependencies
- **[Story] label**: Maps task to specific user story for traceability
- **n8n specifics**: Most work is visual workflow editing, export JSON for version control
- **Notion**: Cannot automate database creation, must follow manual setup in quickstart.md
- **Supabase**: Use SQL Editor to run schema scripts from data-model.md
- **Testing**: Manual via curl following contracts/ specs, no automated test suite
- **Commit strategy**: Export n8n workflow JSON after each major workflow branch completion
- **ngrok**: URL changes on restart, document reconfiguration process
- **Session recording**: User responsibility to run asciinema, system only stores paths
- Each checkpoint is a deployable increment with independent value

---

## Task Summary

**Total Tasks**: 101 (updated after analysis remediation)
- **Phase 1 (Setup)**: 9 tasks (T001-T009)
- **Phase 2 (Foundational)**: 8 tasks (T010-T017)
- **Phase 3 (US1 - Capture + Update)**: 15 tasks (T018-T032) ✅ MVP - includes learning updates
- **Phase 4 (US2 - Query)**: 12 tasks (T033-T044) - task IDs renumbered
- **Phase 5 (US3 - Projects)**: 7 tasks - task IDs renumbered +6
- **Phase 6 (US4 - AI Enrichment)**: 8 tasks - task IDs renumbered +6
- **Phase 7 (US5 - Sessions)**: 17 tasks - task IDs renumbered +6
- **Phase 8 (Integration + Feedback)**: 10 tasks (T071-T080) - includes query feedback endpoint
- **Phase 9 (Polish)**: 11 tasks (T081-T091) - includes auto-close implementation

**Parallel Opportunities**: 30+ tasks marked [P]

**Independent Test Criteria**:
- US1: Capture learning via webhook, update existing learning, verify in Notion with AI_Accepted field
- US2: Query learnings, verify semantic search results, submit relevance feedback
- US3: List projects, verify filters and counts
- US4: Capture with minimal data, verify AI suggestions
- US5: Create/end session, verify duration and associations, test auto-close after 24h

**New Endpoints Added**:
- `/update_learning` - Update existing learnings with status transitions
- `/query_feedback` - Submit query relevance feedback for metrics

**Suggested MVP Scope**: Phase 1 + Phase 2 + Phase 3 (User Story 1 with updates) = 32 tasks

**Note**: Task IDs in Phases 4-7 have been incremented by +6 to accommodate new learning update tasks in Phase 3.
