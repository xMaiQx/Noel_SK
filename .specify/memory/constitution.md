<!--
  Sync Impact Report
  ==================
  Version Change: N/A (template) → 1.0.0 (initial ratification)

  Modified Principles: None (initial version)

  Added Sections:
  - Core Principles (4 principles established)
  - Implementation Standards
  - Governance

  Removed Sections: None

  Templates Requiring Updates:
  - ✅ .specify/templates/plan-template.md (constitution check section already present)
  - ✅ .specify/templates/spec-template.md (no changes required - focuses on requirements)
  - ✅ .specify/templates/tasks-template.md (no changes required - focuses on implementation)
  - ✅ .specify/templates/commands/*.md (no changes required - generic guidance)

  Follow-up TODOs: None

  Rationale: Initial constitution establishing foundational principles for the Noel
  Knowledge Repository project. This is a workflow-first, cloud-native architecture
  project using n8n orchestration with Notion storage and Supabase vector search.
  The constitution reflects the non-traditional nature (no source code repository)
  and establishes quality standards for workflow design, API contracts, and integration.
-->

# Noel Knowledge Repository Constitution

## Core Principles

### I. Workflow-First Architecture

Every feature MUST be implemented through n8n visual workflows that orchestrate cloud services. Workflows MUST be:
- Self-contained with clear input/output contracts (webhook endpoints)
- Independently testable via curl/HTTP requests
- Exportable as JSON for version control
- Documented with inline comments for complex logic nodes

**Rationale**: This project operates without traditional source code. n8n workflows are the primary implementation artifact. Treating workflows as first-class code ensures quality, maintainability, and shareability.

### II. Cloud-Native Storage

Data MUST be stored in specialized cloud services rather than local files or self-managed databases:
- **Structured data**: Notion databases (Projects, Learnings, Sessions)
- **Vector embeddings**: Supabase with pgvector extension
- **Recording files**: Local filesystem with path references only

All database schemas MUST be documented in `data-model.md` since they cannot be version-controlled directly.

**Rationale**: Leveraging managed services (Notion, Supabase) reduces operational complexity and enables rapid development. The system runs entirely on free tiers, making it accessible and cost-effective.

### III. AI-Enhanced Metadata (NON-NEGOTIABLE)

All learning captures MUST support AI enrichment for categorization, tagging, and classification. The system MUST:
- Generate vector embeddings for semantic search (OpenAI text-embedding-3-small)
- Offer AI suggestions for dev streams, types, and tags (GPT-4o-mini)
- Append AI suggestions to user-provided metadata (never replace)
- Track suggestion acceptance rates via `ai_accepted` flag for quality metrics

**Rationale**: AI enrichment reduces capture friction (users can quickly store insights) while maintaining high-quality categorization. Tracking acceptance rates enables continuous improvement of AI prompts.

### IV. Context Preservation

Session tracking with replay capability is a CORE feature, not an enhancement. The system MUST:
- Support session lifecycle (create → active → completed/abandoned)
- Associate learnings with sessions when captured during active sessions
- Store recording file paths for terminal replay (asciinema format)
- Auto-close abandoned sessions (24 hours of inactivity)

**Rationale**: Learnings without context lose significant value. Session recordings preserve the environment, thought process, and discovery path—critical for knowledge review and team learning.

## Implementation Standards

### Webhook API Contracts

All webhook endpoints MUST have OpenAPI specifications in `contracts/` directory with:
- Complete request/response schemas (including error responses)
- Field validation rules (required, type, format, min/max)
- Example requests for manual testing
- Performance requirements (<3s for capture, <1s for query)

### Error Handling

All workflows MUST implement:
- Input validation with HTTP 400 responses for malformed requests
- Retry logic (3 attempts with exponential backoff) for external API failures
- Generic HTTP 500 responses for system errors (no internal details exposed)
- Comprehensive error logging for debugging

### Data Integrity

The system MUST enforce:
- Unique ID generation (learning IDs per project, session IDs per day)
- Referential integrity via Notion relations (Projects ↔ Learnings ↔ Sessions)
- Timestamp preservation (original timestamp + last_modified)
- Status transition rules (Hypothesis → Validated → Deprecated, no rollback)

### Performance Standards

All endpoints MUST meet response time requirements:
- **Capture operations**: <3 seconds (including AI enrichment and storage)
- **Query operations**: <1 second (semantic search with filters)
- **Session operations**: <2 seconds (create/end session)
- **Concurrent requests**: Support 10+ simultaneous captures without degradation

### Testing Protocol

Since automated tests are not feasible for workflow-based systems:
- Manual testing via curl MUST follow contract specifications
- Each user story MUST have independent test criteria documented
- Performance testing MUST validate response times under load
- Integration testing MUST verify end-to-end workflows (capture → query → feedback)

## Governance

This constitution supersedes all other development practices. Changes to core principles require:
1. **Justification**: Document why the change is necessary in project context
2. **Impact assessment**: Identify affected workflows, contracts, and documentation
3. **Version bump**: Follow semantic versioning (MAJOR for principle changes)
4. **Propagation**: Update dependent templates and documentation

**Constitution Compliance**:
- All `/speckit.*` commands MUST verify compliance with principles before proceeding
- Specification analysis MUST flag constitution violations as CRITICAL issues
- Implementation plans MUST document principle adherence in "Constitution Check" section

**Complexity Justification**:
- Any deviation from principles (e.g., adding traditional code, self-hosted storage) MUST be justified in `plan.md` Complexity Tracking section
- Justifications MUST explain why simpler alternatives were rejected

**Development Guidance**:
- This constitution guides specification and planning phases
- Runtime implementation follows `IMPLEMENTATION_GUIDE.md` and `quickstart.md`
- Workflow development follows n8n best practices (modular nodes, error handling, JSON exports)

**Version**: 1.0.0 | **Ratified**: 2025-11-21 | **Last Amended**: 2025-11-21
