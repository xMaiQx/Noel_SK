# Feature Specification: Noel Knowledge Repository System

**Feature Branch**: `001-knowledge-repository`
**Created**: 2025-11-20
**Status**: Draft
**Input**: User description: "Noel: A centralized learning repository system that captures, enriches, and retrieves development knowledge across all projects and sessions using webhooks, Notion storage, vector search (RAG), and AI enrichment"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Capture Development Learning via Webhook (Priority: P1)

As a developer working in Claude Code, I want to capture development learnings to a centralized repository without creating local files, so that knowledge is immediately available across all projects and sessions.

**Why this priority**: This is the foundational capability that enables the entire knowledge repository. Without the ability to capture learnings, the system has no value. This represents the minimal viable product.

**Independent Test**: Can be fully tested by sending a webhook POST request with learning data and verifying it's stored in Notion with correct categorization. Delivers immediate value by centralizing knowledge capture.

**Acceptance Scenarios**:

1. **Given** a developer encounters a useful pattern while coding, **When** they send a capture_learning webhook with title, content, project, and type, **Then** the learning is stored in Notion with a unique ID and timestamp
2. **Given** a learning is captured with minimal metadata, **When** AI enrichment runs, **Then** the system automatically suggests dev streams, tags, and categorization
3. **Given** a learning is captured for a new project, **When** the project doesn't exist in the catalog, **Then** the system creates the project entry automatically
4. **Given** a developer captures a learning without specifying confidence level, **When** the learning is stored, **Then** it defaults to "Medium" confidence and "Hypothesis" status
5. **Given** multiple learnings are captured rapidly, **When** webhook requests are sent concurrently, **Then** each learning is processed and stored independently without data loss

---

### User Story 2 - Query Learnings with Semantic Search (Priority: P2)

As a developer starting a new task, I want to query past learnings using natural language, so I can avoid re-solving known problems and apply proven patterns.

**Why this priority**: Retrieval is the second half of the core value proposition. Once learnings are captured, they must be easily retrievable to close the knowledge loop. However, capture must exist first.

**Independent Test**: Can be fully tested by populating the repository with sample learnings and executing natural language queries. Delivers value by making accumulated knowledge actionable.

**Acceptance Scenarios**:

1. **Given** learnings exist in the repository, **When** a user queries "How to debug n8n workflows?", **Then** the system returns semantically relevant learnings ranked by similarity
2. **Given** a query with project filter "Briseno", **When** learnings exist across multiple projects, **Then** only Briseno-related learnings are returned
3. **Given** a query with dev stream filter "n8n", **When** learnings span multiple dev streams, **Then** only n8n-tagged learnings are included in results
4. **Given** deprecated learnings exist, **When** a query is executed, **Then** deprecated learnings are excluded unless explicitly requested
5. **Given** a query returns multiple relevant learnings, **When** results are presented, **Then** each learning includes its ID, title, project, type, confidence level, and a content excerpt

---

### User Story 3 - Manage Project Catalog (Priority: P3)

As a project manager, I want to view all projects with their priorities and learning counts, so I can decide what to work on next and track knowledge accumulation.

**Why this priority**: Project management is valuable but secondary to core capture/query. The system can function with implicit project creation during learning capture.

**Independent Test**: Can be fully tested by creating projects and capturing learnings, then querying the project catalog. Delivers value by providing portfolio visibility.

**Acceptance Scenarios**:

1. **Given** multiple projects exist, **When** a user requests the project list, **Then** all projects are returned with name, status, priority, tech stack, and learning count
2. **Given** projects with different statuses, **When** a user filters by status "Active", **Then** only active projects are returned
3. **Given** projects with different priorities, **When** a user sorts by priority, **Then** projects are ordered from P0-Critical to P3-Low
4. **Given** a project has accumulated learnings, **When** the project list is viewed, **Then** the learning count reflects the total number of non-deprecated learnings

---

### User Story 4 - AI-Powered Learning Enrichment (Priority: P4)

As a developer capturing learnings quickly, I want AI to automatically categorize and tag my learnings, so I don't have to manually specify all metadata.

**Why this priority**: Enrichment improves the quality and discoverability of learnings but is not essential for the core capture/retrieve workflow. The system can function with manual categorization.

**Independent Test**: Can be fully tested by capturing learnings with minimal metadata and verifying AI-suggested fields. Delivers value by reducing capture friction.

**Acceptance Scenarios**:

1. **Given** a learning is captured with only title and content, **When** AI enrichment analyzes the content, **Then** it suggests appropriate dev streams from the predefined list (Back-end, Front-end, UI/UX, n8n, Database, API, DevOps, Architecture, Performance, Security)
2. **Given** a learning describes an error resolution, **When** AI analyzes the type, **Then** it suggests type "Solution" or "Error" based on content
3. **Given** a learning mentions specific technologies, **When** AI extracts tags, **Then** it includes technology names, patterns, and key concepts as tags
4. **Given** a learning with AI-suggested metadata, **When** the user reviews suggestions, **Then** they can accept, modify, or reject each suggestion before final storage

---

### User Story 5 - Session Tracking and Replay (Priority: P5)

As a developer reviewing past work, I want to track coding sessions with full context and replay recordings, so I can understand the environment and thought process behind captured learnings.

**Why this priority**: Session tracking and replay provide valuable context for understanding learnings but are not essential for the core capture/query workflow. This is an enhancement that adds significant value for knowledge review and team learning.

**Independent Test**: Can be fully tested by starting a session with recording, capturing learnings during the session, ending the session, then querying sessions and accessing replay files. Delivers value by preserving complete session context.

**Acceptance Scenarios**:

1. **Given** a developer starts a coding session, **When** they create a session with goals and recording enabled, **Then** the session is stored with unique ID, start time, associated project(s), and recording file path
2. **Given** an active session exists, **When** learnings are captured, **Then** each learning is automatically associated with the current session ID
3. **Given** a developer ends a session, **When** the session is finalized, **Then** end time is recorded and session status changes to "Completed"
4. **Given** completed sessions exist, **When** a user queries sessions by project or date range, **Then** sessions are returned with ID, start/end times, duration, goals, project(s), learning count, and recording file path
5. **Given** a session has a recording file, **When** a user requests session replay, **Then** the system provides access to the asciinema recording file for terminal playback
6. **Given** multiple sessions exist for a project, **When** viewing project details, **Then** total session count and total session hours are displayed

---

### Edge Cases

- What happens when a learning is captured for a project that doesn't exist in the catalog? **System auto-creates project with default status "Active" and priority "P2-Medium"**
- How does the system handle duplicate learning IDs? **System enforces uniqueness by combining project prefix, sequential number, and timestamp hash if needed**
- What happens when webhook request times out during AI enrichment? **System stores learning with provided metadata only, marks for background enrichment retry**
- How does the system handle malformed webhook requests (missing required fields)? **Returns HTTP 400 with clear error message indicating which required fields are missing**
- What happens when vector embedding generation fails? **Learning is still stored in Notion; vector embedding is retried in background up to 3 times**
- How does the system handle queries when no learnings match? **Returns empty results with HTTP 200, suggests broadening search criteria**
- What happens when a user updates a learning? **System updates Notion record, regenerates vector embedding, preserves original timestamp, adds "Last Modified" timestamp**
- How does the system handle very large learning content (>10,000 characters)? **Accepts full content in Notion, uses truncated summary for vector embedding to stay within token limits**
- What happens when multiple learnings have identical titles? **Allowed, differentiated by unique learning ID and timestamp**
- How does the system handle concurrent updates to the same learning? **Last write wins; no optimistic locking in v1**
- What happens when a learning is captured without an active session? **Learning is still stored; session field is null or references a default "ad-hoc" session**
- How does the system handle a session that is never formally ended? **Session remains in "Active" status; can be manually closed or auto-closed after 24 hours of inactivity**
- What happens when a session recording file is missing or deleted? **Session metadata remains intact; recording_file_path shows the expected location but playback is unavailable**
- How does the system handle sessions spanning multiple projects? **Session can link to multiple projects via many-to-many relationship; learnings captured during session associate with their respective projects**
- What happens when querying sessions with no learnings captured? **Empty sessions are returned in queries; useful for tracking time spent even without explicit learnings documented**

## Requirements *(mandatory)*

### Functional Requirements

**Capture Learnings**

- **FR-001**: System MUST accept webhook POST requests at endpoint `/capture_learning` with learning data (project, type, dev_stream, title, content, context, tags, confidence)
- **FR-002**: System MUST generate unique learning IDs in format `PROJECT_PREFIX-###` (e.g., BR-001, NOEL-045) where ### is zero-padded sequential number per project
- **FR-003**: System MUST store learnings in Notion database with all metadata fields (title, learning_id, project, type, dev_stream, content, context, tags, related_files, confidence, status, timestamp, session)
- **FR-004**: System MUST automatically create project entries in Projects database when capturing learnings for new projects
- **FR-005**: System MUST set default values for optional fields: confidence="Medium", status="Hypothesis" when not provided
- **FR-006**: System MUST return webhook response within 3 seconds including storage and enrichment
- **FR-007**: System MUST preserve all learnings permanently (no automatic deletion or expiration)

**AI Enrichment**

- **FR-008**: System MUST analyze learning content and suggest dev streams from predefined list: Back-end, Front-end, UI/UX, n8n, Database, API, DevOps, Architecture, Performance, Security
- **FR-009**: System MUST suggest learning type (Pattern, Solution, Error, Decision, Insight, Anti-Pattern, Best Practice) based on content analysis
- **FR-010**: System MUST extract and suggest relevant tags including technologies, patterns, and key concepts
- **FR-011**: System MUST append AI-suggested metadata to user-provided metadata (not replace)

**Vector Search**

- **FR-012**: System MUST generate embeddings for learning content and store in vector database (Supabase with pgvector)
- **FR-013**: System MUST accept query requests at endpoint `/query_learnings` with natural language query and optional filters (project, dev_stream, type, tags, confidence, status)
- **FR-014**: System MUST perform semantic similarity search and return top 10 most relevant learnings ranked by similarity score
- **FR-015**: System MUST exclude deprecated learnings from query results by default unless filter explicitly includes status="Deprecated"
- **FR-016**: System MUST fetch full learning details from Notion for returned results
- **FR-017**: Query results MUST include: learning_id, title, project, type, dev_stream, confidence, status, content_excerpt (first 200 characters), similarity_score

**Project Management**

- **FR-018**: System MUST accept requests at endpoint `/list_projects` with optional filters (status, priority, tech_stack)
- **FR-019**: System MUST return project list with fields: name, status, priority, tech_stack, description, started_date, last_activity, learning_count
- **FR-020**: System MUST calculate learning_count dynamically as count of non-deprecated learnings per project
- **FR-021**: System MUST support project statuses: Active, On Hold, Planning, Completed, Archived
- **FR-022**: System MUST support project priorities: P0-Critical, P1-High, P2-Medium, P3-Low

**Learning Updates**

- **FR-023**: System MUST allow updates to existing learnings via webhook with learning_id parameter
- **FR-024**: System MUST preserve original timestamp when updating and add last_modified timestamp
- **FR-025**: System MUST regenerate vector embedding when content is updated
- **FR-026**: System MUST support status transitions: Hypothesis → Validated, Validated → Deprecated, but not Deprecated → Validated (requires new learning)

**Error Handling**

- **FR-027**: System MUST return HTTP 400 for malformed requests with error details indicating missing/invalid fields
- **FR-028**: System MUST return HTTP 500 for system failures (Notion API errors, vector DB errors) with generic error message
- **FR-029**: System MUST retry failed operations (embedding generation, Notion writes) up to 3 times with exponential backoff
- **FR-030**: System MUST log all errors to system log for debugging without exposing internal details to API consumers

**Session Management**

- **FR-031**: System MUST accept requests to create new session at endpoint `/create_session` with session data (project(s), goals, recording_file_path)
- **FR-032**: System MUST generate unique session IDs in format `SESSION-YYYYMMDD-###` where ### is sequential number for the day
- **FR-033**: System MUST store sessions in Notion database with fields: session_id, project(s) (relation), goals, start_time, end_time, status (Active/Completed/Abandoned), recording_file_path, AI type (Claude/Gemini/Other)
- **FR-034**: System MUST automatically set session status to "Active" when created and record start_time
- **FR-035**: System MUST accept requests to end session at endpoint `/end_session` with session_id parameter
- **FR-036**: System MUST update session end_time and status to "Completed" when session is ended
- **FR-037**: System MUST automatically associate learnings with current active session when session_id is provided in capture request
- **FR-038**: System MUST allow learnings to be captured without session association (session field nullable)
- **FR-039**: System MUST accept requests to query sessions at endpoint `/query_sessions` with optional filters (project, date_range, status, ai_type)
- **FR-040**: Query session results MUST include: session_id, project(s), goals, start_time, end_time, duration (calculated), status, learning_count, recording_file_path, AI type
- **FR-041**: System MUST calculate session duration as difference between end_time and start_time (or current time if still active)
- **FR-042**: System MUST support many-to-many relationship between sessions and projects (one session can span multiple projects)
- **FR-043**: System MUST auto-close sessions with status "Active" after 24 hours of inactivity (no new learnings captured)
- **FR-044**: System MUST store recording file paths as relative paths from a configurable base directory (e.g., "~/coding-sessions/2025-11-20-claude-noel.cast")
- **FR-045**: System MUST return recording file access information when querying session details (path, file size if available, recording format)

**Metrics & Feedback**

- **FR-046**: System MUST accept optional AI_Accepted boolean when capturing learnings to track suggestion acceptance rate
- **FR-047**: System MUST accept query feedback via endpoint `/query_feedback` with query text and relevant learning IDs
- **FR-048**: System MUST store query feedback in Supabase for metrics calculation
- **FR-049**: System MUST provide feedback prompt in query response encouraging users to submit relevance feedback

### Key Entities

- **Project**: Represents a development project or initiative. Key attributes: unique name, status (Active/On Hold/Planning/Completed/Archived), priority (P0-P3), tech stack (multi-select tags), description, start date, last activity timestamp, computed learning count, computed session count, computed total session hours. Relationships: one-to-many with Learnings, many-to-many with Sessions.

- **Learning**: Represents a discrete unit of development knowledge. Key attributes: unique learning_id (PROJECT-###), title, type (Pattern/Solution/Error/Decision/Insight/Anti-Pattern/Best Practice), content (full text), context (how it was discovered), dev streams (multi-select from predefined list), tags (multi-select), confidence level (High/Medium/Low), status (Validated/Hypothesis/Deprecated), timestamp (creation), last_modified timestamp, session reference (relation, nullable), related files (text references). Relationships: many-to-one with Project, many-to-one with Session (optional).

- **Learning Vector**: Vector representation of learning content for semantic search. Key attributes: unique ID, reference to learning_id, embedding vector (1536 dimensions for OpenAI embeddings), indexed metadata (project, type, dev_stream, tags, status), creation timestamp. Relationships: one-to-one with Learning.

- **Session**: Represents a development session where learnings are captured with full replay capability. Key attributes: unique session_id (SESSION-YYYYMMDD-###), goals/objectives (text), start_time (timestamp), end_time (timestamp, nullable for active sessions), status (Active/Completed/Abandoned), AI type (Claude/Gemini/Other), recording_file_path (text, path to asciinema .cast file), recording_format (text, e.g., "asciinema"), computed duration (minutes), computed learning_count. Relationships: many-to-many with Projects, one-to-many with Learnings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can capture a learning via webhook and receive confirmation response in under 3 seconds
- **SC-002**: AI categorization suggests correct dev streams with 90%+ accuracy (measured by AI_Accepted flag: percentage of learnings where user accepts AI suggestions without modification)
- **SC-003**: Vector search returns at least one relevant learning in top 3 results for 95% of queries (measured by optional feedback parameter: user indicates which results were relevant)
- **SC-004**: System supports 1000+ learnings with query response time under 1 second
- **SC-005**: Zero data loss - all webhook requests that return success code result in persisted learnings
- **SC-006**: Users can retrieve learnings filtered by any combination of project, type, dev_stream, tags, confidence, status
- **SC-007**: System handles concurrent webhook requests (10+ simultaneous) without errors or response time degradation
- **SC-008**: Project catalog accurately reflects learning counts within 5 seconds of new learning capture
- **SC-009**: Users can successfully query learnings across all projects or filter to specific project(s)
- **SC-010**: System runs on free-tier services (Supabase, n8n community edition) without hitting resource limits for up to 5000 learnings
- **SC-011**: Users can create and end a session via webhook in under 2 seconds each
- **SC-012**: Sessions automatically associate with learnings captured during the active session timeframe
- **SC-013**: Users can query sessions by project and date range and receive results in under 1 second
- **SC-014**: Project details accurately show total session count and cumulative session hours
- **SC-015**: Users can access session recording file paths to replay terminal sessions using asciinema player
- **SC-016**: System tracks AI suggestion acceptance rate and query relevance feedback to enable continuous improvement of categorization and search quality

## Assumptions

1. **Technology Stack**: System will use n8n for workflow orchestration, Notion for structured storage, Supabase with pgvector for vector search, and OpenAI API for embeddings and AI enrichment
2. **Authentication**: Webhook endpoints will be secured via ngrok URL obscurity and optional API key in v1; proper authentication (OAuth, API keys) is out of scope
3. **Embedding Model**: OpenAI's text-embedding-3-small (1536 dimensions) will be used for all vector embeddings
4. **Learning ID Format**: Format is `PROJECT_PREFIX-###` where PROJECT_PREFIX is derived from project name (e.g., "Briseno" → "BR", "Noel" → "NOEL") using first 2-4 letters, and ### is zero-padded 3-digit sequential number per project
5. **Session ID Format**: Format is `SESSION-YYYYMMDD-###` where YYYYMMDD is the date and ### is zero-padded 3-digit sequential number for that day
6. **Session Tracking**: Sessions are tracked as first-class entities in separate Notion database with full lifecycle management (create, active, end, abandon). Recording integration uses asciinema format (.cast files) stored in configurable directory (default: ~/coding-sessions/)
7. **Recording File Management**: System stores recording file paths in Notion but does not manage the actual recording files. Users are responsible for running recording tools (record-claude, record-gemini scripts) and ensuring files are accessible at stored paths
8. **Learning Content Size**: Typical learning content is 500-2000 characters; system will support up to 50,000 characters but may truncate for embedding generation
9. **Query Model**: Queries use the same embedding model as learnings; similarity is measured by cosine distance
10. **Concurrent Access**: System assumes single user (primary developer) with occasional concurrent requests from different projects; full multi-user concurrency control is out of scope
11. **Notion Rate Limits**: System will respect Notion API rate limits (3 requests/second) and implement request queuing if needed
12. **Deprecation Policy**: Learnings are never deleted, only marked as deprecated; deprecated learnings remain in Notion and vector store but are excluded from queries by default
13. **Project Auto-Creation**: When a learning references a non-existent project, system creates project with defaults: status="Active", priority="P2-Medium", tech_stack=empty, description=auto-generated from project name
14. **Bootstrap Migration**: Initial population with existing Briseno learnings is a manual/scripted process outside the core system functionality
15. **Session Auto-Close**: Active sessions with no activity (no learnings captured) for 24 hours are automatically marked as "Abandoned" to keep session list clean
