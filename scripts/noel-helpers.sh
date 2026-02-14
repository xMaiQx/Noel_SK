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
export NOEL_AUTH_TOKEN="${NOEL_AUTH_TOKEN:-${NOEL_AUTH:-}}"
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
# Usage: noel-capture "ProjectName" "Title" "Content" [type] [confidence] [--scope Universal] [--discipline "Backend,API"] [--applies-to "context"]
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
  shift 5 2>/dev/null || shift $#

  if [ -z "$project" ] || [ -z "$title" ] || [ -z "$content" ]; then
    echo -e "${RED}Usage: noel-capture <project> <title> <content> [type] [confidence] [--scope X] [--discipline Y] [--applies-to Z]${NC}"
    return 1
  fi

  # Parse optional multi-project metadata arguments
  local scope="" discipline="" applies_to="" conflicts_with=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scope)
        scope="$2"
        shift 2
        ;;
      --discipline)
        discipline="$2"
        shift 2
        ;;
      --applies-to)
        applies_to="$2"
        shift 2
        ;;
      --conflicts-with)
        conflicts_with="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  # Build JSON payload
  local payload=$(jq -n \
    --arg project "$project" \
    --arg title "$title" \
    --arg content "$content" \
    --arg session_id "$CURRENT_SESSION_ID" \
    --arg type "$type" \
    --arg confidence "$confidence" \
    --arg scope "$scope" \
    --arg discipline "$discipline" \
    --arg applies_to "$applies_to" \
    --arg conflicts_with "$conflicts_with" \
    --arg source_channel "${NOEL_SOURCE_CHANNEL:-claude-code}" \
    '{
      endpoint: "capture_learning",
      project: $project,
      title: $title,
      content: $content,
      source_channel: $source_channel,
      session_id: (if $session_id != "" then $session_id else null end),
      type: (if $type != "" then $type else null end),
      confidence: (if $confidence != "" then $confidence else null end),
      scope: (if $scope != "" then $scope else null end),
      discipline: (if $discipline != "" then ($discipline | split(",") | map(gsub("^\\s+|\\s+$";""))) else null end),
      applies_to: (if $applies_to != "" then $applies_to else null end),
      conflicts_with: (if $conflicts_with != "" then ($conflicts_with | split(",") | map(gsub("^\\s+|\\s+$";""))) else null end)
    } | with_entries(select(.value != null))')

  echo -e "${BLUE}Capturing learning...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -d "$payload")

  local success=$(echo "$response" | jq -r '.[0].success // false')

  if [ "$success" = "true" ]; then
    local learning_id=$(echo "$response" | jq -r '.[0].learning_id // "unknown"')
    echo -e "${GREEN}✓ Learning captured: $learning_id${NC}"
    echo "$response" | jq '.[0]'
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
  local title="" content="" status="" ai_accepted="" scope="" discipline="" applies_to="" conflicts_with=""

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
      --scope)
        scope="$2"
        shift 2
        ;;
      --discipline)
        discipline="$2"
        shift 2
        ;;
      --applies-to)
        applies_to="$2"
        shift 2
        ;;
      --conflicts-with)
        conflicts_with="$2"
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
    --arg scope "$scope" \
    --arg discipline "$discipline" \
    --arg applies_to "$applies_to" \
    --arg conflicts_with "$conflicts_with" \
    '{
      endpoint: "update_learning",
      learning_id: $learning_id,
      title: (if $title != "" then $title else null end),
      content: (if $content != "" then $content else null end),
      status: (if $status != "" then $status else null end),
      ai_accepted: (if $ai_accepted != "" then ($ai_accepted | ascii_downcase == "true") else null end),
      scope: (if $scope != "" then $scope else null end),
      discipline: (if $discipline != "" then ($discipline | split(",") | map(gsub("^\\s+|\\s+$";""))) else null end),
      applies_to: (if $applies_to != "" then $applies_to else null end),
      conflicts_with: (if $conflicts_with != "" then ($conflicts_with | split(",") | map(gsub("^\\s+|\\s+$";""))) else null end)
    } | with_entries(select(.value != null))')

  echo -e "${BLUE}Updating learning...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
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
      endpoint: "query_learnings",
      query: $query,
      filters: (if $project != "" then {project: $project} else {} end)
    }')

  echo -e "${BLUE}Querying learnings...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
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
      endpoint: "query_feedback",
      query_text: $query,
      relevant_learning_ids: $ids
    }')

  echo -e "${BLUE}Submitting feedback...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
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
      endpoint: "list_projects",
      filters: (if $status != "" then {status: $status} else {} end)
    }')

  echo -e "${BLUE}Listing projects...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
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
# Function: Register project (MANDATORY before capturing learnings)
#
# Usage: noel-register-project [project_name] [--description "..."] [--priority "..."] [--tech-stack "..."] [--repo-url "..."]
##############################################################################
function noel-register-project() {
  if ! _noel_check_config; then
    return 1
  fi

  # Auto-detect project if not provided
  local project_name="${1:-}"
  if [ -z "$project_name" ]; then
    project_name=$(basename $(git rev-parse --show-toplevel 2>/dev/null) || basename "$PWD")
  fi
  shift 2>/dev/null || shift $# 2>/dev/null

  # Parse optional arguments
  local description="" priority="" tech_stack="" repo_url="" status=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --description)
        description="$2"
        shift 2
        ;;
      --priority)
        priority="$2"
        shift 2
        ;;
      --tech-stack)
        tech_stack="$2"
        shift 2
        ;;
      --repo-url)
        repo_url="$2"
        shift 2
        ;;
      --status)
        status="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  # Build JSON payload
  local payload=$(jq -n \
    --arg name "$project_name" \
    --arg description "$description" \
    --arg priority "$priority" \
    --arg tech_stack "$tech_stack" \
    --arg repo_url "$repo_url" \
    --arg status "$status" \
    '{
      endpoint: "create_project",
      name: $name,
      description: (if $description != "" then $description else null end),
      priority: (if $priority != "" then $priority else null end),
      tech_stack: (if $tech_stack != "" then ($tech_stack | split(",") | map(gsub("^\\s+|\\s+$";""))) else null end),
      repository_url: (if $repo_url != "" then $repo_url else null end),
      status: (if $status != "" then $status else null end)
    } | with_entries(select(.value != null))')

  echo -e "${BLUE}Registering project: $project_name...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -d "$payload")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local message=$(echo "$response" | jq -r '.message // "Project registered"')
    echo -e "${GREEN}✓ $message${NC}"

    # Check if this was a new registration or already existed
    if echo "$message" | grep -q "already exists"; then
      echo -e "${YELLOW}  → Project was already registered (idempotent operation)${NC}"
    else
      echo -e "${GREEN}  → New project created in Notion Projects database${NC}"
    fi
  else
    echo -e "${RED}✗ Failed to register project${NC}"
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
  shift 2 2>/dev/null || shift $#

  # Parse optional --no-record flag
  local no_record=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-record)
        no_record=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  if [ -z "$project" ] || [ -z "$goals" ]; then
    echo -e "${RED}Usage: noel-start-session <project> <goals> [--no-record]${NC}"
    return 1
  fi

  # Check if asciinema is installed (only if recording is enabled)
  if [ "$no_record" = false ] && ! command -v asciinema &> /dev/null; then
    echo -e "${YELLOW}Warning: asciinema not installed. Session will start without recording.${NC}"
    echo "Install with: brew install asciinema (macOS) or apt install asciinema (Linux)"
    no_record=true
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
      endpoint: "create_session",
      projects: [$project],
      goals: $goals,
      recording_file_path: $recording_path,
      ai_type: "Claude"
    }')

  echo -e "${BLUE}Creating session...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -d "$payload")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    export CURRENT_SESSION_ID=$(echo "$response" | jq -r '.session_id')
    export NOEL_RECORDING_PATH="$recording_path"

    echo -e "${GREEN}✓ Session started: $CURRENT_SESSION_ID${NC}"

    if [ "$no_record" = false ]; then
      # Recording ENABLED - export flag for hook wink detection
      export ASCIINEMA_REC=1
      echo -e "${BLUE}Recording to: $recording_path${NC}"
      echo -e "\n${YELLOW}Starting asciinema recording...${NC}"
      echo -e "${YELLOW}Press Ctrl+D or type 'exit' to end the recording and session${NC}\n"

      # Start asciinema recording (this will block until recording ends)
      asciinema rec "$recording_path"

      # When recording ends, automatically end the session
      echo -e "\n${BLUE}Recording ended. Ending session...${NC}"
      noel-end-session
      unset ASCIINEMA_REC
    else
      # Recording DISABLED - hook winks will be fully visible
      unset ASCIINEMA_REC
      echo -e "${GREEN}📹 Recording disabled - hook winks will be visible${NC}"
      echo -e "${YELLOW}Remember to run 'noel-end-session' when done.${NC}\n"
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
      endpoint: "end_session",
      session_id: $session_id
    }')

  echo -e "${BLUE}Ending session...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
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
      endpoint: "query_sessions",
      filters: (if $project != "" then {project: $project} else {} end)
    }')

  echo -e "${BLUE}Querying sessions...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
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
# Function: List pending evaluation proposals
#
# Usage: noel-proposals [status]
##############################################################################
function noel-proposals() {
  if ! _noel_check_config; then
    return 1
  fi

  local status="${1:-pending}"

  local payload=$(jq -n \
    --arg status "$status" \
    '{
      endpoint: "list_proposals",
      status: $status
    }')

  echo -e "${BLUE}Listing $status proposals...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -H "Authorization: ${NOEL_AUTH_TOKEN}" \
    -d "$payload")

  # Normalize: n8n may wrap response in array
  local data=$(echo "$response" | jq 'if type == "array" then .[0] else . end')
  local success=$(echo "$data" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local count=$(echo "$data" | jq -r '.count // 0')
    echo -e "${GREEN}✓ Found $count $status proposals${NC}\n"
    echo "$data" | jq -r '(.proposals // [])[] | "  \(.evaluation_id) | \(.category) | \(.target_learning_title)\n    Diagnosis: \(.diagnosis | .[0:120])...\n"'
  else
    echo -e "${RED}✗ Failed to list proposals${NC}"
    echo "$response" | jq '.'
    return 1
  fi
}

##############################################################################
# Function: Approve an evaluation proposal
#
# Usage: noel-approve <evaluation_id> [reason]
##############################################################################
function noel-approve() {
  if ! _noel_check_config; then
    return 1
  fi

  local evaluation_id="${1}"
  local reason="${2:-Approved via CLI}"

  if [ -z "$evaluation_id" ]; then
    echo -e "${RED}Usage: noel-approve <evaluation_id> [reason]${NC}"
    return 1
  fi

  local payload=$(jq -n \
    --arg evaluation_id "$evaluation_id" \
    --arg reason "$reason" \
    '{
      endpoint: "approve_proposal",
      evaluation_id: $evaluation_id,
      reason: $reason
    }')

  echo -e "${BLUE}Approving proposal $evaluation_id...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -H "Authorization: ${NOEL_AUTH_TOKEN}" \
    -d "$payload")

  local data=$(echo "$response" | jq 'if type == "array" then .[0] else . end')
  local success=$(echo "$data" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local learning_updated=$(echo "$data" | jq -r '.learning_updated // false')
    local vector_regenerated=$(echo "$data" | jq -r '.vector_regenerated // false')
    echo -e "${GREEN}✓ Proposal approved${NC}"
    echo -e "  Learning updated: $learning_updated"
    echo -e "  Vector regenerated: $vector_regenerated"
  else
    echo -e "${RED}✗ Failed to approve proposal${NC}"
    echo "$response" | jq '.'
    return 1
  fi
}

##############################################################################
# Function: Reject an evaluation proposal
#
# Usage: noel-reject <evaluation_id> [reason]
##############################################################################
function noel-reject() {
  if ! _noel_check_config; then
    return 1
  fi

  local evaluation_id="${1}"
  local reason="${2:-Rejected via CLI}"

  if [ -z "$evaluation_id" ]; then
    echo -e "${RED}Usage: noel-reject <evaluation_id> [reason]${NC}"
    return 1
  fi

  local payload=$(jq -n \
    --arg evaluation_id "$evaluation_id" \
    --arg reason "$reason" \
    '{
      endpoint: "reject_proposal",
      evaluation_id: $evaluation_id,
      reason: $reason
    }')

  echo -e "${BLUE}Rejecting proposal $evaluation_id...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -H "Authorization: ${NOEL_AUTH_TOKEN}" \
    -d "$payload")

  local data=$(echo "$response" | jq 'if type == "array" then .[0] else . end')
  local success=$(echo "$data" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    echo -e "${GREEN}✓ Proposal rejected${NC}"
    echo -e "  Reason: $reason"
  else
    echo -e "${RED}✗ Failed to reject proposal${NC}"
    echo "$response" | jq '.'
    return 1
  fi
}

##############################################################################
# Function: Trigger an evaluation cycle manually
#
# Usage: noel-evaluate [--scope all] [--min-usage 3] [--threshold 50]
##############################################################################
function noel-evaluate() {
  if ! _noel_check_config; then
    return 1
  fi

  local scope="all" min_usage=3 threshold=50 unproven_age=30

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scope) scope="$2"; shift 2 ;;
      --min-usage) min_usage="$2"; shift 2 ;;
      --threshold) threshold="$2"; shift 2 ;;
      --unproven-age) unproven_age="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local payload=$(jq -n \
    --arg scope "$scope" \
    --argjson min_usage "$min_usage" \
    --argjson threshold "$threshold" \
    --argjson unproven_age "$unproven_age" \
    '{
      endpoint: "run_evaluation",
      scope: $scope,
      min_usage: $min_usage,
      improvement_threshold: $threshold,
      unproven_age_days: $unproven_age
    }')

  echo -e "${BLUE}Triggering evaluation cycle...${NC}"

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -H "Authorization: ${NOEL_AUTH_TOKEN}" \
    -d "$payload")

  local data=$(echo "$response" | jq 'if type == "array" then .[0] else . end')
  local success=$(echo "$data" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local cycle_id=$(echo "$data" | jq -r '.cycle_id // "unknown"')
    local evaluated=$(echo "$data" | jq -r '.learnings_evaluated // 0')
    local proposals=$(echo "$data" | jq -r '.proposals_generated // 0')
    echo -e "${GREEN}✓ Evaluation cycle started: $cycle_id${NC}"
    echo -e "  Learnings evaluated: $evaluated"
    echo -e "  Proposals generated: $proposals"
  else
    echo -e "${RED}✗ Failed to start evaluation${NC}"
    echo "$response" | jq '.'
    return 1
  fi
}

##############################################################################
# Function: Update Noel universal skill with latest learnings
#
# Usage: noel-update-skill
##############################################################################
function noel-update-skill() {
  echo -e "${BLUE}🔄 Updating Noel universal skill with latest learnings...${NC}"
  echo ""

  # Check if skill file exists
  local skill_file="$HOME/.claude/skills/noel-universal/SKILL.md"
  if [ ! -f "$skill_file" ]; then
    echo -e "${RED}✗ Noel universal skill not found at: $skill_file${NC}"
    echo -e "${YELLOW}Create it first with the noel-universal skill template${NC}"
    return 1
  fi

  echo -e "${BLUE}📚 Querying Noel for recent high-confidence learnings...${NC}"

  # Query for recent high-confidence learnings
  local learnings=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: ${NOEL_AUTH_TOKEN}" \
    -d '{"endpoint":"query_learnings","query":"high confidence patterns solutions anti-patterns","filters":{"confidence":"High"},"limit":20}' \
    2>/dev/null)

  if [ $? -ne 0 ] || [ -z "$learnings" ]; then
    echo -e "${RED}✗ Failed to query Noel for learnings${NC}"
    return 1
  fi

  local count=$(echo "$learnings" | jq -r '.[0].count // 0' 2>/dev/null)
  echo -e "${GREEN}✓ Found $count high-confidence learnings${NC}"
  echo ""

  echo -e "${BLUE}📝 Recent learnings to consider for skill update:${NC}"
  echo "$learnings" | jq -r '.[0].results[0:10]? | .[] | "  - \(.metadata.title) (\(.metadata.type), \(.metadata.project))"' 2>/dev/null
  echo ""

  echo -e "${YELLOW}💡 Suggested update process:${NC}"
  echo "  1. Review the learnings above"
  echo "  2. Identify new patterns not yet in the Noel skill"
  echo "  3. Update these sections in $skill_file:"
  echo "     - Technology-Specific Patterns"
  echo "     - Anti-Pattern Prevention"
  echo "     - Query Examples"
  echo "     - Capture Examples"
  echo "  4. Test the updated skill in a new Claude Code session"
  echo ""

  echo -e "${BLUE}📂 Skill file location: $skill_file${NC}"
  echo -e "${BLUE}📊 Skill age: $(( ($(date +%s) - $(stat -f %m "$skill_file" 2>/dev/null || stat -c %Y "$skill_file" 2>/dev/null)) / 86400 )) days${NC}"
  echo ""

  read -p "$(echo -e ${YELLOW}Open skill file for editing? [y/N]: ${NC})" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    ${EDITOR:-vim} "$skill_file"
  fi
}

##############################################################################
# Function: Check Telegram gateway RPC accessibility
#
# Usage: noel-telegram-status
##############################################################################
function noel-telegram-status() {
  if ! _noel_check_config; then
    return 1
  fi

  echo -e "${BLUE}Checking Telegram gateway RPCs...${NC}"

  # Test validate_telegram_chat RPC via Supabase
  local supabase_url="${SUPABASE_URL:-https://sladetzgpogodrqwfamy.supabase.co}"
  local supabase_key="${SUPABASE_ANON_KEY:-}"

  if [ -z "$supabase_key" ]; then
    echo -e "${YELLOW}⚠️  SUPABASE_ANON_KEY not set - testing via Noel webhook instead${NC}"

    # Test via a capture with source_channel=telegram (dry run query)
    local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
      -H 'Content-Type: application/json' \
      -H "Authorization: ${NOEL_AUTH_TOKEN}" \
      -d '{"endpoint":"query_learnings","query":"telegram gateway test","limit":1}')

    if echo "$response" | jq -e '.[0].success == true' >/dev/null 2>&1; then
      echo -e "${GREEN}✓ Noel webhook accessible (Telegram gateway can reach it)${NC}"
    else
      echo -e "${RED}✗ Noel webhook not accessible${NC}"
      return 1
    fi
  else
    local response=$(curl -s "${supabase_url}/rest/v1/rpc/validate_telegram_chat" \
      -H "apikey: ${supabase_key}" \
      -H "Authorization: Bearer ${supabase_key}" \
      -H "Content-Type: application/json" \
      -d '{"p_chat_id":"test"}')

    if echo "$response" | jq -e '.[0].is_authorized == false' >/dev/null 2>&1; then
      echo -e "${GREEN}✓ validate_telegram_chat RPC accessible${NC}"
    else
      echo -e "${RED}✗ validate_telegram_chat RPC failed${NC}"
      echo "$response"
      return 1
    fi
  fi

  echo -e "${GREEN}✓ Telegram gateway infrastructure ready${NC}"
}

##############################################################################
# Function: Simulate a Telegram capture (test source_channel passthrough)
#
# Usage: noel-telegram-test "Title" "Content"
##############################################################################
function noel-telegram-test() {
  if ! _noel_check_config; then
    return 1
  fi

  local title="${1:-Telegram Test Learning}"
  local content="${2:-WHY: Testing Telegram capture pipeline\nWHAT: Verifying source_channel=telegram passes through\nHOW: noel-telegram-test function simulates Telegram bot capture}"

  echo -e "${BLUE}Simulating Telegram capture...${NC}"

  local payload=$(jq -n \
    --arg title "$title" \
    --arg content "$content" \
    '{
      endpoint: "capture_learning",
      project: "Noel_SK",
      title: $title,
      content: $content,
      type: "Solution",
      confidence: "Medium",
      source_channel: "telegram",
      tags: ["telegram-capture", "test"]
    }')

  local response=$(curl -s -X POST "$NOEL_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -H "Authorization: ${NOEL_AUTH_TOKEN}" \
    -d "$payload")

  local success=$(echo "$response" | jq -r '.[0].success // false')

  if [ "$success" = "true" ]; then
    local learning_id=$(echo "$response" | jq -r '.[0].learning_id // "unknown"')
    echo -e "${GREEN}✓ Telegram test capture successful: $learning_id${NC}"
    echo -e "${BLUE}  source_channel: telegram${NC}"
    echo "$response" | jq '.[0]'
  else
    echo -e "${RED}✗ Telegram test capture failed${NC}"
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
  noel-register-project [name] [--description "..."] [--priority "..."] [--tech-stack "..."]
                                          Register a new project (MANDATORY before capturing learnings)
  noel-projects [status]                  List all projects

${BLUE}Evaluation Management:${NC}
  noel-evaluate [--scope all]             Trigger an evaluation cycle
  noel-proposals [status]                 List pending evaluation proposals
  noel-approve <eval-id> [reason]         Approve a proposal (updates learning + vector)
  noel-reject <eval-id> [reason]          Reject a proposal with reason

${BLUE}Telegram Gateway:${NC}
  noel-telegram-status                    Check gateway RPC accessibility
  noel-telegram-test [title] [content]    Simulate Telegram capture (source_channel=telegram)

${BLUE}Configuration:${NC}
  export NOEL_WEBHOOK_URL="https://your-ngrok-url.ngrok.io/webhook"

${BLUE}Current Session:${NC}
  Session ID: ${CURRENT_SESSION_ID:-"(none)"}
  Recording:  ${NOEL_RECORDING_PATH:-"(none)"}

${YELLOW}Examples:${NC}
  # Register project first (new as of 2025-01-04)
  noel-register-project "MyProject" --description "Web application" --priority "P1-High"

  # Then start session and capture learnings
  noel-start-session "MyProject" "Implementing new feature"
  noel-capture "MyProject" "Feature pattern" "Use composition over inheritance"
  noel-query "recent patterns"
  noel-end-session

For more details, see: specs/001-knowledge-repository/quickstart.md
EOF
}

# Display help if no webhook URL is configured
if [ -z "$NOEL_WEBHOOK_URL" ]; then
  echo -e "${YELLOW}Noel helper functions loaded, but NOEL_WEBHOOK_URL not set.${NC}"
  echo -e "Set it with: ${BLUE}export NOEL_WEBHOOK_URL='https://your-ngrok-url.ngrok.io/webhook'${NC}"
fi
