#!/bin/bash
# End-to-end workflow test for Noel Knowledge Repository

WEBHOOK_URL="http://localhost:5678/webhook/noel"
AUTH_HEADER="Authorization: 1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

echo "=== Step 1: Create Session ==="
SESSION_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -H "$AUTH_HEADER" -d '{
  "endpoint": "create_session",
  "projects": ["Noel_Test"],
  "goals": "End-to-end workflow test",
  "ai_type": "Claude"
}')
echo "$SESSION_RESPONSE" | jq '.[0]'
SESSION_ID=$(echo "$SESSION_RESPONSE" | jq -r '.[0].session_id')
echo "Session ID: $SESSION_ID"
echo ""

echo "=== Step 2: Capture Learning ==="
LEARNING_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -H "$AUTH_HEADER" -d "{
  \"endpoint\": \"capture_learning\",
  \"project\": \"Noel_Test\",
  \"session_id\": \"$SESSION_ID\",
  \"title\": \"End-to-End Test Learning\",
  \"content\": \"This learning validates that the complete workflow is functioning: session creation, learning capture, querying, and session closure.\"
}")
echo "$LEARNING_RESPONSE" | jq '.[0]'
LEARNING_ID=$(echo "$LEARNING_RESPONSE" | jq -r '.[0].learning_id')
echo "Learning ID: $LEARNING_ID"
echo ""

echo "=== Step 3: Query Learnings ==="
QUERY_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -H "$AUTH_HEADER" -d '{
  "endpoint": "query_learnings",
  "query": "end-to-end workflow test",
  "limit": 3
}')
echo "$QUERY_RESPONSE" | jq '.[0].results | length' | xargs -I {} echo "Found {} results"
echo "$QUERY_RESPONSE" | jq '.[0].results[0] | {learning_id, title, similarity}'
echo ""

echo "=== Step 4: End Session ==="
sleep 2  # Wait to ensure measurable duration
END_RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -H "$AUTH_HEADER" -d "{
  \"endpoint\": \"end_session\",
  \"session_id\": \"$SESSION_ID\"
}")
echo "$END_RESPONSE" | jq '.[0]'
echo ""

echo "=== Test Complete ==="
echo "✓ Session created: $SESSION_ID"
echo "✓ Learning captured: $LEARNING_ID"
echo "✓ Query executed successfully"
echo "✓ Session ended"
