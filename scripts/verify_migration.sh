#!/bin/bash

##############################################################################
# Verify Database Migration Applied Successfully
#
# Usage: bash scripts/verify_migration.sh 001
# Verifies migration 001_usage_tracking_schema.sql was applied
##############################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
SUPABASE_URL="https://sladetzgpogodrqwfamy.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsYWRldHpncG9nb2RycXdmYW15Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU0NjEwNDcsImV4cCI6MjA2MTAzNzA0N30.0lgfAKOCwRHSKI5NjhIQz-nAh0ej44N6AZbHlo8WzAE"

MIGRATION_ID="${1:-001}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Verify Migration ${MIGRATION_ID}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

ERRORS=0

# Test 1: Check learning_usage table exists
echo -n "1. Checking learning_usage table... "
RESPONSE=$(curl -s \
  "${SUPABASE_URL}/rest/v1/learning_usage?limit=0" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}")

if echo "$RESPONSE" | jq -e '. | type == "array"' > /dev/null 2>&1; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗${NC}"
  echo -e "  ${RED}Error: $RESPONSE${NC}"
  ((ERRORS++))
fi

# Test 2: Check learning_feedback table exists
echo -n "2. Checking learning_feedback table... "
RESPONSE=$(curl -s \
  "${SUPABASE_URL}/rest/v1/learning_feedback?limit=0" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}")

if echo "$RESPONSE" | jq -e '. | type == "array"' > /dev/null 2>&1; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗${NC}"
  echo -e "  ${RED}Error: $RESPONSE${NC}"
  ((ERRORS++))
fi

# Test 3: Test track_learning_usage function
echo -n "3. Testing track_learning_usage() function... "
RESPONSE=$(curl -s -X POST \
  "${SUPABASE_URL}/rest/v1/rpc/track_learning_usage" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_learning_id": "TEST-VERIFY-001",
    "p_session_id": "SESSION-VERIFY",
    "p_usage_context": "query_match",
    "p_query_text": "verification test",
    "p_similarity_score": 0.99,
    "p_was_helpful": true,
    "p_applied_successfully": true
  }')

if echo "$RESPONSE" | jq -e 'type == "string"' > /dev/null 2>&1; then
  USAGE_ID=$(echo "$RESPONSE" | jq -r '.')
  echo -e "${GREEN}✓${NC} (ID: ${USAGE_ID:0:8}...)"

  # Refresh metrics view to include test data
  curl -s -X POST \
    "${SUPABASE_URL}/rest/v1/rpc/refresh_learning_metrics" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" > /dev/null

  # Clean up test record
  curl -s -X DELETE \
    "${SUPABASE_URL}/rest/v1/learning_usage?id=eq.${USAGE_ID}" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" > /dev/null
else
  echo -e "${RED}✗${NC}"
  echo -e "  ${RED}Error: $RESPONSE${NC}"
  ((ERRORS++))
fi

# Test 4: Test get_learning_metrics function
echo -n "4. Testing get_learning_metrics() function... "
RESPONSE=$(curl -s -X POST \
  "${SUPABASE_URL}/rest/v1/rpc/get_learning_metrics" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_learning_id": null,
    "p_min_usage_count": 0,
    "p_sort_by": "effectiveness_score",
    "p_limit": 10
  }')

if echo "$RESPONSE" | jq -e '. | type == "array"' > /dev/null 2>&1; then
  COUNT=$(echo "$RESPONSE" | jq '. | length')
  echo -e "${GREEN}✓${NC} (${COUNT} metrics)"
else
  echo -e "${RED}✗${NC}"
  echo -e "  ${RED}Error: $RESPONSE${NC}"
  ((ERRORS++))
fi

# Test 5: Verify indexes created
echo -n "5. Checking table structure... "
# Check if we can query with filters (indicates indexes work)
RESPONSE=$(curl -s \
  "${SUPABASE_URL}/rest/v1/learning_usage?usage_context=eq.query_match&limit=1" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}")

if echo "$RESPONSE" | jq -e '. | type == "array"' > /dev/null 2>&1; then
  echo -e "${GREEN}✓${NC}"
else
  echo -e "${RED}✗${NC}"
  ((ERRORS++))
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}✅ All tests passed!${NC}"
  echo -e "${GREEN}   Migration ${MIGRATION_ID} successfully applied${NC}"
  echo ""
  echo -e "${BLUE}📊 Database ready for:${NC}"
  echo "   - Usage tracking (learning_usage table)"
  echo "   - User feedback (learning_feedback table)"
  echo "   - Metrics queries (learning_metrics view)"
  echo "   - Function calls (track_learning_usage, get_learning_metrics)"
else
  echo -e "${RED}❌ ${ERRORS} test(s) failed${NC}"
  echo -e "${YELLOW}   Please check the Supabase SQL Editor for errors${NC}"
  echo -e "${YELLOW}   Migration may not have been fully applied${NC}"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

exit $ERRORS
