#!/bin/bash

##############################################################################
# Capture 12 Learnings from SESSION_LEARNINGS.md to Noel
# Uses Pattern 2: Single webhook URL with "endpoint" routing in body
##############################################################################

# Configuration (update these if needed)
WEBHOOK_URL="https://18f625ebc1f0.ngrok-free.app/webhook/noel"
AUTH_TOKEN="1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "Capturing 12 learnings from SESSION_LEARNINGS.md..."
echo "Webhook: $WEBHOOK_URL"
echo ""

# Function to capture learning using Pattern 2
capture_learning() {
  local title="$1"
  local content="$2"
  local type="$3"
  local confidence="$4"

  local payload=$(cat <<EOF
{
  "endpoint": "capture_learning",
  "project": "Noel",
  "title": "$title",
  "content": "$content",
  "type": "$type",
  "confidence": "$confidence"
}
EOF
)

  local response=$(curl -s --location "$WEBHOOK_URL" \
    --header 'Content-Type: application/json' \
    --header "Authorization: $AUTH_TOKEN" \
    --data "$payload")

  local success=$(echo "$response" | jq -r '.success // false' 2>/dev/null)

  if [ "$success" = "true" ]; then
    local learning_id=$(echo "$response" | jq -r '.learning_id // "unknown"' 2>/dev/null)
    echo -e "${GREEN}✓${NC} Captured: $learning_id"
    return 0
  else
    echo -e "${RED}✗${NC} Failed"
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
    return 1
  fi
}

# Learning 1: Notion Two ID Types
echo -e "${BLUE}📚 [1/12]${NC} Notion API Two ID Types..."
capture_learning \
  "Notion API Two ID Types - Critical Pattern" \
  "Notion databases have TWO different IDs: (1) Database ID for schema operations (retrieve_database), (2) Data Source ID for querying records (query_data_source). These are NOT interchangeable! Using wrong ID returns empty results. Get Database ID from Notion URL, get Data Source ID from data_sources[0].id in retrieve_database response." \
  "Pattern" \
  "High"
echo ""

# Learning 2: Bash Piping Gotcha
echo -e "${BLUE}📚 [2/12]${NC} Bash Piping to Python..."
capture_learning \
  "Bash Piping curl to Python - Variable Expansion Gotcha" \
  "When piping curl output to python3 -c, shell variable expansion inside heredocs causes syntax errors. curl progress bar mixes with JSON, breaking Python parsing. Solutions: (1) Suppress stderr with 2>/dev/null, (2) Use file intermediary, (3) Quote heredoc delimiter << 'EOF' to prevent variable expansion." \
  "Error" \
  "High"
echo ""

# Learning 3: Path Resolution
echo -e "${BLUE}📚 [3/12]${NC} Bash Path Resolution..."
capture_learning \
  "Environment Variable Path Resolution in Sourced Scripts" \
  "When sourcing bash scripts, \${BASH_SOURCE[0]} may be empty if script is sourced vs executed directly. This breaks relative path resolution. Use fallback: if [ -n \"\${BASH_SOURCE[0]}\" ]; then use it; else use \$0; fi. Try multiple locations for .env file." \
  "Error" \
  "High"
echo ""

# Learning 4: Trailing Spaces
echo -e "${BLUE}📚 [4/12]${NC} Property Name Trailing Spaces..."
capture_learning \
  "Notion Property Names with Trailing Spaces Break Validation" \
  "Notion property names with trailing spaces cause silent failures in automated verification. Visual inspection doesn't catch them - only automated comparison reveals the issue. Example: 'AI Suggested ' (with space) vs 'AI Suggested' (correct). Prevention: Always use automated verification, trim property names in Notion." \
  "Anti-Pattern" \
  "High"
echo ""

# Learning 5: Singular vs Plural
echo -e "${BLUE}📚 [5/12]${NC} Relation Naming Conventions..."
capture_learning \
  "Singular vs Plural Relation Naming - Semantic Consistency" \
  "Relation property names should reflect cardinality: Singular for many-to-one (e.g., Learnings.Session - one learning has one session), Plural for one-to-many or many-to-many (e.g., Sessions.Learnings - one session has many learnings). This improves code readability and API consistency." \
  "Pattern" \
  "High"
echo ""

# Learning 6: Automation
echo -e "${BLUE}📚 [6/12]${NC} Automated Verification..."
capture_learning \
  "Automated Verification Always Beats Manual Checklists" \
  "Manual checklists fail to catch: trailing spaces in property names, plural/singular naming mistakes, missing properties, type mismatches. Automated verification catches ALL discrepancies instantly with 100% accuracy. ROI: 15-30 min manual to 5 sec automated. Pattern: Query database via API, compare actual vs expected properties, report exact discrepancies." \
  "Insight" \
  "High"
echo ""

# Learning 7: Reverse Relations
echo -e "${BLUE}📚 [7/12]${NC} Notion Reverse Relations..."
capture_learning \
  "Notion Reverse Relations Auto-Generate - Expected Behavior" \
  "When creating a relation in Notion (e.g., Learnings.Project to Projects), Notion automatically creates a reverse relation in the target database (Projects.Learnings). These reverse relations appear as 'extra' fields when comparing against spec but are expected and correct. Don't flag as validation errors." \
  "Pattern" \
  "High"
echo ""

# Learning 8: f-string Syntax
echo -e "${BLUE}📚 [8/12]${NC} Python f-string Nested Quotes..."
capture_learning \
  "Python f-string Syntax - Nested Quotes Require Special Handling" \
  "Python f-strings can't contain nested quotes that match the string delimiter. The expression inside {} terminates at first matching quote. Solutions: (1) Use different quote types (double quotes outside, single inside), (2) Assign to variable first, (3) Escaping doesn't work in f-strings. Best practice: Always use double quotes for f-strings containing string operations." \
  "Error" \
  "Medium"
echo ""

# Learning 9: ngrok Automation
echo -e "${BLUE}📚 [9/12]${NC} ngrok URL Automation..."
capture_learning \
  "ngrok URL Extraction - Automated Environment Updates" \
  "ngrok URLs change on every restart. Automate extraction via ngrok's local API at localhost:4040/api/tunnels. Use curl + jq to extract public_url and update .env file automatically. Pattern: curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url'. Update .env with sed and reload environment." \
  "Pattern" \
  "Medium"
echo ""

# Learning 10: Constitution
echo -e "${BLUE}📚 [10/12]${NC} Project Constitution as Validation..."
capture_learning \
  "Constitution as Non-Negotiable Validation Gate" \
  "Having a formal project constitution established BEFORE implementation prevents scope creep and architectural inconsistencies. Principles validated: Workflow-first architecture (everything via n8n), Cloud-native storage (Notion/Supabase), AI-enhanced metadata, Context preservation (sessions, recordings). Pattern: Write constitution then Run /speckit.analyze then Flag violations as CRITICAL." \
  "Insight" \
  "High"
echo ""

# Learning 11: Data Source IDs
echo -e "${BLUE}📚 [11/12]${NC} Data Source ID Discovery..."
capture_learning \
  "Data Source IDs Hidden in retrieve_database Response" \
  "When you call retrieve_database with a Database ID, the response includes data_sources[0].id which IS the Data Source ID you need for queries. No manual ID hunting needed. Pattern: Query retrieve_database, Extract data_sources[0].id, Use for query_data_source. Enables automated environment setup with single Database ID as input." \
  "Pattern" \
  "High"
echo ""

# Learning 12: Living Documentation
echo -e "${BLUE}📚 [12/12]${NC} Skills as Living Documentation..."
capture_learning \
  "Skills as Living Documentation - Update During Implementation" \
  "Skills should evolve during implementation, capturing discovered patterns and solutions in real-time rather than waiting until project complete. Pattern: Encounter issue, Solve it, Immediately document in skill. Benefits: (1) Context fresh in working memory, (2) Examples use actual IDs/errors/solutions, (3) Iterative improvement, (4) Next developer has exact solutions. Update skill references/ directory as patterns emerge." \
  "Best Practice" \
  "High"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Batch capture complete!${NC}"
echo ""
echo -e "To verify, query Noel:"
echo -e "  ${YELLOW}curl --location '$WEBHOOK_URL' \\${NC}"
echo -e "  ${YELLOW}--header 'Content-Type: application/json' \\${NC}"
echo -e "  ${YELLOW}--header 'Authorization: $AUTH_TOKEN' \\${NC}"
echo -e "  ${YELLOW}--data '{\"endpoint\": \"query_learnings\", \"query\": \"Notion API patterns\", \"filters\": {\"project\": \"Noel\"}}' | jq '.'${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
