#!/bin/bash

##############################################################################
# Automated Notion Database Verification Script
#
# This script automatically verifies that your Notion databases match the
# specification in data-model.md by querying them via the n8n API wrapper.
#
# Prerequisites:
# 1. Environment configured (run: source .env)
# 2. n8n workflow with notion_API_AIS webhook active
# 3. Notion databases created and shared with integration
#
# Usage:
#   ./scripts/verify-notion-databases.sh
##############################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Verification results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Load environment
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo -e "${RED}Error: .env file not found${NC}"
  exit 1
fi

source "$ENV_FILE"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Notion Database Automated Verification                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check environment variables
if [ -z "$NOTION_API_WRAPPER_URL" ]; then
  echo -e "${RED}Error: NOTION_API_WRAPPER_URL not set in .env${NC}"
  exit 1
fi

if [ -z "$AUTH_TOKEN" ]; then
  echo -e "${RED}Error: AUTH_TOKEN not set in .env${NC}"
  exit 1
fi

echo -e "API Wrapper URL: ${GREEN}$NOTION_API_WRAPPER_URL${NC}"
echo -e "Using databases:"
echo -e "  Projects:  ${CYAN}$NOTION_PROJECTS_DB${NC}"
echo -e "  Learnings: ${CYAN}$NOTION_LEARNINGS_DB${NC}"
echo -e "  Sessions:  ${CYAN}$NOTION_SESSIONS_DB${NC}"
echo ""

##############################################################################
# Helper Functions
##############################################################################

function print_section() {
  echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN} $1${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
}

function check_pass() {
  echo -e "${GREEN}✓ PASS:${NC} $1"
  ((PASSED_CHECKS++))
  ((TOTAL_CHECKS++))
}

function check_fail() {
  echo -e "${RED}✗ FAIL:${NC} $1"
  ((FAILED_CHECKS++))
  ((TOTAL_CHECKS++))
}

function check_warn() {
  echo -e "${YELLOW}⚠ WARN:${NC} $1"
  ((WARNINGS++))
}

function get_database_schema() {
  local db_id="$1"

  local response=$(curl -s -X POST "$NOTION_API_WRAPPER_URL" \
    -H 'Content-Type: application/json' \
    -H "Authorization: $AUTH_TOKEN" \
    -d "{
      \"query\": {
        \"endpoint\": \"retrieve_database\",
        \"id\": \"$db_id\"
      },
      \"body\": {}
    }" 2>/dev/null)

  echo "$response"
}

function check_property_exists() {
  local schema="$1"
  local property_name="$2"
  local expected_type="$3"

  local result=$(echo "$schema" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list) and len(data) > 0:
        data = data[0]

    props = data.get('properties', {})
    if '$property_name' in props:
        actual_type = props['$property_name'].get('type', '')
        if actual_type == '$expected_type':
            print('PASS')
        else:
            print(f'TYPE_MISMATCH:{actual_type}')
    else:
        print('MISSING')
except Exception as e:
    print(f'ERROR:{e}')
" 2>&1)

  echo "$result"
}

function check_select_options() {
  local schema="$1"
  local property_name="$2"
  shift 2
  local expected_options=("$@")

  local result=$(echo "$schema" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list) and len(data) > 0:
        data = data[0]

    props = data.get('properties', {})
    if '$property_name' not in props:
        print('PROPERTY_MISSING')
        sys.exit(0)

    prop = props['$property_name']
    prop_type = prop.get('type', '')

    if prop_type == 'select':
        options = [opt['name'] for opt in prop.get('select', {}).get('options', [])]
    elif prop_type == 'multi_select':
        options = [opt['name'] for opt in prop.get('multi_select', {}).get('options', [])]
    else:
        print(f'WRONG_TYPE:{prop_type}')
        sys.exit(0)

    expected = ${expected_options[@]}
    expected_set = set([opt.strip() for opt in ' '.join(expected).split()])
    actual_set = set(options)

    missing = expected_set - actual_set
    if missing:
        print(f'MISSING_OPTIONS:{','.join(missing)}')
    else:
        print('PASS')
except Exception as e:
    print(f'ERROR:{e}')
" 2>&1)

  echo "$result"
}

##############################################################################
# Verify Projects Database
##############################################################################

print_section "1. PROJECTS DATABASE"

echo -e "${BLUE}Retrieving Projects database schema...${NC}"
PROJECTS_SCHEMA=$(get_database_schema "$NOTION_PROJECTS_DB")

# Check if we got a valid response
if echo "$PROJECTS_SCHEMA" | grep -q '"properties"'; then
  check_pass "Projects database accessible"

  # Get database title
  DB_TITLE=$(echo "$PROJECTS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
title = data.get('title', [{}])[0].get('plain_text', 'Unknown')
print(title)
" 2>/dev/null)

  echo -e "  Database name: ${CYAN}$DB_TITLE${NC}"

  # Count properties
  PROP_COUNT=$(echo "$PROJECTS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
print(len(data.get('properties', {})))
" 2>/dev/null)

  echo -e "  Total properties: ${CYAN}$PROP_COUNT${NC}"

  if [ "$PROP_COUNT" -eq 10 ]; then
    check_pass "Projects has exactly 10 properties (as specified)"
  else
    check_fail "Projects has $PROP_COUNT properties, expected 10"
  fi

  # Verify each required property
  echo ""
  echo -e "${YELLOW}Checking required properties:${NC}"

  # Name (Title)
  result=$(check_property_exists "$PROJECTS_SCHEMA" "Name" "title")
  if [ "$result" = "PASS" ]; then
    check_pass "Name property exists (title type)"
  else
    check_fail "Name property: $result"
  fi

  # Status (Select)
  result=$(check_property_exists "$PROJECTS_SCHEMA" "Status" "select")
  if [ "$result" = "PASS" ]; then
    check_pass "Status property exists (select type)"

    # Check options
    options_result=$(echo "$PROJECTS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
props = data.get('properties', {})
if 'Status' in props:
    options = [opt['name'] for opt in props['Status'].get('select', {}).get('options', [])]
    expected = ['Active', 'On Hold', 'Planning', 'Completed', 'Archived']
    missing = set(expected) - set(options)
    if missing:
        print(f'Missing: {', '.join(missing)}')
    else:
        print('PASS')
" 2>/dev/null)

    if [ "$options_result" = "PASS" ]; then
      check_pass "Status has all required options (Active, On Hold, Planning, Completed, Archived)"
    else
      check_fail "Status options: $options_result"
    fi
  else
    check_fail "Status property: $result"
  fi

  # Priority (Select)
  result=$(check_property_exists "$PROJECTS_SCHEMA" "Priority" "select")
  if [ "$result" = "PASS" ]; then
    check_pass "Priority property exists (select type)"

    options_result=$(echo "$PROJECTS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
props = data.get('properties', {})
if 'Priority' in props:
    options = [opt['name'] for opt in props['Priority'].get('select', {}).get('options', [])]
    expected = ['P0-Critical', 'P1-High', 'P2-Medium', 'P3-Low']
    missing = set(expected) - set(options)
    if missing:
        print(f'Missing: {', '.join(missing)}')
    else:
        print('PASS')
" 2>/dev/null)

    if [ "$options_result" = "PASS" ]; then
      check_pass "Priority has all required options (P0-Critical, P1-High, P2-Medium, P3-Low)"
    else
      check_fail "Priority options: $options_result"
    fi
  else
    check_fail "Priority property: $result"
  fi

  # Tech Stack (Multi-select)
  result=$(check_property_exists "$PROJECTS_SCHEMA" "Tech Stack" "multi_select")
  if [ "$result" = "PASS" ]; then
    check_pass "Tech Stack property exists (multi_select type)"
  else
    check_fail "Tech Stack property: $result"
  fi

  # Description (Rich Text)
  result=$(check_property_exists "$PROJECTS_SCHEMA" "Description" "rich_text")
  if [ "$result" = "PASS" ]; then
    check_pass "Description property exists (rich_text type)"
  else
    check_fail "Description property: $result"
  fi

  # Started (Date)
  result=$(check_property_exists "$PROJECTS_SCHEMA" "Started" "date")
  if [ "$result" = "PASS" ]; then
    check_pass "Started property exists (date type)"
  else
    check_fail "Started property: $result"
  fi

  # Last Activity (Date)
  result=$(check_property_exists "$PROJECTS_SCHEMA" "Last Activity" "date")
  if [ "$result" = "PASS" ]; then
    check_pass "Last Activity property exists (date type)"
  else
    check_fail "Last Activity property: $result"
  fi

  # Learning Count (Rollup)
  result=$(check_property_exists "$PROJECTS_SCHEMA" "Learning Count" "rollup")
  if [ "$result" = "PASS" ]; then
    check_pass "Learning Count property exists (rollup type)"
  else
    check_fail "Learning Count property: $result"
  fi

  # Session Count (Rollup)
  result=$(check_property_exists "$PROJECTS_SCHEMA" "Session Count" "rollup")
  if [ "$result" = "PASS" ]; then
    check_pass "Session Count property exists (rollup type)"
  else
    check_fail "Session Count property: $result"
  fi

  # Total Session Hours (Rollup)
  result=$(check_property_exists "$PROJECTS_SCHEMA" "Total Session Hours" "rollup")
  if [ "$result" = "PASS" ]; then
    check_pass "Total Session Hours property exists (rollup type)"
  else
    check_fail "Total Session Hours property: $result"
  fi

else
  check_fail "Could not retrieve Projects database schema"
  echo -e "${RED}Response: $PROJECTS_SCHEMA${NC}"
fi

##############################################################################
# Verify Learnings Database
##############################################################################

print_section "2. LEARNINGS DATABASE"

echo -e "${BLUE}Retrieving Learnings database schema...${NC}"
LEARNINGS_SCHEMA=$(get_database_schema "$NOTION_LEARNINGS_DB")

if echo "$LEARNINGS_SCHEMA" | grep -q '"properties"'; then
  check_pass "Learnings database accessible"

  DB_TITLE=$(echo "$LEARNINGS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
title = data.get('title', [{}])[0].get('plain_text', 'Unknown')
print(title)
" 2>/dev/null)

  echo -e "  Database name: ${CYAN}$DB_TITLE${NC}"

  PROP_COUNT=$(echo "$LEARNINGS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
print(len(data.get('properties', {})))
" 2>/dev/null)

  echo -e "  Total properties: ${CYAN}$PROP_COUNT${NC}"

  if [ "$PROP_COUNT" -eq 14 ]; then
    check_pass "Learnings has exactly 14 properties (as specified)"
  else
    check_fail "Learnings has $PROP_COUNT properties, expected 14"
  fi

  echo ""
  echo -e "${YELLOW}Checking required properties:${NC}"

  # Check all 14 properties
  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Title" "title")
  [ "$result" = "PASS" ] && check_pass "Title (title)" || check_fail "Title: $result"

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Learning ID" "rich_text")
  [ "$result" = "PASS" ] && check_pass "Learning ID (rich_text)" || check_fail "Learning ID: $result"

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Project" "relation")
  [ "$result" = "PASS" ] && check_pass "Project (relation)" || check_fail "Project: $result"

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Type" "select")
  if [ "$result" = "PASS" ]; then
    check_pass "Type (select)"
    # Check Type options
    options_result=$(echo "$LEARNINGS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
props = data.get('properties', {})
if 'Type' in props:
    options = [opt['name'] for opt in props['Type'].get('select', {}).get('options', [])]
    expected = ['Pattern', 'Solution', 'Error', 'Decision', 'Insight', 'Anti-Pattern', 'Best Practice']
    missing = set(expected) - set(options)
    if missing:
        print(f'Missing: {', '.join(missing)}')
    else:
        print('PASS')
" 2>/dev/null)
    [ "$options_result" = "PASS" ] && check_pass "Type has all required options" || check_fail "Type options: $options_result"
  else
    check_fail "Type: $result"
  fi

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Dev Stream" "multi_select")
  if [ "$result" = "PASS" ]; then
    check_pass "Dev Stream (multi_select)"
    # Check Dev Stream options
    options_result=$(echo "$LEARNINGS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
props = data.get('properties', {})
if 'Dev Stream' in props:
    options = [opt['name'] for opt in props['Dev Stream'].get('multi_select', {}).get('options', [])]
    expected = ['Back-end', 'Front-end', 'UI/UX', 'n8n', 'Database', 'API', 'DevOps', 'Architecture', 'Performance', 'Security']
    missing = set(expected) - set(options)
    if missing:
        print(f'Missing: {', '.join(missing)}')
    else:
        print('PASS')
" 2>/dev/null)
    [ "$options_result" = "PASS" ] && check_pass "Dev Stream has all required options" || check_fail "Dev Stream options: $options_result"
  else
    check_fail "Dev Stream: $result"
  fi

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Content" "rich_text")
  [ "$result" = "PASS" ] && check_pass "Content (rich_text)" || check_fail "Content: $result"

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Context" "rich_text")
  [ "$result" = "PASS" ] && check_pass "Context (rich_text)" || check_fail "Context: $result"

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Tags" "multi_select")
  [ "$result" = "PASS" ] && check_pass "Tags (multi_select)" || check_fail "Tags: $result"

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Related Files" "rich_text")
  [ "$result" = "PASS" ] && check_pass "Related Files (rich_text)" || check_fail "Related Files: $result"

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Confidence" "select")
  if [ "$result" = "PASS" ]; then
    check_pass "Confidence (select)"
    options_result=$(echo "$LEARNINGS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
props = data.get('properties', {})
if 'Confidence' in props:
    options = [opt['name'] for opt in props['Confidence'].get('select', {}).get('options', [])]
    expected = ['High', 'Medium', 'Low']
    missing = set(expected) - set(options)
    if missing:
        print(f'Missing: {', '.join(missing)}')
    else:
        print('PASS')
" 2>/dev/null)
    [ "$options_result" = "PASS" ] && check_pass "Confidence has all required options" || check_fail "Confidence options: $options_result"
  else
    check_fail "Confidence: $result"
  fi

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Status" "select")
  if [ "$result" = "PASS" ]; then
    check_pass "Status (select)"
    options_result=$(echo "$LEARNINGS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
props = data.get('properties', {})
if 'Status' in props:
    options = [opt['name'] for opt in props['Status'].get('select', {}).get('options', [])]
    expected = ['Validated', 'Hypothesis', 'Deprecated']
    missing = set(expected) - set(options)
    if missing:
        print(f'Missing: {', '.join(missing)}')
    else:
        print('PASS')
" 2>/dev/null)
    [ "$options_result" = "PASS" ] && check_pass "Status has all required options" || check_fail "Status options: $options_result"
  else
    check_fail "Status: $result"
  fi

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Timestamp" "date")
  [ "$result" = "PASS" ] && check_pass "Timestamp (date)" || check_fail "Timestamp: $result"

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Last Modified" "date")
  [ "$result" = "PASS" ] && check_pass "Last Modified (date)" || check_fail "Last Modified: $result"

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "Session" "relation")
  [ "$result" = "PASS" ] && check_pass "Session (relation)" || check_fail "Session: $result"

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "AI Suggested" "checkbox")
  [ "$result" = "PASS" ] && check_pass "AI Suggested (checkbox)" || check_fail "AI Suggested: $result"

  result=$(check_property_exists "$LEARNINGS_SCHEMA" "AI Accepted" "checkbox")
  [ "$result" = "PASS" ] && check_pass "AI Accepted (checkbox)" || check_fail "AI Accepted: $result"

else
  check_fail "Could not retrieve Learnings database schema"
  echo -e "${RED}Response: $LEARNINGS_SCHEMA${NC}"
fi

##############################################################################
# Verify Sessions Database
##############################################################################

print_section "3. SESSIONS DATABASE"

echo -e "${BLUE}Retrieving Sessions database schema...${NC}"
SESSIONS_SCHEMA=$(get_database_schema "$NOTION_SESSIONS_DB")

if echo "$SESSIONS_SCHEMA" | grep -q '"properties"'; then
  check_pass "Sessions database accessible"

  DB_TITLE=$(echo "$SESSIONS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
title = data.get('title', [{}])[0].get('plain_text', 'Unknown')
print(title)
" 2>/dev/null)

  echo -e "  Database name: ${CYAN}$DB_TITLE${NC}"

  PROP_COUNT=$(echo "$SESSIONS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
print(len(data.get('properties', {})))
" 2>/dev/null)

  echo -e "  Total properties: ${CYAN}$PROP_COUNT${NC}"

  if [ "$PROP_COUNT" -eq 11 ]; then
    check_pass "Sessions has exactly 11 properties (as specified)"
  else
    check_fail "Sessions has $PROP_COUNT properties, expected 11"
  fi

  echo ""
  echo -e "${YELLOW}Checking required properties:${NC}"

  result=$(check_property_exists "$SESSIONS_SCHEMA" "Session ID" "title")
  [ "$result" = "PASS" ] && check_pass "Session ID (title)" || check_fail "Session ID: $result"

  result=$(check_property_exists "$SESSIONS_SCHEMA" "Projects" "relation")
  [ "$result" = "PASS" ] && check_pass "Projects (relation)" || check_fail "Projects: $result"

  result=$(check_property_exists "$SESSIONS_SCHEMA" "Goals" "rich_text")
  [ "$result" = "PASS" ] && check_pass "Goals (rich_text)" || check_fail "Goals: $result"

  result=$(check_property_exists "$SESSIONS_SCHEMA" "Start Time" "date")
  [ "$result" = "PASS" ] && check_pass "Start Time (date)" || check_fail "Start Time: $result"

  result=$(check_property_exists "$SESSIONS_SCHEMA" "End Time" "date")
  [ "$result" = "PASS" ] && check_pass "End Time (date)" || check_fail "End Time: $result"

  result=$(check_property_exists "$SESSIONS_SCHEMA" "Status" "select")
  if [ "$result" = "PASS" ]; then
    check_pass "Status (select)"
    options_result=$(echo "$SESSIONS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
props = data.get('properties', {})
if 'Status' in props:
    options = [opt['name'] for opt in props['Status'].get('select', {}).get('options', [])]
    expected = ['Active', 'Completed', 'Abandoned']
    missing = set(expected) - set(options)
    if missing:
        print(f'Missing: {', '.join(missing)}')
    else:
        print('PASS')
" 2>/dev/null)
    [ "$options_result" = "PASS" ] && check_pass "Status has all required options" || check_fail "Status options: $options_result"
  else
    check_fail "Status: $result"
  fi

  result=$(check_property_exists "$SESSIONS_SCHEMA" "AI Type" "select")
  if [ "$result" = "PASS" ]; then
    check_pass "AI Type (select)"
    options_result=$(echo "$SESSIONS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
props = data.get('properties', {})
if 'AI Type' in props:
    options = [opt['name'] for opt in props['AI Type'].get('select', {}).get('options', [])]
    expected = ['Claude', 'Gemini', 'Other']
    missing = set(expected) - set(options)
    if missing:
        print(f'Missing: {', '.join(missing)}')
    else:
        print('PASS')
" 2>/dev/null)
    [ "$options_result" = "PASS" ] && check_pass "AI Type has all required options" || check_fail "AI Type options: $options_result"
  else
    check_fail "AI Type: $result"
  fi

  result=$(check_property_exists "$SESSIONS_SCHEMA" "Recording File Path" "rich_text")
  [ "$result" = "PASS" ] && check_pass "Recording File Path (rich_text)" || check_fail "Recording File Path: $result"

  result=$(check_property_exists "$SESSIONS_SCHEMA" "Recording Format" "select")
  if [ "$result" = "PASS" ]; then
    check_pass "Recording Format (select)"
    options_result=$(echo "$SESSIONS_SCHEMA" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list): data = data[0]
props = data.get('properties', {})
if 'Recording Format' in props:
    options = [opt['name'] for opt in props['Recording Format'].get('select', {}).get('options', [])]
    expected = ['asciinema', 'other']
    missing = set(expected) - set(options)
    if missing:
        print(f'Missing: {', '.join(missing)}')
    else:
        print('PASS')
" 2>/dev/null)
    [ "$options_result" = "PASS" ] && check_pass "Recording Format has all required options" || check_fail "Recording Format options: $options_result"
  else
    check_fail "Recording Format: $result"
  fi

  result=$(check_property_exists "$SESSIONS_SCHEMA" "Learning Count" "rollup")
  [ "$result" = "PASS" ] && check_pass "Learning Count (rollup)" || check_fail "Learning Count: $result"

  result=$(check_property_exists "$SESSIONS_SCHEMA" "Duration" "formula")
  [ "$result" = "PASS" ] && check_pass "Duration (formula)" || check_fail "Duration: $result"

else
  check_fail "Could not retrieve Sessions database schema"
  echo -e "${RED}Response: $SESSIONS_SCHEMA${NC}"
fi

##############################################################################
# Summary
##############################################################################

print_section "VERIFICATION SUMMARY"

echo -e "Total checks:  ${CYAN}$TOTAL_CHECKS${NC}"
echo -e "Passed:        ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Failed:        ${RED}$FAILED_CHECKS${NC}"
echo -e "Warnings:      ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
  echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║  ✓ ALL CHECKS PASSED - DATABASES VERIFIED!                ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo "1. Get Data Source IDs from n8n when connecting databases"
  echo "2. Update .env with Data Source IDs"
  echo "3. Begin building n8n workflow"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║  ✗ VERIFICATION FAILED - FIX ERRORS ABOVE                  ║${NC}"
  echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}To fix issues:${NC}"
  echo "1. Review failed checks above"
  echo "2. Compare with specs/001-knowledge-repository/data-model.md"
  echo "3. Update databases in Notion"
  echo "4. Re-run this script to verify"
  echo ""
  exit 1
fi
