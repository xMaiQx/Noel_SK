#!/bin/bash

##############################################################################
# Capture 12 Learnings from SESSION_LEARNINGS.md to Noel
#
# This script batch-captures all documented learnings from the successful
# database verification session into Noel for permanent storage.
##############################################################################

# Source helpers
source /Users/murodos/Documents/_Mad_Panda_/Proyectos/Noel_SK/scripts/noel-helpers.sh

# Check environment
if [ -z "$NOEL_WEBHOOK_URL" ]; then
  echo "Error: NOEL_WEBHOOK_URL not set"
  echo "Set with: export NOEL_WEBHOOK_URL='https://your-ngrok-url.ngrok-free.app/webhook'"
  exit 1
fi

echo "Capturing 12 learnings from SESSION_LEARNINGS.md..."
echo ""

# Learning 1: Notion Two ID Types
echo "📚 [1/12] Notion API Two ID Types..."
noel-capture "Noel" \
  "Notion API Two ID Types - Critical Pattern" \
  "Notion databases have TWO different IDs: (1) Database ID for schema operations (retrieve_database), (2) Data Source ID for querying records (query_data_source). These are NOT interchangeable! Using wrong ID returns empty results. Get Database ID from Notion URL, get Data Source ID from data_sources[0].id in retrieve_database response." \
  "Pattern" \
  "High"
echo ""

# Learning 2: Bash Piping Gotcha
echo "📚 [2/12] Bash Piping to Python..."
noel-capture "Noel" \
  "Bash Piping curl to Python - Variable Expansion Gotcha" \
  "When piping curl output to python3 -c, shell variable expansion inside heredocs causes syntax errors. curl progress bar mixes with JSON, breaking Python parsing. Solutions: (1) Suppress stderr with 2>/dev/null, (2) Use file intermediary, (3) Quote heredoc delimiter << 'EOF' to prevent variable expansion." \
  "Error" \
  "High"
echo ""

# Learning 3: Path Resolution
echo "📚 [3/12] Bash Path Resolution..."
noel-capture "Noel" \
  "Environment Variable Path Resolution in Sourced Scripts" \
  "When sourcing bash scripts, \${BASH_SOURCE[0]} may be empty if script is sourced vs executed directly. This breaks relative path resolution. Use fallback: if [ -n \"\${BASH_SOURCE[0]}\" ]; then use it; else use \$0; fi. Try multiple locations for .env file." \
  "Error" \
  "High"
echo ""

# Learning 4: Trailing Spaces
echo "📚 [4/12] Property Name Trailing Spaces..."
noel-capture "Noel" \
  "Notion Property Names with Trailing Spaces Break Validation" \
  "Notion property names with trailing spaces cause silent failures in automated verification. Visual inspection doesn't catch them - only automated comparison reveals the issue. Example: 'AI Suggested ' (with space) vs 'AI Suggested' (correct). Prevention: Always use automated verification, trim property names in Notion." \
  "Anti-Pattern" \
  "High"
echo ""

# Learning 5: Singular vs Plural
echo "📚 [5/12] Relation Naming Conventions..."
noel-capture "Noel" \
  "Singular vs Plural Relation Naming - Semantic Consistency" \
  "Relation property names should reflect cardinality: Singular for many-to-one (e.g., Learnings.Session - one learning has one session), Plural for one-to-many or many-to-many (e.g., Sessions.Learnings - one session has many learnings). This improves code readability and API consistency." \
  "Pattern" \
  "High"
echo ""

# Learning 6: Automation
echo "📚 [6/12] Automated Verification..."
noel-capture "Noel" \
  "Automated Verification Always Beats Manual Checklists" \
  "Manual checklists fail to catch: trailing spaces in property names, plural/singular naming mistakes, missing properties, type mismatches. Automated verification catches ALL discrepancies instantly with 100% accuracy. ROI: 15-30 min manual → 5 sec automated. Pattern: Query database via API, compare actual vs expected properties, report exact discrepancies." \
  "Insight" \
  "High"
echo ""

# Learning 7: Reverse Relations
echo "📚 [7/12] Notion Reverse Relations..."
noel-capture "Noel" \
  "Notion Reverse Relations Auto-Generate - Expected Behavior" \
  "When creating a relation in Notion (e.g., Learnings.Project → Projects), Notion automatically creates a reverse relation in the target database (Projects.Learnings). These reverse relations appear as 'extra' fields when comparing against spec but are expected and correct. Don't flag as validation errors." \
  "Pattern" \
  "High"
echo ""

# Learning 8: f-string Syntax
echo "📚 [8/12] Python f-string Nested Quotes..."
noel-capture "Noel" \
  "Python f-string Syntax - Nested Quotes Require Special Handling" \
  "Python f-strings can't contain nested quotes that match the string delimiter. The expression inside {} terminates at first matching quote. Solutions: (1) Use different quote types (double quotes outside, single inside), (2) Assign to variable first, (3) Escaping doesn't work in f-strings. Best practice: Always use double quotes for f-strings containing string operations." \
  "Error" \
  "Medium"
echo ""

# Learning 9: ngrok Automation
echo "📚 [9/12] ngrok URL Automation..."
noel-capture "Noel" \
  "ngrok URL Extraction - Automated Environment Updates" \
  "ngrok URLs change on every restart. Automate extraction via ngrok's local API at localhost:4040/api/tunnels. Use curl + jq to extract public_url and update .env file automatically. Pattern: curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url'. Update .env with sed and reload environment." \
  "Pattern" \
  "Medium"
echo ""

# Learning 10: Constitution
echo "📚 [10/12] Project Constitution as Validation..."
noel-capture "Noel" \
  "Constitution as Non-Negotiable Validation Gate" \
  "Having a formal project constitution (v1.0.0) established BEFORE implementation prevents scope creep and architectural inconsistencies. Principles validated: Workflow-first architecture (everything via n8n), Cloud-native storage (Notion/Supabase), AI-enhanced metadata, Context preservation (sessions, recordings). Pattern: Write constitution → Run /speckit.analyze → Flag violations as CRITICAL." \
  "Insight" \
  "High"
echo ""

# Learning 11: Data Source IDs
echo "📚 [11/12] Data Source ID Discovery..."
noel-capture "Noel" \
  "Data Source IDs Hidden in retrieve_database Response" \
  "When you call retrieve_database with a Database ID, the response includes data_sources[0].id which IS the Data Source ID you need for queries. No manual ID hunting needed. Pattern: Query retrieve_database → Extract data_sources[0].id → Use for query_data_source. Enables automated environment setup with single Database ID as input." \
  "Pattern" \
  "High"
echo ""

# Learning 12: Living Documentation
echo "📚 [12/12] Skills as Living Documentation..."
noel-capture "Noel" \
  "Skills as Living Documentation - Update During Implementation" \
  "Skills should evolve during implementation, capturing discovered patterns and solutions in real-time rather than waiting until project complete. Pattern: Encounter issue → Solve it → Immediately document in skill. Benefits: (1) Context fresh in working memory, (2) Examples use actual IDs/errors/solutions, (3) Iterative improvement, (4) Next developer has exact solutions. Update skill references/ directory as patterns emerge." \
  "Best Practice" \
  "High"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All 12 learnings captured to Noel!"
echo ""
echo "To verify, check your Notion Learnings database or query:"
echo "  noel-query \"Notion API patterns\" \"Noel\""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
