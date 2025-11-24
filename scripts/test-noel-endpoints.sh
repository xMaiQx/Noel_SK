#!/bin/bash
# Test Noel Knowledge Repository Endpoints
# Tests all 8 webhook endpoints with sample data

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Load environment
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

source "$PROJECT_ROOT/.env"

NOEL_WEBHOOK_URL="${NGROK_URL}/webhook/noel"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Testing Noel Knowledge Repository Endpoints              ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Webhook URL: ${GREEN}${NOEL_WEBHOOK_URL}${NC}"
echo ""

# Test 1: Capture Learning
echo -e "${CYAN}Test 1: Capture Learning${NC}"
echo -e "${CYAN}════════════════════════════════════${NC}"

RESPONSE=$(curl -s -X POST "${NOEL_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -H "Authorization: ${AUTH_TOKEN}" \
  -d '{
    "endpoint": "capture_learning",
    "project": "Noel_SK",
    "title": "Test Learning - Noel Workflow Architecture",
    "type": "pattern",
    "content": "Noel uses a wrapper pattern: Webhook → Transform → Switch → Business Logic → Notion API Wrapper → Response",
    "context": "Built modular n8n workflow following MyCFO wrapper pattern",
    "dev_stream": ["Architecture", "n8n"],
    "tags": ["workflow", "wrapper-pattern", "n8n"],
    "confidence": "high",
    "ai_suggested": false
  }')

echo "$RESPONSE" | jq .
echo ""

# Extract learning_id if successful
LEARNING_ID=$(echo "$RESPONSE" | jq -r '.learning_id // empty')

if [ -n "$LEARNING_ID" ]; then
    echo -e "${GREEN}✓ Learning captured: ${LEARNING_ID}${NC}"
    echo ""

    # Test 2: Update Learning
    echo -e "${CYAN}Test 2: Update Learning${NC}"
    echo -e "${CYAN}════════════════════════════════════${NC}"

    RESPONSE=$(curl -s -X POST "${NOEL_WEBHOOK_URL}" \
      -H "Content-Type: application/json" \
      -H "Authorization: ${AUTH_TOKEN}" \
      -d "{
        \"endpoint\": \"update_learning\",
        \"learning_id\": \"${LEARNING_ID}\",
        \"tags\": [\"workflow\", \"wrapper-pattern\", \"n8n\", \"validated\"],
        \"ai_accepted\": true
      }")

    echo "$RESPONSE" | jq .
    echo ""
else
    echo -e "${YELLOW}⚠ Could not extract learning_id, skipping update test${NC}"
    echo ""
fi

# Test 3: Start Session
echo -e "${CYAN}Test 3: Start Session${NC}"
echo -e "${CYAN}════════════════════════════════════${NC}"

RESPONSE=$(curl -s -X POST "${NOEL_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -H "Authorization: ${AUTH_TOKEN}" \
  -d '{
    "endpoint": "start_session",
    "project": "Noel_SK",
    "goals": "Build and test Noel workflow architecture",
    "ai_type": "Claude",
    "recording_format": "markdown",
    "recording_file_path": "/tmp/test-session.md"
  }')

echo "$RESPONSE" | jq .
echo ""

# Extract session_id if successful
SESSION_ID=$(echo "$RESPONSE" | jq -r '.session_id // empty')

if [ -n "$SESSION_ID" ]; then
    echo -e "${GREEN}✓ Session started: ${SESSION_ID}${NC}"
    echo ""

    # Test 4: End Session
    echo -e "${CYAN}Test 4: End Session${NC}"
    echo -e "${CYAN}════════════════════════════════════${NC}"

    RESPONSE=$(curl -s -X POST "${NOEL_WEBHOOK_URL}" \
      -H "Content-Type: application/json" \
      -H "Authorization: ${AUTH_TOKEN}" \
      -d "{
        \"endpoint\": \"end_session\",
        \"session_id\": \"${SESSION_ID}\"
      }")

    echo "$RESPONSE" | jq .
    echo ""
else
    echo -e "${YELLOW}⚠ Could not extract session_id, skipping end session test${NC}"
    echo ""
fi

# Test 5: List Projects
echo -e "${CYAN}Test 5: List Projects${NC}"
echo -e "${CYAN}════════════════════════════════════${NC}"

RESPONSE=$(curl -s -X POST "${NOEL_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -H "Authorization: ${AUTH_TOKEN}" \
  -d '{
    "endpoint": "list_projects",
    "limit": 5
  }')

echo "$RESPONSE" | jq .
echo ""

# Test 6: List Sessions
echo -e "${CYAN}Test 6: List Sessions${NC}"
echo -e "${CYAN}════════════════════════════════════${NC}"

RESPONSE=$(curl -s -X POST "${NOEL_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -H "Authorization: ${AUTH_TOKEN}" \
  -d '{
    "endpoint": "list_sessions",
    "limit": 5
  }')

echo "$RESPONSE" | jq .
echo ""

# Test 7: Query Learnings (not implemented yet)
echo -e "${CYAN}Test 7: Query Learnings (Vector Search - Not Implemented)${NC}"
echo -e "${CYAN}════════════════════════════════════${NC}"

RESPONSE=$(curl -s -X POST "${NOEL_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -H "Authorization: ${AUTH_TOKEN}" \
  -d '{
    "endpoint": "query_learnings",
    "query": "How does Noel workflow architecture work?"
  }')

echo "$RESPONSE" | jq .
echo ""

# Test 8: Query Feedback (not implemented yet)
echo -e "${CYAN}Test 8: Query Feedback (Supabase - Not Implemented)${NC}"
echo -e "${CYAN}════════════════════════════════════${NC}"

RESPONSE=$(curl -s -X POST "${NOEL_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -H "Authorization: ${AUTH_TOKEN}" \
  -d '{
    "endpoint": "query_feedback",
    "query_id": "test-query-123",
    "learning_ids": ["learning-1", "learning-2"],
    "feedback_type": "relevant"
  }')

echo "$RESPONSE" | jq .
echo ""

echo -e "${CYAN}════════════════════════════════════${NC}"
echo -e "${GREEN}✓ All endpoint tests completed!${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} Endpoints 7-8 require Supabase setup (Phase 3-4)"
echo ""
