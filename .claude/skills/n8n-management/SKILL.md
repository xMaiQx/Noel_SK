---
name: n8n-management
description: This skill should be used when working with n8n workflows, checking execution logs, debugging workflow issues, or managing n8n instances via API. Use this skill when the user asks to check workflow status, view execution history, debug failed workflows, or analyze workflow behavior.
---

# n8n Management Skill

This skill provides direct API access to n8n workflow automation platform for debugging, monitoring, and management tasks.

## When to Use This Skill

Use this skill when:
- Checking execution logs for workflows
- Debugging workflow failures or unexpected behavior
- Verifying which nodes executed in a workflow run
- Listing active workflows and their status
- Finding workflows by name pattern
- Analyzing workflow execution history
- Troubleshooting webhook endpoints

## Available Operations

The skill provides a Python script (`scripts/n8n_api.py`) that communicates with the n8n API. It uses the local n8n instance accessible via ngrok tunnel.

### List Workflows

To see all workflows in the n8n instance:

```bash
python3 .claude/skills/n8n-management/scripts/n8n_api.py list-workflows
```

Returns: Workflow ID, name, and active status for each workflow.

### Find Workflow by Name

To search for a workflow using a name pattern:

```bash
python3 .claude/skills/n8n-management/scripts/n8n_api.py find-workflow "workflow_name"
```

Returns: Full workflow details including ID, name, nodes, and configuration.

### List Executions

To view recent executions (optionally filtered by workflow name):

```bash
# All executions
python3 .claude/skills/n8n-management/scripts/n8n_api.py list-executions

# Executions for specific workflow
python3 .claude/skills/n8n-management/scripts/n8n_api.py list-executions "workflow_name"
```

Returns: Execution ID, workflow name, status, and timestamp for each execution.

### Get Latest Execution

To get the most recent execution for a workflow:

```bash
python3 .claude/skills/n8n-management/scripts/n8n_api.py latest-execution "workflow_name"
```

Returns: Full execution summary including:
- Execution metadata (ID, status, timing)
- List of nodes that executed
- Success/failure status for each node
- Error messages if any nodes failed

### Get Specific Execution

To get detailed information about a specific execution:

```bash
python3 .claude/skills/n8n-management/scripts/n8n_api.py get-execution <execution_id>
```

Returns: Complete execution trace showing which nodes ran and in what order.

### Update Workflow

To update a workflow with new nodes or logic:

```bash
python3 .claude/skills/n8n-management/scripts/n8n_api.py update-workflow <workflow_id> <json_file>
```

**Important**: The JSON file must contain only updatable fields:
- `name` - Workflow name
- `nodes` - Array of workflow nodes
- `connections` - Node connections
- `settings` - Workflow settings

**Read-only fields** (will cause 400 error if included):
- `active` - Workflow active status
- `tags` - Workflow tags
- `id`, `createdAt`, `updatedAt` - System fields

Returns: Updated workflow confirmation with node count.

## Common Debugging Workflows

### Verify Workflow Updates Applied

When a workflow has been updated but behavior seems unchanged:

1. Find the workflow: `find-workflow "workflow_name"`
2. Get latest execution: `latest-execution "workflow_name"`
3. Compare nodes in execution vs workflow definition
4. Check if the correct workflow is active

**Example**: When a workflow shows fewer nodes executing than expected, verify the workflow is active and the latest version is deployed.

### Debug Failed Workflows

When a workflow execution fails:

1. List recent executions: `list-executions "workflow_name"`
2. Get failed execution details: `get-execution <failed_execution_id>`
3. Examine which node failed and error message
4. Check input data to failed node

### Verify Webhook Endpoint Working

When testing webhook endpoints:

1. Trigger webhook via curl/Postman
2. Get latest execution immediately: `latest-execution "workflow_name"`
3. Verify all expected nodes executed successfully
4. Check execution timing to ensure no timeouts

## Advanced Debugging Patterns

### Iterative Debugging Workflow

For complex workflow issues requiring multiple fix attempts, follow this systematic cycle:

1. **Fix code** - Modify workflow JSON locally (Code node logic, connections, etc.)
2. **Upload** - Strip read-only fields and update workflow
3. **Trigger test** - Execute workflow via webhook or manual trigger
4. **Check execution** - Get execution details to identify failures
5. **Analyze error** - Examine error messages and node outputs
6. **Await user input** - Present findings and proposed fix to user
7. **Repeat** - Continue cycle until resolved

**CRITICAL**: Always await user input before repeating the cycle. Present current findings and proposed next steps, then wait for user confirmation or guidance.

**Command pattern for efficiency**:
```bash
# Upload workflow (strip read-only fields first)
jq '{name, nodes, connections, settings}' workflow.json > /tmp/upload.json && \
python3 .claude/skills/n8n-management/scripts/n8n_api.py update-workflow <workflow_id> /tmp/upload.json

# Trigger test (example webhook)
curl --location 'https://webhook-url' --max-time 15

# Wait for execution to complete
sleep 3

# Check results
python3 .claude/skills/n8n-management/scripts/n8n_api.py latest-execution "workflow_name"
```

### Adding Debug Instrumentation to Code Nodes

When workflow behavior is unclear, add debug logging directly in Code nodes:

**Console logging**:
```javascript
// Add at key points in Code nodes
console.log("DEBUG - Variable name:", JSON.stringify(data, null, 2));
console.log("DEBUG - Processing item:", itemIndex, "/", totalItems);
```

**Enhanced error messages**:
```javascript
// Before: Generic error
if (!data) throw new Error("Missing data");

// After: Detailed error with context
if (!data) {
  throw new Error(`Missing data: received ${typeof data}, expected object. Input: ${JSON.stringify($input.item.json)}`);
}
```

**Validation with debug output**:
```javascript
// Add type and value information
const value = data?.field;
const valueType = typeof value;

if (!value) {
  throw new Error(`Invalid field: value="${value}" type="${valueType}" fullData="${JSON.stringify(data)}"`);
}
```

### Stripping Read-Only Fields for Upload

The n8n API rejects workflow updates containing read-only fields. Always strip these before uploading:

**Using jq** (recommended):
```bash
jq '{name, nodes, connections, settings}' workflow.json > /tmp/upload.json
```

**Read-only fields to remove**:
- `id`, `createdAt`, `updatedAt` - System fields
- `active` - Workflow active status
- `tags` - Workflow tags
- `versionId`, `versionCounter` - Version metadata
- `shared`, `homeProject` - Sharing metadata

**Example error when not stripped**:
```
HTTP Error 400: {"message":"request/body must NOT have additional properties"}
```

### Chained Commands for Efficient Debugging

Combine multiple operations to reduce iteration time:

**Pattern 1: Upload → Test → Check**:
```bash
jq '{name, nodes, connections, settings}' workflow.json > /tmp/upload.json && \
python3 .claude/skills/n8n-management/scripts/n8n_api.py update-workflow <id> /tmp/upload.json && \
curl <webhook-url> --max-time 15 >/dev/null 2>&1 && \
sleep 3 && \
python3 .claude/skills/n8n-management/scripts/n8n_api.py latest-execution "workflow_name"
```

**Pattern 2: Multiple parallel checks**:
```bash
# Check multiple recent executions
python3 .claude/skills/n8n-management/scripts/n8n_api.py list-executions | head -10
```

**Pattern 3: Conditional execution**:
```bash
# Only proceed if upload succeeds
python3 .claude/skills/n8n-management/scripts/n8n_api.py update-workflow <id> /tmp/upload.json && \
echo "✓ Upload successful, triggering test..." && \
curl <webhook-url>
```

## Common Gotchas and Solutions

### API Wrapper Behavior

When using Execute Workflow nodes to call API wrapper workflows:

**Issue**: Custom fields in the input are stripped in the response.

**Example**:
```javascript
// Send to API wrapper
{
  query: {...},
  body: {...},
  _custom_data: {...}  // Custom field
}

// Receive from API wrapper
{
  results: [...]  // Only API response, _custom_data is lost!
}
```

**Solution**: Use node references to preserve data:
```javascript
// In downstream nodes, reference back to original data
const originalData = $('Source Node Name').first().json;
const apiResult = $input.item.json;

return {
  json: {
    ...originalData,  // Restore custom data
    api_result: apiResult
  }
};
```

### Item Pairing Through Sub-Workflows

**Issue**: After calling Execute Workflow nodes, item pairing is lost. Cannot use `$('Node Name').item.json` to reference items from before the sub-workflow call.

**Error message**:
```
Paired item data for item from node 'X' is unavailable
```

**Solution**: Use `.first()` or `.all()` instead of `.item`:
```javascript
// DON'T: Breaks after Execute Workflow
const data = $('Parse Data').item.json;

// DO: Use .first() for single-item context
const data = $('Parse Data').first().json;

// OR: Use .all() and match by index/identifier
const allData = $('Parse Data').all();
const data = allData.find(item => item.json.id === currentId);
```

### Read-Only Field Upload Errors

**Issue**: Workflow updates fail with 400 errors about "additional properties".

**Common causes**:
1. Including `active`, `tags`, `id` fields in update JSON
2. Using full workflow export without stripping metadata
3. Including version or sharing fields

**Prevention**:
Always use jq to extract only updatable fields before upload:
```bash
jq '{name, nodes, connections, settings}' full_workflow.json > upload.json
```

### Debugging Data Flow Issues

When data isn't flowing correctly through nodes:

1. **Add interim output nodes**: Insert Set nodes to inspect data structure
2. **Check item counts**: Verify expected number of items at each step
3. **Compare working workflows**: Find similar working workflow and diff the logic
4. **Trace backwards**: Start from failing node and work backwards to source

**Example debugging workflow**:
```
Source → [Add Debug Output] → Transform → [Add Debug Output] → Failing Node
```

## Technical Details

**API Configuration**:
- Base URL: Configured in script (update `N8N_BASE_URL` variable when ngrok restarts)
- Authentication: X-N8N-API-KEY header
- API Key: Configured in script (update `API_KEY` variable)

**Script Location**: `.claude/skills/n8n-management/scripts/n8n_api.py`

**Setup**: Update the script's configuration variables with your ngrok URL and API key:
```python
N8N_BASE_URL = "https://your-ngrok-url.ngrok-free.app"
API_KEY = "your-api-key-here"
```

**No Dependencies**: Uses Python standard library (urllib) only - no pip install required.

## Limitations

- Requires ngrok tunnel to be running
- API key and ngrok URL must be updated in script when ngrok restarts
- Limited to n8n v1 API endpoints

## Project Workflows

Key Briseno workflows documented in `references/briseno-workflows.md`:
- `Briseno_ProductivityCoach_v2` - Main agent workflow with Telegram interface
- `Log_Agent_Outputs` - Usage and cost tracking
- Multi-agent workflows (Calendar, Email, Projects, Research agents)

For detailed architecture, tech stack, and patterns, see the references file.

Always check execution logs after testing new workflow logic to ensure all nodes executed as expected.

---

## Workflow Development Best Practices

### Successful Development Cycle (Proven Pattern)

Based on successful Clientes v2 API workflow migration, follow this systematic approach:

**The Golden Loop**:
```
1. Fix code (locally in workflow JSON)
2. Upload (strip read-only fields with jq)
3. Trigger test (via webhook or manual execution)
4. Check execution (get-execution or latest-execution)
5. Analyze error (examine node outputs, error messages)
6. Present findings to user (show what failed, proposed fix)
7. AWAIT USER INPUT (confirm approach before repeating)
8. Repeat from step 1
```

**Critical Rule**: ALWAYS pause at step 6-7 and wait for user confirmation before making the next fix attempt. Never auto-loop without user input.

### Incremental Problem Solving

**DO**:
- ✅ Fix ONE issue per iteration
- ✅ Test after each fix
- ✅ Add debug logging to understand data flow
- ✅ Compare with working workflows
- ✅ Validate assumptions with user

**DON'T**:
- ❌ Fix multiple issues at once
- ❌ Make bulk changes without testing
- ❌ Assume solutions without verification
- ❌ Continue iterating without user input

### Debug Instrumentation Patterns

**Console Logging**:
```javascript
// At decision points
console.log("DEBUG - Variable:", JSON.stringify(data, null, 2));
console.log("DEBUG - Type:", typeof value, "Value:", value);

// Before API calls
console.log("DEBUG - Sending to API:", endpoint, body);

// After data transformations
console.log("DEBUG - Transformed:", before, "→", after);
```

**Enhanced Error Messages**:
```javascript
// Bad: Generic error
if (!data) throw new Error("Missing data");

// Good: Context-rich error
if (!data) {
  throw new Error(
    `Missing data: ` +
    `received=${typeof data} ` +
    `expected=object ` +
    `source=${JSON.stringify($input.item.json)}`
  );
}
```

**Validation with Debug Fields**:
```javascript
return {
  json: {
    ...actualData,
    _debug_count: items.length,
    _debug_type: typeof result,
    _debug_source: nodeName
  }
};
```

### Data Preservation Strategies

**Option A: Self-Contained Items** (Recommended)
```javascript
// Add necessary data to each item
return items.map(item => ({
  ...item,
  poliza_id: sharedData.poliza_id,
  metadata: sharedData.metadata
}));

// Later: Access directly
const polizaId = $json.poliza_id;  // ✅ Simple, reliable
```

**Option B: Node References** (Use with caution)
```javascript
// Reference data from earlier nodes
const originalData = $('Source Node').first().json;

// Issues:
// - Breaks if node renamed
// - Item pairing lost after sub-workflows
// - Hard to debug
```

**When to use each**:
- Use Option A for data needed throughout the workflow
- Use Option B only when data is too large to duplicate
- Always document which approach is used

### Comparative Analysis

**When stuck**, compare with working workflows:

```bash
# Find similar working workflow
python3 .claude/skills/n8n-management/scripts/n8n_api.py list-workflows | grep Similar

# Download both workflows
python3 .claude/skills/n8n-management/scripts/n8n_api.py find-workflow "Working" > /tmp/working.json
python3 .claude/skills/n8n-management/scripts/n8n_api.py find-workflow "Broken" > /tmp/broken.json

# Compare specific nodes
diff <(jq '.nodes[] | select(.name == "Search")' /tmp/working.json) \
     <(jq '.nodes[] | select(.name == "Search")' /tmp/broken.json)
```

**Key comparison points**:
1. Node parameter structure
2. Connection patterns
3. Data transformation logic
4. API request formats

### Command Efficiency Patterns

**Pattern 1: Upload → Test → Check**
```bash
jq '{name, nodes, connections, settings}' workflow.json > /tmp/upload.json && \
python3 .claude/skills/n8n-management/scripts/n8n_api.py update-workflow <id> /tmp/upload.json && \
echo "✓ Uploaded, testing..." && \
curl <webhook-url> --max-time 15 >/dev/null 2>&1 && \
sleep 3 && \
python3 .claude/skills/n8n-management/scripts/n8n_api.py latest-execution "workflow_name"
```

**Pattern 2: Quick iteration**
```bash
# Fix → Upload → Test in one go
jq '.nodes[] | select(.name == "Node") | .parameters.jsCode = $newcode' workflow.json | \
jq '{name, nodes, connections, settings}' > /tmp/upload.json && \
python3 .claude/skills/n8n-management/scripts/n8n_api.py update-workflow <id> /tmp/upload.json && \
curl <webhook-url>
```

**Pattern 3: Parallel investigation**
```bash
# Check multiple executions at once
for id in 5590 5591 5592; do
  echo "=== Execution $id ===" &&
  python3 .claude/skills/n8n-management/scripts/n8n_api.py get-execution $id | grep -A3 Error
done
```

### Problem Classification

**Type 1: Data Flow Issues**
- Symptom: Data not reaching expected nodes
- Debug: Add console.log at each step
- Fix: Check node connections, verify data structure

**Type 2: Property Name Mismatches**
- Symptom: "property X does not exist" errors
- Debug: Query database schema directly
- Fix: Update property names to match database

**Type 3: Node Reference Errors**
- Symptom: "Referenced node doesn't exist" or "Paired item unavailable"
- Debug: Check node names, verify connections
- Fix: Use .first() instead of .item, or switch to Option A

**Type 4: API Format Errors**
- Symptom: 400 errors from API calls
- Debug: Compare request format with working examples
- Fix: Match API wrapper expected format (query + body structure)

**Type 5: Conditional Logic Errors**
- Symptom: Wrong branch taken in IF nodes
- Debug: Add debug fields, check actual values vs expected
- Fix: Verify condition type (string/number/boolean), check branch connections

### Testing Strategy

**Before testing**:
1. Clear previous test data if needed
2. Verify prerequisites (poliza exists, database accessible)
3. Document expected behavior

**During testing**:
1. Trigger test
2. Monitor execution in real-time (n8n UI or logs)
3. Note which nodes succeed/fail
4. Capture error messages completely

**After testing**:
1. Check execution logs systematically
2. Verify data in databases
3. Document what worked/what failed
4. Propose specific fix for ONE issue

### Common Pitfalls to Avoid

1. **Auto-looping**: Never iterate fixes without user confirmation
2. **Bulk changes**: Don't fix everything at once
3. **Assumption stacking**: Verify each assumption before building on it
4. **Ignoring working examples**: Always check similar working workflows
5. **Missing debug output**: Add logging before assuming behavior
6. **Manual UI changes**: If making changes in n8n UI, download workflow before uploading code changes (or manual changes get overwritten)

### Session Wrap-Up Checklist

Before ending a development session:

- [ ] Document current state (what works, what doesn't)
- [ ] Save working workflow JSON locally
- [ ] Note any provisional solutions (e.g., provisional RFC generation)
- [ ] List remaining issues for next session
- [ ] Update skill documentation with new learnings
- [ ] Clear test data if needed

### Success Metrics

A workflow is production-ready when:
- ✅ All nodes execute successfully
- ✅ All array items processed (not just first)
- ✅ Error handling covers edge cases
- ✅ Debug logging can be safely removed
- ✅ No provisional workarounds remain
- ✅ End-to-end test passes with real data
