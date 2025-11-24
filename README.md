# Noel Knowledge Repository System

**A workflow-based knowledge management system for capturing, enriching, and retrieving development learnings across projects**

---

## Overview

Noel is a centralized learning repository that captures development knowledge via webhook endpoints, enriches it with AI-powered categorization, and enables semantic search across all learnings. It includes session tracking with replay capability to preserve the full context of how learnings were discovered.

### Key Features

- **📝 Learning Capture**: Store development insights, patterns, solutions, and errors via webhooks
- **🔍 Semantic Search**: Natural language queries with vector similarity search
- **🤖 AI Enrichment**: Automatic categorization, tagging, and metadata suggestions using GPT-4
- **📊 Project Management**: Organize learnings across multiple projects with statistics
- **🎬 Session Tracking**: Record coding sessions with asciinema for full replay capability
- **⚡ Quick Integration**: Bash helper scripts for seamless Claude Code integration

### Tech Stack

- **Orchestration**: n8n (visual workflow automation)
- **Structured Storage**: Notion (Projects, Learnings, Sessions databases)
- **Vector Search**: Supabase + pgvector (semantic similarity search)
- **AI Services**: OpenAI (text-embedding-3-small, GPT-4o-mini)
- **Development**: Node.js, JavaScript, Bash
- **Recording**: asciinema (session replay)

---

## Project Status

### ✅ Phase 0: Project Setup (COMPLETED)

- [x] All design documentation complete
  - spec.md - Feature specification with 5 user stories and 45 functional requirements
  - plan.md - Technical architecture and implementation plan
  - data-model.md - Notion and Supabase schemas with relationships
  - research.md - Technology decisions and design patterns
  - quickstart.md - Setup and testing guide
  - contracts/ - 8 OpenAPI specifications for all endpoints
- [x] Quality checklists validated (11/11 items passed)
- [x] Project structure created
- [x] .gitignore configured for Node.js, n8n, environment files
- [x] Helper scripts and functions ready for use

### 📋 Next Steps: Implementation

The system is **ready for implementation**. All design and planning work is complete. Follow `IMPLEMENTATION_GUIDE.md` for step-by-step instructions.

**Estimated Implementation Time**: 6-8 hours total
- Phase 1 (Infrastructure Setup): 30-45 minutes
- Phase 2 (Foundational Workflow): 1-2 hours
- Phases 3-7 (User Stories): 3-4 hours
- Phases 8-9 (Integration & Polish): 1-2 hours

---

## Quick Start

### Prerequisites

- Notion account (free plan sufficient)
- Supabase account (free plan sufficient)
- OpenAI API key with credits
- n8n installed (Docker or npm)
- ngrok installed (for webhook tunnel)
- asciinema installed (for session recording)

### Implementation Guide

Follow the comprehensive implementation guide:

```bash
# Read the implementation guide
cat IMPLEMENTATION_GUIDE.md

# Or follow the quickstart guide for detailed setup
cat specs/001-knowledge-repository/quickstart.md
```

### After Implementation

Once the system is set up, use the helper scripts:

```bash
# Source helper functions
source scripts/noel-helpers.sh

# Set webhook URL
export NOEL_WEBHOOK_URL="https://your-ngrok-url.ngrok.io/webhook"

# Start a session
noel-start-session "ProjectName" "Session goals"

# Capture a learning
noel-capture "ProjectName" "Learning Title" "Learning content"

# Query learnings
noel-query "search query"

# End session
noel-end-session

# View all commands
noel-help
```

---

## Project Structure

```
Noel_SK/
├── README.md                          # This file
├── IMPLEMENTATION_GUIDE.md            # Step-by-step implementation instructions
├── .gitignore                         # Git ignore patterns
│
├── specs/001-knowledge-repository/    # Complete design documentation
│   ├── spec.md                        # Feature specification
│   ├── plan.md                        # Implementation plan
│   ├── data-model.md                  # Database schemas and relationships
│   ├── research.md                    # Technology decisions
│   ├── quickstart.md                  # Setup and testing guide
│   ├── tasks.md                       # 91 implementation tasks across 9 phases
│   ├── contracts/                     # API specifications (8 endpoints)
│   │   ├── capture-learning.json
│   │   ├── update-learning.json
│   │   ├── query-learnings.json
│   │   ├── query-feedback.json
│   │   ├── list-projects.json
│   │   ├── create-session.json
│   │   ├── end-session.json
│   │   └── query-sessions.json
│   └── checklists/
│       └── requirements.md            # Quality validation (11/11 passed)
│
├── n8n-workflows/                     # n8n workflow definitions
│   ├── README.md                      # Workflow documentation
│   ├── Knowledge_Repository.json      # Main workflow (to be created)
│   └── helpers/                       # JavaScript helper functions
│       ├── generate_learning_id.js    # Learning ID generation
│       ├── generate_session_id.js     # Session ID generation
│       ├── input_validation.js        # Input validation for all endpoints
│       └── ai_enrichment.js           # AI categorization and tagging
│
└── scripts/                           # Bash helper scripts
    └── noel-helpers.sh                # Claude Code integration functions
```

---

## Architecture

### Data Model

**Three Notion Databases:**

1. **Projects** - Catalog of development projects
   - Properties: Name, Status, Priority, Tech Stack, Description
   - Rollups: Learning Count, Session Count, Total Session Hours

2. **Learnings** - Repository of development knowledge
   - Properties: Title, Learning ID, Project (relation), Type, Dev Stream, Content, Tags, Confidence, Status
   - Relations: Project (1:N), Session (N:1)

3. **Sessions** - Coding session tracking with replay
   - Properties: Session ID, Projects (relation), Goals, Start/End Time, Status, AI Type, Recording Path
   - Relations: Projects (N:M), Learnings (1:N)

**Supabase Vector Database:**

- `learnings_vectors` - 1536-dimension embeddings with metadata
- `query_feedback` - Query relevance feedback for metrics
- Indexes: IVFFlat for cosine similarity search

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/capture_learning` | POST | Store new learning with optional AI enrichment |
| `/update_learning` | POST | Update existing learning with status transitions |
| `/query_learnings` | POST | Semantic search across learnings |
| `/query_feedback` | POST | Submit query relevance feedback |
| `/list_projects` | POST | Query project catalog with filters |
| `/create_session` | POST | Start coding session with recording |
| `/end_session` | POST | Complete session and calculate duration |
| `/query_sessions` | POST | Retrieve session history with replay links |

### Workflow Architecture

Single n8n workflow orchestrates all operations:

```
Webhook Trigger → Validation → Business Logic → Response
                       ↓
                  Error Handler
```

Components:
- **Notion nodes**: CRUD operations on databases
- **Supabase HTTP nodes**: Vector similarity search
- **OpenAI nodes**: Embedding generation, AI enrichment
- **Function nodes**: JavaScript logic (validation, ID generation, formatting)

---

## User Stories

### 1. Capture Development Learning (P1) 🎯 MVP
As a developer, I want to capture learnings via webhook so I can quickly store insights without leaving my development environment.

**Acceptance Criteria:**
- POST to /capture_learning with project, title, content
- Auto-create projects if they don't exist
- Generate unique learning IDs (e.g., NOEL-001)
- Store in Notion with timestamp
- Return confirmation with learning ID

### 2. Query Learnings with Semantic Search (P2)
As a developer, I want to query learnings using natural language so I can find relevant insights even if I don't remember exact keywords.

**Acceptance Criteria:**
- POST to /query_learnings with natural language query
- Generate query embedding and search Supabase vectors
- Return top 10 results with similarity scores
- Support filters: project, dev_stream, type, confidence, status
- Exclude deprecated learnings by default

### 3. Manage Project Catalog (P3)
As a developer, I want to view all projects with learning statistics so I can see which projects have the most captured knowledge.

**Acceptance Criteria:**
- POST to /list_projects (optionally with filters)
- Return projects with: name, status, priority, tech_stack, learning_count, session_count
- Support filters: status, priority, tech_stack

### 4. AI-Powered Learning Enrichment (P4)
As a developer, I want learnings to be automatically categorized and tagged so I can capture quickly without manually filling all metadata.

**Acceptance Criteria:**
- When learning captured with minimal metadata, call GPT-4o-mini
- AI suggests: dev_streams (1-3), type, tags (3-5), confidence
- Merge AI suggestions with user-provided data (append, don't replace)
- Set ai_suggested flag in Notion

### 5. Session Tracking and Replay (P5)
As a developer, I want to track coding sessions with replay capability so I can review how learnings were discovered and share context with my team.

**Acceptance Criteria:**
- POST to /create_session with projects, goals, recording path
- Generate unique session ID (SESSION-YYYYMMDD-###)
- Associate learnings with active session
- POST to /end_session to complete and calculate duration
- Query sessions to retrieve replay file paths

---

## Data Entities

### Learning

```javascript
{
  learning_id: "NOEL-001",          // Unique ID (PROJECT-###)
  title: "n8n webhook pattern",     // 5-200 chars
  content: "...",                   // 10-50k chars (markdown supported)
  project: "Noel",                  // Project name (relation)
  type: "Pattern",                  // Pattern|Solution|Error|Decision|Insight|Anti-Pattern|Best Practice
  dev_stream: ["n8n", "API"],      // Back-end|Front-end|UI/UX|n8n|Database|API|DevOps|Architecture|Performance|Security
  tags: ["webhook", "n8n"],         // Array of strings
  confidence: "High",               // High|Medium|Low
  status: "Validated",              // Validated|Hypothesis|Deprecated
  session_id: "SESSION-...",        // Optional session reference
  ai_suggested: true,               // AI enrichment flag
  ai_accepted: false,               // User confirmed AI suggestions
  timestamp: "2025-11-20T10:30:00Z"
}
```

### Session

```javascript
{
  session_id: "SESSION-20251120-001",
  projects: ["Noel", "Briseno"],    // Array of project names
  goals: "Implement session tracking",
  start_time: "2025-11-20T09:00:00Z",
  end_time: "2025-11-20T11:30:00Z",
  status: "Completed",              // Active|Completed|Abandoned
  ai_type: "Claude",                // Claude|Gemini|Other
  recording_file_path: "~/coding-sessions/2025-11-20-claude-noel-001.cast",
  recording_format: "asciinema",
  learning_count: 5,                // Rollup from learnings
  duration_minutes: 150             // Calculated from start/end time
}
```

---

## Testing

### Manual Testing

```bash
# Set webhook URL
export NOEL_WEBHOOK_URL="https://your-ngrok-url.ngrok.io/webhook"

# Test capture
curl -X POST $NOEL_WEBHOOK_URL/capture_learning \
  -H 'Content-Type: application/json' \
  -d '{
    "project": "Noel",
    "title": "Test learning",
    "content": "Testing the knowledge repository system"
  }'

# Test query
curl -X POST $NOEL_WEBHOOK_URL/query_learnings \
  -H 'Content-Type: application/json' \
  -d '{"query": "knowledge repository"}'

# Test session
curl -X POST $NOEL_WEBHOOK_URL/create_session \
  -H 'Content-Type: application/json' \
  -d '{
    "projects": ["Noel"],
    "goals": "Testing session tracking",
    "ai_type": "Claude"
  }'
```

### Using Helper Scripts

```bash
source scripts/noel-helpers.sh

noel-capture "Noel" "Title" "Content"
noel-query "search query"
noel-projects
noel-start-session "Noel" "Session goals"
noel-end-session
```

---

## Performance Goals

- **Webhook Response**: <3 seconds including AI enrichment
- **Query Response**: <1 second for semantic search
- **Concurrent Captures**: Support 10+ simultaneous requests
- **Scale**: 5000+ learnings on free-tier Supabase (500MB)

---

## Success Criteria

- [x] All design documentation complete and validated
- [ ] All 8 webhook endpoints responding <3 seconds
- [ ] Semantic search returns relevant results 95%+ of time
- [ ] AI categorization accuracy >90%
- [ ] Zero data loss on successful webhook responses
- [ ] System runs on free-tier services
- [ ] Session recordings accessible for replay

---

## Cost Estimates

**Free Tier Services:**
- Notion: Unlimited pages (personal workspace)
- Supabase: 500MB database + 2GB bandwidth
- n8n: Unlimited workflows (self-hosted)

**Paid Services:**
- OpenAI API: ~$0.61 per 1000 learnings
  - Embeddings: $0.013 (text-embedding-3-small)
  - AI Enrichment: $0.60 (gpt-4o-mini)
- ngrok: Free tier sufficient for development

**Total Cost**: <$1/month for typical single-user usage (100-200 learnings/month)

---

## Troubleshooting

See `n8n-workflows/README.md` for detailed troubleshooting guide.

Common issues:
- **"Database not found"**: Update Notion database IDs in workflow
- **"pgvector not available"**: Enable vector extension in Supabase
- **"ngrok URL changed"**: Update NOEL_WEBHOOK_URL and webhook nodes

---

## Contributing

This is a personal knowledge repository system. For team use:
1. Enable Supabase Row Level Security (RLS)
2. Add authentication to webhook endpoints
3. Share Notion databases with team members
4. Consider deploying n8n to cloud (Railway, Render, DigitalOcean)

---

## License

Private project - Not licensed for public use

---

## Resources

### Documentation
- [Notion API Reference](https://developers.notion.com/reference)
- [Supabase pgvector Guide](https://supabase.com/docs/guides/ai/vector-embeddings)
- [OpenAI Embeddings Guide](https://platform.openai.com/docs/guides/embeddings)
- [n8n Documentation](https://docs.n8n.io/)
- [asciinema Format Spec](https://github.com/asciinema/asciinema)

### Project Files
- `IMPLEMENTATION_GUIDE.md` - Step-by-step implementation instructions
- `specs/001-knowledge-repository/quickstart.md` - Detailed setup guide
- `specs/001-knowledge-repository/tasks.md` - 91 implementation tasks
- `n8n-workflows/README.md` - Workflow architecture and testing

---

**Status**: ✅ Ready for implementation

**Next Action**: Follow `IMPLEMENTATION_GUIDE.md` to begin implementation
