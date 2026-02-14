#!/bin/bash

##############################################################################
# Noel - Backfill Missing Projects
#
# Purpose: Register all projects referenced in learnings but missing from
#          the Projects database. Fixes referential integrity issues.
#
# Context: The "lazy registration" approach failed - learnings were captured
#          without ensuring projects existed first. This script repairs that.
#
# Usage:
#   ./scripts/backfill-missing-projects.sh [--dry-run]
#
# Options:
#   --dry-run    Show what would be registered without making changes
#
# Author: Noel Team
# Date: 2025-01-04
##############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source helper functions
if [ -f "$SCRIPT_DIR/noel-helpers.sh" ]; then
  source "$SCRIPT_DIR/noel-helpers.sh"
else
  echo -e "${RED}Error: noel-helpers.sh not found${NC}"
  exit 1
fi

# Check for dry-run flag
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}\n"
fi

# Verify configuration
if ! _noel_check_config; then
  exit 1
fi

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Noel - Backfill Missing Projects Script             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}\n"

# Step 1: Query all unique projects from learnings
echo -e "${BLUE}Step 1: Querying all learnings to find unique project names...${NC}"

LEARNING_RESPONSE=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: ${NOEL_AUTH_TOKEN:-}" \
  -d '{"endpoint":"query_learnings","query":"all projects","limit":1000}')

# Check if response is wrapped in array (new format)
if echo "$LEARNING_RESPONSE" | jq -e 'type == "array"' > /dev/null 2>&1; then
  LEARNING_RESPONSE=$(echo "$LEARNING_RESPONSE" | jq '.[0]')
fi

if [ "$(echo "$LEARNING_RESPONSE" | jq -r '.success // false')" != "true" ]; then
  echo -e "${RED}✗ Failed to query learnings${NC}"
  echo "$LEARNING_RESPONSE" | jq '.'
  exit 1
fi

# Extract unique project names from learnings
LEARNING_PROJECTS=$(echo "$LEARNING_RESPONSE" | jq -r '.results[].metadata.project // empty' | sort -u)
LEARNING_COUNT=$(echo "$LEARNING_PROJECTS" | wc -l | tr -d ' ')

echo -e "${GREEN}✓ Found $LEARNING_COUNT unique projects in learnings${NC}\n"

# Step 2: Query all registered projects
echo -e "${BLUE}Step 2: Querying registered projects...${NC}"

PROJECT_RESPONSE=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: ${NOEL_AUTH_TOKEN:-}" \
  -d '{"endpoint":"list_projects","limit":1000}')

# Check if response is wrapped in array (new format)
if echo "$PROJECT_RESPONSE" | jq -e 'type == "array"' > /dev/null 2>&1; then
  PROJECT_RESPONSE=$(echo "$PROJECT_RESPONSE" | jq '.[0]')
fi

if [ "$(echo "$PROJECT_RESPONSE" | jq -r '.success // false')" != "true" ]; then
  echo -e "${RED}✗ Failed to query projects${NC}"
  echo "$PROJECT_RESPONSE" | jq '.'
  exit 1
fi

# Extract registered project names (from Notion .data.results format)
REGISTERED_PROJECTS=$(echo "$PROJECT_RESPONSE" | jq -r '.data.results[]?.properties.Name.title[0]?.plain_text // empty' | sort -u)
REGISTERED_COUNT=$(echo "$REGISTERED_PROJECTS" | wc -l | tr -d ' ')

echo -e "${GREEN}✓ Found $REGISTERED_COUNT registered projects${NC}\n"

# Step 3: Find missing projects (in learnings but not in Projects database)
echo -e "${BLUE}Step 3: Finding missing projects...${NC}"

MISSING_PROJECTS=$(comm -23 <(echo "$LEARNING_PROJECTS") <(echo "$REGISTERED_PROJECTS"))
MISSING_COUNT=$(echo "$MISSING_PROJECTS" | grep -v '^$' | wc -l | tr -d ' ')

if [ "$MISSING_COUNT" -eq 0 ]; then
  echo -e "${GREEN}✓ No missing projects found! All projects are registered.${NC}"
  exit 0
fi

echo -e "${YELLOW}⚠ Found $MISSING_COUNT unregistered projects:${NC}\n"

# Display missing projects
echo "$MISSING_PROJECTS" | grep -v '^$' | nl

echo ""

# Step 4: Register missing projects
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}[DRY RUN] Would register $MISSING_COUNT projects${NC}"
  exit 0
fi

echo -e "${BLUE}Step 4: Registering missing projects...${NC}\n"

REGISTERED=0
FAILED=0

while IFS= read -r project; do
  # Skip empty lines
  if [ -z "$project" ]; then
    continue
  fi

  echo -e "${BLUE}Registering: $project${NC}"

  # Register project with minimal metadata
  RESPONSE=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: ${NOEL_AUTH_TOKEN:-}" \
    -d "{
      \"endpoint\": \"create_project\",
      \"name\": \"$project\",
      \"description\": \"Auto-registered during backfill (2025-01-04)\",
      \"status\": \"Active\"
    }")

  # Check if response is wrapped in array (new format)
  if echo "$RESPONSE" | jq -e 'type == "array"' > /dev/null 2>&1; then
    RESPONSE=$(echo "$RESPONSE" | jq '.[0]')
  fi

  SUCCESS=$(echo "$RESPONSE" | jq -r '.success // false')

  if [ "$SUCCESS" = "true" ]; then
    MESSAGE=$(echo "$RESPONSE" | jq -r '.message // "Registered"')
    echo -e "${GREEN}  ✓ $MESSAGE${NC}\n"
    ((REGISTERED++))
  else
    ERROR=$(echo "$RESPONSE" | jq -r '.error // "Unknown error"')
    echo -e "${RED}  ✗ Failed: $ERROR${NC}\n"
    ((FAILED++))
  fi

done <<< "$MISSING_PROJECTS"

# Summary
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      Backfill Summary                         ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "  Total projects in learnings:    $LEARNING_COUNT"
echo -e "  Previously registered:          $REGISTERED_COUNT"
echo -e "  Missing (to backfill):          $MISSING_COUNT"
echo -e "${GREEN}  Successfully registered:        $REGISTERED${NC}"
if [ $FAILED -gt 0 ]; then
  echo -e "${RED}  Failed:                         $FAILED${NC}"
fi
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ Backfill complete! All projects are now registered.${NC}\n"
  echo -e "${BLUE}Next steps:${NC}"
  echo -e "  1. Verify with: noel-projects"
  echo -e "  2. Update project metadata as needed"
  echo -e "  3. Future sessions will use 'noel-register-project' before capturing learnings"
  echo ""
else
  echo -e "${YELLOW}⚠ Backfill complete with errors. Review failed projects above.${NC}\n"
  exit 1
fi
