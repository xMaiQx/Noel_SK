# Noel Capture Scripts - Usage Guide

## Available Scripts

### 1. `capture_with_project_lookup.sh` - Quick Capture

**Use when:** You need to quickly capture a learning with minimal fields.

**Fields supported:**
- title (required)
- content (required)
- type (required)
- confidence (required)
- project (required)
- project_id (auto-looked up)

**Example:**
```bash
bash capture_with_project_lookup.sh \
  "Noel" \
  "Quick Learning Title" \
  "Description of the learning" \
  "Pattern" \
  "High"
```

**Pros:**
- Fast and simple
- Fewer arguments to remember
- Good for quick captures during flow

**Cons:**
- Misses context, tags, dev_stream, related_files
- Less rich metadata for retrieval

---

### 2. `capture_learning_full.sh` - Complete Capture (RECOMMENDED)

**Use when:** You want to capture ALL available metadata for maximum context.

**Fields supported:**
- All fields from quick capture PLUS:
- context - How the learning was discovered
- dev_stream - Development domains (comma-separated)
- tags - Keywords for filtering (comma-separated)
- related_files - File paths and line numbers
- session_id - Link to session (Notion page ID)

**Example:**
```bash
bash capture_learning_full.sh \
  "Noel" \
  "Comprehensive Learning Title" \
  "Full description with all context" \
  "Solution" \
  "High" \
  "Discovered while debugging vector search" \
  "Database,API,n8n" \
  "pgvector,supabase,debugging" \
  "scripts/search.sql:42, workflows/main.json" \
  "SESSION-20251220-page-id"
```

**Pros:**
- Captures ALL available metadata
- Better context for future retrieval
- Supports session linking
- Rich filtering via dev_stream and tags

**Cons:**
- More arguments (but optional after the first 5)
- Slightly more complex

---

## Field Comparison

| Field | Quick Script | Full Script | Notion Field Type | Notes |
|-------|-------------|-------------|-------------------|-------|
| Title | ✓ | ✓ | Title | Required |
| Content | ✓ | ✓ | Rich Text | Required |
| Type | ✓ | ✓ | Select | Required (Pattern, Solution, Error, etc.) |
| Confidence | ✓ | ✓ | Select | Required (High, Medium, Low) |
| Project | ✓ | ✓ | Relation | Required |
| Project ID | ✓ | ✓ | - | Auto-looked up |
| Context | ✗ | ✓ | Rich Text | How discovered |
| Dev Stream | ✗ | ✓ | Multi-select | Domains (n8n, API, etc.) |
| Tags | ✗ | ✓ | Multi-select | Keywords |
| Related Files | ✗ | ✓ | Rich Text | File paths |
| Session | ✗ | ✓ | Relation | Session link |
| Timestamp | auto | auto | Date | Auto-set by n8n |
| Last Modified | auto | auto | Date | Auto-set by n8n |
| AI Suggested | auto | auto | Checkbox | Auto-set to false |
| AI Accepted | auto | auto | Checkbox | Auto-set to false |
| Status | auto | auto | Select | Auto-set to 'Active' |

---

## When to Use Each Script

### Use Quick Capture When:
- ✓ In the middle of coding flow
- ✓ Want to capture idea quickly
- ✓ Context is obvious from content
- ✓ Don't care about tags or domains

### Use Full Capture When:
- ✓ Significant breakthrough or solution
- ✓ Want full context for future reference
- ✓ Need to link to specific files
- ✓ Part of a tracked session
- ✓ Want to filter by domain or tags later

---

## Common Patterns

### Capture During Debugging
```bash
# After fixing a bug, capture with full context
bash capture_learning_full.sh \
  "MyProject" \
  "Fixed Authentication Token Expiry Bug" \
  "Auth tokens were expiring after 1 hour instead of 24 hours due to..." \
  "Solution" \
  "High" \
  "Discovered during production incident investigation" \
  "Backend,API,Security" \
  "authentication,tokens,expiry,bug-fix" \
  "src/auth/token-manager.ts:156-178"
```

### Capture Pattern Discovery
```bash
# When discovering a useful pattern
bash capture_learning_full.sh \
  "MyProject" \
  "n8n Error Handling Pattern" \
  "Always wrap external API calls in try-catch with fallback response..." \
  "Pattern" \
  "High" \
  "Emerged from analyzing multiple workflow failures" \
  "n8n,API,Error Handling" \
  "patterns,best-practices,error-handling" \
  "workflows/api-caller-template.json"
```

### Quick Insight Capture
```bash
# Quick capture during flow
bash capture_with_project_lookup.sh \
  "MyProject" \
  "PostgreSQL ILIKE is Case-Insensitive" \
  "Use ILIKE instead of LIKE for case-insensitive matching in PostgreSQL" \
  "Insight" \
  "High"
```

---

## Script Locations

- Quick: `.claude/skills/noel-domain-memory/scripts/capture_with_project_lookup.sh`
- Full: `.claude/skills/noel-domain-memory/scripts/capture_learning_full.sh`

Both scripts:
- Auto-lookup project page ID
- Validate authentication
- Return success/failure status
- Support the same project names

---

## Tips

1. **Start with Full Script**: Even if you leave optional fields empty, using the full script trains you to think about context.

2. **Use Tab Completion**: Both scripts are in your PATH if you've sourced noel-helpers.sh.

3. **Comma-Separated Lists**: For dev_stream and tags, use commas without spaces: `"API,Database,Security"` not `"API, Database, Security"`.

4. **File References**: Include line numbers when possible: `"src/file.ts:42-65"` helps future debugging.

5. **Context is Gold**: The "context" field explaining HOW you discovered the learning is often more valuable than the learning itself.

---

## Migration Guide

If you have existing scripts using the old format, update them to use the full script:

**Before:**
```bash
noel-capture "Project" "Title" "Content" "Type" "Confidence"
```

**After:**
```bash
bash capture_learning_full.sh \
  "Project" \
  "Title" \
  "Content" \
  "Type" \
  "Confidence" \
  "Context about discovery" \
  "Domain1,Domain2" \
  "tag1,tag2,tag3" \
  "file/path.ts:42"
```

---

## Future Enhancements

Planned improvements:
- [ ] Interactive mode asking for optional fields
- [ ] Session ID auto-detection from environment
- [ ] Template-based captures for common patterns
- [ ] Bulk capture from markdown files

Last updated: 2025-12-22
