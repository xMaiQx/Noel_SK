#!/usr/bin/env python3
"""
Automated Notion Database Verification Script

This script verifies that all three Notion databases (Projects, Learnings, Sessions)
match the specification in data-model.md by querying them via the n8n API wrapper.

Prerequisites:
1. Environment configured in .env file
2. n8n workflow with notion_API_AIS webhook active
3. Notion databases created and shared with integration
4. At least one test record in each database (for schema detection)

Usage:
    python3 scripts/verify-all-databases.py
"""

import json
import os
import subprocess
import sys
from pathlib import Path

# Color codes
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color

# Load environment variables
def load_env():
    env_file = Path(__file__).parent.parent / '.env'
    if not env_file.exists():
        print(f"{Colors.RED}Error: .env file not found{Colors.NC}")
        sys.exit(1)

    env_vars = {}
    with open(env_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                # Remove quotes if present
                value = value.strip('"').strip("'")
                # Expand ${VAR} references
                while '${' in value:
                    start = value.index('${')
                    end = value.index('}', start)
                    var_name = value[start+2:end]
                    var_value = env_vars.get(var_name, os.getenv(var_name, ''))
                    value = value[:start] + var_value + value[end+1:]
                env_vars[key] = value

    return env_vars

# Query Notion database
def query_database(env_vars, data_source_id):
    """Query a Notion database to get one record (for schema inspection)"""
    url = env_vars.get('NOTION_API_WRAPPER_URL')
    auth_token = env_vars.get('AUTH_TOKEN')

    if not url or not auth_token:
        print(f"{Colors.RED}Error: NOTION_API_WRAPPER_URL or AUTH_TOKEN not set in .env{Colors.NC}")
        sys.exit(1)

    payload = json.dumps({
        "query": {
            "endpoint": "query_data_source",
            "id": data_source_id
        },
        "body": {
            "page_size": 1
        }
    })

    curl_cmd = [
        'curl', '-s', '-X', 'POST', url,
        '-H', 'Content-Type: application/json',
        '-H', f'Authorization: {auth_token}',
        '-d', payload
    ]

    try:
        result = subprocess.run(curl_cmd, capture_output=True, text=True, check=True)
        data = json.loads(result.stdout)

        if isinstance(data, list) and len(data) > 0:
            data = data[0]

        if 'results' in data and len(data['results']) > 0:
            return data['results'][0]['properties']
        else:
            return None
    except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError) as e:
        print(f"{Colors.RED}Error querying database: {e}{Colors.NC}")
        return None

# Verify Projects database
def verify_projects(env_vars):
    print(f"\n{Colors.CYAN}{'=' * 70}{Colors.NC}")
    print(f"{Colors.CYAN} PROJECTS DATABASE{Colors.NC}")
    print(f"{Colors.CYAN}{'=' * 70}{Colors.NC}\n")

    props = query_database(env_vars, env_vars.get('NOTION_PROJECTS_DS'))

    if not props:
        print(f"{Colors.RED}✗ Could not retrieve Projects database{Colors.NC}")
        print(f"{Colors.YELLOW}Tip: Add at least one test record to the database{Colors.NC}")
        return False

    expected = {
        'Name': 'title',
        'Status': 'select',
        'Priority': 'select',
        'Tech Stack': 'multi_select',
        'Description': 'rich_text',
        'Started': 'date',
        'Last Activity': 'date',
        'Learning Count': 'rollup',
        'Session Count': 'rollup',
        'Total Session Hours': 'rollup'
    }

    print(f"Total fields: {Colors.CYAN}{len(props)}{Colors.NC}")
    print(f"Required fields: {Colors.CYAN}{len(expected)}{Colors.NC}\n")

    all_pass = True
    for field_name, expected_type in sorted(expected.items()):
        if field_name in props:
            actual_type = props[field_name]['type']
            if actual_type == expected_type:
                print(f"  {Colors.GREEN}✓{Colors.NC} {field_name}: {actual_type}")
            else:
                print(f"  {Colors.RED}✗{Colors.NC} {field_name}: expected {expected_type}, got {actual_type}")
                all_pass = False
        else:
            print(f"  {Colors.RED}✗{Colors.NC} {field_name}: MISSING")
            all_pass = False

    # Check for extra fields (excluding expected reverse relations)
    extra = set(props.keys()) - set(expected.keys()) - {'Learnings', 'Sessions'}
    if extra:
        print(f"\n{Colors.YELLOW}⚠️  Unexpected fields: {', '.join(sorted(extra))}{Colors.NC}")

    print()
    if all_pass:
        print(f"{Colors.GREEN}✅ Projects database VERIFIED{Colors.NC}")
    else:
        print(f"{Colors.RED}✗ Projects database FAILED verification{Colors.NC}")

    return all_pass

# Verify Learnings database
def verify_learnings(env_vars):
    print(f"\n{Colors.CYAN}{'=' * 70}{Colors.NC}")
    print(f"{Colors.CYAN} LEARNINGS DATABASE{Colors.NC}")
    print(f"{Colors.CYAN}{'=' * 70}{Colors.NC}\n")

    props = query_database(env_vars, env_vars.get('NOTION_LEARNINGS_DS'))

    if not props:
        print(f"{Colors.RED}✗ Could not retrieve Learnings database{Colors.NC}")
        print(f"{Colors.YELLOW}Tip: Add at least one test record to the database{Colors.NC}")
        return False

    expected = {
        'Title': 'title',
        'Learning ID': 'rich_text',
        'Project': 'relation',
        'Type': 'select',
        'Dev Stream': 'multi_select',
        'Content': 'rich_text',
        'Context': 'rich_text',
        'Tags': 'multi_select',
        'Related Files': 'rich_text',
        'Confidence': 'select',
        'Status': 'select',
        'Timestamp': 'date',
        'Last Modified': 'date',
        'Session': 'relation',
        'AI Suggested': 'checkbox',
        'AI Accepted': 'checkbox'
    }

    print(f"Total fields: {Colors.CYAN}{len(props)}{Colors.NC}")
    print(f"Required fields: {Colors.CYAN}{len(expected)}{Colors.NC}\n")

    all_pass = True
    for field_name, expected_type in sorted(expected.items()):
        if field_name in props:
            actual_type = props[field_name]['type']
            if actual_type == expected_type:
                print(f"  {Colors.GREEN}✓{Colors.NC} {field_name}: {actual_type}")
            else:
                print(f"  {Colors.RED}✗{Colors.NC} {field_name}: expected {expected_type}, got {actual_type}")
                all_pass = False
        else:
            print(f"  {Colors.RED}✗{Colors.NC} {field_name}: MISSING")
            all_pass = False

    # Check for extra fields
    extra = set(props.keys()) - set(expected.keys())
    if extra:
        print(f"\n{Colors.YELLOW}⚠️  Unexpected fields: {', '.join(sorted(extra))}{Colors.NC}")

    print()
    if all_pass:
        print(f"{Colors.GREEN}✅ Learnings database VERIFIED{Colors.NC}")
    else:
        print(f"{Colors.RED}✗ Learnings database FAILED verification{Colors.NC}")

    return all_pass

# Verify Sessions database
def verify_sessions(env_vars):
    print(f"\n{Colors.CYAN}{'=' * 70}{Colors.NC}")
    print(f"{Colors.CYAN} SESSIONS DATABASE{Colors.NC}")
    print(f"{Colors.CYAN}{'=' * 70}{Colors.NC}\n")

    props = query_database(env_vars, env_vars.get('NOTION_SESSIONS_DS'))

    if not props:
        print(f"{Colors.RED}✗ Could not retrieve Sessions database{Colors.NC}")
        print(f"{Colors.YELLOW}Tip: Add at least one test record to the database{Colors.NC}")
        return False

    expected = {
        'Session ID': 'title',
        'Projects': 'relation',
        'Goals': 'rich_text',
        'Start Time': 'date',
        'End Time': 'date',
        'Status': 'select',
        'AI Type': 'select',
        'Recording File Path': 'rich_text',
        'Recording Format': 'select',
        'Learning Count': 'rollup',
        'Duration': 'formula'
    }

    print(f"Total fields: {Colors.CYAN}{len(props)}{Colors.NC}")
    print(f"Required fields: {Colors.CYAN}{len(expected)}{Colors.NC}\n")

    all_pass = True
    for field_name, expected_type in sorted(expected.items()):
        if field_name in props:
            actual_type = props[field_name]['type']
            if actual_type == expected_type:
                print(f"  {Colors.GREEN}✓{Colors.NC} {field_name}: {actual_type}")
            else:
                print(f"  {Colors.RED}✗{Colors.NC} {field_name}: expected {expected_type}, got {actual_type}")
                all_pass = False
        else:
            print(f"  {Colors.RED}✗{Colors.NC} {field_name}: MISSING")
            all_pass = False

    # Check for extra fields (excluding expected reverse relation)
    extra = set(props.keys()) - set(expected.keys()) - {'Learnings'}
    if extra:
        print(f"\n{Colors.YELLOW}⚠️  Unexpected fields: {', '.join(sorted(extra))}{Colors.NC}")

    print()
    if all_pass:
        print(f"{Colors.GREEN}✅ Sessions database VERIFIED{Colors.NC}")
    else:
        print(f"{Colors.RED}✗ Sessions database FAILED verification{Colors.NC}")

    return all_pass

# Main function
def main():
    print(f"{Colors.CYAN}╔════════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.CYAN}║  Notion Database Automated Verification                   ║{Colors.NC}")
    print(f"{Colors.CYAN}╚════════════════════════════════════════════════════════════╝{Colors.NC}")

    # Load environment
    env_vars = load_env()

    print(f"\nAPI Wrapper URL: {Colors.GREEN}{env_vars.get('NOTION_API_WRAPPER_URL')}{Colors.NC}")
    print(f"Using databases:")
    print(f"  Projects:  {Colors.CYAN}{env_vars.get('NOTION_PROJECTS_DS')}{Colors.NC}")
    print(f"  Learnings: {Colors.CYAN}{env_vars.get('NOTION_LEARNINGS_DS')}{Colors.NC}")
    print(f"  Sessions:  {Colors.CYAN}{env_vars.get('NOTION_SESSIONS_DS')}{Colors.NC}")

    # Verify all databases
    projects_pass = verify_projects(env_vars)
    learnings_pass = verify_learnings(env_vars)
    sessions_pass = verify_sessions(env_vars)

    # Summary
    print(f"\n{Colors.CYAN}{'=' * 70}{Colors.NC}")
    print(f"{Colors.CYAN} VERIFICATION SUMMARY{Colors.NC}")
    print(f"{Colors.CYAN}{'=' * 70}{Colors.NC}\n")

    total = 3
    passed = sum([projects_pass, learnings_pass, sessions_pass])

    print(f"Total databases: {Colors.CYAN}{total}{Colors.NC}")
    print(f"Verified:        {Colors.GREEN}{passed}{Colors.NC}")
    print(f"Failed:          {Colors.RED}{total - passed}{Colors.NC}\n")

    if passed == total:
        print(f"{Colors.GREEN}╔════════════════════════════════════════════════════════════╗{Colors.NC}")
        print(f"{Colors.GREEN}║  ✓ ALL DATABASES VERIFIED - READY FOR IMPLEMENTATION!     ║{Colors.NC}")
        print(f"{Colors.GREEN}╚════════════════════════════════════════════════════════════╝{Colors.NC}\n")
        print(f"{Colors.YELLOW}Next steps:{Colors.NC}")
        print("1. Build n8n workflow using verified database schemas")
        print("2. Test endpoints with scripts/test-endpoints.sh")
        print("3. Start capturing learnings!\n")
        sys.exit(0)
    else:
        print(f"{Colors.RED}╔════════════════════════════════════════════════════════════╗{Colors.NC}")
        print(f"{Colors.RED}║  ✗ VERIFICATION FAILED - FIX ERRORS ABOVE                  ║{Colors.NC}")
        print(f"{Colors.RED}╚════════════════════════════════════════════════════════════╝{Colors.NC}\n")
        print(f"{Colors.YELLOW}To fix issues:{Colors.NC}")
        print("1. Review failed checks above")
        print("2. Compare with specs/001-knowledge-repository/data-model.md")
        print("3. Update databases in Notion")
        print("4. Re-run this script to verify\n")
        sys.exit(1)

if __name__ == '__main__':
    main()
