#!/bin/bash

##############################################################################
# Apply Database Migration to Supabase
#
# Usage: bash scripts/apply_migration.sh <migration_file>
# Example: bash scripts/apply_migration.sh migrations/001_usage_tracking_schema.sql
##############################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION_FILE="${1:-}"

# Check if migration file provided
if [ -z "$MIGRATION_FILE" ]; then
  echo -e "${RED}Error: No migration file specified${NC}"
  echo ""
  echo "Usage: bash scripts/apply_migration.sh <migration_file>"
  echo "Example: bash scripts/apply_migration.sh migrations/001_usage_tracking_schema.sql"
  exit 1
fi

# Check if file exists
if [ ! -f "$SCRIPT_DIR/$MIGRATION_FILE" ]; then
  echo -e "${RED}Error: Migration file not found: $SCRIPT_DIR/$MIGRATION_FILE${NC}"
  exit 1
fi

FULL_PATH="$SCRIPT_DIR/$MIGRATION_FILE"
MIGRATION_NAME=$(basename "$MIGRATION_FILE" .sql)

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Apply Database Migration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Migration:${NC} $MIGRATION_NAME"
echo -e "${YELLOW}File:${NC} $FULL_PATH"
echo ""

# Method 1: Check if psql is available
if command -v psql &> /dev/null; then
  echo -e "${YELLOW}⚠️  psql detected, but direct connection requires database password${NC}"
  echo -e "${YELLOW}   For Supabase, it's recommended to use the web SQL Editor${NC}"
  echo ""
fi

# Method 2: Manual instructions
echo -e "${BLUE}📋 Manual Migration Steps:${NC}"
echo ""
echo "1. Open Supabase Dashboard:"
echo -e "   ${GREEN}https://supabase.com/dashboard/project/sladetzgpogodrqwfamy/sql/new${NC}"
echo ""
echo "2. Copy the migration SQL:"
echo -e "   ${BLUE}cat \"$FULL_PATH\" | pbcopy${NC}"
echo "   (SQL copied to clipboard if you run the above command)"
echo ""
echo "3. Paste into SQL Editor and click 'Run'"
echo ""
echo "4. Verify tables created:"
echo "   ${BLUE}SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'learning_%';${NC}"
echo ""
echo "5. Verify materialized view created:"
echo "   ${BLUE}SELECT * FROM learning_metrics LIMIT 1;${NC}"
echo ""

# Method 3: Copy SQL to clipboard (macOS)
if command -v pbcopy &> /dev/null; then
  echo -e "${YELLOW}Would you like to copy the SQL to clipboard? [y/N]${NC}"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    cat "$FULL_PATH" | pbcopy
    echo -e "${GREEN}✓ SQL copied to clipboard${NC}"
    echo -e "${GREEN}  Paste into Supabase SQL Editor and run${NC}"
    echo ""
  fi
fi

# Method 4: Display SQL content
echo -e "${YELLOW}Would you like to view the SQL content? [y/N]${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  cat "$FULL_PATH"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
fi

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Migration file ready to apply${NC}"
echo -e "${YELLOW}⚠️  Remember to verify migration success in Supabase Dashboard${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Next steps
echo -e "${BLUE}📋 After applying migration:${NC}"
echo ""
echo "1. Verify tables exist:"
echo "   ${BLUE}curl 'https://sladetzgpogodrqwfamy.supabase.co/rest/v1/learning_usage?limit=1' \\${NC}"
echo "   ${BLUE}     -H 'apikey: <your-key>' -H 'Authorization: Bearer <your-key>'${NC}"
echo ""
echo "2. Test usage tracking function:"
echo "   ${BLUE}SELECT track_learning_usage('TEST-001', 'SESSION-TEST', 'query_match', 'test query', 0.9, true, true);${NC}"
echo ""
echo "3. Check metrics view:"
echo "   ${BLUE}SELECT * FROM get_learning_metrics(NULL, 0, 'effectiveness_score', 10);${NC}"
echo ""
