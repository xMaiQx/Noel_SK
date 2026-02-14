/**
 * Prepare Supabase Upsert for Structured Vectors
 *
 * n8n Code node: Place AFTER Parse OpenAI Embeddings, BEFORE Supabase HTTP Request.
 * Formats the data for upserting into learnings_vectors with 4 embedding columns.
 */

const data = $input.item.json;

// Build metadata object (same as before)
const metadata = {
  title: data.title,
  project: data.project,
  type: data.type || 'Insight',
  tags: data.tags || [],
  dev_stream: data.dev_stream || [],
  confidence: data.confidence || 'Medium',
  created_at: data.created_at || new Date().toISOString()
};

// Add optional metadata fields if present
if (data.scope) metadata.scope = data.scope;
if (data.discipline) metadata.discipline = data.discipline;
if (data.applies_to) metadata.applies_to = data.applies_to;

// Prepare upsert payload
// Note: learning_id is the unique key for conflict resolution
const upsertPayload = {
  learning_id: data.learning_id,
  content: data.content,
  metadata: metadata,

  // 4 structured embedding columns (as JSON arrays for pgvector)
  title_embedding: JSON.stringify(data.embeddings.title_embedding),
  problem_embedding: JSON.stringify(data.embeddings.problem_embedding),
  solution_embedding: JSON.stringify(data.embeddings.solution_embedding),
  context_embedding: JSON.stringify(data.embeddings.context_embedding)
};

return [{
  json: {
    // For HTTP Request node body
    upsert_payload: upsertPayload,

    // Pass through for response handling
    learning_id: data.learning_id,
    title: data.title,
    project: data.project
  }
}];

/**
 * HTTP Request Node Configuration (Supabase upsert):
 *
 * Method: POST
 * URL: {{ $env.SUPABASE_URL }}/rest/v1/learnings_vectors
 *
 * Headers:
 *   apikey: {{ $env.SUPABASE_ANON_KEY }}
 *   Authorization: Bearer {{ $env.SUPABASE_ANON_KEY }}
 *   Content-Type: application/json
 *   Prefer: resolution=merge-duplicates
 *
 * Body (JSON): {{ $json.upsert_payload }}
 *
 * Note: The "Prefer: resolution=merge-duplicates" header enables upsert
 * behavior when there's a UNIQUE constraint on learning_id.
 */
