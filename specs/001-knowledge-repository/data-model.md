# Data Model: Noel Knowledge Repository System

**Feature**: 001-knowledge-repository
**Date**: 2025-11-20
**Phase**: 1 - Data Models & Schemas

## Overview

This document defines all data models for the Noel knowledge repository system, including Notion database schemas, Supabase vector table structure, and relationships between entities.

## Entity Relationship Diagram

```
┌─────────────┐
│   Projects  │
└──────┬──────┘
       │ 1
       │
       │ N                    ┌──────────────────┐
       ├──────────────────────┤    Learnings     │
       │                      └────────┬─────────┘
       │                               │ 1
       │                               │
       │ N                             │ 1
┌──────┴──────┐                 ┌─────┴─────────────┐
│  Sessions   │◄────────────────┤ Learning_Vectors  │
└─────────────┘       1:1       └───────────────────┘
       │ N
       │
       │ N
       └───────────────────┐
                          │
                    [Learnings]
                    (many-to-one)

Relationships:
- Projects ↔ Learnings (1:N)
- Projects ↔ Sessions (N:M via relation)
- Sessions ↔ Learnings (1:N)
- Learnings ↔ Learning_Vectors (1:1)
```

## Notion Database Schemas

### 1. Projects Database

**Purpose**: Catalog of all development projects

**Database ID**: `[TO BE CREATED IN NOTION]`

**Properties**:

| Property Name | Type | Configuration | Description |
|--------------|------|---------------|-------------|
| Name | Title | - | Project name (unique identifier) |
| Status | Select | Options: Active, On Hold, Planning, Completed, Archived | Current project status |
| Priority | Select | Options: P0-Critical, P1-High, P2-Medium, P3-Low | Project priority for work planning |
| Tech Stack | Multi-select | Tags: n8n, Notion, React, Node.js, Python, Supabase, etc. | Technologies used in project |
| Description | Rich Text | - | Project overview and goals |
| Started | Date | - | Project start date |
| Last Activity | Date | Auto-updated via formula/automation | Most recent learning timestamp |
| Learning Count | Rollup | Related: Learnings, Property: Title, Calculate: Count | Number of non-deprecated learnings |
| Session Count | Rollup | Related: Sessions, Property: Session ID, Calculate: Count | Number of sessions for this project |
| Total Session Hours | Rollup | Related: Sessions, Property: Duration, Calculate: Sum | Cumulative session time |

**Sample Data**:
```
Name: "Briseno"
Status: "Active"
Priority: "P1-High"
Tech Stack: ["n8n", "Notion", "Supabase", "OpenAI"]
Description: "Multi-agent orchestration system for workflow automation"
Started: 2025-10-01
Last Activity: 2025-11-19
Learning Count: 47
Session Count: 12
Total Session Hours: 18.5
```

**Indexes**: Name (unique via Notion constraints)

---

### 2. Learnings Database

**Purpose**: Repository of development knowledge and insights

**Database ID**: `[TO BE CREATED IN NOTION]`

**Properties**:

| Property Name | Type | Configuration | Description |
|--------------|------|---------------|-------------|
| Title | Title | - | Short descriptive title of the learning |
| Learning ID | Rich Text | Format: PROJECT-### | Unique identifier (e.g., BR-001, NOEL-045) |
| Project | Relation | To: Projects, Show: Name | Parent project |
| Type | Select | Options: Pattern, Solution, Error, Decision, Insight, Anti-Pattern, Best Practice | Category of learning |
| Dev Stream | Multi-select | Options: Back-end, Front-end, UI/UX, n8n, Database, API, DevOps, Architecture, Performance, Security | Development domain(s) |
| Content | Rich Text | - | Full learning content (supports markdown) |
| Context | Rich Text | - | How the learning was discovered |
| Tags | Multi-select | Dynamic tags (technologies, patterns, concepts) | Keywords for filtering |
| Related Files | Rich Text | - | File paths or references (e.g., "src/services/auth.ts:45") |
| Confidence | Select | Options: High, Medium, Low | Confidence in learning accuracy |
| Status | Select | Options: Validated, Hypothesis, Deprecated | Learning validation state |
| Timestamp | Date | Include time: Yes | Creation timestamp |
| Last Modified | Date | Include time: Yes | Last edit timestamp |
| Session | Relation | To: Sessions, Show: Session ID | Associated session (nullable) |
| AI Suggested | Checkbox | - | Indicates if metadata was AI-generated |
| AI Accepted | Checkbox | Default: false | User confirms they accepted AI suggestions without modification |
| **Scope** | **Select** | **Options: Project-Specific (default), Universal, Domain-Specific** | **Applicability level of the learning** |
| **Discipline** | **Multi-select** | **Options: Architecture, UX/UI, Backend, Frontend, Database, DevOps, Security, Performance, Testing, Documentation** | **Professional discipline/domain categorization** |
| **Applies To** | **Rich Text** | **Max 2000 chars** | **Free-form description of contexts where learning is relevant** |

**Sample Data**:
```
Title: "Multi-agent coordinator pattern for n8n"
Learning ID: "BR-023"
Project: "Briseno"
Type: "Pattern"
Dev Stream: ["n8n", "Architecture"]
Content: "When orchestrating multiple agents, use a coordinator workflow that..."
Context: "Discovered while refactoring agent communication logic"
Scope: "Domain-Specific"
Discipline: ["Architecture", "Backend"]
Applies To: "n8n workflow design, multi-agent systems, coordinator pattern implementation"
Tags: ["n8n", "agents", "coordinator-pattern", "workflow"]
Related Files: "workflows/coordinator.json"
Confidence: "High"
Status: "Validated"
Timestamp: 2025-11-15 14:30:00
Last Modified: 2025-11-15 14:30:00
Session: "SESSION-20251115-001"
AI Suggested: true
AI Accepted: true
```

**Indexes**:
- Learning ID (unique via Notion constraints)
- Project + Timestamp (for chronological queries)

**Computed Properties**:
- **Project Name** (Formula): `prop("Project").name`
- **Days Since Created** (Formula): `dateBetween(now(), prop("Timestamp"), "days")`

---

### 3. Sessions Database

**Purpose**: Track coding sessions with replay capability

**Database ID**: `[TO BE CREATED IN NOTION]`

**Properties**:

| Property Name | Type | Configuration | Description |
|--------------|------|---------------|-------------|
| Session ID | Title | Format: SESSION-YYYYMMDD-### | Unique session identifier |
| Projects | Relation | To: Projects, Show: Name | Associated projects (many-to-many) |
| Goals | Rich Text | - | Session objectives and context |
| Start Time | Date | Include time: Yes | Session start timestamp |
| End Time | Date | Include time: Yes, Allow empty: Yes | Session end timestamp (null if active) |
| Status | Select | Options: Active, Completed, Abandoned | Session lifecycle state |
| AI Type | Select | Options: Claude, Gemini, Other | AI assistant used |
| Recording File Path | Rich Text | - | Path to asciinema .cast file |
| Recording Format | Select | Options: asciinema, other | Recording file format |
| Learning Count | Rollup | Related: Learnings, Property: Title, Calculate: Count | Number of learnings captured |
| Duration | Formula | `if(empty(prop("End Time")), dateBetween(now(), prop("Start Time"), "minutes"), dateBetween(prop("End Time"), prop("Start Time"), "minutes"))` | Session duration in minutes |

**Sample Data**:
```
Session ID: "SESSION-20251120-001"
Projects: ["Noel", "Briseno"]
Goals: "Implement session tracking and replay functionality for knowledge repository"
Start Time: 2025-11-20 09:00:00
End Time: 2025-11-20 11:30:00
Status: "Completed"
AI Type: "Claude"
Recording File Path: "~/coding-sessions/2025-11-20-claude-noel-001.cast"
Recording Format: "asciinema"
Learning Count: 3
Duration: 150 (minutes)
```

**Indexes**:
- Session ID (unique via Notion constraints)
- Start Time (for chronological queries)

**Computed Properties**:
- **Duration** (Formula): See above - calculates real-time duration for active sessions
- **Project Names** (Formula): `join(map(prop("Projects"), current.name), ", ")`

---

## Supabase Database Schema

### learnings_vectors Table

**Purpose**: Store vector embeddings for semantic search

**Schema**:

```sql
CREATE TABLE learnings_vectors (
  -- Primary key
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Foreign key to Notion learning
  learning_id text UNIQUE NOT NULL,

  -- Full learning content (for retrieval)
  content text NOT NULL,

  -- 1536-dimension embedding from text-embedding-3-small
  embedding vector(1536) NOT NULL,

  -- Metadata for filtering (stored as JSON)
  metadata jsonb NOT NULL,

  -- Timestamps
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

-- Row-level security (disabled for v1, enable for team sharing)
ALTER TABLE learnings_vectors ENABLE ROW LEVEL SECURITY;

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

-- Query feedback table for metrics
CREATE TABLE query_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  query_text text NOT NULL,
  relevant_learning_ids text[] NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

-- Index on created_at for metrics queries
CREATE INDEX idx_query_feedback_created_at
  ON query_feedback(created_at);
```

**Metadata JSON Structure**:
```json
{
  "project": "Briseno",
  "type": "Pattern",
  "dev_streams": ["n8n", "Architecture"],
  "tags": ["agents", "coordinator-pattern"],
  "confidence": "High",
  "status": "Validated",
  "session_id": "SESSION-20251115-001"
}
```

**Sample Query** (Similarity Search):
```sql
-- Find similar learnings
SELECT
  learning_id,
  content,
  metadata,
  1 - (embedding <=> $query_embedding::vector) as similarity_score
FROM learnings_vectors
WHERE
  (metadata->>'status' != 'Deprecated')
  AND ($project_filter::text IS NULL OR metadata->>'project' = $project_filter)
ORDER BY embedding <=> $query_embedding::vector
LIMIT 10;
```

**Storage Estimates**:
- Per learning: ~6.5KB (1536 floats × 4 bytes + content + metadata)
- 1000 learnings: ~6.5MB
- 5000 learnings: ~32.5MB (well within 500MB free tier)

---

## Data Relationships

### 1. Projects ↔ Learnings (One-to-Many)

**Notion Configuration**:
- Learnings.Project → Relation to Projects
- Projects.Learnings → Reverse relation (auto-created)

**Usage**:
- Each learning belongs to exactly one project
- Projects can have many learnings
- Rollup in Projects counts non-deprecated learnings

**Integrity**:
- If project deleted, learnings orphaned (manual cleanup)
- Recommend soft delete (archive) for projects

### 2. Projects ↔ Sessions (Many-to-Many)

**Notion Configuration**:
- Sessions.Projects → Relation to Projects (allow multiple)
- Projects.Sessions → Reverse relation (auto-created)

**Usage**:
- Sessions can span multiple projects
- Projects can have many sessions
- Rollup in Projects counts sessions

**Example Scenario**:
- Session "SESSION-20251120-001" works on both "Noel" and "Briseno"
- Each project shows this session in its sessions list

### 3. Sessions ↔ Learnings (One-to-Many)

**Notion Configuration**:
- Learnings.Session → Relation to Sessions
- Sessions.Learnings → Reverse relation (auto-created)

**Usage**:
- Each learning optionally belongs to one session
- Sessions can have many learnings
- Rollup in Sessions counts learnings

**Integrity**:
- Learning.Session can be null (ad-hoc learnings outside sessions)
- If session deleted, learnings keep session_id (historical record)

### 4. Learnings ↔ Learning_Vectors (One-to-One)

**Implementation**:
- learning_id in Supabase references Learning ID in Notion
- Unique constraint ensures one vector per learning

**Synchronization**:
- When learning created: Generate embedding → Insert vector
- When learning updated: Regenerate embedding → Update vector
- When learning deleted: Delete vector (or mark as deleted in metadata)

**Consistency**:
- n8n workflow ensures both Notion and Supabase updated atomically
- If vector insert fails: Mark learning for retry, return success to user

---

## Data Validation Rules

### Learning ID Format

**Pattern**: `^[A-Z]{2,4}-\d{3}$`

**Examples**:
- BR-001 (Briseno)
- NOEL-045 (Noel)
- CC-112 (Claude Code)

**Generation Logic**:
```javascript
function extractPrefix(projectName) {
  // Remove special characters, convert to uppercase
  const clean = projectName.replace(/[^a-zA-Z\s]/g, '').toUpperCase();

  // Split into words
  const words = clean.split(/\s+/);

  if (words.length === 1) {
    // Single word: First 2-4 consonants
    const consonants = words[0].replace(/[AEIOU]/g, '');
    return consonants.slice(0, Math.min(4, Math.max(2, consonants.length)));
  } else {
    // Multiple words: First letter of each word
    return words.map(w => w[0]).join('').slice(0, 4);
  }
}

// Examples:
// "Briseno" → "BR"
// "Noel" → "NL"
// "Claude Code" → "CC"
// "API Gateway Service" → "AGWS" → "AGS" (truncated to 4)
```

### Session ID Format

**Pattern**: `^SESSION-\d{8}-\d{3}$`

**Examples**:
- SESSION-20251120-001
- SESSION-20251120-002

**Generation Logic**:
```javascript
function generateSessionID(date = new Date()) {
  // Format date as YYYYMMDD
  const dateStr = date.toISOString().slice(0, 10).replace(/-/g, '');

  // Query Notion for sessions on this date
  const existingSessions = queryNotionByDate(dateStr);

  // Find highest number
  const maxNum = existingSessions
    .map(s => parseInt(s.session_id.split('-')[2]))
    .reduce((max, n) => Math.max(max, n), 0);

  // Return next ID
  return `SESSION-${dateStr}-${String(maxNum + 1).padStart(3, '0')}`;
}
```

---

## State Transitions

### Learning Status

```
[Hypothesis] ──validate──> [Validated] ──deprecate──> [Deprecated]
     │                          │
     └──────────deprecate───────┘

Rules:
- New learnings default to "Hypothesis"
- Can move Hypothesis → Validated when confirmed
- Can move Validated → Deprecated when obsolete
- Cannot move Deprecated → Validated (create new learning instead)
```

### Session Status

```
[Active] ──end──> [Completed]
   │
   └──abandon──> [Abandoned]

Rules:
- New sessions start as "Active"
- User explicitly ends session → "Completed"
- Auto-close after 24h inactivity → "Abandoned"
- Cannot reactivate completed/abandoned sessions
```

---

## Data Retention Policy

### Learnings
- **Never deleted** automatically
- Deprecated learnings kept for historical reference
- Manual archival possible via Notion UI

### Sessions
- Keep indefinitely (disk space for recordings may be limiting factor)
- Recording files managed separately by user
- Recommend periodic backup to cloud storage

### Vectors
- Deleted when learning deleted (if implemented)
- Deprecated learnings keep vectors but excluded from searches

---

## Migration & Seeding

### Initial Project Setup

**Projects to Create**:
```json
[
  {
    "name": "Noel",
    "status": "Active",
    "priority": "P1-High",
    "tech_stack": ["n8n", "Notion", "Supabase", "OpenAI"],
    "description": "Knowledge repository system",
    "started": "2025-11-20"
  },
  {
    "name": "Briseno",
    "status": "Active",
    "priority": "P1-High",
    "tech_stack": ["n8n", "Notion", "Supabase", "OpenAI"],
    "description": "Multi-agent orchestration system",
    "started": "2025-10-01"
  }
]
```

### Sample Learnings for Testing

```json
[
  {
    "title": "n8n webhook trigger best practices",
    "project": "Noel",
    "type": "Pattern",
    "dev_stream": ["n8n", "API"],
    "content": "When creating webhook endpoints in n8n, always include validation nodes before processing...",
    "confidence": "High",
    "status": "Validated"
  }
]
```

---

## Backup Strategy

### Notion
- **Built-in**: Notion has automatic backups
- **Manual**: Export databases as CSV weekly
- **Version Control**: Document schemas in this file

### Supabase
- **Automatic**: Supabase free tier includes 7-day backups
- **Manual**: Export vectors as CSV monthly
- **Recovery**: Re-generate vectors from Notion if needed

### Recording Files
- **User Responsibility**: Not managed by system
- **Recommendation**: Sync ~/coding-sessions/ to Dropbox/Google Drive
- **Retention**: Keep recordings for 1+ year for session replay value

---

## Schema Evolution

### Adding New Properties (Notion)

**Process**:
1. Add property via Notion UI
2. Set default value for existing records
3. Update data-model.md documentation
4. Update n8n workflows to populate new property
5. Re-test webhook endpoints

### Changing Embedding Model

**Process**:
1. Create new Supabase table with new dimensions
2. Batch re-generate embeddings for all learnings
3. Update n8n workflow to use new model
4. Test search quality
5. Drop old table after validation

---

## Query Patterns

### Common Queries

**1. Recent learnings for a project**
```
Notion Query:
- Database: Learnings
- Filter: Project = "Noel" AND Status != "Deprecated"
- Sort: Timestamp descending
- Limit: 20
```

**2. All active sessions**
```
Notion Query:
- Database: Sessions
- Filter: Status = "Active"
- Sort: Start Time ascending
```

**3. Semantic search with filters**
```sql
Supabase Query:
SELECT * FROM learnings_vectors
WHERE metadata->>'project' = 'Briseno'
  AND metadata->'dev_streams' ? 'n8n'
ORDER BY embedding <=> $query_embedding
LIMIT 10;
```

**4. Project statistics**
```
Notion Rollup:
- Learning Count: count(Learnings where Status != "Deprecated")
- Session Count: count(Sessions)
- Total Session Hours: sum(Sessions.Duration)
```

---

## Performance Considerations

### Notion API Rate Limits
- 3 requests per second
- Implement request queuing in n8n
- Use batch operations where possible

### Supabase Query Performance
- IVFFlat index provides O(log n) search
- Expect <100ms for 1000 learnings
- Expect <500ms for 5000 learnings
- Monitor query times, adjust index parameters if needed

### Storage Growth
- Average learning: 1KB Notion + 6.5KB Supabase
- 1000 learnings: ~7.5MB total
- Free tier limits: 500MB Supabase, unlimited Notion pages

---

## Conclusion

All data models fully specified and ready for implementation. Notion databases can be created manually via UI following property definitions above. Supabase schema provided as SQL script. Proceed to API contracts definition.
