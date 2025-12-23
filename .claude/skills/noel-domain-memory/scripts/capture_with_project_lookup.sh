#!/bin/bash

##############################################################################
# Capture Learning with Automatic Project Lookup
#
# This script looks up the project page ID before capturing, ensuring
# the Project relation is properly set in Notion.
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
    echo -e "${YELLOW}⚠ Project '$project_name' not found, will create without relation${NC}" >&2
    echo ""
  else
    echo -e "${GREEN}✓ Found project ID: $project_id${NC}" >&2
    echo "$project_id"
  fi
}

# Function to capture learning with project lookup
capture_learning() {
  local project_name="$1"
  local title="$2"
  local content="$3"
  local type="$4"
  local confidence="$5"

  # Lookup project ID
  local project_id=$(lookup_project_id "$project_name")

  # Build payload
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
if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <project> <title> <content> [type] [confidence]"
  echo ""
  echo "Example:"
  echo "  $0 \"Noel\" \"Learning Title\" \"Description\" \"Pattern\" \"High\""
  exit 1
fi

capture_learning "$1" "$2" "$3" "${4:-Pattern}" "${5:-Medium}"
