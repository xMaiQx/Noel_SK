#!/bin/bash
# Test RAG directly via Supabase REST API (bypass n8n)

SUPABASE_URL="https://sladetzgpogodrqwfamy.supabase.co"
SUPABASE_KEY="your-anon-key-here"  # Replace with your anon key

# 1. Get an embedding from OpenAI
get_embedding() {
    local query="$1"
    curl -s https://api.openai.com/v1/embeddings \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d "{
            \"input\": \"$query\",
            \"model\": \"text-embedding-3-small\"
        }" | jq -r '.data[0].embedding | tostring'
}

# 2. Call match_learnings directly
search_learnings() {
    local embedding="$1"
    local limit="${2:-5}"

    curl -s "${SUPABASE_URL}/rest/v1/rpc/match_learnings" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"query_embedding\": ${embedding},
            \"match_count\": ${limit},
            \"project_filter\": null,
            \"similarity_threshold\": 0.1
        }" | jq '.'
}

# Test it
echo "Testing RAG pipeline directly..."
echo ""
echo "1. Getting embedding for query..."
QUERY="n8n vector search debugging"
EMBEDDING=$(get_embedding "$QUERY")

echo "2. Searching Supabase..."
search_learnings "$EMBEDDING" 3

echo ""
echo "If you see results above, the RAG works! The problem is just n8n."
