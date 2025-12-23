# Noel_SK Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-12-18

---

## 🧠 NOEL DOMAIN MEMORY BIOS

**CRITICAL: This section loads FIRST for ALL Claude Code agents (main + subagents)**

Noel is not just a project - it's your **persistent domain memory system**. Every development session automatically integrates with Noel to load past learnings and capture new discoveries.

### Auto-Initialization

When working in ANY project (detected via git repo or directory):

1. **Load relevant learnings** from Noel at session start
2. **Track atomic progress** throughout the session
3. **Capture breakthroughs** as they happen (not after)
4. **Prevent anti-patterns** (no debug file clutter, time-bounded debugging)

### Environment Setup

```bash
# Required: Set webhook URL (already configured in .env)
export NOEL_WEBHOOK_URL="https://18f625ebc1f0.ngrok-free.app/webhook/noel"
export NOEL_AUTH_TOKEN="1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

# Auto-detect current project
CURRENT_PROJECT=$(basename $(git rev-parse --show-toplevel 2>/dev/null) || basename "$PWD")
```

### Noel API Integration (Pattern 2)

**All endpoints use single webhook URL with routing:**

```bash
# Query learnings (ALWAYS do this at session start)
curl -s --location "$NOEL_WEBHOOK_URL" \
  --header "Content-Type: application/json" \
  --header "Authorization: $NOEL_AUTH_TOKEN" \
  --data "{
    \"endpoint\": \"query_learnings\",
    \"query\": \"recent development patterns for $CURRENT_PROJECT\",
    \"filters\": {\"project\": \"$CURRENT_PROJECT\"},
    \"limit\": 5
  }" | jq -r '.results[]'

# Capture learning (when discovering patterns/solutions)
curl -s --location "$NOEL_WEBHOOK_URL" \
  --header "Content-Type: application/json" \
  --header "Authorization: $NOEL_AUTH_TOKEN" \
  --data "{
    \"endpoint\": \"capture_learning\",
    \"project\": \"$CURRENT_PROJECT\",
    \"title\": \"<title>\",
    \"content\": \"<description>\",
    \"type\": \"Pattern|Solution|Error|Insight\",
    \"confidence\": \"High|Medium|Low\"
  }" | jq '.'
```

### When to Use Noel (Automatic Triggers)

**QUERY (Load Context):**
- ✅ **Session start** - Load top 5 relevant learnings for current task
- ✅ **Before debugging** - "How have I debugged similar issues?"
- ✅ **Before implementing** - "What patterns exist for this?"
- ✅ **When stuck** - "What have I learned about this technology?"

**CAPTURE (Save Discovery):**
- ✅ **Solved non-trivial problem** - Save the solution pattern
- ✅ **Discovered workaround** - Document the limitation and fix
- ✅ **Fixed bug with root cause** - Explain why it happened
- ✅ **Found useful pattern** - Describe when/how to apply it
- ✅ **Hit dead end** - Document what DOESN'T work (anti-patterns)

**DO NOT capture:**
- ❌ Routine file creation or trivial edits
- ❌ Following existing patterns exactly
- ❌ Reading documentation (unless extracted key insight)

### Anti-Pattern Prevention

**Before creating ANY debug file**, ask:
1. "Is this a learning that should go in Noel?"
2. "Will this be useful beyond this session?"

If yes → **Capture to Noel**, not a file.

**Time boundaries for debugging:**
- Max 30 minutes per debugging attempt
- After 30 min: Capture findings (even if incomplete), take break
- Query Noel before repeating similar debugging

**Track progress atomically:**
- One change at a time
- Verify immediately
- Capture significant discoveries in real-time

---

## Project Overview

Noel is a workflow-based knowledge management system for capturing, enriching, and retrieving development learnings. This is NOT a traditional code repository - implementation is primarily done through n8n visual workflows and cloud service UIs.

## Active Technologies

- **Orchestration**: n8n (visual workflow automation)
- **Storage**: Notion (Projects, Learnings, Sessions databases)
- **Vector Search**: Supabase + pgvector
- **AI Services**: OpenAI (text-embedding-3-small, GPT-4o-mini)
- **Recording**: asciinema (session replay)
- **Scripting**: Bash, JavaScript (Node.js 18+)

## Project Structure

```text
Noel_SK/
├── README.md                          # Project overview and quick start
├── IMPLEMENTATION_GUIDE.md            # Step-by-step implementation instructions
├── .gitignore                         # Ignore patterns configured
│
├── specs/001-knowledge-repository/    # Complete design documentation
│   ├── spec.md                        # Feature specification
│   ├── plan.md                        # Technical architecture
│   ├── data-model.md                  # Database schemas
│   ├── research.md                    # Technology decisions
│   ├── quickstart.md                  # Setup guide
│   ├── tasks.md                       # 91 implementation tasks
│   ├── contracts/                     # API specifications (8 endpoints)
│   └── checklists/                    # Quality validation
│
├── n8n-workflows/                     # n8n workflow definitions
│   ├── README.md                      # Workflow documentation
│   ├── Knowledge_Repository.json      # Main workflow (to be created)
│   └── helpers/                       # JavaScript helper functions
│       ├── generate_learning_id.js
│       ├── generate_session_id.js
│       ├── input_validation.js
│       └── ai_enrichment.js
│
└── scripts/                           # Bash helper scripts
    └── noel-helpers.sh                # Claude Code integration
```

## Commands

### Helper Script Commands (after implementation)

```bash
# Source helper functions
source scripts/noel-helpers.sh
export NOEL_WEBHOOK_URL="https://your-ngrok-url.ngrok.io/webhook"

# Session management
noel-start-session <project> <goals>   # Start session with recording
noel-end-session                        # End current session

# Learning management
noel-capture <project> <title> <content>  # Capture learning
noel-update <learning_id> [options]       # Update learning
noel-query <query> [project]              # Search learnings
noel-feedback <query> <learning-ids>      # Submit feedback

# Project management
noel-projects [status]                    # List projects
noel-sessions [project]                   # List sessions

# Help
noel-help                                 # Display all commands
```

### Implementation Commands

```bash
# Start n8n
n8n start  # or docker run n8nio/n8n

# Start ngrok tunnel
ngrok http 5678

# Test endpoints with curl
curl -X POST $NOEL_WEBHOOK_URL/capture_learning -H 'Content-Type: application/json' -d '{...}'
```

## Code Style

**JavaScript (n8n Function nodes):**
- Use ES6+ syntax
- Clear variable names (no single letters except loops)
- Include error handling (try-catch)
- Add comments for complex logic
- Return structured JSON objects

**Bash (Helper scripts):**
- Use shellcheck for validation
- Include usage documentation in comments
- Use color codes for output (green=success, red=error, blue=info)
- Check prerequisites before execution
- Use jq for JSON parsing

**Notion Property Naming:**
- Use Title Case (e.g., "Learning ID", "Dev Stream")
- No abbreviations in property names
- Use rich text for markdown content

## Implementation Status

### ✅ Completed (Phase 0)
- All design documentation complete and validated
- Project structure created
- Helper scripts and functions ready
- .gitignore configured
- Quality checklists passed (11/11)

### 📋 Pending (Phases 1-9)
All implementation phases are pending manual setup through UIs:
- Phase 1: Infrastructure setup (Notion, Supabase, n8n, ngrok, asciinema)
- Phase 2: Foundational n8n workflow with 8 webhook triggers
- Phases 3-7: User story implementations (5 stories)
- Phase 8: Integration and helper scripts
- Phase 9: Polish and documentation

**Next Action:** Follow `IMPLEMENTATION_GUIDE.md` for step-by-step instructions

## Recent Changes

- 2025-11-20: Initial project setup and design complete
- 2025-11-20: Helper scripts and JavaScript functions created
- 2025-11-20: All documentation and contracts finalized
- Ready for implementation phase

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
