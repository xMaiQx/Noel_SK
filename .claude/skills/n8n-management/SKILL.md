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
