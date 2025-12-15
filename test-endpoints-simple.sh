#!/bin/bash

WEBHOOK_URL="http://localhost:5678/webhook/noel"
AUTH="Authorization: 1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

echo "Testing Noel API endpoints..."
echo ""

echo "1. list_projects:"
curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -H "$AUTH" -d '{"endpoint":"list_projects","limit":1}' | jq '.[0] | {success, count}'
echo ""

echo "2. capture_learning:"
curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -H "$AUTH" -d '{"endpoint":"capture_learning","project":"Noel_Test","title":"Endpoint Test","content":"Testing which endpoints work"}' | jq '.[0] | {success, title, embedding_stored}'
echo ""

echo "3. query_learnings:"
curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -H "$AUTH" -d '{"endpoint":"query_learnings","query":"endpoint test","limit":2}' | jq '.[0] | {success, count: (.results | length)}'
echo ""

echo "4. query_sessions:"
curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -H "$AUTH" -d '{"endpoint":"query_sessions","limit":2}' | jq '.[0] | {success, count: (.results | length)}'
echo ""

echo "5. create_session:"
curl -s -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -H "$AUTH" -d '{"endpoint":"create_session","projects":["Noel_Test"],"goals":"Testing","ai_type":"Claude"}' | jq '.'
echo ""
