# n8n Workflow Update Guide: Hybrid Multi-Field Search

**Status: IMPLEMENTED** - The workflow `Noel_Knowledge_Repository` (vZSgaLE6I6VK4K6N) has been updated.

This document describes the changes made to support 4-field structured embeddings.

---

## Workflow Structure Overview

```
                              ┌─────────────────────────────────────────────────────────────────┐
                              │                     CAPTURE LEARNING PATH                        │
                              │                                                                  │
Webhook ─► Parse Request ─► Route Endpoint ─► Capture Learning Logic                            │
                              │                        │                                        │
                              │           Prepare Learning Create Call                          │
                              │                        │                                        │
                              │           Call Notion API Wrapper (Query)1                      │
                              │                        │                                        │
                              │           Prepare Embedding Data ◄─── UPDATED                   │
                              │                        │                                        │
                              │           Generate Embedding (OpenAI) ◄─── UPDATED              │
                              │                        │                                        │
                              │           Prepare Supabase Insert ◄─── UPDATED                  │
                              │                        │                                        │
                              │           Store in Supabase ◄─── UPDATED                        │
                              │                        │                                        │
                              │           Format Capture Response                               │
                              │                        │                                        │
                              └────────────────────────┼────────────────────────────────────────┘
                                                       │
                                                       ▼
                                              Respond to Webhook
                                                       ▲
                              ┌────────────────────────┼────────────────────────────────────────┐
                              │                        │                                        │
                              │                     QUERY LEARNINGS PATH                        │
                              │                                                                  │
                              │           Query Learnings Logic ◄─── UPDATED                    │
                              │                        │                                        │
                              │           Generate Query Embedding                              │
                              │                        │                                        │
                              │           Prepare Vector Search ◄─── UPDATED                    │
                              │                        │                                        │
                              │           Search Supabase Vectors ◄─── UPDATED                  │
                              │                        │                                        │
                              │           Format Query Results ◄─── UPDATED                     │
                              │                                                                  │
                              └─────────────────────────────────────────────────────────────────┘
```

---

## Capture Path Changes

### Node: Prepare Embedding Data

**Purpose**: Parse learning content into 4 sections for multi-field embeddings.

**Key changes**:
- Parses content to extract WHY section (problem) and WHAT+HOW sections (solution)
- Composes context text from metadata (project, type, tags, dev_stream, applies_to)
- Outputs `texts_to_embed` array with 4 elements: [title, problem, solution, context]

**Code logic**:
```javascript
// Parse WHY section (problem context)
const whyMatch = content.match(/WHY:([\s\S]*?)(?=\nWHAT:|\n\nWHAT:|$)/i);
const problem = whyMatch ? whyMatch[1].trim() : content.substring(0, 500).trim();

// Parse WHAT+HOW sections (solution)
const whatMatch = content.match(/WHAT:([\s\S]*$)/i);
const solution = whatMatch ? whatMatch[1].trim() : content.trim();

// Compose context from metadata
const contextText = `Project: ${project}. Type: ${type}. Tags: ${tags.join(', ')}...`;

// Output array for single OpenAI API call
return { texts_to_embed: [title, problem, solution, contextText] };
```

---

### Node: Generate Embedding (OpenAI)

**Purpose**: Generate 4 embeddings in a single API call.

**Key change**: JSON body now sends array input instead of single string.

```json
{
  "model": "text-embedding-3-small",
  "input": {{ $json.texts_to_embed }}
}
```

OpenAI returns an array of 4 embeddings (indexed 0-3).

---

### Node: Prepare Supabase Insert

**Purpose**: Extract and format 4 embeddings from OpenAI response.

**Key changes**:
- Sorts embeddings by index to ensure correct order
- Converts each embedding to pgvector string format
- Outputs 4 named embedding fields

**Code logic**:
```javascript
const embeddings = embeddingResponse.data;
embeddings.sort((a, b) => a.index - b.index);

return {
  title_embedding: `[${embeddings[0].embedding.join(',')}]`,
  problem_embedding: `[${embeddings[1].embedding.join(',')}]`,
  solution_embedding: `[${embeddings[2].embedding.join(',')}]`,
  context_embedding: `[${embeddings[3].embedding.join(',')}]`
};
```

---

### Node: Store in Supabase

**Purpose**: Upsert learning with all embedding columns.

**Key change**: JSON body includes all 5 embedding columns (4 new + legacy for backwards compatibility).

```json
{
  "learning_id": "...",
  "content": "...",
  "metadata": {...},
  "embedding": "{{ $json.title_embedding }}",
  "title_embedding": "{{ $json.title_embedding }}",
  "problem_embedding": "{{ $json.problem_embedding }}",
  "solution_embedding": "{{ $json.solution_embedding }}",
  "context_embedding": "{{ $json.context_embedding }}"
}
```

**Note**: The legacy `embedding` column uses title_embedding as fallback until migration 003 is applied.

---

## Query Path Changes

### Node: Query Learnings Logic

**Purpose**: Prepare query parameters including filters.

**Key change**: Extracts project and type filters from payload.

```javascript
return {
  query: payload.query,
  limit: payload.limit || 5,
  project: payload.project || payload.filters?.project || null,
  type: payload.type || payload.filters?.type || null,
  openai_request: { model: 'text-embedding-3-small', input: payload.query }
};
```

---

### Node: Prepare Vector Search

**Purpose**: Prepare RPC call parameters including query_text for text boost.

**Key change**: Now includes `query_text` parameter for text match boosting.

```javascript
return {
  query_embedding: JSON.stringify(queryEmbedding),
  query_text: queryData.query,  // For text match boost
  match_count: queryData.limit,
  project_filter: queryData.project,
  type_filter: queryData.type
};
```

---

### Node: Search Supabase Vectors

**Purpose**: Call the hybrid RPC function.

**Key changes**:
- URL changed from `match_learnings` to `match_learnings_hybrid`
- Body includes `query_text` parameter

```
URL: https://sladetzgpogodrqwfamy.supabase.co/rest/v1/rpc/match_learnings_hybrid

Body:
{
  "query_embedding": "{{ $json.query_embedding }}",
  "query_text": "{{ $json.query_text }}",
  "match_count": {{ $json.match_count }},
  "project_filter": {{ $json.project_filter }},
  "type_filter": {{ $json.type_filter }}
}
```

---

### Node: Format Query Results

**Purpose**: Format hybrid results with per-field similarity scores.

**Key changes**:
- Includes per-field similarity breakdown
- Adds `match_reason` explaining why the result matched
- Calculates `combined_score` from RPC response

**Output format**:
```json
{
  "success": true,
  "count": 3,
  "results": [
    {
      "rank": 1,
      "learning_id": "FIX REQUEST: Missing tipo field...",
      "title": "FIX REQUEST: Missing tipo field...",
      "project": "UDEE",
      "type": "Error",
      "content_excerpt": "WHY: UDEE extraction returns...",
      "similarity": {
        "title": 0.463,
        "problem": 0.226,
        "solution": 0.229,
        "context": 0.368,
        "text_boost": 0.30
      },
      "combined_score": 0.621,
      "match_reason": "Exact title match",
      "content": "...",
      "metadata": {...}
    }
  ]
}
```

---

## Testing

### Test Query (via webhook):
```bash
curl -s https://your-ngrok-url/webhook/noel \
  -H "Content-Type: application/json" \
  -H "Authorization: YOUR_TOKEN" \
  -d '{"endpoint":"query_learnings","query":"FIX REQUEST","limit":3}' | jq '.'
```

### Test Capture (via webhook):
```bash
curl -s https://your-ngrok-url/webhook/noel \
  -H "Content-Type: application/json" \
  -H "Authorization: YOUR_TOKEN" \
  -d '{
    "endpoint": "capture_learning",
    "project": "Test",
    "title": "Test Hybrid Capture",
    "content": "WHY: Testing.\n\nWHAT: It works.\n\nHOW: Send request.",
    "type": "Solution"
  }' | jq '.'
```

### Verify embeddings stored:
```sql
SELECT learning_id,
       CASE WHEN title_embedding IS NOT NULL THEN 'yes' ELSE 'no' END as has_title,
       CASE WHEN problem_embedding IS NOT NULL THEN 'yes' ELSE 'no' END as has_problem,
       CASE WHEN solution_embedding IS NOT NULL THEN 'yes' ELSE 'no' END as has_solution,
       CASE WHEN context_embedding IS NOT NULL THEN 'yes' ELSE 'no' END as has_context
FROM learnings_vectors
WHERE learning_id = 'Test Hybrid Capture';
```

---

## Cleanup (After Validation)

Once confirmed working, apply `scripts/migrations/003_drop_legacy_embedding.sql` to:
1. Drop old `match_learnings` function
2. Drop old `embedding` column and its index

This will also allow removing the legacy `embedding` field from the Store in Supabase node.
