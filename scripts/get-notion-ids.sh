#!/bin/bash

##############################################################################
# Extract Notion Database IDs from Notion URLs
#
# This script helps you extract Database IDs from Notion database URLs
# so you can populate the .env file
#
# Usage:
#   1. Open your Notion database
#   2. Click "..." menu → Copy link
#   3. Paste the URL when prompted
#   4. Script will extract the Database ID
##############################################################################

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Notion Database ID Extractor for Noel                    ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╝${NC}"
echo ""

function extract_database_id() {
  local url="$1"

  # Remove any query parameters and extract the ID portion
  # Format: https://www.notion.so/username/database-name-{DATABASE_ID}?v=...
  # We want just the DATABASE_ID part

  local id=$(echo "$url" | sed -E 's/.*\/([a-f0-9]{32}).*/\1/')

  if [[ "$id" =~ ^[a-f0-9]{32}$ ]]; then
    # Format with dashes: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    echo "${id:0:8}-${id:8:4}-${id:12:4}-${id:16:4}-${id:20:12}"
  else
    echo "ERROR: Could not extract valid Database ID"
    return 1
  fi
}

echo -e "${YELLOW}Step 1: Get Projects Database ID${NC}"
echo "In Notion:"
echo "  1. Open your 'Projects' database"
echo "  2. Click '...' menu → Copy link"
echo "  3. Paste the URL below"
echo ""
read -p "Projects database URL: " projects_url

projects_db=$(extract_database_id "$projects_url")
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ Projects Database ID: $projects_db${NC}"
  echo ""
else
  echo -e "Failed to extract Projects database ID"
  exit 1
fi

echo -e "${YELLOW}Step 2: Get Learnings Database ID${NC}"
echo "In Notion:"
echo "  1. Open your 'Learnings' database"
echo "  2. Click '...' menu → Copy link"
echo "  3. Paste the URL below"
echo ""
read -p "Learnings database URL: " learnings_url

learnings_db=$(extract_database_id "$learnings_url")
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ Learnings Database ID: $learnings_db${NC}"
  echo ""
else
  echo -e "Failed to extract Learnings database ID"
  exit 1
fi

echo -e "${YELLOW}Step 3: Get Sessions Database ID${NC}"
echo "In Notion:"
echo "  1. Open your 'Sessions' database"
echo "  2. Click '...' menu → Copy link"
echo "  3. Paste the URL below"
echo ""
read -p "Sessions database URL: " sessions_url

sessions_db=$(extract_database_id "$sessions_url")
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ Sessions Database ID: $sessions_db${NC}"
  echo ""
else
  echo -e "Failed to extract Sessions database ID"
  exit 1
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Database IDs Extracted Successfully!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Add these to your .env file:"
echo ""
echo -e "${YELLOW}NOTION_PROJECTS_DB=\"$projects_db\"${NC}"
echo -e "${YELLOW}NOTION_LEARNINGS_DB=\"$learnings_db\"${NC}"
echo -e "${YELLOW}NOTION_SESSIONS_DB=\"$sessions_db\"${NC}"
echo ""
echo -e "${BLUE}Note: You still need to get Data Source IDs (DS) from n8n${NC}"
echo "Data Source IDs will be visible when you connect databases in n8n Notion nodes"
echo ""
