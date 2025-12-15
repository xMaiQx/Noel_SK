# Feature Specification: Design Artifacts & Knowledge Management

**Feature ID**: 002-design-artifacts
**Status**: Draft
**Created**: 2025-11-24
**Priority**: P1 (Critical - affects all future development)

---

## Problem Statement

### Current Issues

1. **Learnings are overloaded** - Currently capturing both:
   - Technical gotchas/patterns (true learnings: "n8n webhooks need UI initialization")
   - Design artifacts (analysis, specifications, plans like `option-c-detailed-plan.md`)

2. **One-use-only files proliferate**:
   - `/tmp/noel_ux_analysis.md`
   - `/tmp/verify_session_associations.md`
   - `specs/001-knowledge-repository/option-c-detailed-plan.md`
   - Session learnings documents
   - Testing reports
   - These are valuable but don't fit into "Learnings" database

3. **No structured artifact lifecycle**:
   - Files created during sessions
   - No systematic capture/organization
   - No linkage to sessions/projects
   - No searchability
   - Workspace gets cluttered

4. **Context reconstruction is expensive**:
   - Between sessions, AI must re-read scattered markdown files
   - No index of "what decisions were made"
   - No timeline of design evolution
   - Wastes tokens, time, and money

---

## User Stories

### US1: Distinguish Learnings from Design Artifacts (Priority: P1)

**As a** developer working with AI assistants
**I want** separate storage for technical learnings vs design artifacts
**So that** I can query the right type of knowledge for my current task

**Acceptance Criteria**:
- Learnings database contains ONLY technical gotchas, patterns, decisions
- New Artifacts database contains design docs, analyses, plans, reports
- Clear criteria for what goes where
- API supports both capture_learning and capture_artifact

**Examples**:

**Learning**:
- Title: "n8n Webhook Initialization via API"
- Type: Gotcha
- Content: "Webhooks created via n8n API don't automatically register their webhook paths..."

**Artifact**:
- Title: "Option C: Smart Detection + Auto-Registration - Detailed Plan"
- Type: Design Document
- Content: Full markdown with sections on architecture, implementation, etc.
- Linked to: Project "Noel_SK", Session "20251124-2051-noel-sk"

---

### US2: Automatic Artifact Capture from Sessions (Priority: P1)

**As a** developer
**I want** all significant markdown files created during a session to be captured as artifacts
**So that** I don't lose design work and can reference it later

**Acceptance Criteria**:
- At session end, detect markdown files created/modified during session
- Prompt user to select which files to capture as artifacts
- Store file content in Artifacts database
- Maintain original file path reference
- Associate with session and project

**Flow**:
```bash
$ noel-end-session
→ Session ended. Duration: 2h 15min. Learnings: 8

  📄 Markdown files created during session:
  1. /tmp/noel_ux_analysis.md (5.2KB)
  2. specs/002-design-artifacts/spec.md (12.4KB)
  3. /tmp/verify_session_associations.md (3.1KB)

  Capture as artifacts? [Y/n]: Y
  Select files (comma-separated, or 'all'): all

  ✓ Captured 3 artifacts
  ✓ Associated with session 20251124-2051-noel-sk
```

---

### US3: Artifact Organization & Retrieval (Priority: P2)

**As a** developer
**I want** to query artifacts by project, session, type, or search content
**So that** I can quickly find relevant design context

**Acceptance Criteria**:
- Query artifacts by project, session, type, tags
- Full-text search within artifact content
- Return artifact metadata + content preview
- Support retrieving full artifact content

**Query Examples**:
```bash
# Find all design docs for Noel project
$ noel-query-artifacts --project Noel_SK --type "Design Document"

# Search within artifact content
$ noel-query-artifacts --search "session auto-close"

# Get all artifacts from specific session
$ noel-query-artifacts --session 20251124-2051-noel-sk
```

---

### US4: Workspace Cleanup & Archival (Priority: P2)

**As a** developer
**I want** captured artifacts to be archived and temp files cleaned up
**So that** my workspace stays clean and organized

**Acceptance Criteria**:
- After artifact capture, optionally move/delete original files
- Create archive directory structure (e.g., `archives/YYYY-MM/session-id/`)
- Keep critical files in place (specs/, scripts/)
- Clean /tmp/ files
- Maintain git-ignored archive for local reference

**Cleanup Strategy**:
- `/tmp/*.md` → Captured as artifact → Deleted
- `specs/**/*.md` → Captured as artifact → Kept in place (source of truth)
- Session notes → Captured → Moved to `archives/YYYY-MM/session-id/`
- Generated reports → Captured → Moved to archives

---

### US5: Artifact-Learning Linkage (Priority: P3)

**As a** developer
**I want** to see which artifacts led to which learnings
**So that** I can understand the context behind technical decisions

**Acceptance Criteria**:
- Learnings can reference source artifacts
- Artifacts can list derived learnings
- Bidirectional linkage in database
- Query "show me artifacts that discuss vector search"
- Query "show me learnings from this design doc"

---

## Data Model

### New Database: Artifacts

**Notion Database Schema**:

| Property | Type | Description | Required |
|----------|------|-------------|----------|
| **Title** | Title | Artifact name (e.g., "Option C Detailed Plan") | Yes |
| **Artifact ID** | Rich Text | Auto-generated: `ART-YYYYMMDD-###` | Auto |
| **Type** | Select | Design Doc, Analysis, Plan, Report, Spec, Meeting Notes, Test Report | Yes |
| **Project** | Relation | Link to Projects database | Yes |
| **Session** | Relation | Link to Sessions database | Optional |
| **Content** | Rich Text | Full markdown content | Yes |
| **File Path** | Rich Text | Original file location | Optional |
| **Status** | Select | Draft, Reviewed, Archived, Superseded | Yes |
| **Tags** | Multi-select | Freeform tags (architecture, ux, testing, etc.) | Optional |
| **Created** | Date | Auto-set on creation | Auto |
| **Last Modified** | Date | Auto-updated | Auto |
| **Supersedes** | Relation | Link to previous version of same artifact | Optional |
| **Related Learnings** | Relation | Link to Learnings database | Optional |
| **Word Count** | Number | For estimating reading time | Auto |
| **Summary** | Rich Text | AI-generated summary (first 200 words) | Optional |

### Artifact Types

| Type | Use Case | Example |
|------|----------|---------|
| **Design Doc** | Detailed feature design | "Option C: Smart Detection Plan" |
| **Analysis** | Problem analysis, UX review | "Noel Workflow UX Analysis" |
| **Plan** | Implementation plan, task breakdown | "Phase 7 Implementation Tasks" |
| **Spec** | Feature specification | "002-design-artifacts/spec.md" |
| **Report** | Test results, session summary | "Phase 7 Session Testing Results" |
| **Meeting Notes** | Design discussions, decisions | "Architecture Review 2025-11-24" |
| **Decision Record** | ADR-style decision docs | "ADR-001: Using Notion over Airtable" |

### Updated Learnings Database

**Clarified Purpose**: Technical gotchas, patterns, and implementation decisions ONLY

**New Fields**:
- **Source Artifact** (Relation): Optional link to design doc that led to this learning
- **Derived From Session** (Relation): Session where this was discovered

**Updated Type Options**:
- Pattern (reusable code/architecture pattern)
- Gotcha (unexpected behavior, pitfall)
- Decision (technical choice with rationale)
- ~~Design~~ (removed - use Artifacts instead)
- Tip (performance, best practice)

---

## API Design

### New Endpoints

#### 1. capture_artifact

**Request**:
```json
{
  "endpoint": "capture_artifact",
  "project": "Noel_SK",
  "session_id": "20251124-2051-noel-sk",
  "title": "Option C Detailed Plan",
  "type": "Design Doc",
  "content": "# Option C: Smart Detection...\n\n[full markdown]",
  "file_path": "/specs/001-knowledge-repository/option-c-detailed-plan.md",
  "tags": ["architecture", "ux", "session-management"],
  "status": "Draft"
}
```

**Response**:
```json
{
  "success": true,
  "artifact_id": "ART-20251124-001",
  "title": "Option C Detailed Plan",
  "page_id": "2b53d603-...",
  "url": "https://notion.so/...",
  "word_count": 3847,
  "summary": "Detailed plan for implementing smart session ID detection..."
}
```

#### 2. query_artifacts

**Request**:
```json
{
  "endpoint": "query_artifacts",
  "project": "Noel_SK",
  "session_id": "20251124-2051-noel-sk",
  "type": "Design Doc",
  "tags": ["architecture"],
  "status": "Draft",
  "search": "session auto-close",
  "limit": 10
}
```

**Response**:
```json
{
  "success": true,
  "count": 2,
  "artifacts": [
    {
      "artifact_id": "ART-20251124-001",
      "title": "Option C Detailed Plan",
      "type": "Design Doc",
      "project": "Noel_SK",
      "created": "2025-11-24T20:30:00Z",
      "word_count": 3847,
      "summary": "Detailed plan for implementing...",
      "url": "https://notion.so/...",
      "tags": ["architecture", "ux", "session-management"]
    }
  ]
}
```

#### 3. get_artifact_content

**Request**:
```json
{
  "endpoint": "get_artifact_content",
  "artifact_id": "ART-20251124-001"
}
```

**Response**:
```json
{
  "success": true,
  "artifact_id": "ART-20251124-001",
  "title": "Option C Detailed Plan",
  "content": "[full markdown content]",
  "metadata": {
    "project": "Noel_SK",
    "session": "20251124-2051-noel-sk",
    "type": "Design Doc",
    "created": "2025-11-24T20:30:00Z",
    "word_count": 3847
  }
}
```

#### 4. update_artifact

**Request**:
```json
{
  "endpoint": "update_artifact",
  "artifact_id": "ART-20251124-001",
  "status": "Reviewed",
  "tags": ["architecture", "ux", "session-management", "implemented"],
  "supersedes": "ART-20251120-003"
}
```

#### 5. scan_session_files (Helper endpoint)

**Request**:
```json
{
  "endpoint": "scan_session_files",
  "session_id": "20251124-2051-noel-sk",
  "start_time": "2025-11-24T20:51:00Z",
  "directories": ["/tmp", "/specs", "/docs"]
}
```

**Response**:
```json
{
  "success": true,
  "files_found": [
    {
      "path": "/tmp/noel_ux_analysis.md",
      "size_bytes": 5324,
      "modified": "2025-11-24T21:15:00Z",
      "suggested_title": "Noel Workflow UX Analysis",
      "suggested_type": "Analysis"
    },
    {
      "path": "specs/002-design-artifacts/spec.md",
      "size_bytes": 12456,
      "modified": "2025-11-24T22:30:00Z",
      "suggested_title": "Design Artifacts Specification",
      "suggested_type": "Spec"
    }
  ]
}
```

---

## Helper Script Functions

### noel-end-session (Enhanced)

```bash
noel-end-session() {
  local session_id="${NOEL_CURRENT_SESSION_ID:-$(cat ~/.noel_session_id)}"
  local start_time=$(cat ~/.noel_session_start_time)

  # End session via API
  response=$(curl ... -d "{\"endpoint\": \"end_session\", \"session_id\": \"$session_id\"}")

  duration=$(echo $response | jq -r '.duration_minutes')
  learning_count=$(echo $response | jq -r '.learning_count')

  echo "Session ended. Duration: ${duration}min. Learnings: $learning_count"

  # Scan for artifacts
  echo ""
  echo "📄 Scanning for markdown files created during session..."

  artifact_scan=$(curl ... -d "{
    \"endpoint\": \"scan_session_files\",
    \"session_id\": \"$session_id\",
    \"start_time\": \"$start_time\",
    \"directories\": [\"/tmp\", \"$(pwd)/specs\", \"$(pwd)/docs\"]
  }")

  file_count=$(echo $artifact_scan | jq -r '.files_found | length')

  if [ "$file_count" -gt 0 ]; then
    echo "$artifact_scan" | jq -r '.files_found[] | "  \(.path) (\(.size_bytes / 1024 | floor)KB)"'
    echo ""
    read -p "Capture these files as artifacts? [Y/n]: " capture_choice

    if [ "$capture_choice" != "n" ]; then
      # Capture each file as artifact
      echo "$artifact_scan" | jq -c '.files_found[]' | while read file; do
        path=$(echo $file | jq -r '.path')
        title=$(echo $file | jq -r '.suggested_title')
        type=$(echo $file | jq -r '.suggested_type')
        content=$(cat "$path")

        curl ... -d "{
          \"endpoint\": \"capture_artifact\",
          \"session_id\": \"$session_id\",
          \"title\": \"$title\",
          \"type\": \"$type\",
          \"content\": \"$content\",
          \"file_path\": \"$path\"
        }"

        echo "  ✓ Captured: $title"
      done

      # Cleanup
      read -p "Delete temp files (/tmp/*.md)? [Y/n]: " cleanup_choice
      if [ "$cleanup_choice" != "n" ]; then
        echo "$artifact_scan" | jq -r '.files_found[] | select(.path | startswith("/tmp")) | .path' | xargs rm -f
        echo "  ✓ Cleaned up temp files"
      fi
    fi
  else
    echo "  No markdown files found."
  fi

  # Cleanup session env
  unset NOEL_CURRENT_SESSION_ID
  unset NOEL_CURRENT_SESSION_UUID
  rm -f ~/.noel_session_id ~/.noel_session_uuid ~/.noel_session_start_time
}
```

### New Helper: noel-query-artifacts

```bash
noel-query-artifacts() {
  local project=""
  local type=""
  local search=""
  local session=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project) project="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --search) search="$2"; shift 2 ;;
      --session) session="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; return 1 ;;
    esac
  done

  # Build query
  query="{\"endpoint\": \"query_artifacts\""
  [ -n "$project" ] && query+=", \"project\": \"$project\""
  [ -n "$type" ] && query+=", \"type\": \"$type\""
  [ -n "$search" ] && query+=", \"search\": \"$search\""
  [ -n "$session" ] && query+=", \"session_id\": \"$session\""
  query+="}"

  # Execute query
  response=$(curl ... -d "$query")

  # Display results
  echo "$response" | jq -r '.artifacts[] | "\(.artifact_id): \(.title) (\(.type)) - \(.word_count) words\n  \(.summary)"'
}
```

### New Helper: noel-get-artifact

```bash
noel-get-artifact() {
  local artifact_id=$1

  if [ -z "$artifact_id" ]; then
    echo "Usage: noel-get-artifact <artifact_id>"
    return 1
  fi

  response=$(curl ... -d "{\"endpoint\": \"get_artifact_content\", \"artifact_id\": \"$artifact_id\"}")

  # Extract content and display
  echo "$response" | jq -r '.content'
}
```

---

## Workspace Organization Strategy

### Directory Structure

```
project-root/
├── specs/                    # Feature specifications (KEEP)
│   ├── 001-knowledge-repository/
│   │   ├── spec.md           # Canonical spec
│   │   ├── plan.md           # Implementation plan
│   │   └── ...               # Other design docs
│   └── 002-design-artifacts/
│       └── spec.md
│
├── archives/                 # Session artifacts (GIT IGNORED)
│   └── 2025-11/
│       ├── 20251124-2051-noel-sk/
│       │   ├── session-notes.md
│       │   ├── ux-analysis.md
│       │   └── test-report.md
│       └── 20251124-1430-briseno/
│           └── ...
│
├── scripts/                  # Helper scripts (KEEP)
├── n8n-workflows/           # Workflow definitions (KEEP)
└── .noel/                   # Noel metadata (GIT IGNORED)
    ├── current_session.json
    └── artifact_cache.json
```

### Cleanup Rules

| Location | Capture? | Action After Capture | Rationale |
|----------|----------|---------------------|-----------|
| `/tmp/*.md` | Yes | Delete | Temporary by nature |
| `specs/**/*.md` | Yes | Keep in place | Source of truth |
| `docs/**/*.md` | Yes | Keep in place | Documentation |
| Session notes | Yes | Move to `archives/` | Historical reference |
| Test reports | Yes | Move to `archives/` | One-time use |
| Root `*.md` (temp) | Yes | Delete | Accidentally created |

### .gitignore Updates

```gitignore
# Noel session data
archives/
.noel/
.noel_session_*

# Temporary files
/tmp/
*.tmp.md
```

---

## Decision Criteria: Learning vs Artifact

### Capture as LEARNING when:
- ✅ Technical gotcha (unexpected behavior)
- ✅ Reusable pattern (code/architecture)
- ✅ Technology-specific tip (API limitation, workaround)
- ✅ Implementation decision with rationale
- ✅ Can be summarized in 1-3 paragraphs
- ✅ Applies across multiple projects/contexts

**Example**: "n8n Code nodes cannot use fetch() API - must use HTTP Request nodes instead"

### Capture as ARTIFACT when:
- ✅ Design document (multiple sections, structured)
- ✅ Analysis report (problem breakdown, options comparison)
- ✅ Implementation plan (task lists, architecture diagrams)
- ✅ Feature specification (user stories, data model)
- ✅ Session summary (testing results, findings)
- ✅ Meeting notes (discussion, decisions)
- ✅ >500 words or multiple headings
- ✅ Project-specific context

**Example**: "Option C: Smart Detection + Auto-Registration - Detailed Plan" (this document!)

### Capture BOTH when:
- ✅ Artifact contains extractable learnings
- ✅ Process: Capture artifact first, then extract specific learnings

**Example**:
1. Capture artifact: "Phase 7 Session Testing Results"
2. Extract learnings:
   - "Session relation requires UUID page_id, not human-readable session_id"
   - "end_session works with human-readable ID via Title query"

---

## Implementation Phases

### Phase 1: Artifacts Database & Basic Capture (2-3 hours)
- Create Artifacts database in Notion
- Implement capture_artifact endpoint
- Implement query_artifacts endpoint
- Test manual artifact capture

### Phase 2: Session File Scanning (2 hours)
- Implement scan_session_files endpoint
- File system scanning logic (modified since start_time)
- File type detection and suggestions
- Test with sample files

### Phase 3: Enhanced end-session Flow (1-2 hours)
- Update noel-end-session to scan files
- Interactive artifact capture
- Cleanup logic
- Test end-to-end

### Phase 4: Artifact Retrieval & Helpers (1 hour)
- Implement get_artifact_content endpoint
- Add noel-query-artifacts helper
- Add noel-get-artifact helper
- Documentation

### Phase 5: Workspace Cleanup & Archival (1 hour)
- Create archives/ directory structure
- Implement file move/delete logic
- Update .gitignore
- Test cleanup

### Phase 6: Artifact-Learning Linkage (1-2 hours)
- Add Source Artifact relation to Learnings
- Add Related Learnings relation to Artifacts
- Update capture_learning to accept source_artifact_id
- Query interface for linkage

---

## Success Metrics

After implementation:

- **Artifact capture rate**: % of sessions with captured artifacts
- **Workspace cleanliness**: Reduction in orphaned .md files
- **Context reconstruction time**: Time to find design context (before/after)
- **Search effectiveness**: % of artifact queries returning relevant results
- **Learning extraction rate**: Learnings per artifact (should be 2-5)

---

## Non-Goals (Out of Scope)

- ❌ Version control for artifacts (use git for specs/)
- ❌ Collaborative editing (Notion handles this)
- ❌ Auto-generation of artifacts from code
- ❌ Integration with external design tools (Figma, Miro)
- ❌ AI-powered artifact summarization (v2 feature)

---

## Open Questions

1. Should artifacts support nested structure (parent-child)?
2. How to handle duplicate artifact titles (versioning)?
3. Should we auto-tag artifacts based on content analysis?
4. Integration with existing specs/ directory - migrate retroactively?
5. Should artifacts be searchable via vector embeddings (like learnings)?

---

## Dependencies

- Notion API (existing)
- Notion Artifacts database (new)
- File system access for scanning
- Session tracking (existing)
- Project tracking (existing)

---

## Related Features

- US1 (Capture Learning) - Clarified scope
- US5 (Session Tracking) - Enhanced end-session flow
- Future: AI-powered artifact analysis and summarization

---

## Next Steps

1. Review and approve this spec
2. Create implementation tasks (tasks.md)
3. Set up Artifacts database in Notion
4. Implement Phase 1 (basic capture)
5. Test with current session's artifacts

---

**Status**: Ready for review and approval
