#!/bin/bash
# Upload Noel Knowledge Repository workflow to n8n
# This script creates the workflow in n8n via the API

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Uploading Noel Knowledge Repository Workflow             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Load environment
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

source "$PROJECT_ROOT/.env"

if [ -z "$NGROK_URL" ] || [ -z "$N8N_API_KEY" ]; then
    echo -e "${RED}Error: NGROK_URL or N8N_API_KEY not set in .env${NC}"
    exit 1
fi

echo -e "Using n8n instance: ${GREEN}${NGROK_URL}${NC}"
echo ""

# Read workflow JSON
WORKFLOW_FILE="$PROJECT_ROOT/n8n-workflows/noel_knowledge_repository.json"

if [ ! -f "$WORKFLOW_FILE" ]; then
    echo -e "${RED}Error: Workflow file not found at $WORKFLOW_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}Creating workflow in n8n...${NC}"

# Create workflow via API
RESPONSE=$(curl -s -X POST "${NGROK_URL}/api/v1/workflows" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -H "Content-Type: application/json" \
  -d @"$WORKFLOW_FILE")

# Check for errors
if echo "$RESPONSE" | grep -q '"message"'; then
    echo -e "${RED}✗ Failed to create workflow${NC}"
    echo "$RESPONSE" | jq .
    exit 1
fi

# Extract workflow ID
WORKFLOW_ID=$(echo "$RESPONSE" | jq -r '.id')
WORKFLOW_NAME=$(echo "$RESPONSE" | jq -r '.name')

echo -e "${GREEN}✓ Workflow created successfully!${NC}"
echo ""
echo -e "Workflow ID: ${BLUE}${WORKFLOW_ID}${NC}"
echo -e "Workflow Name: ${BLUE}${WORKFLOW_NAME}${NC}"
echo -e "Webhook URL: ${GREEN}${NGROK_URL}/webhook/noel${NC}"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "1. Activate the workflow in n8n UI"
echo "2. Test endpoints with scripts/test-noel-endpoints.sh"
echo "3. Start capturing learnings!"
echo ""
