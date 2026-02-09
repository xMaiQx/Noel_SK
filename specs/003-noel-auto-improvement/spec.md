# Feature Specification: Noel Auto-Improvement System

**Feature Branch**: `003-noel-auto-improvement`
**Created**: 2025-12-25
**Status**: Draft
**Input**: User description: "Noel Auto-Improvement System - a skill that provides session initialization indicator (wink), manages multi-dimensional knowledge (programming by language, insurance/seguros by ramos), tracks learning effectiveness, and enables auto-improvement through external evaluation agents"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Session Initialization Confirmation (Priority: P1)

As a Noel user starting a new Claude session, I want to immediately see a clear "wink" indicator showing that Noel has loaded successfully, which version is active, and what skills are available, so that I know my session state and can trust that my learnings are being tracked.

**Why this priority**: Without session confirmation, users waste time wondering if Noel is active, which skills are loaded, and whether their work will be captured. This is the foundation for trust in the system and prevents the exact problem the user experienced (lost planning session).

**Independent Test**: Can be fully tested by starting a new Claude session and verifying that a structured boot message appears showing: Noel version, loaded skills list, connection status to backend services, and last session recovery information.

**Acceptance Scenarios**:

1. **Given** a new Claude session is starting, **When** Noel domain memory initializes, **Then** a formatted "BIOS boot" message displays showing: Noel version number, list of active skills with descriptions, webhook connectivity status, and timestamp of last session
2. **Given** Noel fails to connect to backend services, **When** initialization runs, **Then** the boot message clearly indicates which services are unavailable and suggests fallback mode
3. **Given** the previous session had uncaptured learnings, **When** new session initializes, **Then** boot message alerts user to incomplete learnings from last session with count and option to resume

---

### User Story 2 - Multi-Dimensional Knowledge Classification (Priority: P2)

As a Noel user working across different knowledge domains (programming languages, insurance ramos, etc.), I want my learnings automatically categorized into the appropriate dimension and sub-category, so that I can query domain-specific knowledge efficiently without mixing unrelated concepts.

**Why this priority**: Users work in multiple domains. Without proper classification, learnings from Python development pollute results when querying about Java, or insurance learnings in Spanish mix with programming learnings in English. This makes the RAG system less effective and forces manual filtering.

**Independent Test**: Can be tested by capturing learnings tagged with different dimensions (e.g., "Programming:Python", "Seguros:Vida") and verifying that queries filtered by dimension return only relevant results.

**Acceptance Scenarios**:

1. **Given** a user captures a learning about Python decorators, **When** the system classifies it, **Then** it is tagged with dimension="Programming" and sub_category="Python" and language="English"
2. **Given** a user captures a learning about "pólizas de seguros de vida" (life insurance policies), **When** the system classifies it, **Then** it is tagged with dimension="Seguros" and sub_category="Vida" and language="Spanish"
3. **Given** a user queries for "Python patterns", **When** dimension filter is "Programming:Python", **Then** only learnings tagged with Programming:Python are returned (excluding Java, JavaScript, insurance, etc.)
4. **Given** a user queries for "ramos de seguros", **When** dimension filter is "Seguros:*", **Then** only Spanish-language insurance learnings are returned across all ramos

---

### User Story 3 - Learning Effectiveness Dashboard (Priority: P2)

As a Noel user who has accumulated many learnings, I want to see which learnings are most effective (high usage, high helpful rate, high success rate) across different dimensions, so that I can identify patterns in what works and what doesn't in each knowledge domain.

**Why this priority**: Effectiveness tracking was built in Phase 1 but users need visibility into the metrics. Without a dashboard, the data exists but provides no actionable insights. Users should see which learnings are their "MVPs" and which need improvement or archiving.

**Independent Test**: Can be tested by creating learnings with various usage metrics and verifying that a summary report shows top learnings by dimension, sorted by effectiveness score, with drill-down to individual metrics.

**Acceptance Scenarios**:

1. **Given** user has 100+ learnings across 3 dimensions, **When** user requests effectiveness summary, **Then** system displays top 10 learnings per dimension sorted by effectiveness score with usage count, helpful rate, and success rate
2. **Given** a learning has high usage but low helpful rate, **When** viewing effectiveness dashboard, **Then** learning is flagged as "frequently used but unhelpful" suggesting revision needed
3. **Given** a learning has perfect scores but only 1 usage, **When** viewing dashboard, **Then** learning is flagged as "unproven" indicating more usage needed for reliable metrics

---

### User Story 4 - Automated Skill Improvement via External Agents (Priority: P3)

As a Noel system administrator, I want external evaluation agents to automatically analyze skill effectiveness, identify improvement opportunities, and propose skill updates based on usage patterns and user feedback, so that the skill system continuously improves without manual intervention.

**Why this priority**: This is the "auto" in auto-improvement. While valuable for long-term optimization, it's less critical than core functionality. Users can manually improve skills initially, and automation can be added later as usage patterns become clear.

**Independent Test**: Can be tested by configuring an evaluation agent to analyze 30 days of skill usage logs, generate an improvement report identifying underperforming skills, and propose specific code changes or new skills to add.

**Acceptance Scenarios**:

1. **Given** a skill has been used 50+ times with detailed logs, **When** evaluation agent analyzes usage, **Then** agent generates report showing: most common user intents, success rate per intent, identified gaps where skill failed, and recommended improvements
2. **Given** evaluation agent proposes a skill update (e.g., "add dimension auto-detection from content"), **When** user reviews proposal, **Then** proposal includes: problem statement, proposed solution, expected impact metrics, and diff preview showing exact changes
3. **Given** user approves a skill improvement, **When** system applies update, **Then** new skill version is deployed, old version is archived, and next session boot message confirms new version is active

---

### Edge Cases

- **What happens when Noel backend is completely unavailable?** System boots in offline mode, loads skills from local cache, displays warning that learnings won't sync until reconnected, and queues any capture attempts for later sync
- **How does system handle learnings that span multiple dimensions?** Learning can have multiple dimension tags (e.g., "Programming:Python" + "Architecture:Microservices"), and queries can filter by any combination
- **What if a user captures a learning in mixed language (English + Spanish)?** System detects primary language (whichever has more words) and tags accordingly, preserving original mixed content unchanged
- **How are skill conflicts resolved?** If two skills claim the same trigger phrase or overlapping functionality, boot message warns of conflict and disables lower-priority skill until user resolves
- **What happens when evaluation agent proposes contradictory improvements?** System presents both proposals side-by-side with pros/cons analysis and lets user choose or merge

## Requirements *(mandatory)*

### Functional Requirements

#### Session Initialization

- **FR-001**: System MUST display a formatted boot message within 2 seconds of session start showing: Noel version, active skills list, backend connection status, and last session timestamp
- **FR-002**: Boot message MUST use a consistent, visually distinct format (e.g., ASCII art border, specific color scheme) that is immediately recognizable as the "Noel wink"
- **FR-003**: System MUST detect and report connection status for: n8n webhook, Supabase database, and any external evaluation agents configured
- **FR-004**: System MUST check for uncaptured learnings from previous session and alert user if any exist with count and recovery option
- **FR-005**: System MUST display skill descriptions with each skill name so users understand what capabilities are active

#### Multi-Dimensional Knowledge

- **FR-006**: System MUST support configurable knowledge dimensions where each dimension represents a top-level category (e.g., "Programming", "Seguros", "Business")
- **FR-007**: Each dimension MUST support unlimited sub-categories (e.g., Programming has Python/Java/JavaScript, Seguros has Vida/Auto/Hogar)
- **FR-008**: Learnings MUST be taggable with one or more dimension:sub-category pairs during capture
- **FR-009**: System MUST detect content language (Spanish/English/other) and tag learnings accordingly
- **FR-010**: Query operations MUST support filtering by dimension, sub-category, language, or any combination
- **FR-011**: System MUST provide dimension taxonomy management allowing users to add/rename/archive dimensions and sub-categories

#### Effectiveness Tracking

- **FR-012**: System MUST track these metrics per learning: total uses, helpful rate (%), success rate (%), effectiveness score, last used timestamp
- **FR-013**: System MUST calculate effectiveness score as weighted formula: `(helpful_rate * 0.6 + success_rate * 0.4) * total_uses`
- **FR-014**: System MUST provide effectiveness summary showing top N learnings per dimension (N configurable, default 10)
- **FR-015**: System MUST flag learnings as "unproven" (usage < 3), "frequently used but unhelpful" (usage >= 10 AND helpful_rate < 50%), or "high performer" (effectiveness_score > threshold)
- **FR-016**: Users MUST be able to query effectiveness metrics filtered by dimension, date range, or learning type

#### Auto-Improvement via External Agents

- **FR-017**: System MUST expose standardized logging endpoint for skills to report: skill name, trigger intent, execution time, success/failure, user satisfaction (if captured)
- **FR-018**: System MUST accept webhook registrations from external evaluation agents with configuration for: agent URL, evaluation frequency, target skills
- **FR-019**: System MUST invoke registered evaluation agents on schedule (daily/weekly/monthly) with payload containing: skill usage logs, current skill code/config, user feedback data
- **FR-020**: Evaluation agents MUST return structured improvement proposals including: problem statement, proposed solution, expected impact metrics, and implementation diff
- **FR-021**: System MUST present improvement proposals to user for review with: summary of proposed changes, impact assessment, and approve/reject/modify options
- **FR-022**: Upon approval, system MUST apply skill updates, version the old skill, and confirm new version in next boot message

### Key Entities

- **Knowledge Dimension**: Represents a top-level category of knowledge (e.g., "Programming", "Seguros"). Contains: name, description, language preference, list of sub-categories, active/archived status.

- **Knowledge Sub-Category**: A sub-division within a dimension (e.g., "Python" under Programming, "Vida" under Seguros). Contains: name, parent dimension, tag synonyms (for auto-classification), active/archived status.

- **Learning**: An individual piece of captured knowledge. Extended from Phase 1 with: dimension tags (array of "dimension:sub-category" strings), detected language, effectiveness metrics (usage count, helpful rate, success rate, effectiveness score), version history.

- **Skill**: A Claude Code skill that provides specialized functionality. Contains: skill name, version number, description, trigger patterns, code/config location, usage logs, effectiveness metrics, improvement proposals.

- **Evaluation Agent**: An external service that analyzes skill effectiveness. Contains: agent URL, webhook secret, evaluation frequency, target skills, last execution timestamp, generated proposals.

- **Improvement Proposal**: A suggested skill update from an evaluation agent. Contains: proposing agent, target skill, problem statement, proposed solution, expected impact, implementation diff, user decision (pending/approved/rejected), applied timestamp.

### Assumptions

- **Default dimensions**: System ships with pre-configured dimensions for "Programming" (with common language sub-categories) and "Seguros" (with common ramos). Users can add more.
- **Language detection**: Simple word-count heuristic (if >60% words are Spanish, tag as Spanish; if >60% English, tag as English; else "Mixed")
- **Effectiveness thresholds**: "Unproven" = usage < 3; "Unhelpful" = usage >= 10 AND helpful_rate < 50%; "High performer" = effectiveness_score > 5.0
- **Boot message format**: Uses Unicode box-drawing characters for consistent visual "frame" around boot information
- **Session recovery**: Previous session data is stored in `.noel/session-state.json` and loaded if file exists and is less than 7 days old
- **Skill versioning**: Semantic versioning (major.minor.patch) where agent-proposed improvements default to minor version bumps
- **Evaluation agent protocol**: Agents receive POST webhook with JSON payload and return JSON response following defined schema (to be specified in contracts)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can identify Noel is active within 2 seconds of session start by seeing the distinctive boot message
- **SC-002**: 100% of new sessions display boot message showing at minimum: version, 3+ active skills, backend connectivity status
- **SC-003**: Users can filter learnings by dimension achieving 95%+ precision (no irrelevant results) and 90%+ recall (minimal missed results)
- **SC-004**: Effectiveness dashboard loads in under 3 seconds for libraries of up to 1000 learnings
- **SC-005**: Users can identify their top 10 most effective learnings per dimension with a single query
- **SC-006**: Evaluation agents successfully analyze skill usage and generate improvement proposals with 80%+ user approval rate (proposals are actually useful)
- **SC-007**: Approved skill improvements deploy automatically with zero manual code edits required by user
- **SC-008**: System prevents session data loss by recovering uncaptured learnings from previous session 100% of the time when prior session was interrupted
- **SC-009**: Multi-language support enables Spanish-speaking users to capture and query insurance learnings entirely in Spanish with full functionality
- **SC-010**: Users working across 3+ knowledge dimensions report improved productivity due to better knowledge organization (qualitative survey target: 8/10 satisfaction)
