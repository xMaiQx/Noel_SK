#!/bin/bash

##############################################################################
# Noel Knowledge Repository - Helper Functions for Claude Code Integration
#
# Installation:
#   1. Copy this file to: ~/.config/claude-code/noel-helpers.sh
#   2. Add to your shell profile (~/.bashrc or ~/.zshrc):
#      source ~/.config/claude-code/noel-helpers.sh
#   3. Set NOEL_WEBHOOK_URL environment variable
#
# Usage:
#   noel-capture "ProjectName" "Title" "Content"
#   noel-query "search query"
#   noel-start-session "ProjectName" "Session goals"
#   noel-end-session
##############################################################################

# Environment variables (customize these)
export NOEL_WEBHOOK_URL="${NOEL_WEBHOOK_URL:-}"
export CURRENT_SESSION_ID="${CURRENT_SESSION_ID:-}"
export NOEL_RECORDING_PATH="${NOEL_RECORDING_PATH:-}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

##############################################################################
# Helper function: Check if webhook URL is configured
##############################################################################
function _noel_check_config() {
  if [ -z "$NOEL_WEBHOOK_URL" ]; then
    echo -e "${RED}Error: NOEL_WEBHOOK_URL environment variable not set${NC}"
    echo "Set it with: export NOEL_WEBHOOK_URL='https://your-ngrok-url.ngrok.io/webhook'"
    return 1
  fi
  return 0
}

##############################################################################
# Function: Capture learning
#
# Usage: noel-capture "ProjectName" "Title" "Content" [type] [confidence]
##############################################################################
function noel-capture() {
  if ! _noel_check_config; then
    return 1
  fi

  local project="${1}"
  local title="${2}"
  local content="${3}"
  local type="${4:-}"
  local confidence="${5:-}"

  if [ -z "$project" ] || [ -z "$title" ] || [ -z "$content" ]; then
    echo -e "${RED}Usage: noel-capture <project> <title> <content> [type] [confidence]${NC}"
    return 1
  fi

  # Build JSON payload
  local payload=$(jq -n \
    --arg project "$project" \
    --arg title "$title" \
    --arg content "$content" \
    --arg session_id "$CURRENT_SESSION_ID" \
    --arg type "$type" \
    --arg confidence "$confidence" \
    '{
      project: $project,
      title: $title,
      content: $content,
      session_id: (if $session_id != "" then $session_id else null end),
      type: (if $type != "" then $type else null end),
      confidence: (if $confidence != "" then $confidence else null end)
    } | with_entries(select(.value != null))')

  echo -e "${BLUE}Capturing learning...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL/capture_learning" \
    -H 'Content-Type: application/json' \
    -d "$payload")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local learning_id=$(echo "$response" | jq -r '.learning_id // "unknown"')
    echo -e "${GREEN}✓ Learning captured: $learning_id${NC}"
    echo "$response" | jq '.'
  else
    echo -e "${RED}✗ Failed to capture learning${NC}"
    echo "$response" | jq '.'
    return 1
  fi
}

##############################################################################
# Function: Update learning
#
# Usage: noel-update <learning_id> [--title "New Title"] [--content "New Content"] [--status "Validated"]
##############################################################################
function noel-update() {
  if ! _noel_check_config; then
    return 1
  fi

  local learning_id="${1}"
  shift

  if [ -z "$learning_id" ]; then
    echo -e "${RED}Usage: noel-update <learning_id> [--title \"...\"] [--content \"...\"] [--status \"...\"]${NC}"
    return 1
  fi

  # Parse optional arguments
  local title="" content="" status="" ai_accepted=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title)
        title="$2"
        shift 2
        ;;
      --content)
        content="$2"
        shift 2
        ;;
      --status)
        status="$2"
        shift 2
        ;;
      --ai-accepted)
        ai_accepted="$2"
        shift 2
        ;;
      *)
        echo -e "${RED}Unknown option: $1${NC}"
        return 1
        ;;
    esac
  done

  # Build JSON payload
  local payload=$(jq -n \
    --arg learning_id "$learning_id" \
    --arg title "$title" \
    --arg content "$content" \
    --arg status "$status" \
    --arg ai_accepted "$ai_accepted" \
    '{
      learning_id: $learning_id,
      title: (if $title != "" then $title else null end),
      content: (if $content != "" then $content else null end),
      status: (if $status != "" then $status else null end),
      ai_accepted: (if $ai_accepted != "" then ($ai_accepted | ascii_downcase == "true") else null end)
    } | with_entries(select(.value != null))')

  echo -e "${BLUE}Updating learning...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL/update_learning" \
    -H 'Content-Type: application/json' \
    -d "$payload")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    echo -e "${GREEN}✓ Learning updated successfully${NC}"
    echo "$response" | jq '.'
  else
    echo -e "${RED}✗ Failed to update learning${NC}"
    echo "$response" | jq '.'
    return 1
  fi
}

##############################################################################
# Function: Query learnings
#
# Usage: noel-query "search query" [project_filter]
##############################################################################
function noel-query() {
  if ! _noel_check_config; then
    return 1
  fi

  local query="${1}"
  local project_filter="${2:-}"

  if [ -z "$query" ]; then
    echo -e "${RED}Usage: noel-query <query> [project_filter]${NC}"
    return 1
  fi

  # Build JSON payload
  local payload=$(jq -n \
    --arg query "$query" \
    --arg project "$project_filter" \
    '{
      query: $query,
      filters: (if $project != "" then {project: $project} else {} end)
    }')

  echo -e "${BLUE}Querying learnings...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL/query_learnings" \
    -H 'Content-Type: application/json' \
    -d "$payload")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local count=$(echo "$response" | jq -r '.count // 0')
    echo -e "${GREEN}✓ Found $count results${NC}\n"
    echo "$response" | jq '.results[] | {learning_id, title, similarity_score, project}'
  else
    echo -e "${RED}✗ Query failed${NC}"
    echo "$response" | jq '.'
    return 1
  fi
}

##############################################################################
# Function: Submit query feedback
#
# Usage: noel-feedback "query text" "LEARNING-ID-1,LEARNING-ID-2"
##############################################################################
function noel-feedback() {
  if ! _noel_check_config; then
    return 1
  fi

  local query_text="${1}"
  local learning_ids="${2}"

  if [ -z "$query_text" ] || [ -z "$learning_ids" ]; then
    echo -e "${RED}Usage: noel-feedback \"query text\" \"LEARNING-ID-1,LEARNING-ID-2\"${NC}"
    return 1
  fi

  # Convert comma-separated string to JSON array
  local ids_array=$(echo "$learning_ids" | jq -R 'split(",")'| jq 'map(gsub("^\\s+|\\s+$";""))')

  local payload=$(jq -n \
    --arg query "$query_text" \
    --argjson ids "$ids_array" \
    '{
      query_text: $query,
      relevant_learning_ids: $ids
    }')

  echo -e "${BLUE}Submitting feedback...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL/query_feedback" \
    -H 'Content-Type: application/json' \
    -d "$payload")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    echo -e "${GREEN}✓ Feedback submitted${NC}"
  else
    echo -e "${RED}✗ Failed to submit feedback${NC}"
    echo "$response" | jq '.'
    return 1
  fi
}

##############################################################################
# Function: List projects
#
# Usage: noel-projects [status_filter]
##############################################################################
function noel-projects() {
  if ! _noel_check_config; then
    return 1
  fi

  local status_filter="${1:-}"

  local payload=$(jq -n \
    --arg status "$status_filter" \
    '{
      filters: (if $status != "" then {status: $status} else {} end)
    }')

  echo -e "${BLUE}Listing projects...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL/list_projects" \
    -H 'Content-Type: application/json' \
    -d "$payload")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    echo -e "${GREEN}✓ Projects retrieved${NC}\n"
    echo "$response" | jq '.projects[] | {name, status, priority, learning_count, session_count}'
  else
    echo -e "${RED}✗ Failed to list projects${NC}"
    echo "$response" | jq '.'
    return 1
  fi
}

##############################################################################
# Function: Start session with recording
#
# Usage: noel-start-session "ProjectName" "Session goals"
##############################################################################
function noel-start-session() {
  if ! _noel_check_config; then
    return 1
  fi

  local project="${1}"
  local goals="${2}"

  if [ -z "$project" ] || [ -z "$goals" ]; then
    echo -e "${RED}Usage: noel-start-session <project> <goals>${NC}"
    return 1
  fi

  # Check if asciinema is installed
  if ! command -v asciinema &> /dev/null; then
    echo -e "${YELLOW}Warning: asciinema not installed. Session will start without recording.${NC}"
    echo "Install with: brew install asciinema (macOS) or apt install asciinema (Linux)"
  fi

  # Generate recording path
  local timestamp=$(date +%Y-%m-%d-%H%M%S)
  local recording_dir="$HOME/coding-sessions"
  mkdir -p "$recording_dir"
  local recording_path="${recording_dir}/${timestamp}-claude-${project}.cast"

  # Create session via API
  local payload=$(jq -n \
    --arg project "$project" \
    --arg goals "$goals" \
    --arg recording_path "$recording_path" \
    '{
      projects: [$project],
      goals: $goals,
      recording_file_path: $recording_path,
      ai_type: "Claude"
    }')

  echo -e "${BLUE}Creating session...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL/create_session" \
    -H 'Content-Type: application/json' \
    -d "$payload")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    export CURRENT_SESSION_ID=$(echo "$response" | jq -r '.session_id')
    export NOEL_RECORDING_PATH="$recording_path"

    echo -e "${GREEN}✓ Session started: $CURRENT_SESSION_ID${NC}"
    echo -e "${BLUE}Recording to: $recording_path${NC}"
    echo -e "\n${YELLOW}Starting asciinema recording...${NC}"
    echo -e "${YELLOW}Press Ctrl+D or type 'exit' to end the recording and session${NC}\n"

    # Start asciinema recording (this will block until recording ends)
    if command -v asciinema &> /dev/null; then
      asciinema rec "$recording_path"

      # When recording ends, automatically end the session
      echo -e "\n${BLUE}Recording ended. Ending session...${NC}"
      noel-end-session
    else
      echo -e "${YELLOW}Asciinema not available. Remember to run 'noel-end-session' when done.${NC}"
    fi
  else
    echo -e "${RED}✗ Failed to create session${NC}"
    echo "$response" | jq '.'
    return 1
  fi
}

##############################################################################
# Function: End current session
#
# Usage: noel-end-session
##############################################################################
function noel-end-session() {
  if ! _noel_check_config; then
    return 1
  fi

  if [ -z "$CURRENT_SESSION_ID" ]; then
    echo -e "${RED}No active session${NC}"
    return 1
  fi

  local payload=$(jq -n \
    --arg session_id "$CURRENT_SESSION_ID" \
    '{
      session_id: $session_id
    }')

  echo -e "${BLUE}Ending session...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL/end_session" \
    -H 'Content-Type: application/json' \
    -d "$payload")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local duration=$(echo "$response" | jq -r '.duration_minutes // 0')
    local learning_count=$(echo "$response" | jq -r '.learning_count // 0')

    echo -e "${GREEN}✓ Session ended: $CURRENT_SESSION_ID${NC}"
    echo -e "${GREEN}  Duration: $duration minutes${NC}"
    echo -e "${GREEN}  Learnings captured: $learning_count${NC}"

    if [ -n "$NOEL_RECORDING_PATH" ]; then
      echo -e "${BLUE}  Recording saved: $NOEL_RECORDING_PATH${NC}"
      echo -e "${YELLOW}  Replay with: asciinema play $NOEL_RECORDING_PATH${NC}"
    fi

    unset CURRENT_SESSION_ID
    unset NOEL_RECORDING_PATH
  else
    echo -e "${RED}✗ Failed to end session${NC}"
    echo "$response" | jq '.'
    return 1
  fi
}

##############################################################################
# Function: Query sessions
#
# Usage: noel-sessions [project_filter]
##############################################################################
function noel-sessions() {
  if ! _noel_check_config; then
    return 1
  fi

  local project_filter="${1:-}"

  local payload=$(jq -n \
    --arg project "$project_filter" \
    '{
      filters: (if $project != "" then {project: $project} else {} end)
    }')

  echo -e "${BLUE}Querying sessions...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL/query_sessions" \
    -H 'Content-Type: application/json' \
    -d "$payload")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local count=$(echo "$response" | jq -r '.count // 0')
    echo -e "${GREEN}✓ Found $count sessions${NC}\n"
    echo "$response" | jq '.sessions[] | {session_id, status, duration_minutes, learning_count, recording_file_path}'
  else
    echo -e "${RED}✗ Query failed${NC}"
    echo "$response" | jq '.'
    return 1
  fi
}

##############################################################################
# Function: Display help
##############################################################################
function noel-help() {
  cat <<EOF
${GREEN}Noel Knowledge Repository - Helper Commands${NC}

${BLUE}Session Management:${NC}
  noel-start-session <project> <goals>   Start a new session with recording
  noel-end-session                        End current session
  noel-sessions [project]                 Query sessions

${BLUE}Learning Management:${NC}
  noel-capture <project> <title> <content> [type] [confidence]
                                          Capture a new learning
  noel-update <learning_id> [--title "..."] [--content "..."] [--status "..."]
                                          Update existing learning
  noel-query <query> [project]            Search learnings
  noel-feedback <query> <learning-ids>    Submit query relevance feedback

${BLUE}Project Management:${NC}
  noel-projects [status]                  List all projects

${BLUE}Configuration:${NC}
  export NOEL_WEBHOOK_URL="https://your-ngrok-url.ngrok.io/webhook"

${BLUE}Current Session:${NC}
  Session ID: ${CURRENT_SESSION_ID:-"(none)"}
  Recording:  ${NOEL_RECORDING_PATH:-"(none)"}

${YELLOW}Examples:${NC}
  noel-start-session "Noel" "Implementing session tracking"
  noel-capture "Noel" "Session tracking pattern" "Use webhook callbacks for session lifecycle"
  noel-query "session tracking"
  noel-end-session

For more details, see: specs/001-knowledge-repository/quickstart.md
EOF
}

# Display help if no webhook URL is configured
if [ -z "$NOEL_WEBHOOK_URL" ]; then
  echo -e "${YELLOW}Noel helper functions loaded, but NOEL_WEBHOOK_URL not set.${NC}"
  echo -e "Set it with: ${BLUE}export NOEL_WEBHOOK_URL='https://your-ngrok-url.ngrok.io/webhook'${NC}"
fi
