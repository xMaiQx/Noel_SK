#!/usr/bin/env python3
"""
n8n API Helper Script
Provides direct access to n8n API for workflow and execution management
"""

import urllib.request
import urllib.parse
import urllib.error
import json
import sys
import os
from pathlib import Path
from typing import Optional, Dict, List

# Load .env file manually
def load_env():
    """Load environment variables from .env file"""
    # From .claude/skills/n8n-management/scripts/ go up 5 levels to project root
    env_path = Path(__file__).parent.parent.parent.parent.parent / '.env'
    if env_path.exists():
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    # Remove quotes
                    value = value.strip('"').strip("'")
                    # Skip variable expansion for now
                    if not value.startswith('${'):
                        os.environ[key] = value

load_env()

N8N_BASE_URL = os.getenv('NGROK_URL', 'https://your-ngrok-url.ngrok-free.app')
API_KEY = os.getenv('N8N_API_KEY', 'your-n8n-api-key-here')

def _make_request(url: str, method: str = "GET", data: Optional[Dict] = None) -> Dict:
    """Make HTTP request to n8n API"""
    headers = {
        "X-N8N-API-KEY": API_KEY,
        "Content-Type": "application/json"
    }

    req = urllib.request.Request(url, headers=headers, method=method)
    if data:
        req.data = json.dumps(data).encode('utf-8')

    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8')
        print(f"HTTP Error {e.code}: {error_body}")
        raise

def list_workflows() -> List[Dict]:
    """List all workflows"""
    data = _make_request(f"{N8N_BASE_URL}/api/v1/workflows")
    return data.get("data", [])

def get_workflow(workflow_id: str) -> Dict:
    """Get workflow details by ID"""
    return _make_request(f"{N8N_BASE_URL}/api/v1/workflows/{workflow_id}")

def update_workflow(workflow_id: str, workflow_data: Dict) -> Dict:
    """Update a workflow by ID"""
    return _make_request(f"{N8N_BASE_URL}/api/v1/workflows/{workflow_id}", method="PUT", data=workflow_data)

def list_executions(workflow_id: Optional[str] = None, limit: int = 20) -> List[Dict]:
    """List executions, optionally filtered by workflow ID"""
    params = {"limit": str(limit)}
    if workflow_id:
        params["workflowId"] = workflow_id

    query_string = urllib.parse.urlencode(params)
    url = f"{N8N_BASE_URL}/api/v1/executions?{query_string}"
    data = _make_request(url)
    return data.get("data", [])

def get_execution(execution_id: str, include_data: bool = True) -> Dict:
    """Get execution details by ID"""
    url = f"{N8N_BASE_URL}/api/v1/executions/{execution_id}"
    if include_data:
        url += "?includeData=true"
    return _make_request(url)

def find_workflow_by_name(name_pattern: str) -> Optional[Dict]:
    """Find workflow by name pattern (case-insensitive substring match)"""
    workflows = list_workflows()
    name_pattern_lower = name_pattern.lower()

    for workflow in workflows:
        if name_pattern_lower in workflow.get("name", "").lower():
            return workflow
    return None

def get_latest_execution(workflow_name: str) -> Optional[Dict]:
    """Get the most recent execution for a workflow by name"""
    workflow = find_workflow_by_name(workflow_name)
    if not workflow:
        return None

    executions = list_executions(workflow_id=workflow["id"], limit=1)
    return executions[0] if executions else None

def print_execution_summary(execution: Dict):
    """Print a human-readable summary of an execution"""
    print(f"\n{'='*80}")
    print(f"Execution ID: {execution.get('id')}")
    print(f"Workflow: {execution.get('workflowName', 'Unknown')}")
    print(f"Status: {execution.get('status', 'Unknown')}")
    print(f"Started: {execution.get('startedAt', 'Unknown')}")
    print(f"Stopped: {execution.get('stoppedAt', 'Unknown')}")
    print(f"Mode: {execution.get('mode', 'Unknown')}")
    print(f"{'='*80}\n")

    # Print node execution details
    if "data" in execution and "resultData" in execution["data"]:
        runs = execution["data"]["resultData"].get("runData", {})
        print(f"Nodes executed: {len(runs)}")
        for node_name, node_runs in runs.items():
            if node_runs:
                last_run = node_runs[-1]
                status = "✓ Success" if not last_run.get("error") else "✗ Error"
                print(f"  {status} - {node_name}")
                if last_run.get("error"):
                    print(f"    Error: {last_run['error'].get('message', 'Unknown error')}")

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python n8n_api.py list-workflows")
        print("  python n8n_api.py list-executions [workflow_name]")
        print("  python n8n_api.py get-execution <execution_id>")
        print("  python n8n_api.py latest-execution <workflow_name>")
        print("  python n8n_api.py find-workflow <name_pattern>")
        print("  python n8n_api.py update-workflow <workflow_id> <json_file>")
        sys.exit(1)

    command = sys.argv[1]

    try:
        if command == "list-workflows":
            workflows = list_workflows()
            print(f"Found {len(workflows)} workflows:")
            for w in workflows:
                print(f"  {w['id']}: {w['name']} (active: {w['active']})")

        elif command == "list-executions":
            workflow_name = sys.argv[2] if len(sys.argv) > 2 else None
            workflow_id = None

            if workflow_name:
                workflow = find_workflow_by_name(workflow_name)
                if not workflow:
                    print(f"Workflow not found: {workflow_name}")
                    sys.exit(1)
                workflow_id = workflow["id"]
                print(f"Executions for workflow: {workflow['name']}")

            executions = list_executions(workflow_id=workflow_id)
            print(f"Found {len(executions)} executions:")
            for e in executions:
                print(f"  {e['id']}: {e.get('workflowName', 'unknown')} - {e.get('status', 'unknown')} - {e.get('startedAt', '')}")

        elif command == "get-execution":
            if len(sys.argv) < 3:
                print("Error: execution_id required")
                sys.exit(1)
            execution_id = sys.argv[2]
            execution = get_execution(execution_id)
            print_execution_summary(execution)

        elif command == "latest-execution":
            if len(sys.argv) < 3:
                print("Error: workflow_name required")
                sys.exit(1)
            workflow_name = sys.argv[2]
            execution = get_latest_execution(workflow_name)
            if execution:
                print_execution_summary(execution)
            else:
                print(f"No executions found for workflow: {workflow_name}")

        elif command == "find-workflow":
            if len(sys.argv) < 3:
                print("Error: name_pattern required")
                sys.exit(1)
            name_pattern = sys.argv[2]
            workflow = find_workflow_by_name(name_pattern)
            if workflow:
                print(json.dumps(workflow, indent=2))
            else:
                print(f"Workflow not found: {name_pattern}")

        elif command == "update-workflow":
            if len(sys.argv) < 4:
                print("Error: workflow_id and json_file required")
                sys.exit(1)
            workflow_id = sys.argv[2]
            json_file = sys.argv[3]

            # Read workflow data from JSON file
            with open(json_file, 'r') as f:
                workflow_data = json.load(f)

            print(f"Updating workflow {workflow_id}...")
            result = update_workflow(workflow_id, workflow_data)
            print(f"✓ Workflow updated successfully!")
            print(f"  Name: {result.get('name', 'Unknown')}")
            print(f"  Active: {result.get('active', False)}")
            print(f"  Nodes: {len(result.get('nodes', []))}")

        else:
            print(f"Unknown command: {command}")
            sys.exit(1)

    except (urllib.error.HTTPError, urllib.error.URLError) as e:
        print(f"API Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
