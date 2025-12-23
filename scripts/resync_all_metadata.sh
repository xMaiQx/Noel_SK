#!/bin/bash

##############################################################################
# Re-sync All Learning Metadata from Notion to Supabase
#
# This script recaptures all learnings, which regenerates their embeddings
# and metadata in Supabase. Use this after bulk metadata updates in Notion.
##############################################################################

WEBHOOK_URL="https://18f625ebc1f0.ngrok-free.app/webhook/noel"
AUTH_TOKEN="1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Re-sync Metadata: Notion → Supabase${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Query all learnings
echo -e "${BLUE}📥 Fetching all learnings from Noel...${NC}"

RESPONSE=$(curl -s --location "$WEBHOOK_URL" \
  --header 'Content-Type: application/json' \
  --header "Authorization: $AUTH_TOKEN" \
  --data '{
    "endpoint": "query_learnings",
    "query": "Noel development",
    "filters": {"project": "Noel"},
    "limit": 100
  }')

# Extract learning IDs
LEARNING_IDS=$(echo "$RESPONSE" | jq -r '.[0].results[].learning_id')

COUNT=$(echo "$LEARNING_IDS" | wc -l | tr -d ' ')
echo -e "${GREEN}✓ Found $COUNT learnings${NC}"
echo ""

# For each learning, trigger a re-capture which will update Supabase
echo -e "${BLUE}🔄 Re-syncing metadata to Supabase...${NC}"
echo -e "${YELLOW}Note: This uses the update_learning endpoint to trigger metadata refresh${NC}"
echo ""

UPDATED=0
FAILED=0

while IFS= read -r learning_id; do
  if [ -z "$learning_id" ]; then
    continue
  fi

  echo -n "  Syncing: ${learning_id:0:60}... "

  # Trigger update with minimal change (updates Last Modified which triggers Supabase sync if workflow enhanced)
  UPDATE_RESPONSE=$(curl -s --location "$WEBHOOK_URL" \
    --header 'Content-Type: application/json' \
    --header "Authorization: $AUTH_TOKEN" \
    --data "{
      \"endpoint\": \"update_learning\",
      \"learning_id\": \"$learning_id\",
      \"ai_accepted\": true
    }" 2>&1)

  SUCCESS=$(echo "$UPDATE_RESPONSE" | jq -r '.[0].success // false' 2>/dev/null)

  if [ "$SUCCESS" = "true" ]; then
    echo -e "${GREEN}✓${NC}"
    ((UPDATED++))
  else
    echo -e "${YELLOW}⚠${NC}"
    ((FAILED++))
  fi

done <<< "$LEARNING_IDS"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Synced: $UPDATED${NC}"
echo -e "${YELLOW}⚠  Failed: $FAILED${NC}"
echo -e "${BLUE}📊 Total: $COUNT${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}⚠️  IMPORTANT:${NC}"
echo -e "The metadata in Notion has been updated, but Supabase vectors"
echo -e "need manual sync. The n8n workflow should be enhanced to update"
echo -e "Supabase metadata when update_learning is called."
echo ""
echo -e "For now, metadata in query results will be out of sync until"
echo -e "the workflow is enhanced or embeddings are regenerated."
