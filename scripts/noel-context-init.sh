#!/bin/bash
##############################################################################
# Noel Context Init - Smart session initialization with git context extraction
#
# Part of Mission 2: Proactive Memory System
#
# Usage:
#   source scripts/noel-context-init.sh
#   extract_git_context   # Returns JSON with project, branch, keywords, signals
#   smart_query           # Builds composite query from context and queries Noel
#
# Dependencies:
#   - git (for branch/file detection)
#   - jq (for JSON building)
#   - noel-q function from noel-quick.sh
##############################################################################

# Noise words to filter from branch names
_BRANCH_NOISE="feature fix bugfix hotfix release main master develop dev chore docs ci test tests build staging prod production"

##############################################################################
# Function: Extract git context as JSON
#
# Returns: JSON object with project, branch, keywords, tech/domain signals
##############################################################################
extract_git_context() {
  local git_root branch project branch_keywords tech_signals domain_signals recent_files

  # Project name from git root
  git_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$git_root" ]; then
    # Bare directory fallback
    echo '{"project":"'"$(basename "$PWD")"'","branch":"","branch_keywords":[],"tech_signals":[],"domain_signals":[],"recent_files":[]}'
    return 0
  fi

  project=$(basename "$git_root")
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  # Extract keywords from branch name: split on / - _ and filter noise
  branch_keywords=()
  if [ -n "$branch" ]; then
    IFS='/-_' read -ra parts <<< "$branch"
    for part in "${parts[@]}"; do
      # Skip noise words (case-insensitive) and short words
      local lower_part
      lower_part=$(echo "$part" | tr '[:upper:]' '[:lower:]')
      if [ ${#lower_part} -ge 3 ] && ! echo "$_BRANCH_NOISE" | grep -qw "$lower_part"; then
        branch_keywords+=("$lower_part")
      fi
    done
  fi

  # Recent files: last 3 commits or staged changes
  local raw_files
  raw_files=$(git diff --name-only HEAD~3 HEAD 2>/dev/null || git diff --name-only HEAD 2>/dev/null || echo "")

  # Tech signals: extract unique file extensions
  tech_signals=()
  local seen_exts=""
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    local ext="${file##*.}"
    if [ "$ext" != "$file" ] && [ -n "$ext" ]; then
      local lower_ext
      lower_ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
      if ! echo "$seen_exts" | grep -qw "$lower_ext"; then
        seen_exts="$seen_exts $lower_ext"
        # Map extensions to technology names
        case "$lower_ext" in
          js|jsx|mjs) tech_signals+=("javascript") ;;
          ts|tsx)     tech_signals+=("typescript") ;;
          py)         tech_signals+=("python") ;;
          rb)         tech_signals+=("ruby") ;;
          rs)         tech_signals+=("rust") ;;
          go)         tech_signals+=("go") ;;
          sh|bash)    tech_signals+=("bash") ;;
          sql)        tech_signals+=("sql") ;;
          json)       tech_signals+=("json") ;;
          yml|yaml)   tech_signals+=("yaml") ;;
          md)         tech_signals+=("markdown") ;;
          css|scss)   tech_signals+=("css") ;;
          html)       tech_signals+=("html") ;;
          vue)        tech_signals+=("vue") ;;
          svelte)     tech_signals+=("svelte") ;;
          swift)      tech_signals+=("swift") ;;
          kt|kts)     tech_signals+=("kotlin") ;;
          java)       tech_signals+=("java") ;;
        esac
      fi
    fi
  done <<< "$raw_files"

  # Domain signals: extract unique directory names (first level)
  domain_signals=()
  local seen_dirs=""
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    local dir
    dir=$(echo "$file" | cut -d'/' -f1)
    if [ -n "$dir" ] && [ "$dir" != "$file" ]; then
      local lower_dir
      lower_dir=$(echo "$dir" | tr '[:upper:]' '[:lower:]')
      if ! echo "$seen_dirs" | grep -qw "$lower_dir"; then
        seen_dirs="$seen_dirs $lower_dir"
        domain_signals+=("$lower_dir")
      fi
    fi
  done <<< "$raw_files"

  # Recent files (top 10)
  local recent_arr=()
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    recent_arr+=("$file")
    [ ${#recent_arr[@]} -ge 10 ] && break
  done <<< "$raw_files"

  # Build JSON output
  local kw_json tech_json domain_json files_json
  kw_json=$(printf '%s\n' "${branch_keywords[@]}" | jq -R . | jq -s .)
  tech_json=$(printf '%s\n' "${tech_signals[@]}" | jq -R . | jq -s .)
  domain_json=$(printf '%s\n' "${domain_signals[@]}" | jq -R . | jq -s .)
  files_json=$(printf '%s\n' "${recent_arr[@]}" | jq -R . | jq -s .)

  jq -n \
    --arg project "$project" \
    --arg branch "$branch" \
    --argjson branch_keywords "$kw_json" \
    --argjson tech_signals "$tech_json" \
    --argjson domain_signals "$domain_json" \
    --argjson recent_files "$files_json" \
    '{
      project: $project,
      branch: $branch,
      branch_keywords: $branch_keywords,
      tech_signals: $tech_signals,
      domain_signals: $domain_signals,
      recent_files: $recent_files
    }'
}

##############################################################################
# Function: Build and execute a smart query from git context
#
# Combines project name, branch keywords, and tech signals into a composite
# query that surfaces more relevant learnings than a basic "recent patterns"
##############################################################################
smart_query() {
  local context
  context=$(extract_git_context)

  local project branch_keywords tech_signals
  project=$(echo "$context" | jq -r '.project')
  branch_keywords=$(echo "$context" | jq -r '.branch_keywords | join(" ")')
  tech_signals=$(echo "$context" | jq -r '.tech_signals | join(" ")')

  # Build composite query
  local query_parts=()
  [ -n "$project" ] && query_parts+=("$project")
  [ -n "$branch_keywords" ] && query_parts+=("$branch_keywords")
  [ -n "$tech_signals" ] && query_parts+=("$tech_signals")
  query_parts+=("patterns solutions")

  local composite_query="${query_parts[*]}"

  # Log context signal if noel endpoint is available
  if [ -n "$NOEL_URL" ] && [ "$NOEL_URL" != "http://NGROK_NOT_RUNNING/webhook/noel" ]; then
    # Fire-and-forget signal logging
    curl -s "$NOEL_URL" \
      -H "Content-Type: application/json" \
      -H "Authorization: ${NOEL_AUTH:-}" \
      -d "$(jq -n \
        --arg session_id "${CURRENT_SESSION_ID:-}" \
        --arg signal_type "git_branch" \
        --argjson signal_data "$context" \
        --arg query "$composite_query" \
        '{
          endpoint: "log_context_signal",
          session_id: $session_id,
          signal_type: $signal_type,
          signal_data: $signal_data,
          extracted_keywords: ($signal_data.branch_keywords + $signal_data.tech_signals),
          query_generated: $query
        }')" >/dev/null 2>&1 &
  fi

  # Execute the query with context for server-side re-ranking
  if type noel-q-ctx &>/dev/null; then
    noel-q-ctx "$composite_query" "$project"
  elif type noel-q &>/dev/null; then
    noel-q "$composite_query" "$project"
  else
    echo "⚠️  noel-q not available. Source noel-quick.sh first."
    echo "   Composite query: $composite_query"
  fi
}

##############################################################################
# Function: Log a context signal to Supabase (for analytics)
##############################################################################
log_context_signal() {
  local signal_type="$1"
  local signal_data="$2"
  local keywords="$3"
  local query="$4"

  if [ -z "$NOEL_URL" ] || [ "$NOEL_URL" = "http://NGROK_NOT_RUNNING/webhook/noel" ]; then
    return 0  # Silent no-op
  fi

  curl -s "$NOEL_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: ${NOEL_AUTH:-}" \
    -d "$(jq -n \
      --arg session_id "${CURRENT_SESSION_ID:-}" \
      --arg signal_type "$signal_type" \
      --arg signal_data "$signal_data" \
      --arg keywords "$keywords" \
      --arg query "$query" \
      '{
        endpoint: "log_context_signal",
        session_id: $session_id,
        signal_type: $signal_type,
        signal_data: ($signal_data | fromjson? // {raw: $signal_data}),
        extracted_keywords: ($keywords | split(",") | map(gsub("^\\s+|\\s+$";""))),
        query_generated: $query
      }')" >/dev/null 2>&1
}

# Export functions
export -f extract_git_context smart_query log_context_signal 2>/dev/null
