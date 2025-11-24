---
name: notion-api-querying
description: This skill should be used when querying Notion databases through the n8n webhook wrapper. Provides critical patterns for data source queries vs database retrieval, error handling, and Python script debugging.
license: MIT
---

# Notion API Querying

This skill provides battle-tested patterns for querying Notion databases through n8n webhook wrappers.

## Critical Distinction: Data Sources vs Databases

### Database vs Data Source IDs

Every Notion database has **TWO** IDs:
- **Database ID**: Used for metadata operations (retrieve schema, create database)
- **Data Source ID**: Used for querying records (query pages, filter data)

**Example:**
```bash
# Example Database
VITE_NOTION_EXAMPLE_DB=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx    # Database ID
VITE_NOTION_EXAMPLE_DS=yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy    # Data Source ID ✓ Use this for queries
```

**Note**: Replace placeholder IDs with actual values from your project's environment configuration.

### When to Use Each

| Operation | Endpoint | Use ID Type | Example |
|-----------|----------|-------------|---------|
| **Query records** | `query_data_source` | Data Source ID | Get all records, apply filters |
| **Retrieve schema** | `retrieve_database` | Database ID | Check what fields exist |
| **Create database** | `create_database` | N/A | Create new database |
| **Update database** | `update_database` | Database ID | Add new field to schema |

## Common Patterns

### Pattern 1: Query Records from Database

**✓ CORRECT - Use Data Source ID:**
```bash
curl -X POST $NGROK_URL/webhook/notion_api_wrapper \
  -H 'Content-Type: application/json' \
  -H "Authorization: $AUTH_TOKEN" \
  -d '{
    "query": {
      "endpoint": "query_data_source",
      "id": "YOUR_DATA_SOURCE_ID"
    },
    "body": {
      "page_size": 10
    }
  }'
```

**✗ WRONG - Using Database ID returns empty:**
```bash
# This will fail or return no records!
"id": "YOUR_DATABASE_ID"  # Wrong ID type for queries
```

### Pattern 2: Check Schema (Fields) Without Data

**Use retrieve_database with Database ID:**
```bash
curl -X POST $NGROK_URL/webhook/notion_api_wrapper \
  -H 'Content-Type: application/json' \
  -H "Authorization: $AUTH_TOKEN" \
  -d '{
    "query": {
      "endpoint": "retrieve_database",
      "id": "YOUR_DATABASE_ID"
    },
    "body": {}
  }'
```

### Pattern 3: Analyze Field Structure from Query Results

When a database is empty or you can't retrieve schema, query 1 record to see fields:

```bash
curl -X POST $NGROK_URL/webhook/notion_api_wrapper \
  -H 'Content-Type: application/json' \
  -H "Authorization: $AUTH_TOKEN" \
  -d '{"query":{"endpoint":"query_data_source","id":"YOUR_DATA_SOURCE_ID"},"body":{"page_size":1}}' \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)[0]
if data.get('results'):
    fields = list(data['results'][0]['properties'].keys())
    print('Fields:', fields)
"
```

## Python Script Anti-Patterns

### Anti-Pattern 1: Inline Python with Shell Variables

**✗ WRONG - Shell variables don't expand in Python heredoc:**
```bash
curl ... | python3 << 'EOF'
import json, sys
data = json.load(sys.stdin)[0]  # This tries to read from stdin BEFORE curl output arrives
EOF
```

**✓ CORRECT - Use file or pipe:**
```bash
# Option A: Save script to file
cat > /tmp/script.py << 'EOF'
import json, sys
data = json.load(sys.stdin)[0]
print(data)
EOF

curl ... | python3 /tmp/script.py

# Option B: Use -c with proper piping
curl ... 2>/dev/null | python3 -c "import json,sys; data=json.load(sys.stdin)[0]; print(data)"
```

### Anti-Pattern 2: Forgetting 2>/dev/null

**✗ WRONG - curl progress bar pollutes JSON:**
```bash
curl ... | python3 -c "import json,sys; ..."
# Error: JSONDecodeError because curl outputs progress to stderr
```

**✓ CORRECT - Suppress curl progress:**
```bash
curl ... 2>/dev/null | python3 -c "..."
```

### Anti-Pattern 3: Single Quotes in -d Parameter

**✗ WRONG - Bash tries to interpolate:**
```bash
curl -X POST https://example.com \
  -d '{"query":{"endpoint":"query_data_source","id":"$DATA_SOURCE_ID"}}'
# $DATA_SOURCE_ID won't expand in single quotes
```

**✓ CORRECT - Use proper JSON escaping:**
```bash
# Option A: Double quotes with escaped inner quotes
curl -d "{\"query\":{\"id\":\"$DATA_SOURCE_ID\"}}"

# Option B: Single quotes with concatenation
curl -d '{"query":{"id":"'"$DATA_SOURCE_ID"'"}}'

# Option C: Heredoc (cleanest for complex JSON)
curl -d @- << EOF
{
  "query": {
    "id": "$DATA_SOURCE_ID"
  }
}
EOF
```

## Debugging Checklist

When queries return unexpected results:

- [ ] **Verify ID type**: Data Source ID for queries, Database ID for schema
- [ ] **Check endpoint**: `query_data_source` vs `retrieve_database`
- [ ] **Inspect response structure**: Does it have `results` array?
- [ ] **Test with page_size=1**: Reduce noise when checking schema
- [ ] **Save to file**: `curl ... > output.json` then `cat output.json | jq`
- [ ] **Check empty results**: Database might be empty (not an error)
- [ ] **Verify auth token**: Must match n8n webhook configuration

## Environment Variables Reference

```bash
# Development (ngrok - changes on restart)
NGROK_URL="https://[your-ngrok-url].ngrok-free.app"
export N8N_BASE_URL="$NGROK_URL"

# Authentication (from n8n webhook configuration)
AUTH_TOKEN="your-auth-token-here"

# Project-Specific Data Source IDs
# Add your database IDs here as you discover them
# Example:
# EXAMPLE_DATABASE_DS="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

## Real-World Example: Field Discovery

**Goal**: Find all fields in a database

**Step 1: Find correct Data Source ID**
```bash
# Check your environment configuration for database IDs
grep "NOTION.*_DS" .env
# Look for the _DS suffix - that's your Data Source ID
```

**Step 2: Query with page_size=1**
```bash
curl -X POST $NGROK_URL/webhook/notion_api_wrapper \
  -H 'Content-Type: application/json' \
  -H "Authorization: $AUTH_TOKEN" \
  -d '{"query":{"endpoint":"query_data_source","id":"YOUR_DATA_SOURCE_ID"},"body":{"page_size":1}}' \
  2>/dev/null | python3 -m json.tool | grep -A 1 '"properties"'
```

**Step 3: Parse field names**
```bash
curl ... 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)[0]
if data.get('results'):
    fields = sorted(data['results'][0]['properties'].keys())
    print('\n'.join(fields))
"
```

## Error Messages & Solutions

### "JSONDecodeError: Expecting value: line 1 column 1 (char 0)"

**Cause**: Python received curl progress output instead of JSON

**Solution**: Add `2>/dev/null` to curl OR use `-s` flag:
```bash
curl -s ...  # Silent mode
# OR
curl ... 2>/dev/null  # Suppress stderr
```

### "No data in [Database] database"

**Cause**: Database is empty (not an error) OR wrong ID type

**Solution**:
1. Try with Database ID on `retrieve_database` to check if DB exists
2. Verify you're using Data Source ID, not Database ID

### "results": [] but database has records

**Cause**: Using Database ID instead of Data Source ID

**Solution**: Switch to Data Source ID (the one with `_DS` suffix in `.env`)

## Quick Reference Card

```bash
# List all fields in a database
curl -X POST $NGROK_URL/webhook/notion_api_wrapper \
  -H 'Content-Type: application/json' \
  -H "Authorization: $AUTH_TOKEN" \
  -d '{"query":{"endpoint":"query_data_source","id":"YOUR_DATA_SOURCE_ID"},"body":{"page_size":1}}' \
  2>/dev/null | python3 -c "import json,sys; data=json.load(sys.stdin)[0]; print('\n'.join(sorted(data['results'][0]['properties'].keys())) if data.get('results') else 'Empty database')"

# Check if specific field exists
curl ... | python3 -c "import json,sys; data=json.load(sys.stdin)[0]; print('field_name' in data['results'][0]['properties'])"

# Count records
curl -d '{"query":{"endpoint":"query_data_source","id":"YOUR_DATA_SOURCE_ID"},"body":{}}' ... \
  | python3 -c "import json,sys; print(f\"Total: {len(json.load(sys.stdin)[0]['results'])}\")"
```

## Project-Specific Learnings

This section will be updated as you discover patterns specific to your Notion setup.

**Template for adding learnings:**
```markdown
### Discovery: [Brief Title]

**Issue**: [What problem was encountered]

**Solution**: [How it was resolved]

**Lesson**: [Key takeaway for future reference]
```

---

## When to Use This Skill

- When querying Notion databases returns unexpected empty results
- When Python scripts fail with JSONDecodeError
- When unsure whether to use Database ID or Data Source ID
- When debugging n8n webhook API responses
- When adding new database fields and verifying schema

## Related Documentation

Add links to your project's documentation here:
- Environment configuration files
- Database schema documentation
- n8n webhook endpoint registry
