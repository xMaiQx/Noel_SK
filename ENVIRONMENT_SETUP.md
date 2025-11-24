# Noel Environment Setup Guide

This guide walks you through setting up the environment for the `notion-api-querying` skill and other Noel tools.

---

## Quick Start

```bash
# 1. Extract Notion Database IDs
./scripts/get-notion-ids.sh

# 2. Edit .env file with your credentials
nano .env

# 3. Load environment
source scripts/setup-env.sh

# 4. Test connection
./scripts/test-notion-connection.sh
```

---

## Detailed Setup

### Step 1: Get Your n8n Authentication Token

Your n8n webhook needs authentication. To get/set the auth token:

**Option A: If you haven't set it up yet:**
1. Open n8n workflow
2. Add a Webhook node
3. In "Authentication" section, select "Header Auth"
4. Set header name: `Authorization`
5. Set header value: Choose a secure token (e.g., generate with `openssl rand -hex 32`)
6. Copy this token to use in `.env`

**Option B: If already configured:**
1. Open your n8n workflow
2. Find existing Webhook node
3. Check "Authentication" settings
4. Copy the configured token

### Step 2: Extract Notion Database IDs

Run the interactive script:

```bash
./scripts/get-notion-ids.sh
```

For each database (Projects, Learnings, Sessions):
1. Open the database in Notion
2. Click "..." menu → "Copy link"
3. Paste the URL when prompted
4. Script extracts the Database ID

**Example:**
```
URL: https://www.notion.so/username/My-Database-a1b2c3d4e5f67890a1b2c3d4e5f67890?v=...
Database ID: a1b2c3d4-e5f6-7890-a1b2-c3d4e5f67890
```

### Step 3: Configure .env File

Open the `.env` file:

```bash
nano .env
```

**Minimal configuration to start:**

```bash
# n8n Configuration (REQUIRED)
NGROK_URL="https://9e527c57b6c1.ngrok-free.app"  # Auto-detected, update if ngrok restarts
AUTH_TOKEN="your_webhook_auth_token_here"        # From Step 1

# Notion Database IDs (REQUIRED for database verification)
NOTION_PROJECTS_DB="your-projects-db-id"         # From Step 2
NOTION_LEARNINGS_DB="your-learnings-db-id"       # From Step 2
NOTION_SESSIONS_DB="your-sessions-db-id"         # From Step 2

# Data Source IDs (Can add later - get from n8n)
# Leave as placeholders for now, will update after n8n setup
NOTION_PROJECTS_DS="YOUR_PROJECTS_DATA_SOURCE_ID_HERE"
NOTION_LEARNINGS_DS="YOUR_LEARNINGS_DATA_SOURCE_ID_HERE"
NOTION_SESSIONS_DS="YOUR_SESSIONS_DATA_SOURCE_ID_HERE"
```

**Full configuration (for later):**

```bash
# Supabase (Needed for vector search - Phase 2)
SUPABASE_URL="https://your-project.supabase.co"
SUPABASE_ANON_KEY="your-anon-key"

# OpenAI (Needed for AI enrichment - Phase 2)
OPENAI_API_KEY="sk-..."
```

### Step 4: Load Environment

Source the environment setup script:

```bash
source scripts/setup-env.sh
```

This script:
- ✅ Loads all variables from `.env`
- ✅ Validates required configuration
- ✅ Shows configuration status
- ✅ Exports helper functions

You should see:

```
✓ .env file loaded
✓ NGROK_URL configured
✓ AUTH_TOKEN configured
✓ All required variables configured
Environment ready!
```

### Step 5: Test Notion Connection

Once you have n8n running with the Notion API wrapper webhook:

```bash
./scripts/test-notion-connection.sh
```

This tests:
- ✅ Connection to n8n via ngrok
- ✅ Authentication working
- ✅ Each Notion database accessible
- ✅ Database schemas retrieved

---

## Understanding Notion IDs

Notion databases have **TWO** IDs you need to know about:

### Database ID (DB)
- **Used for**: Schema operations (`retrieve_database`, `update_database`)
- **Get from**: Notion database URL
- **Format**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- **Example**: `a1b2c3d4-e5f6-7890-a1b2-c3d4e5f67890`

### Data Source ID (DS)
- **Used for**: Querying records (`query_data_source`)
- **Get from**: n8n Notion node when connecting a database
- **Format**: Same as Database ID but different value
- **Example**: `f9e8d7c6-b5a4-3210-f9e8-d7c6b5a43210`

**Critical Pattern from `notion-api-querying` skill:**

```bash
# ✓ CORRECT - Query records (use Data Source ID)
curl -X POST $NGROK_URL/webhook/notion_api_wrapper \
  -H "Authorization: $AUTH_TOKEN" \
  -d '{"query":{"endpoint":"query_data_source","id":"DATA_SOURCE_ID"}}'

# ✗ WRONG - Using Database ID returns empty results
curl ... -d '{"query":{"endpoint":"query_data_source","id":"DATABASE_ID"}}'
```

### How to Get Data Source IDs

**Method 1: From n8n (Recommended)**
1. In n8n, add a Notion node
2. Select "Get Many" operation
3. Choose your database
4. Look at the database dropdown - the ID shown is the Data Source ID
5. Copy this ID to your `.env` file

**Method 2: From API Response**
1. Use the Database ID to retrieve schema
2. Inspect the response for the `id` field in the data source
3. Update `.env` with this value

---

## Helper Functions

After running `source scripts/setup-env.sh`, you get these helpers:

### `update-ngrok-url`

Automatically updates ngrok URL when it changes:

```bash
update-ngrok-url
```

Output:
```
Old URL: https://abc123.ngrok-free.app
New URL: https://xyz789.ngrok-free.app
✓ ngrok URL updated
```

---

## Common Workflows

### Daily Development Workflow

```bash
# 1. Start ngrok (if not running)
ngrok http 5678

# 2. Update ngrok URL if it changed
source scripts/setup-env.sh
update-ngrok-url  # Only if ngrok restarted

# 3. Load Noel helpers
source scripts/noel-helpers.sh

# 4. Start working!
noel-help  # See available commands
```

### After ngrok Restarts

```bash
# Quick update
source scripts/setup-env.sh
update-ngrok-url

# Verify connection
./scripts/test-notion-connection.sh
```

### Verifying Database Setup

```bash
# Load environment
source scripts/setup-env.sh

# Test connection
./scripts/test-notion-connection.sh

# Should see:
# ✓ Projects: Connected - Projects (X fields)
# ✓ Learnings: Connected - Learnings (X fields)
# ✓ Sessions: Connected - Sessions (X fields)
```

---

## Troubleshooting

### "NGROK_URL not configured"

```bash
# Check if .env exists
ls -la .env

# If missing, it was created at project root:
cat .env

# Load it:
source scripts/setup-env.sh
```

### "AUTH_TOKEN not configured"

1. Open `.env` file
2. Find `AUTH_TOKEN="YOUR_AUTH_TOKEN_HERE"`
3. Replace with your actual n8n webhook auth token
4. Save and reload: `source scripts/setup-env.sh`

### "Notion database connection failed"

**Check 1: Is n8n running?**
```bash
# Test n8n access
curl -s $NGROK_URL
```

**Check 2: Is the Notion API wrapper webhook active?**
- Open n8n
- Find workflow with `/webhook/notion_api_wrapper` endpoint
- Ensure workflow is "Active"

**Check 3: Are Database IDs correct?**
```bash
# Verify Database IDs in .env
grep "NOTION_.*_DB=" .env

# Should NOT see "YOUR_..._HERE"
# Should see actual UUIDs
```

### ngrok URL changes too often

**Solution 1: Use ngrok authtoken**
```bash
ngrok authtoken YOUR_AUTH_TOKEN
```
This gives you a stable subdomain.

**Solution 2: Use `update-ngrok-url` helper**
```bash
source scripts/setup-env.sh
update-ngrok-url  # Automatically updates .env
```

---

## Security Notes

### ⚠️ Never Commit .env File

The `.gitignore` is already configured to exclude `.env`, but always verify:

```bash
git status  # Should NOT show .env as tracked
```

### 🔒 Keep Auth Token Secret

- Never share your `AUTH_TOKEN`
- Rotate it periodically
- Use a strong token (32+ hex characters)

### 🔑 Notion Integration Token

If using Notion API directly (not through n8n):
1. Create internal integration at https://www.notion.so/my-integrations
2. Share databases with the integration
3. Use integration token in n8n Notion nodes

---

## Next Steps

Once environment is configured:

1. **Verify Notion databases match spec**:
   - Use `notion-api-querying` skill to check schemas
   - Ensure all required fields exist
   - Validate field types

2. **Set up Supabase**:
   - Run `scripts/supabase/setup-vector-database.sql`
   - Add Supabase credentials to `.env`

3. **Build n8n workflow**:
   - Use n8n-management skill for automation
   - Paste JavaScript helpers from `n8n-workflows/helpers/`
   - Test with `scripts/test-endpoints.sh`

4. **Start using Noel**:
   - Source `scripts/noel-helpers.sh`
   - Run `noel-help` to see commands
   - Start capturing learnings!

---

## Reference

**Environment Files**:
- `.env` - Main configuration (git-ignored)
- `scripts/setup-env.sh` - Environment loader
- `scripts/get-notion-ids.sh` - Database ID extractor
- `scripts/test-notion-connection.sh` - Connection tester

**Helper Scripts**:
- `scripts/noel-helpers.sh` - CLI integration (10 functions)
- `scripts/test-endpoints.sh` - Endpoint testing

**Skills**:
- `.claude/skills/notion-api-querying/` - Notion patterns
- `.claude/skills/n8n-management/` - n8n API management
- `.claude/skills/skill-creator/` - Skill development

---

**Questions?** Check `IMPLEMENTATION_STATUS.md` for overall project status or specific skill documentation in `.claude/skills/*/SKILL.md`.
