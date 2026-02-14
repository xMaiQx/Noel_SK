# Improving RAG Techniques for Noel

## Current Issues

1. **Retrieval is broken** - n8n workflow returns empty results
2. **Can't validate the system** - Can't test if embeddings/search work
3. **Circular debugging** - Using a broken tool to fix itself
4. **No visibility** - Can't see what's actually being stored/retrieved

## RAG Improvement Strategy

### Phase 1: Fix the Foundation (Do This First!)

#### 1.1 Test Each Component Independently

```bash
# Test 1: Can we store embeddings?
SELECT COUNT(*) FROM learnings_vectors WHERE embedding IS NOT NULL;

# Test 2: Can we search with a known embedding?
SELECT * FROM match_learnings(
  (SELECT embedding FROM learnings_vectors LIMIT 1),
  5, NULL, 0.1
);

# Test 3: What's the similarity distribution?
SELECT
  learning_id,
  1 - (embedding <=> (SELECT embedding FROM learnings_vectors LIMIT 1)) as similarity
FROM learnings_vectors
ORDER BY similarity DESC
LIMIT 10;
```

#### 1.2 Bypass n8n During Testing

Use direct API calls to Supabase:
- Store: Direct INSERT into `learnings_vectors`
- Retrieve: Direct RPC call to `match_learnings`
- This isolates the problem to either: (a) n8n, or (b) Supabase

#### 1.3 Add Logging and Visibility

```sql
-- Create a debug table
CREATE TABLE IF NOT EXISTS rag_debug_log (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at timestamptz DEFAULT now(),
  operation text,
  query_text text,
  results_count int,
  avg_similarity float,
  metadata jsonb
);

-- Log every search
CREATE OR REPLACE FUNCTION match_learnings_debug(...)
RETURNS TABLE (...) AS $$
DECLARE
  results_count int;
  avg_sim float;
BEGIN
  -- Get results
  RETURN QUERY ...;

  -- Log the search
  GET DIAGNOSTICS results_count = ROW_COUNT;
  INSERT INTO rag_debug_log (operation, results_count, metadata)
  VALUES ('search', results_count, jsonb_build_object('threshold', similarity_threshold));
END;
$$;
```

### Phase 2: Improve Retrieval Quality

#### 2.1 Hybrid Search (Vector + Keyword)

```sql
CREATE OR REPLACE FUNCTION match_learnings_hybrid(
  query_embedding vector(1536),
  query_text text,
  match_count int DEFAULT 5
)
RETURNS TABLE (...) AS $$
BEGIN
  RETURN QUERY
  SELECT
    learning_id,
    content,
    metadata,
    -- Combine vector similarity with text matching
    (0.7 * (1 - (embedding <=> query_embedding))) +
    (0.3 * CASE
      WHEN content ILIKE '%' || query_text || '%' THEN 0.5
      WHEN metadata->>'title' ILIKE '%' || query_text || '%' THEN 0.3
      ELSE 0
    END) as combined_score
  FROM learnings_vectors
  ORDER BY combined_score DESC
  LIMIT match_count;
END;
$$;
```

#### 2.2 Adaptive Threshold

Instead of fixed 0.1 threshold, adapt based on results:

```sql
-- If nothing matches at 0.7, try 0.5, then 0.3, then 0.1
WITH ranked_results AS (
  SELECT *,
    1 - (embedding <=> query_embedding) as similarity,
    CASE
      WHEN similarity >= 0.7 THEN 1
      WHEN similarity >= 0.5 THEN 2
      WHEN similarity >= 0.3 THEN 3
      ELSE 4
    END as tier
  FROM learnings_vectors
)
SELECT * FROM ranked_results
WHERE tier = (SELECT MIN(tier) FROM ranked_results WHERE similarity > 0.1)
LIMIT match_count;
```

#### 2.3 Better Chunking Strategy

Currently storing full learnings. Consider:

```javascript
// Split large learnings into chunks
function chunkLearning(content, maxChunkSize = 500) {
  const chunks = [];
  const paragraphs = content.split('\n\n');

  let currentChunk = '';
  for (const para of paragraphs) {
    if (currentChunk.length + para.length > maxChunkSize) {
      if (currentChunk) chunks.push(currentChunk);
      currentChunk = para;
    } else {
      currentChunk += '\n\n' + para;
    }
  }
  if (currentChunk) chunks.push(currentChunk);

  return chunks;
}

// Store each chunk with reference to parent learning
```

### Phase 3: Improve Embedding Quality

#### 3.1 Add Context to Embeddings

Instead of embedding just the content, include metadata:

```javascript
// Better embedding input
const embeddingInput = `
Title: ${learning.title}
Project: ${learning.project}
Type: ${learning.type}
Tags: ${learning.tags.join(', ')}

Content: ${learning.content}
`.trim();
```

#### 3.2 Use Multiple Embedding Models

```sql
-- Store multiple embedding types
ALTER TABLE learnings_vectors
ADD COLUMN embedding_small vector(1536),   -- text-embedding-3-small
ADD COLUMN embedding_large vector(3072);   -- text-embedding-3-large

-- Search uses the appropriate one
```

#### 3.3 Store Query Embeddings

```sql
-- Cache common queries
CREATE TABLE query_cache (
  query_text text PRIMARY KEY,
  query_embedding vector(1536),
  last_used timestamptz DEFAULT now()
);
```

### Phase 4: Add Reranking

After getting initial results, rerank them:

```javascript
// Use a cross-encoder for reranking
async function rerankResults(query, results) {
  const scored = await Promise.all(
    results.map(async result => {
      const score = await crossEncoderScore(query, result.content);
      return { ...result, rerank_score: score };
    })
  );

  return scored.sort((a, b) => b.rerank_score - a.rerank_score);
}
```

### Phase 5: User Feedback Loop

```sql
-- Track which results were useful
CREATE TABLE search_feedback (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at timestamptz DEFAULT now(),
  query_text text,
  learning_id text,
  was_helpful boolean,
  user_notes text
);

-- Use feedback to improve search
CREATE OR REPLACE FUNCTION match_learnings_with_feedback(...)
RETURNS TABLE (...) AS $$
BEGIN
  RETURN QUERY
  SELECT
    l.*,
    1 - (l.embedding <=> query_embedding) as base_similarity,
    -- Boost results that were previously helpful
    COALESCE(
      (SELECT AVG(CASE WHEN was_helpful THEN 0.1 ELSE -0.1 END)
       FROM search_feedback f
       WHERE f.learning_id = l.learning_id
       AND f.query_text ILIKE '%' || query_text || '%'),
      0
    ) as feedback_boost
  FROM learnings_vectors l
  ORDER BY (base_similarity + feedback_boost) DESC
  LIMIT match_count;
END;
$$;
```

## Immediate Action Plan

### Today (Fix the Basics)
1. ✅ Run `scripts/test_rag_direct.sh` to test if Supabase works
2. ✅ If Supabase works, the problem is just n8n HTTP Request node
3. ✅ Document the n8n issue separately and move on
4. ✅ Use direct Supabase API calls for now

### This Week (Make it Usable)
1. Add hybrid search (vector + keyword)
2. Add adaptive thresholds
3. Add debug logging
4. Test with real queries

### Next Week (Make it Good)
1. Implement chunking for large learnings
2. Add reranking
3. Add feedback loop
4. Optimize embedding strategy

## Key Insights

1. **Don't let perfect be the enemy of good** - Use Supabase directly, bypass n8n for now
2. **Test incrementally** - Each component should work independently
3. **Add visibility** - Log everything so you can see what's happening
4. **Iterate based on data** - Track what works, what doesn't
5. **Start simple** - Vector search → Hybrid → Reranking → Feedback

## Resources

- [OpenAI Embeddings Best Practices](https://platform.openai.com/docs/guides/embeddings)
- [pgvector Performance Tuning](https://github.com/pgvector/pgvector#performance)
- [RAG Evaluation Framework](https://docs.ragas.io/)
- [Hybrid Search Strategies](https://www.pinecone.io/learn/hybrid-search-intro/)
