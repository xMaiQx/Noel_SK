#!/bin/bash

##############################################################################
# Environment Setup and Validation Script
#
# This script loads the .env file and validates all required variables
# are configured correctly.
#
# Usage:
#   source scripts/setup-env.sh
#   # Or
#   . scripts/setup-env.sh
##############################################################################

# Get the directory where this script is located
# Handle both sourcing and direct execution
if [ -n "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
else
  SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
fi

# Try to find project root
if [ -f "$SCRIPT_DIR/../.env" ]; then
  PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
elif [ -f "$PWD/.env" ]; then
  PROJECT_ROOT="$PWD"
else
  # Fallback: assume we're in the project directory
  PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
fi

ENV_FILE="$PROJECT_ROOT/.env"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Loading Noel environment configuration...${NC}"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
  echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
  echo "Create it by running: cp .env.example .env (or it should already exist)"
  return 1 2>/dev/null || exit 1
fi

# Load .env file
set -a  # Automatically export all variables
source "$ENV_FILE"
set +a

echo -e "${GREEN}✓ .env file loaded${NC}"

# Validation function
function validate_var() {
  local var_name="$1"
  local var_value="${!var_name}"
  local is_required="${2:-true}"

  if [ "$is_required" = "true" ]; then
    if [ -z "$var_value" ] || [ "$var_value" = "YOUR_"*"_HERE" ]; then
      echo -e "${RED}✗ $var_name is not configured${NC}"
      return 1
    else
      echo -e "${GREEN}✓ $var_name configured${NC}"
      return 0
    fi
  else
    if [ -z "$var_value" ] || [ "$var_value" = "YOUR_"*"_HERE" ]; then
      echo -e "${YELLOW}⚠ $var_name not configured (optional)${NC}"
      return 0
    else
      echo -e "${GREEN}✓ $var_name configured${NC}"
      return 0
    fi
  fi
}

echo ""
echo -e "${BLUE}Validating configuration...${NC}"
echo ""

# Validate required variables
VALIDATION_FAILED=0

echo -e "${YELLOW}n8n Configuration:${NC}"
validate_var "NGROK_URL" || ((VALIDATION_FAILED++))
validate_var "AUTH_TOKEN" || ((VALIDATION_FAILED++))

echo ""
echo -e "${YELLOW}Notion Database IDs:${NC}"
validate_var "NOTION_PROJECTS_DB" "false"
validate_var "NOTION_PROJECTS_DS" "false"
validate_var "NOTION_LEARNINGS_DB" "false"
validate_var "NOTION_LEARNINGS_DS" "false"
validate_var "NOTION_SESSIONS_DB" "false"
validate_var "NOTION_SESSIONS_DS" "false"

echo ""
echo -e "${YELLOW}Supabase Configuration:${NC}"
validate_var "SUPABASE_URL" "false"
validate_var "SUPABASE_ANON_KEY" "false"

echo ""
echo -e "${YELLOW}OpenAI Configuration:${NC}"
validate_var "OPENAI_API_KEY" "false"

echo ""

if [ $VALIDATION_FAILED -gt 0 ]; then
  echo -e "${RED}Configuration incomplete. Please update .env file.${NC}"
  echo "Required variables: NGROK_URL, AUTH_TOKEN"
  return 1 2>/dev/null || exit 1
fi

echo -e "${GREEN}✓ All required variables configured${NC}"
echo ""
echo -e "${BLUE}Environment ready!${NC}"
echo ""
echo -e "Current ngrok URL: ${GREEN}$NGROK_URL${NC}"
echo -e "Webhook URL: ${GREEN}$NOEL_WEBHOOK_URL${NC}"
echo ""
echo -e "${YELLOW}Quick Commands:${NC}"
echo "  Test ngrok: curl -s $NGROK_URL"
echo "  Get new ngrok URL: curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url'"
echo "  Update .env: nano .env"
echo ""

# Export helper function to update ngrok URL
function update-ngrok-url() {
  local new_url=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "import json,sys; data=json.load(sys.stdin); print(data['tunnels'][0]['public_url'] if data.get('tunnels') else '')" 2>/dev/null)

  if [ -z "$new_url" ]; then
    echo -e "${RED}Error: Could not get ngrok URL. Is ngrok running?${NC}"
    return 1
  fi

  echo -e "${BLUE}Updating ngrok URL in .env...${NC}"
  echo -e "Old URL: ${YELLOW}$NGROK_URL${NC}"
  echo -e "New URL: ${GREEN}$new_url${NC}"

  # Update .env file
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|NGROK_URL=\".*\"|NGROK_URL=\"$new_url\"|g" "$ENV_FILE"
  else
    # Linux
    sed -i "s|NGROK_URL=\".*\"|NGROK_URL=\"$new_url\"|g" "$ENV_FILE"
  fi

  # Reload environment
  source "$ENV_FILE"

  echo -e "${GREEN}✓ ngrok URL updated${NC}"
  echo -e "New webhook URL: ${GREEN}$NOEL_WEBHOOK_URL${NC}"
}

echo -e "${YELLOW}Tip: Run 'update-ngrok-url' to automatically update ngrok URL when it changes${NC}"
echo ""
