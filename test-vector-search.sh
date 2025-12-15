#!/bin/bash
# Test vector search directly

OPENAI_KEY="${OPENAI_API_KEY}"
SUPABASE_KEY="${SUPABASE_KEY}"
SUPABASE_URL="${SUPABASE_URL}"

echo "Step 1: Generating embedding for query 'endpoint test'..."
EMBEDDING=$(curl -s https://api.openai.com/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_KEY" \
  -d '{
    "input": "endpoint test",
    "model": "text-embedding-3-small"
  }' | jq -c '.data[0].embedding')

echo "Embedding generated (first 5 values): $(echo "$EMBEDDING" | jq '.[0:5]')"
echo ""

echo "Step 2: Searching Supabase for similar learnings..."
RESULTS=$(curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/match_learnings" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"query_embedding\": $EMBEDDING,
    \"match_count\": 5,
    \"project_filter\": null
  }")

echo "Results:"
echo "$RESULTS" | jq '.'
echo ""
echo "Number of matches: $(echo "$RESULTS" | jq '. | length')"
