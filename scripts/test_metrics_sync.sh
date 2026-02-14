#!/bin/bash
##############################################################################
# Test Metrics Sync - Create Sample Data and Test Sync
#
# Usage: bash scripts/test_metrics_sync.sh
##############################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Load environment
source .env 2>/dev/null || {
  echo -e "${RED}Error: .env file not found${NC}"
  exit 1
}

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Test Metrics Sync Flow${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 1: Insert test usage data into Supabase
echo -e "${BLUE}Step 1: Creating test usage data in Supabase...${NC}"

# Create test learning in Notion first (manual step reminder)
echo -e "${YELLOW}Note: Make sure you have a test learning in Notion with ID 'TEST-METRICS-001'${NC}"
echo ""

# Insert multiple usage records for the test learning
echo "Inserting usage record 1 (helpful + successful)..."
USAGE_ID_1=$(curl -s -X POST \
  "${SUPABASE_URL}/rest/v1/rpc/track_learning_usage" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_learning_id": "TEST-METRICS-001",
    "p_session_id": "SESSION-TEST-001",
    "p_usage_context": "query_match",
    "p_query_text": "How to sync metrics?",
    "p_similarity_score": 0.92,
    "p_was_helpful": true,
    "p_applied_successfully": true
  }' | jq -r '.')

echo -e "${GREEN}✓${NC} Created usage record: ${USAGE_ID_1:0:8}..."

echo "Inserting usage record 2 (helpful + successful)..."
USAGE_ID_2=$(curl -s -X POST \
  "${SUPABASE_URL}/rest/v1/rpc/track_learning_usage" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_learning_id": "TEST-METRICS-001",
    "p_session_id": "SESSION-TEST-002",
    "p_usage_context": "manual_reference",
    "p_query_text": null,
    "p_similarity_score": null,
    "p_was_helpful": true,
    "p_applied_successfully": true
  }' | jq -r '.')

echo -e "${GREEN}✓${NC} Created usage record: ${USAGE_ID_2:0:8}..."

echo "Inserting usage record 3 (not helpful)..."
USAGE_ID_3=$(curl -s -X POST \
  "${SUPABASE_URL}/rest/v1/rpc/track_learning_usage" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_learning_id": "TEST-METRICS-001",
    "p_session_id": "SESSION-TEST-003",
    "p_usage_context": "query_match",
    "p_query_text": "Metrics tracking",
    "p_similarity_score": 0.78,
    "p_was_helpful": false,
    "p_applied_successfully": false
  }' | jq -r '.')

echo -e "${GREEN}✓${NC} Created usage record: ${USAGE_ID_3:0:8}..."
echo ""

# Step 2: Refresh materialized view
echo -e "${BLUE}Step 2: Refreshing metrics view...${NC}"
curl -s -X POST \
  "${SUPABASE_URL}/rest/v1/rpc/refresh_learning_metrics" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" > /dev/null

echo -e "${GREEN}✓${NC} Metrics view refreshed"
echo ""

# Step 3: Query metrics to verify
echo -e "${BLUE}Step 3: Querying metrics...${NC}"
METRICS=$(curl -s -X POST \
  "${SUPABASE_URL}/rest/v1/rpc/get_learning_metrics" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_learning_id": "TEST-METRICS-001",
    "p_min_usage_count": 0,
    "p_sort_by": "effectiveness_score",
    "p_limit": 1
  }')

echo "Metrics for TEST-METRICS-001:"
echo "$METRICS" | jq -r '.[0] | "  Total Uses: \(.total_uses)\n  Helpful Rate: \(.helpful_rate)%\n  Success Rate: \(.success_rate)%\n  Effectiveness Score: \(.effectiveness_score)\n  Last Used: \(.last_used)"'
echo ""

# Step 4: Run sync script (if NOTION_TOKEN is set)
if [ -z "$NOTION_TOKEN" ]; then
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}⚠ NOTION_TOKEN not set in .env${NC}"
  echo ""
  echo "To complete the sync test:"
  echo "1. Add your Notion Integration Token to .env:"
  echo "   NOTION_TOKEN=\"secret_xxxxx\""
  echo ""
  echo "2. Get the token from: https://www.notion.so/my-integrations"
  echo ""
  echo "3. Then run:"
  echo "   python3 scripts/sync_learning_metrics.py TEST-METRICS-001"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
  echo -e "${BLUE}Step 4: Syncing to Notion...${NC}"
  python3 scripts/sync_learning_metrics.py TEST-METRICS-001
fi

echo ""
echo -e "${GREEN}✅ Test data created successfully!${NC}"
echo ""
echo "Expected metrics:"
echo "  • Total Uses: 3"
echo "  • Helpful Rate: 66.67% (2 helpful / 3 total)"
echo "  • Success Rate: 66.67% (2 successful / 3 total)"
echo "  • Effectiveness Score: ~2.00 ((0.67*0.6 + 0.67*0.4) * 3)"
echo ""

# Cleanup option
echo -e "${BLUE}Clean up test data? [y/N]${NC}"
read -r CLEANUP
if [[ "$CLEANUP" =~ ^[Yy]$ ]]; then
  echo "Cleaning up test records..."
  curl -s -X DELETE \
    "${SUPABASE_URL}/rest/v1/learning_usage?learning_id=eq.TEST-METRICS-001" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" > /dev/null

  curl -s -X POST \
    "${SUPABASE_URL}/rest/v1/rpc/refresh_learning_metrics" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" > /dev/null

  echo -e "${GREEN}✓${NC} Test data cleaned up"
fi

echo ""
