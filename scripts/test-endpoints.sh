#!/bin/bash

##############################################################################
# Noel Knowledge Repository - Endpoint Testing Script
#
# This script tests all 8 webhook endpoints to verify the n8n workflow
# implementation is working correctly.
#
# Prerequisites:
# 1. n8n workflow must be active and running
# 2. ngrok tunnel must be active
# 3. Set NOEL_WEBHOOK_URL environment variable
#
# Usage:
#   ./scripts/test-endpoints.sh
#
# Or test specific endpoints:
#   ./scripts/test-endpoints.sh capture
#   ./scripts/test-endpoints.sh query
#   ./scripts/test-endpoints.sh all
##############################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test configuration
WEBHOOK_URL="${NOEL_WEBHOOK_URL:-}"
TEST_MODE="${1:-all}"

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

##############################################################################
# Helper Functions
##############################################################################

function print_header() {
  echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN} $1${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
}

function print_test() {
  echo -e "${BLUE}➤ Testing:${NC} $1"
}

function print_success() {
  echo -e "${GREEN}✓ PASS:${NC} $1"
  ((TESTS_PASSED++))
  ((TESTS_TOTAL++))
}

function print_failure() {
  echo -e "${RED}✗ FAIL:${NC} $1"
  ((TESTS_FAILED++))
  ((TESTS_TOTAL++))
}

function check_config() {
  if [ -z "$WEBHOOK_URL" ]; then
    echo -e "${RED}Error: NOEL_WEBHOOK_URL environment variable not set${NC}"
    echo "Set it with: export NOEL_WEBHOOK_URL='https://your-ngrok-url.ngrok.io/webhook'"
    exit 1
  fi

  if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed${NC}"
    echo "Install with: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
  fi

  echo -e "${GREEN}✓ Configuration verified${NC}"
  echo -e "  Webhook URL: ${WEBHOOK_URL}"
}

##############################################################################
# Test Functions
##############################################################################

function test_capture_learning() {
  print_header "TEST 1: Capture Learning"

  print_test "Capturing test learning with minimal fields"

  local response=$(curl -s -X POST "$WEBHOOK_URL/capture_learning" \
    -H 'Content-Type: application/json' \
    -d '{
      "project": "Noel",
      "title": "Test Learning - Endpoint Verification",
      "content": "This is a test learning to verify the capture_learning endpoint is working correctly. It should generate a unique learning ID and store the learning in Notion."
    }')

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local learning_id=$(echo "$response" | jq -r '.learning_id // "unknown"')
    print_success "Learning captured with ID: $learning_id"
    echo "$response" | jq '.'

    # Store learning ID for later tests
    export TEST_LEARNING_ID="$learning_id"
  else
    print_failure "Failed to capture learning"
    echo "$response" | jq '.'
  fi
}

function test_update_learning() {
  print_header "TEST 2: Update Learning"

  if [ -z "$TEST_LEARNING_ID" ]; then
    print_failure "Skipping - no learning ID from capture test"
    return
  fi

  print_test "Updating test learning status to Validated"

  local response=$(curl -s -X POST "$WEBHOOK_URL/update_learning" \
    -H 'Content-Type: application/json' \
    -d "{
      \"learning_id\": \"$TEST_LEARNING_ID\",
      \"status\": \"Validated\",
      \"ai_accepted\": true
    }")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    print_success "Learning updated successfully"
    echo "$response" | jq '.'
  else
    print_failure "Failed to update learning"
    echo "$response" | jq '.'
  fi
}

function test_query_learnings() {
  print_header "TEST 3: Query Learnings (Semantic Search)"

  print_test "Querying learnings with natural language query"

  local response=$(curl -s -X POST "$WEBHOOK_URL/query_learnings" \
    -H 'Content-Type: application/json' \
    -d '{
      "query": "endpoint verification testing",
      "filters": {
        "project": "Noel"
      }
    }')

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local count=$(echo "$response" | jq -r '.count // 0')
    print_success "Query returned $count results"
    echo "$response" | jq '.results | limit(3; .[])'  # Show first 3 results
  else
    print_failure "Query failed"
    echo "$response" | jq '.'
  fi
}

function test_query_feedback() {
  print_header "TEST 4: Submit Query Feedback"

  if [ -z "$TEST_LEARNING_ID" ]; then
    print_failure "Skipping - no learning ID from capture test"
    return
  fi

  print_test "Submitting relevance feedback for query"

  local response=$(curl -s -X POST "$WEBHOOK_URL/query_feedback" \
    -H 'Content-Type: application/json' \
    -d "{
      \"query_text\": \"endpoint verification testing\",
      \"relevant_learning_ids\": [\"$TEST_LEARNING_ID\"]
    }")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    print_success "Feedback submitted successfully"
    echo "$response" | jq '.'
  else
    print_failure "Failed to submit feedback"
    echo "$response" | jq '.'
  fi
}

function test_list_projects() {
  print_header "TEST 5: List Projects"

  print_test "Retrieving project catalog"

  local response=$(curl -s -X POST "$WEBHOOK_URL/list_projects" \
    -H 'Content-Type: application/json' \
    -d '{
      "filters": {}
    }')

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local count=$(echo "$response" | jq -r '.count // 0')
    print_success "Retrieved $count projects"
    echo "$response" | jq '.projects[] | {name, status, learning_count}'
  else
    print_failure "Failed to list projects"
    echo "$response" | jq '.'
  fi
}

function test_create_session() {
  print_header "TEST 6: Create Session"

  print_test "Creating test session"

  local recording_path="$HOME/coding-sessions/test-$(date +%Y%m%d-%H%M%S).cast"

  local response=$(curl -s -X POST "$WEBHOOK_URL/create_session" \
    -H 'Content-Type: application/json' \
    -d "{
      \"projects\": [\"Noel\"],
      \"goals\": \"Testing session creation endpoint and verifying session tracking functionality\",
      \"recording_file_path\": \"$recording_path\",
      \"ai_type\": \"Claude\"
    }")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local session_id=$(echo "$response" | jq -r '.session_id // "unknown"')
    print_success "Session created with ID: $session_id"
    echo "$response" | jq '.'

    # Store session ID for end session test
    export TEST_SESSION_ID="$session_id"
  else
    print_failure "Failed to create session"
    echo "$response" | jq '.'
  fi
}

function test_end_session() {
  print_header "TEST 7: End Session"

  if [ -z "$TEST_SESSION_ID" ]; then
    print_failure "Skipping - no session ID from create test"
    return
  fi

  # Wait 2 seconds to ensure measurable duration
  echo -e "${YELLOW}Waiting 2 seconds to ensure measurable session duration...${NC}"
  sleep 2

  print_test "Ending test session"

  local response=$(curl -s -X POST "$WEBHOOK_URL/end_session" \
    -H 'Content-Type: application/json' \
    -d "{
      \"session_id\": \"$TEST_SESSION_ID\"
    }")

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local duration=$(echo "$response" | jq -r '.duration_minutes // 0')
    print_success "Session ended (duration: $duration minutes)"
    echo "$response" | jq '.'
  else
    print_failure "Failed to end session"
    echo "$response" | jq '.'
  fi
}

function test_query_sessions() {
  print_header "TEST 8: Query Sessions"

  print_test "Querying session history"

  local response=$(curl -s -X POST "$WEBHOOK_URL/query_sessions" \
    -H 'Content-Type: application/json' \
    -d '{
      "filters": {
        "project": "Noel"
      }
    }')

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ]; then
    local count=$(echo "$response" | jq -r '.count // 0')
    print_success "Query returned $count sessions"
    echo "$response" | jq '.sessions | limit(3; .[]) | {session_id, status, duration_minutes, learning_count}'
  else
    print_failure "Failed to query sessions"
    echo "$response" | jq '.'
  fi
}

##############################################################################
# Performance Tests
##############################################################################

function test_performance() {
  print_header "PERFORMANCE TESTS"

  print_test "Response time for capture endpoint (should be < 3 seconds)"

  local start_time=$(date +%s)

  local response=$(curl -s -X POST "$WEBHOOK_URL/capture_learning" \
    -H 'Content-Type: application/json' \
    -d '{
      "project": "Noel",
      "title": "Performance Test Learning",
      "content": "This learning tests the response time of the capture endpoint including AI enrichment."
    }')

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  local success=$(echo "$response" | jq -r '.success // false')

  if [ "$success" = "true" ] && [ "$duration" -lt 3 ]; then
    print_success "Capture completed in ${duration}s (< 3s requirement met)"
  elif [ "$success" = "true" ]; then
    print_failure "Capture took ${duration}s (exceeds 3s requirement)"
  else
    print_failure "Capture failed"
  fi
}

##############################################################################
# Main Test Runner
##############################################################################

function run_all_tests() {
  check_config

  print_header "NOEL KNOWLEDGE REPOSITORY - ENDPOINT TESTS"
  echo -e "Testing webhook URL: ${WEBHOOK_URL}\n"

  test_capture_learning
  test_update_learning
  test_query_learnings
  test_query_feedback
  test_list_projects
  test_create_session
  test_end_session
  test_query_sessions
  test_performance

  # Print summary
  print_header "TEST SUMMARY"
  echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  echo -e "Total:  $TESTS_TOTAL\n"

  if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}\n"
    exit 0
  else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}\n"
    exit 1
  fi
}

##############################################################################
# CLI Interface
##############################################################################

case "$TEST_MODE" in
  capture)
    check_config
    test_capture_learning
    ;;
  update)
    check_config
    test_update_learning
    ;;
  query)
    check_config
    test_query_learnings
    ;;
  feedback)
    check_config
    test_query_feedback
    ;;
  projects)
    check_config
    test_list_projects
    ;;
  session-create)
    check_config
    test_create_session
    ;;
  session-end)
    check_config
    test_end_session
    ;;
  sessions)
    check_config
    test_query_sessions
    ;;
  performance)
    check_config
    test_performance
    ;;
  all)
    run_all_tests
    ;;
  *)
    echo "Usage: $0 [capture|update|query|feedback|projects|session-create|session-end|sessions|performance|all]"
    echo "Default: all"
    exit 1
    ;;
esac
