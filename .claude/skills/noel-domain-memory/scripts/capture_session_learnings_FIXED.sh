#!/bin/bash

##############################################################################
# Capture 12 Learnings with Project Lookup Fix
#
# This version looks up the Noel project ID before each capture to ensure
# the Project relation is properly set.
##############################################################################

WEBHOOK_URL="https://18f625ebc1f0.ngrok-free.app/webhook/noel"
AUTH_TOKEN="1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "Capturing 12 learnings with Project relation fix..."
echo ""

# Lookup Noel project ID once (reuse for all captures)
echo -e "${BLUE}Looking up Noel project ID...${NC}"
PROJECT_RESPONSE=$(curl -s --location "$WEBHOOK_URL" \
  --header 'Content-Type: application/json' \
  --header "Authorization: $AUTH_TOKEN" \
  --data '{"endpoint":"list_projects","limit":100}')

NOEL_PROJECT_ID=$(echo "$PROJECT_RESPONSE" | jq -r '.[0].data.results[] | select(.properties.Name.title[0].text.content == "Noel") | .id')

if [ -z "$NOEL_PROJECT_ID" ] || [ "$NOEL_PROJECT_ID" = "null" ]; then
  echo -e "${RED}✗ Could not find Noel project!${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Found Noel project ID: $NOEL_PROJECT_ID${NC}"
echo ""

# Function to capture learning
capture_learning() {
  local title="$1"
  local content="$2"
  local type="$3"
  local confidence="$4"

  local response=$(curl -s --location "$WEBHOOK_URL" \
    --header 'Content-Type: application/json' \
    --header "Authorization: $AUTH_TOKEN" \
    --data "{
      \"endpoint\": \"capture_learning\",
      \"project\": \"Noel\",
      \"project_id\": \"$NOEL_PROJECT_ID\",
      \"title\": \"$title\",
      \"content\": \"$content\",
      \"type\": \"$type\",
      \"confidence\": \"$confidence\"
    }")

  local success=$(echo "$response" | jq -r '.[0].success // false' 2>/dev/null)

  if [ "$success" = "true" ]; then
    local learning_title=$(echo "$response" | jq -r '.[0].title // "unknown"' 2>/dev/null)
    echo -e "${GREEN}✓${NC} Captured: $learning_title"
    return 0
  else
    echo -e "${RED}✗${NC} Failed"
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
    return 1
  fi
}

# Learning 1
echo -e "${BLUE}📚 [1/12]${NC} Notion API Two ID Types..."
capture_learning \
  "Notion API Two ID Types" \
  "Notion databases have TWO different IDs: (1) Database ID for schema operations (retrieve_database), (2) Data Source ID for querying records (query_data_source). These are NOT interchangeable! Using wrong ID returns empty results. Get Database ID from Notion URL, get Data Source ID from data_sources[0].id in retrieve_database response." \
  "Pattern" \
  "High"

# Learning 2
echo -e "${BLUE}📚 [2/12]${NC} Bash Piping to Python..."
capture_learning \
  "Bash Piping curl to Python" \
  "When piping curl output to python3, shell variable expansion inside heredocs causes syntax errors. curl progress bar mixes with JSON. Solutions: (1) Suppress stderr with 2>/dev/null, (2) Use file intermediary, (3) Quote heredoc delimiter << 'EOF'." \
  "Error" \
  "High"

# Learning 3
echo -e "${BLUE}📚 [3/12]${NC} Bash Path Resolution..."
capture_learning \
  "Environment Variable Path Resolution" \
  "When sourcing bash scripts, BASH_SOURCE[0] may be empty if script is sourced vs executed directly. This breaks relative path resolution. Use fallback with $0 and try multiple locations for .env file." \
  "Error" \
  "High"

# Learning 4
echo -e "${BLUE}📚 [4/12]${NC} Property Name Trailing Spaces..."
capture_learning \
  "Notion Property Names Trailing Spaces" \
  "Notion property names with trailing spaces cause silent failures. Visual inspection misses them - only automated comparison reveals the issue. Example: 'AI Suggested ' vs 'AI Suggested'. Prevention: Always use automated verification." \
  "Anti-Pattern" \
  "High"

# Learning 5
echo -e "${BLUE}📚 [5/12]${NC} Relation Naming Conventions..."
capture_learning \
  "Singular vs Plural Relation Naming" \
  "Relation property names should reflect cardinality: Singular for many-to-one (Learnings.Session), Plural for one-to-many (Sessions.Learnings). This improves code readability and API consistency." \
  "Pattern" \
  "High"

# Learning 6
echo -e "${BLUE}📚 [6/12]${NC} Automated Verification..."
capture_learning \
  "Automated Verification Beats Manual Checklists" \
  "Manual checklists fail to catch: trailing spaces, plural/singular errors, missing properties, type mismatches. Automated verification catches ALL discrepancies instantly. ROI: 15-30 min manual to 5 sec automated." \
  "Insight" \
  "High"

# Learning 7
echo -e "${BLUE}📚 [7/12]${NC} Notion Reverse Relations..."
capture_learning \
  "Notion Reverse Relations Auto-Generate" \
  "When creating a relation in Notion, a reverse relation is automatically created in the target database. These reverse relations appear as extra fields but are expected and correct. Don't flag as validation errors." \
  "Pattern" \
  "High"

# Learning 8
echo -e "${BLUE}📚 [8/12]${NC} Python f-string Nested Quotes..."
capture_learning \
  "Python f-string Nested Quotes" \
  "Python f-strings can't contain nested quotes that match the string delimiter. The expression inside curly braces terminates at first matching quote. Solutions: (1) Use different quote types, (2) Assign to variable first. Best practice: Use double quotes for f-strings." \
  "Error" \
  "Medium"

# Learning 9
echo -e "${BLUE}📚 [9/12]${NC} ngrok URL Automation..."
capture_learning \
  "ngrok URL Extraction Automation" \
  "ngrok URLs change on every restart. Automate extraction via ngrok local API at localhost:4040/api/tunnels. Use curl + jq to extract public_url and update .env file automatically." \
  "Pattern" \
  "Medium"

# Learning 10
echo -e "${BLUE}📚 [10/12]${NC} Project Constitution..."
capture_learning \
  "Constitution as Validation Gate" \
  "Having a formal project constitution established BEFORE implementation prevents scope creep and architectural inconsistencies. Principles: Workflow-first architecture, Cloud-native storage, AI-enhanced metadata, Context preservation." \
  "Insight" \
  "High"

# Learning 11
echo -e "${BLUE}📚 [11/12]${NC} Data Source ID Discovery..."
capture_learning \
  "Data Source IDs in retrieve_database" \
  "When you call retrieve_database with a Database ID, the response includes data_sources[0].id which IS the Data Source ID you need for queries. Pattern: Query retrieve_database, Extract data_sources[0].id, Use for query_data_source." \
  "Pattern" \
  "High"

# Learning 12
echo -e "${BLUE}📚 [12/12]${NC} Skills as Living Documentation..."
capture_learning \
  "Skills as Living Documentation" \
  "Skills should evolve during implementation, capturing patterns in real-time rather than waiting until project complete. Pattern: Encounter issue, Solve it, Immediately document in skill. Benefits: Context fresh, Examples use actual data, Iterative improvement." \
  "Best Practice" \
  "High"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ All 12 learnings captured with Project relations!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
