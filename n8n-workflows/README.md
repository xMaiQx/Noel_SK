# n8n Workflows - Noel Knowledge Repository

This directory contains n8n workflow definitions and helper functions for the Noel Knowledge Repository system.

## Overview

The Noel system uses **n8n visual workflows** to orchestrate all operations. This is NOT a traditional code repository - most implementation happens in the n8n visual editor.

## Directory Structure

```
n8n-workflows/
├── README.md                          # This file
├── Knowledge_Repository.json          # Main workflow (to be exported after implementation)
└── helpers/                           # JavaScript functions for n8n Function nodes
    ├── generate_learning_id.js        # Learning ID generation logic
    ├── generate_session_id.js         # Session ID generation logic
    ├── input_validation.js            # Input validation for all endpoints
    └── ai_enrichment.js               # AI categorization and tagging
```

## Workflow Architecture

### Main Workflow: `Knowledge_Repository`

**Single n8n workflow with 8 webhook endpoints:**

1. `/capture_learning` - POST - Store new learning with optional AI enrichment
2. `/update_learning` - POST - Update existing learning with status transitions
3. `/query_learnings` - POST - Semantic search across learnings
4. `/query_feedback` - POST - Submit query relevance feedback
5. `/list_projects` - POST - Query project catalog
6. `/create_session` - POST - Start coding session
7. `/end_session` - POST - Complete session with duration calculation
8. `/query_sessions` - POST - Retrieve session history with replay links

### Workflow Pattern

Each endpoint follows this pattern:

```
Webhook Trigger
  ↓
Input Validation (Function node)
  ↓
Business Logic (Notion/Supabase/OpenAI nodes)
  ↓
Response Formatting (Function node)
  ↓
Webhook Response
```

## Helper Functions

### 1. generate_learning_id.js

Generates unique learning IDs in format `PROJECT-###` (e.g., `NOEL-001`, `BR-042`)

**Usage in n8n:**
1. Add Function node with this code after receiving project name
2. Add Notion "Get All" node to query existing learnings
3. Add second Function node to calculate next sequence number (see comments in file)

**Algorithm:**
- Extract prefix from project name (e.g., "Briseno" → "BR", "Claude Code" → "CC")
- Query Notion for highest existing sequence number for this prefix
- Return next ID with zero-padded 3-digit sequence

### 2. generate_session_id.js

Generates unique session IDs in format `SESSION-YYYYMMDD-###` (e.g., `SESSION-20251120-001`)

**Usage in n8n:**
1. Add Function node when creating session (generates date string)
2. Add Notion "Get All" node to query existing sessions for today
3. Add second Function node to calculate next sequence number (see comments in file)

**Algorithm:**
- Format current date as YYYYMMDD
- Query Notion for existing sessions on this date
- Return next ID with zero-padded 3-digit sequence

### 3. input_validation.js

Validates input data for all webhook endpoints

**Usage in n8n:**
Add Function node immediately after each Webhook Trigger with appropriate validator:
- `validateCaptureLearning()` - For /capture_learning
- `validateUpdateLearning()` - For /update_learning
- `validateQueryLearnings()` - For /query_learnings
- `validateCreateSession()` - For /create_session
- `validateEndSession()` - For /end_session

**Validation Rules:**
- Required fields present and non-empty
- Field length constraints (e.g., title 5-200 chars, content 10-50k chars)
- Enum validation (type, confidence, status, dev_stream)
- Array validation (projects, tags)

### 4. ai_enrichment.js

AI-powered categorization and tagging using GPT-4o-mini

**Usage in n8n:**
1. Add Function node to generate enrichment prompt
2. Add OpenAI Chat node with model `gpt-4o-mini`
3. Add Function node to parse JSON response and merge with user metadata

**Functions:**
- `generateEnrichmentPrompt()` - Creates prompt for AI model
- `parseEnrichmentResponse()` - Validates and parses AI JSON response
- `mergeMetadata()` - Merges AI suggestions with user-provided data (append, don't replace)

**AI Suggestions:**
- 1-3 dev streams (Back-end, Front-end, Database, etc.)
- Learning type (Pattern, Solution, Error, etc.)
- 3-5 relevant tags (technologies, patterns, concepts)
- Confidence level (high, medium, low)

## Implementation Status

### ❌ Not Yet Implemented

The workflow JSON file will be created during the implementation phase and exported here for version control.

**To implement:**
1. Follow `IMPLEMENTATION_GUIDE.md` in project root
2. Complete Phase 1 (Infrastructure Setup)
3. Complete Phase 2 (Foundational Workflow) - This is where you'll build the visual workflow
4. Use helper functions from `helpers/` directory in appropriate Function nodes
5. Export completed workflow: n8n UI → Workflow Menu → Download → Save as `Knowledge_Repository.json`

## Testing Workflows

### Manual Testing via curl

Once workflow is deployed and ngrok tunnel is running:

```bash
# Set webhook URL
export NOEL_WEBHOOK_URL="https://your-ngrok-url.ngrok.io/webhook"

# Test capture learning
curl -X POST $NOEL_WEBHOOK_URL/capture_learning \
  -H 'Content-Type: application/json' \
  -d '{
    "project": "Noel",
    "title": "Test learning",
    "content": "This is a test learning to verify the system works"
  }'

# Test query
curl -X POST $NOEL_WEBHOOK_URL/query_learnings \
  -H 'Content-Type: application/json' \
  -d '{"query": "test"}'
```

### Using Helper Scripts

Source the helper script and use convenience functions:

```bash
source scripts/noel-helpers.sh
export NOEL_WEBHOOK_URL="https://your-ngrok-url.ngrok.io/webhook"

noel-capture "Noel" "Test" "This is a test"
noel-query "test"
noel-projects
```

See `scripts/noel-helpers.sh` for all available commands.

## Workflow Export/Import

### Exporting Workflow

After making changes in n8n UI:

1. Open workflow in n8n
2. Click workflow menu (three dots)
3. Select "Download"
4. Save to `n8n-workflows/Knowledge_Repository.json`
5. Commit to git

### Importing Workflow

To import on new machine or restore:

1. Open n8n at http://localhost:5678
2. Click "+ Add workflow"
3. Click workflow menu → "Import from File"
4. Select `n8n-workflows/Knowledge_Repository.json`
5. Update database IDs and credentials as needed

**Important:** After import, you must update:
- Notion database IDs in all Notion nodes
- Supabase project URL in all HTTP Request nodes
- Credentials (Notion API, OpenAI, Supabase)

## Troubleshooting

### "Database not found" errors

**Problem:** Notion database IDs don't match your workspace

**Solution:**
1. Get database IDs from Notion URLs
2. Update all Notion nodes in workflow
3. Save and re-activate workflow

### "OpenAI API error"

**Problem:** Invalid API key or rate limit exceeded

**Solution:**
1. Verify OpenAI credentials in n8n
2. Check API key has credits
3. Add delay nodes if hitting rate limits

### "Supabase connection failed"

**Problem:** Invalid project URL or API key

**Solution:**
1. Verify Supabase credentials
2. Check project URL format: `https://[project-ref].supabase.co`
3. Ensure anon key has correct permissions

### Webhook URLs not working

**Problem:** ngrok tunnel changed

**Solution:**
1. Get new ngrok URL: `ngrok http 5678`
2. Update all Webhook Trigger nodes in n8n
3. Update `NOEL_WEBHOOK_URL` environment variable
4. Save and re-activate workflow

## API Contracts

See `specs/001-knowledge-repository/contracts/` for detailed OpenAPI specifications for each endpoint:

- `capture-learning.json` - Learning capture with AI enrichment
- `update-learning.json` - Learning updates and status transitions
- `query-learnings.json` - Semantic search with filters
- `query-feedback.json` - Query relevance feedback submission
- `list-projects.json` - Project catalog queries
- `create-session.json` - Session creation with recording
- `end-session.json` - Session completion
- `query-sessions.json` - Session history retrieval

## Performance Optimization

### Rate Limiting

**Notion API:** 3 requests/second

**Mitigation:**
- Add rate limit node in n8n
- Queue requests with delay nodes
- Batch operations where possible

**OpenAI API:** Varies by tier

**Mitigation:**
- Use gpt-4o-mini (cheaper, faster)
- Cache embeddings (don't regenerate unnecessarily)
- Implement retry logic with exponential backoff

### Error Handling

All endpoints should include:
1. Try-catch wrappers around critical operations
2. Retry logic for transient failures (3 retries with exponential backoff)
3. Clear error messages in responses
4. Logging to n8n execution logs

## Next Steps

1. Complete infrastructure setup (Phase 1) - See `IMPLEMENTATION_GUIDE.md`
2. Build foundational workflow in n8n UI (Phase 2)
3. Implement each user story endpoint (Phases 3-7)
4. Test thoroughly with curl and helper scripts
5. Export final workflow to `Knowledge_Repository.json`
6. Document any customizations in this README

## Resources

- [n8n Documentation](https://docs.n8n.io/)
- [Notion API Reference](https://developers.notion.com/reference)
- [Supabase pgvector Guide](https://supabase.com/docs/guides/ai/vector-embeddings)
- [OpenAI API Docs](https://platform.openai.com/docs/api-reference)

---

**Status:** Ready for implementation. Follow `IMPLEMENTATION_GUIDE.md` to begin.
