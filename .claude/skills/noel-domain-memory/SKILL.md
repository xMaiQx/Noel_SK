---
name: noel-domain-memory
description: Domain memory BIOS for Noel project development. This skill should be used when working on the Noel Knowledge Repository project to load relevant learnings, track atomic progress, and capture new knowledge. Automatically initializes at session start with context loading from Noel's RAG system.
---

# Noel Domain Memory - Development BIOS

This skill implements persistent domain memory for Noel development using a two-agent pattern: an initializer agent that loads relevant context from Noel's RAG system, and a coding agent that makes atomic progress while capturing learnings back to Noel.

## When This Skill Activates

This skill automatically activates when:
- Working in the Noel_SK project directory
- User explicitly invokes it with `Use noel-domain-memory`
- User mentions "Noel" development tasks

## The Two-Agent Pattern

### Initializer Agent (Session Start)
The initializer "sets the stage" by:
1. Validating environment (ngrok, n8n, Noel API)
2. Querying Noel for relevant past learnings
3. Creating local state file with loaded context
4. Registering session in Noel
5. Presenting context summary to user

### Coding Agent (Continuous)
The coding agent enforces disciplined progress by:
1. Loading state before each task
2. Making ONE atomic, testable change
3. Verifying the outcome
4. Updating state with progress
5. Capturing significant learnings to Noel
6. Tracking KPIs to prevent anti-patterns

## Initialization Sequence (BIOS Boot)

When this skill activates, run through this checklist:

### 1. Environment Check

```bash
# Verify NOEL_WEBHOOK_URL is set
echo $NOEL_WEBHOOK_URL

# Test ngrok tunnel is active
curl -s "$NOEL_WEBHOOK_URL/list_projects" -H "Content-Type: application/json" -d '{"filters":{}}' | jq '.success'

# Verify n8n workflow is responsive (should return true)
```

If any check fails, guide user to fix before proceeding.

### 2. Context Query

```bash
# Source bash helpers
source /Users/murodos/Documents/_Mad_Panda_/Proyectos/Noel_SK/scripts/noel-helpers.sh

# Query Noel for recent development learnings
noel-query "Recent Noel development patterns and solutions" "Noel"
```

Extract top 5 learnings by similarity score for loading into state.

### 3. State Initialization

```bash
# Create .noel directory if needed
mkdir -p .noel/sessions

# Run init script (creates session state from template)
python3 .claude/skills/noel-domain-memory/scripts/init.py
```

This creates `.noel/session-state.json` with:
- Session metadata (ID, timestamp, project)
- Loaded learnings from Noel
- Active blockers (if any)
- Empty atomic progress array
- Initialized KPI counters

### 4. Session Registration

```bash
# Register session in Noel
noel-start-session "Noel" "Implement domain memory skill"
```

Store the returned SESSION-ID in state and export as `CURRENT_SESSION_ID` environment variable.

### 5. Present Context

Display a boot summary showing:
- Environment status (all checks passed)
- Loaded learnings (top 5 with similarity scores)
- Active blockers from previous sessions
- Session goals
- Initialized KPIs

Format:
```
[Noel Domain Memory BIOS v1.0]

Environment Check:
✓ NOEL_WEBHOOK_URL configured
✓ ngrok tunnel active (https://xxxxx.ngrok-free.app)
✓ n8n workflow responsive

Loaded Learnings (5):
  [NOEL-012] n8n webhook routing (87% match)
    → Single endpoint, route via 'endpoint' field in body
  [NOEL-034] Vector embedding format (82% match)
    → PostgreSQL requires plain arrays [1,2,3]
  [NOEL-018] n8n execution stops (79% match)
    → Enable "Always Output Data" for optional results
  ...

Session Started:
  ID: SESSION-2025-12-18-001
  Goals: Implement domain memory skill

KPIs Initialized:
  Learnings loaded: 5
  Atomic steps: 0
  Debug files: 0

Ready for atomic progress. What should we tackle first?
```

## Atomic Progress Discipline (Coding Agent Mode)

For EVERY development task, follow this workflow:

### 1. Load Current State

```python
# Always check current state before working
state = load_state('.noel/session-state.json')
print(f"Loaded {len(state['relevant_learnings'])} learnings")
print(f"Completed {state['kpis']['atomic_steps_completed']} atomic steps so far")
```

### 2. Review Relevant Learnings

Before implementing, check if similar problems have been solved:

```
Task: "Add vector search debugging"
Check learnings for: "vector", "search", "debug", "Supabase"
Found: NOEL-034 (Vector embedding format issue)
Apply: Use plain array format, not JSON strings
```

If a relevant learning exists, apply it and increment `learnings_applied` KPI.

### 3. Make ONE Atomic Change

An atomic change is:
- **Single file** modification (or single new file)
- **Single function** implementation
- **Single test** case
- **Independently testable** - can verify without other changes

Examples of atomic changes:
- ✓ "Add validate_environment() function to init.py"
- ✓ "Create state-template.json with schema"
- ✓ "Extract Learning 1 from SESSION_LEARNINGS to common-patterns.md"
- ✗ "Refactor all scripts and update SKILL.md" (too broad)
- ✗ "Fix bugs and add features" (multiple changes)

### 4. Verify Outcome

Every atomic change MUST have a verification step:
- Code changes: Run syntax check, import test, or unit test
- File creation: Verify file exists and is valid (JSON parse, markdown render)
- API calls: Test endpoint with curl, check response
- Script execution: Run script, verify expected output

NO "looks good" or "should work" - require evidence.

### 5. Update State

```python
# After successful verification
from scripts.state import update_progress, increment_kpi, save_state

update_progress(
    state,
    action="Created state-template.json with domain memory schema",
    test="Validated JSON parsing with python -m json.tool",
    outcome="success",
    learning_id=None  # Only if this step captured a learning
)

increment_kpi(state, 'atomic_steps_completed')
save_state('.noel/session-state.json', state)
```

### 6. Capture Learning (If Significant)

Capture a learning when:
- Discovered a new pattern or solution
- Solved a non-trivial problem
- Fixed a bug with root cause analysis
- Found a workaround for a limitation

Do NOT capture for:
- Routine file creation
- Trivial syntax fixes
- Following existing patterns exactly

```bash
# Capture significant learnings
noel-capture "Noel" \
  "Domain memory state schema design" \
  "Use local .noel/session-state.json for granular progress tracking, sync summary to Noel at session end. Avoids API spam while maintaining persistence." \
  "Pattern" \
  "High"

# Returns: NOEL-045
# Update state with learning_id
```

## Anti-Pattern Prevention

This skill actively prevents the problems that created 17 debug files:

### Before Creating ANY Debug File

Ask yourself:
1. "Is this a learning that should go in Noel?"
2. "Will this be useful later, or just this session?"
3. "Does a similar debug file already exist?"

If it's valuable beyond this session: **Capture it as a learning, not a file.**

If you MUST create a debug file:
- Put it in `.noel/debug/` (gitignored)
- Increment `debug_files_created` KPI
- Capture the FINDING as a learning, then delete the file

### Time Boundaries for Debugging

- Max 30 minutes per debugging attempt
- After 30 min: Stop, capture what you learned (even if incomplete), take a break
- Before starting: Query Noel for similar past debugging sessions

### Query Before Repeating Work

Before debugging similar issues:
```bash
noel-query "debugging vector search empty results" "Noel"
# If found: Apply existing solution (increment learnings_applied)
# If not found: Proceed, but capture solution when found
```

### Track Debug File Creation

The `debug_files_created` KPI should stay at **0**. If it increases:
- Review: Was this necessary?
- Capture the finding as a learning
- Delete the debug file
- Update KPI back to 0 if finding was captured

## Session End Protocol

When user indicates session is ending (or after 2+ hours of work):

### 1. Review Atomic Progress

```python
state = load_state('.noel/session-state.json')
print(f"\nSession Summary:")
print(f"Atomic steps completed: {state['kpis']['atomic_steps_completed']}")
print(f"Learnings captured: {state['kpis']['learnings_captured']}")
print(f"Learnings applied: {state['kpis']['learnings_applied']}")
print(f"Debug files created: {state['kpis']['debug_files_created']}")

print(f"\nAtomic Progress:")
for step in state['atomic_progress']:
    print(f"  [{step['timestamp']}] {step['action']}")
    if step['learning_captured']:
        print(f"    → Learning: {step['learning_id']}")
```

### 2. Identify Uncaptured Learnings

Review `atomic_progress` array for significant steps without `learning_captured=true`.

Prompt user:
```
These steps look significant but weren't captured as learnings:
1. [00:45] Created two-agent pattern workflow harness
2. [01:30] Designed KPI tracking system

Should we capture these before ending the session?
```

### 3. Batch Capture

For each confirmed learning:
```bash
noel-capture "Noel" "<title>" "<content>" "<type>" "<confidence>"
```

Update state with `learning_captured=true` and `learning_id`.

### 4. End Session in Noel

```bash
noel-end-session

# Returns:
# ✓ Session ended: SESSION-2025-12-18-001
#   Duration: 127 minutes
#   Learnings captured: 5
#   Recording saved: /path/to/recording.cast
```

### 5. Archive State

```bash
# Archive current session state
cp .noel/session-state.json .noel/sessions/SESSION-2025-12-18-001.json

# State persists for next session initialization to check for blockers
```

### 6. Display Final KPIs

```
Session Complete: SESSION-2025-12-18-001
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Duration: 127 minutes
Atomic steps: 23
Learnings loaded: 5
Learnings applied: 3
Learnings captured: 5
Debug files created: 0 ✓

Next session will load today's learnings automatically.
```

## KPI Dashboard

Track these metrics throughout the session:

- **learnings_loaded**: How many past learnings were loaded at session start
- **learnings_applied**: How many loaded learnings were used to solve problems
- **learnings_captured**: How many new learnings were saved to Noel
- **atomic_steps_completed**: Number of atomic changes made
- **debug_files_created**: Number of debug files created (goal: 0)

These KPIs should be visible in state file and displayed periodically during long sessions.

## Project-Specific Learnings

These patterns have been discovered during Noel development:

### Notion API Patterns

**Two ID Types** (NOEL-001):
- Database ID: For schema operations (`retrieve_database`)
- Data Source ID: For querying records (`query_data_source`)
- NOT interchangeable! Using wrong ID returns empty results
- Get Data Source ID from `data_sources[0].id` in `retrieve_database` response

**Property Name Gotchas** (NOEL-004):
- Trailing spaces in property names break validation
- Always use automated verification, not manual checks
- Visual inspection misses whitespace issues

### n8n Workflow Patterns

**Webhook Routing** (NOEL-012):
- Single webhook path: `/webhook/noel`
- Route to different operations via `endpoint` field in POST body
- All 8 endpoints use same URL, different `endpoint` values

**Execution Behavior** (NOEL-018):
- Nodes stop when previous node returns empty array
- Enable "Always Output Data" for nodes with optional results
- Use default value nodes to prevent execution stops

**Code Node Limitations** (NOEL-025):
- n8n Code nodes don't support browser APIs (no `fetch()`)
- Use HTTP Request nodes for API calls
- Use Code nodes only for data transformation

### Vector Search Patterns

**Embedding Format** (NOEL-034):
- PostgreSQL pgvector requires plain array strings: `[1,2,3]`
- NOT JSON stringified: `"[1,2,3]"` (breaks vector operations)
- Supabase RPC returns `null` similarity if format is wrong

**Empty Results Debugging** (NOEL-041):
- First check: Are embeddings actually stored? (query `learnings_embeddings` table)
- Second check: Is pgvector extension enabled? (run `SELECT * FROM pg_extension`)
- Third check: Is vector column correct type? (`vector(1536)` not `text`)
- Last resort: Test `<=>` operator directly with raw SQL

### Bash Integration Patterns

**Piping to Python** (NOEL-002):
- curl progress bar pollutes JSON when piping
- Solution 1: Suppress stderr with `2>/dev/null`
- Solution 2: Use file intermediary
- Solution 3: Quote heredoc delimiter `<< 'EOF'`

**Path Resolution** (NOEL-003):
- `${BASH_SOURCE[0]}` empty when sourcing scripts
- Use fallback: Try multiple path resolution methods
- Check for `.env` in multiple locations

**ngrok URL Updates** (NOEL-009):
- ngrok URL changes on every restart
- Automate extraction via `localhost:4040/api/tunnels`
- Update `.env` file programmatically

### Automation Principles

**Automated Verification** (NOEL-006):
- Manual checklists miss: trailing spaces, plural/singular errors, missing fields
- Automation catches ALL discrepancies instantly
- ROI: 15-30 min manual → 5 sec automated, 100% accuracy

**Constitution as Validation** (NOEL-010):
- Formal project constitution prevents scope creep
- Architecture principles established BEFORE implementation
- Automation verifies constitution compliance
- Pattern: Write constitution → Run analysis → Flag violations

## State File Schema Reference

The `.noel/session-state.json` structure:

```json
{
  "metadata": {
    "session_id": "SESSION-2025-12-18-001",
    "created_at": "2025-12-18T00:30:00Z",
    "last_updated": "2025-12-18T01:45:00Z",
    "project": "Noel",
    "skill_version": "1.0.0"
  },

  "session_context": {
    "goals": "Implement domain memory skill for Noel development",
    "current_task": "Create SKILL.md with initialization sequence",
    "branch": "001-knowledge-repository",
    "ngrok_url": "https://f90ea6f6912c.ngrok-free.app",
    "webhook_endpoint": "/webhook/noel"
  },

  "relevant_learnings": [
    {
      "learning_id": "NOEL-012",
      "title": "n8n webhook URL structure",
      "key_insight": "Single webhook path, route via 'endpoint' field",
      "similarity_score": 0.87,
      "captured_at": "2025-12-14",
      "applied_count": 0
    }
  ],

  "active_blockers": [
    {
      "blocker_id": "B001",
      "description": "17 debug files cluttering root directory",
      "impact": "Circular debugging, no knowledge carryover",
      "status": "addressing_with_skill"
    }
  ],

  "atomic_progress": [
    {
      "timestamp": "2025-12-18T01:00:00Z",
      "action": "Created skill directory structure",
      "test": "Verified with ls -la",
      "outcome": "success",
      "learning_captured": false
    }
  ],

  "kpis": {
    "learnings_loaded": 5,
    "learnings_applied": 0,
    "learnings_captured": 0,
    "atomic_steps_completed": 1,
    "debug_files_created": 0
  }
}
```

## Bundled Resources

### Scripts

- `scripts/init.py` - Initialize session state (run during BIOS boot)
- `scripts/state.py` - State management utilities (load, save, update)
- `scripts/capture.py` - Learning capture wrapper

### References

- `references/common-patterns.md` - Extracted learnings from SESSION_LEARNINGS.md
- `references/api-contracts.md` - Noel API endpoint specifications

### Assets

- `assets/state-template.json` - Domain memory state schema template

## Usage Examples

### Example 1: Session Start

```
User: "Let's work on adding bulk import to Noel"

Claude (initializer mode):
[Runs BIOS boot sequence]
[Queries Noel for "bulk import" and "API endpoint" patterns]
[Creates state with loaded learnings]
[Presents context]

Loaded Learnings (3):
  [NOEL-008] Webhook routing pattern
  [NOEL-019] Batch processing in n8n
  [NOEL-027] JSON schema validation

Based on NOEL-008, we should add 'bulk_import' to the webhook routing...

User: "Yes, let's start"

Claude (coder mode):
[Makes atomic change: Add endpoint to webhook switch]
[Tests with curl]
[Updates state]
[Continues with next atomic step]
```

### Example 2: Hitting a Blocker

```
User: "Vector search is returning empty results again"

Claude (checks state.relevant_learnings):
Found: NOEL-034 (Vector embedding format issue)
Key insight: PostgreSQL vector requires plain arrays, not JSON strings

Let me check the current embedding format in the code...
[Applies known solution]
[Tests]
[Updates state: learnings_applied += 1]

This matches NOEL-034. Fixed by ensuring embedding is stored as plain array.
Incrementing learnings_applied KPI.
```

### Example 3: Discovering New Pattern

```
Claude: [After solving novel issue]
This pattern isn't in our loaded learnings. Should we capture this?

User: "Yes"

Claude:
[Calls noel-capture with details]
[Receives learning_id: NOEL-046]
[Updates state:
 - atomic_progress.learning_captured = true
 - atomic_progress.learning_id = "NOEL-046"
 - kpis.learnings_captured += 1]

Captured as NOEL-046. This will be available in future sessions.
```

## Troubleshooting

### Skill Doesn't Auto-Trigger

Check:
- Are you in `/Users/murodos/Documents/_Mad_Panda_/Proyectos/Noel_SK/` directory?
- Does `.claude/skills/noel-domain-memory/SKILL.md` exist?
- Manually invoke: "Use noel-domain-memory skill"

### Environment Check Fails

**NOEL_WEBHOOK_URL not set**:
```bash
export NOEL_WEBHOOK_URL="https://your-ngrok-url.ngrok-free.app/webhook"
```

**ngrok tunnel not responding**:
```bash
# Check ngrok is running
ps aux | grep ngrok

# Restart if needed
ngrok http 5678

# Update URL in .env
```

**n8n workflow not responsive**:
```bash
# Check n8n is running
ps aux | grep n8n

# Start if needed
n8n start

# Or use Docker
docker start n8n
```

### State File Corrupted

```bash
# Backup current state
mv .noel/session-state.json .noel/session-state.backup.json

# Regenerate from template
python3 .claude/skills/noel-domain-memory/scripts/init.py

# Or restore from previous session
cp .noel/sessions/SESSION-<latest>.json .noel/session-state.json
```

### API Calls Failing

Check `references/api-contracts.md` for correct endpoint specification.

Test directly:
```bash
source scripts/noel-helpers.sh
noel-query "test query" "Noel"
```

If all helpers fail, verify:
1. ngrok URL is current (may have changed)
2. n8n workflow is active
3. Notion/Supabase credentials in n8n are valid

## Version History

- **v1.0.0** (2025-12-18): Initial implementation with two-agent pattern, KPI tracking, and anti-pattern prevention
