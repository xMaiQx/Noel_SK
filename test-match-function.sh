#!/bin/bash
# Test the match_learnings function directly

OPENAI_KEY="${OPENAI_API_KEY}"
SUPABASE_KEY="${SUPABASE_KEY}"
SUPABASE_URL="${SUPABASE_URL}"

echo "Testing match_learnings function with real OpenAI embedding"
echo ""

# Test 1: Query for "vector storage"
echo "=== Test 1: Query 'vector storage' ==="
EMBEDDING=$(curl -s https://api.openai.com/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_KEY" \
  -d '{"input": "vector storage", "model": "text-embedding-3-small"}' \
  | jq -c '.data[0].embedding')

RESULT=$(curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/match_learnings" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"query_embedding\": $EMBEDDING, \"match_count\": 5, \"project_filter\": null}")

echo "Results: $(echo "$RESULT" | jq 'length') matches"
echo "$RESULT" | jq '.[] | {learning_id, similarity}'
echo ""

# Test 2: Query for "HTTP Request"
echo "=== Test 2: Query 'HTTP Request' ==="
EMBEDDING2=$(curl -s https://api.openai.com/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_KEY" \
  -d '{"input": "HTTP Request", "model": "text-embedding-3-small"}' \
  | jq -c '.data[0].embedding')

RESULT2=$(curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/match_learnings" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"query_embedding\": $EMBEDDING2, \"match_count\": 5, \"project_filter\": null}")

echo "Results: $(echo "$RESULT2" | jq 'length') matches"
echo "$RESULT2" | jq '.[] | {learning_id, similarity}'
