# Option C: Smart Detection + Auto-Registration - Detailed Plan

## Overview

Implement fully automatic project/session management with smart ID detection for optimal UX.

---

## 1. Project Auto-Registration

### Current State
- Projects database exists in Notion
- Schema: Name (Title), Status (Select), Priority (Select), Tech Stack (Multi-select), Description (Text), Started (Date), Last Activity (Date)
- Learnings have Project relation (one-to-many)
- Sessions have Projects relation (many-to-many)

### Design Questions & Answers

#### Q1: How do we track project IDs?
**Answer: In-workflow query + response caching**

**Strategy**:
1. **No persistent cache** - Notion is the source of truth
2. **Per-request lookup** - Each capture_learning queries Projects if project name provided
3. **Return project_id in response** - Client can cache if desired
4. **Projects database query** - Fast, uses Notion's Title filter

**Why no persistent cache?**
- n8n workflows are stateless
- Notion could be modified outside workflow
- Query overhead is minimal (1 extra API call)
- Keeps implementation simple

#### Q2: What actions trigger project registration?

**Triggers**:
1. **capture_learning** with `project: "ProjectName"`
2. **start_session** with `project: "ProjectName"`

**Action Flow**:
```
1. Parse project name from request
2. Query Projects database: filter by Title = "ProjectName"
3. IF found:
     - Extract project page_id
     - Use for relation
     ELSE:
     - Create new project page with defaults
     - Extract new project page_id
     - Use for relation
4. Continue with learning/session creation
```

**Default Project Values** (when auto-created):
```javascript
{
  "Name": "<project_name>",           // From request
  "Status": "Active",                  // Default
  "Priority": "P2-Medium",             // Default
  "Tech Stack": [],                    // Empty, user adds later
  "Description": "",                   // Empty, user adds later
  "Started": "<current_date>",         // Auto-set on creation
  "Last Activity": "<current_date>"    // Auto-updated on each learning
}
```

#### Q3: Should we validate/sanitize project names?

**Yes - Validation Rules**:
- **Max length**: 100 characters (Notion Title limit: 2000, but practical limit)
- **Required**: Cannot be empty string
- **Allowed characters**: Alphanumeric, spaces, hyphens, underscores, dots
- **Trimming**: Remove leading/trailing whitespace
- **Case**: Preserve as provided (Notion is case-sensitive)

**Validation Logic**:
```javascript
function validateProjectName(name) {
  if (!name || typeof name !== 'string') {
    throw new Error('Project name is required');
  }

  const trimmed = name.trim();

  if (trimmed.length === 0) {
    throw new Error('Project name cannot be empty');
  }

  if (trimmed.length > 100) {
    throw new Error('Project name too long (max 100 chars)');
  }

  const validPattern = /^[a-zA-Z0-9\s\-_.]+$/;
  if (!validPattern.test(trimmed)) {
    throw new Error('Project name contains invalid characters');
  }

  return trimmed;
}
```

#### Q4: What happens to Last Activity date?

**Auto-update on every learning capture**:
- When learning is captured for a project
- Update Project's "Last Activity" field to current timestamp
- Enables tracking project engagement over time

**Implementation**:
- After creating learning, query project page
- Update "Last Activity" property
- This is a second API call, but valuable for analytics

---

## 2. Smart Session ID Detection

### Current State
- Sessions database exists in Notion
- Session ID format: `YYYYMMDD-HHMM-projectname` (e.g., "20251124-2051-noel-sk")
- Session ID is stored in Title field
- start_session returns both `session_id` (string) and `page_id` (UUID)

### Design Questions & Answers

#### Q1: How do we detect UUID vs human-readable format?

**Answer: Regex pattern matching**

**Detection Logic**:
```javascript
function detectSessionIdFormat(sessionId) {
  if (!sessionId) return null;

  // UUID v4 pattern: 8-4-4-4-12 hex characters
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

  if (uuidPattern.test(sessionId)) {
    return {
      format: 'uuid',
      value: sessionId,
      needsLookup: false
    };
  }

  // Human-readable pattern: YYYYMMDD-HHMM-*
  const humanPattern = /^\d{8}-\d{4}-.+$/;

  if (humanPattern.test(sessionId)) {
    return {
      format: 'human_readable',
      value: sessionId,
      needsLookup: true
    };
  }

  throw new Error(`Invalid session_id format: ${sessionId}`);
}
```

#### Q2: What's the lookup process for human-readable IDs?

**Lookup Flow**:
```
1. Detect format (UUID or human-readable)
2. IF UUID:
     - Use directly
     - Skip lookup
   ELSE IF human-readable:
     - Query Sessions database
     - Filter: Title equals session_id
     - Page size: 1
     - IF found:
         - Extract page_id from results[0].id
         - Use for relation
       ELSE:
         - Throw error: "Session not found: {session_id}"
3. Continue with learning creation
```

**Error Handling**:
- Session not found → Return 404-style error to user
- Multiple sessions found → Use first result (shouldn't happen with Title uniqueness)
- Notion API error → Propagate to user with context

#### Q3: Should we cache session lookups?

**Answer: No persistent cache, but optimize flow**

**Why no cache?**:
- Sessions are short-lived
- Typical session has 5-20 learnings max
- Lookup cost is minimal (1 Notion API call)
- Cache invalidation complexity not worth it

**Optimization Instead**:
- Return session page_id in capture_learning response
- Client can use UUID directly for subsequent captures in same session
- Helper scripts can store UUID in environment variable after first lookup

---

## 3. Unclosed Sessions Handling

### Problem Statement
Sessions can be left "Active" if:
- User forgets to call end_session
- Script crashes before cleanup
- System shutdown during session
- User abandons session

### Design Questions & Answers

#### Q1: How do we detect abandoned sessions?

**Answer: Scheduled auto-close workflow**

**Detection Criteria**:
- Status = "Active"
- Last Modified > 24 hours ago
- No associated learnings in last 24 hours

**Why Last Modified?**:
- Updated every time session is touched (create, update, associate learning)
- Indicates actual activity, not just elapsed time

#### Q2: What action should we take on abandoned sessions?

**Answer: Auto-close with special status**

**Action Options**:
| Option | Pros | Cons |
|--------|------|------|
| Set Status="Abandoned" | Clear signal | Loses completion time data |
| Set Status="Completed" + flag | Duration calculated | Misleading (wasn't explicitly ended) |
| Set Status="Auto-Closed" | Most accurate | Need new status option |

**Recommended: Add "Abandoned" status to Sessions**

**Auto-close Logic**:
```javascript
// Scheduled workflow runs every hour
// Query Active sessions older than 24h

const cutoffTime = new Date(Date.now() - 24 * 60 * 60 * 1000);

const abandonedSessions = await queryNotionSessions({
  filter: {
    and: [
      { property: 'Status', select: { equals: 'Active' } },
      { property: 'Start Time', date: { before: cutoffTime } }
    ]
  }
});

for (const session of abandonedSessions) {
  await updateSession(session.id, {
    'Status': { select: { name: 'Abandoned' } },
    'End Time': { date: { start: new Date().toISOString() } }
  });
}
```

#### Q3: Should we notify users about auto-closed sessions?

**Answer: Log only, no active notification**

**Rationale**:
- This is a cleanup mechanism, not critical path
- User can query abandoned sessions if needed
- Notification adds complexity (email, webhook, etc.)

**Implementation**:
- n8n execution log records closed sessions
- User can query: `list_sessions?status=Abandoned`
- Helper script can warn if previous session is still Active

#### Q4: Should end_session fail if session is already closed?

**Answer: Idempotent - allow multiple calls**

**Behavior**:
```javascript
// end_session endpoint
if (session.status === 'Completed' || session.status === 'Abandoned') {
  // Already closed, return success with current state
  return {
    success: true,
    message: 'Session already closed',
    session_id: session.id,
    status: session.status,
    already_closed: true
  };
}

// Otherwise, close it
updateSession({
  'Status': 'Completed',
  'End Time': now
});
```

#### Q5: What happens to learnings from abandoned sessions?

**Answer: Keep associations, they're still valid**

- Learnings remain associated with abandoned session
- Session still appears in learning's Session relation
- Learning Count rollup still accurate
- Duration calculation may be inaccurate (shows time until auto-close, not actual session end)

**This is acceptable** because:
- Learnings were genuinely captured during that session
- User can manually update session end time if needed
- Abandoned status signals "end time is approximate"

---

## 4. State Management & Caching

### Session State in Helper Scripts

#### Current Session Tracking
```bash
# In noel-helpers.sh
noel-start-session() {
  local project=$1
  local goals=$2

  # Call API
  response=$(curl ...)

  # Extract both IDs
  session_id=$(echo $response | jq -r '.session_id')
  page_id=$(echo $response | jq -r '.page_id')

  # Export for use by other functions
  export NOEL_CURRENT_SESSION_ID="$session_id"      # Human-readable
  export NOEL_CURRENT_SESSION_UUID="$page_id"       # UUID (optimization)

  # Store in temp file for persistence across terminal sessions
  echo "$session_id" > ~/.noel_session_id
  echo "$page_id" > ~/.noel_session_uuid

  echo "Session started: $session_id"
}

noel-capture() {
  # Prefer UUID if available (avoids lookup)
  local session_param=""
  if [ -n "$NOEL_CURRENT_SESSION_UUID" ]; then
    session_param="\"session_id\": \"$NOEL_CURRENT_SESSION_UUID\""
  elif [ -n "$NOEL_CURRENT_SESSION_ID" ]; then
    session_param="\"session_id\": \"$NOEL_CURRENT_SESSION_ID\""
  fi

  # Call API with session parameter
  curl ... -d "{ ... $session_param }"
}

noel-end-session() {
  # Use human-readable ID (end_session supports it)
  local session_id="${NOEL_CURRENT_SESSION_ID:-$(cat ~/.noel_session_id)}"

  curl ... -d "{\"endpoint\": \"end_session\", \"session_id\": \"$session_id\"}"

  # Cleanup
  unset NOEL_CURRENT_SESSION_ID
  unset NOEL_CURRENT_SESSION_UUID
  rm -f ~/.noel_session_id ~/.noel_session_uuid
}
```

### Project State - No Caching Needed

**Approach: Always use project name, let workflow handle lookup**

```bash
noel-capture() {
  local project="$1"
  local title="$2"
  local content="$3"

  # Pass project name directly, workflow handles lookup/creation
  curl ... -d "{
    \"endpoint\": \"capture_learning\",
    \"project\": \"$project\",
    \"title\": \"$title\",
    \"content\": \"$content\",
    \"session_id\": \"${NOEL_CURRENT_SESSION_UUID:-$NOEL_CURRENT_SESSION_ID}\"
  }"
}
```

**Why no project caching?**
- Projects change infrequently
- Lookup is fast (indexed by Title)
- Simpler client code
- No cache invalidation issues

---

## 5. Implementation Task Breakdown

### Phase 1: Smart Session ID Detection (1-2 hours)

**T1.1** Add session ID format detection to Capture Learning Logic
- Add `detectSessionIdFormat()` function
- Branch based on format

**T1.2** Add conditional session lookup branch
- IF needs_lookup = true → Query Sessions by Title
- Extract page_id from results
- IF needs_lookup = false → Use UUID directly

**T1.3** Update Capture Learning Logic to use resolved session UUID
- Accept session_page_id from lookup or direct
- Create Session relation

**T1.4** Test both formats
- Test with human-readable: "20251124-2051-noel-sk"
- Test with UUID: "2b53d603-acb6-8106-ae7a-cc5911103c45"
- Test error case: session not found

### Phase 2: Project Auto-Registration (2-3 hours)

**T2.1** Add project validation function
- Implement `validateProjectName()`
- Test edge cases (empty, special chars, length)

**T2.2** Add project lookup branch before Capture Learning Logic
- Query Projects by Title
- IF found → extract page_id
- IF not found → create project → extract page_id

**T2.3** Implement project creation logic
- Build project properties with defaults
- Call Notion create_page
- Return project_id

**T2.4** Update Capture Learning Logic to use project_id
- Accept project_page_id from lookup/creation
- Create Project relation

**T2.5** Implement Last Activity update
- After learning creation, update project's Last Activity field
- Use project_page_id from earlier step

**T2.6** Update start_session to handle project auto-creation
- Same lookup/create logic as capture_learning
- Associate session with project

**T2.7** Test project auto-registration
- Capture learning with new project name
- Verify project created in Notion
- Capture second learning, verify project reused
- Verify Last Activity updates

### Phase 3: Unclosed Session Handling (1-2 hours)

**T3.1** Add "Abandoned" status option to Sessions database
- Update Notion Sessions database Status property
- Add option: Abandoned (color: gray)

**T3.2** Create scheduled auto-close workflow
- New n8n workflow: "Session Auto-Close"
- Schedule: Runs every hour (cron: `0 * * * *`)

**T3.3** Implement abandoned session detection logic
- Query Active sessions with Start Time > 24h ago
- Filter: no Last Modified in last 24h

**T3.4** Implement auto-close logic
- Update Status = Abandoned
- Set End Time = now
- Log closure

**T3.5** Update end_session to be idempotent
- Check current status
- If already closed, return success
- Add `already_closed` flag to response

**T3.6** Test abandoned session handling
- Create test session with old timestamp
- Run auto-close manually
- Verify status changes to Abandoned
- Test end_session on abandoned session

### Phase 4: Helper Script Updates (30-60 min)

**T4.1** Update noel-start-session
- Export both SESSION_ID and SESSION_UUID
- Store in temp files for persistence
- Add warning if previous session still Active

**T4.2** Update noel-capture
- Use SESSION_UUID if available (optimization)
- Fall back to SESSION_ID (triggers lookup)
- Accept project name parameter

**T4.3** Update noel-end-session
- Use SESSION_ID (human-readable)
- Handle already_closed response
- Clean up temp files

**T4.4** Add noel-check-session helper
- Query current session status
- Warn if abandoned
- Show learning count

**T4.5** Update documentation
- Document new project auto-registration
- Document session ID format flexibility
- Document abandoned session behavior

### Phase 5: Testing & Validation (1 hour)

**T5.1** End-to-end test: New project workflow
- Start session with new project
- Capture 3 learnings
- End session
- Verify project created, learnings associated

**T5.2** End-to-end test: Session ID flexibility
- Start session (get both IDs)
- Capture with UUID
- Capture with human-readable ID
- Verify both work

**T5.3** End-to-end test: Abandoned session
- Create session, don't close
- Fast-forward time (manually set timestamps)
- Run auto-close
- Verify status = Abandoned

**T5.4** Error case testing
- Invalid project name
- Non-existent session ID
- Malformed session ID
- Verify helpful error messages

---

## 6. Workflow Architecture Changes

### New Workflow Structure

```
Webhook → Parse Request → Route Endpoint → [Branch by endpoint]

capture_learning branch:
  → Validate Project Name
  → Query/Create Project (Conditional)
  → Detect Session ID Format (Conditional)
  → Query Session if needed (Conditional)
  → Capture Learning Logic (uses project_id + session_page_id)
  → Create Learning in Notion
  → Update Project Last Activity
  → Format Response
  → Respond to Webhook

start_session branch:
  → Validate Project Name
  → Query/Create Project (Conditional)
  → Start Session Logic (uses project_id)
  → Create Session in Notion
  → Format Response
  → Respond to Webhook

end_session branch:
  → Query Session by Title
  → Check if already closed (Conditional)
  → Update Session (if needed)
  → Format Response
  → Respond to Webhook
```

### New Scheduled Workflow

```
Session Auto-Close Workflow:
  → Schedule Trigger (hourly)
  → Query Active Sessions > 24h old
  → For Each Session:
      → Update Status = Abandoned
      → Set End Time = now
      → Log closure
```

---

## 7. Data Model Updates

### Sessions Database - Add Status Option

**Before**:
```
Status (Select): Active, Completed
```

**After**:
```
Status (Select): Active, Completed, Abandoned
```

### No other schema changes needed

---

## 8. API Contract Changes

### capture_learning Request

**Before**:
```json
{
  "endpoint": "capture_learning",
  "project_id": "2b23d603-acb6-...",  // UUID required
  "session_id": "2b53d603-acb6-...",  // UUID required
  "title": "...",
  "content": "..."
}
```

**After (backwards compatible)**:
```json
{
  "endpoint": "capture_learning",
  "project": "Noel_SK",                           // Name or UUID
  "session_id": "20251124-2051-noel-sk",         // Human-readable or UUID
  "title": "...",
  "content": "..."
}
```

**Response - Add project info**:
```json
{
  "success": true,
  "title": "...",
  "page_id": "...",
  "project_id": "2b23d603-...",        // NEW: For client caching
  "project_name": "Noel_SK",           // NEW: Confirmation
  "project_created": false,            // NEW: Was it auto-created?
  "session_id": "20251124-2051-noel-sk",
  "session_page_id": "2b53d603-...",   // NEW: For client optimization
  "message": "Learning created successfully"
}
```

### end_session Response

**Add already_closed field**:
```json
{
  "success": true,
  "session_id": "20251124-2051-noel-sk",
  "status": "Completed",
  "already_closed": false,              // NEW
  "duration_minutes": 45,
  "learning_count": 5
}
```

### New endpoint: check_session (optional)

```json
{
  "endpoint": "check_session",
  "session_id": "20251124-2051-noel-sk"
}

Response:
{
  "success": true,
  "session_id": "20251124-2051-noel-sk",
  "status": "Active",
  "start_time": "...",
  "duration_so_far": 23,
  "learning_count": 3,
  "project": "Noel_SK"
}
```

---

## 9. Error Handling Matrix

| Error Condition | HTTP Status | Error Message | User Action |
|----------------|-------------|---------------|-------------|
| Invalid project name | 400 | "Project name contains invalid characters" | Fix project name |
| Project name too long | 400 | "Project name too long (max 100 chars)" | Shorten name |
| Invalid session_id format | 400 | "Invalid session_id format: {id}" | Check ID format |
| Session not found | 404 | "Session not found: {session_id}" | Verify session exists |
| Project creation failed | 500 | "Failed to create project: {error}" | Retry, check Notion API |
| Session lookup failed | 500 | "Failed to query session: {error}" | Retry, check Notion API |
| Notion API rate limit | 429 | "Rate limit exceeded, retry after {seconds}s" | Wait and retry |

---

## 10. Rollout Plan

### Step 1: Sessions Smart Detection (Non-breaking)
- Deploy session ID format detection
- Test with both formats
- Update helper scripts to export both IDs
- **Users can continue using UUIDs during transition**

### Step 2: Project Auto-Registration (Breaking - requires migration)
- Deploy project auto-registration
- Update API contracts (project → project name)
- Update helper scripts
- **Migration needed: Update existing capture calls to use names**

### Step 3: Abandoned Session Cleanup (New feature)
- Add "Abandoned" status to database
- Deploy scheduled workflow
- Let run for a week to catch existing abandoned sessions
- **No user action needed**

### Step 4: Documentation & Polish
- Update all docs with new workflows
- Add error handling examples
- Create troubleshooting guide

---

## 11. Success Metrics

After implementation, measure:

- **Project auto-creation rate**: How many projects are auto-created vs manually created
- **Session lookup usage**: Human-readable vs UUID usage split
- **Abandoned session rate**: Percentage of sessions that get auto-closed
- **API error rate**: Validation errors, not-found errors
- **Average learnings per session**: Engagement metric

---

## 12. Open Questions for User Decision

1. **Auto-close timing**: 24 hours reasonable, or prefer different threshold?
2. **Project defaults**: Should Priority default to P2-Medium, or something else?
3. **Notification preference**: Want any notification when sessions auto-close?
4. **Session check helper**: Useful to have `noel-check-session` command?
5. **Project edit permissions**: Should workflow allow updating project metadata (description, tech stack) via API?

---

## Summary

Option C provides the smoothest UX by:
- ✅ Auto-creating projects on first use
- ✅ Accepting both UUID and human-readable session IDs
- ✅ Cleaning up abandoned sessions automatically
- ✅ Maintaining backwards compatibility
- ✅ Keeping helper scripts simple

**Estimated Total Implementation Time**: 6-9 hours

**Risk Level**: Low (most changes are additive, can roll out incrementally)

**User Impact**: Significantly improved - reduces manual steps and cognitive load
