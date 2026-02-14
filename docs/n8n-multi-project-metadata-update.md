# n8n Workflow Update: Multi-Project Metadata Support

**Date**: 2025-12-31
**Purpose**: Add scope, discipline, applies_to, and conflicts_with metadata fields to support multi-project architecture

---

## Background

To prevent cross-project architectural conflicts, we're adding metadata fields to classify learnings as:
- **Universal** (applies to ALL projects)
- **Domain-Specific** (applies to technology/industry domain like Programming:Python or Seguros:Vida)
- **Project-Specific** (applies ONLY to one project)

**Critical**: These fields are stored in **Supabase metadata JSONB**, NOT in Notion properties (per user directive to stop Notion UI development).

---

## Changes Required in n8n Workflow

### 1. Update "Parse Request" Node (capture_learning endpoint)

**Location**: n8n workflow → "Parse Request" Code node

**Current code extracts**:
```javascript
const endpoint = $input.item.json.body.endpoint;
const project = $input.item.json.body.project;
const title = $input.item.json.body.title;
const content = $input.item.json.body.content;
const type = $input.item.json.body.type || null;
const confidence = $input.item.json.body.confidence || null;
```

**Add these lines**:
```javascript
// NEW: Multi-project metadata fields
const scope = $input.item.json.body.scope || null;  // Universal | Domain-Specific | Project-Specific
const discipline = $input.item.json.body.discipline || null;  // Array: ["Architecture", "Backend"]
const applies_to = $input.item.json.body.applies_to || null;  // String: "Programming:Python, Noel_SK"
const conflicts_with = $input.item.json.body.conflicts_with || null;  // Array: ["LEARNING-ID-1"]
```

**Return updated object**:
```javascript
return {
  endpoint,
  project,
  title,
  content,
  type,
  confidence,
  scope,  // NEW
  discipline,  // NEW
  applies_to,  // NEW
  conflicts_with  // NEW
};
```

---

### 2. Update "Insert to Supabase" Node (Store Metadata)

**Location**: n8n workflow → "Insert to Supabase" HTTP Request node (or Supabase node)

**Current metadata JSONB**:
```json
{
  "project": "{{ $json.project }}",
  "type": "{{ $json.type }}",
  "confidence": "{{ $json.confidence }}",
  "tags": {{ $json.tags }}
}
```

**Updated metadata JSONB**:
```json
{
  "project": "{{ $json.project }}",
  "type": "{{ $json.type }}",
  "confidence": "{{ $json.confidence }}",
  "tags": {{ $json.tags }},
  "scope": "{{ $json.scope }}",
  "discipline": {{ $json.discipline }},
  "applies_to": "{{ $json.applies_to }}",
  "conflicts_with": {{ $json.conflicts_with }}
}
```

**Note**: Arrays (discipline, conflicts_with) should be passed as JSON arrays, not strings.

---

### 3. Update "query_learnings" Endpoint (Filter Support)

**Location**: n8n workflow → "Parse Query Request" Code node

**Current filter extraction**:
```javascript
const filters = $input.item.json.body.filters || {};
const project_filter = filters.project || null;
const type_filter = filters.type || null;
```

**Add new filter options**:
```javascript
const scope_filter = filters.scope || null;  // e.g., "Universal"
const discipline_filter = filters.discipline || null;  // e.g., "Backend"
const applies_to_filter = filters.applies_to || null;  // e.g., "Programming:Python"
```

**Update Supabase RPC call**:
```javascript
// In the Supabase query node
WHERE
  (project_filter IS NULL OR metadata->>'project' = project_filter)
  AND (type_filter IS NULL OR metadata->>'type' = type_filter)
  AND (scope_filter IS NULL OR metadata->>'scope' = scope_filter)  // NEW
  AND (discipline_filter IS NULL OR metadata->'discipline' ? discipline_filter)  // NEW (array contains)
  AND (applies_to_filter IS NULL OR metadata->>'applies_to' LIKE '%' || applies_to_filter || '%')  // NEW
```

---

### 4. Update "update_learning" Endpoint

**Location**: n8n workflow → "Parse Update Request" Code node

**Add metadata update support**:
```javascript
const scope = $input.item.json.body.scope || null;
const discipline = $input.item.json.body.discipline || null;
const applies_to = $input.item.json.body.applies_to || null;
const conflicts_with = $input.item.json.body.conflicts_with || null;
```

**Update Supabase metadata**:
```javascript
// In Supabase update node
metadata = metadata || '{}'::jsonb;
IF scope IS NOT NULL THEN metadata = jsonb_set(metadata, '{scope}', to_jsonb(scope));
IF discipline IS NOT NULL THEN metadata = jsonb_set(metadata, '{discipline}', to_jsonb(discipline));
IF applies_to IS NOT NULL THEN metadata = jsonb_set(metadata, '{applies_to}', to_jsonb(applies_to));
IF conflicts_with IS NOT NULL THEN metadata = jsonb_set(metadata, '{conflicts_with}', to_jsonb(conflicts_with));
```

---

## Testing

After updating n8n workflow:

### Test 1: Capture with metadata
```bash
curl -s https://3a81dc8c65bf.ngrok-free.app/webhook/noel \
  -H "Content-Type: application/json" \
  -H "Authorization: 1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6" \
  -d '{
    "endpoint": "capture_learning",
    "project": "Noel_SK",
    "title": "Test Multi-Project Metadata",
    "content": "This is a test learning with scope/discipline/applies_to fields",
    "type": "Pattern",
    "confidence": "High",
    "scope": "Universal",
    "discipline": ["Architecture", "Backend"],
    "applies_to": "All software projects"
  }'
```

**Expected response**:
```json
{
  "success": true,
  "learning_id": "LEARNING-YYYYMMDD-XXX",
  "metadata": {
    "scope": "Universal",
    "discipline": ["Architecture", "Backend"],
    "applies_to": "All software projects"
  }
}
```

### Test 2: Query with scope filter
```bash
curl -s https://3a81dc8c65bf.ngrok-free.app/webhook/noel \
  -H "Content-Type: application/json" \
  -H "Authorization: 1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6" \
  -d '{
    "endpoint": "query_learnings",
    "query": "architectural patterns",
    "filters": {"scope": "Universal"}
  }'
```

**Expected**: Only returns learnings with scope=Universal

### Test 3: Update metadata
```bash
curl -s https://3a81dc8c65bf.ngrok-free.app/webhook/noel \
  -H "Content-Type: application/json" \
  -H "Authorization: 1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6" \
  -d '{
    "endpoint": "update_learning",
    "learning_id": "LEARNING-20251231-001",
    "scope": "Project-Specific",
    "discipline": ["DevOps"],
    "applies_to": "Noel_SK session management"
  }'
```

---

## Supabase Schema Verification

**Check existing metadata JSONB structure**:
```sql
SELECT
  learning_id,
  metadata->>'project' as project,
  metadata->>'scope' as scope,
  metadata->'discipline' as discipline,
  metadata->>'applies_to' as applies_to
FROM learnings_vectors
LIMIT 5;
```

**No schema changes needed** - metadata is already JSONB and can accept new fields without migration.

---

## Rollback Plan

If issues occur:
1. Remove new metadata fields from Parse Request node
2. n8n will ignore unknown fields in webhook payload
3. Existing learnings without scope/discipline continue to work
4. Graceful degradation: queries without filters work as before

---

## Next Steps

1. ✅ Updated noel-helpers.sh (noel-capture and noel-update functions)
2. ⏳ Update n8n workflow nodes (manual in n8n UI - follow this guide)
3. ⏳ Test metadata storage in Supabase
4. ⏳ Test query filtering by scope/discipline
5. ⏳ Capture asciinema architectural decision with full metadata

---

**Estimated time**: 30 minutes to update n8n workflow nodes
