# Common Patterns from Noel Development

Extracted learnings from SESSION_LEARNINGS.md and debugging sessions.
These patterns are loaded during skill initialization for immediate context.

---

## Notion API Patterns

### NOEL-001: Two ID Types - Critical Distinction

Notion databases have **TWO different IDs**:
1. **Database ID**: For schema operations (`retrieve_database`)
2. **Data Source ID**: For querying records (`query_data_source`)

**NOT interchangeable!** Using wrong ID returns empty results or errors.

**How to get both:**
- **Database ID**: From Notion URL (`https://www.notion.so/{DATABASE_ID}?v=...`)
- **Data Source ID**: From `retrieve_database` response at `data_sources[0].id`

**Example:**
```bash
# ✓ CORRECT - Query with Data Source ID
curl -X POST $API_URL \
  -d '{"query":{"endpoint":"query_data_source","id":"DATA_SOURCE_ID"}}'

# ✗ WRONG - Using Database ID returns empty
curl -X POST $API_URL \
  -d '{"query":{"endpoint":"query_data_source","id":"DATABASE_ID"}}'
```

### NOEL-004: Property Name Trailing Spaces

Property names with trailing spaces cause silent failures.

**Example:** `"AI Suggested "` (with space) vs `"AI Suggested"` (correct)

**Detection:** Visual inspection misses it - only automated validation catches it

**Prevention:** Use automated verification, trim property names in Notion

---

## n8n Workflow Patterns

### NOEL-012: Webhook Routing Pattern

**Pattern:** Single webhook path, route via body field

```javascript
// Single webhook: /webhook/noel
// Route based on POST body:
{
  "endpoint": "capture_learning",  // or "query_learnings", etc.
  "data": { ... }
}
```

All 8 Noel endpoints use **same webhook URL**, different `endpoint` values.

### NOEL-018: Node Execution Stops

n8n nodes stop execution when previous node returns empty array.

**Solution:** Enable "Always Output Data" in node settings for nodes with optional results.

**Alternative:** Use default value nodes to prevent execution stops.

### NOEL-025: Code Node Limitations

n8n Code nodes don't support browser APIs like `fetch()`.

**Error:** `ReferenceError: fetch is not defined`

**Solution:**
- Use HTTP Request nodes for API calls
- Use Code nodes only for data transformation (JavaScript logic)

---

## Vector Search Patterns

### NOEL-034: PostgreSQL Vector Embedding Format

pgvector requires **plain array strings**, not JSON-stringified arrays.

**Correct:**
```sql
INSERT INTO learnings_embeddings (embedding)
VALUES ('[0.1, 0.2, 0.3, ...]');  -- Plain array string
```

**Wrong:**
```sql
INSERT INTO learnings_embeddings (embedding)
VALUES ('"[0.1, 0.2, 0.3]"');  -- JSON stringified (breaks <=> operator)
```

**Symptom:** Supabase RPC returns `null` similarity scores if format is wrong.

### NOEL-041: Vector Search Empty Results Debugging Checklist

When vector search returns 0 results, check in this order:

1. **Are embeddings stored?**
   ```sql
   SELECT COUNT(*) FROM learnings_embeddings;
   ```

2. **Is pgvector extension enabled?**
   ```sql
   SELECT * FROM pg_extension WHERE extname = 'vector';
   ```

3. **Is column type correct?**
   ```sql
   SELECT column_name, data_type
   FROM information_schema.columns
   WHERE table_name = 'learnings_embeddings' AND column_name = 'embedding';
   -- Should be: user-defined (vector(1536))
   ```

4. **Does `<=>` operator work?**
   ```sql
   SELECT learning_id, embedding <=> '[0.1, 0.2, ...]'::vector AS distance
   FROM learnings_embeddings
   LIMIT 5;
   -- Should return numeric distances, not NULL
   ```

---

## Bash Integration Patterns

### NOEL-002: Piping curl to Python

curl progress bar pollutes JSON when piping to Python.

**Solutions:**
```bash
# Solution 1: Suppress stderr
curl ... 2>/dev/null | python3 -c "..."

# Solution 2: Use file intermediary
curl ... > /tmp/response.json 2>&1
python3 < /tmp/response.json

# Solution 3: Quote heredoc delimiter
curl ... | python3 << 'EOF'  # Note quotes around EOF
import json
# No variable expansion issues
EOF
```

### NOEL-003: Path Resolution in Sourced Scripts

`${BASH_SOURCE[0]}` is empty when script is sourced (not executed).

**Robust pattern:**
```bash
if [ -n "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
else
  SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
fi

# Try multiple locations for .env
if [ -f "$SCRIPT_DIR/../.env" ]; then
  PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
elif [ -f "$PWD/.env" ]; then
  PROJECT_ROOT="$PWD"
fi
```

### NOEL-009: ngrok URL Automation

ngrok URLs change on every restart. Automate extraction:

```bash
# ngrok exposes local API at localhost:4040
curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url'

# Returns: https://abc123.ngrok-free.app
```

**Pattern:** Update `.env` file automatically after ngrok restart.

---

## Automation & Quality Patterns

### NOEL-006: Automated Verification Over Manual Checklists

**Failure modes of manual checklists:**
- Miss trailing spaces in property names
- Overlook plural/singular errors
- Skip properties in long lists
- Can't catch type mismatches reliably

**Why automation wins:**
- Catches ALL discrepancies instantly
- 100% accuracy, no human oversight
- Re-runnable after every change
- ROI: 15-30 min manual → 5 sec automated

**Pattern:**
```python
expected = {'Field Name': 'expected_type'}
actual = query_database(db_id)

for field, expected_type in expected.items():
    if field not in actual:
        print(f"✗ {field}: MISSING")
    elif actual[field]['type'] != expected_type:
        print(f"✗ {field}: type mismatch")
    else:
        print(f"✓ {field}: {expected_type}")
```

### NOEL-010: Constitution as Non-Negotiable Validation

Formal project constitution (established BEFORE implementation) prevents:
- Scope creep
- Architectural inconsistencies
- Manual oversight during implementation

**Principles validated:**
- Workflow-first architecture (everything via n8n)
- Cloud-native storage (Notion/Supabase, no local DB)
- AI-enhanced metadata (automated enrichment)
- Context preservation (session tracking, recordings)

**Pattern:** Write constitution → Run `/speckit.analyze` → Flag violations as CRITICAL

---

## Debugging Anti-Patterns (What Created 17 Files)

### Circular Debugging Loop

**Symptoms:**
- Multiple debug files with incremental names (`debug_1.py`, `debug_2.py`)
- Same issue approached from different angles
- No time boundaries set
- No intermediate validation

**Prevention:**
- Set 30-minute max per debugging attempt
- Query Noel for similar past debugging before starting
- Capture findings as learnings, not files
- Use `.noel/debug/` (gitignored) if files absolutely needed

### Missing Intermediate Validation

**Problem:** Changed multiple things at once, couldn't isolate root cause

**Pattern:**
```
❌ Change A + B + C → Test → Failed (which caused it?)
✅ Change A → Test → Failed → Revert → Change B → Test → Success
```

**Atomic debugging:**
1. Change ONE thing
2. Test immediately
3. Capture result (success or failure)
4. Move to next change

### Using Broken Tools to Debug Themselves

**Problem:** Used n8n vector search (which was broken) to debug vector search

**Pattern:** When tool X is broken, don't use tool X to debug it.

**Solution:** Test at lower levels:
- n8n broken? → Test Supabase directly (bypass n8n)
- Supabase RPC broken? → Test SQL directly (bypass RPC)
- SQL broken? → Test pgvector extension (bypass custom functions)

---

## Data Model Patterns

### Singular vs Plural Relation Naming

**Rule:** Reflect cardinality in property name

- **Singular**: Many-to-one (many learnings → **one** session)
- **Plural**: One-to-many or many-to-many (one session → **many** learnings)

**Example:**
```
Learnings Database:
  - Session (singular) → one learning has one session
  - Project (singular) → one learning has one project

Sessions Database:
  - Learnings (plural) → one session has many learnings (reverse relation)
  - Projects (plural) → one session links to many projects
```

### Reverse Relations Auto-Generate

When creating a relation in Notion, a reverse relation is automatically created.

**Example:**
```
Create: Learnings.Project → Projects
Auto-generated: Projects.Learnings (reverse relation)
```

These appear as "extra" fields but are **expected and correct**. Don't flag as errors in validation.

---

## Usage During Development

### When to Apply These Patterns

**Before starting implementation:**
- Query these patterns for relevant context
- Check if similar problem was already solved

**When hitting a blocker:**
- Search patterns by keyword (vector, n8n, notion, etc.)
- Apply existing solution if found
- Increment `learnings_applied` KPI

**When discovering new pattern:**
- Capture immediately to Noel (don't wait until end of session)
- Link to current session for context
- Add to this file in next session (living documentation)

**When creating debug file:**
- Ask: "Is this a learning or a temporary file?"
- If learning: Capture to Noel, don't create file
- If temporary: Use `.noel/debug/` (gitignored)
- If findings from debug file: Capture those, then delete file

---

## Pattern Evolution

This file is **living documentation** - patterns discovered during Noel development should be added here over time.

**Last updated:** 2025-12-18 (Skill v1.0.0 initialization)

**Pattern count:** 14 core patterns extracted from SESSION_LEARNINGS.md
