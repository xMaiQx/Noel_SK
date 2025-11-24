#!/bin/bash

##############################################################################
# Test Notion Database Connection via n8n Webhook Wrapper
#
# This script tests the connection to your Notion databases through
# the n8n webhook wrapper to verify everything is configured correctly.
#
# Prerequisites:
# 1. Environment configured (run: source scripts/setup-env.sh)
# 2. n8n workflow with Notion API wrapper webhook active
#
# Usage:
#   ./scripts/test-notion-connection.sh
##############################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Notion Database Connection Test                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if environment is loaded
if [ -z "$NGROK_URL" ]; then
  echo -e "${RED}Error: Environment not loaded${NC}"
  echo "Run: source scripts/setup-env.sh"
  exit 1
fi

# Check if Notion IDs are configured
if [ -z "$NOTION_PROJECTS_DB" ] || [ "$NOTION_PROJECTS_DB" = "YOUR_PROJECTS_DATABASE_ID_HERE" ]; then
  echo -e "${RED}Error: Notion database IDs not configured${NC}"
  echo "Run: ./scripts/get-notion-ids.sh"
  echo "Then update .env file"
  exit 1
fi

echo -e "Testing connection to: ${GREEN}$NGROK_URL${NC}"
echo ""

# Test function
function test_database() {
  local db_name="$1"
  local db_id="$2"

  echo -e "${BLUE}Testing $db_name database...${NC}"

  # Test retrieve_database (using Database ID)
  local response=$(curl -s -X POST "$NGROK_URL/webhook/notion_api_wrapper" \
    -H 'Content-Type: application/json' \
    -H "Authorization: $AUTH_TOKEN" \
    -d "{
      \"query\": {
        \"endpoint\": \"retrieve_database\",
        \"id\": \"$db_id\"
      },
      \"body\": {}
    }" 2>/dev/null)

  # Check if we got a valid response
  if echo "$response" | python3 -c "import json,sys; data=json.load(sys.stdin); sys.exit(0 if isinstance(data, (list, dict)) else 1)" 2>/dev/null; then
    # Try to extract database title
    local title=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list) and len(data) > 0:
        data = data[0]
    if 'title' in data:
        title_array = data['title']
        if title_array and len(title_array) > 0:
            print(title_array[0].get('plain_text', 'Unknown'))
        else:
            print('(No title)')
    else:
        print('(Schema retrieved)')
except:
    print('(Response received)')
" 2>/dev/null)

    echo -e "${GREEN}✓ $db_name: Connected - $title${NC}"

    # Show field count
    local fields=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list) and len(data) > 0:
        data = data[0]
    if 'properties' in data:
        print(f\"{len(data['properties'])} fields\")
    else:
        print('')
except:
    print('')
" 2>/dev/null)

    if [ -n "$fields" ]; then
      echo -e "  Fields: $fields"
    fi

  else
    echo -e "${RED}✗ $db_name: Failed to connect${NC}"
    echo -e "  Response: $response"
  fi

  echo ""
}

# Test all three databases
test_database "Projects" "$NOTION_PROJECTS_DB"
test_database "Learnings" "$NOTION_LEARNINGS_DB"
test_database "Sessions" "$NOTION_SESSIONS_DB"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Connection test complete${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Get Data Source IDs from n8n when connecting databases"
echo "2. Update .env with Data Source IDs (*_DS variables)"
echo "3. Test querying records using Data Source IDs"
echo ""
