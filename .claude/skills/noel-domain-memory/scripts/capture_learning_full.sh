#!/bin/bash

##############################################################################
# Capture Learning with ALL Fields Support
#
# This version supports all Notion Learnings database fields including
# context, dev_stream, tags, related_files, and session_id.
##############################################################################

WEBHOOK_URL="https://18f625ebc1f0.ngrok-free.app/webhook/noel"
AUTH_TOKEN="1b3b9c7a-2f3e-41e9-bb29-d9ad58f7c1d6"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to lookup project page ID by name
lookup_project_id() {
  local project_name="$1"

  echo -e "${BLUE}Looking up project: $project_name${NC}" >&2

  local response=$(curl -s --location "$WEBHOOK_URL" \
    --header 'Content-Type: application/json' \
    --header "Authorization: $AUTH_TOKEN" \
    --data "{
      \"endpoint\": \"list_projects\",
      \"limit\": 100
    }")

  # Extract page_id for matching project name
  local project_id=$(echo "$response" | jq -r --arg name "$project_name" '
    .[0].data.results[]
    | select(.properties.Name.title[0].text.content == $name)
    | .id
  ' 2>/dev/null)

  if [ -z "$project_id" ] || [ "$project_id" = "null" ]; then
    echo -e "${YELLOW}⚠ Project '$project_name' not found${NC}" >&2
    echo ""
  else
    echo -e "${GREEN}✓ Found project ID: $project_id${NC}" >&2
    echo "$project_id"
  fi
}

# Function to capture learning with ALL fields
capture_learning_full() {
  local project_name="$1"
  local title="$2"
  local content="$3"
  local type="$4"              # Pattern, Solution, Error, Decision, Insight, Anti-Pattern, Best Practice
  local confidence="$5"        # High, Medium, Low
  local context="${6:-}"       # OPTIONAL: How the learning was discovered
  local dev_stream="${7:-}"    # OPTIONAL: Comma-separated list (e.g. "n8n,API,Database")
  local tags="${8:-}"          # OPTIONAL: Comma-separated list (e.g. "webhook,validation,error-handling")
  local related_files="${9:-}" # OPTIONAL: File paths (e.g. "src/api/endpoint.ts:42")
  local session_id="${10:-}"   # OPTIONAL: Session page ID (not session ID string)

  # Lookup project ID
  local project_id=$(lookup_project_id "$project_name")

  # Build base payload
  local payload=$(cat <<EOF
{
  "endpoint": "capture_learning",
  "project": "$project_name",
  "title": "$title",
  "content": "$content",
  "type": "$type",
  "confidence": "$confidence"
EOF
)

  # Add project_id if found
  if [ -n "$project_id" ] && [ "$project_id" != "null" ]; then
    payload="$payload,
  \"project_id\": \"$project_id\""
  fi

  # Add context if provided
  if [ -n "$context" ]; then
    # Escape quotes in context
    local escaped_context=$(echo "$context" | sed 's/"/\\"/g')
    payload="$payload,
  \"context\": \"$escaped_context\""
  fi

  # Add dev_stream if provided (convert comma-separated to JSON array)
  if [ -n "$dev_stream" ]; then
    local dev_stream_json=$(echo "$dev_stream" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$";""))')
    payload="$payload,
  \"dev_stream\": $dev_stream_json"
  fi

  # Add tags if provided (convert comma-separated to JSON array)
  if [ -n "$tags" ]; then
    local tags_json=$(echo "$tags" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$";""))')
    payload="$payload,
  \"tags\": $tags_json"
  fi

  # Add related_files if provided
  if [ -n "$related_files" ]; then
    local escaped_files=$(echo "$related_files" | sed 's/"/\\"/g')
    payload="$payload,
  \"related_files\": \"$escaped_files\""
  fi

  # Add session_id if provided (must be Notion page ID, not session ID string)
  if [ -n "$session_id" ]; then
    payload="$payload,
  \"session_id\": \"$session_id\""
  fi

  # Close JSON
  payload="$payload
}"

  # Send capture request
  local response=$(curl -s --location "$WEBHOOK_URL" \
    --header 'Content-Type: application/json' \
    --header "Authorization: $AUTH_TOKEN" \
    --data "$payload")

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

# Main execution
if [ "$#" -lt 5 ]; then
  cat <<USAGE
Usage: $0 <project> <title> <content> <type> <confidence> [context] [dev_stream] [tags] [related_files] [session_id]

Required Arguments:
  project       Project name (e.g. "Noel")
  title         Learning title
  content       Full learning description
  type          Pattern|Solution|Error|Decision|Insight|Anti-Pattern|Best Practice
  confidence    High|Medium|Low

Optional Arguments:
  context       How the learning was discovered
  dev_stream    Comma-separated domains (e.g. "n8n,API,Database")
  tags          Comma-separated keywords (e.g. "webhook,validation")
  related_files File paths (e.g. "src/api.ts:42, workflows/main.json")
  session_id    Session Notion page ID (not session ID string)

Examples:

  # Minimal (only required fields)
  $0 "Noel" "Learning Title" "Description here" "Pattern" "High"

  # With context
  $0 "Noel" "Learning Title" "Description" "Solution" "High" \\
     "Discovered while debugging vector search"

  # With dev_stream and tags
  $0 "Noel" "n8n Webhook Pattern" "Always validate input" "Pattern" "High" \\
     "Found during endpoint testing" \\
     "n8n,API,Backend" \\
     "webhooks,validation,security"

  # Full example with all fields
  $0 "Noel" "Vector Search Fix" "Fixed empty results by..." "Solution" "High" \\
     "Debugged RPC function in Supabase" \\
     "Database,API" \\
     "pgvector,supabase,sql" \\
     "scripts/supabase/match_learnings.sql:15-42" \\
     "SESSION-20251220-001-page-id"

USAGE
  exit 1
fi

capture_learning_full "$1" "$2" "$3" "$4" "$5" "${6:-}" "${7:-}" "${8:-}" "${9:-}" "${10:-}"
