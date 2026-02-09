/**
 * Prepare Hybrid Vector Search
 *
 * n8n Code node: Place AFTER OpenAI embedding generation, BEFORE Supabase RPC call.
 * Prepares parameters for match_learnings_hybrid RPC function.
 *
 * Input: Query data with embedding and optional filters
 * Output: RPC payload ready for Supabase HTTP Request
 */

// Get query data from previous nodes
const queryData = $('Webhook').item.json;  // Original request
const embeddingResponse = $input.item.json;  // OpenAI response

// Extract the query embedding
const embedding = embeddingResponse.data?.[0]?.embedding;
if (!embedding) {
  throw new Error('No embedding returned from OpenAI');
}

// Build RPC parameters
const rpcParams = {
  // Required: query embedding as JSON string (pgvector expects this format)
  query_embedding: JSON.stringify(embedding),

  // Required: original query text for text match boosting
  query_text: queryData.query,

  // Optional: limit (default 5)
  match_count: queryData.limit || 5
};

// Optional filters
if (queryData.filters?.project || queryData.project) {
  rpcParams.project_filter = queryData.filters?.project || queryData.project;
}

if (queryData.filters?.type || queryData.type) {
  rpcParams.type_filter = queryData.filters?.type || queryData.type;
}

return [{
  json: {
    rpc_params: rpcParams,

    // Pass through for response context
    original_query: queryData.query,
    requested_limit: queryData.limit || 5,

    // Pass through for context-aware re-ranking (Phase B: Proactive Memory)
    context: queryData.context || null
  }
}];

/**
 * HTTP Request Node Configuration (Supabase RPC):
 *
 * Method: POST
 * URL: {{ $env.SUPABASE_URL }}/rest/v1/rpc/match_learnings_hybrid
 *
 * Headers:
 *   apikey: {{ $env.SUPABASE_ANON_KEY }}
 *   Authorization: Bearer {{ $env.SUPABASE_ANON_KEY }}
 *   Content-Type: application/json
 *
 * Body (JSON): {{ $json.rpc_params }}
 */
